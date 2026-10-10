package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/config"
	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/store"
)

func newTestServer(t *testing.T) (*Server, *store.Store) {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "t.duckdb"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = st.Close() })
	cfg := config.Config{
		JWTSecret:      "test-secret",
		AllowedOrigins: []string{"http://127.0.0.1:47219"},
		AppOrigins:     []string{"http://127.0.0.1:47219"},
	}
	return New(cfg, st), st
}

func TestHealth(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rr.Code != http.StatusOK || !bytes.Contains(rr.Body.Bytes(), []byte(`"duckdb":"ok"`)) {
		t.Fatalf("health: %d %s", rr.Code, rr.Body.String())
	}
}

func TestMembershipIsolationAndSync(t *testing.T) {
	srv, st := newTestServer(t)
	ctx := t.Context()
	userA := "11111111-1111-4111-8111-111111111111"
	userB := "22222222-2222-4222-8222-222222222222"
	baby := "33333333-3333-4333-8333-333333333333"
	feeding := "44444444-4444-4444-8444-444444444444"
	if err := st.CreateUser(ctx, userA, "a@example.com", "sub-a"); err != nil {
		t.Fatal(err)
	}
	if err := st.CreateUser(ctx, userB, "b@example.com", "sub-b"); err != nil {
		t.Fatal(err)
	}
	tokenA, _, err := srv.signAccess(userA)
	if err != nil {
		t.Fatal(err)
	}
	tokenB, _, err := srv.signAccess(userB)
	if err != nil {
		t.Fatal(err)
	}
	body := []byte(`{"id":"` + baby + `","name":"Ada"}`)
	rr := do(srv, http.MethodPost, "/v1/babies", tokenA, body)
	if rr.Code != http.StatusOK {
		t.Fatalf("create baby: %d %s", rr.Code, rr.Body.String())
	}
	rr = do(srv, http.MethodGet, "/v1/babies/"+baby+"/feedings", tokenB, nil)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("other family read: %d %s", rr.Code, rr.Body.String())
	}
	now := time.Now().UTC().Format(time.RFC3339)
	feed := []byte(`{"type":"bottle","start_utc":"` + now + `","end_utc":"` + now + `","utc_offset_min":0,"amount_ml":40,"notes":"secret note","updated_at":"` + now + `"}`)
	rr = do(srv, http.MethodPut, "/v1/babies/"+baby+"/feedings/"+feeding, tokenB, feed)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("other family write: %d %s", rr.Code, rr.Body.String())
	}
	rr = do(srv, http.MethodPut, "/v1/babies/"+baby+"/feedings/"+feeding, tokenA, feed)
	if rr.Code != http.StatusOK {
		t.Fatalf("put: %d %s", rr.Code, rr.Body.String())
	}
	var saved map[string]any
	_ = json.Unmarshal(rr.Body.Bytes(), &saved)
	if saved["type"] != "formula" {
		t.Fatalf("type map: %#v", saved["type"])
	}
	rr = do(srv, http.MethodPut, "/v1/babies/"+baby+"/feedings/"+feeding, tokenA, feed)
	if rr.Code != http.StatusOK {
		t.Fatalf("idempotent put: %d %s", rr.Code, rr.Body.String())
	}
	rr = do(srv, http.MethodDelete, "/v1/babies/"+baby+"/feedings/"+feeding, tokenA, nil)
	if rr.Code != http.StatusOK {
		t.Fatalf("delete: %d %s", rr.Code, rr.Body.String())
	}
	rr = do(srv, http.MethodGet, "/v1/babies/"+baby+"/feedings?since=0", tokenA, nil)
	if rr.Code != http.StatusOK || !bytes.Contains(rr.Body.Bytes(), []byte(`"deleted_at"`)) {
		t.Fatalf("since: %d %s", rr.Code, rr.Body.String())
	}
	var page struct {
		Feedings []struct {
			DeletedAt *string `json:"deleted_at"`
		} `json:"feedings"`
		SyncToken float64 `json:"sync_token"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &page); err != nil {
		t.Fatal(err)
	}
	if len(page.Feedings) != 1 || page.Feedings[0].DeletedAt == nil || page.SyncToken < 1 {
		t.Fatalf("tombstone: %+v", page)
	}
}

func TestWeekSummaryAndEvents(t *testing.T) {
	srv, st := newTestServer(t)
	ctx := t.Context()
	user := "55555555-5555-4555-8555-555555555555"
	baby := "66666666-6666-4666-8666-666666666666"
	if err := st.CreateUser(ctx, user, "c@example.com", "sub-c"); err != nil {
		t.Fatal(err)
	}
	token, _, _ := srv.signAccess(user)
	rr := do(srv, http.MethodPost, "/v1/babies", token, []byte(`{"id":"`+baby+`","name":"Bea"}`))
	if rr.Code != http.StatusOK {
		t.Fatal(rr.Body.String())
	}
	start := time.Date(2026, 10, 5, 9, 0, 0, 0, time.UTC).Format(time.RFC3339)
	end := time.Date(2026, 10, 5, 9, 20, 0, 0, time.UTC).Format(time.RFC3339)
	feed := "77777777-7777-4777-8777-777777777777"
	body := []byte(`{"type":"formula","start_utc":"` + start + `","end_utc":"` + end + `","utc_offset_min":0,"amount_ml":90,"updated_at":"` + end + `"}`)
	rr = do(srv, http.MethodPut, "/v1/babies/"+baby+"/feedings/"+feed, token, body)
	if rr.Code != http.StatusOK {
		t.Fatalf("put: %s", rr.Body.String())
	}
	rr = do(srv, http.MethodGet, "/v1/babies/"+baby+"/summary/week?start=2026-10-05&today=2026-10-08", token, nil)
	if rr.Code != http.StatusOK {
		t.Fatal(rr.Body.String())
	}
	var summary struct {
		Averages struct {
			FormulaMl int `json:"formula_ml"`
		} `json:"averages"`
		Trend []struct {
			WeekStart string `json:"week_start"`
		} `json:"trend"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &summary); err != nil {
		t.Fatal(err)
	}
	if summary.Averages.FormulaMl != 30 {
		t.Fatalf("average formula ml = %d, body %s", summary.Averages.FormulaMl, rr.Body.String())
	}
	if len(summary.Trend) != 8 {
		t.Fatalf("trend len %d", len(summary.Trend))
	}
	event := `{"events":[{"event_id":"88888888-8888-4888-8888-888888888888","name":"app_opened","client_ts":"` + end + `","anon_id":"99999999-9999-4999-8999-999999999999","session_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","platform":"web","app_version":"0.1.0","props":{"display_mode":"browser","notes":"nope"}}]}`
	rr = do(srv, http.MethodPost, "/v1/events", "", []byte(event))
	if rr.Code != http.StatusOK {
		t.Fatalf("events: %d %s", rr.Code, rr.Body.String())
	}
	n, err := st.CountEvents(ctx)
	if err != nil || n != 1 {
		t.Fatalf("count events %d %v", n, err)
	}
}

func TestRefreshRotation(t *testing.T) {
	srv, st := newTestServer(t)
	user := "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
	if err := st.CreateUser(t.Context(), user, "d@example.com", "sub-d"); err != nil {
		t.Fatal(err)
	}
	tokens, err := srv.issueTokens(t.Context(), user)
	if err != nil {
		t.Fatal(err)
	}
	raw := tokens["refresh_token"].(string)
	rr := do(srv, http.MethodPost, "/v1/auth/refresh", "", []byte(`{"refresh_token":"`+raw+`"}`))
	if rr.Code != http.StatusOK {
		t.Fatalf("refresh: %d %s", rr.Code, rr.Body.String())
	}
	rr = do(srv, http.MethodPost, "/v1/auth/refresh", "", []byte(`{"refresh_token":"`+raw+`"}`))
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("reused refresh: %d %s", rr.Code, rr.Body.String())
	}
}

func do(srv *Server, method, path, token string, body []byte) *httptest.ResponseRecorder {
	var r *http.Request
	if body == nil {
		r = httptest.NewRequest(method, path, nil)
	} else {
		r = httptest.NewRequest(method, path, bytes.NewReader(body))
	}
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	rr := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr, r)
	return rr
}

// Each account sees only its own babies, by the keys the app reads.
func TestListBabiesPerUser(t *testing.T) {
	srv, st := newTestServer(t)
	ctx := t.Context()
	userA := "77777777-7777-4777-8777-777777777777"
	userB := "88888888-8888-4888-8888-888888888888"
	baby := "99999999-9999-4999-8999-999999999999"
	for _, u := range []string{userA, userB} {
		if err := st.CreateUser(ctx, u, u+"@example.com", "sub-"+u); err != nil {
			t.Fatal(err)
		}
	}
	tokenA, _, _ := srv.signAccess(userA)
	tokenB, _, _ := srv.signAccess(userB)
	if rr := do(srv, http.MethodPost, "/v1/babies", tokenA, []byte(`{"id":"`+baby+`","name":"Bea"}`)); rr.Code != http.StatusOK {
		t.Fatal(rr.Body.String())
	}

	var got struct {
		Babies []map[string]any `json:"babies"`
	}
	rr := do(srv, http.MethodGet, "/v1/babies", tokenA, nil)
	if err := json.Unmarshal(rr.Body.Bytes(), &got); err != nil || len(got.Babies) != 1 {
		t.Fatalf("user A babies: %d %s", rr.Code, rr.Body.String())
	}
	if got.Babies[0]["id"] != baby || got.Babies[0]["name"] != "Bea" {
		t.Fatalf("baby json: %s", rr.Body.String())
	}

	rr = do(srv, http.MethodGet, "/v1/babies", tokenB, nil)
	if err := json.Unmarshal(rr.Body.Bytes(), &got); err != nil || len(got.Babies) != 0 {
		t.Fatalf("user B should see no babies: %s", rr.Body.String())
	}
}

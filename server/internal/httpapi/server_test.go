package httpapi

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
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
	entry := "44444444-4444-4444-8444-444444444444"
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
	rr = do(srv, http.MethodGet, "/v1/babies/"+baby+"/entries", tokenB, nil)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("other family read: %d %s", rr.Code, rr.Body.String())
	}
	now := time.Now().UTC().Format(time.RFC3339)
	feed := []byte(`{"type":"formula","start_utc":"` + now + `","end_utc":"` + now + `","utc_offset_min":0,"amount_ml":40,"notes":"secret note","updated_at":"` + now + `"}`)
	rr = do(srv, http.MethodPut, "/v1/babies/"+baby+"/entries/"+entry, tokenB, feed)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("other family write: %d %s", rr.Code, rr.Body.String())
	}
	rr = do(srv, http.MethodPut, "/v1/babies/"+baby+"/entries/"+entry, tokenA, feed)
	if rr.Code != http.StatusOK {
		t.Fatalf("put: %d %s", rr.Code, rr.Body.String())
	}
	var saved map[string]any
	_ = json.Unmarshal(rr.Body.Bytes(), &saved)
	if saved["type"] != "formula" {
		t.Fatalf("type map: %#v", saved["type"])
	}
	rr = do(srv, http.MethodPut, "/v1/babies/"+baby+"/entries/"+entry, tokenA, feed)
	if rr.Code != http.StatusOK {
		t.Fatalf("idempotent put: %d %s", rr.Code, rr.Body.String())
	}
	rr = do(srv, http.MethodDelete, "/v1/babies/"+baby+"/entries/"+entry, tokenA, nil)
	if rr.Code != http.StatusOK {
		t.Fatalf("delete: %d %s", rr.Code, rr.Body.String())
	}
	rr = do(srv, http.MethodGet, "/v1/babies/"+baby+"/entries?since=0", tokenA, nil)
	if rr.Code != http.StatusOK || !bytes.Contains(rr.Body.Bytes(), []byte(`"deleted_at"`)) {
		t.Fatalf("since: %d %s", rr.Code, rr.Body.String())
	}
	var page struct {
		Entries []struct {
			DeletedAt *string `json:"deleted_at"`
		} `json:"entries"`
		SyncToken float64 `json:"sync_token"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &page); err != nil {
		t.Fatal(err)
	}
	if len(page.Entries) != 1 || page.Entries[0].DeletedAt == nil || page.SyncToken < 1 {
		t.Fatalf("tombstone: %+v", page)
	}
}

func TestEvents(t *testing.T) {
	srv, st := newTestServer(t)
	end := time.Date(2026, 10, 5, 9, 20, 0, 0, time.UTC).Format(time.RFC3339)
	event := `{"events":[{"event_id":"88888888-8888-4888-8888-888888888888","name":"app_opened","client_ts":"` + end + `","anon_id":"99999999-9999-4999-8999-999999999999","session_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","platform":"web","app_version":"0.1.0","props":{"display_mode":"browser","notes":"nope"}}]}`
	rr := do(srv, http.MethodPost, "/v1/events", "", []byte(event))
	if rr.Code != http.StatusOK {
		t.Fatalf("events: %d %s", rr.Code, rr.Body.String())
	}
	n, err := st.CountEvents(t.Context())
	if err != nil || n != 1 {
		t.Fatalf("count events %d %v", n, err)
	}
}

// newFamily makes a user with one baby and returns the token and baby id.
func newFamily(t *testing.T, srv *Server, st *store.Store, user, baby string) string {
	t.Helper()
	if err := st.CreateUser(t.Context(), user, user+"@example.com", "sub-"+user); err != nil {
		t.Fatal(err)
	}
	token, _, err := srv.signAccess(user)
	if err != nil {
		t.Fatal(err)
	}
	if rr := do(srv, http.MethodPost, "/v1/babies", token, []byte(`{"id":"`+baby+`","name":"Bea"}`)); rr.Code != http.StatusOK {
		t.Fatalf("create baby: %s", rr.Body.String())
	}
	return token
}

func entryBody(fields string) []byte {
	start := time.Date(2026, 10, 5, 9, 0, 0, 0, time.UTC).Format(time.RFC3339)
	end := time.Date(2026, 10, 5, 9, 20, 0, 0, time.UTC).Format(time.RFC3339)
	return []byte(`{"start_utc":"` + start + `","end_utc":"` + end + `","utc_offset_min":120,"updated_at":"` + end + `",` + fields + `}`)
}

// Every kind of entry saves, comes back with its own fields, and drops the rest.
func TestEntryTypesRoundTrip(t *testing.T) {
	srv, st := newTestServer(t)
	baby := "66666666-6666-4666-8666-666666666666"
	token := newFamily(t, srv, st, "55555555-5555-4555-8555-555555555555", baby)
	cases := []struct {
		name, fields string
		want         map[string]any
	}{
		{"breast", `"type":"breast","left_ms":600000,"right_ms":300000,"end_side":"right","amount_ml":50`,
			map[string]any{"left_ms": 600000.0, "right_ms": 300000.0, "end_side": "right", "amount_ml": 0.0}},
		{"formula", `"type":"formula","amount_ml":120,"left_ms":5,"end_side":"left"`,
			map[string]any{"amount_ml": 120.0, "left_ms": 0.0, "end_side": nil}},
		{"breast milk", `"type":"breast_milk","amount_ml":90`, map[string]any{"amount_ml": 90.0}},
		{"pump per side", `"type":"pump","left_ml":40,"right_ml":60,"amount_ml":1`,
			map[string]any{"left_ml": 40.0, "right_ml": 60.0, "amount_ml": 100.0}},
		{"pump total", `"type":"pump","amount_ml":80`, map[string]any{"amount_ml": 80.0, "left_ml": 0.0}},
		{"diaper", `"type":"diaper","diaper":"both","rash":true,"amount_ml":30`,
			map[string]any{"diaper": "both", "rash": true, "amount_ml": 0.0}},
		{"routine", `"type":"routine","title":" Tummy time ","value":"x"`,
			map[string]any{"title": "Tummy time", "value": ""}},
		{"other", `"type":"other","title":"Weight","value":"4.87","unit":"kg","notes":"after bath"`,
			map[string]any{"title": "Weight", "value": "4.87", "unit": "kg", "notes": "after bath"}},
	}
	for i, c := range cases {
		id := fmt.Sprintf("00000000-0000-4000-8000-%012d", i+1)
		rr := do(srv, http.MethodPut, "/v1/babies/"+baby+"/entries/"+id, token, entryBody(c.fields))
		if rr.Code != http.StatusOK {
			t.Fatalf("%s: put %d %s", c.name, rr.Code, rr.Body.String())
		}
		var got map[string]any
		_ = json.Unmarshal(rr.Body.Bytes(), &got)
		for k, v := range c.want {
			if got[k] != v {
				t.Errorf("%s: %s = %#v, want %#v", c.name, k, got[k], v)
			}
		}
	}
	rr := do(srv, http.MethodGet, "/v1/babies/"+baby+"/entries?since=0", token, nil)
	var page struct {
		Entries []map[string]any `json:"entries"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &page); err != nil || len(page.Entries) != len(cases) {
		t.Fatalf("list: %d entries, %s", len(page.Entries), rr.Body.String())
	}
}

func TestEntryValidation(t *testing.T) {
	srv, st := newTestServer(t)
	baby := "66666666-6666-4666-8666-666666666666"
	token := newFamily(t, srv, st, "55555555-5555-4555-8555-555555555555", baby)
	start := time.Date(2026, 10, 5, 9, 0, 0, 0, time.UTC).Format(time.RFC3339)
	cases := map[string][]byte{
		"invalid_type":      entryBody(`"type":"bottle","amount_ml":90`),
		"end_side_required": entryBody(`"type":"breast","left_ms":60000`),
		"diaper_required":   entryBody(`"type":"diaper","diaper":"soggy"`),
		"title_required":    entryBody(`"type":"routine","title":"  "`),
		"value_too_long":    entryBody(`"type":"other","title":"Weight","unit":"` + strings.Repeat("k", 17) + `"`),
		"invalid_amount":    entryBody(`"type":"formula","amount_ml":2001`),
		"pump_empty": []byte(`{"type":"pump","start_utc":"` + start + `","end_utc":"` + start +
			`","utc_offset_min":0,"updated_at":"` + start + `"}`),
	}
	for want, body := range cases {
		rr := do(srv, http.MethodPut, "/v1/babies/"+baby+"/entries/77777777-7777-4777-8777-777777777777", token, body)
		if rr.Code != http.StatusBadRequest || !strings.Contains(rr.Body.String(), want) {
			t.Errorf("%s: got %d %s", want, rr.Code, rr.Body.String())
		}
	}
}

func TestUpdateBabyNameAndBirthDate(t *testing.T) {
	srv, st := newTestServer(t)
	baby := "66666666-6666-4666-8666-666666666666"
	token := newFamily(t, srv, st, "55555555-5555-4555-8555-555555555555", baby)
	path := "/v1/babies/" + baby
	check := func(body, wantName string, wantBirth any) {
		t.Helper()
		rr := do(srv, http.MethodPatch, path, token, []byte(body))
		if rr.Code != http.StatusOK {
			t.Fatalf("%s: %d %s", body, rr.Code, rr.Body.String())
		}
		var got map[string]any
		_ = json.Unmarshal(rr.Body.Bytes(), &got)
		if got["name"] != wantName || got["birth_date"] != wantBirth {
			t.Fatalf("%s: got %v", body, got)
		}
	}
	check(`{"birth_date":"2026-09-01"}`, "Bea", "2026-09-01")
	check(`{"name":"Ada"}`, "Ada", "2026-09-01")
	check(`{"name":"Ada","birth_date":null}`, "Ada", nil)
	for _, bad := range []string{`{}`, `{"name":""}`, `{"birth_date":"01/09/2026"}`, `{"birth_date":"2999-01-01"}`} {
		if rr := do(srv, http.MethodPatch, path, token, []byte(bad)); rr.Code != http.StatusBadRequest {
			t.Errorf("%s: got %d", bad, rr.Code)
		}
	}
}

func TestDeleteAccountRemovesEntries(t *testing.T) {
	srv, st := newTestServer(t)
	baby := "66666666-6666-4666-8666-666666666666"
	token := newFamily(t, srv, st, "55555555-5555-4555-8555-555555555555", baby)
	if rr := do(srv, http.MethodPut, "/v1/babies/"+baby+"/entries/77777777-7777-4777-8777-777777777777", token,
		entryBody(`"type":"diaper","diaper":"wet"`)); rr.Code != http.StatusOK {
		t.Fatal(rr.Body.String())
	}
	if rr := do(srv, http.MethodDelete, "/v1/me", token, nil); rr.Code != http.StatusOK && rr.Code != http.StatusNoContent {
		t.Fatalf("delete me: %d %s", rr.Code, rr.Body.String())
	}
	// Signing up again with a fresh account cannot see anything left behind.
	token2 := newFamily(t, srv, st, "12121212-1212-4121-8121-121212121212", "34343434-3434-4343-8343-343434343434")
	if rr := do(srv, http.MethodGet, "/v1/babies/"+baby+"/entries", token2, nil); rr.Code != http.StatusNotFound {
		t.Fatalf("old baby still reachable: %d", rr.Code)
	}
}

func TestReopenKeepsSchema(t *testing.T) {
	path := filepath.Join(t.TempDir(), "t.duckdb")
	for i := 0; i < 2; i++ {
		st, err := store.Open(path)
		if err != nil {
			t.Fatalf("open %d: %v", i, err)
		}
		_ = st.Close()
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

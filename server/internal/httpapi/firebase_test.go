package httpapi

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestFirebaseStatusUnconfigured(t *testing.T) {
	srv, _ := newTestServer(t)
	rr := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/v1/auth/firebase/status", nil))
	if rr.Code != http.StatusOK {
		t.Fatal(rr.Body.String())
	}
	var status map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &status); err != nil {
		t.Fatal(err)
	}
	if status["configured"] != false {
		t.Fatalf("configured: %#v", status)
	}
	missing, _ := status["missing"].([]any)
	if len(missing) != 5 {
		t.Fatalf("missing: %#v", status["missing"])
	}
}

func TestFirebaseExchangeVerifiesIDToken(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	const kid = "test-key"
	jwks := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"keys": []map[string]string{{
				"kty": "RSA",
				"alg": "RS256",
				"use": "sig",
				"kid": kid,
				"n":   base64.RawURLEncoding.EncodeToString(key.N.Bytes()),
				"e":   base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.E)).Bytes()),
			}},
		})
	}))
	t.Cleanup(jwks.Close)
	firebaseKeys = firebaseKeySet{}

	srv, _ := newTestServer(t)
	srv.cfg.FirebaseAPIKey = "public-web-key"
	srv.cfg.FirebaseAuthDomain = "demo.firebaseapp.com"
	srv.cfg.FirebaseProjectID = "demo-project"
	srv.cfg.FirebaseAppID = "1:1:web:abc"
	srv.cfg.FirebaseSenderID = "1"
	srv.cfg.FirebaseKeysURL = jwks.URL

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iss":            "https://securetoken.google.com/demo-project",
		"aud":            "demo-project",
		"sub":            "firebase-uid-1",
		"email":          "Parent@Example.com",
		"email_verified": true,
		"iat":            time.Now().Add(-time.Minute).Unix(),
		"exp":            time.Now().Add(time.Hour).Unix(),
	})
	token.Header["kid"] = kid
	signed, err := token.SignedString(key)
	if err != nil {
		t.Fatal(err)
	}
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/firebase/exchange", strings.NewReader(`{"id_token":"`+signed+`"}`))
	req.Header.Set("Content-Type", "application/json")
	srv.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("exchange: %d %s", rr.Code, rr.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	user, _ := body["user"].(map[string]any)
	if user["email"] != "parent@example.com" || body["access_token"] == "" {
		t.Fatalf("body: %s", rr.Body.String())
	}

	rr = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/v1/auth/firebase/exchange", strings.NewReader(`{"id_token":"not-a-jwt"}`))
	req.Header.Set("Content-Type", "application/json")
	srv.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("bad token: %d %s", rr.Code, rr.Body.String())
	}
}

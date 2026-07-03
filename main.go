package main

import (
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/chidanandabv/zero-trust-proxy/proxy"
)

const BackendURL = "http://localhost:8081"

func main() {
	tlsCfg, err := proxy.BuildTLSConfig()
	if err != nil {
		log.Fatal("TLS config error:", err)
	}

	backend, _ := url.Parse(BackendURL)
	reverseProxy := httputil.NewSingleHostReverseProxy(backend)

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// mTLS already enforced by TLS config

		// Verify JWT
		tokenStr := proxy.ExtractToken(r)
		if tokenStr == "" {
			http.Error(w, "Missing JWT token", http.StatusUnauthorized)
			return
		}
		claims, err := proxy.VerifyJWT(tokenStr)
		if err != nil {
			http.Error(w, "Invalid JWT: "+err.Error(), http.StatusUnauthorized)
			return
		}

		// Check permissions
		if !proxy.IsAllowed(claims, r.Method, r.URL.Path) {
			http.Error(w, "Forbidden", http.StatusForbidden)
			return
		}

		// Forward to backend

		r.Header.Set("X-User", claims.Username)
		roles := strings.Join(claims.RealmAccess.Roles, ",")
		r.Header.Set("X-Role", roles)
		reverseProxy.ServeHTTP(w, r)
	})

	server := &http.Server{
		Addr:      ":9090",
		Handler:   mux,
		TLSConfig: tlsCfg,
	}

	fmt.Println("Zero-Trust Proxy running on https://localhost:9090")
	log.Fatal(server.ListenAndServeTLS("certs/proxy.crt", "certs/proxy.key"))
}

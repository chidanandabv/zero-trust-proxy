package main

import (
	"encoding/json"
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/api/orders", ordersHandler)
	http.HandleFunc("/api/admin", adminHandler)
	http.HandleFunc("/health", healthHandler)

	fmt.Println("Backend running on :8081")
	http.ListenAndServe(":8081", nil)
}

func ordersHandler(w http.ResponseWriter, r *http.Request) {
	user := r.Header.Get("X-User")
	json.NewEncoder(w).Encode(map[string]any{
		"orders": []string{"order-1", "order-2"},
		"user":   user,
	})
}

func adminHandler(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{
		"message": "You reached the admin panel",
	})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("OK"))
}

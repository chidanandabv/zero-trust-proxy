package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	http.HandleFunc("/files/", filesHandler)
	http.HandleFunc("/files", listFilesHandler)
	http.HandleFunc("/health", healthHandler)

	fmt.Println("File Server running on :8082")
	http.ListenAndServe(":8082", nil)
}

func listFilesHandler(w http.ResponseWriter, r *http.Request) {
	user := r.Header.Get("X-User")
	role := r.Header.Get("X-Role")

	entries, err := os.ReadDir("/app/files")
	if err != nil {
		http.Error(w, "Cannot read files directory", http.StatusInternalServerError)
		return
	}

	var fileList []string
	for _, entry := range entries {
		if !entry.IsDir() {
			fileList = append(fileList, entry.Name())
		}
	}

	json.NewEncoder(w).Encode(map[string]any{
		"user":    user,
		"role":    role,
		"files":   fileList,
		"message": "Files accessible through Zero-Trust Proxy",
	})
}

func filesHandler(w http.ResponseWriter, r *http.Request) {
	user := r.Header.Get("X-User")
	role := r.Header.Get("X-Role")

	filename := strings.TrimPrefix(r.URL.Path, "/files/")
	if filename == "" {
		http.Error(w, "Filename required", http.StatusBadRequest)
		return
	}

	// Clean path to prevent directory traversal
	cleanName := filepath.Base(filename)
	filePath := filepath.Join("/app/files", cleanName)

	content, err := os.ReadFile(filePath)
	if err != nil {
		http.Error(w, "File not found: "+cleanName, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprintf(w, "=== File: %s ===\n", cleanName)
	fmt.Fprintf(w, "Accessed by: %s (role: %s)\n", user, role)
	fmt.Fprintf(w, "=================\n\n")
	w.Write(content)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("File Server OK"))
}

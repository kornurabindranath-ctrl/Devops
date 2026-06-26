package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

func homeHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "🚀 Docker Optimization\n")
	fmt.Fprintf(w, "Current Time: %s\n", time.Now().Format(time.RFC1123))
	fmt.Fprintf(w, "Hostname: %s\n", getHostname())
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "OK")
}

func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "Unknown"
	}
	return hostname
}

func main() {

	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/health", healthHandler)

	port := "8080"

	log.Printf("🚀 Starting Go server %s", port)

	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		log.Fatal(err)
	}
}

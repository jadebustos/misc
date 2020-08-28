package main

// run go get github.com/gorilla/mux to install the dependency before running the code
import (
	"github.com/gorilla/mux"
	"log"
	"net/http"
)

import "time"

var timeout int = 5

// prints a message on /
func YourHandler(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("Hello world!!!\n"))
}

// print a message en /health after a timeout
func Health(w http.ResponseWriter, r *http.Request) {
	time.Sleep(time.Duration(timeout) * time.Second)
	w.Write([]byte("200 OK"))
}

func main() {

	r := mux.NewRouter()
	// Routes consist of a path and a handler function.
	r.HandleFunc("/", YourHandler)
	// Routes consist of a path and a handler function.
	r.HandleFunc("/health", Health)

	// Bind to a port and pass our router in
	log.Fatal(http.ListenAndServe(":8080", r))
}

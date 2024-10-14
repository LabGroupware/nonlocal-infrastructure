package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		host := r.Host
		fmt.Fprintf(w, "Request Host: %s\n", host)
	})

	http.ListenAndServe(":80", nil)
}

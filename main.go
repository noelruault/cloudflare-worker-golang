//go:build js && wasm

package main

import (
	"log"
	"syscall/js"
)

func handleRequest(_ js.Value, input []js.Value) interface{} {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("panic occurred: %v", err)
		}
	}()

	return js.Global().Get("Response").New(
		`{"hello":"world"}`,
	)
}

func main() {
	// Define the function "handleRequest" in the JavaScript scope
	js.Global().Set("handleRequest", js.FuncOf(handleRequest))

	select {} // Prevent the function from returning, which is required in a wasm module
}

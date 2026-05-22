package main

import "core:fmt"

import "jarl"

step_fn :: proc(app: ^jarl.App) {
	if jarl.input_is_key_pressed(&app.input, .Escape) {
		app.running = false
	}
}

main :: proc() {
	jarl.app_run({
		step_fn = step_fn,
		window_title = "Noneuclid",
		window_width = 800,
		window_height = 600,
	})
}
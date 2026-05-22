package main

import "core:fmt"

import "jarl"

step_fn :: proc(app: ^jarl.App) {
	iter: i32
	for key in jarl.input_iter_keys_pressed(&app.input, &iter) {
		fmt.println("Key held: ", key)
	}

	if jarl.input_is_key_pressed(&app.input, .Escape) {
		app.running = false
	}
}

main :: proc() {
	descriptor: jarl.AppDescriptor = {
		gl_major_version = 3,
		gl_minor_version = 3,

		init_fn = nil,
		step_fn = step_fn,
		draw_fn = nil,

		window_title = "Noneuclid",
		window_width = 800,
		window_height = 600,
	}

	switch jarl.app_run(descriptor) {
		case .None: break
		case .GlfwInitializationFailed: fmt.println("Failed to initialize GLFW")
		case .WindowCreationFailed: fmt.println("Failed to create window")
	}
}
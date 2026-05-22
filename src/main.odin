package main

import "core:fmt"
import "vendor:glfw"

step_fn :: proc(app: ^App) {
	iter: i32
	for key in input_iter_keys_down(&app.input, &iter) {
		fmt.println("Key held: ", key)
	}

	if input_is_key_pressed(&app.input, glfw.KEY_ESCAPE) {
		app.running = false
	}
}

main :: proc() {
	app: App

	app_set_step(&app, step_fn)

	switch app_run(&app) {
		case .None: break
		case .GlfwInitializationFailed: fmt.println("Failed to initialize GLFW")
		case .WindowCreationFailed: fmt.println("Failed to create window")
	}
}
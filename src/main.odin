package main

import "core:fmt"

main :: proc() {
	switch app_run() {
		case .None: break
		case .GlfwInitializationFailed: fmt.println("Failed to initialize GLFW")
		case .WindowCreationFailed: fmt.println("Failed to create window")
	}
}
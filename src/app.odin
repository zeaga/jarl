package main

import "core:fmt"
import "core:time"
import "vendor:glfw"
import gl "vendor:OpenGL"

App :: struct {
	run_time: time.Time,
	delta_time: time.Duration,
	running: bool,
	window: Window,
	init_fn: proc (app: ^App),
	step_fn: proc (app: ^App),
	draw_fn: proc (app: ^App),
}

app_run :: proc() -> Error {
	app: App

	glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	if !glfw.Init() {
		return Error.GlfwInitializationFailed
	}
	defer glfw.Terminate()

	if !window_create(&app.window, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE) {
		return Error.WindowCreationFailed
	}
	defer window_destroy(&app.window)

	glfw.SwapInterval(1)

	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	app.run_time = time.now()
	app.running = true

	if app.init_fn != nil {
		app->init_fn()
	}

	for app.running && !window_should_close(&app.window) {
		current_time := time.now()
		app.delta_time = time.diff(current_time, app.run_time)
		app.run_time = current_time
		glfw.PollEvents()

		if app.step_fn != nil {
			app->step_fn()
		}

		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)
		if app.draw_fn != nil {
			app->draw_fn()
		}

		glfw.SwapBuffers(app.window.handle)
	}

	return Error.None
}
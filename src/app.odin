package main

import "core:time"
import "vendor:glfw"
import gl "vendor:OpenGL"

App :: struct {
	run_time: time.Time,
	delta_time: time.Duration,
	running: bool,
	window: Window,
	input: Input,
	init_fn: proc (app: ^App),
	step_fn: proc (app: ^App),
	draw_fn: proc (app: ^App),
}

app_run :: proc(app: ^App) -> Error {
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
	glfw.SetWindowUserPointer(app.window.handle, app)

	app.input.window_size = {WINDOW_WIDTH, WINDOW_HEIGHT}
	app.input.mouse_pos = {glfw.GetCursorPos(app.window.handle)}

	glfw.SetCursorPosCallback(app.window.handle, _app_mouse_pos_cbfn)
	glfw.SetFramebufferSizeCallback(app.window.handle, _app_size_cbfn)
	glfw.SetKeyCallback(app.window.handle, _app_key_cbfn)
	glfw.SetMouseButtonCallback(app.window.handle, _app_mouse_btn_cbfn)
	glfw.SetScrollCallback(app.window.handle, _app_scroll_cbfn)

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

		input_begin_frame(&app.input)
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

app_set_init :: proc(app: ^App, init_fn: proc (app: ^App)) {
	app.init_fn = init_fn
}

app_set_step :: proc(app: ^App, step_fn: proc (app: ^App)) {
	app.step_fn = step_fn
}

app_set_draw :: proc(app: ^App, draw_fn: proc (app: ^App)) {
	app.draw_fn = draw_fn
}

@(private="file") _app_mouse_pos_cbfn :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	app := (^App)(glfw.GetWindowUserPointer(window))
	app.input.mouse_delta = {xpos - app.input.mouse_pos[0], ypos - app.input.mouse_pos[1]}
	app.input.mouse_pos = {xpos, ypos}
}

@(private="file") _app_size_cbfn :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	app := (^App)(glfw.GetWindowUserPointer(window))
	app.input.window_size = {width, height}
	app.input.window_resized = true
	gl.Viewport(0, 0, width, height)
}

@(private="file") _app_key_cbfn :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	app := (^App)(glfw.GetWindowUserPointer(window))
	if key >= 0 && key <= glfw.KEY_LAST {
		app.input.keys_current[key] = action != glfw.RELEASE
	}
}

@(private="file") _app_mouse_btn_cbfn :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	app := (^App)(glfw.GetWindowUserPointer(window))
	if button >= 0 && button <= glfw.MOUSE_BUTTON_LAST {
		app.input.mbtns_current[button] = action != glfw.RELEASE
	}
}

@(private="file") _app_scroll_cbfn :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
	app := (^App)(glfw.GetWindowUserPointer(window))
	app.input.scroll_delta = {xoffset, yoffset}
}
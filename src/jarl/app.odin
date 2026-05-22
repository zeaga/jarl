package jarl

import "core:log"
import "core:time"
import "vendor:glfw"
import gl "vendor:OpenGL"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

AppDescriptor :: struct {
	init_fn: proc (app: ^App),
	step_fn: proc (app: ^App),
	draw_fn: proc (app: ^App),

	window_title: cstring,
	window_width: i32,
	window_height: i32,

	log_level: log.Level,

	user_data: rawptr,
}

App :: struct {
	run_time: time.Time,
	delta_time: time.Duration,
	running: bool,

	user_data: rawptr,
	logger: log.Logger,
	
	log_level: log.Level,
	init_fn: proc (app: ^App),
	step_fn: proc (app: ^App),
	draw_fn: proc (app: ^App),

	window: Window,
	input: Input,
	lvm: LuaVm,
}

app_run :: proc(descriptor: AppDescriptor) -> (ok: bool) {
	app: App

	app.log_level = descriptor.log_level != nil ? descriptor.log_level : log.Level.Info
	app.logger = log.create_console_logger(app.log_level)
	context.logger = app.logger
	defer log.destroy_console_logger(app.logger)

	if descriptor.init_fn != nil {
		app.init_fn = descriptor.init_fn
	}

	if descriptor.step_fn != nil {
		app.step_fn = descriptor.step_fn
	}

	if descriptor.draw_fn != nil {
		app.draw_fn = descriptor.draw_fn
	}

	glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	if !glfw.Init() {
		log.error("Failed to initialize GLFW")
		return false
	}
	defer glfw.Terminate()

	if !window_create(&app.window, descriptor.window_width, descriptor.window_height, descriptor.window_title) {
		log.error("Failed to create window")
		return false
	}
	defer window_destroy(&app.window)
	glfw.SetWindowUserPointer(app.window.handle, &app)

	app.input.window_size = {descriptor.window_width, descriptor.window_height}
	app.input.mouse_pos = {glfw.GetCursorPos(app.window.handle)}

	glfw.SetCursorPosCallback(app.window.handle, _app_mouse_pos_cbfn)
	glfw.SetFramebufferSizeCallback(app.window.handle, _app_size_cbfn)
	glfw.SetKeyCallback(app.window.handle, _app_key_cbfn)
	glfw.SetMouseButtonCallback(app.window.handle, _app_mouse_btn_cbfn)
	glfw.SetScrollCallback(app.window.handle, _app_scroll_cbfn)

	glfw.SwapInterval(1)

	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	lvm_init(&app.lvm)
	defer lvm_destroy(&app.lvm)

	app.run_time = time.now()
	app.running = true

	if app.init_fn != nil {
		app.init_fn(&app)
	}

	for app.running && !window_should_close(&app.window) {
		current_time := time.now()
		app.delta_time = time.diff(current_time, app.run_time)
		app.run_time = current_time

		input_begin_frame(&app.input)
		glfw.PollEvents()

		if app.step_fn != nil {
			app.step_fn(&app)
		}

		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)
		if app.draw_fn != nil {
			app.draw_fn(&app)
		}

		glfw.SwapBuffers(app.window.handle)
	}

	return true
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
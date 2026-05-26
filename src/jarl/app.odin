package jarl

import "base:runtime"
import "core:log"
import "core:math"
import "vendor:glfw"
import gl "vendor:OpenGL"
import im "shared:imgui"

AppDescriptor :: struct {
	window_title: cstring,
	window_width: i32,
	window_height: i32,

	log_level: log.Level,
}

App :: struct {
	clear_color: [4]f32,
	ctx: runtime.Context,
	running: bool,
	vao: u32,

	debug_mode: bool,
	
	camera: Camera,
	input: Input,
	lvm: LuaVm,
	imstate: ImState,
	scene: Scene,
	shader: Shader,
	timing: Timing,
	window: Window,
}

app_run :: proc(descriptor: AppDescriptor) -> (ok: bool) {
	app: App

	app.debug_mode = DEBUG_MODE
	
	log_level := descriptor.log_level != nil ? descriptor.log_level : log.Level.Info
	context.logger = log.create_console_logger(log_level)
	defer log.destroy_console_logger(context.logger)
	
	app.ctx = context

	glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	if !glfw.Init() {
		log.fatal("Failed to initialize GLFW")
		runtime.exit(-1)
	}
	defer glfw.Terminate()

	window_create(&app.window, descriptor.window_width, descriptor.window_height, descriptor.window_title)
	defer window_destroy(&app.window)
	glfw.SetWindowUserPointer(app.window.handle, &app)

	app.input.window_size = {descriptor.window_width, descriptor.window_height}
	app.input.mouse_pos = {glfw.GetCursorPos(app.window.handle)}

	glfw.SetCursorPosCallback(app.window.handle, _app_mouse_pos_cbfn)
	glfw.SetFramebufferSizeCallback(app.window.handle, _app_size_cbfn)
	glfw.SetKeyCallback(app.window.handle, _app_key_cbfn)
	glfw.SetMouseButtonCallback(app.window.handle, _app_mouse_btn_cbfn)
	// glfw.SetWindowRefreshCallback(app.window.handle, _app_refresh_cbfn)
	glfw.SetScrollCallback(app.window.handle, _app_scroll_cbfn)

	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	shader_create(&app.shader)
	defer shader_destroy(&app.shader)

	gl.GenVertexArrays(1, &app.vao)
	gl.BindVertexArray(app.vao)
	defer gl.DeleteVertexArrays(1, &app.vao)

	scene_create(&app.scene)
	defer scene_destroy(&app.scene)

	imgui_init(&app, &app.imstate)
	defer imgui_destroy()

	app.running = true
	timing_init(&app.timing)

	lvm_create(&app.lvm)
	defer lvm_destroy(&app.lvm)

	app_init(&app)

	for app.running && !window_should_close(&app.window) {
		app_update(&app)
		app_render(&app)
	}

	return true
}

app_init :: proc(app: ^App) {
	// INIT HERE
	app.camera.position.z = 10.0
	app.camera.yaw = 180.0
	app.camera.fov = 45.0
	app.clear_color = {0.2, 0.3, 0.5, 1.0}
}

app_update :: proc(app: ^App) {
	timing_update(&app.timing)

	input_update(&app.input)
	glfw.PollEvents()

	imgui_update(app, &app.imstate)

	if input_is_key_down(&app.input, .Escape) {
		app.running = false
	}

	if input_is_key_pressed(&app.input, .GraveAccent) {
		app.debug_mode = !app.debug_mode
	}

	if input_is_mouse_pressed(&app.input, .Left) && (!IMGUI_ENABLED || !im.GetIO().WantCaptureMouse) {
		window_set_mouse_mode(&app.window, .Disabled)
	}

	if input_is_key_pressed(&app.input, .Tab) {
		window_set_mouse_mode(&app.window, .Normal)
	}

	if window_get_mouse_mode(&app.window) != .Normal {
		cam_update(&app.camera, app)
	}
	// UPDATE HERE
}

app_render :: proc(app: ^App) {
	dt := app.timing.delta_time

	gl.ClearColor(0.0, 0.0, 0.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	shader_bind(&app.shader)
	gl.BindVertexArray(app.vao)

	shader_set_uniforms(app, &app.shader)

	t := math.sin(app.timing.run_time)

	scene_add_sphere(&app.scene, {0, 0, 0}, t / 2 + 1.5, {max(0,t), 1.0, max(0,-t), 1})
	scene_add_box(&app.scene, {4, t, 0}, 1.0, t + 2.0, 1.0, {0.1, 0.3, 1.0, 1})

	scene_bind(&app.scene)
	shader_set_uniform(&app.shader, "primitive_count", cast(i32)len(app.scene.primitives))
	gl.DrawArrays(gl.TRIANGLES, 0, 3)

	if IMGUI_ENABLED {
		imgui_render()
	}

	scene_flush(&app.scene)

	window_swap_buffers(&app.window)
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

@(private="file") _app_refresh_cbfn :: proc "c" (window: glfw.WindowHandle) {
	app := (^App)(glfw.GetWindowUserPointer(window))
	context = app.ctx
	app_render(app)
}

@(private="file") _app_scroll_cbfn :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
	app := (^App)(glfw.GetWindowUserPointer(window))
	app.input.scroll_delta = {xoffset, yoffset}
}
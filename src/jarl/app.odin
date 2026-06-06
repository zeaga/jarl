package jarl

import "base:runtime"
import "core:log"
import sdl "vendor:sdl3"
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
	imstate: ImState,
	scene: Scene,
	shader: Shader,
	timing: Timing,
	window: Window,
}

app_run :: proc(descriptor: AppDescriptor) -> (ok: bool) {
	prof_init()
	defer prof_deinit()

	app: App

	app.debug_mode = DEBUG_MODE
	
	log_level := descriptor.log_level != nil ? descriptor.log_level : log.Level.Info
	context.logger = log.create_console_logger(log_level)
	defer log.destroy_console_logger(context.logger)
	log.info("running")
	
	app.ctx = context

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, GL_MAJOR_VERSION)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, GL_MINOR_VERSION)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_CORE))

	if !sdl.Init({.VIDEO}) {
		log.fatal("Failed to initialize SDL:", sdl.GetError())
		runtime.exit(-1)
	}
	defer sdl.Quit()

	window_create(&app.window, descriptor.window_width, descriptor.window_height, descriptor.window_title)
	defer window_destroy(&app.window)

	app.input.window_size = {descriptor.window_width, descriptor.window_height}
	{
		x, y: f32
		_ = sdl.GetMouseState(&x, &y)
		app.input.mouse_pos = {f64(x), f64(y)}
	}

	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, sdl.gl_set_proc_address)

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

	app_init(&app)

	for app.running && !window_should_close(&app.window) {
		prof_frame()
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

	e: sdl.Event
	for sdl.PollEvent(&e) {
		imgui_process_event(&e)
		#partial switch e.type {
		case .QUIT, .WINDOW_CLOSE_REQUESTED:
			app.window.should_close = true
		case .KEY_DOWN, .KEY_UP:
			sc := i32(e.key.scancode)
			if sc >= 0 && sc < i32(Key.Count) {
				app.input.keys_current[sc] = e.type == .KEY_DOWN
			}
		case .MOUSE_MOTION:
			app.input.mouse_delta[0] += f64(e.motion.xrel)
			app.input.mouse_delta[1] += f64(e.motion.yrel)
			app.input.mouse_pos = {f64(e.motion.x), f64(e.motion.y)}
		case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
			btn := i32(e.button.button)
			if btn >= 0 && btn < i32(MouseButton.Count) {
				app.input.mbtns_current[btn] = e.type == .MOUSE_BUTTON_DOWN
			}
		case .MOUSE_WHEEL:
			app.input.scroll_delta[0] += f64(e.wheel.x)
			app.input.scroll_delta[1] += f64(e.wheel.y)
		case .WINDOW_PIXEL_SIZE_CHANGED:
			w := e.window.data1
			h := e.window.data2
			app.input.window_size = {w, h}
			app.input.window_resized = true
			gl.Viewport(0, 0, w, h)
		}
	}

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

	if input_is_mouse_pressed(&app.input, .Right) && window_get_mouse_mode(&app.window) != .Normal {
		window_set_mouse_mode(&app.window, .Normal)
	}

	if input_is_key_pressed(&app.input, .Tab) {
		window_set_mouse_mode(&app.window, .Normal)
	}

	if window_get_mouse_mode(&app.window) != .Normal {
		camera_update(&app.camera, app)
	}
	// UPDATE HERE
}

app_render :: proc(app: ^App) {
	gl.ClearColor(0.0, 0.0, 0.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	shader_bind(&app.shader)
	gl.BindVertexArray(app.vao)

	shader_set_uniforms(app, &app.shader)

	scene_upload(&app.scene)
	shader_set_uniform(&app.shader, "primitive_count", cast(i32)len(app.scene.primitives))
	shader_set_uniform(&app.shader, "portal_count", cast(i32)len(app.scene.portals))
	gl.DrawArrays(gl.TRIANGLES, 0, 3)

	if IMGUI_ENABLED {
		imgui_render()
	}

	// scene_flush(&app.scene)

	window_swap_buffers(&app.window)
}

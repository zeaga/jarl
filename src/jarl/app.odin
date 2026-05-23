package jarl

import "base:runtime"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:time"
import "vendor:glfw"
import gl "vendor:OpenGL"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 3

AppDescriptor :: struct {
	window_title: cstring,
	window_width: i32,
	window_height: i32,

	log_level: log.Level,

	user_data: rawptr,
}

App :: struct {
	start_time: time.Time,
	last_frame: time.Time,
	run_time: time.Duration,
	delta_time: time.Duration,
	running: bool,

	user_data: rawptr,
	ctx: runtime.Context,
	camera: Camera,
	clear_color: [4]f32,

	window: Window,
	input: Input,
	lvm: LuaVm,
	shader: Shader,
	vao: u32,
}

app_run :: proc(descriptor: AppDescriptor) -> (ok: bool) {
	app: App
	
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
	glfw.SetWindowRefreshCallback(app.window.handle, _app_refresh_cbfn)
	glfw.SetScrollCallback(app.window.handle, _app_scroll_cbfn)

	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	shader_create(&app.shader, #load("res/vert.glsl"), #load("res/frag.glsl"))
	defer shader_destroy(&app.shader)

	gl.GenVertexArrays(1, &app.vao)
	gl.BindVertexArray(app.vao)
	defer gl.DeleteVertexArrays(1, &app.vao)

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
	app.start_time = time.now()
	app.last_frame = app.start_time
	app.running = true

	// INIT HERE
	app.camera.position.z = 10.0
	app.camera.fov = 45.0
	app.clear_color = {0.2, 0.3, 0.5, 1.0}
}

app_update :: proc(app: ^App) {
	current_time := time.now()
	app.delta_time = time.diff(app.last_frame, current_time)
	app.run_time = time.diff(app.start_time, current_time)
	app.last_frame = current_time

	input_begin_frame(&app.input)
	glfw.PollEvents()

	if input_is_key_down(&app.input, .Escape) {
		app.running = false
	}

	if input_is_mouse_pressed(&app.input, .Left) {
		window_set_mouse_mode(&app.window, .Disabled)
	}

	if input_is_key_pressed(&app.input, .Tab) {
		window_set_mouse_mode(&app.window, .Normal)
	}

	if window_get_mouse_mode(&app.window) != .Normal {
		cam_update(app)
	}
	// UPDATE HERE
}

cam_update :: proc(app: ^App) {
	delta_time := cast(f32)time.duration_seconds(app.delta_time)
	
	LOOK_SPEED :: 0.7
	MOVE_SPEED :: 5.0

	mx, my := input_get_mouse_delta(&app.input)
	if mx != 0 || my != 0 {
		app.camera.yaw -= cast(f32)mx * delta_time * LOOK_SPEED
		app.camera.pitch -= cast(f32)my * delta_time * LOOK_SPEED
		app.camera.pitch = math.clamp(app.camera.pitch, -89.0, 89.0)
	}

	move_dir := [3]f32{0, 0, 0}
	if input_is_key_down(&app.input, .A) {
		move_dir.x -= 1
	}
	if input_is_key_down(&app.input, .D) {
		move_dir.x += 1
	}
	if input_is_key_down(&app.input, .Space) {
		move_dir.y += 1
	}
	if input_is_key_down(&app.input, .LeftControl) {
		move_dir.y -= 1
	}
	if input_is_key_down(&app.input, .W) {
		move_dir.z -= 1
	}
	if input_is_key_down(&app.input, .S) {
		move_dir.z += 1
	}

	if move_dir.x != 0 || move_dir.y != 0 || move_dir.z != 0 {
		move_dir = linalg.normalize(move_dir)
		rot_mtx := camera_get_rotation_matrix(&app.camera)
		move_world := rot_mtx * move_dir
		app.camera.position += move_world * delta_time * MOVE_SPEED
	}

}

app_render :: proc(app: ^App) {
	gl.ClearColor(0.0, 0.0, 0.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	shader_bind(&app.shader)
	gl.BindVertexArray(app.vao)

	rot_mtx := camera_get_rotation_matrix(&app.camera)
	shader_set_uniform(&app.shader, "cam_position", &app.camera.position)
	shader_set_uniform(&app.shader, "cam_rotation", &rot_mtx)
	shader_set_uniform(&app.shader, "cam_tan_half_fov", camera_get_tan_half_fov(&app.camera))
	shader_set_uniform(&app.shader, "resolution", cast(f32)app.input.window_size.x, cast(f32)app.input.window_size.y)
	shader_set_uniform(&app.shader, "clear_color", &app.clear_color)
	shader_set_uniform(&app.shader, "ray_max_steps", 128)
	shader_set_uniform(&app.shader, "ray_max_dist", 200.0)

	// DRAW HERE

	gl.DrawArrays(gl.TRIANGLES, 0, 3)

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
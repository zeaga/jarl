package jarl

import im_glfw "shared:imgui/imgui_impl_glfw"
import im_gl "shared:imgui/imgui_impl_opengl3"
import im "shared:imgui"

ImState :: struct {
	// show_stats: bool,
	// show_debug: bool,
}

imgui_init :: proc(app: ^App, imstate: ^ImState) {
	if !IMGUI_ENABLED {
		return
	}
	im.CHECKVERSION()
	im.CreateContext(nil)
	io := im.GetIO()
	io.ConfigFlags += {im.ConfigFlag.NavEnableKeyboard}
	im.StyleColorsDark()
	im_glfw.InitForOpenGL(app.window.handle, true)
	im_gl.Init(GLSL_VERSION)
	io.IniFilename = nil
	// imstate.show_stats = DEBUG_MODE
	// imstate.show_debug = DEBUG_MODE
}

imgui_update :: proc(app: ^App, imstate: ^ImState) {
	if !IMGUI_ENABLED {
		return
	}
	im_gl.NewFrame()
	im_glfw.NewFrame()
	im.NewFrame()
	io := im.GetIO()
	if window_get_mouse_mode(&app.window) != .Normal {
		io.ConfigFlags += {im.ConfigFlag.NoMouse}
		io.ConfigFlags -= {im.ConfigFlag.NavEnableKeyboard}
	} else {
		io.ConfigFlags -= {im.ConfigFlag.NoMouse}
		io.ConfigFlags += {im.ConfigFlag.NavEnableKeyboard}
	}

	imgui_ui(app, imstate)
}

imgui_ui :: proc(app: ^App, imstate: ^ImState) {
	if !app.debug_mode {
		return
	}

	menuh: f32 = 0
	if (im.BeginMainMenuBar()) {
		if (im.BeginMenu("File")) {
			if (im.MenuItem("Exit", "Ctrl+W")) {app.running = false}
			im.EndMenu()
		}
		menuh = im.GetWindowSize().y
		im.EndMainMenuBar()
	}

	scrw, scrh := input_get_window_size(&app.input)

	// im.SetNextWindowPos({cast(f32)scrw, menuh}, .Always, {1, 0})
	// if im.Begin("Stats", nil, {
	// 	.AlwaysAutoResize, .NoTitleBar,
	// 	.NoMove, .NoResize,
	// 	.NoScrollbar, .NoScrollWithMouse,
	// 	.NoCollapse
	// }) {
	// 	im.Text("%.3f ms/frame (%.1f FPS)", app.timing.delta_time, timing_get_fps(&app.timing))
	// }
	// im.End()

	im.SetNextWindowPos({0, menuh}, .FirstUseEver, {0, 0})
	if im.Begin("Debug", nil, {.AlwaysAutoResize, .NoResize}) {
		im.Text("Camera")
		im.InputFloat3("Position", &app.camera.position)
		rotation := [2]f32{app.camera.yaw, app.camera.pitch}
		im.InputFloat2("Rotation", &rotation)
		app.camera.yaw = rotation[0]
		app.camera.pitch = rotation[1]
		im.SliderFloat("FOV", &app.camera.fov, 1.0, 179.0, "%.0f\xC2\xB0")

		im.SeparatorText("Timing")
		im.Text("%.1f seconds", app.timing.run_time)
		im.Text("%d frames", app.timing.frame_count)
		im.Text("%.3f ms/frame", app.timing.delta_time)
		im.Text("%.1f frames/s", timing_get_fps(&app.timing))
		
		im.SeparatorText("Rendering")
		im.SliderInt("Ray max marches", &app.shader.ray_max_steps, 1, 5000)
		im.SliderFloat("Ray max distance", &app.shader.ray_max_dist, 1.0, 500.0)
	}
	im.End()
}

imgui_render :: proc() {
	if !IMGUI_ENABLED {
		return
	}
	im.Render()
	im_gl.RenderDrawData(im.GetDrawData())
}

imgui_destroy :: proc() {
	if !IMGUI_ENABLED {
		return
	}
	im_gl.Shutdown()
	im_glfw.Shutdown()
	im.DestroyContext()
}
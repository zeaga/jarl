package jarl

import "core:fmt"

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
	im.SetNextWindowSizeConstraints({300, 100}, {cast(f32)scrw * 0.25, cast(f32)scrh - menuh})
	if im.Begin("Debug", nil, {.AlwaysAutoResize, .NoResize}) {
		im.SeparatorText("Timing")
		im.Text("%.1f seconds", app.timing.run_time)
		im.Text("%d frames", app.timing.frame_count)
		im.Text("%.3f ms/frame", app.timing.delta_time)
		im.Text("%.1f frames/s", timing_get_fps(&app.timing))

		im.PushID("Camera")
		im.SeparatorText("Camera")
		im.InputFloat3("Position", &app.camera.position)
		rotation := [2]f32{app.camera.yaw, app.camera.pitch}
		im.InputFloat2("Rotation", &rotation)
		app.camera.yaw = rotation[0]
		app.camera.pitch = rotation[1]
		im.SliderFloat("FOV#camera", &app.camera.fov, 1.0, 179.0, "%.0f\xC2\xB0")
		im.PopID()

		im.PushID("Light")
		im.SeparatorText("Light")
		im.InputFloat3("Position", &app.scene.light_position)
		im.ColorEdit3("Color", &app.scene.light_color)
		im.PopID()
		
		im.SeparatorText("Rendering")
		im.SliderInt("Ray max marches", &app.shader.ray_max_steps, 1, 5000)
		im.SliderFloat("Ray max distance", &app.shader.ray_max_dist, 1.0, 500.0)

		imgui_ui_scene(app, imstate)
	}
	im.End()
}

imgui_ui_scene :: proc(app: ^App, imstate: ^ImState) {
	im.SeparatorText("Scene")
	for i in 0..< len(app.scene.primitives) {
		primitive := &app.scene.primitives[i]
		position: [3]f32 = {primitive.position[0], primitive.position[1], primitive.position[2]}
		im.PushID(fmt.ctprintf("prim_{}", i))
		if !im.CollapsingHeader(fmt.ctprintf("Object {}", i)) {
			im.Spacing()
			im.PopID()
			continue
		}
		im.Indent(10)
		if im.BeginCombo("Type", fmt.ctprintf("{}", primitive.type)) {
			for t in PrimitiveType {
				if im.Selectable(fmt.ctprintf("{}", t), primitive.type == t) {
					primitive.type = t
				}
			}
			im.EndCombo()
		}

		im.InputFloat3("Position", &position)

		switch cast(PrimitiveType)primitive.type {
		case .Sphere:
			im.SliderFloat("Radius", &primitive.param0, 0.1, 10.0, "%.2f", {.Logarithmic})
		case .Box:
			im.SliderFloat("Width", &primitive.param0, 0.1, 10.0, "%.2f", {.Logarithmic})
			im.SliderFloat("Height", &primitive.param1, 0.1, 10.0, "%.2f", {.Logarithmic})
			im.SliderFloat("Depth", &primitive.param2, 0.1, 10.0, "%.2f", {.Logarithmic})
		}

		im.ColorEdit4("Color", &primitive.color)
		primitive.position = {position[0], position[1], position[2], primitive.position[3]}
		if im.Button("Remove") {
			ordered_remove(&app.scene.primitives, i)
		}
		im.Indent(-10)
		im.Spacing()
		im.PopID()
	}
	if im.Button("Add object") {
		scene_add_box(&app.scene, {0, 0, 0}, 1.0, 1.0, 1.0, {1.0, 1.0, 1.0, 1.0})
	}
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
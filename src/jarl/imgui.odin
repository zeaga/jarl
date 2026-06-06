package jarl

import "core:fmt"
import "core:math"

// import "osdialog"

import im_glfw "shared:imgui/imgui_impl_glfw"
import im_gl "shared:imgui/imgui_impl_opengl3"
import im "shared:imgui"

ImState :: struct {
	// show_stats: bool,
	// show_debug: bool,
	scene_path: string,
}

imgui_init :: proc(app: ^App, imstate: ^ImState) {
	if !IMGUI_ENABLED {
		return
	}
	im.CHECKVERSION()
	im.CreateContext(nil)
	io := im.GetIO()
	io.ConfigDragClickToInputText = true
	io.ConfigFlags += {.NavEnableKeyboard}
	im.StyleColorsDark()
	im_glfw.InitForOpenGL(app.window.handle, true)
	im_gl.Init(GLSL_VERSION)
	io.IniFilename = nil
	imstate.scene_path = ""
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
		io.ConfigFlags += {.NoMouse}
		io.ConfigFlags -= {.NavEnableKeyboard}
	} else {
		io.ConfigFlags -= {.NoMouse}
		io.ConfigFlags += {.NavEnableKeyboard}
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
			if (im.MenuItem("New Scene", "Ctrl+N")) {
				scene_flush(&app.scene)
			}
			im.Separator()
			if (im.MenuItem("Load Default Scene", "Ctrl+D")) {
				scene_load_default(&app.scene)
			}
			if (im.MenuItem("Load Scene...", "Ctrl+O")) {
				// TODO
			}
			im.Separator()
			if (im.MenuItem("Save", "Ctrl+S")) {
				// TODO
			}
			if (im.MenuItem("Save As...", "Ctrl+Shift+S")) {
				// TODO
			}
			im.Separator()
			if (im.MenuItem("Exit", "Esc")) {
				app.running = false
			}
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
		im.Text("%.3f ms/frame", timing_get_spf(&app.timing) * 1000)
		im.Text("%.1f frames/s", timing_get_fps(&app.timing))

		im.PushID("Camera")
		im.SeparatorText("Camera")
		im.DragFloat3("Position", &app.camera.position, 0.25, 0.0, 0.0, "%.2f")
		rotation := [2]f32{app.camera.pitch, app.camera.yaw}
		im.DragFloat2("Rotation", &rotation, 1.0, 0.0, 0.0, "%.0f\xC2\xB0")
		rotation = normalize_rotation_2f32(rotation)
		app.camera.pitch = math.clamp(rotation[0], -89.9, 89.9)
		app.camera.yaw = rotation[1]
		im.DragFloat("FOV", &app.camera.fov, 1.0, 1.0, 179.0, "%.0f\xC2\xB0")
		im.PopID()
		
		im.SeparatorText("Rendering")
		im.DragInt("Ray max marches", &app.shader.ray_max_steps, 1, 1, 5000)
		im.DragFloat("Ray max distance", &app.shader.ray_max_dist, 1.0, 1.0, 500.0)
		im.DragInt("Ray max teleports", &app.shader.ray_max_teleports, 1, 1, 50)

		imgui_ui_scene(app, imstate)
	}
	im.End()
}

imgui_ui_scene :: proc(app: ^App, imstate: ^ImState) {
	im.SeparatorText("Scene")
	im.Indent(10)
	imgui_ui_scene_primitives(app, imstate)
	imgui_ui_scene_portals(app, imstate)
	im.Indent(-10)
}

imgui_ui_scene_primitives :: proc(app: ^App, imstate: ^ImState) {
	im.SeparatorText("Primitives")
	im.Indent(10)
	for i in 0..< len(app.scene.primitives) {
		primitive := &app.scene.primitives[i]
		position: [3]f32 = {primitive.position[0], primitive.position[1], primitive.position[2]}
		im.PushID(fmt.ctprintf("prim_{}", i))
		if !im.CollapsingHeader(fmt.ctprintf("Primitive {}", i)) {
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

		im.DragFloat3("Position", &position, 0.25, 0.0, 0.0, "%.2f")

		switch primitive.type {
		case .Sphere:
			im.DragFloat("Radius", &primitive.param0, 0.25, 0.0, 0.0, "%.2f")
		case .Box:
			scale := [3]f32{primitive.param0, primitive.param1, primitive.param2}
			im.DragFloat3("Scale", &scale, 0.25, 0.0, 0.0, "%.2f")
			primitive.param0 = scale[0]
			primitive.param1 = scale[1]
			primitive.param2 = scale[2]
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
	im.Indent(-4)
	if im.Button("Add primitive") {
		scene_add_box(&app.scene, {0, 0, 0}, 1.0, 1.0, 1.0, {1.0, 1.0, 1.0, 1.0})
	}
	im.Indent(-6)
}

imgui_ui_scene_portals :: proc(app: ^App, imstate: ^ImState) {
	im.SeparatorText("Portals")
	im.Indent(10)
	for i in 0..< len(app.scene.portals) {
		portal := &app.scene.portals[i]
		im.PushID(fmt.ctprintf("portal_{}", i))
		if !im.CollapsingHeader(fmt.ctprintf("Portal {}", i)) {
			im.Spacing()
			im.PopID()
			continue
		}
		im.Indent(10)
		if im.BeginCombo("Type", fmt.ctprintf("{}", portal.type)) {
			for t in PortalType {
				if im.Selectable(fmt.ctprintf("{}", t), portal.type == t) {
					portal.type = t
				}
			}
			im.EndCombo()
		}

		position: [3]f32 = {portal.position[0], portal.position[1], portal.position[2]}
		rotation: [2]f32 = {portal.rotation[0], portal.rotation[1]}
		scale := [2]f32 {portal.half_width * 2, portal.half_height * 2}
		im.DragFloat3("Position", &position, 0.25, 0.0, 0.0, "%.2f")
		im.DragFloat2("Rotation", &rotation, 1.0, 0.0, 0.0, "%.0f\xC2\xB0")
		im.DragFloat2("Scale", &scale, 0.25, 0.1, 10.0)
		im.SliderInt("Partner", &portal.partner, 0, i32(len(app.scene.portals)) - 1)
		portal.position = {position[0], position[1], position[2], portal.position[3]}
		rotation = normalize_rotation_2f32(rotation)
		portal.rotation = {rotation[0], rotation[1], portal.rotation[2], portal.rotation[3]}
		portal.half_width = scale[0] * 0.5
		portal.half_height = scale[1] * 0.5
		if portal.partner < 0 || portal.partner >= i32(len(app.scene.portals)) {
			portal.partner = i32(i)
		}

		if im.Button("Remove") {
			for j in 0..< len(app.scene.portals) {
				if app.scene.portals[j].partner == i32(i) {
					app.scene.portals[j].partner = -1
				} else if app.scene.portals[j].partner > i32(i) {
					app.scene.portals[j].partner -= 1
				}
			}
			ordered_remove(&app.scene.portals, i)
		}
		im.Indent(-10)
		im.Spacing()
		im.PopID()
	}
	im.Indent(-4)
	if im.Button("Add portal") {
		scene_add_portal(&app.scene, {0, 0, 0}, {0, 0, 0}, .Rectangle, -1, 0.5, 1.0)
	}
	im.Indent(-6)
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
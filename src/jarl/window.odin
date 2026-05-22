package jarl

import "vendor:glfw"

Window :: struct {
	handle: glfw.WindowHandle,
}

window_create :: proc(window: ^Window, width: i32, height: i32, title: cstring) -> (ok: bool) {
	handle := glfw.CreateWindow(width, height, title, nil, nil)
	if handle == nil {
		return false
	}

	glfw.SwapInterval(1)
	glfw.MakeContextCurrent(handle)

	window.handle = handle
	return true
}

window_should_close :: proc(window: ^Window) -> bool {
	return bool(glfw.WindowShouldClose(window.handle))
}

window_swap_buffers :: proc(window: ^Window) {
	glfw.SwapBuffers(window.handle)
}

window_destroy :: proc(window: ^Window) {
	glfw.DestroyWindow(window.handle)
}
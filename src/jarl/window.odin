package jarl

import "base:runtime"
import "core:log"
import "vendor:glfw"

Window :: struct {
	handle: glfw.WindowHandle,
}

window_create :: proc(window: ^Window, width: i32, height: i32, title: cstring) {
	handle := glfw.CreateWindow(width, height, title, nil, nil)
	if handle == nil {
		log.fatal("Failed to create window")
		runtime.exit(1)
	}

	glfw.MakeContextCurrent(handle)
	glfw.SetInputMode(handle, glfw.RAW_MOUSE_MOTION, 1)
	glfw.SwapInterval(1)

	window.handle = handle
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

window_set_mouse_mode :: proc(window: ^Window, mode: MouseMode) {
	switch mode {
	case .Normal:
		glfw.SetInputMode(window.handle, glfw.CURSOR, glfw.CURSOR_NORMAL)
	case .Hidden:
		glfw.SetInputMode(window.handle, glfw.CURSOR, glfw.CURSOR_HIDDEN)
	case .Captured:
		glfw.SetInputMode(window.handle, glfw.CURSOR, glfw.CURSOR_CAPTURED)
	case .Disabled:
		glfw.SetInputMode(window.handle, glfw.CURSOR, glfw.CURSOR_DISABLED)
	}
}

window_get_mouse_mode :: proc(window: ^Window) -> MouseMode {
	switch glfw.GetInputMode(window.handle, glfw.CURSOR) {
	case glfw.CURSOR_NORMAL:
		return .Normal
	case glfw.CURSOR_HIDDEN:
		return .Hidden
	case glfw.CURSOR_CAPTURED:
		return .Captured
	case glfw.CURSOR_DISABLED:
		return .Disabled
	}
	return .Normal
}
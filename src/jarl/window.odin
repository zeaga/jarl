package jarl

import "base:runtime"
import "core:log"
import sdl "vendor:sdl3"

Window :: struct {
	handle:      ^sdl.Window,
	gl_ctx:      sdl.GLContext,
	mouse_mode:  MouseMode,
	should_close: bool,
}

window_create :: proc(window: ^Window, width: i32, height: i32, title: cstring) {
	handle := sdl.CreateWindow(title, width, height, {.OPENGL, .RESIZABLE})
	if handle == nil {
		log.fatal("Failed to create window:", sdl.GetError())
		runtime.exit(1)
	}

	gl_ctx := sdl.GL_CreateContext(handle)
	if gl_ctx == nil {
		log.fatal("Failed to create OpenGL context:", sdl.GetError())
		runtime.exit(1)
	}

	sdl.GL_MakeCurrent(handle, gl_ctx)
	sdl.GL_SetSwapInterval(1)
	_ = sdl.SetWindowRelativeMouseMode(handle, false)

	window.handle = handle
	window.gl_ctx = gl_ctx
	window.mouse_mode = .Normal
}

window_should_close :: proc(window: ^Window) -> bool {
	return window.should_close
}

window_swap_buffers :: proc(window: ^Window) {
	sdl.GL_SwapWindow(window.handle)
}

window_destroy :: proc(window: ^Window) {
	sdl.GL_DestroyContext(window.gl_ctx)
	sdl.DestroyWindow(window.handle)
}

window_set_mouse_mode :: proc(window: ^Window, mode: MouseMode) {
	switch mode {
	case .Normal:
		_ = sdl.SetWindowRelativeMouseMode(window.handle, false)
		_ = sdl.SetWindowMouseGrab(window.handle, false)
		_ = sdl.ShowCursor()
	case .Hidden:
		_ = sdl.SetWindowRelativeMouseMode(window.handle, false)
		_ = sdl.SetWindowMouseGrab(window.handle, false)
		_ = sdl.HideCursor()
	case .Captured:
		_ = sdl.SetWindowRelativeMouseMode(window.handle, false)
		_ = sdl.SetWindowMouseGrab(window.handle, true)
		_ = sdl.HideCursor()
	case .Disabled:
		_ = sdl.SetWindowRelativeMouseMode(window.handle, true)
	}
	window.mouse_mode = mode
}

window_get_mouse_mode :: proc(window: ^Window) -> MouseMode {
	return window.mouse_mode
}
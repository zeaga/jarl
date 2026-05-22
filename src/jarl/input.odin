package jarl

import "vendor:glfw"

Input :: struct {
	keys_current: [glfw.KEY_LAST + 1]bool,
	keys_previous: [glfw.KEY_LAST + 1]bool,

	mbtns_current: [glfw.MOUSE_BUTTON_LAST + 1]bool,
	mbtns_previous: [glfw.MOUSE_BUTTON_LAST + 1]bool,

	mouse_pos: [2]f64,
	mouse_delta: [2]f64,
	scroll_delta: [2]f64,

	window_size: [2]i32,
	window_resized: bool,
}

input_begin_frame :: proc(input: ^Input) {
	input.window_resized = false
	input.scroll_delta = {0, 0}
	input.mouse_delta = {0, 0}

	for i in 0..=glfw.KEY_LAST {
		input.keys_previous[i] = input.keys_current[i]
	}

	for i in 0..=glfw.MOUSE_BUTTON_LAST {
		input.mbtns_previous[i] = input.mbtns_current[i]
	}
}

input_is_key_down :: proc(input: ^Input, key: i32) -> bool {
	return input.keys_current[key]
}

input_is_key_pressed :: proc(input: ^Input, key: i32) -> bool {
	return input.keys_current[key] && !input.keys_previous[key]
}

input_is_key_released :: proc(input: ^Input, key: i32) -> bool {
	return !input.keys_current[key] && input.keys_previous[key]
}

input_is_mouse_down :: proc(input: ^Input, button: i32) -> bool {
	return input.mbtns_current[button]
}

input_is_mouse_pressed :: proc(input: ^Input, button: i32) -> bool {
	return input.mbtns_current[button] && !input.mbtns_previous[button]
}

input_is_mouse_released :: proc(input: ^Input, button: i32) -> bool {
	return !input.mbtns_current[button] && input.mbtns_previous[button]
}

input_get_mouse_pos :: proc(input: ^Input) -> (x, y: f64) {
	return input.mouse_pos[0], input.mouse_pos[1]
}

input_get_mouse_delta :: proc(input: ^Input) -> (x, y: f64) {
	return input.mouse_delta[0], input.mouse_delta[1]
}

input_get_scroll_delta :: proc(input: ^Input) -> (x, y: f64) {
	return input.scroll_delta[0], input.scroll_delta[1]
}

input_get_window_size :: proc(input: ^Input) -> (x, y: i32) {
	return input.window_size[0], input.window_size[1]
}

input_is_window_resized :: proc(input: ^Input) -> bool {
	return input.window_resized
}

input_iter_keys_pressed :: proc(input: ^Input, iter_state: ^i32) -> (key: i32, ok: bool) {
	for i in iter_state^..=glfw.KEY_LAST {
		if input_is_key_pressed(input, i) {
			iter_state^ = i + 1
			return i, true
		}
	}
	return 0, false
}

input_iter_keys_released :: proc(input: ^Input, iter_state: ^i32) -> (key: i32, ok: bool) {
	for i in iter_state^..=glfw.KEY_LAST {
		if input_is_key_released(input, i) {
			iter_state^ = i + 1
			return i, true
		}
	}
	return 0, false
}

input_iter_keys_down :: proc(input: ^Input, iter_state: ^i32) -> (key: i32, ok: bool) {
	for i in iter_state^..=glfw.KEY_LAST {
		if input_is_key_down(input, i) {
			iter_state^ = i + 1
			return i, true
		}
	}
	return 0, false
}
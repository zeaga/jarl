package jarl

import "vendor:glfw"

Input :: struct {
	keys_current: [Key.Count]bool,
	keys_previous: [Key.Count]bool,

	mbtns_current: [MouseButton.Count]bool,
	mbtns_previous: [MouseButton.Count]bool,

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

	for i in 0..<i32(Key.Count) {
		input.keys_previous[i] = input.keys_current[i]
	}

	for i in 0..<i32(MouseButton.Count) {
		input.mbtns_previous[i] = input.mbtns_current[i]
	}
}

input_is_key_down :: proc(input: ^Input, key: Key) -> bool {
	if key < Key(0) || key >= Key.Count {
		return false
	}
	return input.keys_current[key]
}

input_is_key_pressed :: proc(input: ^Input, key: Key) -> bool {
	if key < Key(0) || key >= Key.Count {
		return false
	}
	return input.keys_current[key] && !input.keys_previous[key]
}

input_is_key_released :: proc(input: ^Input, key: Key) -> bool {
	if key < Key(0) || key >= Key.Count {
		return false
	}
	return !input.keys_current[key] && input.keys_previous[key]
}

input_is_mouse_down :: proc(input: ^Input, button: MouseButton) -> bool {
	if button < MouseButton(0) || button >= MouseButton.Count {
		return false
	}
	return input.mbtns_current[button]
}

input_is_mouse_pressed :: proc(input: ^Input, button: MouseButton) -> bool {
	if button < MouseButton(0) || button >= MouseButton.Count {
		return false
	}
	return input.mbtns_current[button] && !input.mbtns_previous[button]
}

input_is_mouse_released :: proc(input: ^Input, button: MouseButton) -> bool {
	if button < MouseButton(0) || button >= MouseButton.Count {
		return false
	}
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

input_iter_keys_pressed :: proc(input: ^Input, iter_state: ^i32) -> (key: Key, ok: bool) {
	for i in iter_state^..<i32(Key.Count) {
		if input_is_key_pressed(input, Key(i)) {
			iter_state^ = i + 1
			return Key(i), true
		}
	}
	return .Unknown, false
}

input_iter_keys_released :: proc(input: ^Input, iter_state: ^i32) -> (key: Key, ok: bool) {
	for i in iter_state^..<i32(Key.Count) {
		if input_is_key_released(input, Key(i)) {
			iter_state^ = i + 1
			return Key(i), true
		}
	}
	return .Unknown, false
}

input_iter_keys_down :: proc(input: ^Input, iter_state: ^i32) -> (key: Key, ok: bool) {
	for i in iter_state^..<i32(Key.Count) {
		if input_is_key_down(input, Key(i)) {
			iter_state^ = i + 1
			return Key(i), true
		}
	}
	return .Unknown, false
}
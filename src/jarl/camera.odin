package jarl

import "core:math"
import "core:math/linalg"

Camera :: struct {
	position: [3]f32,
	pitch: f32,
	yaw: f32,
	fov: f32,
}

camera_get_tan_half_fov :: proc(camera: ^Camera) -> f32 {
	return math.tan(camera.fov * 0.5 * math.RAD_PER_DEG)
}

camera_get_rotation_matrix :: proc(camera: ^Camera) -> matrix[3, 3]f32 {
	cos_pitch := math.cos(camera.pitch * math.RAD_PER_DEG)
	sin_pitch := math.sin(camera.pitch * math.RAD_PER_DEG)
	cos_yaw := math.cos(camera.yaw * math.RAD_PER_DEG)
	sin_yaw := math.sin(camera.yaw * math.RAD_PER_DEG)

	forward := [3]f32 {
		cos_pitch * sin_yaw,
		sin_pitch,
		-cos_pitch * cos_yaw,
	}
	right := linalg.normalize(linalg.cross(forward, [3]f32{0, 1, 0}))
	up := linalg.cross(right, forward)

	return {
		right.x,   up.x,   forward.x,
		right.y,   up.y,   forward.y,
		right.z,   up.z,   forward.z,
	}
}

cam_update :: proc(camera: ^Camera, app: ^App) {
	dt := app.timing.delta_time
	
	LOOK_SPEED :: 40.0
	MOVE_SPEED :: 5.0
	ALT_MOD :: 0.1
	SHIFT_MOD :: 10.0

	mx, my := input_get_mouse_delta(&app.input)
	if mx != 0 || my != 0 {
		app.camera.yaw -= cast(f32)mx * dt * LOOK_SPEED
		app.camera.pitch += cast(f32)my * dt * LOOK_SPEED
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
		rot_mtx := camera_get_rotation_matrix(camera)
		move_world := rot_mtx * move_dir
		speed: f32 = MOVE_SPEED
		if input_is_key_down(&app.input, .LeftAlt) {
			speed *= ALT_MOD
		}
		if input_is_key_down(&app.input, .LeftShift) {
			speed *= SHIFT_MOD
		}
		app.camera.position += move_world * dt * speed
	}
}
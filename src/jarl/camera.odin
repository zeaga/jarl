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
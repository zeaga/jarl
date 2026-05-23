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
	cos_pitch := math.cos(camera.pitch)
	sin_pitch := math.sin(camera.pitch)
	cos_yaw := math.cos(camera.yaw)
	sin_yaw := math.sin(camera.yaw)

	forward := [3]f32 {
		cos_pitch * sin_yaw,
		sin_pitch,
		-cos_pitch * cos_yaw,
	}
	right := linalg.normalize(linalg.cross(forward, [3]f32{0, 1, 0}))
	up := linalg.cross(right, forward)

	// Rotation order: yaw (Y) then pitch (X)
	return {
		cos_yaw, 0, sin_yaw,
		sin_pitch * sin_yaw, cos_pitch, -sin_pitch * cos_yaw,
		-cos_pitch * sin_yaw, sin_pitch, cos_pitch * cos_yaw,
	}
}
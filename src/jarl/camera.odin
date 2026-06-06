package jarl

import "core:math"
import "core:math/linalg"

Camera :: struct {
	position: [3]f32,
	last_position: [3]f32,
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

camera_update :: proc(camera: ^Camera, app: ^App) {
	camera.last_position = camera.position
	
	_camera_update_input(camera, app)
	
	_camera_update_portal(camera, app)
}

@(private="file") _camera_update_input :: proc(camera: ^Camera, app: ^App) {
	dt := app.timing.delta_time
	
	LOOK_SPEED :: 40.0
	MOVE_SPEED :: 5.0
	ALT_MOD :: 0.1
	SHIFT_MOD :: 10.0

	mx, my := input_get_mouse_delta(&app.input)
	if mx != 0 || my != 0 {
		camera.yaw -= cast(f32)(mx * dt * LOOK_SPEED)
		camera.pitch += cast(f32)(my * dt * LOOK_SPEED)
		camera.yaw = math.mod(math.mod(camera.yaw + 180.0, 360.0) + 360.0, 360.0) - 180.0
		camera.pitch = math.clamp(camera.pitch, -89.9, 89.9)
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
		speed := MOVE_SPEED
		if input_is_key_down(&app.input, .LeftAlt) {
			speed *= ALT_MOD
		}
		if input_is_key_down(&app.input, .LeftShift) {
			speed *= SHIFT_MOD
		}
		camera.position += move_world * cast(f32)(dt * speed)
	}
}

@(private="file") _camera_update_portal :: proc(camera: ^Camera, app: ^App) {
	if camera.last_position == camera.position {
		return
	}

	for portal, i in app.scene.portals {
		if portal.partner == i32(i) || portal.partner < 0 || portal.partner >= i32(len(app.scene.portals)) do continue
		if !_camera_intersects_portal(camera, portal) { continue }

		partner := app.scene.portals[portal.partner]

		camera.position += partner.position.xyz - portal.position.xyz
		camera.last_position = camera.position

		// c_x := camera.pitch * math.RAD_PER_DEG
		// c_y := camera.yaw * math.RAD_PER_DEG

		// pa_x := portal.rotation.x * math.RAD_PER_DEG
		// pa_y := portal.rotation.y * math.RAD_PER_DEG
		// pa_z := portal.rotation.z * math.RAD_PER_DEG

		// pb_x := partner.rotation.x * math.RAD_PER_DEG
		// pb_y := partner.rotation.y * math.RAD_PER_DEG
		// pb_z := partner.rotation.z * math.RAD_PER_DEG

		// camera_q := linalg.quaternion_from_euler_angles(c_x, c_y, 0.0, .YXZ)
		// portal_q := linalg.quaternion_from_euler_angles(pa_x, pa_y, pa_z, .YXZ)
		// partner_q := linalg.quaternion_from_euler_angles(pb_x, pb_y, pb_z, .YXZ)

		// delta_q := linalg.mul(partner_q, linalg.quaternion_inverse(portal_q))
		// new_camera_q := linalg.mul(delta_q, camera_q)

		// new_pitch, new_yaw, _ := linalg.euler_angles_from_quaternion(new_camera_q, .YXZ)
		// camera.pitch = new_pitch * math.DEG_PER_RAD
		// camera.yaw = new_yaw * math.DEG_PER_RAD

		break
	}
}

@(private="file") _camera_intersects_portal :: proc(camera: ^Camera, portal: Portal) -> bool {
	portal_half_size := [2]f32 {portal.half_width, portal.half_height}
	
	pitch := portal.rotation.x * math.RAD_PER_DEG
	yaw := portal.rotation.y * math.RAD_PER_DEG

	portal_normal := [3]f32 {
		math.cos(pitch) * math.sin(yaw),
		math.sin(pitch),
		-math.cos(pitch) * math.cos(yaw),
	}

	return _line_intersects_plane(
		camera.last_position,
		camera.position,
		portal.position.xyz,
		portal_normal,
		portal_half_size,
	)
}

@(private="file") _line_intersects_plane :: proc(
	line_start, line_end: [3]f32,
	plane_position, plane_normal: [3]f32, plane_half_size: [2]f32,
) -> bool {
	EPSILON :: 0.0001

	dir := line_end - line_start

	denom := linalg.dot(plane_normal, dir)
	if abs(denom) < EPSILON { return false }

	t := linalg.dot(plane_normal, plane_position - line_start) / denom
	if t < 0 || t > 1 { return false }

	hit := line_start + dir * t

	up: [3]f32 = {0, 1, 0}
	right := linalg.cross(up, plane_normal)
	if linalg.length(right) < EPSILON {
		up = {0, 0, 1}
		right = linalg.cross(up, plane_normal)
	}
	forward := linalg.cross(plane_normal, linalg.normalize(right))

	local := hit - plane_position
	u := linalg.dot(local, right)
	v := linalg.dot(local, forward)

	return abs(u) <= plane_half_size.x && abs(v) <= plane_half_size.y
}
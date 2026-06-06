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
		camera.yaw = normalize_rotation(camera.yaw)
		camera.pitch = math.clamp(normalize_rotation(camera.pitch), -89.9, 89.9)
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
		y := move_dir.y
		move_dir.y = 0
		if linalg.length2(move_dir) > 0 {
			move_dir = linalg.normalize(move_dir)
		}
		rot_mtx := camera_get_rotation_matrix(camera)
		move_world := rot_mtx * move_dir
		move_world.y += y
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

@(private="file") _portal_rotation :: proc(nA, tA, nB, tB: [3]f32) -> matrix[3, 3]f32 {
	bA := linalg.cross(nA, tA)
	bB := linalg.cross(nB, tB)
	MA := matrix[3, 3]f32{
		-nA.x, tA.x, bA.x,
		-nA.y, tA.y, bA.y,
		-nA.z, tA.z, bA.z,
	}
	MB := matrix[3, 3]f32{
		nB.x, -tB.x, bB.x,
		nB.y, -tB.y, bB.y,
		nB.z, -tB.z, bB.z,
	}
	return MB * linalg.transpose(MA)
}

@(private="file") _camera_update_portal :: proc(camera: ^Camera, app: ^App) {
	if camera.last_position == camera.position {
		return
	}
	for portal, i in app.scene.portals {
		if portal.partner == i32(i) || portal.partner < 0 || portal.partner >= i32(len(app.scene.portals)) do continue
		if !_camera_intersects_portal(camera, portal) do continue
		partner := app.scene.portals[portal.partner]

		flip :: matrix[3, 3]f32{-1, 0, 0,  0, 1, 0,  0, 0, -1}
		delta := euler_to_mat3(partner.rotation.xyz) * flip * linalg.transpose(euler_to_mat3(portal.rotation.xyz))

		camera.position = partner.position.xyz + delta * (camera.position - portal.position.xyz)
		camera.last_position = camera.position

		cm := camera_get_rotation_matrix(camera)
		cam_fwd := [3]f32{cm[0, 2], cm[1, 2], cm[2, 2]}
		new_fwd := delta * cam_fwd
		camera.yaw = math.atan2(new_fwd.x, -new_fwd.z) * math.DEG_PER_RAD
		camera.pitch = math.asin(math.clamp(new_fwd.y, -1, 1)) * math.DEG_PER_RAD
		break
	}
}

@(private="file") _camera_intersects_portal :: proc(camera: ^Camera, portal: Portal) -> bool {
	rot := euler_to_mat3(portal.rotation.xyz)
	normal  := rot * [3]f32{0, 0, 1}
	tangent := rot * [3]f32{1, 0, 0}

	dir := camera.position - camera.last_position
	denom := linalg.dot(normal, dir)
	if abs(denom) < 0.0001 do return false

	t := linalg.dot(normal, portal.position.xyz - camera.last_position) / denom
	if t < 0 || t > 1 do return false

	hit := camera.last_position + dir * t - portal.position.xyz
	bitan := linalg.cross(normal, tangent)
	u := linalg.dot(hit, tangent)
	v := linalg.dot(hit, bitan)

	return abs(u) <= portal.half_width && abs(v) <= portal.half_height
}

@(private="file") _line_intersects_plane :: proc(
	line_start, line_end: [3]f32,
	plane_position, plane_normal: [3]f32, plane_half_size: [2]f32,
) -> bool {
	EPSILON :: 0.0001

	dir := line_end - line_start
	if linalg.length2(dir) < EPSILON {
		return false
	}

	denom := linalg.dot(plane_normal, dir)
	if abs(denom) < EPSILON do return false

	t := linalg.dot(plane_normal, plane_position - line_start) / denom
	if t < 0 || t > 1 do return false

	hit := line_start + dir * t

	up: [3]f32 = {0, 1, 0}
	right := linalg.cross(up, plane_normal)
	if linalg.length(right) < EPSILON {
		up = {0, 0, 1}
		right = linalg.cross(up, plane_normal)
	}
	right = linalg.normalize(right)
	forward := linalg.cross(plane_normal, right)

	local := hit - plane_position
	u := linalg.dot(local, right)
	v := linalg.dot(local, forward)

	return abs(u) <= plane_half_size.x && abs(v) <= plane_half_size.y
}
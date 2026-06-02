package jarl

import gl "vendor:OpenGL"

PrimitiveType :: enum i32 {
	Sphere = 0,
	Box = 1,
}

Primitive :: struct #align(16) {
	position: [4]f32,
	color: [4]f32,
	type: PrimitiveType,
	param0: f32,
	param1: f32,
	param2: f32,
}

Scene :: struct {
	ssbo: u32,
	primitives: [dynamic]Primitive,
	light_position: [3]f32,
	light_color: [3]f32,
}

scene_create :: proc(scene: ^Scene) {
	gl.CreateBuffers(1, &scene.ssbo)
	scene.primitives = make([dynamic]Primitive, 0)
	scene.light_position = {1, 2, 3}
	scene.light_color = {1, 1, 1}
}

scene_add_sphere :: proc(scene: ^Scene, position: [3]f32, radius: f32, color: [4]f32) {
	primitive := Primitive{
		position = {position[0], position[1], position[2], 0},
		color = color,
		type = .Sphere,
		param0 = radius,
	}
	append(&scene.primitives, primitive)
}

scene_add_box :: proc(scene: ^Scene, position: [3]f32, width, height, depth: f32, color: [4]f32) {
	primitive := Primitive{
		position = {position[0], position[1], position[2], 0},
		color = color,
		type = .Box,
		param0 = width,
		param1 = height,
		param2 = depth,
	}
	append(&scene.primitives, primitive)
}
scene_bind :: proc(scene: ^Scene) {
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, scene.ssbo)
	gl.NamedBufferData(
		scene.ssbo,
		len(scene.primitives) * size_of(Primitive),
		raw_data(scene.primitives[:]),
		gl.DYNAMIC_DRAW,
	)
}

scene_flush :: proc(scene: ^Scene) {
	clear(&scene.primitives)
}

scene_destroy :: proc(scene: ^Scene) {
	gl.DeleteBuffers(1, &scene.ssbo)
	delete(scene.primitives)
}
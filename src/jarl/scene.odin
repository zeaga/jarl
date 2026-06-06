package jarl

import "core:encoding/json"
import "core:log"

import gl "vendor:OpenGL"

@(private="file") NUM_SSBOS :: 2

PrimitiveType :: enum i32 {
	Sphere = 0,
	Box = 1,
}

PortalType :: enum i32 {
	Ellipse = 0,
	Rectangle = 1,
}

Primitive :: struct #align(16) {
	position: [4]f32,
	color: [4]f32,
	type: PrimitiveType,
	param0: f32,
	param1: f32,
	param2: f32,
}

Portal :: struct #align(16) {
	position: [4]f32,
	rotation: [4]f32,
	type: PortalType,
	partner: i32,
	half_width: f32,
	half_height: f32,
}

// Light :: struct #align(16) {
// 	position: [4]f32,
// 	color: [4]f32,
// }

Scene :: struct {
	ssbos: [NUM_SSBOS]u32,
	primitives: [dynamic]Primitive,
	portals: [dynamic]Portal,
	// lights: [dynamic]Light,
}

SerializedScene :: struct {
	primitives: [dynamic]Primitive,
	portals: [dynamic]Portal,
	// lights: [dynamic]Light,
}

scene_create :: proc(scene: ^Scene) {
	gl.CreateBuffers(NUM_SSBOS, &scene.ssbos[0])
	scene.primitives = make([dynamic]Primitive, 0)
	scene.portals = make([dynamic]Portal, 0)
	// scene.lights = make([dynamic]Light, 0)
	scene_load_default(scene)
}

scene_load_default :: proc(scene: ^Scene) {
	scene_flush(scene)

	// Floor
	scene_add_box(scene, {0, -1.1, 0}, 40, 0.2, 40, {0.25, 0.25, 0.28, 1})

	// --- 1. The impossible hallway: a 5-unit corridor that never ends ---
	// Two portals face each other; walk forward and you loop forever.
	scene_add_sphere(scene, {0, 0, -6}, 0.4, {1.0, 0.4, 0.2, 1})
	scene_add_sphere(scene, {0, 0, -8}, 0.3, {1.0, 0.7, 0.2, 1})
	scene_add_portal(scene, {0, 0, -10}, {0, 0, 0},   .Rectangle, 1, 1.5, 2.0)
	scene_add_portal(scene, {0, 0,  -5}, {0, 180, 0}, .Rectangle, 0, 1.5, 2.0)

	// --- 2. The 90° turn: walk straight, the world pivots a quarter turn ---
	// Perpendicular portals (yaw 0 -> yaw 90), no physical corner.
	scene_add_sphere(scene, {-12, 0, 0},  0.5, {0.9, 0.2, 0.5, 1})
	scene_add_sphere(scene, {-12, 0, -4}, 0.4, {0.6, 0.2, 1.0, 1})
	scene_add_portal(scene, {-12, 0, 2},  {0, 0, 0},  .Rectangle, 3, 1.2, 2.0)
	scene_add_portal(scene, {-12, 0, -8}, {0, 90, 0}, .Rectangle, 2, 1.2, 2.0)

	// --- 3. The teleport across the map: two distant rooms stitched together ---
	// Step through the left-room portal, emerge in the far right room.
	scene_add_sphere(scene, {-3, 0,  0}, 0.5, {1.0, 0.3, 0.2, 1})
	scene_add_sphere(scene, {-4, 0, -2}, 0.4, {1.0, 0.6, 0.1, 1})
	scene_add_sphere(scene,  {3, 0,  0}, 0.5, {0.2, 0.5, 1.0, 1})
	scene_add_sphere(scene,  {4, 0, -2}, 0.4, {0.1, 0.8, 0.7, 1})
	scene_add_portal(scene, {-2, 0, 8}, {0, 45, 0},   .Rectangle, 5, 1.0, 2.0)
	scene_add_portal(scene,  {3, 0, 8}, {0, -135, 0}, .Rectangle, 4, 1.0, 2.0)

	// --- 4. The acute wedge: portals at a sharp relative angle ---
	// Crossing rotates your view by an odd amount — disorienting but seamless.
	scene_add_sphere(scene, {12, 0, 0}, 0.5, {0.3, 0.5, 1.0, 1})
	scene_add_sphere(scene, {12, 0, 4}, 0.4, {0.5, 0.2, 1.0, 1})
	scene_add_portal(scene, {12, 0, -2}, {0, 30, 0},  .Rectangle, 7, 1.2, 2.0)
	scene_add_portal(scene, {12, 0,  6}, {0, 200, 0}, .Rectangle, 6, 1.2, 2.0)
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

scene_add_portal :: proc(scene: ^Scene, position: [3]f32, rotation: [3]f32, type: PortalType, partner: i32, half_width: f32, half_height: f32) {
	portal := Portal{
		position = {position[0], position[1], position[2], 0},
		rotation = {rotation[0], rotation[1], rotation[2], 0},
		type = type,
		partner = partner,
		half_width = half_width,
		half_height = half_height,
	}
	append(&scene.portals, portal)
}

scene_upload :: proc(scene: ^Scene) {
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, scene.ssbos[0])
	gl.NamedBufferData(
		scene.ssbos[0],
		len(scene.primitives) * size_of(Primitive),
		raw_data(scene.primitives[:]),
		gl.DYNAMIC_DRAW,
	)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, scene.ssbos[1])
	gl.NamedBufferData(
		scene.ssbos[1],
		len(scene.portals) * size_of(Portal),
		raw_data(scene.portals[:]),
		gl.DYNAMIC_DRAW,
	)
	// gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 2, scene.ssbos[2])
	// gl.NamedBufferData(
	// 	scene.ssbos[2],
	// 	len(scene.lights) * size_of(Light),
	// 	raw_data(scene.lights[:]),
	// 	gl.DYNAMIC_DRAW,
	// )
}

scene_flush :: proc(scene: ^Scene) {
	clear(&scene.primitives)
	clear(&scene.portals)
	// clear(&scene.lights)
}

scene_destroy :: proc(scene: ^Scene) {
	gl.DeleteBuffers(NUM_SSBOS, &scene.ssbos[0])
	delete(scene.primitives)
	delete(scene.portals)
	// delete(scene.lights)
}

scene_to_json :: proc(scene: ^Scene, allocator := context.allocator) -> string {
	data := SerializedScene {
		primitives = scene.primitives,
		portals = scene.portals,
	}

	json_str, err := json.marshal(data, {}, allocator)
	if err != nil {
		log.error("Failed to serialize scene to JSON: {}", err)
		return ""
	}
	return cast(string)json_str
}

scene_from_json :: proc(scene: ^Scene, json_str: string) {
	scene_flush(scene)

	data := SerializedScene{}
	err := json.unmarshal(transmute([]byte)json_str, &data)
	if err != nil {
		log.error("Failed to deserialize scene from JSON: {}", err)
		return
	}

	scene.primitives = data.primitives
	scene.portals = data.portals
}
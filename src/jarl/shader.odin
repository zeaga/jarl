package jarl

import "base:runtime"
import "core:log"
import "core:strings"
import gl "vendor:OpenGL"

Shader :: struct {
	program: u32,
	ray_max_steps: i32,
	ray_max_dist: f32,
	ray_wrap_dist: f32,
}

@(private="file")
_shader_compile_from_source :: proc(shader_type: u32, source: string) -> u32 {
	cstr := strings.clone_to_cstring(source, context.temp_allocator)
	length := i32(len(source))
	shader := gl.CreateShader(shader_type)
	gl.ShaderSource(shader, 1, &cstr, &length)
	gl.CompileShader(shader)

	success: i32
	gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
	if success == 1 {
		return shader
	}

	log_length: i32
	gl.GetShaderiv(shader, gl.INFO_LOG_LENGTH, &log_length)

	log_str := make([]u8, log_length, context.temp_allocator)
	gl.GetShaderInfoLog(shader, log_length, nil, &log_str[0])

	log.fatal("Shader compilation failed!", strings.string_from_ptr(&log_str[0], int(log_length)), sep = "\n")
	runtime.exit(1)
}

shader_create :: proc(shader: ^Shader, vertex_src: string, fragment_src: string) {
	vertex_shader := _shader_compile_from_source(gl.VERTEX_SHADER, vertex_src)
	fragment_shader := _shader_compile_from_source(gl.FRAGMENT_SHADER, fragment_src)

	program := gl.CreateProgram()
	gl.AttachShader(program, vertex_shader)
	gl.AttachShader(program, fragment_shader)
	gl.LinkProgram(program)
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	success: i32
	gl.GetProgramiv(program, gl.LINK_STATUS, &success)
	if success == 1 {
		shader.program = program
		shader.ray_max_dist = SHADER_DEFAULT_RAY_MAX_DIST
		shader.ray_max_steps = SHADER_DEFAULT_RAY_MAX_STEPS
		shader.ray_wrap_dist = SHADER_DEFAULT_RAY_WRAP_DIST
		return
	}

	log_length: i32
	gl.GetProgramiv(program, gl.INFO_LOG_LENGTH, &log_length)

	log_str := make([]u8, log_length, context.temp_allocator)
	gl.GetProgramInfoLog(program, log_length, nil, &log_str[0])

	log.fatal("Shader linking failed!", strings.string_from_ptr(&log_str[0], int(log_length)), sep = "\n")
	runtime.exit(1)
}

shader_set_uniforms :: proc(app: ^App, shader: ^Shader) {
	rot_mtx := camera_get_rotation_matrix(&app.camera)
	shader_set_uniform(&app.shader, "cam_position", &app.camera.position)
	shader_set_uniform(&app.shader, "cam_rotation", &rot_mtx)
	shader_set_uniform(&app.shader, "cam_tan_half_fov", camera_get_tan_half_fov(&app.camera))
	shader_set_uniform(&app.shader, "resolution", cast(f32)app.input.window_size.x, cast(f32)app.input.window_size.y)
	shader_set_uniform(&app.shader, "clear_color", &app.clear_color)
	// shader_set_uniform(&app.shader, "frame_time", delta_time)

	shader_set_uniform(&app.shader, "ray_max_steps", shader.ray_max_steps)
	shader_set_uniform(&app.shader, "ray_max_dist", shader.ray_max_dist)
	shader_set_uniform(&app.shader, "ray_wrap_dist", shader.ray_wrap_dist)
}

shader_bind :: proc(shader: ^Shader) {
	gl.UseProgram(shader.program)
}

shader_destroy :: proc(shader: ^Shader) {
	gl.DeleteProgram(shader.program)
}

shader_get_location :: proc(self: ^Shader, name: cstring) -> (loc: i32, ok: bool) {
	loc = gl.GetUniformLocation(self.program, name)
	ok = loc >= 0
	if !ok {
		log.warn("Uniform '{}' not found in shader", name)
	}
	return loc, ok
}

_shader_set_i32 :: proc(self: ^Shader, name: cstring, v: i32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.Uniform1i(loc, v)
	return true
}

_shader_set_f32 :: proc(self: ^Shader, name: cstring, v: f32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.Uniform1f(loc, v)
	return true
}

_shader_set_vec2 :: proc(self: ^Shader, name: cstring, x, y: f32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.Uniform2f(loc, x, y)
	return true
}

_shader_set_vec3 :: proc(self: ^Shader, name: cstring, x, y, z: f32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.Uniform3f(loc, x, y, z)
	return true
}

_shader_set_vec4 :: proc(self: ^Shader, name: cstring, x, y, z, w: f32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.Uniform4f(loc, x, y, z, w)
	return true
}

_shader_set_vec2v :: proc(self: ^Shader, name: cstring, v: ^[2]f32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.Uniform2fv(loc, 1, cast([^]f32)v)
	return true
}

_shader_set_vec3v :: proc(self: ^Shader, name: cstring, v: ^[3]f32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.Uniform3fv(loc, 1, cast([^]f32)v)
	return true
}

_shader_set_vec4v :: proc(self: ^Shader, name: cstring, v: ^[4]f32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.Uniform4fv(loc, 1, cast([^]f32)v)
	return true
}

_shader_set_mat3 :: proc(self: ^Shader, name: cstring, v: ^matrix[3, 3]f32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.UniformMatrix3fv(loc, 1, false, cast([^]f32)v)
	return true
}

_shader_set_mat4 :: proc(self: ^Shader, name: cstring, v: ^matrix[4, 4]f32) -> bool {
	loc, ok := shader_get_location(self, name)
	if !ok {return false}
	gl.UniformMatrix4fv(loc, 1, false, cast([^]f32)v)
	return true
}

shader_set_uniform :: proc { 
	_shader_set_i32,
	_shader_set_f32,
	_shader_set_vec2,
	_shader_set_vec3,
	_shader_set_vec4,
	_shader_set_vec2v,
	_shader_set_vec3v,
	_shader_set_vec4v,
	_shader_set_mat3,
	_shader_set_mat4,
}
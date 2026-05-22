package jarl

import "core:log"
import "core:strings"
import gl "vendor:OpenGL"

Shader :: struct {
	program: u32,
}

@(private="file")
_shader_compile_from_source :: proc(shader_type: u32, source: string) -> (shader: u32, ok: bool) {
	cstr := strings.clone_to_cstring(source, context.temp_allocator)
	length := i32(len(source))
	shader = gl.CreateShader(shader_type)
	gl.ShaderSource(shader, 1, &cstr, &length)
	gl.CompileShader(shader)

	success: i32
	gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
	if success == 1 {
		return shader, true
	}

	log_length: i32
	gl.GetShaderiv(shader, gl.INFO_LOG_LENGTH, &log_length)

	log_str := make([]u8, log_length, context.temp_allocator)
	gl.GetShaderInfoLog(shader, log_length, nil, &log_str[0])

	log.fatal("    Shader compilation failed:")
	log.fatal(&log_str[0])

	gl.DeleteShader(shader)
	return 0, false
}

shader_create :: proc(shader: ^Shader, vertex_src: string, fragment_src: string) -> (ok: bool) {
	vertex_shader, v_ok := _shader_compile_from_source(gl.VERTEX_SHADER, vertex_src)
	if !v_ok {
		return false
	}
	defer gl.DeleteShader(vertex_shader)

	fragment_shader, f_ok := _shader_compile_from_source(gl.FRAGMENT_SHADER, fragment_src)
	if !f_ok {
		return false
	}
	defer gl.DeleteShader(fragment_shader)

	program := gl.CreateProgram()
	gl.AttachShader(program, vertex_shader)
	gl.AttachShader(program, fragment_shader)
	gl.LinkProgram(program)

	success: i32
	gl.GetProgramiv(program, gl.LINK_STATUS, &success)
	if success == 1 {
		shader.program = program
		return true
	}

	log_length: i32
	gl.GetProgramiv(program, gl.INFO_LOG_LENGTH, &log_length)

	log_str := make([]u8, log_length, context.temp_allocator)
	gl.GetProgramInfoLog(program, log_length, nil, &log_str[0])

	log.fatal("    Shader linking failed:")
	log.fatal(&log_str[0])
	gl.DeleteProgram(program)
	return false
}

shader_bind :: proc(shader: ^Shader) {
	gl.UseProgram(shader.program)
}

shader_destroy :: proc(shader: ^Shader) {
	gl.DeleteProgram(shader.program)
}
#version 330 core

out vec2 uv;

void main() {
	vec2 verts[3] = vec2[](
		vec2(-1, -1),
		vec2( 3, -1),
		vec2(-1,  3)
	);
	gl_Position = vec4(verts[gl_VertexID], 0, 1);
	uv = verts[gl_VertexID];
}
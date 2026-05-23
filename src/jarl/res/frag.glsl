#version 430 core

const float EPSILON = 0.0001;

// uniform float time;
uniform vec3 cam_position;
uniform mat3 cam_rotation;
uniform float cam_tan_half_fov;
uniform vec2 resolution;
uniform vec4 clear_color;

uniform int ray_max_steps;
uniform float ray_max_dist;

in vec2 ndc;
out vec4 fragColor;

vec3 calc_ray_dir(vec2 ndc) {
	float aspect = resolution.x / resolution.y;
	vec3 view_dir = normalize(vec3(
		ndc.x * aspect * cam_tan_half_fov,
		ndc.y * cam_tan_half_fov,
		-1.0
	));
	return cam_rotation * view_dir;
}

// placeholder scene representation (just a sphere)
float map(vec3 p) {
	return length(p) - 1.0;
}

float raymarch(vec3 ray_pos, vec3 ray_dir) {
	float t = 0.0;
	for (int i = 0; i < ray_max_steps; i++) {
		float d = map(ray_pos + ray_dir * t);
		if (d < EPSILON) return t;
		t += d;
		if (t > ray_max_dist) return -1.0;
	}
	return -1.0;
}

vec3 calc_normal(vec3 p) {
	vec2 e = vec2(EPSILON, 0.0);
	return normalize(vec3(
		map(p + e.xyy) - map(p - e.xyy),
		map(p + e.yxy) - map(p - e.yxy),
		map(p + e.yyx) - map(p - e.yyx)
	));
}

void main() {
	vec3 ray_pos = cam_position;
	vec3 ray_dir = calc_ray_dir(ndc);
	
	float t = raymarch(ray_pos, ray_dir);
	if (t < 0.0) {
		fragColor = clear_color;
		return;
	}

	vec3 p = ray_pos + ray_dir * t;

	vec3 n = calc_normal(p);
	vec3 light = normalize(vec3(1, 2, 3));
	float diff = max(dot(n, light), 0.0);

	fragColor = vec4(vec3(diff), 1.0);
}
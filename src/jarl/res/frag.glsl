#version 450 core

const float EPSILON = 0.0001;

// uniform float time;
uniform vec3 cam_position;
uniform mat3 cam_rotation;
uniform float cam_tan_half_fov;
uniform vec2 resolution;
uniform vec4 clear_color;
uniform float frame_time;

uniform int ray_max_steps;
uniform float ray_max_dist;

uniform int primitive_count;

in vec2 ndc;
out vec4 fragColor;

struct Primitive {
	vec4 position;
	vec4 color;
	int type;
	float param0;
	float param1;
	float param2;
};

struct MapResult {
	float dist;
	int id;
};

layout(std430, binding = 0) readonly buffer PrimitiveBuffer {
	Primitive prims[];
};

vec3 calc_ray_dir(vec2 ndc) {
	float aspect = resolution.x / resolution.y;
	vec3 view_dir = normalize(vec3(
		ndc.x * aspect * cam_tan_half_fov,
		ndc.y * cam_tan_half_fov,
		-1.0
	));
	return cam_rotation * view_dir;
}

float sdf_sphere(vec3 p, vec3 center, float radius) {
	return length(p - center) - radius;
}

float sdf_box(vec3 p, vec3 center, vec3 size) {
	vec3 d = abs(p - center) - size;
	return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

MapResult map(vec3 p) {
	MapResult result;
	result.dist = ray_max_dist;
	result.id = -1;
	for (int i = 0; i < primitive_count; i++) {
		if (prims[i].type == 0) { // sphere
			float d = sdf_sphere(p, prims[i].position.xyz, prims[i].param0);
			if (d < result.dist) {
				result.dist = d;
				result.id = i;
			}
		} else if (prims[i].type == 1) { // box
			float d = sdf_box(p, prims[i].position.xyz, vec3(prims[i].param0, prims[i].param1, prims[i].param2));
			if (d < result.dist) {
				result.dist = d;
				result.id = i;
			}
		}
	}
	return result;
}

MapResult raymarch(vec3 ray_pos, vec3 ray_dir) {
	float t = 0.0;
	for (int i = 0; i < ray_max_steps; i++) {
		MapResult comp = map(ray_pos + ray_dir * t);
		if (comp.dist < EPSILON) return MapResult(t, comp.id);
		t += comp.dist;
		if (t > ray_max_dist) return MapResult(-1.0, -1);
	}
	return MapResult(-1.0, -1);
}

void main() {
	vec3 ray_pos = cam_position;
	vec3 ray_dir = calc_ray_dir(ndc);

	MapResult result = raymarch(ray_pos, ray_dir);
	if (result.id < 0) {
		fragColor = clear_color;
		return;
	}

	vec3 p = ray_pos + ray_dir * result.dist;

	vec3 n = calc_normal(p);
	vec3 light = normalize(vec3(1, 2, 3));
	float diff = max(dot(n, light), 0.0);

	fragColor = vec4(prims[result.id].color.rgb * diff, 1.0);
}
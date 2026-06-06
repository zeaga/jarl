const float EPSILON = 0.0001;
const float PORTAL_THICKNESS = 0.05;

in vec2 ndc;
out vec4 fragColor;

// uniform float time;
uniform vec3 cam_position;
uniform mat3 cam_rotation;
uniform float cam_tan_half_fov;
uniform vec2 resolution;
uniform vec4 clear_color;

uniform int ray_max_steps;
uniform float ray_max_dist;
uniform int ray_max_teleports;

uniform bool debug_mode;

struct Primitive {
	vec4 position;
	vec4 color;
	int type;
	float param0;
	float param1;
	float param2;
};
layout(std430, binding = 0) readonly buffer PrimitiveBuffer {
	Primitive prims[];
};
uniform int primitive_count;

struct Portal {
	vec4 position;
	vec4 rotation;
	int type;
	int partner_index;
	float half_width;
	float half_height;
};
layout(std430, binding = 1) readonly buffer PortalBuffer {
	Portal portals[];
};
uniform int portal_count;

struct MapResult {
	float dist;
	int id;
	vec3 pos;
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
	result.pos = p;
	result.dist = ray_max_dist;
	result.id = -1;
	for (int i = 0; i < primitive_count; i++) {
		if (prims[i].type == 0) { // sphere
			float d = sdf_sphere(p, prims[i].position.xyz, prims[i].param0);
			if (d < result.dist) { result.dist = d; result.id = i; }
		} else if (prims[i].type == 1) { // box
			float d = sdf_box(p, prims[i].position.xyz, vec3(prims[i].param0, prims[i].param1, prims[i].param2));
			if (d < result.dist) { result.dist = d; result.id = i; }
		}
	}
	return result;
}

vec3 calc_normal(vec3 p) {
	vec2 e = vec2(EPSILON, 0.0);
	return normalize(vec3(
		map(p + e.xyy).dist - map(p - e.xyy).dist,
		map(p + e.yxy).dist - map(p - e.yxy).dist,
		map(p + e.yyx).dist - map(p - e.yyx).dist
	));
}

mat3 euler_to_mat3(vec3 e) {
	vec3 r = radians(e);
	vec3 cosv = cos(r);
	vec3 sinv = sin(r);
	mat3 Ry = mat3(cosv.y, 0.0, -sinv.y, 0.0, 1.0, 0.0, sinv.y, 0.0, cosv.y);
	mat3 Rx = mat3(1.0, 0.0, 0.0, 0.0, cosv.x, sinv.x, 0.0, -sinv.x, cosv.x);
	mat3 Rz = mat3(cosv.z, sinv.z, 0.0, -sinv.z, cosv.z, 0.0, 0.0, 0.0, 1.0);
	return Ry * Rx * Rz;
}

float ray_portal_outline(vec3 ray_origin, vec3 ray_direction, int j) {
	vec3 center = portals[j].position.xyz;
	mat3 rot = euler_to_mat3(portals[j].rotation.xyz);
	vec3 normal = rot * vec3(0.0, 0.0, 1.0);
	if (dot(normal, ray_direction) >= 0.0) return -1.0; // back face
	vec3 tangent = rot * vec3(1.0, 0.0, 0.0);
	float hw = portals[j].half_width;
	float hh = portals[j].half_height;

	float denom = dot(normal, ray_direction);
	if (abs(denom) < EPSILON * 0.1) return -1.0;
	float t = dot(center - ray_origin, normal) / denom;
	if (t < EPSILON * 0.1) return -1.0;

	vec3 bitan = cross(normal, tangent);
	float u = dot((ray_origin + ray_direction * t) - center, tangent);
	float v = dot((ray_origin + ray_direction * t) - center, bitan);

	if (portals[j].type == 0) {
		float outer = (u*u)/(hw*hw) + (v*v)/(hh*hh);
		float ihw = hw - PORTAL_THICKNESS, ihh = hh - PORTAL_THICKNESS;
		float inner = (u*u)/(ihw*ihw) + (v*v)/(ihh*ihh);
		return (outer > 1.0 || inner < 1.0) ? t : -1.0;
	} else {
		bool inside = abs(u) <= hw && abs(v) <= hh;
		bool inner = abs(u) <= (hw - PORTAL_THICKNESS) && abs(v) <= (hh - PORTAL_THICKNESS);
		return (inside && !inner) ? t : -1.0;
	}
}

float ray_portal_intersect(vec3 ray_origin, vec3 ray_direction, int j) {
	vec3 center = portals[j].position.xyz;
	mat3 rot = euler_to_mat3(portals[j].rotation.xyz);
	vec3 normal = rot * vec3(0.0, 0.0, 1.0);
	vec3 tangent = rot * vec3(1.0, 0.0, 0.0);
	float hw = portals[j].half_width;
	float hh = portals[j].half_height;

	float denom = dot(normal, ray_direction);
	if (abs(denom) < EPSILON) return -1.0;
	float t = dot(center - ray_origin, normal) / denom;
	if (t < EPSILON) return -1.0;

	vec3 hit = (ray_origin + ray_direction * t) - center;
	vec3 bitan = cross(normal, tangent);
	float u = dot(hit, tangent);
	float v = dot(hit, bitan);

	if (portals[j].type == 0) {
		return ((u * u) / (hw * hw) + (v * v) / (hh * hh)) <= 1.0 ? t : -1.0;
	} else {
		return (abs(u) <= hw && abs(v) <= hh) ? t : -1.0;
	}
}

mat3 portal_rotation(vec3 nA, vec3 tA, vec3 nB, vec3 tB) {
	vec3 bA = cross(nA, tA);
	vec3 bB = cross(nB, tB);
	mat3 MA = mat3(-nA, tA, bA);
	mat3 MB = mat3( nB,-tB, bB);
	return MB * transpose(MA);
}

MapResult raymarch(vec3 ray_pos, vec3 ray_dir) {
	float total_dist = 0.0;
	int teleports = 0;

	for (int i = 0; i < ray_max_steps; i++) {
		MapResult r = map(ray_pos);
		if (r.dist < EPSILON) return MapResult(total_dist, r.id, ray_pos);
		if (total_dist > ray_max_dist) break;

		float step_dist = r.dist;
		bool teleported = false;

		// Check portal outlines from the current (possibly teleported) ray position
		if (debug_mode) {
			for (int j = 0; j < portal_count; j++) {
				float ot = ray_portal_outline(ray_pos, ray_dir, j);
				if (ot > 0.0 && ot < step_dist) {
					return MapResult(total_dist + ot, -2, ray_pos + ray_dir * ot);
				}
			}
		}

		if (teleports < ray_max_teleports) {
			for (int j = 0; j < portal_count; j++) {
				mat3 aRot = euler_to_mat3(portals[j].rotation.xyz);
				vec3 aNormal = aRot * vec3(0.0, 0.0, 1.0);
				if (dot(aNormal, ray_dir) >= 0.0) continue; // back face
				vec3 aTangent = aRot * vec3(1.0, 0.0, 0.0);

				float pt = ray_portal_intersect(ray_pos, ray_dir, j);
				if (pt > 0.0 && pt < step_dist) {
					int partner = portals[j].partner_index;
					if (partner < 0 || partner >= portal_count || partner == j) continue;
					mat3 bRot = euler_to_mat3(portals[partner].rotation.xyz);
					vec3 bNormal = bRot * vec3(0.0, 0.0, 1.0);
					vec3 bTangent = bRot * vec3(1.0, 0.0, 0.0);
					mat3 rot = portal_rotation(
						aNormal, aTangent,
						bNormal, bTangent
					);

					ray_pos = portals[partner].position.xyz
							+ rot * ((ray_pos + ray_dir * pt) - portals[j].position.xyz);
					ray_dir = rot * ray_dir;
					total_dist += pt;
					teleports++;
					teleported = true;
					break;
				}
			}
		}

		if (!teleported) {
			ray_pos += ray_dir * step_dist;
			total_dist += step_dist;
		}
	}

	return MapResult(-1.0, -1, vec3(0.0));
}

void main() {
	vec3 ray_dir = calc_ray_dir(ndc);
	vec3 color = clear_color.rgb;

	MapResult result = raymarch(cam_position, ray_dir);

	if (result.id == -2) {
		color = vec3(1.0, 0.8, 0.0);
	} else if (result.id >= 0) {
		vec3 p = result.pos;
		color = prims[result.id].color.rgb;

		vec3 n = calc_normal(p);
		vec3 light = normalize(vec3(1, 2, 3));
		color *= max(dot(n, light) + 0.3, 0.3);
	}

	fragColor = vec4(color, 1.0);
}
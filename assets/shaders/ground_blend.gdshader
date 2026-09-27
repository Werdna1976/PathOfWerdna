// Blends two ground materials (albedo + normal each) on a flat ground with a
// noisy edge. The mask comes from one of:
//   0: a straight gradient (e.g. dry sand -> wet sand toward the sea)
//   1: a circle (e.g. packed earth outside, cobbles around a campfire)
//   2: a painted mask texture stretched over mask_rect (white = material B)
// Textures are projected top-down in world space, so any flat mesh works.
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D albedo_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint_a : source_color = vec4(1.0);
uniform float roughness_a = 0.95;
uniform float uv_scale_a = 0.22;
uniform sampler2D albedo_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint_b : source_color = vec4(1.0);
uniform float roughness_b = 0.5;
uniform float uv_scale_b = 0.22;
uniform float normal_strength = 1.0;

uniform int mask_mode : hint_range(0, 2) = 0;
// Mode 0: B starts blend_start metres from origin along direction.
uniform vec2 origin = vec2(0.0, 0.0);
uniform vec2 direction = vec2(0.0, -1.0);
uniform float blend_start = 0.0;
// Mode 1: B inside this radius around origin.
uniform float radius = 6.0;
// Mode 2: painted mask over (x, z, width, depth) in world units.
uniform sampler2D mask_texture : hint_default_black, filter_linear;
uniform vec4 mask_rect = vec4(-20.0, -20.0, 40.0, 40.0);
uniform float blend_width = 3.0;
uniform sampler2D edge_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float noise_scale = 0.07;
// Metres the edge wanders.
uniform float noise_strength = 2.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = world_pos.xz;
	float n = (texture(edge_noise, xz * noise_scale).r - 0.5) * noise_strength;
	float m;
	if (mask_mode == 0) {
		float dist = dot(xz - origin, normalize(direction)) - blend_start;
		m = smoothstep(-blend_width * 0.5, blend_width * 0.5, dist + n);
	} else if (mask_mode == 1) {
		float dist = radius - length(xz - origin);
		m = smoothstep(-blend_width * 0.5, blend_width * 0.5, dist + n);
	} else {
		vec2 muv = (xz - mask_rect.xy) / mask_rect.zw;
		float painted = texture(mask_texture, muv).r;
		m = smoothstep(0.5 - 0.25, 0.5 + 0.25, painted + n * 0.1);
	}
	vec3 a = texture(albedo_a, xz * uv_scale_a).rgb * tint_a.rgb;
	vec3 b = texture(albedo_b, xz * uv_scale_b).rgb * tint_b.rgb;
	vec3 na = texture(normal_a, xz * uv_scale_a).rgb;
	vec3 nb = texture(normal_b, xz * uv_scale_b).rgb;
	ALBEDO = mix(a, b, m) * COLOR.rgb;
	NORMAL_MAP = mix(na, nb, m);
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(roughness_a, roughness_b, m);
}

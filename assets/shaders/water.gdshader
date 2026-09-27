// Animated water for the world kit: gentle vertex swell, two scrolling normal
// maps, colour that deepens with the water's depth, and foam that laps against
// anything the water touches (shore, rocks, wrecks).
// Depth needs opaque geometry under the surface (a sloping seabed works best).
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.07, 0.16, 0.18, 0.55);
uniform vec4 deep_color : source_color = vec4(0.008, 0.025, 0.05, 0.96);
uniform vec4 foam_color : source_color = vec4(0.62, 0.68, 0.72, 1.0);
// Metres of water before the colour reaches deep_color.
uniform float depth_fade = 3.0;
// Metres of shallow water that get foam.
uniform float foam_width = 0.9;
// How fast foam bands roll in toward the shore.
uniform float foam_speed = 0.35;
uniform float wave_height = 0.06;
uniform float wave_speed = 0.6;
uniform vec2 wave_dir = vec2(0.2, 1.0);
uniform float uv_scale = 0.06;
uniform float normal_strength = 0.5;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 d = normalize(wave_dir);
	float t = TIME * wave_speed;
	float swell = sin(dot(world_pos.xz, d) * 0.55 + t * 2.0) * 0.6
		+ sin(dot(world_pos.xz, vec2(-d.y, d.x)) * 1.1 + t * 2.9) * 0.4;
	VERTEX.y += swell * wave_height;
	world_pos.y += swell * wave_height;
}

void fragment() {
	vec2 d = normalize(wave_dir);
	vec2 uv = world_pos.xz * uv_scale;
	vec3 n1 = texture(normal_a, uv + d * TIME * 0.018).rgb;
	vec3 n2 = texture(normal_b, uv * 1.9 - vec2(d.y, -d.x) * TIME * 0.013).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = normal_strength;

	// Linear depth of whatever is behind the water (reversed-Z, Godot 4.3+).
	float raw = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	behind.xyz /= behind.w;
	float water_depth = max(VERTEX.z - behind.z, 0.0);

	vec4 body = mix(shallow_color, deep_color, clamp(water_depth / depth_fade, 0.0, 1.0));
	float noise = texture(foam_noise, uv * 4.0 + d * TIME * 0.03).r;
	float edge = 1.0 - smoothstep(0.0, foam_width, water_depth);
	float bands = 0.5 + 0.5 * sin(water_depth * 7.0 - TIME * foam_speed * 7.0);
	float foam = smoothstep(0.45, 0.75, edge * (0.55 + 0.45 * bands) * (0.6 + noise * 0.8));
	// A thin solid line right where the water meets the ground.
	foam = max(foam, smoothstep(0.12, 0.0, water_depth) * 0.8);

	ALBEDO = mix(body.rgb, foam_color.rgb, foam);
	ALPHA = mix(body.a, foam_color.a, foam);
	ROUGHNESS = mix(0.06, 0.85, foam);
	SPECULAR = 0.7;
}

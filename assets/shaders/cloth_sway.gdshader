// Cloth ripple for banners and flags. A subdivided quad is pinned along one
// edge (UV.y = 0 for a hanging banner, UV.x = 0 for a flag on a pole) and
// ripples along its normal, more toward the free edge.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Per instance, so every banner can have its own colour with one material.
instance uniform vec4 albedo : source_color = vec4(0.45, 0.08, 0.06, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
// Optional emblem / pattern mask multiplied over the cloth (white = none).
uniform sampler2D emblem_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 emblem_color : source_color = vec4(0.75, 0.6, 0.3, 1.0);
uniform float roughness = 1.0;
// false = hanging banner (pinned at the top), true = flag (pinned at the pole side).
uniform bool pinned_left = false;
uniform float ripple_amount = 0.08;
uniform float ripple_speed = 2.0;
uniform float ripple_frequency = 6.0;

void vertex() {
	float free_edge = pinned_left ? UV.x : UV.y;
	float along = pinned_left ? UV.x : UV.y;
	float phase = dot(MODEL_MATRIX[3].xz, vec2(0.7, 0.3));
	float wave = sin(along * ripple_frequency - TIME * ripple_speed + phase)
		+ 0.4 * sin((pinned_left ? UV.y : UV.x) * 5.0 + TIME * ripple_speed * 0.7 + phase);
	VERTEX += NORMAL * wave * ripple_amount * free_edge;
}

void fragment() {
	vec3 cloth = albedo.rgb * texture(albedo_texture, UV * 2.0).rgb;
	float emblem = 1.0 - texture(emblem_texture, UV).r;
	ALBEDO = mix(cloth, emblem_color.rgb, emblem) * COLOR.rgb;
	ROUGHNESS = roughness;
	BACKLIGHT = ALBEDO * 0.35;
}

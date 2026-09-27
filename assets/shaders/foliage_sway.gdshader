// Wind sway for foliage (trees, bushes, grass clumps). Vertices bend along the
// wind in world space, more the higher they are above the mesh origin, with
// per-plant phase and slow gusts. Vertex colour tints the albedo, so one
// material can serve many plants.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float roughness = 0.9;
// Pixels with alpha below this are cut out (for card-style foliage).
uniform float alpha_scissor = 0.4;
// Sway in metres at sway_height.
uniform float sway_strength = 0.08;
uniform float sway_speed = 1.3;
// Height above the origin that gets the full sway.
uniform float sway_height = 1.5;
uniform vec2 wind_dir = vec2(1.0, 0.35);
// Light passing through thin leaves.
uniform float translucency = 0.25;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = clamp((wp.y - origin.y) / sway_height, 0.0, 1.0);
	weight *= weight;
	float phase = dot(origin.xz, vec2(0.61, 0.43)) + dot(wp.xz, vec2(0.3, 0.2));
	float gust = 0.5 + 0.5 * sin(TIME * sway_speed * 0.31 + dot(origin.xz, normalize(wind_dir)) * 0.08);
	float s = sin(TIME * sway_speed + phase) * 0.55 + sin(TIME * sway_speed * 2.3 + phase * 1.7) * 0.2 + gust * 0.5;
	vec2 dir = normalize(wind_dir);
	vec3 world_offset = vec3(dir.x, -0.15 * abs(s), dir.y) * s * sway_strength * weight;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_offset;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex.rgb * COLOR.rgb;
	ALPHA = tex.a * albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = roughness;
	BACKLIGHT = ALBEDO * translucency;
}

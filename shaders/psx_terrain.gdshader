shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Chão da mata estilo PS1: mistura chão de folhas e trilha de terra
// pela cor do vértice (vermelho = trilha). Paredes íngremes (o barranco)
// usam projeção lateral pra textura não esticar.

uniform sampler2D floor_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 floor_tint : source_color = vec4(1.0);
uniform vec4 path_tint : source_color = vec4(1.0);
uniform vec4 cliff_tint : source_color = vec4(0.75, 0.7, 0.65, 1.0);
uniform float tiles_per_meter = 0.35;
uniform vec2 snap_resolution = vec2(480.0, 270.0);
uniform bool vertex_snap = true;

varying vec3 world_pos;
varying vec3 world_normal;
varying float path_mask;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	path_mask = COLOR.r;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Só "treme" na câmera (projeção em perspectiva); sombras do sol ficam lisas.
	bool perspective = PROJECTION_MATRIX[3][3] == 0.0;
	if (vertex_snap && perspective && clip.w > 0.0001) {
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * snap_resolution + 0.5) / snap_resolution;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 n = abs(world_normal);
	// Amostra tudo fora de "if" (derivadas de mipmap ficam certas em toda GPU).
	vec2 uv_top = world_pos.xz * tiles_per_meter;
	vec3 ground = texture(floor_tex, uv_top).rgb * floor_tint.rgb;
	vec3 path = texture(path_tex, uv_top * 1.3).rgb * path_tint.rgb;
	// Borda da trilha "quebrada" com ruído da própria textura.
	float m = smoothstep(0.35, 0.65, path_mask + (texture(floor_tex, uv_top * 2.7).r - 0.2) * 0.6);
	vec3 top = mix(ground, path, m);
	vec2 uv_x = world_pos.zy * tiles_per_meter * vec2(1.0, -1.0);
	vec2 uv_z = world_pos.xy * tiles_per_meter * vec2(1.0, -1.0);
	vec3 side_x = texture(path_tex, uv_x).rgb;
	vec3 side_z = texture(path_tex, uv_z).rgb;
	vec3 side = mix(side_z, side_x, step(n.z, n.x)) * cliff_tint.rgb;
	ALBEDO = mix(side, top, step(0.55, n.y));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Material de mundo estilo PS1:
// - textura com filtro "nearest" (pixelada)
// - UV triplanar em coordenadas do mundo (a textura não estica em paredes grandes)
// - vértices tremendo levemente (snap de vértice clássico do PS1)

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// Quantas repetições da textura por metro.
uniform float tiles_per_meter = 0.5;
// Resolução do snap de vértice (menor = mais tremido).
uniform vec2 snap_resolution = vec2(320.0, 180.0);
uniform bool vertex_snap = true;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (vertex_snap) {
		vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * snap_resolution + 0.5) / snap_resolution;
		clip.xy = ndc * clip.w;
		POSITION = clip;
	}
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y > n.x && n.y > n.z) {
		uv = world_pos.xz;
	} else if (n.x > n.z) {
		uv = vec2(world_pos.z, -world_pos.y);
	} else {
		uv = vec2(world_pos.x, -world_pos.y);
	}
	vec3 tex = texture(albedo_tex, uv * tiles_per_meter).rgb;
	ALBEDO = tex * tint.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

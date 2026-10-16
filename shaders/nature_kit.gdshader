shader_type spatial;
// Vegetação do mapa (kit temperate_forest_v1, NatureDecorManager/NatureKitCatalog.map_material). Reproduz EXATAMENTE o
// StandardMaterial3D que o mapa usava (atlas × cor por instância, recorte de alfa 0,5, filtro nearest com mipmaps,
// rugosidade 0,92) e acrescenta a neve cosmética do clima (WeatherController): as faces viradas para cima das copas e
// arbustos ficam levemente esbranquiçadas enquanto há neve assentada. Sem neve (weather_snow_cover = 0) o resultado é o
// do material antigo.
//
// COLOR = cor por instância do MultiMesh: tintura do bioma (NatureComposer) e névoa de guerra (NatureDecorManager:
// alfa 0 = oculto, sépia = explorado). O alfa dela entra no recorte, então a névoa continua funcionando igual.
// ALPHA é MULTIPLICADO, nunca sobrescrito (igual ao StandardMaterial3D): o Godot inicia ALPHA com
// 1 - GeometryInstance3D.transparency, que é como o foco visual (VisualFocusSystem) deixa a vegetação do tile da
// unidade translúcida num overlay sem tocar no material compartilhado.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;

global uniform float weather_snow_cover;
const vec3 SNOW_TINT = vec3(0.9, 0.93, 0.97);
// Levemente esbranquiçado (mesma ideia do terreno, um pouco mais visível nas copas que são pequenas na tela). Com 0,55
// as copas ficavam quase brancas na conferência visual; 0,35 mantém o verde lendo como árvore.
const float SNOW_MAX_WHITEN = 0.35;

void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	vec3 albedo = texel.rgb * COLOR.rgb;
	if (weather_snow_cover > 0.0) {
		vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float up = smoothstep(0.5, 0.8, world_normal.y);
		// A neve segue o brilho da instância: tile explorado (sépia escura) não ganha neve "acesa".
		float instance_light = clamp(dot(COLOR.rgb, vec3(0.3333)), 0.0, 1.0);
		albedo = mix(albedo, SNOW_TINT * instance_light, weather_snow_cover * up * SNOW_MAX_WHITEN);
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	ALPHA *= texel.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

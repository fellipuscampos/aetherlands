shader_type spatial;
// Prop que BRILHA (WorldGlow.prop_material; hoje os recursos de mapa Gemas e Nódulo Arcano, ResourcePropsManager).
// Reproduz o StandardMaterial3D que esses props usavam (atlas × cor por instância, recorte de alfa 0,5, filtro nearest
// com mipmaps, rugosidade/metal/especular do material do GLB) e acrescenta a EMISSÃO do brilho:
//  - o que brilha é a parte COLORIDA do atlas (croma acima de glow_chroma_range): os cristais e os veios pintados
//    acendem na própria cor; a rocha neutra da base não. Sem textura de emissão por asset;
//  - a intensidade segue a escuridão da cena (parâmetro global world_darkness, do DayNightController): ao meio-dia só
//    glow_day_strength da energia, crescendo até a energia cheia à noite (e um pouco com o tempo fechado);
//  - por instância (glow_per_instance): INSTANCE_CUSTOM.r do MultiMesh liga/desliga o brilho — a névoa de guerra apaga
//    o de um tile que não está visível agora, igual à luz dele (WorldGlow).
//
// COLOR = cor por instância do MultiMesh (névoa de guerra: alfa 0 = oculto, sépia = explorado). ALPHA é MULTIPLICADO,
// nunca sobrescrito: o Godot inicia ALPHA com 1 - GeometryInstance3D.transparency, que é como o foco visual
// (VisualFocusSystem) deixa o prop do tile da unidade translúcido num overlay sem tocar no material compartilhado.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// Energia da emissão com a cena totalmente escura (multiplica a cor do próprio texel).
uniform float glow_energy = 1.5;
// Fração da energia que sobra em pleno dia.
uniform float glow_day_strength : hint_range(0.0, 1.0) = 0.2;
// Croma linear (maior canal − menor canal) em que o texel começa / termina de contar como "parte que brilha".
uniform vec2 glow_chroma_range = vec2(0.09, 0.14);
uniform bool glow_per_instance = false;

global uniform float world_darkness;

varying float instance_glow;

void vertex() {
	instance_glow = glow_per_instance ? INSTANCE_CUSTOM.r : 1.0;
}

void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	ALBEDO = texel.rgb * albedo.rgb * COLOR.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	float chroma = max(texel.r, max(texel.g, texel.b)) - min(texel.r, min(texel.g, texel.b));
	float glowing = smoothstep(glow_chroma_range.x, glow_chroma_range.y, chroma);
	EMISSION = texel.rgb * glowing * glow_energy * mix(glow_day_strength, 1.0, clamp(world_darkness, 0.0, 1.0)) * instance_glow;
	ALPHA *= texel.a * albedo.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

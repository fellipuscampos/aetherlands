class_name GlowProfiles
extends RefCounted

## Perfis de BRILHO do mundo (dado puro; quem aplica é WorldGlow). Um perfil descreve como uma coisa brilha: a luz que
## ela joga no mapa e a emissão do próprio modelo. Para dar brilho a outra coisa no futuro (prédio, unidade, bioma),
## acrescente um perfil aqui e peça a luz/o material a WorldGlow — nada de luz ou emissão montada à mão no chamador.
##
## Campos:
##  - light_color / light_energy / light_range: OmniLight3D (sem sombra). `light_energy` é a energia com a cena
##    totalmente escura; `light_range` em unidades de mundo (hex de raio 1: o centro do vizinho fica a ~1,73).
##  - light_height: altura da luz acima do ponto de apoio (o chão do tile).
##  - light_attenuation: queda da luz com a distância (OmniLight3D.omni_attenuation; maior = mais concentrada).
##  - emission_energy: energia da emissão do modelo com a cena totalmente escura (shaders/glow_prop.gdshader).
##  - day_strength: fração da luz e da emissão que sobra em pleno dia (0 = some de dia, 1 = igual de dia e de noite).
##    Pedido do usuário: "se tiver claro não dá pra ver muito o brilho, mas conforme a luminosidade diminuir, fica mais
##    evidente".
##  - emission_day (opcional): emissão em pleno dia de um material que JÁ tem mapa de emissão próprio
##    (WorldGlow.track_emission — os núcleos das Grandes Manifestações). 1,0 = de dia o modelo fica exatamente como
##    foi aprovado; `emission_energy` passa a ser o fator à noite. Sem a chave, vale emission_energy × day_strength.
const AMETHYST := &"amethyst"
const ARCANE := &"arcane"
## NÚCLEOS DAS GRANDES MANIFESTAÇÕES (2026-10-13 — "pegue o mesmo efeito de iluminação usado nos cristais in game, e
## coloque nos núcleos das grandes manifestações"): a cor de cada luz é a do mapa de emissão do próprio modelo. O
## núcleo fica a ~1,7–2,4 m do chão (os cristais, a ~0,5 m), por isso o alcance maior: a luz precisa chegar ao terreno
## e passar um pouco do próprio tile. `light_height` é 0: a luz fica presa ao osso do núcleo (WorldGlow.attach_light).
const SERAPH_CORE := &"seraph_core"
const ARCHDEMON_CORE := &"archdemon_core"
const LICH_FOCUS := &"lich_focus"
const NATURE_CORE := &"nature_core"
const VEIL_CORE := &"veil_core"
const PRIMORDIAL_CORE := &"primordial_core"

const PROFILES := {
	&"casting_sacred": {"light_color":Color("f4d99e"),"light_energy":3.2,"light_range":3.8,"light_height":0.0,"light_attenuation":1.2,"emission_energy":2.5,"day_strength":.35},
	&"casting_infernal": {"light_color":Color("ff8b48"),"light_energy":3.4,"light_range":3.8,"light_height":0.0,"light_attenuation":1.2,"emission_energy":2.5,"day_strength":.35},
	&"casting_necromancy": {"light_color":Color("a3d0ad"),"light_energy":2.9,"light_range":3.5,"light_height":0.0,"light_attenuation":1.2,"emission_energy":2.5,"day_strength":.35},
	&"casting_druidism": {"light_color":Color("b1d490"),"light_energy":2.9,"light_range":3.5,"light_height":0.0,"light_attenuation":1.2,"emission_energy":2.5,"day_strength":.35},
	&"casting_arcanism": {"light_color":Color("b5a3ed"),"light_energy":3.1,"light_range":3.7,"light_height":0.0,"light_attenuation":1.2,"emission_energy":2.5,"day_strength":.35},
	&"casting_elementalism": {"light_color":Color("a6cfec"),"light_energy":3.1,"light_range":3.7,"light_height":0.0,"light_attenuation":1.2,"emission_energy":2.5,"day_strength":.35},
	AMETHYST: {
		"light_color": Color(0.74, 0.42, 1.0), "light_energy": 1.5, "light_range": 2.6, "light_height": 0.45,
		"light_attenuation": 1.3, "emission_energy": 1.6, "day_strength": 0.15,
	},
	ARCANE: {
		"light_color": Color(0.35, 0.92, 1.0), "light_energy": 1.9, "light_range": 3.0, "light_height": 0.55,
		"light_attenuation": 1.2, "emission_energy": 2.0, "day_strength": 0.2,
	},
	SERAPH_CORE: {
		"light_color": Color(1.0, 0.9, 0.62), "light_energy": 2.3, "light_range": 4.4, "light_height": 0.0,
		"light_attenuation": 1.15, "emission_energy": 2.0, "emission_day": 1.0, "day_strength": 0.2,
	},
	ARCHDEMON_CORE: {
		"light_color": Color(1.0, 0.3, 0.18), "light_energy": 2.4, "light_range": 4.6, "light_height": 0.0,
		"light_attenuation": 1.15, "emission_energy": 2.2, "emission_day": 1.0, "day_strength": 0.2,
	},
	LICH_FOCUS: {
		"light_color": Color(0.4, 1.0, 0.66), "light_energy": 2.1, "light_range": 4.2, "light_height": 0.0,
		"light_attenuation": 1.2, "emission_energy": 2.2, "emission_day": 1.0, "day_strength": 0.2,
	},
	NATURE_CORE: {
		"light_color": Color(0.58, 1.0, 0.4), "light_energy": 2.2, "light_range": 4.6, "light_height": 0.0,
		"light_attenuation": 1.15, "emission_energy": 2.0, "emission_day": 1.0, "day_strength": 0.2,
	},
	VEIL_CORE: {
		"light_color": Color(0.72, 0.64, 1.0), "light_energy": 2.2, "light_range": 4.4, "light_height": 0.0,
		"light_attenuation": 1.15, "emission_energy": 1.8, "emission_day": 1.0, "day_strength": 0.2,
	},
	PRIMORDIAL_CORE: {
		"light_color": Color(0.4, 0.88, 1.0), "light_energy": 2.3, "light_range": 4.4, "light_height": 0.0,
		"light_attenuation": 1.15, "emission_energy": 2.0, "emission_day": 1.0, "day_strength": 0.2,
	},
}

static func has_profile(id: StringName) -> bool:
	return PROFILES.has(id)

static func profile(id: StringName) -> Dictionary:
	return PROFILES.get(id, {})

static func ids() -> Array:
	return PROFILES.keys()

## Quanto do brilho aparece (0..1) para a escuridão `darkness` da cena (0 = dia, 1 = noite profunda).
static func strength(id: StringName, darkness: float) -> float:
	return lerpf(float(profile(id).get("day_strength", 0.0)), 1.0, clampf(darkness, 0.0, 1.0))

## Fator da emissão de um material com mapa de emissão próprio (WorldGlow.track_emission) para a escuridão `darkness`:
## de `emission_day` (ou emission_energy × day_strength) em pleno dia até `emission_energy` na noite profunda.
static func emission_factor(id: StringName, darkness: float) -> float:
	var data := profile(id)
	var night := float(data.get("emission_energy", 1.0))
	var day := float(data.get("emission_day", night * float(data.get("day_strength", 0.0))))
	return lerpf(day, night, clampf(darkness, 0.0, 1.0))

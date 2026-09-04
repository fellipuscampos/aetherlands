class_name SpellDatabase
extends RefCounted

## Efeitos de gameplay pros feiticos/rituais que TechDatabase.gd ja nomeia
## via TechData.unlocks_spell — pedido do usuario: "permita que o jogador
## selecione o feitico... e aplique o efeito no mapa". So os dois feiticos
## pedidos explicitamente tem efeito cadastrado aqui por enquanto:
##
## - "Lança de Arcana" (invocacao_espiritos): dano direto numa unidade
##   inimiga (ou monstro neutro) atualmente visivel.
## - "Reanimar" (necromancia_pratica): restaura uma fracao do HP maximo de
##   uma unidade PROPRIA.
##
## "Ruína Ígnea" (cataclismo_elemental) e "Metamorfose de Gaia"
## (transcendencia_florestal) — roadmap de gameplay Fase 5 ("fechar os
## feiticos fantasmas"): as duas tecnologias de Tier 3 ja existiam em
## TechDatabase (com unlocks_spell/terrain_transform preenchidos como
## dados) mas ficaram sem SpellData por uma rodada inteira, so prometidas.
## Agora tem efeito de verdade:
## - "Ruína Ígnea": dano em area pequena (SpellData.damage_area_radius,
##   ver SpellManager._apply_damage_area) — mesma mira/UX de clique da
##   Lança de Arcana, so o efeito se espalha pros vizinhos do alvo.
## - "Metamorfose de Gaia": transforma o terreno do tile onde o alvo
##   (uma unidade PROPRIA, mesmo target_kind/UX de clique do Reanimar)
##   esta em pe, usando TechData.terrain_transform (from/to) da propria
##   tech (ver SpellManager._apply_terrain_transform).

static var _cache: Dictionary = {} # nome -> SpellData, montada uma vez por sessao

static func _build_all() -> Dictionary:
	var spells: Dictionary = {}

	var arcane_lance := SpellData.new()
	arcane_lance.name = "Lança de Arcana"
	arcane_lance.description = "Um dardo de energia arcana pura, guiado pela vontade do conjurador ate qualquer inimigo que ele possa enxergar."
	arcane_lance.cooldown_turns = 3
	arcane_lance.mana_cost = 25
	arcane_lance.target_kind = "enemy_unit_in_vision"
	arcane_lance.damage = 6.0
	spells[arcane_lance.name] = arcane_lance

	var reanimate := SpellData.new()
	reanimate.name = "Reanimar"
	reanimate.description = "Um eco tomado do outro lado do veu empresta vigor emprestado a um corpo cansado, selando ferimentos que a medicina comum nao alcançaria a tempo."
	reanimate.cooldown_turns = 4
	reanimate.mana_cost = 40
	reanimate.target_kind = "friendly_unit"
	reanimate.heal_fraction = 0.5
	spells[reanimate.name] = reanimate

	var flame_cataclysm := SpellData.new()
	flame_cataclysm.name = "Ruína Ígnea"
	flame_cataclysm.description = "Fogo, pedra e tempestade convocados ao mesmo tempo sobre um único ponto do mapa — o bastante pra reduzir a cinzas qualquer coisa perto demais quando a terra racha."
	flame_cataclysm.cooldown_turns = 6
	flame_cataclysm.mana_cost = 60
	flame_cataclysm.target_kind = "enemy_unit_in_vision"
	flame_cataclysm.damage = 10.0
	flame_cataclysm.damage_area_radius = 1
	spells[flame_cataclysm.name] = flame_cataclysm

	var gaia_metamorphosis := SpellData.new()
	gaia_metamorphosis.name = "Metamorfose de Gaia"
	gaia_metamorphosis.description = "Um sussurro antigo devolvido à terra estéril — tundra e deserto lembram, por um instante, do verde que um dia foram."
	gaia_metamorphosis.cooldown_turns = 8
	gaia_metamorphosis.mana_cost = 50
	gaia_metamorphosis.target_kind = "friendly_unit"
	gaia_metamorphosis.transforms_terrain = true
	spells[gaia_metamorphosis.name] = gaia_metamorphosis

	return spells

static func _all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build_all()
	return _cache

## null se `name` nao tiver nenhum SpellData cadastrado (feitico so de
## nome/lore por enquanto, ver comentario de topo).
static func get_spell(spell_name: String) -> SpellData:
	return _all().get(spell_name, null)

static func all_spells() -> Array:
	return _all().values()

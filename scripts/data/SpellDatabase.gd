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
## (transcendencia_florestal) sao tecnologias de Tier 3 que ja existem em
## TechDatabase (com unlocks_spell/terrain_transform preenchidos como
## DADOS), mas deliberadamente NAO tem SpellData aqui ainda — nenhuma
## logica de dano em area/transformacao de bioma foi implementada nesta
## rodada. get_spell() devolve null pra elas, e SpellManager.cast() trata
## isso como "sem efeito implementado" em vez de travar (ver comentario
## la). Escopo de um passe futuro.

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

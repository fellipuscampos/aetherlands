class_name SpellManager
extends RefCounted

## Aplica o efeito de um feitico/ritual (ver SpellDatabase) contra um alvo
## escolhido no mapa — chamado por SelectionManager depois que o clique do
## jogador confirma um alvo valido (ver _valid_spell_target la). Estatico
## e sem estado proprio (mesmo padrao de Diplomacy.gd/CombatResolver.gd):
## so le/muta o PlayerData e o Unit passados.
##
## Custo (Ponto 3, "Economia Arcana"): DOIS gates independentes, os dois
## precisam estar satisfeitos pra conjurar —
## - can_cast(): tecnologia pesquisada + cooldown (PlayerData.spell_
##   cooldowns) ja passou.
## - has_enough_mana(): saldo de PlayerData.mana >= SpellData.mana_cost.
## is_castable() e a combinacao dos dois, e o que a HUD usa pra decidir se
## o botao "Conjurar" fica clicavel — mantidos separados (em vez de um
## unico can_cast que ja checasse tudo) pra cada motivo de bloqueio poder
## ser mostrado/testado com uma mensagem propria (recarga vs mana
## insuficiente), sem o chamador ter que redescobrir qual dos dois falhou.

## true se `caster` ja pesquisou a tecnologia que concede este feitico
## (MagicDatabase.unlocked_spells_for — nenhuma tech de Doutrina concede
## feitico, ver TechDatabase.gd) E o cooldown dele ja passou. NAO leva
## mana em conta (ver has_enough_mana/is_castable pra isso).
static func can_cast(caster: PlayerData, spell_name: String, current_turn: int) -> bool:
	if not (spell_name in MagicDatabase.unlocked_spells_for(caster.researched_magic)):
		return false
	var available_at: int = caster.spell_cooldowns.get(spell_name, 0)
	return current_turn >= available_at

## Roadmap 2.0 Parte 1 (B1) — identidade de Nodulo Arcano: custo de mana
## efetivo, descontado por ResourceDatabase.spell_mana_cost_multiplier
## quando `hex_grid` e fornecido (mesma convencao opcional de City.
## production_cost). 0.0 pra feitico sem SpellData cadastrado.
static func effective_mana_cost(spell: SpellData, caster: PlayerData, hex_grid: HexGrid = null) -> float:
	if spell.category == "ritual":
		return spell.mana_cost
	var mult := 1.0
	if hex_grid:
		mult = ResourceDatabase.spell_mana_cost_multiplier(caster, hex_grid)
	return spell.mana_cost * mult

## false pra feitico sem SpellData cadastrado (Ruina Ignea/Metamorfose de
## Gaia, ver SpellDatabase) — nunca "castable" de verdade, mana ou nao.
static func has_enough_mana(caster: PlayerData, spell_name: String, hex_grid: HexGrid = null) -> bool:
	var spell: SpellData = SpellDatabase.get_spell(spell_name)
	if spell == null:
		return false
	return caster.mana >= effective_mana_cost(spell, caster, hex_grid)

## can_cast() (tech+recarga) E has_enough_mana() (saldo) — usado pela HUD
## (Grimorio) pra decidir se "Conjurar" fica clicavel.
static func is_castable(caster: PlayerData, spell_name: String, current_turn: int, hex_grid: HexGrid = null) -> bool:
	var spell := SpellDatabase.get_spell(spell_name)
	if spell and spell.effect != "" and hex_grid:
		return MagicRuntime.reason(caster, spell, hex_grid) == ""
	return can_cast(caster, spell_name, current_turn) and has_enough_mana(caster, spell_name, hex_grid)

## Turno em que o feitico volta a ficar disponivel — so informativo pra UI
## (0 ou <= turno atual significa "disponivel agora").
static func cooldown_ends_at(caster: PlayerData, spell_name: String) -> int:
	return caster.spell_cooldowns.get(spell_name, 0)

## Resolve o efeito de verdade contra `target`, poe o feitico em cooldown
## E desconta o mana. O chamador (SelectionManager) ja validou que `target`
## bate com o target_kind do feitico antes de chegar aqui. Sempre devolve
## uma mensagem curta pronta pro toast (EventBus.notify) em vez de lancar
## erro — feitico sem SpellData cadastrado, em recarga, ou sem mana
## suficiente viram um no-op com aviso em vez de travar o jogo. Nenhum dos
## tres casos de bloqueio consome cooldown NEM mana — so uma conjuracao
## que realmente aconteceu cobra o custo.
static func cast(caster: PlayerData, spell_name: String, target: Unit, hex_grid: HexGrid, current_turn: int) -> String:
	var spell: SpellData = SpellDatabase.get_spell(spell_name)
	if spell and spell.effect != "" and is_instance_valid(target):
		return MagicRuntime.cast(caster, spell, target.coord, hex_grid)
	if spell == null:
		return "%s ainda não tem efeito implementado." % spell_name
	if not can_cast(caster, spell_name, current_turn):
		return "%s ainda está em recarga." % spell_name
	var mana_cost := effective_mana_cost(spell, caster, hex_grid)
	if caster.mana < mana_cost:
		return "Mana insuficiente para conjurar %s (precisa de %d, tem %d)." % [spell_name, int(mana_cost), int(caster.mana)]
	if not is_instance_valid(target) or target.hp <= 0.0:
		return "Alvo inválido."
	if spell.transforms_terrain:
		var tech := MagicDatabase.tech_that_unlocks_spell(spell_name)
		var tile := hex_grid.get_tile(target.coord)
		if tech == null or tile == null or not tile.terrain_type in tech.terrain_transform.get("from", []):
			return "%s não tem efeito nesse terreno." % spell_name

	caster.spell_cooldowns[spell_name] = current_turn + spell.cooldown_turns
	caster.mana -= mana_cost

	if spell.transforms_terrain:
		return _apply_terrain_transform(spell, target, hex_grid)
	if spell.damage > 0.0:
		if spell.damage_area_radius > 0:
			return _apply_damage_area(spell, target, hex_grid, caster)
		return _apply_damage(spell, target, hex_grid, caster)
	if spell.heal_fraction > 0.0:
		return _apply_heal(spell, target)
	return "%s conjurado." % spell_name

## Roadmap de gameplay Fase 5 — "Ruína Ígnea": dano no alvo principal
## (mesma regra de mira de sempre) MAIS em qualquer unidade num tile
## vizinho dele (SpellData.damage_area_radius), aliada ou nao —
## cataclismo indiscriminado, reaproveita _apply_damage por unidade em
## vez de uma formula nova. Guarda o coord do alvo principal ANTES de
## danifica-lo (pode morrer e sumir do grid ali mesmo, ver _apply_damage)
## pra continuar sabendo onde procurar vizinhos.
static func _apply_damage_area(spell: SpellData, primary_target: Unit, hex_grid: HexGrid, caster: PlayerData = null) -> String:
	var origin_coord := primary_target.coord
	var messages: Array = [_apply_damage(spell, primary_target, hex_grid, caster)]
	for neighbor_coord in hex_grid.get_neighbors(origin_coord):
		var unit: Unit = hex_grid.get_unit_at(neighbor_coord)
		if unit:
			if caster and unit.owner_player and unit.owner_player != caster and unit.owner_player != primary_target.owner_player and not caster.is_at_war_with(unit.owner_player):
				continue
			messages.append(_apply_damage(spell, unit, hex_grid, caster))
	return " ".join(messages)

## Roadmap de gameplay Fase 5 — "Metamorfose de Gaia": transforma o
## TERRENO do tile onde `target` esta em pe (a unidade so marca QUAL
## tile, nao e afetada ela mesma) usando TechData.terrain_transform
## (from/to) da tech que concede este feitico. Sem efeito (mensagem de
## aviso — o mana/cooldown ja foram descontados em cast() de qualquer
## forma, mesmo padrao de "conjuracao valida mas alvo ruim" que o resto
## do jogo usa) se o terreno atual do tile nao estiver na lista `from`.
static func _apply_terrain_transform(spell: SpellData, target: Unit, hex_grid: HexGrid) -> String:
	var tech: TechData = MagicDatabase.tech_that_unlocks_spell(spell.name)
	if tech == null or tech.terrain_transform.is_empty():
		return "%s não tem transformação de terreno configurada." % spell.name
	var coord := target.coord
	var current: HexTileData = hex_grid.get_tile(coord)
	if current == null or not (current.terrain_type in tech.terrain_transform.from):
		return "%s não tem efeito nesse terreno." % spell.name
	var new_type: int = tech.terrain_transform.to
	hex_grid.transform_tile_terrain(coord, new_type)
	return "%s transformou o terreno em %s." % [spell.name, TerrainDatabase.create_tile(new_type).display_name]

static func _apply_damage(spell: SpellData, target: Unit, hex_grid: HexGrid, caster: PlayerData = null) -> String:
	var target_name = target.unit_data.unit_name
	var target_coord = target.coord
	if caster:
		DragonEvent.record_damage_if_target_is_the_active_dragon(target, GameManager.players.find(caster), minf(target.hp, spell.damage))
	target.hp -= spell.damage
	hex_grid.spawn_damage_popup(target_coord, spell.damage)
	if target.hp <= 0.0:
		hex_grid.remove_unit(target)
		return "%s foi destruído por %s!" % [target_name, spell.name]
	return "%s causou %d de dano em %s." % [spell.name, int(spell.damage), target_name]

static func _apply_heal(spell: SpellData, target: Unit) -> String:
	var healed = minf(target.unit_data.max_hp - target.hp, target.unit_data.max_hp * spell.heal_fraction)
	target.hp = min(target.unit_data.max_hp, target.hp + healed)
	return "%s restaurou %d de HP em %s." % [spell.name, int(healed), target.unit_data.unit_name]

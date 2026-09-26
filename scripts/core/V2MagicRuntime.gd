class_name V2MagicRuntime
extends RefCounted

## Runtime GENÉRICO dos feitiços V2 (Aetherlands V2, Fase 17). Nenhuma Escola, feitiço ou unidade concreta
## é citada aqui: tudo vem de V2SpellData (números), V2SpellDatabase (quem existe), UnitData.v2_magic_school
## (quem é conjurador de qual Escola) e V2ResearchState (o que o DONO pesquisou).
##
## Reaproveita o que já existia (auditoria da Fase 17):
##   * Mana: o MESMO pool `player.mana` que V2EconomyRuntime abastece — nenhum "v2_mana".
##   * Recarga: `unit.magic_cooldowns[spell_id]` (já salvo; mesmo formato das Técnicas: turno em que volta).
##   * Estado temporário: `target.magic_status[spell_id]` com a regra ÚNICA de V2OwnerTurnEffect ("até o
##     início do próximo turno do dono"), encerrado por expire_finished em GameManager._finish_turn.
##   * Visibilidade: a mesma regra das técnicas de alcance > 1 (lê HexGrid.visibility, nunca recalcula).
## Feitiço NÃO é Técnica Militar: custa Mana e pertence a uma Escola — os dois pipelines ficam separados.
##
## REPERTÓRIO DERIVADO: um conjurador conhece um feitiço se (1) tem `v2_magic_school`, (2) a Escola do feitiço
## bate e (3) o DONO concluiu a pesquisa do feitiço. Nada é salvo (sem spellbook): pesquisar N6 ensina a Onda
## a um Clérigo que já existia; resetar a pesquisa tira o feitiço.

# --- Repertório --------------------------------------------------------------------------------

## A unidade é um conjurador de uma Escola V2? (Conjuradores V1 — escolas "sagrada" etc. — nunca.)
static func is_v2_caster(unit: Unit) -> bool:
	return unit != null and unit.unit_data != null and unit.unit_data.is_v2_caster() and V2MagicContent.is_v2_school(unit.unit_data.v2_magic_school)

## Os feitiços que `unit` conhece AGORA, na ordem dos nós (N4..N7). Só olha os feitiços da Escola dela.
static func spells_for_unit(unit: Unit) -> Array[V2SpellData]:
	var result: Array[V2SpellData] = []
	if not is_v2_caster(unit) or unit.owner_player == null:
		return result
	for spell in V2SpellDatabase.for_school(unit.unit_data.v2_magic_school):
		if V2UnlockSystem.is_unlocked(unit.owner_player, spell.id):
			result.append(spell)
	return result

static func knows(unit: Unit, spell_id: String) -> bool:
	var spell := V2SpellDatabase.get_spell(spell_id)
	return spell != null and is_v2_caster(unit) and unit.unit_data.v2_magic_school == spell.school_branch and unit.owner_player != null and V2UnlockSystem.is_unlocked(unit.owner_player, spell.id)

static func cooldown_remaining(unit: Unit, spell_id: String) -> int:
	return maxi(0, int(unit.magic_cooldowns.get(spell_id, 0)) - TurnManager.turn_number)

static func is_status_active(unit: Unit, spell_id: String) -> bool:
	return V2OwnerTurnEffect.is_active(unit.magic_status, spell_id)

# --- Alvos -------------------------------------------------------------------------------------

## Fase 20 — alcance EFETIVO do alvo primário: `cast_range` do feitiço + `spell_range_bonus` do conjurador (Domínio
## Natural). Genérico para toda Escola (bônus 0 = idêntico a antes); nunca muda área, Mana, recarga nem visão.
static func effective_range(caster: Unit, spell: V2SpellData) -> int:
	var bonus := caster.unit_data.spell_range_bonus if caster != null and caster.unit_data != null else 0
	return spell.cast_range + bonus

## Recarga efetivamente GRAVADA pelo cast. Redução por dado, nunca abaixo de zero e sem
## recalcular retroativamente uma recarga já em curso.
static func effective_cooldown(caster: Unit, spell: V2SpellData) -> int:
	var reduction := caster.unit_data.spell_cooldown_reduction if caster != null and caster.unit_data != null else 0
	return maxi(0, spell.cooldown_turns - reduction)

static func _grid(hex_grid: HexGrid) -> HexGrid:
	return hex_grid if hex_grid != null else GameManager.hex_grid

## Mesma regra das técnicas de alcance > 1: só o humano com neblina calculada precisa ver o tile agora.
static func _visible_to_owner(unit: Unit, coord: Vector2i, grid: HexGrid) -> bool:
	if unit.owner_player != GameManager.human_player or grid.visibility.is_empty():
		return true
	return grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE

## Fase 19 — filtro genérico por traço (V2SpellData.required_target_trait); "" = qualquer unidade.
static func _has_required_trait(unit: Unit, spell: V2SpellData) -> bool:
	return unit != null and unit.unit_data != null and (spell.required_target_trait == "" or unit.unit_data.has_trait(spell.required_target_trait))

static func _is_injured(unit: Unit) -> bool:
	return unit.hp > 0.0 and unit.hp < unit.unit_data.max_hp

static func _hp_ratio(unit: Unit) -> float:
	return unit.hp / maxf(unit.unit_data.max_hp, 0.001)

## Vítimas/beneficiários de área a partir do alvo primário. O primário fica sempre primeiro; secundários
## hostis são determinísticos (menor HP%, depois serial) e respeitam a neblina do humano.
static func affected_units(caster: Unit, spell: V2SpellData, primary: Unit, hex_grid: HexGrid = null) -> Array[Unit]:
	var result: Array[Unit] = []
	if caster == null or primary == null or spell == null:
		return result
	result.append(primary)
	if spell.splash_radius <= 0:
		return result
	var grid := _grid(hex_grid)
	var secondary: Array[Unit] = []
	for coord in HexMetrics.coords_within(primary.coord, spell.splash_radius):
		if coord == primary.coord:
			continue
		var candidate := grid.get_unit_at(coord)
		if candidate == null or candidate.hp <= 0.0:
			continue
		if spell.target_mode == V2SpellData.TargetMode.OWN_UNIT:
			if candidate.owner_player == caster.owner_player and _has_required_trait(candidate, spell):
				secondary.append(candidate)
		elif CombatResolver.is_hostile_unit_target(caster.owner_player, candidate, grid) and _visible_to_owner(caster, coord, grid):
			secondary.append(candidate)
	if spell.target_mode == V2SpellData.TargetMode.HOSTILE_UNIT:
		secondary.sort_custom(func(a: Unit, b: Unit) -> bool:
			var ar := _hp_ratio(a)
			var br := _hp_ratio(b)
			return a.serial_id < b.serial_id if is_equal_approx(ar, br) else ar < br)
	result.append_array(secondary)
	return result

## "" se `target` é um alvo PRIMÁRIO válido para `spell` lançado por `caster`; senão o motivo.
static func target_reason(caster: Unit, spell: V2SpellData, target: Unit, hex_grid: HexGrid = null) -> String:
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return "Alvo inválido."
	var grid := _grid(hex_grid)
	if HexMetrics.axial_distance(caster.coord, target.coord) > effective_range(caster, spell) or not _visible_to_owner(caster, target.coord, grid):
		return "Alvo fora do alcance."
	if spell.targets_tile():
		return "Este feitiço mira um tile, não uma unidade."
	if spell.target_mode == V2SpellData.TargetMode.OWN_UNIT:
		if target.owner_player != caster.owner_player:
			return "Só unidades próprias podem ser alvo deste feitiço."
		if not _has_required_trait(target, spell):
			return "Só %s podem ser alvo deste feitiço." % UnitData.own_target_plural(spell.required_target_trait)
	elif target == caster or not CombatResolver.is_hostile_unit_target(caster.owner_player, target, grid):
		return "Só unidades hostis podem ser alvo deste feitiço."
	elif not _has_required_trait(target, spell):
		return "O alvo não possui o traço necessário para este feitiço."
	elif spell.requires_v2_caster_target and not target.unit_data.is_v2_caster():
		return "Só conjuradores podem ser alvo deste feitiço."
	if spell.is_heal():
		if spell.splash_radius > 0:
			for unit in affected_units(caster, spell, target, grid):
				if _is_injured(unit):
					return ""
			return "Nenhuma unidade ferida na área."
		if not _is_injured(target):
			return "O alvo já está com a Vida máxima."
	return ""

## Os alvos primários válidos de `spell` para `caster` agora: só os tiles do alcance do feitiço
## (HexMetrics.coords_within), resolvidos genericamente pelo TargetMode. Ordem estável (coordenada).
static func target_units(caster: Unit, spell: V2SpellData, hex_grid: HexGrid = null) -> Array[Unit]:
	var result: Array[Unit] = []
	if caster == null or spell == null:
		return result
	var grid := _grid(hex_grid)
	if grid == null or spell.targets_tile():
		return result
	# O próprio conjurador também é alvo possível (§37) — coords_within não inclui o centro.
	for coord in [caster.coord] + HexMetrics.coords_within(caster.coord, effective_range(caster, spell)):
		var unit := grid.get_unit_at(coord)
		if unit != null and target_reason(caster, spell, unit, grid) == "":
			result.append(unit)
	return result

static func target_coords(caster: Unit, spell: V2SpellData, hex_grid: HexGrid = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if spell != null and spell.targets_tile():
		return target_tiles(caster, spell, hex_grid)
	for unit in target_units(caster, spell, hex_grid):
		result.append(unit.coord)
	return result

# --- Alvo de tile (EMPTY_TILE, Fase 19) ------------------------------------------------------------------

static var _summon_data_cache: Dictionary = {}

## O UnitData que `spell` invoca (cache por kind; só leitura — o nascimento cria um UnitData novo).
static func summon_data(spell: V2SpellData) -> UnitData:
	if spell == null or not spell.is_summon():
		return null
	if not _summon_data_cache.has(spell.summon_unit_id):
		_summon_data_cache[spell.summon_unit_id] = UnitDatabase.create_unit(spell.summon_unit_id)
	return _summon_data_cache[spell.summon_unit_id]

## "" se `coord` é um tile VAZIO válido para `spell` lançado por `caster`: existe, visível ao dono humano, dentro
## do alcance, sem unidade, sem covil, sem cidade alheia e com terreno legal para o que o feitiço cria. Território
## não importa (próprio, neutro ou inimigo em guerra). Nunca empilha unidade.
## Fase 20 — TILE: o mesmo, mas o tile pode ter unidade e o próprio tile do conjurador conta (alcance 0..N); depois vêm
## os requisitos de terreno do feitiço (V2TerrainRuntime: aplicar exige tile elegível; restaurar exige modificação).
static func tile_reason(caster: Unit, spell: V2SpellData, coord: Vector2i, hex_grid: HexGrid = null) -> String:
	var grid := _grid(hex_grid)
	if caster == null or spell == null or grid == null:
		return "Tile inválido."
	var tile: HexTileData = grid.get_tile(coord)
	if tile == null:
		return "Tile inválido."
	var distance := HexMetrics.axial_distance(caster.coord, coord)
	var min_distance := 0 if spell.target_mode == V2SpellData.TargetMode.TILE else 1
	if distance < min_distance or distance > effective_range(caster, spell) or not _visible_to_owner(caster, coord, grid):
		return "Tile fora do alcance."
	if spell.target_mode == V2SpellData.TargetMode.EMPTY_TILE:
		if grid.get_unit_at(coord) != null:
			return "O tile está ocupado."
		if grid.lairs_by_coord.has(coord):
			return "Não é possível conjurar sobre um covil."
		var city := grid.get_city_at(coord)
		if city != null and city.owner_player != caster.owner_player:
			return "Não é possível conjurar numa cidade alheia."
	if spell.teleport_caster:
		return grid.unit_destination_reason(caster, coord)
	if spell.creates_portal_pair:
		return V2PortalSystem.creation_destination_reason(coord, grid, caster.owner_player, spell.school_branch)
	if spell.dispel_at_tile:
		return "" if has_dispellable_effect_at(caster, coord, grid) else "Não há efeito mágico dissipável neste tile."
	if spell.environmental_zone_id != "":
		return V2EnvironmentalZoneSystem.application_reason(grid, coord, spell.environmental_zone_id)
	var data := summon_data(spell)
	# Mesma regra de posicionamento do resto do jogo: terrestre/voo tático só termina em terra; o voo V1 livre, em qualquer tile.
	if data != null and tile.blocks_land_units() and not data.flies:
		return "Terreno incompatível com a invocação."
	if spell.requires_existing_terrain_modification or spell.remove_terrain_modification:
		var removal := V2TerrainRuntime.removal_reason(grid, coord)
		if removal != "":
			return removal
	if spell.terrain_modification_id != "":
		# O alvo primário precisa receber a modificação (a área pode ignorar tiles inelegíveis).
		return V2TerrainRuntime.application_reason(grid, coord, spell.terrain_modification_id)
	return ""

## Fase 20 — os tiles que um feitiço de terreno MODIFICA a partir do primário: o primário primeiro, depois a área
## `splash_radius` na ordem estável de HexMetrics.coords_within, só os elegíveis (unidade em cima vale; prédio, cidade,
## melhoria, covil, água/montanha e modificação existente ficam de fora) e — para o humano — só os VISÍVEIS (nunca
## muda/revela área oculta; não recalcula neblina). [] se o primário é inválido.
static func terrain_area_tiles(caster: Unit, spell: V2SpellData, primary: Vector2i, hex_grid: HexGrid = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid := _grid(hex_grid)
	if caster == null or spell == null or grid == null or spell.terrain_modification_id == "":
		return result
	if V2TerrainRuntime.application_reason(grid, primary, spell.terrain_modification_id) != "":
		return result
	result.append(primary)
	if spell.splash_radius <= 0:
		return result
	for coord in HexMetrics.coords_within(primary, spell.splash_radius):
		if coord == primary or not grid.tiles.has(coord):
			continue
		if V2TerrainRuntime.application_reason(grid, coord, spell.terrain_modification_id) == "" and _visible_to_owner(caster, coord, grid):
			result.append(coord)
	return result

## Os tiles VAZIOS válidos ao alcance (só o disco do alcance, nunca o mapa). Ordem estável (a de coords_within).
static func target_tiles(caster: Unit, spell: V2SpellData, hex_grid: HexGrid = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid := _grid(hex_grid)
	if caster == null or spell == null or grid == null:
		return result
	var coords: Array = HexMetrics.coords_within(caster.coord, effective_range(caster, spell))
	if spell.target_mode == V2SpellData.TargetMode.TILE:
		coords = [caster.coord] + coords # coords_within não inclui o centro (achado da Fase 17)
	for coord in coords:
		if tile_reason(caster, spell, coord, grid) == "":
			result.append(coord)
	return result

## "" ou o nome do que o tile-alvo recebe/perde (rótulo da mira).
static func tile_target_label(spell: V2SpellData, coord: Vector2i, hex_grid: HexGrid = null) -> String:
	if spell.teleport_caster:
		return "Destino do conjurador"
	if spell.dispel_at_tile:
		return "Efeito mágico dissipável"
	if spell.creates_portal_pair:
		return "Novo endpoint"
	var data := summon_data(spell)
	if data != null:
		return data.unit_name
	if spell.terrain_modification_id != "":
		var modification := V2TerrainModificationDatabase.get_modification(spell.terrain_modification_id)
		return modification.display_name if modification != null else ""
	if spell.environmental_zone_id != "":
		var zone := V2EnvironmentalZoneDatabase.get_zone(spell.environmental_zone_id)
		return zone.display_name if zone != null else ""
	var current := V2TerrainRuntime.modification_at(_grid(hex_grid), coord)
	return current.display_name if current != null else ""

# --- Disponibilidade -------------------------------------------------------------------------------

## O motivo (uma frase) de `unit` não poder conjurar `spell_id` agora, ou "" se pode (há ao menos um alvo).
static func unavailable_reason(unit: Unit, spell_id: String, hex_grid: HexGrid = null) -> String:
	var spell := V2SpellDatabase.get_spell(spell_id)
	if spell == null or unit == null or unit.unit_data == null:
		return "Feitiço desconhecido."
	if unit.unit_data.v2_magic_school != spell.school_branch:
		return "Esta unidade não conjura feitiços desta Escola."
	if unit.owner_player == null or not V2UnlockSystem.is_unlocked(unit.owner_player, spell.id):
		return "Requer pesquisa: %s." % spell.display_name
	if unit.hp <= 0.0:
		return "A unidade caiu."
	if not unit.can_receive_orders(): # Fase 19: helper genérico de ordem (caminho rápido para quem não é retinue)
		return unit.order_block_reason()
	if is_spellcasting_silenced(unit):
		return "Silêncio — não pode conjurar feitiços."
	var remaining := cooldown_remaining(unit, spell.id)
	if remaining > 0:
		return "Em recarga: %d turno(s)." % remaining
	if spell.consumes_action and (unit.movement_left <= 0.0 or unit.embarked):
		return "A unidade já agiu neste turno."
	if spell.is_summon():
		# Fase 19: a capacidade de comando é checada ANTES da mira (e de novo no cast) — o custo vem do UnitData invocado.
		var command_reason := V2RetinueSystem.summon_reason(unit.owner_player, summon_data(spell))
		if command_reason != "":
			return command_reason
	if unit.owner_player.mana < spell.mana_cost:
		return "Mana insuficiente: requer %d." % int(spell.mana_cost)
	if spell.targets_tile():
		if not target_tiles(unit, spell, hex_grid).is_empty():
			return ""
		if spell.requires_existing_terrain_modification or spell.remove_terrain_modification:
			return "Nenhum tile com modificação de terreno ao alcance."
		if spell.dispel_at_tile:
			return "Não há efeito mágico dissipável neste tile."
		return "Nenhum tile elegível ao alcance." if spell.terrain_modification_id != "" or spell.environmental_zone_id != "" else "Nenhum tile livre ao alcance."
	if target_units(unit, spell, hex_grid).is_empty():
		if spell.is_heal():
			return "Nenhuma unidade ferida ao alcance." if spell.required_target_trait == "" else "Nenhuma entre %s ferida ao alcance." % UnitData.own_target_plural(spell.required_target_trait)
		if spell.target_mode == V2SpellData.TargetMode.HOSTILE_UNIT:
			return "Nenhuma unidade hostil ao alcance."
		return "Nenhuma unidade própria ao alcance." if spell.required_target_trait == "" else "Nenhuma entre %s ao alcance." % UnitData.own_target_plural(spell.required_target_trait)
	return ""

static func can_cast(unit: Unit, spell_id: String, hex_grid: HexGrid = null) -> bool:
	return unavailable_reason(unit, spell_id, hex_grid) == ""

# --- Conjuração ----------------------------------------------------------------------------------

## Conjura `spell_id` no alvo em `target_coord`. false SEM ALTERAR NADA se indisponível ou alvo inválido. A Mana
## só é descontada depois de validar tudo; a recarga só começa num cast bem-sucedido.
static func cast(unit: Unit, spell_id: String, target_coord: Vector2i, hex_grid: HexGrid = null) -> bool:
	var grid := _grid(hex_grid)
	if grid == null or not can_cast(unit, spell_id, grid):
		return false
	var spell := V2SpellDatabase.get_spell(spell_id)
	if spell.targets_tile():
		return _cast_on_tile(unit, spell, target_coord, grid)
	var target := grid.get_unit_at(target_coord)
	if target_reason(unit, spell, target, grid) != "":
		return false
	unit.owner_player.mana -= spell.mana_cost
	_start_cooldown(unit, spell)
	# Reúne tudo ANTES de aplicar: a morte do primário nunca interrompe uma explosão.
	var affected := affected_units(unit, spell, target, grid)
	for affected_unit in affected:
		_apply(unit, spell, affected_unit, grid)
	_commit_action(unit, spell)
	return true

## Custo comum de todo cast bem-sucedido: ação + cancelar fortificar/explorar/marcha.
static func _commit_action(unit: Unit, spell: V2SpellData) -> void:
	if spell.consumes_action:
		unit.movement_left = 0.0
	unit.fortified = false
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER

static func _start_cooldown(unit: Unit, spell: V2SpellData) -> void:
	var turns := effective_cooldown(unit, spell)
	if turns > 0:
		unit.magic_cooldowns[spell.id] = TurnManager.turn_number + turns
	else:
		unit.magic_cooldowns.erase(spell.id)

## Fase 19/20 — cast em tile (invocação, criação ou remoção de modificação de terreno). Revalida tile e comando (can_cast já o fez); nasce pelo pipeline
## normal (HexGrid.spawn_unit: grid, serial, save), dono = do conjurador, Vida cheia e movimento 0 (só age a partir
## do próximo turno do dono). Só DEPOIS de nascer cobra Mana/recarga/ação: se nada nasce, nada é gasto.
static func _cast_on_tile(unit: Unit, spell: V2SpellData, coord: Vector2i, grid: HexGrid) -> bool:
	if tile_reason(unit, spell, coord, grid) != "":
		return false
	# Tudo abaixo já foi validado; efeitos destrutivos/substitutivos só começam agora.
	if spell.is_summon():
		if V2RetinueSystem.summon_reason(unit.owner_player, summon_data(spell)) != "":
			return false
		var summoned := grid.spawn_unit(coord, UnitDatabase.create_unit(spell.summon_unit_id), unit.owner_player)
		if summoned == null:
			return false
		summoned.movement_left = 0.0
	if spell.terrain_modification_id != "":
		# Fase 20: toda a área é decidida ANTES de mudar qualquer tile; zero tiles = nada gasto.
		var area := terrain_area_tiles(unit, spell, coord, grid)
		if area.is_empty():
			return false
		for area_coord in area:
			V2TerrainRuntime.apply(grid, area_coord, spell.terrain_modification_id)
	if spell.environmental_zone_id != "":
		# Toda a área é decidida/aplicada em batch: Mana uma vez, marker por tile,
		# fog no máximo uma vez se uma fonte humana de visão foi afetada.
		if V2EnvironmentalZoneSystem.apply_area(unit, spell.environmental_zone_id, coord, spell.splash_radius, grid).is_empty():
			return false
	if spell.remove_terrain_modification and not V2TerrainRuntime.remove(grid, coord):
		return false
	if spell.teleport_caster:
		grid.teleport_unit(unit, coord) # deslocamento direto: nenhum pathfinding/custo/intermediário
	if spell.dispel_at_tile:
		var target := grid.get_unit_at(coord)
		if target != null:
			for status_id in dispellable_statuses_for(unit, target, grid):
				target.magic_status.erase(status_id)
			target.refresh_technique_marker()
		V2PortalSystem.close_pair_at(coord, grid) # no-op se o efeito elegível era só da unidade
		V2EnvironmentalZoneSystem.remove(grid, coord, true) # Grove/Elevado são físicos e permanecem
	if spell.creates_portal_pair and not V2PortalSystem.create_or_replace_pair(unit.owner_player, spell.school_branch, unit.coord, coord, grid):
		return false
	unit.owner_player.mana -= spell.mana_cost
	_start_cooldown(unit, spell)
	_commit_action(unit, spell)
	return true

static func _apply(caster: Unit, spell: V2SpellData, target: Unit, grid: HexGrid) -> void:
	if spell.is_damage():
		CombatResolver.apply_direct_unit_damage(caster, target, predict_damage(caster, target, spell), grid)
	if spell.is_heal() and _is_injured(target):
		var before := target.hp
		# Sem overheal: nunca passa do máximo, nunca cria Vida temporária.
		target.hp = target.unit_data.max_hp if spell.heal_to_full else minf(target.hp + spell.heal_amount, target.unit_data.max_hp)
		if grid != null and target.hp > before:
			grid.spawn_heal_popup(target.coord, target.hp - before)
	if spell.applies_status():
		# Mesmo feitiço de novo (outro conjurador) SUBSTITUI o registro — nunca 1,35 x 1,35.
		target.magic_status[spell.id] = V2OwnerTurnEffect.expiry_for_now()
		target.refresh_technique_marker()

# --- Interferência mágica ----------------------------------------------------------------------

## Fast path: sem magic_status, nenhuma consulta ao banco. Só ids que resolvem para V2SpellData
## podem silenciar; Techniques históricas no mesmo Dictionary são ignoradas.
static func is_spellcasting_silenced(unit: Unit) -> bool:
	if unit == null or unit.magic_status.is_empty():
		return false
	for status_id in unit.magic_status.keys():
		if not V2OwnerTurnEffect.is_active(unit.magic_status, String(status_id)):
			continue
		var spell := V2SpellDatabase.get_spell(String(status_id))
		if spell != null and spell.silences_spellcasting:
			return true
	return false

## Status de feitiço V2 que `caster` pode remover deste alvo: harmful da própria unidade,
## beneficial de unidade realmente hostil. Aliado diplomático de outra civilização não entra.
static func dispellable_statuses_for(caster: Unit, target: Unit, hex_grid: HexGrid = null) -> Array[String]:
	var result: Array[String] = []
	if caster == null or target == null or target.magic_status.is_empty():
		return result
	var expected := V2SpellData.StatusPolarity.NONE
	if target.owner_player == caster.owner_player:
		expected = V2SpellData.StatusPolarity.HARMFUL
	elif CombatResolver.is_hostile_unit_target(caster.owner_player, target, _grid(hex_grid)):
		expected = V2SpellData.StatusPolarity.BENEFICIAL
	else:
		return result
	for status_id in target.magic_status.keys():
		var id := String(status_id)
		if not V2OwnerTurnEffect.is_active(target.magic_status, id):
			continue
		var spell := V2SpellDatabase.get_spell(id)
		if spell != null and spell.status_dispellable and spell.status_polarity == expected:
			result.append(id)
	result.sort()
	return result

## Preview exato da área ambiental: primary primeiro, secundários visíveis e
## ainda livres. Não altera mapa nem fog.
static func environmental_area_tiles(caster: Unit, spell: V2SpellData, primary: Vector2i, hex_grid: HexGrid = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid := _grid(hex_grid)
	if caster == null or spell == null or grid == null or spell.environmental_zone_id == "":
		return result
	if V2EnvironmentalZoneSystem.application_reason(grid, primary, spell.environmental_zone_id) != "":
		return result
	result.append(primary)
	for coord in HexMetrics.coords_within(primary, spell.splash_radius):
		if coord != primary and grid.tiles.has(coord) and not grid.v2_environmental_zones.has(coord) and _visible_to_owner(caster, coord, grid):
			result.append(coord)
	return result

static func has_dispellable_effect_at(caster: Unit, coord: Vector2i, hex_grid: HexGrid = null) -> bool:
	var grid := _grid(hex_grid)
	if grid == null:
		return false
	var target := grid.get_unit_at(coord)
	return (target != null and not dispellable_statuses_for(caster, target, grid).is_empty()) or not V2PortalSystem.endpoint_at(coord, grid).is_empty() or V2EnvironmentalZoneSystem.is_dispellable_at(coord, grid)

## Fórmula canônica de dano mágico V2. Não consulta Ataque, Defesa, terreno, fortificação,
## auras, posturas, Tensão ou CombatResolver.predict físico.
static func predict_damage(caster: Unit, target: Unit, spell: V2SpellData) -> float:
	if caster == null or target == null or spell == null or not spell.is_damage():
		return 0.0
	var conditional := 1.0
	if spell.low_hp_threshold > 0.0 and spell.low_hp_damage_bonus > 0.0 and _hp_ratio(target) <= spell.low_hp_threshold:
		conditional += spell.low_hp_damage_bonus
	return spell.damage_amount * caster.unit_data.spell_damage_multiplier * conditional

# --- Combate e turno ----------------------------------------------------------------------------------

## Multiplicador de Defesa de `defender` vindo de feitiços V2 ativos nele — UM fator em CombatResolver.predict.
## Caminho rápido: sem nenhum estado mágico, 1.0 sem olhar feitiço nenhum.
static func defense_multiplier(defender: Unit) -> float:
	if defender == null or defender.magic_status.is_empty():
		return 1.0
	var result := 1.0
	for spell in V2SpellDatabase.defensive_spells():
		if V2OwnerTurnEffect.is_active(defender.magic_status, spell.id):
			result *= 1.0 + spell.defense_bonus
	return result

## Multiplicador de Ataque de `attacker` vindo de feitiços V2 ativos nele (Fase 19, Comando Macabro) — UM fator em
## CombatResolver.predict, paralelo a defense_multiplier. Caminho rápido: sem estado mágico, 1.0 sem olhar feitiço.
## O mesmo feitiço nunca acumula consigo (um registro por id); feitiços diferentes multiplicariam.
static func attack_multiplier(attacker: Unit) -> float:
	if attacker == null or attacker.magic_status.is_empty():
		return 1.0
	var result := 1.0
	for spell in V2SpellDatabase.offensive_spells():
		if V2OwnerTurnEffect.is_active(attacker.magic_status, spell.id):
			result *= 1.0 + spell.attack_bonus
	return result

## Encerra, nas unidades de `player`, os estados de feitiço lançados antes do turno atual (início do próximo
## turno do dono). Recargas continuam contando. Chamado uma vez por turno (GameManager._finish_turn).
static func expire_finished(player: PlayerData) -> int:
	var expired := 0
	for unit in player.units:
		if unit.magic_status.is_empty():
			continue
		var changed := false
		for spell in V2SpellDatabase.status_spells():
			if unit.magic_status.has(spell.id) and V2OwnerTurnEffect.has_ended(int(unit.magic_status[spell.id])):
				unit.magic_status.erase(spell.id)
				expired += 1
				changed = true
		if changed:
			unit.refresh_technique_marker()
	return expired

## O nome do primeiro estado de feitiço ativo em `unit` ("" se nenhum) — marcador no mapa.
static func active_status_name(unit: Unit) -> String:
	if unit == null or unit.magic_status.is_empty():
		return ""
	for spell in V2SpellDatabase.status_spells():
		if is_status_active(unit, spell.id):
			return spell.display_name
	return ""

# --- Texto de UI ---------------------------------------------------------------------------------

static func targeting_hint(spell: V2SpellData) -> String:
	if spell.target_mode == V2SpellData.TargetMode.EMPTY_TILE:
		return "Escolha o tile livre de %s (ESC cancela)" % spell.display_name
	if spell.target_mode == V2SpellData.TargetMode.TILE:
		return "Escolha o tile de %s (ESC cancela)" % spell.display_name
	return "Escolha o alvo de %s (ESC cancela)" % spell.display_name

## Linha extra do tooltip de um feitiço de invocação: o comando disponível agora (o motivo de falta já vem de
## unavailable_reason). "" para os demais feitiços.
static func command_tooltip_line(unit: Unit, spell: V2SpellData) -> String:
	var data := summon_data(spell)
	if unit == null or data == null or not data.is_retinue() or V2RetinueSystem.summon_reason(unit.owner_player, data) != "":
		return ""
	return "Comando disponível: %d." % V2RetinueSystem.command_available(unit.owner_player, data.retinue_school)

static func button_text(unit: Unit, spell: V2SpellData) -> String:
	var text := "%s — %d Mana" % [spell.display_name, int(spell.mana_cost)]
	var remaining := cooldown_remaining(unit, spell.id)
	if remaining > 0:
		text += " (recarga %d)" % remaining
	return text

## Estados de feitiço ativos em `unit` (fato público: qualquer observador vê a Égide).
static func status_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	if unit == null or unit.magic_status.is_empty():
		return lines
	for spell in V2SpellDatabase.status_spells():
		if is_status_active(unit, spell.id):
			if spell.silences_spellcasting:
				lines.append("%s — não pode conjurar feitiços." % spell.display_name)
			else:
				lines.append("%s — Ativa (até o início do próximo turno do dono)" % spell.display_name)
	return lines

## Recargas de feitiço de `unit` (só o dono vê).
static func cooldown_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	if not is_v2_caster(unit) or unit.magic_cooldowns.is_empty():
		return lines
	for spell in V2SpellDatabase.for_school(unit.unit_data.v2_magic_school):
		var remaining := cooldown_remaining(unit, spell.id)
		if remaining > 0:
			lines.append("%s — recarga: %d turno(s)" % [spell.display_name, remaining])
	return lines

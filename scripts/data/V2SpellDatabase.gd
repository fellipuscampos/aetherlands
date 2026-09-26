class_name V2SpellDatabase
extends RefCounted

## Registro dos FEITIÇOS V2 (Aetherlands V2, Fase 17) — mesmo padrão de V2DoctrineTechniqueDatabase: um
## cache montado uma vez, consultas O(1). Só DADO: nenhuma regra de conjuração mora aqui (V2MagicRuntime).
## Fases 17-21: quatro feitiços por Escola conectada, de Sagrada até Arcanismo. BALANCE PLACEHOLDER.

static var _by_id: Dictionary = {}
static var _by_school: Dictionary = {}       # escola -> Array[V2SpellData] na ordem dos nós (N4..N7)
static var _defensive: Array[V2SpellData] = []  # feitiços com estado de Defesa (caminho quente do combate)
static var _offensive: Array[V2SpellData] = []  # Fase 19: feitiços com estado de Ataque (attack_multiplier)
static var _status: Array[V2SpellData] = []     # Fase 19: todo feitiço que deixa estado temporário (expiração/UI)

static func _build_all() -> Array[V2SpellData]:
	var result: Array[V2SpellData] = []

	var light := V2SpellData.new()
	light.id = "v2_spell_restoring_light"
	light.school_branch = "sacred"
	light.mana_cost = 4.0
	light.cooldown_turns = 0
	light.cast_range = 2
	light.heal_amount = 8.0
	result.append(light)

	var aegis := V2SpellData.new()
	aegis.id = "v2_spell_sacred_aegis"
	aegis.school_branch = "sacred"
	aegis.mana_cost = 6.0
	aegis.cooldown_turns = 2
	aegis.cast_range = 2
	aegis.defense_bonus = 0.35
	aegis.duration = 1
	aegis.status_polarity = V2SpellData.StatusPolarity.BENEFICIAL
	aegis.status_dispellable = true
	result.append(aegis)

	var wave := V2SpellData.new()
	wave.id = "v2_spell_healing_wave"
	wave.school_branch = "sacred"
	wave.mana_cost = 9.0
	wave.cooldown_turns = 3
	wave.cast_range = 3
	wave.heal_amount = 6.0
	wave.splash_radius = 1
	result.append(wave)

	var miracle := V2SpellData.new()
	miracle.id = "v2_spell_miracle"
	miracle.school_branch = "sacred"
	miracle.mana_cost = 16.0
	miracle.cooldown_turns = 5
	miracle.cast_range = 3
	miracle.heal_to_full = true
	result.append(miracle)

	var flame := V2SpellData.new()
	flame.id = "v2_spell_infernal_flame"
	flame.school_branch = "infernal"
	flame.target_mode = V2SpellData.TargetMode.HOSTILE_UNIT
	flame.mana_cost = 5.0
	flame.cooldown_turns = 0
	flame.cast_range = 3
	flame.damage_amount = 6.0
	result.append(flame)

	var devouring := V2SpellData.new()
	devouring.id = "v2_spell_devouring_fire"
	devouring.school_branch = "infernal"
	devouring.target_mode = V2SpellData.TargetMode.HOSTILE_UNIT
	devouring.mana_cost = 8.0
	devouring.cooldown_turns = 2
	devouring.cast_range = 3
	devouring.damage_amount = 8.0
	devouring.low_hp_threshold = 0.5
	devouring.low_hp_damage_bonus = 0.5
	result.append(devouring)

	var blast := V2SpellData.new()
	blast.id = "v2_spell_infernal_blast"
	blast.school_branch = "infernal"
	blast.target_mode = V2SpellData.TargetMode.HOSTILE_UNIT
	blast.mana_cost = 11.0
	blast.cooldown_turns = 3
	blast.cast_range = 3
	blast.damage_amount = 5.0
	blast.splash_radius = 1
	result.append(blast)

	var damnation := V2SpellData.new()
	damnation.id = "v2_spell_damnation"
	damnation.school_branch = "infernal"
	damnation.target_mode = V2SpellData.TargetMode.HOSTILE_UNIT
	damnation.mana_cost = 18.0
	damnation.cooldown_turns = 5
	damnation.cast_range = 4
	damnation.damage_amount = 15.0
	result.append(damnation)

	# Fase 19 — Necromancia: invocação (EMPTY_TILE + summon_unit_id), cura só de undead (required_target_trait) e
	# buff de Ataque só em retinue. Nenhum causa dano mágico. O custo de comando vem do UnitData invocado.
	var raise_dead := V2SpellData.new()
	raise_dead.id = "v2_spell_raise_dead"
	raise_dead.school_branch = "necromancy"
	raise_dead.target_mode = V2SpellData.TargetMode.EMPTY_TILE
	raise_dead.mana_cost = 7.0
	raise_dead.cooldown_turns = 2
	raise_dead.cast_range = 2
	raise_dead.summon_unit_id = "v2_unit_skeleton_host"
	result.append(raise_dead)

	var mend := V2SpellData.new()
	mend.id = "v2_spell_mend_undead"
	mend.school_branch = "necromancy"
	mend.mana_cost = 6.0
	mend.cooldown_turns = 1
	mend.cast_range = 3
	mend.heal_amount = 8.0
	mend.required_target_trait = UnitData.TRAIT_UNDEAD
	result.append(mend)

	var macabre := V2SpellData.new()
	macabre.id = "v2_spell_macabre_command"
	macabre.school_branch = "necromancy"
	macabre.mana_cost = 7.0
	macabre.cooldown_turns = 2
	macabre.cast_range = 3
	macabre.attack_bonus = 0.4
	macabre.duration = 1
	macabre.required_target_trait = UnitData.TRAIT_RETINUE
	macabre.status_polarity = V2SpellData.StatusPolarity.BENEFICIAL
	macabre.status_dispellable = true
	result.append(macabre)

	var legion := V2SpellData.new()
	legion.id = "v2_spell_raise_legion"
	legion.school_branch = "necromancy"
	legion.target_mode = V2SpellData.TargetMode.EMPTY_TILE
	legion.mana_cost = 15.0
	legion.cooldown_turns = 4
	legion.cast_range = 2
	legion.summon_unit_id = "v2_unit_macabre_host"
	result.append(legion)

	# Fase 20 — Druidismo: modificação FÍSICA persistente de terreno (V2TerrainRuntime), sem dano, cura, status ou dono.
	# Os números do terreno vêm de V2TerrainModificationDatabase; aqui só qual modificação, alvo, área e custo.
	var grow := V2SpellData.new()
	grow.id = "v2_spell_grow_grove"
	grow.school_branch = "druidism"
	grow.target_mode = V2SpellData.TargetMode.EMPTY_TILE
	grow.mana_cost = 6.0
	grow.cooldown_turns = 1
	grow.cast_range = 3
	grow.terrain_modification_id = "v2_terrain_dense_grove"
	result.append(grow)

	var restore := V2SpellData.new()
	restore.id = "v2_spell_restore_terrain"
	restore.school_branch = "druidism"
	restore.target_mode = V2SpellData.TargetMode.TILE
	restore.mana_cost = 5.0
	restore.cooldown_turns = 1
	restore.cast_range = 3
	restore.requires_existing_terrain_modification = true
	restore.remove_terrain_modification = true
	result.append(restore)

	var raise_ground := V2SpellData.new()
	raise_ground.id = "v2_spell_raise_ground"
	raise_ground.school_branch = "druidism"
	raise_ground.target_mode = V2SpellData.TargetMode.EMPTY_TILE
	raise_ground.mana_cost = 9.0
	raise_ground.cooldown_turns = 3
	raise_ground.cast_range = 3
	raise_ground.terrain_modification_id = "v2_terrain_raised_ground"
	result.append(raise_ground)

	var awaken := V2SpellData.new()
	awaken.id = "v2_spell_awaken_forest"
	awaken.school_branch = "druidism"
	awaken.target_mode = V2SpellData.TargetMode.EMPTY_TILE
	awaken.mana_cost = 16.0
	awaken.cooldown_turns = 5
	awaken.cast_range = 4
	awaken.terrain_modification_id = "v2_terrain_dense_grove"
	awaken.splash_radius = 1
	result.append(awaken)

	# Fase 21 — Arcanismo: mobilidade e utilidade mágicas. Toda semântica vem destes campos;
	# V2MagicRuntime/V2PortalSystem não conhecem ids ou nomes da Escola.
	var arcane_step := V2SpellData.new()
	arcane_step.id = "v2_spell_arcane_step"
	arcane_step.school_branch = "arcanism"
	arcane_step.target_mode = V2SpellData.TargetMode.EMPTY_TILE
	arcane_step.mana_cost = 6.0
	arcane_step.cooldown_turns = 2
	arcane_step.cast_range = 4
	arcane_step.teleport_caster = true
	result.append(arcane_step)

	var silence := V2SpellData.new()
	silence.id = "v2_spell_silence"
	silence.school_branch = "arcanism"
	silence.target_mode = V2SpellData.TargetMode.HOSTILE_UNIT
	silence.mana_cost = 8.0
	silence.cooldown_turns = 3
	silence.cast_range = 3
	silence.duration = 1
	silence.required_target_trait = UnitData.TRAIT_CASTER
	silence.requires_v2_caster_target = true
	silence.status_polarity = V2SpellData.StatusPolarity.HARMFUL
	silence.status_dispellable = true
	silence.silences_spellcasting = true
	result.append(silence)

	var dispel := V2SpellData.new()
	dispel.id = "v2_spell_dispel"
	dispel.school_branch = "arcanism"
	dispel.target_mode = V2SpellData.TargetMode.TILE
	dispel.mana_cost = 7.0
	dispel.cooldown_turns = 2
	dispel.cast_range = 3
	dispel.dispel_at_tile = true
	result.append(dispel)

	var portal := V2SpellData.new()
	portal.id = "v2_spell_veil_portal"
	portal.school_branch = "arcanism"
	portal.target_mode = V2SpellData.TargetMode.EMPTY_TILE
	portal.mana_cost = 18.0
	portal.cooldown_turns = 5
	portal.cast_range = 6
	portal.creates_portal_pair = true
	result.append(portal)

	# Fase 22 — Elementalismo: quatro feitiços TILE que materializam uma zona
	# ambiental temporária. Os efeitos e a duração vivem no banco de zonas.
	var mist := V2SpellData.new()
	mist.id = "v2_spell_dense_mist"
	mist.school_branch = "elementalism"
	mist.target_mode = V2SpellData.TargetMode.TILE
	mist.mana_cost = 6.0
	mist.cooldown_turns = 2
	mist.cast_range = 4
	mist.splash_radius = 1
	mist.environmental_zone_id = "v2_zone_dense_mist"
	result.append(mist)

	var gale := V2SpellData.new()
	gale.id = "v2_spell_gale"
	gale.school_branch = "elementalism"
	gale.target_mode = V2SpellData.TargetMode.TILE
	gale.mana_cost = 8.0
	gale.cooldown_turns = 2
	gale.cast_range = 4
	gale.splash_radius = 1
	gale.environmental_zone_id = "v2_zone_gale"
	result.append(gale)

	var storm := V2SpellData.new()
	storm.id = "v2_spell_lightning_storm"
	storm.school_branch = "elementalism"
	storm.target_mode = V2SpellData.TargetMode.TILE
	storm.mana_cost = 12.0
	storm.cooldown_turns = 3
	storm.cast_range = 4
	storm.splash_radius = 1
	storm.environmental_zone_id = "v2_zone_lightning_storm"
	result.append(storm)

	var cataclysm := V2SpellData.new()
	cataclysm.id = "v2_spell_elemental_cataclysm"
	cataclysm.school_branch = "elementalism"
	cataclysm.target_mode = V2SpellData.TargetMode.TILE
	cataclysm.mana_cost = 20.0
	cataclysm.cooldown_turns = 5
	cataclysm.cast_range = 5
	cataclysm.splash_radius = 2
	cataclysm.environmental_zone_id = "v2_zone_elemental_cataclysm"
	result.append(cataclysm)

	return result

static func _ensure_built() -> void:
	if not _by_id.is_empty():
		return
	var all := _build_all()
	for spell in all:
		_by_id[spell.id] = spell
		if spell.defense_bonus > 0.0:
			_defensive.append(spell)
		if spell.attack_bonus > 0.0:
			_offensive.append(spell)
		if spell.applies_status():
			_status.append(spell)
	# Ordem por Escola = a ordem dos nós de pesquisa (N4..N7), nunca a de Dictionary.
	for spell in all:
		if not _by_school.has(spell.school_branch):
			_by_school[spell.school_branch] = [] as Array[V2SpellData]
	for school in _by_school:
		var ordered: Array[V2SpellData] = []
		for spell in all:
			if spell.school_branch == school:
				ordered.append(spell)
		ordered.sort_custom(func(a: V2SpellData, b: V2SpellData) -> bool: return _tier_of(a) < _tier_of(b))
		_by_school[school] = ordered

static func _tier_of(spell: V2SpellData) -> int:
	var node := V2ResearchDatabase.node_for_unlock_id(spell.id)
	return node.tier if node != null else 99

static func get_spell(id: String) -> V2SpellData:
	_ensure_built()
	return _by_id.get(id, null)

static func is_spell(id: String) -> bool:
	return get_spell(id) != null

static func all_spells() -> Array[V2SpellData]:
	_ensure_built()
	var result: Array[V2SpellData] = []
	for spell in _by_id.values():
		result.append(spell)
	return result

## Os feitiços de uma Escola, na ordem dos nós (N4, N5, N6, N7). [] para Escola sem conteúdo.
static func for_school(school: String) -> Array[V2SpellData]:
	_ensure_built()
	var result: Array[V2SpellData] = []
	result.assign(_by_school.get(school, []))
	return result

## Feitiços que deixam um estado de Defesa (lista curta em cache, lida por CombatResolver.predict).
static func defensive_spells() -> Array[V2SpellData]:
	_ensure_built()
	return _defensive

## Fase 19: feitiços que deixam um estado de Ataque (lista curta em cache, lida por CombatResolver.predict).
static func offensive_spells() -> Array[V2SpellData]:
	_ensure_built()
	return _offensive

## Fase 19: todo feitiço com estado temporário (Defesa OU Ataque) — expiração, marcador e linhas de UI.
static func status_spells() -> Array[V2SpellData]:
	_ensure_built()
	return _status

## Texto do efeito montado do DADO (tooltip de pesquisa e botão), nunca um texto fixo por id.
static func effect_text(spell: V2SpellData) -> String:
	var parts: Array[String] = []
	var own_target := UnitData.own_target_phrase(spell.required_target_trait)
	var modification := V2TerrainModificationDatabase.get_modification(spell.terrain_modification_id)
	var environmental := V2EnvironmentalZoneDatabase.get_zone(spell.environmental_zone_id)
	if environmental != null:
		var area := "raio %d" % spell.splash_radius
		parts.append("Cria %s em %s por %d rodadas globais: %s Gasta %d Mana; alcance %d." % [environmental.display_name, area, environmental.duration_rounds, " ".join(V2EnvironmentalZoneDatabase.effect_lines(environmental)), int(spell.mana_cost), spell.cast_range])
	elif spell.teleport_caster:
		parts.append("Teleporta o próprio conjurador para um destino legal, vazio e visível a até %d tiles. Gasta %d Mana; não calcula caminho nem captura cidade." % [spell.cast_range, int(spell.mana_cost)])
	elif spell.silences_spellcasting:
		parts.append("Gasta %d Mana para impedir um conjurador hostil a até %d tiles de lançar feitiços até o início do próximo turno do dono." % [int(spell.mana_cost), spell.cast_range])
	elif spell.dispel_at_tile:
		parts.append("Gasta %d Mana para dissipar efeitos mágicos elegíveis num tile a até %d tiles: status, Portais e zonas ambientais. Modificações físicas de terreno permanecem." % [int(spell.mana_cost), spell.cast_range])
	elif spell.creates_portal_pair:
		parts.append("Cria um par persistente entre a posição do conjurador e um tile livre e visível a até %d tiles. Gasta %d Mana; substitui o par anterior da mesma Escola." % [spell.cast_range, int(spell.mana_cost)])
	elif modification != null and spell.splash_radius > 0:
		parts.append("Cria %s no tile livre alvo (a até %d tiles) e nos tiles adjacentes elegíveis (raio %d): %s. Gasta %d Mana." % [modification.display_name, spell.cast_range, spell.splash_radius, V2TerrainModificationDatabase.effect_summary(modification), int(spell.mana_cost)])
	elif modification != null:
		parts.append("Cria %s: %s. Gasta %d Mana; tile livre e visível a até %d tiles." % [modification.display_name, V2TerrainModificationDatabase.effect_summary(modification), int(spell.mana_cost), spell.cast_range])
	elif spell.remove_terrain_modification:
		parts.append("Remove uma modificação física de terreno do tile (a até %d tiles, inclusive o do conjurador). Gasta %d Mana." % [spell.cast_range, int(spell.mana_cost)])
	elif spell.is_summon():
		var summoned := UnitDatabase.create_unit(spell.summon_unit_id)
		var command := " (Comando %d)" % summoned.retinue_command_cost if summoned.is_retinue() else ""
		parts.append("Invoca uma %s%s. Gasta %d Mana; tile livre e visível a até %d tiles. Persiste e só age a partir do próximo turno do dono." % [summoned.unit_name, command, int(spell.mana_cost), spell.cast_range])
	elif spell.damage_amount > 0.0 and spell.splash_radius > 0:
		parts.append("Gasta %d Mana para causar %s de dano mágico ao alvo (a até %d tiles) e a inimigos adjacentes." % [int(spell.mana_cost), _number(spell.damage_amount), spell.cast_range])
	elif spell.damage_amount > 0.0:
		var damage_text := "Gasta %d Mana para causar %s de dano mágico a uma unidade hostil a até %d tiles." % [int(spell.mana_cost), _number(spell.damage_amount), spell.cast_range]
		if spell.low_hp_threshold > 0.0 and spell.low_hp_damage_bonus > 0.0:
			damage_text += " +%d%% contra alvos com %d%% de Vida ou menos." % [int(round(spell.low_hp_damage_bonus * 100.0)), int(round(spell.low_hp_threshold * 100.0))]
		parts.append(damage_text)
	elif spell.heal_to_full:
		parts.append("Gasta %d Mana para restaurar %s a até %d tiles ao máximo de Vida." % [int(spell.mana_cost), own_target, spell.cast_range])
	elif spell.heal_amount > 0.0 and spell.splash_radius > 0:
		parts.append("Gasta %d Mana para curar %d de Vida do alvo (a até %d tiles) e das unidades próprias adjacentes." % [int(spell.mana_cost), int(spell.heal_amount), spell.cast_range])
	elif spell.heal_amount > 0.0:
		parts.append("Gasta %d Mana para curar %d de Vida de %s a até %d tiles." % [int(spell.mana_cost), int(spell.heal_amount), own_target, spell.cast_range])
	if spell.defense_bonus > 0.0:
		parts.append("Gasta %d Mana para conceder +%d%% Defesa a %s a até %d tiles, até o início do próximo turno do dono." % [int(spell.mana_cost), int(round(spell.defense_bonus * 100.0)), own_target, spell.cast_range])
	if spell.attack_bonus > 0.0:
		parts.append("Gasta %d Mana para conceder +%d%% Ataque a %s a até %d tiles, até o início do próximo turno do dono." % [int(spell.mana_cost), int(round(spell.attack_bonus * 100.0)), own_target, spell.cast_range])
	if spell.cooldown_turns > 0:
		parts.append("Recarga %d." % spell.cooldown_turns)
	return " ".join(parts)

static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, round(value)) else ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

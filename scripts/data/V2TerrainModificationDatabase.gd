class_name V2TerrainModificationDatabase
extends RefCounted

## Registro das MODIFICAÇÕES FÍSICAS de terreno V2 (Aetherlands V2, Fase 20) — mesmo padrão de V2SpellDatabase: cache
## montado uma vez, consultas O(1) por id. Só DADO: as regras moram em V2TerrainRuntime. BALANCE PLACEHOLDER.

static var _by_id: Dictionary = {}

static func _build_all() -> Array[V2TerrainModificationData]:
	var result: Array[V2TerrainModificationData] = []

	var grove := V2TerrainModificationData.new()
	grove.id = "v2_terrain_dense_grove"
	grove.display_name = "Bosque Denso"
	grove.movement_cost_delta = 1
	grove.defense_multiplier = 1.20
	grove.visual_kind = "grove"
	result.append(grove)

	var raised := V2TerrainModificationData.new()
	raised.id = "v2_terrain_raised_ground"
	raised.display_name = "Terreno Elevado"
	raised.movement_cost_delta = 2
	raised.defense_multiplier = 1.35
	raised.visual_kind = "raised"
	result.append(raised)

	return result

static func _ensure_built() -> void:
	if not _by_id.is_empty():
		return
	for modification in _build_all():
		_by_id[modification.id] = modification

static func get_modification(id: String) -> V2TerrainModificationData:
	_ensure_built()
	return _by_id.get(id, null)

static func is_modification(id: String) -> bool:
	return get_modification(id) != null

static func all_modifications() -> Array[V2TerrainModificationData]:
	_ensure_built()
	var result: Array[V2TerrainModificationData] = []
	for modification in _by_id.values():
		result.append(modification)
	return result

## Custo extra de movimento de `id` ("" ou desconhecido = 0). Caminho quente do pathfinding: um lookup.
static func movement_delta(id: String) -> int:
	var modification := get_modification(id)
	return modification.movement_cost_delta if modification != null else 0

## "+1 custo de movimento e +20% Defesa física" — montado do dado (tooltip, inspetor, feitiço).
static func effect_summary(modification: V2TerrainModificationData) -> String:
	return "+%d custo de movimento e +%d%% Defesa física" % [modification.movement_cost_delta, int(round((modification.defense_multiplier - 1.0) * 100.0))]

class_name V2EnvironmentalZoneDatabase
extends RefCounted

## Registro estático das zonas ambientais V2. Só conteúdo; as regras vivem em
## V2EnvironmentalZoneSystem e os feitiços apontam para estes ids por dado.

static var _by_id: Dictionary = {}

static func _zone(id: String, name: String, vision: int, ranged: float, damage: float, visual: String) -> V2EnvironmentalZoneData:
	var zone := V2EnvironmentalZoneData.new()
	zone.id = id
	zone.display_name = name
	zone.duration_rounds = 2
	zone.vision_delta = vision
	zone.physical_ranged_attack_multiplier = ranged
	zone.round_tick_magic_damage = damage
	zone.dispellable = true
	zone.visual_kind = visual
	return zone

static func _ensure_built() -> void:
	if not _by_id.is_empty():
		return
	for zone in [
		_zone("v2_zone_dense_mist", "Névoa Cerrada", -2, 1.0, 0.0, "mist"),
		_zone("v2_zone_gale", "Vendaval", 0, 0.70, 0.0, "gale"),
		_zone("v2_zone_lightning_storm", "Tempestade Elétrica", 0, 1.0, 4.0, "storm"),
		_zone("v2_zone_elemental_cataclysm", "Cataclismo Elemental", -1, 0.80, 5.0, "cataclysm"),
	]:
		_by_id[zone.id] = zone

static func get_zone(id: String) -> V2EnvironmentalZoneData:
	_ensure_built()
	return _by_id.get(id, null)

static func all_zones() -> Array[V2EnvironmentalZoneData]:
	_ensure_built()
	var result: Array[V2EnvironmentalZoneData] = []
	for zone in _by_id.values():
		result.append(zone)
	result.sort_custom(func(a: V2EnvironmentalZoneData, b: V2EnvironmentalZoneData) -> bool: return a.id < b.id)
	return result

static func effect_lines(zone: V2EnvironmentalZoneData) -> Array[String]:
	var lines: Array[String] = []
	if zone == null:
		return lines
	if zone.vision_delta != 0:
		lines.append("Visão de unidades: %d (mínimo 1)." % zone.vision_delta)
	if not is_equal_approx(zone.physical_ranged_attack_multiplier, 1.0):
		lines.append("Ataques físicos à distância: ×%.2f." % zone.physical_ranged_attack_multiplier)
	if zone.round_tick_magic_damage > 0.0:
		lines.append("Dano mágico ambiental por rodada: %d." % int(zone.round_tick_magic_damage))
	return lines

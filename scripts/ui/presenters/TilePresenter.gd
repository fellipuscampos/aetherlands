class_name TilePresenter
extends RefCounted

## View model do Tile Context (Fase 30 / UI-3). Reusa `TileInspector.inspect` —
## a mesma consulta com névoa usada desde a Task 23 — e só reorganiza o resultado
## em camadas: TERRENO (base), MODIFICAÇÃO (Druidismo, camada física), AMBIENTE
## (zona temporária), CARACTERÍSTICAS (recurso/melhoria, Portal, covil, obra) e
## OCUPANTES (cidade/unidade, que viram seletor de contexto). Nada é consultado
## além do que o observador já vê.

static func build(hex_grid: HexGrid, coord: Vector2i, viewer: PlayerData) -> Dictionary:
	if hex_grid == null or not hex_grid.tiles.has(coord):
		return {"valid": false}
	var inspection := TileInspector.inspect(hex_grid, coord, viewer)
	var tile := hex_grid.get_tile(coord)
	var state: String = inspection.state
	var view := {
		"valid": true,
		"coord": coord,
		"state": state,
		"inspection": inspection,
		"title": "Região inexplorada" if state == TileInspector.STATE_UNSEEN else tile.display_name,
		"subtitle": "(%d, %d)" % [coord.x, coord.y],
		"terrain": {},
		"modification": {},
		"environment": {},
		"features": [],
		"occupants": [],
		"remembered": state == TileInspector.STATE_EXPLORED,
	}
	if state == TileInspector.STATE_UNSEEN:
		return view
	var territory := hex_grid.city_owning_tile(coord)
	var territory_name := ""
	if territory != null and (territory.owner_player == viewer or state == TileInspector.STATE_VISIBLE):
		territory_name = territory.city_name
	view.terrain = {
		"name": tile.display_name,
		"movement_cost": tile.movement_cost,
		"defense_pct": int(round(tile.defense_bonus * 100.0)),
		"territory": territory_name,
		"tooltip": AETooltip.compose("Terreno-base: %s" % tile.display_name, "Custo de movimento %d · Defesa física +%d%%." % [tile.movement_cost, int(round(tile.defense_bonus * 100.0))], ["Território: %s" % territory_name] if territory_name != "" else []),
	}
	if state == TileInspector.STATE_VISIBLE:
		var modification := V2TerrainRuntime.modification_at(hex_grid, coord)
		if modification != null:
			view.modification = {
				"name": modification.display_name,
				"movement_delta": modification.movement_cost_delta,
				"defense_pct": int(round((modification.defense_multiplier - 1.0) * 100.0)),
				"tooltip": AETooltip.compose(modification.display_name, "Modificação física do terreno (Druidismo), sobreposta ao terreno-base.", V2TerrainRuntime.inspector_lines(hex_grid, coord).slice(1)),
			}
	for entry in inspection.entries:
		match String(entry.kind):
			TileInspector.KIND_CITY:
				view.occupants.append({"kind": "city", "key": entry.key, "title": entry.title, "tag": entry.tag})
			TileInspector.KIND_UNIT, TileInspector.KIND_MONSTER, TileInspector.KIND_BOSS:
				view.occupants.append({"kind": "unit", "key": entry.key, "title": entry.title, "tag": entry.tag})
			TileInspector.KIND_MAGIC:
				if String(entry.key) == "magic:environment":
					view.environment = {"title": entry.title, "lines": entry.lines, "tooltip": AETooltip.compose(entry.title, "Camada ambiental temporária (não altera o terreno).", entry.lines)}
				else:
					view.features.append(_feature(entry, "portal"))
			TileInspector.KIND_RESOURCE:
				view.features.append(_feature(entry, "resource"))
			TileInspector.KIND_LAIR:
				view.features.append(_feature(entry, "lair"))
			TileInspector.KIND_BUILDING, TileInspector.KIND_SITE:
				view.features.append(_feature(entry, "building"))
	return view

static func _feature(entry: Dictionary, kind: String) -> Dictionary:
	var lines: Array = entry.lines
	return {
		"kind": kind,
		"title": entry.title,
		"lines": lines,
		"tooltip": AETooltip.compose(entry.title, "", lines),
	}

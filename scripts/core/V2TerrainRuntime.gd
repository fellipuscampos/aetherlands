class_name V2TerrainRuntime
extends RefCounted

## MODIFICAÇÃO FÍSICA PERSISTENTE DE TERRENO V2 (Aetherlands V2, Fase 20) — fundação GENÉRICA. Nenhuma Escola,
## feitiço ou modificação concreta é citada aqui: números e visuais vêm de V2TerrainModificationData.
##
## ESTADO: `HexGrid.v2_terrain_modifications` (coord -> id), no MAPA — nunca na cidade (o tile pode ser neutro ou mudar
## de dono) e nunca em unidade. Um dicionário por coordenada (o mesmo padrão de `terrain_changes`) em vez de um campo
## no HexTileData porque a magia V1 (transform_tile_terrain) SUBSTITUI o objeto do tile e apagaria o campo. Lookup O(1).
##
## O TERRENO-BASE NUNCA É REESCRITO: `terrain_type`, bioma, recurso e rendimento continuam os da geração do mapa
## (map gen, saves antigos, fundação e a V1 transitória seguem lendo o mesmo dado). A modificação é uma camada.
##
## SEM DONO: depois de criada é FÍSICA — qualquer civilização sofre o custo, recebe a Defesa, ocupa, anexa ou captura o
## tile. Nada de criador salvo. No máximo UMA por tile. Só some por um efeito que a remova explicitamente ou por uma
## construção física permanente que ocupe o tile (clear_for_construction).

## Texto dos motivos (uma frase cada).
const REASON_INVALID := "Tile inválido."
const REASON_TERRAIN := "O terreno não comporta esta modificação."
const REASON_CITY := "Não é possível modificar o terreno de uma cidade."
const REASON_STRUCTURE := "O terreno está ocupado por uma estrutura permanente."
const REASON_ALREADY := "Este tile já possui uma modificação de terreno."
const REASON_NONE := "Não há modificação de terreno para restaurar."

# --- Consultas O(1) ------------------------------------------------------------------------------------

static func modification_id_at(grid: HexGrid, coord: Vector2i) -> String:
	if grid == null or grid.v2_terrain_modifications.is_empty():
		return ""
	return String(grid.v2_terrain_modifications.get(coord, ""))

static func modification_at(grid: HexGrid, coord: Vector2i) -> V2TerrainModificationData:
	var id := modification_id_at(grid, coord)
	return V2TerrainModificationDatabase.get_modification(id) if id != "" else null

static func has_modification(grid: HexGrid, coord: Vector2i) -> bool:
	return modification_id_at(grid, coord) != ""

## Custo extra de ENTRAR em `coord` (0 sem modificação). A regra de QUEM paga é a do terreno-base, em
## HexGrid.terrain_step_cost — quem ignora o custo do terreno (voo, custo plano) ignora este também.
static func movement_cost_delta(grid: HexGrid, coord: Vector2i) -> int:
	var id := modification_id_at(grid, coord)
	return V2TerrainModificationDatabase.movement_delta(id) if id != "" else 0

## Fator na Defesa física de quem defende em `coord` (1.0 sem modificação) — UM fator em CombatResolver.predict.
static func defense_multiplier_at(grid: HexGrid, coord: Vector2i) -> float:
	var modification := modification_at(grid, coord)
	return modification.defense_multiplier if modification != null else 1.0

# --- Elegibilidade -------------------------------------------------------------------------------------------

## Existe uma estrutura permanente no tile (prédio, melhoria de recurso V2, covil)? A cidade é tratada à parte.
static func has_permanent_structure(grid: HexGrid, coord: Vector2i) -> bool:
	if grid.buildings_by_coord.has(coord) or grid.lairs_by_coord.has(coord) or grid.improvement_markers_by_coord.has(coord):
		return true
	for city in grid.cities_by_coord.values():
		if city.resource_improvements.has(coord):
			return true
	return false

## "" se `modification_id` pode ser criada em `coord` agora; senão o motivo. Unidade no tile NÃO impede (quem exige tile
## vazio é o modo de mira do feitiço). Recurso natural bruto pode ficar (o rendimento não muda).
static func application_reason(grid: HexGrid, coord: Vector2i, modification_id: String) -> String:
	var modification := V2TerrainModificationDatabase.get_modification(modification_id)
	var tile: HexTileData = grid.get_tile(coord) if grid != null else null
	if modification == null or tile == null:
		return REASON_INVALID
	if modification.requires_ground_passable and tile.blocks_land_units():
		return REASON_TERRAIN
	if grid.get_city_at(coord) != null:
		return REASON_CITY
	if has_permanent_structure(grid, coord):
		return REASON_STRUCTURE
	if has_modification(grid, coord):
		return REASON_ALREADY
	return ""

static func removal_reason(grid: HexGrid, coord: Vector2i) -> String:
	if grid == null or grid.get_tile(coord) == null:
		return REASON_INVALID
	return "" if has_modification(grid, coord) else REASON_NONE

# --- Mutação (eventos discretos) ------------------------------------------------------------------------------

## Cria a modificação. false SEM ALTERAR NADA se inelegível. Atualiza só o marcador daquele tile.
static func apply(grid: HexGrid, coord: Vector2i, modification_id: String) -> bool:
	if application_reason(grid, coord, modification_id) != "":
		return false
	grid.v2_terrain_modifications[coord] = modification_id
	grid.refresh_terrain_modification_marker(coord)
	return true

## Remove a modificação (se houver). Não toca terreno-base, recurso, melhoria, unidade nem estado mágico.
static func remove(grid: HexGrid, coord: Vector2i) -> bool:
	if not has_modification(grid, coord):
		return false
	grid.v2_terrain_modifications.erase(coord)
	grid.refresh_terrain_modification_marker(coord)
	return true

## Uma estrutura física permanente vai OCUPAR `coord` AGORA (prédio colocado, melhoria de recurso, centro de cidade):
## limpa a modificação sem custo, sem Druida e sem Mana. Chamado só no momento em que a colocação acontece de fato.
static func clear_for_construction(grid: HexGrid, coord: Vector2i) -> void:
	if grid != null and has_modification(grid, coord):
		remove(grid, coord)

## Restauração de save: grava sem revalidar a jogabilidade (o estado já foi validado quando criado), mas ignora
## id desconhecido/tile inexistente (fail-safe: uma entrada corrompida nunca derruba o save).
static func restore(grid: HexGrid, coord: Vector2i, modification_id: String) -> bool:
	if grid == null or grid.get_tile(coord) == null or not V2TerrainModificationDatabase.is_modification(modification_id):
		return false
	grid.v2_terrain_modifications[coord] = modification_id
	grid.refresh_terrain_modification_marker(coord)
	return true

# --- Texto de UI ------------------------------------------------------------------------------------------------

## Linhas do inspetor ("Modificação: Bosque Denso", custo, Defesa); [] sem modificação.
static func inspector_lines(grid: HexGrid, coord: Vector2i) -> Array[String]:
	var lines: Array[String] = []
	var modification := modification_at(grid, coord)
	if modification == null:
		return lines
	lines.append("Modificação: %s" % modification.display_name)
	lines.append("Movimento: +%d custo" % modification.movement_cost_delta)
	lines.append("Defesa física: +%d%%" % int(round((modification.defense_multiplier - 1.0) * 100.0)))
	return lines

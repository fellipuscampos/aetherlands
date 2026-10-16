class_name DebugSummon
extends RefCounted

## FERRAMENTA DE DEBUG (2026-10-13) — pedido do usuário: "adicione no debug a opção de eu simplesmente invocar qualquer
## um que eu quiser e quantos eu quiser pra eu poder testar" (as Grandes Manifestações). Cria unidades DIRETO no mapa,
## sem passar por produção: não cobra PP nem Mana, não exige a construção ritual nem a pesquisa da Escola e ignora o
## limite de uma Manifestação por Escola (V2ManifestationSystem.MAX_PER_SCHOOL) — de propósito, para pôr várias lado a
## lado. Só é alcançada pelo painel de Debug (build de debug); nenhuma regra do jogo chama isto.
##
## As unidades nascem nos tiles livres mais próximos de `origin` (terra firme, sem unidade, sem cidade), em ordem de
## distância — determinístico para o mesmo mapa.

const MAX_COUNT := 50
const SEARCH_RADIUS := 16
const MAGE_KINDS: Array[String] = [
	"v2_unit_sacred_cleric", "v2_unit_infernal_warlock", "v2_unit_necromancer",
	"v2_unit_druid", "v2_unit_arcanist", "v2_unit_elementalist",
]

static func mage_kinds() -> Array[String]:
	return MAGE_KINDS.duplicate()

## Explicit debug preparation: unlock only this school's four spells, not other branches.
static func prepare_magic_test(unit: Unit) -> bool:
	if not is_instance_valid(unit) or not V2MagicRuntime.is_v2_caster(unit) or unit.owner_player==null or unit.hp<=0:
		return false
	var owner := unit.owner_player
	var was_silent: bool = owner.v2_research.get_meta("debug_silent_research",false)
	owner.v2_research.set_meta("debug_silent_research",true)
	for tier in range(2,8):
		var id := "v2_magic_%s_%d" % [unit.unit_data.v2_magic_school,tier]
		if not owner.v2_research.is_completed(id): owner.v2_research.complete_research(id)
	if was_silent: owner.v2_research.set_meta("debug_silent_research",true)
	else: owner.v2_research.remove_meta("debug_silent_research")
	return renew_magic_test(unit)

static func renew_magic_test(unit: Unit) -> bool:
	if not is_instance_valid(unit) or not V2MagicRuntime.is_v2_caster(unit) or unit.owner_player==null or unit.hp<=0:
		return false
	unit.owner_player.mana = maxf(unit.owner_player.mana,1000.0)
	unit.magic_cooldowns.clear()
	unit.movement_left = UnitStatusEffects.adjusted_movement(unit,unit.unit_data.movement_points)
	return true

## Os tipos que o painel oferece: as seis Grandes Manifestações, na ordem do cadastro.
static func summonable_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		kinds.append(String(kind))
	return kinds

## Invoca `count` unidades `kind` para `owner` em volta de `origin`. Devolve as que nasceram (menos que `count` se não
## houver tile livre no raio de busca; vazio se o pedido não faz sentido).
static func summon(grid: HexGrid, owner: PlayerData, kind: String, count: int, origin: Vector2i) -> Array[Unit]:
	var summoned: Array[Unit] = []
	if grid == null or owner == null or count <= 0 or not UnitDatabase.is_known_kind(kind):
		return summoned # um id desconhecido viraria um Guarda genérico (dado padrão de create_unit)
	for coord in free_tiles_near(grid, origin, mini(count, MAX_COUNT)):
		var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
		if unit != null:
			summoned.append(unit)
	if not summoned.is_empty():
		grid.recompute_fog(owner)
	return summoned

## Até `count` tiles livres em volta de `origin`, do mais perto para o mais longe.
static func free_tiles_near(grid: HexGrid, origin: Vector2i, count: int) -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	if grid == null or count <= 0:
		return free
	var candidates := HexMetrics.coords_within(origin, SEARCH_RADIUS) # não inclui o centro
	candidates.append(origin)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := HexMetrics.axial_distance(origin, a)
		var db := HexMetrics.axial_distance(origin, b)
		return da < db if da != db else (a.x < b.x if a.x != b.x else a.y < b.y))
	for coord in candidates:
		if is_free_tile(grid, coord):
			free.append(coord)
			if free.size() >= count:
				break
	return free

## Terra firme, sem unidade e sem cidade (na água a unidade nasceria embarcada; numa cidade, viraria guarnição).
static func is_free_tile(grid: HexGrid, coord: Vector2i) -> bool:
	var tile := grid.get_tile(coord)
	if tile == null or tile.blocks_land_units() or tile.can_be_embarked_on():
		return false
	return grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null

## Onde invocar quando o jogador não disse: ao lado da unidade selecionada; sem seleção, da primeira cidade dele; sem
## cidade, da primeira unidade; sem nada, do meio do mapa.
static func default_origin(grid: HexGrid, owner: PlayerData, selected: Unit = null) -> Vector2i:
	if selected != null and is_instance_valid(selected):
		return selected.coord
	if owner != null:
		for city in owner.cities:
			if is_instance_valid(city):
				return city.coord
		for unit in owner.units:
			if is_instance_valid(unit):
				return unit.coord
	if grid != null and not grid.tiles.is_empty():
		var sum := Vector2.ZERO
		for coord in grid.tiles:
			sum += Vector2(coord)
		return Vector2i((sum / float(grid.tiles.size())).round())
	return Vector2i.ZERO

class_name HexGrid
extends Node3D

## Gera um mapa hexagonal 3D real (prismas gerados por codigo, sem depender
## de modelos externos) usando MultiMeshInstance3D para desenhar milhares
## de tiles com uma unica draw call. Tambem administra ocupacao (unidades e
## cidades por tile), pathfinding de movimento e fog of war.

const NEIGHBOR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

enum Visibility { UNSEEN, EXPLORED, VISIBLE }

const ROCK_BASE_COLOR := Color(0.55, 0.55, 0.58)

@export var map_radius: int = 12
@export var hex_size: float = 1.0

var tiles: Dictionary = {} # Vector2i(q, r) -> HexTileData
var units_by_coord: Dictionary = {} # Vector2i -> Unit
var cities_by_coord: Dictionary = {} # Vector2i -> City
var buildings_by_coord: Dictionary = {} # Vector2i -> Building (predio POSICIONADO, ver Building.gd)
var visibility: Dictionary = {} # Vector2i -> Visibility
var map_seed: int = 0 # guardado pra Salvar/Carregar recriar o mesmo terreno

## Coords onde um Covil de Monstro foi colocado NESTA geracao de mapa (ver
## _spawn_monster_lairs) — 100% deterministico pela map_seed, igual
## terreno/recursos. SaveManager usa isso pra saber quais covis ja foram
## limpos (sem unidade viva la) e evitar respawna-los ao carregar.
var lair_coords: Array[Vector2i] = []

var _hex_mesh: ArrayMesh
var _tree_mesh: ArrayMesh
var _rock_mesh: ArrayMesh
var _multimesh_instance: MultiMeshInstance3D
var _props_tree_instance: MultiMeshInstance3D
var _props_rock_instance: MultiMeshInstance3D
var _ground_body: StaticBody3D
var _selection_marker: MeshInstance3D
var _noise := FastNoiseLite.new()
var _coord_to_index: Dictionary = {}
var _tree_coord_to_index: Dictionary = {}
var _rock_coord_to_index: Dictionary = {}
var _units_root: Node3D
var _cities_root: Node3D
var _buildings_root: Node3D
var _city_territory_coords: Array[Vector2i] = [] # tiles da cidade atualmente vista na HUD — ver show_city_territory()
var _selection_time := 0.0
var _hover_label: Label3D
var _last_came_from: Dictionary = {} # Vector2i -> Vector2i, da ultima compute_reachable
var _moisture_noise := FastNoiseLite.new() # biomas: seco x umido
var _temp_jitter_noise := FastNoiseLite.new() # biomas: variacao local na faixa de temperatura
var _resource_noise := FastNoiseLite.new() # onde recursos estrategicos/luxo aparecem

func _ready() -> void:
	add_to_group("hex_grid")
	_hex_mesh = _build_hex_prism_mesh(hex_size)
	_tree_mesh = _build_tree_mesh()
	_rock_mesh = _build_hex_prism_mesh(hex_size * 0.32)
	_build_selection_marker()
	_build_hover_label()

	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)

	_cities_root = Node3D.new()
	_cities_root.name = "Cities"
	add_child(_cities_root)

	_buildings_root = Node3D.new()
	_buildings_root.name = "Buildings"
	add_child(_buildings_root)

func _process(delta: float) -> void:
	if _selection_marker.visible:
		_selection_time += delta
		_selection_marker.rotate_y(delta * 1.2)
		var pulse = 1.0 + sin(_selection_time * 3.0) * 0.08
		_selection_marker.scale = Vector3.ONE * pulse

## seed_value < 0 sorteia uma semente nova (jogo novo); Salvar/Carregar passa
## a semente guardada pra recriar exatamente o mesmo terreno.
func generate_map(radius: int, seed_value: int = -1) -> void:
	map_radius = radius
	_clear_entities()
	tiles.clear()
	visibility.clear()
	map_seed = seed_value if seed_value >= 0 else randi()
	_noise.seed = map_seed
	_noise.frequency = 0.15
	# Offsets fixos (nao randi() de novo) pra continuar 100% deterministico a
	# partir da mesma map_seed — Salvar/Carregar depende disso pra recriar o
	# terreno identico so com a semente (ver SaveManager.gd).
	_moisture_noise.seed = map_seed + 1000
	_moisture_noise.frequency = 0.12
	_temp_jitter_noise.seed = map_seed + 2000
	_temp_jitter_noise.frequency = 0.35
	_resource_noise.seed = map_seed + 3000
	_resource_noise.frequency = 0.8 # alta: recursos "espalhados", nao em blocos grandes

	for q in range(-radius, radius + 1):
		var r1 = max(-radius, -q - radius)
		var r2 = min(radius, -q + radius)
		for r in range(r1, r2 + 1):
			var coord = Vector2i(q, r)
			tiles[coord] = _generate_tile_data(coord)

	_rebuild_multimesh()
	_spawn_monster_lairs()

## Libera unidades/cidades/predios de uma partida anterior antes de gerar
## um mapa novo (usado ao reiniciar) — sem isso os nodes antigos ficariam
## orfaos dentro de _units_root/_cities_root/_buildings_root, ainda
## ocupando tiles do mapa novo.
func _clear_entities() -> void:
	if _units_root:
		for child in _units_root.get_children():
			child.queue_free()
	if _cities_root:
		for child in _cities_root.get_children():
			child.queue_free()
	if _buildings_root:
		for child in _buildings_root.get_children():
			child.queue_free()
	units_by_coord.clear()
	cities_by_coord.clear()
	buildings_by_coord.clear()
	_city_territory_coords.clear()

func get_tile(coord: Vector2i) -> HexTileData:
	return tiles.get(coord, null)

func get_unit_at(coord: Vector2i) -> Unit:
	return units_by_coord.get(coord, null)

func get_city_at(coord: Vector2i) -> City:
	return cities_by_coord.get(coord, null)

func get_building_at(coord: Vector2i) -> Building:
	return buildings_by_coord.get(coord, null)

## Algum predio (de qualquer cidade) ja ocupa este tile? Mesmo padrao de
## is_tile_worked() — evita duas cidades vizinhas (ou a mesma cidade duas
## vezes) disputarem o mesmo tile pra construcao.
func is_tile_building_site(coord: Vector2i) -> bool:
	return buildings_by_coord.has(coord)

## Cria o modelo 3D do predio no tile escolhido pelo jogador (ver
## City.pending_building_coord/SelectionManager.start_building_placement)
## — chamado por GameManager quando City.process_turn() reporta um predio
## concluido com coord valido.
func place_building(coord: Vector2i, building_id: String, owner_player: PlayerData) -> Building:
	var building := Building.new()
	_buildings_root.add_child(building)
	building.setup(building_id, coord, owner_player)
	building.position = world_for_coord(coord)
	buildings_by_coord[coord] = building
	return building

func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in NEIGHBOR_DIRS:
		var n = coord + dir
		if tiles.has(n):
			result.append(n)
	return result

func world_for_coord(coord: Vector2i) -> Vector3:
	var pos = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	var data = get_tile(coord)
	pos.y = data.base_height if data else 0.0
	return pos

## Dijkstra simplificado (custo por terreno) limitado ao total de pontos de
## movimento. Tiles ocupados por qualquer unidade, ou por uma cidade
## inimiga, bloqueiam a passagem — cidade inimiga so se resolve atacando
## (SelectionManager/RivalAI), nunca "andando" pra dentro dela. `flies`
## (Grifo, UnitData.flies) ignora custo de terreno (sempre 1 por tile) E
## atravessa oceano — voa por cima de tudo, so unidade/cidade inimiga
## ainda bloqueiam.
func compute_reachable(start: Vector2i, movement_points: float, owner: PlayerData, flies: bool = false) -> Dictionary:
	var cost_so_far := {start: 0.0}
	var came_from := {start: start}
	var frontier: Array[Vector2i] = [start]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		for n in get_neighbors(current):
			if get_unit_at(n) != null:
				continue
			var city_here = get_city_at(n)
			if city_here != null and city_here.owner_player != owner:
				continue
			var terrain: HexTileData = get_tile(n)
			if not flies and terrain.terrain_type == HexTileData.TerrainType.OCEAN:
				continue
			var step_cost = 1.0 if flies else terrain.movement_cost
			var new_cost = cost_so_far[current] + step_cost
			if new_cost <= movement_points and (not cost_so_far.has(n) or new_cost < cost_so_far[n]):
				cost_so_far[n] = new_cost
				came_from[n] = current
				frontier.append(n)
	cost_so_far.erase(start)
	_last_came_from = came_from
	return cost_so_far

## Reconstroi a sequencia de tiles ate `end`, usando os predecessores
## calculados na ULTIMA chamada de compute_reachable — so faz sentido
## logo em seguida, pro mesmo `start` (SelectionManager garante isso: so
## chama isso enquanto um unit continua selecionado).
func reconstruct_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not _last_came_from.has(end):
		return path
	var current = end
	var safety = 0
	while current != start and safety < 64:
		path.append(current)
		current = _last_came_from.get(current, start)
		safety += 1
	path.reverse()
	return path

func spawn_unit(coord: Vector2i, unit_data: UnitData, player: PlayerData) -> Unit:
	var unit := Unit.new()
	_units_root.add_child(unit)
	unit.setup(unit_data, player, coord)
	unit.position = world_for_coord(coord)
	units_by_coord[coord] = unit
	player.units.append(unit)
	return unit

## O estado LOGICO (coord/ocupacao/movimento) muda na hora — so a posicao
## visual desliza suavemente ate la. Fog, combate e IA usam unit.coord, que
## ja esta correto mesmo enquanto a animacao ainda esta rolando.
func move_unit(unit: Unit, dest: Vector2i, cost: float) -> void:
	units_by_coord.erase(unit.coord)
	unit.coord = dest
	unit.movement_left = max(0.0, unit.movement_left - cost)
	var target_pos = world_for_coord(dest)
	unit.slide_to(target_pos)
	units_by_coord[dest] = unit

func remove_unit(unit: Unit) -> void:
	units_by_coord.erase(unit.coord)
	if unit.owner_player:
		unit.owner_player.units.erase(unit)
	unit.queue_free()

## silent=true evita o toast "Cidade fundada" — usado por SaveManager ao
## reconstruir cidades de uma partida carregada (nao e um evento novo).
func found_city(coord: Vector2i, player: PlayerData, city_name: String, silent: bool = false) -> City:
	var city := City.new()
	_cities_root.add_child(city)
	city.setup(player, coord, city_name)
	city.position = world_for_coord(coord)
	cities_by_coord[coord] = city
	player.cities.append(city)
	city.auto_assign_worked_tiles(self)
	if player == GameManager.human_player and not silent:
		EventBus.notify.emit("Cidade fundada: %s" % city_name, "city")
	return city

## Algum OUTRO cidadao (de qualquer cidade, exceto `excluding`) ja trabalha
## este tile? Evita duas cidades vizinhas disputarem o mesmo tile — ver
## City.auto_assign_worked_tiles/toggle_worked_tile.
func is_tile_worked(coord: Vector2i, excluding: City = null) -> bool:
	for city in cities_by_coord.values():
		if city == excluding:
			continue
		if coord in city.worked_tiles:
			return true
	return false

## Cidade sem defensor pode ser tomada por uma unidade inimiga adjacente que
## ataque — sem isso, uma capital indefesa e inconquistavel na pratica.
func capture_city(city: City, new_owner: PlayerData) -> void:
	var old_owner = city.owner_player
	var city_display_name = city.city_name
	if old_owner:
		old_owner.cities.erase(city)
	city.change_owner(new_owner)
	new_owner.cities.append(city)
	if new_owner == GameManager.human_player:
		EventBus.notify.emit("Voce capturou %s!" % city_display_name, "city")
	elif old_owner == GameManager.human_player:
		EventBus.notify.emit("Voce perdeu %s para o inimigo!" % city_display_name, "city")

func show_selection_marker(coord: Vector2i) -> void:
	if not tiles.has(coord):
		_selection_marker.visible = false
		return
	var data: HexTileData = tiles[coord]
	var pos = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	pos.y = data.base_height + 0.05
	_selection_marker.position = pos
	_selection_marker.visible = true

## Uniao do raio de visao de todas as unidades/cidades de um jogador —
## calculo puro, sem tocar no dict `visibility` (que e so pra render/fog do
## jogador humano). Usado tambem pela IA rival pra saber o que ela realmente
## enxerga agora (ver RivalAI.take_turn), em vez de "trapacear" com
## conhecimento global do mapa.
func compute_visible_tiles(player: PlayerData) -> Dictionary:
	var visible_now := {}
	for unit in player.units:
		_mark_visible(unit.coord, unit.unit_data.vision_range, visible_now)
	for city in player.cities:
		_mark_visible(city.coord, 2, visible_now)
	return visible_now

## Recalcula quais tiles estao visiveis para um jogador (uniao do raio de
## visao de todas as unidades e cidades dele). Tiles que ja foram vistos mas
## nao estao mais visiveis ficam "explorados" (escurecidos, nao pretos).
func recompute_fog(player: PlayerData) -> void:
	var visible_now := compute_visible_tiles(player)

	for coord in tiles.keys():
		if visible_now.has(coord):
			visibility[coord] = Visibility.VISIBLE
		elif visibility.get(coord, Visibility.UNSEEN) == Visibility.VISIBLE:
			visibility[coord] = Visibility.EXPLORED

	_apply_fog_colors()
	_apply_fog_to_entities(player)
	EventBus.fog_updated.emit()

## Unidades/cidades/predios do proprio jogador sempre aparecem; os de
## outros so aparecem em tiles ATUALMENTE visiveis (nao basta ja ter
## explorado).
func _apply_fog_to_entities(player: PlayerData) -> void:
	for coord in units_by_coord.keys():
		var unit: Unit = units_by_coord[coord]
		if unit.owner_player == player:
			unit.visible = true
		else:
			unit.visible = visibility.get(coord, Visibility.UNSEEN) == Visibility.VISIBLE
	for coord in cities_by_coord.keys():
		var city: City = cities_by_coord[coord]
		if city.owner_player == player:
			city.visible = true
		else:
			city.visible = visibility.get(coord, Visibility.UNSEEN) == Visibility.VISIBLE
	for coord in buildings_by_coord.keys():
		var building: Building = buildings_by_coord[coord]
		if building.owner_player == player:
			building.visible = true
		else:
			building.visible = visibility.get(coord, Visibility.UNSEEN) == Visibility.VISIBLE

## path_coords (opcional) e a previa do trajeto ate o tile sob o mouse —
## pintado por cima do verde/vermelho, tipo o preview de movimento do
## Civilization. buildable_coords (opcional) e usado so durante o
## posicionamento de um predio (SelectionManager.start_building_placement).
## Chamado de novo a cada frame que o hover muda, entao sempre reaplica
## fog+reachable+attackable do zero antes de tingir o caminho (senao o
## amarelo do hover anterior "grudaria" nos tiles).
func set_highlight(reachable_coords: Array, attackable_coords: Array, path_coords: Array = [], buildable_coords: Array = []) -> void:
	_apply_fog_colors()
	if _multimesh_instance == null:
		return
	var mm = _multimesh_instance.multimesh
	for coord in reachable_coords:
		if _coord_to_index.has(coord):
			var idx = _coord_to_index[coord]
			var base_color = mm.get_instance_color(idx)
			mm.set_instance_color(idx, base_color.lerp(Color(0.3, 1.0, 0.3), 0.5))
	for coord in attackable_coords:
		if _coord_to_index.has(coord):
			var idx = _coord_to_index[coord]
			var base_color = mm.get_instance_color(idx)
			mm.set_instance_color(idx, base_color.lerp(Color(1.0, 0.2, 0.2), 0.5))
	for coord in path_coords:
		if _coord_to_index.has(coord):
			var idx = _coord_to_index[coord]
			var base_color = mm.get_instance_color(idx)
			mm.set_instance_color(idx, base_color.lerp(Color(1.0, 1.0, 0.4), 0.7))
	for coord in buildable_coords:
		if _coord_to_index.has(coord):
			var idx = _coord_to_index[coord]
			var base_color = mm.get_instance_color(idx)
			mm.set_instance_color(idx, base_color.lerp(Color(0.35, 0.7, 1.0), 0.55))

func clear_highlight() -> void:
	_apply_fog_colors()
	hide_hover_label()

## Tinge sutilmente os tiles do "territorio" da cidade sendo vista na HUD
## (a propria cidade + vizinhos — mesmo raio de worked_tiles/predios) com
## um dourado suave, pra o limite da cidade ficar visivel no mapa em vez
## de so existir como numero no painel. Persiste enquanto a cidade estiver
## selecionada — reaplicado toda vez que _apply_fog_colors() roda (inclusive
## por baixo de destaques de unidade/posicionamento de predio), porque
## essa e a unica funcao que TODOS os outros highlights chamam antes de
## pintar por cima.
func show_city_territory(coords: Array) -> void:
	_city_territory_coords.assign(coords)
	_apply_fog_colors()

func clear_city_territory() -> void:
	_city_territory_coords.clear()
	_apply_fog_colors()

## Mostra um rotulo flutuante sobre um tile — usado pra indicar custo de
## movimento (previa de trajeto) ou "ATACAR" ao passar o mouse sobre um
## alvo no alcance, sem precisar abrir nenhum painel.
func show_hover_label(coord: Vector2i, text: String, color: Color) -> void:
	if not tiles.has(coord):
		hide_hover_label()
		return
	var pos = world_for_coord(coord)
	pos.y += 0.7
	_hover_label.position = pos
	_hover_label.text = text
	_hover_label.modulate = color
	_hover_label.visible = true

func hide_hover_label() -> void:
	_hover_label.visible = false

func _apply_fog_colors() -> void:
	if _multimesh_instance == null:
		return
	var mm = _multimesh_instance.multimesh
	for coord in tiles.keys():
		var data: HexTileData = tiles[coord]
		var idx = _coord_to_index[coord]
		var vis = visibility.get(coord, Visibility.UNSEEN)
		var color = data.color
		match vis:
			Visibility.UNSEEN:
				color = Color(0.02, 0.02, 0.02)
			Visibility.EXPLORED:
				color = color * 0.45
			Visibility.VISIBLE:
				pass
		if coord in _city_territory_coords:
			color = color.lerp(Color(1.0, 0.85, 0.3), 0.35)
		mm.set_instance_color(idx, color)

	_apply_prop_fog()

## Mesma logica de escurecimento do terreno, aplicada as arvores/pedras —
## sem isso elas ficariam sempre visiveis mesmo em tiles nunca explorados.
func _apply_prop_fog() -> void:
	if _props_tree_instance:
		_tint_props(_props_tree_instance.multimesh, _tree_coord_to_index, Color.WHITE)
	if _props_rock_instance:
		_tint_props(_props_rock_instance.multimesh, _rock_coord_to_index, ROCK_BASE_COLOR)

func _tint_props(mm: MultiMesh, coord_to_index: Dictionary, base_color: Color) -> void:
	for coord in coord_to_index.keys():
		var idx = coord_to_index[coord]
		var vis = visibility.get(coord, Visibility.UNSEEN)
		var color = base_color
		match vis:
			Visibility.UNSEEN:
				color = Color(0.02, 0.02, 0.02)
			Visibility.EXPLORED:
				color = base_color * 0.45
			Visibility.VISIBLE:
				pass
		mm.set_instance_color(idx, color)

## Todos os tiles a ate `range_dist` passos de `center` (sem contar o
## proprio center). Usado pro alcance de ataque de unidades a distancia
## (arqueiro) — pra unidades corpo-a-corpo (range 1) devolve exatamente os
## vizinhos imediatos, entao substitui get_neighbors() sem quebrar nada.
func tiles_in_range(center: Vector2i, range_dist: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited = {center: 0}
	var frontier: Array[Vector2i] = [center]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		if visited[current] >= range_dist:
			continue
		for n in get_neighbors(current):
			if not visited.has(n):
				visited[n] = visited[current] + 1
				result.append(n)
				frontier.append(n)
	return result

func _mark_visible(center: Vector2i, vision_range: int, out: Dictionary) -> void:
	out[center] = true
	var visited = {center: 0}
	var frontier: Array[Vector2i] = [center]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		if visited[current] >= vision_range:
			continue
		for n in get_neighbors(current):
			if not visited.has(n):
				visited[n] = visited[current] + 1
				out[n] = true
				frontier.append(n)

## Elevacao continua decidindo agua/colina/montanha (igual antes); o que
## mudou e o que preenche a faixa "plana" do meio — antes era so uma unica
## progressao arido->verde->floresta pela elevacao, agora usa um segundo
## eixo de umidade (ruido) cruzado com temperatura por latitude (baseada em
## r, que corresponde a distancia norte-sul no mundo — ver
## HexMetrics.axial_to_world) pra dar biomas de verdade tipo Civilization
## (deserto/savana/selva no "equador", tundra/taiga/neve nos "polos").
func _generate_tile_data(coord: Vector2i) -> HexTileData:
	var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	var elevation = _noise.get_noise_2d(world.x, world.z)

	var data: HexTileData
	if elevation < -0.35:
		data = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	elif elevation >= 0.65:
		data = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	elif elevation >= 0.45:
		data = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	else:
		var moisture = (_moisture_noise.get_noise_2d(world.x, world.z) + 1.0) * 0.5
		var temperature = _temperature_for(coord)
		data = TerrainDatabase.create_tile(_pick_biome(temperature, moisture))

	_maybe_assign_resource(data, coord, world)
	return data

## Medido empiricamente rodando FastNoiseLite.get_noise_2d() com a mesma
## frequencia (0.8) por milhares de amostras: 0.7 (o "chute" original) so
## passa em ~0.03% dos tiles — na pratica, recurso nunca aparecia. 0.3 da
## os ~12% pretendidos (confirmado em varias sementes diferentes).
const RESOURCE_NOISE_THRESHOLD := 0.3

## Recurso estrategico/luxo esparso: so em tiles de terra firme cujo bioma
## e elegivel (ResourceDatabase.ELIGIBILITY), e so onde o ruido de recurso
## passa do limiar (~15% dos tiles elegiveis, dando uma distribuicao rala
## em vez de blocos grandes). Qual recurso exato usa um hash deterministico
## da coordenada em vez de mais uma chamada de ruido — mais barato e ainda
## 100% reproduzivel pela map_seed.
func _maybe_assign_resource(data: HexTileData, coord: Vector2i, world: Vector3) -> void:
	var eligible = ResourceDatabase.eligible_resources(data.terrain_type)
	if eligible.is_empty():
		return
	if _resource_noise.get_noise_2d(world.x, world.z) <= RESOURCE_NOISE_THRESHOLD:
		return
	var index = int(abs(coord.x * 31 + coord.y * 17)) % eligible.size()
	data.resource = eligible[index]

const LAIR_MIN_DISTANCE_FROM_CENTER_FRACTION := 0.25 # nunca perto do (0,0), onde o humano comeca

## Espalha alguns Covis de Monstro (Unit neutra, owner_player == null — ver
## MonsterDatabase) em terra firme longe do centro do mapa, deterministico
## pela map_seed. Poucos e espalhados de proposito: e um risco/recompensa
## opcional pra explorar, nao um obstaculo constante — 4X de fantasia de
## verdade (Age of Wonders, Endless Legend) usa isso pra dar uma razao pra
## sair da capital antes mesmo de encontrar um rival.
func _spawn_monster_lairs() -> void:
	lair_coords.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 4000 # canal proprio, mesmo padrao dos outros noises (seed+N)

	var min_dist = float(map_radius) * LAIR_MIN_DISTANCE_FROM_CENTER_FRACTION
	var all_coords: Array = tiles.keys()
	all_coords.sort() # ordem deterministica antes de sortear, independente de ordem de insercao
	var candidates: Array[Vector2i] = []
	for c in all_coords:
		var data: HexTileData = tiles[c]
		if data.terrain_type != HexTileData.TerrainType.OCEAN and HexMetrics.axial_distance(c, Vector2i.ZERO) >= min_dist:
			candidates.append(c)

	var lair_count = max(1, map_radius / 4)
	for i in range(lair_count):
		if candidates.is_empty():
			break
		var idx = rng.randi_range(0, candidates.size() - 1)
		var coord: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		lair_coords.append(coord)
		_spawn_monster_at(coord, MonsterDatabase.random_kind(rng))

func _spawn_monster_at(coord: Vector2i, kind: String) -> void:
	var unit := Unit.new()
	_units_root.add_child(unit)
	unit.setup(MonsterDatabase.create_monster(kind), null, coord)
	unit.position = world_for_coord(coord)
	units_by_coord[coord] = unit

## 0 = polo (frio), 1 = equador (quente) — gradiente linear pela distancia
## de `r` ao "equador" (r=0), com uma pitada de ruido pra a fronteira entre
## faixas climaticas nao ficar reta demais.
func _temperature_for(coord: Vector2i) -> float:
	var latitude = float(abs(coord.y)) / float(max(map_radius, 1))
	var jitter = _temp_jitter_noise.get_noise_2d(float(coord.x), float(coord.y)) * 0.15
	return clamp(1.0 - latitude + jitter, 0.0, 1.0)

## Biomas "planos" cruzando temperatura x umidade (tipo diagrama de
## Whittaker simplificado). Faixas de elevacao (oceano/colina/montanha) ja
## foram resolvidas antes de chegar aqui.
func _pick_biome(temperature: float, moisture: float) -> int:
	if temperature < 0.2:
		return HexTileData.TerrainType.SNOW
	elif temperature < 0.4:
		return HexTileData.TerrainType.TUNDRA if moisture < 0.5 else HexTileData.TerrainType.TAIGA
	elif temperature < 0.7:
		if moisture < 0.3:
			return HexTileData.TerrainType.PLAINS
		elif moisture < 0.65:
			return HexTileData.TerrainType.GRASSLAND
		else:
			return HexTileData.TerrainType.FOREST
	else:
		if moisture < 0.3:
			return HexTileData.TerrainType.DESERT
		elif moisture < 0.6:
			return HexTileData.TerrainType.SAVANNA
		else:
			return HexTileData.TerrainType.JUNGLE

func _rebuild_multimesh() -> void:
	if _multimesh_instance:
		_multimesh_instance.queue_free()
	if _ground_body:
		_ground_body.queue_free()

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _hex_mesh
	multimesh.instance_count = tiles.size()

	_coord_to_index.clear()
	var i := 0
	for coord in tiles.keys():
		var data: HexTileData = tiles[coord]
		var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
		world.y = data.base_height
		multimesh.set_instance_transform(i, Transform3D(Basis(), world))
		multimesh.set_instance_color(i, data.color)
		# r = e agua (pro shader animar ondinhas), g = fase aleatoria por tile
		var is_water = 1.0 if data.terrain_type == HexTileData.TerrainType.OCEAN else 0.0
		multimesh.set_instance_custom_data(i, Color(is_water, randf(), 0.0, 0.0))
		_coord_to_index[coord] = i
		i += 1

	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.multimesh = multimesh
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/terrain.gdshader")
	const ALBEDO_TEX_PATH := "res://assets/textures/terrain/ground_albedo.jpg"
	if ResourceLoader.exists(ALBEDO_TEX_PATH):
		material.set_shader_parameter("albedo_tex", load(ALBEDO_TEX_PATH))
	else:
		# Sem a textura (CC0, ambientCG "Ground037") o shader ainda funciona
		# — texture() com sampler vazio devolve preto, entao zeramos a
		# influencia dela pra nao pintar o mapa inteiro de preto.
		material.set_shader_parameter("texture_strength", 0.0)
	_multimesh_instance.material_override = material
	add_child(_multimesh_instance)

	_rebuild_props()

	var bounds = float(map_radius) * hex_size * 2.0 + hex_size
	var plane_shape := BoxShape3D.new()
	plane_shape.size = Vector3(bounds * 2.0, 0.2, bounds * 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = plane_shape
	_ground_body = StaticBody3D.new()
	_ground_body.add_child(collision)
	_ground_body.position = Vector3(0, -0.15, 0)
	add_child(_ground_body)

func _build_hex_prism_mesh(size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top_corners: Array[Vector3] = []
	for i in range(6):
		top_corners.append(HexMetrics.corner(size, i))

	for i in range(6):
		var c1 = top_corners[i]
		var c2 = top_corners[(i + 1) % 6]
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(c2)
		st.set_normal(Vector3.UP)
		st.add_vertex(c1)

	var bottom_offset = Vector3(0.0, -size * 0.4, 0.0)
	for i in range(6):
		var c1 = top_corners[i]
		var c2 = top_corners[(i + 1) % 6]
		var side_normal = ((c1 + c2) * 0.5).normalized()
		var b1 = c1 + bottom_offset
		var b2 = c2 + bottom_offset

		st.set_normal(side_normal)
		st.add_vertex(c1)
		st.set_normal(side_normal)
		st.add_vertex(b1)
		st.set_normal(side_normal)
		st.add_vertex(c2)

		st.set_normal(side_normal)
		st.add_vertex(c2)
		st.set_normal(side_normal)
		st.add_vertex(b1)
		st.set_normal(side_normal)
		st.add_vertex(b2)

	return st.commit()

## Espalha arvores procedurais em tiles de floresta e pedras em tiles de
## colina/montanha, dando cara de bioma ao mapa sem precisar de assets. As
## instancias reaproveitam MultiMesh (como o terreno) e respeitam a mesma
## neblina de guerra via _apply_prop_fog().
func _rebuild_props() -> void:
	if _props_tree_instance:
		_props_tree_instance.queue_free()
		_props_tree_instance = null
	if _props_rock_instance:
		_props_rock_instance.queue_free()
		_props_rock_instance = null

	const TREE_TERRAINS := [
		HexTileData.TerrainType.FOREST, HexTileData.TerrainType.TAIGA, HexTileData.TerrainType.JUNGLE,
	]
	var tree_coords: Array[Vector2i] = []
	var rock_coords: Array[Vector2i] = []
	for coord in tiles.keys():
		var data: HexTileData = tiles[coord]
		if data.terrain_type in TREE_TERRAINS:
			tree_coords.append(coord)
		elif data.terrain_type == HexTileData.TerrainType.HILLS or data.terrain_type == HexTileData.TerrainType.MOUNTAINS:
			if randf() < 0.6:
				rock_coords.append(coord)

	_tree_coord_to_index.clear()
	if tree_coords.size() > 0:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _tree_mesh
		mm.instance_count = tree_coords.size()
		for i in range(tree_coords.size()):
			var coord = tree_coords[i]
			var pos = world_for_coord(coord)
			pos.x += randf_range(-0.25, 0.25)
			pos.z += randf_range(-0.25, 0.25)
			var basis = Basis(Vector3.UP, randf() * TAU)
			mm.set_instance_transform(i, Transform3D(basis, pos))
			mm.set_instance_color(i, Color.WHITE)
			_tree_coord_to_index[coord] = i
		_props_tree_instance = MultiMeshInstance3D.new()
		_props_tree_instance.multimesh = mm
		var tree_mat := StandardMaterial3D.new()
		tree_mat.vertex_color_use_as_albedo = true
		tree_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_props_tree_instance.material_override = tree_mat
		add_child(_props_tree_instance)

	_rock_coord_to_index.clear()
	if rock_coords.size() > 0:
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.use_colors = true
		mm2.mesh = _rock_mesh
		mm2.instance_count = rock_coords.size()
		for i in range(rock_coords.size()):
			var coord = rock_coords[i]
			var pos = world_for_coord(coord)
			# A mesh da pedra (prisma hexagonal reduzido) tem o topo em y=0
			# local; sem levantar a origem, o topo ficaria coplanar ao topo
			# do terreno e "brigaria" com ele no render (z-fighting). Erguer
			# pela altura do prisma faz a base dela encostar no chao.
			pos.y += hex_size * 0.32 * 0.4
			pos.x += randf_range(-0.3, 0.3)
			pos.z += randf_range(-0.3, 0.3)
			var basis = Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * randf_range(0.7, 1.3))
			mm2.set_instance_transform(i, Transform3D(basis, pos))
			mm2.set_instance_color(i, ROCK_BASE_COLOR)
			_rock_coord_to_index[coord] = i
		_props_rock_instance = MultiMeshInstance3D.new()
		_props_rock_instance.multimesh = mm2
		var rock_mat := StandardMaterial3D.new()
		rock_mat.vertex_color_use_as_albedo = true
		rock_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_props_rock_instance.material_override = rock_mat
		add_child(_props_rock_instance)

func _build_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var trunk_color = Color(0.36, 0.24, 0.14)
	var trunk_radius = 0.06
	var trunk_height = 0.3
	for i in range(5):
		var a1 = TAU * float(i) / 5.0
		var a2 = TAU * float(i + 1) / 5.0
		var c1 = Vector3(cos(a1) * trunk_radius, 0.0, sin(a1) * trunk_radius)
		var c2 = Vector3(cos(a2) * trunk_radius, 0.0, sin(a2) * trunk_radius)
		var top1 = c1 + Vector3(0.0, trunk_height, 0.0)
		var top2 = c2 + Vector3(0.0, trunk_height, 0.0)
		var normal = ((c1 + c2) * 0.5).normalized()
		for v in [c1, top1, c2, c2, top1, top2]:
			st.set_color(trunk_color)
			st.set_normal(normal)
			st.add_vertex(v)

	var foliage_color = Color(0.16, 0.38, 0.18)
	_add_cone(st, Vector3(0.0, 0.22, 0.0), 0.28, 0.55, foliage_color, 7)
	_add_cone(st, Vector3(0.0, 0.48, 0.0), 0.18, 0.4, foliage_color, 7)

	return st.commit()

func _add_cone(st: SurfaceTool, base_center: Vector3, radius: float, height: float, color: Color, sides: int) -> void:
	var apex = base_center + Vector3(0.0, height, 0.0)
	for i in range(sides):
		var a1 = TAU * float(i) / float(sides)
		var a2 = TAU * float(i + 1) / float(sides)
		var p1 = base_center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var p2 = base_center + Vector3(cos(a2) * radius, 0.0, sin(a2) * radius)
		var mid = (p1 + p2) * 0.5
		var normal = mid - base_center
		normal.y = height * 0.5
		normal = normal.normalized()
		for v in [p1, apex, p2]:
			st.set_color(color)
			st.set_normal(normal)
			st.add_vertex(v)

## Numero de dano flutuante que sobe e some — sem isso, tomar dano so
## aparece como uma notificacao de texto no topo da tela, longe de onde a
## acao realmente aconteceu no mundo.
func spawn_damage_popup(coord: Vector2i, amount: float) -> void:
	var label := Label3D.new()
	label.text = "-%d" % int(round(amount))
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color(1.0, 0.35, 0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var pos = world_for_coord(coord)
	pos.y += 0.9
	pos.x += randf_range(-0.15, 0.15)
	label.position = pos
	add_child(label)

	# create_tween() exige HexGrid dentro da SceneTree (ex: testes GUT que
	# criam HexGrid isolado, sem add_child) — sem isso o jogo de verdade
	# nunca chama isto fora da arvore, mas evita quebrar o teste: so
	# descarta o popup sem animar em vez de crashar.
	if not is_inside_tree():
		label.queue_free()
		return

	var tween = create_tween()
	tween.tween_property(label, "position:y", pos.y + 0.7, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)

func _build_hover_label() -> void:
	_hover_label = Label3D.new()
	_hover_label.font_size = 34
	_hover_label.outline_size = 9
	_hover_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hover_label.no_depth_test = true
	_hover_label.visible = false
	add_child(_hover_label)

func _build_selection_marker() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = hex_size * 0.75
	torus.outer_radius = hex_size * 0.9
	_selection_marker = MeshInstance3D.new()
	_selection_marker.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.1)
	mat.emission_energy_multiplier = 1.5
	_selection_marker.material_override = mat
	_selection_marker.visible = false
	add_child(_selection_marker)

class_name City
extends Node3D

const FOOD_TO_GROW_BASE := 8.0

## Modelos do Kenney Castle Kit (CC0, ver assets/models/castle/LICENSE.txt).
## O pivo de tower-hexagon-base.glb ja fica no nivel do chao (padrao do
## kit pra encaixe sem frestas — a peca desce ate y=-1 local como
## base/soquete enterrado, entao NAO se desloca em Y, so se posiciona na
## origem). TOWER_LOCAL_TOP e a altura visivel acima do pivo (y=1.31 no
## bounding box do GLB), usada so pra saber onde apoiar a bandeira.
## O pivo de flag.glb fica no CENTRO vertical da peca (bounding box
## simetrico -1..1), por isso FLAG_LOCAL_HALF_HEIGHT=1.0 e usado pra
## erguer a base da bandeira ate encostar no topo da torre.
const TOWER_MODEL_PATH := "res://assets/models/castle/tower-hexagon-base.glb"
const FLAG_MODEL_PATH := "res://assets/models/castle/flag.glb"
const TOWER_SCALE := 0.4
const FLAG_SCALE := 0.25
const TOWER_LOCAL_TOP := 1.31
const FLAG_LOCAL_HALF_HEIGHT := 1.0

var owner_player: PlayerData
var coord: Vector2i
var city_name: String = "Cidade"
var population: int = 1
var stored_food: float = 0.0
var stored_production: float = 0.0
var production_item: String = "warrior" # "warrior" ou "settler"

## Cada ponto de populacao trabalha um tile vizinho (o tile da propria
## cidade e sempre contado de graca, fora desta lista — ver
## collect_yields()). Preenchido automaticamente ao fundar/crescer
## (auto_assign_worked_tiles, prioriza melhor rendimento), mas o jogador
## pode trocar via toggle_worked_tile() — da controle real sobre o que a
## cidade produz, em vez de somar todos os vizinhos sempre.
var worked_tiles: Array[Vector2i] = []

## Predios ja construidos (ver BuildingDatabase) — Dictionary id->true,
## mesmo padrao de researched_techs. Diferente de unidade, um predio nao
## "sai" da cidade ao completar, so fica valendo pra sempre (bonus em
## collect_yields()/CombatResolver.predict()).
var buildings: Dictionary = {}

## Onde cada predio construido foi POSICIONADO no mapa (id -> coord) — o
## jogador escolhe o tile ao encomendar o predio (ver
## SelectionManager.start_building_placement), do mesmo jeito que escolhe
## onde uma cidade nasce. HexGrid.place_building() usa isso pra saber onde
## desenhar o modelo 3D (Building.gd) quando a producao completa.
var building_coords: Dictionary = {}

## Sentinela "nenhum tile escolhido ainda" — Vector2i nao tem null, entao
## um valor bem fora do mapa serve de flag (mesmo padrao usado em
## SelectionManager._hovered_coord).
const NO_PENDING_COORD := Vector2i(999999, 999999)

## Tile escolhido pelo jogador pro predio que esta em producao AGORA (ver
## production_item) — setado no momento da escolha, consumido (vira uma
## entrada em building_coords) quando a producao completa em process_turn().
var pending_building_coord: Vector2i = NO_PENDING_COORD

var _name_label: Label3D

func setup(player: PlayerData, start_coord: Vector2i, new_city_name: String) -> void:
	owner_player = player
	coord = start_coord
	city_name = new_city_name
	_build_visual()

## Trocar de projeto zera o progresso acumulado, como na maioria dos 4X:
## evita "salvar" producao de um item pra completar outro instantaneamente.
func set_production(kind: String) -> void:
	if kind != production_item:
		production_item = kind
		stored_production = 0.0

## production_item pode ser um kind de unidade OU um id de predio
## (BuildingDatabase) — checa predio primeiro pra nao precisar de um
## segundo campo/fila de producao separada.
func production_cost() -> float:
	var building: BuildingData = BuildingDatabase.get_building(production_item)
	if building:
		return building.production_cost
	return UnitDatabase.create_unit(production_item).production_cost

## Limite de predios da cidade: cresce junto com a populacao (uma vila de
## populacao 1 nao tem gente/espaco pra sustentar Celeiro+Oficina+Mercado+
## Muralhas ao mesmo tempo) — da um motivo real pra cidade crescer alem de
## so render mais, e evita empilhar toda a lista de predios numa cidade
## que nunca saiu do tamanho inicial.
func max_building_slots() -> int:
	return population

func can_build(building_id: String) -> bool:
	if buildings.has(building_id):
		return false
	return buildings.size() < max_building_slots()

## Tile valido pra POSICIONAR um predio: precisa ser vizinho imediato da
## cidade (mesmo raio de worked_tiles — o "territorio" da cidade), terra
## firme, sem unidade/cidade em cima, e sem outro predio (desta cidade ou
## de qualquer outra, ver HexGrid.is_tile_building_site) ja la.
func is_valid_building_tile(target: Vector2i, hex_grid: HexGrid) -> bool:
	if not target in hex_grid.get_neighbors(coord):
		return false
	var data: HexTileData = hex_grid.get_tile(target)
	if data == null or data.terrain_type == HexTileData.TerrainType.OCEAN:
		return false
	if hex_grid.get_unit_at(target) != null or hex_grid.get_city_at(target) != null:
		return false
	if hex_grid.is_tile_building_site(target):
		return false
	return true

## Usado na conquista: a cidade muda de dono e reconstroi a visual com a
## cor da nova civilizacao. Progresso de producao e mantido de proposito.
func change_owner(new_owner: PlayerData) -> void:
	owner_player = new_owner
	for child in get_children():
		child.queue_free()
	_build_visual()

## Rendimento REAL de um tile pra esta cidade: dado cru do terreno + bonus
## de tecnologia do dono (TechDatabase.yield_bonus_for) + bonus de recurso
## estrategico/luxo do proprio tile (ResourceDatabase.yield_for). Usado por
## collect_yields(), _best_unassigned_neighbor() (senao o auto-assign
## sugeria uma planicie comum em vez de uma colina com ferro, so porque o
## bonus nao entrava na conta) e pela HUD (pra mostrar o numero que
## realmente vai contar, nao so o "cru" do terreno).
func effective_tile_yield(data: HexTileData) -> Dictionary:
	var researched = owner_player.researched_techs if owner_player else {}
	var tech_bonus = TechDatabase.yield_bonus_for(data.terrain_type, researched)
	var resource_bonus = ResourceDatabase.yield_for(data.resource)
	return {
		"food": data.food_yield + tech_bonus.food + resource_bonus.food,
		"production": data.production_yield + tech_bonus.production + resource_bonus.production,
		"gold": data.gold_yield + tech_bonus.gold + resource_bonus.gold,
	}

## Soma o rendimento efetivo do tile da cidade (sempre de graca) + so os
## tiles vizinhos atualmente TRABALHADOS (worked_tiles) — nao mais todo
## vizinho automaticamente. O multiplicador de dificuldade (so != 1.0 pra
## rivais, ver PlayerData.yield_multiplier) e aplicado no total final, nao
## por tile — mais barato e da o mesmo resultado.
func collect_yields(hex_grid: HexGrid) -> Dictionary:
	var totals = {"food": 0.0, "production": 0.0, "gold": 0.0}
	var coords: Array[Vector2i] = [coord]
	coords.append_array(worked_tiles)
	for c in coords:
		var data: HexTileData = hex_grid.get_tile(c)
		if data == null:
			continue
		var y = effective_tile_yield(data)
		totals.food += y.food
		totals.production += y.production
		totals.gold += y.gold
	var building_bonus = BuildingDatabase.total_bonus(buildings)
	totals.food += building_bonus.food
	totals.production += building_bonus.production
	totals.gold += building_bonus.gold
	var mult = owner_player.yield_multiplier if owner_player else 1.0
	totals.food *= mult
	totals.production *= mult
	totals.gold *= mult
	return totals

func process_turn(hex_grid: HexGrid) -> Dictionary:
	var yields = collect_yields(hex_grid)
	stored_food += yields.food
	stored_production += yields.production

	var grow_threshold = FOOD_TO_GROW_BASE * population
	if stored_food >= grow_threshold:
		stored_food -= grow_threshold
		population += 1
		auto_assign_worked_tiles(hex_grid)
		_refresh_label()

	var spawned_kind := ""
	var built_kind := ""
	var built_coord := NO_PENDING_COORD
	var cost = production_cost()
	if stored_production >= cost:
		stored_production -= cost
		var building: BuildingData = BuildingDatabase.get_building(production_item)
		if building:
			buildings[production_item] = true
			built_kind = production_item
			# pending_building_coord so fica vazio se algo chamou
			# set_production() direto (ex: testes) sem passar pelo fluxo de
			# posicionamento — o predio ainda conta pro bonus/limite, so
			# nao ganha modelo 3D no mapa.
			if pending_building_coord != NO_PENDING_COORD:
				building_coords[production_item] = pending_building_coord
				built_coord = pending_building_coord
			pending_building_coord = NO_PENDING_COORD
			# Sem isso a cidade tentaria "reconstruir" o mesmo predio pra
			# sempre — troca pro item mais basico em vez de deixar
			# producao futura ser desperdicada num predio que ja existe.
			production_item = "warrior"
		else:
			spawned_kind = production_item

	return {"gold": yields.gold, "spawn_unit_kind": spawned_kind, "built_kind": built_kind, "built_coord": built_coord}

## Preenche worked_tiles ate `population` com os melhores vizinhos livres
## (nem oceano, nem ja trabalhados por esta ou outra cidade). Chamado ao
## fundar a cidade (HexGrid.found_city) e sempre que a populacao cresce —
## mantem um padrao razoavel sem exigir que o jogador (ou a IA)
## microgerencie toda cidade manualmente.
func auto_assign_worked_tiles(hex_grid: HexGrid) -> void:
	while worked_tiles.size() < population:
		var best_coord = _best_unassigned_neighbor(hex_grid)
		if best_coord == null:
			break
		worked_tiles.append(best_coord)

func _best_unassigned_neighbor(hex_grid: HexGrid):
	var best_coord = null
	var best_score = -INF
	for n in hex_grid.get_neighbors(coord):
		if n in worked_tiles or hex_grid.is_tile_worked(n, self):
			continue
		var data: HexTileData = hex_grid.get_tile(n)
		if data == null or data.terrain_type == HexTileData.TerrainType.OCEAN:
			continue
		var y = effective_tile_yield(data)
		var score = y.food * 1.5 + y.production * 1.3 + y.gold
		if score > best_score:
			best_score = score
			best_coord = n
	return best_coord

## Alterna se um tile vizinho esta sendo trabalhado por um cidadao desta
## cidade. Retorna false se a troca nao for valida: nao e vizinho, e
## oceano, ja trabalhado por OUTRA cidade, ou nao ha cidadao livre pra
## adicionar mais um (worked_tiles.size() >= population). O tile da propria
## cidade nunca entra aqui — ele sempre conta de graca em collect_yields().
func toggle_worked_tile(target: Vector2i, hex_grid: HexGrid) -> bool:
	if target in worked_tiles:
		worked_tiles.erase(target)
		return true
	if not target in hex_grid.get_neighbors(coord):
		return false
	if worked_tiles.size() >= population:
		return false
	var data: HexTileData = hex_grid.get_tile(target)
	if data == null or data.terrain_type == HexTileData.TerrainType.OCEAN:
		return false
	if hex_grid.is_tile_worked(target, self):
		return false
	worked_tiles.append(target)
	return true

func _build_visual() -> void:
	var label_height := 1.4
	if ResourceLoader.exists(TOWER_MODEL_PATH) and ResourceLoader.exists(FLAG_MODEL_PATH):
		label_height = _build_visual_from_model()
	else:
		_build_visual_procedural()

	_name_label = Label3D.new()
	_name_label.font_size = 40
	_name_label.outline_size = 10
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.position = Vector3(0, label_height, 0)
	add_child(_name_label)
	_refresh_label()

## Torre real do Kenney Castle Kit. A pedra fica com a textura original
## (uma cidade nao muda a cor da propria pedra ao trocar de dono) — so a
## bandeira no topo e tingida com a cor da civilizacao, como um castelo
## de verdade indicaria seu dono.
func _build_visual_from_model() -> float:
	var tower_scene: PackedScene = load(TOWER_MODEL_PATH)
	var tower := tower_scene.instantiate() as Node3D
	tower.scale = Vector3.ONE * TOWER_SCALE
	# Pivo da peca ja fica no nivel do chao por convencao do kit (a parte
	# que vai de y=-1 a y=0 e uma base/soquete pensada pra ficar enterrada,
	# sem frestas com o terreno) — nao deslocar em Y, so confiar no pivo.
	add_child(tower)

	var tower_top_y = TOWER_LOCAL_TOP * TOWER_SCALE

	# Mesma licao da torre: o pivo da bandeira tambem ja fica no ponto de
	# ancoragem (metade do mastro embaixo, "cravada" na superficie de
	# apoio) — plantar direto no topo da torre, sem somar meia-altura.
	var flag_scene: PackedScene = load(FLAG_MODEL_PATH)
	var flag := flag_scene.instantiate() as Node3D
	flag.scale = Vector3.ONE * FLAG_SCALE
	flag.position.y = tower_top_y
	_tint_model(flag, owner_player.civ.color)
	add_child(flag)

	return tower_top_y + FLAG_LOCAL_HALF_HEIGHT * FLAG_SCALE + 0.3

func _tint_model(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mesh_instance.material_override = mat
	for child in node.get_children():
		_tint_model(child, color)

## Fallback caso os modelos do Kenney nao tenham sido baixados (o jogo
## continua funcionando com formas procedurais, so menos bonito).
func _build_visual_procedural() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = owner_player.civ.color.lightened(0.1)

	var keep := MeshInstance3D.new()
	var keep_mesh := BoxMesh.new()
	keep_mesh.size = Vector3(0.5, 0.6, 0.5)
	keep.mesh = keep_mesh
	keep.material_override = mat
	keep.position.y = 0.3
	add_child(keep)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(0.6, 0.4, 0.6)
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.5, 0.15, 0.15)
	roof.material_override = roof_mat
	roof.position.y = 0.8
	add_child(roof)

func _refresh_label() -> void:
	if _name_label:
		_name_label.text = "%s (%d)" % [city_name, population]

class_name City
extends Node3D

const FOOD_TO_GROW_BASE := 8.0
const LABEL_HEIGHT := 1.4

## Escala visual da cidade por populacao (pedido do usuario: "Populacao 1 =
## 2-3 casinhas; Populacao 5 = distrito densamente povoado com torres/
## muralhas") — 3 faixas, nao crescimento linear infinito: uma cidade tardia
## com populacao 20+ continuaria com o MESMO teto de estruturas da faixa
## "cidade murada", so a torre central engorda um pouco mais (ver
## _add_tower), senao o numero de MeshInstance3D por cidade cresceria sem
## limite e a leitura visual/FPS degradariam junto com o proprio sucesso da
## cidade.
const POP_HAMLET_MAX := 2 # 1-2: aldeia, so casinhas
const POP_TOWN_MAX := 4 # 3-4: vila, casinhas + salao central
## 5+: cidade murada — casinhas + torre + muralha

var owner_player: PlayerData
var coord: Vector2i
var city_name: String = "Cidade"
var population: int = 1
var stored_food: float = 0.0
var stored_production: float = 0.0
## Colonizador e o unico item SEM predio de treino associado (ver
## BuildingDatabase.building_that_trains), entao e o unico kind sempre
## produzivel de graca — o default seguro pra uma cidade recem-fundada
## (ver can_train() abaixo, Guerreiro agora exige o Quartel construido).
var production_item: String = "settler"

## Cada ponto de populacao trabalha um tile vizinho (o tile da propria
## cidade e sempre contado de graca, fora desta lista — ver
## collect_yields()). Preenchido automaticamente ao fundar/crescer
## (auto_assign_worked_tiles, prioriza melhor rendimento), mas o jogador
## pode trocar via toggle_worked_tile() — da controle real sobre o que a
## cidade produz, em vez de somar todos os vizinhos sempre.
var worked_tiles: Array[Vector2i] = []

## Tiles que a cidade REALMENTE possui (territorio, ver HexGrid.
## city_territory_tiles/_build_city_tint_mesh — o tingimento de cor no chao
## de cada tile e o unico sinal visual disso hoje) — cresce com a
## populacao (ver process_turn/_claim_frontier_tile abaixo), independente
## de worked_tiles (rendimento) e do raio de posicionamento de predio (os
## dois continuam fixos em "vizinho direto da propria celula", fora do
## escopo desta mudanca — so a POSSE de territorio fica dinamica). Iniciado
## em HexGrid.found_city() com o mesmo conjunto de hoje (celula + 6
## vizinhos), depois cresce um tile por vez.
var owned_tiles: Array[Vector2i] = []

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
## Container so pras construcoes proceduais (ver _build_visual_procedural) —
## separado do Label3D pra crescimento de populacao poder reconstruir SO as
## construcoes (queue_free + reconstroi este container) sem afetar o label
## (change_owner() continua livre pra derrubar TUDO, ela ja reconstroi os
## dois de qualquer forma).
var _buildings_root: Node3D

func setup(player: PlayerData, start_coord: Vector2i, new_city_name: String) -> void:
	owner_player = player
	coord = start_coord
	city_name = new_city_name
	_build_visual()

## Trocar de projeto zera o progresso acumulado, como na maioria dos 4X:
## evita "salvar" producao de um item pra completar outro instantaneamente.
func set_production(kind: String) -> void:
	if kind != production_item:
		# Abandonar um predio EM ANDAMENTO (trocar pra unidade ou outro
		# predio antes de completar) limpa o tile reservado — senao
		# pending_building_coord ficaria "preso" apontando pro tile antigo,
		# e o marcador animado de construcao (HexGrid.refresh_construction_
		# markers) nunca saberia que aquela obra foi cancelada.
		if BuildingDatabase.get_building(production_item) and pending_building_coord != NO_PENDING_COORD:
			pending_building_coord = NO_PENDING_COORD
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
	if buildings.size() >= max_building_slots():
		return false
	return _tech_unlocked_for_building(building_id)

## Predio de TREINO so fica disponivel pra construir depois de pesquisar a
## mesma tecnologia que desbloqueia a tropa correspondente
## (TechDatabase.tech_that_unlocks(building.trains_unit)) — pedido do
## usuario: "so posso construir esses predios especiais quando pesquisar a
## tecnologia, ai aparece disponivel pra construir". Predios de PRODUCAO
## (Celeiro, Muralhas...) e o Quartel (Guerreiro nunca exigiu pesquisa)
## nao tem tecnologia associada (tech_that_unlocks devolve null), ficam
## sempre liberados por essa checagem, so sujeitos ao limite de slots.
func _tech_unlocked_for_building(building_id: String) -> bool:
	var building: BuildingData = BuildingDatabase.get_building(building_id)
	if building == null:
		return true
	var tech: TechData = TechDatabase.tech_that_unlocks(building.trains_unit)
	if tech == null:
		return true
	return owner_player != null and owner_player.researched_techs.has(tech.id)

## Cada tropa de combate so pode ser produzida se a cidade ja tiver o
## predio de treino correspondente construido (BuildingDatabase.
## building_that_trains) — Colonizador nao tem predio associado, entao
## fica sempre liberado. Como can_build() ja exige a tecnologia certa pra
## CONSTRUIR o predio, uma tropa so fica trainable depois da cadeia
## completa: pesquisar -> construir -> treinar. So enforced pro JOGADOR
## (ver HUD._on_produce_pressed); RivalAI.decide_production chama
## set_production() direto, sem passar por aqui, mesma assimetria ja
## documentada em BuildingDatabase (IA nao constroi predio nenhum, entao
## nunca teria como cumprir o gate).
##
## Tropa racial exclusiva (UnitDatabase.RACE_UNIQUE_KIND) tem uma segunda
## trava, ANTES da checagem de predio: so a raca DONA da tropa pode
## treinar ela (pedido do usuario: escolher raca na tela de titulo precisa
## ter uma implicacao real) — um jogador Anao nunca deveria conseguir
## treinar o Patrulheiro Elfico so por ter o Quartel construido.
func can_train(kind: String) -> bool:
	var owner_race: String = UnitDatabase.race_for_unique_kind(kind)
	if owner_race != "":
		var player_race: String = owner_player.civ.race if owner_player and owner_player.civ else ""
		if player_race != owner_race:
			return false
	var required: BuildingData = BuildingDatabase.building_that_trains(kind)
	if required == null:
		return true
	return buildings.has(required.id)

## Tile valido pra POSICIONAR um predio: precisa ser vizinho imediato da
## cidade (mesmo raio de worked_tiles — o "territorio" da cidade), terra
## firme, sem unidade/cidade em cima, e sem outro predio (desta cidade ou
## de qualquer outra, ver HexGrid.is_tile_building_site) ja la.
func is_valid_building_tile(target: Vector2i, hex_grid: HexGrid) -> bool:
	if not target in hex_grid.get_neighbors(coord):
		return false
	var data: HexTileData = hex_grid.get_tile(target)
	if data == null or data.blocks_land_units():
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
## estrategico/luxo do proprio tile (ResourceDatabase.yield_for). Usado
## por collect_yields(), _best_unassigned_neighbor() (senao o auto-assign
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
		# Mana nao tem componente "cru" de terreno (HexTileData nao tem
		# mana_yield, so food/production/gold) — vem inteiro de recurso
		# estrategico (Nodulo Arcano, ver ResourceDatabase) ou tech, nunca
		# do bioma sozinho.
		"mana": tech_bonus.mana + resource_bonus.mana,
	}

## Soma o rendimento efetivo do tile da cidade (sempre de graca) + so os
## tiles vizinhos atualmente TRABALHADOS (worked_tiles) — nao mais todo
## vizinho automaticamente. O multiplicador de dificuldade (so != 1.0 pra
## rivais, ver PlayerData.yield_multiplier) e aplicado no total final, nao
## por tile — mais barato e da o mesmo resultado. Tile PILHADO por um
## Invasor (ver HexGrid.pillage_tile/MonsterAI._maybe_pillage_tile) rende
## zero enquanto durar — o tile da propria cidade nunca e alvo disso
## (Invasor nao alcanca tile de cidade, HexGrid.compute_reachable ja
## bloqueia), so um worked_tiles pode estar pilhado na pratica.
func collect_yields(hex_grid: HexGrid) -> Dictionary:
	var totals = {"food": 0.0, "production": 0.0, "gold": 0.0, "mana": 0.0}
	var coords: Array[Vector2i] = [coord]
	coords.append_array(worked_tiles)
	for c in coords:
		if hex_grid.is_tile_pillaged(c, TurnManager.turn_number):
			continue
		var data: HexTileData = hex_grid.get_tile(c)
		if data == null:
			continue
		var y = effective_tile_yield(data)
		totals.food += y.food
		totals.production += y.production
		totals.gold += y.gold
		totals.mana += y.mana
	var building_bonus = BuildingDatabase.total_bonus(buildings)
	totals.food += building_bonus.food
	totals.production += building_bonus.production
	totals.gold += building_bonus.gold
	totals.mana += building_bonus.mana
	var mult = owner_player.yield_multiplier if owner_player else 1.0
	totals.food *= mult
	totals.production *= mult
	totals.gold *= mult
	totals.mana *= mult
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
		_claim_frontier_tile(hex_grid) # territorio (owned_tiles) cresce junto com a populacao
		_refresh_label()
		_build_visual_procedural()

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
			# sempre — troca pro item mais basico em vez de deixar producao
			# futura ser desperdicada num predio que ja existe. "settler"
			# (nao "warrior") porque e o unico kind sempre produzivel sem
			# depender de nenhum predio de treino (ver can_train()).
			production_item = "settler"
		else:
			spawned_kind = production_item

	return {"gold": yields.gold, "mana": yields.mana, "spawn_unit_kind": spawned_kind, "built_kind": built_kind, "built_coord": built_coord}

## Preenche worked_tiles ate `population` com os melhores vizinhos livres
## (ver HexTileData.can_be_worked — terra firme ou Costa, nunca Oceano
## aberto/Mar Gelado/Mar de Lava, nem ja trabalhados por esta ou outra
## cidade). Chamado ao fundar a cidade (HexGrid.found_city) e sempre que a
## populacao cresce — mantem um padrao razoavel sem exigir que o jogador
## (ou a IA) microgerencie toda cidade manualmente.
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
		if data == null or not data.can_be_worked():
			continue
		var y = effective_tile_yield(data)
		var score = y.food * 1.5 + y.production * 1.3 + y.gold
		if score > best_score:
			best_score = score
			best_coord = n
	return best_coord

func claim_tile(coord_to_claim: Vector2i) -> void:
	if not coord_to_claim in owned_tiles:
		owned_tiles.append(coord_to_claim)

## Reivindica UM tile de fronteira por vez (chamado a cada ponto de
## populacao ganho, ver process_turn) — "fronteira" e qualquer vizinho de
## um tile JA possuido que ainda nao esta em owned_tiles, varrendo o
## territorio INTEIRO (nao so os 6 vizinhos da celula central, diferente
## de _best_unassigned_neighbor acima) pra o territorio poder crescer pra
## qualquer direcao conforme se expande. Mesma formula de pontuacao de
## rendimento de _best_unassigned_neighbor, mas SEM o filtro can_be_worked
## — posse de territorio (a borda visual) nao exige que o tile seja
## trabalhavel, ao contrario de worked_tiles (ex: uma montanha pode ser
## "sua" sem nunca ser trabalhada). city_owning_tile() evita reivindicar
## um tile que ja e de OUTRA cidade; get_city_at() evita reivindicar o
## proprio tile de uma cidade (nem a dela mesma, que ja e o centro, nem de
## outra).
func _claim_frontier_tile(hex_grid: HexGrid) -> void:
	var frontier := {}
	for owned in owned_tiles:
		for n in hex_grid.get_neighbors(owned):
			if not n in owned_tiles:
				frontier[n] = true

	var best_coord = null
	var best_score = -INF
	for n in frontier.keys():
		if hex_grid.get_city_at(n) != null or hex_grid.city_owning_tile(n) != null:
			continue
		var data: HexTileData = hex_grid.get_tile(n)
		if data == null:
			continue
		var y = effective_tile_yield(data)
		var score = y.food * 1.5 + y.production * 1.3 + y.gold
		if score > best_score:
			best_score = score
			best_coord = n
	if best_coord != null:
		claim_tile(best_coord)

## Alterna se um tile vizinho esta sendo trabalhado por um cidadao desta
## cidade. Retorna false se a troca nao for valida: nao e vizinho, nao pode
## ser trabalhado (ver HexTileData.can_be_worked — Oceano aberto/Mar
## Gelado/Mar de Lava nao podem, Costa pode), ja trabalhado por OUTRA
## cidade, ou nao ha cidadao livre pra adicionar mais um (worked_tiles.size()
## >= population). O tile da propria cidade nunca entra aqui — ele sempre
## conta de graca em collect_yields().
func toggle_worked_tile(target: Vector2i, hex_grid: HexGrid) -> bool:
	if target in worked_tiles:
		worked_tiles.erase(target)
		return true
	if not target in hex_grid.get_neighbors(coord):
		return false
	if worked_tiles.size() >= population:
		return false
	var data: HexTileData = hex_grid.get_tile(target)
	if data == null or not data.can_be_worked():
		return false
	if hex_grid.is_tile_worked(target, self):
		return false
	worked_tiles.append(target)
	return true

func _build_visual() -> void:
	_build_visual_procedural()

	_name_label = Label3D.new()
	_name_label.font_size = 40
	_name_label.outline_size = 10
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.position = Vector3(0, LABEL_HEIGHT, 0)
	add_child(_name_label)
	_refresh_label()

## Reconstroi o CLUSTER de construcoes (nao o label, ver _buildings_root)
## a partir da populacao atual — chamado na fundacao (_build_visual) e de
## novo a cada ponto de populacao ganho (process_turn). RNG seedado pelo
## proprio `coord` (nao randi() puro): a disposicao das casinhas fica
## ESTAVEL entre reconstrucoes (crescer de pop 3 pra 4 so ACRESCENTA uma
## casinha nova, as antigas nao pulam de lugar) em vez de embaralhar tudo
## a cada turno que a cidade cresce.
func _build_visual_procedural() -> void:
	if _buildings_root:
		_buildings_root.queue_free()
	_buildings_root = Node3D.new()
	add_child(_buildings_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coord)

	var civ_color = owner_player.civ.color.lightened(0.1) if owner_player else Color(0.6, 0.6, 0.6)
	var is_town_or_bigger = population > POP_HAMLET_MAX
	var is_city = population > POP_TOWN_MAX

	# 2 casinhas na aldeia inicial, +1 por ponto de populacao, teto de 8 (a
	# cidade murada nao ganha MAIS casinhas alem disso, so a torre central
	# engorda — ver _add_tower) pra o numero de meshes nunca crescer sem
	# limite numa cidade tardia de populacao alta.
	var hut_count = clampi(population + 1, 2, 8)
	var hut_scale = 0.85 if not is_town_or_bigger else (1.0 if not is_city else 1.1)
	for i in range(hut_count):
		var angle = (TAU / hut_count) * i + rng.randf_range(-0.2, 0.2)
		var radius = rng.randf_range(0.28, 0.44)
		var pos = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_add_hut(pos, hut_scale * rng.randf_range(0.85, 1.15), rng)

	if is_city:
		_add_tower(civ_color, population)
		_add_walls(rng)
	else:
		_add_small_keep(civ_color)

func _add_hut(local_pos: Vector3, scale: float, rng: RandomNumberGenerator) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.22, 0.22, 0.22) * scale
	body.mesh = body_mesh
	var body_mat := StandardMaterial3D.new()
	# Leve variacao de tom entre casinhas (evita aspecto "clonado" — mesmo
	# espirito do color_variation de terrain.gdshader) — tom terroso neutro,
	# nao a cor da civilizacao (so a torre/salao central usa a cor do dono,
	# ver _add_tower/_add_small_keep, senao um distrito inteiro gritando na
	# cor da civ ficaria cansativo visualmente).
	body_mat.albedo_color = Color(0.72, 0.64, 0.5).lightened(rng.randf_range(-0.15, 0.15))
	body.material_override = body_mat
	body.position = local_pos + Vector3(0, 0.11 * scale, 0)
	body.rotation.y = rng.randf_range(0.0, TAU)
	_buildings_root.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(0.26, 0.16, 0.26) * scale
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.45, 0.13, 0.12)
	roof.material_override = roof_mat
	roof.position = local_pos + Vector3(0, 0.22 * scale + 0.08 * scale, 0)
	roof.rotation.y = body.rotation.y
	_buildings_root.add_child(roof)

## Salao/casa grande central (aldeia e vila, populacao ate POP_TOWN_MAX) —
## essencialmente o antigo modelo unico de cidade (keep+prisma), um pouco
## menor pra nao dominar visualmente o anel de casinhas ao redor.
func _add_small_keep(civ_color: Color) -> void:
	var keep := MeshInstance3D.new()
	var keep_mesh := BoxMesh.new()
	keep_mesh.size = Vector3(0.32, 0.4, 0.32)
	keep.mesh = keep_mesh
	var keep_mat := StandardMaterial3D.new()
	keep_mat.albedo_color = civ_color
	keep.material_override = keep_mat
	keep.position.y = 0.2
	_buildings_root.add_child(keep)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(0.38, 0.26, 0.38)
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.5, 0.15, 0.15)
	roof.material_override = roof_mat
	roof.position.y = 0.4 + 0.13
	_buildings_root.add_child(roof)

## Torre central da cidade murada (populacao > POP_TOWN_MAX) — maior que o
## salao de vila, e cresce um pouco mais alem disso (teto proprio, ver
## extra_tier) pra dar alguma diferenca visual entre uma cidade recem-
## murada (pop 5) e um imperio tardio (pop 15+) sem acrescentar NENHUM
## mesh novo (so escala o que ja existe).
func _add_tower(civ_color: Color, population_value: int) -> void:
	var extra_tier = clampi(population_value - POP_TOWN_MAX - 1, 0, 4)
	var height_bonus = extra_tier * 0.08

	var keep := MeshInstance3D.new()
	var keep_mesh := BoxMesh.new()
	keep_mesh.size = Vector3(0.42, 0.9 + height_bonus, 0.42)
	keep.mesh = keep_mesh
	var keep_mat := StandardMaterial3D.new()
	keep_mat.albedo_color = civ_color
	keep.material_override = keep_mat
	keep.position.y = (0.9 + height_bonus) * 0.5
	_buildings_root.add_child(keep)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(0.5, 0.35, 0.5)
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.5, 0.15, 0.15)
	roof.material_override = roof_mat
	roof.position.y = 0.9 + height_bonus + 0.17
	_buildings_root.add_child(roof)

## Segmentos de muralha em anel perto da borda do tile (populacao >
## POP_TOWN_MAX) — pedido do usuario: "distrito densamente povoado com
## torres/muralhas".
func _add_walls(rng: RandomNumberGenerator) -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.5, 0.48, 0.45)
	var segments := 6
	var radius := 0.62
	for i in range(segments):
		var angle = (TAU / segments) * i
		var seg := MeshInstance3D.new()
		var seg_mesh := BoxMesh.new()
		seg_mesh.size = Vector3(0.34, 0.16, 0.08)
		seg.mesh = seg_mesh
		seg.material_override = wall_mat
		seg.position = Vector3(cos(angle) * radius, 0.08, sin(angle) * radius)
		seg.rotation.y = angle + PI / 2.0
		_buildings_root.add_child(seg)

func _refresh_label() -> void:
	if _name_label:
		_name_label.text = "%s (%d)" % [city_name, population]

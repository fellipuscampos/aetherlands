extends Node

## Salva/carrega o estado logico da partida em JSON (user://savegame.json).
## Nao serializa nodes 3D nem visual nenhum — so os dados que importam pro
## jogo (terreno via semente + raio, jogadores, unidades, cidades, turno,
## fog explorado). Recarregar reconstroi tudo chamando os mesmos caminhos
## de spawn/fundacao usados num jogo novo (HexGrid.spawn_unit/found_city),
## depois reaplica hp/movimento/producao por cima.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 6 # v6: predios posicionados no mapa (v5: covis de monstro limpos; v4: predios de cidade; v3: dificuldade; v2: lista de rivais + diplomacia + veterania de unidade)

## path e parametrizavel so pros testes GUT usarem um arquivo isolado, sem
## tocar no save de verdade do jogador — o jogo em si sempre usa SAVE_PATH.
func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)

func delete_save(path: String = SAVE_PATH) -> void:
	if has_save(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func save_game(hex_grid: HexGrid, path: String = SAVE_PATH) -> bool:
	var rivals := []
	for rival in GameManager.rival_players:
		rivals.append(_serialize_player(rival, true))

	var data := {
		"version": SAVE_VERSION,
		"map_radius": hex_grid.map_radius,
		"map_seed": hex_grid.map_seed,
		"turn_number": TurnManager.turn_number,
		"current_player_index": TurnManager.current_player_index,
		"human_kingdom_name": GameManager.human_player.civ.civ_name,
		"difficulty": GameManager.difficulty,
		"explored_coords": _serialize_explored(hex_grid),
		"cleared_lairs": _serialize_cleared_lairs(hex_grid),
		"human": _serialize_player(GameManager.human_player, false),
		"rivals": rivals,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

## Reconstroi hex_grid + GameManager a partir do arquivo salvo. Retorna
## false (sem mexer no jogo em andamento) se nao houver save ou o arquivo
## estiver corrompido/de uma versao incompativel.
func load_game(hex_grid: HexGrid, path: String = SAVE_PATH) -> bool:
	if not has_save(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or data.get("version", 0) != SAVE_VERSION:
		return false

	hex_grid.generate_map(int(data.map_radius), int(data.map_seed))
	# generate_map() acima ja respawnou TODO guardiao original (mesma
	# semente) — desfaz isso pros covis que o save diz que ja foram
	# limpos, senao um monstro derrotado antes de salvar "ressuscitaria".
	for c in data.get("cleared_lairs", []):
		var lair_coord = Vector2i(int(c[0]), int(c[1]))
		var guardian = hex_grid.get_unit_at(lair_coord)
		if guardian != null:
			hex_grid.remove_unit(guardian)
	# GameManager.map_radius fica desatualizado se o save for de um raio
	# diferente do jogo atual (ex: carregar um mapa Grande depois de comecar
	# um Pequeno) — RTSCamera.reset_view() usa esse valor pra calcular o
	# limite de pan da camera, entao precisa bater com o mapa de verdade.
	GameManager.map_radius = int(data.map_radius)
	GameManager.human_kingdom_name = data.get("human_kingdom_name", "")
	GameManager.rival_count = data.rivals.size()
	GameManager.difficulty = data.get("difficulty", "normal")
	GameManager.setup_players(hex_grid) # cria human_player + rival_players do tamanho certo, todos em guerra por padrao

	TurnManager.turn_number = int(data.turn_number)
	TurnManager.current_player_index = int(data.current_player_index)

	_deserialize_player(data.human, GameManager.human_player, hex_grid)
	for i in range(data.rivals.size()):
		var rival_data: Dictionary = data.rivals[i]
		var rival: PlayerData = GameManager.rival_players[i]
		_deserialize_player(rival_data, rival, hex_grid)
		# setup_players() ja colocou todo rival em guerra por padrao — so
		# desfaz se o save dizia que estavam em paz (nunca usa
		# Diplomacy.propose_peace aqui: isso tem heuristica de aceitacao da
		# IA, e a gente quer restaurar o estado EXATO salvo, nao renegociar).
		if not rival_data.get("at_war_with_human", true):
			rival.enemies.erase(GameManager.human_player)
			GameManager.human_player.enemies.erase(rival)

	for c in data.get("explored_coords", []):
		var coord = Vector2i(int(c[0]), int(c[1]))
		if hex_grid.tiles.has(coord):
			hex_grid.visibility[coord] = HexGrid.Visibility.EXPLORED
	hex_grid.recompute_fog(GameManager.human_player)
	GameManager.check_game_over()
	return true

func _serialize_explored(hex_grid: HexGrid) -> Array:
	var out := []
	for coord in hex_grid.visibility.keys():
		if hex_grid.visibility[coord] != HexGrid.Visibility.UNSEEN:
			out.append([coord.x, coord.y])
	return out

## hex_grid.lair_coords guarda TODO covil colocado nesta partida (100%
## deterministico pela semente — ver HexGrid._spawn_monster_lairs); um
## coord aqui sem unidade mais e um covil ja limpo por algum jogador. Salvo
## a parte porque generate_map() (chamado no load) respawnaria os
## guardioes originais de novo, senao.
func _serialize_cleared_lairs(hex_grid: HexGrid) -> Array:
	var out := []
	for coord in hex_grid.lair_coords:
		if hex_grid.get_unit_at(coord) == null:
			out.append([coord.x, coord.y])
	return out

func _serialize_player(player: PlayerData, is_rival: bool) -> Dictionary:
	var units := []
	for unit in player.units:
		units.append({
			"kind": unit.unit_data.visual_kind,
			"coord": [unit.coord.x, unit.coord.y],
			"hp": unit.hp,
			"movement_left": unit.movement_left,
			"kills": unit.kills,
			"veterancy_level": unit.veterancy_level,
		})
	var cities := []
	for city in player.cities:
		var worked := []
		for w in city.worked_tiles:
			worked.append([w.x, w.y])
		var building_coords_out := {}
		for id in city.building_coords.keys():
			var bc: Vector2i = city.building_coords[id]
			building_coords_out[id] = [bc.x, bc.y]
		var city_dict := {
			"coord": [city.coord.x, city.coord.y],
			"name": city.city_name,
			"population": city.population,
			"stored_food": city.stored_food,
			"stored_production": city.stored_production,
			"production_item": city.production_item,
			"worked_tiles": worked,
			"buildings": city.buildings.keys(),
			"building_coords": building_coords_out,
		}
		if city.pending_building_coord != City.NO_PENDING_COORD:
			city_dict["pending_building_coord"] = [city.pending_building_coord.x, city.pending_building_coord.y]
		cities.append(city_dict)
	var known_cities := []
	for coord in player.known_enemy_cities.keys():
		known_cities.append([coord.x, coord.y])

	var result := {
		"gold": player.gold, "units": units, "cities": cities, "known_enemy_cities": known_cities,
		"researched_techs": player.researched_techs.keys(),
		"current_research": player.current_research,
		"research_progress": player.research_progress,
	}
	if is_rival:
		result["at_war_with_human"] = player.is_at_war_with(GameManager.human_player)
	return result

func _deserialize_player(saved: Dictionary, player: PlayerData, hex_grid: HexGrid) -> void:
	player.gold = float(saved.gold)
	for u in saved.units:
		var coord = Vector2i(int(u.coord[0]), int(u.coord[1]))
		var unit = hex_grid.spawn_unit(coord, UnitDatabase.create_unit(u.kind), player)
		unit.hp = float(u.hp)
		unit.movement_left = float(u.movement_left)
		unit.kills = int(u.get("kills", 0))
		unit.veterancy_level = int(u.get("veterancy_level", 0))
	for c in saved.cities:
		var coord = Vector2i(int(c.coord[0]), int(c.coord[1]))
		var city = hex_grid.found_city(coord, player, c.name, true)
		# set_production() zera stored_production quando o tipo muda (existe
		# pra impedir o JOGADOR de "salvar" progresso trocando de item) — por
		# isso precisa vir ANTES de restaurar stored_production, senao o
		# valor salvo seria zerado de volta aqui mesmo.
		city.set_production(c.production_item)
		city.population = int(c.population)
		city.stored_food = float(c.stored_food)
		city.stored_production = float(c.stored_production)
		# found_city() ja chamou auto_assign_worked_tiles() acima (com a
		# populacao default 1) — sobrescreve com a lista exata salva em vez
		# de deixar o auto-assign "adivinhar" de novo.
		var worked: Array[Vector2i] = []
		for w in c.get("worked_tiles", []):
			worked.append(Vector2i(int(w[0]), int(w[1])))
		city.worked_tiles = worked
		for id in c.get("buildings", []):
			city.buildings[id] = true
		# Recria o modelo 3D de cada predio no tile exato onde foi
		# posicionado — sem isso o predio continuaria valendo o bonus (ja
		# restaurado acima) mas sumiria do mapa depois de um load.
		var building_coords_in: Dictionary = c.get("building_coords", {})
		for id in building_coords_in.keys():
			var bc_arr = building_coords_in[id]
			var bc = Vector2i(int(bc_arr[0]), int(bc_arr[1]))
			city.building_coords[id] = bc
			hex_grid.place_building(bc, id, player)
		if c.has("pending_building_coord"):
			var pc = c.pending_building_coord
			city.pending_building_coord = Vector2i(int(pc[0]), int(pc[1]))
		city._refresh_label()
	for coord_arr in saved.get("known_enemy_cities", []):
		player.known_enemy_cities[Vector2i(int(coord_arr[0]), int(coord_arr[1]))] = true
	for id in saved.get("researched_techs", []):
		player.researched_techs[id] = true
	player.current_research = saved.get("current_research", "")
	player.research_progress = float(saved.get("research_progress", 0.0))

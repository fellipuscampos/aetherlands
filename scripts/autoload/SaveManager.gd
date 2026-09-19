extends Node

## Salva/carrega o estado logico da partida em JSON (user://savegame.json).
## Nao serializa nodes 3D nem visual nenhum — so os dados que importam pro
## jogo (terreno via semente + raio, jogadores, unidades, cidades, turno,
## fog explorado). Recarregar reconstroi tudo chamando os mesmos caminhos
## de spawn/fundacao usados num jogo novo (HexGrid.spawn_unit/found_city),
## depois reaplica hp/movimento/producao por cima.

const SAVE_PATH := "user://savegame.json"
## Versoes anteriores aceitas por load_game ALEM de SAVE_VERSION — so pra
## rodar as migracoes de _deserialize_player (ver comentario la). Nao e
## suporte generico a qualquer versao antiga, so a ponte de migracoes
## concretas e explicitas (pedido do usuario: "NAO simplesmente invalide
## saves antigos... se precisar aumentar a versao, implemente a migracao
## explicitamente"). v17 precisa da migracao Tech/Magic (researched_techs
## misturava as duas arvores); v17 E v18 precisam da migracao de ids da
## arvore de 10 niveis (TECH_TIER_REDESIGN_REMAP abaixo) — os 9 ids
## antigos de TechDatabase nao existem mais.
const MIGRATABLE_SAVE_VERSIONS: Array[int] = [17, 18, 19, 20]
const SAVE_VERSION := 21 # Escolas V1, conjuradores, regiões temporárias e rituais.

## Migracao de ids da arvore de Tecnologia (redesenho de 10 niveis, v19) —
## tabela EXPLICITA (pedido do usuario: "nao quero uma migracao inferida
## automaticamente com base em nome... isso pode destruir save sem ninguem
## perceber"), id antigo -> Array de id(s) novo(s). Os 6 primeiros
## preservam o id (mesmo predio/conceito). "arquearia" desbloqueava PREDIO
## E UNIDADE juntos na tech antiga; a arvore nova separou isso em dois nos
## (campo_de_tiro + arqueiro), entao quem ja tinha pago por essa
## capacidade recebe as duas. "batedor_montado" antigo desbloqueava o kind
## "scout" (Batedor simples) — isso agora e a tech "batedor" do Nivel 1; o
## id novo "batedor_montado" virou uma unidade DIFERENTE (mais forte,
## Nivel 3), entao NAO recebe credito automatico por essa migracao.
const TECH_TIER_REDESIGN_REMAP: Dictionary = {
	"quartel": ["quartel"],
	"celeiro": ["celeiro"],
	"oficina": ["oficina"],
	"mercado": ["mercado"],
	"estabulo": ["estabulo"],
	"muralhas": ["muralhas"],
	"navegacao": ["navegacao"],
	"arquearia": ["campo_de_tiro", "arqueiro"],
	"batedor_montado": ["batedor"],
}

## path e parametrizavel so pros testes GUT usarem um arquivo isolado, sem
## tocar no save de verdade do jogador — o jogo em si sempre usa SAVE_PATH.
func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)

func delete_save(path: String = SAVE_PATH) -> void:
	if has_save(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## Roadmap "sistema de menu de jogo moderno" -- pedido do usuario: "o salvar
## salva de fato o jogo, criando um slot daquela partida e salvando por cima
## ela sempre que e clicando salvar, ai voce pode ver seus jogos ao clicar em
## carregar jogo". Camada de MULTIPLOS slots por cima do save unico acima
## (has_save/delete_save/save_game/load_game continuam 100% intocados, com
## toda a logica de serializacao/migracao ja pesadamente testada) -- cada
## slot e so mais um arquivo em SAVE_DIR, identificado pelo proprio nome.
## O save ANTIGO de arquivo unico (SAVE_PATH, fora de SAVE_DIR) fica orfao
## de proposito (decisao explicita do usuario) -- nao aparece em list_slots().
const SAVE_DIR := "user://saves/"

func _slot_path(slot_id: String, dir: String = SAVE_DIR) -> String:
	return dir.path_join(slot_id + ".json")

## Gera um id novo de slot -- uma partida NOVA ou um save CARREGADO ganham um
## id aqui (ver GameManager.current_save_slot), reusado em todo clique de
## "Salvar Jogo" subsequente (sobrescreve sempre o MESMO slot, nunca cria um
## novo so por salvar de novo). Timestamp legivel o bastante pra debug manual
## dos arquivos em user://saves/; o sufixo incremental so existe pra
## desempatar o caso extremo de duas chamadas no mesmo segundo (ex: testes).
func new_slot_id(dir: String = SAVE_DIR) -> String:
	var base := Time.get_unix_time_from_system()
	var id := "slot_%d" % base
	var suffix := 1
	while FileAccess.file_exists(_slot_path(id, dir)):
		id = "slot_%d_%d" % [base, suffix]
		suffix += 1
	return id

func save_to_slot(hex_grid: HexGrid, slot_id: String, dir: String = SAVE_DIR) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	return save_game(hex_grid, _slot_path(slot_id, dir), {"saved_at": Time.get_unix_time_from_system()})

func load_from_slot(hex_grid: HexGrid, slot_id: String, dir: String = SAVE_DIR) -> bool:
	return load_game(hex_grid, _slot_path(slot_id, dir))

func delete_slot(slot_id: String, dir: String = SAVE_DIR) -> void:
	delete_save(_slot_path(slot_id, dir))

func has_any_slots(dir: String = SAVE_DIR) -> bool:
	return not list_slots(dir).is_empty()

## Le so os campos de RESUMO direto do JSON de cada slot (mesmos campos ja
## gravados em save_game()) sem reconstruir jogo nenhum -- usado pela tela de
## Carregar Jogo pra montar a lista. Um arquivo corrompido/formato invalido e
## simplesmente PULADO (nunca derruba a lista inteira por causa de 1 slot
## ruim). Ordenado por saved_at decrescente (mais recente primeiro).
func list_slots(dir: String = SAVE_DIR) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir() and fname.ends_with(".json"):
			var file := FileAccess.open(dir.path_join(fname), FileAccess.READ)
			if file != null:
				# JSON.new().parse() (nao o JSON.parse_string() estatico usado
				# em load_game() acima) de proposito: a versao estatica
				# IMPRIME um ERROR no console quando o texto e invalido, o
				# que o GUT trata como "erro inesperado" e derruba o teste
				# mesmo o codigo aqui ja tratando a falha graciosamente (ver
				# test_list_slots_skips_corrupted_files_instead_of_crashing).
				# A API de instancia so devolve um Error, sem imprimir nada.
				var json := JSON.new()
				var parse_error := json.parse(file.get_as_text())
				file.close()
				var data = json.data if parse_error == OK else null
				if typeof(data) == TYPE_DICTIONARY:
					out.append({
						"slot_id": fname.trim_suffix(".json"),
						"kingdom_name": data.get("human_kingdom_name", "?"),
						"race": data.get("human_race", "human"),
						"turn_number": int(data.get("turn_number", 0)),
						"difficulty": data.get("difficulty", "normal"),
						"saved_at": int(data.get("saved_at", 0)),
					})
		fname = da.get_next()
	da.list_dir_end()
	out.sort_custom(func(a, b): return a.saved_at > b.saved_at)
	return out

## extra_fields e mesclado no dict ANTES de serializar (unico uso hoje:
## "saved_at", ver save_to_slot abaixo) — aditivo de proposito, as ~35
## chamadas existentes em test_save_manager.gd (2 args, sem extra_fields)
## continuam identicas.
func save_game(hex_grid: HexGrid, path: String = SAVE_PATH, extra_fields: Dictionary = {}) -> bool:
	if GameManager.is_turn_processing or GameManager.human_player == null:
		return false
	var rivals := []
	for rival in GameManager.rival_players:
		rivals.append(_serialize_player(rival, true))

	var data := {
		"version": SAVE_VERSION,
		"victory_rules_version": GameManager.victory_rules_version,
		"map_width": hex_grid.map_width,
		"map_height": hex_grid.map_height,
		"map_seed": hex_grid.map_seed,
		"turn_number": TurnManager.turn_number,
		"current_player_index": TurnManager.current_player_index,
		"human_kingdom_name": GameManager.human_player.civ.civ_name,
		"human_race": GameManager.human_player.civ.race,
		"difficulty": GameManager.difficulty,
		"explored_coords": _serialize_explored(hex_grid),
		"neutral_units": _serialize_neutral_units(hex_grid),
		"cleared_lair_coords": _serialize_cleared_lairs(hex_grid),
		"lair_structure_hp": _serialize_lair_structure_hp(hex_grid),
		"lair_alerts": _serialize_lair_alerts(hex_grid),
		# STRING, nao int direto: `RandomNumberGenerator.state` e um inteiro
		# de 64 bits, mas JSON nao tem tipo inteiro (so "number" = double) —
		# `JSON.parse_string` devolveria o valor como float, perdendo
		# precisao acima de 2^53 (~9e15; states de verdade passam disso
		# facil) e corrompendo o replay. Como string, o valor cru
		# sobrevive intacto e `int(String)` reconstroi o int64 exato.
		"monster_rng_state": str(hex_grid.monster_turn_rng.state),
		"human": _serialize_player(GameManager.human_player, false),
		"rivals": rivals,
		"world_events": WorldEventManager.to_save_dict(),
		"relations": _serialize_relations(),
		"trade_routes": _serialize_routes(),
		"terrain_changes": _serialize_coord_values(hex_grid.terrain_changes),
		"terrain_resources": _serialize_terrain_resources(hex_grid),
		"pillaged_tiles": _serialize_coord_values(hex_grid._pillaged_tiles),
	}
	data.merge(extra_fields, true)
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(path)) == OK

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

	var json := JSON.new()
	if json.parse(text) != OK:
		return false
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var version = data.get("version", 0)
	if version != SAVE_VERSION and version not in MIGRATABLE_SAVE_VERSIONS:
		return false
	if not _valid_save_header(data):
		return false

	# GameManager.map_width/map_height/rival_count precisam estar corretos
	# ANTES de generate_map(): HexGrid._spawn_monster_lairs usa
	# GameManager.rival_count (via _nearest_player_origin_distance) pra
	# decidir ameaca/tipo de cada covil — setar isso DEPOIS (como o codigo
	# fazia antes) e um bug latente: o covil carregado podia sortear um
	# tipo diferente do que existia no save original, mesma semente e
	# tudo. RTSCamera.reset_view() tambem depende de map_width/map_height
	# pro limite de pan bater com o mapa de verdade (se o save for de um
	# mapa diferente do jogo atual, ex: carregar um Grande depois de
	# comecar um Pequeno).
	GameManager.map_width = int(data.map_width)
	GameManager.map_height = int(data.map_height)
	GameManager.human_kingdom_name = data.get("human_kingdom_name", "")
	GameManager.human_race = data.get("human_race", "human")
	GameManager.rival_count = data.rivals.size()
	GameManager.difficulty = data.get("difficulty", "normal")
	GameManager.victory_rules_version = int(data.get("victory_rules_version", 1))

	hex_grid.generate_map(int(data.map_width), int(data.map_height), int(data.map_seed))
	for entry in data.get("terrain_changes", []):
		hex_grid.transform_tile_terrain(Vector2i(int(entry[0]), int(entry[1])), int(entry[2]))
	for entry in data.get("terrain_resources", []):
		var tile := hex_grid.get_tile(Vector2i(int(entry[0]), int(entry[1])))
		if tile:
			tile.resource = str(entry[2])
	for entry in data.get("pillaged_tiles", []):
		hex_grid._pillaged_tiles[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])
	# generate_map() acima ja respawnou TODO guardiao original + LairStructure
	# (mesma semente) — descarta esse povoamento deterministico de partida
	# NOVA e restaura o mapa de monstros EXATO que existia no momento do save
	# (guardiao original sobrevivente, reforco, ou o resultado de uma
	# patrulha — todos indistinguiveis entre si, ver HexGrid.neutral_units).
	hex_grid.clear_neutral_units()
	_deserialize_neutral_units(data.get("neutral_units", []), hex_grid)
	# Mesma logica por cima dos covis que ja tinham sido DESTRUIDOS antes do
	# save (ver HexGrid.destroy_lair) — generate_map() os respawnou do zero
	# alguns passos acima, isso desfaz de novo. destroy_lair() e seguro de
	# chamar aqui mesmo se o coord nao existir mais em lair_coords.
	for c in data.get("cleared_lair_coords", []):
		hex_grid.destroy_lair(Vector2i(int(c[0]), int(c[1])))
	# Restaura o HP da ESTRUTURA de qualquer covil ainda de pe mas ja
	# parcialmente atacado (ver _serialize_lair_structure_hp acima) --
	# depois do loop de cleared_lair_coords, entao nunca tenta setar hp
	# numa estrutura que acabou de ser destruida/removida.
	for entry in data.get("lair_structure_hp", []):
		var coord := Vector2i(int(entry[0]), int(entry[1]))
		if hex_grid.lairs_by_coord.has(coord):
			hex_grid.lairs_by_coord[coord].hp = float(entry[2])
	# AGGRO / TERRITORIO DE AMEACA: restaura covil ALERTADO (ver
	# _serialize_lair_alerts acima) -- so' pra covil ainda ATIVO (destroy_lair
	# ja limpa a propria entrada, mas o loop de cleared_lair_coords acima
	# rodou ANTES, entao nunca sobrescreve um covil ja destruido de novo).
	for entry in data.get("lair_alerts", []):
		var coord := Vector2i(int(entry[0]), int(entry[1]))
		if coord in hex_grid.lair_coords:
			hex_grid.lair_alert_until_turn[coord] = int(entry[2])
	# `.state` (nao so o seed) restaura o RNG de reforco/patrulha exatamente
	# de onde parou — sem isso, salvar e recarregar no mesmo turno reiniciava
	# a sequencia de sorteios do zero, quebrando qualquer replay/determinismo
	# de eventos futuros dos covis.
	if data.has("monster_rng_state"):
		hex_grid.monster_turn_rng.state = int(data.monster_rng_state)
	GameManager.setup_players(hex_grid) # cria human_player + rival_players do tamanho certo, todos em guerra por padrao

	TurnManager.turn_number = int(data.turn_number)
	TurnManager.current_player_index = int(data.current_player_index)

	_deserialize_player(data.human, GameManager.human_player, hex_grid, int(version))
	for i in range(data.rivals.size()):
		var rival_data: Dictionary = data.rivals[i]
		var rival: PlayerData = GameManager.rival_players[i]
		_deserialize_player(rival_data, rival, hex_grid, int(version))
		# setup_players() ja colocou todo rival em guerra por padrao — so
		# desfaz se o save dizia que estavam em paz (nunca usa
		# Diplomacy.propose_peace aqui: isso tem heuristica de aceitacao da
		# IA, e a gente quer restaurar o estado EXATO salvo, nao renegociar).
		if rival_data.get("at_war_with_human", true) and not data.has("relations"):
			Diplomacy.declare_war(rival, GameManager.human_player)
	_restore_relations_and_routes(data, hex_grid)

	for c in data.get("explored_coords", []):
		var coord = Vector2i(int(c[0]), int(c[1]))
		if hex_grid.tiles.has(coord):
			hex_grid.visibility[coord] = HexGrid.Visibility.EXPLORED
	# refresh_construction_markers ANTES de recompute_fog (mesma ordem de
	# GameManager._finish_turn, mesmo motivo): recompute_fog e quem gateia
	# a visibilidade de cada marcador pela nevoa (ver HexGrid._apply_fog_to_
	# entities) — se rodasse depois, um marcador restaurado aqui apareceria
	# visivel pra QUALQUER cidade inimiga ate o proximo turno.
	hex_grid.refresh_construction_markers() # restaura o marcador de obra pra predio que ainda estava em producao ao salvar
	hex_grid.recompute_fog(GameManager.human_player)
	# World Event System (ver docs/WORLD_EVENT_CONTRACT.md) -- so RESTAURA
	# estado (from_save_dict), NUNCA chama advance_turn() aqui: carregar um
	# save nao pode fazer um evento avancar, mesma regra ja seguida pelas
	# vitorias de sustentacao (check_victories() abaixo so detecta, nunca
	# avanca streak nenhum). .get(..., {}) tolera um save sem esta chave
	# (ex.: um dict de save montado a mao por teste) sem travar o load.
	WorldEventManager.from_save_dict(data.get("world_events", {}))
	# Roadmap "Fase Macro" 5B.3-A -- a Unit fisica de um DragonEvent em
	# Active nunca e' serializada diretamente (e' so mais um monstro
	# neutro pro save generico, ja restaurado acima em _deserialize_
	# neutral_units); precisa so ser RE-LINKADA ao evento por spawn_coord,
	# depois que os dois lados (monstros neutros E o proprio evento) ja
	# existem de novo.
	for event in WorldEventManager.active_events:
		if event is DragonEvent:
			(event as DragonEvent).relink_unit(hex_grid)
	GameManager.check_victories()
	return true

func _match_players() -> Array[PlayerData]:
	return ([GameManager.human_player] as Array[PlayerData]) + GameManager.rival_players

func _serialize_coord_values(values: Dictionary) -> Array:
	var out: Array = []
	for coord in values:
		out.append([coord.x, coord.y, values[coord]])
	return out

func _serialize_relations() -> Array:
	var out: Array = []
	var players := _match_players()
	for player in players:
		var wars: Array = []
		var campaigns: Array = []
		var truces: Array = []
		var reasons := {}
		for enemy in player.enemies:
			var index := players.find(enemy)
			if index >= 0:
				wars.append(index)
				reasons[str(index)] = player.war_reasons.get(enemy, "Disputa territorial")
		for other in player.truces:
			var index := players.find(other)
			if index >= 0:
				truces.append([index, player.truces[other]])
		for enemy in player.war_campaigns:
			var index := players.find(enemy)
			if index < 0:
				continue
			var c: Dictionary = player.war_campaigns[enemy]
			campaigns.append({"opponent": index, "objective": c.objective,
				"status": c.status, "target_coord": [c.target_coord.x, c.target_coord.y]})
		out.append({"wars": wars, "campaigns": campaigns, "truces": truces, "reasons": reasons})
	return out

func _serialize_routes() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for player in _match_players():
		for route in player.trade_routes:
			if seen.has(route) or not TradeManager._is_route_still_valid(route):
				continue
			seen[route] = true
			out.append([route.city_a.coord.x, route.city_a.coord.y, route.city_b.coord.x, route.city_b.coord.y])
	return out

func _restore_relations_and_routes(data: Dictionary, hex_grid: HexGrid) -> void:
	var players := _match_players()
	var relations: Array = data.get("relations", [])
	for i in range(mini(relations.size(), players.size())):
		var relation: Dictionary = relations[i]
		for enemy_index in relation.get("wars", []):
			var index := int(enemy_index)
			if index >= 0 and index < players.size() and index != i:
				Diplomacy.declare_war(players[i], players[index], relation.get("reasons", {}).get(str(index), "Disputa territorial"))
		players[i].war_campaigns.clear()
		for c in relation.get("campaigns", []):
			var index := int(c.opponent)
			if index >= 0 and index < players.size() and index != i:
				players[i].war_campaigns[players[index]] = {"objective": c.objective,
					"status": c.status, "target_coord": Vector2i(int(c.target_coord[0]), int(c.target_coord[1]))}
	for i in range(mini(relations.size(), players.size())):
		for truce in relations[i].get("truces", []):
			var index := int(truce[0])
			if index >= 0 and index < players.size() and index != i:
				players[i].truces[players[index]] = int(truce[1])
	for coords in data.get("trade_routes", []):
		var a := hex_grid.get_city_at(Vector2i(int(coords[0]), int(coords[1])))
		var b := hex_grid.get_city_at(Vector2i(int(coords[2]), int(coords[3])))
		if a == null or b == null or a.owner_player == b.owner_player or a.owner_player.is_at_war_with(b.owner_player):
			continue
		# Restaurar um acordo não é uma nova negociação.
		var route := TradeRoute.new(a, b)
		a.owner_player.trade_routes.append(route)
		b.owner_player.trade_routes.append(route)

func _valid_save_header(data: Dictionary) -> bool:
	for key in ["map_width", "map_height", "map_seed", "turn_number", "current_player_index", "human", "rivals"]:
		if not data.has(key):
			return false
	if typeof(data.human) != TYPE_DICTIONARY or typeof(data.rivals) != TYPE_ARRAY:
		return false
	for key in ["map_width", "map_height", "map_seed", "turn_number", "current_player_index"]:
		if not _is_number(data[key]):
			return false
	if int(data.map_width) <= 0 or int(data.map_height) <= 0 or int(data.map_width) > 512 or int(data.map_height) > 512:
		return false
	if data.rivals.size() < 1 or data.rivals.size() > GameManager.RIVAL_CIVS.size():
		return false
	for key in ["human_kingdom_name", "human_race", "difficulty", "monster_rng_state"]:
		if data.has(key) and typeof(data[key]) != TYPE_STRING:
			return false
	if data.has("victory_rules_version") and not _is_number(data.victory_rules_version):
		return false
	var occupied := {}
	var cities := {}
	for player in [data.human] + data.rivals:
		if typeof(player) != TYPE_DICTIONARY:
			return false
		if not player.has("gold") or typeof(player.get("units")) != TYPE_ARRAY or typeof(player.get("cities")) != TYPE_ARRAY:
			return false
		if not _is_number(player.gold):
			return false
		if not _valid_magic_state(player):
			return false
		for unit in player.units:
			if not _valid_entity(unit, ["kind"], ["hp", "movement_left"]) or occupied.has(str(unit.coord)):
				return false
			occupied[str(unit.coord)] = true
			if unit.has("move_order_target") and not _valid_coord(unit.move_order_target):
				return false
		for city in player.cities:
			if not _valid_entity(city, ["name", "production_item"], ["population", "stored_food", "stored_production"]) or cities.has(str(city.coord)):
				return false
			for key in ["hp", "shield", "siege_turns", "original_owner_index"]:
				if city.has(key) and not _is_number(city[key]):
					return false
			if city.has("captured_developed") and typeof(city.captured_developed) != TYPE_BOOL:
				return false
			cities[str(city.coord)] = true
			for key in ["worked_tiles", "owned_tiles"]:
				if not _valid_coord_list(city.get(key, [])):
					return false
			if typeof(city.get("buildings", [])) != TYPE_ARRAY or typeof(city.get("building_coords", {})) != TYPE_DICTIONARY:
				return false
			if not _string_list(city.get("buildings", [])):
				return false
			for coord in city.get("building_coords", {}).values():
				if not _valid_coord(coord):
					return false
			if city.has("pending_building_coord") and not _valid_coord(city.pending_building_coord):
				return false
		for key in ["known_enemy_cities", "explored_tiles"]:
			if not _valid_coord_list(player.get(key, [])):
				return false
		for key in ["researched_techs", "researched_magic"]:
			if not _string_list(player.get(key, [])):
				return false
		for key in ["research_saved_progress", "spell_cooldowns"]:
			if typeof(player.get(key, {})) != TYPE_DICTIONARY:
				return false
		if player.has("arcane_ritual_city_coord") and not _valid_coord(player.arcane_ritual_city_coord):
			return false
	for key in ["explored_coords", "cleared_lair_coords", "lair_structure_hp", "lair_alerts", "terrain_changes", "pillaged_tiles"]:
		if not _valid_coord_list(data.get(key, [])):
			return false
	for key in ["neutral_units", "relations", "trade_routes"]:
		if typeof(data.get(key, [])) != TYPE_ARRAY:
			return false
	for unit in data.get("neutral_units", []):
		if not _valid_entity(unit, ["kind"], ["hp"]) or occupied.has(str(unit.coord)):
			return false
		occupied[str(unit.coord)] = true
	return _valid_world_state(data)

func _numeric_dict(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for entry in value.values():
		if not _is_number(entry):
			return false
	return true

func _number_list(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for entry in value:
		if not _is_number(entry):
			return false
	return true

func _string_list(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for entry in value:
		if typeof(entry) != TYPE_STRING:
			return false
	return true

func _valid_magic_state(player: Dictionary) -> bool:
	for key in ["mana", "mana_income_per_turn", "war_weariness", "research_progress", "territorial_streak", "arcane_ritual_streak", "arcane_last_tick"]:
		if player.has(key) and not _is_number(player[key]):
			return false
	if typeof(player.get("current_research", "")) != TYPE_STRING:
		return false
	for key in ["arcane_ritual_active", "at_war_with_human", "supremacy_announced"]:
		if player.has(key) and typeof(player[key]) != TYPE_BOOL:
			return false
	var campaign = player.get("war_campaign")
	if campaign != null and (typeof(campaign) != TYPE_DICTIONARY or not _valid_coord(campaign.get("target_coord")) or typeof(campaign.get("objective")) != TYPE_STRING or typeof(campaign.get("status")) != TYPE_STRING):
		return false
	for key in ["research_saved_progress", "spell_cooldowns"]:
		if not _numeric_dict(player.get(key, {})):
			return false
	if not _number_list(player.get("arcane_ritual_units", [])) or typeof(player.get("completed_rituals", {})) != TYPE_DICTIONARY:
		return false
	if player.has("ai_rng_state") and (typeof(player.ai_rng_state) != TYPE_STRING or not player.ai_rng_state.is_valid_int()):
		return false
	var serials := {}
	for unit in player.units:
		if typeof(unit) != TYPE_DICTIONARY:
			return false
		for key in ["embarked", "fortified", "exploring"]:
			if unit.has(key) and typeof(unit[key]) != TYPE_BOOL:
				return false
		for key in ["magic_cooldowns", "magic_status"]:
			if not _numeric_dict(unit.get(key, {})):
				return false
		for key in ["serial_id", "summoner_id", "expires_turn", "kills", "veterancy_level"]:
			if unit.has(key) and not _is_number(unit[key]):
				return false
		if typeof(unit.get("ritual_id", "")) != TYPE_STRING or not _valid_coord(unit.get("boss_target", [0, 0])):
			return false
		var serial := int(unit.get("serial_id", 0))
		if serial > 0 and serials.has(serial):
			return false
		serials[serial] = true
	for key in ["magic_effects", "rituals"]:
		if typeof(player.get(key, [])) != TYPE_ARRAY:
			return false
	for region in player.get("magic_effects", []):
		if typeof(region) != TYPE_DICTIONARY or typeof(region.get("effect")) != TYPE_STRING:
			return false
		if not _valid_coord(region.get("center")) or not _valid_coord(region.get("origin", [0, 0])):
			return false
		if not _is_number(region.get("radius")) or not _is_number(region.get("expires")) or float(region.radius) < 0 or float(region.radius) > 12:
			return false
		if not _valid_coord_list(region.get("changes", [])):
			return false
		for change in region.get("changes", []):
			if change.size() != 4 or not _is_number(change[2]) or typeof(change[3]) != TYPE_STRING:
				return false
	for ritual in player.get("rituals", []):
		if typeof(ritual) != TYPE_DICTIONARY:
			return false
		for key in ["id", "spell", "effect", "school", "status"]:
			if typeof(ritual.get(key)) != TYPE_STRING:
				return false
		if not MagicContent.SCHOOLS.has(ritual.school) or not ritual.status in ["channeling", "completed", "interrupted"]:
			return false
		if not _valid_coord(ritual.get("seat")) or not _valid_coord(ritual.get("target")) or not _number_list(ritual.get("units")):
			return false
		for key in ["progress", "turns", "started", "last_tick"]:
			if not _is_number(ritual.get(key)):
				return false
	return true

func _valid_world_state(data: Dictionary) -> bool:
	for key in ["terrain_changes", "terrain_resources", "pillaged_tiles"]:
		if not _valid_coord_list(data.get(key, [])):
			return false
		for entry in data.get(key, []):
			if entry.size() != 3:
				return false
			if key == "terrain_resources":
				if typeof(entry[2]) != TYPE_STRING:
					return false
			elif not _is_number(entry[2]):
				return false
	for route in data.get("trade_routes", []):
		if not _number_list(route) or route.size() != 4:
			return false
	for relation in data.get("relations", []):
		if typeof(relation) != TYPE_DICTIONARY or not _number_list(relation.get("wars", [])) or typeof(relation.get("campaigns", [])) != TYPE_ARRAY:
			return false
		if not _valid_coord_list(relation.get("truces", [])) or typeof(relation.get("reasons", {})) != TYPE_DICTIONARY:
			return false
		for reason in relation.get("reasons", {}).values():
			if typeof(reason) != TYPE_STRING:
				return false
		for campaign in relation.get("campaigns", []):
			if typeof(campaign) != TYPE_DICTIONARY or not _is_number(campaign.get("opponent")) or not _valid_coord(campaign.get("target_coord")):
				return false
			if typeof(campaign.get("objective")) != TYPE_STRING or typeof(campaign.get("status")) != TYPE_STRING:
				return false
	return _valid_world_events(data.get("world_events", {}))

func _valid_world_events(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not _is_number(value.get("next_event_id", 0)) or typeof(value.get("events", [])) != TYPE_ARRAY:
		return false
	for event in value.get("events", []):
		if typeof(event) != TYPE_DICTIONARY:
			return false
		for key in ["event_type", "phase"]:
			if typeof(event.get(key, "")) != TYPE_STRING:
				return false
		for key in ["event_id", "turn_started", "turn_deadline", "target_civ_index", "raids_done"]:
			if event.has(key) and not _is_number(event[key]):
				return false
		for key in ["origin_region", "spawn_coord", "current_target_city_coord", "last_raided_city_coord", "last_unit_coord"]:
			if event.has(key) and not _valid_coord(event[key]):
				return false
		for key in ["civ_visits", "damage_by_civ"]:
			if not _numeric_dict(event.get(key, {})):
				return false
		for key in ["participants", "result"]:
			if typeof(event.get(key, {})) != TYPE_DICTIONARY:
				return false
		for participant in event.get("participants", {}).values():
			if typeof(participant) != TYPE_DICTIONARY or typeof(participant.get("decision", false)) != TYPE_BOOL:
				return false
	return true

func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func _valid_coord(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY and value.size() >= 2 and _is_number(value[0]) and _is_number(value[1])

func _valid_coord_list(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for coord in value:
		if not _valid_coord(coord):
			return false
	return true

func _valid_entity(value: Variant, strings: Array, numbers: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not _valid_coord(value.get("coord")):
		return false
	for key in strings:
		if typeof(value.get(key)) != TYPE_STRING:
			return false
	for key in numbers:
		if not _is_number(value.get(key)):
			return false
	return true

func _serialize_explored(hex_grid: HexGrid) -> Array:
	var out := []
	for coord in hex_grid.visibility.keys():
		if hex_grid.visibility[coord] != HexGrid.Visibility.UNSEEN:
			out.append([coord.x, coord.y])
	return out

func _serialize_terrain_resources(grid: HexGrid) -> Array:
	var result := []
	for coord in grid.terrain_changes:
		result.append([coord.x, coord.y, grid.get_tile(coord).resource])
	return result

## Todo monstro neutro vivo no mapa (guardiao de covil original OU reforco/
## resultado de patrulha, ver HexGrid.neutral_units) — cobre o mapa de
## monstros por INTEIRO, nao so quais covis foram limpos, porque
## generate_map() (chamado no load) so recria deterministicamente o
## povoamento de uma partida NOVA (guardioes originais, nenhum reforco),
## nunca o estado real de uma partida em andamento.
func _serialize_neutral_units(hex_grid: HexGrid) -> Array:
	var out := []
	for unit in hex_grid.neutral_units():
		out.append({
			"kind": unit.unit_data.visual_kind,
			"serial_id": unit.serial_id,
			"magic_cooldowns": unit.magic_cooldowns,
			"magic_status": unit.magic_status,
			"summoner_id": unit.summoner_id,
			"expires_turn": unit.expires_turn,
			"ritual_id": unit.ritual_id,
			"boss_target": MagicRuntime.packed(unit.boss_target),
			"coord": [unit.coord.x, unit.coord.y],
			"hp": unit.hp,
			"kills": unit.kills,
			"veterancy_level": unit.veterancy_level,
			"is_camp_boss": unit.is_camp_boss,
			"behavior_state": unit.monster_behavior_state,
			"movement_left": unit.movement_left,
		})
	return out

## Coords de covil ja DESTRUIDOS nesta partida (ver HexGrid.destroy_lair) —
## ao contrario dos monstros vivos acima, generate_map() no load sempre
## recria TODO covil do zero a partir da semente, entao precisa dessa
## lista pra saber quais reverter de novo (ver load_game).
func _serialize_cleared_lairs(hex_grid: HexGrid) -> Array:
	var out := []
	for coord in hex_grid.cleared_lair_coords:
		out.append([coord.x, coord.y])
	return out

## COVIS DE MONSTROS -- DESTRUICAO: HP da propria LairStructure (ver
## CombatResolver.resolve_lair_attack), separado de cleared_lair_coords
## acima -- um covil pode estar PARCIALMENTE atacado (guardiao morto,
## estrutura ainda de pe com HP reduzido) sem estar destruido de vez.
## Sem isto, generate_map() no load sempre respawna a estrutura com HP
## CHEIO de novo, perdendo o progresso do cerco. So grava os que ja levaram
## dano (hp < max_hp) pra nao inchar o save com toda estrutura intacta.
func _serialize_lair_structure_hp(hex_grid: HexGrid) -> Array:
	var out := []
	for coord in hex_grid.lairs_by_coord:
		var structure: LairStructure = hex_grid.lairs_by_coord[coord]
		if structure.hp < structure.max_hp:
			out.append([coord.x, coord.y, structure.hp])
	return out

## AGGRO / TERRITORIO DE AMEACA: covil ALERTADO (ver HexGrid.alert_lair_
## near/is_lair_alerted) e' um efeito TEMPORARIO (turno de expiracao
## absoluto) -- sem persistir isto, salvar/carregar no meio de um alerta
## ativo esqueceria a provocacao e o territorio voltaria a vigilancia
## normal antes da hora, mesmo padrao de pillaged_tiles (expiracao por
## turno absoluto, ja persistida do mesmo jeito).
func _serialize_lair_alerts(hex_grid: HexGrid) -> Array:
	var out := []
	for coord in hex_grid.lair_alert_until_turn:
		out.append([coord.x, coord.y, hex_grid.lair_alert_until_turn[coord]])
	return out

## Espelha _deserialize_player (mesmos campos, mesma ordem de restauracao:
## spawna primeiro com os dados base do tipo, depois sobrescreve hp/kills/
## veterancia por cima) — so que via HexGrid.spawn_monster_at (owner_player
## null) em vez de HexGrid.spawn_unit (dono = jogador). `is_camp_boss`
## precisa ir NO SPAWN (create_monster usa pra escalar HP/ataque e travar
## movement_points), o resto so sobrescreve depois igual sempre.
func _deserialize_neutral_units(saved: Array, hex_grid: HexGrid) -> void:
	for u in saved:
		var coord = Vector2i(int(u.coord[0]), int(u.coord[1]))
		var unit = hex_grid.spawn_monster_at(coord, u.kind, u.get("is_camp_boss", false))
		unit.set_hp_silent(float(u.hp)) # restauracao, nao um golpe -- nao deveria piscar/pular (ver Unit.hp)
		unit.kills = int(u.get("kills", 0))
		unit.veterancy_level = int(u.get("veterancy_level", 0))
		unit.monster_behavior_state = u.get("behavior_state", "")
		unit.movement_left = float(u.get("movement_left", unit.unit_data.movement_points))

func _serialize_player(player: PlayerData, is_rival: bool) -> Dictionary:
	var units := []
	for unit in player.units:
		units.append({
			"kind": unit.unit_data.visual_kind,
			"serial_id": unit.serial_id,
			"magic_cooldowns": unit.magic_cooldowns,
			"magic_status": unit.magic_status,
			"summoner_id": unit.summoner_id,
			"expires_turn": unit.expires_turn,
			"ritual_id": unit.ritual_id,
			"boss_target": MagicRuntime.packed(unit.boss_target),
			"coord": [unit.coord.x, unit.coord.y],
			"hp": unit.hp,
			"movement_left": unit.movement_left,
			"kills": unit.kills,
			"veterancy_level": unit.veterancy_level,
			# Roadmap 2.0 Parte 1 (C6) — EXCECAO deliberada: diferente de
			# fortified/exploring/move_order_target (conveniencia de sessao,
			# de proposito descartados ao salvar), perder isto deixaria uma
			# unidade presa em pleno oceano tratada como terrestre apos
			# carregar — um estado invalido, nao so uma conveniencia perdida
			# (ver comentario de Unit.embarked).
			"embarked": unit.embarked,
			"fortified": unit.fortified,
			"exploring": unit.exploring,
			"move_order_target": [unit.move_order_target.x, unit.move_order_target.y],
		})
	var cities := []
	for city in player.cities:
		var worked := []
		for w in city.worked_tiles:
			worked.append([w.x, w.y])
		var owned := []
		for o in city.owned_tiles:
			owned.append([o.x, o.y])
		var building_coords_out := {}
		for id in city.building_coords.keys():
			var bc: Vector2i = city.building_coords[id]
			building_coords_out[id] = [bc.x, bc.y]
		var city_dict := {
			"original_owner_index": city.original_owner_index,
			"captured_developed": city.captured_developed,
			"coord": [city.coord.x, city.coord.y],
			"name": city.city_name,
			"population": city.population,
			"stored_food": city.stored_food,
			"stored_production": city.stored_production,
			"hp": city.hp,
			"shield": city.shield,
			"siege_turns": city._consecutive_siege_turns,
			"production_item": city.production_item,
			"worked_tiles": worked,
			"owned_tiles": owned,
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
		"researched_magic": player.researched_magic.keys(),
		"current_research": player.current_research,
		"research_progress": player.research_progress,
		"research_saved_progress": player.research_saved_progress,
		"magic_effects": player.magic_effects,
		"rituals": player.rituals,
		"completed_rituals": player.completed_rituals,
		"spell_cooldowns": player.spell_cooldowns,
		"mana": player.mana,
		"mana_income_per_turn": player.mana_income_per_turn,
		"war_weariness": player.war_weariness,
		"explored_tiles": _serialize_coord_values(player.explored_tiles),
		# Roadmap "Fase F" F1/F2/F4 — estado das duas vitorias de sustentacao,
		# QUALQUER jogador (humano ou rival, diferente de war_campaign abaixo
		# que e so-contra-humano): territorial_streak e arcane_ritual_* sao
		# historico acumulado de verdade, perder isso ao salvar/carregar
		# "roubaria" turnos de sustentacao ja conquistados.
		"territorial_streak": player.territorial_streak,
		"supremacy_announced": player.supremacy_announced,
		"arcane_ritual_active": player.arcane_ritual_active,
		"arcane_ritual_city_coord": [player.arcane_ritual_city_coord.x, player.arcane_ritual_city_coord.y],
		"arcane_ritual_streak": player.arcane_ritual_streak,
		"arcane_ritual_units": player.arcane_ritual_units,
		"arcane_last_tick": player.arcane_last_tick,
	}
	if is_rival:
		result["at_war_with_human"] = player.is_at_war_with(GameManager.human_player)
		# Roadmap "Parte C" C3 — so contra o humano de proposito: RivalAI.
		# decide_war/decide_campaign nunca sao chamados com outro oponente
		# (rivais nunca guerreiam entre si, ver Diplomacy.gd) — mesma
		# suposicao que at_war_with_human ja faz, sem esquema de indice/
		# sentinela pra outros PlayerData nenhum.
		var campaign: Dictionary = player.war_campaigns.get(GameManager.human_player, {})
		if not campaign.is_empty():
			result["war_campaign"] = {
				"objective": campaign.objective,
				"target_coord": [campaign.target_coord.x, campaign.target_coord.y],
				"status": campaign.status,
			}
	result["ai_rng_state"] = str(player.ai_rng.state)
	return result

func _deserialize_player(saved: Dictionary, player: PlayerData, hex_grid: HexGrid, version: int = SAVE_VERSION) -> void:
	player.gold = float(saved.gold)
	if saved.has("ai_rng_state"):
		player.ai_rng.state = int(saved.ai_rng_state)
	for u in saved.units:
		var coord = Vector2i(int(u.coord[0]), int(u.coord[1]))
		var unit = hex_grid.spawn_unit(coord, UnitDatabase.create_unit(u.kind), player)
		unit.serial_id = int(u.get("serial_id", unit.serial_id))
		hex_grid.next_unit_id = maxi(hex_grid.next_unit_id, unit.serial_id + 1)
		unit.magic_cooldowns = u.get("magic_cooldowns", {}).duplicate()
		unit.magic_status = u.get("magic_status", {}).duplicate()
		unit.summoner_id = int(u.get("summoner_id", 0))
		unit.expires_turn = int(u.get("expires_turn", 0))
		unit.ritual_id = u.get("ritual_id", "")
		unit.boss_target = MagicRuntime.coord_of(u.get("boss_target", [999999, 999999]))
		unit.set_hp_silent(float(u.hp)) # restauracao, nao um golpe -- nao deveria piscar/pular (ver Unit.hp)
		unit.movement_left = float(u.movement_left)
		unit.kills = int(u.get("kills", 0))
		unit.veterancy_level = int(u.get("veterancy_level", 0))
		unit.embarked = u.get("embarked", false) # Roadmap 2.0 Parte 1 (C6)
		unit.fortified = u.get("fortified", false)
		unit.exploring = u.get("exploring", false)
		var order = u.get("move_order_target", [Unit.NO_MOVE_ORDER.x, Unit.NO_MOVE_ORDER.y])
		unit.move_order_target = Vector2i(int(order[0]), int(order[1]))
	for c in saved.cities:
		var coord = Vector2i(int(c.coord[0]), int(c.coord[1]))
		var city = hex_grid.found_city(coord, player, c.name, true)
		city.original_owner_index = int(c.get("original_owner_index", city.original_owner_index))
		city.captured_developed = c.get("captured_developed", false)
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
		# found_city() ja inicializou owned_tiles com celula+6 vizinhos (ver
		# HexGrid.found_city) — sobrescreve com o territorio EXATO salvo,
		# que pode ser maior (cidade que ja cresceu, ver City.
		# _claim_frontier_tile), mesmo padrao de worked_tiles acima.
		var owned: Array[Vector2i] = []
		for o in c.get("owned_tiles", []):
			owned.append(Vector2i(int(o[0]), int(o[1])))
		city.owned_tiles = owned
		for id in c.get("buildings", []):
			city.buildings[id] = true
		# get(..., max_*()) com fallback: save ANTIGO (de antes de hp/shield
		# existirem) carrega a cidade com vida/escudo cheios em vez de
		# quebrar. Le DEPOIS de population E buildings (Muralhas) ja
		# restauradas acima — senao o fallback calcularia max_hp()/
		# max_shield() errado (population ainda no default 1, "walls"
		# ainda ausente de buildings).
		city.hp = float(c.get("hp", city.max_hp()))
		city.shield = float(c.get("shield", city.max_shield()))
		city._consecutive_siege_turns = int(c.get("siege_turns", 0))
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
		# found_city() acima ja desenhou o cluster de casas/torre/muralha uma
		# vez, mas com populacao 1 e buildings vazio (os dois so foram
		# restaurados DEPOIS, nas linhas acima) — sem refazer agora, uma
		# cidade carregada com populacao 5+ nao mostraria a torre grande, e
		# uma com Muralhas construida nao mostraria o anel (ver City.
		# _build_visual_procedural/_add_walls), os dois so apareceriam no
		# PROXIMO ponto de crescimento de populacao.
		city._build_visual_procedural()
		city._refresh_label()
		city._update_life_bars() # hp/shield restaurados acima, com population/buildings ja no valor final
	for coord_arr in saved.get("known_enemy_cities", []):
		player.known_enemy_cities[Vector2i(int(coord_arr[0]), int(coord_arr[1]))] = true
	for id in saved.get("researched_techs", []):
		player.researched_techs[id] = true
	for id in saved.get("researched_magic", []):
		player.researched_magic[id] = true
	# Migracao de save v17 (MIGRATABLE_SAVE_VERSION): antes da separacao
	# estrutural das arvores, researched_techs guardava ids das DUAS arvores
	# misturados, e nao existia a chave "researched_magic" no save. Sinal de
	# formato antigo == ausencia dessa chave (mais robusto que checar
	# `saved.version`, que so existe no dict raiz do save, nao no dict de
	# CADA jogador que _deserialize_player recebe). Reclassifica pelo
	# proprio id: quem existe em MagicDatabase (e nao em TechDatabase) muda
	# de dicionario — nenhum progresso perdido, current_research/
	# research_progress nao precisam de migracao (o id continua o mesmo,
	# so passa a ser resolvido pela base certa em runtime).
	if not saved.has("researched_magic"):
		for id in player.researched_techs.keys().duplicate():
			if TechDatabase.get_tech(id) == null and MagicDatabase.get_tech(id) != null:
				player.researched_techs.erase(id)
				player.researched_magic[id] = true
	# Migracao de ids da arvore de Tecnologia (redesenho de 10 niveis, v19,
	# ver TECH_TIER_REDESIGN_REMAP) — roda incondicionalmente (checa so a
	# PRESENCA de cada id antigo, nao a versao do save): nenhum dos 9 ids
	# antigos volta a existir na arvore nova, entao um save ja migrado
	# nunca teria essas chaves pra bater aqui mesmo.
	var saved_current_research: String = saved.get("current_research", "")
	if version < 19:
		for old_id in TECH_TIER_REDESIGN_REMAP.keys():
			if player.researched_techs.has(old_id):
				player.researched_techs.erase(old_id)
				for new_id in TECH_TIER_REDESIGN_REMAP[old_id]:
					player.researched_techs[new_id] = true
			# Pesquisa EM ANDAMENTO num id que sumiu: redireciona pro primeiro id
			# novo do mapeamento, preservando o progresso acumulado (perder tudo
			# seria pior que uma redirecao best-effort).
			if saved_current_research == old_id:
				saved_current_research = TECH_TIER_REDESIGN_REMAP[old_id][0]
	player.current_research = saved_current_research
	player.research_progress = float(saved.get("research_progress", 0.0))
	player.research_saved_progress = saved.get("research_saved_progress", {}).duplicate()
	player.magic_effects = saved.get("magic_effects", []).duplicate(true)
	player.rituals = saved.get("rituals", []).duplicate(true)
	player.completed_rituals = saved.get("completed_rituals", {}).duplicate()
	for region in player.magic_effects:
		for changed in region.get("changes", []):
			var changed_tile := hex_grid.get_tile(MagicRuntime.coord_of(changed))
			if changed_tile:
				changed_tile.resource = changed[3]
	if version < 21:
		MagicDatabase.migrate_legacy_research(player)
	var cooldowns: Dictionary = saved.get("spell_cooldowns", {})
	for spell_name in cooldowns.keys():
		player.spell_cooldowns[spell_name] = int(cooldowns[spell_name])
	player.mana = float(saved.get("mana", 0.0))
	player.mana_income_per_turn = float(saved.get("mana_income_per_turn", 0.0))
	player.war_weariness = float(saved.get("war_weariness", 0.0))
	for entry in saved.get("explored_tiles", []):
		player.explored_tiles[Vector2i(int(entry[0]), int(entry[1]))] = true
	# Roadmap "Fase F" F1/F2/F4 — get(..., default) com o MESMO default do
	# campo em PlayerData.gd: save ANTIGO (de antes destes 4 campos
	# existirem) carrega um jogador sem sustentacao nenhuma em andamento em
	# vez de quebrar, mesmo padrao de fallback ja usado pra hp/shield acima.
	player.territorial_streak = int(saved.get("territorial_streak", 0))
	player.supremacy_announced = saved.get("supremacy_announced", false)
	player.arcane_ritual_active = saved.get("arcane_ritual_active", false)
	player.arcane_ritual_streak = int(saved.get("arcane_ritual_streak", 0))
	player.arcane_ritual_units.clear()
	for id in saved.get("arcane_ritual_units", []):
		player.arcane_ritual_units.append(int(id))
	player.arcane_last_tick = int(saved.get("arcane_last_tick", -1))
	var ritual_coord = saved.get("arcane_ritual_city_coord", null)
	if ritual_coord != null:
		player.arcane_ritual_city_coord = Vector2i(int(ritual_coord[0]), int(ritual_coord[1]))
	# Roadmap "Parte C" C3 — cabe na funcao UNICA compartilhada (chamada pra
	# humano E cada rival) sem branch de is_rival: pro humano, a chave nunca
	# foi escrita em _serialize_player, entao "war_campaign" sempre resolve
	# null aqui. GameManager.human_player ja existe nesse ponto (setup_
	# players() roda antes de qualquer _deserialize_player, ver load_game).
	var campaign_data = saved.get("war_campaign", null)
	if campaign_data != null:
		var tc = campaign_data.target_coord
		player.war_campaigns[GameManager.human_player] = {
			"objective": campaign_data.objective,
			"target_coord": Vector2i(int(tc[0]), int(tc[1])),
			"status": campaign_data.status,
		}

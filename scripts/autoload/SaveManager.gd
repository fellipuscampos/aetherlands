extends Node

## Salva/carrega o estado logico da partida em JSON (user://savegame.json).
## Nao serializa nodes 3D nem visual nenhum — so os dados que importam pro
## jogo (terreno via semente + raio, jogadores, unidades, cidades, turno,
## fog explorado). Recarregar reconstroi tudo chamando os mesmos caminhos
## de spawn/fundacao usados num jogo novo (HexGrid.spawn_unit/found_city),
## depois reaplica hp/movimento/producao por cima.

const SAVE_PATH := "user://savegame.json"
## Versoes anteriores aceitas por load_game ALEM de SAVE_VERSION (pedido do usuario: "NAO simplesmente
## invalide saves antigos"). As migrações específicas delas (pesquisa Tecnologia/Magia V1) perderam o
## objeto na Fase 25: o conteúdo V1 é ignorado/sanitizado, o resto do save carrega normalmente.
const MIGRATABLE_SAVE_VERSIONS: Array[int] = [17, 18, 19, 20]
## Fase 25: continua 21 de propósito — o loader é tolerante (campos antigos são ignorados, campos
## novos têm default, conteúdo removido passa por _sanitize_legacy_city/_deserialize_player). As
## versões 17-20 ainda carregam: tudo o que as migrações antigas convertiam (pesquisa Tecnologia/
## Magia V1) deixou de existir e simplesmente é ignorado.
const SAVE_VERSION := 21

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
		"terrain_changes": _serialize_coord_values(hex_grid.terrain_changes),
		"terrain_resources": _serialize_terrain_resources(hex_grid),
		"pillaged_tiles": _serialize_coord_values(hex_grid._pillaged_tiles),
		# Fase 20: modificações físicas de terreno V2 — estado GLOBAL do mapa (fora de cidades), lista esparsa
		# [x, y, id]. Campo opcional (sem bump de versão); custo/Defesa nunca são salvos (derivados do id).
		"v2_terrain_modifications": _serialize_terrain_modifications(hex_grid),
		# Fase 21: efeito global opcional do mapa. Só dados puros; índices/markers são reconstruídos no load.
		"v2_portal_pairs": V2PortalSystem.to_save_array(hex_grid),
		# Fase 22: camada ambiental global, esparsa e opcional. Efeitos são
		# derivados do zone_id; só identidade/dono/duração materializada viajam.
		"v2_environmental_zones": V2EnvironmentalZoneSystem.to_save_array(hex_grid),
		# Fase 23: estado global opcional e mínimo do Ritual Final; owner por
		# índice estável, site por coordenada e relógio idempotente.
		"v2_transcendence_rituals": V2TranscendenceSystem.to_save_array(),
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

	hex_grid.generate_map(int(data.map_width), int(data.map_height), int(data.map_seed))
	for entry in data.get("terrain_changes", []):
		hex_grid.transform_tile_terrain(Vector2i(int(entry[0]), int(entry[1])), int(entry[2]))
	for entry in data.get("terrain_resources", []):
		var tile := hex_grid.get_tile(Vector2i(int(entry[0]), int(entry[1])))
		if tile:
			tile.resource = str(entry[2])
	for entry in data.get("pillaged_tiles", []):
		hex_grid._pillaged_tiles[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])
	_deserialize_terrain_modifications(hex_grid, data.get("v2_terrain_modifications", []))
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
	_restore_relations(data)
	# Depois de jogadores, cidades, prédios e melhorias: identidade por índice já existe e qualquer
	# endpoint que uma estrutura restaurada tornou impossível é descartado fail-safe.
	V2PortalSystem.load_save_array(data.get("v2_portal_pairs", []), hex_grid)
	V2EnvironmentalZoneSystem.load_save_array(data.get("v2_environmental_zones", []), hex_grid)
	# Só agora todas as pesquisas, cidades, prédios e unidades existem. Load
	# inválido é descartado silenciosamente e markers são reconstruídos.
	V2TranscendenceSystem.load_save_array(data.get("v2_transcendence_rituals", []), hex_grid)

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

## Guerras, tréguas, motivos e campanhas. Fase 25: o bloco antigo "trade_routes" (comércio V1,
## removido) é simplesmente ignorado.
func _restore_relations(data: Dictionary) -> void:
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
	var occupied := {}
	var cities := {}
	for player in [data.human] + data.rivals:
		if typeof(player) != TYPE_DICTIONARY:
			return false
		if not player.has("gold") or typeof(player.get("units")) != TYPE_ARRAY or typeof(player.get("cities")) != TYPE_ARRAY:
			return false
		if not _is_number(player.gold):
			return false
		if not _valid_player_state(player):
			return false
		for unit in player.units:
			if not _valid_entity(unit, ["kind"], ["hp", "movement_left"]) or occupied.has(str(unit.coord)):
				return false
			occupied[str(unit.coord)] = true
			if unit.has("move_order_target") and not _valid_coord(unit.move_order_target):
				return false
		for city in player.cities:
			if not _valid_entity(city, ["name", "production_item"], ["stored_production"]) or cities.has(str(city.coord)):
				return false
			for key in ["hp", "shield", "siege_turns", "original_owner_index"]:
				if city.has(key) and not _is_number(city[key]):
					return false
			cities[str(city.coord)] = true
			if not _valid_coord_list(city.get("owned_tiles", [])):
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
	for key in ["explored_coords", "cleared_lair_coords", "lair_structure_hp", "lair_alerts", "terrain_changes", "pillaged_tiles"]:
		if not _valid_coord_list(data.get(key, [])):
			return false
	for key in ["neutral_units", "relations"]:
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

## Campos de jogador que o jogo ainda LÊ (Fase 25). Os campos da pesquisa/magia/vitórias V1 que um
## save antigo possa ter (researched_*, current_research, rituals, magic_effects, arcane_ritual_*...)
## não são mais validados nem lidos — nunca derrubam o load e nunca concedem nada.
func _valid_player_state(player: Dictionary) -> bool:
	for key in ["mana", "mana_income_per_turn", "war_weariness"]:
		if player.has(key) and not _is_number(player[key]):
			return false
	if player.has("at_war_with_human") and typeof(player.at_war_with_human) != TYPE_BOOL:
		return false
	var campaign = player.get("war_campaign")
	if campaign != null and (typeof(campaign) != TYPE_DICTIONARY or not _valid_coord(campaign.get("target_coord")) or typeof(campaign.get("objective")) != TYPE_STRING or typeof(campaign.get("status")) != TYPE_STRING):
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
		for key in ["serial_id", "kills", "veterancy_level"]:
			if unit.has(key) and not _is_number(unit[key]):
				return false
		var serial := int(unit.get("serial_id", 0))
		if serial > 0 and serials.has(serial):
			return false
		serials[serial] = true
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

func _serialize_terrain_modifications(grid: HexGrid) -> Array:
	var result := []
	for coord in grid.v2_terrain_modifications:
		result.append([coord.x, coord.y, String(grid.v2_terrain_modifications[coord])])
	return result

## Fase 20 — restaura ANTES de cidades/prédios (que limpam o próprio tile ao serem recolocados). Fail-safe: entrada
## malformada, tile inexistente ou id desconhecido é ignorada sem derrubar o save; save antigo sem o campo = nenhuma.
func _deserialize_terrain_modifications(grid: HexGrid, entries) -> void:
	if typeof(entries) != TYPE_ARRAY:
		return
	for entry in entries:
		if typeof(entry) != TYPE_ARRAY or entry.size() != 3 or not _is_number(entry[0]) or not _is_number(entry[1]) or typeof(entry[2]) != TYPE_STRING:
			continue
		V2TerrainRuntime.restore(grid, Vector2i(int(entry[0]), int(entry[1])), entry[2])

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
			"coord": [unit.coord.x, unit.coord.y],
			"hp": unit.hp,
			"movement_left": unit.movement_left,
			"kills": unit.kills,
			"veterancy_level": unit.veterancy_level,
			# Aetherlands V2, Fase 15 — cargas restantes do Construtor (0 pra qualquer outra
			# unidade, nunca lido fora de V2ConstructorRuntime). Campo opcional, mesmo padrão dos
			# outros blocos V2 (sem bump de SAVE_VERSION).
			"work_charges_remaining": unit.work_charges_remaining,
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
		var owned := []
		for o in city.owned_tiles:
			owned.append([o.x, o.y])
		var building_coords_out := {}
		for id in city.building_coords.keys():
			var bc: Vector2i = city.building_coords[id]
			building_coords_out[id] = [bc.x, bc.y]
		# Aetherlands V2, Fase 14 — posições físicas de CADA cópia de um prédio repetível
		# (CopyLimitMode.CITY_LEVEL, ver City.repeatable_building_coords) — campo OPCIONAL
		# separado de building_coords, mesmo padrão de repeatable_building_counts na Fase 13.
		var repeatable_building_coords_out := {}
		for id in city.repeatable_building_coords.keys():
			var coord_list := []
			for rc in city.repeatable_building_coords[id]:
				coord_list.append([rc.x, rc.y])
			repeatable_building_coords_out[id] = coord_list
		# Aetherlands V2, Fase 15 -- melhorias de recurso construídas pelo Construtor (§77 do
		# pedido: só improvement_id + coord; o yield é sempre derivado, nunca salvo).
		var resource_improvements_out := {}
		for coord in city.resource_improvements.keys():
			resource_improvements_out["%d,%d" % [coord.x, coord.y]] = city.resource_improvements[coord]
		var city_dict := {
			"original_owner_index": city.original_owner_index,
			"coord": [city.coord.x, city.coord.y],
			"name": city.city_name,
			"stored_production": city.stored_production,
			"hp": city.hp,
			"shield": city.shield,
			"siege_turns": city._consecutive_siege_turns,
			"production_item": city.production_item,
			"owned_tiles": owned,
			"buildings": city.buildings.keys(),
			"building_coords": building_coords_out,
			# Aetherlands V2 Fase 13: campos OPCIONAIS por cidade (sem bump de SAVE_VERSION,
			# mesmo padrão de "v2_research" na Fase 1) — save antigo sem eles carrega com
			# city_level=1/annexation_points=0/repeatable_building_counts={} (ver
			# _deserialize_player abaixo), nunca rejeitado por causa disso.
			"city_level": city.city_level,
			"annexation_points": city.annexation_points,
			"repeatable_building_counts": city.repeatable_building_counts.duplicate(),
			"repeatable_building_coords": repeatable_building_coords_out,
			"resource_improvements": resource_improvements_out,
			# Aetherlands V2, Fase 16 -- campos opcionais (sem bump de SAVE_VERSION): Fortificação, o
			# turno do último Ataque da Cidade (recarregar nunca devolve o disparo) e o crédito de
			# Supremacia (id estável do dono anterior). O progresso da Supremacia nunca é salvo.
			"fortification_level": city.fortification_level,
			"last_city_attack_turn": city.last_city_attack_turn,
			"v2_supremacy_captured_from": city.v2_supremacy_captured_from,
		}
		if city.pending_building_coord != City.NO_PENDING_COORD:
			city_dict["pending_building_coord"] = [city.pending_building_coord.x, city.pending_building_coord.y]
		cities.append(city_dict)
	var known_cities := []
	for coord in player.known_enemy_cities.keys():
		known_cities.append([coord.x, coord.y])

	var result := {
		"gold": player.gold, "units": units, "cities": cities, "known_enemy_cities": known_cities,
		# A única progressão do jogo (Fase 25: os campos de pesquisa Tecnologia/Magia V1 deixaram de
		# ser gravados). Save antigo sem o bloco carrega com pesquisa vazia (V2ResearchState.load_dict).
		"v2_research": player.v2_research.to_dict(),
		"mana": player.mana,
		"mana_income_per_turn": player.mana_income_per_turn,
		"war_weariness": player.war_weariness,
		"explored_tiles": _serialize_coord_values(player.explored_tiles),
	}
	if is_rival:
		# Fase 24: estado estratégico mínimo e opcional. Scores, views e alvos
		# são transitórios; save antigo sem o bloco é rederivado pela seed.
		result["v2_ai_strategy"] = player.v2_ai_strategy.to_dict()
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
		# Fase 25: tipo que não existe mais (conjuradores/invocações da magia V1 removida) é descartado
		# em vez de voltar como um Guarda genérico. Unidades V1 mundanas continuam no banco e voltam.
		if not UnitDatabase.is_known_kind(String(u.kind)):
			continue
		var coord = Vector2i(int(u.coord[0]), int(u.coord[1]))
		var unit = hex_grid.spawn_unit(coord, UnitDatabase.create_unit(u.kind), player)
		unit.serial_id = int(u.get("serial_id", unit.serial_id))
		hex_grid.next_unit_id = maxi(hex_grid.next_unit_id, unit.serial_id + 1)
		unit.magic_cooldowns = _sanitize_magic_dict(u.get("magic_cooldowns", {}))
		unit.magic_status = _sanitize_magic_dict(u.get("magic_status", {}))
		unit.refresh_technique_marker() # V2 (Fase 4): o anel de uma Técnica ativa volta junto com o estado
		unit.set_hp_silent(float(u.hp)) # restauracao, nao um golpe -- nao deveria piscar/pular (ver Unit.hp)
		unit.movement_left = float(u.movement_left)
		unit.kills = int(u.get("kills", 0))
		unit.veterancy_level = int(u.get("veterancy_level", 0))
		unit.work_charges_remaining = int(u.get("work_charges_remaining", 0))
		unit.embarked = u.get("embarked", false) # Roadmap 2.0 Parte 1 (C6)
		unit.fortified = u.get("fortified", false)
		unit.exploring = u.get("exploring", false)
		var order = u.get("move_order_target", [Unit.NO_MOVE_ORDER.x, Unit.NO_MOVE_ORDER.y])
		unit.move_order_target = Vector2i(int(order[0]), int(order[1]))
	# Fase 19: o comando de retinues é DERIVADO (nada salvo); os serial_id acima acabaram de ser restaurados,
	# então o anel "sem comando" é re-derivado agora, pela mesma ordem determinística de antes do save.
	V2RetinueSystem.refresh_all_markers(player)
	for saved_city in saved.cities:
		# Fase 25: uma cópia sanitizada — muralhas V1 viram Fortificação, prédios/produção V1 somem.
		var c := _sanitize_legacy_city(saved_city)
		var coord = Vector2i(int(c.coord[0]), int(c.coord[1]))
		var city = hex_grid.found_city(coord, player, c.name, true)
		city.original_owner_index = int(c.get("original_owner_index", city.original_owner_index))
		# set_production() zera stored_production quando o tipo muda (existe
		# pra impedir o JOGADOR de "salvar" progresso trocando de item) — por
		# isso precisa vir ANTES de restaurar stored_production, senao o
		# valor salvo seria zerado de volta aqui mesmo.
		city.set_production(c.production_item)
		# Aetherlands V2 Fase 13: nunca inferir City Level pelo save antigo — sem o campo, a
		# cidade carrega em Cidade I / 0 Pontos de Anexação (legacy default, §42 do pedido).
		city.city_level = V2CityLevelData.clamp_level(int(c.get("city_level", 1)))
		city.annexation_points = maxi(0, int(c.get("annexation_points", 0)))
		var repeatable_in: Dictionary = c.get("repeatable_building_counts", {})
		for id in repeatable_in.keys():
			city.repeatable_building_counts[id] = int(repeatable_in[id])
		city.stored_production = float(c.stored_production)
		# found_city() ja inicializou owned_tiles com celula+6 vizinhos (ver
		# HexGrid.found_city) — sobrescreve com o territorio EXATO salvo,
		# que pode ser maior (anexação, ou território legado).
		var owned: Array[Vector2i] = []
		for o in c.get("owned_tiles", []):
			owned.append(Vector2i(int(o[0]), int(o[1])))
		city.owned_tiles = owned
		for id in c.get("buildings", []):
			city.buildings[id] = true
		# Fase 16/25: Fortificação. A migração da cadeia V1 de muralhas (save antigo sem o campo) já foi
		# feita por _sanitize_legacy_city, que também removeu os prédios de muralha V1.
		city.fortification_level = V2FortificationData.clamp_level(int(c.get("fortification_level", 0)))
		city.last_city_attack_turn = int(c.get("last_city_attack_turn", -1))
		city.v2_supremacy_captured_from = int(c.get("v2_supremacy_captured_from", -1))
		# get(..., max_*()) com fallback: save ANTIGO (de antes de hp/shield existirem) carrega a cidade
		# com vida/escudo cheios. Lido DEPOIS de city_level/fortification_level: o HP máximo vem do City
		# Level e o escudo da Fortificação — um save antigo acima do novo máximo é LIMITADO a ele.
		city.hp = clampf(float(c.get("hp", city.max_hp())), 0.0, city.max_hp())
		city.shield = clampf(float(c.get("shield", city.max_shield())), 0.0, city.max_shield())
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
		# Aetherlands V2, Fase 14 — recria CADA cópia física de um prédio repetível (ver comentário
		# de save acima); save antigo sem o campo carrega com repeatable_building_coords vazio,
		# nunca inferido (mesmo padrão de city_level/annexation_points acima).
		var repeatable_coords_in: Dictionary = c.get("repeatable_building_coords", {})
		for id in repeatable_coords_in.keys():
			var coord_list: Array = []
			for rc_arr in repeatable_coords_in[id]:
				var rc = Vector2i(int(rc_arr[0]), int(rc_arr[1]))
				coord_list.append(rc)
				hex_grid.place_building(rc, id, player)
			city.repeatable_building_coords[id] = coord_list
		# Aetherlands V2, Fase 15 -- melhorias de recurso: o yield é sempre derivado (nunca salvo),
		# só o improvement_id + coord voltam; o marcador visual é reconstruído aqui, mesmo espírito
		# de hex_grid.place_building acima pros prédios.
		var resource_improvements_in: Dictionary = c.get("resource_improvements", {})
		for key in resource_improvements_in.keys():
			var parts: PackedStringArray = String(key).split(",")
			if parts.size() != 2:
				continue
			var rc := Vector2i(int(parts[0]), int(parts[1]))
			city.resource_improvements[rc] = resource_improvements_in[key]
			hex_grid.refresh_resource_improvement_marker(rc)
		if c.has("pending_building_coord"):
			var pc = c.pending_building_coord
			city.pending_building_coord = Vector2i(int(pc[0]), int(pc[1]))
		# found_city() acima ja desenhou o cluster de casas/torre/muralha uma vez, mas com o City Level e
		# a Fortificação ainda no default — refaz agora com os valores restaurados.
		city._build_visual_procedural()
		city._refresh_label()
		city._update_life_bars()
	for coord_arr in saved.get("known_enemy_cities", []):
		player.known_enemy_cities[Vector2i(int(coord_arr[0]), int(coord_arr[1]))] = true
	# Fase 25: os campos da pesquisa Tecnologia/Magia V1 de um save antigo (researched_techs,
	# researched_magic, current_research, research_progress...) são IGNORADOS — nunca convertidos em
	# pesquisa V2 (não existe mapeamento canônico; seria progresso de graça).
	# Aetherlands V2 Fase 1: atualiza NO LUGAR (quem escuta os sinais do estado
	# continua conectado) e sanitiza tudo — bloco ausente/corrompido vira vazio.
	player.v2_research.load_dict(saved.get("v2_research"))
	var rival_index := GameManager.rival_players.find(player)
	if rival_index >= 0:
		var world_seed := GameManager.hex_grid.map_seed if GameManager.hex_grid != null else 0
		player.v2_ai_strategy.load_dict(saved.get("v2_ai_strategy"), rival_index, world_seed, GameManager.rival_players.size())
	player.mana = float(saved.get("mana", 0.0))
	player.mana_income_per_turn = float(saved.get("mana_income_per_turn", 0.0))
	player.war_weariness = float(saved.get("war_weariness", 0.0))
	for entry in saved.get("explored_tiles", []):
		player.explored_tiles[Vector2i(int(entry[0]), int(entry[1]))] = true
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

## Fase 25 — SANITIZAÇÃO CENTRAL de uma cidade salva (uma única rotina; nenhum `if old_market` espalhado
## pelo runtime). Devolve uma CÓPIA do dicionário com:
##  1. Fortificação: um save sem `fortification_level` migra a cadeia V1 de muralhas (Fase 16:
##     Fortaleza/Fortaleza Imperial -> 3, Muralhas II -> 2, Muralhas -> 1; sem nenhuma, 0).
##  2. Prédios: só ids que existem no BuildingDatabase (todos V2) sobrevivem — prédios V1 (econômicos,
##     de treino, muralhas...) somem, junto com a coordenada/modelo e a contagem de cópias; nenhum é
##     convertido num prédio V2 e nada é reembolsado.
##  3. Produção: item V1 removido (prédio V1, tropa V1 que não é mais treinável) é CANCELADO — a cidade
##     fica ociosa, sem PP guardado e sem obra reservada (nunca completa um item fantasma).
## Campos que não existem mais (population, stored_food, worked_tiles...) são só ignorados por quem lê.
const LEGACY_WALL_FORTIFICATION := {"fortress": 3, "imperial_fortress": 3, "walls_2": 2, "walls": 1}

static func _sanitize_legacy_city(saved_city: Dictionary) -> Dictionary:
	var c: Dictionary = saved_city.duplicate(true)
	var raw_buildings: Array = c.get("buildings", [])
	if not c.has("fortification_level"):
		var migrated := 0
		for id in raw_buildings:
			migrated = maxi(migrated, int(LEGACY_WALL_FORTIFICATION.get(String(id), 0)))
		c["fortification_level"] = migrated
	var kept: Array = []
	for id in raw_buildings:
		if BuildingDatabase.get_building(String(id)) != null:
			kept.append(id)
	c["buildings"] = kept
	for key in ["building_coords", "repeatable_building_counts", "repeatable_building_coords"]:
		var filtered := {}
		var source: Dictionary = c.get(key, {})
		for id in source:
			if BuildingDatabase.get_building(String(id)) != null:
				filtered[id] = source[id]
		c[key] = filtered
	if not _is_valid_production_item(String(c.get("production_item", ""))):
		c["production_item"] = ""
		c["stored_production"] = 0.0
		c.erase("pending_building_coord")
	return c

## Item de produção que o jogo atual sabe concluir: prédio do banco, projeto local (City Level /
## Fortificação), unidade V2 ou o núcleo civil treinável. "" (ociosa) também é válido.
static func _is_valid_production_item(item: String) -> bool:
	if item == "" or BuildingDatabase.get_building(item) != null:
		return true
	if V2CityLevelData.is_city_project(item) or V2FortificationData.is_fortification_project(item):
		return true
	if item in UnitDatabase.CORE_TRAINABLE_KINDS:
		return true
	return V2ResearchDatabase.is_v2_id(item) and UnitDatabase.is_known_kind(item)

## Recargas/estados de unidade: só as chaves de Técnicas Militares e feitiços V2 continuam tendo
## sentido — chaves da magia V1 (silence/curse/revealed..., recargas de feitiço V1) são descartadas.
static func _sanitize_magic_dict(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value:
		var id := String(key)
		if V2DoctrineTechniqueDatabase.get_technique(id) != null or V2SpellDatabase.is_spell(id):
			result[id] = value[key]
	return result

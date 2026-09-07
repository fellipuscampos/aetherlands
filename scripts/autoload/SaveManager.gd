extends Node

## Salva/carrega o estado logico da partida em JSON (user://savegame.json).
## Nao serializa nodes 3D nem visual nenhum — so os dados que importam pro
## jogo (terreno via semente + raio, jogadores, unidades, cidades, turno,
## fog explorado). Recarregar reconstroi tudo chamando os mesmos caminhos
## de spawn/fundacao usados num jogo novo (HexGrid.spawn_unit/found_city),
## depois reaplica hp/movimento/producao por cima.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 17 # v17: World Event System (WorldEventManager.active_events/_next_event_id, ver docs/WORLD_EVENT_CONTRACT.md) -- nenhum evento concreto existe ainda (DragonEvent vem depois), mas o formato de save ja precisa existir desde o primeiro commit do sistema, nao ser retrofitado depois (regra explicita do contrato) -- (v16: estado das vitorias de sustentacao (PlayerData.territorial_streak/arcane_ritual_active/arcane_ritual_city_coord/arcane_ritual_streak, ver Roadmap "Fase F" F1/F2/F4) salvo por jogador, humano E rival -- (v15: campanha de guerra persistente por rival (PlayerData.war_campaigns, ver RivalAI.decide_campaign) salva contra o humano -- unico oponente possivel, ver comentario de _serialize_player -- (v14: raca do jogador (GameManager.human_race, ver TitleScreen/CivilizationData.race) salva pra sobreviver a um load (v13: economia arcana (PlayerData.mana/mana_income_per_turn, ver Ponto 3) salva por jogador (v12: recarga de feiticos (PlayerData.spell_cooldowns, ver SpellManager) salva por jogador (v11: territorio dinamico de cidade (City.owned_tiles, ver HexGrid.city_territory_tiles) salvo por cidade (v10: covis destruidos (LairStructure/HexGrid.destroy_lair) salvos em cleared_lair_coords (v9: acampamentos barbaros — monstro neutro ganha is_camp_boss/behavior_state/movement_left (v8: monstros neutros (guardiao + reforco/patrulha) e o RNG de turno dos covis salvos por inteiro, no lugar de so a lista de covis ja limpos (v7: mapa retangular (map_width/map_height no lugar de map_radius) (v6: predios posicionados no mapa; v5: covis de monstro limpos; v4: predios de cidade; v3: dificuldade; v2: lista de rivais + diplomacia + veterania de unidade)))))))))))

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
	# `.state` (nao so o seed) restaura o RNG de reforco/patrulha exatamente
	# de onde parou — sem isso, salvar e recarregar no mesmo turno reiniciava
	# a sequencia de sorteios do zero, quebrando qualquer replay/determinismo
	# de eventos futuros dos covis.
	if data.has("monster_rng_state"):
		hex_grid.monster_turn_rng.state = int(data.monster_rng_state)
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

func _serialize_explored(hex_grid: HexGrid) -> Array:
	var out := []
	for coord in hex_grid.visibility.keys():
		if hex_grid.visibility[coord] != HexGrid.Visibility.UNSEEN:
			out.append([coord.x, coord.y])
	return out

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
		unit.hp = float(u.hp)
		unit.kills = int(u.get("kills", 0))
		unit.veterancy_level = int(u.get("veterancy_level", 0))
		unit.monster_behavior_state = u.get("behavior_state", "")
		unit.movement_left = float(u.get("movement_left", unit.unit_data.movement_points))

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
			# Roadmap 2.0 Parte 1 (C6) — EXCECAO deliberada: diferente de
			# fortified/exploring/move_order_target (conveniencia de sessao,
			# de proposito descartados ao salvar), perder isto deixaria uma
			# unidade presa em pleno oceano tratada como terrestre apos
			# carregar — um estado invalido, nao so uma conveniencia perdida
			# (ver comentario de Unit.embarked).
			"embarked": unit.embarked,
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
			"coord": [city.coord.x, city.coord.y],
			"name": city.city_name,
			"population": city.population,
			"stored_food": city.stored_food,
			"stored_production": city.stored_production,
			"hp": city.hp,
			"shield": city.shield,
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
		"current_research": player.current_research,
		"research_progress": player.research_progress,
		"spell_cooldowns": player.spell_cooldowns,
		"mana": player.mana,
		"mana_income_per_turn": player.mana_income_per_turn,
		# Roadmap "Fase F" F1/F2/F4 — estado das duas vitorias de sustentacao,
		# QUALQUER jogador (humano ou rival, diferente de war_campaign abaixo
		# que e so-contra-humano): territorial_streak e arcane_ritual_* sao
		# historico acumulado de verdade, perder isso ao salvar/carregar
		# "roubaria" turnos de sustentacao ja conquistados.
		"territorial_streak": player.territorial_streak,
		"arcane_ritual_active": player.arcane_ritual_active,
		"arcane_ritual_city_coord": [player.arcane_ritual_city_coord.x, player.arcane_ritual_city_coord.y],
		"arcane_ritual_streak": player.arcane_ritual_streak,
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
		unit.embarked = u.get("embarked", false) # Roadmap 2.0 Parte 1 (C6)
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
	player.current_research = saved.get("current_research", "")
	player.research_progress = float(saved.get("research_progress", 0.0))
	var cooldowns: Dictionary = saved.get("spell_cooldowns", {})
	for spell_name in cooldowns.keys():
		player.spell_cooldowns[spell_name] = int(cooldowns[spell_name])
	player.mana = float(saved.get("mana", 0.0))
	player.mana_income_per_turn = float(saved.get("mana_income_per_turn", 0.0))
	# Roadmap "Fase F" F1/F2/F4 — get(..., default) com o MESMO default do
	# campo em PlayerData.gd: save ANTIGO (de antes destes 4 campos
	# existirem) carrega um jogador sem sustentacao nenhuma em andamento em
	# vez de quebrar, mesmo padrao de fallback ja usado pra hp/shield acima.
	player.territorial_streak = int(saved.get("territorial_streak", 0))
	player.arcane_ritual_active = saved.get("arcane_ritual_active", false)
	player.arcane_ritual_streak = int(saved.get("arcane_ritual_streak", 0))
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

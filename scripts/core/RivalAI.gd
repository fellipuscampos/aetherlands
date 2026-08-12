class_name RivalAI
extends RefCounted

## IA da civilizacao rival — GDScript puro, sem depender de nenhum plugin
## externo (o jogo precisa funcionar 100% offline). Unidades ofensivas
## avaliam o resultado PROVAVEL do combate antes de atacar
## (CombatResolver.predict(), a mesma formula que realmente vai rodar) em
## vez de brigar as cegas, recuam pra perto da propria cidade quando estao
## fracas (onde curam — ver GameManager._heal_if_garrisoned), e priorizam
## capturar uma cidade indefesa sobre uma escaramuca.
##
## Fog of war propria: a cada turno calcula o que realmente enxerga agora
## (HexGrid.compute_visible_tiles) e so mira em unidades inimigas
## ATUALMENTE visiveis; cidades inimigas (que nao andam) ficam guardadas em
## PlayerData.known_enemy_cities assim que escoutadas, continuando alvo
## valido mesmo fora de visao — nao "enxerga" mais o mapa inteiro de
## graca. Limitacao conhecida: o check de "cidade esta indefesa" usa o
## estado real do jogo mesmo pra cidades so lembradas (nao fica com uma
## foto antiga do que viu da ultima vez) — rastrear isso tambem seria a
## proxima melhoria, mas o ganho de realismo e pequeno pro custo extra.
##
## Coordenacao tatica basica: unidade a distancia (arqueiro) sem nenhum
## aliado corpo-a-corpo por perto nao avanca sozinha pra cima de um alvo —
## fica esperando escolta em vez de virar alvo facil isolado na linha de
## frente. Ainda assim revida normalmente se algo entrar no alcance dela.

const PERCEPTION_RANGE := 5
const SETTLE_MIN_DISTANCE := 3
const RETREAT_HP_FRACTION := 0.35 # abaixo disso, foge pra curar em vez de brigar
const ESCORT_RANGE := 2 # distancia maxima pra um aliado corpo-a-corpo contar como escolta
const MILITARY_KINDS := ["warrior", "warrior", "archer", "cavalry", "catapult", "mage", "griffin", "treant"] # pesos simples

## Tropa exclusiva de cada civilizacao de fantasia (CivilizationData.race,
## ver GameManager.RIVAL_CIVS e UnitDatabase.create_unit) — pedido do
## usuario: "insira outras civilizacoes de fantasia... voce cria tropas
## especificas pra essas civilizacoes". Escopo desta rodada: so a IA rival
## usa isso (o jogador nao tem raca ainda), entao o gate fica aqui em vez
## de em City.can_train()/BuildingDatabase (que sao so pro jogador).
const RACE_UNIQUE_KIND := {
	"dwarf": "dwarf_axeguard",
	"orc": "orc_berserker",
	"elf": "elf_ranger",
}

## MILITARY_KINDS + a tropa racial (pesada igual "warrior", duas entradas)
## quando o jogador tem uma raca com tropa propria — civ sem raca (jogador
## humano, ou um rival hipotetico sem `race` definida) so usa o elenco
## comum, sem nenhuma tropa exclusiva aparecer no sorteio.
static func _military_kinds_for(player: PlayerData) -> Array:
	var kinds := MILITARY_KINDS.duplicate()
	var race: String = player.civ.race if player.civ else ""
	if RACE_UNIQUE_KIND.has(race):
		var unique: String = RACE_UNIQUE_KIND[race]
		kinds.append(unique)
		kinds.append(unique)
	return kinds

static func decide_production(player: PlayerData) -> void:
	for city in player.cities:
		if player.cities.size() < 2:
			city.set_production("settler")
		else:
			var unlocked_kinds = _military_kinds_for(player).filter(func(k): return player.has_unlocked(k))
			city.set_production(unlocked_kinds[randi() % unlocked_kinds.size()])

## Sem nenhuma pesquisa em andamento, escolhe uma tecnologia disponivel ao
## acaso (pre-requisitos ja cumpridos) — mesma logica simples de
## decide_production, so garante que a IA sempre tenha algo na fila em vez
## de desperdicar ciencia gerada por turno (ver GameManager._process_research).
static func decide_research(player: PlayerData) -> void:
	if player.current_research != "":
		return
	var available = TechDatabase.available_techs(player.researched_techs)
	if available.size() > 0:
		player.current_research = available[randi() % available.size()].id

static func take_turn(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> void:
	var visible := hex_grid.compute_visible_tiles(player)
	_scout_enemy_cities(player, opponent, visible)

	for unit in player.units.duplicate():
		if not is_instance_valid(unit):
			continue
		if unit.unit_data.can_found_city:
			_handle_settler(unit, hex_grid, player)
		elif unit.unit_data.attack > 0.0:
			_handle_attacker(unit, hex_grid, player, opponent, visible)

## Cidade inimiga entra na memoria permanente assim que fica visivel — nao
## precisa continuar visivel depois disso (ela nao anda).
static func _scout_enemy_cities(player: PlayerData, opponent: PlayerData, visible: Dictionary) -> void:
	for city in opponent.cities:
		if visible.has(city.coord):
			player.known_enemy_cities[city.coord] = true

static func _handle_attacker(unit: Unit, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData, visible: Dictionary) -> void:
	if unit.hp < unit.unit_data.max_hp * RETREAT_HP_FRACTION:
		_retreat(unit, hex_grid, player)
		return

	var target_coord = _choose_target(unit, hex_grid, player, opponent, visible)
	if target_coord == null:
		return

	if target_coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
		_engage(unit, hex_grid, target_coord)
		return

	if HexMetrics.axial_distance(unit.coord, target_coord) > PERCEPTION_RANGE:
		return

	if unit.unit_data.attack_range > 1 and not _has_melee_escort_nearby(unit, player):
		return

	move_unit_toward(unit, hex_grid, target_coord)

## Ataca so se o combate parecer favoravel; cidade indefesa e sempre um
## alvo valido (captura garantida, nao tem "combate" pra avaliar).
static func _engage(unit: Unit, hex_grid: HexGrid, target_coord: Vector2i) -> void:
	var defender = hex_grid.get_unit_at(target_coord)
	if defender:
		if is_favorable_attack(unit, defender, hex_grid):
			CombatResolver.resolve(unit, defender, hex_grid)
		return
	var city = hex_grid.get_city_at(target_coord)
	if city:
		hex_grid.capture_city(city, unit.owner_player)
		unit.movement_left = 0.0

## Nao ataca se for morrer no proprio ataque. Se o defensor tambem
## sobrevive, so vale a pena se a unidade causar proporcionalmente mais
## dano do que leva (comparado em % do HP maximo de cada um, pra nao
## favorecer injustamente unidades com HP maximo diferente). Publica (sem
## `_`) porque MonsterAI.gd tambem chama, pro comportamento Cacador
## (Vivern/Dragao) so atacar quando favoravel — o resto de RivalAI
## continua privado de proposito (especifico de PlayerData/captura de
## cidade, fora do escopo de monstro neutro).
static func is_favorable_attack(attacker: Unit, defender: Unit, hex_grid: HexGrid) -> bool:
	var result = CombatResolver.predict(attacker, defender, hex_grid)
	if result.attacker_dies:
		return false
	if result.defender_dies:
		return true
	var defender_loss_pct = result.damage_to_defender / defender.unit_data.max_hp
	var attacker_loss_pct = result.damage_to_attacker / attacker.unit_data.max_hp
	return defender_loss_pct >= attacker_loss_pct

## Existe algum aliado corpo-a-corpo (attack_range 1) a ate ESCORT_RANGE
## tiles de distancia de `unit`? Usado pra decidir se uma unidade a
## distancia pode avancar sozinha sem virar alvo facil isolado.
static func _has_melee_escort_nearby(unit: Unit, player: PlayerData) -> bool:
	for ally in player.units:
		if ally == unit or ally.unit_data.attack <= 0.0:
			continue
		if ally.unit_data.attack_range <= 1 and HexMetrics.axial_distance(ally.coord, unit.coord) <= ESCORT_RANGE:
			return true
	return false

## Cidade inimiga indefesa e ja escoutada (nao precisa estar visivel agora,
## so conhecida — ver PlayerData.known_enemy_cities) dentro do alcance de
## percepcao e sempre prioridade sobre uma escaramuca; senao mira no alvo
## mais proximo dentre o que a IA realmente enxerga agora (unidades) ou ja
## escoutou (cidades). Em paz com `opponent` (ver Diplomacy.gd/
## PlayerData.is_at_war_with) nunca mira nele — so o jogador humano
## negocia paz/guerra ativamente, mas a IA sempre respeita o resultado.
static func _choose_target(unit: Unit, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData, visible: Dictionary):
	if not player.is_at_war_with(opponent):
		return null
	for coord in player.known_enemy_cities.keys():
		var city = hex_grid.get_city_at(coord)
		if city and city.owner_player == opponent and hex_grid.get_unit_at(coord) == null:
			if HexMetrics.axial_distance(unit.coord, coord) <= PERCEPTION_RANGE:
				return coord
	return _nearest_known_target(unit.coord, hex_grid, player, opponent, visible)

static func _nearest_known_target(from: Vector2i, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData, visible: Dictionary):
	var best = null
	var best_dist = 999999
	for unit in opponent.units:
		if not visible.has(unit.coord):
			continue
		var d = HexMetrics.axial_distance(from, unit.coord)
		if d < best_dist:
			best_dist = d
			best = unit.coord
	for coord in player.known_enemy_cities.keys():
		var city = hex_grid.get_city_at(coord)
		if city == null or city.owner_player != opponent:
			continue
		var d = HexMetrics.axial_distance(from, coord)
		if d < best_dist:
			best_dist = d
			best = coord
	return best

## Movimento guloso por distancia hexagonal (nao e A* de verdade — so pega,
## entre os tiles alcancaveis neste turno, o que mais reduz distancia ate
## `target_coord`). Publica (sem `_`) porque MonsterAI.gd reusa exatamente
## este primitivo pro comportamento Invasor/Cacador — o unico "conhecimento
## de dono" que ele usa e `unit.owner_player` (repassado como `owner` pro
## compute_reachable, que ja trata `null` corretamente: nenhuma cidade
## nunca conta como do "dono null", entao um monstro nunca consegue sequer
## pisar em tile de cidade, ver HexGrid.compute_reachable).
static func move_unit_toward(unit: Unit, hex_grid: HexGrid, target_coord: Vector2i) -> void:
	var reachable = hex_grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player, unit.unit_data.flies)
	var best_coord = null
	var best_dist = HexMetrics.axial_distance(unit.coord, target_coord)
	for coord in reachable.keys():
		var d = HexMetrics.axial_distance(coord, target_coord)
		if d < best_dist:
			best_dist = d
			best_coord = coord
	if best_coord != null:
		hex_grid.move_unit(unit, best_coord, reachable[best_coord])

## Foge pra perto da cidade mais proxima em vez de continuar brigando
## fraca — la ela cura (GameManager._heal_if_garrisoned).
static func _retreat(unit: Unit, hex_grid: HexGrid, player: PlayerData) -> void:
	if player.cities.is_empty():
		return
	var nearest_city_coord = null
	var best_dist = 999999
	for city in player.cities:
		var d = HexMetrics.axial_distance(unit.coord, city.coord)
		if d < best_dist:
			best_dist = d
			nearest_city_coord = city.coord
	if nearest_city_coord == null or nearest_city_coord == unit.coord:
		return
	move_unit_toward(unit, hex_grid, nearest_city_coord)

static func _handle_settler(unit: Unit, hex_grid: HexGrid, player: PlayerData) -> void:
	if hex_grid.get_city_at(unit.coord) == null and _far_enough_from_cities(unit.coord, player):
		WorldSetup.found_city_from_settler(hex_grid, unit)
		return

	var reachable = hex_grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player)
	if reachable.size() > 0:
		var options = reachable.keys()
		var dest = options[randi() % options.size()]
		hex_grid.move_unit(unit, dest, reachable[dest])

static func _far_enough_from_cities(coord: Vector2i, player: PlayerData) -> bool:
	for city in player.cities:
		if HexMetrics.axial_distance(coord, city.coord) < SETTLE_MIN_DISTANCE:
			return false
	return true

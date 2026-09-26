extends GutTest

## Base COMPARTILHADA dos testes de combate/técnicas da Doutrina do Guerreiro (Aetherlands V2, Fase 7). Não é um
## teste (não começa com `test_`): os arquivos `test_v2_*` a herdam por caminho (`extends "res://test/unit/v2_combat_fixture.gd"`)
## e recebem os mesmos before_each/after_each e helpers. Um grid pequeno de grama (defesa de terreno 0), civilizações
## em guerra e inimigos com HP/Defesa escolhidos — pra cada teste calcular o dano esperado pela FÓRMULA, sem ler o resultado
## do motor.

const W_HALL := "v2_building_warrior_hall"
const WARRIOR := "v2_unit_warrior"
const SWORDSMAN := "v2_unit_swordsman"
const MASTER := "v2_unit_weapon_master"
const ARENA := "v2_building_warrior_mastery"
const HERO := "v2_legendary_blade_hero"
const POWER := "v2_technique_power_strike"
const CLEAVE := "v2_technique_cleave"
const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const SHIELD := "v2_unit_shieldbearer"
const SENTINEL := "v2_unit_sentinel"
const CHAMPION := "v2_legendary_guardian_champion"
const WALL := "v2_technique_shield_wall"
const R_CAMP := "v2_building_ranger_camp"
const ARCHER := "v2_unit_archer"
const HUNTER := "v2_unit_hunter"
const MARKSMAN := "v2_unit_elite_marksman"
const R_TOWER := "v2_building_ranger_mastery"
const LEGEND_HUNTER := "v2_legendary_legend_hunter"
const PRECISE := "v2_technique_precise_shot"
const VOLLEY := "v2_technique_volley"
const C_STABLE := "v2_building_war_stable"
const CAVALIER := "v2_unit_cavalier"
const SHOCK := "v2_unit_shock_cavalier"
const ARMORED := "v2_unit_armored_cavalier"
const C_ORDER := "v2_building_cavalry_mastery"
const GRIFFON := "v2_legendary_griffon_rider"
const CHARGE := "v2_technique_charge"
const RETREAT := "v2_technique_tactical_retreat"
const BRACE := "v2_technique_brace_spears"
const ROGUE_GUILD := "v2_building_rogue_guild"
const ROGUE := "v2_unit_rogue"
const SABOTEUR := "v2_unit_saboteur"
const ASSASSIN := "v2_unit_assassin"
const ROGUE_MASTERY := "v2_building_rogue_mastery"
const SHADOW_MASTER := "v2_legendary_shadow_master"
const SNEAK_ATTACK := "v2_technique_sneak_attack"
const DISMANTLE := "v2_technique_dismantle"
const SIEGE_ARSENAL := "v2_building_siege_arsenal"
const CATAPULT := "v2_unit_catapult"
const TREBUCHET := "v2_unit_trebuchet"
const BOMBARD := "v2_unit_bombard"
const GRAND_ARSENAL := "v2_building_grand_arsenal"
const COLOSSUS := "v2_legendary_siege_colossus"
const DEMOLITION_AMMO := "v2_technique_demolition_ammo"
const PREPARED_BOMBARDMENT := "v2_technique_prepared_bombardment"

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []
var _cities: Array[City] = []
var _original_turn: int
var _original_human: PlayerData

func before_each():
	_original_turn = TurnManager.turn_number
	_original_human = GameManager.human_player
	TurnManager.turn_number = 5

func after_each():
	SelectionManager.reset()
	TurnManager.turn_number = _original_turn
	GameManager.human_player = _original_human
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()
	for player in _players:
		player.release_relations()
	_players.clear()

# --- Helpers -------------------------------------------------------------------------------------------------

func _world(radius: int = 6) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if absi(q + r) <= radius:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid

## Civilização com o Guerreiro pesquisado até o nível `warrior_through` (e o Guardião até `guardian_through`, o Patrulheiro até `ranger_through`,
## a Cavalaria até `cavalry_through`, o Ladino até `rogue_through`, o Cerco até `siege_through`).
func _player(warrior_through: int = 9, guardian_through: int = 0, ranger_through: int = 0, cavalry_through: int = 0, rogue_through: int = 0, siege_through: int = 0) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	for n in range(1, warrior_through + 1):
		player.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	for n in range(1, guardian_through + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	for n in range(1, ranger_through + 1):
		player.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	for n in range(1, cavalry_through + 1):
		player.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	for n in range(1, rogue_through + 1):
		player.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	for n in range(1, siege_through + 1):
		player.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	return player

## Civilização com SÓ o Cerco até `through` (e, se pedido, as outras Doutrinas até os níveis dados).
func _siege_player(through: int = 9, guardian_through: int = 0, warrior_through: int = 0, ranger_through: int = 0, cavalry_through: int = 0, rogue_through: int = 0) -> PlayerData:
	return _player(warrior_through, guardian_through, ranger_through, cavalry_through, rogue_through, through)

## Civilização com SÓ a Cavalaria até `through` (e, se pedido, as outras Doutrinas até os níveis dados).
func _cavalry_player(through: int = 9, guardian_through: int = 0, warrior_through: int = 0, ranger_through: int = 0) -> PlayerData:
	return _player(warrior_through, guardian_through, ranger_through, through)

## Civilização com SÓ o Ladino até `through` (e, se pedido, as outras Doutrinas até os níveis dados).
func _rogue_player(through: int = 9, guardian_through: int = 0, warrior_through: int = 0, ranger_through: int = 0, cavalry_through: int = 0) -> PlayerData:
	return _player(warrior_through, guardian_through, ranger_through, cavalry_through, through)

## Troca o terreno de UM tile do grid de teste (grama por padrão) — montanha, oceano, floresta...
func _set_terrain(grid: HexGrid, coord: Vector2i, terrain: HexTileData.TerrainType) -> void:
	grid.tiles[coord] = TerrainDatabase.create_tile(terrain)

## Um terreno "custoso" de teste: o custo de movimento que o jogo hoje deixa em 1 em todo lugar passa a ser `cost` neste tile.
func _set_costly(grid: HexGrid, coord: Vector2i, cost: int = 2) -> void:
	var tile: HexTileData = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)
	tile.movement_cost = cost
	grid.tiles[coord] = tile

## Civilização com SÓ o Patrulheiro até `through` (e, se pedido, o Guardião/Guerreiro até os níveis dados).
func _ranger_player(through: int = 9, guardian_through: int = 0, warrior_through: int = 0) -> PlayerData:
	return _player(warrior_through, guardian_through, through)

## Uma civilização rival EM GUERRA com `me`.
func _rival_of(me: PlayerData) -> PlayerData:
	var rival := PlayerData.new(CivilizationData.new())
	_players.append(rival)
	Diplomacy.declare_war(me, rival)
	assert_true(me.is_at_war_with(rival), "pré-condição: em guerra")
	return rival

func _unit(grid: HexGrid, player: PlayerData, kind: String, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), player)
	assert_not_null(unit, "spawn %s em %s" % [kind, str(coord)])
	# Aetherlands V2, Fase 15 — esta base é sobre FÓRMULA de combate/técnica, não sobre
	# Suprimentos: sem isso, todo `player` desta fixture (que nunca funda cidade nenhuma) teria
	# capacidade 0, e QUALQUER unidade com supply_cost > 0 entraria em Tensão Logística sozinha,
	# poluindo os números que estes testes verificam pela fórmula. Garante capacidade de sobra na
	# PRIMEIRA vez que isso importa (mesmo espírito de atalho de teste já usado desde a Fase 13:
	# seta repeatable_building_counts direto, sem passar pela produção real).
	if unit != null and unit.unit_data.supply_cost > 0:
		_ensure_ample_supply_capacity(player)
	return unit

var _supply_cities_by_player: Dictionary = {}

func _ensure_ample_supply_capacity(player: PlayerData) -> void:
	if _supply_cities_by_player.has(player):
		return
	var city := City.new()
	city.owner_player = player
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 50
	player.cities.append(city)
	_cities.append(city)
	_supply_cities_by_player[player] = city
	# Fazenda tem gold_upkeep (Fase 15, §25) e esta cidade fantasma nunca tem Mercado -- sem Ouro
	# de sobra a civilização entraria em Déficit sozinha, bloqueando o treino por um motivo alheio
	# ao que estes testes de fórmula verificam.
	if player.gold <= 0.0:
		player.gold = 1000.0

## Inimigo de teste: dado V1 com HP e Defesa escolhidos (HP alto pra sobreviver ao golpe).
func _foe(grid: HexGrid, owner: PlayerData, coord: Vector2i, hp: float = 40.0, defense: float = 3.0) -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.max_hp = hp
	data.defense = defense
	var unit := grid.spawn_unit(coord, data, owner)
	assert_not_null(unit, "inimigo em %s" % str(coord))
	return unit

## Alvo de teste (Fase 10, Desmantelar) com um TRAÇO arbitrário (ex.: UnitData.TRAIT_CASTER, UnitData.TRAIT_SIEGE), mesmo com um id
## QUALQUER — a classificação de Desmantelar nunca pode depender do nome/id, só do traço.
func _traited_foe(grid: HexGrid, owner: PlayerData, coord: Vector2i, trait_id: String, hp: float = 40.0, defense: float = 3.0, fake_id: String = "fixture_traited") -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.visual_kind = fake_id
	data.max_hp = hp
	data.defense = defense
	data.traits.append(trait_id)
	var unit := grid.spawn_unit(coord, data, owner)
	assert_not_null(unit, "alvo com traço %s em %s" % [trait_id, str(coord)])
	return unit

## Dano esperado pela FÓRMULA do motor (Ataque - Defesa/2, piso 1), sem chamar o CombatResolver. `extra_defense` é o
## multiplicador de defesa de efeitos (Muralha etc.); o terreno vem do tile do defensor. `defense_penetration` (Fase 10,
## Ataque Furtivo) reduz a CONTRIBUIÇÃO da Defesa antes da mitigação, do mesmo jeito que CombatResolver.predict faz.
func _formula_damage(grid: HexGrid, attack: float, multiplier: float, defender: Unit, extra_defense: float = 1.0, defense_penetration: float = 0.0) -> float:
	var terrain := 1.0 + grid.get_tile(defender.coord).defense_bonus
	var effective_defense := defender.unit_data.defense * terrain * extra_defense * (1.0 - defense_penetration)
	return maxf(1.0, attack * multiplier - effective_defense * CombatResolver.DEFENSE_MITIGATION_FACTOR)

## Dano esperado pela FÓRMULA de CombatResolver.resolve_city_attack (multiplicação/divisão — a fórmula urbana já era assim ANTES da Fase 11,
## diferente da subtrativa de predict/resolve entre unidades), sem chamar o CombatResolver. `strike_multiplier` (Bombardeio Preparado) e
## `demolition` (V2TechniqueRuntime.city_attack_multiplier, Munição Demolidora) são os dois fatores novos da Fase 11, ambos 1.0 por padrão.
func _city_formula_damage(attacker: Unit, city: City, strike_multiplier: float = 1.0, demolition: float = 1.0) -> float:
	var defense_bonus := city.defense_bonus() # Fase 25: só a Fortificação V2 defende a cidade
	return max(1.0, (attacker.unit_data.attack * attacker.veterancy_multiplier() * UnitAbilities.city_attack_multiplier(attacker) * strike_multiplier * demolition) / (1.0 + defense_bonus))

## Dano REAL que um ataque contra `city` causou: soma o que saiu do escudo com o que saiu da vida (a chamada já deve ter acontecido).
func _city_damage_taken(city: City, hp_before: float, shield_before: float) -> float:
	return (shield_before - city.shield) + (hp_before - city.hp)

## Um tile do grid, livre, a EXATAMENTE `distance` de `center` (prefere o eixo +q, depois varre em ordem fixa).
func _coord_at(grid: HexGrid, center: Vector2i, distance: int) -> Vector2i:
	var preferred := center + Vector2i(distance, 0)
	if grid.tiles.has(preferred) and grid.get_unit_at(preferred) == null and grid.get_city_at(preferred) == null:
		return preferred
	for coord in HexMetrics.coords_within(center, distance):
		if HexMetrics.axial_distance(center, coord) == distance and grid.tiles.has(coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
			return coord
	fail_test("sem tile livre a distância %d de %s" % [distance, str(center)])
	return Vector2i(999, 999)

## Inimigo (dado V1 com HP/Defesa escolhidos) a EXATAMENTE `distance` de `from_unit`.
func _foe_at(grid: HexGrid, owner: PlayerData, from_unit: Unit, distance: int, hp: float = 40.0, defense: float = 3.0) -> Unit:
	return _foe(grid, owner, _coord_at(grid, from_unit.coord, distance), hp, defense)

## Tira os comentários (do `#` ao fim da linha) — as regras de "sem id concreto na lógica" valem pro CÓDIGO; comentário pode citar exemplos.
func _code_only(source: String) -> String:
	var lines: Array[String] = []
	for line in source.split("\n"):
		var index := line.find("#")
		lines.append(line if index < 0 else line.substr(0, index))
	return "\n".join(lines)

func _technique(id: String) -> V2DoctrineTechniqueData:
	return V2DoctrineTechniqueDatabase.get_technique(id)

func _standalone_city(player: PlayerData, buildings: Array[String] = []) -> City:
	var city := City.new()
	city.owner_player = player
	for id in buildings:
		city.buildings[id] = true
	player.cities.append(city) # o slot Lendário lê as ordens de produção de player.cities
	_cities.append(city)
	return city

## Aetherlands V2, Fase 15 — variante de _standalone_city com capacidade de Suprimentos de sobra
## (Fazenda ×4 injetada direto, mesmo atalho de sempre), pra testes que TREINAM uma Lendária
## (custo 5, acima da base de uma cidade sozinha, 4) sem que Suprimentos seja o assunto do teste.
## City.used_building_slots() conta CADA cópia de um prédio repetível (§26 da Fase 13) — a própria
## Fazenda ×4 já ocupa os 4 slots inteiros do City Level I sozinha, então esta variante sobe pra
## City Level III (10 slots) pra sobrar espaço pro que o teste realmente quer construir (alguns
## chamadores passam até 4 prédios distintos pra `buildings`, ex.: Salão+Bastião de uma Doutrina
## MAIS Salão+Arena de outra) — só usada por quem chama esta função opt-in, nunca afeta
## _standalone_city (City Level I, 4 slots) nem seus outros chamadores.
func _standalone_city_with_supply(player: PlayerData, buildings: Array[String] = []) -> City:
	var city := _standalone_city(player, buildings)
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	# Prédios de treino/Maestria têm gold_upkeep (§24-30 da Fase 15) e esta fixture nunca constrói
	# um Mercado — sem Ouro de sobra, a civilização entraria em Déficit sozinha (renda nominal <
	# upkeep, Ouro em caixa 0), bloqueando o treino de QUALQUER unidade com Suprimentos > 0 por um
	# motivo que não é o assunto destes testes. is_gold_deficit() já sai cedo com `gold > 0`.
	if player.gold <= 0.0:
		player.gold = 1000.0
	return city

## Cidade HOSTIL de teste (Fase 11, Doutrina de Cerco) num `coord` real do `grid` — registrada em `cities_by_coord` (o
## mesmo dicionário que CombatResolver.resolve_city_attack/V2TechniqueRuntime.city_strike_targets consultam), com
## hp/shield cheios (como City.found() faria) pra o dano/escudo poderem ser conferidos de verdade.
func _enemy_city(grid: HexGrid, owner: PlayerData, coord: Vector2i, buildings: Array[String] = []) -> City:
	var city := City.new()
	city.owner_player = owner
	city.coord = coord
	city.city_name = "Cidade Inimiga"
	for id in buildings:
		city.buildings[id] = true
	city.hp = city.max_hp()
	city.shield = city.max_shield()
	grid.cities_by_coord[coord] = city
	_cities.append(city)
	return city

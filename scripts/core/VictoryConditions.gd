class_name VictoryConditions
extends RefCounted

## Roadmap "Fase F" F1/F2 -- avaliacao das tres condicoes de vitoria
## alternativas (Dominacao, Dominio Territorial, Ascensao Arcana).
##
## DISCIPLINA DESTE ARQUIVO (combinada com o usuario, F2): toda funcao
## aqui e PURA -- le PlayerData/HexGrid, nunca escreve neles, nunca mexe
## em EventBus/UI, nunca chama GameManager, nunca incrementa streak. A
## logica TEMPORAL (atualizar streaks, ativar o ritual, decidir quando de
## fato encerrar o jogo) fica pra uma fatia seguinte que INTEGRA estas
## funcoes ao loop de turno -- este arquivo so responde "qual e o estado
## agora?", nunca "o que fazer sobre isso?".
##
## Duas perguntas DIFERENTES por vitoria, nunca confundidas (pedido
## explicito do usuario): "progresso" (0.0-1.0, telemetria/UI, ver
## *_progress abaixo) NAO e o mesmo que "condicao atingida" (bool, ver
## is_*_achieved abaixo). O caso mais claro e Arcana, onde a media das 4
## fracoes pode estar em 75% de PREPARACAO sem o ritual ter sequer sido
## ativado -- progresso nunca deve alimentar decide_research/_score_war_
## target nem nenhum outro termo estrategico de IA (camadas diferentes,
## mesmo principio que ja separa CityIdentity de CivilizationPersonality).

## Roadmap "Fase F" F3 -- identificadores usados por
## GameManager.check_victories()/EventBus.victory_achieved (nao lidos por
## nenhuma funcao deste arquivo, so exportados pra quem integra ter um
## nome comum em vez de strings soltas repetidas). VICTORY_TYPE_DEBUG e
## exclusivo do botao "forcar fim de jogo" (GameManager.
## debug_force_game_over) -- nunca produzido por check_victories().
const VICTORY_TYPE_DOMINANCE := "dominance"
const VICTORY_TYPE_TERRITORIAL := "territorial"
const VICTORY_TYPE_ARCANE := "arcane"
const VICTORY_TYPE_DEBUG := "debug"

## --- Dominacao ----------------------------------------------------------

## Todo jogador ALEM de `player` (na lista completa, humano+rivais) esta
## sem unidade e sem cidade nenhuma. Mesma checagem de
## GameManager.check_game_over, generalizada pra QUALQUER jogador (nao so
## o humano) -- Dominacao agora e so mais um dos tres caminhos, nao um
## caso especial verificado so pro lado humano.
static func is_dominance_achieved(player: PlayerData, players: Array[PlayerData]) -> bool:
	for other in players:
		if other == player:
			continue
		if other.units.size() > 0 or other.cities.size() > 0:
			return false
	return true

## Fracao de OUTROS jogadores ja eliminados -- 0.0 se `players` so tiver
## `player` (sem rival nenhum pra eliminar, caso degenerado que nao
## deveria acontecer numa partida real).
static func dominance_progress(player: PlayerData, players: Array[PlayerData]) -> float:
	var others := []
	for other in players:
		if other != player:
			others.append(other)
	if others.is_empty():
		return 0.0
	var eliminated := 0
	for other in others:
		if other.units.is_empty() and other.cities.is_empty():
			eliminated += 1
	return float(eliminated) / float(others.size())

## --- Dominio Territorial --------------------------------------------------

## Ponto de partida CALIBRAVEL (pedido explicito do usuario, mesma
## disciplina de D4: "X% deliberadamente aberto para calibracao", nunca
## escolhido pelo numero que "parece justo"). NAO validado pelo harness
## ainda -- so existe pra o codigo compilar/ser testavel antes da
## calibracao real.
const TERRITORIAL_VICTORY_THRESHOLD := 0.5
const TERRITORIAL_SUSTAIN_TURNS := 5

## Territorio "habitavel" = not tile.blocks_land_units() (exclui so
## Oceano/Mar Gelado/Costa/Lava/Mar de Lava) -- decisao de F1, reusa o
## helper que ja existe em HexTileData, nenhuma classificacao nova de
## terreno. Denominador e o MAPA INTEIRO (incluindo terra ainda nao
## colonizada e os continentes especiais mesmo antes de Navegacao) --
## decisao explicita de F1 pra nao deixar exploracao mudar retroativamente
## o percentual necessario.
static func total_habitable_tiles(hex_grid: HexGrid) -> int:
	var count := 0
	for coord in hex_grid.tiles.keys():
		var data: HexTileData = hex_grid.tiles[coord]
		if data and not data.blocks_land_units():
			count += 1
	return count

## Tiles habitaveis possuidos por QUALQUER cidade de `player`, deduplicados
## -- MESMO padrao defensivo de ResourceDatabase.count_controlled_for_city
## (city.coord PODE ou nao ja estar em owned_tiles, dependendo de como o
## City foi montado).
static func player_habitable_tiles(player: PlayerData, hex_grid: HexGrid) -> int:
	var unique_coords := {}
	for city in player.cities:
		unique_coords[city.coord] = true
		for owned in city.owned_tiles:
			unique_coords[owned] = true
	var count := 0
	for coord in unique_coords.keys():
		var data: HexTileData = hex_grid.get_tile(coord)
		if data and not data.blocks_land_units():
			count += 1
	return count

## Fracao 0.0+ do mapa habitavel controlada por `player` (NAO clampada --
## ver territorial_progress abaixo pra versao clampada em 1.0). Guarda
## contra mapa sem tile habitavel nenhum (nunca deveria acontecer, so
## defensivo).
static func territorial_percentage(player: PlayerData, hex_grid: HexGrid) -> float:
	# hex_grid.total_habitable_tiles_cached() (nao total_habitable_tiles()
	# direto) -- mesmo resultado, so memoizado -- ver o comentario do cache
	# em HexGrid.gd pro custo real que isso evita (varredura do mapa
	# inteiro, chamada uma vez por jogador todo fim de turno).
	var total := hex_grid.total_habitable_tiles_cached()
	if total <= 0:
		return 0.0
	return float(player_habitable_tiles(player, hex_grid)) / float(total)

static func is_territorial_threshold_met(player: PlayerData, hex_grid: HexGrid) -> bool:
	return territorial_percentage(player, hex_grid) >= TERRITORIAL_VICTORY_THRESHOLD

## Telemetria/UI -- clampada em 1.0 (passar do limiar nao da "mais que
## 100%" de progresso).
static func territorial_progress(player: PlayerData, hex_grid: HexGrid) -> float:
	return min(territorial_percentage(player, hex_grid) / TERRITORIAL_VICTORY_THRESHOLD, 1.0)

## Condicao de vitoria de verdade -- streak e ESTADO (PlayerData.
## territorial_streak), atualizado por uma fatia temporal futura, NUNCA
## por esta funcao (pura, so LE). Ver disciplina de topo do arquivo.
static func is_territorial_dominance_achieved(player: PlayerData) -> bool:
	return player.territorial_streak >= TERRITORIAL_SUSTAIN_TURNS

## --- Ascensao Arcana ------------------------------------------------------

## As 7 escolas MAGICAS (Doutrina excluida de proposito -- decisao
## explicita de F1: Doutrina e o branch mundano/economico-militar que
## qualquer civilizacao pesquisa pra jogar normalmente; contar como
## "escola" trivializaria o requisito arcano).
const ARCANE_SCHOOLS: Array[String] = ["Arcanismo", "Alquimia", "Transmutação", "Naturalismo", "Geomancia", "Elementalismo", "Necromancia"]
const ARCANE_SCHOOLS_REQUIRED := 4
const ARCANE_NODES_REQUIRED := 3
const ARCANE_SUSTAIN_TURNS := 5
## Registrado em BuildingDatabase (Roadmap Fase F, "Santuario do Nodulo") --
## sem tech gate, custo/bonus de mana sao valores iniciais de gameplay ainda
## NAO calibrados (ver F7). O desacoplamento por id continua de proposito:
## VictoryConditions nao importa BuildingDatabase, so compara o mesmo
## building_id que City.buildings ja usa como chave.
const SANCTUARY_BUILDING_ID := "arcane_sanctuary"

## Roadmap "Fase F" F3 -- pontos de partida CALIBRAVEIS (pedido explicito
## do usuario, mesma disciplina de TERRITORIAL_VICTORY_THRESHOLD acima e
## de D4: "os dois valores de mana ficam deliberadamente pra calibracao
## posterior"). Consumidos por GameManager.activate_arcane_ritual (custo
## inicial) e GameManager._update_arcane_ritual (manutencao por turno) --
## nunca lidos por nenhuma funcao deste arquivo.
const ARCANE_RITUAL_ACTIVATION_COST := 100.0
const ARCANE_RITUAL_UPKEEP_COST_PER_TURN := 10.0

## Quantas das 7 escolas magicas `player` ja tem PELO MENOS uma tech
## pesquisada -- "escola pesquisada" e por tech.school, nao por uma
## tech-capstone especifica (decisao de F1: qualquer tech daquela escola
## conta, preserva "escolha estrategica" entre as 7). Le MagicDatabase/
## researched_magic (nao mais TechDatabase/researched_techs) desde a
## separacao estrutural das duas arvores de pesquisa -- reapontamento
## MINIMO pra essa funcao continuar funcionando exatamente como antes,
## nenhum limiar/logica de vitoria mudou (ARCANE_SCHOOLS/filtro mantidos
## por seguranca, ainda que hoje toda tech de MagicDatabase ja esteja
## nessa lista).
static func arcane_schools_researched(player: PlayerData) -> int:
	var schools_seen := {}
	for id in player.researched_magic:
		var tech := MagicDatabase.get_tech(id)
		if tech and tech.school in ARCANE_SCHOOLS:
			schools_seen[tech.school] = true
	return schools_seen.size()

## Reusa ResourceDatabase.count_controlled diretamente -- MESMA logica de
## controle de recurso que ja existe pra Ferro/Cavalos/Gemas/Seda, nenhuma
## segunda mecanica de "posse de Nodulo" (decisao explicita de F1).
static func arcane_nodes_controlled(player: PlayerData, hex_grid: HexGrid) -> int:
	return ResourceDatabase.count_controlled(player, hex_grid, "mana_node")

static func has_arcane_sanctuary(player: PlayerData) -> bool:
	for city in player.cities:
		if city.buildings.has(SANCTUARY_BUILDING_ID):
			return true
	return false

## Pre-requisitos pra PODER ativar o ritual (pagar o custo inicial) --
## DIFERENTE de "ritual ja ativo" (PlayerData.arcane_ritual_active, estado
## temporal) e DIFERENTE de "vitoria alcancada" (ver
## is_arcane_ascension_achieved abaixo). So escolas+nodulos -- o Santuario
## em si pode ser construido antes ou depois de bater esses dois (ordem
## livre, decisao de F1 sobre progresso ser media simples, nao estagios).
static func meets_arcane_ritual_prerequisites(player: PlayerData, hex_grid: HexGrid) -> bool:
	return arcane_schools_researched(player) >= ARCANE_SCHOOLS_REQUIRED and arcane_nodes_controlled(player, hex_grid) >= ARCANE_NODES_REQUIRED

## Telemetria/UI (pedido explicito do usuario: NUNCA usar isto como
## condicao de vitoria nem como termo de score estrategico de IA -- sao
## conceitos diferentes). Media simples das 4 fracoes, cada uma clampada
## em 1.0 antes de entrar na media -- um jogador com tudo pronto MENOS o
## Santuario fica em ~75%, nao trava em 0% so porque a fase de ativacao
## ainda nao comecou (decisao explicita de F1/F2: informativo > formal).
static func arcane_progress(player: PlayerData, hex_grid: HexGrid) -> float:
	var schools_fraction: float = min(float(arcane_schools_researched(player)) / float(ARCANE_SCHOOLS_REQUIRED), 1.0)
	var nodes_fraction: float = min(float(arcane_nodes_controlled(player, hex_grid)) / float(ARCANE_NODES_REQUIRED), 1.0)
	var sanctuary_fraction: float = 1.0 if has_arcane_sanctuary(player) else 0.0
	var sustain_fraction: float = min(float(player.arcane_ritual_streak) / float(ARCANE_SUSTAIN_TURNS), 1.0)
	return (schools_fraction + nodes_fraction + sanctuary_fraction + sustain_fraction) / 4.0

## Condicao de vitoria de verdade: ritual ATIVO (estado temporal, ver
## PlayerData.arcane_ritual_active) sustentado pelo streak minimo.
## Ativacao em si (pagar o custo inicial de mana) e logica TEMPORAL de uma
## fatia futura, nunca desta funcao pura.
static func is_arcane_ascension_achieved(player: PlayerData) -> bool:
	return player.arcane_ritual_active and player.arcane_ritual_streak >= ARCANE_SUSTAIN_TURNS

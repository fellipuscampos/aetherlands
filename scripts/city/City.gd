class_name City
extends Node3D

var original_owner_index: int = -1

## Aetherlands V2, Fase 25: a cidade não tem mais população, comida, tiles trabalhados nem rendimento
## por tile — a economia inteira vem de V2EconomyRuntime (base por cidade + prédios + melhorias), e o
## desenvolvimento urbano é o City Level. Ver docs/AETHERLANDS_V2_IMPLEMENTATION.md, Fase 25.
const LABEL_HEIGHT := 1.4

## Vida/escudo da cidade — pedido do usuario: "quero... estabelecer a vida
## da cidade, sempre mostrando na tela quanta vida ela tem, e o shield
## tambem, a partir do momento que voce construir a muralha". Ate aqui
## cidade NAO tinha vida nenhuma: atacar uma indefesa capturava na hora,
## num unico clique (ver SelectionManager._attack_from_selected/RivalAI.
## _engage, ANTES desta mudanca). Agora vira combate de verdade — so
## captura quando hp chega a zero (ver CombatResolver.resolve_city_attack)
## — e Muralhas ganha proposito MECANICO alem do visual: o escudo absorve
## dano antes da vida cair, regenerando mais rapido entre ataques (mesmo
## espirito da cura de guarnicao, ver GameManager.GARRISON_HEAL_FRACTION).
## Aetherlands V2, Fase 16: max_hp vem do City Level (V2CityLevelData.max_hp) e max_shield da
## Fortificação V2 (V2FortificationData.shield_max) — população e o prédio V1 "walls" não entram
## mais. A regeneração por turno (frações abaixo) e o atrito de cerco continuam os de sempre.
const CITY_HP_REGEN_FRACTION := 0.08 # fracao de max_hp curada por turno
const CITY_SHIELD_REGEN_FRACTION := 0.15 # fracao de max_shield recarregada por turno
## Atrito de cerco (roadmap de gameplay Fase 2): unidade inimiga adjacente
## por N turnos SEGUIDOS suspende a regeneracao de HP/escudo da cidade
## (ver _is_enemy_adjacent/process_turn) — pedido do usuario: "comecar com
## UMA unica consequencia simples e legivel" em vez de inventar um dreno
## novo de producao/comida, so desligar um bonus que ja existe. N=2 (nao
## 1) de proposito: uma unidade so DE PASSAGEM no territorio, sem
## intencao de cercar, nao deveria contar como sitio de verdade.
const SIEGE_TURNS_TO_SUSPEND_REGEN := 2

## Escala visual da cidade pelo City Level (Fase 25 — era pela população, removida): Cidade I =
## aldeia (poucas casinhas + salão), Cidade II = vila, Cidade III+ = cidade com torre central. Teto de
## estruturas fixo (ver _build_visual_procedural), então o número de meshes nunca cresce sem limite.
const HUTS_BY_CITY_LEVEL := {1: 3, 2: 5, 3: 7, 4: 8}

var owner_player: PlayerData
var coord: Vector2i
var city_name: String = "Cidade"

## Aetherlands V2, Fase 13 — nível urbano LOCAL desta cidade (1..4, ver V2CityLevelData). Nunca
## derivado de prédios/território/HP — estado próprio, explícito, salvo por cidade.
## Nova cidade nasce em 1; cidade capturada mantém o nível (HexGrid.capture_city não toca isto).
var city_level: int = 1
## Pontos de Anexação desta cidade (LOCAIS — não é recurso de PlayerData, ver V2CityLevelData.
## annexation_grant). Nunca expiram; não resetam ao subir de nível (§31/§32/§91 do pedido).
var annexation_points: int = 0
## id de prédio (CopyLimitMode.CITY_LEVEL) -> quantas cópias esta cidade já tem. Um prédio UNIQUE
## (o padrão, ver BuildingData.copy_limit_mode) nunca entra aqui — `buildings.has(id)` já basta
## pra ele. Ver building_count()/max_copies_for_building()/can_build().
var repeatable_building_counts: Dictionary = {}
## Aetherlands V2, Fase 14 — id de prédio CopyLimitMode.CITY_LEVEL -> Array[Vector2i] com a
## coordenada de CADA cópia física já construída nesta cidade (§8/§58/§98 do pedido: cada cópia
## precisa aparecer no mapa e sobreviver a save/load/captura). Dict SEPARADO de `building_coords`
## (que continua guardando exatamente 1 coord por id, sem alteração nenhuma — segue correto pra
## todo prédio UNIQUE, que nunca tem mais de 1 cópia) em vez de mudar o tipo de `building_coords`
## pra Array em todo mundo — mesma decisão de design de `repeatable_building_counts` na Fase 13
## (dict novo e aditivo em vez de arriscar um dict já usado por ~100 prédios existentes).
var repeatable_building_coords: Dictionary = {}
## Aetherlands V2, Fase 15 — melhorias de recurso do mapa construídas pelo Construtor nesta cidade
## (Vector2i -> improvement_id de V2ResourceImprovementData). Vive na CIDADE (não no HexTileData/
## num recurso global) porque o tile já pertence a ela — captura transfere a cidade inteira, e a
## melhoria vai junto de graça, sem nenhum código novo (§75/§76 do pedido). Nunca conta como
## prédio: não entra em `buildings`, não ocupa slot, não passa por CopyLimitMode.
var resource_improvements: Dictionary = {}
## Circunraio REAL do hex do tile (HexGrid.hex_size, ver setup()) — pedido
## do usuario apos ver a muralha pequena demais e mal encaixada: "voce
## conseguiria fazer... como esse vermelho que tracei" (um hexagono do
## TAMANHO do proprio tile, acompanhando a quebra agua/terra, nao um
## menor abraçando so o cluster de predios do centro). Antes a muralha
## usava um raio LOCAL fixo (0.62) sem nenhuma relacao com o tile de
## verdade — 1.0 aqui e so o fallback pro default de HexGrid.hex_size,
## usado por testes que criam City.new() bare sem passar por setup().
var tile_radius: float = 1.0
var stored_production: float = 0.0
## Ver comentario de CITY_HP_REGEN_FRACTION acima — inicializados em setup()
## (hp cheio, shield 0 ate Muralhas ser construida).
var hp: float = 0.0
var shield: float = 0.0
## Aetherlands V2, Fase 16 — Fortificação LOCAL desta cidade (0 = nenhuma, 1 = Muralhas I, 2 =
## Muralhas II, 3 = Fortaleza; números em V2FortificationData). Construída como PROJETO na mesma
## fila de produção, nunca um prédio: não ocupa slot, não entra em `buildings`. Sobrevive à captura
## (a cidade inteira muda de dono) e é salva.
var fortification_level: int = 0
## Aetherlands V2, Fase 16 — TurnManager.turn_number em que esta cidade já usou o Ataque da Cidade
## (uma vez por turno do dono; -1 = nunca). Salvo: recarregar o jogo não devolve o disparo. A
## captura grava o turno corrente, então a cidade nunca dispara no mesmo turno em que mudou de dono.
var last_city_attack_turn: int = -1
## Aetherlands V2, Fase 16 — índice estável (GameManager.players) do dono anterior de quem o DONO
## ATUAL conquistou esta cidade numa captura QUALIFICADA pra Supremacia Militar V2 (a cidade já era
## Cidade III+ no instante da captura); -1 = nenhuma. Reescrito a cada captura. Salvo.
var v2_supremacy_captured_from: int = -1
## Ver SIEGE_TURNS_TO_SUSPEND_REGEN acima — quantos turnos SEGUIDOS ate
## agora tem unidade inimiga adjacente; zera assim que ninguem ameacador
## fica adjacente por um turno.
var _consecutive_siege_turns: int = 0
## Ultimo turno em que o jogador foi avisado de monstros ameacando ESTA
## cidade (ver CityDefense.warn_player) -- so' evita spam, nao e' salvo.
var last_monster_warning_turn: int = -999
## Colonizador e Guarda sao os dois kinds SEM predio de treino associado
## (ver BuildingDatabase.building_that_trains) — Colonizador nao depende
## de nenhum predio, entao E o kind natural pro jogador escolher assim
## que fundar (ver can_train() abaixo), mas isso e ELE quem decide, nao
## um default automatico (ver "" logo abaixo).
##
## "" = cidade OCIOSA, sem nada em producao — pedido do usuario: "eu quero
## que voce so produza uma unidade se for la e pedir... e quando ela
## acabar, so produza outra se voce for la e por pra produzir de novo",
## reforcado depois de uma cidade recem-fundada, SEM NINGUEM MEXER,
## spawnar um Colonizador sozinha ("fundei uma cidade e fiquei dando
## next, e do nada uma hora spawnou um colonizador") — o default "settler"
## sofria do MESMO bug que process_turn() ja corrigia apos completar: uma
## cidade nova comecava com um item ja selecionado sem o jogador pedir.
## Agora toda cidade nasce ociosa, e process_turn() volta pra "" toda vez
## que um item (unidade OU predio) completa, em vez de cair pra
## "settler"/repetir o mesmo item pra sempre sozinha. A IA rival escolhe a
## fila de cada cidade no próprio planejamento (V2StrategicAI.plan_turn, antes
## de process_turn), entao ela nunca fica ociosa de verdade — isso so afeta
## cidades sem ninguem escolhendo pra elas todo turno, ou seja, so a do
## jogador humano.
var production_item: String = ""

## Tiles que a cidade REALMENTE possui (territorio, ver HexGrid.
## city_territory_tiles/_build_city_tint_mesh — o tingimento de cor no chao
## de cada tile e o unico sinal visual disso hoje). Iniciado em
## HexGrid.found_city() (celula + 6 vizinhos) e depois só cresce por anexação
## manual (annex_tile, Pontos de Anexação do City Level) — Fase 13.
var owned_tiles: Array[Vector2i] = []

## Predios ja construidos (ver BuildingDatabase) — Dictionary id->true
## ("existe pelo menos uma cópia"; a contagem de prédio repetível vive em
## repeatable_building_counts). O rendimento dos prédios econômicos é derivado
## por V2EconomyRuntime.
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
## Barras de vida/escudo (ver _build_life_bars/_update_life_bars) — Sprite3D
## com textura redesenhada a cada update, MESMO sistema ja usado e testado
## pra barra de progresso de construcao (ver HexGrid._build_construction_
## progress_bar_texture) — mais robusto que mutar QuadMesh.size em lugar
## (risco de AABB/culling desatualizado quando a barra CRESCE de novo,
## nao so encolhe, ver saga da barra de progresso nesta sessao).
var _life_bar: Sprite3D
var _shield_bar: Sprite3D

func setup(player: PlayerData, start_coord: Vector2i, new_city_name: String, hex_size: float = 1.0) -> void:
	owner_player = player
	coord = start_coord
	city_name = new_city_name
	tile_radius = hex_size
	# hp/shield cheios ao fundar — precisa vir ANTES de _build_visual() pra
	# _build_life_bars() ja desenhar a barra certa desde o primeiro frame,
	# nao um frame de vida 0/0 seguido de correcao.
	hp = max_hp()
	shield = max_shield()
	_build_visual()

## Aetherlands V2, Fase 16: vem do City Level (V2CityLevelData.max_hp), nunca da população.
func max_hp() -> float:
	return V2CityLevelData.max_hp(city_level)

## Aetherlands V2, Fase 16: o escudo (camada externa da muralha) vem da Fortificação V2
## (V2FortificationData.shield_max(fortification_level)) — 0 sem fortificação. O prédio V1 "walls"
## ficou vestigial (BuildingData.superseded_by_v2_fortification).
func max_shield() -> float:
	return V2FortificationData.shield_max(fortification_level)

func has_fortification() -> bool:
	return fortification_level > 0

## Bônus de defesa urbana — só a Fortificação V2 (Fase 25: os prédios defensivos V1 — Torre de Vigia,
## Guarnição e a cadeia de muralhas — não existem mais no gameplay). Usado pela fórmula urbana de
## sempre (CombatResolver.resolve_city_attack) e pela defesa de quem guarnece a cidade.
func defense_bonus() -> float:
	return V2FortificationData.city_defense_bonus(fortification_level)

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
## segundo campo/fila de producao separada. "" (cidade OCIOSA, ver
## comentario de production_item) devolve 0.0 direto — sem essa guarda,
## cairia em UnitDatabase.create_unit(""), que devolve o CUSTO DEFAULT de
## UnitData (15.0, nao 0), um numero enganoso pra quem chama isto achando
## que reflete "nada em producao". Fase 25: sem descontos V1 (identidade de
## cidade, Ferro/Cavalos) — o custo é exatamente o do dado.
func production_cost() -> float:
	if production_item == "":
		return 0.0
	var building: BuildingData = BuildingDatabase.get_building(production_item)
	if building:
		return building.production_cost
	# Aetherlands V2, Fase 13 — City Project (v2_city_upgrade_2/3/4): custo em PP vem de
	# V2CityLevelData, nunca de UnitDatabase.create_unit(production_item) (que devolveria o
	# custo DEFAULT de UnitData pra um id desconhecido, um número enganoso — mesmo cuidado já
	# documentado acima pra production_item == "").
	var upgrade_target := V2CityLevelData.target_level_for_project(production_item)
	if upgrade_target > 0:
		return V2CityLevelData.upgrade_production_cost(upgrade_target)
	# Aetherlands V2, Fase 16 — projeto de Fortificação: mesmo desvio do City Project acima.
	var fortification_target := V2FortificationData.target_level_for_project(production_item)
	if fortification_target > 0:
		return V2FortificationData.production_cost(fortification_target)
	return UnitDatabase.create_unit(production_item).production_cost

## Aetherlands V2, Fase 13 — limite de prédios da cidade: vem do City Level (V2CityLevelData.
## max_building_slots), a única fonte.
func max_building_slots() -> int:
	return V2CityLevelData.max_building_slots(city_level)

## Aetherlands V2, Fase 13 — cada CÓPIA de um prédio repetível (BuildingData.CopyLimitMode.
## CITY_LEVEL) ocupa seu próprio slot: uma cidade com 3 Fazendas ocupa 3 slots, não 1 (§26 do
## pedido). Prédio UNIQUE (o padrão) ocupa 1. Save legado ACIMA do cap atual (mais prédios do que o City Level de hoje permitiria)
## nunca perde nenhum: used_building_slots() simplesmente reporta o valor real, maior que o cap —
## can_build() é quem barra NOVO prédio enquanto isso (§24).
func used_building_slots() -> int:
	var count := 0
	for id in buildings:
		count += building_count(id)
	return count

## Quantas cópias de `building_id` esta cidade já tem — 0 se nenhuma, 1 pra qualquer prédio
## UNIQUE presente (buildings.has), a contagem real pra um prédio CITY_LEVEL (ver
## repeatable_building_counts). Nunca usar só has_building()/buildings.has() pra decidir
## construção de prédio repetível (§28 do pedido) — este é o helper certo.
func building_count(building_id: String) -> int:
	if not buildings.has(building_id):
		return 0
	var building := BuildingDatabase.get_building(building_id)
	if building != null and building.copy_limit_mode == BuildingData.CopyLimitMode.CITY_LEVEL:
		return int(repeatable_building_counts.get(building_id, 1))
	return 1

## Máximo de cópias de `building` que esta cidade pode ter — 1 pra UNIQUE (sempre, em qualquer
## City Level), V2CityLevelData.repeatable_building_limit(city_level) pra CITY_LEVEL (§26).
func max_copies_for_building(building: BuildingData) -> int:
	if building == null or building.copy_limit_mode != BuildingData.CopyLimitMode.CITY_LEVEL:
		return 1
	return V2CityLevelData.repeatable_building_limit(city_level)

func can_build(building_id: String) -> bool:
	var building := BuildingDatabase.get_building(building_id)
	if building == null:
		return false
	if building_count(building_id) >= max_copies_for_building(building):
		return false
	if used_building_slots() >= max_building_slots():
		return false
	if not _prerequisite_building_present(building_id):
		return false
	# Aetherlands V2, Fase 15 (§43 do pedido): prédio com manutenção de Ouro não pode ser INICIADO
	# durante Déficit — o Mercado (upkeep 0) continua disponível,
	# então a economia sempre tem uma rota de recuperação. Construção já em andamento não é afetada
	# (este gate só decide se PODE começar, nunca cancela o que já está na fila).
	if building.gold_upkeep > 0.0 and owner_player != null and V2EconomyRuntime.is_gold_deficit(owner_player):
		return false
	return _research_unlocked_for_building(building_id)

## Aetherlands V2, Fase 15 — por que `building_id` não pode ser construído agora POR CAUSA do
## Déficit ("" = não é o motivo). Mesmo espírito de V2LegendarySystem.slot_only_reason: só tem algo
## a dizer quando o Déficit é de fato o motivo (prédio tem upkeep e a civilização está em Déficit),
## nunca some informação atrás de "Indisponível" genérico (§43 do pedido).
func deficit_build_reason(building_id: String) -> String:
	var building := BuildingDatabase.get_building(building_id)
	if building == null or building.gold_upkeep <= 0.0:
		return ""
	if owner_player != null and V2EconomyRuntime.is_gold_deficit(owner_player):
		return "Déficit de Ouro: estabilize a economia antes de adicionar manutenção."
	return ""

## Aetherlands V2, Fase 13 — is_developed_v2(): API semântica genérica de "Cidade Desenvolvida"
## (§20 do pedido). Regra: city_level >= V2CityLevelData.DEVELOPED_MIN_LEVEL (3). Consultada pela
## Supremacia Militar V2 (V2VictoryConditions) e pela IA.
func is_developed_v2() -> bool:
	return V2CityLevelData.is_developed(city_level)

## Aetherlands V2, Fase 13 — por que esta cidade NÃO pode iniciar o projeto de upgrade pro
## PRÓXIMO City Level agora ("" = pode). Única fonte do texto de bloqueio (§47 do pedido: motivos
## distintos — "Requer <pesquisa>.", "Requer N Ouro.", "Produção da cidade já está ocupada.",
## "Cidade já está no nível máximo." — nunca um "Indisponível" genérico).
func city_upgrade_unavailable_reason() -> String:
	var target := V2CityLevelData.next_level(city_level)
	if target == 0:
		return "Cidade já está no nível máximo."
	var research_id := V2CityLevelData.research_required_for_level(target)
	if research_id != "" and (owner_player == null or not owner_player.has_unlocked(V2CityLevelData.unlock_id_for_level(target))):
		var node := V2ResearchDatabase.get_node(research_id)
		return "Requer %s." % (node.display_name if node != null else research_id)
	# §16 do pedido: precisa TER o Ouro pra INICIAR (não é descontado ainda — só na conclusão,
	# ver process_turn). Sem isso o jogador poderia começar um projeto sem nunca conseguir pagar.
	var gold_cost := V2CityLevelData.upgrade_gold_cost(target)
	if owner_player == null or owner_player.gold < gold_cost:
		return "Requer %d Ouro." % int(gold_cost)
	var project_id := V2CityLevelData.project_id_for_level(target)
	if production_item != "" and production_item != project_id:
		return "Produção da cidade já está ocupada."
	return ""

func can_start_city_upgrade() -> bool:
	return city_upgrade_unavailable_reason() == ""

## Aetherlands V2, Fase 16 — por que esta cidade NÃO pode iniciar o PRÓXIMO nível de Fortificação
## agora ("" = pode). Requisitos vêm todos de V2FortificationData (pesquisa, City Level, nível
## anterior); um nível CAPTURADO acima da pesquisa do dono continua existindo, mas avançar exige a
## pesquisa e o City Level do dono atual.
func fortification_unavailable_reason() -> String:
	var target := V2FortificationData.next_level(fortification_level)
	if target == 0:
		return "Fortificação já está no nível máximo."
	var unlock_id := V2FortificationData.required_research_id(target)
	if unlock_id != "" and (owner_player == null or not owner_player.has_unlocked(unlock_id)):
		var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
		return "Requer %s." % (node.display_name if node != null else unlock_id)
	var needed_level := V2FortificationData.required_city_level(target)
	if city_level < needed_level:
		return "Requer %s." % V2CityLevelData.level_name(needed_level)
	var project_id := V2FortificationData.project_id(target)
	if production_item != "" and production_item != project_id:
		return "Produção da cidade já está ocupada."
	var deficit_reason := fortification_deficit_reason()
	if deficit_reason != "" and production_item != project_id:
		return deficit_reason
	return ""

func can_start_fortification() -> bool:
	return fortification_unavailable_reason() == ""

## Mesmo princípio de deficit_build_reason (Fase 15): um projeto de Fortificação com upkeep não pode
## ser INICIADO em Déficit; um já em andamento continua.
func fortification_deficit_reason() -> String:
	var target := V2FortificationData.next_level(fortification_level)
	if target == 0 or V2FortificationData.gold_upkeep(target) <= 0.0:
		return ""
	if owner_player != null and V2EconomyRuntime.is_gold_deficit(owner_player):
		return "Déficit de Ouro: estabilize a economia antes de ampliar a fortificação."
	return ""

## Conclui um nível de Fortificação preservando o dano absoluto já sofrido pelo escudo (§24 do pedido):
## novo = clamp(novo_max − (antigo_max − atual), 0, novo_max) — upgrade nunca cura de graça.
func apply_fortification_level(new_level: int) -> void:
	var old_missing := maxf(max_shield() - shield, 0.0)
	fortification_level = V2FortificationData.clamp_level(new_level)
	shield = clampf(max_shield() - old_missing, 0.0, max_shield())

## Sobe o City Level preservando a FRAÇÃO de HP (§27 do pedido: 15/30 -> 18/36, nunca cura cheio).
func apply_city_level(new_level: int) -> void:
	var fraction := hp / maxf(max_hp(), 0.001)
	city_level = new_level
	hp = clampf(fraction * max_hp(), 0.0, max_hp())
	# Fase 25: o visual (casinhas/torre) e o rótulo refletem o City Level — só se o visual já foi montado
	# (City.new() de teste sem setup() não tem nós pra refazer).
	if _name_label != null:
		_build_visual_procedural()
		_refresh_label()

## Aetherlands V2, Fase 17 — Mana que falta para a unidade em produção nascer (0 se não há exigência ou já basta).
## A HUD mostra "Aguardando N Mana." quando os PP já completaram e isto é > 0.
func production_waiting_for_mana() -> int:
	if production_item == "" or not V2ResearchDatabase.is_v2_id(production_item) or BuildingDatabase.get_building(production_item) != null:
		return 0
	var cost := UnitDatabase.create_unit(production_item).production_mana_cost
	if cost <= 0.0 or owner_player == null or owner_player.mana >= cost:
		return 0
	return int(ceil(cost))

## Aetherlands V2, Fase 13 — true enquanto o projeto de upgrade ATUAL já acumulou o PP total mas
## está esperando Ouro suficiente pra concluir (ver process_turn: stored_production fica travado
## no custo total sem perder nada). HUD usa isto pra mostrar "Aguardando N Ouro." (§16 do pedido).
func city_upgrade_waiting_for_gold() -> int:
	var target := V2CityLevelData.target_level_for_project(production_item)
	if target == 0 or stored_production < production_cost():
		return 0
	var gold_cost := V2CityLevelData.upgrade_gold_cost(target)
	return int(gold_cost) if owner_player == null or owner_player.gold < gold_cost else 0

## Alguns prédios exigem OUTRO prédio já construído nesta mesma cidade antes
## (BuildingData.requires_building, ex.: a Maestria de uma Doutrina exige o Salão dela).
## Independente do gate de pesquisa logo abaixo — os dois se combinam.
func _prerequisite_building_present(building_id: String) -> bool:
	var building: BuildingData = BuildingDatabase.get_building(building_id)
	if building == null or building.requires_building == "":
		return true
	return buildings.has(building.requires_building)

## Todo prédio é liberado pela pesquisa V2 da civilização dona (derivada de
## v2_research.is_completed — nenhum estado duplicado, ver V2UnlockSystem). Fase 25: não existe mais
## gate de Tecnologia/Magia V1 — os prédios V1 nem estão no catálogo (BuildingDatabase), então
## can_build já os recusa antes deste gate.
func _research_unlocked_for_building(building_id: String) -> bool:
	return V2UnlockSystem.is_unlocked(owner_player, building_id)

## Treino: toda unidade da progressão é V2 e exige a pesquisa do dono ALÉM do prédio de treino
## (BuildingDatabase.building_that_trains). Fase 25: fora da V2 só o núcleo civil compartilhado
## (UnitDatabase.CORE_TRAINABLE_KINDS — o Colonizador) é treinável; nenhuma tropa V1 abre fila.
## Chamado tanto pela HUD (jogador) quanto por V2StrategicAI (rival) — mesmo gate, sem bypass.
func can_train(kind: String) -> bool:
	# Aetherlands V2 (Fase 3): unidade V2 exige a pesquisa V2 do dono ALÉM do prédio
	# de treino abaixo (Escudeiro: nó N3 + Salão dos Guardiões).
	if V2ResearchDatabase.is_v2_id(kind):
		# Fase 15: redireciona pra UnitData.required_v2_unlock_id quando declarado (Construtor —
		# pesquisar Oficinas libera treiná-lo). Comportamento idêntico a antes pra toda outra unidade.
		if not V2UnlockSystem.is_unit_unlocked(owner_player, kind):
			return false
		# Fase 4: numa linha de Doutrina só a forma MAIS AVANÇADA liberada é produção
		# normal (com N5 o Salão oferece o Guardião, não mais o Escudeiro). Quem já
		# existe continua existindo e evolui por upgrade (V2UnitUpgrade).
		if V2UnitLine.is_line_unit(kind) and not V2UnitLine.is_current_trainable_form(owner_player, kind):
			return false
		# Fase 6: Unidade Lendária (de qualquer Doutrina) só se a civilização tem slot livre — nenhuma ativa
		# e nenhuma em produção em OUTRA cidade (V2LegendarySystem; o prédio de treino é o gate normal abaixo).
		if V2LegendarySystem.is_legendary_kind(kind) and not V2LegendarySystem.legendary_slot_available(owner_player, self):
			return false
		# Fase 17: Grande Manifestação — 1 por Escola (ativa ou em produção em OUTRA cidade), independente da Lendária.
		if V2ManifestationSystem.is_manifestation_kind(kind) and not V2ManifestationSystem.slot_available(owner_player, V2ManifestationSystem.school_of_kind(kind), self):
			return false
		# Fase 17: Mana de produção exigida para INICIAR (nunca reservada/descontada aqui; a cidade que já produz não é barrada).
		if V2ManifestationSystem.production_mana_reason(owner_player, self, kind) != "":
			return false
		# Fase 15: Suprimentos/Déficit (§11/§41 do pedido) — só tem efeito pra kind com supply_cost > 0
		# (o Construtor, supply_cost 0, nunca é barrado por aqui).
		if not V2LogisticsRuntime.can_afford_training(owner_player, self, kind):
			return false
	elif not kind in UnitDatabase.CORE_TRAINABLE_KINDS:
		return false
	var required: BuildingData = BuildingDatabase.building_that_trains(kind)
	if required == null:
		return true
	return buildings.has(required.id)

## Tile valido pra POSICIONAR um predio: precisa ser vizinho imediato da
## cidade ou parte do território dela (owned_tiles), terra
## firme, sem unidade/cidade em cima, e sem outro predio (desta cidade ou
## de qualquer outra, ver HexGrid.is_tile_building_site) ja la.
func is_valid_building_tile(target: Vector2i, hex_grid: HexGrid) -> bool:
	if target == coord or (not target in hex_grid.get_neighbors(coord) and not target in owned_tiles):
		return false
	var tile_owner := hex_grid.city_owning_tile(target)
	if tile_owner != null and tile_owner != self:
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

## Unidade hostil (monstro neutro OU unidade de outro jogador em guerra
## com o dono desta cidade) grudada num tile vizinho AGORA — nao guarda
## memoria nenhuma alem do contador _consecutive_siege_turns acima
## (unidade que sai de perto zera o progresso do sitio no mesmo turno).
func _is_enemy_adjacent(hex_grid: HexGrid) -> bool:
	for neighbor_coord in hex_grid.get_neighbors(coord):
		var unit: Unit = hex_grid.get_unit_at(neighbor_coord)
		if unit == null:
			continue
		if unit.owner_player == null:
			return true # covil/monstro neutro conta como ameaca de sitio tambem
		if unit.owner_player != owner_player and owner_player.is_at_war_with(unit.owner_player):
			return true
	return false

func process_turn(hex_grid: HexGrid) -> Dictionary:
	# Produção LOCAL desta cidade vem só de V2EconomyRuntime.city_production_income() — base fixa +
	# Oficinas + melhorias de Ferro pelo tier de pesquisa do dono (Fase 14). Fase 25: não existe mais
	# comida, população, crescimento nem tiles trabalhados — nada além disto entra aqui.
	stored_production += V2EconomyRuntime.city_production_income(self)

	var spawned_kind := ""
	var built_kind := ""
	var built_coord := NO_PENDING_COORD
	var city_level_up := 0
	var fortification_level_up := 0
	# production_item == "" (cidade OCIOSA, ver comentario da variavel e
	# set_production()) nunca completa nada sozinha — pedido do usuario:
	# "a partir do momento que voce funda a cidade, ele fica produzindo
	# sem parar unidades... eu quero que... quando ela acabar, so produza
	# outra se voce for la e por pra produzir de novo". Guarda aqui (em
	# vez de so confiar em production_cost() devolver 0.0 pra "") pra
	# nao chamar UnitDatabase.create_unit("") a toa todo turno.
	if production_item != "":
		# Aetherlands V2, Fase 13 — City Project (v2_city_upgrade_2/3/4): NÃO é unidade nem
		# prédio, usa a MESMA fila local (§13/§14 do pedido), então precisa ser desviado ANTES
		# do "blocked_spawn"/ramo unidade-ou-prédio abaixo (que assumiria "prédio == não-unidade"
		# e tentaria spawnar uma unidade inexistente). Ver V2CityLevelData.target_level_for_project.
		var upgrade_target := V2CityLevelData.target_level_for_project(production_item)
		if upgrade_target > 0:
			var cost = production_cost()
			if stored_production >= cost:
				# Ouro só é cobrado AQUI, na conclusão — nunca reservado ao selecionar o projeto
				# (§16 do pedido: evita depósito salvo separadamente/refund/double-charge em
				# load). Sem Ouro suficiente: PP fica TRAVADO no custo total (nunca perde, nunca
				# ultrapassa) até a cidade ser processada de novo com Ouro suficiente — sem
				# boolean de reserva, sem estado novo.
				var gold_cost := V2CityLevelData.upgrade_gold_cost(upgrade_target)
				if owner_player != null and owner_player.gold >= gold_cost:
					owner_player.gold -= gold_cost
					stored_production -= cost
					apply_city_level(upgrade_target)
					annexation_points += V2CityLevelData.annexation_grant(city_level) + V2RaceBonusRuntime.annexation_point_bonus(owner_player)
					city_level_up = city_level
					production_item = ""
				else:
					stored_production = cost
		elif V2FortificationData.is_fortification_project(production_item):
			# Aetherlands V2, Fase 16 — projeto de Fortificação: mesma fila local, sem Ouro na conclusão
			# (o custo é só PP; o custo contínuo é o upkeep).
			var cost = production_cost()
			if stored_production >= cost:
				stored_production -= cost
				apply_fortification_level(V2FortificationData.target_level_for_project(production_item))
				fortification_level_up = fortification_level
				production_item = ""
				_build_visual_procedural()
		else:
			var cost = production_cost()
			var blocked_spawn := BuildingDatabase.get_building(production_item) == null and WorldSetup.find_spawn_tile(hex_grid, coord) == WorldSetup.NO_SPAWN_COORD
			# Aetherlands V2, Fase 17 — unidade com Mana de produção (Serafim): com os PP completos mas Mana insuficiente, a
			# produção ESPERA completa (PP travados no custo, sem perder nada, sem cobrar nada, o slot continua reservado pela
			# própria ordem). A Mana é descontada UMA vez no nascimento (GameManager), nunca aqui.
			if not blocked_spawn and production_waiting_for_mana() > 0 and stored_production >= cost:
				blocked_spawn = true
			if blocked_spawn:
				stored_production = minf(stored_production, cost)
			if stored_production >= cost and not blocked_spawn:
				stored_production -= cost
				var building: BuildingData = BuildingDatabase.get_building(production_item)
				if building:
					buildings[production_item] = true
					built_kind = production_item
					if building.copy_limit_mode == BuildingData.CopyLimitMode.CITY_LEVEL:
						repeatable_building_counts[production_item] = int(repeatable_building_counts.get(production_item, 0)) + 1
					# pending_building_coord so fica vazio se algo chamou
					# set_production() direto (ex: testes) sem passar pelo fluxo de
					# posicionamento — o predio ainda conta pro limite/rendimento, so
					# nao ganha modelo 3D no mapa.
					if pending_building_coord != NO_PENDING_COORD:
						# Aetherlands V2, Fase 14 — prédio CITY_LEVEL: cada cópia tem SEU PRÓPRIO
						# tile (§8/§98 do pedido), então a coordenada é ACRESCENTADA a um array em
						# vez de sobrescrever `building_coords[id]` (que só guarda 1 coord — correto
						# pra prédio UNIQUE, errado pra uma 2ª/3ª/4ª cópia). Ver
						# repeatable_building_coords acima.
						if building.copy_limit_mode == BuildingData.CopyLimitMode.CITY_LEVEL:
							var coords: Array = repeatable_building_coords.get(production_item, [])
							coords.append(pending_building_coord)
							repeatable_building_coords[production_item] = coords
						else:
							building_coords[production_item] = pending_building_coord
						built_coord = pending_building_coord
					pending_building_coord = NO_PENDING_COORD
					# Fica OCIOSA apos completar — pedido do usuario (ver
					# comentario acima). ANTES caia de volta pra "settler" e
					# ficava reconstruindo Colonizador pra sempre sozinha;
					# agora o jogador escolhe o proximo item explicitamente
					# (a IA escolhe a própria fila todo turno, V2StrategicAI).
					production_item = ""
				else:
					spawned_kind = production_item
					production_item = "" # idem acima — tropa concluida tambem deixa a cidade ociosa

	# Cura passiva de vida/escudo, todo turno — mesmo espirito da cura de
	# guarnicao de unidade (GameManager._heal_if_garrisoned/_apply_regen).
	# Sem isso, uma cidade que sobreviveu a um ataque ficaria FERIDA PRA
	# SEMPRE (proximo ataque, mesmo fraco, a capturaria trivialmente) —
	# shield regenera mais rapido que hp de proposito, e uma estrutura
	# defensiva feita pra recuperar entre cercos, nao pra desgastar
	# permanentemente. EXCETO sob sitio de verdade (ver
	# SIEGE_TURNS_TO_SUSPEND_REGEN acima) — regenerar livremente com o
	# inimigo parado na porta ha 2+ turnos tornaria cerco irrelevante.
	if _is_enemy_adjacent(hex_grid):
		_consecutive_siege_turns += 1
	else:
		_consecutive_siege_turns = 0
	if _consecutive_siege_turns < SIEGE_TURNS_TO_SUSPEND_REGEN:
		if hp < max_hp():
			hp = min(hp + max_hp() * CITY_HP_REGEN_FRACTION, max_hp())
		if shield < max_shield():
			shield = min(shield + max_shield() * CITY_SHIELD_REGEN_FRACTION, max_shield())
	_update_life_bars()

	return {"spawn_unit_kind": spawned_kind, "built_kind": built_kind, "built_coord": built_coord, "city_level_up": city_level_up, "fortification_level_up": fortification_level_up}

func claim_tile(coord_to_claim: Vector2i) -> void:
	if not coord_to_claim in owned_tiles:
		owned_tiles.append(coord_to_claim)

## Aetherlands V2, Fase 13 — por que `target` NÃO pode ser anexado por esta cidade agora ("" =
## pode). Nenhuma restrição de terreno — água pode ser território (§39 do pedido da Fase 13): só barra tile inexistente, já possuído (por esta cidade ou outra), fora do
## raio de V2CityLevelData.max_territory_radius(city_level), ou não contíguo ao território atual.
func annex_unavailable_reason(target: Vector2i, hex_grid: HexGrid) -> String:
	if annexation_points <= 0:
		return "Sem Pontos de Anexação."
	if not hex_grid.tiles.has(target):
		return "Tile inexistente."
	if target in owned_tiles:
		return "Tile já pertence a esta cidade."
	if hex_grid.get_city_at(target) != null or hex_grid.city_owning_tile(target) != null:
		return "Tile já pertence a outra cidade."
	if HexMetrics.axial_distance(coord, target) > V2CityLevelData.max_territory_radius(city_level):
		return "Fora do raio territorial da cidade."
	for n in hex_grid.get_neighbors(target):
		if n in owned_tiles:
			return ""
	return "Tile não é contíguo ao território atual da cidade."

func can_annex_tile(target: Vector2i, hex_grid: HexGrid) -> bool:
	return annex_unavailable_reason(target, hex_grid) == ""

## Anexa `target` de verdade: gasta EXATAMENTE 1 ponto e reivindica o tile (claim_tile) — atômico (§41 do pedido): se a anexação falhar, nada é
## gasto. Devolve false sem alterar nada se `target` não é elegível agora.
func annex_tile(target: Vector2i, hex_grid: HexGrid) -> bool:
	if not can_annex_tile(target, hex_grid):
		return false
	annexation_points -= 1
	claim_tile(target)
	return true

## Todos os tiles elegíveis pra anexação AGORA (pro destaque visual da UI, §48/§100 do pedido —
## só recalculado ao entrar no modo, ao anexar ou quando level/pontos mudam, nunca por frame).
## Bounded pelo raio territorial (V2CityLevelData.max_territory_radius <= 4), nunca varre o mapa
## inteiro (§98/§99).
func eligible_annexation_tiles(hex_grid: HexGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if annexation_points <= 0:
		return result
	for candidate in HexMetrics.coords_within(coord, V2CityLevelData.max_territory_radius(city_level)):
		if can_annex_tile(candidate, hex_grid):
			result.append(candidate)
	return result

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

	_build_life_bars()

## Duas barras Sprite3D empilhadas, SEMPRE visiveis (nao so quando
## danificada, diferente da barra de HP de unidade — ver Unit._build_hp_
## bar) — pedido do usuario: "sempre mostrando na tela quanta vida ela
## tem". Escudo fica LOGO ABAIXO da vida ("outra vida abaixo da vida
## atual, sendo o shield") e so aparece depois de Muralhas construida (ver
## _update_life_bars/max_shield()).
const LIFE_BAR_Y := 1.65
const SHIELD_BAR_Y := 1.5
const LIFE_BAR_TEX_WIDTH := 64
const LIFE_BAR_TEX_HEIGHT := 10
const LIFE_BAR_PIXEL_SIZE := 0.011
const LIFE_BAR_BORDER_COLOR := Color(0.08, 0.06, 0.05)
const LIFE_BAR_EMPTY_COLOR := Color(0.5, 0.5, 0.52, 0.95)
const LIFE_BAR_HIGH_COLOR := Color(0.3, 0.8, 0.3)
const LIFE_BAR_MID_COLOR := Color(0.85, 0.75, 0.2)
const LIFE_BAR_LOW_COLOR := Color(0.85, 0.2, 0.2)
const SHIELD_BAR_FILL_COLOR := Color(0.35, 0.65, 0.95)
const SHIELD_BAR_EMPTY_COLOR := Color(0.4, 0.42, 0.48, 0.95)

func _build_life_bars() -> void:
	_life_bar = Sprite3D.new()
	_life_bar.name = "LifeBar"
	_life_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_life_bar.no_depth_test = true
	_life_bar.shaded = false
	_life_bar.pixel_size = LIFE_BAR_PIXEL_SIZE
	_life_bar.position = Vector3(0, LIFE_BAR_Y, 0)
	add_child(_life_bar)

	_shield_bar = Sprite3D.new()
	_shield_bar.name = "ShieldBar"
	_shield_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_shield_bar.no_depth_test = true
	_shield_bar.shaded = false
	_shield_bar.pixel_size = LIFE_BAR_PIXEL_SIZE
	_shield_bar.position = Vector3(0, SHIELD_BAR_Y, 0)
	add_child(_shield_bar)

	_update_life_bars()

## Chamado sempre que hp/shield muda (combate, regen por turno, subida de
## City Level — que muda max_hp() — e conclusao de Fortificação) — so redesenha a TEXTURA, nunca mexe
## em tamanho/posicao (mesmo motivo da barra de progresso de construcao,
## ver HexGrid._update_construction_marker_progress).
func _update_life_bars() -> void:
	if _life_bar == null:
		return
	var hp_frac = clamp(hp / max_hp(), 0.0, 1.0) if max_hp() > 0.0 else 1.0
	_life_bar.texture = _build_life_bar_texture(hp_frac, _life_bar_fill_color(hp_frac), LIFE_BAR_EMPTY_COLOR)

	var has_shield := max_shield() > 0.0 # Fase 16: escudo vem da Fortificação V2
	_shield_bar.visible = has_shield
	if has_shield:
		var shield_frac = clamp(shield / max_shield(), 0.0, 1.0) if max_shield() > 0.0 else 0.0
		_shield_bar.texture = _build_life_bar_texture(shield_frac, SHIELD_BAR_FILL_COLOR, SHIELD_BAR_EMPTY_COLOR)

func _life_bar_fill_color(frac: float) -> Color:
	if frac > 0.6:
		return LIFE_BAR_HIGH_COLOR
	elif frac > 0.3:
		return LIFE_BAR_MID_COLOR
	return LIFE_BAR_LOW_COLOR

func _build_life_bar_texture(frac: float, fill_color: Color, empty_color: Color) -> ImageTexture:
	var w := LIFE_BAR_TEX_WIDTH
	var h := LIFE_BAR_TEX_HEIGHT
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var fill_px := roundi(w * clamp(frac, 0.0, 1.0))
	for x in range(w):
		var is_border_x = x == 0 or x == w - 1
		for y in range(h):
			var is_border_y = y == 0 or y == h - 1
			var color: Color
			if is_border_x or is_border_y:
				color = LIFE_BAR_BORDER_COLOR
			else:
				color = fill_color if x < fill_px else empty_color
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

## Reconstroi o CLUSTER de construcoes (nao o label, ver _buildings_root)
## a partir do City Level atual — chamado na fundacao (_build_visual), ao subir
## de nível (apply_city_level) e ao concluir Fortificação. RNG seedado pelo
## proprio `coord` (nao randi() puro): a disposicao das casinhas fica
## ESTAVEL entre reconstrucoes (subir de nível so ACRESCENTA casinhas, as
## antigas nao pulam de lugar).
func _build_visual_procedural() -> void:
	if _buildings_root:
		_buildings_root.queue_free()
	_buildings_root = Node3D.new()
	add_child(_buildings_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coord)

	var civ_color = owner_player.civ.color.lightened(0.1) if owner_player else Color(0.6, 0.6, 0.6)
	var is_town_or_bigger = city_level >= 2
	var is_city = city_level >= 3

	# Teto fixo de casinhas por City Level (HUTS_BY_CITY_LEVEL, máx. 8) — o número de meshes nunca
	# cresce sem limite; na Cidade IV só a torre central engorda (ver _add_tower).
	var hut_count: int = HUTS_BY_CITY_LEVEL.get(V2CityLevelData.clamp_level(city_level), 3)
	var hut_scale = 0.85 if not is_town_or_bigger else (1.0 if not is_city else 1.1)
	for i in range(hut_count):
		var angle = (TAU / hut_count) * i + rng.randf_range(-0.2, 0.2)
		var radius = rng.randf_range(0.28, 0.44)
		var pos = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_add_hut(pos, hut_scale * rng.randf_range(0.85, 1.15), rng)

	if is_city:
		_add_tower(civ_color, city_level)
	else:
		_add_small_keep(civ_color)
	# Anel de muralha: reflete a Fortificação V2 (fortification_level >= 1, Fase 16) — independente
	# do City Level, uma aldeia murada é tão válida quanto uma cidade grande sem muralha.
	if has_fortification():
		_add_walls()

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

## Salao/casa grande central (Cidade I e II) —
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

## Torre central (Cidade III+) — maior que o
## salao de vila, e cresce um pouco mais alem disso (teto proprio, ver
## extra_tier) pra dar alguma diferenca visual entre uma cidade recem-
## murada (pop 5) e um imperio tardio (pop 15+) sem acrescentar NENHUM
## mesh novo (so escala o que ja existe).
func _add_tower(civ_color: Color, level: int) -> void:
	var extra_tier = clampi(level - 3, 0, 1) * 2
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

## Muralha de VERDADE contornando o hexagono do tile — pedido do usuario:
## "se as celulas sao hexagonos, a muralha devem ser um conjunto de retas
## em cada aresta pra formar um hexagono ao redor da celula da cidade",
## depois confirmado com um desenho por cima do proprio contorno do tile
## (a quebra agua/terra): "voce conseguiria fazer... como esse vermelho
## que tracei" — ou seja, do TAMANHO do tile de verdade (ver tile_radius,
## HexGrid.hex_size), nao um raio local pequeno so abraçando o cluster de
## predios do centro (primeira tentativa, rejeitada por ficar mal
## encaixada e pequena demais).
##
## Geometria de hexagono regular (mesma formula angular de HexMetrics.
## corner, agora aplicada ao raio REAL do tile):
## - O MEIO de cada aresta fica no APOTEMA (raio * cos 30°), nao no
##   circunraio (onde ficam os VERTICES).
## - O comprimento de cada aresta de um hexagono regular e IGUAL ao
##   proprio circunraio.
## 6 segmentos retos (um por aresta, centralizados no apotema, alinhados
## com a aresta) + 6 pilares curtos exatamente nos VERTICES (via
## HexMetrics.corner) fecham as juntas entre segmentos adjacentes e leem
## como torres de canto — silhueta de hexagono fechado, do tamanho do
## proprio tile.
const WALL_RADIUS_FACTOR := 0.94 # levemente < 1.0: fica por DENTRO da borda do tile, sem vazar pro vizinho
const WALL_SEGMENT_LENGTH_FACTOR := 0.86 # fracao da aresta cheia: sobra vira o vao que o pilar de canto preenche
const WALL_HEIGHT_FACTOR := 0.24
const WALL_THICKNESS_FACTOR := 0.1
const WALL_PILLAR_RADIUS_FACTOR := 0.065
const WALL_PILLAR_HEIGHT_FACTOR := 0.32

func _add_walls() -> void:
	var wall_radius = tile_radius * WALL_RADIUS_FACTOR
	var wall_apothem = wall_radius * 0.8660254 # cos(30°) — hexagono regular
	var wall_segment_length = wall_radius * WALL_SEGMENT_LENGTH_FACTOR
	var wall_height = wall_radius * WALL_HEIGHT_FACTOR
	var wall_thickness = wall_radius * WALL_THICKNESS_FACTOR
	var wall_pillar_radius = wall_radius * WALL_PILLAR_RADIUS_FACTOR
	var wall_pillar_height = wall_radius * WALL_PILLAR_HEIGHT_FACTOR

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.5, 0.48, 0.45)
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.42, 0.4, 0.38)

	for i in range(6):
		# angulo do MEIO da aresta i — os dois vertices que a delimitam
		# ficam em HexMetrics.corner(), a (60*i - 30) e (60*i + 30), entao
		# o meio cai exatamente em 60*i.
		var mid_angle = deg_to_rad(60.0 * i)
		var seg := MeshInstance3D.new()
		var seg_mesh := BoxMesh.new()
		seg_mesh.size = Vector3(wall_segment_length, wall_height, wall_thickness)
		seg.mesh = seg_mesh
		seg.material_override = wall_mat
		seg.position = Vector3(cos(mid_angle) * wall_apothem, wall_height * 0.5, sin(mid_angle) * wall_apothem)
		# Gira o comprimento (eixo X local) pra tangente da aresta. NAO e
		# "mid_angle + PI/2" (formula antiga, matematicamente errada pra 4
		# das 6 arestas — so i=0/i=3 acertavam por coincidencia de simetria
		# diametral, as outras 4 espelhavam o segmento pro lado errado,
		# cruzando com os vizinhos em vez de formar hexagono fechado).
		# Derivacao: rotation.y=θ leva o eixo +X local pra mundo
		# (cos θ, -sin θ). A direcao real da aresta i (do vertice
		# HexMetrics.corner(i) ao corner(i+1)) e proporcional a
		# (-sin(mid_angle), cos(mid_angle)) — resolvendo cos θ=-sin(mid_angle)
		# e -sin θ=cos(mid_angle) da θ = -mid_angle - PI/2.
		seg.rotation.y = -mid_angle - PI / 2.0
		_buildings_root.add_child(seg)

		var corner_pos := HexMetrics.corner(wall_radius, i)
		var pillar := MeshInstance3D.new()
		var pillar_mesh := CylinderMesh.new()
		pillar_mesh.top_radius = wall_pillar_radius
		pillar_mesh.bottom_radius = wall_pillar_radius
		pillar_mesh.height = wall_pillar_height
		pillar.mesh = pillar_mesh
		pillar.material_override = pillar_mat
		pillar.position = Vector3(corner_pos.x, wall_pillar_height * 0.5, corner_pos.z)
		_buildings_root.add_child(pillar)

func _refresh_label() -> void:
	if _name_label:
		_name_label.text = "%s (%s)" % [city_name, V2CityLevelData.roman(city_level)]

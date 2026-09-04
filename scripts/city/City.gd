class_name City
extends Node3D

## Redesenho do sistema de comida (pedido do usuario): antes acumulava sem
## limite ate um limiar calculado por FOOD_TO_GROW_BASE*populacao. Agora
## toda cidade tem um TETO de armazenamento fixo (aumentado pelo Celeiro,
## ver food_storage_cap()/BuildingData.storage_bonus), e a populacao
## CONSOME comida todo turno — se a producao do turno nao cobre o consumo,
## o estoque so PARA de crescer (nunca fica negativo, nunca reduz
## populacao, decisao explicita do usuario: "só trava o crescimento").
## Cidade cresce 1 populacao quando o estoque atinge o teto (ver
## process_turn()).
const FOOD_STORAGE_BASE := 15.0
const FOOD_CONSUMPTION_PER_POP := 1.0
const LABEL_HEIGHT := 1.4

## Taxa de conversao ouro->producao do rush-buy do Mercado (ver
## can_rush_buy()/rush_buy_cost()/rush_buy() abaixo) — cada ponto de
## producao FALTANTE no item atual custa isso em ouro pra comprar na hora.
const RUSH_BUY_GOLD_PER_PRODUCTION := 2.0

## Piso de producao garantido pro tile CENTRAL da cidade (ver collect_
## yields) — sem isso, uma cidade fundada em Planicie/Deserto/qualquer
## terreno com production_yield 0 (ver TerrainDatabase) ficava com
## stored_production LITERALMENTE travado em zero por varios turnos, ate a
## populacao crescer o bastante pra reivindicar um segundo tile trabalhado
## com producao de verdade — pedido do usuario apos reportar a barra de
## progresso "vários turnos com ela no 0": "não sei se o problema é que a
## construção realmente fica congelada no tempo no início". Era: o tile da
## cidade nao tinha NENHUM piso, e auto_assign_worked_tiles (score = food*
## 1.5 + production*1.3) prefere Planicie de producao 0 sobre Colina/
## Floresta de producao 2 so por causa do peso maior em comida, entao nem o
## primeiro tile trabalhado corrigia isso sozinho. Padrao consagrado de 4X
## (Civilization e afins): o tile central sempre garante um minimo de
## producao, nunca fica refem do terreno cru embaixo dele.
const CITY_CENTER_MIN_PRODUCTION := 1.0

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
## max_hp cresce com a populacao (cidade tardia e mais dificil de arrasar);
## max_shield e um valor fixo, so existe se o predio "walls" ja foi
## construido (ver max_shield()).
const CITY_BASE_MAX_HP := 20.0
const CITY_MAX_HP_PER_POPULATION := 4.0
const CITY_HP_REGEN_FRACTION := 0.08 # fracao de max_hp curada por turno
const CITY_MAX_SHIELD := 15.0
const CITY_SHIELD_REGEN_FRACTION := 0.15 # fracao de max_shield recarregada por turno
## Atrito de cerco (roadmap de gameplay Fase 2): unidade inimiga adjacente
## por N turnos SEGUIDOS suspende a regeneracao de HP/escudo da cidade
## (ver _is_enemy_adjacent/process_turn) — pedido do usuario: "comecar com
## UMA unica consequencia simples e legivel" em vez de inventar um dreno
## novo de producao/comida, so desligar um bonus que ja existe. N=2 (nao
## 1) de proposito: uma unidade so DE PASSAGEM no territorio, sem
## intencao de cercar, nao deveria contar como sitio de verdade.
const SIEGE_TURNS_TO_SUSPEND_REGEN := 2

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
## 5+: cidade grande — casinhas + torre (torre NAO implica muralha mais,
## ver _build_visual_procedural/_add_walls: a muralha agora reflete se o
## predio "walls" foi construido, independente de populacao)

var owner_player: PlayerData
var coord: Vector2i
var city_name: String = "Cidade"
## Circunraio REAL do hex do tile (HexGrid.hex_size, ver setup()) — pedido
## do usuario apos ver a muralha pequena demais e mal encaixada: "voce
## conseguiria fazer... como esse vermelho que tracei" (um hexagono do
## TAMANHO do proprio tile, acompanhando a quebra agua/terra, nao um
## menor abraçando so o cluster de predios do centro). Antes a muralha
## usava um raio LOCAL fixo (0.62) sem nenhuma relacao com o tile de
## verdade — 1.0 aqui e so o fallback pro default de HexGrid.hex_size,
## usado por testes que criam City.new() bare sem passar por setup().
var tile_radius: float = 1.0
var population: int = 1
## Nunca ultrapassa food_storage_cap() (ver process_turn(), que ja aplica o
## clamp todo turno) — o "excedente" de um turno com producao muito alta
## simplesmente e descartado ao cruzar o teto, nao acumula pro proximo
## ciclo.
var stored_food: float = 0.0
var stored_production: float = 0.0
## Ver comentario de CITY_BASE_MAX_HP acima — inicializados em setup()
## (hp cheio, shield 0 ate Muralhas ser construida).
var hp: float = 0.0
var shield: float = 0.0
## Ver SIEGE_TURNS_TO_SUSPEND_REGEN acima — quantos turnos SEGUIDOS ate
## agora tem unidade inimiga adjacente; zera assim que ninguem ameacador
## fica adjacente por um turno.
var _consecutive_siege_turns: int = 0
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
## "settler"/repetir o mesmo item pra sempre sozinha. RivalAI.decide_
## production ja rechama set_production() TODO turno pra IA rival
## (inclusive na fundacao, ver GameManager._on_turn_changed chamando
## decide_production ANTES de process_turn), entao ela nunca fica ociosa
## de verdade — isso so afeta cidades sem ninguem escolhendo pra elas
## todo turno, ou seja, so a do jogador humano.
var production_item: String = ""

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

func max_hp() -> float:
	return CITY_BASE_MAX_HP + population * CITY_MAX_HP_PER_POPULATION

## Teto de armazenamento de comida desta cidade — FOOD_STORAGE_BASE por
## padrao, aumentado pelo Celeiro uma vez construido (BuildingData.
## storage_bonus, ver BuildingDatabase.total_bonus()). Cidade cresce 1
## populacao quando stored_food atinge este teto (ver process_turn()).
func food_storage_cap() -> float:
	return FOOD_STORAGE_BASE + BuildingDatabase.total_bonus(buildings).storage

## 0.0 ate o predio "walls" ser construido (ver BuildingDatabase.gd/
## City._add_walls) — sem Muralhas, a cidade nao tem escudo nenhum pra
## absorver.
func max_shield() -> float:
	return CITY_MAX_SHIELD if buildings.has("walls") else 0.0

## Roadmap de gameplay Fase 4A — pedido do usuario: "Mercado ganha um
## segundo efeito real: aumenta o numero maximo de rotas simultaneas que
## uma cidade aguenta" (primeira vez que "Mercado" faz algo parecido com
## o proprio nome — antes so descontava rush-buy). Ver TradeManager.
## active_route_count/propose_route.
const MARKET_ROUTE_CAPACITY_BONUS := 2
## `hex_grid` OPCIONAL (Roadmap 2.0 Parte 1, B1) — so quando fornecido soma
## o bonus de Seda (ResourceDatabase.extra_trade_route_capacity), mesma
## convencao de parametro opcional de production_cost/rush_buy_cost abaixo.
func max_trade_routes(hex_grid: HexGrid = null) -> int:
	var base = MARKET_ROUTE_CAPACITY_BONUS if buildings.has("market") else 0
	if hex_grid == null:
		return base
	return base + ResourceDatabase.extra_trade_route_capacity(self, hex_grid)

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
## que reflete "nada em producao".
## `hex_grid` OPCIONAL (roadmap de gameplay Fase 3) — so quando fornecido
## aplica o desconto de Cavalos em Cavalaria (ver ResourceDatabase.
## cavalry_cost_multiplier); todo chamador que nao passa (rush-buy,
## HUD, debug) continua vendo o custo BASE, sem discrepancia funcional —
## so o momento em que a producao de fato COMPLETA (process_turn, unico
## chamador que ja tinha hex_grid em maos) usa o desconto de verdade.
func production_cost(hex_grid: HexGrid = null) -> float:
	if production_item == "":
		return 0.0
	var building: BuildingData = BuildingDatabase.get_building(production_item)
	if building:
		return building.production_cost
	var cost: float = UnitDatabase.create_unit(production_item).production_cost
	if hex_grid and owner_player:
		if production_item == "cavalry":
			cost *= ResourceDatabase.cavalry_cost_multiplier(owner_player, hex_grid)
		elif production_item in ResourceDatabase.IRON_DISCOUNT_KINDS:
			cost *= ResourceDatabase.heavy_unit_cost_multiplier(owner_player, hex_grid)
	return cost

## Quanto falta pra completar o item atual (nunca negativo) — usado tanto
## pelo rush-buy abaixo quanto poderia ser reusado por qualquer outro
## calculo futuro de "quanto falta".
func _production_remaining() -> float:
	return max(production_cost() - stored_production, 0.0)

## Mercado permite "comprar" o resto da producao do item atual com ouro em
## vez de esperar os turnos normais — pedido do usuario: "o mercado pode
## servir pra aumentar a produção"/"é uma boa, faça isso" (rush-buy com
## ouro). So disponivel com o predio "market" ja construido NESTA cidade
## (efeito local, mesmo padrao de gate por predio de BuildingDatabase.
## building_that_trains/can_train), so quando ha algo de fato em producao
## (cidade OCIOSA nao tem o que comprar) e so quando ainda falta alguma
## coisa (senao o botao apareceria pra comprar um item que ja completaria
## sozinho neste mesmo turno).
func can_rush_buy() -> bool:
	return buildings.has("market") and production_item != "" and _production_remaining() > 0.0

## Custo em ouro pra completar o restante da producao AGORA — proporcional
## so ao que FALTA (production_cost() - stored_production), nao ao custo
## total, senao comprar um item quase pronto custaria o mesmo que comprar
## do zero. 0.0 quando can_rush_buy() e false (nada pra comprar).
## `hex_grid` OPCIONAL (Roadmap 2.0 Parte 1, B1) — so quando fornecido
## aplica o desconto de Gemas (ResourceDatabase.rush_buy_cost_multiplier),
## mesma convencao de production_cost acima.
func rush_buy_cost(hex_grid: HexGrid = null) -> float:
	if not can_rush_buy():
		return 0.0
	var cost = _production_remaining() * RUSH_BUY_GOLD_PER_PRODUCTION
	if hex_grid and owner_player:
		cost *= ResourceDatabase.rush_buy_cost_multiplier(owner_player, hex_grid)
	return cost

## Completa o item atual instantaneamente gastando ouro do dono da cidade —
## so seta stored_production pro custo total; a conclusao de fato (spawnar
## unidade/marcar predio construido/voltar a ficar OCIOSA, ver
## process_turn()) acontece no PROXIMO turno, reaproveitando a MESMA logica
## de conclusao de sempre em vez de duplicar aqui (evita ter dois lugares
## decidindo "o que acontece quando um item termina"). Devolve false sem
## gastar nada se o rush-buy nao estiver disponivel ou faltar ouro.
func rush_buy(hex_grid: HexGrid = null) -> bool:
	if not can_rush_buy():
		return false
	var cost := rush_buy_cost(hex_grid)
	if owner_player == null or owner_player.gold < cost:
		return false
	owner_player.gold -= cost
	stored_production = production_cost()
	return true

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
	if not _prerequisite_building_present(building_id):
		return false
	return _tech_unlocked_for_building(building_id)

## Alguns predios exigem OUTRO predio ja construido nesta mesma cidade
## antes (BuildingData.requires_building, ex: Estabulo exige o Quartel) —
## pedido do usuario: "faca o estabulo ser uma coisa que so pode ser feita
## depois do quartel". Independente do gate de TECNOLOGIA logo abaixo (os
## dois se combinam pro Estabulo: Quartel construido E tech "Estabulo"
## pesquisada).
func _prerequisite_building_present(building_id: String) -> bool:
	var building: BuildingData = BuildingDatabase.get_building(building_id)
	if building == null or building.requires_building == "":
		return true
	return buildings.has(building.requires_building)

## Predio de TREINO so fica disponivel pra construir depois de pesquisar a
## mesma tecnologia que desbloqueia a tropa correspondente
## (TechDatabase.tech_that_unlocks(building.trains_unit)) — pedido do
## usuario: "so posso construir esses predios especiais quando pesquisar a
## tecnologia, ai aparece disponivel pra construir". Predios de PRODUCAO
## sem tech (so Torre dos Sabios) nao tem tecnologia associada
## (tech_that_unlocks devolve null E tech_that_unlocks_building tambem),
## fica sempre liberada por essa checagem, so sujeita ao limite de slots.
## Quartel, Estabulo, Campo de Tiro, Muralhas, Celeiro, Oficina e Mercado TEM
## tecnologia associada cada um (respectivamente "Quartel"/"Estabulo"/
## "Arquearia"/"Muralhas", ver TechDatabase) — Homem de Armas so treina
## depois da primeira, Cavaleiro (comum)/Cavaleiro Real/Batedor so depois
## da segunda (Batedor ainda exige a PROPRIA tech "Batedor Montado" por
## cima — gate SEPARADO, checado por has_unlocked()/is_unit_unlocked() na
## HUD, nao aqui, ver comentario de TechData.unlocks_unit), Arqueiro so
## depois da terceira, Muralhas so depois da quarta (essa via unlocks_
## building, nao unlocks_unit — Muralhas nao treina tropa nenhuma). Celeiro,
## Oficina e Mercado tambem passam por unlocks_building (techs "celeiro"/
## "oficina"/"mercado", ver TechDatabase) — deixaram de ser sempre
## liberados junto com o resto da familia RENDIMENTO (so Torre dos Sabios
## continua sem tech nenhuma). Guarda nao depende de nenhum predio (ver
## BuildingDatabase.building_that_trains), entao nunca passa por aqui.
func _tech_unlocked_for_building(building_id: String) -> bool:
	var building: BuildingData = BuildingDatabase.get_building(building_id)
	if building == null:
		return true
	var tech: TechData = TechDatabase.tech_that_unlocks(building.trains_unit)
	if tech == null:
		# Predio SEM trains_unit (familia rendimento/defesa) pode MESMO
		# ASSIM ter tech propria (ex: Muralhas, ver TechData.
		# unlocks_building) — so nao passa pelo gate de trains_unit acima.
		tech = TechDatabase.tech_that_unlocks_building(building_id)
	if tech == null:
		return true
	return owner_player != null and owner_player.researched_techs.has(tech.id)

## Cada tropa de combate so pode ser produzida se a cidade ja tiver o
## predio de treino correspondente construido (BuildingDatabase.
## building_that_trains) — Colonizador e Guarda nao tem predio associado,
## entao ficam sempre liberados. Como can_build() ja exige a tecnologia
## certa pra CONSTRUIR o predio, uma tropa so fica trainable depois da cadeia
## completa: pesquisar -> construir -> treinar. Chamado tanto por
## HUD._on_produce_pressed (jogador) quanto por RivalAI.decide_production
## (rival, desde o roadmap de gameplay Fase 1 — antes disso a IA rival
## pulava can_build()/can_train() inteiramente via set_production() direto,
## nunca construindo predio nenhum mas ainda assim treinando tropa
## avancada de graca; ver RivalAI.gd).
##
## Tropa racial exclusiva (UnitDatabase.RACE_UNIQUE_KIND) tem uma segunda
## trava, ANTES da checagem de predio: so a raca DONA da tropa pode
## treinar ela (pedido do usuario: escolher raca na tela de titulo precisa
## ter uma implicacao real) — um jogador Anao nunca deveria conseguir
## treinar o Arqueiro Solar so por ter o Quartel construido.
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
	# Ver RaceEconomy.apply_yield_bonus — anao precisa saber se algum tile
	# TRABALHADO e Colina ou tem o recurso Ferro; calculado nesta mesma
	# volta pra nao precisar de uma segunda varredura so pra isso.
	var worked_has_hills := false
	var worked_has_iron := false
	for c in coords:
		if hex_grid.is_tile_pillaged(c, TurnManager.turn_number):
			continue
		var data: HexTileData = hex_grid.get_tile(c)
		if data == null:
			continue
		if data.terrain_type in RaceEconomy.HILLS_TERRAIN_TYPES:
			worked_has_hills = true
		if data.resource == "iron":
			worked_has_iron = true
		var y = effective_tile_yield(data)
		if c == coord:
			y.production = max(y.production, CITY_CENTER_MIN_PRODUCTION)
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
	# Identidade economica racial (roadmap de gameplay Fase 3) — MESMO
	# lugar que o multiplicador de dificuldade acima, so um segundo
	# multiplicador independente por cima.
	var race: String = owner_player.civ.race if (owner_player and owner_player.civ) else ""
	RaceEconomy.apply_yield_bonus(totals, race, worked_has_hills, worked_has_iron)
	return totals

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
	var yields = collect_yields(hex_grid)
	stored_production += yields.production

	# Consumo por populacao (pedido do usuario): cada habitante come
	# FOOD_CONSUMPTION_PER_POP por turno, descontado da producao de comida
	# do turno ANTES de somar ao estoque. clamp(..., 0.0, cap) cobre os dois
	# lados: deficit so trava o estoque em 0 (nunca fica negativo, nunca
	# reduz populacao), e excedente alem do teto e descartado (nunca
	# acumula pro proximo ciclo) — o "cheio" do teto e o proprio gatilho de
	# crescimento logo abaixo.
	# Identidade racial orc (roadmap Fase 3, ver RaceEconomy.
	# growth_multiplier_for): teto MENOR enche mais rapido com o MESMO
	# yield de comida — "cresce mais rapido" sem mexer no yield de comida
	# em si (esse ja ganhou o bonus generico do humano acima, se for o caso).
	var race: String = owner_player.civ.race if (owner_player and owner_player.civ) else ""
	var cap = food_storage_cap() / RaceEconomy.growth_multiplier_for(race)
	var consumption = population * FOOD_CONSUMPTION_PER_POP
	stored_food = clamp(stored_food + yields.food - consumption, 0.0, cap)
	if stored_food >= cap:
		stored_food -= cap
		population += 1
		auto_assign_worked_tiles(hex_grid)
		_claim_frontier_tile(hex_grid) # territorio (owned_tiles) cresce junto com a populacao
		_refresh_label()
		_build_visual_procedural()

	var spawned_kind := ""
	var built_kind := ""
	var built_coord := NO_PENDING_COORD
	# production_item == "" (cidade OCIOSA, ver comentario da variavel e
	# set_production()) nunca completa nada sozinha — pedido do usuario:
	# "a partir do momento que voce funda a cidade, ele fica produzindo
	# sem parar unidades... eu quero que... quando ela acabar, so produza
	# outra se voce for la e por pra produzir de novo". Guarda aqui (em
	# vez de so confiar em production_cost() devolver 0.0 pra "") pra
	# nao chamar UnitDatabase.create_unit("") a toa todo turno.
	if production_item != "":
		var cost = production_cost(hex_grid)
		if stored_production >= cost:
			stored_production -= cost
			var building: BuildingData = BuildingDatabase.get_building(production_item)
			if building:
				buildings[production_item] = true
				built_kind = production_item
				if building.self_placed:
					# Muralhas: sem modelo 3D separado pra hex_grid.
					# place_building desenhar (ver comentario de self_placed em
					# BuildingData.gd) — o efeito e o anel de muralha da PROPRIA
					# cidade (_add_walls), que so seria redesenhado no PROXIMO
					# crescimento de populacao. Forca agora, senao o jogador nao
					# veria efeito nenhum da producao que acabou de terminar ate
					# a cidade crescer de novo.
					_build_visual_procedural()
					# Escudo comeca CHEIO assim que a muralha fica pronta — o
					# jogador acabou de terminar a obra, nao faz sentido ela
					# comecar vazia e so encher aos poucos (ver CITY_MAX_SHIELD/
					# max_shield()).
					shield = max_shield()
				# pending_building_coord so fica vazio se algo chamou
				# set_production() direto (ex: testes) sem passar pelo fluxo de
				# posicionamento — o predio ainda conta pro bonus/limite, so
				# nao ganha modelo 3D no mapa.
				if pending_building_coord != NO_PENDING_COORD:
					building_coords[production_item] = pending_building_coord
					built_coord = pending_building_coord
				pending_building_coord = NO_PENDING_COORD
				# Fica OCIOSA apos completar — pedido do usuario (ver
				# comentario acima). ANTES caia de volta pra "settler" e
				# ficava reconstruindo Colonizador pra sempre sozinha;
				# agora o jogador escolhe o proximo item explicitamente
				# (RivalAI.decide_production ja rechama set_production
				# TODO turno de qualquer forma, independente disso).
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
	# Tambem cobre o caso de max_hp() ter mudado so por causa do
	# crescimento de populacao acima (fracao mostrada muda mesmo sem hp
	# mudar).
	_update_life_bars()

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

## Roadmap 2.0 Parte 1 (A1) — bonus fixo pra qualquer tile com recurso
## estrategico, somado em cima da formula de yield de sempre (ver
## _tile_claim_score). Sem isso um Nodulo Arcano pontuava 0 (nao rende
## comida/producao/ouro, so mana) e nunca era mais atraente que um tile
## barrento qualquer — o bonus da a QUALQUER recurso o mesmo empurrao,
## independente do yield bruto dele. Tamanho nao ajustado por medicao ainda
## (ver harness de simulacao, test_simulation_balance.gd — Fase 0 do roadmap
## ja tem esse padrao de "medir antes de recalibrar").
const FRONTIER_RESOURCE_SCORE_BONUS := 4.0

## Formula de pontuacao de rendimento compartilhada por _best_unassigned_
## neighbor (trabalho) e _claim_frontier_tile (posse) abaixo — ver
## comentario de _claim_frontier_tile pra por que as duas precisam ficar em
## sincronia.
func _tile_claim_score(data: HexTileData) -> float:
	var y = effective_tile_yield(data)
	var score = y.food * 1.5 + y.production * 1.3 + y.gold
	if data.resource != "":
		score += FRONTIER_RESOURCE_SCORE_BONUS
	return score

func _best_unassigned_neighbor(hex_grid: HexGrid):
	var best_coord = null
	var best_score = -INF
	for n in hex_grid.get_neighbors(coord):
		if n in worked_tiles or hex_grid.is_tile_worked(n, self):
			continue
		var data: HexTileData = hex_grid.get_tile(n)
		if data == null or not data.can_be_worked():
			continue
		var score = _tile_claim_score(data)
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
		var score = _tile_claim_score(data)
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

## Chamado sempre que hp/shield/population/buildings muda (combate, regen
## por turno, crescimento de populacao — que muda max_hp() mesmo sem hp
## mudar — e conclusao de Muralhas) — so redesenha a TEXTURA, nunca mexe
## em tamanho/posicao (mesmo motivo da barra de progresso de construcao,
## ver HexGrid._update_construction_marker_progress).
func _update_life_bars() -> void:
	if _life_bar == null:
		return
	var hp_frac = clamp(hp / max_hp(), 0.0, 1.0) if max_hp() > 0.0 else 1.0
	_life_bar.texture = _build_life_bar_texture(hp_frac, _life_bar_fill_color(hp_frac), LIFE_BAR_EMPTY_COLOR)

	var has_shield = buildings.has("walls")
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
	else:
		_add_small_keep(civ_color)
	# Anel de muralha: ANTES acionado so por populacao (junto com is_city
	# acima) — pedido do usuario: "a muralha [predio] nao faz tanto
	# sentido... adiciona como pesquisa... essa muralha simplesmente
	# adiciona esteticamente uma muralha ao redor do tile da cidade...
	# dando um shield a ela". Agora reflete se a cidade de fato CONSTRUIU
	# o predio "walls" (gated pela tech "muralhas", ver BuildingDatabase.
	# gd) — independente de populacao, uma aldeia pequena murada e tao
	# valida quanto uma cidade grande sem muralha nenhuma.
	if buildings.has("walls"):
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
		_name_label.text = "%s (%d)" % [city_name, population]

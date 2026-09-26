class_name DragonEvent
extends WorldEvent

## Fase 5B.3-D do roadmap (Fase Macro, "O Mundo Esta Vivo") -- evolucao do
## comportamento em Active depois do primeiro playtest visual de 5B.3-B/C:
## o Dragao virou uma entidade fisica real (5B.3-A), com movimento/combate/
## raid basico (5B.3-B) e UX de evento (5B.3-C), mas o playtest revelou 3
## problemas concretos, todos resolvidos aqui SEM introduzir uma IA de
## verdade nem um segundo sistema de combate paralelo:
##
## 1. "atravessa o mapa devagar demais" -- dois MODOS de deslocamento
##    explicitos (travel_mode): FLYING (viajando entre alvos distantes,
##    ~DRAGON_FLYING_TILES_PER_TURN tiles/turno, ignora terreno/agua) e
##    GROUND (perto do alvo atual, movimento normal ~2/turno, ver
##    MonsterDatabase.KIND_DATA["dragon"].movement_points, INALTERADO).
##    Reusa RivalAI.move_unit_toward + HexGrid.compute_reachable/flies —
##    a "viagem rapida" e' so' um movement_left MAIOR nesse tick, nunca um
##    pathfinding novo nem um loop de N movimentos com combate entre cada.
## 2. "parece uma pedra parada batendo em uma unidade por turno" -- dano em
##    area (CombatResolver.resolve_with_splash, reusa resolve()/predict()
##    de verdade) + um limite pequeno de turnos de combate no MESMO lugar
##    antes de reposicionar (GROUND_COMBAT_STREAK_LIMIT) + escolha de alvo
##    agora EXCLUI a ultima cidade raidada quando existe alternativa
##    (last_raided_city_coord) -- cidade A -> B -> eventualmente A de novo.
## 3. "o Dragao as vezes simplesmente sumia, sem mensagem nenhuma" -- os 4
##    pontos que decidem o `result`/entram em Resolution agora SEMPRE
##    emitem um toast CLARAMENTE distinguivel por desfecho (_resolve_with_
##    outcome) -- o problema nao era o FSM (ja transicionava certo pra
##    Resolution/Completed), era a AUSENCIA de qualquer aviso alem do texto
##    de 1-tick do Event Tracker (5B.3-C), facil de perder.
##
## IA continua deliberadamente MINIMA (mesma decisao de 5B.3-B): sem
## avaliar risco, sem fugir de combate desfavoravel. Reusa o MAXIMO
## possivel do que ja existe -- RivalAI.move_unit_toward, MonsterAI.
## _hostile_in_attack_range, CombatResolver.resolve/resolve_city_attack/
## resolve_with_splash -- nunca um "dragon_damage_city()" paralelo. A
## UNICA mudanca no combate compartilhado continua sendo o guard em
## CombatResolver.resolve_city_attack pra nunca capturar uma cidade quando
## o atacante e' neutro -- decisao explicita: raid, nunca conquista (ainda
## sem uma regra de "cidade destruida por um atacante neutro" -- lacuna
## registrada, ver comentario de resolve_city_attack, NAO inventada aqui).
##
## 5B.3-E (rodadas seguintes, apos o usuario reportar "desaparece" mais
## duas vezes): relink_unit() usava spawn_coord (congelado no nascimento,
## nunca atualizado) pra reencontrar a Unit apos um save/load -- corrigido
## com last_unit_coord (ver relink_unit/to_save_dict). HexGrid.
## _maybe_roam_lair tambem teleportava a Unit sem checar world_event_
## managed. WorldEventTrigger.choose_dragon_origin_region passou a
## preferir a zona Principal (evita nascer num continente especial
## distante).
##
## 5B.3-F (achado por reproducao INSTRUMENTADA de um playtest real, apos o
## usuario reportar "destroi uma cidade e some" mais uma vez): um rival em
## guerra de verdade PRODUZ reforcos sem parar -- o break-off antigo do
## item 2 (so' um vizinho) so' trocava o Dragao pro PROXIMO defensor da
## MESMA fileira, entao ele ficava preso lutando contra um exercito inteiro
## por dezenas de turnos seguidos (raids_done travado, HP/posicao
## praticamente parados) sem NUNCA voltar a raidar -- o evento continuava
## tecnicamente Active o tempo todo, mas indistinguivel de "sumiu" pro
## jogador. Fix: _break_off_toward substitui _reposition_nearby como
## caminho PRINCIPAL -- um salto GRANDE (orcamento de FLYING) em direcao a
## cidade-alvo, nao um vizinho, dando uma chance real de ULTRAPASSAR o
## aglomerado de defensores. _reposition_nearby vira fallback so' pro caso
## sem cidade-alvo nenhuma.
##
## 5B.3-G (pedido explicito do usuario apos o playtest de ponta a ponta: "o
## Dragao e' uma AMEACA CONTINENTAL", nao um bicho que visita 1-2 cidades e
## some): DEVASTATION_RAID_LIMIT (3 raids TOTAIS, sem ligacao nenhuma com
## quantas civs foram tocadas) deixa de ser a condicao de termino -- vira
## CIV_VISIT_TARGET (civ_visits, ver campo abaixo): toda civ VIVA precisa
## ser raidada de verdade ~2 vezes antes do Dragao poder "fugir saciado"
## (outcome ainda chamado "devastated", ver secao 14 do pedido -- o proprio
## usuario autorizou consolidar em vez de criar um outcome novo). Isso
## TAMBEM revisa Blocker #3 de novo (ver docs/DRAGON_EVENT_DESIGN.md): a
## ordem de visita deixa de ser "civ anunciada sempre primeiro" (pedido
## explicito: "a ordem NAO deve ser fixa") -- _choose_target_city agora
## prioriza civs com MENOS visitas (pressao de cobertura), desempatando por
## distancia, nunca so' "cidade mais proxima" cru. Alem disso, a IA rival
## ganha uma reacao militar minima ao evento (RivalAI.defend_against_dragon,
## reusando move_unit_toward/CombatResolver.resolve existentes -- NADA de
## arvore de IA nova; a producao fica com o planejamento V2) e
## o desfecho do evento (defeated/devastated/no_target) passa a ser
## comunicado por MODAL bloqueante (HUD._on_world_event_phase_changed),
## nunca mais o toast pequeno de _resolve_with_outcome (removido -- UX era
## o problema real, o FSM ja transicionava certo).

const EVENT_TYPE := "dragon"

## Sentinela Vector2i (mesmo padrao ja usado por City.NO_PENDING_COORD/
## PlayerData.NO_RITUAL_CITY_COORD) -- nunca confundir "ainda nao
## escolhido" com uma coordenada real (0,0).
const NO_COORD := Vector2i(999999, 999999)

## PROVISORIO/NAO CALIBRADO (mesma disciplina de WorldEventTrigger.
## DRAGON_TRIGGER_MIN_TURN/CHANCE_PER_TURN) -- so o suficiente pra existir
## um prazo real de decisao. Calibrar depois do primeiro playtest, nunca
## adivinhar agora.
const PREPARATION_DURATION_TURNS := 3

## Quantos "aneis" de vizinhos a busca por um tile de spawn valido tenta
## antes de desistir e cair de volta em origin_region mesmo assim (caso
## degenerado, raro) -- regra MINIMA proposital (contrato: "nao precisamos
## decidir hoje uma formula perfeita de qual e' o melhor tile").
const SPAWN_SEARCH_MAX_RINGS := 6

## Regiao aproximada de origem -- conhecida desde a criacao (preenchida por
## WorldEventTrigger.choose_dragon_origin_region no momento do spawn),
## publica desde Announced. NOTA pra 5B.3: hoje isto e' semanticamente uma
## COORDENADA REPRESENTATIVA da regiao (um tile), nao uma regiao/area de
## verdade -- suficiente pra "regiao aproximada, nunca o tile exato" por
## enquanto, mas se precisarmos de regiao como area/cluster de verdade
## depois, o campo pode precisar evoluir (ex.: origin_region_coord +
## definicao explicita de raio/area), sem quebrar o principio "so a
## origem, nunca o spawn exato". NUNCA o tile exato de spawn -- ver spawn_coord
## abaixo e docs/DRAGON_EVENT_DESIGN.md, "cadeia de origem/spawn".
var origin_region: Vector2i = NO_COORD

## Tile EXATO de spawn da Unit do Dragao -- permanece NO_COORD durante
## Dormant/Announced/Preparation de proposito (contrato: "o tile exato so
## e sorteado na transicao pra Active"), sorteado deterministicamente
## (event_rng -- event_id ja existe neste ponto, diferente do trigger) na
## transicao Preparation->Active.
var spawn_coord: Vector2i = NO_COORD

## civ_index (posicao em GameManager.players, mesma convencao do contrato)
## da civilizacao ANUNCIADA -- travado na transicao Announced->Preparation
## (docs/DRAGON_EVENT_DESIGN.md, Blocker #3). -1 = ainda nao travado.
## Formula PROVISORIA (civ com a cidade mais proxima de origin_region).
##
## 5B.3-G, "cobertura continental": Blocker #3 revisado DE NOVO -- este
## campo NAO influencia mais qual cidade e' raidada primeiro nem em que
## ordem (_choose_target_city ignora completamente target_civ_index,
## priorizando so' a civ viva com MENOS visitas). Sobrevive apenas como a
## civ NOMEADA no aviso de Preparation (_notify_preparation_started) e como
## sinal de "esta civ ja sabe da ameaca" (is_civ_threatened) -- nunca mais
## uma garantia de ordem de ataque.
var target_civ_index: int = -1

## A Unit FISICA do Dragao -- NUNCA persistida diretamente (e' um Node, nao
## dado puro). spawn_coord (esse sim persistido) e' o suficiente pra
## reencontrar a MESMA Unit que o save generico de monstros neutros
## (HexGrid.neutral_units/SaveManager) ja reconstroi sozinho -- ver
## relink_unit() abaixo, chamado pelo SaveManager depois do load.
## owner_player desta Unit e' SEMPRE null (HexGrid.spawn_monster_at ja
## garante isso) -- nunca conta como unidade de civilizacao nenhuma
## (player.units, upkeep de guerra, contagem de Dominacao, producao) por
## construcao, nao por um cuidado especial aqui.
var dragon_unit: Unit = null

## PROVISORIO/NAO CALIBRADO -- quantas visitas/raids bem-sucedidos contra
## uma MESMA civ ate ela ser considerada "coberta" pela marcha continental
## do Dragao (ver civ_visits abaixo). Substitui DEVASTATION_RAID_LIMIT
## (5B.3-G, "o Dragao e' uma ameaca continental" -- 3 raids TOTAIS sem
## relacao com quantas civs foram tocadas nao representava isso). Numero
## exato e' tuning, nao design -- nao calibrar ainda (pedido explicito).
const CIV_VISIT_TARGET := 2

## Quantos raids bem-sucedidos ja aconteceram nesta incursao, no TOTAL
## (informativo -- nao e' mais a condicao de termino, ver civ_visits/
## CIV_VISIT_TARGET) -- persistido (ver to_save_dict) pra sobreviver a um
## save/load em pleno Active.
var raids_done: int = 0

## civ_index (mesma convencao de target_civ_index, posicao em GameManager.
## players) -> quantos raids bem-sucedidos essa civ ja recebeu. Chave so'
## existe depois do 1o raid contra aquela civ (civ_visits.get(i, 0) == 0
## pra qualquer civ ainda nao tocada). Persistido como Dictionary de
## CHAVES STRING (ver to_save_dict/from_save_dict) -- SaveManager serializa
## em JSON, que so' tem chave string; reconstruido de volta pra chave int
## no load, senao civ_visits.get(int_index, 0) nunca bateria com uma chave
## string sobrevivente do save (mesmo bug que participants.gd corre o
## risco de ja ter, nao introduzido aqui). Cobertura continental (5B.3-G):
## enquanto existir civ viva com civ_visits < CIV_VISIT_TARGET, essas civs
## tem prioridade de escolha de alvo (ver _choose_target_city);
## _all_living_civs_covered() decide quando o evento pode terminar por
## "devastated".
var civ_visits: Dictionary = {}

## civ_index -> dano REAL causado ao Dragao por unidades daquela civ (nunca
## escolha de alvo/movimento/tentativa -- so' dano de verdade aplicado,
## mesmo principio de civ_visits acima). Roadmap "Dragon Event v1 fechado",
## pedido explicito do usuario: "ranking de dano... transforma o Dragao numa
## atividade competitiva entre civilizacoes... isso também deixa preparado
## o terreno para o 5B.4: recompensa proporcional à contribuição" -- so' a
## CONTAGEM aqui, a recompensa em si continua fora de escopo (5B.4, nao
## implementada). Preenchido por record_damage_if_target_is_the_active_
## dragon() (abaixo), chamado dos DOIS pontos reais de combate que podem
## acertar o Dragao (RivalAI.react_to_dragon e SelectionManager.
## _attack_from_selected, unico caminho do jogador humano) -- nunca duplica
## a formula de dano em si, so' mede hp antes/depois de CombatResolver.
## resolve() ja ter rodado. Exibido no modal de resolucao (HUD).
var damage_by_civ: Dictionary = {}

## Chamado pelos dois pontos de combate reais que podem atingir o Dragao --
## generico o bastante pra nao duplicar "sera' que o defensor e' o Dragao
## de algum evento ativo" em RivalAI/SelectionManager (nenhum dos dois
## precisa conhecer DragonEvent alem desta chamada). No-op segura se
## `defender` nao for a Unit do Dragao de nenhum evento ativo, se o dano
## for <= 0 (ataque que nao acertou de verdade) ou se attacker_civ_index
## for invalido (unidade sem dono, ex.: outro monstro).
static func record_damage_if_target_is_the_active_dragon(defender: Unit, attacker_civ_index: int, damage: float) -> void:
	if damage <= 0.0 or attacker_civ_index < 0:
		return
	for event in WorldEventManager.active_events:
		if event is DragonEvent and (event as DragonEvent).dragon_unit == defender:
			var dragon_event := event as DragonEvent
			dragon_event.damage_by_civ[attacker_civ_index] = float(dragon_event.damage_by_civ.get(attacker_civ_index, 0.0)) + damage
			return

## Cidade que o Dragao esta perseguindo AGORA (dentro da civ travada em
## target_civ_index) -- NO_COORD quando ainda nao escolheu ou acabou de
## raidar uma e precisa escolher de novo (docs/DRAGON_EVENT_DESIGN.md:
## "depois de uma incursao, ele precisa continuar procurando outro
## destino" -- limpar isto e' o mecanismo exato disso). Guarda so a
## COORDENADA (nunca a City, mesmo principio de "coordenada, nao
## referencia" ja usado em todo o resto do save).
var current_target_city_coord: Vector2i = NO_COORD

## Ultima cidade raidada com sucesso -- usada so' pra EXCLUIR ela da
## proxima escolha de alvo quando existir alternativa (ver
## _choose_target_city), pra nao ficar eternamente na mesma cidade tendo
## outras disponiveis (item 7 do pedido do usuario). Nunca uma lista/
## historico de verdade, so' a mais recente -- a cidade anterior volta a
## ficar elegivel assim que outra for raidada por sua vez (A -> B -> A).
## Persistido (precisa sobreviver a save/load pra continuar valendo).
var last_raided_city_coord: Vector2i = NO_COORD

## Dois modos EXPLICITOS de deslocamento (pedido do usuario, item 1) --
## recalculado TODO tick em _take_dragon_turn a partir da distancia atual
## ate o alvo (nunca persistido: e' inteiramente derivado do estado real,
## igual current_target_city_coord ja e' recomputado sempre que necessario
## -- ver nota de persistencia em to_save_dict()). Sem diferenca visual
## ainda (pedido explicito do usuario: "não precisa implementar animação
## visual de voo agora"), mas o campo fica pronto pra Unit.gd usar no
## futuro (ex.: trocar a pose/anim conforme o modo).
const TRAVEL_MODE_FLYING := "flying"
const TRAVEL_MODE_GROUND := "ground"
var travel_mode: String = TRAVEL_MODE_FLYING

## PROVISORIO/NAO CALIBRADO -- quantos tiles o Dragao cobre por turno
## voando (bem mais que os ~2/turno normais de MonsterDatabase, de
## proposito: "não quero que o jogador precise esperar dezenas de turnos
## pro Dragao atravessar o mapa"). Implementado como um movement_left
## MAIOR so' nesse tick (ver _take_dragon_turn) -- reset_movement() (rodado
## uma vez por turno pra TODO neutro, GameManager._on_turn_changed) volta
## ao normal sozinho no proximo turno, entao nao precisa nenhum
## "desconto"/contador extra aqui. Reduzido de 10 pra 6 apos o playtest de
## 5B.3-D (pedido explicito do usuario: "ficou rápido demais"); devolvido
## de 6 pra 10 no roadmap 5B.3-G v2 (pedido explicito do usuario, junto com
## a IA rival finalmente conseguindo interceptar de verdade) -- ainda
## PROVISORIO/NAO CALIBRADO, so' um ajuste de sentido, nao um numero final.
const DRAGON_FLYING_TILES_PER_TURN := 10

## PROVISORIO/NAO CALIBRADO -- distancia (em tiles) ate o alvo atual a
## partir da qual o Dragao troca de FLYING pra GROUND (comeca a poder
## circular/procurar inimigos/raidar em vez de so' avancar rapido).
const DRAGON_GROUND_ENGAGE_RANGE := 3

## PROVISORIO/NAO CALIBRADO -- raio (tiles) ao redor do alvo PRIMARIO que
## tambem recebe dano quando o Dragao combate uma unidade (item 4, "dano
## em area"). Ver CombatResolver.resolve_with_splash -- reusa predict() de
## verdade, nunca uma formula nova.
const DRAGON_SPLASH_RADIUS := 1
## PROVISORIO/NAO CALIBRADO -- fracao do dano do alvo primario aplicada a
## cada alvo secundario (pedido do usuario: "aproximadamente 30-50%").
const DRAGON_SPLASH_DAMAGE_FRACTION := 0.4

## PROVISORIO/NAO CALIBRADO -- depois de combater N turnos SEGUIDOS sem o
## Dragao nunca ter se movido (mesmo alvo continua no alcance de ataque
## todo tick), ele quebra o engajamento e se reposiciona pra um vizinho
## valido em vez de continuar preso no mesmo lugar indefinidamente (item
## 3: "não fica parado permanentemente batendo em uma unidade por turno").
## Decisao explicita do usuario: evitar isso SEM uma arvore de decisao de
## verdade. NAO persistido (perder a contagem num save/load e' uma perda
## cosmetica minima, nunca uma quebra de estado) -- zera sozinho sempre
## que o Dragao NAO estiver em combate no tick (raid/viagem/reposicionar).
const GROUND_COMBAT_STREAK_LIMIT := 3
var _combat_streak: int = 0

## PROVISORIO/NAO CALIBRADO -- pedido explicito do usuario apos o
## playtest: "ele não deveria destruir a cidade, só causar dano... não
## fazer a vida da cidade chegar a 0 na primeira passada". Antes, um raid
## contra uma cidade jovem/fraca podia levar o HP direto perto de zero
## numa UNICA passada (o guard de "nunca captura" ja evitava o pior --
## nunca mudava de dono -- mas o SUSTO de "quase morreu" num so' golpe
## nao era o efeito pretendido: "dar alguns golpes e causar dano", nao
## nocautear de uma vez). CombatResolver.resolve_city_attack agora aceita
## limitar o dano de UM raid a esta fracao do HP ATUAL da cidade --
## jogador/rival continuam SEM capa nenhuma (parametro default da
## funcao), so' o raid do Dragao usa isto.
const DRAGON_RAID_DAMAGE_FRACTION := 0.35

func _init() -> void:
	event_type = EVENT_TYPE

## Announced/Preparation (5B.2), nascimento fisico (5B.3-A) e agora
## movimento/combate/raid (5B.3-B) tem comportamento real. Resolution
## ainda so fecha o ciclo (remove a Unit) -- desfecho detalhado
## (recompensas, consequencias persistentes) e' 5B.4.
func advance_turn(hex_grid: HexGrid, players: Array[PlayerData]) -> void:
	match phase:
		WorldEvent.PHASE_DORMANT:
			phase = WorldEvent.PHASE_ANNOUNCED
			EventBus.notify.emit("Rumores do Oeste: mercadores e aldeões relatam uma criatura colossal cruzando os céus durante a noite. Ainda não há confirmação, mas os relatos são numerosos demais para serem ignorados.", "")
		WorldEvent.PHASE_ANNOUNCED:
			# Alvo travado AQUI, nunca depois (Blocker #3) -- formula
			# provisoria: civ com a cidade mais proxima da regiao.
			target_civ_index = _find_nearest_civ_index(players)
			turn_deadline = TurnManager.turn_number + PREPARATION_DURATION_TURNS
			phase = WorldEvent.PHASE_PREPARATION
			_notify_preparation_started(players)
		WorldEvent.PHASE_PREPARATION:
			# turn_deadline e' o ULTIMO turno em que uma decisao ainda pode
			# ser registrada (Blocker #2) -- so avanca no processamento do
			# turno SEGUINTE ao prazo.
			if TurnManager.turn_number > turn_deadline:
				spawn_coord = _choose_spawn_coord(hex_grid)
				dragon_unit = hex_grid.spawn_monster_at(spawn_coord, "dragon")
				_mark_dragon_unit(dragon_unit)
				phase = WorldEvent.PHASE_ACTIVE
				EventBus.notify.emit("O Dragão despertou! As montanhas estremecem quando a criatura surge dos céus.", "")
		WorldEvent.PHASE_ACTIVE:
			_take_dragon_turn(hex_grid, players)
		WorldEvent.PHASE_RESOLUTION:
			# Desfecho DETALHADO (recompensas, consequencias persistentes)
			# e' 5B.4 -- result.outcome ja foi decidido em _take_dragon_turn/
			# _resolve_with_outcome ("defeated"/"devastated"/"no_target").
			# Aqui so fecha o ciclo: remove a Unit do mapa se ainda estiver
			# viva (se morreu em combate, CombatResolver.resolve ja chamou
			# hex_grid.remove_unit sozinho -- _remove_dragon_unit e' segura
			# contra dupla remocao).
			_remove_dragon_unit(hex_grid)
			phase = WorldEvent.PHASE_COMPLETED
	if phase in [WorldEvent.PHASE_RESOLUTION, WorldEvent.PHASE_COMPLETED]:
		award_contribution_rewards(players)

## Prêmio proporcional à contribuição dos participantes; persistido no resultado.
func award_contribution_rewards(players: Array[PlayerData]) -> void:
	if result.get("rewards_applied", false):
		return
	result["rewards_applied"] = true
	result["rewards"] = {}
	if result.get("outcome", "") != "defeated":
		return
	var total := 0.0
	for index in damage_by_civ:
		if index >= 0 and index < players.size() and participants.get(index, {}).get("decision", false):
			total += maxf(0, float(damage_by_civ[index]))
	if total <= 0:
		return
	for index in damage_by_civ:
		if index < 0 or index >= players.size() or not participants.get(index, {}).get("decision", false):
			continue
		var damage := float(damage_by_civ[index])
		if damage <= 0:
			continue
		var gold := 25.0 + floorf(300.0 * damage / total)
		var mana := 10.0 + floorf(150.0 * damage / total)
		players[index].gold += gold
		players[index].mana += mana
		result.rewards[str(index)] = {"gold": gold, "mana": mana, "damage": damage}
		if players[index] == GameManager.human_player:
			EventBus.notify.emit("A Guilda reconhece sua contribuição contra o Dragão: +%d ouro e +%d mana." % [int(gold), int(mana)], "confirm")

## Um "turno" do Dragao: luta se tiver inimigo em alcance (com dano em
## area ao redor do alvo primario, ver CombatResolver.resolve_with_splash);
## senao escolhe uma cidade-alvo (dentro da civ travada) e ou raida (se em
## alcance) ou avanca em direcao a ela -- rapido (FLYING) se longe, normal
## (GROUND) se perto (ver travel_mode). IA deliberadamente MINIMA -- sem
## avaliar favorabilidade de combate (RivalAI.is_favorable_attack de
## proposito NAO usado aqui: o Dragao e' uma ameaca que nao foge).
##
## REGRA (item 8 do pedido do usuario, prioridade alta): o Dragao NUNCA
## desaparece silenciosamente -- todo caminho que poe fim ao evento passa
## por _resolve_with_outcome(), que define `result` E emite um toast
## claramente distinguivel ANTES de entrar em Resolution. Nunca escreva
## `result = {...}; phase = PHASE_RESOLUTION` direto aqui de novo.
##
## 5B.3-G, rede de seguranca GERAL contra estagnação (achado por reproducao
## de LONGA duracao apos a IA rival ganhar reacao militar/producao de
## emergencia sem teto): o combate (_combat_streak/_break_off_toward) so'
## cobre o caso de estar LUTANDO sem progresso -- mas o Dragao tambem pode
## ficar parado tentando simplesmente ANDAR (RivalAI.move_unit_toward
## bloqueado por um caminho sem saida, sem NENHUM inimigo em alcance pra
## sequer disparar o combat_streak). Um teste real de 200 turnos confirmou
## esse segundo caso: posicao E raids_done identicos por 194 turnos
## seguidos, exercito rival crescendo sem parar, e nenhum dos fallbacks
## especificos de combate era sequer chamado. Esta funcao virou um wrapper
## fino: compara posicao/raids_done ANTES e DEPOIS de _take_dragon_turn_
## logic (unica logica de verdade, inalterada) -- se NENHUM dos dois mudou
## por DRAGON_STUCK_TURNS_ESCAPE_THRESHOLD ticks seguidos (qualquer motivo,
## combate ou movimento), forca _reposition_escaping_siege() como ultimo
## recurso. Raiding repetido na MESMA cidade (comportamento normal e
## desejado) nunca conta como "travado" porque raids_done muda a cada raid.
func _take_dragon_turn(hex_grid: HexGrid, players: Array[PlayerData]) -> void:
	var coord_before := (dragon_unit.coord if (dragon_unit != null and is_instance_valid(dragon_unit)) else NO_COORD)
	var raids_before := raids_done
	_take_dragon_turn_logic(hex_grid, players)
	if dragon_unit == null or not is_instance_valid(dragon_unit):
		_stuck_turns = 0
		return
	if dragon_unit.coord != coord_before or raids_done != raids_before:
		_stuck_turns = 0
		return
	_stuck_turns += 1
	if _stuck_turns >= DRAGON_STUCK_TURNS_ESCAPE_THRESHOLD:
		_stuck_turns = 0
		_reposition_escaping_siege(hex_grid)

## PROVISORIO/NAO CALIBRADO -- quantos ticks SEM progresso nenhum (nem
## movimento, nem raid) ate' o Dragao forcar uma fuga de emergencia (ver
## comentario de _take_dragon_turn acima). Maior que GROUND_COMBAT_STREAK_
## LIMIT (3) de proposito -- da pelo menos uma chance real do proprio
## fallback de combate (_break_off_toward) resolver sozinho antes de
## escalar pro ultimo recurso.
const DRAGON_STUCK_TURNS_ESCAPE_THRESHOLD := 6
var _stuck_turns: int = 0

## PROVISORIO/NAO CALIBRADO -- pedido explicito do usuario apos playtest:
## "ele foi pra uma cidade que tinha muitas tropas e ficou infinito lá, não
## saía mais... o correto é ele estabelecer uma meta... e ir embora pra
## outra cidade, se não ele vai ficar preso pra sempre". _combat_streak/
## _stuck_turns acima so' garantem que o Dragao CONSEGUE se mexer -- nao
## que ele desiste de um alvo bem defendido de verdade. Com movimento de
## sobra (FLYING) ele sempre consegue voltar a tentar a MESMA cidade,
## girando ao redor dela pra sempre sem nunca raidar de verdade. Conta
## quantos ticks SEGUIDOS o Dragao gasta perseguindo o MESMO alvo (cidade)
## sem raida-lo -- ao estourar o orcamento, abandona esse alvo (exclui via
## last_raided_city_coord, MESMO mecanismo ja usado apos um raid bem-
## sucedido -- "não escolher eternamente a mesma cidade se houver
## alternativas") e escolhe outro IMEDIATAMENTE, no mesmo tick. NUNCA conta
## como visita (civ_visits so' incrementa em raid real) -- so' torna a
## cidade temporariamente inelegivel, podendo voltar a ser escolhida depois
## se nao houver alternativa (mesma regra de exclusao de sempre).
const DRAGON_TARGET_ABANDON_THRESHOLD := 8
var _turns_engaged_at_target: int = 0
var _engagement_target_coord: Vector2i = NO_COORD

func _abandon_target_if_engagement_budget_exhausted(target_city: City, players: Array[PlayerData]) -> City:
	if target_city == null:
		_engagement_target_coord = NO_COORD
		_turns_engaged_at_target = 0
		return null
	if target_city.coord != _engagement_target_coord:
		_engagement_target_coord = target_city.coord
		_turns_engaged_at_target = 0
		return target_city
	_turns_engaged_at_target += 1
	if _turns_engaged_at_target < DRAGON_TARGET_ABANDON_THRESHOLD:
		return target_city
	_turns_engaged_at_target = 0
	last_raided_city_coord = target_city.coord
	current_target_city_coord = NO_COORD
	var new_target := _choose_target_city(players)
	_engagement_target_coord = (new_target.coord if new_target != null else NO_COORD)
	return new_target

func _take_dragon_turn_logic(hex_grid: HexGrid, players: Array[PlayerData]) -> void:
	if dragon_unit == null or dragon_unit.hp <= 0.0:
		# Morreu ANTES deste tick -- em combate normal (outra unidade
		# interceptou durante o turno de outro jogador) OU por qualquer
		# outro dano direto a hp (ex.: feitico V2, que tambem chama
		# hex_grid.remove_unit fora do CombatResolver) -- de qualquer jeito,
		# quem causou o dano ja removeu a Unit do mapa sozinho
		# quando isso aconteceu; aqui so' falta reconhecer o desfecho.
		_resolve_with_outcome("defeated")
		return

	# Escolhido ANTES do check de combate agora (5B.3-F) -- ver comentario
	# de _combat_streak abaixo pro motivo.
	var target_city := _choose_target_city(players)
	target_city = _abandon_target_if_engagement_budget_exhausted(target_city, players)

	var enemy: Unit = MonsterAI._hostile_in_attack_range(dragon_unit, hex_grid)
	if enemy != null:
		if _combat_streak >= GROUND_COMBAT_STREAK_LIMIT:
			# BUG real encontrado apos o usuario reportar "desaparece" DE
			# NOVO, reproduzido com instrumentacao temporaria: um rival em
			# guerra de verdade PRODUZ reforcos sem parar, entao repor
			# pra so' o vizinho mais proximo (como era antes) so' trocava
			# pro PROXIMO defensor da mesma fileira -- o Dragao ficava
			# preso lutando contra um exercito inteiro (20+ turnos
			# seguidos observados no playtest, raids_done travado, HP/
			# posicao praticamente parados) sem NUNCA voltar a raidar,
			# parecendo "sumido" pro jogador mesmo o evento tecnicamente
			# continuando Active. Fix: o "break off" agora e' um salto
			# GRANDE em direcao a cidade-alvo (orcamento de FLYING, nao um
			# vizinho) -- da uma chance real de ULTRAPASSAR o aglomerado
			# de defensores em vez de so' trocar de adversario.
			_combat_streak = 0
			if target_city != null:
				_break_off_toward(hex_grid, target_city.coord)
			else:
				_reposition_nearby(hex_grid)
			return
		_combat_streak += 1
		_play_dragon_attack_effects()
		CombatResolver.resolve_with_splash(dragon_unit, enemy, hex_grid, DRAGON_SPLASH_RADIUS, DRAGON_SPLASH_DAMAGE_FRACTION)
		if dragon_unit.hp <= 0.0:
			_play_dragon_death_effects()
			_resolve_with_outcome("defeated")
		return
	_combat_streak = 0

	if target_city == null:
		# Civ-alvo sem cidade nenhuma (todas destruidas/civ eliminada) --
		# nao ha mais o que fazer. Caso raro, nao previsto no contrato
		# original; tratado aqui como fim do evento em vez de travar.
		_resolve_with_outcome("no_target")
		return
	current_target_city_coord = target_city.coord

	# Dois modos EXPLICITOS de deslocamento (item 1) -- recalculado todo
	# tick a partir da distancia ATUAL, nunca guardado alem deste tick.
	var distance_to_target: float = HexMetrics.axial_distance(dragon_unit.coord, target_city.coord)
	travel_mode = TRAVEL_MODE_GROUND if distance_to_target <= DRAGON_GROUND_ENGAGE_RANGE else TRAVEL_MODE_FLYING
	# Roadmap "Dragon Event v1 fechado" -- pedido explicito do usuario:
	# animacao de Voo (asas batendo) durante Flying, em vez do Walking_A
	# generico que slide_to() tocaria por padrao. moving_animation/idle_
	# animation sao campos de INSTANCIA (ver Unit.gd) -- trocar isto aqui
	# nao exige nenhuma mudanca no restante do arquivo de movimento.
	if travel_mode == TRAVEL_MODE_FLYING:
		dragon_unit.moving_animation = "Fly"
		dragon_unit.idle_animation = "Fly"
	else:
		dragon_unit.moving_animation = Unit.WALK_ANIMATION
		dragon_unit.idle_animation = Unit.DEFAULT_ANIMATION

	if _city_in_attack_range(hex_grid, target_city):
		_play_dragon_attack_effects()
		CombatResolver.resolve_city_attack(dragon_unit, target_city, hex_grid, DRAGON_RAID_DAMAGE_FRACTION)
		raids_done += 1
		last_raided_city_coord = target_city.coord
		# 5B.3-G, cobertura continental -- so' conta como "visita" um raid
		# REAL (dano de verdade aplicado acima), nunca escolha de alvo,
		# movimento ou aproximacao (pedido explicito do usuario).
		var civ_index := _civ_index_of_city(target_city, players)
		if civ_index >= 0:
			civ_visits[civ_index] = int(civ_visits.get(civ_index, 0)) + 1
		# "Depois de uma incursao, ele precisa continuar procurando outro
		# destino" -- limpa a perseguicao atual; o PROXIMO tick escolhe de
		# novo, EXCLUINDO esta cidade enquanto existir alternativa (item 7).
		current_target_city_coord = NO_COORD
		_turns_engaged_at_target = 0
		_engagement_target_coord = NO_COORD
		if _all_living_civs_covered(players):
			_resolve_with_outcome("devastated")
		return

	# FLYING: um movement_left bem maior SO' NESTE TICK (nunca um pathfind
	# novo nem um loop de N movimentos com combate entre cada, pedido
	# explicito do usuario) -- reusa RivalAI.move_unit_toward/HexGrid.
	# compute_reachable exatamente como GROUND usa, so' com orcamento
	# maior. reset_movement() (uma vez por turno, GameManager) volta ao
	# normal sozinho no proximo turno, entao nao precisa desfazer isto.
	if travel_mode == TRAVEL_MODE_FLYING:
		dragon_unit.movement_left = DRAGON_FLYING_TILES_PER_TURN
	RivalAI.move_unit_toward(dragon_unit, hex_grid, target_city.coord)

## Toca a animacao de Ataque + o VFX de sopro de fogo (GPUParticles3D +
## luz, ambos construidos junto do corpo em Unit._build_dragon_body) --
## chamado ANTES de CombatResolver.resolve_with_splash/resolve_city_attack
## de proposito (pedido do usuario: "cabeça abre → inclina → pausa, e um
## sistema de partículas produz o jato de fogo" -- o efeito visual precisa
## comecar ANTES/JUNTO do dano ser aplicado, nunca depois). Busca os nodes
## pelo nome (find_child) em vez de guardar referencia direta -- a Unit e'
## reconstruida do zero a cada spawn/relink, nunca vale a pena cachear.
func _play_dragon_attack_effects() -> void:
	if dragon_unit == null or not is_instance_valid(dragon_unit):
		return
	dragon_unit._play_animation("Attack")
	var emitter := dragon_unit.find_child("FireBreathEmitter", true, false)
	if emitter is GPUParticles3D:
		emitter.restart()
	var light := dragon_unit.find_child("FireBreathLight", true, false)
	if light is OmniLight3D:
		light.light_energy = 3.0
		var tween := dragon_unit.create_tween()
		tween.tween_property(light, "light_energy", 0.0, 0.5).set_delay(0.3)

## Toca "Death" (rotation, ver Unit._build_dragon_death_animation) + um
## Tween a parte pra QUEDA (position:y) relativo ao valor ATUAL da Unit no
## momento da morte -- nunca um numero fixo dentro do proprio clipe (ver
## comentario la pro motivo exato). Chamado so' quando o proprio
## DragonEvent detecta a morte em tempo real (combate contra `enemy`
## acima); se o Dragao morreu no turno de OUTRO jogador (ver dead-check no
## topo de _take_dragon_turn_logic), a Unit ja foi removida do mapa antes
## do DragonEvent sequer notar -- nao ha corpo mais pra animar.
func _play_dragon_death_effects() -> void:
	if dragon_unit == null or not is_instance_valid(dragon_unit):
		return
	dragon_unit._play_animation("Death")
	var tween := dragon_unit.create_tween()
	tween.tween_property(dragon_unit, "position:y", dragon_unit.position.y - 0.35, 1.2)

## Ponto UNICO que decide um desfecho de verdade pro evento (item 8/9 do
## pedido original: "o Dragao nao pode sumir sem resolucao"). 5B.3-G:
## deixou de emitir toast aqui -- playtest revelou que um aviso de 1-tick
## era fraco demais pra um evento continental de varios turnos, fácil de
## perder ("o jogador viu apenas um texto minusculo e interpretou como
## bug/desaparecimento"). A transicao de fase (phase = RESOLUTION abaixo)
## ja dispara EventBus.world_event_phase_changed sozinha (ver
## WorldEventManager.advance_turn) -- HUD._on_world_event_phase_changed
## escuta esse sinal e mostra um MODAL bloqueante (reusa o mesmo padrao
## _show_overlay ja usado pro anuncio de Announced), exigindo confirmacao
## do jogador. _outcome_message() continua existindo, usada pelo Event
## Tracker/label curto -- so' nao vai mais pro canal de toast.
func _resolve_with_outcome(outcome: String) -> void:
	result = {"outcome": outcome}
	phase = WorldEvent.PHASE_RESOLUTION

static func _outcome_message(outcome: String) -> String:
	match outcome:
		"defeated":
			return "O Dragão foi derrotado! A ameaça chegou ao fim."
		"devastated":
			return "O Dragão devastou a região e partiu, saciado, para outras terras."
		"no_target":
			return "O Dragão perdeu o rastro de suas vítimas e desapareceu no horizonte."
		_:
			return "O Dragão se afastou."

## Move o Dragao pro primeiro vizinho valido encontrado -- so' pra quebrar
## um combate estagnado (ver GROUND_COMBAT_STREAK_LIMIT). SEM RNG de
## proposito: a ordem FIXA de HexGrid.NEIGHBOR_DIRS ja e' suficiente pra
## escolher consistentemente o mesmo vizinho toda vez que o mesmo estado
## se repetir (determinismo, item 11) -- nao precisa do event_rng aqui.
## So' usada como FALLBACK quando nao ha cidade-alvo nenhuma pra onde
## quebrar o combate em direcao (ver _break_off_toward abaixo, o caminho
## normal) -- caso raro/defensivo (civ-alvo ja sem cidade nenhuma, mas
## ainda tinha um inimigo em alcance nesta mesma tick).
func _reposition_nearby(hex_grid: HexGrid) -> void:
	for neighbor in hex_grid.get_neighbors(dragon_unit.coord):
		if _is_valid_dragon_tile(hex_grid, neighbor):
			hex_grid.move_unit(dragon_unit, neighbor, 0.0)
			return

## 5B.3-G -- achado por reproducao de LONGA duracao (200 turnos) apos a IA
## rival ganhar reacao militar/producao de emergencia SEM teto (RivalAI.
## prepare_for_world_event): um rival com varias cidades conseguia produzir
## unidades bem mais rapido do que o Dragao conseguia raidar/eliminar,
## cercando-o em TODOS os 6 vizinhos ao mesmo tempo -- _reposition_nearby
## (so' 1 anel) falhava toda vez, e _break_off_toward ficava tao preso
## quanto antes do fix anterior (raids_done/civ_visits travados em {},
## dragon.hp e posicao IDENTICOS por 194 turnos seguidos num teste real).
## Mesma varredura em ANEIS CRESCENTES ja usada por _choose_spawn_coord
## (SPAWN_SEARCH_MAX_RINGS) -- reposiciona (teleporta, sem pathfind, mesmo
## principio de _reposition_nearby) pro primeiro tile valido encontrado,
## por mais distante que esteja. Um cerco que ocupa TODOS os tiles dentro
## de SPAWN_SEARCH_MAX_RINGS(6) exigiria centenas de unidades bem
## organizadas ao redor do Dragao -- fora do alcance realista da economia
## de uma unica civ, mesmo em emergencia.
func _reposition_escaping_siege(hex_grid: HexGrid) -> void:
	var origin := dragon_unit.coord
	var visited := {origin: true}
	var frontier: Array[Vector2i] = [origin]
	for ring in range(SPAWN_SEARCH_MAX_RINGS):
		var next_frontier: Array[Vector2i] = []
		for coord in frontier:
			for neighbor in hex_grid.get_neighbors(coord):
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				if _is_valid_dragon_tile(hex_grid, neighbor):
					hex_grid.move_unit(dragon_unit, neighbor, 0.0)
					return
				next_frontier.append(neighbor)
		frontier = next_frontier

## Quebra um combate estagnado com um salto GRANDE em direcao a cidade-alvo
## (mesmo orcamento de FLYING, ver DRAGON_FLYING_TILES_PER_TURN) -- NUNCA
## so' um vizinho. BUG real encontrado por reproducao instrumentada apos o
## usuario reportar "desaparece" repetidamente: um rival em guerra de
## verdade PRODUZ reforcos sem parar; reposicionar pro vizinho mais proximo
## so' trocava o Dragao pro PROXIMO defensor da MESMA fileira, entao ele
## ficava preso lutando contra um exercito inteiro por dezenas de turnos
## seguidos, raids_done travado, sem NUNCA voltar a perseguir/raidar a
## cidade -- parecia "sumido" pro jogador mesmo o evento tecnicamente
## continuando Active o tempo todo. Um salto GRANDE da ao Dragao uma chance
## real de ULTRAPASSAR o aglomerado de defensores em vez de so' trocar de
## adversario -- reusa RivalAI.move_unit_toward exatamente como o
## deslocamento FLYING normal, nunca um pathfinding novo.
##
## 5B.3-G, dois fallbacks em camadas (achados por reproducao apos a propria
## IA rival ganhar reacao militar/producao de emergencia, ver RivalAI.
## prepare_for_world_event/defend_against_dragon): RivalAI.move_unit_toward
## usa HexGrid.compute_reachable, que so' considera tiles alcancaveis por
## um CAMINHO livre -- se reforcos frescos ocuparem os vizinhos imediatos
## do Dragao (efeito colateral direto de uma defesa mais agressiva), o
## salto "grande" pode nao mover o Dragao NENHUM tile, mesmo com orcamento
## de sobra. Se o pathfind normal nao mudou a posicao, tenta primeiro
## _reposition_nearby (1 vizinho livre); se ISSO TAMBEM falhar -- cercado
## nos 6 vizinhos ao mesmo tempo, caso real confirmado numa reproducao de
## 200 turnos -- escala pra _reposition_escaping_siege (aneis crescentes),
## garantindo alguma saida sempre que existir QUALQUER tile livre dentro de
## SPAWN_SEARCH_MAX_RINGS.
func _break_off_toward(hex_grid: HexGrid, target_coord: Vector2i) -> void:
	var coord_before := dragon_unit.coord
	dragon_unit.movement_left = DRAGON_FLYING_TILES_PER_TURN
	RivalAI.move_unit_toward(dragon_unit, hex_grid, target_coord)
	if dragon_unit.coord != coord_before:
		return
	_reposition_nearby(hex_grid)
	if dragon_unit.coord == coord_before:
		_reposition_escaping_siege(hex_grid)

## Indice (posicao em `players`, mesma convencao de target_civ_index) da
## civ dona de `city` -- -1 se `city` nao pertencer a nenhum player da
## lista (nao deveria acontecer de verdade, defensivo).
func _civ_index_of_city(city: City, players: Array[PlayerData]) -> int:
	return players.find(city.owner_player)

## Indices de civs ainda VIVAS (com pelo menos 1 cidade) -- civ eliminada
## nunca conta pra cobertura continental (nao ha mais o que raidar nela).
func _living_civ_indices(players: Array[PlayerData]) -> Array[int]:
	var indices: Array[int] = []
	for i in range(players.size()):
		if not players[i].cities.is_empty():
			indices.append(i)
	return indices

## True quando TODA civ viva ja recebeu pelo menos CIV_VISIT_TARGET raids
## bem-sucedidos -- condicao de termino "devastated" da 5B.3-G (substitui
## raids_done >= DEVASTATION_RAID_LIMIT). Nenhuma civ viva = trivialmente
## coberta (nao deveria acontecer de verdade -- target_city == null/
## "no_target" ja cobre "mapa sem cidade nenhuma" antes de chegar aqui).
func _all_living_civs_covered(players: Array[PlayerData]) -> bool:
	for i in _living_civ_indices(players):
		if int(civ_visits.get(i, 0)) < CIV_VISIT_TARGET:
			return false
	return true

## Pedido explicito do usuario (5B.3-G, "IA precisa reagir ao Dragao" +
## "Preparation = tempo de preparacao militar"): esta civ deveria estar em
## alerta/producao militar de emergencia AGORA? Preparation: so' a civ
## ANUNCIADA (ja sabe que sera' visitada, mesma info publica desde sempre).
## Active: qualquer civ que ja tenha recebido ao menos 1 raid (a ameaca
## deixou de ser hipotetica) OU que tenha uma cidade dentro de THREAT_
## DETECTION_RADIUS do Dragao AGORA -- nunca uma violacao de fog of war:
## a Unit do Dragao e' always_visible=true por design (ver _mark_dragon_
## unit), entao "todo mundo ve o Dragao" ja e' a regra existente, nao uma
## trapaca nova concedida so' pra IA.
const THREAT_DETECTION_RADIUS := 8
func is_civ_threatened(player_index: int, players: Array[PlayerData]) -> bool:
	if phase == WorldEvent.PHASE_PREPARATION:
		return player_index == target_civ_index
	if phase != WorldEvent.PHASE_ACTIVE or dragon_unit == null or not is_instance_valid(dragon_unit):
		return false
	if int(civ_visits.get(player_index, 0)) > 0:
		return true
	if player_index < 0 or player_index >= players.size():
		return false
	for city in players[player_index].cities:
		if HexMetrics.axial_distance(dragon_unit.coord, city.coord) <= THREAT_DETECTION_RADIUS:
			return true
	return false

## Prioridade 1: a MESMA cidade ja sendo perseguida (persiste enquanto ela
## continuar existindo, qualquer civ). Prioridade 2 (5B.3-G, "cobertura
## continental"): entre as civs VIVAS com o MENOR numero de visitas AINDA
## abaixo de CIV_VISIT_TARGET, a cidade mais proxima -- pedido explicito do
## usuario usa um exemplo de RODADA COMPLETA ("Humanos -> Elfos -> Orcs ->
## Anoes -> Humanos -> Orcs -> ...", toda civ recebe sua 1a passagem antes
## de QUALQUER civ receber a 2a), entao o corte precisa ser pelo MINIMO
## exato de visitas entre as civs vivas, nunca so' um balde binario "abaixo
## do alvo" (isso deixaria uma civ ja visitada 1x competir de igual pra
## igual com uma civ ainda em 0, so' por distancia, quebrando a rodada).
## Blocker #3 revisado de novo: "a ordem NAO deve ser fixa" -- sem lock
## nenhum em target_civ_index aqui. Uma vez que TODAS as civs vivas ja
## atingiram o alvo de visitas, a busca reabre pra QUALQUER cidade (o
## Dragao pode voltar livremente). Dentro do conjunto escolhido, ainda
## EXCLUI a ultima cidade raidada enquanto existir alguma alternativa (item
## 7 original: "não escolher eternamente a mesma cidade se houver
## alternativas") -- se a unica cidade que resta FOR a ultima raidada, ela
## continua sendo escolhida mesmo assim.
func _choose_target_city(players: Array[PlayerData]) -> City:
	if current_target_city_coord != NO_COORD:
		for player in players:
			for city in player.cities:
				if city.coord == current_target_city_coord:
					return city
	var living := _living_civ_indices(players)
	var min_visits := CIV_VISIT_TARGET
	for i in living:
		min_visits = min(min_visits, int(civ_visits.get(i, 0)))
	var priority_indices: Array[int] = living
	if min_visits < CIV_VISIT_TARGET:
		priority_indices = []
		for i in living:
			if int(civ_visits.get(i, 0)) == min_visits:
				priority_indices.append(i)
	var best: City = null
	var best_distance := INF
	var best_excluding_last: City = null
	var best_excluding_last_distance := INF
	for i in priority_indices:
		for city in players[i].cities:
			var distance: float = HexMetrics.axial_distance(dragon_unit.coord, city.coord)
			if distance < best_distance:
				best_distance = distance
				best = city
			if city.coord != last_raided_city_coord and distance < best_excluding_last_distance:
				best_excluding_last_distance = distance
				best_excluding_last = city
	return best_excluding_last if best_excluding_last != null else best

func _city_in_attack_range(hex_grid: HexGrid, city: City) -> bool:
	return city.coord in hex_grid.tiles_in_range(dragon_unit.coord, dragon_unit.unit_data.attack_range)

## Civilizacao com a cidade mais proxima de origin_region -- formula
## PROVISORIA (Blocker #3 continua aberto pra formula definitiva). -1 se
## nenhuma civ tiver cidade nenhuma (mapa vazio/todos eliminados).
func _find_nearest_civ_index(players: Array[PlayerData]) -> int:
	var best_index := -1
	var best_distance := INF
	for i in range(players.size()):
		for city in players[i].cities:
			var distance: float = HexMetrics.axial_distance(origin_region, city.coord)
			if distance < best_distance:
				best_distance = distance
				best_index = i
	return best_index

func _notify_preparation_started(players: Array[PlayerData]) -> void:
	var target_name := "uma civilização desconhecida"
	if target_civ_index >= 0 and target_civ_index < players.size():
		target_name = players[target_civ_index].civ.civ_name
	# 5B.3-G: "primeiro" removido de proposito -- a ordem de visita nao e'
	# mais garantida (Blocker #3 revisado de novo, ver _choose_target_city),
	# so' a PRIMEIRA a ser avisada continua sendo verdade.
	EventBus.notify.emit("O Dragão se aproxima. Os relatos foram confirmados: uma criatura de poder incomum deverá surgir na região em breve. %s foi a primeira a ser avisada da ameaça. Faltam %d turnos para sua chegada — deseja participar da expedição para detê-lo?" % [target_name, PREPARATION_DURATION_TURNS], "")

## Regra MINIMA proposital (docs/DRAGON_EVENT_DESIGN.md, Blocker #1):
## considera origin_region primeiro, depois expande em aneis de vizinhos
## ate achar um tile valido (existe no mapa, sem cidade/unidade em cima) ou
## esgotar SPAWN_SEARCH_MAX_RINGS -- nesse caso degenerado (raro), cai de
## volta em origin_region mesmo assim. Formulas melhores (montanha,
## distancia do alvo, fog of war) ficam pra depois. Deterministico -- nao
## usa event_rng aqui porque a busca em si e' uma varredura fixa por
## distancia crescente, sem decisao aleatoria nenhuma (o ponto de partida,
## origin_region, ja veio do RNG do trigger). Agua/lava sao tiles VALIDOS
## aqui (item 2 do pedido do usuario) -- ver _is_valid_dragon_tile.
func _choose_spawn_coord(hex_grid: HexGrid) -> Vector2i:
	if _is_valid_dragon_tile(hex_grid, origin_region):
		return origin_region
	var visited := {origin_region: true}
	var frontier: Array[Vector2i] = [origin_region]
	for ring in range(SPAWN_SEARCH_MAX_RINGS):
		var next_frontier: Array[Vector2i] = []
		for coord in frontier:
			for neighbor in hex_grid.get_neighbors(coord):
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				if _is_valid_dragon_tile(hex_grid, neighbor):
					return neighbor
				next_frontier.append(neighbor)
		frontier = next_frontier
	return origin_region # degenerado -- nenhum tile valido na busca inteira

## Compartilhada por _choose_spawn_coord (spawn) e _reposition_nearby
## (quebra de combate estagnado) -- so' precisa existir no mapa e estar
## livre de outra unidade/cidade. Item 2 do pedido do usuario (5B.3-D):
## NUNCA checa HexTileData.blocks_land_units() de proposito -- o Dragao
## voa, entao agua/lava sao tiles validos pra ele (spawn OU reposicionar),
## diferente da restricao normal de unidade terrestre.
func _is_valid_dragon_tile(hex_grid: HexGrid, coord: Vector2i) -> bool:
	var data: HexTileData = hex_grid.get_tile(coord)
	if data == null:
		return false
	if hex_grid.get_unit_at(coord) != null or hex_grid.get_city_at(coord) != null:
		return false
	return true

## Segura contra dupla remocao: se o Dragao morreu em combate (outcome
## "defeated"), CombatResolver.resolve JA chamou hex_grid.remove_unit --
## checar hex_grid.get_unit_at(...) == dragon_unit antes de remover de novo
## evita operar numa Unit ja removida do mapa (ainda valida como objeto,
## queue_free() e' adiado, mas nao deveria ser tratada como presente).
func _remove_dragon_unit(hex_grid: HexGrid) -> void:
	if dragon_unit != null and is_instance_valid(dragon_unit) and hex_grid.get_unit_at(dragon_unit.coord) == dragon_unit:
		hex_grid.remove_unit(dragon_unit)
	dragon_unit = null

## Aplica as DUAS flags que fazem esta Unit se comportar como o Dragao de
## um World Event, nunca como um monstro comum -- ver comentario dos
## campos em Unit.gd (always_visible/world_event_managed). Chamado tanto
## no spawn (Preparation->Active) quanto em relink_unit() (pos save/load,
## ver comentario abaixo): nenhuma das duas flags e' persistida como dado
## (sao propriedades da Unit, nao do DragonEvent), entao uma Unit
## RECONSTRUIDA pelo save generico de monstros neutros nasce com as duas
## em `false` -- sem reaplicar aqui, um save/load durante Active
## reintroduziria os DOIS bugs que essas flags corrigem (Dragao invisivel
## sob nevoa de novo, Dragao processado de novo pela IA generica de
## monstro).
func _mark_dragon_unit(unit: Unit) -> void:
	unit.always_visible = true
	unit.world_event_managed = true

## Onde a Unit REALMENTE esta agora (nao onde nasceu) -- persistido so'
## pra relink_unit() conseguir reencontra-la depois de um save/load em
## pleno Active. Ver comentario de to_save_dict()/relink_unit() abaixo pro
## bug real que este campo corrige.
var last_unit_coord: Vector2i = NO_COORD

## Chamado pelo SaveManager DEPOIS de restaurar os monstros neutros (que ja
## inclui esta Unit, ver HexGrid.neutral_units/_deserialize_neutral_units)
## e DEPOIS de WorldEventManager.from_save_dict reconstruir este evento --
## dragon_unit e' um Node, nunca serializado diretamente. Usa last_unit_
## coord (onde a Unit estava no momento do SAVE), NUNCA spawn_coord --
## BUG real encontrado apos o usuario reportar "desaparece sem explicacao"
## de novo: o Dragao se move MUITO depois de nascer (Flying/Ground, raids,
## reposicionamento), mas spawn_coord fica CONGELADO no tile de nascimento
## pra sempre (nunca reescrito em lugar nenhum deste arquivo). Um save/
## load em pleno Active, com o Dragao ja longe de onde nasceu, procurava a
## Unit no lugar ERRADO -- geralmente vazio -- e relink_unit() achava
## `null`. O proximo tick entao lia dragon_unit == null e resolvia
## "defeated" por engano, mesmo com a Unit de verdade ainda viva e
## presente no mapa (so' ORFA, sem always_visible/world_event_managed
## reaplicados -- ficava invisivel sob nevoa de novo E voltava a ser
## processada pela IA generica de monstro, o MESMO bug que ja tinhamos
## corrigido, agora reintroduzido pelo relink quebrado). No-op segura se o
## Dragao ainda nao tinha nascido (spawn_coord == NO_COORD continua o
## guard certo pra isso).
func relink_unit(hex_grid: HexGrid) -> void:
	if spawn_coord == NO_COORD:
		return
	var lookup_coord := last_unit_coord if last_unit_coord != NO_COORD else spawn_coord
	dragon_unit = hex_grid.get_unit_at(lookup_coord)
	if dragon_unit != null:
		_mark_dragon_unit(dragon_unit)

func to_save_dict() -> Dictionary:
	var data := super.to_save_dict()
	data["origin_region"] = [origin_region.x, origin_region.y]
	data["spawn_coord"] = [spawn_coord.x, spawn_coord.y]
	data["target_civ_index"] = target_civ_index
	data["raids_done"] = raids_done
	data["current_target_city_coord"] = [current_target_city_coord.x, current_target_city_coord.y]
	# 5B.3-D -- necessario pra reconstruir corretamente qual cidade fica
	# EXCLUIDA da proxima escolha de alvo (ver _choose_target_city); sem
	# isto, um save/load logo apos raidar esqueceria a exclusao e a MESMA
	# cidade poderia ser escolhida novamente sem motivo. travel_mode/
	# _combat_streak de proposito NAO sao persistidos -- sao inteiramente
	# derivados/recalculados a cada tick (ver seus comentarios de campo),
	# nao SAVE_VERSION nenhum precisou mudar (chave nova, opcional, com
	# fallback seguro em from_save_dict).
	data["last_raided_city_coord"] = [last_raided_city_coord.x, last_raided_city_coord.y]
	# BUG FIX -- ver comentario de relink_unit() acima. Le dragon_unit.coord
	# DIRETO (a Unit continua viva/valida neste exato momento, o save esta
	# acontecendo AGORA) em vez de depender de spawn_coord, que nunca e'
	# atualizado conforme o Dragao se move.
	if dragon_unit != null and is_instance_valid(dragon_unit):
		data["last_unit_coord"] = [dragon_unit.coord.x, dragon_unit.coord.y]
	# 5B.3-G -- chaves convertidas pra STRING explicitamente: SaveManager
	# serializa em JSON (ver SaveManager.gd), que so' tem chave string.
	# Sem esta conversao, civ_visits.get(indice_int, 0) nunca bateria com
	# uma chave string sobrevivente do load (silenciosamente perderia todo
	# o progresso de cobertura continental a cada save/load).
	var civ_visits_for_save := {}
	for civ_index in civ_visits:
		civ_visits_for_save[str(civ_index)] = civ_visits[civ_index]
	data["civ_visits"] = civ_visits_for_save
	# Mesma conversao de chave pro ranking de dano (ver comentario do campo).
	var damage_by_civ_for_save := {}
	for civ_index in damage_by_civ:
		damage_by_civ_for_save[str(civ_index)] = damage_by_civ[civ_index]
	data["damage_by_civ"] = damage_by_civ_for_save
	return data

func from_save_dict(data: Dictionary) -> void:
	super.from_save_dict(data)
	var origin: Array = data.get("origin_region", [NO_COORD.x, NO_COORD.y])
	origin_region = Vector2i(int(origin[0]), int(origin[1]))
	var last_unit: Array = data.get("last_unit_coord", [NO_COORD.x, NO_COORD.y])
	last_unit_coord = Vector2i(int(last_unit[0]), int(last_unit[1]))
	var spawn: Array = data.get("spawn_coord", [NO_COORD.x, NO_COORD.y])
	spawn_coord = Vector2i(int(spawn[0]), int(spawn[1]))
	target_civ_index = int(data.get("target_civ_index", -1))
	raids_done = int(data.get("raids_done", 0))
	var last_raided: Array = data.get("last_raided_city_coord", [NO_COORD.x, NO_COORD.y])
	last_raided_city_coord = Vector2i(int(last_raided[0]), int(last_raided[1]))
	var target_city: Array = data.get("current_target_city_coord", [NO_COORD.x, NO_COORD.y])
	current_target_city_coord = Vector2i(int(target_city[0]), int(target_city[1]))
	civ_visits = {}
	for key in data.get("civ_visits", {}):
		civ_visits[int(key)] = int(data["civ_visits"][key])
	damage_by_civ = {}
	for key in data.get("damage_by_civ", {}):
		damage_by_civ[int(key)] = float(data["damage_by_civ"][key])

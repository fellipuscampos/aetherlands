class_name Unit
extends Node3D

const HP_BAR_WIDTH := 0.5
const HP_BAR_HEIGHT := 0.07
const HP_BAR_Y := 0.95
const MOVE_DURATION := 0.35

## Badge "isto e uma tropa" acima de toda unidade — pedido do usuario:
## "coloque icones em cima das tropas tipo os dos recursos pra identificar
## que e uma tropa" (ver ResourceIconManager pro mesmo principio visual
## sobre tile de recurso). TROOP_ICON_Y fica acima da propria barra de vida
## (HP_BAR_Y) pra nunca sobrepor ela.
const TROOP_ICON_SIZE := 32
const TROOP_ICON_BADGE_RADIUS := 13.0
const TROOP_ICON_BADGE_COLOR := Color(0.05, 0.05, 0.08, 0.6)
const TROOP_ICON_COLOR := Color(0.88, 0.88, 0.92)
const TROOP_ICON_Y := 1.08
static var _troop_icon_texture: ImageTexture

## Cor FALLBACK pro corpo/base de monstro neutro (owner_player == null, ver
## MonsterDatabase) sem entrada em MONSTER_KIND_COLORS — nao tem civ.color
## pra puxar, entao um vermelho sangue fixo serve tambem pra diferenciar
## visualmente "isso e hostil a todo mundo" de qualquer unidade de jogador.
const MONSTER_COLOR := Color(0.45, 0.08, 0.08)

## Cada tipo de monstro (MonsterDatabase.KIND_DATA) tem sua PROPRIA cor fixa
## de silhueta — pedido: "Goblins verde viva, Trolls cinza/rocha, Vivern/
## Dragao vermelho-laranja/roxo, Esqueleto branco/creme" — em vez de todos
## caindo no mesmo MONSTER_COLOR vermelho-sangue generico. Usado tanto no
## corpo (_build_procedural_body) quanto na base (_build_base_disc).
const MONSTER_KIND_COLORS := {
	"goblin": Color(0.25, 0.75, 0.2),
	"troll": Color(0.5, 0.5, 0.52),
	"wyvern": Color(0.85, 0.35, 0.05),
	"dragon": Color(0.55, 0.1, 0.55),
	"skeleton": Color(0.92, 0.9, 0.82),
}

## Veterania: unidade que vence combate (mata ou sobrevive matando quem a
## atacou) acumula kills e sobe de nivel em thresholds fixos, ganhando
## +10%/nivel em ataque E defesa (CombatResolver.predict() aplica) e uma
## cura parcial na hora da promocao — da um motivo real pra manter
## unidades veteranas vivas em vez de sempre produzir novas.
const VETERANCY_TITLES := ["Recruta", "Veterano", "Elite", "Lendario"]
const VETERANCY_KILL_THRESHOLDS := [0, 1, 3, 6] # kills minimos pra cada indice/nivel
const VETERANCY_BONUS_PER_LEVEL := 0.1
const PROMOTION_HEAL_FRACTION := 0.2

## Sentinela "sem ordem pendente" (mesmo padrao de HexGrid.NO_LAIR) pro
## campo abaixo.
const NO_MOVE_ORDER := Vector2i(-999999, -999999)

var unit_data: UnitData
var serial_id: int = 0
var magic_cooldowns: Dictionary = {}
var magic_status: Dictionary = {} # efeito -> turno de expiração exclusivo
var owner_player: PlayerData
var coord: Vector2i
var movement_left: float = 0.0
var kills: int = 0
var veterancy_level: int = 0

## Aetherlands V2, Fase 15 — cargas restantes do Construtor (V2ConstructorRuntime). Definido UMA
## vez, ao nascer (GameManager, pelo tier de Indústria do dono naquele instante — §56 do pedido:
## pesquisa posterior nunca recarrega um Construtor já existente). 0 pra qualquer unidade que não
## seja o Construtor — nunca lido fora do runtime do Construtor.
var work_charges_remaining: int = 0

## Destino de um pedido "mover ate" que pode levar VARIOS turnos pra
## completar (pedido do usuario: "no civilization eu posso colocar pra ela
## se mover pra um lugar longe... o movimento fica gravado e todo turno
## essa tropa vai se movendo") — NO_MOVE_ORDER = sem ordem pendente.
## SelectionManager._try_queue_move_order seta isto ao clicar um destino
## fora do alcance do turno atual; HexGrid.continue_move_order consome ele
## aos poucos, chamado tanto na hora (mesmo turno, o quanto der) quanto em
## toda troca de turno seguinte (GameManager._on_turn_changed), ate chegar
## ou o caminho deixar de existir. Recalculado do ZERO a cada chamada (nao
## e um caminho fixo salvo aqui) — se um obstaculo novo aparecer no meio
## do trajeto (outra unidade, guerra declarada...) a rota se adapta
## sozinha em vez de travar numa rota velha invalida. Nao sobrevive a um
## save/load (SaveManager nao serializa este campo de proposito — ordem
## pendente e uma conveniencia de sessao, nao um estado de jogo que
## precise persistir; carregar um save so limpa silenciosamente qualquer
## ordem em andamento).
var move_order_target: Vector2i = NO_MOVE_ORDER

## Colonizador da IA (ver CitySite.choose_site/RivalAI._handle_settler): local
## de fundacao ja escolhido (histerese -- sem isso o colonizador trocaria de
## alvo a cada passo, porque a pontuacao de candidatos empatados muda
## conforme ele anda) e quantos turnos ja esperou sem achar nenhum local
## aceitavel. Estado de sessao da IA, nao salvo (mesmo padrao de
## move_order_target): carregar um save so faz o colonizador reavaliar.
const NO_SETTLE_TARGET := Vector2i(-999999, -999999)
var settle_target: Vector2i = NO_SETTLE_TARGET
var settle_wait_turns: int = 0

## Modo "Fortificar" tipo Civilization (pedido do usuario: "um modo em que
## se você tiver ferido, você fica se curando um pouco todo turno... e em
## geral ela fica daquele jeito parado até você mover ela ou alguma tropa
## atacar ela") — cura passiva fora de cidade (ver GameManager.
## FORTIFY_HEAL_FRACTION/_heal_if_garrisoned) + bonus de defesa (ver
## CombatResolver.FORTIFY_DEFENSE_BONUS). So cancela com uma ORDEM NOVA do
## jogador (mover, atacar, explorar) — SER atacado nao cancela (a unidade
## revida normalmente e continua fortificada se sobreviver), exatamente
## como o usuario descreveu.
var fortified: bool = false

## Modo "Explorar" tipo Civilization (pedido do usuario: "uma função que
## fica ativada... que se baseie em ficar andando por territórios que
## ainda não foram explorados") — HexGrid.explore_step() consome isto a
## cada troca de turno, andando sozinha em direcao ao tile UNSEEN mais
## perto alcancavel. Cancela com Mover ou Fortificar (pedido do usuario:
## "algo desliga a opção de explorar"), ou sozinho quando nao sobra
## nenhum tile UNSEEN alcancavel (mapa todo explorado).
var exploring: bool = false

## Modo "Embarcar" (Roadmap 2.0 Parte 1, acesso naval — pedido do usuario)
## — unidade TERRESTRE que atravessa agua de verdade (Oceano/Mar Gelado/
## Costa, ver HexTileData.can_be_embarked_on()) enquanto isto for true. So
## liga via SelectionManager.toggle_embark_selected(), o UNICO lugar que
## checa as 3 condicoes (tech "Navegação" pesquisada, unidade nao voa, tile
## atual adjacente a agua — ver HexGrid.is_coastal_tile). Unidade em
## transito, nao um segundo modo de combate: NAO pode atacar, fortificar,
## explorar, fundar/capturar cidade nem conjurar feitico enquanto embarcada
## (cada acao guarda isso no proprio ponto de decisao). NAO ignora custo de
## terreno nem cruza Lava (diferente de UnitData.flies) — so a restricao de
## AGUA. Desliga sozinho ao pisar em terra firme de novo (ver HexGrid.
## move_unit) — nao precisa de um botao "Desembarcar" separado. Assim como
## fortified/exploring/move_order_target acima, NAO sobrevive a save/load
## por padrao seria a convencao — mas este campo e a EXCECAO deliberada
## (ver SaveManager._serialize_player/_deserialize_player): perder isto
## silenciosamente deixaria uma unidade presa em pleno oceano tratada como
## terrestre apos carregar, um estado invalido, nao so uma conveniencia
## perdida.
var embarked: bool = false

## true so pro ocupante ORIGINAL de um Covil de Monstro (ver HexGrid.
## spawn_monster_at/_spawn_monster_lairs) — do lado de MonsterDatabase.
## create_monster, controla HP/ataque reforcados e movement_points travado
## em 0. O marcador visual do covil em si (tenda/caverna/etc) NAO depende
## mais disso — ver LairStructure, uma entidade de terreno separada que
## sobrevive mesmo depois do camp boss morrer/ser afastado.
var is_camp_boss: bool = false

## "" = usa o comportamento PADRAO do tipo (MonsterDatabase.KIND_DATA[kind].
## behavior); "guardian"/"invader"/"hunter" (ver MonsterDatabase.BEHAVIOR_*)
## sobrescreve por INSTANCIA — usado pela MonsterAI pra promover um grupo
## ocioso de Goblins Guardioes a Invasores (ver MonsterAI, HexGrid.
## KIND_DATA["goblin"].invader_promotable). So se aplica a monstro neutro
## (owner_player == null); unidade de jogador/rival ignora este campo.
var monster_behavior_state: String = ""

## Roadmap "Fase Macro" 5B.3-C -- pedido do usuario apos reportar que o
## Dragao "nunca aparece": WorldEventTrigger.choose_dragon_origin_region
## sorteia a origem entre TODOS os tiles do mapa, entao a Unit quase
## sempre nasce fora da area ja explorada do jogador -- HexGrid.
## _apply_fog_to_entities so' torna uma unidade de outro dono visivel no
## tile ATUALMENTE visivel (nao so' explorado), entao o Dragao ficava
## invisivel pra sempre a menos que alguem escoteasse aquele tile exato.
## true faz a unidade ignorar essa regra e aparecer sempre, mesmo em
## territorio nunca visto -- pensado pra qualquer entidade de WORLD EVENT
## (a Boss Bar ja anuncia HP/alvo independente de nevoa; esconder o modelo
## fisico contradiz isso), nao exclusivo do Dragao especificamente. Unidade
## comum de jogador/rival/monstro de covil NUNCA liga isto (default false).
var always_visible: bool = false

## Roadmap "Fase Macro" 5B.3-D -- BUG real encontrado apos o usuario
## reportar "o Dragao desaparece sem mensagem": esta Unit e' neutra
## (owner_player == null), MESMO criterio usado por qualquer monstro de
## covil comum -- sem este campo, MonsterAI.take_turn()/GameManager.
## _build_monster_turn_items() (o caminho de verdade usado no jogo real,
## stagger_ai_turns == true) processavam esta Unit de novo com a IA
## GENERICA de monstro (MonsterDatabase.KIND_DATA["dragon"].behavior ==
## BEHAVIOR_HUNTER -- ver MonsterAI._take_hunter_turn), COMPLETAMENTE
## independente do proprio DragonEvent: perseguia presa propria (raio 6,
## bem maior que o alcance de ataque do Dragao), podia mover a Unit pra
## longe do alvo que o DragonEvent estava perseguindo, e podia ate matar a
## Unit via CombatResolver.resolve() comum (nao resolve_with_splash) --
## tudo isso ANTES do proprio DragonEvent._take_dragon_turn() rodar no
## mesmo turno, causando movimento/combate erratico e imprevisivel. true
## faz MonsterAI ignorar esta Unit por completo (ela ja tem IA propria em
## outro lugar) -- generico de proposito (qualquer entidade de WORLD
## EVENT futura precisaria da mesma exclusao), nao exclusivo do Dragao.
## Unidade comum de jogador/rival/monstro de covil NUNCA liga isto.
var world_event_managed: bool = false

## Setter dispara a atualizacao visual da barra de vida sozinha — assim
## qualquer lugar que faca `unit.hp -= dano` (CombatResolver, etc.) ja
## reflete na barra sem precisar lembrar de chamar nada extra. Tambem
## dispara a reacao visual de dano (ver _play_hit_reaction abaixo) sempre
## que o valor NOVO for menor que o atual -- pedido do usuario: "os
## personagens perdem vida isso funciona, mas... nao reagem... minha
## sugestao é piscarem em vermelho... uma puladinha". Cobre TODA fonte de
## dano existente hoje (CombatResolver: ataque, contra-ataque, splash do
## Dragao; SpellManager: feitico de dano direto) e qualquer uma futura de
## graca, sem precisar lembrar de chamar nada extra em cada uma -- mesmo
## principio do comentario acima sobre a barra de vida. `_suppress_hit_
## reaction` e o escape hatch pra restauracao administrativa de hp (ver
## set_hp_silent abaixo) onde "o valor caiu" nao representa um golpe
## acontecendo agora (ex: SaveManager sobrescrevendo o hp cheio do spawn
## inicial pelo hp salvo).
var hp: float = 10.0:
	set(value):
		if value < hp and not _suppress_hit_reaction:
			_play_hit_reaction()
		hp = value
		_update_hp_bar()

var _suppress_hit_reaction := false

## Define hp SEM disparar a reacao visual de dano — ver comentario do
## setter de hp acima. Unico uso hoje: SaveManager restaurando o hp salvo
## por cima do hp cheio que Unit.setup() ja atribuiu no spawn.
func set_hp_silent(value: float) -> void:
	_suppress_hit_reaction = true
	hp = value
	_suppress_hit_reaction = false

var _hp_bar_fg: MeshInstance3D
var _hp_bar_bg: MeshInstance3D

func setup(data: UnitData, player: PlayerData, start_coord: Vector2i, camp_boss: bool = false) -> void:
	unit_data = data
	owner_player = player
	coord = start_coord
	is_camp_boss = camp_boss
	hp = data.max_hp
	movement_left = data.movement_points
	_build_visual()

func reset_movement() -> void:
	movement_left = unit_data.movement_points

## Troca a FORMA desta MESMA unidade por `new_data` (upgrade V2, ver V2UnitUpgrade) —
## não cria uma tropa nova: o objeto continua o mesmo, então dono, coord, serial_id,
## kills/veterania, recargas/estados (magic_cooldowns/magic_status), ordens e o resto
## do estado persistente seguem intactos. Só o que DEPENDE do tipo é refeito: o
## visual (corpo, base, barra de vida, ícone) e o HP, que preserva o PERCENTUAL
## (9/18 vira 12/24), nunca cura de graça nem passa do máximo novo.
func apply_form(new_data: UnitData) -> void:
	var old_max := unit_data.max_hp
	var hp_fraction := clampf(hp / old_max, 0.0, 1.0) if old_max > 0.0 else 1.0
	for t in _hit_reaction_tweens:
		if t and t.is_valid():
			t.kill()
	_hit_reaction_tweens.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_visual_root = null
	_hp_bar_fg = null
	_hp_bar_bg = null
	_anim_player = null
	_formation_players.clear()
	idle_animation = DEFAULT_ANIMATION
	moving_animation = WALK_ANIMATION
	attack_animation = ""
	_marker_height = HP_BAR_Y
	unit_data = new_data
	_build_visual()
	set_hp_silent(minf(new_data.max_hp, hp_fraction * new_data.max_hp))
	refresh_technique_marker()

const TECHNIQUE_MARKER_NAME := "V2TechniqueMarker"
const TECHNIQUE_MARKER_COLOR := Color(0.55, 0.95, 1.0, 0.95)

## Anel azul na base enquanto a unidade tem uma Técnica Militar de Doutrina ATIVA
## (V2TechniqueRuntime) — feedback mínimo no mapa, sem asset novo. Idempotente: chame
## depois de ativar/expirar, de restaurar um save e de trocar de forma.
func refresh_technique_marker() -> void:
	var existing := get_node_or_null(TECHNIQUE_MARKER_NAME)
	# Fase 17: o MESMO anel marca um estado de feitiço V2 ativo (Égide Sagrada) — sem asset novo.
	var active := V2TechniqueRuntime.active_technique_name(self) != "" or V2MagicRuntime.active_status_name(self) != ""
	if active and existing == null:
		var ring := MeshInstance3D.new()
		ring.name = TECHNIQUE_MARKER_NAME
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.43
		mesh.outer_radius = 0.62
		ring.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TECHNIQUE_MARKER_COLOR
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		ring.position.y = 0.11
		add_child(ring)
	elif not active and existing != null:
		remove_child(existing)
		existing.queue_free()

const COMMAND_MARKER_NAME := "V2UncommandedMarker"
## Cinza neutro de propósito: não confunde com o ciano de Técnica/Égide nem com vermelho/verde de mira.
const COMMAND_MARKER_COLOR := Color(0.62, 0.62, 0.66, 0.95)

## Fase 19 — anel cinza (maior que o de Técnica) enquanto esta retinue está SEM COMANDO. Idempotente; quem
## decide é V2RetinueSystem.refresh_markers (o estado é derivado, nunca guardado aqui).
func refresh_command_marker(uncommanded: bool) -> void:
	var existing := get_node_or_null(COMMAND_MARKER_NAME)
	if uncommanded and existing == null:
		var ring := MeshInstance3D.new()
		ring.name = COMMAND_MARKER_NAME
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.66
		mesh.outer_radius = 0.78
		ring.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COMMAND_MARKER_COLOR
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		ring.position.y = 0.12
		add_child(ring)
	elif not uncommanded and existing != null:
		remove_child(existing)
		existing.queue_free()

## Fase 19 — HELPER GENÉRICO de "esta unidade pode receber ordens agora?" (mover, atacar, agir). Hoje compõe só o
## estado de retinue (V2RetinueSystem.is_commanded, caminho rápido true para quem não é retinue); futuros bloqueios
## entram aqui, não em HUD/SelectionManager/CombatResolver separadamente. Defender/retaliar NÃO passa por aqui.
func can_receive_orders() -> bool:
	return V2RetinueSystem.is_commanded(self)

## O motivo (uma frase) de can_receive_orders() ser false, ou "".
func order_block_reason() -> String:
	return "" if can_receive_orders() else V2RetinueSystem.uncommanded_reason(self)

## Chamado por CombatResolver quando esta unidade vence um combate (mata o
## alvo, ou sobrevive ao contra-ataque de quem morreu tentando mata-la).
## Cura uma fracao do HP maximo so quando sobe de nivel de verdade — nao
## em todo kill, senao viraria um jeito facil demais de curar sem recuar.
## world_event_managed (Dragao de DragonEvent, ver comentario do campo
## abaixo): pedido explicito do usuario apos playtest -- "parece que o
## dragao tem regeneracao de vida... causei 1 de dano nele, e ele se curou
## quando foi pra outra cidade". Bug real: register_kill() cura uma fracao
## do HP MAXIMO a cada promocao de veterania (linha abaixo), e nada aqui
## excluia o Dragao disso -- cada unidade fraca que ele matava em combate
## normal (CombatResolver.resolve/resolve_with_splash, attacker.register_
## kill()) podia cruzar um limiar de kills e curar a vida de volta. Um
## boss scriptado (stats fixos em MonsterDatabase, nunca deveria "subir de
## nivel" como uma unidade normal) -- nunca acumula kills/veterania nem
## cura por promocao.
func register_kill() -> void:
	if world_event_managed:
		return
	kills += 1
	var new_level = _level_for_kills(kills)
	if new_level > veterancy_level:
		veterancy_level = new_level
		hp = min(hp + unit_data.max_hp * PROMOTION_HEAL_FRACTION, unit_data.max_hp)

static func _level_for_kills(k: int) -> int:
	var level := 0
	for i in range(VETERANCY_KILL_THRESHOLDS.size()):
		if k >= VETERANCY_KILL_THRESHOLDS[i]:
			level = i
	return level

func veterancy_title() -> String:
	return VETERANCY_TITLES[veterancy_level]

## Multiplica ataque E defesa igualmente (CombatResolver.predict()) — uma
## unidade veterana e melhor nos dois papeis, nao so atacando.
func veterancy_multiplier() -> float:
	return 1.0 + veterancy_level * VETERANCY_BONUS_PER_LEVEL

## Fila de trechos (um Vector3 por tile) ainda por animar — ver walk_path()
## abaixo. Existe pra resolver o bug reportado pelo usuario: "se ele vai
## andar 3 tiles ele desliza pro terceiro [quase instantaneo]", que tinha
## DUAS causas na mesma familia: (1) HexGrid.move_unit podia ser chamado
## com um `dest` a varios tiles de distancia numa unica tacada (clique num
## tile alcancavel do turno, ou a IA escolhendo o melhor tile reachable) e
## so animava um unico salto reto ate o destino final, pulando os tiles do
## meio; (2) HexGrid.continue_move_order chama move_unit uma vez POR TILE
## de um trajeto de varios tiles no MESMO turno, tudo na MESMA frame — cada
## chamada antiga criava um Tween NOVO competindo pela propriedade
## "position" antes do anterior sequer ter processado um frame, entao so o
## ULTIMO tween criado aparecia visualmente (mesmo efeito liquido: pula
## direto pro tile final). Uma fila resolve as duas: qualquer chamada nova
## so ENFILEIRA trechos, nunca cria um Tween concorrente — um unico "motor"
## (_advance_walk_queue) consome a fila um trecho de cada vez, entao andar
## N tiles agora sempre demora N * MOVE_DURATION de verdade, nao importa se
## vieram de uma chamada so (com N pontos) ou de N chamadas separadas.
var _walk_queue: Array[Vector3] = []
var _walking: bool = false

## Anima a posicao por UM UNICO trecho ate `target_pos` — atalho pra
## walk_path() com uma lista de um elemento so, pra quem so precisa mover
## um tile (ver walk_path() pro caso geral de varios tiles em sequencia).
func slide_to(target_pos: Vector3) -> void:
	walk_path([target_pos])

## Anima a posicao atravessando CADA ponto de `waypoints` em sequencia real
## (nunca todos de uma vez) e vira a unidade de frente pra direcao de cada
## trecho. Puramente visual — quem chama isso (HexGrid.move_unit) ja
## atualizou coord/ocupacao na hora. Chamadas repetidas (mesmo na mesma
## frame, ver _walk_queue acima) se acumulam na fila em vez de brigar por
## um Tween so.
func walk_path(waypoints: Array[Vector3]) -> void:
	if waypoints.is_empty():
		return
	# create_tween() exige a unidade estar dentro da SceneTree (ex: testes
	# GUT que criam Unit/HexGrid isolados, sem add_child). Sem isso o jogo
	# de verdade nunca chama walk_path fora da arvore, mas nao custa nada
	# nao quebrar se acontecer — so pula a animacao e teletransporta direto
	# pro ULTIMO ponto.
	if not is_inside_tree():
		var final_pos: Vector3 = waypoints[-1]
		var direction = final_pos - position
		direction.y = 0.0
		position = final_pos
		if direction.length() > 0.05:
			rotation.y = atan2(direction.x, direction.z)
		return

	_walk_queue.append_array(waypoints)
	if _walking:
		return # ja tem um _advance_walk_queue rodando, ele vai pegar isso sozinho
	_walking = true
	_play_animation(moving_animation) # pedido do usuario: "os mobs nao tem animacao de andando?"
	_advance_walk_queue()

## "Motor" que consome _walk_queue um trecho de cada vez -- so este metodo
## cria Tween novo, entao nunca ha dois Tweens de "position" competindo na
## mesma unidade.
func _advance_walk_queue() -> void:
	if _walk_queue.is_empty():
		_walking = false
		_play_animation(idle_animation)
		return
	var target_pos: Vector3 = _walk_queue.pop_front()
	var direction = target_pos - position
	direction.y = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE)
	if direction.length() > 0.05:
		var target_angle = atan2(direction.x, direction.z)
		tween.tween_property(self, "rotation:y", target_angle, MOVE_DURATION * 0.6)
	tween.finished.connect(_advance_walk_queue)

## Envolve SO o corpo (modelo externo OU geometria procedural, o que quer
## que _build_procedural_body tenha acabado de montar) numa Node3D
## dedicada, ANTES de construir base/barra de vida/icone -- ver
## _play_hit_reaction abaixo, que anima a posicao LOCAL e o material_
## overlay de tudo dentro de _visual_root. Sem este wrapper, a reacao de
## dano teria que mexer em `self.position`/`self.rotation` diretamente,
## que ja pertencem ao sistema de movimento (walk_path/_advance_walk_
## queue) -- dois Tweens brigando pela MESMA propriedade e exatamente o
## bug que acabamos de corrigir pro movimento (ver comentario de
## _walk_queue). Reparentar DEPOIS de construir (em vez de mudar toda
## _build_procedural_body/_build_model_body pra receber um `parent`
## explicito) evita tocar as dezenas de add_child() espalhados por elas --
## `reparent(_visual_root, false)` preserva o transform LOCAL de cada
## filho ja construido (relativo a `self`), e como _visual_root nasce na
## origem sem rotacao/escala, o transform GLOBAL de cada parte nao muda
## nem um pixel.
var _visual_root: Node3D
var _marker_height: float = HP_BAR_Y

func _build_visual() -> void:
	_build_procedural_body()
	var bounds = _model_aabb(self)
	if bounds != null:
		_marker_height = maxf(HP_BAR_Y, bounds.end.y + 0.12)
	if unit_data.is_caster():
		_build_school_emblem()
	_visual_root = Node3D.new()
	add_child(_visual_root)
	move_child(_visual_root, 0)
	for child in get_children():
		if child != _visual_root:
			child.reparent(_visual_root, false)
	if unit_data.visual_template != "":
		_visual_root.scale = Vector3.ONE * unit_data.model_scale_multiplier # distingue as formas que compartilham o mesmo corpo procedural
	_build_base_disc()
	_build_hp_bar()
	_build_troop_icon()

## Material overlay compartilhado (uma unica instancia pra TODA unidade do
## jogo, criado uma vez so) -- GeometryInstance3D.material_overlay desenha
## uma passada extra POR CIMA do material original de cada MeshInstance3D,
## entao funciona identico em cima de qualquer material (corpo procedural
## com StandardMaterial3D por caixa, .glb da KayKit, .glb da Asset Factory)
## sem precisar conhecer/trocar o material de base de ninguem.
static var _hit_flash_material: StandardMaterial3D

static func _get_hit_flash_material() -> StandardMaterial3D:
	if _hit_flash_material == null:
		_hit_flash_material = StandardMaterial3D.new()
		_hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hit_flash_material.albedo_color = Color(1.0, 0.08, 0.08, 0.7)
		_hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _hit_flash_material

const HIT_HOP_HEIGHT := 0.12
const HIT_HOP_UP_DURATION := 0.10
const HIT_HOP_DOWN_DURATION := 0.16
const HIT_FLASH_ON_DURATION := 0.08
const HIT_FLASH_OFF_DURATION := 0.05

## Tweens da reacao de dano em andamento (pulo + pisca) -- rastreados juntos
## pra uma nova batida (ex: contra-ataque no mesmo turno) sempre MATAR
## qualquer um ainda rodando antes de comecar de novo, em vez de dois
## Tweens brigando pela mesma propriedade (mesma familia do bug de
## movimento corrigido antes -- ver _walk_queue).
var _hit_reaction_tweens: Array[Tween] = []

## Reacao visual "eu tomei um golpe" (pedido do usuario, ver o comentario
## do setter de hp acima): pisca vermelho + uma puladinha, os dois
## puramente cosmeticos sobre _visual_root -- nunca tocam unit.position/
## rotation (usados por hex-grid/movimento) nem unit.hp (ja mudou antes
## desta chamada, ver o setter). Funciona em QUALQUER tipo de modelo
## (procedural, KayKit, Asset Factory) porque so usa material_overlay e a
## posicao local do wrapper, nunca o material/geometria de base de
## ninguem.
func _play_hit_reaction() -> void:
	if not is_inside_tree() or _visual_root == null:
		return
	for t in _hit_reaction_tweens:
		if t and t.is_valid():
			t.kill()
	_hit_reaction_tweens.clear()

	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(_visual_root, meshes)
	for m in meshes:
		m.material_overlay = null # limpa resto de um flash anterior interrompido

	_visual_root.position.y = 0.0
	var hop_tween := create_tween()
	hop_tween.tween_property(_visual_root, "position:y", HIT_HOP_HEIGHT, HIT_HOP_UP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(_visual_root, "position:y", 0.0, HIT_HOP_DOWN_DURATION).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_hit_reaction_tweens.append(hop_tween)

	var flash_mat := _get_hit_flash_material()
	var flash_tween := create_tween()
	flash_tween.tween_callback(_set_mesh_overlay.bind(meshes, flash_mat))
	flash_tween.tween_interval(HIT_FLASH_ON_DURATION)
	flash_tween.tween_callback(_set_mesh_overlay.bind(meshes, null))
	flash_tween.tween_interval(HIT_FLASH_OFF_DURATION)
	flash_tween.tween_callback(_set_mesh_overlay.bind(meshes, flash_mat))
	flash_tween.tween_interval(HIT_FLASH_ON_DURATION)
	flash_tween.tween_callback(_set_mesh_overlay.bind(meshes, null))
	_hit_reaction_tweens.append(flash_tween)

static func _set_mesh_overlay(meshes: Array[MeshInstance3D], mat: StandardMaterial3D) -> void:
	for m in meshes:
		if is_instance_valid(m):
			m.material_overlay = mat

func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)

## Cor do corpo/base de uma unidade: cor da civilizacao pro jogador, ou —
## pra monstro neutro (owner_player == null) — a cor FIXA do proprio tipo
## (MONSTER_KIND_COLORS), caindo no vermelho-sangue generico (MONSTER_
## COLOR) so se o visual_kind nao tiver entrada la (unidade neutra futura
## sem cor propria ainda definida).
func _body_color() -> Color:
	if owner_player:
		return owner_player.civ.color
	return MONSTER_KIND_COLORS.get(unit_data.visual_kind, MONSTER_COLOR)

## Acessorio de assinatura do "kit de estilo" racial (RaceTheme) pras 4
## tropas comuns do ramo militar (men_at_arms/cavalry/archer/scout) —
## reaproveita literalmente o MESMO padrao de mesh ja usado na tropa
## exclusiva daquela raca (branches "dwarf_axeguard"/"orc_berserker"/
## "elf_ranger" mais abaixo neste arquivo) em vez de desenhar geometria
## nova so pra essa reskin (pedido do usuario, escopo confirmado como
## "kit de estilo": mesma silhueta base + paleta + 1-2 detalhes de
## assinatura). Sem-efeito pra "human" (ou qualquer raca desconhecida) de
## proposito — nenhum `match` bate, entao o chamador continua desenhando a
## arma padrao dele sozinho. `anchor` e o ponto local (relativo a `root`)
## onde pendurar a arma.
func _attach_race_signature_weapon(root: Node3D, race: String, kit: Dictionary, anchor: Vector3) -> void:
	match race:
		"dwarf":
			var handle := MeshInstance3D.new()
			var handle_mesh := CylinderMesh.new()
			handle_mesh.top_radius = 0.025
			handle_mesh.bottom_radius = 0.025
			handle_mesh.height = 0.42
			handle.mesh = handle_mesh
			var handle_mat := StandardMaterial3D.new()
			handle_mat.albedo_color = Color(0.4, 0.28, 0.18)
			handle.material_override = handle_mat
			handle.position = anchor
			root.add_child(handle)

			var head := MeshInstance3D.new()
			var head_mesh := PrismMesh.new()
			head_mesh.size = Vector3(0.14, 0.15, 0.035)
			head.mesh = head_mesh
			var head_mat := StandardMaterial3D.new()
			head_mat.albedo_color = kit.metal_color
			head.material_override = head_mat
			head.position = anchor + Vector3(0.0, 0.2, 0.0)
			root.add_child(head)
		"orc":
			var club := MeshInstance3D.new()
			var club_mesh := BoxMesh.new()
			club_mesh.size = Vector3(0.08, 0.4, 0.08)
			club.mesh = club_mesh
			var club_mat := StandardMaterial3D.new()
			club_mat.albedo_color = Color(0.32, 0.24, 0.16)
			club.material_override = club_mat
			club.position = anchor
			club.rotation_degrees = Vector3(0, 0, -18)
			root.add_child(club)
		"elf":
			var bow := MeshInstance3D.new()
			var bow_mesh := CylinderMesh.new()
			bow_mesh.top_radius = 0.015
			bow_mesh.bottom_radius = 0.015
			bow_mesh.height = 0.42
			bow.mesh = bow_mesh
			var bow_mat := StandardMaterial3D.new()
			bow_mat.albedo_color = kit.metal_color
			bow.material_override = bow_mat
			bow.position = anchor
			bow.rotation_degrees = Vector3(0, 0, 12)
			root.add_child(bow)

## Nomes dos clipes usados aqui — todo pacote KayKit Character Animations
## reaproveitado nesta sessao (Rig_Medium_General.glb/Rig_Medium_
## MovementBasic.glb) tem os dois. Sem selecao de combate ainda (fica pra
## depois — ataque/morte tem clipe pronto no pacote, so falta ligar).
const DEFAULT_ANIMATION := "Idle_A"
const WALK_ANIMATION := "Walking_A"

## Clipes de fato tocados por slide_to() abaixo -- campos DE INSTANCIA
## (nao as constantes direto) pra uma unidade poder trocar seu proprio
## "andar"/"parado" sem precisar mexer em slide_to(). Default = as MESMAS
## constantes de sempre, ZERO mudanca de comportamento pra qualquer
## unidade existente. Roadmap "Dragon Event v1 fechado" -- unico uso ate
## agora: DragonEvent troca pra "Fly" enquanto travel_mode == FLYING
## (pedido explicito do usuario, animacao de bater asas durante o voo),
## sem duplicar/reescrever a logica de troca de animacao em si.
var moving_animation: String = WALK_ANIMATION
var idle_animation: String = DEFAULT_ANIMATION

## "" ate hoje pra toda unidade (combate normal, CombatResolver.gd, nao
## toca nenhuma animacao ainda) -- so o Dragao usa "Attack" hoje, tocado
## manualmente por DragonEvent.gd. Unidades com UnitData.
## attack_animation_override ganham esse nome aqui em _build_model_body(),
## prontas pro dia que o combate normal tambem chamar _play_animation().
var attack_animation: String = ""

## Segunda cena de animacao, sempre reaproveitada JUNTO da de UnitData.
## animation_scene_path (General) pra fechar Idle+Andar — mesmo rig
## compartilhado entre os dois arquivos e entre todo personagem/esqueleto
## usado nesta sessao (confirmado nome a nome de osso antes de escrever
## isto). Vira campo proprio em UnitData so se algum dia existir uma
## unidade animada com um rig DIFERENTE (ex: "Rig_Large").
const WALK_ANIMATION_SCENE := "res://assets/models/kaykit/animations/Rig_Medium_MovementBasic.glb"

## AnimationPlayer construido em _build_model_body(), guardado aqui pra
## slide_to() poder trocar entre Idle/Andar sem precisar buscar na arvore
## de novo a cada passo. null pra qualquer unidade sem model_scene_path/
## animation_scene_path (corpo procedural, ou modelo sem animacao).
var _anim_player: AnimationPlayer

## Altura-alvo (em unidades de mundo) pra qualquer modelo KayKit carregado
## aqui — pedido do usuario apos ver o resultado ("como fazer isso ficar
## mais bonito e organizado"): os personagens vem na escala "real" do
## pacote (tamanho humano de verdade), bem maior que o corpo procedural que
## substituem (ex: CapsuleMesh do Guarda tem 0.68 de altura). 0.7 casa com
## essa escala antiga, e fica confortavelmente MENOR que qualquer predio ja
## reescalado (ver Building.KAYKIT_SCALE — o menor predio do pack fica em
## ~0.85 de altura depois de escalado, o maior em ~2.1).
##
## Por que ALTURA-ALVO por modelo (normaliza cada personagem pra 0.7) em vez
## do MESMO fator de escala global usado nos predios (Building.KAYKIT_
## SCALE, derivado do proprio tile hexagonal do pacote): tile e predio sao
## geometria "morta" (sem esqueleto), entao medir o bounding box crua e
## confiavel; personagem tem esqueleto/skinning, e o bind pose usado pro
## rig costuma abrir os bracos mais que uma pose de pe normal (bom pra
## pintar peso de esqueleto, ruim pra medir "altura de pe" direito) —
## medido nesta sessao, TODO personagem do pack (silhuetas bem diferentes:
## Barbaro/Cavaleiro/Mago/Ranger/Ladino) da a MESMA largura crua (~1.94),
## o que so faz sentido como artefato do bind pose, nao como medida real de
## corpo. Altura (Y) sofre menos com isso e ainda varia proporcionalmente
## entre os personagens, entao normalizar por ALTURA continua sendo a
## medida mais confiavel disponivel pra humanoide, mesmo sem um numero
## "global" tao solido quanto o dos predios.
const MODEL_TARGET_HEIGHT := 0.7

## Carrega uma cena externa (KayKit) como corpo da unidade em vez de montar
## geometria procedural — ver UnitData.model_scene_path. Reescala pra
## MODEL_TARGET_HEIGHT a partir do proprio bounding box do modelo (cada
## personagem do pack vem numa escala "real" ligeiramente diferente). NAO
## tinge o modelo pela cor da civilizacao (primeira versao multiplicava
## albedo_color por cima da textura pintada — tecnica de "atlas gradiente"
## da KayKit — e lavava tudo pra uma cor lisa, reportado pelo usuario: "ta
## todos sem texturas").
## Modelos gerados pela 3D Asset Factory (tools/asset_factory) SEMPRE
## salvam em res://assets/generated/ -- ao contrario do KayKit (pose de
## bind mais aberta que a de pe, escala "real" inconsistente entre
## personagens do pacote, ver MODEL_TARGET_HEIGHT acima), a Asset Factory
## e NOSSA: a altura de cada personagem ja e um parametro explicito
## (metros) no proprio preset JSON, com a MESMA convencao de unidade do
## hex_size do jogo, e o bind pose usado pra exportar e o rest pose de
## pe de verdade (sem esqueleto "em T" nem bracos abertos). Renormalizar
## esses pra MODEL_TARGET_HEIGHT via aabb.size.y so reintroduz o problema
## que esse sistema existe pra resolver -- e foi exatamente essa conta
## (aabb.size.y incluindo arma equipada, cada personagem com uma silhueta
## bem diferente) que rendeu Goblin/Esqueleto/Troll visivelmente maiores
## no jogo do que qualquer formula previa, sem causa raiz encontrada
## (pedido do usuario: "o caminho correto nao seria... deixar eles apenas
## com o tamanho do modelo 3d deles?" -- sim). Pulando a normalizacao
## pra esses: escala 1:1 direta (so multiplicada por model_scale_
## multiplier, que continua disponivel como ajuste fino manual, default
## 1.0 -- ver UnitData.gd).
const ASSET_FACTORY_PATH_PREFIX := "res://assets/generated/"

func _build_model_body() -> void:
	var scene: PackedScene = load(unit_data.model_scene_path)
	var model: Node3D = scene.instantiate()
	add_child(model)
	if unit_data.model_scene_path.begins_with(ASSET_FACTORY_PATH_PREFIX):
		model.scale = Vector3.ONE * unit_data.model_scale_multiplier
	else:
		var aabb = _model_aabb(model)
		if aabb != null and aabb.size.y > 0.0:
			model.scale = Vector3.ONE * (MODEL_TARGET_HEIGHT / aabb.size.y * unit_data.model_scale_multiplier)
	if unit_data.model_yaw_offset_degrees != 0.0:
		model.rotation.y += deg_to_rad(unit_data.model_yaw_offset_degrees)
	if unit_data.animation_scene_path != "":
		if unit_data.idle_animation_override != "":
			idle_animation = unit_data.idle_animation_override
		if unit_data.walk_animation_override != "":
			moving_animation = unit_data.walk_animation_override
		if unit_data.attack_animation_override != "":
			attack_animation = unit_data.attack_animation_override
		_anim_player = _build_animation_player(model)
		if _anim_player:
			_anim_player.play(idle_animation)
	_build_formation_copies(model)

## Fase 19 — Hostes: `model_formation_count` > 1 repete o corpo em volta do centro do tile, como MALHA filha
## desta mesma Unit (nenhuma lógica/HP/seleção individual). O corpo principal vai para o primeiro posto.
## Cada cópia toca o próprio Idle (sem ela a cópia ficaria em bind pose); só o principal anda/ataca.
const FORMATION_RADIUS := 0.34
var _formation_players: Array[AnimationPlayer] = []

func _build_formation_copies(main_model: Node3D) -> void:
	var count := unit_data.model_formation_count
	if count <= 1:
		return
	var scene: PackedScene = load(unit_data.model_scene_path)
	for i in count:
		var angle := TAU * float(i) / float(count) + PI / 6.0
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * FORMATION_RADIUS
		if i == 0:
			main_model.position += offset
			continue
		var copy: Node3D = scene.instantiate()
		copy.name = "FormationBody%d" % i
		copy.scale = main_model.scale
		copy.rotation = main_model.rotation
		copy.position = offset
		add_child(copy)
		if unit_data.animation_scene_path != "":
			var player := _build_animation_player(copy)
			if player:
				player.play(idle_animation)
				_formation_players.append(player)

## Bounding box combinado de toda malha dentro de `node`, em espaco LOCAL a
## `node` (nao depende da arvore de cena real). null se nao houver nenhum
## MeshInstance3D com malha valida. Building.gd NAO usa mais este mesmo
## esquema (ver Building.KAYKIT_SCALE e o comentario de MODEL_TARGET_HEIGHT
## acima pro motivo) — helper especifico desta classe.
func _model_aabb(node: Node, xform: Transform3D = Transform3D.IDENTITY):
	var result = null
	if node is MeshInstance3D and node.mesh:
		result = xform * node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_aabb = _model_aabb(child, xform * child.transform)
			if child_aabb != null:
				result = child_aabb if result == null else result.merge(child_aabb)
	return result

## Combina os clipes de DOIS pacotes de animacao (Idle vindo de UnitData.
## animation_scene_path + Andar vindo de WALK_ANIMATION_SCENE) numa UNICA
## AnimationLibrary — cada arquivo KayKit exporta a propria biblioteca com
## nome "" (padrao), entao dar add_animation_library() direto pros dois
## colidiria (nome duplicado); copiar as Animation individuais pra uma
## library nova e o jeito de somar os dois sem esse conflito. Funciona
## porque o pacote de animacoes usa os MESMOS nomes de osso do pacote de
## personagens (mesmo rig, confirmado antes de escrever isto), entao as
## trilhas resolvem certo contra o Skeleton3D de `model` sem precisar
## reexportar/retarget nada manualmente.
func _build_animation_player(model: Node) -> AnimationPlayer:
	var library := AnimationLibrary.new()
	_copy_animations_into(library, unit_data.animation_scene_path)
	if unit_data.merge_shared_walk_animation:
		_copy_animations_into(library, WALK_ANIMATION_SCENE)
	if library.get_animation_list().is_empty():
		return null
	# glTF nao carrega "isso deve repetir" -- o importador da Godot sempre
	# cria a Animation com loop_mode = NONE, entao Idle/Andar "travam" no
	# ultimo frame apos um unico ciclo sem isso. So idle_animation/
	# moving_animation (ja resolvidos pros nomes certos em _build_model_
	# body(), antes desta chamada) -- Ataque/Morte ficam LOOP_NONE de
	# proposito, tocam uma vez so.
	for loop_anim_name in [idle_animation, moving_animation]:
		if library.has_animation(loop_anim_name):
			library.get_animation(loop_anim_name).loop_mode = Animation.LOOP_LINEAR
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.add_animation_library("", library)
	return player

func _copy_animations_into(library: AnimationLibrary, scene_path: String) -> void:
	var anim_scene: PackedScene = load(scene_path)
	var anim_source := anim_scene.instantiate()
	var source_player := _find_animation_player(anim_source)
	if source_player:
		for lib_name in source_player.get_animation_library_list():
			var source_lib := source_player.get_animation_library(lib_name)
			for anim_name in source_lib.get_animation_list():
				if not library.has_animation(anim_name):
					library.add_animation(anim_name, source_lib.get_animation(anim_name))
	anim_source.free()

## Troca pro clipe `anim_name` so se a unidade tiver AnimationPlayer, o
## clipe existir, e nao for o que ja esta tocando (evita reiniciar o ciclo
## de Idle toda vez que um slide_to() termina enquanto ja estava parada).
func _play_animation(anim_name: String) -> void:
	if _anim_player and _anim_player.has_animation(anim_name) and _anim_player.current_animation != anim_name:
		_anim_player.play(anim_name)
	for player in _formation_players: # Fase 19: a formação da Hoste anda/ataca junto (só visual)
		if is_instance_valid(player) and player.has_animation(anim_name) and player.current_animation != anim_name:
			player.play(anim_name)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

## Formas proceduras simples, cada uma com silhueta diferente pra dar pra
## reconhecer o tipo de unidade a distancia mesmo sem textura/detalhe.
func _build_procedural_body() -> void:
	# Identidade visual nova (pedido do usuario, ver UnitData.model_scene_
	# path) — se a tropa tiver um modelo externo definido, usa ele em vez
	# do resto desta funcao. "" (a maioria ainda hoje) continua no corpo
	# procedural de sempre.
	if unit_data.model_scene_path != "":
		_build_model_body()
		return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _body_color()

	# Raca do dono (ou "human" pra monstro/settler/etc sem dono) e o kit de
	# estilo dela (RaceTheme.style_kit) — so as 4 tropas comuns do ramo
	# militar (men_at_arms/cavalry/archer/scout, ver blocos abaixo) de fato
	# consultam isso; pro resto do match e computado a toa mas e barato (so
	# leitura de Dictionary ja cacheado) e evita recalcular em cada branch.
	var race := owner_player.civ.race if owner_player else "human"
	var kit := RaceTheme.style_kit(race)

	# `visual_template` (Fase 9): uma unidade V2 pode reaproveitar o corpo procedural de um visual V1 ("cavalry", "griffin"...).
	match unit_data.visual_template if unit_data.visual_template != "" else unit_data.visual_kind:
		"settler":
			var body := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.3
			mesh.height = 0.6
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.35
			add_child(body)
		"warrior":
			# Guarda basico (tropa inicial, sempre disponivel sem predio
			# nenhum — pedido do usuario: "crie uma representação do
			# personagem que combine mais com o guarda ao invés de ser um
			# cilindro"). Antes caia no fallback generico (so uma capsula
			# nua, sem arma nem escudo) — agora tem silhueta propria de
			# "infantaria de guarda": corpo + espada erguida + escudo com a
			# cor da propria civilizacao (mesmo espirito do cavaleiro
			# comum, que tinge o cavaleiro mas nao o cavalo).
			#
			# Kit de estilo racial aplicado aqui tambem (pedido do usuario,
			# rodada seguinte: "ta vindo ainda o guarda padrao quando
			# escolho outra civilização, sendo que era pra vir a tropa
			# basica de cada civilização, o guarda é a tropa basica
			# humana") — mesmo padrao ja usado em "men_at_arms" abaixo:
			# raiz escalada + arma de assinatura reaproveitada da tropa
			# exclusiva da raca no lugar da espada padrao.
			var root := Node3D.new()
			root.scale = kit.scale
			add_child(root)

			var body := MeshInstance3D.new()
			var body_mesh := CapsuleMesh.new()
			body_mesh.radius = 0.19
			body_mesh.height = 0.68
			body.mesh = body_mesh
			body.material_override = mat
			body.position.y = 0.38
			root.add_child(body)

			if race == "dwarf" or race == "orc" or race == "elf":
				_attach_race_signature_weapon(root, race, kit, Vector3(0.22, 0.64, 0.0))
			else:
				var sword := MeshInstance3D.new()
				var sword_mesh := PrismMesh.new()
				sword_mesh.size = Vector3(0.05, 0.5, 0.02)
				sword.mesh = sword_mesh
				var sword_mat := StandardMaterial3D.new()
				sword_mat.albedo_color = kit.metal_color # aco/bronze/ferro/dourado conforme a raca (RaceTheme.STYLE_KITS)
				sword.material_override = sword_mat
				sword.position = Vector3(0.22, 0.64, 0.0)
				sword.rotation_degrees = Vector3(0, 0, 12)
				root.add_child(sword)

			var shield := MeshInstance3D.new()
			var shield_mesh := CylinderMesh.new()
			shield_mesh.top_radius = 0.16
			shield_mesh.bottom_radius = 0.16
			shield_mesh.height = 0.04
			shield.mesh = shield_mesh
			var shield_mat := StandardMaterial3D.new()
			shield_mat.albedo_color = owner_player.civ.color.darkened(0.2) # escudo com o brasao/cor do reino, mesmo espirito do cavaleiro tingido na Cavalaria comum
			shield.material_override = shield_mat
			shield.position = Vector3(-0.2, 0.42, 0.05)
			shield.rotation_degrees = Vector3(90, 0, 90)
			root.add_child(shield)
		"men_at_arms":
			# Homem de Armas (segunda tropa humana, so treinavel apos a tech
			# "Quartel" — ver TechDatabase/UnitDatabase). Precisa ler como um
			# "upgrade" do Guarda a distancia: corpo mais largo (mais
			# blindado), elmo (o Guarda nao tem), e um escudo RETANGULAR
			# (tipo torre) em vez do escudo redondo do Guarda — silhueta
			# claramente mais pesada/profissional, nao so uma reskin.
			# Raiz escalada pelo kit de estilo racial (RaceTheme) — anao mais
			# atarracado, orc mais bruto, elfo mais esguio — sem afetar barra
			# de vida/icone de tropa, que continuam filhos diretos da unidade
			# (ver _build_visual).
			var root := Node3D.new()
			root.scale = kit.scale
			add_child(root)

			var body := MeshInstance3D.new()
			var body_mesh := CapsuleMesh.new()
			body_mesh.radius = 0.22
			body_mesh.height = 0.7
			body.mesh = body_mesh
			body.material_override = mat
			body.position.y = 0.4
			root.add_child(body)

			var helmet := MeshInstance3D.new()
			var helmet_mesh := SphereMesh.new()
			helmet_mesh.radius = 0.13
			helmet_mesh.height = 0.26
			helmet.mesh = helmet_mesh
			var helmet_mat := StandardMaterial3D.new()
			helmet_mat.albedo_color = kit.metal_color # aco/bronze/ferro/dourado conforme a raca (RaceTheme.STYLE_KITS)
			helmet.material_override = helmet_mat
			helmet.position.y = 0.84
			root.add_child(helmet)

			# Arma de assinatura: anao/orc/elfo trocam a espada padrao pelo
			# acessorio reaproveitado da propria tropa exclusiva deles (ver
			# _attach_race_signature_weapon); humano (ou raca desconhecida)
			# mantem a espada de sempre.
			if race == "dwarf" or race == "orc" or race == "elf":
				_attach_race_signature_weapon(root, race, kit, Vector3(0.25, 0.68, 0.0))
			else:
				var sword := MeshInstance3D.new()
				var sword_mesh := PrismMesh.new()
				sword_mesh.size = Vector3(0.06, 0.55, 0.025)
				sword.mesh = sword_mesh
				var sword_mat := StandardMaterial3D.new()
				sword_mat.albedo_color = kit.metal_color
				sword.material_override = sword_mat
				sword.position = Vector3(0.25, 0.68, 0.0)
				sword.rotation_degrees = Vector3(0, 0, 12)
				root.add_child(sword)

			var shield := MeshInstance3D.new()
			var shield_mesh := BoxMesh.new() # painel reto/alto, contraste de proposito com o escudo redondo do Guarda
			shield_mesh.size = Vector3(0.05, 0.42, 0.22)
			shield.mesh = shield_mesh
			var shield_mat := StandardMaterial3D.new()
			shield_mat.albedo_color = owner_player.civ.color.darkened(0.15)
			shield.material_override = shield_mat
			shield.position = Vector3(-0.25, 0.42, 0.0)
			root.add_child(shield)
		"archer":
			var root := Node3D.new()
			root.scale = kit.scale
			add_child(root)

			var body := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.04
			mesh.bottom_radius = 0.17
			mesh.height = 0.8
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.42
			root.add_child(body)

			_attach_race_signature_weapon(root, race, kit, Vector3(-0.16, 0.5, -0.05))
		"cavalry":
			# A montaria continua tingida na cor da civ (mat), igual sempre —
			# o kit de estilo racial so muda a montaria de FALTA de cor fixa
			# (ver "scout" abaixo, cuja montaria e uma cor fixa) e escala/
			# acessorio, nunca a cor primaria de ownership.
			var root := Node3D.new()
			root.scale = kit.scale
			add_child(root)

			var horse := MeshInstance3D.new()
			var horse_mesh := BoxMesh.new()
			horse_mesh.size = Vector3(0.55, 0.32, 0.28)
			horse.mesh = horse_mesh
			horse.material_override = mat
			horse.position.y = 0.28
			root.add_child(horse)

			var rider := MeshInstance3D.new()
			var rider_mesh := CapsuleMesh.new()
			rider_mesh.radius = 0.12
			rider_mesh.height = 0.4
			rider.mesh = rider_mesh
			var rider_mat := StandardMaterial3D.new()
			rider_mat.albedo_color = owner_player.civ.color.darkened(0.25)
			rider.material_override = rider_mat
			rider.position = Vector3(0.05, 0.55, 0.0)
			root.add_child(rider)

			_attach_race_signature_weapon(root, race, kit, Vector3(0.22, 0.68, 0.0))
		"scout":
			# Batedor (Estabulo, tech "Batedor Montado") — leitura de
			# "cavalaria LEVE": cavalo menor e SEM tingir na cor da civ
			# (mesmo espirito do Cavaleiro Real, "nao e um cavalo de
			# guerra"), cavaleiro pequeno tingido na civ (pra ownership
			# continuar legivel), SEM arma nenhuma (nem lanca, nem espada,
			# nem arco) — so um alforje/trouxa nas costas, silhueta de
			# "viaja rapido e leve", distinta o bastante do Cavaleiro
			# comum/Cavaleiro Real a distancia.
			var root := Node3D.new()
			root.scale = kit.scale
			add_child(root)

			var horse := MeshInstance3D.new()
			var horse_mesh := BoxMesh.new()
			horse_mesh.size = Vector3(0.42, 0.24, 0.2)
			horse.mesh = horse_mesh
			var horse_mat := StandardMaterial3D.new()
			horse_mat.albedo_color = kit.mount_color # pelagem fixa (nao tingida pela civ) — so muda de tom por raca
			horse.material_override = horse_mat
			horse.position.y = 0.22
			root.add_child(horse)

			var rider := MeshInstance3D.new()
			var rider_mesh := CapsuleMesh.new()
			rider_mesh.radius = 0.09
			rider_mesh.height = 0.32
			rider.mesh = rider_mesh
			var rider_mat := StandardMaterial3D.new()
			rider_mat.albedo_color = owner_player.civ.color.darkened(0.15)
			rider.material_override = rider_mat
			rider.position = Vector3(0.03, 0.42, 0.0)
			root.add_child(rider)

			var pack := MeshInstance3D.new()
			var pack_mesh := SphereMesh.new()
			pack_mesh.radius = 0.06
			pack_mesh.height = 0.12
			pack.mesh = pack_mesh
			var pack_mat := StandardMaterial3D.new()
			pack_mat.albedo_color = Color(0.45, 0.36, 0.24)
			pack.material_override = pack_mat
			pack.position = Vector3(-0.1, 0.4, 0.0)
			root.add_child(pack)
			# Sem arma nenhuma de proposito, mesmo pras raças reskinadas — o
			# Batedor continua "so alforje/trouxa", silhueta de "viaja rapido
			# e leve" (ver comentario original acima), nao ganha o acessorio
			# de assinatura das outras 3 tropas do ramo militar.
		"catapult":
			var frame := MeshInstance3D.new()
			var frame_mesh := BoxMesh.new()
			frame_mesh.size = Vector3(0.6, 0.25, 0.4)
			frame.mesh = frame_mesh
			frame.material_override = mat
			frame.position.y = 0.2
			add_child(frame)

			var arm := MeshInstance3D.new()
			var arm_mesh := BoxMesh.new()
			arm_mesh.size = Vector3(0.08, 0.5, 0.08)
			arm.mesh = arm_mesh
			var arm_mat := StandardMaterial3D.new()
			arm_mat.albedo_color = owner_player.civ.color.darkened(0.3)
			arm.material_override = arm_mat
			arm.position = Vector3(-0.1, 0.5, 0.0)
			arm.rotation_degrees = Vector3(0, 0, -25)
			add_child(arm)
		"mage":
			var robe := MeshInstance3D.new()
			var robe_mesh := PrismMesh.new()
			robe_mesh.size = Vector3(0.4, 0.75, 0.4)
			robe.mesh = robe_mesh
			robe.material_override = mat
			robe.position.y = 0.38
			add_child(robe)

			var head := MeshInstance3D.new()
			var head_mesh := SphereMesh.new()
			head_mesh.radius = 0.14
			head_mesh.height = 0.28
			head.mesh = head_mesh
			var head_mat := StandardMaterial3D.new()
			head_mat.albedo_color = Color(0.85, 0.75, 0.6) # "pele" clara generica
			head.material_override = head_mat
			head.position.y = 0.85
			add_child(head)
		"goblin":
			# Esfera pequena verde — pedido do usuario: silhueta minima,
			# rasteira, facil de ler como "fraco" a distancia.
			var body := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.22
			mesh.height = 0.44
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.22
			add_child(body)
		"troll":
			# Cubo grande e largo cinza-rocha — pedido do usuario: silhueta
			# "atarracada"/pesada, oposto do resto do bestiario.
			var body := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.6, 0.85, 0.5)
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.42
			add_child(body)
		"skeleton":
			# Silhueta bem fina (mais magra que qualquer outro humanoide do
			# bestiario) branca/creme — pedido do usuario.
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.11
			mesh.height = 0.8
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.4
			add_child(body)
		"wyvern":
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.22
			mesh.height = 0.9
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.5
			add_child(body)
			# Duas "asas" (prismas achatados) inclinadas pra cima — silhueta
			# minima que ja basta pra ler "isso voa", sem precisar de rig.
			for side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var wing_mesh := PrismMesh.new()
				wing_mesh.size = Vector3(0.5, 0.05, 0.28)
				wing.mesh = wing_mesh
				wing.material_override = mat
				wing.position = Vector3(side * 0.32, 0.68, 0.0)
				wing.rotation_degrees = Vector3(0, 0, side * 35)
				add_child(wing)
		"dragon":
			# Roadmap "Dragon Event v1 fechado" -- pedido explicito do
			# usuario: "o sistema do Dragao ja esta bom o suficiente pra
			# merecer um Dragao de verdade... Aetherlands Low Poly Modular
			# -- primeiro prototipo do futuro sistema visual proprio do
			# jogo". Substitui a capsula+asas+cauda placeholder por um
			# corpo modular de verdade (ver _build_dragon_body abaixo) --
			# geometria cubica/prismatica simples de proposito (silhueta
			# forte, poucos materiais, nada de textura/realismo).
			_build_dragon_body(mat)
		"griffin":
			var body := MeshInstance3D.new()
			var body_mesh := CapsuleMesh.new()
			body_mesh.radius = 0.2
			body_mesh.height = 0.65
			body.mesh = body_mesh
			body.material_override = mat
			body.position = Vector3(0, 0.42, 0)
			body.rotation_degrees = Vector3(90, 0, 0) # deitado, tipo corpo de leao/aguia
			add_child(body)

			var head := MeshInstance3D.new()
			var head_mesh := PrismMesh.new()
			head_mesh.size = Vector3(0.16, 0.2, 0.16)
			head.mesh = head_mesh
			head.material_override = mat
			head.position = Vector3(0, 0.5, 0.3)
			head.rotation_degrees = Vector3(90, 0, 0)
			add_child(head)

			# Asas bem maiores que as do vivern — grifo e uma montaria nobre,
			# nao um monstro rasteiro, a silhueta precisa deixar isso claro.
			for side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var wing_mesh := PrismMesh.new()
				wing_mesh.size = Vector3(0.75, 0.06, 0.4)
				wing.mesh = wing_mesh
				wing.material_override = mat
				wing.position = Vector3(side * 0.4, 0.55, -0.05)
				wing.rotation_degrees = Vector3(0, 0, side * 40)
				add_child(wing)
		"treant", "woodland_beast":
			# Tronco na cor da civilizacao (mesmo padrao de "corpo principal"
			# de todo outro kind), folhagem sempre verde fixo — nao faz
			# sentido uma arvore ter folhas na cor do dono, so o "estandarte"
			# (aqui, o proprio tronco) precisa identificar de quem e.
			var trunk := MeshInstance3D.new()
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius = 0.12
			trunk_mesh.bottom_radius = 0.19
			trunk_mesh.height = 0.55
			trunk.mesh = trunk_mesh
			trunk.material_override = mat
			trunk.position.y = 0.28
			add_child(trunk)

			var foliage := MeshInstance3D.new()
			var foliage_mesh := SphereMesh.new()
			foliage_mesh.radius = 0.34
			foliage_mesh.height = 0.68
			foliage.mesh = foliage_mesh
			var foliage_mat := StandardMaterial3D.new()
			foliage_mat.albedo_color = Color(0.18, 0.42, 0.2)
			foliage.material_override = foliage_mat
			foliage.position.y = 0.75
			add_child(foliage)
		"human_knight":
			# Cavalo em tom natural (NAO tingido pela cor da civ, diferente
			# da Cavalaria comum) + cavaleiro na cor da civ + lanca erguida
			# com bandeirola dourada — leitura de "realeza"/nobreza,
			# silhueta distinta o bastante da Cavalaria comum (sem lanca)
			# pra nao confundir as duas na tela.
			var horse := MeshInstance3D.new()
			var horse_mesh := BoxMesh.new()
			horse_mesh.size = Vector3(0.58, 0.34, 0.28)
			horse.mesh = horse_mesh
			var horse_mat := StandardMaterial3D.new()
			horse_mat.albedo_color = Color(0.42, 0.28, 0.16)
			horse.material_override = horse_mat
			horse.position.y = 0.29
			add_child(horse)

			var rider := MeshInstance3D.new()
			var rider_mesh := CapsuleMesh.new()
			rider_mesh.radius = 0.13
			rider_mesh.height = 0.42
			rider.mesh = rider_mesh
			rider.material_override = mat
			rider.position = Vector3(0.05, 0.56, 0.0)
			add_child(rider)

			var lance := MeshInstance3D.new()
			var lance_mesh := CylinderMesh.new()
			lance_mesh.top_radius = 0.015
			lance_mesh.bottom_radius = 0.02
			lance_mesh.height = 0.6
			lance.mesh = lance_mesh
			var lance_mat := StandardMaterial3D.new()
			lance_mat.albedo_color = Color(0.6, 0.58, 0.5)
			lance.material_override = lance_mat
			lance.position = Vector3(0.2, 0.75, 0.0)
			lance.rotation_degrees = Vector3(0, 0, 15)
			add_child(lance)

			var pennant := MeshInstance3D.new()
			var pennant_mesh := PrismMesh.new()
			pennant_mesh.size = Vector3(0.14, 0.1, 0.02)
			pennant.mesh = pennant_mesh
			var pennant_mat := StandardMaterial3D.new()
			pennant_mat.albedo_color = Color(0.9, 0.75, 0.2)
			pennant.material_override = pennant_mat
			pennant.position = Vector3(0.28, 0.95, 0.0)
			pennant.rotation_degrees = Vector3(0, 0, 15)
			add_child(pennant)
		"dwarf_axeguard":
			# Baixo e largo (silhueta "atarracada" reconhecivel de longe,
			# oposto do humanoide alto e magro do padrao) + cabeca de
			# machado numa haste, cor do metal fixa independente do dono.
			var torso := MeshInstance3D.new()
			var torso_mesh := BoxMesh.new()
			torso_mesh.size = Vector3(0.34, 0.4, 0.24)
			torso.mesh = torso_mesh
			torso.material_override = mat
			torso.position.y = 0.24
			add_child(torso)

			var axe_handle := MeshInstance3D.new()
			var handle_mesh := CylinderMesh.new()
			handle_mesh.top_radius = 0.025
			handle_mesh.bottom_radius = 0.025
			handle_mesh.height = 0.55
			axe_handle.mesh = handle_mesh
			var handle_mat := StandardMaterial3D.new()
			handle_mat.albedo_color = Color(0.4, 0.28, 0.18)
			axe_handle.material_override = handle_mat
			axe_handle.position = Vector3(0.22, 0.45, 0.0)
			add_child(axe_handle)

			var axe_head := MeshInstance3D.new()
			var head_mesh := PrismMesh.new()
			head_mesh.size = Vector3(0.16, 0.18, 0.04)
			axe_head.mesh = head_mesh
			var head_mat := StandardMaterial3D.new()
			head_mat.albedo_color = Color(0.65, 0.66, 0.68)
			axe_head.material_override = head_mat
			axe_head.position = Vector3(0.22, 0.68, 0.0)
			add_child(axe_head)
		"orc_berserker":
			# Corpo maior e mais bruto que o padrao (torso avantajado,
			# corcunda) — silhueta que le "forca bruta" antes mesmo de
			# reconhecer qualquer arma.
			var body := MeshInstance3D.new()
			var body_mesh := CapsuleMesh.new()
			body_mesh.radius = 0.24
			body_mesh.height = 0.75
			body.mesh = body_mesh
			body.material_override = mat
			body.position = Vector3(0, 0.42, 0.03)
			body.rotation_degrees = Vector3(8, 0, 0) # levemente curvado pra frente
			add_child(body)

			var club := MeshInstance3D.new()
			var club_mesh := BoxMesh.new()
			club_mesh.size = Vector3(0.09, 0.5, 0.09)
			club.mesh = club_mesh
			var club_mat := StandardMaterial3D.new()
			club_mat.albedo_color = Color(0.32, 0.24, 0.16)
			club.material_override = club_mat
			club.position = Vector3(0.26, 0.5, 0.0)
			club.rotation_degrees = Vector3(0, 0, -18)
			add_child(club)
		"elf_ranger":
			# Silhueta alta e esguia (mais fina que o Arqueiro comum) + um
			# arco fino nas costas — leitura de "movel e a distancia", nao
			# "forte e corpo-a-corpo" como os outros dois novos.
			var body := MeshInstance3D.new()
			var body_mesh := CylinderMesh.new()
			body_mesh.top_radius = 0.03
			body_mesh.bottom_radius = 0.13
			body_mesh.height = 0.85
			body.mesh = body_mesh
			body.material_override = mat
			body.position.y = 0.45
			add_child(body)

			var bow := MeshInstance3D.new()
			var bow_mesh := CylinderMesh.new()
			bow_mesh.top_radius = 0.015
			bow_mesh.bottom_radius = 0.015
			bow_mesh.height = 0.5
			bow.mesh = bow_mesh
			var bow_mat := StandardMaterial3D.new()
			bow_mat.albedo_color = Color(0.42, 0.3, 0.2)
			bow.material_override = bow_mat
			bow.position = Vector3(-0.14, 0.5, -0.05)
			bow.rotation_degrees = Vector3(0, 0, 12)
			add_child(bow)
		"stone_golem", "arcane_golem", "grave_guardian":
			# Silhueta larga e empilhada (torso grande + "cabeca" cubica
			# menor por cima) — leitura de "bloco de pedra andante", o
			# oposto do humanoide magro padrao.
			var torso := MeshInstance3D.new()
			var torso_mesh := BoxMesh.new()
			torso_mesh.size = Vector3(0.5, 0.55, 0.4)
			torso.mesh = torso_mesh
			torso.material_override = mat
			torso.position.y = 0.32
			add_child(torso)

			var head := MeshInstance3D.new()
			var head_mesh := BoxMesh.new()
			head_mesh.size = Vector3(0.24, 0.24, 0.24)
			head.mesh = head_mesh
			head.material_override = mat
			head.position.y = 0.72
			add_child(head)
		"storm_elemental":
			for i in range(4):
				var ring := MeshInstance3D.new()
				var mesh := TorusMesh.new()
				mesh.inner_radius = 0.14 + i * 0.08
				mesh.outer_radius = mesh.inner_radius + 0.08
				ring.mesh = mesh
				var glow := StandardMaterial3D.new()
				glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				glow.albedo_color = Color(0.4, 0.8, 1.0).lerp(Color.WHITE, i * 0.15)
				ring.material_override = glow
				ring.position.y = 0.35 + i * 0.35
				ring.rotation.z = 0.15 * (i - 2)
				add_child(ring)
		"shadow_summoner":
			# Silhueta fina e encapuzada (mesmo corte do Mago) mas com um
			# orbe escuro flutuando acima da cabeca em vez de uma cabeca
			# clara — leitura de "algo sombrio sendo canalizado", nao um
			# rosto normal.
			var robe := MeshInstance3D.new()
			var robe_mesh := PrismMesh.new()
			robe_mesh.size = Vector3(0.36, 0.75, 0.36)
			robe.mesh = robe_mesh
			robe.material_override = mat
			robe.position.y = 0.38
			add_child(robe)

			var orb := MeshInstance3D.new()
			var orb_mesh := SphereMesh.new()
			orb_mesh.radius = 0.13
			orb_mesh.height = 0.26
			orb.mesh = orb_mesh
			var orb_mat := StandardMaterial3D.new()
			orb_mat.albedo_color = Color(0.15, 0.05, 0.2)
			orb.material_override = orb_mat
			orb.position.y = 0.88
			add_child(orb)
		_: # kind desconhecido cai no padrao (capsula nua, sem arma/acessorio)
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.2
			mesh.height = 0.7
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.4
			add_child(body)

## ===========================================================================
## "Aetherlands Low Poly Modular" -- primeiro prototipo do dragao (roadmap
## "Dragon Event v1 fechado"). Toda a geometria fica sob um unico
## DragonVisualRoot (nunca direto sob `self`) de proposito: `self.position`/
## `self.rotation` continuam pertencendo EXCLUSIVAMENTE a slide_to() (o
## tween de movimento pelo grid) -- se as animacoes abaixo tambem
## escrevessem nessas propriedades, as duas ficariam brigando pelo mesmo
## valor todo frame. Pivots nomeados (NeckPivot/HeadPivot/JawPivot/*Hip/
## TailPivot/*WingPivot) sao o "esqueleto" barato desta unidade -- cada
## um e' so' um Node3D vazio que os MeshInstance3D reais penduram embaixo,
## e as animacoes (ver _build_dragon_animation_player) so' giram/deslocam
## ESSES pivots, nunca a malha em si.
## ===========================================================================
func _build_dragon_body(mat: StandardMaterial3D) -> void:
	var visual_root := Node3D.new()
	visual_root.name = "DragonVisualRoot"
	add_child(visual_root)

	var horn_mat := StandardMaterial3D.new()
	horn_mat.albedo_color = Color(0.88, 0.85, 0.78)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.85, 0.1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.6, 0.0)
	eye_mat.emission_energy_multiplier = 2.5
	# Roadmap "Dragon Event v1 fechado" v2 -- pedido explicito do usuario:
	# "se baseie um pouco nessa imagem" (referencia de um Dragao Ancestral
	# roxo+laranja com espinhos na espinha/cauda e asas grandes e
	# contrastantes). Segunda cor (accent) e' NOVA aqui -- silhueta v1 era
	# monocromatica demais pra ler bem a distancia.
	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color(0.95, 0.55, 0.08)

	# --- Torso: v7 -- correcao explicita do usuario depois do v6 (malha
	# lofted lisa): "eu quero ele composto de quadrados mesmo... ou faz
	# igual uma geladeira usando 3 quadrados, ou faz o bagulho todo
	# redondo, o estilo e' justamente low poly voxel fantasy" -- ou seja,
	# NEM 2-3 blocos grandes (geladeira) NEM um tubo liso (v6 errou pro
	# lado oposto): o estilo certo e' VARIOS blocos pequenos, cada um
	# rotacionado pra seguir a curva (uma "escada" de cubos, nao uma
	# superficie continua) -- ver `_add_segmented_boxes`, que reaproveita
	# a mesma coluna/raios do v6 mas desenha um BoxMesh de verdade em cada
	# ponto em vez de um anel de malha lisa.
	var torso_spine: Array = [
		Vector3(0, 0.66, -0.55),
		Vector3(0, 0.67, -0.35),
		Vector3(0, 0.70, -0.10),
		Vector3(0, 0.76, 0.15),
		Vector3(0, 0.81, 0.40),
		Vector3(0, 0.85, 0.60),
	]
	var torso_radii: Array = [
		Vector2(0.20, 0.18),
		Vector2(0.27, 0.25),
		Vector2(0.29, 0.27),
		Vector2(0.27, 0.25),
		Vector2(0.24, 0.22),
		Vector2(0.18, 0.16),
	]
	_add_segmented_boxes(visual_root, torso_spine, torso_radii, mat)

	# Barriga em PLACAS separadas (nao uma faixa unica) -- mais geometria
	# de verdade, nao so' cor: cada placa e' um pouco menor que a anterior,
	# com um pequeno vao entre elas (ritmo visual "couraça segmentada",
	# pedido do usuario: "aplicasse modificações no modelo pra ficar mais
	# desenvolvido... ta simples demais").
	var belly_z := 0.62
	for i in range(4):
		var plate := MeshInstance3D.new()
		var plate_mesh := BoxMesh.new()
		var plate_width: float = 0.4 - i * 0.03
		plate_mesh.size = Vector3(plate_width, 0.09, 0.22)
		plate.mesh = plate_mesh
		plate.material_override = accent_mat
		plate.position = Vector3(0, 0.44, belly_z)
		visual_root.add_child(plate)
		belly_z -= 0.27

	_add_spine_spikes(visual_root, accent_mat, [Vector3(0, 0.98, -0.4), Vector3(0, 1.0, -0.1), Vector3(0, 1.06, 0.2)])

	# --- Placas de ombro (uma de cada lado, na base do peito) -- quebra a
	# silhueta lisa do torso, mesmo espirito de "couraça" da barriga acima.
	for side in [-1.0, 1.0]:
		var shoulder_plate := MeshInstance3D.new()
		var shoulder_plate_mesh := BoxMesh.new()
		shoulder_plate_mesh.size = Vector3(0.1, 0.16, 0.16)
		shoulder_plate.mesh = shoulder_plate_mesh
		shoulder_plate.material_override = accent_mat
		shoulder_plate.position = Vector3(side * 0.27, 0.95, 0.15)
		shoulder_plate.rotation_degrees = Vector3(0, 0, side * 15)
		visual_root.add_child(shoulder_plate)

	# --- Pescoco: pivot na base (anima em Idle/Attack) + segmentos CUBICOS
	# afunilando ate a cabeca -- cada segmento sobe um pouco de Y alem de
	# avancar em Z, arqueando o pescoco pra CIMA e pra FRENTE (silhueta da
	# referencia: pescoco curva antes da cabeca apontar forward), tudo via
	# POSICIONAMENTO fixo das malhas -- o pivot em si continua girando a
	# partir de 0 nas animacoes (Idle/Attack), sem precisar mudar nenhuma
	# key existente.
	# v4: arco bem mais dramatico (pedido do usuario: modelo "nao ta nada
	# parecido" com a referencia, que tem a cabeca erguida BEM acima do
	# corpo) -- cada segmento agora sobe quase o dobro em Y do que avanca
	# em Z, entao o pescoco lê como um "S" subindo pra cima antes da
	# cabeca, nao uma linha quase reta pra frente.
	# v7: correcao explicita do usuario depois do v6 (malha lofted lisa) --
	# "o pescoço tambem varios quadrados... o estilo e' justamente low
	# poly voxel fantasy" -- volta a ser uma corrente de BoxMesh (agora 6,
	# nao 3, pra "dar a sensação de ter curvas" com mais degraus), cada um
	# rotacionado pra seguir a coluna via `_add_segmented_boxes`. O arco
	# pra cima (S dramatico, pedido de v4) continua na propria curva da
	# coluna (`neck_spine`), nao em rotacao do pivot -- o pivot continua
	# girando a partir de 0 nas animacoes (Idle/Attack) sem precisar mudar
	# nenhuma key existente.
	var neck_pivot := Node3D.new()
	neck_pivot.name = "NeckPivot"
	neck_pivot.position = Vector3(0, 0.98, 0.6)
	visual_root.add_child(neck_pivot)
	var neck_spine: Array = [
		Vector3(0, 0.0, 0.0),
		Vector3(0, 0.10, 0.14),
		Vector3(0, 0.24, 0.26),
		Vector3(0, 0.40, 0.36),
		Vector3(0, 0.54, 0.44),
		Vector3(0, 0.64, 0.50),
	]
	var neck_radii: Array = [
		Vector2(0.19, 0.19),
		Vector2(0.17, 0.17),
		Vector2(0.155, 0.155),
		Vector2(0.135, 0.135),
		Vector2(0.115, 0.115),
		Vector2(0.10, 0.10),
	]
	_add_segmented_boxes(neck_pivot, neck_spine, neck_radii, mat)
	for spine_pt in neck_spine.slice(1, neck_spine.size() - 1):
		_add_spine_spikes(neck_pivot, accent_mat, [spine_pt + Vector3(0, 0.14, 0)], 0.8)
	var neck_y: float = neck_spine[neck_spine.size() - 1].y
	var neck_z: float = neck_spine[neck_spine.size() - 1].z

	# --- Cabeca: cubo + focinho + mandibula articulada + chifres + olhos
	# emissivos -- pendurada na PONTA do pescoco (anima JUNTO com ele).
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, neck_y + 0.12, neck_z + 0.05)
	neck_pivot.add_child(head_pivot)

	var head_box := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.26, 0.24, 0.28)
	head_box.mesh = head_mesh
	head_box.material_override = mat
	head_box.position = Vector3(0, 0, 0.1)
	head_pivot.add_child(head_box)

	var snout := MeshInstance3D.new()
	var snout_mesh := BoxMesh.new()
	snout_mesh.size = Vector3(0.16, 0.14, 0.22)
	snout.mesh = snout_mesh
	snout.material_override = mat
	snout.position = Vector3(0, -0.02, 0.34)
	head_pivot.add_child(snout)

	var jaw_pivot := Node3D.new()
	jaw_pivot.name = "JawPivot"
	jaw_pivot.position = Vector3(0, -0.09, 0.28)
	head_pivot.add_child(jaw_pivot)
	var jaw := MeshInstance3D.new()
	var jaw_mesh := BoxMesh.new()
	jaw_mesh.size = Vector3(0.14, 0.06, 0.2)
	jaw.mesh = jaw_mesh
	jaw.material_override = mat
	jaw.position = Vector3(0, -0.03, 0.1)
	jaw_pivot.add_child(jaw)

	# Presa inferior -- um unico detalhe pequeno, mas ajuda a cabeca ler
	# "predador" em vez de "cubo com boca" (pedido do usuario: modelo mais
	# desenvolvido).
	var fang := MeshInstance3D.new()
	var fang_mesh := PrismMesh.new()
	fang_mesh.size = Vector3(0.025, 0.07, 0.025)
	fang.mesh = fang_mesh
	fang.material_override = horn_mat
	fang.position = Vector3(0, 0.02, 0.19)
	fang.rotation_degrees = Vector3(180, 0, 0)
	jaw_pivot.add_child(fang)

	for side in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var horn_mesh := PrismMesh.new()
		horn_mesh.size = Vector3(0.05, 0.24, 0.05)
		horn.mesh = horn_mesh
		horn.material_override = horn_mat
		horn.position = Vector3(side * 0.09, 0.16, -0.02)
		horn.rotation_degrees = Vector3(-20, 0, side * -10)
		head_pivot.add_child(horn)

		# Sobrancelha/crista -- pequeno espinho de destaque acima do olho,
		# entre o chifre e o focinho (referencia: "crista" ao longo da
		# cabeca, nao so' chifres isolados).
		var brow := MeshInstance3D.new()
		var brow_mesh := PrismMesh.new()
		brow_mesh.size = Vector3(0.04, 0.06, 0.09)
		brow.mesh = brow_mesh
		brow.material_override = accent_mat
		brow.position = Vector3(side * 0.1, 0.09, 0.18)
		brow.rotation_degrees = Vector3(15, 0, 0)
		head_pivot.add_child(brow)

		var eye := MeshInstance3D.new()
		var eye_mesh := BoxMesh.new()
		eye_mesh.size = Vector3(0.05, 0.05, 0.04)
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.12, 0.02, 0.2)
		head_pivot.add_child(eye)

	# --- Sopro de fogo: GPUParticles3D + luz, ambos DESLIGADOS por padrao
	# (ver DragonEvent._play_fire_breath_vfx) -- pendurados na cabeca pra
	# se mover/virar junto dela automaticamente, nunca reposicionados a
	# mao por quem dispara o ataque.
	var fire_emitter := GPUParticles3D.new()
	fire_emitter.name = "FireBreathEmitter"
	fire_emitter.position = Vector3(0, -0.02, 0.46)
	fire_emitter.emitting = false
	fire_emitter.one_shot = true
	fire_emitter.amount = 40
	fire_emitter.lifetime = 0.45
	fire_emitter.explosiveness = 0.5
	var fire_particle_mesh := SphereMesh.new()
	fire_particle_mesh.radius = 0.05
	fire_particle_mesh.height = 0.1
	fire_emitter.draw_pass_1 = fire_particle_mesh
	var fire_particle_mat := ParticleProcessMaterial.new()
	fire_particle_mat.direction = Vector3(0, 0, 1)
	fire_particle_mat.spread = 14.0
	fire_particle_mat.initial_velocity_min = 2.5
	fire_particle_mat.initial_velocity_max = 4.5
	fire_particle_mat.gravity = Vector3(0, 0.6, 0)
	fire_particle_mat.scale_min = 0.08
	fire_particle_mat.scale_max = 0.24
	fire_particle_mat.color = Color(1.0, 0.55, 0.05)
	fire_emitter.process_material = fire_particle_mat
	head_pivot.add_child(fire_emitter)

	var fire_light := OmniLight3D.new()
	fire_light.name = "FireBreathLight"
	fire_light.light_color = Color(1.0, 0.6, 0.1)
	fire_light.light_energy = 0.0 # 0 por padrao -- so' acende durante o ataque
	fire_light.omni_range = 2.0
	fire_light.position = Vector3(0, -0.02, 0.4)
	head_pivot.add_child(fire_light)

	# --- Pernas: 4, cada uma com pivot de quadril (anima em Walk) + coxa
	# + canela, ambas caixas simples.
	# v4: pernas mais longas erguendo o corpo bem acima do chao (pedido do
	# usuario: modelo "nao ta nada parecido" com a referencia, que fica em
	# pe de forma ereta, nao esparramada perto do chao); dianteiras presas
	# mais alto que traseiras porque o peito agora fica acima do quadril.
	var leg_hip_positions := {
		"FrontLeftHipPivot": Vector3(-0.28, 0.42, 0.2),
		"FrontRightHipPivot": Vector3(0.28, 0.42, 0.2),
		"BackLeftHipPivot": Vector3(-0.28, 0.34, -0.35),
		"BackRightHipPivot": Vector3(0.28, 0.34, -0.35),
	}
	# v7: pedido explicito do usuario -- "um quadrado pra pata, um acima
	# pra ser a canela, outro pra ser a coxa, um pra ser o ombro" -- 4
	# blocos distintos por perna (nao so' coxa+canela+garras soltas).
	for leg_name in leg_hip_positions:
		var hip_pivot := Node3D.new()
		hip_pivot.name = leg_name
		hip_pivot.position = leg_hip_positions[leg_name]
		visual_root.add_child(hip_pivot)

		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := BoxMesh.new()
		shoulder_mesh.size = Vector3(0.17, 0.13, 0.17)
		shoulder.mesh = shoulder_mesh
		shoulder.material_override = mat
		shoulder.position = Vector3(0, -0.01, 0)
		hip_pivot.add_child(shoulder)

		var thigh := MeshInstance3D.new()
		var thigh_mesh := BoxMesh.new()
		thigh_mesh.size = Vector3(0.14, 0.22, 0.14)
		thigh.mesh = thigh_mesh
		thigh.material_override = mat
		thigh.position = Vector3(0, -0.18, 0)
		hip_pivot.add_child(thigh)

		var shin := MeshInstance3D.new()
		var shin_mesh := BoxMesh.new()
		shin_mesh.size = Vector3(0.11, 0.2, 0.11)
		shin.mesh = shin_mesh
		shin.material_override = mat
		shin.position = Vector3(0, -0.39, 0.02)
		hip_pivot.add_child(shin)

		var paw := MeshInstance3D.new()
		var paw_mesh := BoxMesh.new()
		paw_mesh.size = Vector3(0.13, 0.09, 0.17)
		paw.mesh = paw_mesh
		paw.material_override = mat
		paw.position = Vector3(0, -0.53, 0.06)
		hip_pivot.add_child(paw)

		# Garras -- 3 por pata, levemente espalhadas, apontando pra frente/
		# baixo.
		for claw_x in [-0.035, 0.0, 0.035]:
			var claw := MeshInstance3D.new()
			var claw_mesh := PrismMesh.new()
			claw_mesh.size = Vector3(0.035, 0.08, 0.035)
			claw.mesh = claw_mesh
			claw.material_override = horn_mat
			claw.position = Vector3(claw_x, -0.58, 0.12)
			claw.rotation_degrees = Vector3(-75, 0, 0)
			hip_pivot.add_child(claw)

	# --- Cauda: pivot na base (anima em Idle/Walk) + segmentos CUBICOS
	# progressivamente menores ate a ponta -- mais longa que a v1 (5
	# segmentos, nao 4) com espinhos no topo de cada um, seguindo a
	# referencia ("cauda longa, afunilando, com espinhos na espinha").
	# v4: cauda agora sobe um pouco em Y conforme afunila (mesma tecnica do
	# pescoco acima) -- pedido do usuario: modelo "nao ta nada parecido"
	# com a referencia, que tem a cauda varrendo pra CIMA no ar, nao
	# arrastando reta e murcha atras do corpo.
	# v7: correcao explicita do usuario depois do v6 (malha lofted lisa) --
	# "a cauda 6 quadrados, mas eles vao ficando menor pra deixar a
	# sensação de ter curvas... o estilo e' justamente low poly voxel
	# fantasy" -- exatamente os 6 pontos ja definidos abaixo, so' que cada
	# um agora e' um BoxMesh de verdade (`_add_segmented_boxes`) em vez de
	# um anel de malha lisa. A varredura pra cima (pedido de v4) continua
	# na propria curva da coluna, nao em rotacao do pivot.
	var tail_pivot := Node3D.new()
	tail_pivot.name = "TailPivot"
	tail_pivot.position = Vector3(0, 0.62, -0.6)
	visual_root.add_child(tail_pivot)
	var tail_spine: Array = [
		Vector3(0, 0.0, 0.0),
		Vector3(0, 0.05, -0.22),
		Vector3(0, 0.11, -0.45),
		Vector3(0, 0.17, -0.68),
		Vector3(0, 0.23, -0.92),
		Vector3(0, 0.30, -1.15),
	]
	var tail_radii: Array = [
		Vector2(0.19, 0.19),
		Vector2(0.16, 0.16),
		Vector2(0.13, 0.13),
		Vector2(0.10, 0.10),
		Vector2(0.07, 0.07),
		Vector2(0.04, 0.04),
	]
	_add_segmented_boxes(tail_pivot, tail_spine, tail_radii, mat)
	for spine_pt in tail_spine.slice(1, tail_spine.size() - 1):
		_add_spine_spikes(tail_pivot, accent_mat, [spine_pt + Vector3(0, 0.11, 0)], 0.7)
	var tail_y: float = tail_spine[tail_spine.size() - 1].y
	var tail_z: float = tail_spine[tail_spine.size() - 1].z

	# Aba/leque na PONTA da cauda -- referencia tem um "spade" la, nao so'
	# um cubo minusculo desaparecendo no nada.
	var tail_fin := MeshInstance3D.new()
	var tail_fin_mesh := PrismMesh.new()
	tail_fin_mesh.size = Vector3(0.22, 0.18, 0.12)
	tail_fin.mesh = tail_fin_mesh
	tail_fin.material_override = accent_mat
	tail_fin.position = Vector3(0, tail_y, tail_z - 0.03)
	tail_fin.rotation_degrees = Vector3(0, 0, 90)
	tail_pivot.add_child(tail_fin)

	# --- Asas: v5 -- reconstruidas do zero (pedido explicito do usuario
	# depois de ver o v4 em jogo: "as asas parecem dois papeis... faça um
	# modelo atraves de uma solução robusta", nao mais um remendo em cima
	# do anterior). Empilhar varios prismas finos em angulos escolhidos a
	# mao (v1-v4) sempre ia continuar lendo como sticks soltos, porque
	# cada peca e' plana e sem gradiente. A solução robusta: a membrana
	# agora e' UMA malha poligonal real (SurfaceTool, formato de leque com
	# a borda de tras recortada entre os "dedos") com cor por vertice
	# (mais escura perto do corpo, mais clara na ponta) simulando volume
	# sem depender de textura -- ver `_build_wing_membrane_mesh`. Um unico
	# osso de borda de ataque vai do ombro direto ate a ponta (a linha reta
	# que mais define a silhueta na referencia), orientado via
	# `_basis_pointing` (matematica de direcao real, nao Euler angles
	# escolhidos no olho) -- o mesmo helper orienta as nervuras (uma por
	# "dedo", encaixada por baixo da malha, nao um graveto solto pra fora
	# dela) e as garras na ponta.
	for side in [-1.0, 1.0]:
		var wing_pivot := Node3D.new()
		wing_pivot.name = "LeftWingPivot" if side < 0 else "RightWingPivot"
		wing_pivot.position = Vector3(side * 0.24, 0.85, -0.05)
		wing_pivot.rotation_degrees = Vector3(-6, side * -10, 0)
		visual_root.add_child(wing_pivot)

		var root_pt := Vector3(0, 0, 0.08)
		var lead_mid := Vector3(side * 0.5, 0.06, 0.22)
		var tip_pt := Vector3(side * 1.05, 0.12, 0.08)
		var fin1 := Vector3(side * 0.92, -0.05, -0.22)
		var val1 := Vector3(side * 0.7, -0.15, -0.05)
		var fin2 := Vector3(side * 0.55, -0.08, -0.32)
		var val2 := Vector3(side * 0.35, -0.18, -0.1)
		var fin3 := Vector3(side * 0.22, -0.1, -0.35)
		var trailing_root := Vector3(0, -0.05, -0.15)

		var membrane := MeshInstance3D.new()
		var boundary: Array = [lead_mid, tip_pt, fin1, val1, fin2, val2, fin3, trailing_root]
		membrane.mesh = _build_wing_membrane_mesh(root_pt, boundary, accent_mat.albedo_color, side < 0.0)
		# Sem sombreamento (pedido do usuario: comparou com uma captura REAL
		# em jogo e a asa apareceu quase preta) -- a cena real
		# (scenes/main/Main.tscn) usa ambient_light_energy=0.22 (bem mais
		# escuro que o meu rig de teste isolado, que usava 0.9), entao
		# qualquer face virada pro lado errado do sol ficava quase sem luz
		# nenhuma e o gradiente pintado por vertice desaparecia. Sem
		# sombreamento, o gradiente sempre aparece exatamente como
		# desenhado, independente da luz da cena.
		var membrane_mat := StandardMaterial3D.new()
		membrane_mat.vertex_color_use_as_albedo = true
		membrane_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		membrane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		membrane.material_override = membrane_mat
		wing_pivot.add_child(membrane)

		var leading_edge := MeshInstance3D.new()
		var leading_edge_mesh := BoxMesh.new()
		leading_edge_mesh.size = Vector3((tip_pt - root_pt).length(), 0.055, 0.08)
		leading_edge.mesh = leading_edge_mesh
		leading_edge.material_override = mat
		leading_edge.position = (root_pt + tip_pt) * 0.5
		leading_edge.transform.basis = _basis_pointing(tip_pt - root_pt, false)
		wing_pivot.add_child(leading_edge)

		# Nervuras -- uma por "dedo", encaixada por baixo da malha
		# (encolhida a 85% do comprimento real pra nao furar a silhueta) +
		# uma garra pequena na ponta de cada uma.
		for finger_tip in [fin1, fin2, fin3]:
			var rib := MeshInstance3D.new()
			var rib_mesh := BoxMesh.new()
			rib_mesh.size = Vector3((finger_tip - root_pt).length() * 0.85, 0.03, 0.035)
			rib.mesh = rib_mesh
			rib.material_override = mat
			rib.position = root_pt.lerp(finger_tip, 0.42)
			rib.transform.basis = _basis_pointing(finger_tip - root_pt, false)
			wing_pivot.add_child(rib)

			var claw_tip := MeshInstance3D.new()
			var claw_tip_mesh := PrismMesh.new()
			claw_tip_mesh.size = Vector3(0.03, 0.09, 0.03)
			claw_tip.mesh = claw_tip_mesh
			claw_tip.material_override = horn_mat
			claw_tip.position = finger_tip
			claw_tip.transform.basis = _basis_pointing(finger_tip - root_pt, true)
			wing_pivot.add_child(claw_tip)

	_anim_player = _build_dragon_animation_player()

## Fileira de espinhos pequenos (PrismMesh) no topo de um segmento de
## corpo -- pedido explicito do usuario: "se baseie um pouco nessa
## imagem" (referencia tem espinhos ao longo de toda a espinha/cauda).
## `local_positions` sao pontos NO ESPACO LOCAL de `parent` (o proprio
## segmento) -- cada chamador decide quantos/onde, esta funcao so'
## constroi a malha em si.
func _add_spine_spikes(parent: Node3D, spike_mat: StandardMaterial3D, local_positions: Array, scale: float = 1.0) -> void:
	for local_pos in local_positions:
		var spike := MeshInstance3D.new()
		var spike_mesh := PrismMesh.new()
		spike_mesh.size = Vector3(0.06, 0.14, 0.06) * scale
		spike.mesh = spike_mesh
		spike.material_override = spike_mat
		spike.position = local_pos
		parent.add_child(spike)

## Monta uma Basis que aponta o eixo LOCAL X (`along_y=false`, pra ossos
## tipo BoxMesh cujo comprimento e' X) ou Y (`along_y=true`, pra garras
## tipo PrismMesh cuja ponta e' Y) na direcao `direction` -- pedido
## explicito do usuario ("solução robusta") em vez de orientar cada osso/
## garra com Euler angles escolhidos no olho por peça, o que e' fragil e
## dificil de acertar em pares simetricos left/right. `up_hint` evita uma
## base degenerada quando `direction` fica quase paralelo a ele.
static func _basis_pointing(direction: Vector3, along_y: bool, up_hint: Vector3 = Vector3.UP) -> Basis:
	var axis := direction.normalized()
	var hint := up_hint
	if absf(axis.dot(hint)) > 0.98:
		hint = Vector3.FORWARD
	if along_y:
		var x_axis := hint.cross(axis).normalized()
		var z_axis := x_axis.cross(axis).normalized()
		return Basis(x_axis, axis, z_axis)
	var y_axis := axis.cross(hint).normalized()
	var z_axis := axis.cross(y_axis).normalized()
	return Basis(axis, y_axis, z_axis)

## Constroi a membrana da asa como UMA malha poligonal real (leque de
## triangulos a partir de `root`, formato recortado com "dedos" entre as
## reentrancias), com cor por vertice indo de mais escura (perto do corpo,
## `root`) a mais clara (ponta da asa) -- pedido do usuario depois de
## "as asas parecem dois papeis": uma malha so' com gradiente le como
## superficie tensionada com volume implicito, nao como pedacos de prisma
## fino colados um do lado do outro. `flip_normals` inverte a normal
## gerada -- necessario pro lado esquerdo, cujo espelhamento em X inverte
## a lateralidade (winding) dos triangulos comparado ao lado direito.
func _build_wing_membrane_mesh(root: Vector3, boundary: Array, base_color: Color, flip_normals: bool) -> ArrayMesh:
	var root_color := base_color.darkened(0.35)
	var tip_color := base_color.lightened(0.3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(boundary.size() - 1):
		var a: Vector3 = boundary[i]
		var b: Vector3 = boundary[i + 1]
		var a_t: float = float(i) / float(boundary.size() - 1)
		var b_t: float = float(i + 1) / float(boundary.size() - 1)
		st.set_color(root_color)
		st.add_vertex(root)
		st.set_color(root_color.lerp(tip_color, a_t))
		st.add_vertex(a)
		st.set_color(root_color.lerp(tip_color, b_t))
		st.add_vertex(b)
	st.generate_normals(flip_normals)
	return st.commit()

## Cria uma corrente de BoxMesh de verdade ao longo de `spine` (uma lista
## de pontos formando a coluna central), um bloco por ponto, do tamanho
## de `radii[i]` (largura/altura, Vector2) -- pedido explicito do usuario
## depois de ver a v6 (uma malha lofted lisa): "eu quero ele composto de
## quadrados mesmo... ou faz igual uma geladeira usando 3 quadrados, ou
## faz o bagulho todo redondo, o estilo e' justamente low poly voxel
## fantasy". Ou seja nem poucos blocos grandes (geladeira) nem uma
## superficie continua (v6 errou pro lado oposto) -- o estilo certo e'
## VARIOS blocos pequenos formando uma "escada" que sobe/afunila, cada um
## ORIENTADO (via `_basis_pointing`) pra seguir a direcao local da coluna,
## entao a propria rotacao de cada bloco acompanha a curva, nao so' a
## posicao.
func _add_segmented_boxes(parent: Node3D, spine: Array, radii: Array, seg_mat: StandardMaterial3D) -> void:
	for i in range(spine.size()):
		var center: Vector3 = spine[i]
		var radius: Vector2 = radii[i]
		var forward: Vector3
		if i == 0:
			forward = (spine[1] - spine[0])
		elif i == spine.size() - 1:
			forward = (spine[i] - spine[i - 1])
		else:
			forward = (spine[i + 1] - spine[i - 1])
		var length := 0.0
		if i > 0:
			length = (spine[i] - spine[i - 1]).length()
		if i < spine.size() - 1:
			length = max(length, (spine[i + 1] - spine[i]).length())
		if length <= 0.0:
			length = radius.x
		var box := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(length, radius.y * 2.0, radius.x * 2.0)
		box.mesh = box_mesh
		box.material_override = seg_mat
		box.position = center
		box.transform.basis = _basis_pointing(forward, false)
		parent.add_child(box)

## Uma track de VALUE por chamada -- `keys` e' um Array de [tempo, valor].
## Extraido pra nao repetir add_track/track_set_path/track_insert_key em
## cada uma das 5 animacoes abaixo (~20 tracks no total).
static func _add_animation_track(animation: Animation, node_path: String, keys: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(node_path))
	for key in keys:
		animation.track_insert_key(track, key[0], key[1])

## 5 clipes -- pedido explicito do usuario: "para o primeiro Dragao
## proprio, 5 animações são suficientes". Idle_A/Walking_A usam os MESMOS
## nomes das constantes DEFAULT_ANIMATION/WALK_ANIMATION -- slide_to() ja
## troca entre elas sozinho, sem NENHUMA mudanca no restante do arquivo
## (mesmo mecanismo generico ja usado pelos modelos KayKit). Fly/Attack/
## Death sao tocadas explicitamente por quem controla o Dragao (ver
## DragonEvent) via _play_animation(), que ja no-opa com seguranca se
## chamada em qualquer OUTRA unidade sem esses clipes.
func _build_dragon_animation_player() -> AnimationPlayer:
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	library.add_animation("Idle_A", _build_dragon_idle_animation())
	library.add_animation("Walking_A", _build_dragon_walk_animation())
	library.add_animation("Fly", _build_dragon_fly_animation())
	library.add_animation("Attack", _build_dragon_attack_animation())
	library.add_animation("Death", _build_dragon_death_animation())
	player.add_animation_library("", library)
	add_child(player)
	player.play("Idle_A")
	return player

## Respiracao leve: o corpo inteiro sobe/desce um pouco, pescoco balanca
## suavemente -- looping, ~2s (bem mais lento que Walk/Fly, "parado mas
## vivo").
func _build_dragon_idle_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 2.0
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_animation_track(animation, "DragonVisualRoot:position:y", [[0.0, 0.0], [1.0, 0.03], [2.0, 0.0]])
	_add_animation_track(animation, "DragonVisualRoot/NeckPivot:rotation:x", [[0.0, 0.0], [1.0, deg_to_rad(-4.0)], [2.0, 0.0]])
	return animation

## Trote de quadrupede simples: as 4 pernas alternam em 2 pares diagonais
## (dianteira-esquerda+traseira-direita vs dianteira-direita+traseira-
## esquerda) -- looping, ~0.6s (bem mais rapido que Idle, "andando de
## verdade").
func _build_dragon_walk_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.6
	animation.loop_mode = Animation.LOOP_LINEAR
	var swing := deg_to_rad(22.0)
	_add_animation_track(animation, "DragonVisualRoot/FrontLeftHipPivot:rotation:x", [[0.0, swing], [0.3, -swing], [0.6, swing]])
	_add_animation_track(animation, "DragonVisualRoot/BackRightHipPivot:rotation:x", [[0.0, swing], [0.3, -swing], [0.6, swing]])
	_add_animation_track(animation, "DragonVisualRoot/FrontRightHipPivot:rotation:x", [[0.0, -swing], [0.3, swing], [0.6, -swing]])
	_add_animation_track(animation, "DragonVisualRoot/BackLeftHipPivot:rotation:x", [[0.0, -swing], [0.3, swing], [0.6, -swing]])
	_add_animation_track(animation, "DragonVisualRoot:position:y", [[0.0, 0.0], [0.15, 0.02], [0.3, 0.0], [0.45, 0.02], [0.6, 0.0]])
	return animation

## Bater de asas -- looping, ~0.5s (rapido, "sustentando o proprio peso no
## ar"). Cauda balanca suave em contraponto pra dar sensacao de peso;
## pescoco fica mais esticado (postura de voo) que em Idle/Walk.
func _build_dragon_fly_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.5
	animation.loop_mode = Animation.LOOP_LINEAR
	var flap_up := deg_to_rad(-55.0)
	var flap_down := deg_to_rad(15.0)
	_add_animation_track(animation, "DragonVisualRoot/LeftWingPivot:rotation:z", [[0.0, flap_down], [0.25, flap_up], [0.5, flap_down]])
	_add_animation_track(animation, "DragonVisualRoot/RightWingPivot:rotation:z", [[0.0, -flap_down], [0.25, -flap_up], [0.5, -flap_down]])
	_add_animation_track(animation, "DragonVisualRoot/TailPivot:rotation:x", [[0.0, deg_to_rad(4.0)], [0.25, deg_to_rad(-4.0)], [0.5, deg_to_rad(4.0)]])
	_add_animation_track(animation, "DragonVisualRoot/NeckPivot:rotation:x", [[0.0, deg_to_rad(8.0)]])
	return animation

## Cabeca/pescoco avancam + mandibula abre e fecha -- UMA VEZ (nao
## looping), ~0.6s. Pedido do usuario: "a animação: cabeça abre → inclina
## → pausa, e um sistema de partículas produz o jato de fogo" -- o VFX em
## si (GPUParticles3D/luz) e' disparado separadamente por quem chama esta
## animacao (ver DragonEvent._play_fire_breath_vfx), nunca por uma key de
## animacao — mantém o disparo do efeito de fora do proprio clipe.
func _build_dragon_attack_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.6
	animation.loop_mode = Animation.LOOP_NONE
	_add_animation_track(animation, "DragonVisualRoot/NeckPivot:rotation:x", [[0.0, 0.0], [0.2, deg_to_rad(18.0)], [0.45, deg_to_rad(18.0)], [0.6, 0.0]])
	_add_animation_track(animation, "DragonVisualRoot/NeckPivot:position:z", [[0.0, 0.0], [0.2, 0.12], [0.45, 0.12], [0.6, 0.0]])
	_add_animation_track(animation, "DragonVisualRoot/NeckPivot/HeadPivot/JawPivot:rotation:x", [[0.0, 0.0], [0.25, deg_to_rad(35.0)], [0.5, deg_to_rad(35.0)], [0.6, 0.0]])
	return animation

## Corpo perde sustentacao e tomba -- UMA VEZ, ~1.2s. Anima `self`
## diretamente (nao DragonVisualRoot) de proposito: e' a UNICA animacao
## terminal (a Unit e' removida do mapa logo depois, DragonEvent.
## _remove_dragon_unit), entao nao ha risco de brigar com slide_to() de
## novo -- nao vai haver mais nenhum movimento depois desta. So' rotation
## (sempre relativa a 0, seguro independente de pra onde o Dragao estava
## virado) -- a QUEDA de verdade (position:y) fica de fora do clipe de
## proposito e usa um Tween a parte com o valor ATUAL no momento da morte
## (ver DragonEvent._play_dragon_death_effects) -- um valor de posicao
## fixo AQUI ficaria congelado no Y de onde o corpo estava quando esta
## Animation foi CONSTRUIDA (spawn), nao de onde ele morreu de verdade.
func _build_dragon_death_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 1.2
	animation.loop_mode = Animation.LOOP_NONE
	_add_animation_track(animation, ".:rotation:z", [[0.0, 0.0], [1.2, deg_to_rad(85.0)]])
	return animation

## Disco colorido embaixo dos pes — indica de quem e a unidade sem precisar
## tingir o modelo real inteiro (o que destruiria a textura pintada dele,
## mesma logica usada na bandeira das cidades vs a pedra da torre).
func _build_base_disc() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.35
	base_mesh.bottom_radius = 0.35
	base_mesh.height = 0.06
	base.mesh = base_mesh
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = _body_color().darkened(0.3)
	base.material_override = base_mat
	base.position.y = 0.03
	add_child(base)

## Barra de vida sempre visivel (nao so quando selecionada) — pra dar pra
## ver a vida das suas unidades E das inimigas so olhando o mapa, sem
## precisar clicar em cada uma. Fundo escuro fixo + barra colorida que
## encolhe da direita pra esquerda conforme o HP cai.
func _build_hp_bar() -> void:
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg = MeshInstance3D.new()
	_hp_bar_bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.08, 0.08, 0.85)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 1
	_hp_bar_bg.material_override = bg_mat
	# Same calibrated-for-MODEL_TARGET_HEIGHT issue as TROOP_ICON_Y above.
	_hp_bar_bg.position = Vector3(0, _marker_height, 0)
	add_child(_hp_bar_bg)

	var fg_mesh := QuadMesh.new()
	fg_mesh.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_fg = MeshInstance3D.new()
	_hp_bar_fg.mesh = fg_mesh
	var fg_mat := StandardMaterial3D.new()
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fg_mat.no_depth_test = true
	fg_mat.render_priority = 2
	_hp_bar_fg.material_override = fg_mat
	_hp_bar_fg.position = Vector3(0, _marker_height, 0.001)
	add_child(_hp_bar_fg)

	_update_hp_bar()

func _update_hp_bar() -> void:
	# Chamado pelo setter de hp mesmo antes de _build_visual() rodar
	# (setup() seta hp = data.max_hp antes de construir a barra) — nesse
	# momento a barra ainda nao existe, entao so ignora.
	if _hp_bar_fg == null or unit_data == null:
		return
	var frac = clamp(hp / unit_data.max_hp, 0.0, 1.0)
	var mesh := _hp_bar_fg.mesh as QuadMesh
	mesh.size = Vector2(HP_BAR_WIDTH * frac, HP_BAR_HEIGHT)
	_hp_bar_fg.position.x = -(HP_BAR_WIDTH - HP_BAR_WIDTH * frac) * 0.5

	var mat := _hp_bar_fg.material_override as StandardMaterial3D
	if frac > 0.6:
		mat.albedo_color = Color(0.25, 0.85, 0.25)
	elif frac > 0.3:
		mat.albedo_color = Color(0.9, 0.75, 0.15)
	else:
		mat.albedo_color = Color(0.85, 0.2, 0.2)

	_hp_bar_bg.visible = frac < 1.0
	_hp_bar_fg.visible = frac < 1.0

## Sprite3D com textura desenhada em pixels (mesma tecnica de
## ResourceIconManager._build_icon_texture, nao Label3D/glifo Unicode — a
## fonte padrao do projeto nao garante cobertura de simbolo de espada) —
## placa circular semi-transparente com um par de espadas cruzadas por
## cima. Cor FIXA (nao tingida pela civ) de proposito: o corpo/escudo/
## bandeira da propria unidade ja carrega a cor da civilizacao, o badge so
## precisa dizer "isto e uma unidade militar", igual pra qualquer dono —
## inclusive monstro neutro. Textura construida uma unica vez (static,
## cache compartilhado entre TODAS as unidades) ja que o desenho e sempre
## identico.
func _build_troop_icon() -> void:
	if _troop_icon_texture == null:
		_troop_icon_texture = _build_troop_icon_texture()
	var sprite := Sprite3D.new()
	sprite.texture = _troop_icon_texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.pixel_size = 0.01 # menor que o badge de recurso (0.016) — flutua sobre uma unidade, nao um tile inteiro
	# TROOP_ICON_Y is calibrated for MODEL_TARGET_HEIGHT (0.7) -- scale it
	# by the same per-unit multiplier the model itself got, or it stays
	# floating at head/face height on any unit scaled bigger than that
	# (model_scale_multiplier defaults to 1.0, so this is a no-op for
	# every unit that doesn't set one).
	sprite.position = Vector3(0, _marker_height + 0.2, 0)
	add_child(sprite)

static func _build_troop_icon_texture() -> ImageTexture:
	var img := Image.create(TROOP_ICON_SIZE, TROOP_ICON_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TROOP_ICON_SIZE / 2.0, TROOP_ICON_SIZE / 2.0)
	for y in range(TROOP_ICON_SIZE):
		for x in range(TROOP_ICON_SIZE):
			var d := Vector2(x + 0.5, y + 0.5) - center
			var pixel := Color(0, 0, 0, 0)
			if d.length() <= TROOP_ICON_BADGE_RADIUS:
				pixel = TROOP_ICON_BADGE_COLOR
				if _hit_crossed_swords(d):
					pixel = TROOP_ICON_COLOR
			img.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(img)

## `d` = offset em pixels a partir do centro do badge — nucleo redondo
## (cruzamento/guarda) + duas laminas finas nas diagonais, capadas ao raio
## do badge — silhueta simples de "espadas cruzadas", mesmo espirito
## geometrico dos outros icones (triangulo/losango/ferradura) do selo de
## recurso.
static func _hit_crossed_swords(d: Vector2) -> bool:
	if d.length() <= 2.0:
		return true
	if d.length() > 11.0:
		return false
	var diag1: float = abs(d.x - d.y)
	var diag2: float = abs(d.x + d.y)
	return diag1 <= 1.6 or diag2 <= 1.6

func _build_school_emblem() -> void:
	var emblem := Label3D.new()
	emblem.name = "SchoolEmblem"
	var school := unit_data.v2_magic_school
	emblem.text = V2MagicContent.school_emblem(school)
	emblem.font_size = 28
	emblem.outline_size = 5
	emblem.pixel_size = 0.009
	emblem.modulate = V2MagicContent.school_color(school)
	emblem.position.y = _marker_height + 0.55
	emblem.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(emblem)

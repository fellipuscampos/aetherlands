class_name Unit
extends Node3D

const HP_BAR_WIDTH := 0.5
const HP_BAR_HEIGHT := 0.07
const HP_BAR_Y := 0.95
const MOVE_DURATION := 0.35

## Selo acima de toda unidade — pedido do usuario: "coloque icones em cima das tropas tipo os dos recursos pra
## identificar que e uma tropa". Desde 2026-10-13 o selo diz O QUE a unidade é e DE QUEM: o pictograma da classe/
## espécie na cor da civilização dona (IconCatalog.unit_badge). Fica acima da barra de vida (HP_BAR_Y).
## Tamanho no mundo = BADGE_SIZE * TROOP_ICON_PIXEL_SIZE (o quadro de 128 px inclui a margem da sombra; a placa em
## si fica com ~0.5, proporcional ao hex).
const TROOP_ICON_PIXEL_SIZE := 0.0044
const TROOP_ICON_Y := 1.08

## Cor FALLBACK pro corpo procedural de monstro neutro (owner_player == null, ver
## MonsterDatabase) sem entrada em MONSTER_KIND_COLORS — nao tem civ.color
## pra puxar, entao um vermelho sangue fixo serve tambem pra diferenciar
## visualmente "isso e hostil a todo mundo" de qualquer unidade de jogador.
const MONSTER_COLOR := Color(0.45, 0.08, 0.08)

## Cada tipo de monstro (MonsterDatabase.KIND_DATA) tem sua PROPRIA cor fixa
## de silhueta — pedido: "Goblins verde viva, Trolls cinza/rocha, Vivern/
## Dragao vermelho-laranja/roxo, Esqueleto branco/creme" — em vez de todos
## caindo no mesmo MONSTER_COLOR vermelho-sangue generico. Usado no corpo
## procedural (_build_procedural_body).
const MONSTER_KIND_COLORS := {
	"goblin": Color(0.25, 0.75, 0.2),
	"troll": Color(0.5, 0.5, 0.52),
	"wyvern": Color(0.85, 0.35, 0.05),
	"dragon": Color(0.55, 0.1, 0.55),
	"skeleton": Color(0.92, 0.9, 0.82),
	# V3 / Combat Ecology — placeholders (MonsterPlaceholderVisuals); o Presentation Pass substitui.
	"worg": Color(0.38, 0.3, 0.24),
	"giant_spider": Color(0.16, 0.14, 0.18),
	"minotaur": Color(0.55, 0.32, 0.18),
	"basilisk": Color(0.3, 0.52, 0.25),
	"colossal_worm": Color(0.7, 0.55, 0.42),
	"arboreal_ancient": Color(0.28, 0.4, 0.16),
	"mana_devourer": Color(0.3, 0.2, 0.75),
	"corrupted_hero": Color(0.55, 0.58, 0.66),
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
var manifestation_order: Dictionary = {}
var manifestation_ready_turn: int = 0
var manifestation_acted_turn: int = -1
## Transient detour cache; loading replans from the saved strategic target.
var manifestation_route: Array[Vector2i] = []
var manifestation_route_goal: Vector2i = NO_MOVE_ORDER
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
var move_order_target: Vector2i = NO_MOVE_ORDER:
	set(value):
		if value == move_order_target:
			return
		move_order_target = value
		EventBus.unit_move_order_changed.emit(self) # a rota visível do jogador acompanha (MarchRouteOverlay)

## Colonizador da IA (ver CitySite.choose_site/RivalAI._handle_settler): local
## de fundacao ja escolhido (histerese -- sem isso o colonizador trocaria de
## alvo a cada passo, porque a pontuacao de candidatos empatados muda
## conforme ele anda) e quantos turnos ja esperou sem achar nenhum local
## aceitavel. Estado de sessao da IA, nao salvo (mesmo padrao de
## move_order_target): carregar um save so faz o colonizador reavaliar.
const NO_SETTLE_TARGET := Vector2i(-999999, -999999)
var settle_target: Vector2i = NO_SETTLE_TARGET
var settle_wait_turns: int = 0
## Fase 33D2 (Bug #6): locais em que a fundação real FALHOU para este Colonizador. A IA escolhe o local só
## com o que conhece; se o runtime recusar (ex.: cidade rival escondida perto demais), o tile sai da busca
## — sem revelar a causa. Estado de sessão, não salvo (mesma regra de settle_target).
var settle_rejected_sites: Dictionary = {}

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

## EMBARQUE AUTOMÁTICO (2026-10-10, pedido do usuário: "quando uma tropa entra na água, ele vire o barquinho e quando
## sai da água ele vire a tropa de novo"). ESTADO DERIVADO do tile, não um modo: true enquanto a unidade (que embarca,
## can_embark) está num tile de água embarcável (Oceano/Mar Gelado/Costa, HexTileData.can_be_embarked_on()). Quem liga e
## desliga é SÓ HexGrid (move_unit/sync_embarked: andar, teleporte, spawn, load, terreno transformado embaixo dela).
## Unidade em trânsito, não um segundo modo de combate: NÃO ataca, não fortifica, não funda cidade, não conjura nem usa
## técnica que consome ação, não constrói, não evolui (cada ação guarda isso no próprio ponto de decisão). Água custa o
## movimento normal do tile. Salvo no save (SaveManager) por compatibilidade, mas o load re-deriva do tile.
var embarked: bool = false

## Quem embarca: toda unidade de civilização que anda pelo chão (tropas, colonos, construtores, magos, retinue,
## invocações, o infiltrador). Monstros neutros (sem dono) não; quem voa (perfil FLYING ou voo legado) já sobrevoa.
func can_embark() -> bool:
	if owner_player == null or unit_data == null:
		return false
	return not unit_data.flies and unit_data.movement_profile != UnitData.MovementProfile.FLYING

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

## Fase 33D2 — covil que gerou este monstro (chefe original, reforço ou guardião). Base da população
## POR COVIL das ameaças regionais/guardiões (HexGrid.lair_population) e do teatro regional da
## MonsterAI. Salvo com o monstro (SaveManager, campo opcional); Vector2i(-999999, -999999) = sem covil.
var source_lair_coord: Vector2i = Vector2i(-999999, -999999)
## V3 / Combat Ecology — sítio ecológico dono deste monstro (MonsterEcologySystem); -1 = fora da ecologia.
## Salvo com o monstro ("ecology_site"); a população POR SÍTIO e a diretiva de atividade por Era saem daqui.
var ecology_site_id: int = -1
## V3 / Combat Ecology — turno global até o qual o monstro descansa depois de um raide (cidade/melhoria):
## volta ao território e não escolhe outro objetivo de raide antes disto (MonsterAI._take_ecology_turn). Salvo.
var ecology_rest_until: int = 0

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
var always_visible: bool = false:
	set(value):
		always_visible = value
		if value:
			visible = true # a névoa esconde quem nasce fora da visão (HexGrid.shown_through_fog); isto desfaz na hora

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
			# V3 / Etapa 2: Barreira Arcana (Devorador de Mana) absorve dano real antes da Vida, por QUALQUER fonte.
			if arcane_barrier > 0.0:
				var absorbed := minf(arcane_barrier, hp - value)
				arcane_barrier -= absorbed
				value += absorbed
				if arcane_barrier <= 0.0 and is_inside_tree():
					refresh_status_overlay() # a casca some quando a barreira acaba
			if value < hp:
				took_damage_since_regen = true # V3: interrompe a Regeneração Monstruosa do Troll neste ciclo
				_play_hit_reaction()
		hp = value
		_update_hp_bar()

## V3 / Etapa 2 — estado de habilidade de monstro guardado na própria unidade (salvo com o monstro):
## escudo da Barreira Arcana e se a unidade levou dano real desde a última checagem de regeneração.
var arcane_barrier: float = 0.0
var took_damage_since_regen: bool = false
## Estado específico de espécie (Verme: subterrâneo/destino; Devorador: rodada da Fome Arcana; Worg: turno do
## bônus de caça). Dicionário pequeno, salvo como está (só tipos JSON).
var ability_state: Dictionary = {}

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
	# Arte da raça do dono (UnitArtCatalog) — único ponto, junto com apply_form; só apresentação.
	unit_data = UnitArtCatalog.for_owner(data, player)
	owner_player = player
	coord = start_coord
	is_camp_boss = camp_boss
	hp = data.max_hp
	movement_left = data.movement_points
	_build_visual()

func reset_movement() -> void:
	# V3 / Etapa 2: Petrificação/Enraizado (Movimento 0) e Abalado (−1) no turno próprio da vítima.
	movement_left = UnitStatusEffects.adjusted_movement(self, unit_data.movement_points)

## Troca a FORMA desta MESMA unidade por `new_data` (upgrade V2, ver V2UnitUpgrade) —
## não cria uma tropa nova: o objeto continua o mesmo, então dono, coord, serial_id,
## kills/veterania, recargas/estados (magic_cooldowns/magic_status), ordens e o resto
## do estado persistente seguem intactos. Só o que DEPENDE do tipo é refeito: o
## visual (corpo, base, barra de vida, ícone) e o HP, que preserva o PERCENTUAL
## (9/18 vira 12/24) e nunca passa do máximo novo. A troca de forma em si não cura: a cura da evolução é do
## V2UnitUpgrade.perform_upgrade (UPGRADE_HEAL_FRACTION), por cima disto.
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
	_clear_boat_state()
	_braced = false # novo modelo: a postura da Muralha recomeça (refresh_technique_marker abaixo reaplica se ativa)
	idle_animation = DEFAULT_ANIMATION
	moving_animation = WALK_ANIMATION
	attack_animation = ""
	_marker_height = HP_BAR_Y
	unit_data = UnitArtCatalog.for_owner(new_data, owner_player)
	_build_visual()
	set_boat_visual(embarked, false) # evoluiu/trocou de forma na água (ex.: load): continua de barco
	set_hp_silent(minf(new_data.max_hp, hp_fraction * new_data.max_hp))
	refresh_technique_marker()

const TECHNIQUE_MARKER_NAME := "V2TechniqueMarker"
const TECHNIQUE_MARKER_COLOR := Color(0.55, 0.95, 1.0, 0.95)

## Anel azul na base enquanto a unidade tem uma Técnica Militar de Doutrina ATIVA
## (V2TechniqueRuntime) — feedback mínimo no mapa, sem asset novo. Idempotente: chame
## depois de ativar/expirar, de restaurar um save e de trocar de forma.
func refresh_technique_marker(animate_brace: bool = true) -> void:
	_refresh_brace_visual(animate_brace)
	if preload("res://scripts/vfx/CombatFeedback.gd").defer_call(self, &"refresh_technique_marker", [false], true): return
	preload("res://scripts/vfx/SpellStatusFX.gd").sync(self)
	var aegis_active := V2OwnerTurnEffect.is_active(magic_status, "v2_spell_sacred_aegis")
	var aegis := get_node_or_null("SacredAegis")
	if aegis_active and aegis == null:
		aegis = preload("res://scripts/vfx/SacredAegisFX.gd").new()
		add_child(aegis)
		aegis.setup(self)
	elif not aegis_active and aegis != null:
		remove_child(aegis)
		aegis.queue_free()
	var existing := get_node_or_null(TECHNIQUE_MARKER_NAME)
	# School-specific status markers replace the generic ring; techniques still use it.
	var active := V2TechniqueRuntime.active_technique_name(self) != ""
	for status_id in magic_status:
		if status_id != "v2_spell_sacred_aegis" and status_id not in preload("res://scripts/vfx/SpellStatusFX.gd").MANAGED and V2MagicRuntime.is_status_active(self,status_id) and V2SpellDatabase.get_spell(status_id)!=null:
			active = true
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

## Linha do Guardião — Muralha de Escudos ativa (V2TechniqueRuntime): a unidade ERGUE o escudo (clipe de ativação, que
## emenda no loop da postura) e fica na POSTURA no lugar do Idle até o efeito expirar; aí volta ao Idle com o crossfade
## normal. `animate_brace` = false (load de save) entra direto na postura, sem repetir o "erguer". Só visual.
var _braced := false

func _refresh_brace_visual(animate_brace: bool = true) -> void:
	var hold := unit_data.shield_wall_hold_animation_override if unit_data != null else ""
	if hold == "" or _anim_player == null or not _anim_player.has_animation(hold):
		return
	var braced := V2TechniqueRuntime.is_active(self, V2DoctrineTechniqueDatabase.SHIELD_WALL)
	if braced == _braced:
		return
	_braced = braced
	if braced:
		var enter := unit_data.shield_wall_animation_override
		_anim_player.play(enter if animate_brace and _anim_player.has_animation(enter) else hold)
	else:
		_anim_player.play(idle_animation)

## O clipe de "parado" agora: a postura da Muralha enquanto ela durar, senão o Idle.
func _rest_animation() -> String:
	return unit_data.shield_wall_hold_animation_override if _braced else idle_animation

const STATUS_MARKER_NAME := "V3StatusMarker"
const BARRIER_MARKER_NAME := "V3BarrierMarker"
## V3 / Etapa 3 — estados da Combat Ecology por prioridade de leitura (um só é mostrado no anel; o rótulo lista
## o principal). Cores próprias, distintas do ciano de Técnica/Égide e do cinza de "sem comando".
const STATUS_MARKER_ORDER := [
	[UnitStatusEffects.PETRIFIED, Color(0.72, 0.72, 0.76), "Petrificado"],
	[UnitStatusEffects.ROOTED, Color(0.55, 0.38, 0.16), "Enraizado"],
	[UnitStatusEffects.SILENCED, Color(0.68, 0.38, 1.0), "Silenciado"],
	[UnitStatusEffects.BURNING, Color(1.0, 0.5, 0.12), "Em Chamas"],
	[UnitStatusEffects.POISON, Color(0.45, 0.95, 0.3), "Envenenado"],
	[UnitStatusEffects.STAGGERED, Color(1.0, 0.82, 0.25), "Abalado"],
]

## V3 / Etapa 3 — indicador de estado temporário (render-only, idempotente): anel colorido + rótulo curto do
## estado mais importante, e uma casca translúcida enquanto houver Barreira Arcana. Nós próprios (não usa
## material_overlay, que o flash de dano limpa). Chamado ao aplicar/expirar estado, ao ganhar barreira e no load —
## e avisa EventBus.unit_status_changed (Etapa 4) para o card atualizar os chips.
func refresh_status_overlay() -> void:
	if preload("res://scripts/vfx/CombatFeedback.gd").defer_call(self, &"refresh_status_overlay", [], true): return
	var chosen: Array = []
	for entry in STATUS_MARKER_ORDER:
		if magic_status.has(entry[0]):
			chosen = entry
			break
	var existing := get_node_or_null(STATUS_MARKER_NAME)
	if existing != null and (chosen.is_empty() or existing.get_meta("status", "") != chosen[0]):
		remove_child(existing)
		existing.queue_free()
		existing = null
	if not chosen.is_empty() and existing == null:
		var marker := Node3D.new()
		marker.name = STATUS_MARKER_NAME
		marker.set_meta("status", chosen[0])
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.3
		mesh.outer_radius = 0.4
		ring.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(chosen[1].r, chosen[1].g, chosen[1].b, 0.9)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		ring.position.y = 0.14
		marker.add_child(ring)
		var label := Label3D.new()
		label.text = String(chosen[2])
		label.font_size = 26
		label.outline_size = 8
		label.modulate = chosen[1]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = _marker_height + 0.22
		marker.add_child(label)
		add_child(marker)
	var barrier := get_node_or_null(BARRIER_MARKER_NAME)
	if arcane_barrier > 0.0 and barrier == null:
		var shell := MeshInstance3D.new()
		shell.name = BARRIER_MARKER_NAME
		var sphere := SphereMesh.new()
		sphere.radius = 0.55
		sphere.height = 1.1
		shell.mesh = sphere
		var shell_mat := StandardMaterial3D.new()
		shell_mat.albedo_color = Color(0.68, 0.38, 1.0, 0.18)
		shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		shell.material_override = shell_mat
		shell.position.y = 0.5
		add_child(shell)
	elif arcane_barrier <= 0.0 and barrier != null:
		remove_child(barrier)
		barrier.queue_free()
	EventBus.unit_status_changed.emit(self) # V3 / Etapa 4: chips do card da unidade (event-driven)

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
	if get_meta("feedback_retired", false): return false
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
## Embarque automático: para cada trecho de _walk_queue, se o tile de chegada é água (barco) ou terra (tropa).
var _walk_water: Array[bool] = []
var _walking: bool = false
var _walk_tween: Tween = null
## Rumo do ULTIMO passo dado (um HexGrid.NEIGHBOR_DIRS; ZERO = sem rumo: recem-criada, teleportada, carregada do
## save). HexGrid.move_unit grava; o roteador (HexGrid.unit_path/unit_route) parte dele para a proxima rota continuar
## reto em vez de trocar de perna a cada replanejamento. So preferencia entre rotas de mesmo custo — nao vai pro save.
var travel_dir: Vector2i = Vector2i.ZERO

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
var _movement_skill_clip := ""

##
## `water_steps` (embarque automático, HexGrid.move_unit): um bool por waypoint — chegar nele é estar na água. Vazio =
## nenhum passo troca de visual (quem não embarca, ou chamadas que só deslizam a unidade).
func walk_path(waypoints: Array[Vector3], animation_override: String = "", water_steps: Array[bool] = []) -> void:
	if waypoints.is_empty():
		return
	var feedback := preload("res://scripts/vfx/CombatFeedback.gd").current()
	if feedback != null and feedback.source_ref.get_ref() != self:
		if preload("res://scripts/vfx/CombatFeedback.gd").defer_call(self, &"walk_path", [waypoints, animation_override, water_steps], true): return
	if has_meta("feedback_revision_place_at"):
		set_meta("feedback_revision_place_at", int(get_meta("feedback_revision_place_at")) + 1)
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
		if water_steps.size() == waypoints.size():
			set_boat_visual(water_steps[-1], false)
		return

	_walk_queue.append_array(waypoints)
	for i in waypoints.size():
		# Sem flag: o passo mantém o visual de quem chega nele (o último enfileirado, ou o atual).
		_walk_water.append(water_steps[i] if i < water_steps.size() else (_walk_water[-1] if not _walk_water.is_empty() else _boat_shown))
	if animation_override != "" and _anim_player != null and _anim_player.has_animation(animation_override):
		_movement_skill_clip = animation_override
	if _walking:
		if _movement_skill_clip != "": _play_animation(_movement_skill_clip)
		return # ja tem um _advance_walk_queue rodando, ele vai pegar isso sozinho
	_walking = true
	_play_animation(_movement_skill_clip if _movement_skill_clip != "" else moving_animation)
	_advance_walk_queue()

## "Motor" que consome _walk_queue um trecho de cada vez -- so este metodo
## cria Tween novo, entao nunca ha dois Tweens de "position" competindo na
## mesma unidade.
func _advance_walk_queue() -> void:
	if _walk_queue.is_empty():
		_walking = false
		_update_boat_animation()
		if _facing_pending:
			_turn_to_facing_target()
		var movement_clip := _movement_skill_clip
		_movement_skill_clip = ""
		# Carga/ataque podem começar enquanto a aproximação ainda desliza.
		# Ao chegar, deixe o golpe terminar; o callback já volta ao repouso.
		if _anim_player != null and _anim_player.is_playing():
			var current_clip := String(_anim_player.current_animation)
			if current_clip != movement_clip and (_is_attack_clip(current_clip) or current_clip == cast_animation or unit_data.technique_animation_overrides.values().has(current_clip)):
				return
		_play_animation(_rest_animation())
		return
	var target_pos: Vector3 = _walk_queue.pop_front()
	var to_water: bool = _walk_water.pop_front() if not _walk_water.is_empty() else _boat_shown
	var direction = target_pos - position
	direction.y = 0.0
	_stop_facing_turn() # o passo assume o giro; um giro de ataque pendente brigaria pela mesma propriedade
	var tween = create_tween()
	_walk_tween = tween
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE)
	if direction.length() > 0.05:
		tween.tween_property(self, "rotation:y", shortest_yaw_to(atan2(direction.x, direction.z)), MOVE_DURATION * 0.6)
	# Embarque automático: o passo que cruza a margem troca tropa <-> barco no MEIO do trecho (quando a unidade passa
	# pela borda entre os dois hexes), não antes de sair nem depois de chegar.
	if to_water != _boat_shown:
		tween.tween_callback(set_boat_visual.bind(to_water, true)).set_delay(MOVE_DURATION * 0.5)
	tween.finished.connect(_advance_walk_queue)

## Coloca a unidade em `target_pos` NA HORA — o unico jeito de reposiciona-la sem animar (movimento fora da tela,
## teleporte, terreno que muda de altura embaixo dela, patrulha de covil fora da neblina). Cancela a caminhada em
## andamento: escrever `position` direto com um passo ainda rodando deixava o Tween sobrescrever a posicao nos quadros
## seguintes e a fila continuar — a unidade terminava parada no tile ERRADO (o estado logico em um, o corpo em outro) e
## o proximo movimento saia de la, atravessando o mapa na diagonal.
func place_at(target_pos: Vector3) -> void:
	if preload("res://scripts/vfx/CombatFeedback.gd").defer_call(self, &"place_at", [target_pos], true): return
	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	_walk_tween = null
	_walk_queue.clear()
	_walk_water.clear()
	position = target_pos
	if _walking:
		_advance_walk_queue() # fila vazia: encerra a caminhada pelo caminho de sempre (repouso, giro pendente, barco)

## --- EMBARQUE AUTOMÁTICO: o barquinho ------------------------------------------------------------------------------
## O barco da raça do dono (UnitArtCatalog.boat_scene_path_for) é montado SOB DEMANDA, na primeira vez que a unidade
## entra na água, dentro de _visual_root (recebe a reação de dano como o corpo). Trocar de visual é ESCALA cruzada:
## o corpo da tropa (modelo, cópias da formação, emblema) encolhe enquanto o barco cresce, BOAT_SWAP_DURATION, curva
## TRANS_BACK — sem transparência (não briga com o foco visual/neblina, que mexem em material). No fim, o lado encolhido
## fica invisível e o AnimationPlayer dele para (custo zero). Idle <-> walk do barco com crossfade de BOAT_BLEND_TIME.
const BOAT_NODE_NAME := "EmbarkBoat"
const BOAT_SWAP_DURATION := 0.25
const BOAT_HIDDEN_SCALE := 0.001 # nunca 0: base singular gera aviso de transform

var _boat_root: Node3D = null
var _boat_player: AnimationPlayer = null
var _boat_shown := false
var _troop_part_scales: Dictionary = {} # Node3D -> escala original (capturada antes de encolher)
var _boat_swap_tween: Tween = null

func is_boat_visual() -> bool:
	return _boat_shown

## Mostra o barco (`on`) ou a tropa. `animate` = troca cruzada suave; false = imediata (spawn, load, fora da tela).
func set_boat_visual(on: bool, animate: bool = true) -> void:
	if on == _boat_shown or _visual_root == null:
		return
	if on and not _ensure_boat():
		return # sem modelo de barco: segue com a tropa (nunca some)
	_boat_shown = on
	if _boat_swap_tween != null and _boat_swap_tween.is_valid():
		_boat_swap_tween.kill()
	_boat_swap_tween = null
	var parts := _troop_parts()
	for part in parts:
		if not _troop_part_scales.has(part):
			_troop_part_scales[part] = part.scale
	var boat_full := _boat_full_scale()
	if not animate or not is_inside_tree():
		for part in parts:
			part.visible = not on
			part.scale = _troop_part_scales[part] if not on else _troop_part_scales[part] * BOAT_HIDDEN_SCALE
		_boat_root.visible = on
		_boat_root.scale = boat_full if on else boat_full * BOAT_HIDDEN_SCALE
		_apply_marker_height(on)
		_finish_boat_swap()
		return
	var tween := create_tween().set_parallel(true)
	for part in parts:
		var full: Vector3 = _troop_part_scales[part]
		if on:
			tween.tween_property(part, "scale", full * BOAT_HIDDEN_SCALE, BOAT_SWAP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		else:
			part.visible = true
			if part.scale.length() > full.length():
				part.scale = full * BOAT_HIDDEN_SCALE
			tween.tween_property(part, "scale", full, BOAT_SWAP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if on:
		_boat_root.visible = true
		_boat_root.scale = boat_full * BOAT_HIDDEN_SCALE
		tween.tween_property(_boat_root, "scale", boat_full, BOAT_SWAP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(_boat_root, "scale", boat_full * BOAT_HIDDEN_SCALE, BOAT_SWAP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_finish_boat_swap)
	_boat_swap_tween = tween
	# O lado que APARECE já anima no estado certo (o barco rema se está andando; a tropa volta a andar/descansar).
	_set_troop_animation_active(true)
	if _boat_player != null:
		_boat_player.active = true
	_apply_marker_height(on)
	_update_boat_animation()
	if not on:
		_play_animation(moving_animation if _walking else _rest_animation())

## Fim da troca: o lado escondido sai da renderização e o AnimationPlayer dele para.
func _finish_boat_swap() -> void:
	_boat_swap_tween = null
	for part in _troop_parts():
		part.visible = not _boat_shown
	if _boat_root != null:
		_boat_root.visible = _boat_shown
	_set_troop_animation_active(not _boat_shown)
	if _boat_player != null:
		_boat_player.active = _boat_shown
	_update_boat_animation()
	if not _boat_shown:
		_play_animation(moving_animation if _walking else _rest_animation())
	_refresh_animation_culling() # o barco nasce depois da caixa de visão: entra na regra aqui

## O corpo da tropa: tudo dentro de _visual_root menos o próprio barco.
func _troop_parts() -> Array[Node3D]:
	var parts: Array[Node3D] = []
	if _visual_root == null:
		return parts
	for child in _visual_root.get_children():
		if child is Node3D and child != _boat_root:
			parts.append(child)
	return parts

func _set_troop_animation_active(active: bool) -> void:
	if _anim_player != null:
		_anim_player.active = active
	for player in _formation_players:
		if is_instance_valid(player):
			player.active = active

## Escala do barco DENTRO de _visual_root: compensa o multiplicador do corpo procedural (visual_template), para o barco
## ter sempre o tamanho do pacote (a escala de mapa já vem na cena).
func _boat_full_scale() -> Vector3:
	var root_scale := _visual_root.scale if _visual_root != null else Vector3.ONE
	return Vector3(1.0 / maxf(root_scale.x, 0.001), 1.0 / maxf(root_scale.y, 0.001), 1.0 / maxf(root_scale.z, 0.001))

func _ensure_boat() -> bool:
	if _boat_root != null and is_instance_valid(_boat_root):
		return true
	var path := UnitArtCatalog.boat_scene_path_for(owner_player)
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("Unit: barco ausente '%s' — a tropa segue visível na água." % path)
		return false
	_boat_root = Node3D.new()
	_boat_root.name = BOAT_NODE_NAME
	var model: Node3D = scene.instantiate()
	model.rotation.y = deg_to_rad(UnitArtCatalog.BOAT_YAW_DEGREES)
	_boat_root.add_child(model)
	# Antes de entrar na árvore: o post-import (tools/art_pipeline/embark_boat_import.gd) liga autoplay de `idle`; quem
	# decide o clipe aqui é o estado de andar da unidade (_update_boat_animation).
	_boat_player = _find_animation_player(model)
	if _boat_player != null:
		_boat_player.autoplay = ""
		for clip in [UnitArtCatalog.BOAT_IDLE_CLIP, UnitArtCatalog.BOAT_WALK_CLIP]:
			if _boat_player.has_animation(clip):
				_boat_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_boat_player.playback_default_blend_time = UnitArtCatalog.BOAT_BLEND_TIME
	_visual_root.add_child(_boat_root)
	_boat_root.visible = false
	_boat_root.scale = _boat_full_scale() * BOAT_HIDDEN_SCALE
	if _boat_player != null:
		_boat_player.play(UnitArtCatalog.BOAT_IDLE_CLIP)
	# Barra de vida/ícone acima do mastro enquanto embarcado, se o barco for mais alto que a tropa.
	_troop_marker_height = _marker_height
	var bounds = _model_aabb(_boat_root)
	_boat_marker_height = maxf(_troop_marker_height, (bounds.end.y + 0.12) if bounds != null else 0.0)
	return true

## Altura dos marcadores (barra de vida, ícone de tropa, emblema): a do barco enquanto ele aparece, a da tropa em terra.
var _troop_marker_height := HP_BAR_Y
var _boat_marker_height := HP_BAR_Y

## Altura LOCAL do topo do que flutua acima da unidade — o selo (_build_troop_icon). Para quem precisa pôr algo
## ACIMA da unidade sem sobrepor nada dela (a barra de progresso de uma obra no mesmo tile, ver VisualFocusSystem).
func markers_top_height() -> float:
	return _marker_height + 0.2 + IconCatalog.BADGE_SIZE * 0.5 * TROOP_ICON_PIXEL_SIZE

func _apply_marker_height(boat: bool) -> void:
	var target := _boat_marker_height if boat else _troop_marker_height
	var delta := target - _marker_height
	if is_zero_approx(delta):
		return
	_marker_height = target
	for node in [_hp_bar_bg, _hp_bar_fg, get_node_or_null(TROOP_ICON_NAME)]:
		if node != null and is_instance_valid(node):
			(node as Node3D).position.y += delta

## Barco andando (rema/balança mais) enquanto há trecho na fila; parado, o balanço calmo. Crossfade no próprio player.
func _update_boat_animation() -> void:
	if _boat_player == null or not _boat_shown:
		return
	var clip := UnitArtCatalog.BOAT_WALK_CLIP if _walking else UnitArtCatalog.BOAT_IDLE_CLIP
	if _boat_player.has_animation(clip) and _boat_player.current_animation != clip:
		_boat_player.play(clip)

const TROOP_ICON_NAME := "TroopIcon"

func _clear_boat_state() -> void:
	if _boat_swap_tween != null and _boat_swap_tween.is_valid():
		_boat_swap_tween.kill()
	_boat_swap_tween = null
	_boat_root = null
	_boat_player = null
	_boat_shown = false
	_troop_part_scales.clear()
	_troop_marker_height = HP_BAR_Y
	_boat_marker_height = HP_BAR_Y

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
	_marker_height = maxf(_marker_height, unit_data.marker_min_height)
	_visual_root = Node3D.new()
	add_child(_visual_root)
	move_child(_visual_root, 0)
	for child in get_children():
		if child != _visual_root:
			child.reparent(_visual_root, false)
	if unit_data.visual_template != "":
		_visual_root.scale = Vector3.ONE * unit_data.model_scale_multiplier # distingue as formas que compartilham o mesmo corpo procedural
	# Nada no chao embaixo da unidade (pedido do usuario 2026-10-10: o disco colorido sob os pes saiu de TODAS —
	# tropas, monstros, barcos). Fora do corpo, a unidade so tem o que flutua acima dela (barra de vida, icone) e os
	# aros de ESTADO, que so existem enquanto o estado dura (Tecnica, status, sem comando).
	_build_hp_bar()
	_build_troop_icon()
	_build_animation_culling(bounds)

## --- ANIMAÇÃO SÓ ONDE ALGUÉM VÊ (otimização, 2026-10-14; docs/PERFORMANCE_GUIDE.md §6) -------------------------------
## Uma unidade fora da câmera ou escondida pela névoa não precisa avançar o esqueleto: o AnimationPlayer dela fica com
## process_mode DISABLED (nenhum quadro processado, nenhum cache limpo — ao contrário de `active`, que o barco usa) e
## volta a INHERIT quando a unidade entra na tela, continuando do ponto em que parou. Nada visível muda: a caixa do
## VisibleOnScreenNotifier3D é a do modelo com folga de ANIM_CULL_MARGIN (a sombra de uma unidade logo fora da borda
## continua animando). Clipe de UMA vez (golpe, feitiço, trabalho, pouso) nunca é pausado no meio: termina e só então
## a unidade, já no ciclo de repouso, para. Headless (testes GUT, laboratório de balanceamento) não tem câmera: nada
## é pausado e o comportamento é o de sempre.
const ANIM_CULL_NODE := "AnimCull"
const ANIM_CULL_MARGIN := 4.0
var _anim_cull_notifier: VisibleOnScreenNotifier3D = null

func _build_animation_culling(bounds) -> void:
	_anim_cull_notifier = null
	if DisplayServer.get_name() == "headless" or _anim_player == null:
		return
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.name = ANIM_CULL_NODE
	var box: AABB = bounds if bounds != null else AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	notifier.aabb = box.grow(ANIM_CULL_MARGIN)
	add_child(notifier)
	_anim_cull_notifier = notifier
	notifier.screen_entered.connect(_refresh_animation_culling)
	notifier.screen_exited.connect(_refresh_animation_culling)
	if not visibility_changed.is_connected(_refresh_animation_culling):
		visibility_changed.connect(_refresh_animation_culling)
	_refresh_animation_culling.call_deferred()

func _animation_players() -> Array[AnimationPlayer]:
	var players: Array[AnimationPlayer] = []
	if _anim_player != null and is_instance_valid(_anim_player):
		players.append(_anim_player)
	for player in _formation_players:
		if is_instance_valid(player):
			players.append(player)
	if _boat_player != null and is_instance_valid(_boat_player):
		players.append(_boat_player)
	return players

## Alguém pode estar vendo esta unidade agora?
func animation_on_screen() -> bool:
	if _anim_cull_notifier == null or not is_instance_valid(_anim_cull_notifier):
		return true
	return is_visible_in_tree() and _anim_cull_notifier.is_on_screen()

func _refresh_animation_culling() -> void:
	if _anim_cull_notifier == null or not is_inside_tree():
		return
	var seen := animation_on_screen()
	for player in _animation_players():
		# Um clipe pedido com o player já pausado (golpe da IA fora da tela) também reavalia: sinal emitido no play().
		if not player.current_animation_changed.is_connected(_on_culled_animation_changed):
			player.current_animation_changed.connect(_on_culled_animation_changed)
		if seen:
			player.process_mode = Node.PROCESS_MODE_INHERIT
		elif _playing_one_shot(player):
			player.process_mode = Node.PROCESS_MODE_INHERIT
			if not player.animation_finished.is_connected(_on_culled_one_shot_finished):
				player.animation_finished.connect(_on_culled_one_shot_finished, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
		else:
			player.process_mode = Node.PROCESS_MODE_DISABLED

func _on_culled_one_shot_finished(_clip: StringName) -> void:
	_refresh_animation_culling()

func _on_culled_animation_changed(_clip: String) -> void:
	if not animation_on_screen():
		_refresh_animation_culling()

func _playing_one_shot(player: AnimationPlayer) -> bool:
	if not player.is_playing() or not player.has_animation(player.current_animation):
		return false
	return player.get_animation(player.current_animation).loop_mode == Animation.LOOP_NONE

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
	if preload("res://scripts/vfx/CombatFeedback.gd").defer_call(self, &"_play_hit_reaction"): return
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
## unidade existente. Quem tem mais de um conjunto de clipes (o Dragao: no ar e em
## terra) troca os tres de uma vez com set_posture(), sem duplicar/reescrever a
## logica de troca de animacao em si.
var moving_animation: String = WALK_ANIMATION
var idle_animation: String = DEFAULT_ANIMATION

## "" para unidade sem clipe de ataque. Unidades com UnitData.
## attack_animation_override ganham esse nome aqui em _build_model_body();
## o combate toca por play_attack_visual / play_city_attack_visual.
var attack_animation: String = ""
## Clipe de conjuração resolvido do UnitData (magos); "" = feitiços sem animação na unidade.
var cast_animation: String = ""

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

## false = a cena não carregou (arquivo ausente/não importado): o chamador cai no corpo procedural em
## vez de quebrar o turno com `instantiate` em null.
func _build_model_body() -> bool:
	var scene := load(unit_data.model_scene_path) as PackedScene if ResourceLoader.exists(unit_data.model_scene_path) else null
	if scene == null:
		push_warning("Unit: modelo ausente '%s' (%s) — usando corpo procedural." % [unit_data.model_scene_path, unit_data.visual_kind])
		return false
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
		cast_animation = unit_data.cast_animation_override
		_anim_player = _build_animation_player(model)
		if _anim_player:
			_anim_player.play(idle_animation)
	_build_formation_copies(model)
	_build_core_glow(model)
	_build_fire_breath(model)
	posture = unit_data.default_posture if unit_data.posture_animations.has(unit_data.default_posture) else ""
	return true

## POSTURAS (UnitData.posture_animations — o Dragão: "flying" e "ground"). Uma postura é um conjunto de clipes
## (parado, andar, atacar); trocar de postura troca os três de uma vez e leva o clipe que está tocando para o
## equivalente da postura nova, com a transição de postura (pouso/decolagem). "" = unidade sem posturas.
var posture: String = ""

## Troca para a postura `posture_name`. true se a unidade tem essa postura (mesmo que já estivesse nela).
func set_posture(posture_name: String) -> bool:
	var clips: Dictionary = unit_data.posture_animations.get(posture_name, {}) if unit_data != null else {}
	if clips.is_empty():
		return false
	if posture_name == posture:
		return true
	var previous := {idle_animation: "idle", moving_animation: "walk", attack_animation: "attack"}
	posture = posture_name
	idle_animation = String(clips.get("idle", idle_animation))
	moving_animation = String(clips.get("walk", moving_animation))
	attack_animation = String(clips.get("attack", attack_animation))
	if _anim_player == null:
		return true
	# Parado ou andando: segue no mesmo estado, agora na postura nova. Um ataque em curso termina como começou; o
	# retorno dele (_on_blended_animation_finished) já cai no parado/andar da postura nova.
	var role := String(previous.get(String(_anim_player.current_animation), ""))
	var target := moving_animation if role == "walk" else (idle_animation if role == "idle" else "")
	if target != "" and _anim_player.has_animation(target) and String(_anim_player.current_animation) != target:
		_play_model_animation(_anim_player, target, false, unit_data.posture_transition_time)
	return true

## `clip` é um golpe desta unidade: o ataque da postura atual ou o de qualquer outra (um golpe começado numa postura
## pode terminar depois de a unidade trocar para outra — ainda é um clipe de uma vez só, que volta ao parado).
func _is_attack_clip(clip: String) -> bool:
	if clip == "":
		return false
	if clip == attack_animation:
		return true
	for clips in unit_data.posture_animations.values():
		if String((clips as Dictionary).get("attack", "")) == clip:
			return true
	return false

## SOPRO DE FOGO (UnitData.fire_breath_bone — o Dragão). Emissor de partículas e luz presos ao osso da boca por um
## BoneAttachment3D (seguem a cabeça em qualquer clipe), DESLIGADOS até play_fire_breath. O eixo +Y do osso aponta
## para a frente; as partículas ficam no mundo (não giram com a cabeça depois de soltas).
const FIRE_BREATH_ANCHOR := "FireBreathAnchor"
const FIRE_BREATH_EMITTER := "FireBreathEmitter"
const FIRE_BREATH_LIGHT := "FireBreathLight"
const FIRE_BREATH_LIGHT_ENERGY := 4.0
const FIRE_BREATH_LIGHT_FADE_IN := 0.15
const FIRE_BREATH_LIGHT_FADE_OUT := 0.45
var _fire_breath_emitter: GPUParticles3D
var _fire_breath_light: OmniLight3D
var _fire_breath_tween: Tween

func _build_fire_breath(model: Node3D) -> void:
	_fire_breath_emitter = null
	_fire_breath_light = null
	if unit_data.fire_breath_bone == "":
		return
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty() or (skeletons[0] as Skeleton3D).find_bone(unit_data.fire_breath_bone) < 0:
		return
	var anchor := BoneAttachment3D.new()
	anchor.name = FIRE_BREATH_ANCHOR
	skeletons[0].add_child(anchor)
	anchor.bone_name = unit_data.fire_breath_bone

	var emitter := GPUParticles3D.new()
	emitter.name = FIRE_BREATH_EMITTER
	emitter.emitting = false
	emitter.one_shot = false
	emitter.local_coords = false
	emitter.amount = 110
	emitter.lifetime = 0.55
	emitter.randomness = 0.35
	emitter.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var particle_mesh := BoxMesh.new() # blocos, como o resto da arte
	particle_mesh.size = Vector3(0.22, 0.22, 0.22)
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.vertex_color_use_as_albedo = true
	particle_material.emission_enabled = true
	particle_material.emission = Color(1.0, 0.45, 0.05)
	particle_material.emission_energy_multiplier = 2.5
	particle_mesh.material = particle_material
	emitter.draw_pass_1 = particle_mesh
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0) # +Y do osso = para a frente
	process.spread = 13.0
	process.initial_velocity_min = 5.0
	process.initial_velocity_max = 8.0
	process.gravity = Vector3(0, 0.8, 0)
	process.scale_min = 0.45
	process.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.45))
	ramp.set_color(1, Color(0.85, 0.12, 0.02, 0.0))
	ramp.add_point(0.45, Color(1.0, 0.5, 0.06))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	emitter.process_material = process
	anchor.add_child(emitter)

	var light := OmniLight3D.new()
	light.name = FIRE_BREATH_LIGHT
	light.light_color = Color(1.0, 0.6, 0.15)
	light.light_energy = 0.0 # só acende durante a rajada
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.visible = false
	light.position = Vector3(0, 1.2, 0) # um pouco à frente da boca, onde o fogo está
	anchor.add_child(light)
	_fire_breath_emitter = emitter
	_fire_breath_light = light

## Dispara a rajada: começa `fire_breath_start` segundos depois (quando o clipe de ataque abre a boca) e para em
## `fire_breath_end`. Chamar junto com o clipe de ataque. Uma rajada nova cancela a anterior. Só visual.
func play_fire_breath() -> void:
	if _fire_breath_emitter == null or not is_instance_valid(_fire_breath_emitter):
		return
	stop_fire_breath()
	if not is_inside_tree():
		return
	var duration := maxf(unit_data.fire_breath_end - unit_data.fire_breath_start, 0.1)
	_fire_breath_tween = create_tween()
	_fire_breath_tween.tween_interval(maxf(unit_data.fire_breath_start, 0.0))
	_fire_breath_tween.tween_callback(_set_fire_breath.bind(true))
	_fire_breath_tween.tween_property(_fire_breath_light, "light_energy", FIRE_BREATH_LIGHT_ENERGY, FIRE_BREATH_LIGHT_FADE_IN)
	_fire_breath_tween.tween_interval(maxf(duration - FIRE_BREATH_LIGHT_FADE_IN, 0.0))
	_fire_breath_tween.tween_callback(_set_fire_breath.bind(false))
	_fire_breath_tween.tween_property(_fire_breath_light, "light_energy", 0.0, FIRE_BREATH_LIGHT_FADE_OUT)
	_fire_breath_tween.tween_callback(func() -> void: _fire_breath_light.visible = false)

func stop_fire_breath() -> void:
	if _fire_breath_tween != null and _fire_breath_tween.is_valid():
		_fire_breath_tween.kill()
	_fire_breath_tween = null
	if _fire_breath_emitter != null and is_instance_valid(_fire_breath_emitter):
		_fire_breath_emitter.emitting = false
	if _fire_breath_light != null and is_instance_valid(_fire_breath_light):
		_fire_breath_light.light_energy = 0.0
		_fire_breath_light.visible = false

func _set_fire_breath(on: bool) -> void:
	if _fire_breath_emitter != null and is_instance_valid(_fire_breath_emitter):
		_fire_breath_emitter.emitting = on
	if on and _fire_breath_light != null and is_instance_valid(_fire_breath_light):
		_fire_breath_light.visible = true

func has_fire_breath() -> bool:
	return _fire_breath_emitter != null and is_instance_valid(_fire_breath_emitter)

func is_breathing_fire() -> bool:
	return has_fire_breath() and _fire_breath_emitter.emitting

## TOMBO DE MORTE (Dragão abatido): o corpo perde a sustentação e tomba de lado em `duration` segundos. Gira a própria
## Unit — é terminal, ela é removida do mapa logo depois, então não briga com o movimento. Fora da árvore, tomba na hora.
const DEATH_TOPPLE_DEGREES := 85.0

func play_death_topple(duration: float = 1.2) -> void:
	stop_fire_breath()
	_stop_facing_turn()
	if not is_inside_tree() or duration <= 0.0:
		rotation.z = deg_to_rad(DEATH_TOPPLE_DEGREES)
		return
	create_tween().tween_property(self, "rotation:z", deg_to_rad(DEATH_TOPPLE_DEGREES), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## NÚCLEO QUE ILUMINA (UnitData.glow_profile — Grandes Manifestações): o mesmo efeito dos cristais do mapa, pelo mesmo
## sistema (HexGrid.world_glow). Uma luz sem sombra presa ao osso do núcleo (acompanha a flutuação e os gestos; some
## com o modelo na névoa, no embarque e na morte) e o mapa de emissão do modelo crescendo com a escuridão. Unidade
## fora de um HexGrid (cena de revisão, teste isolado) fica só com a emissão que o modelo já tem.
const CORE_GLOW_ANCHOR := "CoreGlowAnchor"

func _build_core_glow(model: Node3D) -> void:
	if unit_data.glow_profile == &"" or not GlowProfiles.has_profile(unit_data.glow_profile):
		return
	var glow := _world_glow()
	if glow == null:
		return
	var anchor: Node3D = model
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty() and (skeletons[0] as Skeleton3D).find_bone(unit_data.glow_bone) >= 0:
		var attachment := BoneAttachment3D.new()
		attachment.name = CORE_GLOW_ANCHOR
		skeletons[0].add_child(attachment)
		attachment.bone_name = unit_data.glow_bone
		anchor = attachment
	glow.attach_light(WorldGlow.GROUP_UNITS, get_instance_id(), anchor, unit_data.glow_profile)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance.mesh != null and instance.mesh.get_surface_count() > 0:
			glow.track_emission(instance.get_active_material(0) as BaseMaterial3D, unit_data.glow_profile)

## O WorldGlow do mapa em que a unidade está (null fora de um HexGrid).
func _world_glow() -> WorldGlow:
	var node := get_parent()
	while node != null:
		if node is HexGrid:
			return (node as HexGrid).world_glow
		node = node.get_parent()
	return null

## A luz do núcleo desta unidade (null se ela não ilumina ou está fora de um mapa).
func core_glow_light() -> OmniLight3D:
	var glow := _world_glow()
	return glow.get_light(WorldGlow.GROUP_UNITS, get_instance_id()) if glow != null else null

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
	# proposito, tocam uma vez so. A postura da Muralha de Escudos (hold) tambem e um ciclo: o import de elfos/orcs
	# vem sem a flag de loop e a postura congelava no ultimo quadro enquanto o efeito durava.
	var looping: Array = [idle_animation, moving_animation, unit_data.shield_wall_hold_animation_override]
	for clips in unit_data.posture_animations.values(): # o Parado e o Andar de TODAS as posturas, não só da inicial
		looping.append(String((clips as Dictionary).get("idle", "")))
		looping.append(String((clips as Dictionary).get("walk", "")))
	for loop_anim_name in looping:
		if library.has_animation(loop_anim_name):
			library.get_animation(loop_anim_name).loop_mode = Animation.LOOP_LINEAR
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.add_animation_library("", library)
	if unit_data.animation_blend_time > 0.0:
		player.playback_default_blend_time = unit_data.animation_blend_time
	if unit_data.animation_blend_time > 0.0 or _uses_pose_transitions():
		player.animation_finished.connect(_on_blended_animation_finished.bind(player))
	if _uses_pose_transitions():
		# Grandes Manifestações: a troca de clipe parte da pose atual do esqueleto (PoseCaptureTransition). Modelo sem
		# esqueleto não tem o que capturar: segue no crossfade comum.
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			var transition := PoseCaptureTransition.new()
			transition.setup(player, skeletons[0] as Skeleton3D)
			player.set_meta(POSE_TRANSITION_META, transition)
	return player

## So pra unidades com UnitData.animation_blend_time > 0 (ou pose_transition_time > 0): o Ataque (LOOP_
## NONE) termina e volta, com crossfade, pro ciclo que faz sentido agora --
## Andar se ainda houver trecho na fila de walk_path(), senao Idle.
func _on_blended_animation_finished(anim_name: StringName, player: AnimationPlayer) -> void:
	if not is_instance_valid(player):
		return
	if _walking and _movement_skill_clip != "" and anim_name == StringName(_movement_skill_clip):
		player.play(_movement_skill_clip)
		return
	# Muralha de Escudos: o clipe de erguer emenda no loop da postura (sem crossfade de volta ao Idle).
	if unit_data.shield_wall_animation_override != "" and anim_name == StringName(unit_data.shield_wall_animation_override):
		if _braced and player.has_animation(unit_data.shield_wall_hold_animation_override):
			player.play(unit_data.shield_wall_hold_animation_override)
		return
	var one_shot := _is_attack_clip(String(anim_name)) \
		or (cast_animation != "" and anim_name == StringName(cast_animation)) \
		or unit_data.technique_animation_overrides.values().has(String(anim_name)) \
		or (unit_data.emerge_animation_override != "" and anim_name == StringName(unit_data.emerge_animation_override)) \
		or (unit_data.block_animation_override != "" and anim_name == StringName(unit_data.block_animation_override))
	one_shot = one_shot or (unit_data.work_animation_override != "" and anim_name == StringName(unit_data.work_animation_override))
	if not one_shot:
		return
	var next_anim := (_movement_skill_clip if _movement_skill_clip != "" else moving_animation) if _walking else _rest_animation()
	if not player.has_animation(next_anim):
		next_anim = idle_animation # sem Walk (Verme): anda no Idle em vez de congelar no fim do Ataque
	if player.has_animation(next_anim):
		_play_model_animation(player,next_anim)

## Clipes de cada cena de animação, na ordem em que eram copiados: [[nome, Animation], ...]. Antes, TODA unidade que
## nascia instanciava a cena inteira (modelo + esqueleto) só para ler as bibliotecas e a descartava — o dobro do custo
## de spawn. As Animation são as mesmas instâncias compartilhadas da PackedScene (mesmo resultado de antes); otimização
## de 2026-10-14, docs/PERFORMANCE_GUIDE.md §6.
static var _animation_clips_cache: Dictionary = {}

func _copy_animations_into(library: AnimationLibrary, scene_path: String) -> void:
	if not _animation_clips_cache.has(scene_path):
		var clips: Array = []
		var anim_scene: PackedScene = load(scene_path)
		var anim_source := anim_scene.instantiate()
		var source_player := _find_animation_player(anim_source)
		if source_player:
			for lib_name in source_player.get_animation_library_list():
				var source_lib := source_player.get_animation_library(lib_name)
				for anim_name in source_lib.get_animation_list():
					clips.append([anim_name, source_lib.get_animation(anim_name)])
		anim_source.free()
		_animation_clips_cache[scene_path] = clips
	for clip in _animation_clips_cache[scene_path]:
		if not library.has_animation(clip[0]):
			library.add_animation(clip[0], clip[1])

## Verme Colossal (Escavar) -- so visual, nunca muda regra. A logica esconde a
## Unit NA HORA do mergulho (sai de units_by_coord, visible = false); isto deixa
## no mesmo lugar uma COPIA do modelo tocando o clipe de entrar na terra, que se
## apaga sozinha no fim (o clipe termina com o corpo todo em escala ~0). So se
## o jogador estava vendo o Verme (visible = neblina) e o modelo tem o clipe.
func play_burrow_visual() -> void:
	var clip := unit_data.burrow_animation_override
	if clip == "" or not visible or _anim_player == null or not _anim_player.has_animation(clip) or get_parent() == null:
		return
	var ghost := Node3D.new()
	ghost.name = "BurrowGhost"
	get_parent().add_child(ghost)
	ghost.global_transform = global_transform
	var model: Node3D = (load(unit_data.model_scene_path) as PackedScene).instantiate()
	model.transform = (_anim_player.get_parent() as Node3D).transform
	ghost.add_child(model)
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.add_animation_library("", _anim_player.get_animation_library(""))
	player.animation_finished.connect(func(_finished: StringName) -> void: ghost.queue_free())
	player.play(clip)

## Verme Colossal (Escavar): ao reaparecer no destino, toca o clipe de sair da
## terra SEM crossfade (o primeiro frame ja e o corpo escondido -- misturar com o
## Idle mostraria o Verme inteiro encolhendo). No fim volta pro Idle com o
## crossfade normal (_on_blended_animation_finished).
func play_emerge_visual() -> void:
	var clip := unit_data.emerge_animation_override
	if clip == "" or _anim_player == null or not _anim_player.has_animation(clip):
		return
	_anim_player.play(clip, 0.0)

## Técnica de ATAQUE em curso (V2TechniqueRuntime.perform_strike): o clipe próprio dela (UnitData.technique_animation_
## overrides) e se ele já tocou neste uso. Um golpe com vários alvos (Ataque em Arco, Saraivada) resolve um combate por
## alvo; o clipe toca UMA vez, virado para o primeiro alvo, em vez de reiniciar a cada um.
var _technique_clip: String = ""
var _technique_clip_started := false

func begin_technique_animation(technique_id: String) -> void:
	_technique_clip = String(unit_data.technique_animation_overrides.get(technique_id, ""))
	_technique_clip_started = false

func end_technique_animation() -> void:
	_technique_clip = ""
	_technique_clip_started = false

var _combat_visual_generation := 0
var _combat_visual_wait := 0.0

func visual_walk_remaining() -> float:
	if not _walking: return 0.0
	var elapsed := _walk_tween.get_total_elapsed_time() if _walk_tween != null and _walk_tween.is_valid() else 0.0
	return maxf(0.0, MOVE_DURATION - elapsed) + _walk_queue.size() * MOVE_DURATION

func _queue_combat_animation(clip: String, casting: bool = false) -> void:
	_combat_visual_generation += 1
	_combat_visual_wait = visual_walk_remaining()
	if _combat_visual_wait > 0.0 and is_inside_tree():
		get_tree().create_timer(_combat_visual_wait, false).timeout.connect(_start_combat_animation.bind(clip, casting, _combat_visual_generation), CONNECT_ONE_SHOT)
	else:
		_start_combat_animation(clip, casting, _combat_visual_generation)

func _start_combat_animation(clip: String, casting: bool, generation: int) -> void:
	if generation != _combat_visual_generation or _anim_player == null: return
	if casting and _anim_player.current_animation == clip:
		if _uses_pose_transitions():
			_play_model_animation(_anim_player, clip, true)
		else:
			_anim_player.seek(0.0, true)
	elif casting:
		_play_model_animation(_anim_player, clip)
	elif _anim_player.current_animation == clip:
		if _uses_pose_transitions():
			_play_model_animation(_anim_player, clip, true)
		else:
			_anim_player.seek(0.0, true)
	else:
		_play_animation(clip)

## GIRO SUAVE (pedido do usuario 2026-10-09: transicoes suaves entre parado/andando/atacando). O clipe ja fazia
## crossfade, mas o CORPO estalava: o ataque setava rotation.y direto, e o passo interpolava o angulo cru (de +170°
## a -170° dava quase uma volta pelo lado errado). Agora todo giro vai pelo caminho curto (shortest_yaw_to) e o
## ataque/bloqueio vira em FACE_TURN_DURATION. Andando, o passo ja aponta para o destino e e dono do giro (o giro de
## ataque espera, nunca briga com o Tween do passo); fora da arvore/da neblina o giro e imediato (nada a animar).
const FACE_TURN_DURATION := 0.15
var _face_tween: Tween
## Para onde a unidade terminou (ou vai terminar) virada — o giro animado chega nele em FACE_TURN_DURATION.
var facing_target_yaw: float = 0.0
## Pedido de giro feito andando (golpe que começa no meio da aproximação): aplicado quando o último passo termina, a
## partir da posição de CHEGADA (o ponto-alvo fica guardado, não o ângulo de quando o pedido foi feito).
var _facing_pending := false
var _facing_point := Vector3.ZERO

## Ângulo equivalente a `target_yaw` mais próximo da rotação atual (diferença em [-PI, PI]).
func shortest_yaw_to(target_yaw: float) -> float:
	return rotation.y + wrapf(target_yaw - rotation.y, -PI, PI)

func face_toward(world_point: Vector3) -> void:
	_facing_point = world_point
	var direction := world_point - position
	direction.y = 0.0
	if direction.length() > 0.05:
		facing_target_yaw = atan2(direction.x, direction.z)
	if _walking:
		_facing_pending = true
		return
	_turn_to_facing_target()

func _turn_to_facing_target() -> void:
	_facing_pending = false
	var direction := _facing_point - position
	direction.y = 0.0
	if direction.length() <= 0.05:
		return
	facing_target_yaw = atan2(direction.x, direction.z)
	_stop_facing_turn()
	var target := shortest_yaw_to(facing_target_yaw)
	if not is_inside_tree() or not visible or is_equal_approx(target, rotation.y):
		rotation.y = target
		return
	_face_tween = create_tween()
	_face_tween.tween_property(self, "rotation:y", target, FACE_TURN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _stop_facing_turn() -> void:
	if _face_tween != null and _face_tween.is_valid():
		_face_tween.kill()
	_face_tween = null

## Visual do ataque (CombatResolver): vira para o defensor e toca o Attack — ou, durante uma técnica com clipe próprio,
## o clipe dela (uma vez por uso). Unidade sem attack_animation segue sem animação de combate (no-op, como sempre foi).
func play_attack_visual(defender: Unit) -> void:
	if attack_animation == "":
		return
	var clip := attack_animation
	if _technique_clip != "" and _anim_player != null and _anim_player.has_animation(_technique_clip):
		if _technique_clip_started:
			return
		clip = _technique_clip
		_technique_clip_started = true
	elif defender != null and defender.unit_data != null and (defender.unit_data.traits.has(UnitData.TRAIT_CASTER) or defender.unit_data.traits.has(UnitData.TRAIT_SIEGE)):
		var dismantle := String(unit_data.technique_animation_overrides.get(V2DoctrineTechniqueDatabase.DISMANTLE, ""))
		if dismantle != "" and _anim_player != null and _anim_player.has_animation(dismantle) and V2UnlockSystem.is_unlocked(owner_player, V2DoctrineTechniqueDatabase.DISMANTLE):
			clip = dismantle
	if defender != null and is_instance_valid(defender):
		face_toward(defender.position)
	set_meta("feedback_attack_clip", clip)
	_queue_combat_animation(clip)

## Feitiço bem-sucedido (V2MagicRuntime.cast — jogador e IA): vira para o alvo (giro suave, face_toward) e toca o clipe
## de conjuração UMA vez; ao terminar, _on_blended_animation_finished volta ao Idle/Andar com o crossfade normal. O MESMO
## clipe serve para todos os feitiços (pedido do usuário). Só visual: o feitiço já foi resolvido. Sem clipe = no-op.
func play_cast_visual(target_world: Vector3) -> void:
	if cast_animation == "" or _anim_player == null or not _anim_player.has_animation(cast_animation):
		return
	face_toward(target_world)
	_queue_combat_animation(cast_animation, true)

## Trabalho do construtor. Na última carga, uma cópia visual termina o
## gesto enquanto a unidade é consumida imediatamente pelas regras.
func play_work_visual(consumed: bool = false) -> void:
	var clip := unit_data.work_animation_override
	if clip == "" or _anim_player == null or not _anim_player.has_animation(clip) or not is_inside_tree():
		return
	if not consumed:
		_anim_player.stop()
		_anim_player.play(clip)
		return
	var model := _anim_player.get_parent() as Node3D
	var ghost := (load(unit_data.model_scene_path) as PackedScene).instantiate() as Node3D
	get_parent().add_child(ghost)
	ghost.global_transform = model.global_transform
	ghost.visible = is_visible_in_tree()
	var players := ghost.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		ghost.queue_free()
		return
	var player := players[0] as AnimationPlayer
	player.get_animation(clip).loop_mode = Animation.LOOP_NONE
	player.animation_finished.connect(func(_name: StringName) -> void: ghost.queue_free(), CONNECT_ONE_SHOT)
	player.play(clip)

## Cerco contra cidade usa o mecanismo e a técnica próprios, sem alterar dano ou resolução.
func play_city_attack_visual(city: City) -> void:
	if attack_animation == "": return
	var clip := attack_animation
	if _technique_clip != "" and _anim_player != null and _anim_player.has_animation(_technique_clip):
		if _technique_clip_started: return
		clip = _technique_clip
		_technique_clip_started = true
	else:
		var demolition := String(unit_data.technique_animation_overrides.get(V2DoctrineTechniqueDatabase.DEMOLITION_AMMO, ""))
		if demolition != "" and _anim_player != null and _anim_player.has_animation(demolition) and V2UnlockSystem.is_unlocked(owner_player, V2DoctrineTechniqueDatabase.DEMOLITION_AMMO):
			clip = demolition
	if city != null and is_instance_valid(city):
		face_toward(city.position)
	set_meta("feedback_attack_clip", clip)
	_queue_combat_animation(clip)

## Herói Corrompido (Bloqueio com Escudo): vira para quem atacou e toca o clipe do escudo (com o crossfade normal);
## no fim volta pro Idle (_on_blended_animation_finished). Só visual: o dano já foi negado pelo CombatResolver.
func play_block_visual(attacker: Unit) -> void:
	if preload("res://scripts/vfx/CombatFeedback.gd").defer_call(self, &"play_block_visual", [attacker]): return
	var clip := unit_data.block_animation_override
	if clip == "" or _anim_player == null or not _anim_player.has_animation(clip):
		return
	if attacker != null and is_instance_valid(attacker):
		face_toward(attacker.position)
	_anim_player.play(clip)

## Troca pro clipe `anim_name` so se a unidade tiver AnimationPlayer, o
## clipe existir, e nao for o que ja esta tocando (evita reiniciar o ciclo
## de Idle toda vez que um slide_to() termina enquanto ja estava parada).
func _play_animation(anim_name: String) -> void:
	if _boat_shown:
		_update_boat_animation() # na água quem anima é o barco (idle/walk pelo estado de andar); a tropa está escondida
		return
	if _anim_player and _anim_player.has_animation(anim_name) and _anim_player.current_animation != anim_name:
		_play_model_animation(_anim_player,anim_name)
	for player in _formation_players: # Fase 19: a formação da Hoste anda/ataca junto (só visual)
		if is_instance_valid(player) and player.has_animation(anim_name) and player.current_animation != anim_name:
			player.play(anim_name)

## Meta do AnimationPlayer que guarda o PoseCaptureTransition da unidade.
const POSE_TRANSITION_META := "pose_transition"

## Grandes Manifestações (UnitData.pose_transition_time > 0): as trocas de estado partem da pose atual do esqueleto.
func _uses_pose_transitions() -> bool:
	return unit_data != null and unit_data.pose_transition_time > 0.0

## Segundos da transição para `clip` a partir do que `player` toca agora: entrar ou sair do Andar tem tempo próprio.
func pose_transition_seconds(player: AnimationPlayer, clip: String) -> float:
	var changing_posture := clip == moving_animation or player.current_animation == moving_animation
	if changing_posture and unit_data.pose_transition_walk_time > 0.0:
		return unit_data.pose_transition_walk_time
	return unit_data.pose_transition_time

## `seconds` > 0 impõe o tempo desta troca (pouso/decolagem); senão vale o tempo normal da unidade.
func _play_model_animation(player: AnimationPlayer,clip: String,restart: bool=false,seconds: float=0.0) -> void:
	if _uses_pose_transitions():
		var transition: Variant=player.get_meta(POSE_TRANSITION_META,null)
		if transition!=null:
			transition.play(clip, seconds if seconds > 0.0 else pose_transition_seconds(player, clip), restart)
		else:
			player.play(clip)
	elif _uses_elemental_path_motion(): _play_elemental_path_animation(player,clip)
	else: player.play(clip)

func _uses_elemental_path_motion() -> bool:
	return unit_data != null and unit_data.model_scene_path.contains("/elemental_dragon_v9_animated/")

## Mantém a mesma posição no percurso ao mudar velocidade ou começar um gesto.
## As trilhas da mandíbula e do núcleo continuam com o tempo próprio do gesto.
func _play_elemental_path_animation(player: AnimationPlayer, clip: String) -> void:
	var phase := float(player.get_meta("elemental_path_phase",0.0))
	if player.current_animation in [idle_animation,moving_animation]:
		phase = fposmod(player.current_animation_position / player.current_animation_length,1.0)
	if clip in [idle_animation,moving_animation]:
		player.play(clip,0.0)
		player.seek(phase*player.get_animation(clip).length,true)
		return
	player.set_meta("elemental_path_phase",phase)
	var template_key := "elemental_template_" + clip
	if not player.has_meta(template_key):
		player.set_meta(template_key,player.get_animation(clip).duplicate(true))
	var animation := (player.get_meta(template_key) as Animation).duplicate(true) as Animation
	var route := player.get_animation(moving_animation)
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		if path.get_subname_count()==0: continue
		var bone := String(path.get_subname(0))
		if not (bone=="root" or bone=="head" or bone.begins_with("spine_") or bone.begins_with("ring_")): continue
		var type := animation.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]: continue
		var source_track := route.find_track(path,type)
		if source_track<0: continue
		while animation.track_get_key_count(track)>0: animation.track_remove_key(track,0)
		var count := roundi(animation.length*30)
		for sample in range(count+1):
			var progress := float(sample)/count
			var advance := progress*progress*progress*(progress*(progress*6.0-15.0)+10.0)
			var time := fposmod(phase+advance,1.0)*route.length
			var value: Variant
			match type:
				Animation.TYPE_POSITION_3D: value=route.position_track_interpolate(source_track,time)
				Animation.TYPE_ROTATION_3D: value=route.rotation_track_interpolate(source_track,time)
				Animation.TYPE_SCALE_3D: value=route.scale_track_interpolate(source_track,time)
			animation.track_insert_key(track,progress*animation.length,value)
	var library := player.get_animation_library("")
	library.remove_animation(clip)
	library.add_animation(clip,animation)
	player.play(clip,0.0)

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
	if unit_data.model_scene_path != "" and _build_model_body():
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
			# V3 / Combat Ecology: espécie nova sem modelo final ganha uma silhueta provisória própria.
			if MonsterPlaceholderVisuals.build(unit_data.visual_kind, self, mat):
				return
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.2
			mesh.height = 0.7
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.4
			add_child(body)

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

var _presented_hp := 10.0

func presentation_hp() -> float:
	return _presented_hp

func _update_hp_bar() -> void:
	if preload("res://scripts/vfx/CombatFeedback.gd").defer_call(self, &"_present_hp_bar", [hp], true): return
	_present_hp_bar(hp)

func _present_hp_bar(value: float) -> void:
	_presented_hp = value
	# Chamado pelo setter de hp mesmo antes de _build_visual() rodar
	# (setup() seta hp = data.max_hp antes de construir a barra) — nesse
	# momento a barra ainda nao existe, entao so ignora.
	if _hp_bar_fg == null or unit_data == null:
		return
	var frac = clamp(value / unit_data.max_hp, 0.0, 1.0)
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

## O selo da unidade: Sprite3D billboard com a textura composta por IconCatalog (pictograma da classe/espécie na cor
## do dono, pontos de nível, aro dourado para Lendárias e Grandes Manifestações). A textura é compartilhada por todas
## as unidades iguais do mesmo dono (cache do catálogo). Arte vetorial suavizada: filtro linear com mipmaps (o selo
## é reduzido de 128 px para o tamanho na tela) e transparência por mistura, que preserva a borda suave e a sombra.
func _build_troop_icon() -> void:
	var sprite := Sprite3D.new()
	sprite.texture = IconCatalog.unit_badge(self)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.double_sided = true
	sprite.pixel_size = TROOP_ICON_PIXEL_SIZE
	sprite.position = Vector3(0, _marker_height + 0.2, 0)
	sprite.name = TROOP_ICON_NAME
	add_child(sprite)

## Recompõe o selo depois que a cor do reino mudou (mecânica de escolher a cor base). Só troca a textura, que vem do
## cache do catálogo: chamar para todas as unidades de um reino é barato.
func refresh_troop_icon() -> void:
	var sprite := get_node_or_null(TROOP_ICON_NAME) as Sprite3D
	if sprite != null:
		sprite.texture = IconCatalog.unit_badge(self)

## DEBUG (painel de Debug): toca o clipe de um estado — "idle", "walk", "attack" ou "cast" — com a MESMA transição que o
## jogo usaria, sem tocar em regra nenhuma (não move, não ataca, não gasta nada). Um clipe de uma vez só (Ataque,
## Conjuração) recomeça se já estiver tocando e volta sozinho ao Parado quando a unidade tem transição/crossfade.
## false se a unidade não tem clipe para o estado.
func debug_play_state(state: String) -> bool:
	var clip := String({"idle": idle_animation, "walk": moving_animation, "attack": attack_animation, "cast": cast_animation}.get(state, ""))
	if clip == "" or _anim_player == null or not _anim_player.has_animation(clip):
		return false
	_play_model_animation(_anim_player, clip, _anim_player.current_animation == clip and clip != idle_animation and clip != moving_animation)
	return true

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
var owner_player: PlayerData
var coord: Vector2i
var movement_left: float = 0.0
var kills: int = 0
var veterancy_level: int = 0

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

## Setter dispara a atualizacao visual da barra de vida sozinha — assim
## qualquer lugar que faca `unit.hp -= dano` (CombatResolver, etc.) ja
## reflete na barra sem precisar lembrar de chamar nada extra.
var hp: float = 10.0:
	set(value):
		hp = value
		_update_hp_bar()

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

## Chamado por CombatResolver quando esta unidade vence um combate (mata o
## alvo, ou sobrevive ao contra-ataque de quem morreu tentando mata-la).
## Cura uma fracao do HP maximo so quando sobe de nivel de verdade — nao
## em todo kill, senao viraria um jeito facil demais de curar sem recuar.
func register_kill() -> void:
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

## Anima a posicao ate `target_pos` (em vez de teletransportar) e vira a
## unidade de frente pra direcao do movimento. Puramente visual — quem
## chama isso (HexGrid.move_unit) ja atualizou coord/ocupacao na hora.
func slide_to(target_pos: Vector3) -> void:
	var direction = target_pos - position
	direction.y = 0.0

	# create_tween() exige a unidade estar dentro da SceneTree (ex: testes
	# GUT que criam Unit/HexGrid isolados, sem add_child). Sem isso o jogo
	# de verdade nunca chama slide_to fora da arvore, mas nao custa nada
	# nao quebrar se acontecer — so pula a animacao e teletransporta.
	if not is_inside_tree():
		position = target_pos
		if direction.length() > 0.05:
			rotation.y = atan2(direction.x, direction.z)
		return

	# Andar (pedido do usuario: "os mobs nao tem animacao de andando?") — so
	# troca se ja nao estiver tocando (ver _play_animation), e volta pro
	# Idle quando o tween termina. Fica meio "piscando" em Idle por 1 frame
	# entre dois passos consecutivos de um caminho de varios tiles (cada
	# tile chama slide_to() separado, ver HexGrid.move_unit) — aceitavel
	# por enquanto, sincronizar direito exigiria HexGrid avisar "ainda tem
	# mais passo vindo", fora do escopo desta rodada.
	_play_animation(WALK_ANIMATION)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE)
	if direction.length() > 0.05:
		var target_angle = atan2(direction.x, direction.z)
		tween.tween_property(self, "rotation:y", target_angle, MOVE_DURATION * 0.6)
	tween.finished.connect(func(): _play_animation(DEFAULT_ANIMATION))

func _build_visual() -> void:
	_build_procedural_body()
	_build_base_disc()
	_build_hp_bar()
	_build_troop_icon()

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
func _build_model_body() -> void:
	var scene: PackedScene = load(unit_data.model_scene_path)
	var model: Node3D = scene.instantiate()
	add_child(model)
	var aabb = _model_aabb(model)
	if aabb != null and aabb.size.y > 0.0:
		model.scale = Vector3.ONE * (MODEL_TARGET_HEIGHT / aabb.size.y)
	if unit_data.animation_scene_path != "":
		_anim_player = _build_animation_player(model)
		if _anim_player:
			_anim_player.play(DEFAULT_ANIMATION)

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
	_copy_animations_into(library, WALK_ANIMATION_SCENE)
	if library.get_animation_list().is_empty():
		return null
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

	match unit_data.visual_kind:
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
			# Mesmo padrao do Vivern (corpo alongado + asas), so numa escala
			# bem maior — pedido do usuario: "Dragao (Boss Raro)... atributos
			# massivos", a silhueta precisa ler "muito maior" a distancia,
			# nao so "outro voador vermelho".
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.4
			mesh.height = 1.6
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.85
			add_child(body)
			for side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var wing_mesh := PrismMesh.new()
				wing_mesh.size = Vector3(0.95, 0.08, 0.5)
				wing.mesh = wing_mesh
				wing.material_override = mat
				wing.position = Vector3(side * 0.55, 1.15, 0.0)
				wing.rotation_degrees = Vector3(0, 0, side * 35)
				add_child(wing)
			var tail := MeshInstance3D.new()
			var tail_mesh := PrismMesh.new()
			tail_mesh.size = Vector3(0.2, 0.2, 0.8)
			tail.mesh = tail_mesh
			tail.material_override = mat
			tail.position = Vector3(0, 0.6, -0.55)
			tail.rotation_degrees = Vector3(90, 0, 0)
			add_child(tail)
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
		"treant":
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
		"stone_golem":
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
	_hp_bar_bg.position = Vector3(0, HP_BAR_Y, 0)
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
	_hp_bar_fg.position = Vector3(0, HP_BAR_Y, 0.001)
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
	sprite.position = Vector3(0, TROOP_ICON_Y, 0)
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

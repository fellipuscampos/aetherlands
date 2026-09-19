class_name UnitDatabase
extends RefCounted

## Roster de kinds que a cidade do JOGADOR pode produzir via producao normal
## (ver City.can_train, HUD._build_production_buttons) — fonte UNICA usada
## pra montar os botoes de producao dinamicamente, pedido do usuario: "ler
## dinamicamente todas as unidades cadastradas em UnitDatabase.gd", em vez
## de um botao fixo cadastrado a mao na cena toda vez que uma unidade nova
## nasce (foi exatamente isso que deixou stone_golem/shadow_summoner sem
## nenhum jeito de treinar de verdade quando entraram no jogo). Inclui as 4
## tropas raciais exclusivas (human_knight/dwarf_axeguard/orc_berserker/
## elf_ranger, ver RACE_UNIQUE_KIND abaixo) desde que o jogador ganhou a
## propria raca escolhivel na tela de titulo (CivilizationData.race,
## TitleScreen) — cada uma so fica DISPONIVEL de verdade (visivel na HUD e
## treinavel) se a raca do jogador bater, ver City.can_train() e
## HUD._on_tile_selected.
const PLAYER_TRAINABLE_KINDS: Array[String] = [
	"settler", "warrior", "men_at_arms", "archer", "cavalry", "scout", "catapult",
	"mage", "griffin", "treant", "stone_golem", "shadow_summoner",
	"human_knight", "dwarf_axeguard", "orc_berserker", "elf_ranger",
	# Roadmap "arvore de 10 niveis" (Tecnologia mundana) — 21 kinds novos, ver
	# TechDatabase.gd/BuildingDatabase.UNIT_TRAINER_FALLBACK pra quem
	# desbloqueia/treina cada um.
	"batedor_montado", "mercador", "lanceiro", "espadachim", "homem_de_escudo",
	"besteiro", "cavaleiro_pesado", "balista", "halberdier", "cavaleiro_de_choque",
	"ariete", "torre_de_cerco", "campeao", "cavalaria_blindada", "trebuchet",
	"engenheiro_de_cerco", "general", "cavaleiro_imperial", "bombarda",
	"campeao_do_reino", "colosso_de_cerco",
	"cleric", "cultist", "necromancer", "druid", "arcanist", "elementalist",
	"hierophant", "infernal_warlock", "arcane_golem", "storm_elemental",
]

## Raca de fantasia (CivilizationData.race) -> kind da tropa exclusiva dela
## (ver UnitDatabase.create_unit abaixo) — pedido original do usuario:
## "insira outras civilizacoes de fantasia... voce cria tropas especificas
## pra essas civilizacoes", estendido depois pro JOGADOR tambem poder
## escolher a propria raca (TitleScreen) e ganhar a mesma exclusividade.
## "human" incluido de proposito (pedido do usuario: "elfo, anao, orc e
## humanos") — sem isso, escolher Humano na tela de titulo seria estranho
## na pratica, a UNICA das 4 opcoes sem nenhuma tropa propria.
const RACE_UNIQUE_KIND := {
	"human": "human_knight",
	"dwarf": "dwarf_axeguard",
	"orc": "orc_berserker",
	"elf": "elf_ranger",
}

## Inverso de RACE_UNIQUE_KIND (kind -> raca dona), ou "" se `kind` nao e
## nenhuma tropa racial — usado por City.can_train() (so a raca dona pode
## treinar) e BuildingDatabase.building_that_trains() (todas as 4 treinam
## no Quartel, mesmo predio do Guarda comum, ver comentario la).
static func race_for_unique_kind(kind: String) -> String:
	for race in RACE_UNIQUE_KIND.keys():
		if RACE_UNIQUE_KIND[race] == kind:
			return race
	return ""

static func create_unit(kind: String) -> UnitData:
	if kind in MagicContent.TRAINABLE or kind in MagicContent.SUMMONED:
		return MagicContent.create_unit(kind)
	var data := UnitData.new()
	match kind:
		"settler":
			data.unit_name = "Colonizador"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 1.0
			data.max_hp = 8.0
			data.vision_range = 3
			data.can_found_city = true
			data.visual_kind = "settler"
			data.production_cost = 25.0
			# Identidade visual: mesma 3D Asset Factory procedural do Guarda
			# (tools/asset_factory, engine "blocky"), reaproveitando o mesmo
			# corpo/proporcao (ver memoria feedback_blocky_humanoid_
			# baseline), so equipamento/textura de manga diferentes (sem
			# armadura/elmo/luvas, mangas de pano em vez de cota de malha,
			# ver preset human_settler_blocky.json) -- um colonizador nao e
			# combatente, entao a silhueta precisa deixar isso claro de
			# longe (nada de metal). Cajado no lugar de arma e uma trouxa
			# de viagem nas costas em vez de escudo/lanca.
			data.model_scene_path = "res://assets/generated/humans/settler_blocky/human_settler_blocky.glb"
			data.animation_scene_path = "res://assets/generated/humans/settler_blocky/human_settler_blocky.glb"
			data.merge_shared_walk_animation = false
			data.idle_animation_override = "Idle"
			data.walk_animation_override = "Walk"
			# Sem attack_animation_override de proposito -- o Colonizador
			# nunca ataca (attack 0.0 acima), "nao precisa de animacao de
			# ataque" (usuario). O clipe "Attack" ainda existe no .glb (a
			# pipeline gera os 4 sempre, ver tools/asset_factory/animation/
			# clips.py) mas nunca e tocado: attack_animation fica "" em
			# Unit.gd, e CombatResolver.resolve() so chama _play_animation
			# quando esse campo nao e vazio.
			# Modelos da 3D Asset Factory (tools/asset_factory) usam escala
			# 1:1 direta agora, nao mais normalizacao por MODEL_TARGET_
			# HEIGHT (ver Unit.gd _build_model_body's ASSET_FACTORY_PATH_
			# PREFIX check) -- a altura de cada personagem ja e o proprio
			# parametro "height" do preset JSON, na mesma convencao de
			# unidade do jogo, entao model_scale_multiplier volta a ser
			# 1.0 (ajuste fino manual, nao mais "quanto preciso multiplicar
			# pra compensar uma bounding box normalizada"). O antigo 2.35
			# so existia pra compensar justamente essa normalizacao pela
			# bounding box (corpo + arma) -- ver comentario historico do
			# Esqueleto em MonsterDatabase.gd pra a saga completa de por
			# que esse sistema foi abandonado pros personagens proprios.
			data.model_scale_multiplier = 1.0
			data.model_yaw_offset_degrees = 180.0
		"warrior":
			data.unit_name = "Guarda"
			data.movement_points = 2.0
			data.attack = 4.0
			data.defense = 3.0
			data.max_hp = 12.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "warrior"
			data.production_cost = 15.0
			# Identidade visual: guarda gerado pela 3D Asset Factory
			# procedural (tools/asset_factory, engine "blocky") em vez do
			# Barbaro do KayKit — esqueleto proprio (18 ossos, nomes
			# distintos do rig KayKit). O proprio .glb ja exporta os 4
			# clipes prontos (Idle/Walk/Attack/Death, ver tools/
			# asset_factory/animation/clips.py), entao animation_scene_path
			# aponta pro MESMO arquivo do modelo — e merge_shared_walk_
			# animation fica false pra NAO somar o "Walking_A" do
			# WALK_ANIMATION_SCENE (rig KayKit, esqueleto incompativel) por
			# cima. idle/walk_animation_override usam os nomes reais dos
			# clipes (sem o sufixo "_A" da convencao KayKit).
			data.model_scene_path = "res://assets/generated/humans/guard_blocky/human_guard_blocky.glb"
			data.animation_scene_path = "res://assets/generated/humans/guard_blocky/human_guard_blocky.glb"
			data.merge_shared_walk_animation = false
			data.idle_animation_override = "Idle"
			data.walk_animation_override = "Walk"
			data.attack_animation_override = "Attack"
			# Escala 1:1 direta agora (ver Unit.gd _build_model_body's
			# ASSET_FACTORY_PATH_PREFIX check e o comentario longo do
			# Colonizador acima) -- o preset ja modela o Guarda com 1.8m de
			# altura, sem precisar de multiplicador nenhum. yaw_offset
			# continua necessario: a unidade aparecia de costas ao andar,
			# ja que a "frente" exportada por tools/asset_factory nao bate
			# com a convencao que slide_to() usa pra girar a unidade.
			data.model_scale_multiplier = 1.0
			data.model_yaw_offset_degrees = 180.0
		# Segunda tropa humana comum, so treinavel no Quartel apos pesquisar
		# a tech "Quartel" (ver TechDatabase) — infantaria profissional,
		# estatisticas acima do Guarda em troca do investimento em pesquisa
		# + construcao.
		"men_at_arms":
			data.unit_name = "Homem de Armas"
			data.movement_points = 2.0
			data.attack = 5.5
			data.defense = 4.5
			data.max_hp = 16.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "men_at_arms"
			data.production_cost = 22.0
			# Prova de conceito da identidade visual nova (pedido do usuario, ver
			# UnitData.model_scene_path) — modelo real (KayKit Adventurers, CC0)
			# em vez do corpo procedural de sempre. So esta tropa por enquanto;
			# ainda sem animacao (bind pose) — retargeting das animacoes do
			# KayKit Character Animations fica pra depois de validar esta fatia.
			data.model_scene_path = "res://assets/models/kaykit/characters/Knight.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		"archer":
			data.unit_name = "Arqueiro"
			data.movement_points = 2.0
			data.attack = 3.0
			data.defense = 1.5
			data.attack_range = 2
			data.max_hp = 9.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "archer"
			data.production_cost = 18.0
			# Identidade visual (KayKit Adventurers, CC0) — combinacao literal.
			data.model_scene_path = "res://assets/models/kaykit/characters/Ranger.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		"cavalry":
			data.unit_name = "Cavaleiro"
			data.movement_points = 4.0
			data.attack = 5.0
			data.defense = 2.0
			data.max_hp = 14.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "cavalry"
			data.production_cost = 22.0
		# Segunda tropa do Estabulo, so treinavel apos pesquisar a tech
		# "Batedor Montado" (que por sua vez exige "Estabulo" pesquisada
		# antes, ver TechDatabase) — pedido do usuario: "e uma pesquisa
		# seguinte ao estabulo... o batedor montado... que e basicamente um
		# explorador que pode andar 3 casas, mas nao causa muito dano".
		# Movimento igual Cavaleiro Real (3), mas ataque/defesa/vida bem
		# abaixo de QUALQUER outra tropa montada — o investimento aqui e
		# 100% mobilidade/visao, nao combate. Maior vision_range do elenco
		# comum (so perde pro Arqueiro Solar, tropa exclusiva elfica).
		"scout":
			data.unit_name = "Batedor"
			data.movement_points = 3.0
			data.attack = 1.5
			data.defense = 1.0
			data.max_hp = 8.0
			data.vision_range = 5
			data.can_found_city = false
			data.visual_kind = "scout"
			data.production_cost = 16.0
			# Identidade visual (KayKit Adventurers, CC0) — Ladino, silhueta
			# leve/agil condiz com "Batedor" (sem cavalo disponivel nos pacotes
			# gratuitos, mesma limitacao de Cavaleiro/Cavaleiro Real abaixo).
			data.model_scene_path = "res://assets/models/kaykit/characters/Rogue.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		"catapult":
			data.unit_name = "Catapulta"
			data.movement_points = 1.0
			data.attack = 6.0
			data.defense = 1.0
			data.attack_range = 2
			data.max_hp = 8.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "catapult"
			data.production_cost = 30.0
		"mage":
			data.unit_name = "Mago"
			data.movement_points = 2.0
			data.attack = 4.0
			data.defense = 1.0
			data.attack_range = 2
			data.max_hp = 8.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "mage"
			data.ignores_terrain_defense = true
			data.production_cost = 28.0
			# Identidade visual (KayKit Adventurers, CC0) — combinacao literal.
			data.model_scene_path = "res://assets/models/kaykit/characters/Mage.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		"griffin":
			data.unit_name = "Grifo"
			data.movement_points = 4.0
			data.attack = 6.0
			data.defense = 3.0
			data.max_hp = 15.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "griffin"
			data.flies = true
			data.production_cost = 35.0
		"treant":
			data.unit_name = "Ent"
			data.movement_points = 1.0
			data.attack = 5.0
			data.defense = 5.0
			data.max_hp = 18.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "treant"
			data.regen_fraction = 0.15
			data.production_cost = 30.0
		# Tropas magicas desbloqueadas pela nova arvore de tecnologia (ver
		# TechDatabase: forja_runica -> stone_golem, necromancia_pratica ->
		# shadow_summoner). Treinaveis de verdade via PLAYER_TRAINABLE_KINDS
		# acima, cada uma com seu proprio predio de treino em
		# BuildingDatabase (Bigorna Runica / Cripta Sombria).
		"stone_golem":
			data.unit_name = "Golem de Pedra"
			data.movement_points = 1.0 # pesado, nao sai correndo
			data.attack = 5.0
			data.defense = 6.0 # a maior defesa do elenco, guardiao de pedra viva
			data.max_hp = 20.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "stone_golem"
			data.production_cost = 32.0
		"shadow_summoner":
			data.unit_name = "Convocador de Sombras"
			data.movement_points = 2.0
			data.attack = 5.0
			data.defense = 1.0
			data.attack_range = 2
			data.max_hp = 9.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "shadow_summoner"
			data.ignores_terrain_defense = true
			data.regen_fraction = 0.1 # drena ecos da sombra pra se sustentar, mesmo padrao do Ent
			data.production_cost = 33.0
			# Identidade visual (KayKit Skeletons, CC0) — Mago Esqueleto, o
			# modelo mais proximo tematicamente de "necromancia/sombra" nos
			# pacotes gratuitos.
			data.model_scene_path = "res://assets/models/kaykit/skeletons/Skeleton_Mage.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		# Tropas raciais exclusivas (ver RACE_UNIQUE_KIND acima) — cada
		# civilizacao de fantasia (CivilizationData.race, escolhida pelo
		# jogador na tela de titulo ou sorteada pra rival em
		# GameManager.RIVAL_CIVS) tem uma, alem do elenco comum acima.
		"human_knight":
			data.unit_name = "Cavaleiro Real"
			data.movement_points = 3.0 # mais agil que Cavalaria comum, mas nao tao rapido quanto o Arqueiro Solar
			data.attack = 5.0
			data.defense = 4.0 # maior defesa entre as 4 tropas raciais moveis (perde so pro Guarda-Machado Anao, que fica parado)
			data.max_hp = 15.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "human_knight"
			data.production_cost = 26.0
		"dwarf_axeguard":
			data.unit_name = "Guarda-Machado Anao"
			data.movement_points = 1.0 # pernas curtas, mas nao sai do lugar
			data.attack = 5.0
			data.defense = 5.0
			data.max_hp = 16.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "dwarf_axeguard"
			data.production_cost = 24.0
		"orc_berserker":
			data.unit_name = "Berserker da Horda"
			data.movement_points = 2.0
			data.attack = 6.0 # o maior ataque corpo-a-corpo do jogo, de proposito
			data.defense = 1.0 # sem armadura nenhuma, todo o investimento e ofensivo
			data.max_hp = 10.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "orc_berserker"
			data.production_cost = 18.0
		"elf_ranger":
			data.unit_name = "Arqueiro Solar"
			data.movement_points = 3.0 # o mais agil entre as unidades terrestres
			data.attack = 3.5
			data.defense = 1.0
			data.attack_range = 3 # alcance maior que o Arqueiro comum (2)
			data.max_hp = 8.0
			data.vision_range = 5
			data.can_found_city = false
			data.visual_kind = "elf_ranger"
			data.production_cost = 26.0
			# Identidade visual (KayKit Adventurers, CC0) — reusa o mesmo
			# modelo do Arqueiro comum (silhueta de arqueiro generica ja
			# combina tematicamente com "Arqueiro Solar"; sem modelo elfico
			# dedicado nos pacotes gratuitos, so estatisticas diferenciam as
			# duas tropas).
			data.model_scene_path = "res://assets/models/kaykit/characters/Ranger.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		# --- Roadmap "arvore de 10 niveis" (Tecnologia mundana) ---------
		# 21 kinds novos, sem model_scene_path (fallback seguro e ja
		# confirmado: capsula generica na cor da civilizacao, ver
		# Unit._build_procedural_body/match visual_kind). Defesa de toda
		# unidade mundana nova fica <= 5.5, de proposito, pra stone_golem
		# (mágico, defesa 6.0) continuar sendo a maior defesa do jogo
		# inteiro (ver test_create_unit_stone_golem_has_the_highest_
		# defense_in_the_roster). Custos/stats por escala manual crescente
		# por nivel, mesmo estilo hardcoded do resto deste arquivo — ainda
		# NAO calibrados, faceis de ajustar depois.
		#
		# Nivel 3 — versao mais rapida e cara do Batedor (kind "scout"),
		# ver TechDatabase "batedor_montado": "transforma a linha de
		# Batedor numa unidade muito mais rapida". Treina no Estabulo (ver
		# BuildingDatabase.UNIT_TRAINER_FALLBACK), nao mais o mesmo kind
		# "scout" de antes da separacao.
		"batedor_montado":
			data.unit_name = "Batedor Montado"
			data.movement_points = 5.0
			data.attack = 2.0
			data.defense = 1.5
			data.max_hp = 10.0
			data.vision_range = 5
			data.can_found_city = false
			data.visual_kind = "batedor_montado"
			data.production_cost = 22.0
		# Unidade utilitaria (Nivel 3) — sem combate de proposito (attack
		# 0.0, mesmo padrao do Colonizador), ainda sem logica de criar
		# rota comercial de verdade (ver TradeRoute/TradeManager — fica
		# pra quando essa mecanica for implementada).
		"mercador":
			data.unit_name = "Mercador"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 1.0
			data.max_hp = 10.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "mercador"
			data.production_cost = 20.0
		# Nivel 4 — anti-cavalaria (papel descritivo por enquanto, sem
		# bonus de dano por role ainda — CombatResolver nao tem esse
		# mecanismo hoje).
		"lanceiro":
			data.unit_name = "Lanceiro"
			data.movement_points = 2.0
			data.attack = 4.5
			data.defense = 4.0
			data.max_hp = 15.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "lanceiro"
			data.production_cost = 24.0
		"espadachim":
			data.unit_name = "Espadachim"
			data.movement_points = 2.0
			data.attack = 6.5
			data.defense = 3.0
			data.max_hp = 15.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "espadachim"
			data.production_cost = 26.0
		# Nivel 5 — tanque da infantaria, HP/defesa altos, dano baixo.
		"homem_de_escudo":
			data.unit_name = "Homem de Escudo"
			data.movement_points = 1.0
			data.attack = 3.0
			data.defense = 5.5
			data.max_hp = 22.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "homem_de_escudo"
			data.production_cost = 28.0
		# Nivel 6 — mais lento que Arqueiro, mais dano.
		"besteiro":
			data.unit_name = "Besteiro"
			data.movement_points = 2.0
			data.attack = 4.5
			data.defense = 2.0
			data.attack_range = 2
			data.max_hp = 10.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "besteiro"
			data.production_cost = 26.0
		"cavaleiro_pesado":
			data.unit_name = "Cavaleiro Pesado"
			data.movement_points = 3.0
			data.attack = 5.5
			data.defense = 3.5
			data.max_hp = 17.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "cavaleiro_pesado"
			data.production_cost = 30.0
		# Cerco direcionado — muito dano contra um alvo so, sem area (a
		# diferenca de "area vs alvo unico" descrita no pedido original e
		# so tematica por enquanto, ver CombatResolver.resolve_with_splash,
		# ja existe mas nenhuma unidade nova usa ainda).
		"balista":
			data.unit_name = "Balista"
			data.movement_points = 1.0
			data.attack = 7.0
			data.defense = 1.0
			data.attack_range = 2
			data.max_hp = 8.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "balista"
			data.production_cost = 34.0
		# Nivel 7 — evolucao do Lanceiro, anti-cavalaria pesado.
		"halberdier":
			data.unit_name = "Halberdier"
			data.movement_points = 2.0
			data.attack = 5.5
			data.defense = 5.0
			data.max_hp = 18.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "halberdier"
			data.production_cost = 38.0
		"cavaleiro_de_choque":
			data.unit_name = "Cavaleiro de Choque"
			data.movement_points = 4.0
			data.attack = 7.0
			data.defense = 2.5
			data.max_hp = 16.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "cavaleiro_de_choque"
			data.production_cost = 40.0
		"ariete":
			data.unit_name = "Aríete"
			data.movement_points = 1.0
			data.attack = 6.5
			data.defense = 2.0
			data.max_hp = 14.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "ariete"
			data.production_cost = 38.0
		"torre_de_cerco":
			data.unit_name = "Torre de Cerco"
			data.movement_points = 1.0
			data.attack = 5.0
			data.defense = 2.5
			data.max_hp = 16.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "torre_de_cerco"
			data.production_cost = 42.0
		# Nivel 8 — infantaria ofensiva de elite.
		"campeao":
			data.unit_name = "Campeão"
			data.movement_points = 2.0
			data.attack = 7.5
			data.defense = 4.0
			data.max_hp = 20.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "campeao"
			data.production_cost = 46.0
		"cavalaria_blindada":
			data.unit_name = "Cavalaria Blindada"
			data.movement_points = 3.0
			data.attack = 6.0
			data.defense = 5.5
			data.max_hp = 20.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "cavalaria_blindada"
			data.production_cost = 48.0
		"trebuchet":
			data.unit_name = "Trebuchet"
			data.movement_points = 1.0
			data.attack = 7.5
			data.defense = 1.0
			data.attack_range = 3
			data.max_hp = 9.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "trebuchet"
			data.production_cost = 50.0
		# Unidade utilitaria (Nivel 8) — attack 0.0 de proposito, mesmo
		# padrao de Mercador/Colonizador. "Reparar/montar/desmontar
		# maquinas de cerco" descrito no pedido original fica pra quando
		# essa mecanica existir (ver comentario da TechData "engenheiro_
		# de_cerco" em TechDatabase.gd).
		"engenheiro_de_cerco":
			data.unit_name = "Engenheiro de Cerco"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 1.0
			data.max_hp = 10.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "engenheiro_de_cerco"
			data.production_cost = 30.0
		# Nivel 9 — unidade de SUPORTE, nao ataca diretamente (attack 0.0
		# de proposito, pedido do usuario: "nao e pra causar dano
		# diretamente"). Aura de fortalecer tropas proximas fica pra
		# quando essa mecanica existir (ver comentario da tech "general").
		"general":
			data.unit_name = "General"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 2.0
			data.max_hp = 14.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "general"
			data.production_cost = 55.0
		"cavaleiro_imperial":
			data.unit_name = "Cavaleiro Imperial"
			data.movement_points = 3.0
			data.attack = 8.0
			data.defense = 5.5
			data.max_hp = 22.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "cavaleiro_imperial"
			data.production_cost = 60.0
		"bombarda":
			data.unit_name = "Bombarda"
			data.movement_points = 1.0
			data.attack = 9.0
			data.defense = 1.0
			data.attack_range = 2
			data.max_hp = 10.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "bombarda"
			data.production_cost = 65.0
		# Nivel 10 — unidade terrestre final (ver TechDatabase
		# "exercito_supremo"). Cada raca podera futuramente ter sua propria
		# variante visual (Cavaleiro Real/Campeao Elfico/Guardiao
		# Ancestral/Senhor da Guerra, mesma tech) — por enquanto todas usam
		# esta entrada unica.
		"campeao_do_reino":
			data.unit_name = "Campeão do Reino"
			data.movement_points = 2.0
			data.attack = 9.5
			data.defense = 5.5
			data.max_hp = 26.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "campeao_do_reino"
			data.production_cost = 90.0
		"colosso_de_cerco":
			data.unit_name = "Colosso de Cerco"
			data.movement_points = 1.0
			data.attack = 10.0
			data.defense = 3.0
			data.attack_range = 2
			data.max_hp = 20.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "colosso_de_cerco"
			data.production_cost = 100.0
	return data

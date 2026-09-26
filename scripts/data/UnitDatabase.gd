class_name UnitDatabase
extends RefCounted

## Núcleo civil compartilhado treinável fora da progressão V2 (Fase 25): só o Colonizador. O Guarda
## ("warrior") continua existindo como unidade INICIAL de toda civilização, mas não abre fila de
## produção; as tropas V1 continuam como dado só para recriar unidades de saves antigos.
const CORE_TRAINABLE_KINDS: Array[String] = ["settler"]

## Roster de kinds que uma cidade pode produzir via producao normal (ver City.can_train,
## HUD._build_production_buttons e V2StrategicAI) — fonte UNICA usada pra montar os botoes de
## producao dinamicamente: o núcleo civil + toda unidade treinável da progressão V2.
const PLAYER_TRAINABLE_KINDS: Array[String] = [
	"settler",
	# Aetherlands V2 (Fase 3): treinável só com o nó v2_doctrine_guardian_3
	# pesquisado e um Salão dos Guardiões na cidade (City.can_train +
	# PlayerData.has_unlocked). Entrar aqui dá de graça o botão da HUD, o
	# candidato da IA e a cobertura de SaveManager.
	"v2_unit_shieldbearer",
	# Fase 4: primeira evolução da linha do Guardião. Treinável no lugar do Escudeiro
	# depois do nó N5 (V2UnitLine.resolve_trainable_form) e também alcançável por upgrade
	# físico de um Escudeiro existente (V2UnitUpgrade).
	"v2_unit_guardian",
	# Fase 5: forma Elite convencional da linha do Guardião (nó N7).
	"v2_unit_sentinel",
	# Fase 6: candidato Lendário da linha (nó N9). NÃO é forma da cadeia Escudeiro->Guardião->
	# Sentinela: treinado no Bastião de Maestria, limitado pelo slot global de V2LegendarySystem.
	"v2_legendary_guardian_champion",
	# Fase 7 — Doutrina do Guerreiro (N3/N5/N7 + candidato Lendário N9), sobre os MESMOS frameworks do Guardião:
	# cadeia por V2UnitLine/V2UnitUpgrade, Lendário por V2LegendarySystem (slot global compartilhado com o Campeão).
	"v2_unit_warrior",
	"v2_unit_swordsman",
	"v2_unit_weapon_master",
	"v2_legendary_blade_hero",
	# Fase 8 — Doutrina do Patrulheiro (N3/N5/N7 + candidato Lendário N9): ranged pelo MESMO combate (attack_range), as mesmas
	# fundações (V2UnitLine/V2UnitUpgrade/V2LegendarySystem) e o mesmo slot Lendário global das outras duas Doutrinas.
	"v2_unit_archer",
	"v2_unit_hunter",
	"v2_unit_elite_marksman",
	"v2_legendary_legend_hunter",
	# Fase 9 — Doutrina da Cavalaria (N3/N5/N7 + candidato Lendário N9): mobilidade e choque sobre as mesmas fundações; toda a linha é `mounted`
	# (o traço da Fase 5, que o Preparar Lanças já consulta) e o Cavaleiro de Grifo é a primeira unidade de perfil de movimento FLYING.
	"v2_unit_cavalier",
	"v2_unit_shock_cavalier",
	"v2_unit_armored_cavalier",
	"v2_legendary_griffon_rider",
	# Fase 10 — Doutrina do Ladino (N3/N5/N7 + candidato Lendário N9): sabotagem/assassinato sobre as mesmas fundações; Ataque Furtivo (penetração de
	# Defesa + sem revide) e Desmantelar (bônus contra os traços `caster`/`siege`) por dado; o Mestre das Sombras é a primeira unidade de perfil
	# de movimento INFILTRATOR (Passo Sombrio).
	"v2_unit_rogue",
	"v2_unit_saboteur",
	"v2_unit_assassin",
	"v2_legendary_shadow_master",
	# Fase 11 — Doutrina de Cerco (N3/N5/N7 + candidato Lendário N9), a SEXTA e última Doutrina Militar: destruição de
	# cidades/fortificações sobre as mesmas fundações; Munição Demolidora (bônus contra cidade) e Bombardeio Preparado
	# (ataque de Cerco com mira de CIDADE, exige não ter se movido) por dado; o Colosso de Cerco é a primeira unidade
	# a ignorar esse requisito por dado (Artilharia Andante), sem perfil de movimento novo.
	"v2_unit_catapult",
	"v2_unit_trebuchet",
	"v2_unit_bombard",
	"v2_legendary_siege_colossus",
	"v2_unit_builder",
	# Fase 17 — Escola Sagrada (Magia V2): o conjurador N3 (treinado no Templo Sagrado) e a Grande Manifestação N9
	# (produzida na Catedral Sagrada, 1 por Escola via V2ManifestationSystem, com Mana cobrada na conclusão).
	"v2_unit_sacred_cleric",
	"v2_manifestation_seraph",
	# Fase 18 — Escola Infernal: caster N3 + Grande Manifestação N9.
	"v2_unit_infernal_warlock",
	"v2_manifestation_archdemon",
	# Fase 19 — Escola de Necromancia: caster N3 + Grande Manifestação N9. As duas Hostes
	# (v2_unit_skeleton_host / v2_unit_macabre_host) NÃO entram aqui de propósito: só nascem por feitiço.
	"v2_unit_necromancer",
	"v2_manifestation_lich_sovereign",
	# Fase 20 — Escola Druídica: caster N3 + Grande Manifestação N9.
	"v2_unit_druid",
	"v2_manifestation_nature_avatar",
	# Fase 21 — Arcanismo: caster N3 + Grande Manifestação N9.
	"v2_unit_arcanist",
	"v2_manifestation_veil_archon",
	# Fase 22 — Elementalismo: caster N3 + sexta Grande Manifestação N9.
	"v2_unit_elementalist",
	"v2_manifestation_elemental_primordial",
]

## As tropas raciais exclusivas V1 (Cavaleiro Real, Guarda-Machado, Berserker, Arqueiro Solar) não são
## mais treináveis desde a Fase 25 — a Fase 26 adiciona só modificadores sistêmicos por raça, sem
## reintroduzir unidades exclusivas. Os dados
## delas seguem abaixo só para recriar unidades de saves antigos.

## `kind` existe neste banco? Todo ramo de create_unit grava `visual_kind = kind`; o dado padrão (id
## desconhecido) fica com o visual_kind default "warrior" — por isso o Guarda é a única exceção
## explícita. Usado pelo SaveManager para descartar unidades de tipos removidos (ex.: conjuradores e
## invocações da magia V1, Fase 25) em vez de recriá-las como um Guarda genérico.
static func is_known_kind(kind: String) -> bool:
	return kind == "warrior" or (kind != "" and create_unit(kind).visual_kind == kind)

static func create_unit(kind: String) -> UnitData:
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
		# AETHERLANDS V2, Fase 3 — Escudeiro, unidade-base da Doutrina do Guardião
		# (nó v2_doctrine_guardian_3). Só existe pra civilização que pesquisou o
		# nó (V2UnlockSystem) E só treina no Salão dos Guardiões
		# (v2_building_guardian_hall, trains_unit = este kind).
		# BALANCE PLACEHOLDER: todos os números abaixo são provisórios, escolhidos
		# só pra encaixar entre as tropas V1 já existentes — mais resistente que o
		# Guarda (vida 18 > 12, defesa 4.5 > 3.0) porém com ataque menor (3.0 < 4.0),
		# movimento normal (2) e custo entre Guarda (15) e Homem de Armas (22).
		# Sem upkeep de ouro/Suprimentos (não existem na V2 ainda). Não use estes
		# valores como referência de balanceamento — ver docs/BALANCE_REFERENCE.md.
		# `visual_kind` == id do kind de propósito: é o que SaveManager grava e usa
		# pra recriar a unidade no load (UnitDatabase.create_unit(kind)).
		# Modelo PROVISÓRIO: o mesmo Knight do KayKit do Homem de Armas.
		"v2_unit_shieldbearer":
			data.unit_name = "Escudeiro"
			data.movement_points = 2.0
			data.attack = 3.0
			data.defense = 4.5
			data.max_hp = 18.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_shieldbearer"
			data.supply_cost = 1
			data.production_cost = 20.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Knight.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		# AETHERLANDS V2, Fase 4 — Guardião, primeira evolução da linha do Guardião (nó
		# v2_doctrine_guardian_5, tier `evolution_1`). É o Escudeiro evoluído: continua
		# tank/frontline (não é DPS nem ganha mobilidade). Cidades com o Salão dos
		# Guardiões passam a treiná-lo NO LUGAR do Escudeiro, e um Escudeiro existente
		# vira Guardião por upgrade físico (V2UnitUpgrade). Sem upkeep.
		# BALANCE PLACEHOLDER: todos os números são provisórios — contra o Escudeiro
		# (18 / 3,0 / 4,5 / mov. 2 / 20 PP): mais vida (24), mais defesa (6,0), ataque só
		# um pouco maior (4,0), MESMO movimento e custo 32 PP (upgrade = 2 x 12 = 24 Ouro).
		# `visual_kind` == id (SaveManager recria a unidade por ele).
		# Modelo PROVISÓRIO: o mesmo Knight do KayKit do Escudeiro, 20% maior pra dar pra
		# distinguir a evolução no mapa. Sem arte V2.
		"v2_unit_guardian":
			data.unit_name = "Guardião"
			data.movement_points = 2.0
			data.attack = 4.0
			data.defense = 6.0
			data.max_hp = 24.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_guardian"
			data.supply_cost = 2
			data.production_cost = 32.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Knight.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.2
		# AETHERLANDS V2, Fase 5 — Sentinela, forma Elite CONVENCIONAL da linha do Guardião
		# (nó v2_doctrine_guardian_7, tier `elite_form`; NÃO é Lendária). Continua tank/
		# frontline: mais vida e defesa que o Guardião, ataque só moderadamente maior, mesmo
		# movimento. Herda as Técnicas da linha (Muralha de Escudos, Preparar Lanças) por
		# `branch_of == guardian`, sem código próprio. Treinada no Salão dos Guardiões (o
		# Bastião de Maestria, N8, NÃO é requisito) e alcançável por upgrade físico de um
		# Guardião (V2UnitUpgrade). Sem upkeep.
		# BALANCE PLACEHOLDER: vida 32 / ataque 5,0 / defesa 8,0 / mov. 2 / 48 PP (upgrade
		# Guardião -> Sentinela = 2 x (48 - 32) = 32 Ouro, pela fórmula genérica).
		# Modelo PROVISÓRIO: o mesmo Knight do KayKit, 40% maior que o Escudeiro (o Guardião é
		# 20% maior) pra distinguir as três formas no mapa. Sem arte V2.
		"v2_unit_sentinel":
			data.unit_name = "Sentinela"
			data.movement_points = 2.0
			data.attack = 5.0
			data.defense = 8.0
			data.max_hp = 32.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_sentinel"
			data.supply_cost = 3
			data.production_cost = 48.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Knight.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.4
		# AETHERLANDS V2, Fase 6 — Campeão Guardião, candidato a Unidade LENDÁRIA da linha do
		# Guardião (nó v2_doctrine_guardian_9, tier `legendary_candidate`). NÃO é upgrade da Sentinela:
		# unidade separada e excepcional, treinada no Bastião de Maestria; a Sentinela segue a forma
		# convencional máxima. Filosofia de Guardião (tank/frontline): mais resistente e defensivo que a
		# Sentinela, ataque melhor sem virar DPS, MESMO movimento. Herda Muralha de Escudos e Preparar
		# Lanças pela linha (doctrine_branch_of == guardian), sem duplicar técnica no dado. Aura própria:
		# Comando Defensivo (V2UnitAuras) — aliados em raio 2 recebem +20% de Defesa, nunca ele mesmo.
		# O traço `legendary` é semeado no fim de create_unit (metadata do N9). Sem upkeep.
		# BALANCE PLACEHOLDER: vida 44 / ataque 6,5 / defesa 10,0 / mov. 2 / 90 PP; aura raio 2, +20%.
		# Modelo PROVISÓRIO: Barbarian do KayKit (silhueta diferente dos Knights das outras formas), 1,5x.
		"v2_legendary_guardian_champion":
			data.unit_name = "Campeão Guardião"
			data.movement_points = 2.0
			data.attack = 6.5
			data.defense = 10.0
			data.max_hp = 44.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_legendary_guardian_champion"
			data.supply_cost = 5
			data.production_cost = 90.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.5
			data.aura_id = "defensive_command"
			data.aura_name = "Comando Defensivo"
			data.aura_radius = 2
			data.aura_defense_bonus = 0.2
		# AETHERLANDS V2, Fase 7 — Guerreiro, unidade-base da Doutrina do Guerreiro (nó v2_doctrine_warrior_3):
		# melee DPS básico. Treinado no Salão de Armas. Contra o Escudeiro (18 / 3,0 / 4,5): MENOS vida (16) e
		# defesa (3,5), MUITO mais ataque (5,0) — o Guardião vence em resistência, o Guerreiro em dano.
		# Mesmo movimento (2), visão 3, alcance corpo a corpo, 20 PP. Sem upkeep.
		# BALANCE PLACEHOLDER: todos os números são provisórios. `visual_kind` == id (SaveManager recria por ele).
		# Modelo PROVISÓRIO: o Barbarian do KayKit (escala 1,0). Sem arte V2.
		"v2_unit_warrior":
			data.unit_name = "Guerreiro"
			data.movement_points = 2.0
			data.attack = 5.0
			data.defense = 3.5
			data.max_hp = 16.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_warrior"
			data.supply_cost = 1
			data.production_cost = 20.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		# Fase 7 — Espadachim, primeira evolução da linha do Guerreiro (nó v2_doctrine_warrior_5): mesma função
		# (melee ofensivo), mais poder por tile. Treinado no lugar do Guerreiro depois do N5; um Guerreiro existente
		# vira Espadachim por V2UnitUpgrade (2 x (32 - 20) = 24 Ouro, fórmula genérica). BALANCE PLACEHOLDER:
		# 21 / 7,0 / 4,5 / mov. 2 / 32 PP. Modelo PROVISÓRIO: Barbarian 15% maior (distingue a forma no mapa).
		"v2_unit_swordsman":
			data.unit_name = "Espadachim"
			data.movement_points = 2.0
			data.attack = 7.0
			data.defense = 4.5
			data.max_hp = 21.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_swordsman"
			data.supply_cost = 2
			data.production_cost = 32.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.15
		# Fase 7 — Mestre de Armas, forma Elite CONVENCIONAL da linha do Guerreiro (nó v2_doctrine_warrior_7; NÃO é
		# Lendária). Melee avançado: mais Ataque que a Sentinela (9,5 > 5,0) e menos Defesa (5,5 < 8,0) — dano
		# substancial sem virar glass cannon. Herda Golpe Poderoso e Ataque em Arco por `branch == warrior`.
		# Upgrade Espadachim -> Mestre = 2 x (48 - 32) = 32 Ouro. BALANCE PLACEHOLDER: 28 / 9,5 / 5,5 / mov. 2 / 48 PP.
		# Modelo PROVISÓRIO: Barbarian 30% maior.
		"v2_unit_weapon_master":
			data.unit_name = "Mestre de Armas"
			data.movement_points = 2.0
			data.attack = 9.5
			data.defense = 5.5
			data.max_hp = 28.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_weapon_master"
			data.supply_cost = 3
			data.production_cost = 48.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.3
		# Fase 7 — Herói da Lâmina, candidato a Unidade LENDÁRIA da linha do Guerreiro (nó v2_doctrine_warrior_9,
		# `legendary_candidate`). NÃO é upgrade do Mestre de Armas: unidade separada, treinada na Arena dos Campeões,
		# sob o MESMO slot global de V2LegendarySystem do Campeão Guardião (o traço `legendary` é semeado no fim de
		# create_unit). Identidade oposta à do Campeão: 38 HP / 12,0 ataque / 7,0 defesa (Campeão: 44 / 6,5 / 10,0) —
		# finalizador, não âncora. Herda as duas Técnicas da Doutrina pela linha (doctrine_branch_of == warrior).
		# Passiva intrínseca EXECUÇÃO (dado `low_hp_attack_*`, sem `if` de id): +30% de Ataque contra unidades com 50%
		# de HP ou menos. BALANCE PLACEHOLDER: mov. 2, visão 3, 90 PP. Modelo PROVISÓRIO: Barbarian 65% maior (o
		# Campeão Guardião é o mesmo modelo a 1,5x — a distinção é só de escala e de painel).
		"v2_legendary_blade_hero":
			data.unit_name = "Herói da Lâmina"
			data.movement_points = 2.0
			data.attack = 12.0
			data.defense = 7.0
			data.max_hp = 38.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_legendary_blade_hero"
			data.supply_cost = 5
			data.production_cost = 90.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.65
			data.low_hp_attack_name = "Execução"
			data.low_hp_attack_threshold = 0.5
			data.low_hp_attack_bonus = 0.3
		# AETHERLANDS V2, Fase 8 — Arqueiro, unidade-base da Doutrina do Patrulheiro (nó v2_doctrine_ranger_3): ranged DPS básico. Treinado
		# no Campo dos Patrulheiros. Ataque à distância pelo sistema V1 (`attack_range` 2: atira de fora do alcance de melee e não sofre revide).
		# Frágil de propósito: menos HP e Defesa que o Guerreiro (16 / 3,5) e o Escudeiro (18 / 4,5). Sem upkeep.
		# BALANCE PLACEHOLDER: 13 HP / 4,5 / 2,5 / mov. 2 / visão 3 / alcance 2 / 20 PP. `visual_kind` == id (SaveManager recria por ele).
		# Modelo PROVISÓRIO: o Ranger do KayKit (o mesmo do Arqueiro V1) na escala 1,0. Sem arte V2.
		"v2_unit_archer":
			data.unit_name = "Arqueiro"
			data.movement_points = 2.0
			data.attack = 4.5
			data.defense = 2.5
			data.attack_range = 2
			data.max_hp = 13.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_archer"
			data.supply_cost = 1
			data.production_cost = 20.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Ranger.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		# Fase 8 — Caçador, 1ª evolução do Arqueiro (nó v2_doctrine_ranger_5): mesma função, mais dano e sobrevivência, MESMO alcance (2).
		# Upgrade Arqueiro -> Caçador = 2 x (32 - 20) = 24 Ouro (fórmula genérica). BALANCE PLACEHOLDER: 17 / 6,5 / 3,0 / mov. 2 / alcance 2 / 32 PP.
		# Modelo PROVISÓRIO: Ranger 15% maior.
		"v2_unit_hunter":
			data.unit_name = "Caçador"
			data.movement_points = 2.0
			data.attack = 6.5
			data.defense = 3.0
			data.attack_range = 2
			data.max_hp = 17.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_hunter"
			data.supply_cost = 2
			data.production_cost = 32.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Ranger.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.15
		# Fase 8 — Atirador de Elite, forma Elite CONVENCIONAL (nó v2_doctrine_ranger_7; NÃO é Lendária). A mudança estratégica do N7 é o ALCANCE
		# BÁSICO 3 (domínio avançado de ranged) — sem mais movimento e sem Defesa que o proteja em melee. O Disparo Preciso (alcance básico + 1) chega
		# a 4 tiles sem exceção nenhuma; a Saraivada usa o alcance básico (3). Upgrade Caçador -> Atirador = 2 x (48 - 32) = 32 Ouro.
		# BALANCE PLACEHOLDER: 22 / 8,5 / 3,5 / mov. 2 / alcance 3 / 48 PP. VISÃO 4 (o pedido só fixa visão 3 pro Arqueiro): o Disparo Preciso do N7
		# alcança 4 tiles e um alvo precisa estar VISÍVEL pro jogador humano — com visão 3 o alcance extra só valeria com observador de fora.
		# Modelo PROVISÓRIO: Ranger 30% maior.
		"v2_unit_elite_marksman":
			data.unit_name = "Atirador de Elite"
			data.movement_points = 2.0
			data.attack = 8.5
			data.defense = 3.5
			data.attack_range = 3
			data.max_hp = 22.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "v2_unit_elite_marksman"
			data.supply_cost = 3
			data.production_cost = 48.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Ranger.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.3
		# Fase 8 — Caçador de Lendas, candidato a Unidade LENDÁRIA da linha do Patrulheiro (nó v2_doctrine_ranger_9, `legendary_candidate`). NÃO é upgrade
		# do Atirador de Elite: unidade separada, produzida na Torre dos Patrulheiros, sob o MESMO slot global de V2LegendarySystem (Campeão Guardião,
		# Herói da Lâmina...; o traço `legendary` é semeado no fim de create_unit). Extremamente perigoso à distância e muito mais frágil que o Campeão
		# Guardião (30 HP / 4,5 de Defesa contra 44 / 10,0). Herda Disparo Preciso e Saraivada pela linha (doctrine_branch_of == ranger).
		# Passiva intrínseca CAÇADA LENDÁRIA (dado `trait_attack_*`, sem `if` de id): +40% de Ataque contra alvos com o TRAÇO `legendary`.
		# BALANCE PLACEHOLDER: 30 / 11,0 / 4,5 / mov. 2 / alcance 3 / 90 PP. Modelo PROVISÓRIO: Ranger 50% maior (os outros dois Lendários são Barbarian).
		"v2_legendary_legend_hunter":
			data.unit_name = "Caçador de Lendas"
			data.movement_points = 2.0
			data.attack = 11.0
			data.defense = 4.5
			data.attack_range = 3
			data.max_hp = 30.0
			data.vision_range = 4 # como o Atirador de Elite: o Disparo Preciso alcança 4 tiles
			data.can_found_city = false
			data.visual_kind = "v2_legendary_legend_hunter"
			data.supply_cost = 5
			data.production_cost = 90.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Ranger.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.5
			data.trait_attack_name = "Caçada Lendária"
			data.trait_attack_target_traits.append(UnitData.TRAIT_LEGENDARY)
			data.trait_attack_bonus = 0.4
		# AETHERLANDS V2, Fase 9 — Cavaleiro, unidade-base da Doutrina da Cavalaria (nó v2_doctrine_cavalry_3): mobilidade + flanco + choque inicial.
		# Contra o Guerreiro (16 / 5,0 / 3,5 / mov. 2 / 20 PP): MOVIMENTO 4 (o dobro), visão 4, resistência parecida (17 HP, defesa 3,0 um pouco menor), o
		# MESMO ataque (5,0) e mais caro (24 PP) — não vence o Guerreiro de frente pelos números; o valor dele é MOVIMENTO + POSICIONAMENTO. Traço `mounted`
		# declarado no dado (o Preparar Lanças do Guardião o reconhece por ele, sem integração entre as Doutrinas). Sem upkeep. BALANCE PLACEHOLDER.
		# Visual PROVISÓRIO: o corpo procedural "cavalry" do V1 (cavalo + cavaleiro na cor da civilização) na escala 1,0. Sem arte nova.
		"v2_unit_cavalier":
			data.unit_name = "Cavaleiro"
			data.movement_points = 4.0
			data.attack = 5.0
			data.defense = 3.0
			data.max_hp = 17.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "v2_unit_cavalier"
			data.supply_cost = 1
			data.production_cost = 24.0
			data.traits.append(UnitData.TRAIT_MOUNTED)
			data.visual_template = "cavalry"
		# Fase 9 — Cavaleiro de Choque, 1ª evolução (nó v2_doctrine_cavalry_5): a especialização mais agressiva do Cavaleiro (mais Ataque e vida), MESMO movimento.
		# Upgrade Cavaleiro -> Choque = 2 x (38 - 24) = 28 Ouro (fórmula genérica). BALANCE PLACEHOLDER: 22 / 7,0 / 4,0 / mov. 4 / 38 PP. Visual: cavalo ×1,15.
		"v2_unit_shock_cavalier":
			data.unit_name = "Cavaleiro de Choque"
			data.movement_points = 4.0
			data.attack = 7.0
			data.defense = 4.0
			data.max_hp = 22.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "v2_unit_shock_cavalier"
			data.supply_cost = 2
			data.production_cost = 38.0
			data.traits.append(UnitData.TRAIT_MOUNTED)
			data.visual_template = "cavalry"
			data.model_scale_multiplier = 1.15
		# Fase 9 — Cavaleiro Blindado, forma Elite CONVENCIONAL (nó v2_doctrine_cavalry_7; NÃO é Lendária): mais capacidade de ficar em combate, boa pressão,
		# mobilidade PRESERVADA (4) — mas nunca supera a Sentinela na função defensiva (30 HP / 6,0 contra 32 / 8,0): continua MOBILIDADE / CHOQUE.
		# Upgrade Choque -> Blindado = 2 x (56 - 38) = 36 Ouro. BALANCE PLACEHOLDER: 30 / 8,5 / 6,0 / mov. 4 / 56 PP. Visual: cavalo ×1,3.
		"v2_unit_armored_cavalier":
			data.unit_name = "Cavaleiro Blindado"
			data.movement_points = 4.0
			data.attack = 8.5
			data.defense = 6.0
			data.max_hp = 30.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "v2_unit_armored_cavalier"
			data.supply_cost = 3
			data.production_cost = 56.0
			data.traits.append(UnitData.TRAIT_MOUNTED)
			data.visual_template = "cavalry"
			data.model_scale_multiplier = 1.3
		# Fase 9 — Cavaleiro de Grifo, candidato a Unidade LENDÁRIA da Cavalaria (nó v2_doctrine_cavalry_9, `legendary_candidate`). NÃO é upgrade do Cavaleiro
		# Blindado: unidade separada, produzida na Ordem da Cavalaria, sob o MESMO slot global de V2LegendarySystem (`legendary` semeado no fim de create_unit).
		# A singularidade NÃO é o número, é a REGRA DE MOVIMENTO: perfil FLYING (voo tático — atravessa terreno e unidades, termina só em tile de terra livre;
		# ver HexGrid.flight_reachable) e herda Carga e Retirada Tática pela linha (doctrine_branch_of == cavalry), agora pelo perfil aéreo. Traços: `mounted`
		# (o Preparar Lanças a reconhece: dois counters — anti-montado e a vulnerabilidade), `flying` (semeado do perfil; clima futuro pode consultar) e `legendary`.
		# COUNTER por dado: +25% de dano recebido de ataques físicos à distância (`ranged_damage_taken_bonus`). Não supera as outras Lendárias em número (36 HP / 6,5
		# defesa contra o Campeão 44 / 10,0; Ataque 10,0 contra o Herói 12,0): o valor é o acesso ao mapa e à backline.
		# BALANCE PLACEHOLDER: 36 / 10,0 / 6,5 / mov. 5 / visão 5 / 100 PP. Visual PROVISÓRIO: o corpo procedural "griffin" do V1 (asas + corpo) na escala 1,4.
		"v2_legendary_griffon_rider":
			data.unit_name = "Cavaleiro de Grifo"
			data.movement_points = 5.0
			data.attack = 10.0
			data.defense = 6.5
			data.max_hp = 36.0
			data.vision_range = 5
			data.can_found_city = false
			data.visual_kind = "v2_legendary_griffon_rider"
			data.supply_cost = 5
			data.production_cost = 100.0
			data.traits.append(UnitData.TRAIT_MOUNTED)
			data.movement_profile = UnitData.MovementProfile.FLYING
			data.ranged_damage_taken_bonus = 0.25
			data.visual_template = "griffin"
			data.model_scale_multiplier = 1.4
		# AETHERLANDS V2, Fase 10 — Ladino, unidade-base da Doutrina do Ladino (nó v2_doctrine_rogue_3): melee frágil e móvel, especializado em
		# assassinato de alvos prioritários. Contra o Guerreiro (16 / 5,0 / 3,5 / mov. 2): MENOS Ataque (4,5), MUITO menos Defesa (2,5) e vida (14),
		# mais Movimento (3) — não troca golpes de frente, depende de escolher o alvo certo e do Ataque Furtivo (N4). Alcance corpo a corpo, visão 4
		# (para enxergar antes de se aproximar), 20 PP. Sem upkeep. BALANCE PLACEHOLDER. Modelo PROVISÓRIO: o Rogue do KayKit (o mesmo do Batedor V1)
		# na escala 1,0. Sem arte V2.
		"v2_unit_rogue":
			data.unit_name = "Ladino"
			data.movement_points = 3.0
			data.attack = 4.5
			data.defense = 2.5
			data.max_hp = 14.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "v2_unit_rogue"
			data.supply_cost = 1
			data.production_cost = 20.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Rogue.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
		# Fase 10 — Sabotador, primeira evolução da linha do Ladino (nó v2_doctrine_rogue_5): mesma função (assassinato móvel), mais poder por tile,
		# MESMO movimento (3). Upgrade Ladino -> Sabotador = 2 x (32 - 20) = 24 Ouro (fórmula genérica). BALANCE PLACEHOLDER: 18 / 6,0 / 3,0 / mov. 3 /
		# 32 PP. Modelo PROVISÓRIO: Rogue 15% maior.
		"v2_unit_saboteur":
			data.unit_name = "Sabotador"
			data.movement_points = 3.0
			data.attack = 6.0
			data.defense = 3.0
			data.max_hp = 18.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "v2_unit_saboteur"
			data.supply_cost = 2
			data.production_cost = 32.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Rogue.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.15
		# Fase 10 — Assassino, forma Elite CONVENCIONAL da linha do Ladino (nó v2_doctrine_rogue_7; NÃO é Lendária): bom burst e mobilidade terrestre
		# alta, Defesa baixa, HP moderado — excelente contra alvos prioritários, nunca um tanque. Não deve superar o Mestre de Armas (9,5 Ataque / 5,5
		# Defesa) em confronto frontal sustentado: Ataque um pouco menor e MUITO menos Defesa. Upgrade Sabotador -> Assassino = 2 x (48 - 32) = 32 Ouro.
		# BALANCE PLACEHOLDER: 23 / 8,0 / 3,5 / mov. 3 / 48 PP. Modelo PROVISÓRIO: Rogue 30% maior.
		"v2_unit_assassin":
			data.unit_name = "Assassino"
			data.movement_points = 3.0
			data.attack = 8.0
			data.defense = 3.5
			data.max_hp = 23.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "v2_unit_assassin"
			data.supply_cost = 3
			data.production_cost = 48.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Rogue.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.3
		# Fase 10 — Mestre das Sombras, candidato a Unidade LENDÁRIA da linha do Ladino (nó v2_doctrine_rogue_9, `legendary_candidate`). NÃO é upgrade
		# do Assassino: unidade separada, produzida no Refúgio das Sombras, sob o MESMO slot global de V2LegendarySystem das outras quatro Lendárias
		# (traço `legendary` semeado no fim de create_unit). A singularidade NÃO é o número — é a REGRA DE MOVIMENTO: perfil INFILTRATOR (Passo
		# Sombrio: atravessa unidades, nunca terreno impassável; ver HexGrid.infiltrate_reachable). Herda Ataque Furtivo e Desmantelar pela linha
		# (doctrine_branch_of == rogue). Não supera as outras Lendárias em número (36 HP / 6,5 defesa contra o Campeão 44 / 10,0; Ataque 10,5 contra
		# o Herói 12,0): o valor é atravessar formações inteiras, não os stats. BALANCE PLACEHOLDER: 30 / 10,5 / 4,5 / mov. 4 / visão 5 / 95 PP.
		# Modelo PROVISÓRIO: o Rogue do KayKit na escala 1,45.
		"v2_legendary_shadow_master":
			data.unit_name = "Mestre das Sombras"
			data.movement_points = 4.0
			data.attack = 10.5
			data.defense = 4.5
			data.max_hp = 30.0
			data.vision_range = 5
			data.can_found_city = false
			data.visual_kind = "v2_legendary_shadow_master"
			data.supply_cost = 5
			data.production_cost = 95.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Rogue.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.45
			data.movement_profile = UnitData.MovementProfile.INFILTRATOR
		# AETHERLANDS V2, Fase 11 — Catapulta, unidade-base da Doutrina de Cerco (nó v2_doctrine_siege_3): o primeiro
		# instrumento realmente eficiente contra cidades. Ataque básico ranged (alcance 2) pelo combate normal —
		# SEM fórmula anti-unidade especial; o valor dela é o bônus INATO de Cerco contra cidade (auditoria da Fase 11:
		# UnitAbilities.city_attack_multiplier já dava +50% a UnitAbilities.SIEGE por `kind` — generalizado pra também
		# reconhecer o traço `siege`, então esta unidade herda o MESMO bônus sem duplicar a classificação) e Munição
		# Demolidora (N4, +40% adicional). Contra o Arqueiro (13 / 4,5 / 2,5 / mov. 2 / alcance 2 / 20 PP): custo maior
		# (28 PP), HP um pouco maior, Defesa igual — não é feita pra vencer unidades, é feita pra derrubar cidades.
		# Traço `siege` declarado no dado (Desmantelar do Ladino já a reconhece, nenhuma integração entre Doutrinas).
		# Sem upkeep. BALANCE PLACEHOLDER. Modelo PROVISÓRIO: o corpo procedural "catapult" já existente do V1 — mesmo
		# NOME de exibição da Catapulta V1 (`kind` diferente; ver a mesma limitação já documentada nas Fases 7-8 para
		# Espadachim/Arqueiro) na escala 1,0.
		"v2_unit_catapult":
			data.unit_name = "Catapulta"
			data.movement_points = 2.0
			data.attack = 3.5
			data.defense = 2.5
			data.attack_range = 2
			data.max_hp = 16.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_catapult"
			data.supply_cost = 1
			data.production_cost = 28.0
			data.traits.append(UnitData.TRAIT_SIEGE)
			data.visual_template = "catapult"
		# Fase 11 — Trebuchet, primeira evolução da linha de Cerco (nó v2_doctrine_siege_5): o ganho principal é
		# ALCANCE (3, +1 sobre a Catapulta) e mais poder por tile de Cerco — o MOVIMENTO permanece 2 (não é uma
		# evolução de mobilidade). Upgrade Catapulta -> Trebuchet = 2 x (44 - 28) = 32 Ouro (fórmula genérica).
		# BALANCE PLACEHOLDER: 20 / 5,0 / 3,0 / mov. 2 / alcance 3 / 44 PP. Modelo PROVISÓRIO: o mesmo corpo
		# "catapult" 15% maior.
		"v2_unit_trebuchet":
			data.unit_name = "Trebuchet"
			data.movement_points = 2.0
			data.attack = 5.0
			data.defense = 3.0
			data.attack_range = 3
			data.max_hp = 20.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_trebuchet"
			data.supply_cost = 2
			data.production_cost = 44.0
			data.traits.append(UnitData.TRAIT_SIEGE)
			data.visual_template = "catapult"
			data.model_scale_multiplier = 1.15
		# Fase 11 — Bombarda, forma Elite CONVENCIONAL da linha de Cerco (nó v2_doctrine_siege_7; NÃO é Lendária):
		# sobrevive melhor e pressiona mais, continua precisando de proteção e continua inferior ao Patrulheiro
		# equivalente em combate ranged anti-unidade — nunca vira um tanque. Upgrade Trebuchet -> Bombarda =
		# 2 x (64 - 44) = 40 Ouro. BALANCE PLACEHOLDER: 26 / 6,5 / 4,0 / mov. 2 / alcance 3 / 64 PP. Modelo
		# PROVISÓRIO: o mesmo corpo "catapult" 30% maior.
		"v2_unit_bombard":
			data.unit_name = "Bombarda"
			data.movement_points = 2.0
			data.attack = 6.5
			data.defense = 4.0
			data.attack_range = 3
			data.max_hp = 26.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_bombard"
			data.supply_cost = 3
			data.production_cost = 64.0
			data.traits.append(UnitData.TRAIT_SIEGE)
			data.visual_template = "catapult"
			data.model_scale_multiplier = 1.3
		# Fase 11 — Colosso de Cerco, candidato a Unidade LENDÁRIA da linha de Cerco (nó v2_doctrine_siege_9,
		# `legendary_candidate`). NÃO é upgrade da Bombarda: unidade separada, produzida no Grande Arsenal, sob o
		# MESMO slot global de V2LegendarySystem das outras cinco Lendárias (traço `legendary` semeado no fim de
		# create_unit). A singularidade NÃO é o número (44 HP / 8,0 Defesa fica abaixo do Campeão Guardião, 44 / 10,0;
		# Ataque 9,0 fica abaixo do Herói, 12,0) — é a passiva ARTILHARIA ANDANTE: pode usar Bombardeio Preparado
		# mesmo depois de se mover (`ignores_technique_stationary_requirement`, ver V2TechniqueRuntime.
		# unavailable_reason — não ganha ação extra, a Técnica continua consumindo a ação normalmente); as formas
		# convencionais continuam exigindo posição parada. Herda Munição Demolidora e Bombardeio Preparado pela linha
		# (doctrine_branch_of == siege). DOIS traços de origens diferentes, nenhum substitui o outro: `siege`
		# (Desmantelar do Ladino o reconhece) E `legendary` (Caçada Lendária do Caçador de Lendas também o reconhece).
		# BALANCE PLACEHOLDER: 44 / 9,0 / 8,0 / mov. 2 / visão 4 / alcance 3 / 110 PP. Modelo PROVISÓRIO: o mesmo
		# corpo "catapult" 50% maior (sem prédio/criatura de "colosso" nos pacotes gratuitos — o mais coerente com
		# "grande máquina de Cerco" disponível).
		"v2_legendary_siege_colossus":
			data.unit_name = "Colosso de Cerco"
			data.movement_points = 2.0
			data.attack = 9.0
			data.defense = 8.0
			data.attack_range = 3
			data.max_hp = 44.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "v2_legendary_siege_colossus"
			data.supply_cost = 5
			data.production_cost = 110.0
			data.traits.append(UnitData.TRAIT_SIEGE)
			data.visual_template = "catapult"
			data.model_scale_multiplier = 1.5
			data.ignores_technique_stationary_requirement = true
		# AETHERLANDS V2, Fase 15 — Construtor: unidade CIVIL, melhora recursos do mapa
		# (V2ConstructorRuntime). Sem Ataque, sem participar de composição militar/Doutrina/
		# slot Lendário/Suprimentos (supply_cost 0, igual ao Colonizador). Treinado na OFICINA
		# (BuildingDatabase: v2_building_workshop.trains_unit), liberado por
		# `required_v2_unlock_id = "v2_building_workshop"` — pesquisar Oficinas já libera, sem
		# um segundo unlock artificial no mesmo nó (§53 do pedido). work_charges_remaining
		# (Unit.gd) é setado no nascimento pelo tier de Indústria do dono (GameManager),
		# nunca aqui. BALANCE PLACEHOLDER. Modelo PROVISÓRIO: Rogue do KayKit (silhueta civil,
		# sem armadura pesada — já usado pelo Batedor V1/Ladino V2, mas nenhuma arma visível
		# nesta escala reduzida).
		"v2_unit_builder":
			data.unit_name = "Construtor"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 1.0
			data.max_hp = 8.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "v2_unit_builder"
			data.supply_cost = 0
			data.production_cost = 16.0
			data.required_v2_unlock_id = "v2_building_workshop"
			data.model_scene_path = "res://assets/models/kaykit/characters/Rogue.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 0.9
		# AETHERLANDS V2, Fase 17 — Clérigo, conjurador da Escola Sagrada (nó v2_magic_sacred_3). Unidade física do exército
		# (consome 2 Suprimentos, sofre a Tensão Logística na Defesa), mas SEM ATAQUE BÁSICO (can_basic_attack = false: nunca
		# inicia ataque nem revida; Ataque 0 sozinho não bastaria por causa do piso de dano). `v2_magic_school` "sacred" semeia o
		# traço `caster` (Desmantelar do Ladino vale sozinho) e define o repertório (V2MagicRuntime.spells_for_unit). Treinado no
		# Templo Sagrado. BALANCE PLACEHOLDER: 12 / 0 / 2,0 / mov. 2 / visão 3 / 24 PP. Modelo PROVISÓRIO: o Mage do KayKit.
		"v2_unit_sacred_cleric":
			data.unit_name = "Clérigo"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 2.0
			data.max_hp = 12.0
			data.vision_range = 3
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_unit_sacred_cleric"
			data.v2_magic_school = "sacred"
			data.supply_cost = 2
			data.production_cost = 24.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Mage.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.0
		# AETHERLANDS V2, Fase 17 — Serafim, Grande Manifestação da Escola Sagrada (nó v2_magic_sacred_9). Entidade mágica
		# persistente: voa pelo MESMO perfil FLYING da Fase 9 (sem a vulnerabilidade à distância do Grifo — ser voador não
		# implica ser vulnerável), não consome Suprimentos (é sustentada por magia), não ataca, conhece o repertório Sagrado do
		# dono (v2_magic_school) e emite a Presença Sagrada pela MESMA infraestrutura de aura do Comando Defensivo (V2UnitAuras).
		# Traços: caster (qualquer namespace de Escola), flying (perfil) e grand_manifestation (metadata do nó) — NUNCA legendary.
		# Produção: 100 PP + 60 Mana cobrada na conclusão (production_mana_cost). BALANCE PLACEHOLDER: 38 / 0 / 7,0 / mov. 3 /
		# visão 4. Modelo PROVISÓRIO: o Mage do KayKit em escala 1,5 (nenhum modelo de anjo nos pacotes gratuitos).
		"v2_manifestation_seraph":
			data.unit_name = "Serafim"
			data.movement_points = 3.0
			data.attack = 0.0
			data.defense = 7.0
			data.max_hp = 38.0
			data.vision_range = 4
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_manifestation_seraph"
			data.v2_magic_school = "sacred"
			data.supply_cost = 0
			data.production_cost = 100.0
			data.production_mana_cost = 60.0
			data.movement_profile = UnitData.MovementProfile.FLYING
			data.ranged_damage_taken_bonus = 0.0
			data.aura_id = "sacred_presence"
			data.aura_name = "Presença Sagrada"
			data.aura_radius = 2
			data.aura_defense_bonus = 0.15
			data.model_scene_path = "res://assets/models/kaykit/characters/Mage.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.5
		# AETHERLANDS V2, Fase 18 — Bruxo Infernal: caster ofensivo frágil, sem ataque básico.
		# `v2_magic_school` separa semanticamente o id "infernal" da Escola V1 de mesmo id.
		"v2_unit_infernal_warlock":
			data.unit_name = "Bruxo Infernal"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 1.5
			data.max_hp = 10.0
			data.vision_range = 3
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_unit_infernal_warlock"
			data.v2_magic_school = "infernal"
			data.spell_damage_multiplier = 1.0
			data.supply_cost = 2
			data.production_cost = 24.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Mage.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 0.9
		# AETHERLANDS V2, Fase 18 — Arquidemônio: Grande Manifestação Infernal. O modelo
		# monstruoso existente é reaproveitado; nenhum runtime específico da Escola.
		"v2_manifestation_archdemon":
			data.unit_name = "Arquidemônio"
			data.movement_points = 3.0
			data.attack = 0.0
			data.defense = 6.0
			data.max_hp = 36.0
			data.vision_range = 4
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_manifestation_archdemon"
			data.v2_magic_school = "infernal"
			data.spell_damage_multiplier = 1.25
			data.spell_damage_multiplier_name = "Chama Primordial"
			data.supply_cost = 0
			data.production_cost = 105.0
			data.production_mana_cost = 70.0
			data.movement_profile = UnitData.MovementProfile.FLYING
			data.ranged_damage_taken_bonus = 0.0
			data.model_scene_path = "res://assets/generated/magic/archdemon/archdemon.glb"
			data.animation_scene_path = data.model_scene_path
			data.merge_shared_walk_animation = false
			data.idle_animation_override = "Idle"
			data.walk_animation_override = "Walk"
			data.attack_animation_override = "Attack"
			data.model_scale_multiplier = 1.0
		# AETHERLANDS V2, Fase 19 — Necromante: conjurador da Escola de Necromancia e COMANDANTE de retinues
		# (retinue_command_capacity 2, somado por civilização em V2RetinueSystem). Humano vivo: não é undead nem
		# retinue. Consome 2 Suprimentos (os comandantes usam a logística normal; as Hostes, não). BALANCE
		# PLACEHOLDER: 10 / 0 / 1,5 / mov. 2 / visão 3 / 24 PP. Modelo PROVISÓRIO: o Mage do KayKit.
		"v2_unit_necromancer":
			data.unit_name = "Necromante"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 1.5
			data.max_hp = 10.0
			data.vision_range = 3
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_unit_necromancer"
			data.v2_magic_school = "necromancy"
			data.retinue_command_capacity = 2
			data.supply_cost = 2
			data.production_cost = 24.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Mage.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 0.95
		# Fase 19 — Hoste Esquelética: UM token que representa um GRUPO de esqueletos (nunca N Units). Retinue da
		# Necromancia de custo de comando 1, combate físico normal, 0 Suprimentos, só nasce por feitiço (fora de
		# PLAYER_TRAINABLE_KINDS, nenhum prédio a treina). BALANCE PLACEHOLDER: 18 / 4,0 / 3,0 / mov. 2 / visão 2.
		# Visual PROVISÓRIO: três corpos do esqueleto da Asset Factory dentro da MESMA Unit (model_formation_count).
		"v2_unit_skeleton_host":
			data.unit_name = "Hoste Esquelética"
			data.movement_points = 2.0
			data.attack = 4.0
			data.defense = 3.0
			data.max_hp = 18.0
			data.vision_range = 2
			data.attack_range = 1
			data.can_basic_attack = true
			data.can_found_city = false
			data.visual_kind = "v2_unit_skeleton_host"
			data.retinue_school = "necromancy"
			data.retinue_command_cost = 1
			data.traits.append(UnitData.TRAIT_UNDEAD)
			data.supply_cost = 0
			data.production_cost = 0.0
			_apply_skeleton_formation(data, 3)
		# Fase 19 — Hoste Macabra: formação MAIOR de mortos-vivos, custo de comando 2. Não é upgrade da Esquelética:
		# as duas coexistem como opções de custo. BALANCE PLACEHOLDER: 30 / 7,0 / 5,0 / mov. 2 / visão 3.
		"v2_unit_macabre_host":
			data.unit_name = "Hoste Macabra"
			data.movement_points = 2.0
			data.attack = 7.0
			data.defense = 5.0
			data.max_hp = 30.0
			data.vision_range = 3
			data.attack_range = 1
			data.can_basic_attack = true
			data.can_found_city = false
			data.visual_kind = "v2_unit_macabre_host"
			data.retinue_school = "necromancy"
			data.retinue_command_cost = 2
			data.traits.append(UnitData.TRAIT_UNDEAD)
			data.supply_cost = 0
			data.production_cost = 0.0
			_apply_skeleton_formation(data, 5)
		# Fase 19 — Lich Soberano: Grande Manifestação da Necromancia. Conjurador (repertório por v2_magic_school),
		# undead (declarado), grand_manifestation (metadata do nó) — nunca legendary nem retinue (custo de comando 0:
		# cria capacidade, não a consome). Soberania dos Mortos = retinue_command_capacity 4, só dado. 100 PP + 65 Mana
		# na conclusão. BALANCE PLACEHOLDER: 34 / 0 / 6,0 / mov. 2 / visão 4. Modelo PROVISÓRIO: o Lich Ancião V1.
		"v2_manifestation_lich_sovereign":
			data.unit_name = "Lich Soberano"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 6.0
			data.max_hp = 34.0
			data.vision_range = 4
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_manifestation_lich_sovereign"
			data.v2_magic_school = "necromancy"
			data.retinue_command_capacity = 4
			data.retinue_command_capacity_name = "Soberania dos Mortos"
			data.traits.append(UnitData.TRAIT_UNDEAD)
			data.supply_cost = 0
			data.production_cost = 100.0
			data.production_mana_cost = 65.0
			data.model_scene_path = "res://assets/generated/magic/elder_lich/elder_lich.glb"
			data.animation_scene_path = data.model_scene_path
			data.merge_shared_walk_animation = false
			data.idle_animation_override = "Idle"
			data.walk_animation_override = "Walk"
			data.attack_animation_override = "Attack"
			data.model_scale_multiplier = 1.0
		# AETHERLANDS V2, Fase 20 — Druida: conjurador da Escola Druídica (modificação física persistente de terreno, via
		# V2TerrainRuntime pelos feitiços). Mortal: 2 Suprimentos (a Tensão reduz a Defesa dele, nunca os feitiços), sem
		# ataque básico. Não é undead/retinue/legendary/manifestation. BALANCE PLACEHOLDER: 12 / 0 / 2,0 / mov. 2 / visão 3 /
		# 24 PP. Modelo PROVISÓRIO: o Mage do KayKit (a identidade vem do emblema "DR" da Escola).
		"v2_unit_druid":
			data.unit_name = "Druida"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 2.0
			data.max_hp = 12.0
			data.vision_range = 3
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_unit_druid"
			data.v2_magic_school = "druidism"
			data.supply_cost = 2
			data.production_cost = 24.0
			data.model_scene_path = "res://assets/models/kaykit/characters/Mage.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.05
		# Fase 20 — Avatar da Natureza: Grande Manifestação Druídica. Conjurador (repertório por v2_magic_school), traço
		# grand_manifestation pela metadata do nó — nunca legendary/retinue/undead. Domínio Natural = spell_range_bonus 1 por
		# dado (V2MagicRuntime.effective_range, genérico). 105 PP + 65 Mana na conclusão, 0 Suprimentos, terrestre, sem ataque.
		# BALANCE PLACEHOLDER: 42 / 0 / 8,0 / mov. 3 / visão 4. Visual PROVISÓRIO: o corpo procedural do Ent V1 ("treant"),
		# ampliado (visual_template) — não há modelo de avatar natural nos pacotes.
		"v2_manifestation_nature_avatar":
			data.unit_name = "Avatar da Natureza"
			data.movement_points = 3.0
			data.attack = 0.0
			data.defense = 8.0
			data.max_hp = 42.0
			data.vision_range = 4
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_manifestation_nature_avatar"
			data.visual_template = "treant"
			data.model_scale_multiplier = 1.7
			data.v2_magic_school = "druidism"
			data.spell_range_bonus = 1
			data.spell_range_bonus_name = "Domínio Natural"
			data.supply_cost = 0
			data.production_cost = 105.0
			data.production_mana_cost = 65.0
		# AETHERLANDS V2, Fase 21 — Arcanista: caster frágil de mobilidade/utilidade, sem ataque básico.
		# BALANCE PLACEHOLDER: 10 / 0 / 1,5 / mov. 2 / visão 4 / 24 PP / Supply 2.
		"v2_unit_arcanist":
			data.unit_name = "Arcanista"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 1.5
			data.max_hp = 10.0
			data.vision_range = 4
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_unit_arcanist"
			data.v2_magic_school = "arcanism"
			data.supply_cost = 2
			data.production_cost = 24.0
			data.movement_profile = UnitData.MovementProfile.GROUND
			data.model_scene_path = "res://assets/models/kaykit/characters/Mage.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.1
		# Fase 21 — Arconte do Véu: Grande Manifestação voadora do Arcanismo. Fluxo do Véu reduz
		# a recarga aplicada pelos feitiços em 1, inteiramente por dado. Nunca legendary/retinue/undead.
		"v2_manifestation_veil_archon":
			data.unit_name = "Arconte do Véu"
			data.movement_points = 4.0
			data.attack = 0.0
			data.defense = 5.5
			data.max_hp = 34.0
			data.vision_range = 5
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_manifestation_veil_archon"
			data.v2_magic_school = "arcanism"
			data.spell_cooldown_reduction = 1
			data.spell_cooldown_reduction_name = "Fluxo do Véu"
			data.supply_cost = 0
			data.production_cost = 105.0
			data.production_mana_cost = 70.0
			data.movement_profile = UnitData.MovementProfile.FLYING
			data.ranged_damage_taken_bonus = 0.0
			data.model_scene_path = "res://assets/generated/magic/arcane_caster/arcane_caster.glb"
			data.animation_scene_path = data.model_scene_path
			data.merge_shared_walk_animation = false
			data.idle_animation_override = "Idle"
			data.walk_animation_override = "Walk"
			data.attack_animation_override = "Attack"
			data.model_scale_multiplier = 1.45
		# AETHERLANDS V2, Fase 22 — Elementalista: caster frágil de controle ambiental.
		# BALANCE PLACEHOLDER: 11 / 0 / 1,5 / mov. 2 / visão 4 / 24 PP / Supply 2.
		"v2_unit_elementalist":
			data.unit_name = "Elementalista"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 1.5
			data.max_hp = 11.0
			data.vision_range = 4
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_unit_elementalist"
			data.v2_magic_school = "elementalism"
			data.supply_cost = 2
			data.production_cost = 24.0
			data.movement_profile = UnitData.MovementProfile.GROUND
			data.model_scene_path = "res://assets/models/kaykit/characters/Mage.glb"
			data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
			data.model_scale_multiplier = 1.0
		# Fase 22 — Primordial dos Elementos: Grande Manifestação voadora. Coração
		# Elemental materializa +1 rodada somente nas zonas criadas por ela.
		"v2_manifestation_elemental_primordial":
			data.unit_name = "Primordial dos Elementos"
			data.movement_points = 4.0
			data.attack = 0.0
			data.defense = 6.5
			data.max_hp = 40.0
			data.vision_range = 5
			data.attack_range = 0
			data.can_basic_attack = false
			data.can_found_city = false
			data.visual_kind = "v2_manifestation_elemental_primordial"
			data.v2_magic_school = "elementalism"
			data.environmental_zone_duration_bonus = 1
			data.environmental_zone_duration_bonus_name = "Coração Elemental"
			data.supply_cost = 0
			data.production_cost = 110.0
			data.production_mana_cost = 75.0
			data.movement_profile = UnitData.MovementProfile.FLYING
			data.ranged_damage_taken_bonus = 0.0
			data.visual_template = "storm_elemental"
			data.model_scale_multiplier = 1.7
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
	return _seed_traits(data, kind)

## Fase 19 — visual PROVISÓRIO das Hostes: o esqueleto da Asset Factory (o mesmo do monstro "skeleton"), repetido
## `count` vezes dentro da MESMA Unit (só malha: nenhuma lógica, HP, seleção ou caminho individual). Escala 1:1
## (altura = o "height" do preset), como todo modelo da Asset Factory.
static func _apply_skeleton_formation(data: UnitData, count: int) -> void:
	data.model_scene_path = "res://assets/generated/skeletons/skeleton_blocky/skeleton_blocky.glb"
	data.animation_scene_path = data.model_scene_path
	data.merge_shared_walk_animation = false
	data.idle_animation_override = "Idle"
	data.walk_animation_override = "Walk"
	data.attack_animation_override = "Attack"
	data.model_scale_multiplier = 1.0
	data.model_formation_count = count

## Traços SEMÂNTICOS semeados a partir de classificações que já existem (Fases 5-6, 9-10) — nunca uma lista nova de ids na LÓGICA de combate/
## movimento, só aqui, na criação do dado.
static func _seed_traits(data: UnitData, kind: String) -> UnitData:
	# Traço "montada" (Fase 5): a classificação V1 de UnitAbilities.MOUNTED (a única definição
	# de quais tropas V1 são montadas) vira um TRAÇO no dado. Toda regra "contra montados"
	# consulta UnitData.has_trait — as unidades V2 de Cavalaria só precisarão declará-lo.
	if kind in UnitAbilities.MOUNTED and not data.has_trait(UnitData.TRAIT_MOUNTED):
		data.traits.append(UnitData.TRAIT_MOUNTED)
	# Traço "legendary" (Fase 6): todo unlock `legendary_candidate` (os N9 conectados) vira Lendário no dado, sem
	# lista de ids aqui — V2LegendarySystem.is_legendary_kind lê a metadata de pesquisa.
	if V2LegendarySystem.is_legendary_kind(kind) and not data.has_trait(UnitData.TRAIT_LEGENDARY):
		data.traits.append(UnitData.TRAIT_LEGENDARY)
	# Traço "flying" (Fase 9): toda unidade de perfil de voo tático (MovementProfile.FLYING) o carrega — a pergunta "voa?" para regras futuras (clima...) é um
	# traço, sem lista de ids. O voo V1 (`flies`: grifo, elemental, monstros) segue como sempre e não passa por aqui (UnitData.is_flying() cobre os dois).
	if data.movement_profile == UnitData.MovementProfile.FLYING and not data.has_trait(UnitData.TRAIT_FLYING):
		data.traits.append(UnitData.TRAIT_FLYING)
	# Traço "caster" unificado (Fase 10/18): V1 e V2 têm namespaces de Escola separados,
	# mas compartilham a classificação pública semântica via helper.
	if data.is_caster() and not data.has_trait(UnitData.TRAIT_CASTER):
		data.traits.append(UnitData.TRAIT_CASTER)
	# Traço "siege" (Fase 10, Desmantelar): a classificação V1 de UnitAbilities.SIEGE (a única lista de máquinas de Cerco, já usada pelo bônus de
	# dano contra cidade) vira um TRAÇO no dado — as máquinas de Cerco V2 só precisarão declará-lo.
	if kind in UnitAbilities.SIEGE and not data.has_trait(UnitData.TRAIT_SIEGE):
		data.traits.append(UnitData.TRAIT_SIEGE)
	# Traço "grand_manifestation" (Fase 17): todo unlock `grand_manifestation` (o N9 de uma Escola) — pela metadata de
	# pesquisa, como o `legendary`. Nunca `legendary`: slots e counters diferentes (V2ManifestationSystem).
	if V2ManifestationSystem.is_manifestation_kind(kind) and not data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION):
		data.traits.append(UnitData.TRAIT_GRAND_MANIFESTATION)
	# Traço "retinue" (Fase 19): toda unidade que ocupa comando mágico pelo DADO (retinue_school + custo) — sem lista de ids.
	if data.is_retinue() and not data.has_trait(UnitData.TRAIT_RETINUE):
		data.traits.append(UnitData.TRAIT_RETINUE)
	return data

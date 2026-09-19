class_name MonsterDatabase
extends RefCounted

## Monstros neutros: guardam Covis de Monstro espalhados pelo mapa (ver
## HexGrid._spawn_monster_lairs) e, desde a introducao de MonsterAI, agem
## por conta propria a cada turno (guardar territorio, marchar sobre uma
## cidade, cacar presa isolada — ver MonsterAI.gd). Sao Unit comuns com
## owner_player == null: nunca entram em nenhuma PlayerData.units, entao
## GameManager processa o turno deles separado do loop de jogador/rival
## (ver GameManager._on_turn_changed: reset_movement + MonsterAI.take_turn).
## Quem vence um monstro em combate recebe unit_data.gold_reward em ouro
## (CombatResolver.resolve()).

const BEHAVIOR_GUARDIAN := "guardian" # fica no territorio do covil (raio configuravel, ver guard_radius/MonsterAI.GUARD_RADIUS), so briga com quem invade -- OU com cidade inimiga que se aproximar o bastante (ver MonsterAI._take_guardian_turn)
const BEHAVIOR_INVADER := "invader" # marcha sobre a cidade inimiga mais proxima do mapa INTEIRO, brigando com quem encontrar no caminho (ver MonsterAI._take_invader_turn)
const BEHAVIOR_HUNTER := "hunter" # patrulha uma area larga cacando presa isolada/fraca, so ataca se favoravel (ver MonsterAI._take_hunter_turn)
## COMPORTAMENTO DOS MONSTROS (pedido do usuario: "muitos monstros parecem
## extremamente passivos... quero uma revisao... cada tipo pode possuir
## comportamento proprio... goblins podem ser agressivos e oportunistas:
## saquear; atacar unidades fracas; ameacar melhorias; aproximar-se de
## cidades proximas"). Guardiao (radio pequeno, so reage a quem entra) era
## PASSIVO DEMAIS pro Goblin default -- Saqueador busca ATIVAMENTE presa
## fraca/isolada dentro de um raio MAIOR que o Guardiao mas ainda preso ao
## territorio do proprio covil (nunca atravessa o mapa como o Invasor);
## sem presa a vista, se aproxima da cidade mais proxima DENTRO do raio
## (pra ameacar os arredores/saquear, nunca pra capturar) e ainda saqueia
## tile trabalhado normalmente (mesma _maybe_pillage_tile do Invasor). Ver
## MonsterAI._take_raider_turn/RAIDER_RADIUS.
const BEHAVIOR_RAIDER := "raider"

## Tabela central de dados por tipo — mesmo espirito de HexGrid._BIOME_TABLE
## (geracao de terreno): tudo que diferencia um tipo de monstro do outro
## fica AQUI, num dicionario so, em vez de espalhado por match/if-elif. Pra
## ajustar bioma/raridade/tamanho de grupo/comportamento de um tipo, mexe
## so aqui.
##
## Campos:
## - biomes: Array[HexTileData.TerrainType] onde esse tipo pode ser
##   sorteado pro COVIL (ver HexGrid._spawn_monster_lairs/random_kind
##   abaixo). Reforco/patrulha nao re-checam bioma — o covil ja fixou o
##   tipo, so a colocacao INICIAL depende de bioma.
## - weight: peso de sorteio entre os tipos ELEGIVEIS (bioma + ameaca) num
##   dado tile — nao e uma probabilidade global fixa, ver random_kind.
## - min_threat (0..1, ver HexGrid._threat_level): abaixo disso o tipo fica
##   INDISPONIVEL pro covil, nao so com peso baixo.
## - lair_cap: populacao maxima viva (guardiao incluso) que ESSE tipo
##   mantem na area do proprio covil (ver HexGrid._count_live_monsters_
##   near_lair) — substitui o antigo LAIR_SPAWN_CAP fixo unico.
## - global_cap: populacao maxima viva desse tipo em QUALQUER LUGAR do
##   mapa, somando TODOS os covis (ver HexGrid._count_alive_of_kind/
##   _global_cap_for) — pedido do usuario: "ponha um limite no spawn de
##   monstros... cada um so pode ter 5 vivos por vez, no caso dos vivern 2
##   vivos de uma vez e no dragao apenas 1". Independente de lair_cap: um
##   mapa grande pode ter VARIOS covis do mesmo tipo, cada um enchendo ate
##   o proprio lair_cap — sem este segundo teto, o total global do tipo
##   nao teria limite nenhum (ex: 3 covis de Vivern, lair_cap 2 cada,
##   dariam 6 Viverns vivos ao mesmo tempo sem essa checagem extra).
## - batch_spawn: quantos nascem de uma vez quando o covil acerta o roll de
##   reforco (ver HexGrid._reinforce_lair) — Esqueleto nasce em grupo (3),
##   o resto nasce um de cada vez (1).
## - behavior: BEHAVIOR_* default do tipo (MonsterAI pode substituir por
##   instancia via Unit.monster_behavior_state, ver invader_promotable).
## - invader_promotable: se true, um grupo de 2+ unidades OCIOSAS (ainda no
##   comportamento default) desse tipo na area do covil e promovido pra
##   Invasor pela MonsterAI (ver INVADER_GROUP_THRESHOLD) — so faz sentido
##   pra tipos BEHAVIOR_GUARDIAN que devem "virar" agressivos em grupo
##   (Goblin); Esqueleto ja nasce Invasor, nao precisa de promocao.
## - clear_reward: ouro concedido por DESTRUIR o covil abandonado (atacar
##   a LairStructure ate zerar o HP dela, ver CombatResolver.
##   resolve_lair_attack/HexGrid._grant_lair_clear_reward) — recompensa
##   maior e de uma vez so, diferente de gold_reward (que paga por matar
##   CADA monstro individual em combate).
## - clear_reward_mana: MESMO evento (destruir a estrutura), mas em Mana
##   em vez de ouro — pedido do usuario (RECOMPENSAS DE COVIS: "ouro;
##   recurso; mana; experiencia; combinacao; recompensa especifica por
##   tipo... escolha recompensas coerentes com os sistemas atuais").
##   0.0 (goblin/troll: bandido comum/brutamontes, sem ligacao arcana
##   nenhuma) pros tipos "mundanos"; so' os tipos com identidade
##   tematica arcana ja estabelecida ganham Mana — Esqueleto (morto-vivo,
##   residuo de necromancia) modesto, Vivern/Dragao (guardioes dos
##   continentes Vulcanico/de Cristal, ver comentario de biomes do Vivern
##   abaixo) o suficiente pra valer um feitico (SpellDatabase: feiticos
##   custam 25-60 de Mana). Sistema de Mana ja existe (PlayerData.mana,
##   gasto em feiticos) — reusado direto, sem inventar um "banco de
##   recurso" novo so' pra covil (Ferro/Gemas/Seda/Cavalos so existem como
##   YIELD de tile trabalhado, nao tem estoque nenhum pra depositar).
const KIND_DATA := {
	"goblin": {
		"biomes": [HexTileData.TerrainType.FOREST, HexTileData.TerrainType.PLAINS, HexTileData.TerrainType.GRASSLAND],
		"weight": 60, "min_threat": 0.0, "lair_cap": 4, "global_cap": 5, "batch_spawn": 1,
		# COMPORTAMENTO DOS MONSTROS: Saqueador (nao mais Guardiao) e' o
		# default -- Goblin sozinho/em duplas incomoda ativamente os
		# arredores do proprio covil; ao atingir INVADER_GROUP_THRESHOLD
		# ociosos, o bando inteiro ainda e promovido a Invasor de verdade
		# (invader_promotable, inalterado), virando uma invasao real.
		"behavior": BEHAVIOR_RAIDER, "invader_promotable": true,
		"unit_name": "Goblin", "attack": 3.0, "defense": 2.0, "max_hp": 8.0,
		"movement_points": 1.0, "vision_range": 1, "gold_reward": 15.0, "clear_reward": 75.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "goblin",
	},
	"troll": {
		"biomes": [HexTileData.TerrainType.MOUNTAINS, HexTileData.TerrainType.TAIGA, HexTileData.TerrainType.TUNDRA],
		"weight": 30, "min_threat": 0.3, "lair_cap": 2, "global_cap": 5, "batch_spawn": 1,
		# COMPORTAMENTO DOS MONSTROS (pedido do usuario: "trolls podem
		# defender uma regiao maior... nao precisam atravessar meio
		# continente... mas se uma cidade, unidade ou territorio estiver
		# suficientemente proximo, podem reagir"): continua Guardiao (nunca
		# sai do proprio territorio, ataque incondicional), so' com raio
		# MAIOR que o padrao (MonsterAI.GUARD_RADIUS=2) -- "guard_radius"
		# e' lido por MonsterAI._guard_radius_for, ausente pra qualquer
		# outro kind cai no padrao.
		"behavior": BEHAVIOR_GUARDIAN, "guard_radius": 5, "invader_promotable": false,
		"unit_name": "Troll", "attack": 6.0, "defense": 4.0, "max_hp": 20.0,
		"movement_points": 1.0, "vision_range": 1, "gold_reward": 35.0, "clear_reward": 100.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "troll",
	},
	"wyvern": {
		# Microbiomas dos continentes Vulcanico/de Cristal (VOLCANIC_ROCK/
		# PEAKS/ASH, CRYSTAL_PEAKS, MYSTIC_SOIL/SPRING) somados aqui —
		# sem isso, _spawn_monster_lairs (nao escopado por zona) cairia no
		# fallback "ignora bioma" de MonsterDatabase.random_kind pra
		# qualquer tile desses tipos novos, deixando Goblin/Troll/Esqueleto
		# nascerem nos continentes especiais e quebrando a identidade
		# tematica estrita pedida pelo usuario. Vivern vira "guardiao de
		# todo o continente especial", extensao natural do que ja cobria
		# (Lava/Mar de Lava/Cristal).
		"biomes": [
			HexTileData.TerrainType.LAVA, HexTileData.TerrainType.LAVA_SEA, HexTileData.TerrainType.CRYSTAL,
			HexTileData.TerrainType.VOLCANIC_ROCK, HexTileData.TerrainType.VOLCANIC_HILLS, HexTileData.TerrainType.VOLCANIC_PEAKS, HexTileData.TerrainType.VOLCANIC_ASH,
			HexTileData.TerrainType.CRYSTAL_PEAKS, HexTileData.TerrainType.MYSTIC_SOIL, HexTileData.TerrainType.MYSTIC_SPRING,
		],
		"weight": 10, "min_threat": 0.65, "lair_cap": 2, "global_cap": 2, "batch_spawn": 1,
		"behavior": BEHAVIOR_HUNTER, "invader_promotable": false,
		"unit_name": "Vivern", "attack": 8.0, "defense": 3.0, "max_hp": 16.0,
		"movement_points": 3.0, "vision_range": 1, "gold_reward": 70.0, "clear_reward": 130.0, "clear_reward_mana": 20.0,
		"flies": true, "visual_kind": "wyvern",
	},
	"skeleton": {
		"biomes": [HexTileData.TerrainType.DESERT, HexTileData.TerrainType.TUNDRA],
		"weight": 25, "min_threat": 0.15, "lair_cap": 4, "global_cap": 5, "batch_spawn": 3,
		"behavior": BEHAVIOR_INVADER, "invader_promotable": false,
		"unit_name": "Esqueleto", "attack": 4.0, "defense": 1.0, "max_hp": 6.0,
		"movement_points": 2.0, "vision_range": 1, "gold_reward": 10.0, "clear_reward": 85.0, "clear_reward_mana": 10.0,
		"flies": false, "visual_kind": "skeleton",
	},
	"dragon": {
		"biomes": [HexTileData.TerrainType.LAVA],
		"weight": 5, "min_threat": 0.85, "lair_cap": 1, "global_cap": 1, "batch_spawn": 1,
		"behavior": BEHAVIOR_HUNTER, "invader_promotable": false,
		"unit_name": "Dragao", "attack": 16.0, "defense": 8.0, "max_hp": 50.0,
		"movement_points": 2.0, "vision_range": 2, "gold_reward": 200.0, "clear_reward": 150.0, "clear_reward_mana": 35.0,
		"flies": true, "visual_kind": "dragon",
	},
}
const KINDS := ["goblin", "troll", "wyvern", "skeleton", "dragon"] # ordem fixa (nao KIND_DATA.keys(), ver nota abaixo), usada por WEIGHTS-like iteracao e testes que esperam ordem estavel

## O ocupante ORIGINAL de um covil (spawnado por HexGrid._spawn_monster_
## lairs) multiplica HP/ataque em cima da tabela — le como um "chefao" de
## verdade guardando o proprio covil, nao so mais um reforco igual aos que
## nascem depois. Ver create_monster(is_camp_boss).
const CAMP_BOSS_HP_MULTIPLIER := 2.5
const CAMP_BOSS_ATTACK_MULTIPLIER := 1.3

## `is_camp_boss` distingue o ocupante ORIGINAL de um covil (sempre
## chamado assim por HexGrid._spawn_monster_lairs) de um reforco/patrulha
## comum (todo o resto, default false): o boss NUNCA se move
## (movement_points = 0, preserva o comportamento historico de "guardiao
## nunca sai do proprio tile" — ver test_create_monster_camp_boss_never_
## moves) e vem com HP/ataque multiplicados (CAMP_BOSS_HP_MULTIPLIER/
## CAMP_BOSS_ATTACK_MULTIPLIER). Um reforco comum usa movement_points de
## verdade da tabela — "ficar parado perto do covil" agora e uma ESCOLHA
## de IA (MonsterAI, comportamento Guardiao), nao mais uma trava de stat.
static func create_monster(kind: String, is_camp_boss: bool = false) -> UnitData:
	var info: Dictionary = KIND_DATA.get(kind, KIND_DATA["goblin"])
	var data := UnitData.new()
	data.unit_name = info.unit_name
	data.attack = info.attack * (CAMP_BOSS_ATTACK_MULTIPLIER if is_camp_boss else 1.0)
	data.defense = info.defense
	data.max_hp = info.max_hp * (CAMP_BOSS_HP_MULTIPLIER if is_camp_boss else 1.0)
	data.vision_range = info.vision_range
	data.visual_kind = info.visual_kind
	data.gold_reward = info.gold_reward
	data.flies = info.flies
	data.movement_points = 0.0 if is_camp_boss else info.movement_points
	# Identidade visual: segundo teste da 3D Asset Factory numa especie
	# NAO-humana (depois do Goblin) -- mesmo esqueleto/rig de 18 ossos,
	# HumanStyle magro/oco (slim_build+thin_arms, orbitas ocas via
	# body_blocky.build_head_parts eye_style="hollow", ver style/textures.
	# build_head_face_image), pele tom osso (MaterialLibrary.skin_color_
	# override). Substitui o modelo KayKit (Skeleton_Warrior.glb, CC0) que
	# era usado antes — Troll/Wyvern/Dragao continuam sem modelo
	# procedural equivalente por ora. Preset: presets/skeleton_blocky.json.
	if kind == "skeleton":
		data.model_scene_path = "res://assets/generated/skeletons/skeleton_blocky/skeleton_blocky.glb"
		data.animation_scene_path = "res://assets/generated/skeletons/skeleton_blocky/skeleton_blocky.glb"
		data.merge_shared_walk_animation = false
		data.idle_animation_override = "Idle"
		data.walk_animation_override = "Walk"
		data.attack_animation_override = "Attack"
		# Escala 1:1 direta agora (ver Unit.gd _build_model_body's
		# ASSET_FACTORY_PATH_PREFIX check): modelos da 3D Asset Factory
		# nao passam mais pela normalizacao MODEL_TARGET_HEIGHT/aabb.
		# size.y, entao model_scale_multiplier volta a ser 1.0 -- a
		# altura final agora e literalmente a altura "1.75" do preset
		# JSON, na mesma unidade do resto do jogo, sem nenhuma conta.
		#
		# Isso resolve, na raiz, uma saga inteira de tentativas de
		# calibrar esse numero: a normalizacao por aabb.size.y (formula
		# antiga) e algebricamente garantida a dar sempre MODEL_TARGET_
		# HEIGHT*mult, independente do aabb -- confirmado medindo de
		# varias formas (aabb local, global_transform.basis.get_scale(),
		# aabb em espaco de mundo) -- mas o Esqueleto renderizava ~1.28x
		# mais alto que essa formula previa no jogo de verdade, sem causa
		# raiz encontrada (nao era timing de animacao nem swing de braco
		# no Idle). O usuario perguntou "o caminho correto nao seria
		# deixar eles apenas com o tamanho do modelo 3d deles?" -- sim, e
		# eliminar a normalizacao (nao so recalibrar o multiplicador em
		# cima dela) e a correcao de verdade.
		data.model_scale_multiplier = 1.0
		data.model_yaw_offset_degrees = 180.0
	elif kind == "goblin":
		# Identidade visual: primeiro teste da 3D Asset Factory (tools/
		# asset_factory) numa especie NAO-humana — mesmo esqueleto/rig de
		# 18 ossos do Guarda/Colonizador, mas HumanStyle com proporcoes bem
		# diferentes (baixinho, cabeca enorme, magro) + pele/cabelo verdes
		# (MaterialLibrary.skin_color_override/hair_color_override, ver
		# tools/asset_factory/style/palette.py) + orelhas pontudas (style.
		# pointy_ears, ver body_blocky.build_head_parts) em vez de reusar a
		# cor de pele humana fixa. Preset: presets/goblin_blocky.json.
		data.model_scene_path = "res://assets/generated/goblins/goblin_blocky/goblin_blocky.glb"
		data.animation_scene_path = "res://assets/generated/goblins/goblin_blocky/goblin_blocky.glb"
		data.merge_shared_walk_animation = false
		data.idle_animation_override = "Idle"
		data.walk_animation_override = "Walk"
		data.attack_animation_override = "Attack"
		# NAO é a mesma escala do Guarda/Colonizador -- um goblin TEM que
		# parecer mais baixo que um humano. Ver comentario do Colonizador
		# acima sobre por que o multiplicador nao pode ser copiado entre
		# personagens. "Deixe o goblin mais ou menos na altura da barriga
		# quase chegando no peito" (do Guarda) -- medido em compute_
		# measurements do proprio Guarda: z_spine_top (topo da barriga)
		# fica a 68.1% da altura total dele, z_chest_top a 85.5% -- "quase
		# chegando no peito" mira por volta de 80%.
		# Escala 1:1 direta agora (ver comentario longo do Esqueleto
		# acima e Unit.gd _build_model_body's ASSET_FACTORY_PATH_PREFIX
		# check) -- sem normalizacao por aabb, model_scale_multiplier
		# volta a 1.0. A altura final passa a ser literalmente o "height"
		# do preset (1.3m vs 1.8m do Guarda, ~72% -- perto do "quase
		# chegando no peito" pedido, sem precisar calcular multiplicador
		# nenhum). Se a proporcao ainda nao ficar certa, o ajuste agora e
		# no proprio preset (tools/asset_factory/presets/goblin_blocky.
		# json "height"), nao aqui.
		data.model_scale_multiplier = 1.0
		data.model_yaw_offset_degrees = 180.0
	elif kind == "troll":
		# Identidade visual: terceiro teste da 3D Asset Factory numa
		# especie NAO-humana (depois do Goblin e do Esqueleto) -- mesmo
		# esqueleto/rig de 18 ossos, mas HumanStyle grande (sem slim_build/
		# thin_arms -- o "built" default, mais limb_slenderness 1.15 pra
		# ficar um pouco mais volumoso, SEM exagero -- ver nota abaixo) +
		# pele azul-acinzentada escura, olhos amarelos "slit", definicao de
		# musculo real (equipment.muscles, ver body_blocky.py) + tanga de
		# couro (pelvis_material="leather") + um porrete de log com
		# espinhos CURTOS (weapon="troll_club", ver equipment_blocky.
		# build_troll_club_parts) -- pedido do usuario com imagem de
		# referencia (um troll estilo Minecraft). Preset: presets/
		# troll_blocky.json.
		data.model_scene_path = "res://assets/generated/trolls/troll_blocky/troll_blocky.glb"
		data.animation_scene_path = "res://assets/generated/trolls/troll_blocky/troll_blocky.glb"
		data.merge_shared_walk_animation = false
		data.idle_animation_override = "Idle"
		data.walk_animation_override = "Walk"
		data.attack_animation_override = "Attack"
		# "pode ter 2x o tamanho de uma pessoa" (usuario) -- o que fazia
		# ele parecer MUITO maior que qualquer altura pedida nao era a
		# altura em si: ombros largos (shoulder_width_ratio 0.34 -> 0.27),
		# limb_slenderness exagerado (1.35 -> 1.15) e principalmente os
		# espinhos do porrete esticando bem pra LADOS (spike_len ~1.3x a
		# largura da cabeca do porrete -> 0.55x).
		# Escala 1:1 direta agora (ver comentario longo do Esqueleto acima
		# e Unit.gd _build_model_body ASSET_FACTORY_PATH_PREFIX check) --
		# model_scale_multiplier volta a 1.0, altura final = "height" do
		# preset. Redimensionado no editor Blender pra 2.5m (~1.4x o
		# Guarda de 1.8m) -- ajustar altura agora e so no proprio preset
		# (troll_blocky.json "height" + resalvar/reexportar), nao aqui.
		data.model_scale_multiplier = 1.0
		data.model_yaw_offset_degrees = 180.0
	return data

## Ouro pago por destruir o covil ABANDONADO (ver HexGrid.destroy_lair/
## _grant_lair_clear_reward) — kind desconhecido cai no valor do Goblin,
## mesmo fallback de create_monster acima.
static func lair_clear_reward(kind: String) -> float:
	return KIND_DATA.get(kind, KIND_DATA["goblin"]).get("clear_reward", 75.0)

## RECOMPENSAS DE COVIS: Mana paga pelo MESMO evento acima (ver comentario
## de clear_reward_mana no topo do arquivo) -- 0.0 pra kind desconhecido ou
## sem identidade arcana (goblin/troll), nunca negativo.
static func lair_clear_mana_reward(kind: String) -> float:
	return KIND_DATA.get(kind, {}).get("clear_reward_mana", 0.0)

## Sorteio ponderado deterministico — `rng` ja vem semeado pelo chamador
## (HexGrid._spawn_monster_lairs usa map_seed), entao o resultado e 100%
## reproduzivel pra mesma semente de mapa. `threat_level` (default 1.0 =
## "sem restricao de ameaca") filtra tipos cujo KIND_MIN_THREAT nao foi
## atingido; `terrain_type` (default -1 = "sem filtro de bioma", nunca um
## HexTileData.TerrainType valido de verdade, todos sao >= 0) filtra tipos
## cujo bioma nao inclui esse terreno. Os dois filtros se somam (E logico);
## se ninguem sobra, cai pro filtro so-por-ameaca (compat com chamadas
## antigas sem bioma); se AINDA ninguem sobra (bioma existe mas nenhum tipo
## elegivel por ameaca bate ali), cai pro mais fraco (KINDS[0], goblin).
static func random_kind(rng: RandomNumberGenerator, threat_level: float = 1.0, terrain_type: int = -1) -> String:
	var eligible := _eligible_kinds(threat_level, terrain_type)
	if eligible.is_empty():
		eligible = _eligible_kinds(threat_level, -1) # cai pro filtro so-por-ameaca (ignora bioma)
	if eligible.is_empty():
		eligible = [KINDS[0]] # sempre sobra pelo menos o mais fraco (min_threat 0.0, sem restricao de bioma)

	var total := 0
	for k in eligible:
		total += KIND_DATA[k].weight
	var roll = rng.randi_range(0, total - 1)
	var acc := 0
	for k in eligible:
		acc += KIND_DATA[k].weight
		if roll < acc:
			return k
	return eligible[0]

static func _eligible_kinds(threat_level: float, terrain_type: int) -> Array:
	var eligible: Array = []
	for k in KINDS:
		var info: Dictionary = KIND_DATA[k]
		if threat_level < info.min_threat:
			continue
		if terrain_type != -1 and not (terrain_type in info.biomes):
			continue
		eligible.append(k)
	return eligible

## Como random_kind, mas restrito a tipos com flies=true — usado SO pra
## covis nascendo em tile de Lava/Mar de Lava (HexGrid._spawn_monster_
## lairs), onde um tipo terrestre ficaria fisicamente preso pra sempre
## (LAVA/LAVA_SEA bloqueiam unidade terrestre, ver HexTileData.
## blocks_land_units). Cai pro tipo voador mais fraco elegivel pro bioma
## (ignorando ameaca) se nenhum bater min_threat — NUNCA cai pro fallback
## biome-agnostico de random_kind (que poderia devolver um tipo
## terrestre); devolve "" (nao KINDS[0]) se mesmo assim nada servir, pro
## chamador pular esse candidato em vez de forcar um monstro que nao pode
## existir ali.
static func random_flying_kind(rng: RandomNumberGenerator, threat_level: float, terrain_type: int) -> String:
	var eligible: Array = _eligible_kinds(threat_level, terrain_type).filter(func(k): return KIND_DATA[k].flies)
	if eligible.is_empty():
		eligible = _eligible_kinds(0.0, terrain_type).filter(func(k): return KIND_DATA[k].flies)
	if eligible.is_empty():
		return ""

	var total := 0
	for k in eligible:
		total += KIND_DATA[k].weight
	var roll = rng.randi_range(0, total - 1)
	var acc := 0
	for k in eligible:
		acc += KIND_DATA[k].weight
		if roll < acc:
			return k
	return eligible[0]

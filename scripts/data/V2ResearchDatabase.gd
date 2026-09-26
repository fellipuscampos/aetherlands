class_name V2ResearchDatabase
extends RefCounted

## Fundação de dados das TRÊS árvores de pesquisa do Aetherlands V2 (ver
## docs/AETHERLANDS_V2_IMPLEMENTATION.md): Doutrinas Militares, Escolas de
## Magia e Infraestrutura. Todas são categorias (V2ResearchNode.TreeType) de UM
## único sistema conceitual de pesquisa — no futuro, um projeto ativo por vez,
## pago em Conhecimento. Nada aqui pressupõe três filas ou três pools.
##
## Este banco é "O QUE EXISTE": dados, relações e consultas puras. O que UMA
## civilização já pesquisou (ativo, concluídos, progresso, overflow) vive em
## V2ResearchState (scripts/core) — nunca aqui, o banco é estático e compartilhado.
##
## FASES 0–2 (histórico): nenhum nó alterava gameplay e a pesquisa V1 corria em
## paralelo. Fase 25: esta é a única árvore de pesquisa do jogo (a V1 foi removida,
## ver docs/AETHERLANDS_V2_IMPLEMENTATION.md).
## unlock_type/unlock_id seguem sendo só metadata. Fase 2: as Doutrinas Militares
## têm conteúdo canônico (V2DoctrineContent); Magia e Infraestrutura seguem
## placeholders estruturais.
## FASE 3: só os nós com `gameplay_connected` (Guardião N1-N3, ver V2DoctrineContent.
## CONNECTED_UNLOCK_IDS) liberam algo de verdade, via V2UnlockSystem.
##
## Estrutura (55 + 55 + 18 = 128 nós):
##  - Doutrinas: 6 linhas x 9 níveis + Exército Supremo.
##  - Escolas:   6 linhas x 9 níveis + Transcendência.
##  - Infraestrutura: 6 linhas x 3 níveis (scaffold — uma linha pode ficar com
##    2 níveis no futuro se o 3º não gerar decisão; não é obrigação manter 18).
##
## IDs: v2_doctrine_<linha>_<n>, v2_magic_<linha>_<n>,
## v2_infrastructure_<linha>_<n>, v2_supreme_army, v2_transcendence.

const ID_PREFIX := "v2_"
const SUPREME_ARMY_ID := "v2_supreme_army"
const TRANSCENDENCE_ID := "v2_transcendence"

const BRANCH_TIER_COUNT := 9
const INFRASTRUCTURE_TIER_COUNT := 3
const CAPSTONE_TIER := 10
## "Duas Doutrinas completas" / "duas Escolas completas" (N9 concluído).
const CAPSTONE_REQUIRED_BRANCHES := 2

## Fase 27 — primeira curva balanceada por microcenários e telemetria multi-seed.
## Mantém crescimento estritamente monotônico sem a parede exponencial da F26.
const BRANCH_TIER_COSTS := [8.0, 16.0, 24.0, 28.0, 40.0, 80.0, 128.0, 196.0, 268.0]
## Infraestrutura I / II / III, preservando sua curva curta e monotônica.
const INFRASTRUCTURE_TIER_COSTS := [16.0, 48.0, 120.0]
## Projeto separado e materialmente mais caro que o N9, sem bloquear o endgame.
const CAPSTONE_COST := 400.0

## Fase 12: o nome da VIA DE VITÓRIA que cada capstone universal desbloqueia — não é
## o nome do nó de pesquisa (Exército Supremo desbloqueia a Supremacia Militar; o nó
## em si nunca é a vitória, ver docs/AETHERLANDS_V2_IMPLEMENTATION.md #48). Chave é o
## `tree_type` (estrutural), nunca o id do nó — o mesmo texto serve a Transcendência
## (Escolas de Magia) sem precisar de um segundo mecanismo de capstone.
const CAPSTONE_VICTORY_LABELS := {
	V2ResearchNode.TreeType.MILITARY_DOCTRINE: "Supremacia Militar",
	V2ResearchNode.TreeType.MAGIC_SCHOOL: "Transcendência",
}
## Ressalva fixa nos capstones de vitória: a condição TERRITORIAL/urbana final
## ainda não existe (depende de City Level/Urbanização, Infraestrutura V2 — fase
## futura). Nunca apresentar uma regra temporária como definitiva.
## Fase 16: a condição territorial está conectada (V2VictoryConditions).
const CAPSTONE_TERRITORIAL_NOTE := "Vitória: para cada rival, mantenha uma Cidade III+ conquistada dele (ou elimine-o)."
const CAPSTONE_TRANSCENDENCE_NOTE := "Ritual Final: mantenha 2 Grandes Manifestações ativas e uma cidade com Estrutura Ritual utilizável; custa 120 Mana e dura 4 rodadas."

const PLACEHOLDER_NOTICE := "Conteúdo ainda não implementado."
## Nota discreta do tooltip nos nós com conteúdo canônico (não-placeholder) mas
## ainda sem gameplay: concluir a pesquisa não muda nada no jogo. (Fase 3: os nós
## conectados mostram no lugar o que desbloqueiam, ver unlock_effect_text.)
const GAMEPLAY_NOTICE := "Efeito ainda não conectado ao jogo."

## Regra futura (Fase 2: só registrada, nenhum slot Lendário existe): cada
## civilização poderá ter somente UMA Unidade Lendária ativa por vez. Os seis N9
## das Doutrinas são os `legendary_candidate`.
const MAX_ACTIVE_LEGENDARY_UNITS := 1

## Rótulo em português de cada `unlock_type` (tooltip/UI). Os tipos das
## Doutrinas seguem o vocabulário canônico da Fase 2; os demais são das Fases 0-1.
const UNLOCK_TYPE_LABELS := {
	"doctrine": "Doutrina",
	"building": "Estrutura",
	"unit": "Unidade",
	"technique": "Técnica",
	"unit_upgrade": "Evolução de unidade",
	"mastery_building": "Estrutura de Maestria",
	"legendary_candidate": "Candidato a Unidade Lendária",
	"victory_capstone": "Capstone de vitória",
	"city_level": "Nível de cidade",
	"school": "Escola",
	"caster": "Conjurador",
	"spell": "Feitiço",
	"manifestation": "Grande Manifestação",
	"school_building": "Prédio da Escola",
	"ritual_building": "Estrutura Ritual",
	"grand_manifestation": "Grande Manifestação",
	"infrastructure_upgrade": "Melhoria de infraestrutura",
}

## Estado de um nó para uma civilização (ver node_state e V2ResearchState).
## PARTIAL = disponível, com progresso guardado, mas não é o projeto ativo.
enum NodeState { LOCKED, AVAILABLE, RESEARCHING, COMPLETED, PARTIAL }

const STATE_LABELS := {
	NodeState.LOCKED: "Bloqueado",
	NodeState.AVAILABLE: "Disponível",
	NodeState.RESEARCHING: "Pesquisando",
	NodeState.COMPLETED: "Concluído",
	NodeState.PARTIAL: "Parcial",
}

# --- Papéis fixos dos tiers (parte do design oficial da V2, NÃO placeholder) ---

const DOCTRINE_TIER_ROLES := [
	"doctrine_unlock", "training_structure", "base_unit", "technique_1",
	"evolution_1", "technique_2", "elite_form", "mastery_structure",
	"legendary_candidate",
]
const MAGIC_TIER_ROLES := [
	"school_unlock", "school_building", "caster", "basic_spell",
	"intermediate_spell", "advanced_spell", "greater_spell",
	"ritual_structure", "grand_manifestation",
]
## Infraestrutura: o pedido não fixa papéis por nível — um papel por nível
## (I / II / III) da própria linha.
const INFRASTRUCTURE_TIER_ROLES := ["infrastructure_level_1", "infrastructure_level_2", "infrastructure_level_3"]

const TIER_ROLE_LABELS := {
	"doctrine_unlock": "Doutrina",
	"training_structure": "Estrutura de treinamento",
	"base_unit": "Unidade-base",
	"technique_1": "Técnica I",
	"evolution_1": "Primeira evolução",
	"technique_2": "Técnica II",
	"elite_form": "Forma Elite",
	"mastery_structure": "Estrutura de Maestria",
	"legendary_candidate": "Candidato a Unidade Lendária",
	"school_unlock": "Escola",
	"school_building": "Prédio da Escola",
	"caster": "Conjurador",
	"basic_spell": "Feitiço Básico",
	"intermediate_spell": "Feitiço Intermediário",
	"advanced_spell": "Feitiço Avançado",
	"greater_spell": "Grande Feitiço",
	"ritual_structure": "Estrutura Ritual",
	"grand_manifestation": "Grande Manifestação",
	"infrastructure_level_1": "Nível I",
	"infrastructure_level_2": "Nível II",
	"infrastructure_level_3": "Nível III",
	"military_victory_capstone": "Capstone de Vitória Militar",
	"magic_victory_capstone": "Capstone de Vitória Mágica",
}

## O que cada papel desbloqueará no futuro (V2ResearchNode.unlock_type).
const TIER_ROLE_UNLOCK_TYPES := {
	"doctrine_unlock": "doctrine",
	"training_structure": "building",
	"base_unit": "unit",
	"technique_1": "technique",
	"evolution_1": "unit_upgrade",
	"technique_2": "technique",
	"elite_form": "unit_upgrade",
	"mastery_structure": "mastery_building",
	"legendary_candidate": "legendary_candidate",
	"school_unlock": "school",
	# Fase 17: tipos PRÓPRIOS da Magia (prédio de Escola, estrutura ritual e Grande Manifestação não são
	# "building"/Lendária militares — o toast, o tooltip e o slot de Manifestação distinguem por tipo).
	"school_building": "school_building",
	"caster": "caster",
	"basic_spell": "spell",
	"intermediate_spell": "spell",
	"advanced_spell": "spell",
	"greater_spell": "spell",
	"ritual_structure": "ritual_building",
	"grand_manifestation": "grand_manifestation",
	"infrastructure_level_1": "infrastructure_upgrade",
	"infrastructure_level_2": "infrastructure_upgrade",
	"infrastructure_level_3": "infrastructure_upgrade",
	"military_victory_capstone": "victory_capstone",
	"magic_victory_capstone": "victory_capstone",
}

## "Futuramente desbloqueará <isto>." — {title} = nome da linha (nominativo),
## {of} = genitivo ("da Doutrina do Guardião").
const TIER_ROLE_FUTURE_TEXT := {
	"doctrine_unlock": "a {title}",
	"training_structure": "a estrutura de treinamento {of}",
	"base_unit": "a unidade-base {of}",
	"technique_1": "a Técnica I {of}",
	"evolution_1": "a primeira evolução {of}",
	"technique_2": "a Técnica II {of}",
	"elite_form": "a Forma Elite {of}",
	"mastery_structure": "a Estrutura de Maestria {of}",
	"legendary_candidate": "o candidato a Unidade Lendária {of}",
	"school_unlock": "a {title}",
	"school_building": "o prédio {of}",
	"caster": "o conjurador {of}",
	"basic_spell": "o feitiço básico {of}",
	"intermediate_spell": "o feitiço intermediário {of}",
	"advanced_spell": "o feitiço avançado {of}",
	"greater_spell": "o grande feitiço {of}",
	"ritual_structure": "a estrutura ritual {of}",
	"grand_manifestation": "a Grande Manifestação {of}",
	"infrastructure_level_1": "o nível I {of}",
	"infrastructure_level_2": "o nível II {of}",
	"infrastructure_level_3": "o nível III {of}",
}

const ROMAN_NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]

# --- Linhas (branches). `role` é a identidade semântica, `summary` é texto de UI ---

const DOCTRINE_BRANCHES := [
	{"id": "guardian", "name": "Guardião", "title": "Doutrina do Guardião", "genitive": "da Doutrina do Guardião", "role": "tank_frontline", "summary": "Tank / linha de frente / proteção"},
	{"id": "warrior", "name": "Guerreiro", "title": "Doutrina do Guerreiro", "genitive": "da Doutrina do Guerreiro", "role": "melee_damage", "summary": "Dano físico corpo a corpo"},
	{"id": "ranger", "name": "Patrulheiro", "title": "Doutrina do Patrulheiro", "genitive": "da Doutrina do Patrulheiro", "role": "ranged_combat", "summary": "Combate à distância"},
	{"id": "cavalry", "name": "Cavalaria", "title": "Doutrina da Cavalaria", "genitive": "da Doutrina da Cavalaria", "role": "mobility_shock", "summary": "Mobilidade, flanco e choque"},
	{"id": "rogue", "name": "Ladino", "title": "Doutrina do Ladino", "genitive": "da Doutrina do Ladino", "role": "sabotage_assassination", "summary": "Sabotagem e alvos prioritários"},
	{"id": "siege", "name": "Cerco", "title": "Doutrina de Cerco", "genitive": "da Doutrina de Cerco", "role": "city_conquest", "summary": "Conquista e destruição de cidades"},
]

const MAGIC_BRANCHES := [
	{"id": "sacred", "name": "Sagrada", "title": "Escola Sagrada", "genitive": "da Escola Sagrada", "role": "sustain", "summary": "Sustentação: cura, proteção e suporte de formação"},
	{"id": "infernal", "name": "Infernal", "title": "Escola Infernal", "genitive": "da Escola Infernal", "role": "magical_damage", "summary": "Dano mágico"},
	{"id": "necromancy", "name": "Necromancia", "title": "Escola de Necromancia", "genitive": "da Escola de Necromancia", "role": "undead_summoning", "summary": "Mortos-vivos e Retinues"},
	{"id": "druidism", "name": "Druidismo", "title": "Escola Druídica", "genitive": "da Escola Druídica", "role": "terrain_manipulation", "summary": "Manipulação física do terreno"},
	{"id": "arcanism", "name": "Arcanismo", "title": "Escola do Arcanismo", "genitive": "da Escola do Arcanismo", "role": "mobility_utility", "summary": "Mobilidade e utilidade mágica"},
	{"id": "elementalism", "name": "Elementalismo", "title": "Escola de Elementalismo", "genitive": "da Escola de Elementalismo", "role": "environmental_control", "summary": "Controle ambiental: clima e terremoto"},
]

const INFRASTRUCTURE_BRANCHES := [
	{"id": "economy", "name": "Economia", "title": "Linha de Economia", "genitive": "da linha de Economia", "role": "gold", "summary": "Foco: Ouro"},
	{"id": "logistics", "name": "Logística", "title": "Linha de Logística", "genitive": "da linha de Logística", "role": "supplies", "summary": "Foco: Suprimentos"},
	{"id": "industry", "name": "Indústria", "title": "Linha de Indústria", "genitive": "da linha de Indústria", "role": "production", "summary": "Foco: Produção"},
	{"id": "academy", "name": "Academia", "title": "Linha de Academia", "genitive": "da linha de Academia", "role": "knowledge", "summary": "Foco: Conhecimento"},
	{"id": "arcane", "name": "Arcana", "title": "Linha Arcana", "genitive": "da linha Arcana", "role": "mana", "summary": "Foco: Mana"},
	{"id": "urbanization", "name": "Urbanização", "title": "Linha de Urbanização/Fortificação", "genitive": "da linha de Urbanização/Fortificação", "role": "city_fortification", "summary": "Foco: nível da cidade e fortificações"},
]

# --- Cache (montado uma vez por sessão) ----------

static var _ordered: Array[V2ResearchNode] = []
static var _by_id: Dictionary = {}
static var _by_tree: Dictionary = {}    # TreeType -> Array[V2ResearchNode] (na ordem de criação)
static var _by_branch: Dictionary = {}  # "<tree>|<branch>" -> Array[V2ResearchNode] (por tier)
static var _by_unlock_id: Dictionary = {} # unlock_id canônico -> V2ResearchNode (só nós com conteúdo real)

static func _ensure_built() -> void:
	if not _ordered.is_empty():
		return
	for tree_type in tree_types():
		_by_tree[tree_type] = []
	_add_branches(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "doctrine", DOCTRINE_BRANCHES, DOCTRINE_TIER_ROLES, BRANCH_TIER_COSTS)
	_add_capstone(V2ResearchNode.TreeType.MILITARY_DOCTRINE, SUPREME_ARMY_ID, "Exército Supremo", "military_victory_capstone", "")
	_apply_doctrine_content()
	_add_branches(V2ResearchNode.TreeType.MAGIC_SCHOOL, "magic", MAGIC_BRANCHES, MAGIC_TIER_ROLES, BRANCH_TIER_COSTS)
	_add_capstone(V2ResearchNode.TreeType.MAGIC_SCHOOL, TRANSCENDENCE_ID, "Transcendência", "magic_victory_capstone",
		"Nó universal da árvore mágica. Exige duas Escolas completas até o N9 e libera a via de vitória por Transcendência.")
	_apply_magic_content()
	_add_branches(V2ResearchNode.TreeType.INFRASTRUCTURE, "infrastructure", INFRASTRUCTURE_BRANCHES, INFRASTRUCTURE_TIER_ROLES, INFRASTRUCTURE_TIER_COSTS)
	_apply_infrastructure_content()

static func _register(node: V2ResearchNode) -> void:
	_ordered.append(node)
	_by_id[node.id] = node
	_by_tree[node.tree_type].append(node)
	var key := _branch_key(node.tree_type, node.branch)
	if not _by_branch.has(key):
		_by_branch[key] = []
	_by_branch[key].append(node)

static func _add_branches(tree_type: int, id_kind: String, branches: Array, roles: Array, costs: Array) -> void:
	for line in branches:
		for tier in range(1, roles.size() + 1):
			var role: String = roles[tier - 1]
			var node := V2ResearchNode.new()
			node.id = "%s%s_%s_%d" % [ID_PREFIX, id_kind, line.id, tier]
			node.display_name = "%s %s" % [line.name, ROMAN_NUMERALS[tier - 1]]
			node.tree_type = tree_type
			node.branch = line.id
			node.tier = tier
			node.tier_role = role
			node.cost = costs[tier - 1]
			if tier > 1:
				node.prerequisites = [String("%s%s_%s_%d" % [ID_PREFIX, id_kind, line.id, tier - 1])]
			node.unlock_type = TIER_ROLE_UNLOCK_TYPES[role]
			node.unlock_id = "placeholder"
			node.is_placeholder = true
			node.branch_role = line.role
			node.description = _describe_future_unlock(role, line)
			_register(node)

static func _add_capstone(tree_type: int, id: String, display_name: String, role: String, summary: String) -> void:
	var node := V2ResearchNode.new()
	node.id = id
	node.display_name = display_name
	node.tree_type = tree_type
	node.branch = V2ResearchNode.UNIVERSAL_BRANCH
	node.tier = CAPSTONE_TIER
	node.tier_role = role
	node.cost = CAPSTONE_COST
	node.unlock_type = TIER_ROLE_UNLOCK_TYPES[role]
	node.unlock_id = "placeholder"
	node.is_placeholder = true
	node.is_universal = true
	node.requirement = {
		"type": "complete_branches",
		"tree_type": tree_type,
		"branch_count": CAPSTONE_REQUIRED_BRANCHES,
		"at_tier": BRANCH_TIER_COUNT,
	}
	node.description = "%s\n\n%s" % [summary, PLACEHOLDER_NOTICE]
	_register(node)

## Fase 2: troca o placeholder estrutural das Doutrinas Militares pelo conteúdo
## canônico (V2DoctrineContent): nome, descrição, unlock_id e função pretendida,
## mais a linha de evolução das três unidades convencionais (N3 -> N5 -> N7) e o
## capstone. NÃO mexe em `id`, `tier`, `tier_role`, `cost` nem `prerequisites` — o
## runtime de pesquisa e os saves da Fase 1 continuam valendo. Fase 3: marca
## `gameplay_connected` só nos unlock_ids de V2DoctrineContent.CONNECTED_UNLOCK_IDS.
static func _apply_doctrine_content() -> void:
	for line in DOCTRINE_BRANCHES:
		var entries := V2DoctrineContent.entries_for(line.id)
		var nodes: Array = _by_branch.get(_branch_key(V2ResearchNode.TreeType.MILITARY_DOCTRINE, line.id), [])
		var unit_line: Array[V2ResearchNode] = []
		for i in nodes.size():
			var node: V2ResearchNode = nodes[i]
			var entry: Dictionary = entries[i]
			node.display_name = entry.name
			node.unlock_id = entry.unlock_id
			node.intent = entry.intent
			node.description = entry.description
			if node.tier_role == "legendary_candidate":
				node.description = "%s %s" % [node.description, V2DoctrineContent.LEGENDARY_RULE]
			node.is_placeholder = false
			node.gameplay_connected = node.unlock_id in V2DoctrineContent.CONNECTED_UNLOCK_IDS
			if node.tier_role in ["base_unit", "evolution_1", "elite_form"]:
				unit_line.append(node)
			_by_unlock_id[node.unlock_id] = node
		for j in unit_line.size():
			if j > 0:
				unit_line[j].upgrade_from = unit_line[j - 1].unlock_id
			if j < unit_line.size() - 1:
				unit_line[j].upgrade_to = unit_line[j + 1].unlock_id
	var army: V2ResearchNode = _by_id[SUPREME_ARMY_ID]
	army.unlock_id = V2DoctrineContent.SUPREME_ARMY_UNLOCK_ID
	army.intent = V2DoctrineContent.SUPREME_ARMY_INTENT
	army.description = V2DoctrineContent.SUPREME_ARMY_DESCRIPTION
	army.is_placeholder = false
	# Fase 12: mesma regra dos 54 nós normais — SÓ conectado se o próprio unlock_id
	# está na lista única (V2DoctrineContent.CONNECTED_UNLOCK_IDS), nunca um segundo
	# mecanismo de capstone.
	army.gameplay_connected = army.unlock_id in V2DoctrineContent.CONNECTED_UNLOCK_IDS
	_by_unlock_id[army.unlock_id] = army

## Fase 13/14: troca o placeholder estrutural da Infraestrutura pelo conteúdo canônico
## (V2InfrastructureContent): nome, descrição e função pretendida das 18 pesquisas. Urbanização
## ganha `unlock_type = "city_level"` (troca o tipo estrutural "infrastructure_upgrade" desta
## ÚNICA linha, ver V2CityLevelData). Fase 14: as cinco linhas econômicas (Economia/Logística/
## Indústria/Academia/Arcano) ganham `unlock_type = "building"` no N1 e `"infrastructure_upgrade"`
## no N2/N3 (§66 do pedido — o tipo estrutural já era "infrastructure_upgrade" por padrão, só o N1
## precisa virar "building"). As 18 pesquisas ficam `gameplay_connected = true`. NÃO mexe em `id`,
## `tier`, `tier_role`, `cost` nem `prerequisites`.
static func _apply_infrastructure_content() -> void:
	for line in INFRASTRUCTURE_BRANCHES:
		var entries := V2InfrastructureContent.entries_for(line.id)
		var nodes: Array = _by_branch.get(_branch_key(V2ResearchNode.TreeType.INFRASTRUCTURE, line.id), [])
		for i in nodes.size():
			var node: V2ResearchNode = nodes[i]
			var entry: Dictionary = entries[i]
			node.display_name = entry.name
			node.intent = entry.intent
			node.description = entry.description
			node.is_placeholder = false
			var unlock_id: String = entry.get("unlock_id", "")
			if unlock_id != "":
				node.unlock_id = unlock_id
				node.unlock_type = "city_level" if line.id == "urbanization" else ("building" if i == 0 else "infrastructure_upgrade")
				node.gameplay_connected = unlock_id in V2InfrastructureContent.CONNECTED_UNLOCK_IDS
				_by_unlock_id[unlock_id] = node

## Fase 17: troca o placeholder estrutural das Escolas de Magia com conteúdo canônico (V2MagicContent) — hoje
## só a Escola Sagrada: nome, descrição, unlock_id e função pretendida; `gameplay_connected` só nos ids de
## V2MagicContent.CONNECTED_UNLOCK_IDS. Desde a Fase 23, as seis Escolas e a Transcendência estão conectadas
## inertes. NÃO mexe em `id`, `tier`, `tier_role`, `cost` nem `prerequisites`.
static func _apply_magic_content() -> void:
	for line in MAGIC_BRANCHES:
		var entries := V2MagicContent.entries_for(line.id)
		if entries.is_empty():
			continue
		var nodes: Array = _by_branch.get(_branch_key(V2ResearchNode.TreeType.MAGIC_SCHOOL, line.id), [])
		for i in nodes.size():
			var node: V2ResearchNode = nodes[i]
			var entry: Dictionary = entries[i]
			node.display_name = entry.name
			node.unlock_id = entry.unlock_id
			node.intent = entry.intent
			node.description = entry.description
			if node.tier_role == "grand_manifestation":
				node.description = "%s %s" % [node.description, V2MagicContent.MANIFESTATION_RULE]
			node.is_placeholder = false
			node.gameplay_connected = node.unlock_id in V2MagicContent.CONNECTED_UNLOCK_IDS
			_by_unlock_id[node.unlock_id] = node
	var transcendence: V2ResearchNode = _by_id[TRANSCENDENCE_ID]
	transcendence.unlock_id = V2MagicContent.TRANSCENDENCE_UNLOCK_ID
	transcendence.intent = V2MagicContent.TRANSCENDENCE_INTENT
	transcendence.description = V2MagicContent.TRANSCENDENCE_DESCRIPTION
	transcendence.is_placeholder = false
	transcendence.gameplay_connected = transcendence.unlock_id in V2MagicContent.CONNECTED_UNLOCK_IDS
	_by_unlock_id[transcendence.unlock_id] = transcendence

static func _describe_future_unlock(role: String, line: Dictionary) -> String:
	var what: String = TIER_ROLE_FUTURE_TEXT[role].format({"title": line.title, "of": line.genitive})
	return "Futuramente desbloqueará %s.\n\n%s" % [what, PLACEHOLDER_NOTICE]

static func _branch_key(tree_type: int, branch: String) -> String:
	return "%d|%s" % [tree_type, branch]

# --- Consultas ------------------------------------------------------------------

static func all_nodes() -> Array[V2ResearchNode]:
	_ensure_built()
	return _ordered.duplicate()

static func get_node(id: String) -> V2ResearchNode:
	_ensure_built()
	return _by_id.get(id, null)

static func is_v2_id(id: String) -> bool:
	return id.begins_with(ID_PREFIX)

static func tree_types() -> Array[int]:
	var result: Array[int] = []
	result.append(V2ResearchNode.TreeType.MILITARY_DOCTRINE)
	result.append(V2ResearchNode.TreeType.MAGIC_SCHOOL)
	result.append(V2ResearchNode.TreeType.INFRASTRUCTURE)
	return result

## Todos os nós de uma árvore (Doutrinas/Escolas incluem o capstone).
static func nodes_for_tree(tree_type: int) -> Array[V2ResearchNode]:
	_ensure_built()
	var result: Array[V2ResearchNode] = []
	result.assign(_by_tree.get(tree_type, []))
	return result

## Nós de uma linha, em ordem de tier. UNIVERSAL_BRANCH devolve o capstone.
static func nodes_for_branch(tree_type: int, branch: String) -> Array[V2ResearchNode]:
	_ensure_built()
	var result: Array[V2ResearchNode] = []
	result.assign(_by_branch.get(_branch_key(tree_type, branch), []))
	return result

## As linhas da árvore, na ordem de exibição (Dictionary: id/name/title/genitive/
## role/summary). Não inclui o nó universal.
static func branches_for_tree(tree_type: int) -> Array:
	match tree_type:
		V2ResearchNode.TreeType.MILITARY_DOCTRINE:
			return DOCTRINE_BRANCHES
		V2ResearchNode.TreeType.MAGIC_SCHOOL:
			return MAGIC_BRANCHES
		V2ResearchNode.TreeType.INFRASTRUCTURE:
			return INFRASTRUCTURE_BRANCHES
	return []

static func branch_info(tree_type: int, branch: String) -> Dictionary:
	for info in branches_for_tree(tree_type):
		if info.id == branch:
			return info
	return {}

## Exército Supremo (Doutrinas) / Transcendência (Magia); null na Infraestrutura.
static func capstone_for_tree(tree_type: int) -> V2ResearchNode:
	match tree_type:
		V2ResearchNode.TreeType.MILITARY_DOCTRINE:
			return get_node(SUPREME_ARMY_ID)
		V2ResearchNode.TreeType.MAGIC_SCHOOL:
			return get_node(TRANSCENDENCE_ID)
	return null

static func tree_label(tree_type: int) -> String:
	match tree_type:
		V2ResearchNode.TreeType.MILITARY_DOCTRINE:
			return "Doutrinas Militares"
		V2ResearchNode.TreeType.MAGIC_SCHOOL:
			return "Escolas de Magia"
		V2ResearchNode.TreeType.INFRASTRUCTURE:
			return "Infraestrutura"
	return ""

static func role_label(tier_role: String) -> String:
	return TIER_ROLE_LABELS.get(tier_role, tier_role)

# --- Regra estrutural dos capstones e estados (sem gameplay) ---------------------

## Linha completa = o último tier (N9 / III) concluído. `completed` é um
## Dictionary id -> true (mesmo formato de V2ResearchState.completed_ids).
static func is_branch_completed(tree_type: int, branch: String, completed: Dictionary) -> bool:
	var nodes := nodes_for_branch(tree_type, branch)
	return not nodes.is_empty() and completed.has(nodes[nodes.size() - 1].id)

static func completed_branches(tree_type: int, completed: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for info in branches_for_tree(tree_type):
		if is_branch_completed(tree_type, info.id, completed):
			result.append(info.id)
	return result

## Vector2i(linhas completas, linhas exigidas) — pra UI mostrar "1/2".
static func capstone_progress(node_id: String, completed: Dictionary) -> Vector2i:
	var node := get_node(node_id)
	if node == null or not node.is_universal:
		return Vector2i.ZERO
	var needed: int = node.requirement.branch_count
	return Vector2i(mini(completed_branches(node.requirement.tree_type, completed).size(), needed), needed)

## Só REPRESENTA a condição ("duas Doutrinas/Escolas completas"): não executa
## vitória, não libera nada no jogo.
static func capstone_requirement_met(node_id: String, completed: Dictionary) -> bool:
	var progress := capstone_progress(node_id, completed)
	return progress.y > 0 and progress.x >= progress.y

static func is_available(node_id: String, completed: Dictionary) -> bool:
	var node := get_node(node_id)
	if node == null or completed.has(node_id):
		return false
	for prerequisite in node.prerequisites:
		if not completed.has(prerequisite):
			return false
	if node.is_universal and not capstone_requirement_met(node_id, completed):
		return false
	return true

static func node_state(node_id: String, completed: Dictionary, active_id: String = "", progress_by_id: Dictionary = {}) -> NodeState:
	if completed.has(node_id):
		return NodeState.COMPLETED
	if node_id == active_id and node_id != "":
		return NodeState.RESEARCHING
	if not is_available(node_id, completed):
		return NodeState.LOCKED
	return NodeState.PARTIAL if float(progress_by_id.get(node_id, 0.0)) > 0.0 else NodeState.AVAILABLE

static func state_label(state: int) -> String:
	return STATE_LABELS.get(state, "")

## Por que o nó não pode ser pesquisado agora ("" = pode). Única fonte do texto
## de bloqueio: a UI e V2ResearchState.unavailable_reason só repassam isto.
static func unavailable_reason(node_id: String, completed: Dictionary) -> String:
	var node := get_node(node_id)
	if node == null:
		return "Pesquisa inexistente."
	if completed.has(node_id):
		return "Já concluída."
	var missing: Array[String] = []
	for prerequisite in node.prerequisites:
		if not completed.has(prerequisite):
			var required := get_node(prerequisite)
			missing.append(required.display_name if required else prerequisite)
	if not missing.is_empty():
		return "Requer %s." % ", ".join(missing)
	if node.is_universal and not capstone_requirement_met(node_id, completed):
		var progress := capstone_progress(node_id, completed)
		return "Requer %d %s completas (N%d): %d/%d." % [node.requirement.branch_count, capstone_unit_word(node), node.requirement.at_tier, progress.x, progress.y]
	return ""

## "Doutrinas" / "Escolas" — o que o capstone conta.
static func capstone_unit_word(node: V2ResearchNode) -> String:
	return "Doutrinas" if node.tree_type == V2ResearchNode.TreeType.MILITARY_DOCTRINE else "Escolas"

## O nó de pesquisa que concede o `unlock_id` canônico (Fase 2); null se não existe
## (inclui "placeholder" e os ids das Escolas/Infraestrutura, ainda sem conteúdo real).
static func node_for_unlock_id(unlock_id: String) -> V2ResearchNode:
	_ensure_built()
	return _by_unlock_id.get(unlock_id, null)

## As 3 unidades convencionais da linha em ordem de evolução (unidade-base ->
## evolução -> Elite), como nós de pesquisa. [] fora das Doutrinas.
static func unit_line(branch: String) -> Array[V2ResearchNode]:
	var result: Array[V2ResearchNode] = []
	for node in nodes_for_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, branch):
		if node.tier_role in ["base_unit", "evolution_1", "elite_form"]:
			result.append(node)
	return result

## As técnicas convencionais da linha (N4 e N6).
static func techniques_for_branch(branch: String) -> Array[V2ResearchNode]:
	var result: Array[V2ResearchNode] = []
	for node in nodes_for_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, branch):
		if node.unlock_type == "technique":
			result.append(node)
	return result

## Os candidatos a Unidade Lendária (um por Doutrina: os N9).
static func legendary_candidates() -> Array[V2ResearchNode]:
	var result: Array[V2ResearchNode] = []
	for node in nodes_for_tree(V2ResearchNode.TreeType.MILITARY_DOCTRINE):
		if node.unlock_type == "legendary_candidate":
			result.append(node)
	return result

static func unlock_type_label(unlock_type: String) -> String:
	return UNLOCK_TYPE_LABELS.get(unlock_type, unlock_type)

## Como a linha aparece ao lado do nível: o título da Doutrina ("Doutrina do
## Guardião") nos nós com conteúdo canônico; o nome curto nos placeholders.
static func line_label(node: V2ResearchNode) -> String:
	var info := branch_info(node.tree_type, node.branch)
	return info.get("name", node.branch) if node.is_placeholder else info.get("title", node.branch)

## Quebra `text` em linhas de até `width` caracteres, sem cortar palavras (o tooltip
## não quebra sozinho; sem isto uma descrição longa vira uma linha gigante).
static func wrap_text(text: String, width: int) -> String:
	var lines: Array[String] = []
	for paragraph in text.split("\n"):
		var current := ""
		for word in paragraph.split(" "):
			if current != "" and current.length() + 1 + word.length() > width:
				lines.append(current)
				current = word
			else:
				current = word if current == "" else "%s %s" % [current, word]
		lines.append(current)
	return "\n".join(lines)

## Texto do tooltip: nome, linha, nível, papel, custo, pré-requisito e descrição;
## nos nós com conteúdo canônico também a linha de evolução, o desbloqueio futuro
## e a nota de que o gameplay V2 ainda não está conectado. `completed` (Fase 12):
## só muda o texto dos capstones de vitória (antes/depois de concluir); os demais
## tipos de unlock mostram o mesmo texto em qualquer estado, como sempre.
static func node_tooltip(node: V2ResearchNode, completed: bool = false) -> String:
	var lines: Array[String] = [node.display_name]
	if node.is_universal:
		lines.append("Nó universal · %s" % tree_label(node.tree_type))
	else:
		lines.append("%s · Nível %d" % [line_label(node), node.tier])
	lines.append(role_label(node.tier_role))
	lines.append("Custo: %d Conhecimento" % int(node.cost))
	if node.is_universal:
		lines.append("Requer: %d %s completas (N%d)" % [node.requirement.branch_count, capstone_unit_word(node), node.requirement.at_tier])
	elif node.prerequisites.is_empty():
		lines.append("Requer: nenhum (início da linha)")
	else:
		var names: Array[String] = []
		for prerequisite in node.prerequisites:
			var required := get_node(prerequisite)
			names.append(required.display_name if required else prerequisite)
		lines.append("Requer: %s" % ", ".join(names))
	if not node.is_placeholder:
		if node.upgrade_from != "" or node.upgrade_to != "":
			lines.append("Linha de evolução: %s" % _evolution_chain_text(node))
		if node.gameplay_connected:
			lines.append("Desbloqueio: %s" % unlock_type_label(node.unlock_type))
		elif node.unlock_id != "placeholder":
			lines.append("Desbloqueio futuro: %s" % unlock_type_label(node.unlock_type))
		else:
			# Fase 13: conteúdo canônico (is_placeholder=false) sem endereço estável ainda — as
			# 15 pesquisas inertes de Infraestrutura (§65: sem unlock id definitivo até a Fase 14).
			lines.append("Desbloqueio futuro: %s" % unlock_type_label(node.unlock_type))
	lines.append("")
	lines.append(wrap_text(node.description, 64))
	# Placeholder estrutural: só a descrição (que já traz o próprio aviso).
	if not node.is_placeholder:
		lines.append("")
		lines.append(wrap_text(unlock_effect_text(node, completed), 64) if node.gameplay_connected else GAMEPLAY_NOTICE)
	return "\n".join(lines)

## FASE 3: o que concluir um nó COM gameplay conectado realmente desbloqueia, em
## uma frase (mostrada no tooltip no lugar de GAMEPLAY_NOTICE). "" se o nó não
## está conectado. Unidade-base: a estrutura de treinamento exigida é o nó
## "training_structure" da mesma linha (derivada da estrutura, sem repetir dado).
## `completed` (Fase 12): só o capstone de vitória (`victory_capstone`) varia o
## texto por estado — os demais tipos ignoram o parâmetro, como sempre.
static func unlock_effect_text(node: V2ResearchNode, completed: bool = false) -> String:
	if not node.gameplay_connected:
		return ""
	match node.unlock_type:
		"doctrine":
			return "Desbloqueia a %s." % node.display_name
		"building":
			# Fase 14: as cinco linhas econômicas de Infraestrutura (Economia/Logística/Indústria/
			# Academia/Arcano) precisam do NOME DO PRÉDIO (ex.: "Mercado"), não do nome da pesquisa
			# (ex.: "Mercados Locais") — os dois divergem aqui, ao contrário das Doutrinas, onde o
			# nó e o prédio sempre têm o mesmo nome. Dirigido pelo dado (V2InfrastructureEconomyData),
			# nunca por `if node.unlock_id == "v2_building_market"`.
			if V2InfrastructureEconomyData.is_economy_building(node.unlock_id):
				return _infrastructure_economy_effect_text(node.branch, node.unlock_id)
			return "Desbloqueia %s." % node.display_name
		"infrastructure_upgrade":
			# Fase 14: só as cinco linhas econômicas ficam gameplay_connected com este tipo (N2/N3);
			# Só as linhas econômicas de Infraestrutura usam este tipo; Magia tem seus próprios tipos.
			return _infrastructure_economy_effect_text(node.branch, node.unlock_id)
		"unit":
			var text := "Desbloqueia %s." % node.display_name
			for candidate in nodes_for_branch(node.tree_type, node.branch):
				if candidate.tier_role == "training_structure":
					text += " Requer %s para treinamento." % candidate.display_name
					break
			return text
		"technique":
			# Fase 4: técnica de Doutrina, usável por toda unidade da linha.
			return "Desbloqueia %s para unidades %s." % [node.display_name, branch_info(node.tree_type, node.branch).get("genitive", "da linha")]
		"unit_upgrade":
			# Fase 4: a forma nova é treinada no lugar da anterior e as antigas evoluem.
			var structure := ""
			var base_name := ""
			for candidate in nodes_for_branch(node.tree_type, node.branch):
				if candidate.tier_role == "training_structure":
					structure = candidate.display_name
				elif candidate.unlock_id == node.upgrade_from:
					base_name = candidate.display_name
			# Sem pronome nem plural de propósito: serve a Guardião (m.), Sentinela (f.) e às demais formas.
			return "Desbloqueia %s. Cidades com %s passam a treinar %s diretamente, e cada %s existente pode evoluir em cidades próprias." % [node.display_name, structure, node.display_name, base_name]
		"mastery_building":
			# Fase 6: a estrutura de Maestria só habilita o candidato Lendário da linha (todos masculinos).
			var hall_name := ""
			var legend_name := ""
			for candidate in nodes_for_branch(node.tree_type, node.branch):
				if candidate.tier_role == "training_structure":
					hall_name = candidate.display_name
				elif candidate.tier_role == "legendary_candidate":
					legend_name = candidate.display_name
			return "Desbloqueia %s. Requer %s e permite treinar o %s após sua pesquisa." % [node.display_name, hall_name, legend_name]
		"legendary_candidate":
			var mastery_name := ""
			for candidate in nodes_for_branch(node.tree_type, node.branch):
				if candidate.tier_role == "mastery_structure":
					mastery_name = candidate.display_name
			return "Desbloqueia %s, a Unidade Lendária da Doutrina. Treinamento em %s; cada civilização só pode ter uma Unidade Lendária ativa ou em treinamento." % [node.display_name, mastery_name]
		"victory_capstone":
			# Fase 12: capstone universal -- acesso a uma VIA DE VITORIA, nunca uma
			# unidade/predio/tecnica/buff. O nome da vitoria vem do tree_type
			# (capstone_victory_label), nunca do node.display_name ("Exercito
			# Supremo" e o no; "Supremacia Militar" e a vitoria que ele desbloqueia)
			# -- o mesmo texto serve a Transcendencia sem um segundo mecanismo.
			var access := capstone_victory_label(node)
			var headline := ("Acesso à %s desbloqueado." % access) if completed else ("Desbloqueia o acesso à %s." % access)
			var condition := CAPSTONE_TERRITORIAL_NOTE if node.tree_type == V2ResearchNode.TreeType.MILITARY_DOCTRINE else CAPSTONE_TRANSCENDENCE_NOTE
			return "%s\n\n%s" % [headline, condition]
		"school":
			return "Desbloqueia a %s. Marco da Escola: abre a pesquisa do prédio da Escola, sem bônus passivo." % node.display_name
		"school_building":
			var caster_name := ""
			for candidate in nodes_for_branch(node.tree_type, node.branch):
				if candidate.tier_role == "caster":
					caster_name = candidate.display_name
			return "Desbloqueia %s. Treina %s depois da pesquisa correspondente. Manutenção: %d Ouro/turno." % [node.display_name, caster_name, int(_building_upkeep(node.unlock_id))]
		"caster":
			var school_building := ""
			for candidate in nodes_for_branch(node.tree_type, node.branch):
				if candidate.tier_role == "school_building":
					school_building = candidate.display_name
			var data := UnitDatabase.create_unit(node.unlock_id)
			var caster_text := "Desbloqueia %s, conjurador %s. Requer %s para treinamento. Consome %d Suprimentos." % [node.display_name, branch_info(node.tree_type, node.branch).get("genitive", ""), school_building, data.supply_cost]
			if not data.can_basic_attack:
				caster_text += " Sem ataque básico: conhece os feitiços que a civilização pesquisar."
			if data.is_retinue_commander(): # Fase 19: capacidade de comando de retinues, por dado
				caster_text += " Concede +%d de capacidade de %s." % [data.retinue_command_capacity, V2MagicContent.command_label(data.v2_magic_school)]
			return caster_text
		"spell":
			var spell := V2SpellDatabase.get_spell(node.unlock_id)
			return "Novo feitiço para os conjuradores %s. %s" % [branch_info(node.tree_type, node.branch).get("genitive", ""), V2SpellDatabase.effect_text(spell) if spell != null else ""]
		"ritual_building":
			var temple := ""
			var manifestation := ""
			for candidate in nodes_for_branch(node.tree_type, node.branch):
				if candidate.tier_role == "school_building":
					temple = candidate.display_name
				elif candidate.tier_role == "grand_manifestation":
					manifestation = candidate.display_name
			return "Desbloqueia %s. Requer %s na mesma cidade e permite produzir %s após sua pesquisa. Manutenção: %d Ouro/turno." % [node.display_name, temple, manifestation, int(_building_upkeep(node.unlock_id))]
		"grand_manifestation":
			var ritual := ""
			for candidate in nodes_for_branch(node.tree_type, node.branch):
				if candidate.tier_role == "ritual_structure":
					ritual = candidate.display_name
			var manifestation_data := UnitDatabase.create_unit(node.unlock_id)
			var manifestation_text := "Desbloqueia %s, a Grande Manifestação da Escola. Produzido em %s: %d PP + %d Mana (a Mana é cobrada na conclusão). Uma por Escola, ativa ou em produção." % [node.display_name, ritual, int(manifestation_data.production_cost), int(manifestation_data.production_mana_cost)]
			if manifestation_data.is_retinue_commander() and manifestation_data.retinue_command_capacity_name != "": # Fase 19, por dado
				manifestation_text += " Passiva — %s: concede +%d de capacidade de %s." % [manifestation_data.retinue_command_capacity_name, manifestation_data.retinue_command_capacity, V2MagicContent.command_label(manifestation_data.v2_magic_school)]
			return manifestation_text
		"city_level":
			# Fase 13: a pesquisa só PERMITE o nível -- cada cidade continua precisando produzir
			# o próprio projeto local (City.gd, V2CityLevelData) pra de fato subir (§1/§9/§19).
			# Fase 16: a MESMA pesquisa também libera um nível de Fortificação (segundo efeito,
			# derivado de V2FortificationData — nunca um nó novo).
			return "Desbloqueia %s. Cada cidade precisa produzir seu próprio projeto de desenvolvimento urbano." % urbanization_unlock_label(node.unlock_id)
	return ""

## Fase 14 — texto dinâmico do efeito de N1 (`unlock_type = "building"`) e N2/N3
## (`"infrastructure_upgrade"`) das cinco linhas econômicas de Infraestrutura. Dirigido por
## V2InfrastructureEconomyData (id do prédio, resource kind, yield por posição na linha), nunca um
## texto fixo por nó/id (§128 do pedido). `tier` aqui é a POSIÇÃO do nó na linha (1/2/3) — o texto
## descreve o que ESTE nó desbloqueia, não o tier de pesquisa atual do jogador (ver
## V2EconomyRuntime.infrastructure_tier, usado pelo runtime real).
static func _infrastructure_economy_effect_text(branch: String, unlock_id: String) -> String:
	var pair := V2InfrastructureEconomyData.branch_and_tier_for_unlock(unlock_id)
	var tier: int = pair[1]
	if tier == 0:
		return ""
	var building_id := V2InfrastructureEconomyData.building_id_for_branch(branch)
	var building: BuildingData = BuildingDatabase.get_building(building_id)
	var building_name: String = building.display_name if building else ""
	var building_plural := V2InfrastructureEconomyData.building_name_plural(branch)
	var resource := V2InfrastructureEconomyData.resource_for_building(building_id)
	var amount := int(V2InfrastructureEconomyData.yield_per_copy(building_id, tier))
	var resource_label := V2InfrastructureEconomyData.resource_label(resource)
	var sentence := ""
	match resource:
		"supply":
			sentence = "Cada %s fornece +%d de %s." % [building_name, amount, resource_label] if tier == 1 \
				else "%s passam a fornecer +%d de %s." % [building_plural, amount, resource_label]
		"production":
			sentence = "Cada %s adiciona %d Produção à cidade." % [building_name, amount] if tier == 1 \
				else "%s passam a adicionar %d Produção local por turno." % [building_plural, amount]
		_:
			sentence = "Cada %s produz %d %s por turno." % [building_name, amount, resource_label] if tier == 1 \
				else "%s passam a produzir %d %s por turno." % [building_plural, amount, resource_label]
	var text := ("Desbloqueia %s. %s" % [building_name, sentence]) if tier == 1 else sentence
	if branch == "logistics":
		text += " Suprimentos são capacidade logística, não estoque: unidades militares consomem essa capacidade."
	return text

static func _building_upkeep(building_id: String) -> float:
	var building: BuildingData = BuildingDatabase.get_building(building_id)
	return building.gold_upkeep if building != null else 0.0

## "Cidade II e Muralhas I" — o nível urbano e a Fortificação que a mesma pesquisa de Urbanização
## libera (Fase 16). Usado pelo tooltip e pelo toast (V2UnlockSystem).
static func urbanization_unlock_label(unlock_id: String) -> String:
	var level_name := V2CityLevelData.level_name_for_unlock(unlock_id)
	var fortification := V2FortificationData.level_for_research_unlock(unlock_id)
	return level_name if fortification == 0 else "%s e %s" % [level_name, V2FortificationData.display_name(fortification)]

## "Supremacia Militar" (Doutrinas) / "Transcendencia" (Magia): a via de vitoria que
## o capstone universal de `node.tree_type` desbloqueia -- nunca o nome do proprio no
## de pesquisa. Ver CAPSTONE_VICTORY_LABELS.
static func capstone_victory_label(node: V2ResearchNode) -> String:
	return CAPSTONE_VICTORY_LABELS.get(node.tree_type, node.display_name)

## "Escudeiro → Guardião → Sentinela", com a posição de `node` marcada por [ ].
static func _evolution_chain_text(node: V2ResearchNode) -> String:
	var chain: Array[String] = []
	for candidate in unit_line(node.branch):
		var label := candidate.display_name
		chain.append("[%s]" % label if candidate == node else label)
	return " → ".join(chain)

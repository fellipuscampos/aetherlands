extends GutTest

## Roadmap "Parte C" (composicao de exercito), fatia C1 — papeis DERIVADOS
## (ArmyComposition.gd) das propriedades que UnitData ja expoe, sem
## taxonomia nova. Cobre so ArmyComposition.roles_for_kind aqui; o uso em
## RivalAI._role_counts/_role_gap_bonus fica em test_rival_ai.gd.

func test_settler_has_no_role():
	assert_eq(ArmyComposition.roles_for_kind("settler"), [] as Array[String])

func test_unknown_kind_has_no_role():
	assert_eq(ArmyComposition.roles_for_kind("dragon"), [] as Array[String])

func test_building_id_has_no_role():
	# regressao: UnitDatabase.create_unit() nao tem clausula "_:" no match,
	# entao um kind desconhecido (aqui, um id de PREDIO real, que aparece
	# na mesma lista de candidatos que RivalAI._production_candidates monta)
	# devolveria silenciosamente os defaults de @export (attack=1.0,
	# attack_range=1) se roles_for_kind nao filtrasse por
	# PLAYER_TRAINABLE_KINDS antes de chamar create_unit.
	assert_eq(ArmyComposition.roles_for_kind("walls"), [] as Array[String])
	assert_eq(ArmyComposition.roles_for_kind("barracks"), [] as Array[String])

func test_melee_only_kinds():
	var melee_only := ["warrior", "men_at_arms", "treant", "stone_golem", "dwarf_axeguard", "orc_berserker"]
	for kind in melee_only:
		assert_eq(ArmyComposition.roles_for_kind(kind), [ArmyComposition.ROLE_MELEE] as Array[String], kind)

func test_ranged_only_kinds():
	var ranged_only := ["archer", "mage", "shadow_summoner"]
	for kind in ranged_only:
		assert_eq(ArmyComposition.roles_for_kind(kind), [ArmyComposition.ROLE_RANGED] as Array[String], kind)

func test_melee_cavalry_kinds():
	var melee_cavalry := ["cavalry", "scout", "griffin", "human_knight"]
	for kind in melee_cavalry:
		assert_eq(ArmyComposition.roles_for_kind(kind), [ArmyComposition.ROLE_MELEE, ArmyComposition.ROLE_CAVALRY] as Array[String], kind)

func test_catapult_is_ranged_and_siege():
	assert_eq(ArmyComposition.roles_for_kind("catapult"), [ArmyComposition.ROLE_RANGED, ArmyComposition.ROLE_SIEGE] as Array[String])

func test_elf_ranger_is_ranged_and_cavalry():
	# movement_points=3.0 > BASELINE_MOVEMENT_POINTS=2.0 -- regra de
	# mobilidade aplicada de forma uniforme, mesmo elf_ranger sendo a
	# distancia: nao ha excecao especial "unidade a distancia nunca e
	# cavalaria" no modelo.
	assert_eq(ArmyComposition.roles_for_kind("elf_ranger"), [ArmyComposition.ROLE_RANGED, ArmyComposition.ROLE_CAVALRY] as Array[String])

## Roadmap "arvore de 10 niveis" — cerco deixou de ser so a Catapulta:
## Balista/Ariete/Torre de Cerco/Trebuchet (via siege_workshop) e Bombarda/
## Colosso de Cerco (via grand_arsenal, ver ArmyComposition.roles_for_kind)
## tambem ganham ROLE_SIEGE agora.
const SIEGE_KINDS := ["catapult", "balista", "ariete", "torre_de_cerco", "trebuchet", "bombarda", "colosso_de_cerco"]

func test_only_catapult_has_siege_role():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if kind in SIEGE_KINDS:
			continue
		assert_false(ArmyComposition.ROLE_SIEGE in ArmyComposition.roles_for_kind(kind), kind)

func test_siege_kinds_all_have_the_siege_role():
	for kind in SIEGE_KINDS:
		assert_true(ArmyComposition.ROLE_SIEGE in ArmyComposition.roles_for_kind(kind), kind)

## Roadmap "arvore de 10 niveis" — Mercador/Engenheiro de Cerco/General sao
## unidades de SUPORTE de proposito (attack 0.0, mesmo padrao do
## Colonizador) — ainda sem tropa nenhuma pra defender, so utilidade.
const NON_COMBAT_KINDS := ["settler", "mercador", "engenheiro_de_cerco", "general"]

func test_every_trainable_combat_kind_has_at_least_one_role():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if kind in NON_COMBAT_KINDS:
			continue
		assert_gt(ArmyComposition.roles_for_kind(kind).size(), 0, kind)

func test_non_combat_kinds_have_no_role():
	for kind in NON_COMBAT_KINDS:
		assert_eq(ArmyComposition.roles_for_kind(kind), [] as Array[String], kind)

## Cobertura de papel das 21 unidades novas da arvore de 10 niveis —
## confirma que cada uma cai no papel descrito no desenho original.
func test_new_melee_only_kinds():
	var melee_only := ["lanceiro", "espadachim", "homem_de_escudo", "halberdier", "campeao", "campeao_do_reino"]
	for kind in melee_only:
		assert_eq(ArmyComposition.roles_for_kind(kind), [ArmyComposition.ROLE_MELEE] as Array[String], kind)

func test_new_ranged_only_kinds():
	assert_eq(ArmyComposition.roles_for_kind("besteiro"), [ArmyComposition.ROLE_RANGED] as Array[String])

func test_new_melee_cavalry_kinds():
	var melee_cavalry := ["batedor_montado", "cavaleiro_pesado", "cavaleiro_de_choque", "cavalaria_blindada", "cavaleiro_imperial"]
	for kind in melee_cavalry:
		assert_eq(ArmyComposition.roles_for_kind(kind), [ArmyComposition.ROLE_MELEE, ArmyComposition.ROLE_CAVALRY] as Array[String], kind)

func test_new_ranged_siege_kinds():
	var ranged_siege := ["balista", "trebuchet", "bombarda", "colosso_de_cerco"]
	for kind in ranged_siege:
		assert_eq(ArmyComposition.roles_for_kind(kind), [ArmyComposition.ROLE_RANGED, ArmyComposition.ROLE_SIEGE] as Array[String], kind)

func test_new_melee_siege_kinds():
	var melee_siege := ["ariete", "torre_de_cerco"]
	for kind in melee_siege:
		assert_eq(ArmyComposition.roles_for_kind(kind), [ArmyComposition.ROLE_MELEE, ArmyComposition.ROLE_SIEGE] as Array[String], kind)

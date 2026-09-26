extends GutTest

## Roadmap "Parte C" (composicao de exercito), fatia C1 — papeis DERIVADOS
## (ArmyComposition.gd) das propriedades que UnitData ja expoe, sem
## taxonomia nova. Fase 25: unidade de Doutrina V2 pelo branch_role da
## Doutrina; unidade legada (fora das Doutrinas) por alcance + TRACOS do dado
## (montado/voo -> cavalaria, cerco -> cerco), nunca mais por movimento.

func test_settler_has_no_role():
	assert_eq(ArmyComposition.roles_for_kind("settler"), [] as Array[String])

func test_unknown_kind_has_no_role():
	assert_eq(ArmyComposition.roles_for_kind("dragon"), [] as Array[String])

func test_building_id_has_no_role():
	# regressao: UnitDatabase.create_unit() devolve os defaults de @export
	# (attack=1.0) pra um kind desconhecido -- roles_for_kind filtra por
	# UnitDatabase.is_known_kind antes de classificar.
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
	var melee_cavalry := ["cavalry", "griffin", "human_knight"]
	for kind in melee_cavalry:
		assert_eq(ArmyComposition.roles_for_kind(kind), [ArmyComposition.ROLE_MELEE, ArmyComposition.ROLE_CAVALRY] as Array[String], kind)

func test_catapult_is_ranged_and_siege():
	assert_eq(ArmyComposition.roles_for_kind("catapult"), [ArmyComposition.ROLE_RANGED, ArmyComposition.ROLE_SIEGE] as Array[String])

## Fase 25: movimento alto sozinho nao faz cavalaria (Batedor/Patrulheiro Elfico legados
## nao tem o traco montado).
func test_fast_legacy_units_without_the_mounted_trait_are_not_cavalry():
	assert_eq(ArmyComposition.roles_for_kind("scout"), [ArmyComposition.ROLE_MELEE] as Array[String])
	assert_eq(ArmyComposition.roles_for_kind("elf_ranger"), [ArmyComposition.ROLE_RANGED] as Array[String])

## Roadmap "arvore de 10 niveis" — cerco deixou de ser so a Catapulta:
## Balista/Ariete/Torre de Cerco/Trebuchet (via siege_workshop) e Bombarda/
## Colosso de Cerco (via grand_arsenal, ver ArmyComposition.roles_for_kind)
## tambem ganham ROLE_SIEGE agora.
const SIEGE_KINDS := ["catapult", "balista", "ariete", "torre_de_cerco", "trebuchet", "bombarda", "colosso_de_cerco"]

## Fase 25: no roster produzivel, so a Doutrina de Cerco (city_conquest) tem papel de cerco.
func test_only_the_siege_doctrine_has_the_siege_role_in_the_trainable_roster():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		var is_siege_line := V2UnitLine.role_of(kind) == "city_conquest"
		assert_eq(ArmyComposition.ROLE_SIEGE in ArmyComposition.roles_for_kind(kind), is_siege_line, kind)

func test_siege_kinds_all_have_the_siege_role():
	for kind in SIEGE_KINDS:
		assert_true(ArmyComposition.ROLE_SIEGE in ArmyComposition.roles_for_kind(kind), kind)

## Roadmap "arvore de 10 niveis" — Mercador/Engenheiro de Cerco/General sao
## unidades de SUPORTE de proposito (attack 0.0, mesmo padrao do
## Colonizador) — ainda sem tropa nenhuma pra defender, so utilidade.
## Aetherlands V2, Fase 15 — o Construtor (v2_unit_builder) é civil, como o Colonizador: sem
## composição militar/papel de combate (§53 do pedido).
## Aetherlands V2, Fases 17–22 — conjuradores V2 SEM ataque básico não entram na composição de ataque físico.
const NON_COMBAT_KINDS := ["settler", "mercador", "engenheiro_de_cerco", "general", "v2_unit_builder", "v2_unit_sacred_cleric", "v2_manifestation_seraph", "v2_unit_infernal_warlock", "v2_manifestation_archdemon", "v2_unit_necromancer", "v2_manifestation_lich_sovereign", "v2_unit_druid", "v2_manifestation_nature_avatar", "v2_unit_arcanist", "v2_manifestation_veil_archon", "v2_unit_elementalist", "v2_manifestation_elemental_primordial"]

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

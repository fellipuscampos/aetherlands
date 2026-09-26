extends GutTest

## Cobre UnitDatabase.PLAYER_TRAINABLE_KINDS (roster que a HUD usa pra montar os botoes de producao)
## e a criacao de unidades legadas que ainda podem vir de saves antigos.
##
## Fase 25: nao existe mais linha de producao V1 (tropa racial exclusiva, Golem/Convocador por tech
## V1) -- o roster produzivel e' o Colonizador + o elenco V2 (Doutrinas, Escolas, Construtor).

func test_player_trainable_kinds_is_the_settler_plus_v2_only():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		assert_true(kind in UnitDatabase.CORE_TRAINABLE_KINDS or V2ResearchDatabase.is_v2_id(kind), kind)
	assert_eq(UnitDatabase.CORE_TRAINABLE_KINDS, ["settler"] as Array[String])

func test_v1_troops_are_no_longer_producible():
	for kind in ["warrior", "archer", "men_at_arms", "cavalry", "catapult", "mage", "stone_golem", "shadow_summoner", "human_knight", "dwarf_axeguard", "orc_berserker", "elf_ranger", "mercador"]:
		assert_false(kind in UnitDatabase.PLAYER_TRAINABLE_KINDS, kind)

func test_legacy_kinds_from_old_saves_are_still_known():
	for kind in ["warrior", "human_knight", "shadow_summoner", "catapult"]:
		assert_true(UnitDatabase.is_known_kind(kind), kind)
	assert_false(UnitDatabase.is_known_kind("nao_existe"))

func test_player_trainable_kinds_has_no_duplicates():
	var seen := []
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		assert_false(kind in seen, "%s apareceu duplicado no roster" % kind)
		seen.append(kind)

func test_create_unit_shadow_summoner_is_a_ranged_caster():
	var summoner = UnitDatabase.create_unit("shadow_summoner")
	assert_eq(summoner.unit_name, "Convocador de Sombras")
	assert_eq(summoner.attack_range, 2)
	assert_true(summoner.ignores_terrain_defense, "conjurador deveria ignorar fortificacao, mesmo padrao do Mago")

func test_create_unit_human_knight_exists_and_is_melee():
	var knight = UnitDatabase.create_unit("human_knight")
	assert_eq(knight.unit_name, "Cavaleiro Real")
	assert_eq(knight.attack_range, 1, "Cavaleiro Real e corpo-a-corpo (1 = sem alcance a distancia)")
	assert_false(knight.can_found_city)

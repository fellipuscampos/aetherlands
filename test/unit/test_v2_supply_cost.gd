extends GutTest

## Aetherlands V2, Fase 15 — cobertura de UnitData.supply_cost: o DADO puro que toda a
## Logística (V2LogisticsRuntime) deriva. Cobre as 24 formas militares V2 (N3/N5/N7/N9 das seis
## Doutrinas: 1/2/3/5), o Construtor e o Colonizador (0, civis) e uma amostra de unidades V1
## (0, herança automática do valor padrão de UnitData — nenhuma delas participa da Fase 15).

const DOCTRINE_FORMS := {
	"guardian": ["v2_unit_shieldbearer", "v2_unit_guardian", "v2_unit_sentinel", "v2_legendary_guardian_champion"],
	"warrior": ["v2_unit_warrior", "v2_unit_swordsman", "v2_unit_weapon_master", "v2_legendary_blade_hero"],
	"ranger": ["v2_unit_archer", "v2_unit_hunter", "v2_unit_elite_marksman", "v2_legendary_legend_hunter"],
	"cavalry": ["v2_unit_cavalier", "v2_unit_shock_cavalier", "v2_unit_armored_cavalier", "v2_legendary_griffon_rider"],
	"rogue": ["v2_unit_rogue", "v2_unit_saboteur", "v2_unit_assassin", "v2_legendary_shadow_master"],
	"siege": ["v2_unit_catapult", "v2_unit_trebuchet", "v2_unit_bombard", "v2_legendary_siege_colossus"],
}
## N3/N5/N7/N9(Lendária) na mesma ordem de DOCTRINE_FORMS acima, em todas as seis Doutrinas.
const EXPECTED_COSTS_BY_TIER := [1, 2, 3, 5]

func test_all_24_v2_military_units_have_the_correct_supply_cost_by_tier():
	for doctrine in DOCTRINE_FORMS:
		var forms: Array = DOCTRINE_FORMS[doctrine]
		for i in forms.size():
			var kind: String = forms[i]
			var data := UnitDatabase.create_unit(kind)
			assert_eq(data.supply_cost, EXPECTED_COSTS_BY_TIER[i], "%s (%s)" % [kind, doctrine])

func test_exactly_24_military_kinds_declare_a_positive_supply_cost():
	var positive := 0
	for doctrine in DOCTRINE_FORMS:
		for kind in DOCTRINE_FORMS[doctrine]:
			if UnitDatabase.create_unit(kind).supply_cost > 0:
				positive += 1
	assert_eq(positive, 24)

func test_the_builder_and_the_settler_have_zero_supply_cost():
	assert_eq(UnitDatabase.create_unit("v2_unit_builder").supply_cost, 0, "Construtor é civil")
	assert_eq(UnitDatabase.create_unit("settler").supply_cost, 0, "Colonizador é civil")

## Amostra de conteúdo V1 (nunca tocado pela Fase 15) — o padrão de UnitData.supply_cost (0) se
## aplica sem nenhuma linha extra em UnitDatabase pra cada um.
func test_a_sample_of_v1_units_default_to_zero_supply_cost():
	for kind in ["warrior", "archer", "human_knight", "catapult", "homem_de_escudo", "lanceiro"]:
		var data := UnitDatabase.create_unit(kind)
		assert_not_null(data, kind)
		assert_eq(data.supply_cost, 0, kind)

func test_supply_cost_default_lives_on_unit_data_not_hardcoded_elsewhere():
	assert_eq(UnitData.new().supply_cost, 0)

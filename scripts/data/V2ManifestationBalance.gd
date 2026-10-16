class_name V2ManifestationBalance
extends RefCounted

## N9 bound entities: production tempo and mortal mages stay unchanged.
## Upfront Mana funds ordinary spells; permanent armies still pay normal Mana.
const PROFILES := {
	"sacred": {"hp":50.0, "attack":12.0, "range":2, "mana":120.0},
	"infernal": {"hp":50.0, "attack":15.0, "range":2, "mana":140.0},
	"necromancy": {"hp":46.0, "attack":12.0, "range":2, "mana":130.0},
	"druidism": {"hp":60.0, "attack":16.0, "range":1, "mana":130.0},
	"arcanism": {"hp":46.0, "attack":13.0, "range":2, "mana":140.0},
	"elementalism": {"hp":54.0, "attack":14.0, "range":2, "mana":150.0},
}
const LEGACY_HP := {"sacred":38.0, "infernal":36.0, "necromancy":34.0, "druidism":42.0, "arcanism":34.0, "elementalism":40.0}

static func restored_hp(unit: Unit, saved_hp: float, profile_version: int) -> float:
	if not V2ManifestationSystem.is_manifestation_unit(unit) or profile_version >= 1:
		return saved_hp
	return unit.unit_data.max_hp * clampf(saved_hp / float(LEGACY_HP.get(unit.unit_data.v2_magic_school, unit.unit_data.max_hp)),0.0,1.0)

static func apply(data: UnitData) -> void:
	if not data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION):
		return
	var profile: Dictionary = PROFILES.get(data.v2_magic_school, {})
	if profile.is_empty():
		return
	data.max_hp = profile.hp
	data.attack = profile.attack
	data.attack_range = profile.range
	data.can_basic_attack = true
	data.production_mana_cost = profile.mana

static func mana_cost(unit: Unit, spell: V2SpellData) -> float:
	if V2ManifestationSystem.is_manifestation_unit(unit) and not spell.is_summon():
		return 0.0
	return spell.mana_cost

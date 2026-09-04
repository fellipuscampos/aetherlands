class_name ArmyComposition
extends RefCounted

const ROLE_MELEE := "melee"
const ROLE_RANGED := "ranged"
const ROLE_CAVALRY := "cavalry"
const ROLE_SIEGE := "siege"
const ROLES := [ROLE_MELEE, ROLE_RANGED, ROLE_CAVALRY, ROLE_SIEGE]
const BASELINE_MOVEMENT_POINTS := 2.0 # modal entre os 16 kinds treinaveis (UnitDatabase) -- acima disso conta como "mobilidade"

## Deriva papeis puramente das propriedades que UnitData ja expoe -- sem
## taxonomia nova. Settler (attack=0) e qualquer kind fora de
## PLAYER_TRAINABLE_KINDS (inclusive ids de predio, que aparecem na mesma
## lista de candidatos de RivalAI._production_candidates) devolvem [].
## Guarda contra o match sem clausula "_:" em UnitDatabase.create_unit --
## chamar com kind desconhecido NAO da erro, so devolve defaults de
## @export (attack=1.0, attack_range=1), o que classificaria errado um id
## de predio como unidade corpo-a-corpo se nao filtrasse antes.
static func roles_for_kind(kind: String) -> Array[String]:
	var roles: Array[String] = []
	if not (kind in UnitDatabase.PLAYER_TRAINABLE_KINDS):
		return roles
	var data: UnitData = UnitDatabase.create_unit(kind)
	if data.attack <= 0.0:
		return roles
	if data.attack_range <= 1:
		roles.append(ROLE_MELEE)
	else:
		roles.append(ROLE_RANGED)
	if data.movement_points > BASELINE_MOVEMENT_POINTS or data.flies:
		roles.append(ROLE_CAVALRY)
	var trainer: BuildingData = BuildingDatabase.building_that_trains(kind)
	if trainer != null and trainer.id == "siege_workshop":
		roles.append(ROLE_SIEGE)
	return roles

class_name ArmyComposition
extends RefCounted

## Papéis de combate genéricos (corpo a corpo / à distância / mobilidade / cerco), usados pela escolha
## de alvo de guerra da IA (RivalAI._role_counts/_role_fit_bonus) e como rótulo de fallback no
## inspetor. Uma unidade pode ter mais de um papel.
##
## Fase 25: unidade da progressão (Doutrina V2) é classificada pela identidade semântica da PRÓPRIA
## Doutrina (V2UnitLine.role_of -> branch_role), nunca por movimento/alcance/prédio de treino — a
## heurística V1 (que chamava o Ladino de cavalaria e não reconhecia o Cerco V2) não se aplica mais a
## ela. A heurística só sobra como fallback para unidades fora das Doutrinas (unidades legadas de saves
## antigos, o Guarda inicial), agora pelos TRAÇOS do dado (`mounted`/`siege`), nunca por id de prédio.

const ROLE_MELEE := "melee"
const ROLE_RANGED := "ranged"
const ROLE_CAVALRY := "cavalry"
const ROLE_SIEGE := "siege"
const ROLES := [ROLE_MELEE, ROLE_RANGED, ROLE_CAVALRY, ROLE_SIEGE]

## branch_role canônico da Doutrina (V2ResearchDatabase) -> papéis genéricos.
const ROLES_BY_BRANCH_ROLE := {
	"tank_frontline": [ROLE_MELEE],
	"melee_damage": [ROLE_MELEE],
	"ranged_combat": [ROLE_RANGED],
	"mobility_shock": [ROLE_MELEE, ROLE_CAVALRY],
	"sabotage_assassination": [ROLE_MELEE],
	"city_conquest": [ROLE_RANGED, ROLE_SIEGE],
}

static func roles_for_kind(kind: String) -> Array[String]:
	var roles: Array[String] = []
	var branch_role := V2UnitLine.role_of(kind)
	if branch_role != "":
		for role in ROLES_BY_BRANCH_ROLE.get(branch_role, []):
			roles.append(role)
		return roles
	if kind == "" or V2ResearchDatabase.is_v2_id(kind) or not UnitDatabase.is_known_kind(kind):
		return roles # conjuradores, Manifestações, Hostes, Construtor, ids de prédio/desconhecidos: sem papel
	var data: UnitData = UnitDatabase.create_unit(kind)
	if data.attack <= 0.0 or not data.can_basic_attack:
		return roles
	roles.append(ROLE_MELEE if data.attack_range <= 1 else ROLE_RANGED)
	if data.has_trait(UnitData.TRAIT_MOUNTED) or data.flies:
		roles.append(ROLE_CAVALRY)
	if data.has_trait(UnitData.TRAIT_SIEGE):
		roles.append(ROLE_SIEGE)
	return roles

class_name V2SpellData
extends Resource

## Um FEITIÇO V2 (Aetherlands V2, Fase 17) — irmão de V2DoctrineTechniqueData, mas outro conceito: feitiço
## custa MANA e pertence a uma ESCOLA (quem o conhece é o conjurador cuja UnitData.v2_magic_school bate e cujo
## dono pesquisou o nó); Técnica Militar não tem Mana e pertence a uma linha de Doutrina. Os dois nunca se
## misturam (V2MagicRuntime x V2TechniqueRuntime).
##
## Só os campos que as Escolas implementadas precisam; todo campo tem default inerte.

## Quem o feitiço pode mirar. A regra diplomática de HOSTILE_UNIT vem de
## CombatResolver.is_hostile_unit_target, sem depender de ataque básico. EMPTY_TILE (Fase 19): um tile VAZIO,
## visível, ao alcance e legal para o que o feitiço cria (V2MagicRuntime.tile_reason) — genérico para invocação
## hoje e para efeitos de tile futuros. TILE (Fase 20): qualquer tile existente, visível e ao alcance — MESMO com
## unidade em cima, e o próprio tile do conjurador incluído (alcance 0..N); o resto é requisito do próprio feitiço.
enum TargetMode { OWN_UNIT, HOSTILE_UNIT, EMPTY_TILE, TILE }
enum StatusPolarity { NONE, BENEFICIAL, HARMFUL }

@export var id: String = ""                 # == unlock_id do nó de pesquisa (v2_spell_*)
@export var school_branch: String = ""      # Escola dona (== UnitData.v2_magic_school do conjurador)
@export var mana_cost: float = 0.0
@export var cooldown_turns: int = 0         # 0 = sem recarga
@export var target_mode: TargetMode = TargetMode.OWN_UNIT
@export var cast_range: int = 1             # distância hex máxima do conjurador ao alvo primário
@export var consumes_action: bool = true    # conjurar zera o movimento restante

# --- Efeitos (defaults inertes) -----------------------------------------------------------------
@export var heal_amount: float = 0.0        # cura fixa por alvo afetado
@export var heal_to_full: bool = false      # restaura ao máximo de Vida
@export var splash_radius: int = 0          # 0 = só o alvo; N = também as unidades próprias a até N tiles do alvo
@export var defense_bonus: float = 0.0      # +X de Defesa enquanto o estado durar (fator de CombatResolver.predict)
@export var duration: int = 0               # 0 = instantâneo; 1 = até o início do próximo turno do dono
@export var damage_amount: float = 0.0      # dano mágico fixo; ignora Defesa física
@export var low_hp_threshold: float = 0.0   # fração de HP máximo; 0 = sem condição
@export var low_hp_damage_bonus: float = 0.0 # 0.5 = +50% quando no limiar ou abaixo
# --- Fase 19 (Necromancia) — extensões mínimas, genéricas -----------------------------------------
@export var required_target_trait: String = "" # OWN_UNIT: o alvo (e a área) precisa ter este UnitData.traits; "" = qualquer
@export var summon_unit_id: String = ""     # EMPTY_TILE: o kind (UnitDatabase) que nasce no tile; o custo de comando vem do UnitData dele
@export var attack_bonus: float = 0.0       # +X de Ataque enquanto o estado durar (V2MagicRuntime.attack_multiplier)
# --- Fase 21 (Arcanismo) — mobilidade/interferência mágicas genéricas -----------------------------
@export var teleport_caster: bool = false   # EMPTY_TILE: reposiciona diretamente o próprio conjurador
@export var requires_v2_caster_target: bool = false # HOSTILE_UNIT: participa do runtime V2, não apenas do trait público
@export var status_polarity: StatusPolarity = StatusPolarity.NONE
@export var status_dispellable: bool = false
@export var silences_spellcasting: bool = false
@export var dispel_at_tile: bool = false     # TILE: remove status elegíveis e efeito mágico de mapa elegível
@export var creates_portal_pair: bool = false # EMPTY_TILE: origem no caster + endpoint no alvo, persistente no mapa
# --- Fase 22 (Elementalismo) — condição ambiental temporária, separada do terreno -----------------
@export var environmental_zone_id: String = "" # TILE: cria esta zona no alvo e na área `splash_radius`
# --- Fase 20 (Druidismo) — terreno físico persistente, genérico (V2TerrainRuntime) -------------------------
@export var terrain_modification_id: String = ""          # cria esta modificação no alvo (e na área `splash_radius`, onde elegível)
@export var remove_terrain_modification: bool = false      # remove a modificação física do tile alvo
@export var requires_existing_terrain_modification: bool = false # o tile alvo precisa já ter uma modificação

## O nome exibido vem do nó de pesquisa (fonte única do nome canônico, V2MagicContent).
var display_name: String:
	get:
		var node := V2ResearchDatabase.node_for_unlock_id(id)
		return node.display_name if node != null else id

func is_heal() -> bool:
	return heal_amount > 0.0 or heal_to_full

func is_buff() -> bool:
	return (defense_bonus > 0.0 or attack_bonus > 0.0) and duration > 0

func applies_status() -> bool:
	return duration > 0 and (is_buff() or silences_spellcasting)

func is_summon() -> bool:
	return summon_unit_id != ""

## Feitiço que mexe na camada física de terreno (cria ou remove modificação)?
func is_terrain_spell() -> bool:
	return terrain_modification_id != "" or remove_terrain_modification

## Mira em tile (EMPTY_TILE ou TILE), nunca em unidade?
func targets_tile() -> bool:
	return target_mode == TargetMode.EMPTY_TILE or target_mode == TargetMode.TILE

func is_damage() -> bool:
	return damage_amount > 0.0

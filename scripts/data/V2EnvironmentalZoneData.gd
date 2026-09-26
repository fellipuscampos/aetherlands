class_name V2EnvironmentalZoneData
extends Resource

## Condição ambiental temporária aplicada a um tile. O dado descreve efeitos
## concretos; não existe hierarquia de elementos, resistências ou status na Unit.
@export var id: String = ""
@export var display_name: String = ""
@export var duration_rounds: int = 0
@export var vision_delta: int = 0
@export var physical_ranged_attack_multiplier: float = 1.0
@export var round_tick_magic_damage: float = 0.0
@export var dispellable: bool = true
@export var visual_kind: String = ""

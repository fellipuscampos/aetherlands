class_name BuildingData
extends Resource

## Um predio de cidade. Recurso puro de dados (igual TechData/UnitData) —
## quem interpreta isto e BuildingDatabase (consultas) e City/CombatResolver
## (aplicacao dos efeitos).

@export var id: String = ""
@export var display_name: String = ""
@export var production_cost: float = 20.0

## Bonus PERMANENTE somado ao total da cidade (nao por tile, diferente de
## TechData) uma vez construido — ver City.collect_yields().
@export var bonus_food: int = 0
@export var bonus_production: int = 0
@export var bonus_gold: int = 0

## So Muralhas usa isso por enquanto: soma ao multiplicador de defesa de
## unidade guarnicionada na cidade, igual bonus de terreno — ver
## CombatResolver.predict().
@export var defense_bonus: float = 0.0

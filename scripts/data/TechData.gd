class_name TechData
extends Resource

## Um no da arvore de tecnologia. Recurso puro de dados (igual UnitData/
## CivilizationData) — quem interpreta isto e TechDatabase (consultas) e
## City.collect_yields/GameManager (aplicacao dos efeitos).

@export var id: String = ""
@export var display_name: String = ""
@export var cost: float = 30.0
@export var prerequisites: Array[String] = []

## "" = nao desbloqueia unidade nenhuma. Guerreiro e Colonizador sempre
## disponiveis desde o inicio (ver TechDatabase.is_unit_unlocked) — so
## Arqueiro/Cavaleiro dependem de tecnologia.
@export var unlocks_unit: String = ""

## Bonus de rendimento aplicado a QUALQUER tile destes biomas que a
## civilizacao estiver trabalhando, uma vez pesquisada — ver
## City.collect_yields() e TechDatabase.yield_bonus_for().
@export var bonus_terrain_types: Array[int] = []
@export var bonus_food: int = 0
@export var bonus_production: int = 0
@export var bonus_gold: int = 0

class_name UnitData
extends Resource

@export var unit_name: String = "Unidade"
@export var movement_points: float = 2.0
@export var attack: float = 1.0
@export var defense: float = 1.0
@export var attack_range: int = 1 # 1 = corpo-a-corpo, 2+ = a distancia (sem contra-ataque)
@export var max_hp: float = 10.0
@export var vision_range: int = 2
@export var can_found_city: bool = false
@export var visual_kind: String = "warrior"
@export var production_cost: float = 15.0
## Mago: ataque magico ignora o bonus de defesa de terreno E de predio
## (colinas/floresta/montanha, Muralhas) do defensor — nao protegem
## contra magia. Ver CombatResolver.predict().
@export var ignores_terrain_defense: bool = false

## So > 0 pra monstros neutros (MonsterDatabase) que guardam Covis de
## Monstro espalhados pelo mapa — quem derrotar o guardiao (Unit com
## owner_player == null) recebe esse ouro. Zero pra qualquer unidade de
## jogador. Ver CombatResolver.resolve().
@export var gold_reward: float = 0.0

## Grifo: ignora custo de terreno E atravessa oceano livremente (o resto do
## exercito precisa de estrada/costa) — ver HexGrid.compute_reachable().
@export var flies: bool = false

## Ent: cura essa fracao do HP maximo TODO turno, em qualquer lugar — nao
## precisa estar guarnicionado na propria cidade como o resto do exercito
## (GameManager._heal_if_garrisoned). Zero pra qualquer outra unidade. Ver
## GameManager._apply_regen().
@export var regen_fraction: float = 0.0

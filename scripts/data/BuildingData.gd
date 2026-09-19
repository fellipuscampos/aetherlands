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
@export var bonus_mana: int = 0

## Aumenta o TETO de armazenamento de comida da cidade (City.
## food_storage_cap()) uma vez construido — so o Celeiro usa isto por
## enquanto (pedido do usuario: redesenho do sistema de comida — cidade tem
## um limite de armazenamento por padrao, consumido por turno pela
## populacao, e o Celeiro aumenta esse limite em vez de so somar comida
## bruta). Diferente de bonus_food (soma comida BRUTA todo turno, ANTES do
## consumo), isso soma ao limite maximo que a cidade consegue guardar antes
## de crescer populacao — ver City.process_turn()/food_storage_cap().
@export var storage_bonus: float = 0.0

## So Muralhas usa isso por enquanto: soma ao multiplicador de defesa de
## unidade guarnicionada na cidade, igual bonus de terreno — ver
## CombatResolver.predict().
@export var defense_bonus: float = 0.0

## Kind de UnitDatabase que este predio libera pra treino (ex: "warrior" pro
## Quartel) — vazio pra predios de rendimento/defesa (Celeiro, Muralhas...),
## que nao travam producao de unidade nenhuma. Ver City.can_train() e
## BuildingDatabase.building_that_trains().
@export var trains_unit: String = ""

## Id de OUTRO BuildingData que precisa estar construido NESTA cidade antes
## deste poder ser construido (ex: "barracks" pro Estabulo) — vazio pra
## predio sem pre-requisito de construcao nenhum (a maioria). Independente
## do gate de TECNOLOGIA (ver TechDatabase.tech_that_unlocks/City.
## _tech_unlocked_for_building) — os dois podem se combinar (o Estabulo
## exige tanto o Quartel construido QUANTO a propria tech "Estabulo"
## pesquisada). Ver City.can_build().
@export var requires_building: String = ""
## Uma melhoria aproveita o terreno da estrutura anterior.
@export var upgrades_building: String = ""

## true so pra Muralhas por enquanto: em vez do fluxo normal de escolher um
## tile VIZINHO no mapa (SelectionManager.start_building_placement), a
## producao comeca na hora (mesmo fluxo de treinar uma unidade) e o efeito
## final e visual DENTRO da propria cidade (ver City._add_walls, acionado
## por City.buildings.has("walls")) — nao existe Building.gd separado
## posicionado em tile nenhum. Nao faz sentido escolher "onde" cercar uma
## cidade que so tem um tile pra chamar de seu.
@export var self_placed: bool = false

## Caminho de uma cena externa (.glb/.gltf, ex: KayKit) pra usar como visual
## deste predio EM VEZ da geometria procedural de Building.gd — pedido do
## usuario: "estude a questao de texturas e modelos 3d... pra gerar uma
## identidade visual coerente", depois de duas tentativas anteriores com
## pacotes prontos (Kenney/Quaternius) terem sido revertidas por destoar do
## resto do visual. "" (padrao) mantem o comportamento procedural de sempre
## — aditivo, nenhum predio existente quebra. Ver Building._build_visual().
@export var model_scene_path: String = ""

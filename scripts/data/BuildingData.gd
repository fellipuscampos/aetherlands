class_name BuildingData
extends Resource

## Um predio de cidade. Recurso puro de dados (igual UnitData) — quem
## interpreta isto e BuildingDatabase (consultas), City (fila/slots/gates) e
## V2EconomyRuntime (rendimento e manutenção dos prédios econômicos).
##
## Fase 25: os campos da economia V1 (bônus fixo de comida/produção/ouro/mana
## por prédio, armazenamento de comida, defesa por prédio, upgrade de prédio,
## auto-posicionamento das Muralhas e a flag de muralha vestigial) saíram junto
## com os prédios V1.

@export var id: String = ""
@export var display_name: String = ""
@export var production_cost: float = 20.0

## Kind de UnitDatabase que este predio libera pra treino — vazio pra prédio
## econômico/ritual sem tropa. Ver City.can_train() e
## BuildingDatabase.building_that_trains().
@export var trains_unit: String = ""

## Id de OUTRO BuildingData que precisa estar construido NESTA cidade antes
## deste poder ser construido (ex.: o Salão de uma Doutrina pro prédio de
## Maestria) — vazio pra predio sem pre-requisito. Combina com o gate de
## pesquisa (City._research_unlocked_for_building). Ver City.can_build().
@export var requires_building: String = ""

## Caminho de uma cena externa (.glb/.gltf, ex: KayKit) pra usar como visual
## deste predio EM VEZ da geometria procedural de Building.gd. "" mantém o
## visual procedural. Ver Building._build_visual().
@export var model_scene_path: String = ""

## Aetherlands V2, Fase 13 — quantas cópias do MESMO id uma cidade pode ter. UNIQUE (padrão) = no
## máximo 1 por cidade. CITY_LEVEL = o limite vem de V2CityLevelData.repeatable_building_limit(
## city.city_level), ver City.max_copies_for_building()/building_count()/can_build() — os cinco
## prédios econômicos (Fase 14).
enum CopyLimitMode { UNIQUE, CITY_LEVEL }
@export var copy_limit_mode: CopyLimitMode = CopyLimitMode.UNIQUE

## Aetherlands V2, Fase 15 — Ouro/turno que CADA cópia deste prédio custa, somado por
## V2EconomyRuntime.city_gold_upkeep/player_gold_upkeep. 0.0 no Mercado de propósito (rota de
## recuperação de um Déficit). Nunca lido por id concreto no runtime — é dado puro.
@export var gold_upkeep: float = 0.0

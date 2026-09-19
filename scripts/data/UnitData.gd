class_name UnitData
extends Resource

@export var magic_school: String = ""
@export var mana_upkeep: float = 0.0

@export var unit_name: String = "Unidade"
@export var movement_points: float = 2.0
@export var attack: float = 1.0
@export var defense: float = 1.0
@export var attack_range: int = 1 # 1 = corpo-a-corpo, 2+ = a distancia (sem contra-ataque)
@export var max_hp: float = 10.0
@export var vision_range: int = 3
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

## Caminho de uma cena externa (.glb/.gltf, ex: KayKit) pra usar como corpo
## desta unidade EM VEZ da geometria procedural de Unit.gd — mesmo motivo/
## historico de BuildingData.model_scene_path (ver comentario la). ""
## (padrao) mantem o corpo procedural de sempre. Ver Unit._build_procedural_
## body().
@export var model_scene_path: String = ""

## Caminho de uma cena externa (.glb) contendo clipes de animacao pro MESMO
## esqueleto de model_scene_path (KayKit Character Animations — nomes de
## osso identicos entre o pacote de personagens e o de animacoes, mesmo
## rig compartilhado) — "" (padrao) deixa a unidade em bind pose (sem
## animar). Ver Unit._build_model_body()/_play_default_animation().
@export var animation_scene_path: String = ""

## Multiplica a escala calculada em cima de MODEL_TARGET_HEIGHT (Unit.gd) —
## 1.0 (padrao) mantem o comportamento de sempre pra qualquer unidade
## baseada em model_scene_path. So existe pra dar um ajuste POR UNIDADE
## sem mexer na constante compartilhada (que afetaria todo mundo, incluindo
## o Homem de Armas do KayKit, ja calibrado). Ver Unit._build_model_body().
@export var model_scale_multiplier: float = 1.0

## Rotacao extra (graus, eixo Y) aplicada ao modelo depois de carregado —
## alguns pipelines de exportacao (ex: a 3D Asset Factory procedural em
## tools/asset_factory) exportam a "frente" do personagem virada pro lado
## errado em relacao a convencao que slide_to() usa pra girar a unidade na
## direcao do movimento (-Z local = frente). 0.0 (padrao) nao muda nada.
## Ver Unit._build_model_body().
@export var model_yaw_offset_degrees: float = 0.0

## Overrides de nome de clipe pra unidades cujo animation_scene_path NAO
## segue a convencao KayKit ("Idle_A"/"Walking_A") — ex: a 3D Asset
## Factory procedural (tools/asset_factory) exporta clipes literalmente
## chamados "Idle"/"Walk"/"Attack"/"Death". "" (padrao) mantem as
## constantes de sempre (Unit.DEFAULT_ANIMATION/WALK_ANIMATION), ZERO
## mudanca pra qualquer unidade KayKit existente. Ver Unit._build_model_
## body().
@export var idle_animation_override: String = ""
@export var walk_animation_override: String = ""
@export var attack_animation_override: String = ""

## Todo pacote KayKit reaproveitado ate hoje separa Idle (vem do proprio
## personagem, model_scene_path) de Andar (sempre este segundo arquivo
## compartilhado, Unit.WALK_ANIMATION_SCENE) — precisa desse merge pra
## fechar os dois clipes. Uma unidade cujo animation_scene_path JA contem
## os proprios clipes de Idle E Andar (ex: a 3D Asset Factory, que exporta
## os 4 clipes prontos no mesmo arquivo do modelo) nao precisa — e nao
## deve, o rig dela nao bate com o esqueleto KayKit desse arquivo
## compartilhado. true (padrao) mantem o comportamento de sempre.
@export var merge_shared_walk_animation: bool = true

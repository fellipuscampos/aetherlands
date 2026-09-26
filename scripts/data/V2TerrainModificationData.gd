class_name V2TerrainModificationData
extends Resource

## Uma MODIFICAÇÃO FÍSICA PERSISTENTE de terreno V2 (Aetherlands V2, Fase 20). É uma camada SOBRE o terreno-base do
## mapa (que nunca é reescrito): fica entre turnos, sem conjurador, depois de morte/captura/save, e não tem dono —
## qualquer civilização sofre o custo e recebe a Defesa. Não é clima/zona temporária (isso será outra fundação) e
## nunca vira `magic_status` de unidade. Só os campos que as modificações implementadas precisam; defaults inertes.

@export var id: String = ""
@export var display_name: String = ""
## Pontos de movimento A MAIS para ENTRAR no tile, pela mesma regra de custo de terreno do perfil de movimento
## (quem ignora o custo do terreno-base também ignora este). Nunca torna o tile impassável.
@export var movement_cost_delta: int = 0
## Fator na Defesa FÍSICA de quem defende no tile (CombatResolver.predict), pela mesma regra do bônus de terreno-base.
## Dano mágico V2 nunca lê a Defesa física, então nunca é afetado.
@export var defense_multiplier: float = 1.0
## Só pode existir em tile que uma unidade terrestre pode ocupar (nunca água, lava ou montanha).
@export var requires_ground_passable: bool = true
## Chave do marcador visual reaproveitado ("grove" = árvores KayKit; "raised" = rochas procedurais).
@export var visual_kind: String = ""

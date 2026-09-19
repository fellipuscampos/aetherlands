class_name SpellData
extends Resource

@export var school: String = ""
@export var effect: String = "" # Vazio identifica os efeitos legados.
@export var category: String = "spell"
@export var cast_range: int = 3

## Um ritual/feitico de verdade — dados de gameplay pro NOME que
## TechData.unlocks_spell ja registra (ver TechDatabase). Recurso puro de
## dados (mesmo padrao de TechData/UnitData/BuildingData) — quem interpreta
## isto e SpellManager (aplica o efeito) e a HUD (Grimorio, mostra custo/
## descricao). Indexado por NOME (nao um id proprio) porque
## TechData.unlocks_spell ja guarda o feitico so pelo nome — nao faz
## sentido duplicar um id paralelo pra a mesma coisa.

@export var name: String = ""
@export var description: String = ""

## Custo em NUMERO DE TURNOS de recarga apos conjurar (ver PlayerData.
## spell_cooldowns/SpellManager.can_cast) — cobra JUNTO com mana_cost
## abaixo (Ponto 3, "Economia Arcana": o jogo ganhou um recurso de mana de
## verdade), nao no lugar dela — os dois precisam estar satisfeitos pra
## conjurar (ver SpellManager.is_castable).
@export var cooldown_turns: int = 3

## Custo em MANA (PlayerData.mana) descontado ao conjurar com sucesso — ver
## SpellManager.has_enough_mana/cast.
@export var mana_cost: int = 0

## "enemy_unit_in_vision" (Lanca de Arcana: qualquer unidade inimiga ou
## monstro neutro, atualmente visivel) ou "friendly_unit" (Reanimar: uma
## unidade do proprio jogador) — ver SelectionManager._valid_spell_target.
@export var target_kind: String = "enemy_unit_in_vision"

## Dano direto aplicado ao alvo (kind "enemy_unit_in_vision"). 0 = feitico
## nao causa dano.
@export var damage: float = 0.0

## Fracao do HP MAXIMO do alvo restaurada (kind "friendly_unit"). 0 =
## feitico nao cura.
@export var heal_fraction: float = 0.0

## Roadmap de gameplay Fase 5 — "Ruína Ígnea": alem do alvo principal
## (mesmo target_kind/UX de clique de sempre), tambem atinge QUALQUER
## unidade (aliada ou nao — cataclismo indiscriminado, ver flavor text da
## tech) num tile vizinho dele. 0 (padrao) = dano de alvo unico, como
## Lança de Arcana ja fazia.
@export var damage_area_radius: int = 0

## Roadmap de gameplay Fase 5 — "Metamorfose de Gaia": em vez de curar
## `target`, transforma o TERRENO do tile onde ele esta em pe (a unidade
## so marca QUAL tile, reaproveitando target_kind="friendly_unit"/mesma UX
## de Reanimar) — ver SpellManager._apply_terrain_transform e
## TechDatabase.tech_that_unlocks_spell().terrain_transform.
@export var transforms_terrain: bool = false

class_name SpellData
extends Resource

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

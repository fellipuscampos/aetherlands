class_name CivilizationData
extends Resource

@export var civ_name: String = "Reino Sem Nome"
@export var leader_name: String = ""
@export var color: Color = Color.WHITE

## "human"/"dwarf"/"orc"/"elf" dao acesso a uma tropa exclusiva de combate
## (ver UnitDatabase.RACE_UNIQUE_KIND, City.can_train) — pedido do usuario:
## "insira outras civilizacoes de fantasia... voce cria tropas especificas
## pra essas civilizacoes", em vez de todo rival ser uma copia de nome/cor
## do reino do jogador. Rival sempre vem de GameManager.RIVAL_CIVS (so
## dwarf/orc/elf no pool atual); o jogador ESCOLHE a propria na tela de
## titulo (TitleScreen -> GameManager.human_race), entre as 4. "" (vazio)
## continua valido como "nenhuma raca reconhecida" pra qualquer civ criada
## fora desses dois caminhos (ex: um PlayerData de teste construido a mao).
@export var race: String = ""

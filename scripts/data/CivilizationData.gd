class_name CivilizationData
extends Resource

@export var civ_name: String = "Reino Sem Nome"
@export var leader_name: String = ""
@export var color: Color = Color.WHITE

## "" = humano/generico (jogador, e qualquer rival sem raca de fantasia
## definida). "dwarf"/"orc"/"elf" dao acesso a uma tropa exclusiva no pool
## de producao da IA (ver RivalAI._military_kinds_for) — pedido do usuario:
## "insira outras civilizacoes de fantasia... voce cria tropas especificas
## pra essas civilizacoes", em vez de todo rival ser uma copia de nome/cor
## do reino do jogador. Escopo desta rodada: so afeta os RIVAIS (ver
## GameManager.RIVAL_CIVS); o jogador continua sem raca (civilizacao
## humana generica), escolher a propria raca fica pra uma rodada futura.
@export var race: String = ""

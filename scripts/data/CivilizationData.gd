class_name CivilizationData
extends Resource

@export var civ_name: String = "Reino Sem Nome"
@export var leader_name: String = ""
@export var color: Color = Color.WHITE

## "human"/"dwarf"/"orc"/"elf" — identidade da civilização (nome padrão do reino, estilo visual via
## RaceTheme). Fase 25 removeu tropas exclusivas e bônus econômicos V1; a Fase 26 usa apenas este
## id para derivar duas especialidades sistêmicas V2, sem estado paralelo. Rival vem de
## GameManager.RIVAL_CIVS; o jogador escolhe a
## própria na tela de nova partida. "" = nenhuma raça reconhecida (ex.: PlayerData de teste).
@export var race: String = ""

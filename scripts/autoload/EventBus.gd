extends Node

signal tile_selected(coord: Vector2i, data: HexTileData)
signal unit_selected(unit: Unit)
signal game_over(victory: bool)
## Roadmap "Fase F" F1/F2/F3 -- emitido JUNTO com game_over (nunca sozinho,
## ver GameManager._end_game), nunca substituindo-o -- sistemas legados
## (HUD/AudioManager/botao de debug/testes existentes) continuam ouvindo
## so game_over sem precisar mudar nada. victory_type e uma das
## VictoryConditions.VICTORY_TYPE_* (ou VICTORY_TYPE_DEBUG pro botao de
## forcar fim de jogo). Pensado pra a tela de resultado detalhada (F1/F2
## passo 7, ainda nao implementada) consumir sem precisar transportar
## nenhum snapshot pelo proprio sinal -- ela consulta VictoryConditions
## de novo no momento de renderizar.
signal victory_achieved(winner: PlayerData, victory_type: String)
signal restart_requested
## sfx_kind identifica o efeito sonoro a tocar ("combat", "city" ou "" pra
## nenhum) — melhor do que o AudioManager tentar adivinhar pelo texto da
## mensagem, que e fragil se a redacao mudar.
signal notify(text: String, sfx_kind: String)
signal fog_updated
signal minimap_clicked(world_pos: Vector3)

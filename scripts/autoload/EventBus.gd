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
## Aetherlands V2 (Fase 3): um unlock V2 conectado passou a valer pro jogador
## HUMANO (ver V2UnlockSystem/PlayerData._on_v2_unlock_applied). A HUD só usa pra
## atualizar o painel de cidade — a disponibilidade em si é derivada da pesquisa.
signal v2_unlock_applied(player: PlayerData, unlock_type: String, unlock_id: String)
## Fase 23: informação pública do Ritual Final; nenhum destes sinais revela fog.
signal v2_transcendence_started(player: PlayerData, site_coord: Vector2i, remaining_rounds: int)
signal v2_transcendence_progressed(player: PlayerData, site_coord: Vector2i, remaining_rounds: int)
signal v2_transcendence_interrupted(player: PlayerData, site_coord: Vector2i, reason: String)
signal minimap_clicked(world_pos: Vector3)
## World Event System (docs/WORLD_EVENT_CONTRACT.md) -- emitidos so por
## WorldEventManager (ver comentario de topo la), nunca por um WorldEvent
## diretamente (mesma disciplina de victory_achieved: o sinal carrega o
## objeto vivo + um resultado, nunca um snapshot duplicado). result no
## sinal completed e so o resultado FINAL do evento (WorldEvent.result),
## nunca uma copia permanente do estado do evento inteiro.
signal world_event_announced(event: WorldEvent)
signal world_event_phase_changed(event: WorldEvent, old_phase: String, new_phase: String)
signal world_event_completed(event: WorldEvent, result: Dictionary)

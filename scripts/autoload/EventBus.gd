extends Node

signal tile_selected(coord: Vector2i, data: HexTileData)
signal unit_selected(unit: Unit)
signal game_over(victory: bool)
signal restart_requested
## sfx_kind identifica o efeito sonoro a tocar ("combat", "city" ou "" pra
## nenhum) — melhor do que o AudioManager tentar adivinhar pelo texto da
## mensagem, que e fragil se a redacao mudar.
signal notify(text: String, sfx_kind: String)
signal fog_updated
signal minimap_clicked(world_pos: Vector3)
signal pause_requested

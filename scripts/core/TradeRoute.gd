class_name TradeRoute
extends RefCounted

## Uma rota de comercio ativa entre duas cidades (roadmap de gameplay
## Fase 4A) — ver TradeManager.gd pra criacao/processamento/cancelamento.
## Guarda `player_a`/`player_b` SEPARADO de `city_a.owner_player`/
## `city_b.owner_player` de proposito: se uma cidade for capturada
## (City.change_owner), `city_a.owner_player` passa a apontar pro NOVO
## dono, mas a rota precisa continuar sabendo quem eram os donos
## ORIGINAIS pra conseguir se remover corretamente da lista de rotas de
## cada um (PlayerData.trade_routes) e pra TradeManager.
## _is_route_still_valid detectar a mudanca de dono como motivo de
## cancelamento (cidade capturada nao devia manter um acordo comercial
## antigo do dono anterior).

var city_a: City
var city_b: City
var player_a: PlayerData
var player_b: PlayerData

func _init(a: City, b: City) -> void:
	city_a = a
	city_b = b
	player_a = a.owner_player
	player_b = b.owner_player

class_name TradeManager
extends RefCounted

## Comercio, MVP fechado (roadmap de gameplay Fase 4A) — rota ponto-a-
## ponto entre duas cidades de jogadores DIFERENTES, rendendo um pouco de
## comida/producao pra CADA cidade envolvida e ouro pro dono de cada uma,
## todo turno enquanto a rota ficar ativa. Escopo deliberadamente minimo
## (decisao ja validada com o usuario): sem caravana como entidade
## atacavel no mapa, sem preco de mercado, sem transporte de recurso —
## isso fica pra Fase 4B, e so vale a pena implementar se este MVP sozinho
## ja mostrar que vale a pena no harness de simulacao (Fase 0).
##
## Mesmo padrao estatico de Diplomacy.gd/RivalAI.gd: nenhum estado proprio
## na classe — tudo vive em PlayerData.trade_routes (ver TradeRoute.gd) e
## em City (buildings/owner_player).
##
## O elo mais importante pedido pelo usuario: guerra declarada entre as
## duas pontas cancela a rota (ver _is_route_still_valid, checado a cada
## turno em process_all_routes) — comercio e guerra finalmente se
## conversando.

const ROUTE_INCOME_FOOD := 1.0
const ROUTE_INCOME_PRODUCTION := 1.0
const ROUTE_INCOME_GOLD := 2.0

## Quantas rotas uma cidade especifica ja tem ativas agora — usado tanto
## pra checar capacidade livre (ver City.max_trade_routes) quanto por
## quem for construir UI de comercio no futuro.
static func active_route_count(city: City) -> int:
	if city.owner_player == null:
		return 0
	var count := 0
	for route in city.owner_player.trade_routes:
		if route.city_a == city or route.city_b == city:
			count += 1
	return count

## Propoe uma rota entre duas cidades de jogadores DIFERENTES — aceita se
## as duas tem capacidade livre (ver City.max_trade_routes, vem do
## Mercado + Seda, Roadmap 2.0 Parte 1 B1), estao em paz, e o dono da
## cidade proposta aceita pela MESMA heuristica simples que Diplomacy.
## _accepts_peace ja usa pra propostas de paz (reaproveitada, nao
## reinventada — mesmo espirito "aceita a menos que ja em guerra/muito
## cansado"). Retorna a TradeRoute criada, ou null se a proposta for
## invalida/recusada. `hex_grid` OPCIONAL — so quando fornecido conta o
## bonus de capacidade de Seda (mesma convencao de City.max_trade_routes).
static func propose_route(from_city: City, to_city: City, hex_grid: HexGrid = null) -> TradeRoute:
	var proposer := from_city.owner_player
	var other := to_city.owner_player
	if proposer == null or other == null or proposer == other:
		return null
	if proposer.is_at_war_with(other):
		return null
	for existing in proposer.trade_routes:
		if (existing.city_a == from_city and existing.city_b == to_city) or (existing.city_b == from_city and existing.city_a == to_city):
			return null
	if active_route_count(from_city) >= from_city.max_trade_routes(hex_grid):
		return null
	if active_route_count(to_city) >= to_city.max_trade_routes(hex_grid):
		return null
	if not Diplomacy._accepts_peace(other, proposer):
		return null
	var route := TradeRoute.new(from_city, to_city)
	proposer.trade_routes.append(route)
	other.trade_routes.append(route)
	return route

## Aplica a renda de TODA rota ativa e remove as que deixaram de valer —
## chamado UMA VEZ por turno com a lista inteira de jogadores (nao por
## jogador individual: cada rota conecta 2 jogadores, processar por
## jogador dessincronizaria a limpeza, ja que a MESMA TradeRoute aparece
## nas duas listas). Ver GameManager._on_turn_changed.
static func process_all_routes(players: Array) -> void:
	var seen := {} # TradeRoute -> true, dedup (a mesma rota esta nas 2 listas)
	for player in players:
		for route in player.trade_routes:
			seen[route] = true
	for route in seen.keys():
		if _is_route_still_valid(route):
			_apply_income_to_city(route.city_a)
			_apply_income_to_city(route.city_b)
		else:
			_remove_route(route)

static func _apply_income_to_city(city: City) -> void:
	city.stored_food += ROUTE_INCOME_FOOD
	city.stored_production += ROUTE_INCOME_PRODUCTION
	if city.owner_player:
		city.owner_player.gold += ROUTE_INCOME_GOLD

## Guerra declarada entre as duas pontas OU uma das cidades ter mudado de
## dono (capturada — nao faz sentido um acordo comercial sobreviver a
## troca de dono) cancela a rota.
static func _is_route_still_valid(route: TradeRoute) -> bool:
	if not is_instance_valid(route.city_a) or not is_instance_valid(route.city_b):
		return false
	if route.city_a.owner_player != route.player_a or route.city_b.owner_player != route.player_b:
		return false
	if route.player_a == null or route.player_b == null:
		return false
	return not route.player_a.is_at_war_with(route.player_b)

static func _remove_route(route: TradeRoute) -> void:
	if route.player_a:
		route.player_a.trade_routes.erase(route)
	if route.player_b:
		route.player_b.trade_routes.erase(route)

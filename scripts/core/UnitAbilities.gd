class_name UnitAbilities
extends RefCounted

## Capacidades compartilhadas por jogador e IA. Bônus de suporte não acumulam.
const MOUNTED := ["cavalry", "human_knight", "batedor_montado", "cavaleiro_pesado", "cavaleiro_de_choque", "cavalaria_blindada", "cavaleiro_imperial"]
const SIEGE := ["catapult", "balista", "ariete", "torre_de_cerco", "trebuchet", "bombarda", "colosso_de_cerco"]
const ARMORED := ["men_at_arms", "homem_de_escudo", "stone_golem", "campeao", "campeao_do_reino", "cavaleiro_pesado", "cavalaria_blindada", "cavaleiro_imperial"]

static func command_multiplier(unit: Unit) -> float:
	if unit.owner_player == null:
		return 1.0
	for ally in unit.owner_player.units:
		if ally != unit and ally.hp > 0 and ally.unit_data.visual_kind == "general" and HexMetrics.axial_distance(ally.coord, unit.coord) <= 2:
			return 1.25
	return 1.0

static func attack_multiplier(attacker: Unit, defender: Unit) -> float:
	var kind := attacker.unit_data.visual_kind
	var target := defender.unit_data.visual_kind
	var result := command_multiplier(attacker)
	if kind in ["lanceiro", "halberdier"] and target in MOUNTED:
		result *= 1.5
	if kind == "besteiro" and target in ARMORED:
		result *= 1.3
	if kind == "cavaleiro_de_choque" and attacker.movement_left < attacker.unit_data.movement_points:
		result *= 1.25
	return result

static func city_attack_multiplier(unit: Unit) -> float:
	var kind := unit.unit_data.visual_kind
	var bonus := 2.0 if kind in ["ariete", "bombarda", "colosso_de_cerco"] else (1.5 if kind in SIEGE else 1.0)
	return bonus * command_multiplier(unit)

static func process_turn(player: PlayerData, grid: HexGrid) -> void:
	var repaired: Dictionary = {}
	for unit in player.units.duplicate():
		if unit.hp <= 0.0:
			continue
		match unit.unit_data.visual_kind:
			"engenheiro_de_cerco":
				for ally in player.units:
					if ally.unit_data.visual_kind in SIEGE and not repaired.has(ally) and HexMetrics.axial_distance(unit.coord, ally.coord) <= 1:
						ally.hp = minf(ally.unit_data.max_hp, ally.hp + ally.unit_data.max_hp * 0.25)
						repaired[ally] = true
			"mercador":
				_establish_trade(unit, player, grid)

static func _establish_trade(unit: Unit, player: PlayerData, grid: HexGrid) -> void:
	for target in grid.cities_by_coord.values():
		if target.owner_player == player or player.is_at_war_with(target.owner_player) or HexMetrics.axial_distance(unit.coord, target.coord) > 2:
			continue
		for origin in player.cities:
			if TradeManager.propose_route(origin, target, grid) != null:
				player.gold += 25.0
				if player == GameManager.human_player:
					EventBus.notify.emit("Mercador estabeleceu uma rota entre %s e %s. +25 ouro." % [origin.city_name, target.city_name], "confirm")
				grid.remove_unit(unit)
				return

static func description(kind: String) -> String:
	match kind:
		"general": return "Comando: aliados a até 2 hexágonos recebem +25% de ataque e defesa. Não acumula."
		"engenheiro_de_cerco": return "Repara 25% da vida de máquinas de cerco adjacentes por turno. Não acumula."
		"mercador": return "Termine o turno a até 2 hexágonos de uma cidade estrangeira em paz. Consome o mercador para criar uma rota e ganhar 25 ouro; ambas as cidades precisam de capacidade comercial."
		"lanceiro", "halberdier": return "+50% de ataque contra cavalaria."
		"besteiro": return "+30% de ataque contra unidades blindadas."
		"cavaleiro_de_choque": return "+25% de ataque depois de se mover neste turno."
		"torre_de_cerco": return "Ataques contra cidades ignoram o escudo das muralhas."
		"catapult": return "Cerco: +50% de dano contra cidades; 30% de dano nos inimigos adjacentes ao alvo."
		"ariete", "bombarda", "colosso_de_cerco": return "+100% de dano contra cidades."
		"balista", "trebuchet": return "+50% de dano contra cidades."
	return ""

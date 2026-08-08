class_name CombatResolver
extends RefCounted

## Combate simples: dano proporcional a diferenca entre ataque e defesa
## (defesa multiplicada pelo bonus de terreno do defensor). O atacante
## sempre gasta todo o movimento restante ao atacar. Unidades a distancia
## (attack_range >= 2, ex: arqueiro) atacando de fora do alcance
## corpo-a-corpo do defensor nao sofrem contra-ataque — o defensor
## simplesmente nao alcança quem atirou nele. Tambem notifica o jogador
## quando o combate envolve uma unidade dele — sem isso, um ataque do rival
## fora de tela passaria despercebido.

## Calcula o resultado do combate SEM aplicar nada — usado pela RivalAI
## pra decidir se vale a pena atacar antes de se comprometer (ver
## RivalAI._is_favorable_attack). resolve() usa isso tambem, garantindo
## que a IA avalia exatamente a mesma formula que realmente vai rodar,
## nao uma aproximacao separada que podia divergir com o tempo.
static func predict(attacker: Unit, defender: Unit, hex_grid: HexGrid) -> Dictionary:
	var terrain: HexTileData = hex_grid.get_tile(defender.coord)
	# Mago (unit_data.ignores_terrain_defense) atira magia: colinas/floresta/
	# montanha (bonus de terreno) e Muralhas (bonus de predio) nao protegem
	# o defensor contra isso.
	var ignore_fortification := attacker.unit_data.ignores_terrain_defense
	var terrain_bonus = terrain.defense_bonus if (terrain and not ignore_fortification) else 0.0
	var building_bonus := 0.0
	if not ignore_fortification:
		var city = hex_grid.get_city_at(defender.coord)
		if city and city.owner_player == defender.owner_player:
			building_bonus = BuildingDatabase.defense_bonus_for(city.buildings)
	var defense_multiplier = 1.0 + terrain_bonus + building_bonus
	var atk = attacker.unit_data.attack * attacker.veterancy_multiplier()
	var def = defender.unit_data.defense * defense_multiplier * defender.veterancy_multiplier()
	var is_melee_range = HexMetrics.axial_distance(attacker.coord, defender.coord) <= 1

	var damage_to_defender = max(1.0, atk - def * 0.5)
	var defender_dies = (defender.hp - damage_to_defender) <= 0.0

	var damage_to_attacker = 0.0
	var attacker_dies = false
	if not defender_dies and is_melee_range:
		damage_to_attacker = max(0.0, def - atk * 0.5) * 0.5
		attacker_dies = (attacker.hp - damage_to_attacker) <= 0.0

	return {
		"damage_to_defender": damage_to_defender,
		"defender_dies": defender_dies,
		"damage_to_attacker": damage_to_attacker,
		"attacker_dies": attacker_dies,
		"is_melee_range": is_melee_range,
	}

static func resolve(attacker: Unit, defender: Unit, hex_grid: HexGrid) -> void:
	var result = predict(attacker, defender, hex_grid)

	var attacker_name = attacker.unit_data.unit_name
	var defender_name = defender.unit_data.unit_name
	var attacker_is_human = attacker.owner_player == GameManager.human_player
	var defender_is_human = defender.owner_player == GameManager.human_player

	var defender_coord = defender.coord
	defender.hp -= result.damage_to_defender
	attacker.movement_left = 0.0
	hex_grid.spawn_damage_popup(defender_coord, result.damage_to_defender)

	if result.defender_dies:
		attacker.register_kill()
		# Covil de Monstro (MonsterDatabase, defender.owner_player == null):
		# quem vence saqueia o ouro do guardiao, humano ou rival — ver
		# UnitData.gold_reward.
		var is_monster_lair = defender.owner_player == null
		var loot = defender.unit_data.gold_reward if is_monster_lair else 0.0
		hex_grid.remove_unit(defender)
		if is_monster_lair:
			if attacker.owner_player:
				attacker.owner_player.gold += loot
			if attacker_is_human:
				EventBus.notify.emit("Voce derrotou %s e saqueou %d ouro do covil!" % [defender_name, int(loot)], "combat")
		elif attacker_is_human:
			EventBus.notify.emit("Seu %s derrotou o %s inimigo!" % [attacker_name, defender_name], "combat")
		elif defender_is_human:
			EventBus.notify.emit("Seu %s foi derrotado por um %s!" % [defender_name, attacker_name], "combat")
		return

	if not result.is_melee_range:
		if defender_is_human:
			EventBus.notify.emit("Seu %s foi atacado a distancia e resistiu!" % defender_name, "combat")
		return

	var attacker_coord = attacker.coord
	attacker.hp -= result.damage_to_attacker
	if result.damage_to_attacker > 0.0:
		hex_grid.spawn_damage_popup(attacker_coord, result.damage_to_attacker)

	if result.attacker_dies:
		defender.register_kill()
		hex_grid.remove_unit(attacker)
		if defender_is_human:
			EventBus.notify.emit("Seu %s destruiu o %s atacante!" % [defender_name, attacker_name], "combat")
		elif attacker_is_human:
			if defender.owner_player == null:
				EventBus.notify.emit("Seu %s foi derrotado pelo %s que guardava o covil!" % [attacker_name, defender_name], "combat")
			else:
				EventBus.notify.emit("Seu %s foi derrotado ao atacar!" % attacker_name, "combat")
	elif defender_is_human:
		EventBus.notify.emit("Seu %s foi atacado e resistiu!" % defender_name, "combat")

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

## Bonus de defesa por ficar Fortificado (Unit.fortified, ver
## SelectionManager.fortify_selected) — pedido do usuario descreveu a cura
## passiva do Fortificar mas nao os detalhes de combate ("não sei tantos
## detalhes"); bonus de defesa e o efeito CLASSICO do Fortificar em jogos
## de estrategia por turnos — sem ele, "Fortificar" seria so um sinonimo
## de "nao fazer nada". Reusa o mesmo "ignore_fortification" do Mago
## abaixo (unit_data.ignores_terrain_defense) que ja ignora terreno/
## Muralhas — fortificar tambem e uma fortificacao, magia ignora do mesmo
## jeito.
const FORTIFY_DEFENSE_BONUS := 0.25

## Defesa so MITIGA metade do proprio valor (nao anula ataque bruto 1 pra
## 1) — mantem ataque sempre a variavel dominante, pra unidade "de ataque"
## (mago, arqueiro) continuar valendo a pena treinar mesmo contra alvo bem
## defendido.
const DEFENSE_MITIGATION_FACTOR := 0.5
## Roadmap de gameplay Fase 2: nomeado e documentado o "numero magico" que
## ja existia (pedido do usuario: "revisar... nomear a constante e
## comentar a razao... ou igualar a formula principal" — optei por manter
## e documentar, nao igualar). Contra-ataque usa a MESMA mitigacao acima
## (DEFENSE_MITIGATION_FACTOR) e AINDA multiplica o resultado por isto —
## de proposito: quem PUXA o combate leva vantagem sobre quem so revida,
## convencao comum de jogos de estrategia por turno (recompensa iniciativa
## tatica, ex: focar um alvo fraco antes que ele ataque primeiro).
const COUNTER_ATTACK_PENALTY := 0.5

## Roadmap de gameplay Fase 2 — pedido do usuario: "bonus de flanqueamento
## simples (unidade aliada adjacente ao alvo dá multiplicador modesto de
## ataque)... so contagem de adjacencia, sem modelo de direcao/orientacao".
## Modesto e limitado de proposito (FLANKING_MAX_ALLIES) — nao vira uma
## corrida por empilhar unidades no mesmo alvo.
const FLANKING_BONUS_PER_ALLY := 0.15
const FLANKING_MAX_ALLIES := 2

## Calcula o resultado do combate SEM aplicar nada — usado pela RivalAI
## pra decidir se vale a pena atacar antes de se comprometer (ver
## RivalAI.is_favorable_attack). resolve() usa isso tambem, garantindo
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
	var fortify_bonus = FORTIFY_DEFENSE_BONUS if (defender.fortified and not ignore_fortification) else 0.0
	var defense_multiplier = 1.0 + terrain_bonus + building_bonus + fortify_bonus
	var atk = attacker.unit_data.attack * attacker.veterancy_multiplier() * _flanking_multiplier(attacker, defender, hex_grid)
	var def = defender.unit_data.defense * defense_multiplier * defender.veterancy_multiplier()
	var is_melee_range = HexMetrics.axial_distance(attacker.coord, defender.coord) <= 1

	var damage_to_defender = max(1.0, atk - def * DEFENSE_MITIGATION_FACTOR)
	var defender_dies = (defender.hp - damage_to_defender) <= 0.0

	var damage_to_attacker = 0.0
	var attacker_dies = false
	if not defender_dies and is_melee_range:
		damage_to_attacker = max(0.0, def - atk * DEFENSE_MITIGATION_FACTOR) * COUNTER_ATTACK_PENALTY
		attacker_dies = (attacker.hp - damage_to_attacker) <= 0.0

	return {
		"damage_to_defender": damage_to_defender,
		"defender_dies": defender_dies,
		"damage_to_attacker": damage_to_attacker,
		"attacker_dies": attacker_dies,
		"is_melee_range": is_melee_range,
	}

## Conta aliados do ATACANTE (mesmo owner_player, incluindo dois monstros
## neutros com owner_player==null) grudados num tile vizinho do DEFENSOR
## (nao do atacante) — "cercar o alvo de mais de um lado", sem modelar
## direcao/angulo real. O proprio atacante nunca conta a si mesmo mesmo se
## ele proprio for adjacente ao defensor (ataque corpo-a-corpo comum).
static func _flanking_multiplier(attacker: Unit, defender: Unit, hex_grid: HexGrid) -> float:
	var ally_count := 0
	for neighbor_coord in hex_grid.get_neighbors(defender.coord):
		if neighbor_coord == attacker.coord:
			continue
		var unit: Unit = hex_grid.get_unit_at(neighbor_coord)
		if unit and unit.owner_player == attacker.owner_player:
			ally_count += 1
	return 1.0 + FLANKING_BONUS_PER_ALLY * min(ally_count, FLANKING_MAX_ALLIES)

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

## Atacar uma cidade SEM unidade guarnicionada (ver defender_unit check no
## chamador — SelectionManager._attack_from_selected/RivalAI._engage; uma
## cidade DEFENDIDA continua resolvendo o combate contra a unidade acima,
## sem mudanca) — pedido do usuario: "quero... estabelecer a vida da
## cidade... e o shield tambem... a partir do momento que voce construir a
## muralha... [o shield fica] abaixo da vida atual". Ate aqui, uma cidade
## indefesa era capturada na hora, num unico clique — agora o dano
## desconta do ESCUDO primeiro (Muralhas, se construida), so depois da
## VIDA da propria cidade, e so captura quando a vida chega a zero (ANTES
## disso, a cidade so fica mais fraca — regenera aos poucos entre ataques,
## ver City.process_turn).
static func resolve_city_attack(attacker: Unit, city: City, hex_grid: HexGrid) -> void:
	var attacker_name = attacker.unit_data.unit_name
	var attacker_is_human = attacker.owner_player == GameManager.human_player
	var defender_is_human = city.owner_player == GameManager.human_player

	# Roadmap de gameplay Fase 2: antes, atacar uma cidade SEM unidade
	# guarnicionada ignorava Muralhas por completo (so o escudo importava),
	# enquanto atacar uma cidade COM guarnicao aplicava o bonus de defesa
	# das Muralhas normalmente via predict() acima — duas regras diferentes
	# pra "Muralha defende" dependendo de ter ou nao unidade dentro.
	# Unificado: o mesmo BuildingDatabase.defense_bonus_for() agora reduz o
	# dano bruto tambem aqui (dividindo em vez de multiplicar um "defense"
	# que uma cidade nao tem) — sem Muralhas, defense_bonus_for({})==0.0 e
	# o resultado e IDENTICO ao de antes.
	var defense_bonus := BuildingDatabase.defense_bonus_for(city.buildings)
	var damage = max(1.0, (attacker.unit_data.attack * attacker.veterancy_multiplier()) / (1.0 + defense_bonus))
	attacker.movement_left = 0.0

	var remaining_damage = damage
	if city.shield > 0.0:
		var absorbed = min(city.shield, remaining_damage)
		city.shield -= absorbed
		remaining_damage -= absorbed
	if remaining_damage > 0.0:
		city.hp = max(0.0, city.hp - remaining_damage)
	city._update_life_bars()
	hex_grid.spawn_damage_popup(city.coord, damage)

	if city.hp <= 0.0:
		# Roadmap "Fase Macro" 5B.3-B -- atacante NEUTRO (Dragao/monstro,
		# attacker.owner_player == null): raid, NUNCA captura -- decisao
		# explicita do usuario (docs/DRAGON_EVENT_DESIGN.md: "nao quero que
		# o Dragao destrua a cidade como uma unidade de conquista"). Sem
		# este guard, hex_grid.capture_city(city, null) quebraria mesmo
		# (new_owner.cities.append(city) sobre null) -- nunca acontecia
		# antes porque nenhum monstro jamais atacava uma cidade diretamente
		# (MonsterAI so pilha tiles ao redor, ver comentario de topo do
		# arquivo). Cidade fica extremamente fragil (1 HP) mas nunca muda
		# de dono por um ataque neutro.
		if attacker.owner_player == null:
			city.hp = 1.0
			city._update_life_bars()
		else:
			hex_grid.capture_city(city, attacker.owner_player) # emite seu proprio EventBus.notify
		return

	if defender_is_human:
		EventBus.notify.emit("%s foi atacada! Vida: %d/%d" % [city.city_name, int(city.hp), int(city.max_hp())], "combat")
	elif attacker_is_human:
		EventBus.notify.emit("Seu %s enfraqueceu %s!" % [attacker_name, city.city_name], "combat")

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
## `defense_penetration`/`prevents_counterattack` (Fase 10 — Ataque Furtivo): mais dois fatores da MESMA conta, nunca uma segunda fórmula.
## `defense_penetration` (0..1) reduz a CONTRIBUIÇÃO da Defesa do defensor antes da mitigação, só nesta resolução (o defensor não fica mais fraco
## depois); `prevents_counterattack` zera o revide desta resolução (o defensor, se sobreviver, continua sem nenhum estado). 0.0/false = idêntico a antes.
static func predict(attacker: Unit, defender: Unit, hex_grid: HexGrid, strike_multiplier: float = 1.0, defense_penetration: float = 0.0, prevents_counterattack: bool = false) -> Dictionary:
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
			building_bonus = city.defense_bonus() # Fase 16: inclui a Fortificação V2
	var fortify_bonus = FORTIFY_DEFENSE_BONUS if (defender.fortified and not ignore_fortification) else 0.0
	var defense_multiplier = 1.0 + terrain_bonus + building_bonus + fortify_bonus
	# `strike_multiplier` (Fase 7): o multiplicador da TÉCNICA de ataque em curso (Golpe Poderoso 1,60; Ataque em
	# Arco 0,75); 1.0 num ataque comum. É só mais um fator da mesma conta — nada de segunda fórmula.
	# V2LogisticsRuntime.combat_multiplier (Fase 15): 0,85 em Ataque E Defesa se o DONO da unidade
	# está em Tensão Logística e ELA TEM supply_cost > 0 — a mesma função serve os dois lados
	# (o efeito é idêntico; nunca um id de unidade concreto, ver o arquivo).
	# V2MagicRuntime.attack_multiplier (Fase 19, Comando Macabro): UM fator a mais, paralelo ao defense_multiplier;
	# sem estado mágico no atacante devolve 1.0 sem olhar feitiço nenhum.
	var atk = attacker.unit_data.attack * attacker.veterancy_multiplier() * _flanking_multiplier(attacker, defender, hex_grid) * UnitAbilities.attack_multiplier(attacker, defender) * V2MagicRuntime.attack_multiplier(attacker) * V2EnvironmentalZoneSystem.physical_ranged_attack_multiplier(attacker, hex_grid) * strike_multiplier * V2LogisticsRuntime.combat_multiplier(attacker) * V2RaceBonusRuntime.combat_attack_multiplier(attacker)
	# V2MagicRuntime.defense_multiplier (Fase 17, Égide Sagrada): UM fator a mais da mesma conta; sem estado mágico no
	# defensor devolve 1.0 sem olhar feitiço nenhum.
	# V2TerrainRuntime (Fase 20, modificação física de terreno sem dono): UM fator na Defesa física, pela MESMA regra do
	# bônus do terreno-base (quem ignora o terreno — o Mago V1 — ignora também); 1.0 sem modificação no tile.
	var terrain_modification = 1.0 if ignore_fortification else V2TerrainRuntime.defense_multiplier_at(hex_grid, defender.coord)
	var def = defender.unit_data.defense * defense_multiplier * terrain_modification * defender.veterancy_multiplier() * UnitAbilities.command_multiplier(defender) * V2TechniqueRuntime.defense_multiplier(defender, hex_grid) * V2UnitAuras.defense_multiplier(defender) * V2MagicRuntime.defense_multiplier(defender) * V2LogisticsRuntime.combat_multiplier(defender)
	# Penetração de Defesa (Fase 10): só a contribuição da Defesa NESTE golpe é reduzida — o revide (abaixo) e qualquer outra resolução seguem com a
	# Defesa `def` inteira, nunca com `effective_def`.
	var effective_def = def * (1.0 - clampf(defense_penetration, 0.0, 1.0))
	var is_melee_range = HexMetrics.axial_distance(attacker.coord, defender.coord) <= 1

	# Fase 17: unidade SEM ataque básico (UnitData.can_basic_attack = false — Clérigo, Serafim) nunca causa dano por ataque
	# comum: bloqueado ANTES do piso de dano de 1 (Ataque 0 sozinho ainda causaria 1). resolve() nem chega aqui para ela.
	var damage_to_defender = max(1.0, atk - effective_def * DEFENSE_MITIGATION_FACTOR) * UnitAbilities.ranged_vulnerability_multiplier(attacker, defender) if attacker.unit_data.can_basic_attack else 0.0
	var defender_dies = (defender.hp - damage_to_defender) <= 0.0

	var damage_to_attacker = 0.0
	var attacker_dies = false
	# Fase 17: defensor sem ataque básico nunca revida (nem o piso de dano).
	if not defender_dies and is_melee_range and not prevents_counterattack and defender.unit_data.can_basic_attack:
		# Fase 19: o estado de Ataque mágico do DEFENSOR (Comando Macabro) também fortalece o revide dele — o revide
		# deste motor sai da Defesa, então o fator entra no resultado (1.0 sem estado; predict == resolve).
		damage_to_attacker = max(0.0, def - atk * DEFENSE_MITIGATION_FACTOR) * COUNTER_ATTACK_PENALTY * V2MagicRuntime.attack_multiplier(defender)
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
static func _record_damage(attacker: Unit, defender: Unit, damage: float) -> void:
	_record_damage_from_player(attacker.owner_player, defender, damage)

## Mesmo registro de _record_damage pra um dano causado por algo que não é Unit (Fase 16: o Ataque
## da Cidade) — o crédito é da civilização dona.
static func _record_damage_from_player(player: PlayerData, defender: Unit, damage: float) -> void:
	var index := GameManager.players.find(player)
	DragonEvent.record_damage_if_target_is_the_active_dragon(defender, index, damage)

static func _flanking_multiplier(attacker: Unit, defender: Unit, hex_grid: HexGrid) -> float:
	var ally_count := 0
	for neighbor_coord in hex_grid.get_neighbors(defender.coord):
		if neighbor_coord == attacker.coord:
			continue
		var unit: Unit = hex_grid.get_unit_at(neighbor_coord)
		if unit and unit.owner_player == attacker.owner_player:
			ally_count += 1
	return 1.0 + FLANKING_BONUS_PER_ALLY * min(ally_count, FLANKING_MAX_ALLIES)

## Regra semântica ÚNICA de hostilidade contra uma unidade. Não pergunta se a fonte pode fazer
## ataque básico: feitiços ofensivos usam isto diretamente. Mantém a diplomacia, monstros e
## ocultação que já valiam para ataques físicos.
static func is_hostile_unit_target(owner: PlayerData, target: Unit, hex_grid: HexGrid) -> bool:
	if owner == null or target == null or not is_instance_valid(target) or target.hp <= 0.0 or target.owner_player == owner:
		return false
	return target.owner_player == null or owner.is_at_war_with(target.owner_player)

## Ataque básico compõe capacidade física + a regra semântica acima. Fase 19: e a capacidade de RECEBER ORDEM
## (Unit.can_receive_orders — retinue sem comando não INICIA ataque; defender/retaliar não passa por aqui).
static func can_attack_unit(attacker: Unit, target: Unit, hex_grid: HexGrid) -> bool:
	if attacker == null or target == null or target == attacker or attacker.owner_player == null or not attacker.unit_data.can_basic_attack:
		return false
	if not attacker.can_receive_orders():
		return false
	return is_hostile_unit_target(attacker.owner_player, target, hex_grid)

## Aplica dano DIRETO já calculado e centraliza a pipeline normal de morte por Unit: popup,
## registro contra world event, alerta de covil, kill/veterania, saque e remoção. Não contém
## fórmula de dano e não causa contra-ataque; serve ao combate físico e aos feitiços V2.
## Retorna true quando o alvo morreu.
static func apply_direct_unit_damage(source: Unit, target: Unit, damage: float, hex_grid: HexGrid) -> bool:
	if source == null or target == null or hex_grid == null or not is_instance_valid(target) or target.hp <= 0.0:
		return false
	var applied := maxf(damage, 0.0)
	var target_coord := target.coord
	var source_name := source.unit_data.unit_name
	var target_name := target.unit_data.unit_name
	var source_is_human := source.owner_player == GameManager.human_player
	var target_is_human := target.owner_player == GameManager.human_player
	_record_damage(source, target, minf(target.hp, applied))
	target.hp -= applied
	if applied > 0.0:
		hex_grid.spawn_damage_popup(target_coord, applied)
	if target.owner_player == null and source.owner_player != null:
		hex_grid.alert_lair_near(target_coord, TurnManager.turn_number)
	if target.hp > 0.0:
		return false
	source.register_kill()
	var is_monster_lair := target.owner_player == null
	var loot := target.unit_data.gold_reward if is_monster_lair else 0.0
	hex_grid.remove_unit(target)
	if is_monster_lair:
		if source.owner_player:
			source.owner_player.gold += loot
		if source_is_human:
			EventBus.notify.emit("Voce derrotou %s e saqueou %d ouro do covil!" % [target_name, int(loot)], "combat")
	elif source_is_human:
		EventBus.notify.emit("Seu %s derrotou o %s inimigo!" % [source_name, target_name], "combat")
	elif target_is_human:
		EventBus.notify.emit("Seu %s foi derrotado por um %s!" % [target_name, source_name], "combat")
	return true

## Dano fixo de uma fonte AMBIENTAL sem Unit: ignora toda fórmula de combate e
## nunca concede abate, XP, loot, recompensa ou crédito de evento. Ainda usa a
## remoção canônica da Unit, que rederiva comando/slots automaticamente.
static func apply_environmental_unit_damage(target: Unit, damage: float, hex_grid: HexGrid) -> bool:
	if target == null or hex_grid == null or not is_instance_valid(target) or target.hp <= 0.0:
		return false
	var applied := maxf(damage, 0.0)
	var coord := target.coord
	target.hp -= applied
	if applied > 0.0 and (hex_grid.visibility.is_empty() or hex_grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE):
		hex_grid.spawn_damage_popup(coord, applied)
	if target.hp > 0.0:
		return false
	hex_grid.remove_unit(target)
	return true

## Regra ÚNICA de "esta CIDADE pode ser atacada por `attacker` agora" (Fase 11): dono diferente e em guerra — a MESMA condição
## que já valia embutida em SelectionManager._select_unit (attackable) desde antes desta fase; agora também usada pelas
## Técnicas de Cerco com alvo de cidade (Bombardeio Preparado). Sem neblina aqui: a visibilidade de alcance > 1 é
## responsabilidade de quem chama.
static func can_attack_city(attacker: Unit, city: City) -> bool:
	return attacker != null and city != null and attacker.owner_player != null and attacker.unit_data.can_basic_attack and attacker.can_receive_orders() and city.owner_player != attacker.owner_player and attacker.owner_player.is_at_war_with(city.owner_player)

## `strike_multiplier` (Fase 7), `defense_penetration`/`prevents_counterattack` (Fase 10): ver predict(). Só o Ataque/Defesa/revide DESTE golpe
## mudam; morte, abate, recompensa, notificações e o resto do combate são exatamente os do ataque normal.
static func resolve(attacker: Unit, defender: Unit, hex_grid: HexGrid, strike_multiplier: float = 1.0, defense_penetration: float = 0.0, prevents_counterattack: bool = false) -> void:
	# Fase 17: fail-closed — unidade sem ataque básico nunca resolve um ataque comum, venha de onde vier (seleção, IA...).
	# Fase 19: idem para retinue sem comando (não inicia ataque; o revide dela é resolvido do lado do defensor).
	if not attacker.unit_data.can_basic_attack or not attacker.can_receive_orders():
		return
	if attacker.unit_data.visual_kind == "catapult":
		resolve_with_splash(attacker, defender, hex_grid, 1, 0.3)
	else:
		_resolve_primary(attacker, defender, hex_grid, strike_multiplier, defense_penetration, prevents_counterattack)

static func _resolve_primary(attacker: Unit, defender: Unit, hex_grid: HexGrid, strike_multiplier: float = 1.0, defense_penetration: float = 0.0, prevents_counterattack: bool = false) -> void:
	var result = predict(attacker, defender, hex_grid, strike_multiplier, defense_penetration, prevents_counterattack)

	# So unidades com UnitData.attack_animation_override tem attack_animation
	# != "" (ver Unit._build_model_body()) -- pra qualquer outra unidade
	# isso e um no-op, igual sempre foi (combate sem nenhuma animacao). Sem
	# gancho pra voltar pro Idle depois: o clipe termina numa pose que ja
	# fica proxima da neutra de proposito (ver tools/asset_factory/
	# animation/clips.py), entao so segurar no ultimo frame ate o proximo
	# slide_to() ja e aceitavel visualmente sem precisar de timer.
	if attacker.attack_animation != "":
		# Sem isso o atacante fica olhando pra qualquer direcao que sobrou do
		# ultimo slide_to() (ex: quem acabou de andar pro lado e ataca pra
		# frente) e o swing da arma acontece apontando pro lugar errado --
		# "ele nao usa a lanca" (usuario), a lanca balanca no ar em vez de
		# ir na direcao do defensor. Mesma formula de slide_to().
		var attack_direction: Vector3 = defender.position - attacker.position
		attack_direction.y = 0.0
		if attack_direction.length() > 0.05:
			attacker.rotation.y = atan2(attack_direction.x, attack_direction.z)
		attacker._play_animation(attacker.attack_animation)

	var attacker_name = attacker.unit_data.unit_name
	var defender_name = defender.unit_data.unit_name
	var attacker_is_human = attacker.owner_player == GameManager.human_player
	var defender_is_human = defender.owner_player == GameManager.human_player

	attacker.movement_left = 0.0
	if apply_direct_unit_damage(attacker, defender, result.damage_to_defender, hex_grid):
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

## Dano em area (Roadmap "Fase Macro" 5B.3-D, Dragon World Event — item 4
## do pedido do usuario: "dano em area... reutilizar sistema existente de
## dano/combat, nao duplicar toda a logica"). O alvo PRIMARIO passa pelo
## resolve() de VERDADE, sem nenhuma mudanca (contra-ataque, morte, loot,
## notificacao — tudo identico a um combate normal). Alvos SECUNDARIOS
## (outro inimigo do atacante num raio ao redor do alvo primario) reusam a
## MESMA formula de dano (predict(), nunca uma formula nova) escalada por
## `splash_damage_fraction` — nunca revidam (um "estilhaço" nao e' um
## combate de verdade, so' o alvo realmente engajado luta de volta) e nunca
## contam pra `register_kill()`/loot (isso continua exclusivo do alvo
## primario). Generico de proposito (radius/fraction sao parametros, nunca
## hardcoded aqui) — DragonEvent e' o unico chamador hoje, mas nada aqui e'
## especifico de Dragao.
static func resolve_with_splash(attacker: Unit, primary_defender: Unit, hex_grid: HexGrid, splash_radius: int, splash_damage_fraction: float) -> void:
	var primary_coord := primary_defender.coord
	_resolve_primary(attacker, primary_defender, hex_grid)
	# Dragao morto pelo contra-ataque do proprio alvo primario -- nao
	# deveria continuar "respirando fogo" depois de morto.
	if attacker.hp <= 0.0 or splash_radius <= 0 or splash_damage_fraction <= 0.0:
		return
	for coord in hex_grid.tiles_in_range(primary_coord, splash_radius):
		var victim: Unit = hex_grid.get_unit_at(coord)
		if victim == null or victim == primary_defender:
			continue # nunca dobra o dano de quem ja foi o alvo primario
		if victim.owner_player == null or victim.owner_player == attacker.owner_player:
			continue # so' inimigos de verdade do atacante, nunca aliado/outro neutro
		if attacker.owner_player != null and victim.owner_player != primary_defender.owner_player and not attacker.owner_player.is_at_war_with(victim.owner_player):
			continue
		var prediction := predict(attacker, victim, hex_grid)
		var splash_damage: float = prediction.damage_to_defender * splash_damage_fraction
		victim.hp -= splash_damage
		hex_grid.spawn_damage_popup(victim.coord, splash_damage)
		if victim.hp <= 0.0:
			hex_grid.remove_unit(victim)

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
## `max_damage_fraction_of_current_hp` (default 1.0 -- SEM capa nenhuma,
## comportamento IDENTICO a antes) permite limitar o dano de UM UNICO
## ataque a uma fracao do HP ATUAL da cidade -- pedido explicito do
## usuario apos o playtest do Dragao: "ele não deveria destruir a cidade,
## só causar dano... não fazer a vida da cidade chegar a 0 na primeira
## passada". Jogador/rival continuam sem capa nenhuma (parametro default);
## so' DragonEvent passa uma fracao menor pro proprio raid (ver
## DRAGON_RAID_DAMAGE_FRACTION) -- generico de proposito, nunca hardcoded
## aqui, pra nao duplicar a formula de dano em outro lugar.
## `strike_multiplier` (Fase 11, Bombardeio Preparado): o multiplicador da TÉCNICA de ataque de Cerco em curso (1.50), 1.0 num
## ataque comum — mais um fator da MESMA fórmula abaixo, nunca uma segunda fórmula de dano urbano. Munição Demolidora (Fase 11,
## `V2TechniqueRuntime.city_attack_multiplier`) entra pela mesma linha, incondicionalmente (1.0 pra quem não a tem/pesquisou):
## vale pro ataque básico de Cerco E pro Bombardeio, nunca pra covil (resolve_lair_attack não chama city_attack_multiplier).
static func resolve_city_attack(attacker: Unit, city: City, hex_grid: HexGrid, max_damage_fraction_of_current_hp: float = 1.0, strike_multiplier: float = 1.0) -> void:
	if not attacker.unit_data.can_basic_attack or not attacker.can_receive_orders(): # Fase 17: sem ataque básico, sem ataque a cidade; Fase 19: sem comando, idem
		return
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
	var defense_bonus := city.defense_bonus() # Fase 16: prédios defensivos + Fortificação V2, mesma fórmula
	var damage = max(1.0, (attacker.unit_data.attack * attacker.veterancy_multiplier() * UnitAbilities.city_attack_multiplier(attacker) * strike_multiplier * V2TechniqueRuntime.city_attack_multiplier(attacker)) / (1.0 + defense_bonus))
	# Capa (se pedida) -- nunca abaixo de 1.0 mesmo assim, pra sempre
	# continuar sendo um ataque de verdade (mesma convencao de "dano
	# minimo 1.0" ja usada na linha acima).
	damage = max(1.0, min(damage, city.hp * max_damage_fraction_of_current_hp))
	attacker.movement_left = 0.0

	var remaining_damage = damage
	if city.shield > 0.0 and attacker.unit_data.visual_kind != "torre_de_cerco":
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

## COVIS DE MONSTROS -- DESTRUICAO (pedido do usuario: "quero transformar
## covis em alvos reais... HP; defesa; ataque ao covil; destruicao;
## recompensa"). Mesma arquitetura de resolve_city_attack acima (estrutura
## com HP/defesa proprios, dano reduz HP, HP<=0 destroi e concede
## recompensa), reaproveitada em vez de inventar um sistema paralelo. So'
## deveria ser chamada quando o covil ja esta SEM nenhum guardiao/reforco
## vivo na area (ver SelectionManager._select_unit, que so marca a
## estrutura como atacavel nessa condicao) -- a estrutura em si nunca
## revida (sem contra-ataque, diferente de resolve() entre Units), so'
## absorve dano ate estourar. Defesa vem do proprio kind (MonsterDatabase.
## KIND_DATA) -- "a tenda de Goblin ainda cai facil, a caverna de Troll
## resiste mais", sem precisar de uma tabela de defesa separada pra
## estrutura.
static func resolve_lair_attack(attacker: Unit, lair_coord: Vector2i, hex_grid: HexGrid) -> void:
	if not attacker.can_receive_orders() or not hex_grid.lairs_by_coord.has(lair_coord):
		return
	# Defesa em profundidade: SelectionManager._select_unit ja so' marca a
	# estrutura como atacavel quando genuinamente indefesa, mas confere de
	# novo aqui tambem -- nenhum caminho, direto ou indireto, deveria
	# conseguir "pular a fila" e atacar a estrutura enquanto o guardiao/
	# reforco ainda estiver vivo na area (ver HexGrid._count_live_monsters_
	# near_lair, mesmo criterio usado pelo bloqueio de movimento).
	if hex_grid._count_live_monsters_near_lair(lair_coord) > 0:
		return
	var structure: LairStructure = hex_grid.lairs_by_coord[lair_coord]
	var info: Dictionary = MonsterDatabase.KIND_DATA.get(structure.kind, {})
	var defense: float = info.get("defense", 0.0)
	var damage = max(1.0, attacker.unit_data.attack * attacker.veterancy_multiplier() * UnitAbilities.city_attack_multiplier(attacker) - defense * DEFENSE_MITIGATION_FACTOR)
	attacker.movement_left = 0.0
	structure.hp = max(0.0, structure.hp - damage)
	hex_grid.spawn_damage_popup(lair_coord, damage)

	var attacker_is_human = attacker.owner_player == GameManager.human_player
	if structure.hp <= 0.0:
		hex_grid._grant_lair_clear_reward(attacker, lair_coord)
		return
	if attacker_is_human:
		var display_name: String = info.get("unit_name", "Covil")
		EventBus.notify.emit("Voce atacou o covil de %s! Estrutura: %d/%d" % [display_name, int(structure.hp), int(structure.max_hp)], "combat")

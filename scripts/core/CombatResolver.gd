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
	var atk = attacker.unit_data.attack * attacker.veterancy_multiplier() * _flanking_multiplier(attacker, defender, hex_grid) * UnitAbilities.attack_multiplier(attacker, defender) * MagicRuntime.attack_multiplier(attacker)
	var def = defender.unit_data.defense * defense_multiplier * defender.veterancy_multiplier() * UnitAbilities.command_multiplier(defender)
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
static func _record_damage(attacker: Unit, defender: Unit, damage: float) -> void:
	var index := GameManager.players.find(attacker.owner_player)
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

static func resolve(attacker: Unit, defender: Unit, hex_grid: HexGrid) -> void:
	if attacker.ritual_id != "":
		return
	attacker.magic_status["revealed"] = TurnManager.turn_number + 2
	if attacker.unit_data.visual_kind == "catapult":
		resolve_with_splash(attacker, defender, hex_grid, 1, 0.3)
	else:
		_resolve_primary(attacker, defender, hex_grid)

static func _resolve_primary(attacker: Unit, defender: Unit, hex_grid: HexGrid) -> void:
	var result = predict(attacker, defender, hex_grid)

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

	var defender_coord = defender.coord
	_record_damage(attacker, defender, minf(defender.hp, result.damage_to_defender))
	defender.hp -= result.damage_to_defender
	attacker.movement_left = 0.0
	hex_grid.spawn_damage_popup(defender_coord, result.damage_to_defender)

	# AGGRO / TERRITORIO DE AMEACA (pedido do usuario: "o jogador ataca
	# membros do covil" e' um dos gatilhos de reacao) -- qualquer ataque de
	# jogador/rival contra um monstro neutro alerta o covil dono do alvo,
	# morrendo ou nao (ver HexGrid.alert_lair_near/MonsterAI._guard_radius_
	# for/_raider_radius_for). Nunca dispara o inverso (monstro atacando
	# jogador) nem monstro-vs-monstro (impossivel de qualquer forma, ver
	# nota de arquitetura no topo do arquivo).
	if defender.owner_player == null and attacker.owner_player != null:
		hex_grid.alert_lair_near(defender_coord, TurnManager.turn_number)

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
	if attacker.ritual_id != "":
		return
	attacker.magic_status["revealed"] = TurnManager.turn_number + 2
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
static func resolve_city_attack(attacker: Unit, city: City, hex_grid: HexGrid, max_damage_fraction_of_current_hp: float = 1.0) -> void:
	if attacker.ritual_id != "":
		return
	attacker.magic_status["revealed"] = TurnManager.turn_number + 2
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
	var damage = max(1.0, (attacker.unit_data.attack * attacker.veterancy_multiplier() * UnitAbilities.city_attack_multiplier(attacker)) / (1.0 + defense_bonus))
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
	if attacker.ritual_id != "" or not hex_grid.lairs_by_coord.has(lair_coord):
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
	attacker.magic_status["revealed"] = TurnManager.turn_number + 2
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

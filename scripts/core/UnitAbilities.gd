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

## Classificação ÚNICA de "montada": o traço `mounted` do dado (UnitData.traits). As tropas V1
## ganham o traço a partir de MOUNTED em UnitDatabase.create_unit; as V2 o declaram. Nenhuma
## regra de combate lista ids de cavalaria.
static func is_mounted(unit_data: UnitData) -> bool:
	return unit_data != null and unit_data.has_trait(UnitData.TRAIT_MOUNTED)

## Voa? (V1 `flies` ou o perfil de voo tático do V2.) Fonte única da pergunta "esta unidade voa?".
static func is_flying(unit_data: UnitData) -> bool:
	return unit_data != null and unit_data.is_flying()

## Vulnerabilidade a ataques físicos À DISTÂNCIA (Fase 9): 1 + `defender.ranged_damage_taken_bonus` se o alcance de ataque de `attacker` é maior que
## 1 (ataque básico de arqueiro/atirador, Disparo Preciso, cada vítima da Saraivada, máquina de cerco...), 1.0 caso contrário. Só unidade contra
## unidade (predict): melee, feitiço, cidade e dano ambiental não passam por aqui. Nenhuma unidade citada: é DADO do defensor.
static func ranged_vulnerability_multiplier(attacker: Unit, defender: Unit) -> float:
	var bonus := defender.unit_data.ranged_damage_taken_bonus
	if bonus <= 0.0 or attacker.unit_data.attack_range <= 1:
		return 1.0
	return 1.0 + bonus

## "Voo tático: ..." para o painel de uma unidade de perfil de movimento FLYING; "" para as demais (o voo V1 `flies` segue como sempre, sem texto novo).
static func flight_text(data: UnitData) -> String:
	if data == null or data.movement_profile != UnitData.MovementProfile.FLYING:
		return ""
	return "Voo tático: atravessa terreno e unidades; pousa só em terra livre."

## "Passo Sombrio: ..." para o painel de uma unidade de perfil de movimento INFILTRATOR (Fase 10); "" para as demais. Nunca menciona "voo": a unidade
## atravessa unidades mas continua barrada por terreno realmente impassável (água/montanha) — diferente do voo tático acima.
static func infiltration_text(data: UnitData) -> String:
	if data == null or data.movement_profile != UnitData.MovementProfile.INFILTRATOR:
		return ""
	return "Passo Sombrio: atravessa unidades e ignora custo extra de terreno terrestre; não atravessa terreno impassável."

## "Vulnerável a ataques à distância: +25% de dano recebido." a partir do dado; "" sem a vulnerabilidade.
static func ranged_vulnerability_text(data: UnitData) -> String:
	if data == null or data.ranged_damage_taken_bonus <= 0.0:
		return ""
	return "Vulnerável a ataques à distância: +%d%% de dano recebido." % int(round(data.ranged_damage_taken_bonus * 100.0))

## "Passiva Lendária — Artilharia Andante" + efeito, pro painel de uma unidade com `ignores_technique_stationary_requirement` (Fase 11, Colosso
## de Cerco); [] pras demais. Mesmo padrão de duas linhas de low_hp_attack_lines/trait_attack_lines (prefixo "Passiva Lendária" só se a unidade
## também for Lendária — hoje sempre é, mas o campo é genérico, pronto pra uma unidade convencional futura declará-lo e ganhar só "Passiva").
static func artillery_march_lines(unit: Unit) -> Array[String]:
	var result: Array[String] = []
	if unit == null or unit.unit_data == null or not unit.unit_data.ignores_technique_stationary_requirement:
		return result
	var prefix := "Passiva Lendária" if unit.unit_data.has_trait(UnitData.TRAIT_LEGENDARY) else "Passiva"
	result.append("%s — Artilharia Andante" % prefix)
	result.append("Pode usar Bombardeio Preparado mesmo depois de se mover.")
	return result

## Multiplicador do ATAQUE BÁSICO contra `defender` por características de quem ataca (bônus
## contra tipo de unidade). Combina MULTIPLICANDO bônus de origens diferentes (o +50% do
## Lanceiro V1 e o das Técnicas passivas V2 são coisas distintas); a mesma origem nunca
## conta duas vezes. Não entra aqui dano de cidade, de feitiço nem de efeito de mapa.
static func attack_multiplier(attacker: Unit, defender: Unit) -> float:
	var kind := attacker.unit_data.visual_kind
	var target := defender.unit_data.visual_kind
	var result := command_multiplier(attacker)
	result *= V2TechniqueRuntime.attack_multiplier(attacker, defender) # Técnicas passivas V2 (Preparar Lanças...)
	result *= low_hp_attack_multiplier(attacker, defender) # passiva intrínseca V2 (Execução)
	result *= trait_attack_multiplier(attacker, defender) # passiva intrínseca V2 (Caçada Lendária)
	if kind in ["lanceiro", "halberdier"] and is_mounted(defender.unit_data):
		result *= 1.5
	if kind == "besteiro" and target in ARMORED:
		result *= 1.3
	if kind == "cavaleiro_de_choque" and attacker.movement_left < attacker.unit_data.movement_points:
		result *= 1.25
	return result

## Passiva intrínseca de UnitData (`low_hp_attack_*`, Fase 7 — Execução): 1 + bônus se o HP do ALVO está no limiar
## ou abaixo dele (comparação `<=`: exatamente 50% conta), 1.0 caso contrário ou se o atacante não tem a passiva.
## Só unidade contra unidade (predict); dano de cidade/feitiço nunca passa por aqui.
static func low_hp_attack_multiplier(attacker: Unit, defender: Unit) -> float:
	var data := attacker.unit_data
	if data.low_hp_attack_bonus <= 0.0 or defender.unit_data.max_hp <= 0.0:
		return 1.0
	return 1.0 + data.low_hp_attack_bonus if defender.hp / defender.unit_data.max_hp <= data.low_hp_attack_threshold else 1.0

## Texto do efeito da passiva a partir do dado ("+30% de Ataque contra unidades com 50% de HP ou menos.").
static func low_hp_attack_effect_text(data: UnitData) -> String:
	return "+%d%% de Ataque contra unidades com %d%% de HP ou menos." % [int(round(data.low_hp_attack_bonus * 100.0)), int(round(data.low_hp_attack_threshold * 100.0))]

## Como cada traço de alvo aparece no texto da passiva ("+40% de Ataque contra Unidades Lendárias."); sem entrada, o próprio id.
const TRAIT_TARGET_LABELS := {"legendary": "Unidades Lendárias", "mounted": "unidades montadas"}

## Passiva intrínseca de UnitData (`trait_attack_*`, Fase 8 — Caçada Lendária): 1 + bônus se o alvo tem QUALQUER traço da lista
## (uma vez, mesmo com vários traços casando), 1.0 caso contrário ou se o atacante não tem a passiva. Só unidade contra unidade
## (predict); identifica o alvo pelo TRAÇO (`legendary`), nunca por id/nome. Combina multiplicando com os demais fatores.
static func trait_attack_multiplier(attacker: Unit, defender: Unit) -> float:
	var data := attacker.unit_data
	if data.trait_attack_bonus <= 0.0:
		return 1.0
	for trait_id in data.trait_attack_target_traits:
		if defender.unit_data.has_trait(trait_id):
			return 1.0 + data.trait_attack_bonus
	return 1.0

## "+40% de Ataque contra Unidades Lendárias." a partir do dado.
static func trait_attack_effect_text(data: UnitData) -> String:
	var labels: Array[String] = []
	for trait_id in data.trait_attack_target_traits:
		labels.append(TRAIT_TARGET_LABELS.get(trait_id, trait_id))
	return "+%d%% de Ataque contra %s." % [int(round(data.trait_attack_bonus * 100.0)), " ou ".join(labels)]

## Linhas da passiva por traço pro painel da própria unidade: "Passiva Lendária — Caçada Lendária" e o efeito abaixo.
static func trait_attack_lines(unit: Unit) -> Array[String]:
	var result: Array[String] = []
	if unit == null or unit.unit_data == null or not unit.unit_data.has_trait_attack_bonus():
		return result
	var prefix := "Passiva Lendária" if unit.unit_data.has_trait(UnitData.TRAIT_LEGENDARY) else "Passiva"
	result.append("%s — %s" % [prefix, unit.unit_data.trait_attack_name])
	result.append(trait_attack_effect_text(unit.unit_data))
	return result

## Todas as linhas de passivas intrínsecas de ATAQUE da unidade (Execução por HP do alvo, Caçada por traço do alvo).
static func intrinsic_attack_lines(unit: Unit) -> Array[String]:
	var result: Array[String] = low_hp_attack_lines(unit)
	result.append_array(trait_attack_lines(unit))
	return result

## Linhas da passiva pro painel da própria unidade: "Passiva Lendária — Execução" e o efeito abaixo. [] sem a passiva.
static func low_hp_attack_lines(unit: Unit) -> Array[String]:
	var result: Array[String] = []
	if unit == null or unit.unit_data == null or not unit.unit_data.has_low_hp_attack_bonus():
		return result
	var prefix := "Passiva Lendária" if unit.unit_data.has_trait(UnitData.TRAIT_LEGENDARY) else "Passiva"
	result.append("%s — %s" % [prefix, unit.unit_data.low_hp_attack_name])
	result.append(low_hp_attack_effect_text(unit.unit_data))
	return result

## Subclassificação SÓ do V1 (Fase 11 — auditoria: kinds LITERAIS que antecedem o sistema de traços da Fase 10) com bônus
## MAIOR de ataque contra cidade/covil; ficou como estava (nenhum destes 3 nomes é reaproveitado por uma unidade V2 real —
## a Bombarda/Colosso de Cerco V2 têm `visual_kind` diferente, ver limitação de nomes repetidos documentada nas Fases 7-11).
const SIEGE_HEAVY := ["ariete", "bombarda", "colosso_de_cerco"]

## Fonte ÚNICA de "esta unidade é uma máquina de Cerco" pro bônus INATO de ataque contra cidade/covil (Fase 11, auditoria da
## seção 15 do pedido): a lista V1 por `kind` (SIEGE, acima) OU o traço `siege` do dado (UnitData.TRAIT_SIEGE, semeado por
## UnitDatabase de UMA das duas formas — nunca as duas contando em separado para a mesma unidade). Uma máquina de Cerco V2
## real só precisa declarar o traço para herdar o MESMO bônus "padrão" (1.5×) que a Catapulta V1 já tinha; o comportamento
## V1 (inclusive o bônus MAIOR de SIEGE_HEAVY, por kind) permanece byte a byte igual a antes desta fase.
static func city_attack_multiplier(unit: Unit) -> float:
	var kind := unit.unit_data.visual_kind
	var is_siege := kind in SIEGE or unit.unit_data.has_trait(UnitData.TRAIT_SIEGE)
	var bonus := 2.0 if kind in SIEGE_HEAVY else (1.5 if is_siege else 1.0)
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

static func description(kind: String) -> String:
	match kind:
		"general": return "Comando: aliados a até 2 hexágonos recebem +25% de ataque e defesa. Não acumula."
		"engenheiro_de_cerco": return "Repara 25% da vida de máquinas de cerco adjacentes por turno. Não acumula."
		"lanceiro", "halberdier": return "+50% de ataque contra cavalaria."
		"besteiro": return "+30% de ataque contra unidades blindadas."
		"cavaleiro_de_choque": return "+25% de ataque depois de se mover neste turno."
		"torre_de_cerco": return "Ataques contra cidades ignoram o escudo das muralhas."
		"catapult": return "Cerco: +50% de dano contra cidades; 30% de dano nos inimigos adjacentes ao alvo."
		"ariete", "bombarda", "colosso_de_cerco": return "+100% de dano contra cidades."
		"balista", "trebuchet": return "+50% de dano contra cidades."
	return ""

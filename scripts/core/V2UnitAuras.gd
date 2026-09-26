class_name V2UnitAuras
extends RefCounted

## Auras INTRÍNSECAS de unidade (Aetherlands V2, Fase 6) — habilidades da PRÓPRIA unidade, dirigidas
## por dado (UnitData.aura_*), diferentes de Técnica de Doutrina (essas vêm de pesquisa). Comando Defensivo
## do Campeão Guardião (Fase 6, +20%) e Presença Sagrada do Serafim (Fase 17, +15%), ambos raio 2.
##
## Por POSIÇÃO REAL, nunca um buff guardado: consulta na hora do cálculo defensivo
## (CombatResolver.predict) — o aliado que sai do raio perde o bônus, ao voltar recebe. Sem _process.
## Custo local: só as unidades da PRÓPRIA civilização (não o mapa), uma comparação de raio cada.
##
## REGRAS: (1) a aura NÃO afeta quem a emite; (2) só aliados do MESMO dono; (3) emissor vivo;
## (4) auras defensivas NÃO acumulam entre si — vale só o MAIOR bônus aplicável, seja de dois emissores da
## mesma aura, seja de auras diferentes (Fase 17: Campeão +20% e Serafim +15% sobre o mesmo aliado = +20%,
## nunca +38% nem +35%; antes da Fase 17 só existia uma aura, então a regra "auras diferentes multiplicam"
## nunca tinha sido exercida e foi trocada por esta); (5) a aura (uma origem) multiplica normalmente com
## origens DIFERENTES — Muralha de Escudos, Égide Sagrada, terreno, veterania, Tensão.

## Multiplicador de Defesa de `defender` vindo de auras de unidades aliadas; 1.0 se nenhuma.
static func defense_multiplier(defender: Unit) -> float:
	if defender == null or defender.owner_player == null:
		return 1.0
	var best := 0.0
	for ally in defender.owner_player.units:
		if ally == defender or ally.unit_data == null:
			continue
		var data: UnitData = ally.unit_data
		if data.aura_radius <= 0 or data.aura_defense_bonus <= best or ally.hp <= 0.0:
			continue
		if HexMetrics.axial_distance(ally.coord, defender.coord) > data.aura_radius:
			continue
		best = data.aura_defense_bonus
	return 1.0 + best

## O texto do efeito de uma aura, montado do dado ("Aliados em raio 2 recebem +20% de Defesa.").
static func effect_text(data: UnitData) -> String:
	return "Aliados em raio %d recebem +%d%% de Defesa." % [data.aura_radius, int(round(data.aura_defense_bonus * 100.0))]

## Linhas da aura da própria unidade pro painel (só o dono): "Passiva Lendária — Comando Defensivo" e o
## efeito abaixo. [] se a unidade não tem aura.
static func lines(unit: Unit) -> Array[String]:
	var result: Array[String] = []
	if unit == null or unit.unit_data == null or not unit.unit_data.has_aura():
		return result
	var prefix := "Passiva"
	if unit.unit_data.has_trait(UnitData.TRAIT_LEGENDARY):
		prefix = "Passiva Lendária"
	elif unit.unit_data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION):
		prefix = "Passiva da Manifestação"
	result.append("%s — %s" % [prefix, unit.unit_data.aura_name])
	result.append(effect_text(unit.unit_data))
	return result

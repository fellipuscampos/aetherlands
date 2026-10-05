class_name MonsterHabitatProfile
extends RefCounted

## V3 / Etapa 4 — HABITAT ecológico data-driven. Dá lógica à DISTRIBUIÇÃO das 12 espécies sem refazer biomas nem o
## gerador: cada espécie tem pesos sobre sinais de terreno que JÁ existem no mapa, avaliados na composição LOCAL
## (raio 2 em volta da âncora, o tile central conta em dobro), e o planner sorteia a âncora entre candidatos válidos
## com peso pelo score (MonsterEcologyPlanner.habitat_anchor) — probabilístico, nunca "espécie só no terreno X".
##
## Sinais disponíveis (auditados): tipo de terreno (bioma), recurso do tile ("mana_node" = Nódulo Arcano; outros
## recursos = valor), água em volta (Oceano/Costa/Mar Gelado), Colinas/Montanhas (relevo), distância às capitais.
## NÃO existem no mapa: ruínas, rios, umidade/temperatura guardadas por tile, elevação contínua por tile — nenhum
## sinal é inventado. Floresta/Selva/Taiga = vegetação densa; Planície/Pradaria = terra aberta fértil ("civilizável").
##
## Custo: só no setup e na reposição (nunca por frame/turno de monstro). Sinais estáticos em cache por coordenada.

const RADIUS := 2
const MANA_RESOURCE := "mana_node"
## Raio de interesse do Nódulo Arcano para o Devorador de Mana (1 até d=1, cai 0,25 por tile).
const MANA_REACH := 4

## Contribuição de cada terreno para os sinais de fração local (0..1).
const TERRAIN_SIGNALS := {
	HexTileData.TerrainType.FOREST: {"forest": 1.0, "fertile": 0.4},
	HexTileData.TerrainType.JUNGLE: {"forest": 1.0, "fertile": 0.5},
	HexTileData.TerrainType.TAIGA: {"forest": 1.0, "cold": 0.35},
	HexTileData.TerrainType.GRASSLAND: {"open": 1.0, "fertile": 1.0},
	HexTileData.TerrainType.PLAINS: {"open": 1.0, "fertile": 0.8},
	HexTileData.TerrainType.SAVANNA: {"open": 1.0, "arid": 0.45},
	HexTileData.TerrainType.DESERT: {"open": 1.0, "arid": 1.0},
	HexTileData.TerrainType.TUNDRA: {"open": 1.0, "cold": 0.7},
	HexTileData.TerrainType.SNOW: {"open": 1.0, "cold": 1.0},
	HexTileData.TerrainType.ICE: {"cold": 1.0},
	HexTileData.TerrainType.HILLS: {"rugged": 1.0},
	HexTileData.TerrainType.MOUNTAINS: {"rugged": 1.0},
	HexTileData.TerrainType.OCEAN: {"water": 1.0},
	HexTileData.TerrainType.COAST: {"water": 1.0},
	HexTileData.TerrainType.FROZEN_OCEAN: {"water": 1.0, "cold": 0.5},
}
const FRACTION_SIGNALS: Array[String] = ["forest", "open", "fertile", "arid", "cold", "rugged", "water"]

## Pesos por espécie (positivos somam ~1; negativos afastam). Sinais derivados: edge = mistura floresta/aberto (borda
## de floresta), variety = transições entre famílias de terreno, mana = proximidade de Nódulo Arcano, resource = recurso
## por perto, remote = longe de toda capital. V3 COMBAT ECOLOGY PLACEHOLDER — TUNE LATER.
const PROFILES := {
	"goblin": {"edge": 0.35, "fertile": 0.35, "forest": 0.2, "water": 0.1, "cold": -0.7, "arid": -0.6},
	"skeleton": {"arid": 0.35, "cold": 0.3, "open": 0.2, "rugged": 0.15, "forest": -0.5, "fertile": -0.3},
	"worg": {"forest": 0.35, "edge": 0.35, "open": 0.3, "arid": -0.5, "water": -0.2},
	"giant_spider": {"forest": 0.75, "water": 0.15, "edge": 0.1, "open": -0.3, "arid": -0.6, "cold": -0.3},
	"troll": {"rugged": 0.45, "forest": 0.25, "water": 0.15, "resource": 0.15, "arid": -0.4},
	"wyvern": {"rugged": 0.65, "open": 0.2, "cold": 0.15, "forest": -0.4, "water": -0.1},
	"minotaur": {"open": 0.5, "variety": 0.3, "fertile": 0.2, "forest": -0.5, "rugged": -0.3},
	"basilisk": {"arid": 0.5, "rugged": 0.35, "open": 0.15, "forest": -0.5, "water": -0.3, "fertile": -0.2},
	"colossal_worm": {"arid": 0.8, "open": 0.2, "forest": -0.6, "water": -0.4, "rugged": -0.3, "cold": -0.4},
	"arboreal_ancient": {"forest": 0.9, "fertile": 0.1, "open": -0.4, "arid": -0.6, "cold": -0.2},
	"mana_devourer": {"mana": 0.75, "remote": 0.25},
	"corrupted_hero": {"fertile": 0.4, "forest": 0.35, "water": 0.25, "arid": -0.6, "cold": -0.5}, # provisório: herdado da Colmeia
}

## Seleção: janela de candidatos válidos avaliados por espécie; sem nenhum >= GOOD_SCORE, a janela dobra (fallback
## progressivo) até WINDOW_MAX. Peso do sorteio = max(score, MIN_WEIGHT)^SHARPNESS (agrupa sem ser determinístico).
## Escolha com score < FALLBACK_SCORE conta como fallback (habitat ideal insuficiente no mapa/seed).
const WINDOW := 24
const WINDOW_MAX := 96
const GOOD_SCORE := 0.4
const FALLBACK_SCORE := 0.25
const SHARPNESS := 3.0
const MIN_WEIGHT := 0.03
## Distância às capitais para "remote": 0 até REMOTE_NEAR, 1 a partir de REMOTE_NEAR + REMOTE_SPAN.
const REMOTE_NEAR := 10
const REMOTE_SPAN := 20

static func profile_for(kind: String) -> Dictionary:
	var id := String(MonsterEcologyData.SPECIES.get(kind, {}).get("habitat_profile", kind))
	return PROFILES.get(id if id != "" else kind, {})

## Coordenadas dos Nódulos Arcanos do mapa (uma varredura; setup/reposição).
static func mana_coords(grid: HexGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coord in grid.tiles:
		if (grid.tiles[coord] as HexTileData).resource == MANA_RESOURCE:
			result.append(coord)
	return MonsterEcologyPlanner.sorted_coords(result)

## Sinais ESTÁTICOS da região de `coord` (composição local + Nódulo Arcano + recurso por perto).
static func features(grid: HexGrid, coord: Vector2i, mana: Array[Vector2i]) -> Dictionary:
	var sums := {}
	for key in FRACTION_SIGNALS:
		sums[key] = 0.0
	var weight_total := 0.0
	var resources := 0
	var families := {}
	for near in [coord, coord] + HexMetrics.coords_within(coord, RADIUS):
		var tile: HexTileData = grid.tiles.get(near)
		if tile == null:
			continue
		weight_total += 1.0
		if near != coord and tile.resource != "":
			resources += 1
		var signals: Dictionary = TERRAIN_SIGNALS.get(tile.terrain_type, {})
		for key in signals:
			sums[key] = float(sums[key]) + float(signals[key])
		var family := _family(signals)
		if family != "":
			families[family] = true
	var result := {}
	for key in FRACTION_SIGNALS:
		result[key] = float(sums[key]) / weight_total if weight_total > 0.0 else 0.0
	result.edge = 1.0 - absf(2.0 * float(result.forest) - 1.0) if float(result.forest) > 0.0 else 0.0
	result.variety = clampf(float(families.size() - 1) / 3.0, 0.0, 1.0)
	result.resource = clampf(float(resources) / 2.0, 0.0, 1.0)
	var mana_distance := 999
	for node in mana:
		mana_distance = mini(mana_distance, HexMetrics.axial_distance(node, coord))
	result.mana = clampf(1.0 - float(maxi(mana_distance - 1, 0)) * 0.25, 0.0, 1.0) if mana_distance <= MANA_REACH else 0.0
	return result

static func _family(signals: Dictionary) -> String:
	var best := ""
	var best_value := 0.0
	for key in ["forest", "arid", "cold", "rugged", "water", "fertile"]:
		if float(signals.get(key, 0.0)) > best_value:
			best_value = float(signals[key])
			best = key
	return best

## "Longe das capitais" (dinâmico: depende das âncoras de fairness do momento).
static func remote_value(coord: Vector2i, anchors: Array[Vector2i]) -> float:
	if anchors.is_empty():
		return 1.0
	var nearest := 999999
	for anchor in anchors:
		nearest = mini(nearest, HexMetrics.axial_distance(anchor, coord))
	return clampf(float(nearest - REMOTE_NEAR) / float(REMOTE_SPAN), 0.0, 1.0)

## Suitability 0..1 da espécie para uma região (sinais estáticos + remote).
static func score(kind: String, feats: Dictionary, remote: float = 0.0) -> float:
	var total := 0.0
	var profile := profile_for(kind)
	for key in profile:
		var value := remote if key == "remote" else float(feats.get(key, 0.0))
		total += float(profile[key]) * value
	return clampf(total, 0.0, 1.0)

static func selection_weight(value: float) -> float:
	return pow(maxf(value, MIN_WEIGHT), SHARPNESS)

## Sorteio ponderado (RNG da ecologia) entre `scores`; devolve o índice escolhido.
static func roulette(scores: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for value in scores:
		total += selection_weight(float(value))
	var roll := rng.randf() * total
	var acc := 0.0
	for i in scores.size():
		acc += selection_weight(float(scores[i]))
		if roll < acc:
			return i
	return scores.size() - 1

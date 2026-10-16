class_name NatureBiomeProfiles
extends RefCounted

## Perfil ecológico de vegetação por bioma (HexTileData.TerrainType) — DADO puro consumido por NatureComposer. O kit
## é de floresta temperada (carvalho, faia, pinheiro, aveleira, sub-bosque, tronco caído, pedra com raiz); cada bioma
## usa o subconjunto e as proporções que fazem sentido para ele, e biomas onde o kit não pertence (neve, deserto, gelo,
## vulcânico, cristal, místico, montanha, água) simplesmente não têm perfil.
##
## Campos de um perfil:
##   forest            — bioma florestal (participa da transição de borda floresta/campo e de clareiras).
##   coverage          — chance base de o tile ter vegetação; o ruído de densidade (bosques x campos abertos) modula.
##   main_trees        — Vector2i(min, max) de árvores de copa no tile em densidade plena.
##   small_trees       — Vector2i(min, max) de árvores jovens (regeneração, borda de mata).
##   shrubs            — Vector2i(min, max) de arbustos de sub-bosque.
##   log_chance        — chance de um tronco caído (floresta madura).
##   rocks             — Vector2i(min, max) de pedras com raiz.
##   species           — peso de cada espécie de COPA ("oak", "beech", "pine"); árvores jovens herdam a família
##                       (folhosa -> carvalho jovem, conífera -> pinheiro jovem).
##   conifer_stands    — o ruído de espécie forma manchas de pinheiral dentro do bioma (ex.: Floresta mista).
##   shrub_weights     — peso de cada asset de arbusto.
##   tint / tint_jitter— cor multiplicada na instância (clima/umidade do bioma) e variação individual.
##   scale             — faixa de escala uniforme (o README do kit recomenda 0.85–1.12; jovens e campos usam menos).

const FOREST_TYPES: Array[int] = [HexTileData.TerrainType.FOREST, HexTileData.TerrainType.TAIGA, HexTileData.TerrainType.JUNGLE]

const PROFILES := {
	# Floresta temperada mista: carvalho/faia dominantes, manchas de pinheiral, sub-bosque e chão de mata madura.
	HexTileData.TerrainType.FOREST: {
		"forest": true, "coverage": 0.94,
		"main_trees": Vector2i(2, 4), "small_trees": Vector2i(0, 2), "shrubs": Vector2i(1, 3), "log_chance": 0.28, "rocks": Vector2i(0, 1),
		"species": {"oak": 0.52, "beech": 0.36, "pine": 0.12}, "conifer_stands": true,
		"shrub_weights": {"shrub_hazel": 0.55, "shrub_bracken": 0.45},
		"tint": Color(1.0, 1.0, 1.0), "tint_jitter": 0.06, "scale": Vector2(0.88, 1.12),
	},
	# Taiga boreal: pinheiral denso, muita regeneração de pinheiro jovem, sub-bosque ralo, pedras; verde mais frio.
	HexTileData.TerrainType.TAIGA: {
		"forest": true, "coverage": 0.88,
		"main_trees": Vector2i(2, 4), "small_trees": Vector2i(1, 3), "shrubs": Vector2i(0, 1), "log_chance": 0.22, "rocks": Vector2i(0, 2),
		"species": {"pine": 0.92, "beech": 0.08}, "conifer_stands": false,
		"shrub_weights": {"shrub_bracken": 0.75, "shrub_hazel": 0.25},
		"tint": Color(0.86, 0.94, 0.92), "tint_jitter": 0.05, "scale": Vector2(0.9, 1.12),
	},
	# Selva: folhosas fechadas (sem coníferas), sub-bosque muito denso, troncos caídos frequentes; verde saturado.
	HexTileData.TerrainType.JUNGLE: {
		"forest": true, "coverage": 0.97,
		"main_trees": Vector2i(3, 4), "small_trees": Vector2i(1, 2), "shrubs": Vector2i(2, 4), "log_chance": 0.35, "rocks": Vector2i(0, 0),
		"species": {"oak": 0.55, "beech": 0.45}, "conifer_stands": false,
		"shrub_weights": {"shrub_bracken": 0.6, "shrub_hazel": 0.4},
		"tint": Color(0.82, 1.0, 0.76), "tint_jitter": 0.06, "scale": Vector2(0.95, 1.12),
	},
	# Planície: campo aberto com árvores isoladas e moitas — só onde o ruído forma bosquetes.
	HexTileData.TerrainType.GRASSLAND: {
		"forest": false, "coverage": 0.22,
		"main_trees": Vector2i(0, 1), "small_trees": Vector2i(0, 1), "shrubs": Vector2i(1, 2), "log_chance": 0.0, "rocks": Vector2i(0, 1),
		"species": {"oak": 0.7, "beech": 0.3}, "conifer_stands": false,
		"shrub_weights": {"shrub_hazel": 0.7, "shrub_bracken": 0.3},
		"tint": Color(1.0, 1.0, 1.0), "tint_jitter": 0.05, "scale": Vector2(0.85, 1.05),
	},
	# Estepe: seca e aberta — arbustos e pedras, árvore jovem rara; tom amarelado.
	HexTileData.TerrainType.PLAINS: {
		"forest": false, "coverage": 0.14,
		"main_trees": Vector2i(0, 0), "small_trees": Vector2i(0, 1), "shrubs": Vector2i(1, 2), "log_chance": 0.0, "rocks": Vector2i(0, 1),
		"species": {"oak": 1.0}, "conifer_stands": false,
		"shrub_weights": {"shrub_hazel": 0.4, "shrub_bracken": 0.6},
		"tint": Color(1.0, 0.94, 0.76), "tint_jitter": 0.05, "scale": Vector2(0.8, 1.0),
	},
	# Savana: árvores isoladas e baixas sobre capim seco.
	HexTileData.TerrainType.SAVANNA: {
		"forest": false, "coverage": 0.18,
		"main_trees": Vector2i(0, 1), "small_trees": Vector2i(0, 1), "shrubs": Vector2i(0, 2), "log_chance": 0.0, "rocks": Vector2i(0, 1),
		"species": {"oak": 1.0}, "conifer_stands": false,
		"shrub_weights": {"shrub_hazel": 0.5, "shrub_bracken": 0.5},
		"tint": Color(1.0, 0.9, 0.68), "tint_jitter": 0.05, "scale": Vector2(0.82, 1.0),
	},
	# Colinas: afloramentos de pedra, arbustos e pinheiros esparsos nas encostas.
	HexTileData.TerrainType.HILLS: {
		"forest": false, "coverage": 0.34,
		"main_trees": Vector2i(0, 1), "small_trees": Vector2i(0, 2), "shrubs": Vector2i(0, 2), "log_chance": 0.0, "rocks": Vector2i(1, 2),
		"species": {"pine": 0.7, "oak": 0.3}, "conifer_stands": false,
		"shrub_weights": {"shrub_bracken": 0.6, "shrub_hazel": 0.4},
		"tint": Color(0.95, 0.97, 0.92), "tint_jitter": 0.05, "scale": Vector2(0.85, 1.05),
	},
	# Tundra: quase sem árvores — pedras e arbustos rasteiros, pinheiro jovem raro; tom frio.
	HexTileData.TerrainType.TUNDRA: {
		"forest": false, "coverage": 0.16,
		"main_trees": Vector2i(0, 0), "small_trees": Vector2i(0, 1), "shrubs": Vector2i(0, 1), "log_chance": 0.0, "rocks": Vector2i(1, 2),
		"species": {"pine": 1.0}, "conifer_stands": false,
		"shrub_weights": {"shrub_bracken": 1.0},
		"tint": Color(0.84, 0.9, 0.86), "tint_jitter": 0.04, "scale": Vector2(0.75, 0.95),
	},
}

## Transição floresta -> campo (ecótono): um tile aberto vizinho de floresta ganha cobertura extra e árvores jovens /
## arbustos do lado da mata; um tile de floresta na borda rarefaz do lado aberto.
const FRINGE_COVERAGE_PER_FOREST_NEIGHBOR := 0.14
const FRINGE_SMALL_TREES := Vector2i(1, 2)
const FOREST_EDGE_THINNING := 0.6 # fração das árvores de copa mantida no tile de floresta mais exposto

## Clareiras: abaixo deste valor do ruído de densidade, um tile florestal vira clareira (só sub-bosque e chão).
const CLEARING_DENSITY := 0.16

static func profile(terrain_type: int) -> Dictionary:
	return PROFILES.get(terrain_type, {})

static func has_vegetation(terrain_type: int) -> bool:
	return PROFILES.has(terrain_type)

static func is_forest(terrain_type: int) -> bool:
	return terrain_type in FOREST_TYPES

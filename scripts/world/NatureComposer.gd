class_name NatureComposer
extends RefCounted

## Composição ecológica da vegetação de UM tile (regra pura, sem render): decide QUAIS assets do kit
## (NatureKitCatalog), QUANTOS, ONDE dentro do hexágono, com que escala, rotação e tintura. NatureDecorManager só
## desenha o resultado. Determinístico: o mesmo mapa (seed) e o mesmo tile dão a mesma composição — gerar, salvar e
## carregar, ou recompor um tile cujo terreno mudou, nunca "sorteia" outra floresta.
##
## Camadas de decisão, da escala do mapa para a do tile:
##   1. Bioma (NatureBiomeProfiles): estratos, espécies, tintura e escala que fazem sentido para ele.
##   2. Ruído de DENSIDADE (baixa frequência, em coordenadas de mundo): bosques fechados x clareiras na floresta,
##      bosquetes x campo aberto nos biomas abertos — regiões contínuas, não moeda tile a tile.
##   3. Ruído de ESPÉCIE: manchas de pinheiral / faial dentro da floresta mista (talhões coerentes entre vizinhos).
##   4. Ecótono: campo vizinho de floresta ganha árvores jovens e arbustos do lado da mata (com a família de espécie
##      da floresta vizinha); floresta de borda rarefaz e recua do lado aberto.
##   5. Dentro do tile: ordem ecológica (copa -> árvores jovens -> tronco caído -> arbustos -> pedras), cada peça com
##      distância mínima pelo raio de copa do manifesto, inteira dentro do hexágono e com o centro livre para a
##      unidade/cidade (copa e tronco caído não ocupam o miolo).

const SQRT3_HALF := 0.8660254 # apótema do hexágono pointy-top de raio 1 (círculo inscrito)
const EDGE_MARGIN := 0.02     # margem do README do kit para a silhueta não encostar na borda
const CENTER_CLEARING := 0.24 # miolo livre de copas/troncos (onde fica a unidade ou a cidade)
const CANOPY_SPACING := 0.8   # copas podem se tocar levemente (dossel fechado), nunca se atravessar
const UNDERSTORY_SPACING := 0.6
const MAX_ATTEMPTS := 24
const DENSITY_FREQUENCY := 0.085
const SPECIES_FREQUENCY := 0.06
const CONIFER_STAND := 0.68   # ruído de espécie acima disto: talhão de pinheiro
const BEECH_STAND := 0.3      # abaixo disto: faial

const BROADLEAF := ["oak", "beech"]
const MAIN_TREE_BY_SPECIES := {"oak": ["tree_oak_a", "tree_oak_b"], "beech": ["tree_beech_a"], "pine": ["tree_pine_a"]}

## Campos de ruído do MAPA (um par por seed). Criados uma vez por reconstrução.
static func make_fields(map_seed: int) -> Dictionary:
	var density := FastNoiseLite.new()
	density.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	density.seed = map_seed
	density.frequency = DENSITY_FREQUENCY
	density.fractal_octaves = 2
	var species := FastNoiseLite.new()
	species.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	species.seed = map_seed + 7919
	species.frequency = SPECIES_FREQUENCY
	species.fractal_octaves = 1
	return {"density": density, "species": species, "seed": map_seed}

static func _noise01(noise: FastNoiseLite, world_xz: Vector2) -> float:
	return clampf((noise.get_noise_2d(world_xz.x, world_xz.y) + 1.0) * 0.5, 0.0, 1.0)

## `context`: {coord: Vector2i, terrain: int, has_resource: bool, world_xz: Vector2, hex_size: float,
##             neighbors: Array[{terrain: int, dir: Vector2 (normalizado, do centro para o vizinho)}],
##             density/species: float opcionais que substituem o ruído (0..1)}
## Devolve Array de {asset, local: Vector2 (XZ relativo ao centro), angle, scale, tint: Color}.
static func compose_tile(context: Dictionary, fields: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var terrain: int = context.terrain
	var profile := NatureBiomeProfiles.profile(terrain)
	if profile.is_empty() or bool(context.get("has_resource", false)):
		return result
	var coord: Vector2i = context.coord
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(fields.seed), coord.x, coord.y, "nature"])
	var world_xz: Vector2 = context.world_xz
	var hex_size: float = context.hex_size
	# `density`/`species` no contexto fixam os campos (testes e ferramentas); em jogo vêm do ruído do mapa.
	var density := float(context.density) if context.has("density") else _noise01(fields.density, world_xz)
	var species_noise := float(context.species) if context.has("species") else _noise01(fields.species, world_xz)
	var is_forest := bool(profile.forest)

	# Vizinhança: lados de floresta (para o campo) e lados abertos (para a floresta).
	var forest_dir := Vector2.ZERO
	var open_dir := Vector2.ZERO
	var forest_neighbors := 0
	var open_neighbors := 0
	var neighbor_conifer := 0.0
	for neighbor in context.get("neighbors", []):
		if NatureBiomeProfiles.is_forest(int(neighbor.terrain)):
			forest_neighbors += 1
			forest_dir += neighbor.dir
			neighbor_conifer += 1.0 if int(neighbor.terrain) == HexTileData.TerrainType.TAIGA else 0.0
		else:
			open_neighbors += 1
			open_dir += neighbor.dir

	# Cobertura: floresta quase sempre; campo só onde o ruído forma bosquete, reforçado perto da mata.
	var coverage: float = profile.coverage
	if not is_forest:
		coverage = coverage * lerpf(0.35, 1.7, density) + NatureBiomeProfiles.FRINGE_COVERAGE_PER_FOREST_NEIGHBOR * forest_neighbors
	if rng.randf() >= clampf(coverage, 0.0, 1.0):
		return result

	var clearing := is_forest and density < NatureBiomeProfiles.CLEARING_DENSITY
	var fullness := lerpf(0.65, 1.0, density) if is_forest else 1.0
	var main_count := 0 if clearing else _count(rng, profile.main_trees, fullness)
	var small_count := _count(rng, profile.small_trees, fullness if not clearing else 0.6)
	var shrub_count := _count(rng, profile.shrubs, 1.0)
	var rock_count := _count(rng, profile.rocks, 1.0)
	var log_count := 1 if rng.randf() < float(profile.log_chance) * (1.6 if clearing else 1.0) else 0

	# Borda de floresta: menos copas do lado exposto e recuo para o interior.
	var interior_bias := Vector2.ZERO
	if is_forest and open_neighbors > 0:
		main_count = int(round(main_count * lerpf(1.0, NatureBiomeProfiles.FOREST_EDGE_THINNING, open_neighbors / 6.0)))
		interior_bias = (-open_dir).normalized() if open_dir.length() > 0.01 else Vector2.ZERO
	# Ecótono: campo encostado na mata recebe regeneração do lado da floresta.
	var fringe_bias := Vector2.ZERO
	var fringe_small := 0
	if not is_forest and forest_neighbors > 0:
		fringe_small = _count(rng, NatureBiomeProfiles.FRINGE_SMALL_TREES, minf(1.0, forest_neighbors / 3.0))
		fringe_bias = forest_dir.normalized() if forest_dir.length() > 0.01 else Vector2.ZERO

	var weights := _stand_weights(profile, species_noise)
	var placed: Array[Dictionary] = []
	for i in main_count:
		var tree_species := _weighted_pick(rng, weights)
		var options: Array = MAIN_TREE_BY_SPECIES.get(tree_species, MAIN_TREE_BY_SPECIES["oak"])
		_try_place(rng, placed, String(options[rng.randi_range(0, options.size() - 1)]), profile, hex_size, CENTER_CLEARING, interior_bias)
	for i in small_count:
		var family := _weighted_pick(rng, weights)
		_try_place(rng, placed, "tree_oak_young" if family in BROADLEAF else "tree_pine_young", profile, hex_size, CENTER_CLEARING * 0.6, interior_bias)
	for i in fringe_small:
		var conifer_fringe := neighbor_conifer > forest_neighbors * 0.5
		_try_place(rng, placed, "tree_pine_young" if conifer_fringe else "tree_oak_young", profile, hex_size, CENTER_CLEARING * 0.6, fringe_bias)
	for i in log_count:
		_try_place(rng, placed, "fallen_log", profile, hex_size, CENTER_CLEARING, interior_bias)
	for i in shrub_count:
		_try_place(rng, placed, _weighted_pick(rng, profile.shrub_weights), profile, hex_size, 0.0, fringe_bias)
	for i in rock_count:
		_try_place(rng, placed, "rock_root_small", profile, hex_size, 0.0, Vector2.ZERO)

	for item in placed:
		result.append(item)
	return result

## Pesos de espécie de copa do tile: o perfil do bioma, deslocado pelo ruído de espécie em talhões coerentes.
static func _stand_weights(profile: Dictionary, species_noise: float) -> Dictionary:
	var weights: Dictionary = (profile.species as Dictionary).duplicate()
	if bool(profile.conifer_stands):
		if species_noise > CONIFER_STAND:
			weights["pine"] = float(weights.get("pine", 0.0)) + 1.6
		elif species_noise < BEECH_STAND:
			weights["beech"] = float(weights.get("beech", 0.0)) * 2.4
	return weights

static func _count(rng: RandomNumberGenerator, span: Vector2i, fullness: float) -> int:
	if span.y <= 0:
		return 0
	return int(round(lerpf(float(span.x), float(span.y), rng.randf()) * fullness))

static func _weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += maxf(float(weights[key]), 0.0)
	var roll := rng.randf() * total
	for key in weights:
		roll -= maxf(float(weights[key]), 0.0)
		if roll <= 0.0:
			return String(key)
	return String(weights.keys()[0])

## Uma peça: amostra posições dentro do círculo inscrito do hexágono até achar uma que respeite a borda, o miolo livre
## e a distância às peças já postas; `bias` (unitário ou zero) favorece um lado do tile. Sem lugar: a peça é omitida
## (densidade se ajusta ao espaço, nunca sobrepõe).
static func _try_place(rng: RandomNumberGenerator, placed: Array[Dictionary], asset: String, profile: Dictionary, hex_size: float, min_center: float, bias: Vector2) -> void:
	var span: Vector2 = profile.scale
	var item_scale := rng.randf_range(span.x, span.y)
	var radius := NatureKitCatalog.footprint(asset) * item_scale * hex_size
	var max_center := SQRT3_HALF * hex_size - radius - EDGE_MARGIN * hex_size
	if max_center < min_center * hex_size:
		return
	var category := NatureKitCatalog.category(asset)
	var canopy := category == NatureKitCatalog.MAIN_TREE or category == NatureKitCatalog.SMALL_TREE
	for attempt in MAX_ATTEMPTS:
		var angle := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * max_center
		var local := Vector2(cos(angle), sin(angle)) * dist
		if dist < min_center * hex_size:
			continue
		if bias != Vector2.ZERO and dist > 0.001 and rng.randf() > 0.5 + 0.5 * local.normalized().dot(bias):
			continue
		if not _fits(placed, local, radius, canopy):
			continue
		var tint: Color = profile.tint
		var jitter := rng.randf_range(-float(profile.tint_jitter), float(profile.tint_jitter))
		placed.append({
			"asset": asset, "local": local, "angle": rng.randf() * TAU, "scale": item_scale, "radius": radius,
			"canopy": canopy,
			"tint": Color(clampf(tint.r * (1.0 + jitter), 0.0, 1.0), clampf(tint.g * (1.0 + jitter), 0.0, 1.0), clampf(tint.b * (1.0 + jitter), 0.0, 1.0), 1.0),
		})
		return

static func _fits(placed: Array[Dictionary], local: Vector2, radius: float, canopy: bool) -> bool:
	for other in placed:
		var spacing := CANOPY_SPACING if canopy and bool(other.canopy) else UNDERSTORY_SPACING
		if local.distance_to(other.local) < (radius + float(other.radius)) * spacing:
			return false
	return true

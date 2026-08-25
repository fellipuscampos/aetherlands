class_name HexTileData
extends Resource

## Alem dos 12 biomas originais, 4 tipos novos (pedido do usuario: "quero
## que tenha rios, mares, biomas de gelo... bioma de lava, algum outra
## bioma de fantasia"): FROZEN_OCEAN (variante polar do Oceano, "os
## mares"), ICE (bioma de terra firme mais extremo que Neve), LAVA (bioma
## vulcanico raro, hostil) e CRYSTAL (Campos de Cristal, bioma arcano
## original, tematica de fantasia — combina com Torre Arcana/Mago). Ver
## HexGrid._generate_tile_data/_pick_biome pra como cada um aparece no mapa.
##
## LAVA_SEA (roadmap item 32, pedido do usuario: "pegar o sistema de
## oceano que temos e fazer um igual so que vermelho num bioma com aquele
## solo vulcanico") — o nucleo mais "quente" de uma regiao de Lava vira
## um corpo liquido de verdade, reusando o MESMO shader/animacao de onda
## do Oceano (HexGrid._rebuild_multimesh/_material_kind_for), so
## vermelho/emissivo em vez de azul. Mar Gelado ja seguia esse padrao
## (variante do Oceano); Mar de Lava e o mesmo padrao pra Lava.
enum TerrainType {
	OCEAN, SNOW, TUNDRA, TAIGA, DESERT, SAVANNA, JUNGLE, PLAINS,
	GRASSLAND, FOREST, HILLS, MOUNTAINS,
	FROZEN_OCEAN, ICE, LAVA, CRYSTAL, LAVA_SEA,
	## Microbiomas dos continentes Vulcanico/de Cristal (pedido do usuario:
	## "os novos continentes ficaram visualmente e taticamente simplórios
	## por serem blocos homogêneos/monobioma... precisamos aplicar a eles o
	## mesmo nivel de complexidade, relevo e variacao de microbiomas que o
	## Continente Principal possui") — todos CAMINHAVEIS (ao contrario de
	## LAVA/LAVA_SEA acima, que continuam sendo o unico obstaculo/perigo de
	## verdade em cada continente especial). Ver HexGrid._generate_tile_data
	## pra como cada um se encaixa na decisao em camadas (elevacao ->
	## litoral -> ruido) dentro da zona Vulcanica/de Cristal.
	VOLCANIC_ROCK, # "Terra Vulcanica" — base caminhavel dominante do Vulcanico, substitui o antigo "100% Lava"
	VOLCANIC_HILLS, # "Colinas Vulcanicas" — elevacao MEDIA (elevation_tier HILLS na zona Vulcanica), relevo 3D real (cupula, ver elevation_kind) entre a base e os Picos
	VOLCANIC_PEAKS, # "Montanhas Vulcanicas" — cordilheira central (elevation_tier MOUNTAINS na zona Vulcanica)
	VOLCANIC_ASH, # "Solo de Cinzas" — faixa costeira/periferica do Vulcanico
	CRYSTAL_PEAKS, # "Picos de Cristal" — cordilheira central (elevation_tier HILLS/MOUNTAINS na zona de Cristal)
	MYSTIC_SOIL, # "Solo Mistico" — base caminhavel dominante do Cristal / faixa costeira
	MYSTIC_SPRING, # "Fonte Mistica" — feature rara de "recursos fluidos" (ruido bem alto, sem reintroduzir rio)
	## Agua rasa encostada em terra firme (pedido do usuario: "Coast" tipo
	## Civilization) — nunca nasce direto do ruido de elevacao como Oceano;
	## HexGrid._reclassify_coastal_ocean converte OCEAN pra COAST num passo
	## de pos-processamento, depois que TODOS os tiles ja existem (saber
	## "sou vizinho de terra" exige conhecer os vizinhos, que so existem
	## depois da geracao inteira rodar uma vez). Mar Gelado NAO ganha um
	## equivalente "Costa Gelada" de proposito — ja rende 0/0/0 (tematica
	## "gelado demais pra pescar"), uma variante de costa nao mudaria nada.
	COAST,
}

@export var terrain_type: TerrainType = TerrainType.GRASSLAND
@export var display_name: String = "Planicie"
@export var movement_cost: int = 1
@export var defense_bonus: float = 0.0
@export var food_yield: int = 0
@export var production_yield: int = 0
@export var gold_yield: int = 0
@export var base_height: float = 0.0
@export var color: Color = Color.WHITE

## "" = sem recurso. Ver ResourceDatabase — recurso estrategico/luxo
## espalhado deterministicamente por HexGrid durante a geracao do mapa, da
## bonus de rendimento quando o tile e trabalhado (City.collect_yields).
@export var resource: String = ""

## Agua de verdade (Oceano comum, Mar Gelado OU Costa) — unidade que nao
## voa (UnitData.flies) nunca consegue pisar aqui (ver blocks_land_units()
## abaixo pro conjunto completo de terrenos intransitaveis). Mar de Lava
## NAO conta como agua aqui de proposito (e lava, nao agua) — ver is_lava()
## pra esse par. Costa AINDA bloqueia unidades terrestres igual Oceano —
## a diferenca dela e so poder ser TRABALHADA por uma cidade (ver
## can_be_worked() abaixo), nao andavel.
func is_water() -> bool:
	return terrain_type == TerrainType.OCEAN or terrain_type == TerrainType.FROZEN_OCEAN or terrain_type == TerrainType.COAST

## Lava de verdade (pedra vulcanica solida OU Mar de Lava liquido) — os
## dois bloqueiam unidade terrestre e nunca sao atravessados por rio de
## AGUA (ver HexGrid._lowest_unvisited_neighbor), mesmo par que
## is_water() faz pra Oceano/Mar Gelado.
func is_lava() -> bool:
	return terrain_type == TerrainType.LAVA or terrain_type == TerrainType.LAVA_SEA

## Terreno que nenhuma unidade terrestre consegue pisar: agua (is_water())
## e Lava (is_lava()) tambem — usado por HexGrid.compute_reachable
## (unidade que voa ignora isso), City.is_valid_building_tile/
## _best_unassigned_neighbor/toggle_worked_tile, WorldSetup (spawn/
## capital) e HUD (lista de "tiles trabalhados"). Centralizado aqui pra
## nao repetir a mesma lista de tipos em 6+ lugares diferentes do
## codebase.
func blocks_land_units() -> bool:
	return is_water() or is_lava()

## Uma cidade consegue TRABALHAR este tile (ver City._best_unassigned_
## neighbor/toggle_worked_tile) pra receber o rendimento dele? Terreno
## solido comum sempre pode; agua/lava normalmente nao (blocks_land_units),
## EXCETO Costa — pesca rasa perto da cidade, pedido do usuario ("rendimento
## de cidade costeira, igual Civilization"). Oceano aberto/Mar Gelado/Mar
## de Lava continuam intrabalhaveis (sem porto/tecnologia pra isso neste
## jogo ainda). Deliberadamente SEPARADO de blocks_land_units() — esse
## continua so sobre MOVIMENTO de unidade terrestre (Costa AINDA bloqueia
## isso, so nao bloqueia ser trabalhada).
func can_be_worked() -> bool:
	return not blocks_land_units() or terrain_type == TerrainType.COAST

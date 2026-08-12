class_name TerrainDatabase
extends RefCounted

## Fabrica de dados de terreno. Em uma proxima etapa isto pode virar
## recursos .tres editaveis no editor, sem mudar quem consome HexTileData.
static func create_tile(terrain_type: int) -> HexTileData:
	var data := HexTileData.new()
	data.terrain_type = terrain_type
	match terrain_type:
		HexTileData.TerrainType.OCEAN:
			data.display_name = "Oceano"
			data.movement_cost = 1
			data.food_yield = 1
			data.production_yield = 0
			data.gold_yield = 1
			data.base_height = -0.3
			data.color = Color(0.13, 0.35, 0.62)
		HexTileData.TerrainType.SNOW:
			data.display_name = "Neve"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.05
			data.color = Color(0.92, 0.94, 0.97)
		HexTileData.TerrainType.TUNDRA:
			data.display_name = "Tundra"
			data.movement_cost = 1
			data.food_yield = 1
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.04
			data.color = Color(0.58, 0.6, 0.52)
		HexTileData.TerrainType.TAIGA:
			data.display_name = "Taiga"
			data.movement_cost = 2
			data.food_yield = 1
			data.production_yield = 2
			data.gold_yield = 0
			data.defense_bonus = 0.25
			data.base_height = 0.15
			data.color = Color(0.14, 0.32, 0.28)
		HexTileData.TerrainType.DESERT:
			data.display_name = "Deserto"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 1
			data.base_height = 0.0
			data.color = Color(0.82, 0.71, 0.45)
		HexTileData.TerrainType.SAVANNA:
			data.display_name = "Savana"
			data.movement_cost = 1
			data.food_yield = 2
			data.production_yield = 0
			data.gold_yield = 1
			data.base_height = 0.01
			data.color = Color(0.68, 0.62, 0.32)
		HexTileData.TerrainType.JUNGLE:
			data.display_name = "Selva"
			data.movement_cost = 2
			data.food_yield = 2
			data.production_yield = 1
			data.gold_yield = 0
			data.defense_bonus = 0.25
			data.base_height = 0.1
			data.color = Color(0.08, 0.32, 0.14)
		HexTileData.TerrainType.PLAINS:
			data.display_name = "Estepe"
			data.movement_cost = 1
			data.food_yield = 1
			data.production_yield = 1
			data.gold_yield = 0
			data.base_height = 0.02
			data.color = Color(0.58, 0.56, 0.32)
		HexTileData.TerrainType.GRASSLAND:
			data.display_name = "Planicie"
			data.movement_cost = 1
			data.food_yield = 3
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.02
			data.color = Color(0.36, 0.62, 0.28)
		HexTileData.TerrainType.FOREST:
			data.display_name = "Floresta"
			data.movement_cost = 2
			data.food_yield = 1
			data.production_yield = 2
			data.gold_yield = 0
			data.defense_bonus = 0.25
			data.base_height = 0.12
			data.color = Color(0.16, 0.4, 0.18)
		HexTileData.TerrainType.HILLS:
			data.display_name = "Colinas"
			data.movement_cost = 2
			data.food_yield = 1
			data.production_yield = 2
			data.gold_yield = 0
			data.defense_bonus = 0.5
			data.base_height = 0.3
			data.color = Color(0.55, 0.45, 0.3)
		HexTileData.TerrainType.MOUNTAINS:
			data.display_name = "Montanhas"
			data.movement_cost = 3
			data.food_yield = 0
			data.production_yield = 1
			data.gold_yield = 0
			data.defense_bonus = 1.0
			data.base_height = 0.65
			data.color = Color(0.45, 0.44, 0.46)
		HexTileData.TerrainType.FROZEN_OCEAN:
			# Variante polar do Oceano ("os mares", pedido do usuario) — mesma
			# agua, so mais fria/menos farta (sem peixe de graca) e SEM a
			# animacao de onda do shader (HexGrid._rebuild_multimesh so liga
			# is_water=1 pro Oceano comum), pra "ler" como parada/congelada.
			data.display_name = "Mar Gelado"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = -0.28
			data.color = Color(0.75, 0.85, 0.9)
		HexTileData.TerrainType.ICE:
			# Mais extremo que Neve: nada cresce, nada rende, so existe pra
			# marcar o polo de verdade — Neve continua sendo a faixa "fria mas
			# habitavel", Gelo Eterno e a faixa "fria demais pra qualquer
			# coisa" (ver HexGrid._pick_biome).
			data.display_name = "Gelo Eterno"
			data.movement_cost = 2
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.06
			data.color = Color(0.8, 0.9, 0.95)
		HexTileData.TerrainType.LAVA:
			# Bioma vulcanico raro (ver HexGrid._generate_tile_data/
			# _maybe_volcanic): pode nascer em QUALQUER terra firme, nao so
			# Colina/Montanha (roadmap item 30, pedido do usuario: "e ser um
			# bioma terrestre tal qual qualquer outro"), entao a maioria dos
			# tiles de Lava agora vem de terreno originalmente PLANO —
			# base_height mais baixo que antes (era 0.55, nivel de Montanha)
			# pra nao parecer um monte de blocos flutuando no meio de uma
			# planicie. Intransitavel pra unidade terrestre
			# (HexTileData.blocks_land_units), entao nenhuma cidade consegue
			# trabalha-lo — yield fica zerado de proposito (nao ha como
			# coletar), so o defense_bonus fica pra eventual uso futuro (ex:
			# se um dia houver unidade resistente a lava).
			data.display_name = "Lava"
			data.movement_cost = 99
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.1
			data.color = Color(0.85, 0.25, 0.05)
		HexTileData.TerrainType.CRYSTAL:
			# Campos de Cristal: bioma arcano original (nao sugerido pelo
			# usuario, "aprofundar a tematica de fantasia" como fez sentido),
			# raro e disperso (ver HexGrid._generate_tile_data), tematicamente
			# ligado a Torre Arcana/Mago. Ouro alto recompensa explorar/se
			# assentar perto, sem comida (nada cresce entre os cristais).
			data.display_name = "Campos de Cristal"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 2
			data.gold_yield = 3
			data.base_height = 0.08
			data.color = Color(0.58, 0.4, 0.82)
		HexTileData.TerrainType.LAVA_SEA:
			# Mar de Lava (roadmap item 32, pedido do usuario: "pegar o
			# sistema de oceano que temos e fazer um igual so que vermelho"):
			# o nucleo mais quente de uma regiao de Lava (ver
			# HexGrid._maybe_volcanic) — mesmo shader/animacao de onda do
			# Oceano (HexGrid._rebuild_multimesh liga is_water/animate_waves
			# igual, `_material_kind_for` devolve 5 pro shader saber tingir
			# de vermelho/emissivo em vez do azul padrao). base_height um
			# pouco mais baixo que a pedra de Lava (0.1) pra ler como uma
			# depressao onde a lava se acumula, nao um bloco solido igual.
			# Intransitavel/sem yield, mesma logica de Lava (pedra).
			data.display_name = "Mar de Lava"
			data.movement_cost = 99
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.05
			data.color = Color(1.0, 0.32, 0.03)
		HexTileData.TerrainType.COAST:
			# Agua rasa perto de terra firme (pedido do usuario, "Coast" tipo
			# Civilization) — nunca nasce aqui direto, ver HexGrid._reclassify_
			# coastal_ocean (converte OCEAN pra COAST no pos-processamento).
			# Pesca mais farta perto da costa (comida 2, contra o 1 do Oceano
			# aberto) e continua podendo ser TRABALHADA por uma cidade (ver
			# HexTileData.can_be_worked — Oceano aberto/Mar Gelado nao podem,
			# sem porto/tecnologia pra isso neste jogo ainda). base_height/
			# color sao vestigiais pra renderizacao (o plano de agua usa UM
			# shader so, water_shader.gdshader, que decide raso/fundo pela
			# profundidade real via DEPTH_TEXTURE, nao por estes campos —
			# mesma situacao de Oceano/Mar Gelado ja hoje), mantidos so por
			# consistencia com o resto da tabela.
			data.display_name = "Costa"
			data.movement_cost = 1
			data.food_yield = 2
			data.production_yield = 0
			data.gold_yield = 1
			data.base_height = -0.2
			data.color = Color(0.18, 0.55, 0.68)
	return data

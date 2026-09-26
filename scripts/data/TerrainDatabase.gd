class_name TerrainDatabase
extends RefCounted

## Fabrica de dados de terreno. Em uma proxima etapa isto pode virar
## recursos .tres editaveis no editor, sem mudar quem consome HexTileData.
##
## movement_cost e 1 pra TODO terreno de proposito (pedido do usuario: "tire
## o peso do terreno... faca todo terreno ter peso 1") -- Colinas/Floresta/
## Taiga/Selva/Montanhas/Picos ja foram 2 ou 3 antes disso; comentarios mais
## antigos abaixo que ainda mencionam esses numeros sao so contexto
## historico do porque cada bioma existe, nao refletem mais o custo real.
## Lava/Mar de Lava tambem cairam pra 1 (eram 99, um valor so simbolico --
## unidade terrestre ja nao entra ali de jeito nenhum via
## HexTileData.blocks_land_units(), e unidade voadora sempre pagou 1.0 fixo
## por tile independente de movement_cost, ver HexGrid.gd -- 99 nunca teve
## efeito de jogo nenhum, so ficava esquisito numa tabela agora uniforme).
## Passabilidade (o que BLOQUEIA unidade terrestre) continua controlada
## separadamente por HexTileData.blocks_land_units() -- Oceano/Mar Gelado/
## Costa/Lava/Mar de Lava continuam intransitaveis pra terrestre, so o
## CUSTO de andar em cima de terreno permitido deixou de variar.
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
			data.movement_cost = 1
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
			data.movement_cost = 1
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
			data.movement_cost = 1
			data.food_yield = 1
			data.production_yield = 2
			data.gold_yield = 0
			data.defense_bonus = 0.25
			data.base_height = 0.12
			data.color = Color(0.16, 0.4, 0.18)
		HexTileData.TerrainType.HILLS:
			data.display_name = "Colinas"
			data.movement_cost = 1
			data.food_yield = 1
			data.production_yield = 2
			data.gold_yield = 0
			data.defense_bonus = 0.5
			data.base_height = 0.3
			data.color = Color(0.55, 0.45, 0.3)
		HexTileData.TerrainType.MOUNTAINS:
			data.display_name = "Montanhas"
			data.movement_cost = 1
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
			data.movement_cost = 1
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
			# base_height REBAIXADO (regressao reportada pelo usuario: "leitura
			# visual 3D ficou pessima... nao ha contraste de... elevacao" — Lava
			# solida agora fica visivelmente AFUNDADA/em fenda, abaixo do nivel
			# de caminhada de Terra Vulcanica/Solo de Cinzas, lendo como canal
			# de rocha derretida em vez de mais um bloco plano igual ao resto).
			data.display_name = "Lava"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = -0.05
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
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.05
			data.color = Color(1.0, 0.32, 0.03)
		HexTileData.TerrainType.VOLCANIC_ROCK:
			# Base caminhavel DOMINANTE do continente Vulcanico (pedido do
			# usuario: "em vez de ser 100% lava, estruture o solo em Terra
			# Vulcanica/Basalto como terreno base walking-friendly").
			# Regressao reportada pelo usuario ("mesmo material de basalto
			# preto para tudo... nao ha contraste de cor"): mat_kind 3
			# (HexGrid._material_kind_for) escurece o tint MUITO (multiplica
			# por textura de rocha E por 0.6, ver terrain.gdshader) — um tint
			# quase preto igual antes virava indistinguivel de Montanhas
			# Vulcanicas/Lava. Cor bem mais clara/saturada aqui (obsidiana
			# arroxeada) pra sobrar contraste de verdade depois do
			# escurecimento do shader. base_height = "nivel de caminhada"
			# de referencia da zona (Solo de Cinzas/Colinas/Picos sao
			# definidos RELATIVOS a este).
			data.display_name = "Terra Vulcanica"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 1
			data.gold_yield = 1
			data.base_height = 0.1
			data.color = Color(0.32, 0.26, 0.28)
		HexTileData.TerrainType.VOLCANIC_HILLS:
			# "Colinas Vulcanicas" — elevacao MEDIA (pedido do usuario apos
			# regressao "leitura visual 3D pessima... sem contraste de
			# elevacao": "Colinas Vulcanicas: nivel de elevacao medio,
			# adicione variacao de altura 3D"). Mesma faixa de custo/altura
			# de Colinas normal, ganha CUPULA de verdade (elevation_kind=1,
			# ver HexGrid._build_terrain_multimesh/terrain.gdshader
			# elevation_height) — relevo 3D real, nao so um numero de
			# altura mais alto. Cor mais quente/avermelhada que Terra
			# Vulcanica pura, sugerindo fluxo de lava ja solidificado.
			data.display_name = "Colinas Vulcanicas"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 2
			data.gold_yield = 1
			data.defense_bonus = 0.5
			data.base_height = 0.3
			data.color = Color(0.4, 0.24, 0.2)
		HexTileData.TerrainType.VOLCANIC_PEAKS:
			# "Espinha dorsal" do continente Vulcanico (pedido do usuario:
			# "gere cordilheiras de Montanhas Vulcanicas no centro") — mesma
			# faixa de custo/defesa/altura de Montanhas normal (mesmo
			# tratamento visual de cupula/pico, ver HexGrid.gd onde
			# elevation_kind e atribuido — o shader ja exclui neve pra
			# mat_kind 3, ver terrain.gdshader). Cor mais ESCURA que Terra
			# Vulcanica/Colinas (o pico mais extremo/queimado da zona), mas
			# ainda longe de preto puro pra nao se perder contra Terra
			# Vulcanica depois do escurecimento do shader — a CUPULA em si
			# (relevo, nao cor) e o principal sinal visual de "isto e pico".
			data.display_name = "Montanhas Vulcanicas"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 1
			data.gold_yield = 1
			data.defense_bonus = 1.0
			data.base_height = 0.65
			data.color = Color(0.2, 0.16, 0.17)
		HexTileData.TerrainType.VOLCANIC_ASH:
			# Faixa costeira/periferica do continente Vulcanico (pedido do
			# usuario: "adicione zonas de Solo de Cinzas/Rocha Negra nas
			# bordas e praias... mude para um tom CINZA-CLARO/GRAFITE...
			# criara um contraste imediato"). Reusa a formula de Deserto
			# (mat_kind 2 — textura granulada/dunas, SEM o escurecimento
			# ×0.6 que mat_kind 3/rocha aplica, ver HexGrid._material_kind_
			# for) com tint CLARO — da uma textura de po/cinza vulcanica
			# genuina, visualmente BEM diferente da rocha solida (Terra
			# Vulcanica/Colinas/Picos/Lava, todas mat_kind 3), nao so uma
			# variacao de cor sobre a MESMA textura. Levemente mais BAIXO
			# que Terra Vulcanica (praia descendo suave rumo a agua/lava).
			data.display_name = "Solo de Cinzas"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 1
			data.gold_yield = 2
			data.base_height = 0.04
			data.color = Color(0.88, 0.86, 0.84)
		HexTileData.TerrainType.CRYSTAL_PEAKS:
			# "Espinha dorsal" do continente de Cristal (pedido do usuario:
			# "gere Picos/Montanhas de Cristal no interior") — mesma faixa
			# de custo/defesa/altura de Montanhas normal (mesmo tratamento
			# visual de cupula/pico), mas ganha o brilho/textura animada de
			# Cristal (ver HexGrid._material_kind_for) e ouro alto (cristal
			# concentrado nos picos vale mais que nos campos abertos).
			data.display_name = "Picos de Cristal"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 1
			data.gold_yield = 4
			data.defense_bonus = 1.0
			data.base_height = 0.65
			data.color = Color(0.68, 0.52, 0.88)
		HexTileData.TerrainType.MYSTIC_SOIL:
			# Base caminhavel dominante do continente de Cristal (pedido do
			# usuario: "Solo Mistico/Grama Arcana/Vegetacao Cristalina nas
			# regioes mais baixas e costeiras") — Campos de Cristal denso
			# continua reservado ao interior/nucleo (ver HexGrid.
			# _generate_tile_data), este e a periferia mais amena, fertil
			# o bastante pra sustentar alguma lavoura magica.
			data.display_name = "Solo Mistico"
			data.movement_cost = 1
			data.food_yield = 2
			data.production_yield = 1
			data.gold_yield = 1
			data.base_height = 0.08
			data.color = Color(0.55, 0.72, 0.6)
		HexTileData.TerrainType.MYSTIC_SPRING:
			# "Recursos fluidos" do continente de Cristal (pedido do
			# usuario: "integre rios/fontes de agua pura ou fluido arcano
			# cortando o continente" — sem reintroduzir o sistema de rio
			# removido antes nesta sessao, vira uma mancha rara de ruido
			# bem alto em vez de uma feature linear, ver HexGrid.
			# _generate_tile_data). Caminhavel de proposito (ao contrario
			# dos Lagos de Magma do Vulcanico) — fonte convidativa, nao
			# perigo; ouro alto representa o valor do fluido arcano em si.
			data.display_name = "Fonte Mistica"
			data.movement_cost = 1
			data.food_yield = 1
			data.production_yield = 0
			data.gold_yield = 3
			data.base_height = 0.05
			data.color = Color(0.4, 0.85, 0.9)
		HexTileData.TerrainType.COAST:
			# Agua rasa perto de terra firme (pedido do usuario, "Coast" tipo
			# Civilization) — nunca nasce aqui direto, ver HexGrid._reclassify_
			# coastal_ocean (converte OCEAN pra COAST no pos-processamento).
			# Pesca mais farta perto da costa (comida 2, contra o 1 do Oceano
			# aberto) e continua podendo ser TRABALHADA por uma cidade (ver
			# HexTileData.is_usable_land — Oceano aberto/Mar Gelado nao podem,
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

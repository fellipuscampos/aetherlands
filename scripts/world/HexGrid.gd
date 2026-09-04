class_name HexGrid
extends Node3D

## Gera um mapa hexagonal 3D real (prismas gerados por codigo, sem depender
## de modelos externos) usando MultiMeshInstance3D para desenhar milhares
## de tiles com uma unica draw call. Tambem administra ocupacao (unidades e
## cidades por tile), pathfinding de movimento e fog of war.

const NEIGHBOR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

enum Visibility { UNSEEN, EXPLORED, VISIBLE }

## Pack ice/icebergs pequenos flutuando no Mar Gelado (pedido do usuario,
## Ponto 2 — "se possivel... micro-icebergs flutuantes" — ver
## _build_ice_floe_mesh/_rebuild_props abaixo). Azul-ciano claro e fosco
## (pedido do usuario, 3a rodada: a tonalidade anterior, quase branca pura,
## lia como "isopor" — esta tem saturacao de azul suficiente pra ler como
## gelo, mesma familia de cor do frozen_tint do shader de agua em vez de um
## branco neutro) — sao pedacos de gelo solido de verdade, nao a superficie
## liquida gelada por baixo.
const ICE_FLOE_BASE_COLOR := Color(0.75, 0.88, 0.95)

## Refatoracao de nevoa de guerra (pedido do usuario: 3 estados visuais
## distintos em vez de escurecimento direto) — props (arvores/pedras/picos)
## usam StandardMaterial3D simples sem shader custom, entao o tom sepia/
## dessaturado do estado EXPLORED e calculado aqui em GDScript (ver
## _sepia_prop_color), espelhando o mesmo tratamento que terrain.gdshader
## aplica por pixel pro terreno solido (fog_explored_tint/desaturate/darken).
const PROP_SEPIA_TINT := Color(0.55, 0.48, 0.36)
const PROP_SEPIA_DESATURATE := 0.6
const PROP_SEPIA_DARKEN := 0.4

## Espelha peak_height de terrain.gdshader (default do uniform) — usado por
## _tile_surface_height pra saber a altura VISUAL real do centro de uma
## Montanha (base_height + o pico do shader), sem precisar ser
## pixel-perfeito (o shader ainda soma um ruido de quebra por cima que o
## GDScript nao replica aqui — so precisa ficar proximo o bastante).
const MOUNTAIN_PEAK_HEIGHT := 0.9
## Espelha hill_height de terrain.gdshader (mesmo motivo do par acima) —
## usado por _tile_surface_height pra saber a altura VISUAL real do centro
## de uma Colina, nao so base_height cru.
const HILL_HEIGHT := 0.35

## Mapa retangular (pedido do usuario, com numeros exatos de referencia:
## "Pequeno: 74x46... Medio: 84x54... Grande: 96x60"), nao mais um
## losango/hexagono de raio unico — ver TitleScreen.MAP_SIZES pros tres
## tamanhos oficiais e generate_map() pro algoritmo de geracao (linhas
## offset "odd-r" convertidas pra axial, formato padrao de mapa hex
## retangular tipo Civilization).
@export var map_width: int = 25
@export var map_height: int = 25
@export var hex_size: float = 1.0

## Reescrita da geracao (era so uma unica _noise de elevacao sem mascara de
## borda nenhuma — o mapa inteiro virava terra, "uma unica grande massa de
## terra retangular" com biomas em retalhos por cima, exatamente o problema
## reportado). Agora elevacao = ruido de continente (baixa frequencia,
## formas grandes) DISTORCIDO por um ruido de warp (litoral organico, sem
## cara de "curva de nivel") MENOS uma mascara de borda que empurra as
## bordas do mapa pra oceano (ver _elevation_for/_edge_falloff/_warp_world
## abaixo). Todos ajustaveis no Inspector sem editar o script.
@export_group("Geracao de Terreno")
## Frequencia do ruido que desenha continentes/ilhas. Mais baixo = poucos
## continentes GRANDES; mais alto = mais ilhas/arquipelagos pequenos e
## numerosos. Baixado de 0.035 (pedido do usuario: mapa estava saindo
## "arquipelago denso" — ~74% agua medido empiricamente — e sufocando
## expansao terrestre; ver OCEAN_ELEVATION_THRESHOLD abaixo pro outro lado
## do ajuste). Frequencia mais baixa da litorais mais lisos/organicos e
## continentes maiores, o que junto com o novo limiar deixa a maior parte
## da terra conectada numa unica massa continua em vez de fragmentada.
@export var continent_noise_frequency: float = 0.028
## Quanto a mascara de borda puxa a elevacao pra baixo perto das bordas do
## mapa. 0 desliga a mascara (volta ao bug antigo: ruido cru preenchendo o
## retangulo inteiro); 1 garante borda 100% oceano mesmo se o ruido cru
## estivesse no pico ali.
@export_range(0.0, 1.0, 0.01) var edge_falloff_strength: float = 0.6
## A partir de que fracao da distancia ao centro (0 = centro do mapa, 1 =
## borda) a mascara comeca a agir. Mais baixo = continentes menores e mais
## concentrados no meio; mais alto = terra pode chegar mais perto da borda
## antes do oceano comecar.
@export_range(0.0, 0.95, 0.01) var edge_falloff_start: float = 0.25
## Frequencia/forca do ruido de distorcao (domain warp) aplicado as
## coordenadas do mundo antes de amostrar elevacao/umidade/vulcanico/
## arcano — sem isso, litorais e fronteiras de bioma acompanham exatamente
## as curvas de nivel do ruido base (reconhecivel como "ruido de
## computador", nao geografia). Mesmo campo de warp reaplicado em todos
## esses ruidos de proposito: os contornos de cada um se distorcem JUNTOS
## em vez de brigarem entre si com warps desalinhados.
@export var warp_frequency: float = 0.06
@export var warp_strength: float = 6.0
@export var moisture_noise_frequency: float = 0.02
@export var temperature_jitter_frequency: float = 0.35
@export var volcanic_noise_frequency: float = 0.015
@export var arcane_noise_frequency: float = 0.025

var tiles: Dictionary = {} # Vector2i(q, r) -> HexTileData
var units_by_coord: Dictionary = {} # Vector2i -> Unit
var cities_by_coord: Dictionary = {} # Vector2i -> City
var buildings_by_coord: Dictionary = {} # Vector2i -> Building (predio POSICIONADO, ver Building.gd)
var visibility: Dictionary = {} # Vector2i -> Visibility
var map_seed: int = 0 # guardado pra Salvar/Carregar recriar o mesmo terreno

## Coords onde um Covil de Monstro esta ATIVO nesta partida (ver
## _spawn_monster_lairs) — a colocacao inicial e 100% deterministica pela
## map_seed, igual terreno/recursos, mas um coord sai desta lista pra
## sempre quando destroy_lair() e chamado (jogador entrou no tile sem
## defensor, ver move_unit/_grant_lair_clear_reward) — dali em diante o
## covil nunca mais reforca nem aparece no mapa. Ver cleared_lair_coords
## pra como isso sobrevive a Salvar/Carregar.
var lair_coords: Array[Vector2i] = []

## Vector2i -> String ("goblin"/"troll"/"wyvern") — qual tipo de monstro
## cada covil produz, pra process_monster_lairs() saber o que gerar de
## reforco ao redor. Nao precisa ser salvo (SaveManager): so importa
## enquanto o mapa atual existe, e generate_map() recria tudo do zero com
## a mesma semente de qualquer forma.
var lair_kind_by_coord: Dictionary = {}

## Vector2i -> LairStructure — o prop 3D do covil (tenda/caverna/ossario/
## etc conforme o tipo, ver LairStructure.build), independente da Unit
## guardia. Existe do momento em que o covil nasce (_spawn_monster_lairs)
## ate destroy_lair() ser chamado; nao precisa ser salvo (SaveManager),
## generate_map() recria do zero e cleared_lair_coords reconcilia depois.
var lairs_by_coord: Dictionary = {}

## Coords de covil destruidos (destroy_lair) NESTA partida — ao contrario
## de lair_coords/lair_kind_by_coord (recriados do zero deterministicamente
## a cada generate_map()), esta lista precisa ser salva (SaveManager) e
## reaplicada apos o load: generate_map() sempre respawna TODO covil da
## semente, entao sem reconciliar por cima um covil ja limpo "voltaria a
## vida" ao carregar. Mesmo padrao de generate_map()-recria-tudo-fresco +
## reconciliacao por cima que HexGrid.clear_neutral_units()/SaveManager.
## _deserialize_neutral_units ja usam pra unidades.
var cleared_lair_coords: Array[Vector2i] = []

var _hex_mesh: ArrayMesh
var _tree_mesh: ArrayMesh
var _ice_floe_mesh: ArrayMesh # pedaco de gelo baixo/chato flutuando no Mar Gelado, ver _build_ice_floe_mesh
var _multimesh_instance: MultiMeshInstance3D # terreno solido (terrain.gdshader) — continua 1 instancia de prisma por tile
## Agua (Oceano/Mar Gelado) E Mar de Lava agora dividem UM UNICO PlaneMesh
## continuo (water_shader.gdshader, shader unificado) — nao 2 planos
## sobrepostos (isso deixava o mapa "cortado ao meio" por sorting de
## transparencia entre os dois, reportado pelo usuario) nem 1 prisma por
## tile (isso dava "blocos de vidro" com fresta entre vizinhos, reportado
## antes). Qual bioma cada pixel do plano mostra vem de uma textura de
## mascara, ver _rebuild_water_overlay/_build_liquid_plane.
var _liquid_plane_instance: MeshInstance3D
var _props_tree_instance: MultiMeshInstance3D
var _props_ice_floe_instance: MultiMeshInstance3D
var _ground_body: StaticBody3D
var _selection_marker: MeshInstance3D
var _noise := FastNoiseLite.new() # elevacao/continentes — ver _elevation_for()
var _warp_noise := FastNoiseLite.new() # domain warp: distorce coordenadas antes de amostrar elevacao/umidade/vulcanico/arcano, pra formas organicas
var _coord_to_index: Dictionary = {} # so tiles de terreno solido (_multimesh_instance)
## Distancia (em tiles) de cada tile ate a terra solida mais proxima — ver
## _compute_coast_distance_tiles/_rebuild_water_overlay. Calculado UMA VEZ
## por geracao de mapa (a topologia terra/agua nunca muda depois), nao a
## cada _rebuild_water_overlay (isso rodaria a cada hover/selecao/turno,
## bem mais frequente que o necessario pra um dado estatico).
var _coast_distance_tiles: Dictionary = {}
## Textura de 1 texel-por-tile pra classificacao EXATA de Mar de Lava — ver
## _rebuild_lava_tile_mask.
var _lava_tile_mask_texture: ImageTexture
var _tree_coord_to_index: Dictionary = {}
var _ice_floe_coord_to_index: Dictionary = {}
## Props 3D de recurso (minerio/cavalos/gemas/seda, ver ResourceDatabase) —
## classe separada (nao mais campos soltos aqui) porque cada recurso
## precisa da sua PROPRIA malha/MultiMesh (uma por "tipo", igual arvore/
## pedra/pico), entao ResourcePropsManager encapsula essa colecao inteira
## em vez de HexGrid crescer mais 4 pares de MultiMeshInstance3D/Dictionary.
var _resource_props_manager: ResourcePropsManager
## Icones 2D billboard (placa + silhueta) flutuando sobre tiles com
## recurso, estilo Civilization — ver ResourceIconManager. Separado de
## _resource_props_manager de proposito: um e o objeto 3D no chao, o
## outro e o selo sempre virado pra camera; cada um so sabe desenhar/
## reconstruir a propria coisa.
var _resource_icon_manager: ResourceIconManager
## Agua/lava sao 1 MeshInstance3D continuo agora (sem instancia por tile)
## — fog-of-war/destaque de movimento (que antes tingiam a cor de cada
## instancia individualmente) viram esta textura compartilhada, amostrada
## pelo shader por posicao-mundo (ver _rebuild_water_overlay,
## water_shader.gdshader). RGB = brilho (fog/destaque); A = "esta
## congelado?" (Mar Gelado).
## pixel-index (py*res+px) -> coord axial, pra WATER_OVERLAY_RESOLUTION.
## Profiling real (usuario reportou "cai de 140 pra 15 fps ao passar
## turno") mostrou _rebuild_water_overlay sozinho custando ~180-250ms/
## chamada num mapa Grande com varias civs — a troca de Image.set_pixel por
## PackedByteArray (otimizacao anterior) so baratou a ESCRITA; o custo de
## verdade era HexMetrics.world_to_axial (varias operacoes de ponto
## flutuante + chamada de funcao) rodando 224*224=50176 vezes TODA
## chamada. Como a geometria da grade (half_extents/hex_size/resolucao) e
## FIXA depois de generate_map(), o mapeamento pixel->coord tambem e fixo
## — calculado UMA vez aqui (_ensure_water_overlay_coord_cache) e reusado
## em toda chamada seguinte via indexacao de array pura, sem nenhum
## world_to_axial repetido.
var _water_overlay_coord_cache: Array[Vector2i] = []
## Mesma ideia de _water_overlay_coord_cache, pra BIOME_OVERLAY_RESOLUTION.
var _biome_overlay_coord_cache: Array[Vector2i] = []
## Bytes RGBA de _water_overlay_texture pro caso SEM highlight nenhum
## (reachable/attackable/path/buildable todos vazios — o caso de
## recompute_fog/fim de turno) — nesse caso o tint fica sempre branco puro e
## so a transparencia de Mar Gelado (is_frozen, ESTATICO, nunca muda depois
## do mapa gerado) entra em jogo, entao o resultado e sempre IDENTICO entre
## chamadas. Calculado uma vez (junto do coord cache) e reusado direto sem
## reconstruir Image/ImageTexture nenhum turno em que nada esta destacado.
var _water_overlay_baseline_bytes: PackedByteArray = PackedByteArray()
## Textura pronta (Image+ImageTexture ja construidos) equivalente aos bytes
## acima — cacheada separada pra nem pagar o custo de Image.create_from_data/
## ImageTexture.create_from_image de novo no caso sem highlight.
var _water_overlay_baseline_texture: ImageTexture
## Bytes RGBA de _liquid_type_texture com R/G/B (lava/coast, ambos
## ESTATICOS — nunca mudam depois do mapa gerado) ja preenchidos e A=0 de
## placeholder — _rebuild_water_overlay duplica isto (memcpy rapido) e so
## sobrescreve o canal A (fog_level, o UNICO canal que muda de verdade a
## cada turno) em vez de recalcular lava/coast por pixel de novo.
var _liquid_type_static_bytes: PackedByteArray = PackedByteArray()
var _water_overlay_texture: ImageTexture
## Mascara global de cor de bioma pro terreno solido (mesma estrategia da
## agua, pedido do usuario) — RGB = cor de bioma do tile, JA com o
## escurecimento de fog-of-war embutido (pra nunca vazar cor de tile nao
## explorado pra perto da borda de um tile visivel). Ver
## _rebuild_biome_overlay/terrain.gdshader biome_overlay_texture.
var _biome_overlay_texture: ImageTexture
## Segunda textura, MESMA resolucao/mapeamento de UV que _water_overlay_
## texture: R = 0.0 (agua, inclui Mar Gelado) ou 1.0 (Mar de Lava) — o
## shader unificado usa isso pra decidir qual dos dois "modos" desenhar em
## cada pixel do plano continuo (ver _rebuild_water_overlay).
var _liquid_type_texture: ImageTexture
## Coords de terreno SOLIDO tingidas pela ultima chamada de set_highlight
## (uniao de reachable+attackable+path+buildable) — deixa clear_highlight/a
## PROXIMA set_highlight desfazer so ESSAS instancias (mm.set_instance_color
## de volta a tiles[coord].color) em vez de varrer o mapa INTEIRO (ate 5760
## tiles) so pra apagar um highlight de meia duzia de hexagonos. Ver
## _reset_highlighted_terrain/set_highlight/clear_highlight.
var _last_highlighted_land_coords: Array = []
var _units_root: Node3D
var _cities_root: Node3D
var _buildings_root: Node3D
var _construction_root: Node3D
var _lairs_root: Node3D
var _tints_root: Node3D
var _city_tints: Dictionary = {} # City -> MeshInstance3D, tingimento do chao do territorio (ver _update_city_tint)
## Cache do shader de tingimento — evita um load() do disco por CIDADE a
## CADA turno (_update_city_tint roda pra toda cidade toda vez que a nevoa
## muda). load() em si tem cache interno do Godot por caminho, mas ainda
## paga overhead de lookup/validacao a cada chamada; carregar uma vez so e
## estritamente mais barato e o Shader e imutavel (nunca precisa recarregar).
var _territory_tint_shader: Shader
var _construction_markers: Dictionary = {} # Vector2i -> Node3D, marcador animado de "em construcao" (ver refresh_construction_markers)
## Vector2i -> true, predios que ACABARAM de ser concluidos e cujo marcador
## esta na "volta de graca" (bara travada em 100%, ver refresh_construction_
## markers) antes de sumir de vez no PROXIMO refresh — pedido do usuario:
## "quando a barra chega em 90% a construção acaba", ou seja o marcador
## sumia no MESMO turno em que a producao empurrava alem do custo, entao o
## jogador nunca chegava a VER a barra cheia, so o ultimo valor do turno
## anterior (podia ser bem menos que 100%, dependendo do ritmo de producao
## vs custo do predio).
var _construction_markers_pending_removal: Dictionary = {}
## Vector2i -> turno em que a pilhagem expira (ver pillage_tile/
## is_tile_pillaged) — Invasor saqueando um tile trabalhado por cidade
## (MonsterAI._maybe_pillage_tile) zera o rendimento dele por um tempo
## (City.collect_yields). So cresce com o uso real (poucos tiles pilhados
## por partida) — sem limpeza ativa de entrada expirada, igual
## _construction_markers nao se preocupa em podar chaves antigas.
var _pillaged_tiles: Dictionary = {}
var _selection_time := 0.0
var _construction_time := 0.0 # sempre roda, diferente de _selection_time (so anda com unidade selecionada)
var _hover_label: Label3D
var _last_came_from: Dictionary = {} # Vector2i -> Vector2i, da ultima compute_reachable
var _moisture_noise := FastNoiseLite.new() # biomas: seco x umido
var _temp_jitter_noise := FastNoiseLite.new() # biomas: variacao local na faixa de temperatura
var _resource_noise := FastNoiseLite.new() # onde recursos estrategicos/luxo aparecem
var _volcanic_noise := FastNoiseLite.new() # bioma raro: Lava substituindo Montanhas
var _arcane_noise := FastNoiseLite.new() # bioma raro: Campos de Cristal

## Profundidade do prisma de TERRA firme, como fracao de hex_size — maior
## que o 0.4 padrao de _build_hex_prism_mesh (ver abaixo) de proposito:
## reportado pelo usuario, com screenshot, que
## costa de Colina/Montanha (base_height 0.3/0.65) parecia "cortada" na
## agua, sem base submersa nenhuma — o prisma antigo (fundo em base_height
## - hex_size*0.4) ficava ACIMA do plano de agua (LIQUID_LEVEL_Y = -0.2)
## bem nesses dois biomas especificamente (bioma "plano" comum, ate
## base_height ~0.15, ja tinha fundo bem abaixo da agua, sem bug — so
## Colina/Montanha nao). 1.0 garante fundo em base_height - hex_size, que
## pro pior caso (Montanha, base_height 0.65) da -0.35 — 0.15 abaixo do
## plano de agua, margem confortavel.
const LAND_PRISM_DEPTH_FACTOR := 1.0

## Arvore real (KayKit Forest Nature Pack, mesmo criador/ecossistema do
## KAYKIT_SCALE usado em Building.gd) substituindo o cone/cilindro
## procedural — pedido do usuario: "por que nao substituiu assets da
## natureza... arvores, e etc". A malha nativa mede ~4.16 de altura (Y);
## a arvore procedural antiga (_build_tree_mesh, removida) tinha ~0.88 de
## altura (tronco 0.3 + copa ate 0.22+0.55). 0.2 e o fator que aproxima a
## altura nova da antiga (0.2*4.16=~0.83), preservando a escala relativa
## ja calibrada entre arvore/predio/unidade no mapa.
const TREE_MODEL_SCENE := "res://assets/models/kaykit/nature/Tree_1_A_Color1.gltf"
const TREE_MODEL_SCALE := 0.2

func _ready() -> void:
	add_to_group("hex_grid")
	_hex_mesh = _build_hex_prism_mesh(hex_size, LAND_PRISM_DEPTH_FACTOR)
	_tree_mesh = _load_tree_mesh()
	_ice_floe_mesh = _build_ice_floe_mesh()
	_resource_props_manager = ResourcePropsManager.new(self)
	_resource_icon_manager = ResourceIconManager.new(self)
	_build_selection_marker()
	_build_hover_label()

	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)

	_cities_root = Node3D.new()
	_cities_root.name = "Cities"
	add_child(_cities_root)

	_buildings_root = Node3D.new()
	_buildings_root.name = "Buildings"
	add_child(_buildings_root)

	_construction_root = Node3D.new()
	_construction_root.name = "ConstructionMarkers"
	add_child(_construction_root)

	_lairs_root = Node3D.new()
	_lairs_root.name = "Lairs"
	add_child(_lairs_root)

	_tints_root = Node3D.new()
	_tints_root.name = "TerritoryTints"
	add_child(_tints_root)

func _process(delta: float) -> void:
	if _selection_marker.visible:
		_selection_time += delta
		_selection_marker.rotate_y(delta * 1.2)
		var pulse = 1.0 + sin(_selection_time * 3.0) * 0.08
		_selection_marker.scale = Vector3.ONE * pulse
	if _construction_markers.size() > 0:
		_construction_time += delta
		for marker in _construction_markers.values():
			# So a geometria do guindaste (sub-no "Crane") gira — `marker` em
			# si (pai da barra de progresso tambem, ver _build_construction_
			# marker) so balança em Y, senao a barra giraria junto.
			marker.get_node("Crane").rotate_y(delta * 1.5)
			marker.position.y = marker.get_meta("base_y") + sin(_construction_time * 2.0 + marker.get_meta("phase")) * 0.05

## seed_value < 0 sorteia uma semente nova (jogo novo); Salvar/Carregar passa
## a semente guardada pra recriar exatamente o mesmo terreno.
func generate_map(width: int, height: int, seed_value: int = -1) -> void:
	map_width = width
	map_height = height
	_clear_entities()
	tiles.clear()
	visibility.clear()
	# Geometria da grade (half_extents) muda com map_width/map_height —
	# invalida os caches de pixel->coord (ver _water_overlay_coord_cache),
	# senao um novo jogo/mapa reusaria o mapeamento antigo, errado.
	_water_overlay_coord_cache = []
	_biome_overlay_coord_cache = []
	map_seed = seed_value if seed_value >= 0 else randi()
	# Frequencias BAIXAS (nao mexem nos octaves fractais padrao do
	# FastNoiseLite — 5 octavas de FBM por padrao) esticam o comprimento de
	# correlacao do ruido pra dezenas de tiles, pra bioma/continente formar
	# REGIAO coerente em vez de "sal e pimenta" tile a tile. As mesmas 5
	# octavas continuam dando detalhe fino nas BORDAS (litoral irregular,
	# nao um circulo perfeito) — quem decide a FORMA geral e a octava base.
	_noise.seed = map_seed
	_noise.frequency = continent_noise_frequency
	# Offsets fixos (nao randi() de novo) pra continuar 100% deterministico a
	# partir da mesma map_seed — Salvar/Carregar depende disso pra recriar o
	# terreno identico so com a semente (ver SaveManager.gd).
	_warp_noise.seed = map_seed + 500
	_warp_noise.frequency = warp_frequency
	_moisture_noise.seed = map_seed + 1000
	_moisture_noise.frequency = moisture_noise_frequency
	_temp_jitter_noise.seed = map_seed + 2000
	_temp_jitter_noise.frequency = temperature_jitter_frequency
	_resource_noise.seed = map_seed + 3000
	_resource_noise.frequency = 0.8 # alta: recursos "espalhados", nao em blocos grandes (proposital, ver RESOURCE_NOISE_THRESHOLD)
	_volcanic_noise.seed = map_seed + 5000
	_volcanic_noise.frequency = volcanic_noise_frequency
	_arcane_noise.seed = map_seed + 6000
	_arcane_noise.frequency = arcane_noise_frequency # Campos de Cristal em CAMPO, nao tile solto
	# Canal DEDICADO pra reforco/patrulha de covil turno a turno (ver
	# monster_turn_rng acima) — semeado aqui igual todo outro canal, mas
	# SaveManager pode sobrescrever `.state` logo em seguida (apos um load)
	# pra continuar a sequencia exata de onde o save parou, em vez de
	# reiniciar do turno 0.
	monster_turn_rng.seed = map_seed + 7000

	# Formato RETANGULAR de verdade (nao losango/hexagono). Armazenamento
	# continua puramente axial (q, r) igual sempre foi (ver HexMetrics —
	# pointy-top, sem nenhum conceito de offset coordinate antes disso), mas
	# as linhas usam a conversao offset "odd-r" padrao
	# (redblobgames.com/grids/hexagons#coordinates-offset) SO na hora de
	# decidir quais (q, r) entram no mapa: pra cada linha `row`, a coluna
	# `col` (0..width) vira `q = col - (row - (row & 1)) / 2`, que desloca
	# fileiras impares meio hexagono pra manter as bordas verticais retas
	# — sem isso (so testando `q` puro) o resultado seria um paralelogramo
	# torto, nao um retangulo de verdade quando desenhado. Centralizado
	# perto da origem (linhas/colunas de -metade a +metade) pra continuar
	# valendo a suposicao usada em varios lugares (capital do humano,
	# distancia minima de covil/bioma forcado, camera, mascara de borda) de
	# que o "centro do mapa" e perto de (0,0).
	var half_h = height / 2
	var half_w = width / 2
	var coords: Array[Vector2i] = []
	for row in range(-half_h, height - half_h):
		for col in range(-half_w, width - half_w):
			var r = row
			var q = col - (row - (row & 1)) / 2
			coords.append(Vector2i(q, r))

	# Passo 1: elevacao (ruido de continente + mascara de borda, ver
	# _elevation_for) e classificacao agua/terra de TODO coord ANTES de
	# decidir bioma nenhum — precisa existir o mapa de terra inteiro pra
	# calcular distancia-ate-o-oceano e tamanho de ilha no passo 2, que por
	# sua vez decidem onde biomas especiais (vulcanico/cristal) fazem
	# sentido tematicamente (ver _generate_tile_data).
	var elevation_by_coord: Dictionary = {}
	var is_land_by_coord: Dictionary = {}
	for coord in coords:
		var elevation = _elevation_for(coord)
		elevation_by_coord[coord] = elevation
		is_land_by_coord[coord] = elevation >= OCEAN_ELEVATION_THRESHOLD

	# Passo 2: pra cada tile de terra, distancia (em tiles) ate a agua mais
	# proxima (regioes litoraneas ficam mais umidas que o interior, e
	# "vulcanico perto de oceano/fenda" precisa saber o que e costa) e o
	# tamanho da massa de terra conectada a que ele pertence (Campos de
	# Cristal em "ilha isolada" precisa saber o que e ilha pequena vs
	# continente grande).
	var coastal_distance := _coastal_distance_by_coord(coords, is_land_by_coord)
	var land_component_size := _land_component_size_by_coord(coords, is_land_by_coord)

	for coord in coords:
		tiles[coord] = _generate_tile_data(
			coord,
			elevation_by_coord[coord],
			coastal_distance.get(coord, COASTAL_DISTANCE_MAX),
			land_component_size.get(coord, 0)
		)

	_smooth_isolated_biome_cells()
	_ensure_biome_variety()
	# _ensure_biome_variety (Grande pra cima) pode ISOLAR um tile vizinho
	# sem querer: crescer a regiao forcada de um bioma raro consome os
	# vizinhos de quem estava do lado, e num canto do mapa hexagonal (so
	# 2-3 vizinhos de verdade, nao 6) isso as vezes zera os vizinhos do
	# MESMO tipo que sobravam pro tile vizinho — bug pego testando o
	# roadmap item 31 (savana isolada bem no canto do mapa, cercada por
	# Campos de Cristal recem-forcados). Rodar a limpeza de novo aqui e
	# seguro: uma regiao forcada de verdade (FORCED_CLUSTER_MIN+ tiles
	# conectados) nunca fica isolada aos PROPRIOS olhos desta funcao, so
	# tiles de fora que viraram colateral dela.
	_smooth_isolated_biome_cells()
	# Depois de toda decisao de bioma (incluindo _ensure_biome_variety,
	# que pode ter acabado de PLANTAR um cluster minimo de Montanha em
	# mapa Grande+) — ver _thin_mountain_clusters pro motivo/mecanica.
	_thin_mountain_clusters()
	# Mesma poda, aplicada as Montanhas Vulcanicas/Picos de Cristal dos
	# continentes especiais (regressao critica reportada pelo usuario:
	# "gerou um bloco massivo com mais de 30 montanhas... agrupadas no
	# centro" — ver _thin_special_zone_peaks pro motivo/mecanica).
	_thin_special_zone_peaks()
	# _thin_mountain_clusters/_thin_special_zone_peaks rebaixam tile a
	# tile (nao a regiao inteira de uma vez) — um blob grande vira "anel"/
	# parede fina ou pontos isolados de verdade, mas o efeito colateral e
	# que uma pontinha fina as vezes fica com 0 vizinhos do mesmo tipo
	# depois da poda (tile isolado, MESMO bug que _ensure_biome_variety ja
	# causava em outro contexto, ver comentario acima) — rodar a limpeza
	# de novo aqui absorve essas pontas pro bioma vizinho majoritario,
	# mesmo padrao ja seguro/testado.
	_smooth_isolated_biome_cells()
	_ensure_lava_sea_present()
	_reclassify_coastal_ocean()
	# Mesmo motivo das duas chamadas repetidas acima (_ensure_biome_variety/
	# _thin_mountain_clusters): _reclassify_coastal_ocean converte Oceano em
	# Costa em ONDA por passadas (ate COAST_RECLASSIFY_MAX_PASSES), e pode
	# colateralmente isolar um tile vizinho — um Oceano cercado por Costa
	# recem-convertida (a onda avancou nos vizinhos dele mas nao nele
	# mesmo, geralmente perto da borda de alcance da onda) fica sem nenhum
	# vizinho do mesmo bioma. So virou visivel com os continentes Vulcanico/
	# de Cristal (gap de oceano bem maior entre eles, mais chance da onda
	# esbarrar num limite antes de terminar de convergir) — rodar a limpeza
	# de novo aqui absorve esses tiles, mesmo padrao ja seguro/testado.
	_smooth_isolated_biome_cells()
	_ensure_minimum_volcanic_peaks()
	# Mesmo motivo de sempre (_ensure_biome_variety/_thin_mountain_clusters/
	# _thin_special_zone_peaks acima): promover um tile a Montanha Vulcanica
	# pode isolar colateralmente o vizinho que antes compartilhava o TIPO
	# ANTIGO dele (ex: uma Rocha Vulcanica que so tinha aquele UM vizinho do
	# mesmo tipo — bug pego pelo proprio teste de regressao deste item,
	# "esta isolado, sem nenhum vizinho do mesmo bioma", agora numa
	# Rocha Vulcanica em vez de Montanha). _smooth_isolated_biome_cells ja
	# tem a excecao dedicada pra NUNCA mexer em Montanha Vulcanica (ver
	# comentario la), entao rodar de novo aqui so limpa o colateral nos
	# OUTROS tipos, nunca desfaz a promocao que acabou de acontecer.
	_smooth_isolated_biome_cells()
	_rebuild_multimesh()
	_spawn_monster_lairs()

## Libera unidades/cidades/predios/contornos/marcadores de uma partida
## anterior antes de gerar um mapa novo (usado ao reiniciar) — sem isso os
## nodes antigos ficariam orfaos dentro das raizes, ainda ocupando tiles
## do mapa novo.
func _clear_entities() -> void:
	if _units_root:
		for child in _units_root.get_children():
			child.queue_free()
	if _cities_root:
		for child in _cities_root.get_children():
			child.queue_free()
	if _buildings_root:
		for child in _buildings_root.get_children():
			child.queue_free()
	if _construction_root:
		for child in _construction_root.get_children():
			child.queue_free()
	if _lairs_root:
		for child in _lairs_root.get_children():
			child.queue_free()
	if _tints_root:
		for child in _tints_root.get_children():
			child.queue_free()
	units_by_coord.clear()
	cities_by_coord.clear()
	buildings_by_coord.clear()
	_city_tints.clear()
	_construction_markers.clear()
	_construction_markers_pending_removal.clear()
	# lairs_by_coord/cleared_lair_coords tambem resetam aqui: generate_map()
	# (unico chamador de _clear_entities) sempre recria os covis do zero
	# deterministicamente, logo em seguida (_spawn_monster_lairs). Quem
	# repovoa cleared_lair_coords de uma partida CARREGADA e o proprio
	# SaveManager.load_game, chamando destroy_lair() de novo por cima —
	# mesmo padrao ja usado por clear_neutral_units()/_deserialize_neutral_
	# units() pra unidades.
	lairs_by_coord.clear()
	cleared_lair_coords.clear()
	_pillaged_tiles.clear()

func get_tile(coord: Vector2i) -> HexTileData:
	return tiles.get(coord, null)

func get_unit_at(coord: Vector2i) -> Unit:
	return units_by_coord.get(coord, null)

func get_city_at(coord: Vector2i) -> City:
	return cities_by_coord.get(coord, null)

func get_building_at(coord: Vector2i) -> Building:
	return buildings_by_coord.get(coord, null)

## Algum predio (de qualquer cidade) ja ocupa este tile? Mesmo padrao de
## is_tile_worked() — evita duas cidades vizinhas (ou a mesma cidade duas
## vezes) disputarem o mesmo tile pra construcao.
func is_tile_building_site(coord: Vector2i) -> bool:
	return buildings_by_coord.has(coord)

## Cria o modelo 3D do predio no tile escolhido pelo jogador (ver
## City.pending_building_coord/SelectionManager.start_building_placement)
## — chamado por GameManager quando City.process_turn() reporta um predio
## concluido com coord valido.
func place_building(coord: Vector2i, building_id: String, owner_player: PlayerData) -> Building:
	var building := Building.new()
	_buildings_root.add_child(building)
	building.setup(building_id, coord, owner_player)
	building.position = world_for_coord(coord)
	buildings_by_coord[coord] = building
	return building

func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in NEIGHBOR_DIRS:
		var n = coord + dir
		if tiles.has(n):
			result.append(n)
	return result

func world_for_coord(coord: Vector2i) -> Vector3:
	var pos = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	var data = get_tile(coord)
	pos.y = data.base_height if data else 0.0
	return pos

## Metade da largura/profundidade (eixos X/Z) que o mapa retangular ocupa
## no mundo, centrado perto da origem — derivado direto de map_width/
## map_height pela mesma formula de HexMetrics.axial_to_world (pointy-top:
## x = size*sqrt(3)*(q + r/2), z = size*1.5*r). Usado em qualquer lugar
## que precise dos limites do mapa em coordenadas de mundo (colisao do
## chao aqui embaixo, Minimap, RTSCamera) — fonte unica da formula, em vez
## de cada consumidor duplicar a mesma conta (o que aconteceria antes,
## quando o mapa era um losango de raio unico e cada lugar so multiplicava
## map_radius pelas mesmas constantes sqrt(3)/1.5).
func get_world_half_extents() -> Vector2:
	var half_width_world = hex_size * sqrt(3.0) * (float(map_width) / 2.0 + float(map_height) / 4.0) + hex_size
	var half_depth_world = hex_size * 1.5 * (float(map_height) / 2.0) + hex_size
	return Vector2(half_width_world, half_depth_world)

## Dijkstra simplificado (custo por terreno) limitado ao total de pontos de
## movimento. Tiles ocupados por qualquer unidade, ou por uma cidade
## inimiga, bloqueiam a passagem — cidade inimiga so se resolve atacando
## (SelectionManager/RivalAI), nunca "andando" pra dentro dela. `flies`
## (Grifo, UnitData.flies) ignora custo de terreno (sempre 1 por tile) E
## atravessa oceano — voa por cima de tudo, so unidade/cidade inimiga
## ainda bloqueiam. `embarked` (Roadmap 2.0 Parte 1, C — Unit.embarked)
## permite cruzar agua (HexTileData.can_be_embarked_on()) SEM ignorar custo
## de terreno nem cruzar Lava (diferente de `flies`) — e terra firme so e
## permitida como DESTINO FINAL enquanto embarcado (ver check logo apos o
## pop_front() abaixo): um tile de terra alcancado NO MEIO do trajeto vira
## no-folha, nunca expande vizinhos dali, entao nenhum caminho computado
## atravessa terra->agua->terra de novo dentro do MESMO comando (achado na
## revisao do plano — sem essa regra, continue_move_order executaria um
## trajeto multi-trecho sem revalidar terreno a cada passo).
func compute_reachable(start: Vector2i, movement_points: float, owner: PlayerData, flies: bool = false, embarked: bool = false) -> Dictionary:
	var cost_so_far := {start: 0.0}
	var came_from := {start: start}
	var frontier: Array[Vector2i] = [start]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		if embarked and current != start and not flies and not get_tile(current).can_be_embarked_on():
			continue
		for n in get_neighbors(current):
			if get_unit_at(n) != null:
				continue
			var city_here = get_city_at(n)
			if city_here != null and city_here.owner_player != owner:
				continue
			var terrain: HexTileData = get_tile(n)
			if not flies and terrain.blocks_land_units() and not (embarked and terrain.can_be_embarked_on()):
				continue
			var step_cost = 1.0 if flies else terrain.movement_cost
			var new_cost = cost_so_far[current] + step_cost
			if new_cost <= movement_points and (not cost_so_far.has(n) or new_cost < cost_so_far[n]):
				cost_so_far[n] = new_cost
				came_from[n] = current
				frontier.append(n)
	cost_so_far.erase(start)
	_last_came_from = came_from
	return cost_so_far

## Reconstroi a sequencia de tiles ate `end`, usando os predecessores
## calculados na ULTIMA chamada de compute_reachable — so faz sentido
## logo em seguida, pro mesmo `start` (SelectionManager garante isso: so
## chama isso enquanto um unit continua selecionado).
func reconstruct_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not _last_came_from.has(end):
		return path
	var current = end
	var safety = 0
	while current != start and safety < 64:
		path.append(current)
		current = _last_came_from.get(current, start)
		safety += 1
	path.reverse()
	return path

## Caminho de custo minimo entre `start` e `end`, SEM teto de movement_points
## (diferente de compute_reachable, que so acha tiles alcancaveis NO turno
## atual) — pedido do usuario: "no civilization eu posso colocar pra ela se
## mover pra um lugar longe... o movimento fica gravado e todo turno essa
## tropa vai se movendo". MESMAS regras de passagem de compute_reachable
## (sem empilhar unidade, sem entrar em cidade inimiga, terreno bloqueado
## so pra quem nao voa) — nao reusa aquela funcao direto porque o teto de
## movimento e essencial pra ela (reachable-NESTE-turno), enquanto aqui o
## objetivo e o oposto (caminho completo, custe quantos turnos custar).
## Devolve [] se nao existir caminho nenhum (ex: destino numa ilha sem
## ponte, pra unidade terrestre) — Array NAO inclui `start`, so os passos
## a partir dele. Ver HexGrid.continue_move_order, quem consome isso aos
## poucos a cada turno.
## Dijkstra de verdade com fila de prioridade (heap binario, ver
## _heap_push/_heap_pop_min abaixo) — ANTES era uma busca estilo SPFA sem
## ordem nenhuma (fila FIFO simples) que sempre inundava o componente
## conectado INTEIRO antes de devolver, mesmo pra achar o caminho ate um
## `end` bem pertinho (usuario reportou queda pra ~15 FPS na troca de turno;
## explore_step/continue_move_order chamam isto pra CADA unidade explorando
## ou com ordem de movimento pendente, TODO turno). Com fila de prioridade
## por custo, o primeiro pop de um no ja e seu custo MINIMO definitivo
## (garantia de Dijkstra pra pesos nao-negativos, que e sempre o caso aqui —
## movement_cost nunca e negativo), entao da pra parar assim que `end` for
## extraido do topo do heap sem nenhum risco de achar um caminho pior do que
## o de antes. Devolve o MESMO caminho de custo minimo de sempre (com pesos
## de terreno diferentes por tile pode haver mais de um caminho igualmente
## curto — qual desses empates especificos e escolhido pode variar em
## relacao a versao antiga, mas o CUSTO/numero de turnos pra completar nunca
## muda).
func compute_path(start: Vector2i, end: Vector2i, owner: PlayerData, flies: bool = false, embarked: bool = false) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if start == end:
		return path
	var cost_so_far := {start: 0.0}
	var came_from := {start: start}
	var heap: Array = [[0.0, start]] # array de [cost, coord], mantido como min-heap pelo indice 0
	while heap.size() > 0:
		var entry = _heap_pop_min(heap)
		var current_cost: float = entry[0]
		var current: Vector2i = entry[1]
		if current_cost > cost_so_far.get(current, INF):
			continue # entrada obsoleta: este no ja teve um custo melhor relaxado depois de entrar no heap
		if current == end:
			break
		# Mesma regra de compute_reachable acima: terra so e permitida como
		# DESTINO FINAL enquanto embarcado. O check `current == end` ja
		# rodou/deu break antes deste ponto, entao um `end` em terra
		# continua funcionando normalmente — so uma terra QUE NAO e `end`
		# vira beco sem saida aqui.
		if embarked and current != start and not flies and not get_tile(current).can_be_embarked_on():
			continue
		for n in get_neighbors(current):
			if get_unit_at(n) != null:
				continue
			var city_here = get_city_at(n)
			if city_here != null and city_here.owner_player != owner:
				continue
			var terrain: HexTileData = get_tile(n)
			if not flies and terrain.blocks_land_units() and not (embarked and terrain.can_be_embarked_on()):
				continue
			var step_cost = 1.0 if flies else terrain.movement_cost
			var new_cost = current_cost + step_cost
			if not cost_so_far.has(n) or new_cost < cost_so_far[n]:
				cost_so_far[n] = new_cost
				came_from[n] = current
				_heap_push(heap, new_cost, n)
	if not came_from.has(end):
		return path
	var step = end
	while step != start:
		path.push_front(step)
		step = came_from[step]
	return path

## Heap binario minimo generico sobre um Array de pares [cost, coord] —
## usado so por compute_path acima. Implementacao classica (sift-up/
## sift-down por indice de arvore binaria empacotada num Array).
func _heap_push(heap: Array, cost: float, coord: Vector2i) -> void:
	heap.append([cost, coord])
	var i = heap.size() - 1
	while i > 0:
		var parent = (i - 1) / 2
		if heap[parent][0] <= heap[i][0]:
			break
		var tmp = heap[parent]
		heap[parent] = heap[i]
		heap[i] = tmp
		i = parent

func _heap_pop_min(heap: Array) -> Array:
	var top = heap[0]
	var last = heap.pop_back()
	if heap.size() > 0:
		heap[0] = last
		var i = 0
		while true:
			var left = 2 * i + 1
			var right = 2 * i + 2
			var smallest = i
			if left < heap.size() and heap[left][0] < heap[smallest][0]:
				smallest = left
			if right < heap.size() and heap[right][0] < heap[smallest][0]:
				smallest = right
			if smallest == i:
				break
			var tmp = heap[smallest]
			heap[smallest] = heap[i]
			heap[i] = tmp
			i = smallest
	return top

func spawn_unit(coord: Vector2i, unit_data: UnitData, player: PlayerData) -> Unit:
	var unit := Unit.new()
	_units_root.add_child(unit)
	unit.setup(unit_data, player, coord)
	unit.position = world_for_coord(coord)
	units_by_coord[coord] = unit
	player.units.append(unit)
	return unit

## O estado LOGICO (coord/ocupacao/movimento) muda na hora — so a posicao
## visual desliza suavemente ate la. Fog, combate e IA usam unit.coord, que
## ja esta correto mesmo enquanto a animacao ainda esta rolando.
func move_unit(unit: Unit, dest: Vector2i, cost: float) -> void:
	units_by_coord.erase(unit.coord)
	unit.coord = dest
	unit.movement_left = max(0.0, unit.movement_left - cost)
	# Roadmap 2.0 Parte 1 (C) — desembarque automatico: assim que `dest`
	# deixa de ser um terreno de can_be_embarked_on(), a unidade volta a
	# ser terrestre normal. Sempre dispara corretamente porque compute_
	# reachable/compute_path com embarked=true so alcancam terra como o
	# ULTIMO passo de qualquer caminho computado (ver comentario deles) —
	# nunca no meio, entao nao ha risco de "desembarcar" preso em terra
	# sem conseguir voltar a agua no mesmo trajeto.
	if unit.embarked and not get_tile(dest).can_be_embarked_on():
		unit.embarked = false
	var target_pos = world_for_coord(dest)
	# Unidade fora da nevoa (unit.visible == false, ver _apply_fog_to_entities)
	# nao aparece na tela — animar o deslize dela com Tween e trabalho jogado
	# fora (o Tween continua processando todo frame por MOVE_DURATION mesmo
	# sem nada renderizado). So teleporta direto pra posicao final nesse caso.
	# Unidade do proprio jogador humano SEMPRE tem visible=true (mesma funcao
	# acima), entao ela continua animando normalmente sempre — so afeta
	# unidades de rival/monstro fora de visao, exatamente a rajada de
	# unidades de IA se movendo/agindo de uma vez que o usuario reportou como
	# "muito travado" ao passar o turno.
	if unit.visible:
		unit.slide_to(target_pos)
	else:
		unit.position = target_pos
	units_by_coord[dest] = unit
	# Pilhagem de Covil (pedido do usuario: "mover unidade militar ate um
	# covil ativo sem defensores destroi o covil"): move_unit so e chamado
	# com um `dest` que ja passou por compute_reachable, que exclui
	# qualquer tile OCUPADO (linha ~543 acima) — entao se dest esta em
	# lair_coords aqui, o guardiao/reforco dali ja morreu ou foi afastado,
	# exatamente a condicao pedida, sem precisar checar defensor de novo.
	# owner_player != null exclui movimento de monstro (um Invasor
	# marchando nunca deveria destruir covil alheio so por passar perto);
	# attack > 0 exclui o Colonizador (pedido explicito: "unidade MILITAR").
	if unit.owner_player != null and unit.unit_data.attack > 0.0 and dest in lair_coords:
		_grant_lair_clear_reward(unit, dest)

## Consome um pedido de "mover ate" pendente (Unit.move_order_target) o
## quanto o movimento ATUAL da unidade permitir — chamado tanto na hora
## (SelectionManager._try_queue_move_order, o quanto der ja neste turno)
## quanto em toda troca de turno seguinte (GameManager._on_turn_changed,
## logo apos unit.reset_movement() recarregar movement_left). Recalcula o
## caminho INTEIRO do zero a cada chamada (nao anda por um Array salvo) —
## se um obstaculo novo aparecer no meio do trajeto (outra unidade
## entrando no caminho, guerra declarada bloqueando uma cidade...) a rota
## se adapta sozinha em vez de travar tentando seguir uma rota velha
## invalida. Desiste da ordem (limpa move_order_target) em 3 casos: chegou,
## o destino deixou de ter caminho nenhum, ou o proximo passo custa mais
## que o TOTAL de movimento da unidade mesmo com o turno inteiro fresco
## (nunca vai dar pra completar, ja que movimento nao acumula entre
## turnos — sem essa saida a ordem ficaria presa pra sempre, tentando de
## novo a cada turno sem nenhum feedback).
func continue_move_order(unit: Unit) -> void:
	# Rede de seguranca (pedido do usuario: "fortificar é um estado de
	# alerta... ao ativar o estado de fortificado ele deve cancelar as
	# outras ações") — SelectionManager.fortify_selected() ja limpa
	# move_order_target na hora de ligar Fortificar, entao isto normalmente
	# nunca dispara; existe so pra garantir que uma unidade fortificada
	# JAMAIS ande sozinha, mesmo que algum caminho futuro esqueca de
	# limpar o campo.
	if unit.fortified:
		unit.move_order_target = Unit.NO_MOVE_ORDER
		return
	if unit.move_order_target == Unit.NO_MOVE_ORDER:
		return
	if unit.coord == unit.move_order_target:
		unit.move_order_target = Unit.NO_MOVE_ORDER
		return
	var path = compute_path(unit.coord, unit.move_order_target, unit.owner_player, unit.unit_data.flies, unit.embarked)
	if path.is_empty():
		unit.move_order_target = Unit.NO_MOVE_ORDER
		return
	var first_terrain: HexTileData = get_tile(path[0])
	var first_step_cost = 1.0 if unit.unit_data.flies else first_terrain.movement_cost
	if first_step_cost > unit.unit_data.movement_points:
		unit.move_order_target = Unit.NO_MOVE_ORDER
		return
	for step in path:
		var terrain: HexTileData = get_tile(step)
		var step_cost = 1.0 if unit.unit_data.flies else terrain.movement_cost
		if step_cost > unit.movement_left:
			break
		move_unit(unit, step, step_cost)
		if unit.movement_left <= 0.0:
			break
	if unit.coord == unit.move_order_target:
		unit.move_order_target = Unit.NO_MOVE_ORDER

## Consome "Explorar" (Unit.exploring) por um turno — pedido do usuario:
## "uma função que fica ativada... que se baseie em ficar andando por
## territórios que ainda não foram explorados". Acha os tiles UNSEEN mais
## pertos (por distancia hexagonal crua) e tenta um caminho de verdade
## (compute_path) ate os mais proximos deles, na ordem, ate achar um
## alcancavel — nao so o UNICO mais perto, senao uma unidade terrestre
## numa ilha desistiria de explorar so porque o tile UNSEEN geometricamente
## mais perto calha de ficar do outro lado do oceano, mesmo com MUITO
## territorio alcancavel ainda por perto. Anda o quanto o movimento ATUAL
## permitir, igual continue_move_order (mesmo padrao: recalcula tudo do
## ZERO a cada chamada, pra fog-of-war revelada durante o proprio
## movimento ja valer pro PROXIMO turno). Desliga sozinho (exploring =
## false) quando nao sobra nenhum tile UNSEEN alcancavel — mapa todo
## explorado (ou unidade isolada) e um fim natural, nao um erro.
const EXPLORE_CANDIDATE_LIMIT := 24 # tentar TODOS os UNSEEN do mapa com compute_path seria caro demais; os N mais pertos ja bastam pra achar algum alcancavel

func explore_step(unit: Unit) -> void:
	# Mesma rede de seguranca de continue_move_order acima — Fortificar
	# sempre vence, uma unidade fortificada nunca deveria andar sozinha.
	if unit.fortified:
		unit.exploring = false
		return
	# Roadmap 2.0 Parte 1 (C2) — unidade embarcada nao pode explorar (mesma
	# rede de seguranca do fortificado acima). Na pratica SelectionManager.
	# toggle_embark_selected ja cancela Explorar ao ligar embarque, entao
	# isto normalmente nunca dispara — existe so como segunda camada de
	# defesa.
	if unit.embarked:
		unit.exploring = false
		return
	if not unit.exploring:
		return
	# So mantem os EXPLORE_CANDIDATE_LIMIT tiles UNSEEN mais pertos JA VISTOS
	# durante a varredura (heap limitado, reaproveitando _heap_push/
	# _heap_pop_min de compute_path com custo negativo — mesmo truque de
	# "min-heap vira max-heap") em vez de juntar TODOS os UNSEEN do mapa
	# (ate 5760) num Array so pra depois sort_custom() descartar quase tudo.
	# sort_custom tambem RECALCULAVA axial_distance a cada COMPARACAO
	# (O(n log n) chamadas de lambda) em vez de uma vez por candidato — o
	# heap limitado computa a distancia UMA vez por tile e faz so O(log
	# EXPLORE_CANDIDATE_LIMIT) trabalho por candidato. Mesmo conjunto final
	# de ate 24 mais pertos, na mesma ordem crescente de distancia.
	var heap: Array = []
	for coord in tiles.keys():
		if visibility.get(coord, Visibility.UNSEEN) != Visibility.UNSEEN:
			continue
		var terrain: HexTileData = tiles[coord]
		if not unit.unit_data.flies and terrain.blocks_land_units():
			continue
		var dist: float = float(HexMetrics.axial_distance(unit.coord, coord))
		if heap.size() < EXPLORE_CANDIDATE_LIMIT:
			_heap_push(heap, -dist, coord)
		elif -dist > heap[0][0]:
			_heap_pop_min(heap)
			_heap_push(heap, -dist, coord)
	if heap.is_empty():
		unit.exploring = false
		return
	var candidates: Array[Vector2i] = []
	while heap.size() > 0:
		candidates.push_front(_heap_pop_min(heap)[1])

	var path: Array[Vector2i] = []
	for candidate in candidates:
		path = compute_path(unit.coord, candidate, unit.owner_player, unit.unit_data.flies)
		if not path.is_empty():
			break
	if path.is_empty():
		unit.exploring = false
		return

	for step in path:
		var terrain: HexTileData = get_tile(step)
		var step_cost = 1.0 if unit.unit_data.flies else terrain.movement_cost
		if step_cost > unit.movement_left:
			break
		move_unit(unit, step, step_cost)
		if unit.movement_left <= 0.0:
			break

## Remove TODO estado de um covil (reforco, estrutura 3D, marca de
## "ativo") sem conceder ouro nem notificar — usado tanto pela recompensa
## de limpeza do jogador (_grant_lair_clear_reward) quanto por SaveManager.
## load_game reconciliando os covis que ja tinham sido limpos ANTES do
## save (generate_map() acabou de respawnar todos do zero; isso desfaz
## esse respawn pros que nao deviam voltar).
func destroy_lair(coord: Vector2i) -> void:
	if not coord in lair_coords:
		return
	lair_coords.erase(coord)
	lair_kind_by_coord.erase(coord)
	if lairs_by_coord.has(coord):
		lairs_by_coord[coord].queue_free()
		lairs_by_coord.erase(coord)
	if not coord in cleared_lair_coords:
		cleared_lair_coords.append(coord)

func _grant_lair_clear_reward(unit: Unit, coord: Vector2i) -> void:
	var kind = lair_kind_by_coord.get(coord, "")
	var reward = MonsterDatabase.lair_clear_reward(kind)
	destroy_lair(coord)
	unit.owner_player.gold += reward
	if unit.owner_player == GameManager.human_player:
		EventBus.notify.emit("Voce destruiu um covil abandonado e saqueou %d ouro!" % int(reward), "combat")

func remove_unit(unit: Unit) -> void:
	units_by_coord.erase(unit.coord)
	if unit.owner_player:
		unit.owner_player.units.erase(unit)
	unit.queue_free()

## silent=true evita o toast "Cidade fundada" — usado por SaveManager ao
## reconstruir cidades de uma partida carregada (nao e um evento novo).
func found_city(coord: Vector2i, player: PlayerData, city_name: String, silent: bool = false) -> City:
	var city := City.new()
	_cities_root.add_child(city)
	city.setup(player, coord, city_name, hex_size)
	city.position = world_for_coord(coord)
	cities_by_coord[coord] = city
	player.cities.append(city)
	# Territorio inicial (ver City.owned_tiles) — mesmo conjunto que
	# city_territory_tiles() sempre devolveu antes desta virar posse
	# mutavel (celula + 6 vizinhos); dali em diante so cresce (ver
	# City._claim_frontier_tile, chamado a cada crescimento de populacao).
	city.owned_tiles = [coord]
	city.owned_tiles.append_array(get_neighbors(coord))
	city.auto_assign_worked_tiles(self)
	_update_city_tint(city)
	if player == GameManager.human_player and not silent:
		EventBus.notify.emit("Cidade fundada: %s" % city_name, "city")
	return city

## Algum OUTRO cidadao (de qualquer cidade, exceto `excluding`) ja trabalha
## este tile? Evita duas cidades vizinhas disputarem o mesmo tile — ver
## City.auto_assign_worked_tiles/toggle_worked_tile.
## Cidade (de qualquer dono) que atualmente trabalha `coord`, ou null se
## nenhuma — usado tanto por is_tile_worked() (bool) quanto por
## MonsterAI._maybe_pillage_tile (precisa da City de verdade pra descontar
## ouro do dono certo).
func city_working_tile(coord: Vector2i, excluding: City = null) -> City:
	for city in cities_by_coord.values():
		if city == excluding:
			continue
		if coord in city.worked_tiles:
			return city
	return null

func is_tile_worked(coord: Vector2i, excluding: City = null) -> bool:
	return city_working_tile(coord, excluding) != null

## Saque de Invasor (MonsterAI._maybe_pillage_tile): `coord` fica sem
## rendimento por `duration` turnos a partir de `turn` (ver City.
## collect_yields, que zera o rendimento de qualquer coord ainda pilhado).
## Sem limpeza ativa de entradas expiradas — ver comentario de
## _pillaged_tiles.
func pillage_tile(coord: Vector2i, turn: int, duration: int) -> void:
	_pillaged_tiles[coord] = turn + duration

func is_tile_pillaged(coord: Vector2i, turn: int) -> bool:
	return turn < _pillaged_tiles.get(coord, -1)

## Cidade sem defensor pode ser tomada por uma unidade inimiga adjacente que
## ataque — sem isso, uma capital indefesa e inconquistavel na pratica.
func capture_city(city: City, new_owner: PlayerData) -> void:
	var old_owner = city.owner_player
	var city_display_name = city.city_name
	if old_owner:
		old_owner.cities.erase(city)
	# Cidade capturada comeca "curada" pro novo dono — pedido do usuario
	# ("vida da cidade... o shield") tornou hp/shield mecanicos de verdade
	# (ver CombatResolver.resolve_city_attack); sem isso, uma cidade
	# capturada com a vida quase zerada ficaria trivialmente reconquistavel
	# pelo dono anterior no proximo turno. Precisa vir ANTES de change_owner
	# (que reconstroi as barras do zero via _build_visual/_build_life_bars)
	# pra elas ja nascerem mostrando o valor certo.
	city.hp = city.max_hp()
	city.shield = city.max_shield()
	city.change_owner(new_owner)
	new_owner.cities.append(city)
	_update_city_tint(city) # tingimento do territorio precisa seguir o novo dono
	if new_owner == GameManager.human_player:
		EventBus.notify.emit("Voce capturou %s!" % city_display_name, "city")
	elif old_owner == GameManager.human_player:
		EventBus.notify.emit("Voce perdeu %s para o inimigo!" % city_display_name, "city")

func show_selection_marker(coord: Vector2i) -> void:
	if not tiles.has(coord):
		_selection_marker.visible = false
		return
	var data: HexTileData = tiles[coord]
	var pos = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	pos.y = data.base_height + 0.05
	_selection_marker.position = pos
	_selection_marker.visible = true

## Uniao do raio de visao de todas as unidades/cidades de um jogador —
## calculo puro, sem tocar no dict `visibility` (que e so pra render/fog do
## jogador humano). Usado tambem pela IA rival pra saber o que ela realmente
## enxerga agora (ver RivalAI.take_turn), em vez de "trapacear" com
## conhecimento global do mapa.
func compute_visible_tiles(player: PlayerData) -> Dictionary:
	var visible_now := {}
	for unit in player.units:
		_mark_visible(unit.coord, unit.unit_data.vision_range, visible_now)
	for city in player.cities:
		_mark_visible(city.coord, 2, visible_now)
	return visible_now

## Debug: com isso ligado, recompute_fog() (chamada normalmente a cada
## fim de turno) para de calcular visao de verdade e so mostra o mapa
## inteiro sempre — nao e so um "reveal" de uma vez, senao o proximo fim
## de turno desfaria (ver HUD.gd, botao de Debug, so em builds de
## desenvolvimento via OS.is_debug_build()).
var debug_fog_disabled: bool = false

## Liga/desliga a neblina de guerra pro jogador humano e reaplica na hora
## (nao precisa esperar o proximo turno pra ver o efeito).
func set_debug_fog_disabled(disabled: bool) -> void:
	debug_fog_disabled = disabled
	if GameManager.human_player:
		recompute_fog(GameManager.human_player)

## Recalcula quais tiles estao visiveis para um jogador (uniao do raio de
## visao de todas as unidades e cidades dele). Tiles que ja foram vistos mas
## nao estao mais visiveis ficam "explorados" (escurecidos, nao pretos).
func recompute_fog(player: PlayerData) -> void:
	if debug_fog_disabled:
		for coord in tiles.keys():
			visibility[coord] = Visibility.VISIBLE
	else:
		var visible_now := compute_visible_tiles(player)
		for coord in tiles.keys():
			if visible_now.has(coord):
				visibility[coord] = Visibility.VISIBLE
			elif visibility.get(coord, Visibility.UNSEEN) == Visibility.VISIBLE:
				visibility[coord] = Visibility.EXPLORED

	_apply_fog_colors()
	_apply_fog_to_entities(player)
	EventBus.fog_updated.emit()

## Unidades/cidades/predios do proprio jogador sempre aparecem; os de
## outros so aparecem em tiles ATUALMENTE visiveis (nao basta ja ter
## explorado).
func _apply_fog_to_entities(player: PlayerData) -> void:
	for coord in units_by_coord.keys():
		var unit: Unit = units_by_coord[coord]
		if unit.owner_player == player:
			unit.visible = true
		else:
			unit.visible = visibility.get(coord, Visibility.UNSEEN) == Visibility.VISIBLE
	for coord in cities_by_coord.keys():
		var city: City = cities_by_coord[coord]
		if city.owner_player == player:
			city.visible = true
		else:
			city.visible = visibility.get(coord, Visibility.UNSEEN) == Visibility.VISIBLE
	for coord in buildings_by_coord.keys():
		var building: Building = buildings_by_coord[coord]
		if building.owner_player == player:
			building.visible = true
		else:
			building.visible = visibility.get(coord, Visibility.UNSEEN) == Visibility.VISIBLE
	# marcador de obra (guindaste + barra) tem que seguir a MESMA regra —
	# senao a obra de uma cidade inimiga aparecia mesmo em tile nunca visto,
	# entregando de graca "essa cidade esta construindo algo ali" por baixo
	# da nevoa. owner_player vem de meta (ver refresh_construction_markers),
	# null pra um marcador que nunca recebeu meta ainda (nao deveria
	# acontecer fora de teste, mas fica visivel por padrao nesse caso raro
	# em vez de sumir sem explicacao).
	for coord in _construction_markers.keys():
		var marker: Node3D = _construction_markers[coord]
		var owner = marker.get_meta("owner_player", null)
		if owner == null or owner == player:
			marker.visible = true
		else:
			marker.visible = visibility.get(coord, Visibility.UNSEEN) == Visibility.VISIBLE

## path_coords (opcional) e a previa do trajeto ate o tile sob o mouse —
## pintado por cima do verde/vermelho, tipo o preview de movimento do
## Civilization. buildable_coords (opcional) e usado so durante o
## posicionamento de um predio (SelectionManager.start_building_placement).
## Chamado de novo a cada frame que o hover muda, entao sempre reaplica
## fog+reachable+attackable do zero antes de tingir o caminho (senao o
## amarelo do hover anterior "grudaria" nos tiles).
## Terreno solido continua tingido por instancia (_highlight_coords, MultiMesh
## de verdade); agua/lava agora sao 1 plano continuo cada, sem instancia por
## tile — participam do destaque via o MESMO overlay de textura do fog (ver
## _rebuild_water_overlay), reconstruido aqui com os 4 conjuntos de coords.
## ANTES chamava _apply_land_and_prop_fog() inteiro aqui — reconstruia
## props/biome_overlay/tingimento de TODA cidade a cada troca de hover,
## mesmo que `visibility` nao tenha mudado NADA (so a previa de trajeto sob
## o mouse muda durante um hover). Isso rodava a cada tile novo sob o mouse
## enquanto uma unidade esta selecionada — usuario reportou "muito travado,
## quando eu dou zoom laga" (zoom em si e barato, mas mexer a camera quase
## sempre muda o tile sob o mouse tambem, entao disparava a mesma cascata).
## Agora so desfaz (_reset_highlighted_terrain) as instancias que a chamada
## ANTERIOR tingiu, aplica os tingimentos novos, e pronto — nevoa de
## verdade (props/biome/territorio) so e recalculada por recompute_fog
## (fim de turno) ou set_debug_fog_disabled, os UNICOS momentos em que
## `visibility` realmente muda.
func set_highlight(reachable_coords: Array, attackable_coords: Array, path_coords: Array = [], buildable_coords: Array = []) -> void:
	_reset_highlighted_terrain(_last_highlighted_land_coords)
	_highlight_coords(reachable_coords, Color(0.3, 1.0, 0.3), 0.5)
	_highlight_coords(attackable_coords, Color(1.0, 0.2, 0.2), 0.5)
	_highlight_coords(path_coords, Color(1.0, 1.0, 0.4), 0.7)
	_highlight_coords(buildable_coords, Color(0.35, 0.7, 1.0), 0.55)
	_last_highlighted_land_coords = reachable_coords + attackable_coords + path_coords + buildable_coords
	_rebuild_water_overlay(reachable_coords, attackable_coords, path_coords, buildable_coords)

## Tinge `coords` por cima da cor ja aplicada (fog) no terreno SOLIDO —
## agua/lava (sem instancia por tile) sao tratados por _rebuild_water_overlay.
func _highlight_coords(coords: Array, tint: Color, weight: float) -> void:
	if _multimesh_instance == null:
		return
	var mm = _multimesh_instance.multimesh
	for coord in coords:
		if not _coord_to_index.has(coord):
			continue
		var idx = _coord_to_index[coord]
		var base_color = mm.get_instance_color(idx)
		mm.set_instance_color(idx, base_color.lerp(tint, weight))

## Desfaz o tingimento de highlight de `coords`, devolvendo a cor CRUA do
## bioma (tiles[coord].color) — mesmo valor que _apply_terrain_fog aplicaria
## pra esses tiles especificos, so que sem varrer o mapa inteiro. Fog-of-war
## em si (escurecimento/sepia) nunca viveu na cor da instancia (isso e
## sempre shader-side via biome_overlay_texture, ver _apply_terrain_fog) —
## entao resetar pra cor crua aqui e sempre correto, nao so uma aproximacao.
func _reset_highlighted_terrain(coords: Array) -> void:
	if _multimesh_instance == null or coords.is_empty():
		return
	var mm = _multimesh_instance.multimesh
	for coord in coords:
		if not _coord_to_index.has(coord) or not tiles.has(coord):
			continue
		mm.set_instance_color(_coord_to_index[coord], tiles[coord].color)

## Roadmap de gameplay Fase 5 — "Metamorfose de Gaia" (ver SpellManager.
## _apply_terrain_transform): troca o TIPO de terreno de um tile ja
## gerado, mantendo o resto do mapa intacto. So atualiza a COR da
## instancia no multimesh (mesma tecnica de _reset_highlighted_terrain
## acima) — nao mexe na altura/geometria do prisma (a diferenca de
## base_height entre os biomas elegiveis pro unico uso disto hoje —
## Tundra/Deserto/Planicie — e minima, todos essencialmente planos, ver
## TerrainDatabase.gd) nem em recurso ja sorteado no tile (limpo: o
## bioma novo pode nao ser elegivel pro recurso antigo, ver
## ResourceDatabase.ELIGIBILITY). recompute_fog (chamado pelo proprio
## SelectionManager logo apos conjurar) reaplica o tingimento de neblina
## por cima da cor crua nova.
func transform_tile_terrain(coord: Vector2i, new_terrain_type: int) -> void:
	if not tiles.has(coord):
		return
	var new_tile: HexTileData = TerrainDatabase.create_tile(new_terrain_type)
	tiles[coord] = new_tile
	if _multimesh_instance and _coord_to_index.has(coord):
		_multimesh_instance.multimesh.set_instance_color(_coord_to_index[coord], new_tile.color)

func clear_highlight() -> void:
	_reset_highlighted_terrain(_last_highlighted_land_coords)
	_last_highlighted_land_coords = []
	_rebuild_water_overlay()
	hide_hover_label()

## Territorio de uma cidade = City.owned_tiles (posse dinamica, cresce com
## a populacao — ver City._claim_frontier_tile) — usado pro tingimento
## visual (_build_city_tint_mesh). Diferente de worked_tiles (rendimento)
## e do raio de posicionamento de predio, que continuam fixos em "vizinho
## direto da propria celula", fora do escopo desta mudanca.
func city_territory_tiles(city: City) -> Dictionary:
	var territory := {}
	for coord in city.owned_tiles:
		territory[coord] = true
	return territory

## Cidade (de qualquer dono) que atualmente POSSUI `coord` (ver
## City.owned_tiles), ou null se nenhuma — mesmo padrao de
## city_working_tile, usado por City._claim_frontier_tile pra duas cidades
## vizinhas nunca disputarem o mesmo tile de territorio.
func city_owning_tile(coord: Vector2i, excluding: City = null) -> City:
	for city in cities_by_coord.values():
		if city == excluding:
			continue
		if coord in city.owned_tiles:
			return city
	return null

## Roadmap 2.0 Parte 1 (A2) — proxy MINIMO de "tile sob pressao de cidade
## rival", sem nenhuma camada de cultura/influencia por tras: so distancia
## hexagonal crua ate a cidade rival mais perto. Uma cidade rival a
## RIVAL_PRESSURE_RADIUS hexes NAO significa que as duas civs estejam
## disputando aquele tile especificamente, so que ele esta dentro do
## alcance de expansao plausivel de outra civ — usado em RivalAI (B3) pra
## a IA preferir levemente um destino de assentamento longe disso, nunca
## pra bloquear nada.
const RIVAL_PRESSURE_RADIUS := 4

func is_under_rival_pressure(coord: Vector2i, player: PlayerData) -> bool:
	for city in cities_by_coord.values():
		if city.owner_player == player:
			continue
		if HexMetrics.axial_distance(coord, city.coord) <= RIVAL_PRESSURE_RADIUS:
			return true
	return false

## Roadmap 2.0 Parte 1 (C3) — pre-condicao espacial pro modo "Embarcar" (ver
## SelectionManager.toggle_embark_selected): `coord` tem pelo menos um
## vizinho de agua (HexTileData.can_be_embarked_on()). Nao da pra exigir
## "estar EM CIMA de um tile de Costa" — confirmado que blocks_land_units()
## = is_water() or is_lava() e is_water() inclui COAST, ou seja, uma
## unidade terrestre NUNCA consegue fisicamente ocupar um tile de Costa
## hoje (so trabalha-lo a distancia) — "adjacente a agua" e a regra
## equivalente fisicamente possivel.
func is_coastal_tile(coord: Vector2i) -> bool:
	for n in get_neighbors(coord):
		var data := get_tile(n)
		if data and data.can_be_embarked_on():
			return true
	return false

## Deslocamento vertical do tingimento de territorio acima do chao. O
## tingimento e um leque preenchendo o hexagono INTEIRO, quase
## perfeitamente COPLANAR com o topo do terreno, entao qualquer folga
## pequena sofre z-fighting/oclusao na area toda — 0.04 da margem de
## verdade contra isso.
const TINT_ABOVE_OFFSET := 0.04
## Opacidade do tingimento pra um trecho VISIBLE — pedido do usuario apos
## abandonar o sistema de linha de contorno (repetidos problemas de
## renderizacao/juncao de geometria, ver historico de border_shader.
## gdshader/_build_player_border_mesh, removidos): "faça apenas com que o
## territorio de uma nacao tenha uma cor especifica... colorir o topo de
## cada celula com essa cor". Sem NENHUMA linha de contorno agora, o
## tingimento e o UNICO sinal visual de posse territorial — subido bem
## acima do "8%-12%" original (que era so um acabamento complementar a
## borda) pra ficar claramente reconhecivel sozinho.
const TERRITORY_TINT_ALPHA := 0.35
## EXPLORED (nao VISIBLE agora) fica com uma FRACAO da opacidade normal —
## memoria mais fraca que visao ativa de verdade, mesmo espirito de
## _sepia_prop_color pros outros props/estruturas deste arquivo.
const TERRITORY_TINT_EXPLORED_ALPHA_MULT := 0.5

## Camada visual SEPARADA (nao um material do proprio terreno — mesmo
## principio de todo outro overlay deste arquivo: rio, contorno, props de
## recurso) que tinge o chao de cada tile do territorio da cidade na cor
## da civ (pedido do usuario, requisito 3: "tingimento suave no chao dos
## hexagonos dominados"). Reconstruida no MESMO ciclo que o contorno (ver
## _apply_land_and_prop_fog/found_city/capture_city).
## Reaproveita o MeshInstance3D/ShaderMaterial da cidade entre chamadas (em
## vez de queue_free() + instanciar tudo de novo do zero toda vez) — cidade
## nunca e destruida individualmente fora de um reset de mapa inteiro
## (_clear_entities, que ja libera _tints_root inteiro e limpa _city_tints),
## entao e sempre seguro so trocar o `.mesh` de uma instancia existente. So
## a malha (SurfaceTool) em si ainda e reconstruida — territorio/nevoa podem
## ter mudado — mas sem o custo de alocar Node/Material novos e agendar
## queue_free() todo turno pra toda cidade.
func _update_city_tint(city: City) -> void:
	var mesh_instance: MeshInstance3D
	if _city_tints.has(city):
		mesh_instance = _city_tints[city]
	else:
		mesh_instance = MeshInstance3D.new()
		var mat := ShaderMaterial.new()
		if _territory_tint_shader == null:
			_territory_tint_shader = load("res://shaders/territory_tint_shader.gdshader")
			if _territory_tint_shader == null:
				push_error("HexGrid: falha ao carregar res://shaders/territory_tint_shader.gdshader — tingimento de territorio ficara sem material (invisivel)")
		mat.shader = _territory_tint_shader
		mesh_instance.material_override = mat
		_tints_root.add_child(mesh_instance)
		_city_tints[city] = mesh_instance
	var mesh := _build_city_tint_mesh(city)
	mesh_instance.mesh = mesh if mesh.get_surface_count() > 0 else null

## Leque de triangulos (centro + 6 cantos) por tile do territorio — um
## "tampo" plano cobrindo o hexagono INTEIRO. Altura: centro na altura VISUAL real
## (_tile_surface_height, com pico/domo de Montanha/Colina) e os 6 cantos
## em base_height puro — mesmo fato geometrico usado no resto do arquivo
## (no canto de verdade o pico/domo ja caiu pra zero) — entao o leque
## aproxima a curva real do dominio do tile em vez de flutuar acima dos
## cantos (Montanha/Colina) ou afundar no pico. Nevoa POR TILE (mesma fonte
## que o contorno usa, _fog_level_for): UNSEEN nao gera geometria, EXPLORED
## fica sepia + mais transparente ainda, VISIBLE cor/opacidade cheias.
func _build_city_tint_mesh(city: City) -> ArrayMesh:
	var territory := city_territory_tiles(city)
	var civ: CivilizationData = city.owner_player.civ if city.owner_player else null
	var base_color = civ.color if civ else Color.WHITE

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tile_coord in territory.keys():
		var fog_level = _fog_level_for(tile_coord)
		if fog_level <= 0.0:
			continue # UNSEEN: tile sem tingimento nenhum sob a nevoa
		var explored: bool = fog_level < 1.0
		var color = base_color if not explored else _sepia_prop_color(base_color)
		var alpha = TERRITORY_TINT_ALPHA * (TERRITORY_TINT_EXPLORED_ALPHA_MULT if explored else 1.0)
		var col := Color(color.r, color.g, color.b, alpha)
		var w = world_for_coord(tile_coord)
		var center_point = Vector3(w.x, _tile_surface_height(tile_coord) + TINT_ABOVE_OFFSET, w.z)
		var corner_y = w.y + TINT_ABOVE_OFFSET
		var corners: Array[Vector3] = []
		for i in range(6):
			var c = HexMetrics.corner(hex_size, i)
			corners.append(Vector3(w.x + c.x, corner_y, w.z + c.z))
		for i in range(6):
			st.set_color(col); st.set_uv(Vector2.ZERO); st.add_vertex(center_point)
			st.set_color(col); st.set_uv(Vector2.ZERO); st.add_vertex(corners[i])
			st.set_color(col); st.set_uv(Vector2.ZERO); st.add_vertex(corners[(i + 1) % 6])
	return st.commit()

## Marcador animado (girando + balancando) sobre um tile com um predio EM
## PRODUCAO — sem isso, um predio sendo construido nao tinha NENHUMA
## diferenca visual de um tile vazio ate a producao completar. Reconciliado
## a cada mudanca de estado relevante (ver refresh_construction_markers):
## mais simples e menos propenso a erro do que caçar manualmente todo lugar
## que pending_building_coord pode mudar (concluido, trocado, cancelado).
## wanted agora mapeia coord -> City (nao so um bool) — pedido do usuario:
## "a barra de progresso nao esta avançando... faça ficar acima da
## construção nao da cidade" — o marcador ja fica na posicao certa
## (world_for_coord do TILE do predio, ver _build_construction_marker), so
## faltava ATUALIZAR a barra a cada refresh (antes so existia visualmente
## presa em City.gd, flutuando sobre a CIDADE, nao sobre o predio de
## verdade sendo construido — o usuario nunca via ela se mexer porque
## olhava pro lugar errado). Precisa da City dona pra ler stored_production/
## production_cost() na hora de atualizar.
##
## just_completed: coords cujo predio ACABOU de ficar pronto NESTE turno
## (ver GameManager._on_turn_changed/_finish_turn, result.built_coord) — sem
## isso, wanted.has(coord) ja da false no MESMO refresh em que a producao
## cruzou o custo (City.process_turn ja limpou pending_building_coord antes
## de refresh_construction_markers ser chamado), entao o marcador sumia
## sem NUNCA renderizar 100%, so o ultimo valor do turno anterior. Agora,
## pra esses coords, a barra fica travada em 100% por UM refresh extra
## antes de sumir de vez — cancelamento (jogador trocou a producao antes de
## completar) continua removendo na hora, sem essa "volta de graca".
func refresh_construction_markers(just_completed: Array[Vector2i] = []) -> void:
	var wanted := {} # coord -> City
	for city in cities_by_coord.values():
		if city.pending_building_coord != City.NO_PENDING_COORD:
			wanted[city.pending_building_coord] = city
	for coord in _construction_markers.keys().duplicate():
		if wanted.has(coord):
			continue
		if _construction_markers_pending_removal.has(coord):
			_construction_markers[coord].queue_free()
			_construction_markers.erase(coord)
			_construction_markers_pending_removal.erase(coord)
		elif coord in just_completed:
			_update_construction_marker_progress_full(_construction_markers[coord])
			_construction_markers_pending_removal[coord] = true
		else:
			_construction_markers[coord].queue_free()
			_construction_markers.erase(coord)
	for coord in wanted.keys():
		if not _construction_markers.has(coord):
			_construction_markers[coord] = _build_construction_marker(coord)
		var city: City = wanted[coord]
		# owner_player fica de meta (nao da pra ler da City depois que o
		# marcador sai de "wanted" — ver volta de graca acima) pra
		# _apply_fog_to_entities saber gatear visibilidade igual unidade/
		# cidade/predio: dono sempre ve, resto so com o tile ATUALMENTE
		# visivel (nao so explorado) — sem isso a obra de uma cidade
		# inimiga vazava por baixo da nevoa, nunca escondida.
		_construction_markers[coord].set_meta("owner_player", city.owner_player)
		_update_construction_marker_progress(_construction_markers[coord], city)

## Guindaste bem simples (base + braco) — nao precisa ser bonito, so
## precisa ser obviamente DIFERENTE de um predio pronto (por isso
## translucido) e chamar atencao (por isso gira e balanca em _process()).
## A geometria do guindaste (post/arm) mora num sub-no "Crane" PROPRIO que
## e quem de fato gira (ver _process()) — `marker` (o pai, so balança em Y)
## e a barra de progresso ficam de FORA dessa rotacao. Regressao: a barra
## era filha direta de `marker` antes, entao girava junto com o guindaste
## (pedido do usuario: "a barra de progresso ta girando, e ainda por cima
## ta duas barras girando diferente" — o bg/fg quase coincidentes, ambos
## com billboard, brigando com a rotacao do pai a cada frame e alternando
## qual ficava na frente).
func _build_construction_marker(coord: Vector2i) -> Node3D:
	var marker := Node3D.new()
	var base_pos = world_for_coord(coord)
	marker.position = base_pos
	marker.set_meta("base_y", base_pos.y)
	marker.set_meta("phase", randf() * TAU)

	var crane := Node3D.new()
	crane.name = "Crane"
	marker.add_child(crane)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.04
	post_mesh.bottom_radius = 0.06
	post_mesh.height = 0.45
	post.mesh = post_mesh
	post.material_override = mat
	post.position.y = 0.22
	crane.add_child(post)

	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.4, 0.04, 0.04)
	arm.mesh = arm_mesh
	arm.material_override = mat
	arm.position = Vector3(0.12, 0.45, 0.0)
	crane.add_child(arm)

	_build_construction_progress_bar(marker)

	_construction_root.add_child(marker)
	return marker

## Barra de progresso ACIMA do guindaste (0.68, guindaste vai ate 0.45) —
## pedido do usuario: "pra saber se a construção esta ficando prova [pronta]
## ... faça ficar acima da construção nao da cidade". TERCEIRA versao desta
## barra — as duas anteriores usavam DOIS QuadMesh separados (fundo +
## preenchimento) tentando se manter alinhados por matematica de posicao/
## tamanho manual, e isso nunca funcionou direito (girava junto com o
## guindaste, depois o preenchimento ficava com limites de visibilidade
## errados ao crescer, e por fim os DOIS QUADS NUNCA FICAVAM ALINHADOS um
## sob o outro — pedido do usuario: "as barras nao ficam uma sob a outra,
## ache um sistema melhor"). Sistema novo: UM UNICO Sprite3D com UMA
## textura so, contendo fundo+preenchimento JA desenhados juntos, no MESMO
## padrao ja comprovado de Unit._build_troop_icon()/ResourceIconManager
## (billboard de Sprite3D, nao StandardMaterial3D.billboard_mode numa
## malha propria — Sprite3D ja resolve sozinho tamanho/posicionamento/
## orientacao, sem matematica manual nenhuma pra dar errado). O tamanho e
## a POSICAO do sprite NUNCA mudam depois de criado — so os PIXELS da
## textura mudam a cada atualizacao, entao nao ha nada pra desalinhar.
const CONSTRUCTION_PROGRESS_BAR_Y := 0.7
const CONSTRUCTION_PROGRESS_BAR_TEX_WIDTH := 64
const CONSTRUCTION_PROGRESS_BAR_TEX_HEIGHT := 12
## world_width = TEX_WIDTH * PIXEL_SIZE = 64 * 0.0125 = 0.8 — pedido do
## usuario: "fica uns bons turnos sem a barra de progresso aparecer...
## quando ta em 90% a construção termina". As duas versoes anteriores ja
## tinham a MATEMATICA de preenchimento certa (confirmado por teste
## automatizado), entao o problema que sobrou e de PERCEPCAO: em 0.5
## unidade de largura (a distancia normal de camera do RTS) um
## preenchimento de 10-30% vira uma lasca fininha, quase impossivel de
## notar antes de ja estar bem cheia. Aumentado ~60% (0.5 -> 0.8) e com
## BORDA propria (ver abaixo) — a MOLDURA do indicador fica visivel desde
## o turno 1, mesmo com 0% de progresso, entao da pra perceber que "tem um
## indicador ali" antes mesmo dele comecar a encher.
const CONSTRUCTION_PROGRESS_BAR_PIXEL_SIZE := 0.0125
const CONSTRUCTION_PROGRESS_BAR_FILL_COLOR := Color(1.0, 0.8, 0.2) # mesmo amarelo do guindaste
## Cinza CLARO (nao mais quase-preto 0.08) — pedido do usuario, mesmo
## motivo do tamanho maior acima: o fundo escuro demais se confundia com
## sombra/terreno escuro, entao nem a MOLDURA do indicador chamava atencao
## enquanto o preenchimento ainda era pequeno.
const CONSTRUCTION_PROGRESS_BAR_EMPTY_COLOR := Color(0.55, 0.55, 0.58, 0.95)
## Contorno escuro solido (1px) em volta da barra inteira — da uma leitura
## de "isso e um indicador de UI", nao so um retangulo colorido solto,
## visivel independente da cor de fundo do bioma por baixo.
const CONSTRUCTION_PROGRESS_BAR_BORDER_COLOR := Color(0.12, 0.1, 0.06)

func _build_construction_progress_bar(marker: Node3D) -> void:
	var bar := Sprite3D.new()
	bar.name = "ProgressBar"
	bar.texture = _build_construction_progress_bar_texture(0.0)
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.no_depth_test = true
	bar.shaded = false
	bar.pixel_size = CONSTRUCTION_PROGRESS_BAR_PIXEL_SIZE
	bar.position = Vector3(0, CONSTRUCTION_PROGRESS_BAR_Y, 0)
	marker.add_child(bar)

## Desenha borda + fundo (cinza claro) + preenchimento (amarelo) NA MESMA
## imagem, pixel a pixel da esquerda pra direita — os primeiros `frac` por
## cento das colunas (fora da moldura de 1px) ficam com a cor de
## preenchimento, o resto com a cor de fundo. Reconstroi a textura inteira
## do zero a cada chamada (mesmo padrao ja usado por Unit._build_troop_
## icon_texture/ResourceIconManager — nunca reaproveita/muta uma Image
## existente).
func _build_construction_progress_bar_texture(frac: float) -> ImageTexture:
	var w := CONSTRUCTION_PROGRESS_BAR_TEX_WIDTH
	var h := CONSTRUCTION_PROGRESS_BAR_TEX_HEIGHT
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var fill_px := roundi(w * clamp(frac, 0.0, 1.0))
	for x in range(w):
		var is_border_x = x == 0 or x == w - 1
		for y in range(h):
			var is_border_y = y == 0 or y == h - 1
			var color: Color
			if is_border_x or is_border_y:
				color = CONSTRUCTION_PROGRESS_BAR_BORDER_COLOR
			else:
				color = CONSTRUCTION_PROGRESS_BAR_FILL_COLOR if x < fill_px else CONSTRUCTION_PROGRESS_BAR_EMPTY_COLOR
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

## Chamado a cada refresh_construction_markers() (uma vez por turno, ja
## depois de City.process_turn() ter acumulado producao — ver comentario
## de refresh_construction_markers) — so troca a TEXTURA do sprite pela
## fracao atual (stored_production/production_cost() da cidade DONA deste
## predio); nunca mexe em tamanho/posicao (ver comentario da const
## CONSTRUCTION_PROGRESS_BAR_Y acima pro motivo).
func _update_construction_marker_progress(marker: Node3D, city: City) -> void:
	var bar := marker.get_node_or_null("ProgressBar") as Sprite3D
	if bar == null:
		return
	var cost = city.production_cost()
	var frac = clamp(city.stored_production / cost, 0.0, 1.0) if cost > 0.0 else 1.0
	bar.texture = _build_construction_progress_bar_texture(frac)

## Trava a barra do marcador em 100% sem precisar da City dona — usada na
## "volta de graca" de um predio recem-concluido (ver refresh_construction_
## markers/just_completed), onde a City ja resetou production_item/
## pending_building_coord e nao tem mais como calcular a fracao de novo.
func _update_construction_marker_progress_full(marker: Node3D) -> void:
	var bar := marker.get_node_or_null("ProgressBar") as Sprite3D
	if bar == null:
		return
	bar.texture = _build_construction_progress_bar_texture(1.0)

## Mostra um rotulo flutuante sobre um tile — usado pra indicar custo de
## movimento (previa de trajeto) ou "ATACAR" ao passar o mouse sobre um
## alvo no alcance, sem precisar abrir nenhum painel.
func show_hover_label(coord: Vector2i, text: String, color: Color) -> void:
	if not tiles.has(coord):
		hide_hover_label()
		return
	var pos = world_for_coord(coord)
	pos.y += 0.7
	_hover_label.position = pos
	_hover_label.text = text
	_hover_label.modulate = color
	_hover_label.visible = true

func hide_hover_label() -> void:
	_hover_label.visible = false

## Reaplica fog-of-war nos 3 multimeshes de terreno (solido/agua/lava, ver
## _multimesh_target_for) — cada um so itera os proprios coords
## (_coord_to_index/_water_coord_to_index/_lava_coord_to_index), entao
## cada tile e escurecido exatamente uma vez, na malha certa.
func _apply_fog_colors() -> void:
	_apply_land_and_prop_fog()
	_rebuild_water_overlay()

func _apply_land_and_prop_fog() -> void:
	if _multimesh_instance:
		_apply_terrain_fog(_multimesh_instance.multimesh, _coord_to_index)
	_apply_prop_fog()
	_rebuild_biome_overlay()
	# Tingimento de territorio: reconstruido no MESMO ciclo, mesmo custo ja
	# aceito hoje (evento discreto: turno/hover/selecao, nunca por frame) —
	# cobre TANTO fog mudando (nevoa por tile, ver _build_city_tint_mesh)
	# QUANTO territorio crescendo (City.owned_tiles, ver City.
	# _claim_frontier_tile chamado todo turno em process_turn), sem
	# precisar de um gancho separado em GameManager/City pra cada caso.
	for city in cities_by_coord.values():
		_update_city_tint(city)

## Refatoracao de nevoa de guerra (pedido do usuario: "escurecimento direto
## nos tiles... corte seco no formato do hexagono" virando 3 estados visuais
## refinados com borda suave). O terreno solido NAO dimeriza mais a cor por
## instancia aqui — so reseta pra cor CRUA do bioma (desfazendo qualquer
## destaque de _highlight_coords de uma chamada anterior). O tingimento de
## nevoa em si (nuvem/sepia/cor plena, com fade suave entre eles) agora vive
## inteiramente em terrain.gdshader, amostrando fog_level continuo da MESMA
## mascara global de biome_overlay_texture com filtro linear (ver
## _rebuild_biome_overlay/_fog_level_for) — dai a mistura suave "de graca"
## entre tiles vizinhos em vez do corte reto por instancia de antes.
func _apply_terrain_fog(mm: MultiMesh, coord_to_index: Dictionary) -> void:
	for coord in coord_to_index.keys():
		var data: HexTileData = tiles[coord]
		var idx = coord_to_index[coord]
		mm.set_instance_color(idx, data.color)
	# Mapa inteiro ja esta na cor crua agora — nenhum highlight residual pra
	# _reset_highlighted_terrain desfazer na proxima set_highlight/
	# clear_highlight (ver _last_highlighted_land_coords).
	_last_highlighted_land_coords = []

## Props (arvores/pedras/picos) nao passam por terrain.gdshader (material
## simples, sem shader custom) — entao continuam tingidos por INSTANCIA,
## mas agora com 3 tratamentos distintos em vez do escurecimento linear de
## antes: UNSEEN vira alfa 0 (escondido de verdade, pedido do usuario
## "visibilidade/alfa zerados" — ver _rebuild_props, materiais com
## TRANSPARENCY_ALPHA_SCISSOR pra alfa 0 realmente sumir sem custo de
## blending/ordenacao, ja que aqui alfa e sempre binario 0 ou 1, nunca
## fracionario), EXPLORED vira sepia/dessaturado (_sepia_prop_color, mesmo
## espirito do tratamento de terreno), VISIBLE fica com a cor original.
func _apply_prop_fog() -> void:
	if _props_tree_instance:
		_tint_props(_props_tree_instance.multimesh, _tree_coord_to_index, Color.WHITE)
	if _props_ice_floe_instance:
		_tint_props(_props_ice_floe_instance.multimesh, _ice_floe_coord_to_index, ICE_FLOE_BASE_COLOR)
	_resource_props_manager.apply_fog(visibility)
	_resource_icon_manager.apply_fog(visibility)
	for coord in lairs_by_coord.keys():
		lairs_by_coord[coord].apply_fog_state(visibility.get(coord, Visibility.UNSEEN))

func _tint_props(mm: MultiMesh, coord_to_index: Dictionary, base_color: Color) -> void:
	for coord in coord_to_index.keys():
		var indices: Array = coord_to_index[coord] # varios props por tile agora (ver _rebuild_props), nao mais 1 indice so
		var vis = visibility.get(coord, Visibility.UNSEEN)
		var color = base_color
		match vis:
			Visibility.UNSEEN:
				color = Color(base_color.r, base_color.g, base_color.b, 0.0)
			Visibility.EXPLORED:
				color = _sepia_prop_color(base_color)
			Visibility.VISIBLE:
				pass
		for idx in indices:
			mm.set_instance_color(idx, color)

## Sepia/dessaturado a partir da luminancia de `base_color` — mesma formula
## de luminancia perceptual (0.299/0.587/0.114) usada em terrain.gdshader
## pro terreno solido, pra os dois tratamentos lerem como a MESMA "familia"
## visual de nevoa mesmo sendo calculados em lugares diferentes (shader vs
## GDScript, ver comentario de _apply_prop_fog acima).
func _sepia_prop_color(base_color: Color) -> Color:
	var luminance = base_color.r * 0.299 + base_color.g * 0.587 + base_color.b * 0.114
	var toned_r = lerp(luminance, PROP_SEPIA_TINT.r * (luminance + 0.3), PROP_SEPIA_DESATURATE)
	var toned_g = lerp(luminance, PROP_SEPIA_TINT.g * (luminance + 0.3), PROP_SEPIA_DESATURATE)
	var toned_b = lerp(luminance, PROP_SEPIA_TINT.b * (luminance + 0.3), PROP_SEPIA_DESATURATE)
	return Color(toned_r * (1.0 - PROP_SEPIA_DARKEN), toned_g * (1.0 - PROP_SEPIA_DARKEN), toned_b * (1.0 - PROP_SEPIA_DARKEN), 1.0)

## Todos os tiles a ate `range_dist` passos de `center` (sem contar o
## proprio center). Usado pro alcance de ataque de unidades a distancia
## (arqueiro) — pra unidades corpo-a-corpo (range 1) devolve exatamente os
## vizinhos imediatos, entao substitui get_neighbors() sem quebrar nada.
func tiles_in_range(center: Vector2i, range_dist: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited = {center: 0}
	var frontier: Array[Vector2i] = [center]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		if visited[current] >= range_dist:
			continue
		for n in get_neighbors(current):
			if not visited.has(n):
				visited[n] = visited[current] + 1
				result.append(n)
				frontier.append(n)
	return result

func _mark_visible(center: Vector2i, vision_range: int, out: Dictionary) -> void:
	out[center] = true
	var visited = {center: 0}
	var frontier: Array[Vector2i] = [center]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		if visited[current] >= vision_range:
			continue
		for n in get_neighbors(current):
			if not visited.has(n):
				visited[n] = visited[current] + 1
				out[n] = true
				frontier.append(n)

## Os 6 vizinhos axiais de `coord`, SEM checar se pertencem ao mapa — puro,
## diferente de get_neighbors() (que so devolve vizinhos ja presentes em
## `tiles`). Precisa existir separado porque os passos de pre-calculo de
## geracao (_coastal_distance_by_coord/_land_component_size_by_coord)
## rodam ANTES de `tiles` estar preenchido.
func _neighbor_coords(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in NEIGHBOR_DIRS:
		result.append(coord + dir)
	return result

## Distorce coordenadas do mundo antes de amostrar ruido de elevacao/
## umidade/vulcanico/arcano — sem isso, litorais e fronteiras de bioma
## acompanhariam exatamente as curvas de nivel do ruido base (reconhecivel
## como "ruido de computador", nao geografia organica). O deslocamento vem
## de duas amostras do MESMO _warp_noise (uma normal, outra com offset
## fixo grande o bastante pra nao correlacionar com a primeira) — padrao
## usual de "domain warping".
func _warp_world(world: Vector3) -> Vector2:
	var dx = _warp_noise.get_noise_2d(world.x, world.z) * warp_strength
	var dz = _warp_noise.get_noise_2d(world.x + 1000.0, world.z - 1000.0) * warp_strength
	return Vector2(world.x + dx, world.z + dz)

## 0 no centro DA ZONA (nao mais do mapa inteiro — ver nota de _zone_for
## acima), sobe suavemente ate 1 na borda da zona (comecando em
## edge_falloff_start, ver @export) — multiplicado por edge_falloff_strength
## e subtraido da elevacao (ver _elevation_for) pra garantir que a borda de
## CADA zona seja SEMPRE oceano e a terra fique concentrada no centro dela,
## formando continentes/ilhas separados do resto do mapa em vez de uma
## unica massa retangular colada na borda (o bug original: ruido sem
## mascara nenhuma preenchia o retangulo inteiro de ponta a ponta). Usa a
## distancia Chebyshev (o MAIOR dos dois eixos normalizados) de proposito —
## um falloff radial/eliptico deixaria o meio de cada lado do retangulo sem
## puxao nenhum antes de chegar nos cantos; Chebyshev trata a borda inteira
## igualmente, do jeito que uma zona RETANGULAR pede.
##
## Parametrizada por center/half_w/half_h (nao mais map_width/map_height
## direto) — pedido do usuario: "expandir o tamanho fixo do mapa pra
## acomodar dois novos continentes especiais... mantenha a proporcao de
## mar aberto ao redor dos continentes normais". Se isto continuasse lendo
## map_width/map_height ao vivo, o continente Principal se espalharia pra
## preencher o canvas TOTAL (agora bem maior, pra caber Vulcanico/Cristal)
## em vez de manter a pegada historica de 96x60 — _edge_falloff (a
## variante sem parametro, abaixo) e quem trava isso pra zona Principal.
func _edge_falloff_for_zone(coord: Vector2i, center: Vector2i, half_w: float, half_h: float) -> float:
	var nx = float(coord.x - center.x) / max(half_w, 1.0)
	var nz = float(coord.y - center.y) / max(half_h, 1.0)
	var d = max(abs(nx), abs(nz))
	return smoothstep(edge_falloff_start, 1.0, d)

## Wrapper fino sobre _edge_falloff_for_zone pra zona Principal — mantido
## com o nome/assinatura de sempre pra todo chamador existente continuar
## funcionando sem mudanca nenhuma.
func _edge_falloff(coord: Vector2i) -> float:
	# Mapa ABAIXO do tamanho Grande: sem continentes especiais (ver
	# _zone_for), o mapa INTEIRO e a zona Principal — falloff tem que ser
	# proporcional as dimensoes DELE MESMO (map_width/map_height ao vivo),
	# exatamente como sempre foi, senao um mapa de teste pequeno (ex:
	# 41x41) mal aciona o falloff (que so faria sentido pra um retangulo
	# de 96x60) e gera terra demais/agua de menos. So o tamanho Grande de
	# verdade trava a zona Principal na pegada FIXA historica.
	if not _is_large_map_or_bigger():
		return _edge_falloff_for_zone(coord, MAIN_ZONE_CENTER, float(map_width) / 2.0, float(map_height) / 2.0)
	return _edge_falloff_for_zone(coord, MAIN_ZONE_CENTER, MAIN_ZONE_HALF_WIDTH, MAIN_ZONE_HALF_HEIGHT)

## Elevacao "de verdade" usada por TUDO (agua/plano/colina/montanha, ver
## _generate_tile_data/_tier_for_elevation): ruido de continente de baixa
## frequencia (formas grandes, `_noise`) com coordenadas distorcidas
## (_warp_world, litoral organico) menos a mascara de borda da ZONA a que
## `coord` pertence (ver _zone_for/_edge_falloff_for_zone). Fora de toda
## zona (o oceano de separacao entre continentes) devolve elevacao bem
## abaixo de OCEAN_ELEVATION_THRESHOLD incondicionalmente — oceano
## GARANTIDO por construcao ali, nunca dependente do ruido dar certo.
## Reusa a MESMA instancia de `_noise`/`_warp_world` pras 3 zonas (nao
## precisa de ruido dedicado novo): e um campo continuo infinito, amostrar
## a centenas de tiles de distancia ja da formas descorrelacionadas de
## graca, sem arriscar uma frequencia/seed nova degenerar uma ilha.
## O falloff sobe ate 1.0 na borda da zona; multiplicado por
## edge_falloff_strength (0..1) isso desloca a elevacao ate 1 unidade
## inteira pra baixo — bem mais que o suficiente pra cruzar
## OCEAN_ELEVATION_THRESHOLD mesmo se o ruido cru estivesse no pico (+1)
## bem na borda da zona.
func _elevation_for(coord: Vector2i) -> float:
	var zone = _zone_for(coord)
	if zone == _Zone.NONE:
		return OCEAN_ELEVATION_THRESHOLD - 1.0
	var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	var warped = _warp_world(world)
	var base = _noise.get_noise_2d(warped.x, warped.y)
	match zone:
		_Zone.VOLCANIC:
			return base - _edge_falloff_for_zone(coord, VOLCANIC_ZONE_CENTER, VOLCANIC_ZONE_HALF_WIDTH, VOLCANIC_ZONE_HALF_HEIGHT) * edge_falloff_strength
		_Zone.CRYSTAL:
			return base - _edge_falloff_for_zone(coord, CRYSTAL_ZONE_CENTER, CRYSTAL_ZONE_HALF_WIDTH, CRYSTAL_ZONE_HALF_HEIGHT) * edge_falloff_strength
		_:
			return base - _edge_falloff(coord) * edge_falloff_strength

func _tier_for_elevation(elevation: float) -> int:
	if elevation < OCEAN_ELEVATION_THRESHOLD:
		return _ElevationTier.WATER
	elif elevation >= MOUNTAINS_ELEVATION_THRESHOLD:
		return _ElevationTier.MOUNTAINS
	elif elevation >= HILLS_ELEVATION_THRESHOLD:
		return _ElevationTier.HILLS
	return _ElevationTier.FLAT

## Alem desta distancia (em tiles) da agua mais proxima, nem o bonus de
## umidade litoranea nem as regras de elegibilidade vulcanica (ver
## _is_volcanic_eligible) enxergam diferenca nenhuma — BFS ja pode parar.
const COASTAL_DISTANCE_MAX := 6

## BFS multi-fonte (a partir de TODO tile de agua ao mesmo tempo) pra achar
## a distancia minima ate a agua mais proxima de cada tile de terra — usada
## pra umidade litoranea (_moisture_for) e pra "vulcanico perto de oceano/
## fenda" (_is_volcanic_eligible). O(numero de tiles): cada coord entra na
## fila no maximo uma vez.
func _coastal_distance_by_coord(coords: Array, is_land_by_coord: Dictionary) -> Dictionary:
	var coord_set := {}
	for c in coords:
		coord_set[c] = true
	var dist := {}
	var frontier: Array[Vector2i] = []
	for c in coords:
		if not is_land_by_coord[c]:
			dist[c] = 0
			frontier.append(c)
	var d = 0
	while frontier.size() > 0 and d < COASTAL_DISTANCE_MAX:
		d += 1
		var next_frontier: Array[Vector2i] = []
		for c in frontier:
			for n in _neighbor_coords(c):
				if coord_set.has(n) and not dist.has(n):
					dist[n] = d
					next_frontier.append(n)
		frontier = next_frontier
	return dist

## Tamanho da massa de terra CONECTADA (BFS por vizinhanca real de
## hexagono) a que cada tile de terra pertence — usado pra saber se um tile
## esta numa "ilha isolada" pequena o bastante pra ser elegivel a Campos de
## Cristal (ver _is_crystal_eligible/CRYSTAL_ISLAND_MAX_SIZE). Tiles de
## agua nao entram no dicionario devolvido.
func _land_component_size_by_coord(coords: Array, is_land_by_coord: Dictionary) -> Dictionary:
	var coord_set := {}
	for c in coords:
		coord_set[c] = true
	var visited := {}
	var size_by_coord := {}
	for c in coords:
		if not is_land_by_coord[c] or visited.has(c):
			continue
		var component: Array = []
		var stack: Array = [c]
		visited[c] = true
		while stack.size() > 0:
			var cur: Vector2i = stack.pop_back()
			component.append(cur)
			for n in _neighbor_coords(cur):
				if coord_set.has(n) and is_land_by_coord.get(n, false) and not visited.has(n):
					visited[n] = true
					stack.append(n)
		for cc in component:
			size_by_coord[cc] = component.size()
	return size_by_coord

## Mar Gelado (variante fria do Oceano) e Campos de Cristal (bioma arcano
## original) continuam sendo biomas de "voce encontrou algo especial
## explorando" — limiares altos de proposito. Lava NAO e mais tratada
## assim, ver VOLCANIC_NOISE_THRESHOLD abaixo (a raridade dela agora vem
## de _is_volcanic_eligible(), nao so do limiar de ruido).
const FROZEN_OCEAN_TEMPERATURE_THRESHOLD := 0.12 # abaixo disso, Oceano vira Mar Gelado

## Fracao dos tiles de terra elegivel (ver _is_volcanic_eligible/
## _is_crystal_eligible abaixo) que vira Lava/Cristal quando o ruido
## correspondente passa do limiar — medido empiricamente pra dar regioes de
## tamanho comparavel a Floresta/Selva/Tundra, nunca "5 celulaszinhas" nem
## uma mancha absurda cobrindo a elegibilidade inteira.
const VOLCANIC_NOISE_THRESHOLD := 0.28
## Nucleo mais "quente" de uma regiao de Lava — reusa a MESMA
## `_volcanic_noise`, so com limiar mais alto, entao o Mar de Lava sempre
## nasce DENTRO/perto da regiao de Lava (pedra), nunca solto no meio de
## outro bioma (o mesmo campo de ruido correlacionado espacialmente que
## formou a regiao de pedra continua subindo em direcao ao pico). Tambem
## e o limiar usado pra Oceano virar Mar de Lava (ver _generate_tile_data)
## quando um tile de agua cai numa zona vulcanica de alta temperatura.
const LAVA_SEA_NOISE_THRESHOLD := 0.46
const ARCANE_NOISE_THRESHOLD := 0.4

## Continentes Vulcanico/de Cristal (pedido do usuario: "aplicar a eles o
## mesmo nivel de complexidade, relevo e variacao de microbiomas que o
## Continente Principal possui"). Distancia costeira (mesma unidade de
## _coastal_distance_by_coord) dentro da qual a periferia de CADA zona
## especial vira incondicionalmente Solo de Cinzas/Solo Mistico.
##
## 1 (nao 3) — medido empiricamente apos regressao (a zona Vulcanica
## virou ~60-70% Solo de Cinzas com o valor antigo): zonas especiais sao
## bem menores que o continente Principal (64x42 contra 96x60), e uma
## massa de terra menor tem proporcionalmente MAIS territorio perto da
## propria costa pra qualquer distancia fixa (mesma geometria basica que
## VOLCANIC_COASTAL_MAX_DISTANCE ja documenta pro continente Principal:
## "dobrar o raio so dobra o perimetro mas quadruplica a area") — um
## limiar calibrado pro continente Principal vira desproporcionalmente
## generoso numa zona menor. 1 tile ainda da um anel de praia real e
## visivel, sem dominar o continente.
const SPECIAL_ZONE_PERIPHERY_MAX_DISTANCE := 1
## Limiar de ruido (bem ACIMA de ARCANE_NOISE_THRESHOLD) pra Fonte
## Mistica — "recursos fluidos" do usuario, feature RARA de proposito
## (nascentes especiais, nao um bioma comum), reusando o MESMO
## _arcane_noise ja amostrado pra decidir Campos de Cristal, sem
## reintroduzir o sistema de rio removido antes nesta sessao.
const MYSTIC_SPRING_NOISE_THRESHOLD := 0.72

## Limiares de Lava/Mar de Lava DENTRO da zona Vulcanica — DELIBERADAMENTE
## bem mais baixos que VOLCANIC_NOISE_THRESHOLD/LAVA_SEA_NOISE_THRESHOLD
## (os limiares "legado" do continente Principal, calibrados perto da
## origem do mapa). Regressao critica reportada pelo usuario: "eliminou
## completamente a lava" — _volcanic_noise amostrado bem longe da origem
## (a zona Vulcanica fica centrada em VOLCANIC_ZONE_CENTER, ~148 tiles do
## (0,0)) tem uma faixa de valores LOCAL bem mais estreita (medido
## empiricamente numa amostragem offline da zona: min~-0.68, max~0.42,
## mediana~-0.03) — os limiares legado (0.28/0.46) praticamente nunca
## batiam ali, deixando o continente inteiro sem Lava nenhuma. Recalibrados
## por PERCENTIL da faixa observada, nao valor absoluto: LAVA_THRESHOLD
## perto da mediana (~metade do interior vira Lava-ou-Mar-de-Lava, pedido
## do usuario: "a Lava DEVE ser o elemento fluido dominante desta zona"),
## LAVA_SEA_THRESHOLD no top ~20% (o nucleo mais "quente" vira liquido de
## verdade, mesma proporcao/espirito do limiar legado, so recentralizado).
const VOLCANIC_ZONE_LAVA_THRESHOLD := -0.05
const VOLCANIC_ZONE_LAVA_SEA_THRESHOLD := 0.15

## Limite de vizinhos pra Picos de Cristal (pedido do usuario original:
## "nenhum tile de montanha/vulcao pode ter mais de 2 vizinhos diretos que
## tambem sejam montanhas" — mais estrito que MAX_MOUNTAIN_NEIGHBORS=3 do
## continente Principal). Ver _thin_special_zone_peaks, mesmo algoritmo de
## _thin_mountain_clusters (poda iterativa ate estabilizar).
##
## Montanha Vulcanica (VOLCANIC_PEAKS) NAO usa mais este limiar — pedido do
## usuario numa rodada seguinte, apos ganhar a cratera de vulcao ativo em
## terrain.gdshader: "vulcões tem que estar apenas sozinhos" (o limiar de 2
## ainda deixava ate 3 tiles mutuamente vizinhos sobreviverem juntos, ex:
## um triangulo onde cada um tem exatamente 2 vizinhos-pico — foi
## literalmente reportado assim: "veio 3 vulcoes juntos"). Ver
## VOLCANIC_PEAK_MAX_NEIGHBORS abaixo, zero tolerancia.
const MAX_SPECIAL_ZONE_PEAK_NEIGHBORS := 2

## Vulcao de verdade tem que nascer ISOLADO — zero vizinhos diretos que
## tambem sejam Montanha Vulcanica (ver _thin_special_zone_peaks). Picos de
## Cristal continuam usando MAX_SPECIAL_ZONE_PEAK_NEIGHBORS (podem formar
## pequenas cordilheiras) — so vulcao precisa ficar sozinho.
const VOLCANIC_PEAK_MAX_NEIGHBORS := 0

## Garantia minima de vulcoes por continente Vulcanico (pedido do usuario:
## "tem que ter pelo menos uns 3 por continente de fogo") — a poda de
## isolamento acima (VOLCANIC_PEAK_MAX_NEIGHBORS=0) pode, numa semente
## azarada, derrubar quase todo Pico gerado pela elevacao crua ate sobrar
## menos que isso. Ver _ensure_minimum_volcanic_peaks, chamada logo depois
## de _thin_special_zone_peaks em generate_map().
const MIN_VOLCANIC_PEAKS := 3

## Elevacao < isso vira Oceano/Mar Gelado; senao e terra. Ver _elevation_for
## — elevacao ja inclui a mascara de borda (_edge_falloff), entao este
## limiar sozinho decide a fracao terra/agua do mapa junto com
## edge_falloff_strength/edge_falloff_start (@export) e continent_noise_
## frequency (@export, acima).
##
## -0.38 (era -0.13, pedido do usuario: "mundo esta gerando ~74% de agua...
## sufoca a expansao dos imperios", queria ~50% terra / 50% agua padrao
## "Continentes/Pangaea"). Escolhido varrendo threshold x frequencia
## OFFLINE (amostrando _elevation_for cru em varias sementes, sem pagar o
## custo de generate_map() completo) ate achar o ponto onde a media de 5
## sementes fixas (1, 42, 999, 12345, 7) cai perto de 52% terra / 48% agua
## — perto o bastante do centro da faixa-alvo (45-50% agua) que a variacao
## normal entre sementes (a mesma amostragem mediu ~±5 pontos percentuais
## de uma semente pra outra) nao empurra nenhuma delas pra fora da faixa
## tolerada nos testes (ver test_terrain_generation.gd,
## test_generate_map_water_percentage_stays_within_the_continents_range).
## -0.13 dava so ~22-27% terra com a frequencia antiga — mudar SO a
## frequencia (mais baixa = continentes maiores) sem tambem descer este
## limiar teria deixado o mapa ainda mais aguado, nao menos.
const OCEAN_ELEVATION_THRESHOLD := -0.38
const HILLS_ELEVATION_THRESHOLD := 0.14
const MOUNTAINS_ELEVATION_THRESHOLD := 0.32

## Continentes Vulcanico/de Cristal (pedido do usuario: "dois novos
## continentes especiais... utilizando estritamente os tipos de terreno
## que JA EXISTEM"). O mapa Grande passa a ter 3 "zonas" fixas em
## coordenadas axiais — Principal (a pegada historica 96x60, centro na
## origem, ver TitleScreen.MAIN_ZONE_SIZE), Vulcanica e de Cristal (novas,
## centradas longe da origem) — mais uma margem de oceano GARANTIDO fora
## de toda zona (ver _elevation_for). Layout lado a lado no eixo largo (Q),
## nao na diagonal, pra crescer o canvas so em largura em vez de largura E
## altura juntas. Gap Principal<->cada zona nova: MAIN_ZONE_HALF_WIDTH(48)
## + gap(36) + VOLCANIC_ZONE_HALF_WIDTH(32) = 116, exatamente o centro
## escolhido abaixo — gap sempre >= 36 tiles de oceano garantido por
## construcao (nunca "provavelmente oceano" por sorte de ruido).
const MAIN_ZONE_CENTER := Vector2i(0, 0)
const MAIN_ZONE_HALF_WIDTH := 48.0 # TitleScreen.MAIN_ZONE_SIZE.width / 2
const MAIN_ZONE_HALF_HEIGHT := 30.0 # TitleScreen.MAIN_ZONE_SIZE.height / 2

const VOLCANIC_ZONE_CENTER := Vector2i(-116, 0)
const VOLCANIC_ZONE_HALF_WIDTH := 32.0
const VOLCANIC_ZONE_HALF_HEIGHT := 21.0

const CRYSTAL_ZONE_CENTER := Vector2i(116, 0)
const CRYSTAL_ZONE_HALF_WIDTH := 32.0
const CRYSTAL_ZONE_HALF_HEIGHT := 21.0

enum _Zone { NONE, MAIN, VOLCANIC, CRYSTAL }

## `coord` esta dentro do retangulo (distancia Chebyshev) centrado em
## `center` com as meia-dimensoes dadas — mesmo teste de "esta dentro dos
## limites" usado pelas 3 zonas em _zone_for.
func _in_zone_bounds(coord: Vector2i, center: Vector2i, half_w: float, half_h: float) -> bool:
	return absf(coord.x - center.x) <= half_w and absf(coord.y - center.y) <= half_h

## Qual zona `coord` pertence — fonte unica de verdade consultada por toda
## a geracao de elevacao/bioma/clima que precisa saber "isto e continente
## Principal, Vulcanico, de Cristal, ou nem isso (oceano de separacao)".
func _zone_for(coord: Vector2i) -> int:
	# Mapas ABAIXO do tamanho Grande nao tem continentes especiais nenhum
	## — o mapa INTEIRO e a zona Principal, do jeito que sempre foi (mesmo
	# mapas de teste ad-hoc maiores que 96x60 numa dimensao mas com area
	# total pequena, ex: bem estreitos e compridos, continuam 100% zona
	# Principal). So o tamanho Grande de verdade (com area >= a nova
	# MAP_SIZES.large) usa a classificacao por retangulo fixo abaixo.
	if not _is_large_map_or_bigger():
		return _Zone.MAIN
	if _in_zone_bounds(coord, MAIN_ZONE_CENTER, MAIN_ZONE_HALF_WIDTH, MAIN_ZONE_HALF_HEIGHT):
		return _Zone.MAIN
	if _in_zone_bounds(coord, VOLCANIC_ZONE_CENTER, VOLCANIC_ZONE_HALF_WIDTH, VOLCANIC_ZONE_HALF_HEIGHT):
		return _Zone.VOLCANIC
	if _in_zone_bounds(coord, CRYSTAL_ZONE_CENTER, CRYSTAL_ZONE_HALF_WIDTH, CRYSTAL_ZONE_HALF_HEIGHT):
		return _Zone.CRYSTAL
	return _Zone.NONE

## "Alta temperatura" pro proposito das regras de fantasia abaixo — mesmo
## patamar que _pick_biome ja chama de "quente" (Deserto/Savana/Selva).
const VOLCANIC_MIN_TEMPERATURE := 0.62
## Vulcanico "perto de oceano/fenda": distancia (em tiles) ate a agua mais
## proxima (ver _coastal_distance_by_coord) igual ou menor que isto conta
## como litoraneo/fenda o bastante. Subido de 3 pra 5 (proximo do teto de
## alcance da propria busca, COASTAL_DISTANCE_MAX=6) junto com o
## rebalanceamento de terra/agua (ver OCEAN_ELEVATION_THRESHOLD acima):
## continentes bem maiores/mais conectados tem uma fracao MENOR de terra
## litoranea (menos costa por area, geometria basica — dobrar o raio de um
## continente so dobra o perimetro mas quadruplica a area), entao o mesmo
## raio de 3 tiles passou a cobrir uma fatia proporcionalmente menor da
## terra do que cobria no mundo arquipelago antigo, deixando a regiao
## vulcanica pequena demais perto do resto dos biomas (ver
## test_generate_map_desert_and_volcanic_are_comparable_in_size_to_other_
## biomes/test_generate_map_lava_mostly_occupies_flat_terrain_not_just_
## mountains). Continua estritamente MENOR que o teto de busca (6) —
## "vulcanico no interior profundo, longe de qualquer agua" continua
## impossivel pela via costeira (so resta a via de Montanha).
const VOLCANIC_COASTAL_MAX_DISTANCE := 5
## Faixa fria (Tundra/Taiga, ver _pick_biome) onde a transicao pra
## Colina/Montanha vira elegivel a Campos de Cristal.
const CRYSTAL_TRANSITION_MAX_TEMPERATURE := 0.4
## Massa de terra conectada com ate esse tanto de tiles conta como "ilha
## isolada" pro proposito de Campos de Cristal — grande o bastante pra
## caber uma regiao de verdade (ver FORCED_CLUSTER_SIZE abaixo), pequena o
## bastante pra nunca confundir com um continente principal.
const CRYSTAL_ISLAND_MAX_SIZE := 14

## Regra de fantasia (vulcanico): "so em area de alta temperatura, perto de
## oceano/fenda OU numa altitude alta" — nunca no meio frio do continente
## nem espalhado por qualquer terreno piano ao acaso, pra ler como geografia
## de verdade (cadeia costeira ou platô vulcanico), nao ruido decorativo.
func _is_volcanic_eligible(temperature: float, elevation_tier: int, coastal_distance: int) -> bool:
	if temperature < VOLCANIC_MIN_TEMPERATURE:
		return false
	return coastal_distance <= VOLCANIC_COASTAL_MAX_DISTANCE or elevation_tier == _ElevationTier.MOUNTAINS

## Regra de fantasia (Campos de Cristal): cluster coeso numa TRANSICAO
## tundra/montanha (fria + Colina ou Montanha) OU numa ilha pequena isolada
## — nunca espalhado tile a tile em qualquer planicie comum.
func _is_crystal_eligible(temperature: float, elevation_tier: int, land_component_size: int) -> bool:
	if land_component_size > 0 and land_component_size <= CRYSTAL_ISLAND_MAX_SIZE:
		return true
	return temperature < CRYSTAL_TRANSITION_MAX_TEMPERATURE and (elevation_tier == _ElevationTier.HILLS or elevation_tier == _ElevationTier.MOUNTAINS)

## Regiao litoranea fica mais umida que o interior (geografia real: ventos
## marinhos carregam umidade) — soma um bonus que decai com a distancia ate
## a agua mais proxima (ver _coastal_distance_by_coord) em cima do ruido de
## umidade de sempre. Contribui pra transicao suave Deserto -> Savana ->
## Estepe -> Floresta fazer sentido geografico (deserto tende a nascer
## longe da costa, nao colado nela).
const COASTAL_MOISTURE_BONUS := 0.16
const COASTAL_MOISTURE_RANGE := 3.0

func _moisture_for(warped: Vector2, coastal_distance: int) -> float:
	var base = (_moisture_noise.get_noise_2d(warped.x, warped.y) + 1.0) * 0.5
	var coastal_bonus = clamp(1.0 - float(coastal_distance) / COASTAL_MOISTURE_RANGE, 0.0, 1.0) * COASTAL_MOISTURE_BONUS
	return clamp(base + coastal_bonus, 0.0, 1.0)

## Elevacao continua decidindo agua/colina/montanha (igual antes); o que
## muda e o que preenche a faixa "plana" do meio — usa um segundo eixo de
## umidade (ruido, com bonus litoraneo, ver _moisture_for) cruzado com
## temperatura por latitude (baseada em r, que corresponde a distancia
## norte-sul no mundo — ver HexMetrics.axial_to_world) pra dar biomas de
## verdade tipo Civilization (deserto/savana/selva no "equador", tundra/
## taiga/neve nos "polos"). Vulcanico e Campos de Cristal so entram em jogo
## quando o TILE ja e tematicamente elegivel (ver _is_volcanic_eligible/
## _is_crystal_eligible) — nao em qualquer terra ao acaso.
func _generate_tile_data(coord: Vector2i, elevation: float, coastal_distance: int, land_component_size: int) -> HexTileData:
	var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	var warped = _warp_world(world)
	var temperature = _temperature_for(coord)
	var zone = _zone_for(coord)

	var data: HexTileData
	if elevation < OCEAN_ELEVATION_THRESHOLD:
		# Mar de Lava NUNCA nasce aqui fora da zona Vulcanica (pedido do
		# usuario, regressao: "lava gerando no meio do oceano" — antes
		# disso, qualquer tile de agua aberta com temperatura alta o
		# bastante virava Mar de Lava so pelo ruido vulcanico, SEM NENHUMA
		# relacao com terra vulcanica proxima). Mar de Lava so existe pelo
		# caminho de TERRA abaixo (_maybe_volcanic chamado com land_biome),
		# nasce sempre DENTRO de uma regiao de terra ja vulcanica.
		var water_biome = _pick_water_biome(temperature)
		data = TerrainDatabase.create_tile(water_biome)
	elif zone == _Zone.VOLCANIC:
		# Continente Vulcanico — "plano infernal/Mordor" (pedido do
		# usuario). PRIORIDADE REVISADA DUAS VEZES apos regressoes
		# criticas reportadas: (1) "gerou um bloco massivo com mais de 30
		# montanhas... e eliminou completamente a lava" — elevacao
		# decidindo Picos PRIMEIRO com Colina+Montanha juntas podia
		# consumir a zona inteira; (2) corrigido isso deixando Lava vir
		# ANTES de elevacao, mas ai Lava as vezes reivindicava TODO
		# territorio de elevacao alta tambem, deixando ZERO Picos nalgumas
		# sementes. Solucao final: so elevacao MOUNTAINS (nao mais Colina
		# junto) decide Picos, e ela vem PRIMEIRO — mesma garantia
		# deterministica que o continente Principal ja da pra Montanha de
		# verdade (nao depende de sorte de ruido vulcanico), com pegada
		# inicial pequena o bastante pra sobrar territorio de sobra pra
		# Lava dominar. A PRIMEIRA regra que bater vence:
		var volcanic_elevation_tier = _tier_for_elevation(elevation)
		if volcanic_elevation_tier == _ElevationTier.MOUNTAINS:
			# 1) Cordilheira ("espinha dorsal", pedido do usuario) — SO
			# elevacao MOUNTAINS (nao Colina), pegada inicial pequena;
			# poda de vizinhanca (_thin_special_zone_peaks, chamada depois
			# em generate_map) corta qualquer blob remanescente pra linhas
			# finas/pontos isolados (pedido do usuario: "nenhum tile de
			# montanha pode ter mais de 2 vizinhos diretos que tambem
			# sejam montanha").
			data = TerrainDatabase.create_tile(HexTileData.TerrainType.VOLCANIC_PEAKS)
		elif volcanic_elevation_tier == _ElevationTier.HILLS:
			# 2) Colinas Vulcanicas — elevacao MEDIA (pedido do usuario:
			# "Colinas Vulcanicas: nivel de elevacao medio, adicione
			# variacao de altura 3D") — sem poda de vizinhanca (Colina nao
			# bloqueia nada nem cria "continente morto", so' Montanha
			# precisava da regra estrita de 2 vizinhos).
			data = TerrainDatabase.create_tile(HexTileData.TerrainType.VOLCANIC_HILLS)
		elif coastal_distance <= SPECIAL_ZONE_PERIPHERY_MAX_DISTANCE:
			# 3) Periferia/praia (pedido do usuario: "adicione zonas de
			# Solo de Cinzas/Rocha Negra nas bordas e praias") — anel
			# limpo incondicional perto da costa da PROPRIA zona.
			data = TerrainDatabase.create_tile(HexTileData.TerrainType.VOLCANIC_ASH)
		else:
			# 4) So' o que sobra (Plano, nem periferia) — Lava/Mar de Lava
			# com limiares RECALIBRADOS especificamente pra esta zona (ver
			# VOLCANIC_ZONE_LAVA_THRESHOLD/_SEA_THRESHOLD, a faixa de
			# ruido aqui e bem mais estreita que perto da origem do mapa)
			# pra Lava ser de verdade o elemento DOMINANTE (pedido do
			# usuario: "a Lava DEVE ser o elemento fluido dominante desta
			# zona... grandes corpos fluidos de Lava cortando a massa
			# terrestre"); Terra Vulcanica caminhavel preenche o resto.
			var volcanic_value = _volcanic_noise.get_noise_2d(warped.x, warped.y)
			if volcanic_value > VOLCANIC_ZONE_LAVA_SEA_THRESHOLD:
				data = TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA_SEA)
			elif volcanic_value > VOLCANIC_ZONE_LAVA_THRESHOLD:
				data = TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA)
			else:
				data = TerrainDatabase.create_tile(HexTileData.TerrainType.VOLCANIC_ROCK)
	elif zone == _Zone.CRYSTAL:
		# Continente de Cristal — mesma decisao em camadas do Vulcanico
		# acima, tipos trocados pro tema arcano.
		var crystal_elevation_tier = _tier_for_elevation(elevation)
		if crystal_elevation_tier == _ElevationTier.MOUNTAINS or crystal_elevation_tier == _ElevationTier.HILLS:
			# 1) Cordilheira central (pedido do usuario: "gere Picos/
			# Montanhas de Cristal no interior da massa terrestre").
			data = TerrainDatabase.create_tile(HexTileData.TerrainType.CRYSTAL_PEAKS)
		elif coastal_distance <= SPECIAL_ZONE_PERIPHERY_MAX_DISTANCE:
			# 2) Periferia/costa (pedido do usuario: "transicionando para
			# areas de Solo Mistico/Grama Arcana/Vegetacao Cristalina nas
			# regioes mais baixas e costeiras") — incondicional perto da
			# costa da propria zona.
			data = TerrainDatabase.create_tile(HexTileData.TerrainType.MYSTIC_SOIL)
		else:
			# 3) Interior — MESMO ruido/limiar de sempre pro nucleo denso
			# de Cristal (pedido do usuario: "zonas de Campos de Cristal
			# denso no centro"), com um limiar EXTRA acima (ruido bem mais
			# alto, feature rara) pra Fonte Mistica ("recursos fluidos",
			# sem reintroduzir o sistema de rio removido antes nesta
			# sessao — vira mancha rara em vez de feature linear).
			var arcane_value = _arcane_noise.get_noise_2d(warped.x, warped.y)
			if arcane_value > MYSTIC_SPRING_NOISE_THRESHOLD:
				data = TerrainDatabase.create_tile(HexTileData.TerrainType.MYSTIC_SPRING)
			else:
				data = TerrainDatabase.create_tile(_maybe_crystal(HexTileData.TerrainType.MYSTIC_SOIL, arcane_value))
	else:
		var elevation_tier = _tier_for_elevation(elevation)
		var land_biome: int
		if elevation_tier == _ElevationTier.MOUNTAINS:
			land_biome = HexTileData.TerrainType.MOUNTAINS
		elif elevation_tier == _ElevationTier.HILLS:
			land_biome = HexTileData.TerrainType.HILLS
		else:
			var moisture = _moisture_for(warped, coastal_distance)
			land_biome = _pick_biome(temperature, moisture)

		# So o continente Principal, e so em mapas ABAIXO do tamanho Grande
		# (que ja tem seus proprios continentes Vulcanico/Cristal dedicados
		# — ver ramos acima), continua com o espalhamento probabilistico
		# antigo de Lava/Cristal dentro do continente normal. Pedido do
		# usuario: "remova a geracao pontual/avulsa de Solo Vulcanico,
		# Lava e Solo de Cristal dos continentes normais" — no tamanho
		# Grande, o continente Principal nunca mais chama estas duas
		# funcoes de elegibilidade.
		if not _is_large_map_or_bigger():
			if _is_crystal_eligible(temperature, elevation_tier, land_component_size):
				var arcane_value = _arcane_noise.get_noise_2d(warped.x, warped.y)
				land_biome = _maybe_crystal(land_biome, arcane_value)

			if _is_volcanic_eligible(temperature, elevation_tier, coastal_distance):
				var volcanic_value = _volcanic_noise.get_noise_2d(warped.x, warped.y)
				land_biome = _maybe_volcanic(land_biome, volcanic_value)

		data = TerrainDatabase.create_tile(land_biome)

	_maybe_assign_resource(data, coord, world)
	return data

## Pura, igual _pick_biome — Mar Gelado e a variante polar do Oceano ("os
## mares", pedido do usuario).
func _pick_water_biome(temperature: float) -> int:
	return HexTileData.TerrainType.FROZEN_OCEAN if temperature < FROZEN_OCEAN_TEMPERATURE_THRESHOLD else HexTileData.TerrainType.OCEAN

## Pura — Campos de Cristal (bioma arcano original) so substitui um bioma
## "plano" ja escolhido quando o ruido arcano passa do limiar raro,
## nunca Oceano/Colina/Montanha (essas ja se resolveram antes de chegar
## aqui, ver _generate_tile_data).
func _maybe_crystal(biome: int, arcane_value: float) -> int:
	return HexTileData.TerrainType.CRYSTAL if arcane_value > ARCANE_NOISE_THRESHOLD else biome

## Pura, mesma ideia de _maybe_crystal — Lava substitui QUALQUER bioma de
## terra firme ja escolhido (plano, Colina ou Montanha) quando o ruido
## vulcanico passa do limiar raro, senao devolve o bioma original sem
## mexer. Nunca chamada pra Oceano/Mar Gelado (ver _generate_tile_data).
## Mar de Lava (roadmap item 32) e um segundo limiar, mais alto, sobre o
## MESMO ruido — o nucleo mais quente de uma regiao de Lava vira liquido
## de verdade em vez de pedra, ver LAVA_SEA_NOISE_THRESHOLD.
func _maybe_volcanic(biome: int, volcanic_value: float) -> int:
	if volcanic_value > LAVA_SEA_NOISE_THRESHOLD:
		return HexTileData.TerrainType.LAVA_SEA
	if volcanic_value > VOLCANIC_NOISE_THRESHOLD:
		return HexTileData.TerrainType.LAVA
	return biome

## Regressao critica ("nenhum bioma deve ser tao pequeno ao ponto de
## formar celulas isoladas de um bioma... deserto e vulcanico sao os
## piores... tem uma floresta gigante e 1 celula de vulcanico", reportado
## pelo usuario DUAS vezes seguidas): cortar um campo de ruido continuo em
## faixas com limiares fixos (`_pick_biome`, `_maybe_volcanic`,
## `_maybe_crystal`) sempre deixa alguns tiles isolados perto das bordas
## de cada faixa — um pixel de ruido que cruza o limiar sozinho, cercado
## por vizinhos de um bioma diferente, mesmo com os ruidos ja de baixa
## frequencia (roadmap item 28). Chamada logo depois do loop principal de
## geracao (ANTES de
## `_ensure_biome_variety`, que roda so no Grande e ja garante suas
## proprias regioes/clusters — nao deveria ser "limpo" por engano) e vale
## pra TODO tamanho de mapa: qualquer tile cujo bioma nao bate com NENHUM
## vizinho vira o bioma mais comum entre os vizinhos (empate resolvido
## pelo id mais baixo, deterministico). So conta como "isolado" quando
## nenhum vizinho compartilha o mesmo bioma — clusters de 2+ tiles (o
## objetivo real de "formar biomas") nunca sao tocados.
##
## Roda em passadas (ate SMOOTH_MAX_PASSES) em vez de uma unica vez:
## como cada passada calcula TODAS as mudancas a partir do estado ORIGINAL
## (antes de aplicar qualquer uma) e so aplica tudo no final, dois tiles
## isolados vizinhos um do outro podem "trocar de lugar" numa passada so
## (A vira o bioma antigo de B, B vira o bioma antigo de A) e continuarem
## sem bater entre si — bug pego pelo proprio teste de regressao deste
## item. Repetir a passada resolve: a segunda passada ve o resultado JA
## aplicado da primeira, entao qualquer troca que nao tenha se resolvido
## fica visivel e e corrigida de novo. Poucas passadas bastam na pratica
## (esse tipo de troca mutua e raro); o limite so existe pra nunca rodar
## sem fim.
const SMOOTH_MAX_PASSES := 5

func _smooth_isolated_biome_cells() -> void:
	for _pass_index in range(SMOOTH_MAX_PASSES):
		var changes := {}
		for coord in tiles.keys():
			var terrain_type = tiles[coord].terrain_type
			# Vulcao PRECISA ficar isolado (VOLCANIC_PEAK_MAX_NEIGHBORS=0, ver
			# _thin_special_zone_peaks/pedido do usuario: "vulcões tem que
			# estar apenas sozinhos") — sem esta excecao, esta MESMA funcao
			# convertia de volta pro bioma vizinho qualquer Montanha Vulcanica
			# isolada de verdade (0 vizinhos do mesmo tipo e exatamente a
			# definicao de "isolado" que o resto do loop abaixo usa pra
			# LIMPAR biomas indesejados) — so sobreviviam ate aqui os
			# aglomerados de 2-3 tiles mutuamente vizinhos, que e literalmente
			# o bug reportado ("veio 3 vulcoes juntos").
			if terrain_type == HexTileData.TerrainType.VOLCANIC_PEAKS:
				continue
			var neighbors = get_neighbors(coord)
			if neighbors.is_empty():
				continue
			var is_isolated = true
			var neighbor_counts := {}
			for n in neighbors:
				var n_type = tiles[n].terrain_type
				if n_type == terrain_type:
					is_isolated = false
					break
				neighbor_counts[n_type] = neighbor_counts.get(n_type, 0) + 1
			if not is_isolated:
				continue
			var best_type = -1
			var best_count = 0
			var sorted_types: Array = neighbor_counts.keys()
			sorted_types.sort()
			for t in sorted_types:
				if neighbor_counts[t] > best_count:
					best_count = neighbor_counts[t]
					best_type = t
			changes[coord] = best_type

		if changes.is_empty():
			return

		for coord in changes.keys():
			var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
			var data = TerrainDatabase.create_tile(changes[coord])
			_maybe_assign_resource(data, coord, world)
			tiles[coord] = data

## LAVA/CRYSTAL removidos desta lista (pedido do usuario: "remova a
## geracao pontual/avulsa de Solo Vulcanico, Lava e Solo de Cristal dos
## continentes normais") — o continente Principal, no tamanho Grande,
## nunca mais gera nenhum dos dois (ver _generate_tile_data), entao nao
## faz sentido _ensure_biome_variety forcar cluster deles la. Os dois
## continuam garantidos, so que pelos continentes Vulcanico/Cristal
## dedicados (deterministicos por construcao, ver _zone_for), nao por
## este mecanismo probabilistico.
const ALL_BIOME_TYPES := [
	HexTileData.TerrainType.OCEAN, HexTileData.TerrainType.SNOW, HexTileData.TerrainType.TUNDRA,
	HexTileData.TerrainType.TAIGA, HexTileData.TerrainType.DESERT, HexTileData.TerrainType.SAVANNA,
	HexTileData.TerrainType.JUNGLE, HexTileData.TerrainType.PLAINS, HexTileData.TerrainType.GRASSLAND,
	HexTileData.TerrainType.FOREST, HexTileData.TerrainType.HILLS, HexTileData.TerrainType.MOUNTAINS,
	HexTileData.TerrainType.FROZEN_OCEAN, HexTileData.TerrainType.ICE,
]
## Campos de Cristal incluido aqui (regra de fantasia: "transicoes entre
## tundra e montanhas", ver _is_crystal_eligible) — quando o fallback
## forcado precisa plantar uma semente do zero, prefere o candidato mais
## FRIO disponivel na faixa de Colina (ver _BIOME_ELEVATION_TIER abaixo),
## aproximando o resultado forcado da mesma regra tematica da geracao
## natural em vez de cair em qualquer planicie ao acaso.
const COLD_BIOMES := [HexTileData.TerrainType.SNOW, HexTileData.TerrainType.TUNDRA, HexTileData.TerrainType.TAIGA, HexTileData.TerrainType.ICE, HexTileData.TerrainType.CRYSTAL]
## Lava incluida aqui (regra de fantasia: "so em area de alta temperatura",
## ver _is_volcanic_eligible) — quando _find_forceable_tile precisa plantar
## uma semente de Lava do zero (fallback raro, mapa Grande+), prefere o
## candidato mais QUENTE disponivel em vez de ignorar temperatura, mesmo
## vies que Deserto/Savana/Selva ja tinham.
const HOT_BIOMES := [HexTileData.TerrainType.DESERT, HexTileData.TerrainType.SAVANNA, HexTileData.TerrainType.JUNGLE, HexTileData.TerrainType.LAVA]

enum _ElevationTier { WATER, FLAT, HILLS, MOUNTAINS }

## Elevacao (agua/plano/colina/montanha) so pra saber que tipo de tile um
## coord PODERIA virar se forcado — mesma elevacao/limiares de
## _generate_tile_data (_elevation_for/_tier_for_elevation), so devolvendo
## a faixa em vez do bioma final.
func _elevation_tier(coord: Vector2i) -> int:
	return _tier_for_elevation(_elevation_for(coord))

const _BIOME_ELEVATION_TIER := {
	HexTileData.TerrainType.OCEAN: _ElevationTier.WATER,
	HexTileData.TerrainType.FROZEN_OCEAN: _ElevationTier.WATER,
	HexTileData.TerrainType.HILLS: _ElevationTier.HILLS,
	HexTileData.TerrainType.MOUNTAINS: _ElevationTier.MOUNTAINS,
	# Campos de Cristal usa Colina de proposito (regra de fantasia: cluster
	# forcado nasce numa "transicao tundra/montanha", ver COLD_BIOMES acima
	# e _is_crystal_eligible) — nao FLAT, diferente do resto.
	HexTileData.TerrainType.CRYSTAL: _ElevationTier.HILLS,
	# todo o resto (biomas "planos": Neve, Tundra, Taiga, Deserto, Savana,
	# Selva, Estepe, Planicie, Floresta, Gelo Eterno, e Lava — nasce em
	# QUALQUER terra firme, entao usar FLAT aqui so decide onde o primeiro
	# tile forcado nasce quando a semente nunca formou nenhuma Lava
	# natural; o crescimento em _find_cluster_neighbors depois trata Lava
	# como caso especial e aceita Colina e Montanha vizinhas tambem, ver
	# la) usa FLAT, ver Dictionary.get() abaixo.
}

## No tamanho Grande (ou maior) pra cima, todo bioma deveria aparecer
## formando uma REGIAO minima de verdade — pedido do usuario, DUAS vezes
## seguidas: primeiro "acho que faz sentido todos os biomas sempre serem
## gerados pelo menos no grande", depois "nenhum bioma deve ser tao
## pequeno ao ponto de formar celulas isoladas... quero que todos os
## biomas sejam relativamente grandes". Nao basta um bioma EXISTIR no
## mapa (a checagem antiga) — se so tem 1-2 tiles espalhados, ainda conta
## como "isolado" pro usuario, entao _ensure_forced_region() checa a
## MAIOR regiao conectada de cada bioma e so entra em acao se ela nao
## bater FORCED_CLUSTER_MIN. Mapas menores que o Grande continuam 100%
## probabilisticos de proposito (biomas raros as vezes nao aparecerem
## mantem uma sensacao real de descoberta — "nos outros talvez faça
## sentido ter menos", palavras do proprio usuario) — a limpeza de
## celulas isoladas ai vem so de _smooth_isolated_biome_cells(), chamada
## ANTES desta funcao pra todo tamanho de mapa.
func _ensure_biome_variety() -> void:
	if not _is_large_map_or_bigger():
		return

	# So escopo pra zona Principal — sem isso, este passo (que nao sabe
	# nada de zona) plantaria cluster forcado de DESERTO/NEVE/OCEANO/etc
	# em cima dos continentes Vulcanico/de Cristal, corrompendo a
	# composicao estritamente Lava/Cristal deles.
	var sorted_coords: Array = tiles.keys().filter(func(c): return _zone_for(c) == _Zone.MAIN)
	sorted_coords.sort()
	var claimed := {}
	var min_dist = _min_distance_from_center()

	for terrain_type in ALL_BIOME_TYPES:
		_ensure_forced_region(terrain_type, sorted_coords, claimed, min_dist)

## Tile elegivel pro bioma pedido: faixa de elevacao compativel, longe o
## bastante do centro, e ainda nao reivindicado por outro bioma forcado
## nesta mesma chamada. Biomas frios/quentes preferem o candidato de
## temperatura mais EXTREMA disponivel (o mais frio pra Neve/Tundra/
## Taiga/Gelo, o mais quente pra Deserto/Savana/Selva) em vez do primeiro
## que aparecer, pra nao acabar plantando um deserto bem numa faixa fria
## so por coincidencia de ordenacao. Os demais (sem preferencia de
## temperatura, ex: Campos de Cristal) preferem o candidato com MAIS
## vizinhos ja da mesma faixa de elevacao — regressao pega testando este
## item: escolher literalmente o primeiro candidato em ordem de coord
## sempre cai perto da BORDA do mapa (coord ordenado por q depois r,
## entao o primeiro elegivel tende a ser q minimo), onde o tile tem menos
## vizinhos de verdade e a garantia de regiao (_ensure_forced_region)
## podia nao achar NENHUM vizinho elegivel pra crescer, deixando o bioma
## preso a 1 tile isolado mesmo depois de "forcado".
func _find_forceable_tile(terrain_type: int, sorted_coords: Array, claimed: Dictionary, min_dist: float):
	var required_tier: int = _BIOME_ELEVATION_TIER.get(terrain_type, _ElevationTier.FLAT)
	var prefer_cold = terrain_type in COLD_BIOMES
	var prefer_hot = terrain_type in HOT_BIOMES

	var best = null
	var best_temp = 0.0
	var best_same_tier_neighbors = -1
	for coord in sorted_coords:
		if claimed.has(coord):
			continue
		if HexMetrics.axial_distance(coord, Vector2i.ZERO) < min_dist:
			continue
		if _elevation_tier(coord) != required_tier:
			continue
		if not prefer_cold and not prefer_hot:
			var same_tier_neighbors = 0
			for n in get_neighbors(coord):
				if _elevation_tier(n) == required_tier:
					same_tier_neighbors += 1
			if same_tier_neighbors > best_same_tier_neighbors:
				best_same_tier_neighbors = same_tier_neighbors
				best = coord
			continue
		var temp = _temperature_for(coord)
		if best == null or (prefer_cold and temp < best_temp) or (prefer_hot and temp > best_temp):
			best = coord
			best_temp = temp
	if best != null:
		claimed[best] = true
		return best

	# Nenhum tile bateu a faixa de elevacao EXATA — pode acontecer com
	# ruido de baixa frequencia (correlacao espacial maior = mais chance
	# de uma semente especifica nunca alcancar o extremo de elevacao em
	# lugar nenhum do mapa, mesmo num mapa Grande com milhares de tiles).
	# Cai pro candidato de elevacao mais PROXIMA do que o bioma pede
	# (o mais alto pra Colina/Montanha, o mais baixo pra Oceano) em vez de
	# deixar o bioma faltando de vez — bioma "plano" nunca cai aqui na
	# pratica (sempre sobra candidato de sobra).
	if required_tier == _ElevationTier.FLAT:
		return null
	return _find_closest_elevation_tile(required_tier, sorted_coords, claimed, min_dist)

## Fallback de _find_forceable_tile: candidato de elevacao mais extrema
## disponivel (mais alta pra Colina/Montanha, mais baixa pra Oceano),
## ignorando a faixa exata — usado so quando nao existe NENHUM tile na
## faixa pedida.
func _find_closest_elevation_tile(required_tier: int, sorted_coords: Array, claimed: Dictionary, min_dist: float):
	var want_high = required_tier == _ElevationTier.MOUNTAINS or required_tier == _ElevationTier.HILLS
	var best = null
	var best_elevation = -INF if want_high else INF
	for coord in sorted_coords:
		if claimed.has(coord):
			continue
		if HexMetrics.axial_distance(coord, Vector2i.ZERO) < min_dist:
			continue
		var elevation = _elevation_for(coord)
		if (want_high and elevation > best_elevation) or (not want_high and elevation < best_elevation):
			best_elevation = elevation
			best = coord
	if best != null:
		claimed[best] = true
	return best

## Tamanho alvo da regiao quando _ensure_forced_region precisa crescer um
## bioma — pedido do usuario: "nao... um unico bloco... seria um bioma
## agrupado" (Lava) e depois "quero que todos os biomas sejam
## relativamente grandes" (generalizado pra qualquer bioma forcado).
const FORCED_CLUSTER_SIZE := 5

## Abaixo disso a regiao natural de um bioma conta como "isolada" pro
## proposito de _ensure_forced_region — 1 ou 2 tiles soltos (mesmo que
## tecnicamente "presentes" no mapa) ainda parecem exatamente as "celulas
## isoladas" que o usuario reportou, entao tambem contam como precisando
## de reforco, nao so ausencia total.
const FORCED_CLUSTER_MIN := 3

## Garantia de regiao minima dentro de _ensure_biome_variety, generalizada
## pra QUALQUER bioma (era so pra Lava, roadmap item 29 — o usuario voltou
## a reportar celulas isoladas de OUTROS biomas tambem, principalmente
## Deserto, entao a garantia de regiao real precisa valer pra todos, nao
## so o vulcanico). Nao basta o bioma EXISTIR no mapa, precisa formar uma
## REGIAO minima de verdade. Se a maior regiao conectada desse bioma ja no
## mapa bate FORCED_CLUSTER_MIN, nao mexe em nada (a natural ja esta boa).
## Senao, cresce a partir de um tile existente desse bioma (se houver
## algum) ou, se nao existir NENHUM, forca um tile novo do zero (mesma
## logica de sempre, `_find_forceable_tile`) e cresce a partir dele.
func _ensure_forced_region(terrain_type: int, sorted_coords: Array, claimed: Dictionary, min_dist: float) -> void:
	var existing_coords: Array = []
	for coord in tiles.keys():
		if tiles[coord].terrain_type == terrain_type:
			existing_coords.append(coord)

	var largest_cluster = _largest_cluster_of(terrain_type, existing_coords)
	if largest_cluster.size() >= FORCED_CLUSTER_MIN:
		return

	if largest_cluster.is_empty():
		var target = _find_forceable_tile(terrain_type, sorted_coords, claimed, min_dist)
		if target == null:
			return # mapa sem nenhum candidato elegivel (bem raro no tamanho Grande)
		_write_forced_tile(terrain_type, target)
		largest_cluster = [target]

	var needed = FORCED_CLUSTER_SIZE - largest_cluster.size()
	if needed <= 0:
		return
	var extra = _find_cluster_neighbors(terrain_type, largest_cluster, claimed, min_dist, needed)
	for coord in extra:
		_write_forced_tile(terrain_type, coord)

## So usado por _ensure_forced_region: escreve o tile forcado de verdade
## em `tiles` (bug encontrado testando o item 30 generalizado — o tile
## "semente" de uma regiao forcada do zero, `target` acima, ficava so na
## Limite de vizinhos de Montanha (pedido do usuario: "montanhas gerando em
## blocos gigantescos/massivos... nenhum tile de montanha pode ter mais de
## 3 vizinhos diretos que tambem sejam montanha"). Qualquer tile de
## Montanha respeitando isso so pode fazer parte de uma linha/parede fina
## (no MAXIMO um "T" ou cotovelo largo) — um blob solido inevitavelmente
## tem tiles interiores com 5-6 vizinhos de Montanha, entao violam sempre.
const MAX_MOUNTAIN_NEIGHBORS := 3

## Erosao iterativa (pedido do usuario, "Restruturacao da Geracao de
## Montanhas"): cada PASSADA acha TODOS os tiles violando MAX_MOUNTAIN_
## NEIGHBORS usando o estado do INICIO da passada (nao recalcula no meio —
## senao a ordem de iteracao de tiles.keys() mudaria o resultado final) e
## rebaixa todos de uma vez; repete ate nao sobrar violacao nenhuma. Sempre
## converge: cada passada com violacao remove PELO MENOS 1 tile de
## Montanha, e o total de tiles de Montanha so' diminui (nunca cresce) —
## nao ha como entrar em loop infinito. Rodando um blob solido, isso poda
## as camadas internas passada a passada ate sobrar so' um "anel"/parede
## fina de 1-2 tiles de espessura nas bordas do blob original, exatamente
## a leitura de "cordilheira" pedida — muito mais barato e prevcircavel
## que remodelar o ruido de elevacao inteiro (`_elevation_for`), que
## alimenta tambem agua/costa/Colina e varias regras de elegibilidade
## (vulcanico/cristal) ja calibradas em rodadas anteriores.
##
## So mexe em tiles cujo terrain_type JA E MOUNTAINS no momento da chamada
## — chamada DEPOIS de _generate_tile_data/_maybe_volcanic/_maybe_crystal
## decidirem o bioma final de cada coord (ver generate_map), entao um tile
## que a elevacao marcou como "faixa de Montanha" mas que virou Lava/
## Cristal (land_biome sobrescrito) nunca e tocado aqui — thinning nao
## interfere nas contagens/proporcoes de vulcanico/cristal ja resolvidas.
## Fallback tematico (pedido do usuario: "converta o tile interno para
## Colina (Hills) ou Neve (Snow/Tundra)"): Neve pra clima frio (mesmo
## SNOW_TEMPERATURE_THRESHOLD ja usado em _temp_band_for), Colina pro
## resto — mesmo par HOT/COLD_BIOMES usado alhures neste arquivo.
func _thin_mountain_clusters() -> void:
	while true:
		var to_downgrade: Array[Vector2i] = []
		for coord in tiles.keys():
			var data: HexTileData = tiles[coord]
			if data.terrain_type != HexTileData.TerrainType.MOUNTAINS:
				continue
			var mountain_neighbors := 0
			for n in get_neighbors(coord):
				var ndata: HexTileData = tiles.get(n)
				if ndata != null and ndata.terrain_type == HexTileData.TerrainType.MOUNTAINS:
					mountain_neighbors += 1
			if mountain_neighbors > MAX_MOUNTAIN_NEIGHBORS:
				to_downgrade.append(coord)
		if to_downgrade.is_empty():
			return

		for coord in to_downgrade:
			var fallback = HexTileData.TerrainType.SNOW if _temperature_for(coord) < SNOW_TEMPERATURE_THRESHOLD else HexTileData.TerrainType.HILLS
			_write_forced_tile(fallback, coord)

## Mesmo algoritmo de erosao iterativa de _thin_mountain_clusters acima
## (converge do mesmo jeito: cada passada com violacao remove PELO MENOS
## 1 tile, entao o total so' diminui, nunca entra em loop infinito),
## aplicado as Montanhas Vulcanicas/Picos de Cristal dos continentes
## especiais — regressao critica reportada pelo usuario: "gerou um bloco
## massivo com mais de 30 montanhas... agrupadas no centro" (o ramo de
## _generate_tile_data pra essas zonas escolhe o tipo por elevacao SEM
## nenhuma poda depois, entao um platô de elevacao alta virava um blob
## solido de Peaks, exatamente esse bug). Limite mais ESTRITO que
## MAX_MOUNTAIN_NEIGHBORS (ver MAX_SPECIAL_ZONE_PEAK_NEIGHBORS=2, pedido
## explicito do usuario) — "espalhe os vulcoes como picos isolados... ou
## no maximo pequenas cordilheiras em linha de 1 tile de largura", mais
## rigoroso que a "parede/anel" que o continente Principal aceita.
## Rebaixa sempre pro tipo-base CAMINHAVEL da propria zona (Terra
## Vulcanica/Solo Mistico) — nunca de volta pra Lava/Cristal (que tem seu
## proprio criterio de ruido, ja decidido antes desta poda rodar).
func _thin_special_zone_peaks() -> void:
	var peak_to_base := {
		HexTileData.TerrainType.VOLCANIC_PEAKS: HexTileData.TerrainType.VOLCANIC_ROCK,
		HexTileData.TerrainType.CRYSTAL_PEAKS: HexTileData.TerrainType.MYSTIC_SOIL,
	}
	# Vulcao exige isolamento TOTAL (VOLCANIC_PEAK_MAX_NEIGHBORS=0); Cristal
	# continua no limiar mais frouxo de sempre (MAX_SPECIAL_ZONE_PEAK_
	# NEIGHBORS=2, pode formar pequena cordilheira) — ver comentario das
	# duas constantes.
	var peak_max_neighbors := {
		HexTileData.TerrainType.VOLCANIC_PEAKS: VOLCANIC_PEAK_MAX_NEIGHBORS,
		HexTileData.TerrainType.CRYSTAL_PEAKS: MAX_SPECIAL_ZONE_PEAK_NEIGHBORS,
	}
	while true:
		var to_downgrade: Array[Vector2i] = []
		for coord in tiles.keys():
			var terrain_type = tiles[coord].terrain_type
			if not peak_to_base.has(terrain_type):
				continue
			var peak_neighbors := 0
			for n in get_neighbors(coord):
				var ndata: HexTileData = tiles.get(n)
				if ndata != null and ndata.terrain_type == terrain_type:
					peak_neighbors += 1
			if peak_neighbors > peak_max_neighbors[terrain_type]:
				to_downgrade.append(coord)
		if to_downgrade.is_empty():
			return

		for coord in to_downgrade:
			_write_forced_tile(peak_to_base[tiles[coord].terrain_type], coord)

## Garantia minima de vulcoes por continente Vulcanico (ver MIN_VOLCANIC_
## PEAKS/pedido do usuario: "tem que ter pelo menos uns 3 por continente de
## fogo") — a poda de isolamento total acima (VOLCANIC_PEAK_MAX_NEIGHBORS=0)
## pode, numa semente azarada, derrubar quase todo Pico que a elevacao crua
## tinha proposto ate sobrar menos que isso. Promove tiles CAMINHAVEIS da
## propria zona Vulcanica (nunca Lava/Mar de Lava, que tem seu proprio
## criterio de ruido ja decidido) que ainda nao sao vizinhos de nenhum Pico
## existente — mantendo o MESMO isolamento total exigido de qualquer
## vulcao, inclusive entre os proprios candidatos promovidos NESTA MESMA
## passada (`peak_count`/checagem de vizinhanca atualizam a cada promocao).
## Preferencia por Rocha/Colina Vulcanica (interior) sobre Solo de Cinzas
## (periferia/praia) — um vulcao na beira da praia lê estranho tematicamente,
## so cai nela se o interior nao tiver candidato isolado suficiente. Ordem
## de iteracao de `tiles` e a mesma sempre (insercao determinada pela
## sequencia de coords de generate_map), entao nenhuma aleatoriedade nova
## entra na geracao do mapa — mesma semente continua dando o mesmo mapa.
func _ensure_minimum_volcanic_peaks() -> void:
	var peak_count := 0
	var interior_candidates: Array[Vector2i] = []
	var periphery_candidates: Array[Vector2i] = []
	for coord in tiles.keys():
		if _zone_for(coord) != _Zone.VOLCANIC:
			continue
		var terrain_type = tiles[coord].terrain_type
		if terrain_type == HexTileData.TerrainType.VOLCANIC_PEAKS:
			peak_count += 1
		elif terrain_type == HexTileData.TerrainType.VOLCANIC_ROCK or terrain_type == HexTileData.TerrainType.VOLCANIC_HILLS:
			interior_candidates.append(coord)
		elif terrain_type == HexTileData.TerrainType.VOLCANIC_ASH:
			periphery_candidates.append(coord)

	if peak_count >= MIN_VOLCANIC_PEAKS:
		return

	for candidates in [interior_candidates, periphery_candidates]:
		for coord in candidates:
			if peak_count >= MIN_VOLCANIC_PEAKS:
				return
			var has_peak_neighbor := false
			for n in get_neighbors(coord):
				var ndata: HexTileData = tiles.get(n)
				if ndata != null and ndata.terrain_type == HexTileData.TerrainType.VOLCANIC_PEAKS:
					has_peak_neighbor = true
					break
			if has_peak_neighbor:
				continue
			_write_forced_tile(HexTileData.TerrainType.VOLCANIC_PEAKS, coord)
			peak_count += 1

## lista local `largest_cluster` pra fins de contagem/BFS, mas nunca era
## de fato escrito em `tiles`; se nenhum vizinho elegivel fosse encontrado
## depois, o bioma inteiro acabava sumindo do mapa — foi assim que
## Montanha sumiu de vez de uma semente durante os testes deste item).
func _write_forced_tile(terrain_type: int, coord: Vector2i) -> void:
	var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	var data = TerrainDatabase.create_tile(terrain_type)
	_maybe_assign_resource(data, coord, world)
	tiles[coord] = data

## Garantia pro Mar de Lava no tamanho Grande (roadmap item 32, pedido do
## usuario: "pegar o sistema de oceano que temos e fazer um igual so que
## vermelho"): o limiar mais alto do ruido vulcanico (LAVA_SEA_NOISE_
## THRESHOLD) da Mar de Lava na MAIORIA das sementes Grande com regiao de
## Lava (medido: 14/15), mas nao em TODAS. Se o mapa nao tem NENHUM Mar de
## Lava natural, converte 2 tiles VIZINHOS entre si (nunca isolados, ver
## roadmap item 31) de dentro da maior regiao de Lava (pedra) ja
## garantida existir (itens 29/31) — nunca cria uma regiao vulcanica nova
## do zero, so "abre uma poca" dentro da que ja existe. Se a regiao de
## Lava nem existe (sementes sem elegibilidade nenhuma, bem raro), nao
## faz nada — nao da pra ter Mar de Lava sem Lava.
func _ensure_lava_sea_present() -> void:
	if not _is_large_map_or_bigger():
		return
	for data in tiles.values():
		if data.terrain_type == HexTileData.TerrainType.LAVA_SEA:
			return

	var lava_coords: Array = []
	for coord in tiles.keys():
		if tiles[coord].terrain_type == HexTileData.TerrainType.LAVA:
			lava_coords.append(coord)
	var largest = _largest_cluster_of(HexTileData.TerrainType.LAVA, lava_coords)
	if largest.is_empty():
		return

	largest.sort()
	var lava_set := {}
	for c in largest:
		lava_set[c] = true

	var seed_coord: Vector2i = largest[0]
	var to_convert: Array = [seed_coord]
	for n in get_neighbors(seed_coord):
		if lava_set.has(n):
			to_convert.append(n)
			break

	for coord in to_convert:
		var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
		var data = TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA_SEA)
		_maybe_assign_resource(data, coord, world)
		tiles[coord] = data

## Converte todo tile de Oceano (nao Mar Gelado/Mar de Lava, ver
## HexTileData.TerrainType.COAST) vizinho de PELO MENOS um tile de terra
## firme solida OU de outro tile ja convertido em Costa em Costa (pedido do
## usuario: "Coast" tipo Civilization, com rendimento de cidade proprio,
## ver TerrainDatabase/City.can_be_worked). So roda DEPOIS de todo o mapa
## ja estar gerado — precisa conhecer os vizinhos de CADA tile, que so existem depois da
## geracao completa rodar uma vez. "Terra firme" aqui e "nao e agua nem
## lava" (data.is_water()/is_lava()) — Mar de Lava, por exemplo, NAO conta
## como terra firme, entao Oceano encostado nele nao vira Costa so por
## causa disso.
##
## Em PASSADAS (ate COAST_RECLASSIFY_MAX_PASSES) em vez de uma unica
## varredura — bug de regressao pego pelo proprio test_generate_map_never_
## has_isolated_single_tile_biomes (invariante: NENHUM tile de NENHUM
## bioma pode ficar sem vizinho do mesmo tipo): uma unica passada podia (1)
## deixar um Oceano "preso" isolado, cercado so por Costa recem-convertida
## (todos os vizinhos dele tocavam terra, mas ele mesmo nao tocava terra
## DIRETAMENTE, so Costa), ou (2) deixar uma Costa isolada na ponta de uma
## peninsula, cercada so por Oceano aberto que nao toca terra por si so.
## Reconsiderar Costa como um "gatilho" valido (nao so terra firme) a cada
## passada seguinte resolve os dois: o Oceano preso vira Costa na proxima
## passada (agora tem vizinho Costa), e isso por sua vez da a Costa da
## peninsula um vizinho Costa de verdade.
##
## Constante PROPRIA (nao SMOOTH_MAX_PASSES de _smooth_isolated_biome_
## cells, que so precisa de 5) — bug de regressao real pego testando: perto
## dos polos, onde Mar Gelado cerca um bolsao de Oceano aberto, a "cadeia"
## de vizinhanca ate a terra firme mais proxima as vezes passa de 5 saltos,
## e o Oceano preso ficava sem converter (5 passadas nao bastavam,
## precisava de 6 nesse caso especifico). 30 e uma folga generosa sobre
## qualquer cadeia realista; o loop sai cedo (`to_convert.is_empty()`)
## assim que estabiliza, entao o custo extra so aparece se realmente
## precisar de mais passadas, nunca em mapas sem esse bolsao.
const COAST_RECLASSIFY_MAX_PASSES := 30

func _reclassify_coastal_ocean() -> void:
	for _pass_index in range(COAST_RECLASSIFY_MAX_PASSES):
		var to_convert: Array[Vector2i] = []
		for coord in tiles.keys():
			var data: HexTileData = tiles[coord]
			if data.terrain_type != HexTileData.TerrainType.OCEAN:
				continue
			for dir in NEIGHBOR_DIRS:
				var n = coord + dir
				var ndata: HexTileData = tiles.get(n, null)
				if ndata == null:
					continue
				var neighbor_triggers_coast = (not ndata.is_water() and not ndata.is_lava()) or ndata.terrain_type == HexTileData.TerrainType.COAST
				if neighbor_triggers_coast:
					to_convert.append(coord)
					break

		if to_convert.is_empty():
			return

		for coord in to_convert:
			var old_data: HexTileData = tiles[coord]
			var new_data = TerrainDatabase.create_tile(HexTileData.TerrainType.COAST)
			new_data.resource = old_data.resource # Oceano nao tem recurso hoje (ResourceDatabase), mas preserva por seguranca se um dia ganhar
			tiles[coord] = new_data

## Todas as regioes conectadas (BFS por vizinhanca de hexagono real, nao
## so distancia) dentro de `coords` — cada uma como um Array de Vector2i,
## em ordem deterministica (mesma ordem de `coords`). Usado pela garantia
## de regiao minima (`_largest_cluster_of` abaixo, so precisa da maior).
func _connected_components_of(coords: Array) -> Array:
	var coord_set := {}
	for c in coords:
		coord_set[c] = true
	var visited := {}
	var components: Array = []
	for coord in coords:
		if visited.has(coord):
			continue
		var component: Array = []
		var stack: Array = [coord]
		visited[coord] = true
		while stack.size() > 0:
			var c: Vector2i = stack.pop_back()
			component.append(c)
			for n in get_neighbors(c):
				if coord_set.has(n) and not visited.has(n):
					visited[n] = true
					stack.append(n)
		components.append(component)
	return components

## Maior componente conexa dentro de `coords` — devolve array vazio se
## `coords` for vazio.
func _largest_cluster_of(terrain_type: int, coords: Array) -> Array:
	var best: Array = []
	for component in _connected_components_of(coords):
		if component.size() > best.size():
			best = component
	return best

## So usado por _ensure_forced_region: expande a partir de TODOS os tiles
## em `existing_cluster` (ja desse bioma, incluidos em `visited` desde o
## inicio pra nunca serem re-contados/re-criados), pegando vizinhos — e
## vizinhos de vizinhos — que sejam elegiveis e ainda nao reivindicados
## por outro bioma forcado, ate `max_extra` tiles NOVOS ou esgotar
## candidatos. Lava e um caso especial (roadmap item 30: nasce em
## QUALQUER terra firme, nao so a faixa de elevacao "certa") — aceita
## qualquer vizinho que nao seja Oceano/Mar Gelado. Montanha tambem aceita
## vizinho de Colina (contraforte, geografia real) e Colina aceita vizinho
## PLANO (encosta suave) — sem essas duas excecoes, uma semente cujos
## picos de Montanha/Colina nunca formam par adjacente entre si (elevacao
## e um campo continuo, isso acontece) ficava sem NENHUM vizinho elegivel
## pra crescer, deixando o bioma preso a 1 tile mesmo depois de forcado
## (bug pego testando este item: Montanha sumindo do mapa Grande, semente
## 555). Os demais biomas (terreno plano, Oceano/Mar Gelado) continuam
## exigindo a faixa exata de `_BIOME_ELEVATION_TIER`.
func _find_cluster_neighbors(terrain_type: int, existing_cluster: Array, claimed: Dictionary, min_dist: float, max_extra: int) -> Array:
	var is_lava = terrain_type == HexTileData.TerrainType.LAVA
	var required_tier: int = _BIOME_ELEVATION_TIER.get(terrain_type, _ElevationTier.FLAT)
	var extra: Array = []
	var visited := {}
	for c in existing_cluster:
		visited[c] = true
	var frontier: Array = existing_cluster.duplicate()
	while frontier.size() > 0 and extra.size() < max_extra:
		var current: Vector2i = frontier.pop_front()
		for n in get_neighbors(current):
			if extra.size() >= max_extra:
				break
			if visited.has(n) or claimed.has(n):
				continue
			visited[n] = true
			if HexMetrics.axial_distance(n, Vector2i.ZERO) < min_dist:
				continue
			var tier = _elevation_tier(n)
			if is_lava:
				if tier == _ElevationTier.WATER:
					continue
			elif required_tier == _ElevationTier.MOUNTAINS:
				if tier != _ElevationTier.MOUNTAINS and tier != _ElevationTier.HILLS:
					continue
			elif required_tier == _ElevationTier.HILLS:
				if tier != _ElevationTier.HILLS and tier != _ElevationTier.FLAT:
					continue
			elif tier != required_tier:
				continue
			claimed[n] = true
			extra.append(n)
			frontier.append(n)
	return extra

## Medido empiricamente rodando FastNoiseLite.get_noise_2d() com a mesma
## frequencia (0.8) por milhares de amostras: 0.7 (o "chute" original) so
## passa em ~0.03% dos tiles — na pratica, recurso nunca aparecia. 0.3 da
## os ~12% pretendidos (confirmado em varias sementes diferentes).
const RESOURCE_NOISE_THRESHOLD := 0.3

## Recurso estrategico/luxo esparso: so em tiles de terra firme cujo bioma
## e elegivel (ResourceDatabase.ELIGIBILITY), e so onde o ruido de recurso
## passa do limiar (~15% dos tiles elegiveis, dando uma distribuicao rala
## em vez de blocos grandes). Qual recurso exato usa um hash deterministico
## da coordenada em vez de mais uma chamada de ruido — mais barato e ainda
## 100% reproduzivel pela map_seed.
func _maybe_assign_resource(data: HexTileData, coord: Vector2i, world: Vector3) -> void:
	var eligible = ResourceDatabase.eligible_resources(data.terrain_type)
	if eligible.is_empty():
		return
	if _resource_noise.get_noise_2d(world.x, world.z) <= RESOURCE_NOISE_THRESHOLD:
		return
	var index = int(abs(coord.x * 31 + coord.y * 17)) % eligible.size()
	data.resource = eligible[index]

const LAIR_MIN_DISTANCE_FROM_CENTER_FRACTION := 0.25 # nunca perto do (0,0), onde o humano comeca

## Mapa agora e retangular (largura/altura podem ser diferentes), entao
## "distancia minima do centro" usa a MENOR das duas dimensoes (nao a
## media) — evita excluir o mapa inteiro no eixo mais estreito. Mesma
## proporcao de antes: raio_equivalente = metade da menor dimensao,
## min_dist = 25% disso (medido pra continuar dando a mesma folga que o
## mapa em losango tinha).
## Mapa ABAIXO do tamanho Grande usa as PROPRIAS dimensoes ao vivo
## (comportamento historico — mapas de teste pequenos, ex: "radius 3",
## precisam continuar excluindo so uma fatia pequena e proporcional ao
## PROPRIO tamanho, senao a exclusao vira maior que o mapa inteiro e
## nenhum covil consegue nascer). So o tamanho Grande de verdade trava na
## pegada FIXA do continente Principal (TitleScreen.MAIN_ZONE_SIZE) — essa
## exclusao existe pra manter covil longe de onde o humano SEMPRE comeca
## ((0,0), dentro da zona Principal), entao la sim trava no tamanho
## historico em vez de variar com o canvas total (agora maior, pra caber
## os continentes Vulcanico/de Cristal).
func _min_distance_from_center() -> float:
	if _is_large_map_or_bigger():
		return float(min(TitleScreen.MAIN_ZONE_SIZE.width, TitleScreen.MAIN_ZONE_SIZE.height)) / 2.0 * LAIR_MIN_DISTANCE_FROM_CENTER_FRACTION
	return float(min(map_width, map_height)) / 2.0 * LAIR_MIN_DISTANCE_FROM_CENTER_FRACTION

## Verdadeiro so no tamanho Grande (TitleScreen.MAP_SIZES.large) ou maior
## — usado pra ligar as garantias de cobertura de bioma/Mar de Lava so em
## mapas grandes o bastante (mapas menores continuam probabilisticos de
## proposito, "nos outros talvez faça sentido ter menos" nas palavras do
## usuario). Compara AREA total (largura x altura) em vez de um raio
## unico, ja que os tres tamanhos oficiais agora tem proporcoes W:H
## ligeiramente diferentes entre si.
func _is_large_map_or_bigger() -> bool:
	var large: Dictionary = TitleScreen.MAP_SIZES.large
	return map_width * map_height >= large.width * large.height

## Espalha alguns Covis de Monstro (Unit neutra, owner_player == null — ver
## MonsterDatabase) em terra firme longe do centro do mapa, deterministico
## pela map_seed. Poucos e espalhados de proposito: e um risco/recompensa
## opcional pra explorar, nao um obstaculo constante — 4X de fantasia de
## verdade (Age of Wonders, Endless Legend) usa isso pra dar uma razao pra
## sair da capital antes mesmo de encontrar um rival.
func _spawn_monster_lairs() -> void:
	lair_coords.clear()
	lair_kind_by_coord.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 4000 # canal proprio, mesmo padrao dos outros noises (seed+N)

	var min_dist = _min_distance_from_center()
	var all_coords: Array = tiles.keys()
	all_coords.sort() # ordem deterministica antes de sortear, independente de ordem de insercao
	var candidates: Array[Vector2i] = []
	for c in all_coords:
		var data: HexTileData = tiles[c]
		# Lava/Mar de Lava agora TAMBEM sao candidatos validos (antes,
		# blocks_land_units() os excluia sempre — Dragao, bioma so [LAVA],
		# nunca conseguia nascer de verdade por causa disso, so em testes
		# que chamam MonsterDatabase.random_kind direto). Kind pra esses
		# tiles especificamente vem restrito a voadores logo abaixo, entao
		# nunca sobra um monstro terrestre fisicamente preso numa ilha de
		# lava.
		if (not data.blocks_land_units() or data.is_lava()) and HexMetrics.axial_distance(c, Vector2i.ZERO) >= min_dist:
			candidates.append(c)

	# Formula equivalente a antiga `map_radius / 4`: pro losango antigo,
	# largura/altura eram sempre ~2*raio+1, entao raio ~ (largura+altura)/4
	# e a contagem de covis ~ (largura+altura)/16. Confirmado nos numeros
	# oficiais: Grande (96x60) da 9 covis, igual o Grande antigo (raio 37).
	var lair_count = max(1, (map_width + map_height) / 16)
	for i in range(lair_count):
		if candidates.is_empty():
			break
		var idx = rng.randi_range(0, candidates.size() - 1)
		var coord: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		# Ameaca ESPACIAL (turno sempre 0: geracao do mapa acontece antes
		# de qualquer turno jogado) cruzada com o BIOMA do proprio tile —
		# covil perto do centro (onde a capital tende a nascer) nunca
		# sorteia Vivern/Dragao, so longe o suficiente ("regiao profunda do
		# mapa") destrava os tipos mais fortes, E cada tipo so nasce no
		# bioma que faz sentido pra ele (ver MonsterDatabase.KIND_DATA/
		# _threat_level).
		var threat = _threat_level(_nearest_player_origin_distance(coord), 0)
		var kind: String
		if tiles[coord].is_lava():
			# So tipo VOADOR pode nascer em cima de lava (Dragao/Vivern ja
			# tem flies=true em KIND_DATA) — nunca cai no fallback
			# biome-agnostico de random_kind, que poderia devolver um tipo
			# terrestre fisicamente preso ali. Checado ANTES de registrar o
			# covil (lair_coords.append abaixo) — se nenhum voador serve
			# aqui, pula o candidato inteiro em vez de deixar um covil
			# "fantasma" sem kind/guardiao/estrutura.
			kind = MonsterDatabase.random_flying_kind(rng, threat, tiles[coord].terrain_type)
			if kind == "":
				continue # nenhum voador elegivel pra esse terreno especifico — pula este candidato
		else:
			kind = MonsterDatabase.random_kind(rng, threat, tiles[coord].terrain_type)
		# Teto GLOBAL (ver _global_cap_for) tambem vale na geracao inicial —
		# sem isso, um mapa grande o bastante podia colocar 2+ covis do
		# MESMO tipo raro (ex: 2 covis de Dragao, global_cap 1) e cada um
		# nascer com seu proprio chefao, estourando o teto antes mesmo do
		# primeiro turno. Pula o candidato (nao consome esse slot de covil)
		# em vez de forcar outro tipo aqui.
		if _count_alive_of_kind(kind) >= _global_cap_for(kind):
			continue
		lair_coords.append(coord)
		lair_kind_by_coord[coord] = kind
		# Nenhum covil futuro pode nascer perto o bastante pra sua area
		# (_lair_area, a propria celula + vizinhos) se sobrepor a de OUTRO
		# covil — sem isso, dois covis a distancia <= 2 compartilham pelo
		# menos um tile vizinho em comum, e process_monster_lairs podia
		# gerar um reforco do kind ERRADO ali (o tile "pertence" aos dois
		# covis ao mesmo tempo pro proposito de spawn/contagem/patrulha).
		candidates = candidates.filter(func(c): return HexMetrics.axial_distance(c, coord) > 2)
		# `true` (camp boss): o ocupante ORIGINAL do covil e um "chefao"
		# reforcado (HP/ataque multiplicados, nunca se move) — ver
		# MonsterDatabase.create_monster/CAMP_BOSS_*_MULTIPLIER.
		spawn_monster_at(coord, kind, true)
		var structure := LairStructure.new()
		_lairs_root.add_child(structure)
		structure.position = world_for_coord(coord)
		structure.build(kind, self)
		lairs_by_coord[coord] = structure

## Distancia ate a origem de jogador (humano ou rival) mais proxima — usada
## por _spawn_monster_lairs pra decidir o tipo de covil (pedido do usuario:
## "usar a distancia pra Cidade/Capital mais proxima, em vez de (0,0)
## fixo"). Nenhuma City existe ainda nesse momento (generate_map() sempre
## roda ANTES de qualquer capital ser fundada — ver Main.gd/GameManager.
## _spawn_starting_forces/SaveManager.load_game), entao usa as MESMAS
## origens deterministicas que decidem onde cada capital vai nascer minutos
## depois: Vector2i.ZERO pro humano (GameManager._spawn_starting_forces) e
## GameManager._rival_origin(i, count) pra cada rival. Depende de
## GameManager.rival_count/map_width/map_height ja estarem corretos ANTES
## desta chamada — verdade tanto pro jogo novo (Main.gd seta tudo antes de
## generate_map) quanto pro load (SaveManager.load_game seta esses campos
## antes de chamar generate_map, de proposito).
func _nearest_player_origin_distance(coord: Vector2i) -> float:
	var best = HexMetrics.axial_distance(coord, Vector2i.ZERO)
	var count = clamp(GameManager.rival_count, 1, GameManager.RIVAL_CIVS.size())
	for i in range(count):
		var d = HexMetrics.axial_distance(coord, GameManager._rival_origin(i, count))
		best = min(best, d)
	return float(best)

## Distancia (fracao do "raio" do mapa, ver _threat_level) alem da qual o
## eixo ESPACIAL de ameaca ja satura em 1.0 — controla a partir de onde
## "regiao profunda do mapa" comeca pro proposito de que tipo de covil pode
## nascer ali (ver _spawn_monster_lairs). Comeca a subir logo depois de
## LAIR_MIN_DISTANCE_FROM_CENTER_FRACTION (onde covil nenhum pode nascer)
## e satura bem antes da borda, pra dar uma faixa real de gradiente em vez
## de virar tudo-ou-nada.
const THREAT_DISTANCE_FULL_FRACTION := 0.65
## Turno em que o eixo TEMPORAL de ameaca satura em 1.0 — controla quao
## rapido os covis passam a reforcar a propria guarda mais rapido conforme
## a partida avanca (ver _reinforce_chance). Reforco continua SEMPRE do
## MESMO tipo do guardiao original (lair_kind_by_coord nunca muda depois
## de definido) — o eixo temporal nao desbloqueia tipo novo, so faz o
## mundo ja definido ficar mais ativo/perigoso com o tempo.
const THREAT_TURN_RAMP_TURNS := 60.0

## Ameaca [0, 1] combinando DISTANCIA do centro do mapa e TURNO atual —
## MAXIMO dos dois eixos (nao soma/media) de proposito: um lugar bem longe
## de tudo ja e perigoso mesmo no turno 1 (nao devia esperar o jogo
## "envelhecer" pra isso valer), e um evento tardio continua pesando so o
## turno mesmo perto do centro. Cada chamador usa um eixo por vez (distancia
## sempre 0 ao consultar so o turno, turno sempre 0 ao consultar so a
## distancia) — ver _spawn_monster_lairs/_reinforce_chance.
func _threat_level(distance_from_center: float, turn: int) -> float:
	var half_min_dim = float(min(map_width, map_height)) / 2.0
	var full_distance = max(half_min_dim * THREAT_DISTANCE_FULL_FRACTION, 1.0)
	var distance_axis = clamp(distance_from_center / full_distance, 0.0, 1.0)
	var turn_axis = clamp(float(turn) / THREAT_TURN_RAMP_TURNS, 0.0, 1.0)
	return max(distance_axis, turn_axis)

## Populacao maxima viva (guardiao original incluso) que um covil mantem
## ao redor de si — pedido do usuario: "ao redor de um covil de goblin
## pode spawnar ate sei la 5 goblins... tem que ter um limite pra nao
## spawnar pra sempre". Um covil raio 1 (a propria celula + 6 vizinhos)
## sempre tem espaco de sobra pra esse limite. Fallback defensivo pra kind
## desconhecido — o limite de VERDADE e por TIPO
## (MonsterDatabase.KIND_DATA[kind].lair_cap: Goblin 4, Troll/Vivern 2,
## Esqueleto 4, Dragao 1), ver _lair_cap_for.
const LAIR_SPAWN_CAP := 5

func _lair_cap_for(kind: String) -> int:
	return MonsterDatabase.KIND_DATA.get(kind, {}).get("lair_cap", LAIR_SPAWN_CAP)

## Teto GLOBAL (mapa inteiro, todos os covis somados) por tipo — pedido do
## usuario: "ponha um limite no spawn de monstros... cada um so pode ter 5
## vivos por vez, no caso dos vivern 2 vivos de uma vez e no dragao apenas
## 1". Fallback 5 (GLOBAL_MONSTER_CAP) pra kind desconhecido, mesmo padrao
## de _lair_cap_for/LAIR_SPAWN_CAP.
const GLOBAL_MONSTER_CAP := 5

func _global_cap_for(kind: String) -> int:
	return MonsterDatabase.KIND_DATA.get(kind, {}).get("global_cap", GLOBAL_MONSTER_CAP)

## Chance BASE por turno de UM covil elegivel gerar mais um monstro —
## trickle gradual (o covil "se enchendo aos poucos" quando alguem nao
## limpa a regiao) em vez de todos os covis baterem o teto no mesmo turno.
## Ver LAIR_SPAWN_CHANCE_TURN_BONUS pro incremento conforme o turno avanca.
const LAIR_SPAWN_CHANCE := 0.25
## Quanto a chance de reforco sobe (em cima da base acima) conforme o eixo
## TEMPORAL de ameaca satura — "o mundo fica mais perigoso com o tempo"
## sem precisar inventar covil novo do zero, so fazendo os que ja existem
## reforcarem mais depressa depois de THREAT_TURN_RAMP_TURNS turnos.
const LAIR_SPAWN_CHANCE_TURN_BONUS := 0.15
## Chance por turno de um covil CHEIO (no teto de populacao) mandar um dos
## proprios moradores "patrulhar" pra outro tile livre dentro do proprio
## territorio, em vez de todo mundo ficar parado pra sempre uma vez batido
## o LAIR_SPAWN_CAP — ver _maybe_roam_lair.
const ROAM_CHANCE := 0.2

## Canal de RNG DEDICADO pra tudo que acontece turno a turno num covil
## (reforco e patrulha) — nao usa randi()/randf() globais de proposito:
## aqueles nao tem semente controlavel, entao dois turnos identicos (ex:
## salvar e recarregar no mesmo turno, depois repetir a mesma sequencia de
## acoes) podiam gerar eventos DIFERENTES cada vez, quebrando replay/
## determinismo. Semeado em generate_map() a partir de map_seed (mesmo
## padrao dos outros canais, +7000) e seu `.state` e persistido pelo
## SaveManager — apos um load, a sequencia de sorteios futura continua
## EXATAMENTE de onde parou, nao reinicia do zero.
var monster_turn_rng := RandomNumberGenerator.new()

## Chamado por GameManager a cada troca de turno (ver GameManager.
## _on_turn_changed), com o numero do turno ATUAL (TurnManager.turn_number
## — default 0 so pra chamadas de teste/isoladas que nao se importam com
## progressao). Cada covil ainda de pe (kind conhecido em
## lair_kind_by_coord) tenta reforcar a propria guarda com o MESMO tipo do
## guardiao original, respeitando o limite POR TIPO (ver _lair_cap_for) —
## sem isso, limpar so o guardiao original esvaziava o covil pra sempre, e
## nenhum ficava forte o bastante pra ser uma ameaca real com o tempo.
## Quando o covil esta cheio (LOCAL, ver _lair_cap_for, OU GLOBAL, ver
## _global_cap_for — pedido do usuario: "ponha um limite no spawn de
## monstros") OU nao ha tile livre pro reforco sorteado, os moradores
## existentes tem uma chance de patrulhar em vez de ficar parados (ver
## _maybe_roam_lair).
func process_monster_lairs(turn: int = 0) -> void:
	for lair_coord in lair_coords:
		var kind = lair_kind_by_coord.get(lair_coord, "")
		if kind == "":
			continue
		if _count_live_monsters_near_lair(lair_coord) >= _lair_cap_for(kind) or _count_alive_of_kind(kind) >= _global_cap_for(kind):
			_maybe_roam_lair(lair_coord)
			continue
		if monster_turn_rng.randf() > _reinforce_chance(turn):
			continue
		if not _reinforce_lair(lair_coord, kind):
			_maybe_roam_lair(lair_coord)

## No hit do roll de reforco (ver process_monster_lairs): spawna ate
## MonsterDatabase.KIND_DATA[kind].batch_spawn monstros de uma vez,
## limitado pelo espaco que ainda sobra ate o limite por tipo (LOCAL, area
## do covil, E GLOBAL, mapa inteiro — ver _global_cap_for) — e assim
## que Esqueleto "nasce em grupo" (batch_spawn=3) sem nenhum contador novo,
## so multiplas chamadas de _find_free_tile_for_lair_spawn no MESMO evento
## de roll (o resto dos tipos tem batch_spawn=1, comportamento identico ao
## de antes). O teto GLOBAL entra aqui tambem (nao so em process_monster_
## lairs) pra um batch nao poder estourar o teto NUM SO evento de reforco
## (ex: Esqueleto com so 1 vaga global restante nasce so 1, nao os 3 do
## batch inteiro). Devolve false se nao conseguiu spawnar ninguem (area
## cheia/sem tile livre) — sinal pro chamador tentar patrulha em vez disso.
func _reinforce_lair(lair_coord: Vector2i, kind: String) -> bool:
	var batch_spawn: int = MonsterDatabase.KIND_DATA.get(kind, {}).get("batch_spawn", 1)
	var room_left = _lair_cap_for(kind) - _count_live_monsters_near_lair(lair_coord)
	room_left = min(room_left, _global_cap_for(kind) - _count_alive_of_kind(kind))
	var flies: bool = MonsterDatabase.KIND_DATA.get(kind, {}).get("flies", false)
	var spawned_any := false
	for i in range(min(batch_spawn, room_left)):
		var target = _find_free_tile_for_lair_spawn(lair_coord, flies)
		if target == null:
			break
		spawn_monster_at(target, kind)
		spawned_any = true
	return spawned_any

## So o eixo TEMPORAL de _threat_level importa aqui (distancia sempre 0) —
## ver THREAT_TURN_RAMP_TURNS/LAIR_SPAWN_CHANCE_TURN_BONUS.
func _reinforce_chance(turn: int) -> float:
	return LAIR_SPAWN_CHANCE + _threat_level(0.0, turn) * LAIR_SPAWN_CHANCE_TURN_BONUS

## A propria celula do covil + seus 6 vizinhos — area "ao redor" do covil
## pra fins de contagem/spawn/patrulha (LAIR_SPAWN_CAP so faz sentido junto
## com a mesma area usada pra escolher onde nascer, ver _find_free_tile_for_
## lair_spawn/_maybe_roam_lair).
func _lair_area(lair_coord: Vector2i) -> Array[Vector2i]:
	var area: Array[Vector2i] = [lair_coord]
	area.append_array(get_neighbors(lair_coord))
	return area

## Devolve o lair_coord cuja _lair_area() contem `coord` (o proprio covil
## OU um dos 6 vizinhos dele), ou Vector2i(-999999, -999999) se `coord` nao
## pertence a territorio de covil nenhum — usado por MonsterAI pro
## comportamento Guardiao saber o proprio territorio (seguro: covis ficam
## a distancia > 2 um do outro, ver _spawn_monster_lairs, entao
## _lair_area()s nunca se sobrepoem e a busca abaixo nunca da resultado
## ambiguo). Sentinela em vez de null pra manter o tipo de retorno
## Vector2i simples (GDScript nao tem Optional/Variant tipado aqui sem
## custo extra de chamador); NO_LAIR e o valor de comparacao.
const NO_LAIR := Vector2i(-999999, -999999)

func home_lair_for(coord: Vector2i) -> Vector2i:
	for lair_coord in lair_coords:
		if coord in _lair_area(lair_coord):
			return lair_coord
	return NO_LAIR

func _count_live_monsters_near_lair(lair_coord: Vector2i) -> int:
	var count := 0
	for coord in _lair_area(lair_coord):
		var unit: Unit = get_unit_at(coord)
		if unit != null and unit.owner_player == null:
			count += 1
	return count

## Quantos monstros de `kind` estao vivos em QUALQUER LUGAR do mapa agora
## (nao so perto de UM covil, diferente de _count_live_monsters_near_lair
## acima) — usado pelo teto GLOBAL por tipo, ver _global_cap_for.
## visual_kind bate 1:1 com o proprio kind pra todo monstro
## (MonsterDatabase.KIND_DATA[k].visual_kind == k, ver create_monster),
## entao filtrar por visual_kind aqui e equivalente a filtrar pelo kind
## original do covil que o gerou.
func _count_alive_of_kind(kind: String) -> int:
	var count := 0
	for unit in units_by_coord.values():
		if unit.owner_player == null and unit.unit_data.visual_kind == kind:
			count += 1
	return count

## Tile livre (sem unidade, sem bloquear terrestre — a MENOS que `flies`
## seja verdadeiro, ver abaixo) na area do covil, escolhido aleatoriamente
## entre os candidatos — null se a area inteira ja esta ocupada (covil no
## limite ou cercado). Inclui a propria celula do covil: normalmente
## ocupada pelo guardiao original, mas se ele ja foi derrotado o tile fica
## livre pra um novo monstro reocupar o covil.
## `flies` (do kind do proprio covil, ver _reinforce_lair) libera tile de
## Lava/Mar de Lava como candidato tambem — sem isso, um covil de Vivern/
## Dragao nascido em cima de lava (ver _spawn_monster_lairs) nunca
## conseguiria reforcar, ja que TODA a area ao redor dele e lava.
func _find_free_tile_for_lair_spawn(lair_coord: Vector2i, flies: bool = false):
	var candidates: Array[Vector2i] = []
	for coord in _lair_area(lair_coord):
		if get_unit_at(coord) != null:
			continue
		var data = get_tile(coord)
		if data == null or (data.blocks_land_units() and not (flies and data.is_lava())):
			continue
		candidates.append(coord)
	if candidates.is_empty():
		return null
	return candidates[monster_turn_rng.randi() % candidates.size()]

## "Patrulha" simples de um covil CHEIO: sorteia um morador vivo da area do
## covil e o reposiciona num OUTRO tile livre da MESMA area — nunca sai do
## territorio do proprio covil de proposito (mesma area que _lair_area/
## LAIR_SPAWN_CAP ja usam), o que garante por construcao que a patrulha
## nunca invade a area de um covil vizinho (lairs ficam a distancia > 2 um
## do outro, ver _spawn_monster_lairs) e nunca pisa numa cidade (excluida
## abaixo). Reposicionamento DIRETO (nao usa compute_reachable/move_unit,
## o sistema de movimento com pontos de jogador) — monstro continua com
## unit_data.movement_points == 0 por design (MonsterDatabase.
## create_monster), a patrulha e o proprio sistema de covil administrando a
## posicao, nao um gasto de movimento da unidade.
func _maybe_roam_lair(lair_coord: Vector2i) -> void:
	if monster_turn_rng.randf() > ROAM_CHANCE:
		return
	# Mesmo motivo de _find_free_tile_for_lair_spawn: covil de Vivern/
	# Dragao em lava precisa poder patrulhar dentro da propria (toda-lava)
	# area tambem, senao _maybe_roam_lair nunca acha free_coords nenhum e
	# fica sempre um no-op silencioso pra esses covis.
	var flies: bool = MonsterDatabase.KIND_DATA.get(lair_kind_by_coord.get(lair_coord, ""), {}).get("flies", false)
	var area = _lair_area(lair_coord)
	var occupants: Array[Unit] = []
	var free_coords: Array[Vector2i] = []
	for coord in area:
		var unit = get_unit_at(coord)
		if unit != null and unit.owner_player == null:
			occupants.append(unit)
			continue
		if unit != null or get_city_at(coord) != null:
			continue
		var data = get_tile(coord)
		if data != null and (not data.blocks_land_units() or (flies and data.is_lava())):
			free_coords.append(coord)
	if occupants.is_empty() or free_coords.is_empty():
		return
	var wanderer: Unit = occupants[monster_turn_rng.randi() % occupants.size()]
	var dest: Vector2i = free_coords[monster_turn_rng.randi() % free_coords.size()]
	units_by_coord.erase(wanderer.coord)
	wanderer.coord = dest
	# Mesmo motivo de move_unit acima: sem nevoa cobrindo o covil, o
	# guardiao nem aparece na tela — nao vale animar.
	if wanderer.visible:
		wanderer.slide_to(world_for_coord(dest))
	else:
		wanderer.position = world_for_coord(dest)
	units_by_coord[dest] = wanderer

## Unica funcao que cria um monstro neutro de verdade (guardiao original OU
## reforco/restauracao de save — todos passam por aqui) — sempre uma
## `Unit` (mesma classe usada pra unidade de jogador/rival). O marcador
## visual do covil em si e um node SEPARADO (LairStructure, ver
## lairs_by_coord/_spawn_monster_lairs/destroy_lair) — o guardiao original
## (`is_camp_boss = true`) so ganha stats reforcados (ver MonsterDatabase.
## CAMP_BOSS_*_MULTIPLIER), sem adorno visual proprio. Publica (sem `_`)
## porque SaveManager tambem chama, pra restaurar cada monstro neutro salvo
## (ver SaveManager._deserialize_neutral_units).
func spawn_monster_at(coord: Vector2i, kind: String, is_camp_boss: bool = false) -> Unit:
	var unit := Unit.new()
	_units_root.add_child(unit)
	unit.setup(MonsterDatabase.create_monster(kind, is_camp_boss), null, coord, is_camp_boss)
	unit.position = world_for_coord(coord)
	units_by_coord[coord] = unit
	return unit

## Todo monstro neutro (owner_player == null) vivo no mapa agora — guardiao
## original OU reforco/patrulhado, sem distincao (a unica coisa "especial"
## num covil e a COORDENADA original em lair_coords/lair_kind_by_coord,
## nunca a Unit em si). Fonte de verdade unica pra save/load (ver
## SaveManager) em vez de manter uma segunda lista paralela pra manter
## sincronizada com remove_unit()/combate.
func neutral_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units_by_coord.values():
		if unit.owner_player == null:
			result.append(unit)
	return result

## Remove TODO monstro neutro do mapa — usado por SaveManager antes de
## restaurar a lista exata de monstros de um save (generate_map() ja
## respawnou os guardioes originais deterministicamente; isso desfaz esse
## respawn automatico pra dar lugar ao estado salvo de verdade).
func clear_neutral_units() -> void:
	for unit in neutral_units():
		remove_unit(unit)

## 0 = polo (frio), 1 = equador (quente) — gradiente linear pela distancia
## de `r` ao "equador" (r=0), com uma pitada de ruido pra a fronteira entre
## faixas climaticas nao ficar reta demais. Latitude normalizada pela
## pegada FIXA do continente Principal (TitleScreen.MAIN_ZONE_SIZE, nao
## map_height ao vivo) — senao o gradiente climatico do continente
## Principal se comprimiria conforme o canvas total cresce pra caber os
## continentes Vulcanico/Cristal, redistribuindo deserto/neve/selva sem
## nenhuma mudanca pedida. Continentes especiais nao usam temperatura pra
## decidir bioma (sempre Lava/Cristal, ver _generate_tile_data), entao so
## importa aqui pro oceano de separacao decidir Oceano vs Mar Gelado.
func _temperature_for(coord: Vector2i) -> float:
	# Mesma logica de _edge_falloff: mapa ABAIXO do tamanho Grande usa a
	# propria altura ao vivo (comportamento historico, senao um mapa de
	# teste pequeno normaliza a latitude errado e todo o clima muda);
	# so o tamanho Grande de verdade trava na pegada FIXA da zona Principal.
	var half_height = float(TitleScreen.MAIN_ZONE_SIZE.height) / 2.0 if _is_large_map_or_bigger() else float(map_height) / 2.0
	var latitude = float(abs(coord.y)) / max(half_height, 1.0)
	var jitter = _temp_jitter_noise.get_noise_2d(float(coord.x), float(coord.y)) * 0.15
	return clamp(1.0 - latitude + jitter, 0.0, 1.0)

const ICE_TEMPERATURE_THRESHOLD := 0.08 # mais frio que isso, nem Neve aguenta

## Roadmap item 33, **reportado pelo usuario**: "o de deserto tambem esta
## extremamente pequeno". Causa raiz: `_moisture_noise` (FBM multi-octava)
## NAO se espalha uniformemente por [-1, 1] depois do `(n+1)*0.5` — os
## limiares antigos (0.3/0.6 pro lado quente, 0.3/0.65 pro lado temperado)
## foram escolhidos assumindo uma distribuicao uniforme, mas o valor real
## quase nunca sai de ~[0.3, 0.7], com a MAIORIA concentrada perto de 0.5.
## Resultado medido (censo de bioma num mapa Grande real): Deserto/Estepe
## ficavam com ~3-11% da propria faixa de temperatura enquanto Savana/
## Planicie (a categoria "moderada" do meio) engolia 65-80% — a mesma
## imprecisao existiria pra Selva/Floresta do lado umido. Medindo os
## PERCENTIS reais do `_moisture_noise` (5 sementes, so terra firme): a
## faixa 33/67 fica em -0.126/0.109 de ruido cru, que vira 0.437/0.555
## depois do `(n+1)*0.5` — bem mais estreita que 0.3/0.6. Os limiares
## abaixo usam esses percentis (arredondados) pra dar uma faixa seca/
## moderada/umida de tamanho comparavel em VEZ de uma "moderada" gigante
## engolindo as outras duas. Tundra/Taiga (0.5) nunca teve esse problema —
## 0.5 ja calha perto da mediana real do ruido, entao ficou de fora dessa
## correcao.
const MOISTURE_DRY_THRESHOLD := 0.44
const MOISTURE_WET_THRESHOLD := 0.56

## Onde cada faixa de temperatura comeca (ICE_TEMPERATURE_THRESHOLD, acima,
## e o limite mais frio de todos). Faixas de elevacao (oceano/colina/
## montanha) ja foram resolvidas antes de chegar em _pick_biome — isto so
## decide o bioma "plano".
const SNOW_TEMPERATURE_THRESHOLD := 0.2
const COLD_TEMPERATURE_THRESHOLD := 0.4 # abaixo disso: Tundra/Taiga. Entre isso e HOT: Estepe/Planicie/Floresta.
const HOT_TEMPERATURE_THRESHOLD := 0.7 # a partir disso: Deserto/Savana/Selva
## Tundra/Taiga usa um corte proprio de umidade (0.5) em vez dos limiares
## DRY/WET calibrados pro resto da tabela — 0.5 ja calha perto da mediana
## real do `_moisture_noise`, entao nunca precisou da mesma correcao.
const TUNDRA_TAIGA_MOISTURE_THRESHOLD := 0.5

enum _TempBand { ICE, SNOW, COLD, TEMPERATE, HOT }
enum _MoistureBand { DRY, MODERATE, WET }

## TABELA DE DECISAO DE BIOMA: temperatura (por faixa de latitude, ver
## _temperature_for) cruzada com umidade (ruido + bonus litoraneo, ver
## _moisture_for) — o mesmo diagrama de Whittaker simplificado que jogos 4X
## usam (Frio+Seco=Tundra/Estepe, Frio+Umido=Taiga/Neve, Quente+Seco=
## Deserto/Savana, Temperado+Umido=Floresta/Planicie). Gelo Eterno e o
## extremo mais frio, mais severo que Neve — sem isso o polo inteiro seria
## so uma unica faixa de Neve, sem gradacao.
##
## Pra ajustar QUAL bioma cada combinacao produz: mude os valores aqui
## direto, e so isso. Pra ajustar ONDE cada faixa comeca/termina: mude as
## constantes *_THRESHOLD acima (temperatura) ou MOISTURE_DRY_THRESHOLD/
## MOISTURE_WET_THRESHOLD (umidade) — nenhuma delas exige tocar em
## `_pick_biome`/`_temperature_band`/`_moisture_band`.
const _BIOME_TABLE := {
	_TempBand.ICE: HexTileData.TerrainType.ICE,
	_TempBand.SNOW: HexTileData.TerrainType.SNOW,
	_TempBand.COLD: {
		_MoistureBand.DRY: HexTileData.TerrainType.TUNDRA,
		_MoistureBand.MODERATE: HexTileData.TerrainType.TUNDRA,
		_MoistureBand.WET: HexTileData.TerrainType.TAIGA,
	},
	_TempBand.TEMPERATE: {
		_MoistureBand.DRY: HexTileData.TerrainType.PLAINS,
		_MoistureBand.MODERATE: HexTileData.TerrainType.GRASSLAND,
		_MoistureBand.WET: HexTileData.TerrainType.FOREST,
	},
	_TempBand.HOT: {
		_MoistureBand.DRY: HexTileData.TerrainType.DESERT,
		_MoistureBand.MODERATE: HexTileData.TerrainType.SAVANNA,
		_MoistureBand.WET: HexTileData.TerrainType.JUNGLE,
	},
}

func _temperature_band(temperature: float) -> int:
	if temperature < ICE_TEMPERATURE_THRESHOLD:
		return _TempBand.ICE
	elif temperature < SNOW_TEMPERATURE_THRESHOLD:
		return _TempBand.SNOW
	elif temperature < COLD_TEMPERATURE_THRESHOLD:
		return _TempBand.COLD
	elif temperature < HOT_TEMPERATURE_THRESHOLD:
		return _TempBand.TEMPERATE
	return _TempBand.HOT

func _moisture_band(temp_band: int, moisture: float) -> int:
	if temp_band == _TempBand.COLD:
		return _MoistureBand.DRY if moisture < TUNDRA_TAIGA_MOISTURE_THRESHOLD else _MoistureBand.WET
	if moisture < MOISTURE_DRY_THRESHOLD:
		return _MoistureBand.DRY
	elif moisture < MOISTURE_WET_THRESHOLD:
		return _MoistureBand.MODERATE
	return _MoistureBand.WET

func _pick_biome(temperature: float, moisture: float) -> int:
	var temp_band = _temperature_band(temperature)
	var entry = _BIOME_TABLE[temp_band]
	if entry is Dictionary:
		return entry[_moisture_band(temp_band, moisture)]
	return entry

## Valores tem que bater EXATAMENTE com o `mat_kind` interpretado em
## `shaders/terrain.gdshader` (0 = terreno comum/textura de chao generica,
## 1 = Neve/Gelo Eterno, 2 = Deserto, 3 = rocha vulcanica solida generica,
## 4 = Campos de Cristal, 5 = Mar de Lava, 6 = Lava solida) — cada um troca
## a textura de chao generica por um tratamento visual proprio (neve com
## brilho, duna de deserto, cristal facetado, lava brilhando), em vez de so
## mudar de cor sob a mesma "grama/terra" de sempre. Mar de Lava (roadmap
## item 32) e diferente dos outros: e um tile de AGUA (`v_is_water`, ver
## _rebuild_multimesh), entao o shader ja pula a textura de chao antes
## mesmo de olhar pro mat_kind — o numero 5 so diz pro branch de agua
## aplicar EMISSION vermelha em vez do visual padrao de agua (azul, sem
## brilho). Pura, testavel sem precisar de contexto de shader/desenho.
func _material_kind_for(terrain_type: int) -> float:
	match terrain_type:
		HexTileData.TerrainType.SNOW, HexTileData.TerrainType.ICE:
			return 1.0
		HexTileData.TerrainType.DESERT:
			return 2.0
		HexTileData.TerrainType.VOLCANIC_ASH:
			# Regressao reportada pelo usuario ("leitura visual 3D ficou
			# pessima... mesmo material de basalto preto para tudo"): Solo
			# de Cinzas reusa a formula de Deserto (textura granulada de
			# dunas, SEM o escurecimento ×0.6 que mat_kind 3/rocha aplica —
			# ver terrain.gdshader) com um tint CLARO (ver TerrainDatabase)
			# — da uma textura e brilho genuinamente diferentes da rocha
			# solida, nao so uma variacao de cor sobre a MESMA textura.
			return 2.0
		HexTileData.TerrainType.VOLCANIC_PEAKS, HexTileData.TerrainType.VOLCANIC_HILLS, HexTileData.TerrainType.VOLCANIC_ROCK:
			# Rocha vulcanica solida "morta" (Terra Vulcanica/Colinas/
			# Montanhas Vulcanicas — SEM Lava, ver mat_kind 6 abaixo) reusa
			# a MESMA textura de rocha negra real — so' `color` muda por
			# tipo (ver TerrainDatabase, cores recalibradas pra sobrar
			# contraste depois do escurecimento ×0.6 que este mat_kind
			# aplica). elevation_kind separado (ver mais abaixo) e quem da a
			# cupula/relevo de Colinas/Montanhas Vulcanicas; o shader ja
			# exclui neve pra mat_kind 3 especificamente (ver
			# terrain.gdshader).
			return 3.0
		HexTileData.TerrainType.CRYSTAL, HexTileData.TerrainType.CRYSTAL_PEAKS, HexTileData.TerrainType.MYSTIC_SPRING:
			# Picos de Cristal e Fonte Mistica reusam o brilho/textura
			# animada de Cristal (facetas + emissao) — combina com "pico
			# cristalino" e "fluido arcano" sem shader novo nenhum.
			return 4.0
		HexTileData.TerrainType.LAVA_SEA:
			return 5.0
		HexTileData.TerrainType.LAVA:
			# SEPARADO da rocha vulcanica solida (mat_kind 3) — pedido do
			# usuario: "faça o terreno lava... parecer mais magma,
			# atualmente é só uma pedra preta". Lava solida (a "saia" que
			# fica exposta ao redor do Mar de Lava, movement_cost 99, ver
			# TerrainDatabase) precisa de veios brilhando por baixo da
			# crosta, tratamento visual PROPRIO que a rocha vulcanica comum
			# (Terra/Colinas/Montanhas, mat_kind 3) nao tem — ver
			# terrain.gdshader.
			return 6.0
		_:
			return 0.0

## Distancia em tiles (BFS no grafo de vizinhos, land_coords como fontes
## multiplas) de CADA tile ate a terra solida mais proxima — "falsa
## profundidade" pro water_shader.gdshader (pedido do usuario: o gradiente
## de profundidade REAL via DEPTH_TEXTURE salta quase direto pro azul
## escuro logo apos a borda do hexagono, porque nao ha malha de fundo do
## mar submersa alem da "saia" vertical do prisma de terreno — ver
## LAND_PRISM_DEPTH_FACTOR — entao o degrade real so existe numa faixa
## finissima). Land tile = distancia 0 (fonte da BFS); primeiro anel de
## agua colado na costa = distancia 1; e por ai vai. _rebuild_water_overlay
## consome isso (subtraindo 1, ja que so tiles de AGUA importam pro shader)
## e baka num canal da textura pro shader ler por pixel, ver
## COAST_DISTANCE_NORM_MAX em water_shader.gdshader.
func _compute_coast_distance_tiles(land_coords: Array[Vector2i]) -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for coord in land_coords:
		dist[coord] = 0
		queue.append(coord)
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var d: int = dist[current]
		for n in get_neighbors(current):
			if tiles.has(n) and not dist.has(n):
				dist[n] = d + 1
				queue.append(n)
	return dist

## Terreno solido (todo bioma que nao seja Oceano/Mar Gelado/Mar de Lava)
## continua 1 prisma por tile num MultiMeshInstance3D (terrain.gdshader).
## TODO liquido (agua E lava) divide UM UNICO PlaneMesh continuo — ver
## _build_liquid_plane/_rebuild_water_overlay pro porque (2 planos
## sobrepostos cortavam o mapa ao meio; prisma-por-tile antes disso dava
## fresta entre vizinhos).
func _rebuild_multimesh() -> void:
	if _multimesh_instance:
		_multimesh_instance.queue_free()
	if _liquid_plane_instance:
		_liquid_plane_instance.queue_free()
	if _ground_body:
		_ground_body.queue_free()

	var land_coords: Array[Vector2i] = []
	for coord in tiles.keys():
		var data: HexTileData = tiles[coord]
		if data.terrain_type != HexTileData.TerrainType.LAVA_SEA and not data.is_water():
			land_coords.append(coord)

	_coord_to_index.clear()
	_multimesh_instance = _build_terrain_multimesh(land_coords, _coord_to_index)
	add_child(_multimesh_instance)

	_coast_distance_tiles = _compute_coast_distance_tiles(land_coords)

	_liquid_plane_instance = _build_liquid_plane()
	add_child(_liquid_plane_instance)
	_rebuild_lava_tile_mask()

	_rebuild_props()
	_rebuild_water_overlay() # fog inicial (tudo UNSEEN, ver visibility) no plano recem-criado
	_rebuild_biome_overlay() # idem, mascara inicial pro terreno solido

	var half_extents = get_world_half_extents()
	var plane_shape := BoxShape3D.new()
	plane_shape.size = Vector3(half_extents.x * 2.0, 0.2, half_extents.y * 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = plane_shape
	_ground_body = StaticBody3D.new()
	_ground_body.add_child(collision)
	_ground_body.position = Vector3(0, -0.15, 0)
	add_child(_ground_body)

## Altura UNICA pro liquido (agua E lava) — "logo abaixo da superficie da
## terra firme" (Deserto, o bioma solido mais baixo, fica em 0.0; sempre
## 0.2 acima disso). Diferente de antes (Oceano a -0.3, Mar de Lava a
## 0.05, cada um seu proprio plano): agora e UMA malha so, entao so pode
## ter UMA altura — o shader (nao a geometria) e quem decide se aquele
## pixel parece agua ou lava, ver _rebuild_water_overlay/water_shader.gdshader.
const LIQUID_LEVEL_Y := -0.2

## PlaneMesh UNICO e continuo cobrindo o mapa inteiro (+ margem, pra nunca
## mostrar "fim do oceano" nas bordas) na altura fixa LIQUID_LEVEL_Y —
## terra "emerge" por cima como prismas independentes. cull_back (ja no
## render_mode do shader) descarta so a face de baixo do plano, que a
## camera (sempre acima) nunca veria mesmo.
func _build_liquid_plane() -> MeshInstance3D:
	var half_extents = get_world_half_extents()
	const MARGIN := 2.0
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2((half_extents.x + MARGIN) * 2.0, (half_extents.y + MARGIN) * 2.0)
	plane_mesh.subdivide_width = 32
	plane_mesh.subdivide_depth = 32

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.position = Vector3(0, LIQUID_LEVEL_Y, 0)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water_shader.gdshader")
	material.set_shader_parameter("overlay_half_extents", half_extents)
	mesh_instance.material_override = material
	return mesh_instance

## Resolucao modesta e filtro linear DE PROPOSITO: o objetivo e uma
## transicao suave tipo neblina na agua (e uma borda levemente
## antialiased entre agua/lava, de graca pelo MESMO filtro linear — ver
## liquid_type abaixo), nao um contorno hexagonal pixel-perfeito. Subida de
## 160 pra 224 (pedido do usuario: eliminar "linhas de contorno em
## camadas" na borda Oceano/Mar Gelado) — num mapa Grande (96 tiles de
## largura), 160 texels davam so ~1.7 texel por tile, tao grosseiro que o
## filtro linear malha o contorno hexagonal de verdade num degrade
## quadriculado/staircase em vez de suave. 224 ainda e "modesta" (a maior
## parte do trabalho de suavizar a borda agora vem do dithering por ruido
## no fragment shader, ver frozen_noise em water_shader.gdshader), so o
## bastante a mais de texel-por-tile pra nao brigar visualmente com esse
## ruido. _rebuild_water_overlay roda em eventos discretos (nunca por
## frame), entao o custo extra (~2x iteracoes) fica imperceptivel.
const WATER_OVERLAY_RESOLUTION := 224

## Teto (em tiles) pra normalizar _coast_distance_tiles num canal de 8 bits
## da textura (0..1) — TEM que bater com a const de mesmo nome em
## water_shader.gdshader (comentado la tambem), senao o shader desnormaliza
## errado. 6 tiles e bem mais que coast_mid_extent_tiles (a distancia onde o
## shader ja considera "oceano aberto"), entao nunca clipa a faixa que
## realmente importa pro gradiente visual.
const COAST_DISTANCE_NORM_MAX := 6.0

## Mascara de Mar de Lava EXATA por tile (pedido do usuario, apos duas
## rodadas de ajuste fino na resolucao/filtro de liquid_type_texture ainda
## nao bastarem: "quero que as celulas de lava ocupem a celula inteira") —
## 1 texel POR TILE (map_width x map_height), nao por posicao-mundo continua
## como WATER_OVERLAY_RESOLUTION. O shader converte world_pos.xz pro coord
## axial EXATO (mesmo arredondamento cubo que HexMetrics.world_to_axial faz
## aqui, portado pra GLSL como world_to_axial_round em water_shader.gdshader)
## e busca ESSE tile especifico nesta textura com filter_nearest — garantido
## bater com a fronteira hexagonal de verdade, sem zona fracionaria nenhuma
## (diferente de amostrar uma grade continua, que nunca alinha perfeitamente
## com o contorno hexagonal nao importa a resolucao). col/row usa o MESMO
## esquema de coordenada offset "odd-r" que generate_map usa pra popular
## `tiles` (invertido: dado q/r, `col = q + (row - (row&1))/2` desfaz
## `q = col - (row - (row&1))/2`), garantindo indices sempre dentro de
## [0, map_width) x [0, map_height) sem precisar de nenhuma margem de
## seguranca extra. Calculada UMA VEZ por geracao de mapa (mesma razao de
## _coast_distance_tiles: bioma nunca muda de tile depois de gerado).
func _rebuild_lava_tile_mask() -> void:
	if _liquid_plane_instance == null:
		return
	var half_w = map_width / 2
	var half_h = map_height / 2
	var img := Image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	for coord in tiles.keys():
		var data: HexTileData = tiles[coord]
		if data.terrain_type != HexTileData.TerrainType.LAVA_SEA:
			continue
		var row = coord.y
		var col = coord.x + (row - (row & 1)) / 2
		var px = col + half_w
		var py = row + half_h
		if px >= 0 and px < map_width and py >= 0 and py < map_height:
			img.set_pixel(px, py, Color(1.0, 0.0, 0.0, 1.0))
	_lava_tile_mask_texture = ImageTexture.create_from_image(img)
	var material: ShaderMaterial = _liquid_plane_instance.material_override
	material.set_shader_parameter("lava_tile_mask", _lava_tile_mask_texture)
	material.set_shader_parameter("lava_grid_size", Vector2(map_width, map_height))
	material.set_shader_parameter("lava_grid_half", Vector2(half_w, half_h))
	material.set_shader_parameter("lava_hex_size", hex_size)

## O plano de liquido e 1 malha continua so, sem instancia por tile pra
## tingir/classificar individualmente — fog-of-war, destaque de movimento
## E "isso aqui e agua ou lava" (antes dois PlaneMesh/shaders separados,
## agora um shader unificado que decide por pixel) viram DUAS texturas
## compartilhadas, reconstruidas aqui e amostradas por posicao-mundo:
## - _water_overlay_texture: RGB = multiplicador de destaque (so o tingido
##   de movimento/ataque/construcao por cima — a nevoa de guerra em si NAO
##   dimeriza mais aqui, ver abaixo, mesma mudanca de _apply_terrain_fog);
##   A = "esta congelado?" (Mar Gelado vs Oceano comum), sempre 1.0 fora de
##   Mar Gelado.
## - _liquid_type_texture: R = 0.0 (agua) ou 1.0 (Mar de Lava) — o shader
##   usa isso pra escolher qual "modo" desenhar em cada pixel do plano; A =
##   fog_level continuo (_fog_level_for, MESMA semantica 0/0.5/1 do canal
##   alfa de biome_overlay_texture em terrain.gdshader) — canal que antes
##   ficava sempre 1.0 sem uso, reaproveitado pra water_shader.gdshader
##   aplicar a MESMA nuvem/sepia/cor-plena da terra (pedido do usuario:
##   "a transicao terra/mar homogenea na area coberta pela Terra Incognita").
## Custo: ~WATER_OVERLAY_RESOLUTION² consultas de coordenada por chamada —
## so roda em eventos discretos (turno, hover, selecao), nunca por frame.
## Constroi (so na primeira vez — memoizado pelo tamanho do array) o
## mapeamento pixel->coord axial pra resolucao/geometria ATUAL do mapa. Ver
## comentario de _water_overlay_coord_cache acima pro motivo.
func _ensure_water_overlay_coord_cache() -> void:
	var res := WATER_OVERLAY_RESOLUTION
	if _water_overlay_coord_cache.size() == res * res:
		return
	var half_extents = get_world_half_extents()
	var cache: Array[Vector2i] = []
	cache.resize(res * res)
	# Constroi junto com o coord cache (mesmo loop, mesma passada) os bytes
	# ESTATICOS de overlay/type — ver comentario dos campos acima pro motivo.
	var baseline_bytes := PackedByteArray()
	baseline_bytes.resize(res * res * 4)
	var type_static_bytes := PackedByteArray()
	type_static_bytes.resize(res * res * 4)
	for py in range(res):
		var v = float(py) / float(res - 1)
		var world_z = lerp(-half_extents.y, half_extents.y, v)
		var row_offset = py * res
		var byte_row_offset = row_offset * 4
		for px in range(res):
			var u = float(px) / float(res - 1)
			var world_x = lerp(-half_extents.x, half_extents.x, u)
			var coord = HexMetrics.world_to_axial(world_x, world_z, hex_size)
			cache[row_offset + px] = coord

			var tile: HexTileData = tiles.get(coord)
			var is_frozen = tile != null and tile.terrain_type == HexTileData.TerrainType.FROZEN_OCEAN
			var is_lava = tile != null and tile.terrain_type == HexTileData.TerrainType.LAVA_SEA
			var land_dist = _coast_distance_tiles.get(coord, -1)
			var water_coast_dist = float(max(land_dist - 1, 0)) if land_dist >= 0 else COAST_DISTANCE_NORM_MAX
			var coast_dist_norm = clamp(water_coast_dist / COAST_DISTANCE_NORM_MAX, 0.0, 1.0)

			var idx = byte_row_offset + px * 4
			baseline_bytes[idx] = 255
			baseline_bytes[idx + 1] = 255
			baseline_bytes[idx + 2] = 255
			baseline_bytes[idx + 3] = 0 if is_frozen else 255
			var lava_byte = 255 if is_lava else 0
			type_static_bytes[idx] = lava_byte
			type_static_bytes[idx + 1] = int(round(coast_dist_norm * 255.0))
			type_static_bytes[idx + 2] = lava_byte
			type_static_bytes[idx + 3] = 0
	_water_overlay_coord_cache = cache
	_water_overlay_baseline_bytes = baseline_bytes
	_water_overlay_baseline_texture = ImageTexture.create_from_image(
		Image.create_from_data(res, res, false, Image.FORMAT_RGBA8, baseline_bytes)
	)
	_liquid_type_static_bytes = type_static_bytes

## Bytes RGB estaticos de _rebuild_biome_overlay (cor CRUA do bioma — so'
## muda se o terreno em si mudar, o que nunca acontece depois do mapa
## gerado; ver _liquid_type_static_bytes pro mesmo padrao na agua) — A fica
## sempre 0, placeholder sobrescrito toda chamada com o fog_level de verdade.
var _biome_overlay_static_bytes: PackedByteArray = PackedByteArray()

func _ensure_biome_overlay_coord_cache() -> void:
	var res := BIOME_OVERLAY_RESOLUTION
	if _biome_overlay_coord_cache.size() == res * res:
		return
	var half_extents = get_world_half_extents()
	var cache: Array[Vector2i] = []
	cache.resize(res * res)
	var static_bytes := PackedByteArray()
	static_bytes.resize(res * res * 4)
	for py in range(res):
		var v = float(py) / float(res - 1)
		var world_z = lerp(-half_extents.y, half_extents.y, v)
		var row_offset = py * res
		var byte_row_offset = row_offset * 4
		for px in range(res):
			var u = float(px) / float(res - 1)
			var world_x = lerp(-half_extents.x, half_extents.x, u)
			var coord = HexMetrics.world_to_axial(world_x, world_z, hex_size)
			cache[row_offset + px] = coord

			var tile: HexTileData = tiles.get(coord)
			var color := Color(0.05, 0.05, 0.05)
			if tile != null and not tile.is_water() and tile.terrain_type != HexTileData.TerrainType.LAVA_SEA:
				color = tile.color
			var idx = byte_row_offset + px * 4
			static_bytes[idx] = int(round(clamp(color.r, 0.0, 1.0) * 255.0))
			static_bytes[idx + 1] = int(round(clamp(color.g, 0.0, 1.0) * 255.0))
			static_bytes[idx + 2] = int(round(clamp(color.b, 0.0, 1.0) * 255.0))
			static_bytes[idx + 3] = 0
	_biome_overlay_static_bytes = static_bytes
	_biome_overlay_coord_cache = cache

## Perfilamento real (usuario: "cai de 140 pra 15/20 fps toda troca de
## turno") mostrou esta funcao sozinha custando ~120-250ms/chamada num mapa
## Grande com varias civs — a MAIOR fatia do custo de recompute_fog. Duas
## otimizacoes em cima do coord cache (ver _ensure_water_overlay_coord_
## cache): (1) type_data (lava/coast/fog) NUNCA depende de highlight nenhum
## — R/G/B sao ESTATICOS (terreno nunca muda), so o canal A (fog_level)
## varia de turno a turno, entao SEMPRE usa o template cacheado
## (_liquid_type_static_bytes) + so recalcula A; (2) overlay_data (tint de
## destaque) SO precisa do loop pixel-a-pixel de verdade quando algum dos 4
## conjuntos de highlight tem alguma coisa — sem highlight nenhum (o caso de
## recompute_fog/fim de turno, o mais comum de todos) o resultado e SEMPRE
## identico ao baseline cacheado (_water_overlay_baseline_texture), entao
## reusa a MESMA textura em vez de reconstruir do zero.
func _rebuild_water_overlay(reachable: Array = [], attackable: Array = [], path: Array = [], buildable: Array = []) -> void:
	if _liquid_plane_instance == null:
		return

	_ensure_water_overlay_coord_cache()
	var res := WATER_OVERLAY_RESOLUTION

	var type_data := _liquid_type_static_bytes.duplicate()
	for py in range(res):
		var row_offset = py * res
		var byte_row_offset = row_offset * 4
		for px in range(res):
			var coord = _water_overlay_coord_cache[row_offset + px]
			# visibility so tem entrada pra coord que existe em `tiles` (ver
			# recompute_fog/set_debug_fog_disabled) — _fog_level_for ja
			# devolve 0.0 (UNSEEN) de graca pra qualquer coord ausente, entao
			# nao precisa checar tiles.has(coord) antes, so' um lookup a
			# menos por pixel.
			var fog_level = _fog_level_for(coord)
			type_data[byte_row_offset + px * 4 + 3] = int(round(clamp(fog_level, 0.0, 1.0) * 255.0))
	var type_img := Image.create_from_data(res, res, false, Image.FORMAT_RGBA8, type_data)
	_liquid_type_texture = ImageTexture.create_from_image(type_img)

	if reachable.is_empty() and attackable.is_empty() and path.is_empty() and buildable.is_empty():
		_water_overlay_texture = _water_overlay_baseline_texture
	else:
		var reachable_set := {}
		for c in reachable:
			reachable_set[c] = true
		var attackable_set := {}
		for c in attackable:
			attackable_set[c] = true
		var path_set := {}
		for c in path:
			path_set[c] = true
		var buildable_set := {}
		for c in buildable:
			buildable_set[c] = true

		var overlay_data := PackedByteArray()
		overlay_data.resize(res * res * 4)
		for py in range(res):
			var row_offset = py * res
			var byte_row_offset = row_offset * 4
			for px in range(res):
				var coord = _water_overlay_coord_cache[row_offset + px]

				# Nevoa de guerra em si NAO dimeriza mais aqui (ver comentario da
				# funcao acima) — so o destaque de movimento/ataque/construcao
				# continua sendo blend de cor por cima de uma base neutra,
				# mesmo espirito de _highlight_coords pro terreno solido.
				var tint := Color(1.0, 1.0, 1.0, 1.0)
				if buildable_set.has(coord):
					tint = tint.lerp(Color(0.35, 0.7, 1.0), 0.55)
				if path_set.has(coord):
					tint = tint.lerp(Color(1.0, 1.0, 0.4), 0.7)
				if attackable_set.has(coord):
					tint = tint.lerp(Color(1.0, 0.2, 0.2), 0.5)
				if reachable_set.has(coord):
					tint = tint.lerp(Color(0.3, 1.0, 0.3), 0.5)

				var tile: HexTileData = tiles.get(coord)
				var is_frozen = tile != null and tile.terrain_type == HexTileData.TerrainType.FROZEN_OCEAN
				tint.a = 0.0 if is_frozen else 1.0

				var idx = byte_row_offset + px * 4
				overlay_data[idx] = int(round(clamp(tint.r, 0.0, 1.0) * 255.0))
				overlay_data[idx + 1] = int(round(clamp(tint.g, 0.0, 1.0) * 255.0))
				overlay_data[idx + 2] = int(round(clamp(tint.b, 0.0, 1.0) * 255.0))
				overlay_data[idx + 3] = int(round(clamp(tint.a, 0.0, 1.0) * 255.0))
		var overlay_img := Image.create_from_data(res, res, false, Image.FORMAT_RGBA8, overlay_data)
		_water_overlay_texture = ImageTexture.create_from_image(overlay_img)

	var material: ShaderMaterial = _liquid_plane_instance.material_override
	material.set_shader_parameter("overlay_texture", _water_overlay_texture)
	# R (is_lava) desta textura so' alimenta mais lava_proximity (blend
	# cosmetico da agua perto de lava) agora — a decisao de RAMO lava-vs-agua
	# usa lava_tile_mask (1 texel por tile, ver _rebuild_lava_tile_mask),
	# nao mais esta textura continua por posicao-mundo.
	material.set_shader_parameter("liquid_type_texture", _liquid_type_texture)

## Resolucao PROPOSITALMENTE mais baixa que WATER_OVERLAY_RESOLUTION —
## quanto MENOS texels por tile, mais larga a mistura natural que o filtro
## linear (terrain.gdshader biome_overlay_texture: filter_linear) da entre
## biomas vizinhos na borda. 128 da uma mistura sutil sem lavar a
## identidade do bioma no centro do tile.
const BIOME_OVERLAY_RESOLUTION := 128

## Nivel de visibilidade CONTINUO (0=Unexplored, 0.5=Explored, 1=Visible) —
## fonte unica de verdade pro canal alfa de _rebuild_biome_overlay, evitando
## que a mascara amostrada por pixel em terrain.gdshader algum dia
## dessincronize do dicionario `visibility` de verdade.
func _fog_level_for(coord: Vector2i) -> float:
	match visibility.get(coord, Visibility.UNSEEN):
		Visibility.EXPLORED:
			return 0.5
		Visibility.VISIBLE:
			return 1.0
		_:
			return 0.0

## Mascara global de cor de bioma pro terreno solido (pedido do usuario:
## "mesma estrategia vencedora da agua", ver _rebuild_water_overlay acima).
## Amostrada por posicao-mundo com filtro linear em terrain.gdshader, pra
## suavizar a transicao de cor entre hexagonos vizinhos de biomas
## diferentes em vez do contorno reto de favo de mel. RGB guarda a cor CRUA
## do bioma (sem escurecimento — a nevoa de guerra, pedido do usuario de
## "3 estados visuais refinados" em vez de escurecimento direto, agora e
## responsabilidade inteira do shader); o canal ALFA guarda o fog_level
## continuo (_fog_level_for) — a MESMA textura, amostrada com filtro
## linear, da de graca tanto a mistura suave de cor de bioma na borda
## QUANTO a mistura suave entre nuvem/sepia/cor-plena da nevoa (ver
## terrain.gdshader fragment(), fog_level). Tiles de agua/lava entram so
## pelo alfa (a cor RGB fica neutra, ja que esse pixel so e amostrado pelas
## bordas de terra vizinhas) — sem isso um tile de terra bem na costa
## vazaria "nao explorado" na borda so por causa do vizinho de agua, mesmo
## quando a agua em si esta VISIVEL. Chamada em todo _apply_land_and_prop_
## fog(), mesma cadencia de _rebuild_water_overlay (evento discreto:
## turno/hover/selecao, nunca por frame).
func _rebuild_biome_overlay() -> void:
	if _multimesh_instance == null:
		return

	_ensure_biome_overlay_coord_cache()
	var res := BIOME_OVERLAY_RESOLUTION
	# RGB (cor crua do bioma) e ESTATICO — vem pronto do template cacheado
	# (_biome_overlay_static_bytes, ver _ensure_biome_overlay_coord_cache);
	# so o canal A (fog_level) muda de turno a turno, entao e o UNICO valor
	# recalculado por pixel aqui (mesmo padrao de _rebuild_water_overlay's
	# type_data — perfilamento real mostrou isso cortando o custo desta
	# funcao de ~27ms pra uma fracao disso).
	var data := _biome_overlay_static_bytes.duplicate()
	for py in range(res):
		var row_offset = py * res
		var byte_row_offset = row_offset * 4
		for px in range(res):
			var coord = _biome_overlay_coord_cache[row_offset + px]
			var fog_level := _fog_level_for(coord) # ver comentario equivalente em _rebuild_water_overlay
			data[byte_row_offset + px * 4 + 3] = int(round(clamp(fog_level, 0.0, 1.0) * 255.0))

	var img := Image.create_from_data(res, res, false, Image.FORMAT_RGBA8, data)
	_biome_overlay_texture = ImageTexture.create_from_image(img)
	var terrain_material: ShaderMaterial = _multimesh_instance.material_override
	terrain_material.set_shader_parameter("biome_overlay_texture", _biome_overlay_texture)

## Terra firme (todo bioma que nao seja Oceano/Mar Gelado/Mar de Lava) —
## terrain.gdshader, opaco.
func _build_terrain_multimesh(coords: Array[Vector2i], coord_to_index: Dictionary) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _hex_mesh
	multimesh.instance_count = coords.size()

	var i := 0
	for coord in coords:
		var data: HexTileData = tiles[coord]
		var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
		world.y = data.base_height
		multimesh.set_instance_transform(i, Transform3D(Basis(), world))
		multimesh.set_instance_color(i, data.color)
		# r = seed aleatorio por tile (variacao sutil de cor/rugosidade,
		# ver shaders/terrain.gdshader), g = volumetria (elevation_kind: 0
		# plano, 1 Colina, 2 Montanha — pedido do usuario, ver terrain.gdshader
		# elevation_height), a = tratamento visual especial
		# (_material_kind_for) — sem isso todo bioma so mudava de cor sob a
		# MESMA textura de chao generica, reportado pelo usuario ("os biomas
		# nao parecem bem trabalhados"). b fica sem uso (0.0).
		var material_kind = _material_kind_for(data.terrain_type)
		var elevation_kind := 0.0
		if data.terrain_type == HexTileData.TerrainType.MOUNTAINS or data.terrain_type == HexTileData.TerrainType.VOLCANIC_PEAKS or data.terrain_type == HexTileData.TerrainType.CRYSTAL_PEAKS:
			# Montanhas Vulcanicas/Picos de Cristal (continentes especiais)
			# ganham a MESMA cupula/pico visual de Montanhas normal — mesmo
			# canal, so mais tipos reconhecidos (ver _material_kind_for pra
			# textura/brilho, canal independente deste).
			elevation_kind = 2.0
		elif data.terrain_type == HexTileData.TerrainType.HILLS or data.terrain_type == HexTileData.TerrainType.VOLCANIC_HILLS:
			# Colinas Vulcanicas (pedido do usuario: "adicione variacao de
			# altura 3D para colinas vulcanicas") ganham a MESMA cupula de
			# Colina normal.
			elevation_kind = 1.0
		multimesh.set_instance_custom_data(i, Color(randf(), elevation_kind, 0.0, material_kind))
		coord_to_index[coord] = i
		i += 1

	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.multimesh = multimesh
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/terrain.gdshader")
	material.set_shader_parameter("prism_depth", hex_size * LAND_PRISM_DEPTH_FACTOR) # bate com _build_hex_prism_mesh(hex_size, LAND_PRISM_DEPTH_FACTOR), nunca dessincroniza se qualquer um dos dois mudar
	material.set_shader_parameter("hex_radius", hex_size) # normaliza a distancia ao centro do tile pra 0..1 na transicao organica de bioma (ver terrain.gdshader)
	material.set_shader_parameter("biome_overlay_half_extents", get_world_half_extents()) # setup unico, igual overlay_half_extents da agua em _build_liquid_plane — o TEXTURE em si (que muda com fog) e atualizado a parte por _rebuild_biome_overlay
	const ALBEDO_TEX_PATH := "res://assets/textures/terrain/ground_albedo.jpg"
	if ResourceLoader.exists(ALBEDO_TEX_PATH):
		material.set_shader_parameter("albedo_tex", load(ALBEDO_TEX_PATH))
	else:
		# Sem a textura (CC0, ambientCG "Ground037") o shader ainda funciona
		# — texture() com sampler vazio devolve preto, entao zeramos a
		# influencia dela pra nao pintar o mapa inteiro de preto.
		material.set_shader_parameter("texture_strength", 0.0)
	# Texturas reais dos 4 biomas com tratamento visual proprio (ver
	# _material_kind_for) — pedido do usuario: "baixe as texturas corretas
	# de assets pra isso". Cada uma so e amostrada dentro do branch do
	# proprio mat_kind no shader; se o arquivo faltar, o uniform fica no
	# branco padrao (`hint_default_white` no shader), a tint sozinha ainda
	# funciona — mesma filosofia de fallback do resto do projeto.
	_set_optional_texture(material, "snow_tex", "res://assets/textures/terrain/snow_albedo.jpg")
	_set_optional_texture(material, "desert_tex", "res://assets/textures/terrain/desert_albedo.jpg")
	_set_optional_texture(material, "lava_tex", "res://assets/textures/terrain/lava_albedo.jpg")
	_set_optional_texture(material, "crystal_tex", "res://assets/textures/terrain/crystal_albedo.jpg")
	mm_instance.material_override = material
	return mm_instance

func _set_optional_texture(material: ShaderMaterial, param: String, path: String) -> void:
	if ResourceLoader.exists(path):
		material.set_shader_parameter(param, load(path))

## `depth_factor` multiplica `size` pra profundidade do prisma (padrao 0.4,
## historico) — terreno solido chama com um `depth_factor` MAIOR (ver
## LAND_PRISM_DEPTH_FACTOR) pra garantir "saia" submersa abaixo do plano de
## agua mesmo nos tiles mais altos (Colina/Montanha).
func _build_hex_prism_mesh(size: float, depth_factor: float = 0.4) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top_corners: Array[Vector3] = []
	for i in range(6):
		top_corners.append(HexMetrics.corner(size, i))

	for i in range(6):
		var c1 = top_corners[i]
		var c2 = top_corners[(i + 1) % 6]
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(c2)
		st.set_normal(Vector3.UP)
		st.add_vertex(c1)

	var bottom_offset = Vector3(0.0, -size * depth_factor, 0.0)
	for i in range(6):
		var c1 = top_corners[i]
		var c2 = top_corners[(i + 1) % 6]
		var side_normal = ((c1 + c2) * 0.5).normalized()
		var b1 = c1 + bottom_offset
		var b2 = c2 + bottom_offset

		st.set_normal(side_normal)
		st.add_vertex(c1)
		st.set_normal(side_normal)
		st.add_vertex(b1)
		st.set_normal(side_normal)
		st.add_vertex(c2)

		st.set_normal(side_normal)
		st.add_vertex(c2)
		st.set_normal(side_normal)
		st.add_vertex(b1)
		st.set_normal(side_normal)
		st.add_vertex(b2)

	return st.commit()

## Espalha arvores (modelo real KayKit, ver _load_tree_mesh) em tiles de
## floresta e gelo flutuante em tiles de Mar Gelado, dando cara de bioma ao
## mapa. As instancias reaproveitam MultiMesh (como o terreno) e respeitam a
## mesma neblina de guerra via _apply_prop_fog().
func _rebuild_props() -> void:
	if _props_tree_instance:
		_props_tree_instance.queue_free()
		_props_tree_instance = null
	if _props_ice_floe_instance:
		_props_ice_floe_instance.queue_free()
		_props_ice_floe_instance = null

	const TREE_TERRAINS := [
		HexTileData.TerrainType.FOREST, HexTileData.TerrainType.TAIGA, HexTileData.TerrainType.JUNGLE,
	]
	var tree_coords: Array[Vector2i] = []
	var ice_floe_coords: Array[Vector2i] = []
	for coord in tiles.keys():
		var data: HexTileData = tiles[coord]
		# Tile com recurso especial (ver ResourceDatabase/ResourcePropsManager)
		# nunca ganha arvore decorativa — pedido do usuario: 3-5 arvores
		# empilhadas enterravam visualmente o prop pequeno do recurso (e o
		# icone billboard some atras da copa da arvore), tornando o tile
		# ilegivel como "tem recurso aqui".
		if data.terrain_type in TREE_TERRAINS:
			if data.resource == "":
				tree_coords.append(coord)
		elif data.terrain_type == HexTileData.TerrainType.FROZEN_OCEAN:
			# Nem todo tile de Mar Gelado ganha gelo flutuante (pedido do
			# usuario: "nao precisam ter em todas as celulas") — um mar de
			# gelo real tem trechos de agua aberta entre os blocos, nao
			# cobertura uniforme tile-a-tile.
			if randf() < 0.55:
				ice_floe_coords.append(coord)

	_tree_coord_to_index.clear()
	if tree_coords.size() > 0:
		# 3 a 5 arvores menores por tile de floresta, cada uma com offset
		# radial/rotacao/escala proprios (pedido do usuario: "em vez de 1
		# arvore centralizada" — o padrao antigo, 1 instancia sempre no
		# centro do tile e sempre do mesmo tamanho, lia como grade rigida
		# de repeticao). _tree_coord_to_index guarda um Array de indices
		# por coord agora (nao mais 1 int), ver _tint_props abaixo.
		var placements: Array[Dictionary] = []
		for coord in tree_coords:
			var center = world_for_coord(coord)
			var count = randi_range(3, 5)
			for j in range(count):
				# Offset RADIAL (angulo + distancia aleatorios), nao X/Z
				# uniforme independente — X/Z uniforme tende a agrupar mais
				# perto dos cantos do quadrado de amostragem; radial da uma
				# dispersao mais organica dentro do hexagono. 0.62*hex_size
				# fica bem dentro do raio do tile (corners ficam a 1.0*
				# hex_size), pra nao invadir visualmente o tile vizinho.
				var offset_dist = randf_range(0.1, hex_size * 0.62)
				var offset_angle = randf() * TAU
				var pos = center
				pos.x += cos(offset_angle) * offset_dist
				pos.z += sin(offset_angle) * offset_dist
				var tree_scale = randf_range(0.8, 1.2) * TREE_MODEL_SCALE
				var basis = Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * tree_scale)
				placements.append({"coord": coord, "pos": pos, "basis": basis})

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _tree_mesh
		mm.instance_count = placements.size()
		for i in range(placements.size()):
			var p = placements[i]
			mm.set_instance_transform(i, Transform3D(p.basis, p.pos))
			mm.set_instance_color(i, Color.WHITE)
			if not _tree_coord_to_index.has(p.coord):
				_tree_coord_to_index[p.coord] = []
			_tree_coord_to_index[p.coord].append(i)
		_props_tree_instance = MultiMeshInstance3D.new()
		_props_tree_instance.multimesh = mm
		var tree_mat := StandardMaterial3D.new()
		# Textura pintada real da arvore KayKit (a malha em si nao carrega
		# vertex color nenhum — confirmado no glTF, so POSITION/UV/NORMAL —
		# entao a cor de instancia do MultiMesh abaixo so multiplica por
		# branco/nevoa, nunca lava a textura).
		tree_mat.albedo_texture = load("res://assets/models/kaykit/nature/forest_texture.png")
		tree_mat.vertex_color_use_as_albedo = true
		tree_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Nevoa de guerra (pedido do usuario: props escondidos em tiles nao
		# explorados) — _tint_props zera o ALFA da cor de instancia pra
		# Unseen; SCISSOR (em vez de ALPHA normal) porque o alfa aqui e
		# sempre binario (0 ou 1, nunca fracionario), evitando o custo/
		# artefato de ordenacao de blending que TRANSPARENCY_ALPHA teria.
		tree_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		tree_mat.alpha_scissor_threshold = 0.5
		_props_tree_instance.material_override = tree_mat
		add_child(_props_tree_instance)

	_ice_floe_coord_to_index.clear()
	if ice_floe_coords.size() > 0:
		# 1 a 2 pedacos de gelo por tile de Mar Gelado SORTEADO (nem todo
		# tile ganha, ver ice_floe_coords acima), tamanho bem variado por
		# instancia — pedido do usuario: "mais realistas... nao precisam ter
		# em todas as celulas... tamanhos variados, alguns grandes, alguns
		# pequenos, em rotacoes diferentes". Mesmo padrao radial de arvore/
		# pico, mas flutuando NA SUPERFICIE do plano de agua (LIQUID_LEVEL_Y)
		# em vez de assentar no terreno solido, ja que Mar Gelado e um bioma
		# de AGUA (is_water()==true, sem prisma embaixo).
		var placements: Array[Dictionary] = []
		for coord in ice_floe_coords:
			var center = world_for_coord(coord)
			var count = randi_range(1, 2)
			for j in range(count):
				var offset_dist = randf_range(0.05, hex_size * 0.45)
				var offset_angle = randf() * TAU
				var pos = center
				pos.x += cos(offset_angle) * offset_dist
				pos.z += sin(offset_angle) * offset_dist
				# Exatamente na altura do plano de agua (pedido do usuario:
				# "garanta que fiquem alinhados com a altura exata do nivel
				# da agua") — a malha ja tem a base em y=0 local, entao sem
				# nenhum offset aleatorio o topo/base do floe fica sempre na
				# MESMA cota que LIQUID_LEVEL_Y, nunca flutuando acima nem
				# afundando abaixo da superficie.
				pos.y = LIQUID_LEVEL_Y
				# Faixa ampla (era 1.3-2.0, so "grande") pra ter pedaços
				# pequenos e grandes de verdade no mesmo mapa (pedido do
				# usuario: "tamanhos variados, alguns grandes, alguns
				# pequenos"), nao so uma variação sutil dentro do "grande".
				var floe_scale = randf_range(0.5, 2.2)
				# Rotacao aleatoria em Y por instancia (ja existia) — cada
				# pedaco pega um angulo independente, entao nunca ficam
				# todos com a mesma orientacao.
				var floe_basis = Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * floe_scale)
				placements.append({"coord": coord, "pos": pos, "basis": floe_basis})

		var mm4 := MultiMesh.new()
		mm4.transform_format = MultiMesh.TRANSFORM_3D
		mm4.use_colors = true
		mm4.mesh = _ice_floe_mesh
		mm4.instance_count = placements.size()
		for i in range(placements.size()):
			var p = placements[i]
			mm4.set_instance_transform(i, Transform3D(p.basis, p.pos))
			mm4.set_instance_color(i, ICE_FLOE_BASE_COLOR)
			if not _ice_floe_coord_to_index.has(p.coord):
				_ice_floe_coord_to_index[p.coord] = []
			_ice_floe_coord_to_index[p.coord].append(i)
		_props_ice_floe_instance = MultiMeshInstance3D.new()
		_props_ice_floe_instance.multimesh = mm4
		var floe_mat := StandardMaterial3D.new()
		floe_mat.vertex_color_use_as_albedo = true
		floe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Fosco (pedido do usuario, mesmo espirito do Mar Gelado no shader
		# de agua) — gelo solido nao deveria brilhar como plastico/metal.
		# 0.9 (era 0.85, pedido do usuario 3a rodada) reduz ainda mais
		# qualquer reflexo especular residual que contribuia pro aspecto de
		# "isopor" ao lado da nova cor mais saturada acima.
		floe_mat.roughness = 0.9
		floe_mat.metallic = 0.0
		# Nevoa de guerra — ver comentario equivalente em tree_mat acima.
		floe_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		floe_mat.alpha_scissor_threshold = 0.5
		_props_ice_floe_instance.material_override = floe_mat
		add_child(_props_ice_floe_instance)

	_resource_props_manager.rebuild(tiles)
	_resource_icon_manager.rebuild(tiles)

## Altura VISUAL real do CENTRO de um tile (base_height + o pico/domo do
## terrain.gdshader no seu ponto mais alto, r=0) — usado pelo contorno de
## territorio da cidade (_build_city_tint_mesh) pra encaixar no relevo em
## vez de afundar dentro de um pico de Montanha/domo de Colina.
func _tile_surface_height(coord: Vector2i) -> float:
	var data: HexTileData = tiles[coord]
	var h = data.base_height
	# VOLCANIC_PEAKS/CRYSTAL_PEAKS (continentes especiais) e VOLCANIC_HILLS
	# faltavam aqui (bug latente pego revisando a regressao de relevo 3D:
	# props/tingimento de territorio nesses tiles ficavam na altura CRUA de
	# base_height, sem a cupula/pico — mesmo canal elevation_kind que
	# _build_terrain_multimesh ja usa pro relevo visual de verdade).
	if data.terrain_type == HexTileData.TerrainType.MOUNTAINS or data.terrain_type == HexTileData.TerrainType.VOLCANIC_PEAKS or data.terrain_type == HexTileData.TerrainType.CRYSTAL_PEAKS:
		h += MOUNTAIN_PEAK_HEIGHT
	elif data.terrain_type == HexTileData.TerrainType.HILLS or data.terrain_type == HexTileData.TerrainType.VOLCANIC_HILLS:
		h += HILL_HEIGHT
	return h

## Pack ice/iceberg pequeno (pedido do usuario, Ponto 2: "micro-icebergs
## flutuantes... pequenas formacoes de gelo 3D/procedurais") — contorno
## jitterado (mesma tecnica de _build_tree_mesh), so BAIXO e CHATO em vez de
## pontudo (gelo flutuando na superficie, nao uma montanha) e com a base
## mais ESTREITA que o topo (afunila pra baixo, como um pedaco de gelo real
## que fica mais fino debaixo d'agua). Escala/posicao/rotacao por instancia
## ficam em _rebuild_props, igual arvore/gelo.
func _build_ice_floe_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides := 6
	var top_radius := 0.16
	var bottom_radius := 0.1
	var height := 0.09
	var top_points: Array[Vector3] = []
	var bottom_points: Array[Vector3] = []
	for i in range(sides):
		var a = TAU * float(i) / float(sides)
		var jitter = 1.0 + 0.4 * sin(a * 2.3 + 0.7) # contorno irregular fixo, nao um hexagono perfeito
		top_points.append(Vector3(cos(a) * top_radius * jitter, height, sin(a) * top_radius * jitter))
		bottom_points.append(Vector3(cos(a) * bottom_radius * jitter, 0.0, sin(a) * bottom_radius * jitter))

	var top_center := Vector3(0.0, height, 0.0)
	for i in range(sides):
		var p1 = top_points[i]
		var p2 = top_points[(i + 1) % sides]
		for v in [top_center, p1, p2]:
			st.set_color(ICE_FLOE_BASE_COLOR)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)

	for i in range(sides):
		var t1 = top_points[i]
		var t2 = top_points[(i + 1) % sides]
		var b1 = bottom_points[i]
		var b2 = bottom_points[(i + 1) % sides]
		var mid = (t1 + t2 + b1 + b2) * 0.25
		var normal = Vector3(mid.x, 0.0, mid.z).normalized()
		for v in [b1, t2, t1, b1, b2, t2]:
			st.set_color(ICE_FLOE_BASE_COLOR)
			st.set_normal(normal)
			st.add_vertex(v)

	return st.commit()

## Extrai a malha (so geometria/UV, sem material — o material real vem do
## StandardMaterial3D montado em _rebuild_props via material_override, que
## precisa MISTURAR a textura da arvore com a cor de instancia do MultiMesh
## pra nevoa de guerra continuar funcionando) da cena importada da KayKit.
## Uma unica instancia temporaria e criada so pra alcancar o MeshInstance3D
## dentro dela; o recurso ArrayMesh em si sobrevive a instancia ser
## descartada (fica compartilhado por todas as copias via MultiMesh, igual
## a malha procedural antiga).
func _load_tree_mesh() -> Mesh:
	var scene: PackedScene = load(TREE_MODEL_SCENE)
	var inst := scene.instantiate()
	var mesh_instance := _find_mesh_instance(inst)
	var mesh: Mesh = mesh_instance.mesh
	inst.queue_free()
	return mesh

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null

## Numero de dano flutuante que sobe e some — sem isso, tomar dano so
## aparece como uma notificacao de texto no topo da tela, longe de onde a
## acao realmente aconteceu no mundo.
func spawn_damage_popup(coord: Vector2i, amount: float) -> void:
	var label := Label3D.new()
	label.text = "-%d" % int(round(amount))
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color(1.0, 0.35, 0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var pos = world_for_coord(coord)
	pos.y += 0.9
	pos.x += randf_range(-0.15, 0.15)
	label.position = pos
	add_child(label)

	# create_tween() exige HexGrid dentro da SceneTree (ex: testes GUT que
	# criam HexGrid isolado, sem add_child) — sem isso o jogo de verdade
	# nunca chama isto fora da arvore, mas evita quebrar o teste: so
	# descarta o popup sem animar em vez de crashar.
	if not is_inside_tree():
		label.queue_free()
		return

	var tween = create_tween()
	tween.tween_property(label, "position:y", pos.y + 0.7, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)

func _build_hover_label() -> void:
	_hover_label = Label3D.new()
	_hover_label.font_size = 34
	_hover_label.outline_size = 9
	_hover_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hover_label.no_depth_test = true
	_hover_label.visible = false
	add_child(_hover_label)

func _build_selection_marker() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = hex_size * 0.75
	torus.outer_radius = hex_size * 0.9
	_selection_marker = MeshInstance3D.new()
	_selection_marker.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.1)
	mat.emission_energy_multiplier = 1.5
	_selection_marker.material_override = mat
	_selection_marker.visible = false
	add_child(_selection_marker)

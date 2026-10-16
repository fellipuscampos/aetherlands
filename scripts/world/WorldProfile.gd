class_name WorldProfile
extends RefCounted

## PERFIL de mundo da geração: tamanho da grade, ÁREA RESERVADA ao continente principal e o que existe além dele.
##
## TAMANHOS JOGÁVEIS (2026-10-10, proposta do usuário: "cada versão seria só uma versão menor do mesmo continente a
## nível de cálculo de biomas"; o oceano grande existia para aventuras navais/outros continentes, que não existem mais):
##
##   | Tamanho | Grade    | Área reservada | Terra (medida) |
##   | Pequeno | 96 × 56  | 72 × 44        | ~1.650 tiles   |
##   | Médio   | 112 × 64 | 84 × 52        | ~2.275 tiles   |
##   | Grande  | 128 × 72 | 96 × 60        | ~3.000 tiles   |
##
## O continente fica dentro da área reservada (HexGrid._edge_falloff puxa a borda dela para o oceano; o clima é
## normalizado pela altura dela). "O MESMO continente, menor": noise_scale = 96 / largura da área multiplica as
## frequências do ruído da geração (e divide a força da distorção do litoral) — a mesma seed gera o mesmo desenho e a
## mesma distribuição de biomas em escala reduzida. Conferido: a área reservada cabe na grade nos três (o canto do
## paralelogramo axial cai na coluna 47/48, 55/56 e 63/64).
##
## PERFIS LEGADOS (saves): o mundo é REGENERADO por seed + dimensões no load (SaveManager), então o perfil sai das
## dimensões (`for_dimensions`). 144 × 76 (o "padrão 1.0" anterior) e 320 × 84 (continentes Vulcânico e Cristalino,
## reservados para conteúdo futuro) continuam registrados com a área 96 × 60 e escala 1: um save antigo regenera
## exatamente o mesmo mundo (test_map_sizes.gd compara o terreno com um hash capturado antes desta mudança).
##
## Campos: id, label, width/height (grade em colunas/linhas offset), main_frame (área reservada, em colunas axiais q ×
## linhas r), fixed_main_frame (false = o mapa inteiro é a zona principal, só fixtures de teste), volcanic_continent,
## crystal_continent.

## Largura da área reservada de referência (o Grande): noise_scale = REFERENCE_FRAME_WIDTH / main_frame.x.
const REFERENCE_FRAME_WIDTH := 96.0

const MAP_SMALL := {
	"id": "small", "label": "Pequeno", "width": 96, "height": 56, "main_frame": Vector2i(72, 44),
	"fixed_main_frame": true, "volcanic_continent": false, "crystal_continent": false,
}
const MAP_MEDIUM := {
	"id": "medium", "label": "Médio", "width": 112, "height": 64, "main_frame": Vector2i(84, 52),
	"fixed_main_frame": true, "volcanic_continent": false, "crystal_continent": false,
}
const MAP_LARGE := {
	"id": "large", "label": "Grande", "width": 128, "height": 72, "main_frame": Vector2i(96, 60),
	"fixed_main_frame": true, "volcanic_continent": false, "crystal_continent": false,
}

## LEGADO — o tamanho de toda partida nova entre a V3/Etapa 3 e 2026-10-10. Só para saves antigos.
const STANDARD_1_0 := {
	"id": "standard_1_0", "label": "Grande (legado 144×76)", "width": 144, "height": 76, "main_frame": Vector2i(96, 60),
	"fixed_main_frame": true, "volcanic_continent": false, "crystal_continent": false,
}
## LEGADO / conteúdo futuro — continentes especiais (saves antigos do tamanho Grande 320×84).
const SPECIAL_CONTINENTS := {
	"id": "special_continents", "label": "Continentes especiais", "width": 320, "height": 84, "main_frame": Vector2i(96, 60),
	"fixed_main_frame": true, "volcanic_continent": true, "crystal_continent": true,
}
## Fixtures de teste (abaixo do menor tamanho jogável): sem área fixa nem continentes especiais — o mapa inteiro é a zona
## principal (comportamento histórico de mapa pequeno de teste).
const TEST_FIXTURE := {
	"id": "test_fixture", "label": "Teste", "width": 0, "height": 0, "main_frame": Vector2i.ZERO,
	"fixed_main_frame": false, "volcanic_continent": false, "crystal_continent": false,
}

## Tamanhos oferecidos na tela de partida nova, do menor ao maior.
static func playable_sizes() -> Array:
	return [MAP_SMALL, MAP_MEDIUM, MAP_LARGE]

## Todos os perfis com área reservada fixa (jogáveis + legados), para `for_dimensions`.
static func registered() -> Array:
	return [MAP_SMALL, MAP_MEDIUM, MAP_LARGE, STANDARD_1_0, SPECIAL_CONTINENTS]

## Tamanho padrão de uma partida nova (GameSetupScreen / laboratório de balanceamento).
static func default_size() -> Dictionary:
	return MAP_LARGE

static func standard() -> Dictionary:
	return default_size()

static func by_id(id: String) -> Dictionary:
	for profile in registered():
		if String(profile.id) == id:
			return profile
	return {}

## Perfil derivado das dimensões da grade. Dimensões EXATAS de um perfil registrado escolhem esse perfil (é o que os
## saves gravam). Dimensões desconhecidas seguem a regra de sempre, para nada existente mudar de comportamento: área de
## continentes especiais ou maior = continentes especiais; área do legado 144×76 ou maior = legado; menor = fixture de
## teste (o mapa inteiro é a zona principal — ex.: os mapas 41×41/81×81 dos testes).
static func for_dimensions(width: int, height: int) -> Dictionary:
	for profile in registered():
		if width == int(profile.width) and height == int(profile.height):
			return profile
	var area := width * height
	if area >= int(SPECIAL_CONTINENTS.width) * int(SPECIAL_CONTINENTS.height):
		return SPECIAL_CONTINENTS
	if area >= int(STANDARD_1_0.width) * int(STANDARD_1_0.height):
		return STANDARD_1_0
	return TEST_FIXTURE

## Meia-largura (colunas axiais q) e meia-altura (linhas r) da área reservada ao continente principal. Fixture: o mapa
## inteiro (meia-dimensões da grade).
static func main_half_extents(profile: Dictionary, map_width: int, map_height: int) -> Vector2:
	if not bool(profile.get("fixed_main_frame", false)):
		return Vector2(float(map_width) / 2.0, float(map_height) / 2.0)
	var frame: Vector2i = profile.main_frame
	return Vector2(float(frame.x) / 2.0, float(frame.y) / 2.0)

## Quanto o ruído da geração é "apertado" para o continente caber na área reservada mantendo o mesmo desenho:
## 96 / largura da área (1 no Grande e nos legados; fixtures também 1 — comportamento histórico).
static func noise_scale(profile: Dictionary) -> float:
	if not bool(profile.get("fixed_main_frame", false)):
		return 1.0
	return REFERENCE_FRAME_WIDTH / float((profile.main_frame as Vector2i).x)

## Terra estimada do tamanho (texto da tela de partida nova): proporcional à área reservada, ~3.000 no Grande.
static func estimated_land_tiles(profile: Dictionary) -> int:
	var frame: Vector2i = profile.get("main_frame", Vector2i.ZERO)
	return int(round(3000.0 * float(frame.x * frame.y) / (96.0 * 60.0) / 25.0)) * 25

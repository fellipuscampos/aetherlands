class_name WorldProfile
extends RefCounted

## V3 / Etapa 3 — PERFIL de mundo da geração (o que existe no canvas além do terreno do continente principal).
##
## Aetherlands 1.0 gera SÓ o continente principal (STANDARD_1_0). Os continentes Vulcânico e Cristalino continuam
## existindo em código (zonas, biomas, Vivern/Dragão de lava, testes) e são reservados para conteúdo futuro
## (opção de setup, aventura, expansão): o perfil SPECIAL_CONTINENTS os liga num canvas maior. Nada foi apagado.
##
## O mundo é REGENERADO pela seed + dimensões no load (SaveManager), então o perfil é derivado das dimensões
## (`for_dimensions`) — um save antigo de 320×84 continua com os continentes especiais, sem campo novo no save.
## Mapas menores que o padrão (fixtures de teste) não usam a pegada fixa: o mapa inteiro é "principal".
##
## Campos: id, width/height (canvas em colunas/linhas offset), fixed_main_frame (o continente principal usa a pegada
## histórica fixa TitleScreen.MAIN_ZONE_SIZE em vez das dimensões do canvas), volcanic_continent, crystal_continent.

## V3 / Etapa 4 — DECISÃO DE PRODUTO PENDENTE: o tamanho 144×76 do STANDARD_1_0 (definido na Etapa 3) ainda não é final
## — o product owner pode mantê-lo, aumentá-lo ou restaurar outro tamanho. Não alterar sem essa decisão, e não comparar
## números de laboratório 144×76 com F33B/Etapa 2 (320×84) como se fossem amostras equivalentes.
const STANDARD_1_0 := {
	"id": "standard_1_0", "width": 144, "height": 76,
	"fixed_main_frame": true, "volcanic_continent": false, "crystal_continent": false,
}
const SPECIAL_CONTINENTS := {
	"id": "special_continents", "width": 320, "height": 84,
	"fixed_main_frame": true, "volcanic_continent": true, "crystal_continent": true,
}
## Fixtures/mapas pequenos: sem pegada fixa nem continentes especiais (comportamento histórico de mapa pequeno).
const SMALL := {
	"id": "small", "width": 0, "height": 0,
	"fixed_main_frame": false, "volcanic_continent": false, "crystal_continent": false,
}

## Perfil de uma partida nova normal (GameSetupScreen / laboratório).
static func standard() -> Dictionary:
	return STANDARD_1_0

## Perfil derivado das dimensões do canvas: as dimensões exatas de um perfil registrado escolhem esse perfil; área
## de canvas especial ou maior = continentes especiais (saves antigos do tamanho Grande 320×84); área do padrão 1.0
## ou maior = padrão; menor = mapa pequeno.
static func for_dimensions(width: int, height: int) -> Dictionary:
	for profile in [STANDARD_1_0, SPECIAL_CONTINENTS]:
		if width == int(profile.width) and height == int(profile.height):
			return profile
	var area := width * height
	if area >= int(SPECIAL_CONTINENTS.width) * int(SPECIAL_CONTINENTS.height):
		return SPECIAL_CONTINENTS
	if area >= int(STANDARD_1_0.width) * int(STANDARD_1_0.height):
		return STANDARD_1_0
	return SMALL

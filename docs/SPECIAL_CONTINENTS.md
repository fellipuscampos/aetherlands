# Continentes especiais (Vulcânico e Cristalino) — status

**Resumo:** o conteúdo dos continentes Vulcânico e Cristalino **existe no código e funciona**, mas está
**desligado na geração padrão do Aetherlands 1.0**. Fica reservado para conteúdo futuro opcional (opção de setup,
modo aventura, expansão). Nada foi apagado.

## O que o 1.0 gera

`WorldProfile.STANDARD_1_0` (`scripts/world/WorldProfile.gd`): canvas 144×76, só o continente principal (pegada
fixa histórica). É o perfil de toda partida nova (`TitleScreen.MAP_SIZES.large`) e do laboratório de balanceamento
(`tools/balance/BalanceSeedSet.gd`). Medido em 48 seeds: 0 tiles de zona Vulcânica/Cristalina, 0 terreno especial
(Lava, Mar de Lava, Picos Vulcânicos, Cristal...), 0 terra fora do continente principal.

## Onde o conteúdo especial vive

| Peça | Local |
|---|---|
| Perfil que liga os dois continentes | `WorldProfile.SPECIAL_CONTINENTS` (canvas 320×84, `volcanic_continent`/`crystal_continent` = true) |
| Zonas e retângulos fixos | `HexGrid.VOLCANIC_ZONE_CENTER`, `CRYSTAL_ZONE_CENTER`, `_zone_for`, `_in_zone_bounds`, `_edge_falloff_for_zone` |
| Biomas | `HexGrid._maybe_volcanic`, `_maybe_crystal`, `_volcanic_noise`, terrenos Lava/Mar de Lava/Terra Vulcânica/Colinas e Picos Vulcânicos/Solo de Cinzas/Solo Místico/Campos e Picos de Cristal (`HexTileData`/`TerrainDatabase`) |
| Testes que provam que funcionam | `test/unit/test_terrain_generation.gd` (constante `SPECIAL_WORLD`, `test_special_continents_profile_still_generates_volcanic_and_crystal_land`) |

`_zone_for` só devolve VULCÂNICA/CRISTAL quando o perfil do mapa (`HexGrid.world_profile`) liga a flag; no padrão
1.0 esses tiles nunca são classificados, então nenhum bioma especial é sorteado.

## Saves antigos

O mundo é regenerado pela seed + dimensões no load, e o perfil é derivado das dimensões
(`WorldProfile.for_dimensions`). Um save do tamanho Grande antigo (320×84) **continua** com os continentes
especiais; um save novo (144×76) continua só com o principal. Sem campo novo no save, sem migração.

## Como religar no futuro

Gerar o mapa com as dimensões de `WorldProfile.SPECIAL_CONTINENTS` (ou criar um perfil novo com as flags ligadas e
registrá-lo em `for_dimensions`). Antes de expor isso ao jogador: decidir a ecologia/ameaças dessas terras (a Combat
Ecology só povoa a terra do perfil principal) e revalidar o world survey.

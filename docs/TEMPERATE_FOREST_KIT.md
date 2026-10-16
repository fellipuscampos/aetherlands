# Kit modular de floresta temperada

[Guia de uso e catálogo](../assets/generated/nature/temperate_forest_v1/README.md) · [Galeria](../art_source/temperate_forest_review/index.html).

Dez assets criados pelo MCP do Blender. Total de 1.202 triângulos, uma malha por asset e um atlas compartilhado de 512×512. Fontes, GLBs, cenas individuais e malhas para MultiMesh estão no diretório do kit.

## Uso no mapa (composição procedural)

Desde 09/10/2026 a vegetação do mapa vem deste kit; a árvore KayKit única, repetida com escala e rotação, saiu. São três peças com papéis separados:

| Arquivo | Papel |
|---|---|
| `scripts/data/NatureKitCatalog.gd` | Catálogo: categoria, espécie, `footprint_radius` e altura de cada asset (conferidos contra `manifest.json` pelos testes), malha `.res` em cache e material do mapa (cópia do `.tres` com cor por instância e recorte de alfa para a névoa; o `.tres` do kit nunca é alterado). |
| `scripts/data/NatureBiomeProfiles.gd` | Dados ecológicos por bioma: cobertura, faixas de árvores de copa/jovens/arbustos/pedras, chance de tronco caído, peso de espécies, talhões de conífera, tintura de clima e faixa de escala. |
| `scripts/world/NatureComposer.gd` | Compositor puro e determinístico (seed do mapa + coordenada): devolve a lista de peças de um tile. |
| `scripts/world/NatureDecorManager.gd` | Desenho: MultiMesh por asset e região de 12×12 tiles, índice por tile para névoa, limpeza, foco visual e terreno alterado por magia. |

### Regras de composição

- **Bioma.** Floresta mista: carvalho e faia dominantes, com manchas de pinheiral. Taiga: pinheiral denso com muita regeneração de pinheiro jovem e verde frio. Selva: só folhosas, sub-bosque denso e muitos troncos caídos. Planície, estepe, savana, colina e tundra ganham vegetação esparsa (árvores isoladas, moitas, pedras), cada um com seu subconjunto e tom. Biomas onde o kit não pertence (neve, deserto, gelo, vulcânico, cristal, místico, montanha, água) não têm perfil e ficam sem vegetação.
- **Densidade regional.** Um ruído de baixa frequência forma bosques e campos abertos. Em floresta, abaixo de `CLEARING_DENSITY` o tile vira clareira: só sub-bosque e chão de mata.
- **Talhões de espécie.** Um segundo ruído agrupa as espécies (manchas de pinheiral ou de faial) em vez de sortear árvore por árvore.
- **Ecótono.** Um tile aberto vizinho de floresta ganha cobertura extra e árvores jovens do lado da mata. Um tile de floresta na borda rarefaz e recua as copas do lado aberto.
- **Ordem e espaçamento.** As peças entram em camadas: copa → jovens → borda → tronco → arbustos → pedras. Cada uma é colocada por amostragem de dardo dentro do círculo inscrito do hexágono, seguindo a regra do README (`distância + footprint × escala ≤ √3/2 − 0,02`). Há espaçamento entre copas e entre sub-bosque, e um vão central (0,24) para a unidade/ficha continuar legível. Cada tile tem no máximo 12 peças.
- **Relevo.** A altura de cada peça vem de `HexGrid.surface_height_at`, o mesmo perfil do shader: pico na montanha, topo plano em todos os outros tiles (`HexGrid.elevation_kind_for`).
- **Tiles sem vegetação.** Tile com recurso não recebe vegetação, para o prop do recurso continuar legível. Cidade, prédio, covil e unidade nascendo limpam a vegetação do tile (`clear_at`).
- **Terreno alterado por magia.** `refresh_tile` recompõe o tile com o terreno novo, chegando ao mesmo resultado que a geração daria.
- **Bosque Denso druídico.** Usa um anel de carvalhos jovens e aveleiras do kit.

Para ajustar a aparência, mexa nos dados de `NatureBiomeProfiles` antes de tocar no compositor. Testes: `test/unit/test_nature_composition.gd`. Custos medidos: `docs/PERFORMANCE_GUIDE.md`, seção 2.11.

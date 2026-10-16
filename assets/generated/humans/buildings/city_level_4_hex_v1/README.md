# Centro da Cidade — Nível IV / Hex V1

Evolução final do centro urbano: palácio de blocos com três coberturas azuis
em degraus, torre central mais larga e alta, coroas e frisos dourados e
bandeira no ponto mais alto. Criado pela conexão MCP do Blender ativo e
integrado em `City.CITY_MODELS_BY_LEVEL` para **Cidade IV**.

## Silhueta e composição

A Cidade III mantém sua identidade: entrada térrea, varanda, duas torres
frontais, telhado principal e pátio cívico continuam reconhecíveis.
O nível IV acrescenta coberturas íngremes sobre as torres laterais, amplia
a torre central em 18% na planta e 0,10 unidade na altura e eleva a torre
direita em 0,13. A bandeira passa à cobertura mais alta. Frisos dourados,
uma coroa na torre central e pequeno tapete de entrada completam a capital.

**Não contém muralhas ao redor da cidade.** A fundação pointy-top mantém
raio **0,84**, igual aos outros três níveis, dentro do tile de raio **1**.
O maior semiplano ocupado mede 0,72746, abaixo da face interna da fortificação
existente, 0,76706. A borda permanece livre para os modelos independentes
dos três níveis de Fortificação. As ameias pertencem às torres do castelo;
não concedem defesa ou escudo por conta própria.

## Família completa

| Nível | Silhueta | Altura | Triângulos |
| --- | --- | --- | --- |
| I | Castelo baixo com uma torre | 1,2150 | 1.496 |
| II | Salão de dois pisos e duas torres | 1,3150 | 2.088 |
| III | Torre central e varanda real | 1,7425 | 2.520 |
| IV | Três torres cobertas e acabamento dourado | 2,1850 | 2.944 |

Todos têm a mesma fundação e escala nativa. Os quatro níveis estão ligados
ao jogo; o visual procedural permanece apenas como fallback de carregamento.

## Integração e cores

Fundação, upgrade, captura e carregamento selecionam a fonte pelo City Level.
A instância escala uniformemente por `tile_radius`, sem normalização pela
altura. `City.gd` mede as malhas na reconstrução para posicionar nome, HP
e escudo acima da bandeira, preservando a distância entre os elementos.

A malha `Faction` contém tecidos, placas e tapete neutros. Seu material
é duplicado por cidade e recebe a cor do dono, preservando os atlases
compartilhados. Pedra, telhas, coroas, corrimão e frisos mantêm suas cores.
As prévias Blender mostram o tecido neutro; no jogo recebe a cor da civilização.
Fortificação, nomes e barras ficam fora do GLB.

## Arquivos e escala

- `city_level_4_hex_v1.blend`: **223 peças editáveis**, cena exclusiva,
  texturas empacotadas e estúdio. A fonte da Cidade III permanece preservada.
- `city_level_4_hex_v1.glb`: **2.944 triângulos**, 8 malhas por grupo,
  1 material fonte. O material de facção é duplicado na instância do jogo.
- Atlases albedo/emissão **2048 × 2048**, nearest, 128 px/unidade,
  3 pixels de margem, embutidos no GLB e salvos como PNGs.
- Dimensões: **1,4549 × 1,6800 × 2,1850**, largura × profundidade × altura.
- Origem no centro da base, chão Z=0 no Blender/Y=0 no Godot.
- Frente: −Y no Blender / +Z no Godot.

Prévias: [3/4](previews/three_quarter.png), [câmera elevada](previews/game_top.png),
[planta hexagonal](previews/top.png), [traseira](previews/back.png).

## Reprodução pela conexão MCP

Na raiz do projeto, com Blender e MCP ativos:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/city_level_4_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/city_level_4_hex_v1_finish.py
```

O construtor recusa sobrescrever uma cena existente. Duplica as malhas da
Cidade III aberta; se necessário, carrega sua cena do `.blend` salvo.
Pintura e exportação usam os helpers da família de construções.
Reimportar com Godot `--headless --path . --editor --import` após exportar.

## Verificação

Peças fechadas, shading flat, zero arestas não manifold. Exportação verifica
malhas, triângulos, nearest e hashes dos PNGs embutidos. No Godot, colocação
por `HexGrid.found_city` e upgrade III→IV conferem chão, escala, limites do
hex, cor do dono e espaço para fortificação: **zero vértices fora do tile**,
base no chão e folga interna confirmada.

**117 testes aprovados, 639 assertivas**, cobrindo cidade, City Level,
fortificação, seleção dos quatro modelos, captura, escala e altura da interface.
Uma execução de revisão visual compara Cidade III e Cidade IV lado a lado,
ambas sem fortificação. Cena temporária removida após a captura.
Resultados em `city_level_4_hex_v1_report.json`.

# Centro da Cidade — Nível III / Hex V1

Terceiro dos quatro níveis de centro urbano. Evolução da Cidade II com torre
central sobre o telhado, varanda real sobre a entrada e duas torres laterais
mais altas. Preserva pedra clara, telhados azuis em degraus, coroas douradas,
porta dupla e pátio cívico da família. Criado pela conexão MCP do Blender
ativo e integrado em `City.CITY_MODELS_BY_LEVEL` para **Cidade III**.

## Composição e fortificação

**Sem muralhas ao redor da cidade.** As ameias pertencem às torres do
castelo. A base pointy-top tem raio **0,84**, igual aos níveis I e II,
dentro do tile de raio **1**. O maior semiplano ocupado mede 0,72746,
abaixo da face interna da fortificação existente, 0,76706. A borda fica
livre para os modelos independentes dos três níveis de Fortificação.

O modelo aumenta a silhueta vertical sem ocupar tiles vizinhos. O salão
cresce 0,13 unidade, a torre esquerda cresce 0,16 e a direita cresce 0,30.
A torre central substitui o topo do telhado anterior, com janelas de pedra,
telhado próprio em degraus e pequeno acabamento dourado. A varanda tem
porta, apoios de pedra, balaústres de ferro, corrimão dourado e estandarte.
Porta térrea, degraus, água, banco, canteiros e fundação continuam reconhecíveis.

A expansão final já existe em `city_level_4_hex_v1`, completando os quatro
modelos. As torres decorativas não concedem defesa ou escudo.
O jogo desenha sua fortificação separada somente quando comprada.

## Integração e interface

Fundação, upgrade, captura e carregamento escolhem o modelo pelo nível.
A escala uniforme acompanha `tile_radius`, sem normalização pela altura.
`City.gd` mede os limites das malhas na reconstrução e posiciona nome,
HP e escudo acima do castelo, preservando a distância entre eles.
As malhas e a interface são atualizadas pelo mesmo caminho dos níveis I/II;
o upgrade preserva os nós de rótulo/barras e o estado da cidade.

A malha `Faction` contém placa, bandeira, estandarte da varanda e tecido
da torre direita. O material é duplicado por cidade e recebe a cor do dono,
preservando os atlases compartilhados. Pedra, telhas, coroas, hastes e
corrimão mantêm suas cores. As prévias Blender mostram tecidos neutros;
no jogo recebem a cor da civilização.

## Arquivos e escala

- `city_level_3_hex_v1.blend`: **193 peças editáveis**, cena exclusiva,
  texturas empacotadas e estúdio. A fonte da Cidade II permanece preservada.
- `city_level_3_hex_v1.glb`: **2.520 triângulos**, 8 malhas por grupo,
  1 material fonte. O material de facção é duplicado na instância do jogo.
- Atlases albedo/emissão **2048 × 2048**, nearest, 128 px/unidade,
  3 pixels de margem, embutidos no GLB e salvos como PNGs.
- Dimensões: **1,4549 × 1,6800 × 1,7425**, largura × profundidade × altura.
- Origem no centro da base, chão Z=0 no Blender/Y=0 no Godot.
- Frente: −Y no Blender / +Z no Godot.

Prévias: [3/4](previews/three_quarter.png), [câmera elevada](previews/game_top.png),
[planta hexagonal](previews/top.png), [traseira](previews/back.png).

## Reprodução pela conexão MCP

Na raiz do projeto, com Blender e MCP ativos:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/city_level_3_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/city_level_3_hex_v1_finish.py
```

O construtor recusa sobrescrever uma cena existente. Duplica as malhas da
Cidade II aberta; se necessário, carrega sua cena do `.blend` salvo.
Pintura e exportação usam os helpers da família de construções.
Reimportar com Godot `--headless --path . --editor --import` após exportar.

## Verificação

Peças fechadas, shading flat, zero arestas não manifold. Exportação verifica
malhas, triângulos, nearest e hashes dos PNGs embutidos. No Godot, colocação
real por `HexGrid.found_city` e upgrade para III conferem chão, escala,
limites do hex, cor do dono e espaço para fortificação: **zero vértices fora
do tile**, base no chão e folga interna confirmada.

**117 testes aprovados, 630 assertivas**, cobrindo cidade, City Level,
fortificação, escala, captura, transições de modelo e altura da interface.
Uma execução de revisão visual compara Cidade II e Cidade III lado a lado,
ambas sem fortificação. Cena temporária removida após a captura.
Resultados em `city_level_3_hex_v1_report.json`.

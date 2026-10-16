# Salão dos Guardiões — Hex V2

Peça de mapa **4X** desenhada para um **tile hexagonal pointy-top de raio 1**.
Geometria criada no Blender pelo MCP; substitui a versão retangular V1 no jogo.

## Composição

- Base de seis lados, com raio 0,92, alinhada ao hex do `HexMetrics`.
- Salão central hexagonal e telhado azul de seis lados em degraus.
- Duas torres baixas nas quinas frontais e uma torre na ponta traseira.
- Muralhas acompanhando as bordas diagonais do tile, com junções em meia-esquadria.
- Pátio de treino em cunha e acesso voltado para a ponta frontal.
- Escudo grande na fachada, dois manequins de escudo, suporte de lanças e bandeira.

As proporções são simbólicas para estratégia: as massas principais e o escudo
são grandes o suficiente para leitura pela câmera de cima. A arquitetura não
representa uma construção em escala humana literal.

## Integração

`BuildingDatabase` aponta `v2_building_guardian_hall` para
`guardian_hall_hex_v2.glb`, com `model_scale_multiplier = 1.0`.
A fonte já está na escala final do mapa; não normalizar por altura nem aplicar
a calibração do pacote KayKit.

Treina **Escudeiro → Guardião → Sentinela**. O Campeão Guardião continua sendo
treinado no seu próprio Bastião de Maestria.

## Entrega

| Arquivo | Conteúdo |
| --- | --- |
| `guardian_hall_hex_v2.blend` | Fonte editável, 150 peças e coleções por função. |
| `guardian_hall_hex_v2.glb` | 2.312 triângulos, 8 malhas, 1 material; texturas embutidas. |
| `guardian_hall_hex_v2_albedo.png` | Atlas pixelado 2048 × 2048, filtro nearest. |
| `guardian_hall_hex_v2_emission.png` | Emissão discreta das duas lanternas. |
| `guardian_hall_hex_v2_report.json` | Geometria, medidas e hashes das texturas embutidas. |
| `previews/three_quarter.png` | Composição geral. |
| `previews/game_top.png` | Vista de estratégia. |
| `previews/top.png` | Planta para conferir o encaixe no hex. |
| `previews/back.png` | Traseira. |

Dimensões nativas: **1,5935 × 1,84 × 1,4965** (largura × profundidade × altura).
Origem no chão, no centro do tile; frente −Y no Blender / +Z no Godot.
Flat shading, geometria fechada por peça, sem rig, animações ou colisão.

## Reprodução via MCP

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/guardian_hall_hex_v2_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/guardian_hall_hex_v2_finish.py
```

O construtor preserva V1 e outras cenas abertas; recusa sobrescrever uma cena
V2 existente. O finalizador pinta/exporta e resolve os IDs atuais também ao
reabrir o `.blend`. Para as quatro vistas, definir `VIEWS` na chamada ao MCP.

## Conferência

- Todos os vértices contidos nas seis meias-planícies do tile de raio 1.
- Export: 8 malhas, 1 material, 2.312 triângulos; PNGs embutidos conferidos por SHA-256.
- Colocação real por `HexGrid.place_building` e revisão não-headless com a
  iluminação do jogo, pitch de 50° e zoom mínimo de 6.
- Testes existentes de prédios e Salão dos Guardiões: 31/31 PASS.

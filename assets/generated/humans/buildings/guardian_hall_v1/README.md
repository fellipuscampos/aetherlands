# Salão dos Guardiões V1 — Aetherlands

**Versão anterior preservada como fonte.** Foi substituída no jogo pela
[Hex V2](../guardian_hall_hex_v2/README.md), projetada desde a planta para um tile hexagonal 4X.

Construção blocky/voxel para treinar **Escudeiro → Guardião → Sentinela**.
Corresponde ao prédio `v2_building_guardian_hall` existente no jogo. O **Campeão
Guardião** continua reservado ao Bastião de Maestria, seu prédio próprio.

Criado dentro do Blender 5.2.2 pelo MCP ativo em `localhost:9876`, com o cliente
do projeto. Geometria e texturas originais; nenhuma dependência de modelos externos.

## Desenho

- Salão de pedra com telhado azul em degraus e porta dupla reforçada com ferro.
- Escudo de madeira, aro de ferro, umbo quadrado e faixa azul, seguindo o escudeiro.
- Ala baixa de equipamentos e torre quadrada com ameias e bandeirola de escudo.
- Pátio aberto e portão largo, legíveis pela câmera de estratégia.
- Dois manequins para investida de escudo, suporte de escudos, suporte de lanças,
  seis marcações de formação, banco, caixas e quatro lanternas.
- Pedra em blocos, madeira e telhas com pintura pixelada; superfícies planas,
  sem suavização, bevel ou primitivas redondas.

## Arquivos

| Arquivo | Uso |
| --- | --- |
| `guardian_hall_v1.blend` | Fonte editável: 301 peças, separadas em coleções; texturas empacotadas; estúdio para revisão. |
| `guardian_hall_v1.glb` | Modelo estático para o motor, com 8 malhas por grupo arquitetônico e atlas embutidos. |
| `guardian_hall_v1_albedo.png` | Atlas de cor, 4096 × 4096. |
| `guardian_hall_v1_emission.png` | Atlas de emissão das lanternas, 4096 × 4096. |
| `guardian_hall_v1_report.json` | Medidas, geometria e validação da exportação. |
| `previews/three_quarter.png` | Vista principal. |
| `previews/game_top.png` | Vista de cima para estratégia. |
| `previews/front.png`, `side.png`, `back.png` | Revisão dos outros lados. |
| `previews/courtyard_detail.png` | Detalhe do pátio de treinamento. |
| `previews/scale_with_squire.png` | Escudeiro de 1,80 m no pátio, apenas para comparação. |

## Especificações e escala

| Item | Valor |
| --- | --- |
| Triângulos | 4.672 |
| Peças na fonte | 301 |
| Malhas no GLB | 8 |
| Materiais | 1 |
| Faces | Flat |
| Arestas não manifold | 0 |
| Texturas | Albedo + emissão, nearest, 64 px/m, padding de 3 px |
| Largura × profundidade × altura | 9,85 × 9,325 × 6,83 m, incluindo degraus e bandeirola |
| Origem | Centro da base, no chão |
| Frente | −Y no Blender / +Z no glTF e Godot |
| Rig / animações / colisão | Não incluídos |

A fonte usa metros reais e comporta os humanos de 1,80 m. No mapa estratégico,
`BuildingDatabase` define `model_scale_multiplier = 0.14`: largura 1,379 m,
profundidade 1,3055 m e altura 0,9562 m. A base e os degraus cabem no hex de raio 1.
O visual estratégico é uma miniatura; não copiar o multiplicador de unidades.

Esta V1 foi integrada inicialmente ao `v2_building_guardian_hall`, mas o
BuildingDatabase agora usa a Hex V2. O Bastião de Maestria continua separado.
O GLB exclui estúdio, luzes, câmera e escudeiro de referência. A fonte preserva
as peças separadas; só cópias temporárias são unidas para exportação.

## Validação

- Fonte: faces com área positiva, geometria fechada por peça e flat shading.
- GLB: 8 malhas, 1 material, 4.672 triângulos, samplers nearest; os PNGs
  embutidos foram comparados por SHA-256 com os atlas entregues.
- Godot 4.7.1: carregamento direto via `GLTFDocument`, 8 malhas, 4.672
  triângulos, atlas e filtro corretos, base no chão e dimensões conferidas.
  Sem câmeras, luzes, skeletons ou AnimationPlayers no export.
- Integração: colocação real via `HexGrid.place_building`, base na altura do tile,
  todos os vértices dentro do hex, texturas nearest e escala KayKit dos outros
  prédios preservada. Conferência visual não-headless no Godot com cena descartável.
- Testes existentes: `test_buildings.gd` e `test_v2_guardian_hall.gd`, 31/31 PASS.

## Reprodução pelo MCP

Na raiz do projeto, com o Blender e seu MCP em execução:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/guardian_hall_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/guardian_hall_paint_save.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/guardian_hall_previews.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/guardian_hall_scale_preview.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/guardian_hall_export.py
```

O primeiro script recusa reconstruir uma cena existente, preservando edições
manuais. Para reexportar ou renderizar a fonte salva, abra o `.blend` e rode só
os scripts de exportação/prévia; `guardian_hall_state.py` resolve os IDs atuais.

Verificação independente no motor:

```powershell
& 'C:\Users\felipe campos\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tools/art_pipeline/verify_guardian_hall_import.gd
```

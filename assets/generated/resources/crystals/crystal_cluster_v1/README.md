# Cristais de recurso — v1

Veia de ametista para o recurso `gems`, criada no Blender pelo servidor MCP
local. Segue as facetas planas e texturas pixeladas dos personagens e do kit
de natureza existentes.

- Sete cristais de seção quadrada, pontas piramidais e quatro blocos de
  rocha; 202 triângulos.
- Uma malha, uma superfície e um material opaco; atlas 256 × 256 embutido.
- Altura 0,76 e raio máximo 0,449 em um tile de raio 1; origem no chão.
- `.blend` editável com textura empacotada; `.glb` pronto para Godot, sem
  câmera, luz, armadura ou animação exportadas.

`ResourcePropsManager` carrega o GLB, aplica os transforms dos nós à malha
uma vez e conserva o material ao criar o MultiMesh. Continua usando o
sistema existente de névoa de guerra, foco visual, ajuste de altura e
remoção da decoração em tiles ocupados. O selo de gemas fica a 1,05 acima
da superfície, livre da ponta do cristal.

Prévia do modelo: `previews/three_quarter.png`. Prévia nos tiles do Godot:
`previews/godot_tiles.png`. Mapa gerado pelo jogo: `previews/in_game_map.png`.

Validações: `manifest.json`, `godot_validation.json` e `map_validation.json`.
O teste dos managers usa um grid mínimo; a prévia do mapa usa `HexGrid`
real, terreno e decoração do projeto, com seed 122026 e mapa 48 × 36.

Pipeline:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_crystal_resource_mcp.py
python tools/art_pipeline/validate_crystal_resource_godot.py
```

Revisão solicitada para a estética blocky:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/update_crystal_resource_blocky_mcp.py
```

A revisão original de seção hexagonal foi preservada em
`art_source/crystal_resource_review/original_hex_revision`.

A geração protege um GLB já existente. Para uma nova revisão, escolha um
novo nome e diretório. Nenhuma cena já aberta no Blender foi substituída.

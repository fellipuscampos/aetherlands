# Jazida de ferro — v1

Modelo do recurso `iron`, criado no Blender via MCP com a estética blocky
aprovada para os cristais e o nódulo arcano. Seis blocos de rocha escura,
grãos de ferro cinza expostos e veios de óxido pintados na textura.

- 216 triângulos; uma malha, uma superfície e um material.
- Atlas pixelado 256 × 256, embutido no GLB e empacotado no Blender.
- Altura 0,55; raio máximo 0,447; origem no chão, tile de raio 1.
- Sem câmera, luz, armadura ou animação no GLB.

`ResourcePropsManager` usa o GLB no MultiMesh existente, preservando o
material. Névoa de guerra, foco visual, altura do terreno e remoção em
tiles ocupados continuam no mesmo sistema. O ícone fica a 0,84 acima da
superfície, livre do topo da jazida. A geração dos recursos e seus
rendimentos não foram alterados.

Fonte editável: `iron_outcrop_v1.blend`. Modelo para Godot:
`iron_outcrop_v1.glb`. Textura: `iron_outcrop_v1_albedo.png`.
Prévias: `previews/three_quarter.png`, `previews/game_top.png`,
`previews/godot_tiles.png` e `previews/in_game_map.png`.

Validações: `manifest.json`, `godot_validation.json` e `map_validation.json`.
O teste dos managers usa um grid mínimo; a captura usa o `HexGrid` real,
terreno e vegetação do projeto, mapa 48 × 36, seed 122026.

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_iron_resource_mcp.py
python tools/art_pipeline/validate_crystal_resource_godot.py --resource iron
godot --path . res://tools/art_pipeline/preview_crystal_resource_map.tscn -- iron
```

A geração protege um GLB já existente e preserva as cenas abertas no
Blender. Para uma revisão, escolha outro nome e diretório.

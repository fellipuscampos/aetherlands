# Nódulo arcano — v1

Recurso `mana_node` modelado no Blender via MCP, seguindo a estética
blocky aprovada para os cristais. Núcleo ciano suspenso com seção quadrada
e pontas piramidais, três fragmentos menores e base de pedra em blocos
com veios arcanos pintados na textura.

- 124 triângulos; uma malha, uma superfície e um material.
- Atlas pixelado 256 × 256, embutido no GLB e empacotado no Blender.
- Altura 0,84; raio máximo 0,432; núcleo com ponta inferior a 0,25 do chão.
- Origem no chão e escala pronta para tiles de raio 1.
- Modelo estático; fragmentos suspensos fazem parte da mesma malha.

`ResourcePropsManager` aplica os transforms do GLB uma vez e conserva a
textura no MultiMesh. Mantém névoa de guerra, foco visual, ajuste de altura
do terreno e remoção em tiles ocupados. O ícone fica a 1,15 acima do chão.

Arquivos: `arcane_node_v1.blend`, `arcane_node_v1.glb` e
`arcane_node_v1_albedo.png`. O GLB não contém câmera, luz ou armadura.
Prévia do modelo em `previews/three_quarter.png`; prévia no mapa real em
`previews/in_game_map.png`.

Validações: `manifest.json`, `godot_validation.json` e `map_validation.json`.
O teste dos managers usa um grid mínimo e confere textura, três estados de
névoa, altura, remoção, reconstrução e folga do ícone. A captura do mapa
usa o `HexGrid` real com terreno e vegetação, mapa 48 × 36 e seed 122026.

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_arcane_node_resource_mcp.py
python tools/art_pipeline/validate_crystal_resource_godot.py --resource mana_node
```

A geração protege um GLB já existente e preserva as cenas abertas no
Blender. Para capturar novamente, execute a cena de revisão no Godot:

```powershell
godot --path . res://tools/art_pipeline/preview_crystal_resource_map.tscn -- mana_node
```

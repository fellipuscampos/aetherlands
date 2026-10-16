# Seda — amoreira v1

Modelo do recurso `silk`, criado no Blender via MCP. Amoreira compacta
com tronco e galhos em blocos, seis volumes de folhagem e sete casulos
claros. Os casulos têm corpo alongado e extremidades em degraus, seguindo
a estética blocky dos recursos já aprovados.

- 464 triângulos; uma malha, uma superfície e um material opaco.
- Atlas pixelado 256 × 256; textura de seda com pequenas faixas tecidas.
- Altura 0,68; raio máximo 0,396; origem no chão, tile de raio 1.
- Textura empacotada no `.blend` e embutida no `.glb`.
- GLB sem câmera, luz, armadura ou animação.

`ResourcePropsManager` conserva o atlas no MultiMesh existente. Mantém
névoa de guerra, foco visual, altura do terreno e remoção da decoração
em tiles ocupados. O ícone fica a 0,98 acima da superfície. Não altera a
distribuição de seda em florestas e selvas nem os rendimentos do recurso.

Fonte: `silk_mulberry_v1.blend`. Modelo: `silk_mulberry_v1.glb`. Textura:
`silk_mulberry_v1_albedo.png`. Prévias em `previews/three_quarter.png`,
`previews/game_top.png`, `previews/godot_tiles.png` e
`previews/in_game_map.png`.

Validações: `manifest.json`, `godot_validation.json` e `map_validation.json`.
O teste dos managers usa um grid mínimo e confere textura, três estados
de névoa, altura, remoção, reconstrução e folga do ícone. A captura usa o
`HexGrid` real, mapa 48 × 36, seed 122026, com terreno e vegetação.

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_silk_resource_mcp.py
python tools/art_pipeline/validate_crystal_resource_godot.py --resource silk
godot --path . res://tools/art_pipeline/preview_crystal_resource_map.tscn -- silk
```

A geração protege um GLB já existente e preserva as cenas abertas no
Blender. Para uma revisão, escolha outro nome e diretório.

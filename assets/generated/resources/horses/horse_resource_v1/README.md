# Cavalo de recurso — v1

Cavalo castanho reaproveitado do `cavalier_v1`, unidade Cavaleiro humano.
Adaptado no Blender via MCP a partir do `.blend` existente, copiando as
dezenove peças anatômicas e suas texturas. Preserva proporções, cabeça,
orelhas, crina, cauda, olhos, focinho, lista branca e meias das patas.

Removidos cavaleiro, sela, manta, estribos, rédeas, freio e cabresto
pintado. Os pixels da pelagem original foram copiados para um atlas menor;
somente os pixels das tiras do cabresto na cabeça foram preenchidos com
cores vizinhas. O modelo original da unidade não foi alterado.

- 228 triângulos; uma malha e um material no GLB.
- Fonte editável com dezenove peças; nenhum rig ou animação de unidade.
- Atlas 512 × 512 com nearest e margens para mipmaps.
- Escala de 35% aplicada na geometria; altura 0,710 e raio máximo 0,381.
- Origem centralizada no chão; quatro cascos assentados no tile.
- Ícone a 1,0 acima da superfície, livre das orelhas.

`ResourcePropsManager` instancia o novo GLB no caminho existente de
cavalos, preservando névoa de guerra, foco visual, atualização de altura e
remoção da decoração em tiles ocupados. A escala em runtime é 1,0 porque
o asset já está dimensionado para o mapa. A geração e os rendimentos do
recurso `horses` não foram alterados.

Fonte: `horse_resource_v1.blend`. Modelo: `horse_resource_v1.glb`.
Prévias em `previews/three_quarter.png`, `previews/side.png`,
`previews/godot_tiles.png` e `previews/in_game_map.png`.

`manifest.json` registra origem, hash SHA-256 do `.blend` original,
partes copiadas e escala. A geração verifica a cópia das coordenadas e a
preservação do arquivo original. `godot_validation.json` confere textura,
ausência de rig, escala, névoa, altura, remoção e ícone. A captura em
`map_validation.json` usa o `HexGrid` real, mapa 48 × 36 e seed 122026.

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/adapt_cavalier_horse_resource_mcp.py
python tools/art_pipeline/validate_crystal_resource_godot.py --resource horses
godot --path . res://tools/art_pipeline/preview_crystal_resource_map.tscn -- horses
```

O cavalo de recurso anterior permanece em `assets/generated/resources/horses/horses.glb`.
A geração protege o novo GLB e preserva as cenas abertas no Blender.

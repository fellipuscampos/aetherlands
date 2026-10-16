# Covis em runtime

Publicação dos 12 GLBs aprovados em `assets/generated/monster_lairs_v2/`.
Fontes Blender, imagens de revisão e scripts permanecem lá, sob `.gdignore`.
Esta pasta contém só os modelos usados por `LairStructure.gd` e as texturas extraídas pelo Godot.

Uma malha/material por espécie, geometria estática, origem no chão, frente +Z, raio máximo 0,78 m.
Escala em jogo: `HexGrid.hex_size`. Malhas/texturas são compartilhadas; a cor de névoa é por instância.
Texturas: BC7 (`compress/mode=2`, `compress/high_quality=true`), mipmaps e nearest.
Modelos não contêm câmera, luz, animação, colisão ou lógica de jogo.

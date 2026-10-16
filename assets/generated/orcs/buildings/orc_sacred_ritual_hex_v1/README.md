# Grande Catedral — Orcs

Estrutura de madeira grossa, postes cintados com ferro e contraventamentos diagonais; coberturas ferrugem, pedra escura na fundação e presas do clã.

Revisão de arquitetura de 2026-10-09 pelo **Blender MCP**. Mantém a função de treino, os equipamentos, o ID e o caminho usados pelo catálogo do jogo.

- Fonte `.blend` com peças editáveis e atlas empacotados.
- Exportação `.glb` com grupos arquitetônicos e dois atlas embutidos.
- Sem câmera, luz, rig ou animação na exportação.
- Origem no centro do tile, solo Z=0; frente −Y no Blender / +Z no Godot.
- 217 peças, 2688 triângulos, atlas 2048² e filtro nearest.

Prévias: [três quartos](previews/three_quarter.png), [mapa](previews/game_top.png), [topo](previews/top.png), [traseira](previews/back.png).

O relatório JSON lista alterações de geometria, conexões dos contraventamentos e limites do tile. Os arquivos anteriores estão preservados em `art_source/buildings_before_architecture_revision`.

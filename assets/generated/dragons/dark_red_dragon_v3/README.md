# Dragão vermelho escuro — V3

Dragão ocidental blocky, modelado no Blender via MCP seguindo a referência enviada.
Quatro patas, cabeça alongada, olhos vermelhos, chifres escuros, asas de membrana e
cauda longa em gancho. Textura de escamas em vermelho escuro e detalhes em osso.
Sem núcleo.

Esta reconstrução usa asas de geometria espelhada e articulações correspondentes;
as patas dobram no plano longitudinal, sem torção lateral. Crânio, focinho,
mandíbula e dentes são construídos em um referencial comum. A mandíbula abre a
partir de sua articulação, mantendo os dentes alinhados.

- `dark_red_dragon_v3.blend`: fonte editável, 141 peças e texturas empacotadas.
- `dark_red_dragon_v3.glb`: export com 1 malha, 1 material e 38 ossos preparados.
- `dark_red_dragon_v3_{albedo,emission}.png`: atlas 1024 × 1024, filtro nearest.
- `previews/`: vistas do Blender e Godot.
- `blender_validation.json` / `godot_validation.json`: verificações do arquivo.

Altura de 3 m entre as garras e o alto das asas, com folga de voo de 0,25 m.
Frente −Y no Blender / +Z no Godot. Ainda não há clipes de animação.
Asset independente: nenhuma unidade, regra ou modelo anterior do jogo é substituído.

Gerador: `tools/art_pipeline/build_dark_red_dragon_v3_mcp.py`.

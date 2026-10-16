# Dragão vermelho escuro

Modelo ocidental blocky feito no Blender via MCP, seguindo a referência enviada:
cabeça quadrada alongada e baixa, chifres grossos voltados para trás, quatro patas
dobradas, asas altas com borda superior articulada e cauda longa em gancho.
Escamas irregulares em vinho escuro, membranas
vermelhas escuras, dentes e garganta em osso envelhecido, olhos vermelho-alaranjados.

- `dark_red_dragon_v2.blend`: fonte editável, peças separadas, texturas empacotadas.
- `dark_red_dragon_v2.glb`: uma malha com rig preparado para animação.
- `dark_red_dragon_v2_{albedo,emission}.png`: atlas de pixel art, 1024 × 1024.
- `previews/`: vistas do Blender e conferência de importação no Godot.
- `dark_red_dragon_v2_report.json` / `godot_validation.json`: medidas e validação.

Altura nativa de 3 m entre as garras e a asa mais alta, com 0,25 m de folga para o
voo. Frente −Y no Blender / +Z no Godot. As asas, pescoço, mandíbula, patas e cauda
têm ossos próprios; ainda não há clipes de animação ou núcleo. Este asset é independente e
não altera o elemental serpentino, o wyvern ou regras do jogo.

Gerador: `tools/art_pipeline/build_dark_red_dragon_v2_mcp.py`.

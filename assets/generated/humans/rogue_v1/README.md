# Ladino humano

Criado sequencialmente pelo Blender MCP. Fonte editável: `rogue_v1.blend`; jogo: `rogue_v1.glb`.

Altura de referência: 1.8 m. Frente -Y no Blender / +Z no Godot. Origem no solo. Um material pixelado, filtro nearest, atlas albedo/emission embutidos.

Base copiada: warrior_v1. Animações: Rogue_Idle, Rogue_Walk, Rogue_Attack, Rogue_SneakAttack. Idle/Walk em loop; ações recuperam a pose inicial. Revisão de cada animação em `previews/animations` (MP4, GIF e folha de contato).

O script `rogue_v1_import.gd` marca loops no Godot. Ataque Furtivo está incluído. O clipe Desmantelar entra a partir do Sabotador.

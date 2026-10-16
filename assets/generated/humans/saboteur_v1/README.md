# Sabotador humano

Criado sequencialmente pelo Blender MCP. Fonte editável: `saboteur_v1.blend`; jogo: `saboteur_v1.glb`.

Altura de referência: 1.8 m. Frente -Y no Blender / +Z no Godot. Origem no solo. Um material pixelado, filtro nearest, atlas albedo/emission embutidos.

Base copiada: rogue_v1. Animações: Saboteur_Idle, Saboteur_Walk, Saboteur_Attack, Saboteur_SneakAttack, Saboteur_Dismantle. Idle/Walk em loop; ações recuperam a pose inicial. Revisão de cada animação em `previews/animations` (MP4, GIF e folha de contato).

O script `saboteur_v1_import.gd` marca loops no Godot. Desmantelar é entregue como animação; permanece passiva conforme as regras existentes.

# Assassino humano

Criado sequencialmente pelo Blender MCP. Fonte editável: `assassin_v1.blend`; jogo: `assassin_v1.glb`.

Altura de referência: 1.8 m. Frente -Y no Blender / +Z no Godot. Origem no solo. Um material pixelado, filtro nearest, atlas albedo/emission embutidos.

Base copiada: saboteur_v1. Animações: Assassin_Idle, Assassin_Walk, Assassin_Attack, Assassin_SneakAttack, Assassin_Dismantle. Idle/Walk em loop; ações recuperam a pose inicial. Revisão de cada animação em `previews/animations` (MP4, GIF e folha de contato).

O script `assassin_v1_import.gd` marca loops no Godot. Desmantelar é entregue como animação; permanece passiva conforme as regras existentes.

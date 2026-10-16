# Bombarda humano

Criado sequencialmente pelo Blender MCP. Fonte editável: `bombard_v1.blend`; jogo: `bombard_v1.glb`.

Altura de referência: 1.8 m. Frente -Y no Blender / +Z no Godot. Origem no solo. Um material pixelado, filtro nearest, atlas albedo/emission embutidos.

Base copiada: trebuchet_v1. Animações: Bombard_Idle, Bombard_Walk, Bombard_Attack, Bombard_DemolitionAmmo, Bombard_PreparedBombardment. Idle/Walk em loop; ações recuperam a pose inicial. Revisão de cada animação em `previews/animations` (MP4, GIF e folha de contato).

O script `bombard_v1_import.gd` marca loops no Godot. Munição Demolidora é entregue como animação; permanece passiva conforme as regras existentes.

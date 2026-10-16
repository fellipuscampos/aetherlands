# Trebuchet humano

Criado sequencialmente pelo Blender MCP. Fonte editável: `trebuchet_v1.blend`; jogo: `trebuchet_v1.glb`.

Altura de referência: 1.8 m. Frente -Y no Blender / +Z no Godot. Origem no solo. Um material pixelado, filtro nearest, atlas albedo/emission embutidos.

Base copiada: catapult_v1. Animações: Trebuchet_Idle, Trebuchet_Walk, Trebuchet_Attack, Trebuchet_DemolitionAmmo, Trebuchet_PreparedBombardment. Idle/Walk em loop; ações recuperam a pose inicial. Revisão de cada animação em `previews/animations` (MP4, GIF e folha de contato).

O script `trebuchet_v1_import.gd` marca loops no Godot. Munição Demolidora é entregue como animação; permanece passiva conforme as regras existentes.

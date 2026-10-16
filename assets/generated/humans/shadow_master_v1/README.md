# Mestre das Sombras humano

Criado sequencialmente pelo Blender MCP. Fonte editável: `shadow_master_v1.blend`; jogo: `shadow_master_v1.glb`.

Altura de referência: 2.0 m. Frente -Y no Blender / +Z no Godot. Origem no solo. Um material pixelado, filtro nearest, atlas albedo/emission embutidos.

Base copiada: assassin_v1. Animações: ShadowMaster_Idle, ShadowMaster_Walk, ShadowMaster_Attack, ShadowMaster_SneakAttack, ShadowMaster_Dismantle. Idle/Walk em loop; ações recuperam a pose inicial. Revisão de cada animação em `previews/animations` (MP4, GIF e folha de contato).

O script `shadow_master_v1_import.gd` marca loops no Godot. Desmantelar é entregue como animação; permanece passiva conforme as regras existentes.

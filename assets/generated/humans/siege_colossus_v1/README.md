# Colosso de Cerco humano

Criado sequencialmente pelo Blender MCP. Fonte editável: `siege_colossus_v1.blend`; jogo: `siege_colossus_v1.glb`.

Altura de referência: 2.0 m. Frente -Y no Blender / +Z no Godot. Origem no solo. Um material pixelado, filtro nearest, atlas albedo/emission embutidos.

Base copiada: bombard_v1. Animações: SiegeColossus_Idle, SiegeColossus_Walk, SiegeColossus_Attack, SiegeColossus_DemolitionAmmo, SiegeColossus_PreparedBombardment. Idle/Walk em loop; ações recuperam a pose inicial. Revisão de cada animação em `previews/animations` (MP4, GIF e folha de contato).

O script `siege_colossus_v1_import.gd` marca loops no Godot. Munição Demolidora é entregue como animação; permanece passiva conforme as regras existentes.

Visual revisado: grande bombarda de cano único e oco, carro de carvalho com laterais inclinadas, seis rodas com raios, ferragens, guincho manual e placas azuis da civilização humana. Dourado discreto nos detalhes lendários. Altura de 2 m até a estrutura de madeira. Apoios laterais do canhão e trilho de recuo mantêm o interior do cano livre.

Os dez ossos e as curvas dos cinco clipes anteriores foram preservados. Backup da versão substituída: `art_source/siege_colossus_before_redesign_v1/asset`. Validação: `docs/siege_colossus_redesign_validation.json`.

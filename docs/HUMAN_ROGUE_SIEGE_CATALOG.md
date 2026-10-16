# Tropas humanas — Ladino e Cerco

Produção pelo Blender MCP, concluindo e salvando cada unidade antes da seguinte. Somente arte humana. Fontes anteriores preservadas por SHA-256.

![As oito tropas humanas](previews/human_rogue_siege/overview.png)

| Unidade | Altura | Triângulos | Clipes | Arquivos |
|---|---:|---:|---:|---|
| Ladino | 1,8 m | 288 | 4 | [GLB](../assets/generated/humans/rogue_v1/rogue_v1.glb) · [Blender](../assets/generated/humans/rogue_v1/rogue_v1.blend) · [Prévia](../assets/generated/humans/rogue_v1/previews/threequarter.png) |
| Sabotador | 1,8 m | 360 | 5 | [GLB](../assets/generated/humans/saboteur_v1/saboteur_v1.glb) · [Blender](../assets/generated/humans/saboteur_v1/saboteur_v1.blend) · [Prévia](../assets/generated/humans/saboteur_v1/previews/threequarter.png) |
| Assassino | 1,8 m | 432 | 5 | [GLB](../assets/generated/humans/assassin_v1/assassin_v1.glb) · [Blender](../assets/generated/humans/assassin_v1/assassin_v1.blend) · [Prévia](../assets/generated/humans/assassin_v1/previews/threequarter.png) |
| Mestre das Sombras | 2,0 m | 456 | 5 | [GLB](../assets/generated/humans/shadow_master_v1/shadow_master_v1.glb) · [Blender](../assets/generated/humans/shadow_master_v1/shadow_master_v1.blend) · [Prévia](../assets/generated/humans/shadow_master_v1/previews/threequarter.png) |
| Catapulta | 1,8 m | 580 | 4 | [GLB](../assets/generated/humans/catapult_v1/catapult_v1.glb) · [Blender](../assets/generated/humans/catapult_v1/catapult_v1.blend) · [Prévia](../assets/generated/humans/catapult_v1/previews/threequarter.png) |
| Trebuchet | 1,8 m | 624 | 5 | [GLB](../assets/generated/humans/trebuchet_v1/trebuchet_v1.glb) · [Blender](../assets/generated/humans/trebuchet_v1/trebuchet_v1.blend) · [Prévia](../assets/generated/humans/trebuchet_v1/previews/threequarter.png) |
| Bombarda | 1,8 m | 756 | 5 | [GLB](../assets/generated/humans/bombard_v1/bombard_v1.glb) · [Blender](../assets/generated/humans/bombard_v1/bombard_v1.blend) · [Prévia](../assets/generated/humans/bombard_v1/previews/threequarter.png) |
| Colosso de Cerco | 2,0 m | 3644 | 5 | [GLB](../assets/generated/humans/siege_colossus_v1/siege_colossus_v1.glb) · [Blender](../assets/generated/humans/siege_colossus_v1/siege_colossus_v1.blend) · [Prévia](../assets/generated/humans/siege_colossus_v1/previews/threequarter.png) |

## Derivação e acabamento

Guerreiro aprovado → Ladino → Sabotador → Assassino → Mestre das Sombras. A geometria real do antecessor foi copiada, preservando os blocos do corpo e suas juntas. Capuz e máscara são pintados no único bloco da cabeça. A evolução acrescenta bolsa e ferramentas, segunda adaga, proteção de ombro e capa dividida; o lendário tem capa longa com acabamento dourado. Os três comuns têm 1,80 m de corpo; o lendário tem 2,00 m.

Catapulta → Trebuchet → Bombarda → Colosso de Cerco. O chassi foi copiado e os mecanismos evoluem: braço de torção; pórtico com contrapeso pendente e funda; canhão oco com recuo; grande bombarda de cano único, carro de carvalho com laterais inclinadas, seis rodas com raios e guincho manual. Máquinas sem tripulação visível. Altura de repouso: 1,80 m para as comuns e 2,00 m para o Colosso. No Colosso, a altura vem da estrutura de madeira. Madeira, ferro e azul humano; dourado adicional no lendário.

Capas presas ao torso, selos presos ao cinto, eixos sustentados por mancais, bandeiras com suportes ligados ao chassi e mastros laterais fora do caminho do braço de lançamento. Rodas do Colosso têm espaçamento próprio.

O Colosso recebeu uma revisão visual completa, preservando o chassi, o rig e as curvas dos cinco clipes. Apoios laterais e trilho de recuo deixam o interior do canhão livre. A revisão passou na importação Godot, na inspeção de geometria e nos dois testes de reprodução das tropas (77 assertivas). [Relatório da revisão](siege_colossus_redesign_validation.json).

## Animações cumulativas

| Linha | Todas as unidades | A partir da primeira evolução |
|---|---|---|
| Ladino | Idle, Walk, Attack, SneakAttack | Dismantle (Sabotador, Assassino, Mestre das Sombras) |
| Cerco | Idle, Walk, Attack, DemolitionAmmo | PreparedBombardment (Trebuchet, Bombarda, Colosso) |

Os quatro ladinos usam o mesmo rig rígido de 16 ossos. As curvas de todos os clipes herdados são cópias exatas, verificadas por SHA-256; a altura lendária fica somente no ROOT. No cerco, os papéis dos clipes são herdados e os movimentos se adaptam ao mecanismo (lançamento ou recuo). Todos os clipes são amostrados a 24 fps, Idle/Walk repetem, ações recuperam a postura inicial e têm marcador de impacto. GIF/MP4 de revisão em 12 fps.

Revisão 3D: abra [_human_rogue_siege_review.tscn](../_human_rogue_siege_review.tscn) no Godot e pressione F6. Teclas 1–5 selecionam parado, andar, ataque, técnica inicial e técnica avançada; Q/E giram a câmera.

## Animações para revisão

### Ladino

| Ação | Revisão |
|---|---|
| Idle | [GIF](../assets/generated/humans/rogue_v1/previews/animations/Rogue_Idle.gif) · [MP4](../assets/generated/humans/rogue_v1/previews/animations/Rogue_Idle.mp4) · [Contato](../assets/generated/humans/rogue_v1/previews/animations/Rogue_Idle_contact.png) |
| Walk | [GIF](../assets/generated/humans/rogue_v1/previews/animations/Rogue_Walk.gif) · [MP4](../assets/generated/humans/rogue_v1/previews/animations/Rogue_Walk.mp4) · [Contato](../assets/generated/humans/rogue_v1/previews/animations/Rogue_Walk_contact.png) |
| Attack | [GIF](../assets/generated/humans/rogue_v1/previews/animations/Rogue_Attack.gif) · [MP4](../assets/generated/humans/rogue_v1/previews/animations/Rogue_Attack.mp4) · [Contato](../assets/generated/humans/rogue_v1/previews/animations/Rogue_Attack_contact.png) |
| SneakAttack | [GIF](../assets/generated/humans/rogue_v1/previews/animations/Rogue_SneakAttack.gif) · [MP4](../assets/generated/humans/rogue_v1/previews/animations/Rogue_SneakAttack.mp4) · [Contato](../assets/generated/humans/rogue_v1/previews/animations/Rogue_SneakAttack_contact.png) |

### Sabotador

| Ação | Revisão |
|---|---|
| Idle | [GIF](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Idle.gif) · [MP4](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Idle.mp4) · [Contato](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Idle_contact.png) |
| Walk | [GIF](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Walk.gif) · [MP4](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Walk.mp4) · [Contato](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Walk_contact.png) |
| Attack | [GIF](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Attack.gif) · [MP4](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Attack.mp4) · [Contato](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Attack_contact.png) |
| SneakAttack | [GIF](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_SneakAttack.gif) · [MP4](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_SneakAttack.mp4) · [Contato](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_SneakAttack_contact.png) |
| Dismantle | [GIF](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Dismantle.gif) · [MP4](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Dismantle.mp4) · [Contato](../assets/generated/humans/saboteur_v1/previews/animations/Saboteur_Dismantle_contact.png) |

### Assassino

| Ação | Revisão |
|---|---|
| Idle | [GIF](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Idle.gif) · [MP4](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Idle.mp4) · [Contato](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Idle_contact.png) |
| Walk | [GIF](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Walk.gif) · [MP4](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Walk.mp4) · [Contato](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Walk_contact.png) |
| Attack | [GIF](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Attack.gif) · [MP4](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Attack.mp4) · [Contato](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Attack_contact.png) |
| SneakAttack | [GIF](../assets/generated/humans/assassin_v1/previews/animations/Assassin_SneakAttack.gif) · [MP4](../assets/generated/humans/assassin_v1/previews/animations/Assassin_SneakAttack.mp4) · [Contato](../assets/generated/humans/assassin_v1/previews/animations/Assassin_SneakAttack_contact.png) |
| Dismantle | [GIF](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Dismantle.gif) · [MP4](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Dismantle.mp4) · [Contato](../assets/generated/humans/assassin_v1/previews/animations/Assassin_Dismantle_contact.png) |

### Mestre das Sombras

| Ação | Revisão |
|---|---|
| Idle | [GIF](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Idle.gif) · [MP4](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Idle.mp4) · [Contato](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Idle_contact.png) |
| Walk | [GIF](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Walk.gif) · [MP4](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Walk.mp4) · [Contato](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Walk_contact.png) |
| Attack | [GIF](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Attack.gif) · [MP4](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Attack.mp4) · [Contato](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Attack_contact.png) |
| SneakAttack | [GIF](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_SneakAttack.gif) · [MP4](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_SneakAttack.mp4) · [Contato](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_SneakAttack_contact.png) |
| Dismantle | [GIF](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Dismantle.gif) · [MP4](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Dismantle.mp4) · [Contato](../assets/generated/humans/shadow_master_v1/previews/animations/ShadowMaster_Dismantle_contact.png) |

### Catapulta

| Ação | Revisão |
|---|---|
| Idle | [GIF](../assets/generated/humans/catapult_v1/previews/animations/Catapult_Idle.gif) · [MP4](../assets/generated/humans/catapult_v1/previews/animations/Catapult_Idle.mp4) · [Contato](../assets/generated/humans/catapult_v1/previews/animations/Catapult_Idle_contact.png) |
| Walk | [GIF](../assets/generated/humans/catapult_v1/previews/animations/Catapult_Walk.gif) · [MP4](../assets/generated/humans/catapult_v1/previews/animations/Catapult_Walk.mp4) · [Contato](../assets/generated/humans/catapult_v1/previews/animations/Catapult_Walk_contact.png) |
| Attack | [GIF](../assets/generated/humans/catapult_v1/previews/animations/Catapult_Attack.gif) · [MP4](../assets/generated/humans/catapult_v1/previews/animations/Catapult_Attack.mp4) · [Contato](../assets/generated/humans/catapult_v1/previews/animations/Catapult_Attack_contact.png) |
| DemolitionAmmo | [GIF](../assets/generated/humans/catapult_v1/previews/animations/Catapult_DemolitionAmmo.gif) · [MP4](../assets/generated/humans/catapult_v1/previews/animations/Catapult_DemolitionAmmo.mp4) · [Contato](../assets/generated/humans/catapult_v1/previews/animations/Catapult_DemolitionAmmo_contact.png) |

### Trebuchet

| Ação | Revisão |
|---|---|
| Idle | [GIF](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_Idle.gif) · [MP4](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_Idle.mp4) · [Contato](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_Idle_contact.png) |
| Walk | [GIF](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_Walk.gif) · [MP4](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_Walk.mp4) · [Contato](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_Walk_contact.png) |
| Attack | [GIF](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_Attack.gif) · [MP4](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_Attack.mp4) · [Contato](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_Attack_contact.png) |
| DemolitionAmmo | [GIF](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_DemolitionAmmo.gif) · [MP4](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_DemolitionAmmo.mp4) · [Contato](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_DemolitionAmmo_contact.png) |
| PreparedBombardment | [GIF](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_PreparedBombardment.gif) · [MP4](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_PreparedBombardment.mp4) · [Contato](../assets/generated/humans/trebuchet_v1/previews/animations/Trebuchet_PreparedBombardment_contact.png) |

### Bombarda

| Ação | Revisão |
|---|---|
| Idle | [GIF](../assets/generated/humans/bombard_v1/previews/animations/Bombard_Idle.gif) · [MP4](../assets/generated/humans/bombard_v1/previews/animations/Bombard_Idle.mp4) · [Contato](../assets/generated/humans/bombard_v1/previews/animations/Bombard_Idle_contact.png) |
| Walk | [GIF](../assets/generated/humans/bombard_v1/previews/animations/Bombard_Walk.gif) · [MP4](../assets/generated/humans/bombard_v1/previews/animations/Bombard_Walk.mp4) · [Contato](../assets/generated/humans/bombard_v1/previews/animations/Bombard_Walk_contact.png) |
| Attack | [GIF](../assets/generated/humans/bombard_v1/previews/animations/Bombard_Attack.gif) · [MP4](../assets/generated/humans/bombard_v1/previews/animations/Bombard_Attack.mp4) · [Contato](../assets/generated/humans/bombard_v1/previews/animations/Bombard_Attack_contact.png) |
| DemolitionAmmo | [GIF](../assets/generated/humans/bombard_v1/previews/animations/Bombard_DemolitionAmmo.gif) · [MP4](../assets/generated/humans/bombard_v1/previews/animations/Bombard_DemolitionAmmo.mp4) · [Contato](../assets/generated/humans/bombard_v1/previews/animations/Bombard_DemolitionAmmo_contact.png) |
| PreparedBombardment | [GIF](../assets/generated/humans/bombard_v1/previews/animations/Bombard_PreparedBombardment.gif) · [MP4](../assets/generated/humans/bombard_v1/previews/animations/Bombard_PreparedBombardment.mp4) · [Contato](../assets/generated/humans/bombard_v1/previews/animations/Bombard_PreparedBombardment_contact.png) |

### Colosso de Cerco

| Ação | Revisão |
|---|---|
| Idle | [GIF](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_Idle.gif) · [MP4](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_Idle.mp4) · [Contato](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_Idle_contact.png) |
| Walk | [GIF](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_Walk.gif) · [MP4](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_Walk.mp4) · [Contato](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_Walk_contact.png) |
| Attack | [GIF](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_Attack.gif) · [MP4](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_Attack.mp4) · [Contato](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_Attack_contact.png) |
| DemolitionAmmo | [GIF](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_DemolitionAmmo.gif) · [MP4](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_DemolitionAmmo.mp4) · [Contato](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_DemolitionAmmo_contact.png) |
| PreparedBombardment | [GIF](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_PreparedBombardment.gif) · [MP4](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_PreparedBombardment.mp4) · [Contato](../assets/generated/humans/siege_colossus_v1/previews/animations/SiegeColossus_PreparedBombardment_contact.png) |

## Uso no Godot

Cada GLB tem uma malha, um material e um esqueleto; atlas albedo/emission embutidos e filtro nearest. Frente +Z, origem no solo, escala nativa 1:1. Fonte Blender isolada e editável, com peças separadas e os mesmos clipes. O script de pós-importação de cada modelo configura os loops.

UnitDatabase usa os novos caminhos e o helper existente das tropas humanas, com crossfade de 0,2 s e mapeamento de técnicas. Não há mudanças nos atributos ou regras de combate. Desmantelar e Munição Demolidora permanecem passivas no jogo; os respectivos clipes estão entregues para uso visual e revisão. Ataque Furtivo e Bombardeio Preparado usam os clipes pelo fluxo existente das técnicas.

Validações: [importação Godot](human_rogue_siege_godot_validation.json), [geometria e suportes](human_rogue_siege_geometry_validation.json), [reprodução no jogo](human_rogue_siege_runtime_validation.json), [fontes anteriores](human_rogue_siege_source_baseline.json). Os 10 testes das duas suítes de tropas passaram, com 260 assertivas. Teste do playback real em Unit: test/unit/test_v2_human_rogue_siege_models.gd.

Pipeline: tools/art_pipeline/human_rogue_siege_live.py e run_human_rogue_siege.py; somente MCP do Blender para modelagem, animação, render e exportação.

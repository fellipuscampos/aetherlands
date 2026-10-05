# Troll Blocky V3 — refinamento final

Asset original de Aetherlands, criado e refinado no Blender 5.2.2 via MCP localhost:9876. Construção por cubos/prismas, Shade Flat, sem bevel ou subdivisão.

## Correções

- Cabeça apoiada no corpo, sem malha de pescoço visível.
- Orelhas com bases largas embutidas na lateral da cabeça.
- Presas contínuas saindo da linha da boca, sem blocos soltos.
- Mãos sem dedos pintados; punho direito com canal real alinhado ao cabo.
- Couro frontal preso sob o cinto, afastado das coxas e com barra recortada.
- Dois ossos simples articulam couro frontal/traseiro nas animações.
- Contato mandíbula/cabeça corrigido para evitar faces coplanares.

## Arquivos

- troll_blocky_v3.glb: rig, duas malhas com skin, textura embutida e três clips.
- troll_blocky_v3_atlas.png: textura pixel art única, 512×512.
- troll_blocky_v3_report.json: medições e auditoria de todos os frames.
- troll_blocky_v3.glb.import / troll_blocky_import.gd: importação Godot a 24 fps, Idle/Walk em loop e Attack sem loop.
- previews/{front,three_quarter,side,back}.png: vistas neutras, 1000×1000.
- previews/pose_test.png: preparação do ataque.
- previews/animations/Troll_{Idle,Walk,Attack}.{mp4,gif}: previews 640×640.
- Fontes na raiz do projeto: art_source/troll_blocky_v3/troll_blocky_v3.blend e troll_blocky_v3.fbx.

## UV e textura

340 ilhas únicas sem sobreposição, com dois pixels de margem dilatada. Cada face recebe projeção ortonormal a **64 pixels por metro**, preservando a proporção real. A pintura foi desenhada nas dimensões de cada face, sem esticar painéis quadrados para preencher retângulos.

Medição de todas as arestas: **63,998699–64,001079 px/m**, erro relativo máximo **0,0021%** (precisão numérica). Escala igual nos dois eixos e filtro nearest. O atlas 512×512 acomoda todas as ilhas nessa densidade.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 716: corpo 644, arma 72 |
| Vértices de modelagem | 460; export duplica vértices nas costuras UV/normais |
| Malhas / materiais | 2 malhas, 1 material |
| Altura / pivot | 2,50 m; base no chão; origem (0,0,0) |
| Ossos | 24, incluindo arma e duas peças de couro |
| Skinning | Rígido por bloco, pesos normalizados |
| Rig exportado | FK; pés resolvidos e gravados, sem dependência de IK |

O osso interno neck permanece na hierarquia; não existe malha de pescoço. weapon acompanha hand_r. O arquivo abre no início de Idle, em postura neutra.

## Animações

| Action / clip | Frames locais a 24 fps | Duração | Loop | NLA |
| --- | --- | --- | --- | --- |
| Troll_Idle | 1–49 | 2,00 s | Sim | 1–49 |
| Troll_Walk | 1–29 | 1,1667 s | Sim | 61–89 |
| Troll_Attack | 1–37 | 1,50 s | Não | 101–137 |

Loops incluem um último frame igual ao primeiro; os vídeos não repetem esse frame na emenda. Idle tem respiração e movimentos secundários sutis. Walk é uma caminhada pesada **no lugar**, com 60% de apoio e pés controlados no chão. Velocidade de deslocamento sugerida ao controlador: **0,486 m/s**.

Ataque: preparação até frame 13, suspensão até 17, **impacto em 21**, continuação do golpe em 24 e recuperação até 37. O instante de impacto no clip exportado é **0,8333 s**.

Os nomes são idênticos nas actions, tracks NLA, GLB e AnimationStacks do FBX. glTF não codifica loop como propriedade padrão; o script de importação fornecido aplica os loops no Godot sem renomear clips.

## Validação

- Geometria fechada, faces com área positiva, normais flat e pesos normalizados.
- 115 frames conferidos: coordenadas finitas e arestas rígidas preservadas.
- Emendas de Idle/Walk com deslocamento máximo de vértice igual a zero.
- Erro dos alvos dos pés abaixo de 0,000001 m; sem penetração material no chão.
- Nenhuma interseção entre couro frontal/traseiro e coxas nos 115 frames.
- Fonte blend isolada: uma cena final e exatamente três actions.
- Godot 4.7.1 em projeto isolado: 24 ossos, duas malhas com skin, altura 2,5000002 m, textura 512×512 nearest, três clips com durações e loops corretos.
- FBX 7400 conferido: Troll_Idle, Troll_Walk e Troll_Attack.

## Integração

Usar res://assets/generated/trolls/troll_blocky_v3/troll_blocky_v3.glb, escala 1,0. Frente: -Y no Blender / +Z no glTF. Ajustar yaw conforme o controlador existente. Conservar os arquivos de importação fornecidos para os loops.

Asset pronto para integração com Idle/Walk/Attack. Integrado ao jogo em 2026-10-03 (`MonsterDatabase.gd`, kind "troll"), yaw 0 e crossfade entre clipes. Death e outros clips não solicitados não estão incluídos.

## Fontes e reprodução

art_source/troll_blocky_v3/history_before_refinement/ preserva a versão anterior. O blockout aprovado está em troll_blocky_v3_blockout.blend. Na mesma sessão MCP, os scripts em tools/art_pipeline executam nesta ordem:

1. troll_refine_geometry_uv.py — cena aprovada e blockout salvo.
2. troll_refine_paint.py — pintura e medição das UVs.
3. troll_refine_animate.py — rig e três actions/NLA.
4. troll_refine_validate.py — auditoria completa.
5. troll_refine_export.py — fonte isolada, GLB e FBX.
6. troll_refine_stills.py / troll_refine_animation_previews.py — renders Blender.
7. encode_troll_previews.py — codifica PNGs já renderizados em MP4/GIF.

Executar scripts Blender por python tools/art_pipeline/blender_mcp_client.py <script>. Eles recusam sobrescrever uma cena/rig refinado existente para preservar edições manuais. art_source é excluída da importação de recursos Godot.


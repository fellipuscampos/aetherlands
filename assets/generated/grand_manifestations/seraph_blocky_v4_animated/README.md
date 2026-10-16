# Serafim — quatro animações

Modelo e textura da V4 preservados, com 36 peças editáveis, 2.072 triângulos, 1 malha, 1 material e 11 ossos. Frente: Blender -Y / Godot +Z. Altura da pose de referência: 3,00 m.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
| Idle | 24 s | Sim | Flutuação suave, movimento contido das asas e giro lento do núcleo e das auréolas. |
| Walk | 8 s | Sim | Voo no lugar, inclinação para a frente e batidas suaves das asas. |
| Attack | 1,5 s | Não | Preparação, impulso frontal do núcleo e recuperação. Impacto aos 0,625 s. |
| Spell | 3 s | Não | Abertura das asas, alinhamento frontal da auréola externa e pulsos de energia sagrada. Conjuração aos 1,375 s. |

- `seraph_blocky_v4_animated.glb`: os quatro clipes no AnimationPlayer, com texturas embutidas e filtro NEAREST.
- `seraph_blocky_v4_animated.blend`: cena isolada com quatro ações e faixas NLA separadas. Peças articuladas rigidamente; núcleo com pulsos de escala uniforme.
- `seraph_animation_import.gd`: marca Idle/Walk como loop e Attack/Spell como execução única. A importação mantém os canais constantes, permitindo interromper Spell e retornar ao Idle sem deixar escala ou asas na pose anterior.
- A raiz permanece fixa em todos os clipes. O jogo controla o deslocamento de Walk.
- `animation_report.json`: 1.756 poses e meios de quadro conferidos no Blender; asas sem cruzamentos, peças separadas e sem contato com o chão.
- `godot_validation.json`: 880 poses verificadas no Godot, inclusive repetição, rigidez e transição de Spell para Idle. Todas as prévias usam o GLB importado no Godot.
- Revisão: `scenes/art_review/SeraphAnimationReview.tscn` (F6; 1–4 para escolher, setas para girar, espaço para pausar e R para repetir).

Integrado em `UnitDatabase` como `v2_manifestation_seraph`, compartilhado entre humanos, elfos, orcs e anões, na escala nativa de 3 metros. O controlador da unidade aciona Idle, Walk e Spell, com transição por captura de pose de 0,5 s (`PoseCaptureTransition.gd`, desde 2026-10-13; antes um crossfade linear de 0,2 s) e retorno automático após conjurar. Attack está disponível, mantendo a regra atual de não ter ataque básico. O AnimationPlayer original não inicia sozinho, evitando dois controladores sobre os mesmos ossos.

`game_integration_validation.json`: 39 testes passaram, com 705 verificações, incluindo movimento, conjuração, produção, efeitos sagrados, IA e save/load.

O modelo estático da V4 e as versões anteriores continuam preservados. As regras de cura, combate, produção e deslocamento permanecem as mesmas.

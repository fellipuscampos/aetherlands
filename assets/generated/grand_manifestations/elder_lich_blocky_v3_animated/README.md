# Lich Ancião — quatro animações

Modelo aprovado V2, mantendo o crânio do esqueleto atual, as vestes roxas, o cajado, o grimório e o corpo espectral. Altura de referência: 3 m. Frente Blender -Y / Godot +Z.

79 peças editáveis, 1548 triângulos, 1 malha exportada, 1 material, 37 ossos e atlas de 512 px com filtro NEAREST. Texturas e superfícies rígidas da V2 preservadas. Somente as superfícies do manto foram divididas em segmentos articulados, conservando a silhueta, espessura e UVs. Um osso por vértice, faces planas, sem arredondamentos.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
| Idle | 6.0 s | Sim | Flutuação suave, manto ondulando e vestígios espectrais em movimento. |
| Walk | 2.0 s | Sim | Deslizamento no lugar, corpo levemente inclinado e manto acompanhando o fluxo. |
| Attack | 1.5 s | Não | Preparação e golpe mágico frontal com o cajado, seguido de recuperação. |
| Spell | 3.0 s | Não | Ergue o grimório, lê e canaliza a magia pelo cajado; retorna ao repouso. |

- Ataque: impacto aos 0,625 s; conjuração: liberação aos 1,45 s. Attack e Spell terminam na pose inicial de Idle.
- Raiz imóvel em todos os clipes; o movimento de Walk é controlado pelo jogo.
- Braços conectados com segmentos de comprimento fixo. Punhos limitados a 35 graus em relação à pose inicial do antebraço. Cajado permanece preso à mão; grimório levita ligeiramente durante Spell.
- Partes superiores das vestes fixas ao torso/cintura; dobras e barras respondem com movimentos defasados.
- `elder_lich_blocky_v3_animated.glb`: quatro clipes, texturas embutidas e skin pronto para Godot.
- `elder_lich_blocky_v3_animated.blend`: cena isolada com quatro ações e faixas NLA.
- `elder_lich_animation_import.gd`: Idle/Walk em loop; Attack/Spell em execução única; sem autoplay.
- `animation_report.json`: poses e meios de quadro auditados no Blender, incluindo ciclos, articulações, punhos, distância do chão e interseções de adereços com torso/crânio.
- `godot_validation.json`: importação e reprodução reais, canais constantes, repetição dos ciclos e reinício de Spell para Idle.
- Prévias MP4/GIF renderizadas no Godot em `previews/animations`.
- Cena de revisão `scenes/art_review/ElderLichAnimationReview.tscn` (F6; 1–4 para escolher clipe, setas para girar, espaço para pausar e R para repetir).

A V2 está preservada. Em jogo desde 2026-10-13 (`UnitDatabase._apply_manifestation_model`): o mesmo modelo para as quatro raças, escala nativa de 3 m, Idle/Walk em ciclo, Spell em todo feitiço e trocas de estado por captura de pose (`scripts/units/PoseCaptureTransition.gd`, 0,5 s com curva seno). Attack fica ligado, mas a unidade não tem ataque básico: só toca pelo painel de Debug.

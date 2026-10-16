# Avatar da Natureza — quatro animações

Modelo flutuante V4, mantendo as 86 peças, 2060 triângulos, as texturas pixeladas e os 18 ossos. 1 malha exportada, 1 material e mapas de cor/emissão embutidos. Frente Blender -Y / Godot +Z.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
| Idle | 12.0 s | Sim | Flutuação suave, giro lento do núcleo e raízes suspensas balançando. |
| Walk | 6.0 s | Sim | Deslizamento pairando no lugar, corpo inclinado e raízes acompanhando o fluxo. |
| Attack | 2.0 s | Não | Prepara o braço direito e libera um golpe frontal de energia, com recuperação. |
| Spell | 3.5 s | Não | Ergue os dois braços, concentra energia no núcleo e projeta o poder em direção ao terreno. |

- Impacto de Attack: 0,875 s. Liberação de Spell: 1,75 s.
- Raiz imóvel em todos os clipes. O controlador do jogo faz o deslocamento de Walk.
- Braços conectados, comprimento constante, punhos com gestos limitados. Partes permanecem rígidas.
- Raízes balançam pelos pontos em que se ligam ao tronco.
- O núcleo tem um pequeno afastamento frontal para girar sem atravessar a casca; mantém sua geometria e recebe pulsação uniforme durante as ações.
- Idle/Walk repetem; Attack/Spell recuperam a pose inicial de Idle. Todos têm os mesmos canais.
- `animation_report.json`: amostragem dos meios de quadro, articulações, ciclos, distância do solo, movimento das raízes e colisões do núcleo.
- `godot_validation.json`: reprodução e repetição reais no Godot, reset de Spell para Idle e prévias nativas.
- `nature_avatar_animation_import.gd`: configuração dos ciclos na importação.
- `scenes/art_review/NatureAvatarAnimationReview.tscn`: revisão com teclas 1–4 e controle de câmera.
- MP4/GIF em `previews/animations`; galeria em `art_source/nature_avatar_blocky_v5_animated_review/index.html`.

As versões estáticas e os outros bosses estão preservados.

Em jogo desde 2026-10-13 (`UnitDatabase._apply_manifestation_model`): o mesmo modelo para as quatro raças, escala nativa de 3 m, Idle/Walk em ciclo, Spell em todo feitiço e trocas de estado por captura de pose (`scripts/units/PoseCaptureTransition.gd`, 0,5 s com curva seno). Attack fica ligado, mas a unidade não tem ataque básico: só toca pelo painel de Debug.

# Arconte do Véu — quatro animações

Modelo rúnico V8 animado, com os seis arcos externos roxos removidos. Mantém a geometria das 47 peças restantes e as texturas aprovadas. 1364 triângulos, 39 ossos, 1 malha e 1 material, mapas de cor/emissão embutidos. Frente Blender -Y / Godot +Z.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
| Idle | 24.0 s | Sim | Giro lento da casca, núcleo girando em sentido contrário e pulsação suave das placas. |
| Walk | 12.0 s | Sim | Desliza pairando, com leve inclinação frontal e giro contínuo das placas. |
| Attack | 2.25 s | Não | Concentra o núcleo e abre as quatro placas frontais para liberar um pulso de mana. |
| Spell | 4.0 s | Não | Levanta e expande a casca rúnica, gira as camadas e revela o núcleo durante a conjuração. |

- Attack libera o pulso em 0,875 s; Spell conjura em 2,0 s.
- Raiz imóvel; o controlador do jogo faz o deslocamento de Walk.
- Placas permanecem rígidas, com expansão radial e pivôs individuais.
- Núcleo cúbico com giro independente e pulsação uniforme nas ações.
- Idle/Walk repetem; Attack/Spell recuperam a pose inicial de Idle. Todos têm os mesmos canais.
- `animation_report.json`: amostragem dos meios de quadro, ciclos, chão e colisões do núcleo e das placas.
- `godot_validation.json`: reprodução nativa, pesos rígidos, ciclos, reset de Spell para Idle e prévias.
- `veil_archon_animation_import.gd`: configura os ciclos na importação.
- `scenes/art_review/VeilArchonAnimationReview.tscn`: revisão com teclas 1–4.
- MP4/GIF em `previews/animations`; galeria em `art_source/veil_archon_blocky_v9_animated_review/index.html`.

Em jogo desde 2026-10-13 (`UnitDatabase._apply_manifestation_model`): o mesmo modelo para as quatro raças, escala nativa de 3 m, Idle/Walk em ciclo, Spell em todo feitiço e trocas de estado por captura de pose (`scripts/units/PoseCaptureTransition.gd`, 0,5 s com curva seno). Attack fica ligado, mas a unidade não tem ataque básico: só toca pelo painel de Debug.

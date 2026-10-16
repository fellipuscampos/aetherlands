# Arcdemônio — quatro animações

Revisão da V3: faixas laterais giradas 90° e encaixadas na superfície das placas da cintura; núcleo substituído por um único cubo emissivo vermelho de 24 cm, dentro da cavidade do peito. Ombros e mãos permanecem separados. Texturas da armadura e faixas preservadas.

Altura de referência: 3 m. Frente: Blender -Y / Godot +Z. 74 peças editáveis, 1.084 triângulos, 1 malha, 1 material e 29 ossos. Corpo e mãos rígidos; faixas articuladas em seções compartilhadas, com um osso por vértice e junções contínuas.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
| Idle | 24.0 s | Sim | Flutuação e ondulação das faixas, com atraso entre as dobras. |
| Walk | 8.0 s | Sim | Deslizamento no lugar e faixas acompanhando o fluxo. |
| Attack | 1.5 s | Não | Preparação e golpe frontal com as duas mãos flutuantes. |
| Spell | 3.0 s | Não | Mãos à frente com palmas para cima; liberação de energia e retorno suave. |

- `archdemon_blocky_v5_animated.glb`: quatro clipes, texturas embutidas e filtro NEAREST.
- `archdemon_blocky_v5_animated.blend`: cena isolada, quatro ações e faixas NLA separadas.
- `archdemon_animation_import.gd`: Idle/Walk em loop e Attack/Spell em execução única; canais constantes mantidos para reiniciar as poses após interrupções.
- `animation_report.json`: poses e meios de quadro conferidos no Blender; cubo dentro do peito, mãos sem interseção com ombros, raiz imóvel e folga do chão.
- `godot_validation.json`: quatro clipes exercitados na importação nativa, com rigidez, fechamento dos ciclos e reinício de Spell para Idle verificados.
- Prévias: `previews/animations/*.mp4` e `*.gif`, renderizadas no Godot.
- Cena de revisão: `scenes/art_review/ArchdemonAnimationReview.tscn`. F6; 1–4 escolhem o clipe; setas giram; espaço pausa; R repete.

Revisão das animações: faixas com ondas defasadas, junções fechadas e segmento inicial fixo à cintura. Spell orientado pelo eixo real das mãos: punhos para trás e palmas para cima, com avanço na liberação.

Em jogo desde 2026-10-13 (`UnitDatabase._apply_manifestation_model`): o mesmo modelo para as quatro raças, escala nativa de 3 m, Idle/Walk em ciclo, Spell em todo feitiço e trocas de estado por captura de pose (`scripts/units/PoseCaptureTransition.gd`, 0,5 s com curva seno). Attack fica ligado, mas a unidade não tem ataque básico: só toca pelo painel de Debug. A V4 e as demais cenas estão preservadas.

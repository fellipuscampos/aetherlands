# Primordial dos Elementos — idle, caminhada e spell

Modelo ativo da grande invocação `v2_manifestation_elemental_primordial`, com a geometria aprovada de 3 m e a estética quadrada preservadas.

| Animação | Comportamento | Duração |
| --- | --- | --- |
| idle | Postura erguida, pequena ondulação lateral, flutuação e pulso suave | 6 s, loop |
| walk | Corpo aberto em S; a onda passa da cabeça à cauda, como uma serpente | 4 s, loop |
| spell | Entrada na postura de conjuração, voltas aprovadas em torno do núcleo e retorno à postura parada | 8 s, uma vez |
| attack | Animação da versão v9 preservada | 2,4 s, uma vez |

O trecho central de 6 s do spell reproduz o walk aprovado da versão v9. A comparação de 13 poses em todos os ossos está em `approved_spell_motion` no relatório. A entrada e a recuperação levam 1 s cada.

Fonte: Blender aberto via MCP, usando `tools/art_pipeline/animate_elemental_dragon_states_mcp.py`. O `.blend`, o `.glb`, as texturas e as prévias estão nesta pasta. A importação mantém todas as chaves de animação e acrescenta a variação de emissão do núcleo.

As regras e os atributos da unidade permanecem preservados. As verificações do Blender, do importador e da unidade real estão em `elemental_dragon_v10_animated_report.json`, `godot_validation.json` e `unit_validation.json`.

Transicoes no jogo: `PoseCaptureTransition.gd` (o antigo `ElementalSerpentTransition.gd`, generalizado em 2026-10-13 para as seis Grandes Manifestacoes) captura a pose atual e usa a mistura de propriedades do Godot com curva seno suave. Trocas envolvendo walk levam 0,9 s; as demais, 0,6 s. A captura inclui os ossos e a emissao do nucleo, permitindo interromper uma transicao ou reiniciar spell sem salto de pose. Os clipes importados sao copiados em memoria; o GLB aprovado permanece intacto.

A cena `ElementalSerpentTransitionReview.tscn` verifica 12 pares de estados e 6 interrupcoes, alem de comparar as poses com o modelo original. Resultado em `transition_validation.json`; previa completa em `previews/transitions.mp4` e `previews/transitions.gif`.

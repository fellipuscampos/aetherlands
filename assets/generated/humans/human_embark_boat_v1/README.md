# Barco Humano — embarcação de transporte

Casco de madeira clara, vela azul lisa com bordas de linho, baú na popa.

Representa **uma unidade embarcada**. São quatro designs, um por raça, com velas sem símbolos e estufadas para a frente.

- `human_embark_boat_v1.blend`: peças separadas e editáveis, texturas empacotadas.
- `human_embark_boat_v1.glb`: 4 grupos de malha, um material opaco, albedo e ORM de 512×512 embutidos, filtro nearest.
- `human_embark_boat_v1.tscn`: cena para o mapa, escala 0,52 já aplicada no filho `Visual`.
- `previews/`: vistas na água, de cima, de lado e casco completo.

**Animações embutidas:** `idle` (4 s) e `walk` (2 s), em loop e no lugar. Afundamento suave em Y negativo e inclinação pequena em torno da linha d’água; o mar permanece um plano fixo. A vela tem uma deformação discreta pelo vento. O barco anão tem menos balanço. O post-import `tools/art_pipeline/embark_boat_import.gd` configura os loops e autoplay de `idle`; use `AnimationPlayer.play("walk")` para navegar.

A origem fica no centro da linha d’água; no Godot o eixo frontal é **−Z**, Y aponta para cima. O casco submerso permanece abaixo de Y=0. Posicione a raiz na altura da superfície da água. A cena usa uma escala simbólica para caber no hexágono de raio 1; o GLB conserva a escala de modelagem.

Importe a cena `.tscn` como visual da unidade durante `embarked=true`, escondendo o visual terrestre. Ao desembarcar, restaure o visual terrestre. A troca automática de visual não foi alterada por este pacote de modelos.

Modelado e animado no Blender aberto pelo MCP em localhost:9876. Versão anterior em `art_source/embark_boats_review/before_sails_animation/`.

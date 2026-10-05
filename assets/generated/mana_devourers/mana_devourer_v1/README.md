# Devorador de Mana — Aetherlands

Entidade arcana não humanoide, criada no Blender 5.2.2 pelo MCP em localhost:9876.
As referências inspecionadas foram `troll_blocky_v3` e `goblin_raider_v3`: faces
planas, prismas simples, pintura em blocos de pixels e escala de **64 px/m**.

O núcleo de obsidiana possui uma abertura vertical escura com bordas emissivas,
fendas ciano e violeta e uma silhueta irregular que termina em ponta. Quatro
fragmentos assimétricos e dois trechos de um aro quebrado formam a órbita.
São **sete peças visíveis**, sem blocos internos ou componentes redundantes.

## Arquivos

- `mana_devourer_v1.blend`: fonte editável; sete peças separadas, rig e estúdio.
- `mana_devourer_v1.glb`: uma malha com skin, um material, oito ossos e texturas embutidas.
- `mana_devourer_v1_albedo.png`: atlas de cor 512×512, sRGB.
- `mana_devourer_v1_emission.png`: mapa emissivo 512×512, sRGB.
- `mana_devourer_v1_report.json`: geometria, UV, GLB e fonte Blender verificados.
- `godot_validation.json`: verificação de importação e material no Godot.
- `previews/{front,three_quarter,side,back,game_top}.png`: revisão Blender.
- `previews/godot_game_view.png`: render real do GLB importado no Godot.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 252 |
| Vértices de modelagem | 140; a exportação duplica vértices nas costuras UV/normais |
| Componentes editáveis | 7 |
| GLB | 1 malha, 1 material, 1 skin |
| Rig | 8 ossos, pesos rígidos normalizados |
| Dimensões ocupadas | 2,421 m de largura × 1,141 m de profundidade × 2,451 m de altura |
| Altura máxima acima do chão | 2,693 m |
| Distância mínima ao chão | 0,242 m |
| UVs | 110 ilhas únicas, 2 px de margem, sem sobreposição |
| Densidade medida | 63,99980–64,00015 px/m |
| Material | Flat, roughness 0,78, sem transparência; albedo + emissão |
| Texturas | 512×512, nearest; PNGs também embutidos no `.blend` e no GLB |
| Animações | Nenhuma nesta entrega |

As UVs usam projeção ortonormal por face em escala métrica. Os motivos foram
pintados nas dimensões reais de cada ilha, sem redimensionar painéis quadrados.
O material mantém o brilho das fendas pela emissão, sem exigir luzes auxiliares
ou bloom para a leitura do personagem. O brilho difuso ao redor depende das
configurações de pós-processamento do jogo.

## Organização e controles

Cena `Mana_Devourer_V1`, com coleções `01_CORE`, `02_ORBITALS`, `03_RIG` e `04_STUDIO`.
O estúdio é excluído do GLB. Transforms dos componentes aplicados, escala 1.
Origem no chão sob a criatura; a altura de flutuação já está na geometria.

Ossos: `root`, `core`, `orbit_01` a `orbit_04`, `arc_upper`, `arc_lower`.
Os fragmentos têm pivôs próprios; os dois arcos têm pivôs no centro de sua órbita.
Isso permite animar flutuação, rotação e abertura das peças posteriormente.

## Uso no jogo

Instanciar `mana_devourer_v1.glb` com escala **1,0**. Frente **-Y no Blender**,
**+Z no glTF/Godot**; yaw inicial **0°** na convenção dos modelos manuais V3.
Manter o filtro nearest. O GLB já inclui emissão; não precisa de shaders externos.

O arquivo é um asset de criatura pronto para importação. Cadastro em
`MonsterDatabase.gd`, habilidades de drenagem de mana, combate, colisão e clipes
de animação pertencem à integração de gameplay e não foram incluídos nesta etapa.

## Reprodução e verificações

Via `python tools/art_pipeline/blender_mcp_client.py <script>`:

1. `mana_devourer_model.py`: modelo, UVs, mapas e rig; recusa sobrescrever cena existente.
2. `mana_devourer_previews.py`: renders Blender.
3. `mana_devourer_export.py`: auditoria, `.blend` isolado e GLB.

`mana_devourer_repaint.py` atualiza somente a pintura após editar sua definição.
`validate_mana_devourer_godot.py` roda pelo Python local: importa o GLB em um projeto
temporário, verifica skin/ossos/material/filtro/escala e captura uma única vista
real do Godot. O projeto temporário é removido ao terminar.

Geometria fechada, sem faces de área zero, sem cruzamentos entre as sete peças;
arquivo Blender com apenas a cena final e sem ações. O GLB é conferido diretamente:
contagens, sampler nearest, skin e igualdade dos PNGs embutidos com os arquivos.

## Integração

Integrado ao jogo em 2026-10-03: kind "mana_devourer" (`MonsterDatabase.HANDMADE_MODELS`), escala 1,0, yaw 0,
crossfade de 0,2 s entre ManaDevourer_Idle/ManaDevourer_Walk/ManaDevourer_Attack (`animation_blend_time`).
O GLB atual já traz os três clipes (a tabela acima, "Animações: nenhuma", é da entrega
estática anterior). Loops via `mana_devourer_import.gd`, ligado no `.glb.import`.

## Escala (2026-10-04)

O nó `Mana_Devourer_V1_ROOT` (pai do rig) tem escala uniforme **0,65** no `.blend` e no `.glb`.
Malha, UVs, texturas, rig e animações não mudaram: só esse nó. Medidas em jogo:
**1,57 m de largura, 1,59 m de altura (flutuando), 0,74 m de profundidade** (o resto deste README descreve o modelo em escala 1,0). A escala foi
gravada direto no nó raiz do GLB, sem re-export, e copiada para o `.blend`. Um
re-export mantém a escala porque o `_ROOT` vai junto.

# Centro da Cidade Orc — Nível I

Modelo original blocky para uma cidade orc de um jogo 4X. Salão do chefe de
madeira grossa sobre pedra escura, telhado avermelhado em degraus com amarrações
de ferro, grandes presas na entrada, emblema da mandíbula do clã e totem lateral.
O pequeno pátio tem um braseiro comunitário, suprimentos e caminho de pedra.

**Somente asset: não cadastrado nem colocado no jogo.** Nenhum catálogo ou
código de cidade foi alterado para integrar este modelo. O campo
`city_center_level_1` no nó raiz é metadado do asset, não uma seleção de modelo
para as cidades humanas.

- `orc_city_level_1_hex_v1.blend`: cena isolada, 128 peças editáveis e texturas
  empacotadas; câmera e iluminação de prévia incluídas na fonte.
- `orc_city_level_1_hex_v1.glb`: exportação para integração futura, 8 malhas,
  1 material, 1.656 triângulos, texturas embutidas. Sem câmera, luz, rig ou animação.
- `orc_city_level_1_hex_v1_albedo.png` e `_emission.png`: atlas 1024², pixels
  com filtro nearest; braseiro com emissão.
- `previews/`: vistas de três quartos, câmera alta de jogo, topo e traseira.
- `orc_city_level_1_hex_v1_report.json`: medidas, limites e validação do GLB.

Base hexagonal pointy-top com raio 0,84 para tile de raio 1. Dimensões da peça:
1,4549 × 1,68 × 1,192 unidades de mapa. Origem central no chão Z=0. Frente em
−Y no Blender / +Z no glTF. Para um tile de outro raio, escalar uniformemente
pelo raio do tile. O maior limite projetado nas seis faces do hex é 0,72746,
abaixo do limite interno de fortificação 0,76706, com margem de 0,03960.

**Não possui muralha ao redor.** As muralhas e seus níveis continuam como
assets independentes. O volume central e o único totem são modestos para
permitir que os níveis II–IV acrescentem um salão maior, torres e novos anexos.

O grupo `Faction` separa bandeira e tecido do emblema, pintados de vermelho
ferrugem. Pode receber a cor do dono quando a integração das civilizações
for implementada. Presas, telhado, ferro e madeira conservam suas cores.

Geração pelo Blender aberto, via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_city_level_1_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_city_level_1_hex_v1_finish.py
```

A construção recusa substituir uma cena já existente para preservar edições.
O script de finalização pode exportar a cena existente novamente. O diretório
é persistido em `asset_output_relative` na cena Blender, permitindo que os
helpers compartilhados mantenham humanos e orcs em suas próprias pastas.

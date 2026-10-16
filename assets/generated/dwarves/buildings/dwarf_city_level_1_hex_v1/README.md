# Centro da Cidade Anã — Nível I

Salão cívico original em estilo blocky para a civilização anã. Volume baixo
e largo em granito, grandes pilares quadrados, inscrições geométricas de
cobre e telhado escuro em degraus com cintas metálicas. Portal monumental
com martelo, pequeno lanternim no telhado, monumento à bigorna dos fundadores,
banco de pedra e cisterna no pátio aberto.

**Somente asset: não cadastrado nem colocado no jogo.** Nenhum código de
gameplay ou catálogo foi alterado. Os campos `city_center_level_1` e
`civilization=dwarf` no nó raiz são metadados para uma integração futura.

- `dwarf_city_level_1_hex_v1.blend`: cena isolada, 143 peças editáveis,
  texturas empacotadas e estúdio de prévia.
- `dwarf_city_level_1_hex_v1.glb`: 8 malhas, 1 material, 1.848 triângulos e
  texturas embutidas. Sem câmera, luz, rig ou animação.
- `dwarf_city_level_1_hex_v1_albedo.png` e `_emission.png`: atlas 1024²,
  filtro nearest; emissão âmbar nas lanternas e janelas iluminadas.
- `previews/`: três quartos, câmera alta de jogo, topo e traseira.
- `dwarf_city_level_1_hex_v1_report.json`: medidas, limites e verificações do GLB.

Base hexagonal pointy-top de raio 0,84 para tile de raio 1. Dimensões:
1,4549 × 1,68 × 1,187 unidades de mapa. Origem central no chão Z=0.
Frente em −Y no Blender / +Z no glTF. Para outros tamanhos de tile,
escalar uniformemente pelo raio do tile durante a integração futura.
Limite projetado máximo nas seis faces do hex: 0,72746, abaixo do limite
interno da fortificação independente: 0,76706, com folga de 0,03960.

**Sem muralhas ao redor.** O único salão e o lanternim baixo são a etapa
inicial de uma família de quatro níveis. Torres maiores, alas laterais e
coberturas adicionais ficam reservadas para os níveis II–IV. A bigorna
é um monumento cívico; o pátio não tem equipamentos de treinamento.

Placa e bandeira azul-safira ficam no grupo `Faction`, separado da pedra,
cobre, telhado e luzes. O grupo permite cor por dono em uma futura integração.

Geração pelo Blender aberto, via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/dwarf_city_level_1_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/dwarf_city_level_1_hex_v1_finish.py
```

O script de construção recusa substituir uma cena existente, preservando
edições. O script de finalização pode renderizar e exportar a cena novamente.
O diretório de saída é persistido em `asset_output_relative` na cena Blender.

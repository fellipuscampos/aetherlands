# Centro da Cidade Élfica — Nível I

Pavilhão de conselho original em estilo blocky para uma cidade élfica de um
jogo 4X. Pedra clara, madeira quente, pilares esbeltos, apoios em forma de
galhos feitos em degraus, telhado verde-esmeralda e ornamentos dourados de
folhas. Entrada em arco pontudo, árvore com copa em blocos, pequeno espelho
d'água, banco, jardim e bandeirola cívica.

**Somente asset: não cadastrado nem colocado no jogo.** Nenhum script de
gameplay ou catálogo foi alterado. `city_center_level_1` e `civilization=elf`
no nó raiz são metadados para futura integração.

- `elf_city_level_1_hex_v1.blend`: cena isolada com 133 peças editáveis,
  texturas empacotadas, câmera e iluminação de prévia.
- `elf_city_level_1_hex_v1.glb`: 8 malhas, 1 material e 2.028 triângulos;
  texturas embutidas, sem câmera, luz, rig ou animação.
- `elf_city_level_1_hex_v1_albedo.png` e `_emission.png`: atlas 1024²,
  nearest, com emissão somente nas pequenas lanternas da entrada.
- `previews/`: três quartos, câmera alta de jogo, topo e traseira.
- `elf_city_level_1_hex_v1_report.json`: medidas e verificações de exportação.

Base hexagonal pointy-top de raio 0,84 para tile de raio 1. Dimensões:
1,4549 × 1,68 × 1,3125 unidades de mapa. Origem central no chão Z=0.
Frente: −Y no Blender / +Z no glTF. Escalar uniformemente pelo raio do tile
na integração futura. Todos os vértices, incluindo a copa da árvore e o
telhado, ficam dentro do espaço reservado ao centro da cidade; limite
projetado máximo nas faces do hex: 0,72746, frente ao limite interno da
fortificação: 0,76706.

**Sem muralhas ao redor.** A borda fica livre para as fortificações
independentes. O nível I tem um único volume e cobertura principal; salões
maiores, torres e novos anexos ficam reservados para os níveis II–IV.

Tecidos verde-menta da placa e da bandeirola ficam no grupo `Faction`,
separados do telhado, ouro, árvore e água. Isso permite cor por dono quando
o suporte às construções das civilizações for integrado.

Scripts executados pelo Blender aberto via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/elf_city_level_1_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/elf_city_level_1_hex_v1_finish.py
```

O script de construção recusa sobrescrever uma cena existente para preservar
edições. O script de finalização pode renderizar e exportar novamente a cena
existente. O diretório de saída está salvo em `asset_output_relative` na cena.

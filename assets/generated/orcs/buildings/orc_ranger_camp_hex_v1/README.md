# Campo dos Patrulheiros Orcs

Prédio original blocky para treinar a classe de unidades à distância e
suas evoluções no mapa 4X. Cabana lateral de basalto/madeira pesada com
telhado vermelho, ferro e presas, emblema de arco reforçado com flecha,
três alvos de anéis vermelhos e marfim sob cobertura de couro, barreira
traseira para flechas e pistas de tiro marcadas. Suporte de arcos, caixa
de munição com flechas, banco e bandeirola completam o campo aberto.

**Somente asset: não cadastrado nem colocado no jogo.** É a versão visual
orc de `v2_building_ranger_camp`, a mesma construção funcional dos humanos.
Esse ID no nó raiz é metadado para integração futura; o modelo humano atual
e as regras de treinamento permanecem como estavam.

O relatório referencia a linha comum existente: `v2_unit_archer`,
`v2_unit_hunter`, `v2_unit_elite_marksman`. O lendário
`v2_legendary_legend_hunter` continua no prédio próprio de maestria.
Nenhum modelo de personagem orc foi criado ou presumido.

- `orc_ranger_camp_hex_v1.blend`: cena isolada, 181 peças editáveis,
  texturas empacotadas, câmera e iluminação de prévia.
- `orc_ranger_camp_hex_v1.glb`: 8 malhas, 1 material, 3.532 triângulos;
  texturas embutidas. Sem câmera, luz, rig ou animação.
- `orc_ranger_camp_hex_v1_albedo.png` e `_emission.png`: atlas 2048²,
  nearest, com emissão apenas na lanterna da cabana.
- `previews/`: três quartos, câmera alta de jogo, topo e traseira.
- `orc_ranger_camp_hex_v1_report.json`: medidas, função e validações do GLB.

Base hexagonal pointy-top de raio 0,92 para tile de raio 1, igual aos
prédios militares humanos e orcs. Dimensões: 1,5935 × 1,84 × 1,029 unidades
de mapa. Origem central no chão Z=0; frente em −Y no Blender / +Z no glTF.
Escalar uniformemente pelo raio do tile na integração futura. Limite
projetado máximo nas seis faces: 0,79674, dentro do apótema do tile 0,86603,
com margem de 0,06928. Cabana, cobertura inclinada dos alvos, flechas e
bandeira foram verificados. Sem anel de muralhas ou torre de vigia.

Placa do emblema e bandeirola ficam no grupo `Faction`, separado das armas,
pedra, madeira e alvos. Isso permite cor do dono em uma futura integração,
preservando o contraste dos anéis para indicar o treino de tiro.

Geração pelo Blender aberto, via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_ranger_camp_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_ranger_camp_hex_v1_finish.py
```

O script de construção recusa substituir uma cena existente. O script de
finalização pode renderizar e exportar novamente a fonte. O diretório de
saída é persistido em `asset_output_relative` na cena Blender.

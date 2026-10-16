# Salão de Armas dos Orcs

Prédio original blocky para treinar a classe guerreiro e suas evoluções
no mapa 4X. Mantém a identidade da cidade e do salão de tanks orcs:
basalto, madeira pesada, ferro escuro, telhados vermelho-ferrugem e presas.
Salão baixo e largo, telhado transversal, grande emblema de machados cruzados
e abrigo lateral aberto com suporte de machados. Dois alvos de palha com
marcas de golpes ocupam o pátio de combate em cunha, com posições de treino,
braseiro e bandeira do clã.

**Somente asset: não cadastrado nem colocado no jogo.** Representa a
versão visual orc de `v2_building_warrior_hall`, preservando a função
compartilhada entre as civilizações. Esse ID no nó raiz é metadado para
a futura integração; o modelo humano atual permanece como estava.

O relatório referencia a linha comum já existente: `v2_unit_warrior`,
`v2_unit_swordsman`, `v2_unit_weapon_master`. O herói supremo
`v2_legendary_blade_hero` permanece excluído, com prédio próprio de maestria.
Nenhum modelo de personagem orc foi criado ou presumido.

- `orc_warrior_hall_hex_v1.blend`: cena isolada, 164 peças editáveis,
  texturas empacotadas e estúdio de prévia.
- `orc_warrior_hall_hex_v1.glb`: 8 malhas, 1 material, 2.244 triângulos;
  texturas embutidas. Sem câmera, luz, rig ou animação.
- `orc_warrior_hall_hex_v1_albedo.png` e `_emission.png`: atlas 2048²,
  nearest; emissão nas lanternas e no fogo do braseiro.
- `previews/`: três quartos, câmera alta de jogo, topo e traseira.
- `orc_warrior_hall_hex_v1_report.json`: medidas, função e validações do GLB.

Base hexagonal pointy-top de raio 0,92 para tile de raio 1, igual às
construções militares humanas e ao salão de tanks orcs. Dimensões:
1,5935 × 1,84 × 1,197 unidades de mapa. Origem no centro da base, chão Z=0;
frente em −Y no Blender / +Z no glTF. Escalar uniformemente pelo raio do tile
na integração futura. Limite projetado máximo nas seis faces: 0,79674,
dentro do apótema do tile 0,86603, com margem de 0,06928. Telhado, machados,
presas e abrigo lateral também foram verificados. Sem anel de muralhas.

Placa dos machados e bandeira ficam no grupo `Faction`, separado da pedra,
madeira, lâminas, presas e fogo, permitindo cor do dono em uma integração futura.

Geração pelo Blender aberto, via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_warrior_hall_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_warrior_hall_hex_v1_finish.py
```

O script de construção recusa substituir uma cena existente. O script de
finalização pode renderizar e exportar a fonte novamente. O diretório de
saída é persistido em `asset_output_relative` na cena Blender.

# Guilda dos Ladinos Orcs

Prédio original blocky para a linha ladino/sabotador/assassino no mapa 4X.
Salão assimétrico em basalto e madeira escura, telhado vermelho-ferrugem em degraus,
presas curtas no topo e cintas vermelhas. Emblema de capuz com
olhos estreitos, pequenas presas e duas adagas cruzadas. Anexo baixo com
toldo vermelho escuro e barra vermelha recortada; pátio com alvo para facas,
manequim de golpes precisos, bancada de adagas, frascos e alçapão fechado.

**Somente asset: não cadastrado nem colocado no jogo.** A versão orc da
construção `v2_building_rogue_guild` usa esse ID apenas como metadado no
nó raiz. Catálogo, treinamento e seleção de modelos permanecem intactos.

O relatório referencia `v2_unit_rogue`, `v2_unit_saboteur` e
`v2_unit_assassin`. O lendário `v2_legendary_shadow_master` permanece
excluído: pertence ao prédio próprio de maestria.

- `orc_rogue_guild_hex_v1.blend`: cena isolada com 191 peças editáveis,
  texturas empacotadas e câmera/iluminação de prévia.
- `orc_rogue_guild_hex_v1.glb`: 8 malhas, 1 material e 2.652 triângulos;
  atlas embutidos, sem câmera, luz, rig, skin ou animação.
- `orc_rogue_guild_hex_v1_albedo.png` e `_emission.png`: atlas 2048² nearest.
- `previews/`: três quartos, visão alta do mapa, topo e traseira.
- `orc_rogue_guild_hex_v1_report.json`: função, medidas e verificações.

Base hexagonal pointy-top de raio 0,92 para tile de raio 1. Dimensões:
1,5935 × 1,84 × 1,135 unidades de mapa. Origem central no chão Z=0;
frente −Y no Blender / +Z no glTF. Na integração futura, usar escala
uniforme igual ao raio do tile. Projeção máxima sobre as seis faces:
0,79674, dentro do apótema 0,86603, com margem de 0,06928. Todos os
vértices foram verificados, incluindo telhados, presas e toldo.
Não há anel de muralhas. O alçapão é um adereço fechado, sem interior.

O tecido atrás do emblema e a barra recortada do toldo ficam na malha
`Faction` para permitir futura cor do dono. Telhado, madeira, ferro,
adagas, presas e frascos preservam suas cores. Todos os objetos são
geometria estática original; não há dependência de um personagem orc.

Geração no Blender aberto via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_rogue_guild_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_rogue_guild_hex_v1_finish.py
```

O construtor preserva as outras cenas e recusa sobrescrever uma cena
existente. A finalização pode renderizar e exportar novamente. O destino
fica salvo em `asset_output_relative` na cena Blender.

# Estábulo de Guerra dos Orcs

Prédio original blocky para treinar a cavalaria orc e suas evoluções no mapa
4X. Basalto, madeira pesada, ferro escuro, telhado vermelho-ferrugem e presas,
seguindo a família de construções orcs. Duas baias realmente abertas, emblema
de ferradura com presas, cavalos em miniatura, pátio com cercas baixas oblíquas,
feno, suporte de lanças, sela de reserva e bebedouro.

**Somente asset: não cadastrado nem colocado no jogo.** É a versão visual
orc de `v2_building_war_stable`, a mesma construção funcional dos humanos.
Esse ID no nó raiz é metadado para integração futura. Nenhum catálogo,
treinamento, modelo humano ou seletor de civilização foi alterado.

O relatório referencia a linha comum: `v2_unit_cavalier`,
`v2_unit_shock_cavalier`, `v2_unit_armored_cavalier`. O lendário
`v2_legendary_griffon_rider` continua no prédio próprio de maestria.

- `orc_war_stable_hex_v1.blend`: cena isolada, 185 peças editáveis,
  texturas empacotadas, câmera e iluminação de prévia.
- `orc_war_stable_hex_v1.glb`: 8 malhas, 1 material e 2.492 triângulos;
  texturas embutidas. Sem câmera, luz, rig, skin ou animação.
- `orc_war_stable_hex_v1_albedo.png` e `_emission.png`: atlas 2048² nearest,
  com emissão somente nas lanternas das baias.
- `previews/`: três quartos, câmera alta de jogo, topo e traseira.
- `orc_war_stable_hex_v1_report.json`: medidas, função e verificações do GLB.

Os dois cavalos são adereços estáticos genéricos, reaproveitados de
`humans/cavalier_v1/cavalier_v1.blend`: somente cavalo, sela e manta, sem
cavaleiro ou rig. A pelagem aprovada foi repintada no atlas do prédio a
partir das UVs da fonte. Mantas superiores e laterais usam vermelho do clã
no grupo `Faction`. Os arquivos do cavaleiro original permanecem intactos.
Isso não define nem implementa o modelo futuro da unidade montada orc.

Base hexagonal pointy-top de raio 0,92 para tile de raio 1. Dimensões:
1,5935 × 1,84 × 1,238 unidades de mapa. Origem central no chão Z=0;
frente em −Y no Blender / +Z no glTF. Escalar uniformemente pelo raio do
tile na integração futura. Limite projetado máximo nas seis faces: 0,79674,
dentro do apótema do tile 0,86603, com margem de 0,06928. Todos os vértices
do telhado, presas, lanças, cavalos e cercas foram verificados. Cercas
somente no pátio de montaria, sem anel de muralhas ao redor do tile.

Placa da ferradura, estandarte e mantas dos cavalos ficam no grupo `Faction`
para futura cor do dono. Ferro, presas, madeira, pelagem e água mantêm suas cores.

Geração pelo Blender aberto, via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_war_stable_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_war_stable_hex_v1_finish.py
```

O script de construção recusa substituir uma cena existente. O script de
finalização pode renderizar e exportar novamente a fonte. O diretório de
saída é persistido em `asset_output_relative` na cena Blender.

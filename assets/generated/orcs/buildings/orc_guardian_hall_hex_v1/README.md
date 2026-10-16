# Salão dos Guardiões Orcs

Prédio original blocky para treinar a classe tank dos orcs no mapa 4X.
Segue a mesma identidade visual do centro da cidade orc: basalto,
madeira pesada, ferro escuro, telhado vermelho-ferrugem e presas claras.
Salão traseiro com grande emblema de escudo, torre de vigia quadrada com
cantos de presas, estandarte do clã e pátio de areia em cunha. Dois manequins
com escudos, posições de treino e suporte de escudo de reserva identificam
a função militar pela câmera alta.

**Somente asset: não cadastrado nem colocado no jogo.** Os orcs possuem
as mesmas construções e funções dos humanos; esta peça representa a
versão visual orc de `v2_building_guardian_hall`. Esse ID no nó raiz é
metadado para a futura integração, sem substituir o modelo humano atual.

A linha comum de tanks é registrada como referência no relatório:
`v2_unit_shieldbearer`, `v2_unit_guardian`, `v2_unit_sentinel`.
O herói supremo `v2_legendary_guardian_champion` continua excluído e tem
prédio próprio. Nenhum modelo de personagem orc foi criado ou presumido.

- `orc_guardian_hall_hex_v1.blend`: cena isolada com 166 peças editáveis,
  texturas empacotadas, câmera e iluminação de prévia.
- `orc_guardian_hall_hex_v1.glb`: 8 malhas, 1 material e 2.492 triângulos;
  texturas embutidas. Sem câmera, luz, rig ou animação.
- `orc_guardian_hall_hex_v1_albedo.png` e `_emission.png`: atlas 2048²,
  filtro nearest, emissão apenas nas lanternas.
- `previews/`: três quartos, câmera alta de jogo, topo e traseira.
- `orc_guardian_hall_hex_v1_report.json`: medidas, função e validações do GLB.

Base hexagonal pointy-top de raio 0,92 para tile de raio 1, igual à base
das construções militares humanas. Dimensões: 1,5935 × 1,84 × 1,326 unidades
de mapa. Origem no centro da base, chão Z=0; frente em −Y no Blender / +Z
no glTF. Escalar uniformemente pelo raio do tile na integração futura.
Limite projetado máximo nas seis faces: 0,79674, dentro do apótema do
tile 0,86603, com margem de 0,06928. Telhado, presas, escudos e torre
também foram verificados. O pátio é aberto, sem um anel de muralhas.

Estandarte e faixas dos escudos estão no grupo `Faction`, separado da
madeira, ferro e presas, para permitir cor do dono em uma integração futura.

Geração pelo Blender aberto, via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_guardian_hall_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_guardian_hall_hex_v1_finish.py
```

O script de construção recusa substituir uma cena existente. O script de
finalização pode renderizar e exportar novamente a fonte existente.
O diretório de saída é persistido em `asset_output_relative` na cena.

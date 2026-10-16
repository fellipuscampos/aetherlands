# Centro da Cidade — Nível I / Hex V1

Primeiro de quatro níveis de centro urbano: castelo compacto, com uma torre
baixa de ameias, salão de pedra, telhado azul e pátio cívico. Criado no Blender
pela conexão MCP ativa e integrado em `City.gd` para **Cidade I**.

## Direção da evolução

O nível I estabelece a linguagem da família: pedra clara, volumes de blocos,
telhas azuis, coroa dourada e frente voltada para a ponta inferior do hex.
Sua silhueta usa um salão de um piso e uma única torre lateral. Os próximos
três níveis podem acrescentar altura, alas e mais torres, mantendo reconhecível
o centro original. Os níveis II e III já foram produzidos separadamente em
`city_level_2_hex_v1` e `city_level_3_hex_v1`; o nível IV completa a família
em `city_level_4_hex_v1`.

As muralhas do tile são a **Fortificação**, um sistema independente do City
Level. A torre faz parte da arquitetura do centro; sua existência não concede
escudo, ataque ou bônus de defesa. A integração preserva essas regras.

## Composição para o mapa 4X

- Base pointy-top de raio **0,84**, dentro do tile de raio **1**.
- A base menor deixa espaço para a face interna da muralha de fortificação.
- Salão pentagonal de pedra, traseira seguindo as diagonais do hex,
  contrafortes e cornijas de pedra clara.
- Telhado em degraus, recortado pelo hex em cada camada, sem normalização
  automática por altura na importação.
- Uma torre quadrada baixa com ameias, frestas e faixa de apoio superior.
- Porta dupla, moldura de pedra em degraus, três degraus e lanternas.
- Coroa dourada sobre a entrada, bandeira, bacia de água, banco e canteiros.

## Cor da civilização e integração

`City.CITY_MODELS_BY_LEVEL` escolhe a fonte conforme o City Level. Atualmente
contém os quatro modelos I, II, III e IV. O visual procedural permanece como
fallback de carregamento. Fundação, upgrades e carregamento
reconstroem o visual pelo mesmo caminho usado anteriormente.

A malha `Faction` contém só a placa e a bandeira, pintadas em tom neutro.
`City.gd` duplica seu material por instância e aplica a cor do dono, preservando
o atlas compartilhado. Captura atualiza a bandeira da cidade capturada sem
mudar outras cidades. Pedra, telhado, coroa e hastes mantêm a pintura original.
As prévias Blender mostram o tecido neutro; no jogo ele recebe a cor da civilização.

O modelo escala uniformemente por `tile_radius`. A fortificação, nomes e barras
de HP/escudo continuam sob responsabilidade da cidade, fora do GLB.

## Arquivos e escala

- `city_level_1_hex_v1.blend`: **113 peças editáveis**, cena exclusiva,
  texturas empacotadas e estúdio. Outras cenas abertas preservadas.
- `city_level_1_hex_v1.glb`: **1.496 triângulos**, 8 malhas por grupo,
  1 material fonte. Uma instância de material adicional para a cor da facção
  é criada no jogo, usando os mesmos atlases.
- Atlases albedo/emissão **1024 × 1024**, nearest, 128 px/unidade,
  3 pixels de margem, embutidos no GLB e salvos como PNGs.
- Dimensões: **1,4549 × 1,6800 × 1,2150** (largura × profundidade × altura).
- Origem no centro da base, chão Z=0 no Blender/Y=0 no Godot.
- Frente: −Y no Blender / +Z no Godot.

Prévias: [3/4](previews/three_quarter.png), [câmera elevada](previews/game_top.png),
[planta hexagonal](previews/top.png), [traseira](previews/back.png).

## Reprodução pela conexão MCP

Na raiz do projeto, com Blender e MCP ativos:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/city_level_1_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/city_level_1_hex_v1_finish.py
```

O construtor recusa sobrescrever uma cena existente. Usa as primitivas e helpers
de atlas/estado/export da família de prédios. Paleta e integração estão nas
propriedades da cena. Depois de exportar, reimportar com
Godot `--headless --path . --editor --import`.

## Verificação

Peças fechadas, shading flat, zero arestas não manifold. Export verifica malhas,
triângulos, nearest e hashes dos PNGs embutidos. Limites do hex e folga interna
da fortificação conferidos por vértice, além de escala e chão via
`HexGrid.found_city`. Revisão com duas cores de civilização e fortificação.

Testes aprovados: **117 testes, 615 assertivas**, cobrindo cidade, City Level,
fortificação e novos cenários de escala, captura e transição de modelo.
Colocação no Godot aprovada: nenhum vértice fora do tile, base no chão,
folga interna à muralha e cores de civilização conferidas. A cena temporária
de revisão foi removida.

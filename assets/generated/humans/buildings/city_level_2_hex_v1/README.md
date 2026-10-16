# Centro da Cidade — Nível II / Hex V1

Segundo dos quatro níveis de centro urbano. Evolução do castelo da Cidade I:
salão de dois pavimentos, torre esquerda elevada, nova torre direita mais
baixa e janelas no piso superior. Estilo de blocos, pedra clara, telhado azul,
coroas douradas e pátio cívico. Criado no Blender pela conexão MCP ativa e
integrado em `City.CITY_MODELS_BY_LEVEL` para **Cidade II**.

## Cidade e muralhas independentes

**Não contém muralhas ao redor da cidade.** As ameias pertencem apenas às
duas torres do castelo. A base pointy-top mantém o raio **0,84** do nível I,
dentro do tile de raio **1**, com borda livre para modelos de fortificação.
O maior semiplano ocupado mede 0,72746, abaixo do limite interno da
fortificação existente, 0,76706.

Os três níveis de Fortificação são independentes dos quatro níveis da cidade.
A integração preserva a fortificação procedural existente quando comprada,
sem incorporá-la ao `.blend` ou ao `.glb` do centro. As torres deste modelo
não concedem escudo ou bônus de defesa por conta própria.

## Evolução reconhecível

O salão original ganha 0,24 unidade de altura, um segundo piso e janelas com
molduras de pedra. A torre esquerda cresce e recebe a bandeira; uma torre
direita menor enquadra a entrada. Porta dupla, degraus, coroa, lanternas,
telhado e canteiros preservam a identidade do nível I. Bacia de água e banco
são reposicionados para acomodar a nova torre. O nível III já tem sua evolução
em `city_level_3_hex_v1`; o nível IV completa a família em `city_level_4_hex_v1`.

## Integração e cor da civilização

Fundação, upgrade, captura e carregamento selecionam o modelo pelo nível da
cidade. A instância escala uniformemente por `tile_radius`, sem normalização
pela altura. Nomes, HP, escudo e muralhas são responsabilidade de `City.gd`.

A malha `Faction` contém placa, bandeira e dois pequenos estandartes neutros.
Seu material é duplicado por cidade e recebe a cor do dono, preservando
texturas compartilhadas. Pedra, telhas, coroas e hastes mantêm suas cores.
As prévias Blender mostram tecidos neutros; no jogo eles recebem a cor da
civilização.

## Arquivos e escala

- `city_level_2_hex_v1.blend`: **157 peças editáveis**, cena exclusiva,
  texturas empacotadas e estúdio. A cena do nível I permanece preservada.
- `city_level_2_hex_v1.glb`: **2.088 triângulos**, 8 malhas por grupo e
  1 material fonte. O material de facção é duplicado apenas na instância.
- Atlases albedo/emissão **1024 × 1024**, nearest, 128 px/unidade,
  3 pixels de margem, embutidos no GLB e salvos como PNGs.
- Dimensões: **1,4549 × 1,6800 × 1,3150**, largura × profundidade × altura.
- Origem no centro da base, chão Z=0 no Blender/Y=0 no Godot.
- Frente: −Y no Blender / +Z no Godot.

Prévias: [3/4](previews/three_quarter.png), [câmera elevada](previews/game_top.png),
[planta hexagonal](previews/top.png), [traseira](previews/back.png).

## Reprodução pela conexão MCP

Na raiz do projeto, com Blender e MCP ativos:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/city_level_2_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/city_level_2_hex_v1_finish.py
```

O construtor recusa sobrescrever uma cena existente. Usa a Cidade I aberta
como fonte; se necessário, carrega sua cena do `.blend` salvo. Duplica as
malhas antes de modificá-las. A pintura e exportação usam os helpers da
família de construções. Reimportar com Godot
`--headless --path . --editor --import` após exportar.

## Verificação

Peças fechadas, shading flat, zero arestas não manifold. Exportação verifica
malhas, triângulos, nearest e hashes dos PNGs embutidos. Escala, chão,
limites do hex e espaço para fortificação são conferidos por vértice através
de `HexGrid.found_city`. Revisão visual compara Cidade I e Cidade II sem
fortificação; testes cobrem escala, upgrade, captura e fortificação separada.
Resultados registrados em `city_level_2_hex_v1_report.json`.

Godot: **117 testes aprovados, 620 assertivas**, zero vértices fora do tile,
base apoiada na altura real do chão e folga para a fortificação confirmada.
Uma execução de revisão visual no Godot com os dois níveis lado a lado,
sem muralhas; cena temporária removida após a captura. As suítes existentes
ainda emitem avisos de recursos/instâncias ao encerrar o runner.

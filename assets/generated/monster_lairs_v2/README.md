# Covis de monstros — Aetherlands V2

12 modelos originais criados no Blender aberto, exclusivamente pelo MCP `localhost:9876`.
Abra `index.html` para conferir a galeria ou as pranchas `catalog_three_quarter.jpg` e `catalog_game_top.jpg`.
`monster_lairs_v2_catalog.blend` reúne os 12 covis numa cena, na mesma escala, organizados por espécie.
`comparison.html` e `critical_review.md` mostram a revisão. `map_readability.png` confere os covis
com albedos reais do terreno e inclinação de câmera de 50°, em uma cena isolada do Blender.

## Conceitos

- **Acampamento de saqueadores** (`goblin`): Tenda remendada, paliçada irregular, saque e fogueira apagada.
- **Cripta violada** (`skeleton`): Sepultura aberta e ossário sob um arco funerário partido.
- **Toca das raízes** (`worg`): Abrigo baixo entre raízes de árvore caída, ossos de presas e terra pisada.
- **Ninho de seda** (`giant_spider`): Troncos mortos sustentam teias poligonais, casulos e bolsas de ovos.
- **Abrigo sob a laje** (`troll`): Caverna de blocos pesados, musgo, clava e restos de uma refeição.
- **Poleiro da escarpa** (`wyvern`): Escarpa escalonada com galhos chamuscados, ovos e ossos na plataforma.
- **Labirinto arruinado** (`minotaur`): Paredes baixas em meandro, porta com chifres e troféu de crânio bovino.
- **Ninho da petrificação** (`basilisk`): Ninho de gravetos e palha em rocha árida, ovos manchados e presas petrificadas.
- **Poço de escavação** (`colossal_worm`): Funil profundo entre placas de areia rompida, túneis escuros e cascas segmentadas.
- **Berço de pedra viva** (`arboreal_ancient`): Pedras de espiral ancestral, raízes e musgo em torno de um núcleo verde.
- **Jazida arcana exaurida** (`mana_devourer`): Leito cúbico fraturado, cristais drenados e fendas violetas na rocha.
- **Vigília abandonada** (`corrupted_hero`): Posto militar em ruínas, assento vazio, estandarte gasto e escudo-torre esquecido.

## Arquivos e escala

Cada subpasta contém a fonte `.blend` com as peças separadas e materiais empacotados,
um `.glb` com uma malha / um material, `manifest.json`, README e três renders:
`three_quarter`, `game_top` e `back`. O cenário de estúdio e os anchors de referência
existem somente no Blender e não estão nos arquivos GLB.

Todos os modelos têm origem no chão, escala aplicada, frente -Y no Blender / +Z no glTF.
Raio horizontal máximo de 0,78 m: cabe no hex de raio 1 m, cuja meia largura é 0,866 m.
Albedo e emissão 1024×1024 estão embutidos; amostragem nearest, densidade de 64 px/m.
A emissão discreta só aparece nos vestígios de mana e de pedra viva.
As cavidades são geometria com fundo acima do chão: não exigem cortar o terreno.
As peças são volumes fechados; junções entre pedras, raízes e estrutura podem se intersectar.

## Integração posterior

Esta entrega é exclusivamente de arte. Não modifica `LairStructure.gd`, bancos de monstros,
cenas, importadores, HP, líder, spawn ou lógica de destruição. A estrutura visual pode ser
removida junto com a entidade do covil quando o jogo resolver o golpe de destruição.
Não há colisão, animação nem scripts de runtime no GLB.

A raiz desta pasta tem `.gdignore` de propósito: enquanto ele existir, Godot não importa
nem monitora os novos modelos. Isso evita interferir na sessão e no trabalho paralelo.
Quando a integração for autorizada, remova esse marcador, importe os GLBs e faça o
mapeamento `kind -> <kind>_lair_v2/<kind>_lair_v2.glb` no consumidor visual apropriado.
As prévias, fontes Blender e o atlas de referência podem permanecer fora do runtime.
Siga então a auditoria de texturas BC7 já documentada em `docs/ASSET_FACTORY_GUIDE.md`.

## Verificações

`validation.json` inspeciona o binário de cada GLB: malha e material únicos, texturas
embutidas, nearest, bounds, origem no chão, área dos triângulos, normais, UVs e ausência
de câmeras/luzes de estúdio. `blender_validation.json` registra a reimportação no Blender
e a abertura isolada das fontes. Os 25 arquivos `.blend`/`.glb` dos monstros existentes
são comparados por SHA-256 antes/depois. Nenhum processo Godot é lançado ou interrompido.

Scripts de reprodução e logs: `art_source/monster_lairs_v2/`. Para reproduzir, use
`python art_source/monster_lairs_v2/run_mcp.py --only <kind> --rebuild` com o MCP ativo.
Os scripts também estão copiados em `source_tools/` nesta entrega; preserve a estrutura
original do projeto ao reproduzir. `--rebuild` sobrescreve somente a nova arte desta versão.

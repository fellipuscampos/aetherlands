# Aetherlands (nome provisorio)

[![License: CC BY-NC 4.0](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/)

> **Licenca:** projeto publico sob **CC BY-NC 4.0**, livre pra ver, rodar,
> estudar, modificar e compartilhar (com credito), mas **uso comercial nao
> e permitido** sem autorizacao explicita do autor. Detalhes no arquivo
> [`LICENSE`](LICENSE).

MVP jogavel de um 4X de estrategia por turnos, medieval/fantasia, em 3D, no
estilo "Civilization", construido em **Godot 4** (Forward+ renderer). O loop
completo funciona de ponta a ponta: comeca a partida, explora o mapa, funda
cidades, luta contra a IA rival, vence ou perde, e da pra jogar de novo sem
fechar o jogo. O projeto tambem ja vem com a base tecnica que um jogo desse
porte precisa desde o inicio, para nao ter que recomeçar do zero quando a
complexidade aumentar:

- Mapa hexagonal 3D real, gerado por codigo (`SurfaceTool`) e desenhado com
  `MultiMeshInstance3D` (milhares de tiles em uma unica draw call).
- Shader proprio (`shaders/terrain.gdshader`) rodando no pipeline
  Forward+, com 5 texturas reais CC0 (ambientCG) projetadas em triplanar,
  uma por FAMILIA de bioma, cada uma escolhida pelo material de verdade
  que aquele bioma deveria parecer (nao so "textura de chao generica pra
  tudo"): terreno "comum" (a maioria dos biomas — Planicie, Floresta,
  Colinas etc.) usa `Ground037`; Neve/Gelo Eterno usa `Snow006`; Deserto
  usa `Ground033` (areia); Lava usa `Rock035` (pedra vulcanica escura);
  Campos de Cristal usa `Ice003` (gelo rachado/facetado, tingido na cor
  arcana do bioma). Cada uma das 4 especiais AINDA ganha um efeito
  procedural por cima da textura real (reportado pelo usuario: "os
  biomas nao parecem bem trabalhados... nem pareciam biomas de neve...
  nao vi o de fogo", depois "baixe as texturas corretas de assets pra
  isso"): Neve/Gelo Eterno ganham brilho pontual tipo cristal de gelo
  pegando luz; Deserto ganha ondulacao de duna (faixas); Lava ganha veios
  brilhando por baixo da pedra, pulsando (com EMISSION de verdade, nao so
  cor); Campos de Cristal ganham facetas brilhantes com um leve brilho
  magico (tambem EMISSION). Tiles de oceano ondulam e brilham
  (deslocamento de vertice + glint animado, sem textura nenhuma). Qual
  tratamento cada tile usa vem de um canal extra de "custom data" por
  instancia do MultiMesh (`HexGrid._material_kind_for`, 0-4) que o
  fragment shader interpreta; se algum arquivo de textura faltar no
  disco, o uniform cai no branco padrao (`hint_default_white`) em vez de
  pintar o tile de preto — mesma filosofia de fallback do resto do
  projeto. Normal corrigida por face (`FRONT_FACING`) pra iluminacao
  ficar certa mesmo com culling desligado.
- 16 biomas (antes eram 12, e 6 antes disso) gerados por dois eixos
  independentes, tipo diagrama de Whittaker simplificado, nao e mais so
  uma progressao unica de elevacao: **elevacao** (`FastNoiseLite`) ainda
  decide oceano/colina/montanha, mas a faixa "plana" do meio agora cruza
  **umidade** (segundo ruido) com **temperatura por latitude** (gradiente
  pela distancia ao "equador" do mapa, com uma pitada de ruido nas bordas
  das faixas), Gelo Eterno/Neve/Tundra/Taiga nos "polos" (Gelo Eterno e o
  mais extremo dos quatro, faixa nova, ver bullet abaixo), Planicie/
  Estepe/Floresta na faixa temperada, Deserto/Savana/Selva no "equador".
  Tudo 100% deterministico pela `map_seed` (ver `HexGrid._pick_biome`/
  `_temperature_for`), condicao que Salvar/Carregar depende pra recriar o
  terreno so com a semente. Arvores proceduralmente espalhadas em
  Floresta/Taiga/Selva e pedras em Colinas/Montanhas, tambem via
  `MultiMesh`, tambem respeitando a neblina de guerra. **Regioes de
  verdade, nao "sal e pimenta"** (reportado pelo usuario: "um monte de
  celula distribuida aleatoriamente... isso nao e bioma de fato"): as
  frequencias do ruido de elevacao/umidade/vulcanico/arcano eram altas
  demais pro tamanho do mapa (um ciclo de ruido a cada 6-8 tiles, dado
  que o `FastNoiseLite` ja soma 5 octavas de FBM por padrao), entao bioma
  virava tile a tile em vez de regiao continua. Baixadas
  significativamente (elevacao/umidade de 0.15/0.12 pra 0.025/0.02,
  vulcanico/arcano de 0.06/0.1 pra 0.02/0.025) — mesma distribuicao MEDIA
  de cada bioma no mapa (frequencia nao muda os limiares nem a fracao
  esperada de cada tipo), so a correlacao espacial fica maior, formando
  continentes/regioes coerentes com litoral irregular (as octavas
  fractais continuam dando o detalhe fino nas bordas). Medido
  empiricamente: media de vizinhos do mesmo bioma foi de ruido quase
  puro pra ~75% (`test_generate_map_biomes_form_contiguous_regions_
  not_scattered_cells`).
- 4 biomas novos (pedido do usuario: "quero que tenha rios, mares,
  biomas de gelo... bioma de lava, algum outra bioma de fantasia... se
  quiser aprofunde a tematica de fantasia"), todos 100% deterministicos
  pela `map_seed` igual todo o resto do terreno:
  - **Mar Gelado** ("os mares"): variante polar do Oceano, mesma agua mas
    fria demais pra peixe (yield zerado) e SEM a animacao de onda/brilho
    do Oceano comum (`shaders/terrain.gdshader`, canal `v_animate_waves`
    separado de `v_is_water` — os dois contam como agua pra jogabilidade,
    so um dos dois anima).
  - **Gelo Eterno**: bioma de terra firme mais severo que Neve, a faixa
    de temperatura mais fria de todas (`HexGrid._pick_biome`).
  - **Lava**: bioma vulcanico raro (~1 em cada 3-4 Montanhas/Colinas cujo
    ruido vulcanico secundario passa de um limiar alto,
    `HexGrid._pick_mountain_biome`), intransitavel pra qualquer unidade
    terrestre (`HexTileData.blocks_land_units()`, so unidade que voa
    atravessa) e nao pode ser trabalhado por nenhuma cidade — obstaculo
    de verdade, nao so decoracao.
  - **Campos de Cristal**: bioma arcano ORIGINAL (nao sugerido pelo
    usuario, "aprofundar a tematica de fantasia" como fez sentido —
    combina com Torre Arcana/Mago ja existentes), raro e disperso
    (`HexGrid._maybe_crystal`), ouro alto recompensa explorar/se
    assentar perto.

  No tamanho **Grande** (ou maior), TODO tipo de bioma — os 4 novos e os
  16 no total — aparece pelo menos uma vez garantido
  (`HexGrid._ensure_biome_variety`, chamado dentro de `generate_map()`):
  reportado pelo usuario que os biomas raros as vezes simplesmente nao
  apareciam no mapa gerado. Continua 100% probabilistico nos tamanhos
  Pequeno/Medio de proposito ("nos outros talvez faça sentido ter
  menos", palavras do usuario — mantem a sensacao de descoberta nesses
  tamanhos). Biomas frios/quentes preferem o tile de temperatura mais
  EXTREMA disponivel entre os candidatos elegiveis (o mais frio pra
  Neve/Tundra/Taiga/Gelo, o mais quente pra Deserto/Savana/Selva), e
  nenhum tile forcado fica perto demais do centro do mapa (mesma
  distancia minima que os Covis de Monstro respeitam), pra nunca
  estragar o comeco de jogo do humano com, por exemplo, um tile de Lava
  bem do lado da capital.
- **Continentes de verdade, nao um retangulo de terra unico** (reescrita
  do algoritmo de geracao, `HexGrid.generate_map`/`_elevation_for`):
  antes a elevacao vinha de um unico `FastNoiseLite` sem mascara nenhuma
  de borda, entao com frequencia baixa (necessaria pra formar regioes
  coerentes, ver bullet acima) o mapa quase sempre virava uma unica massa
  de terra retangular colada nas quatro bordas, com biomas em retalhos
  por cima. Agora a elevacao usa uma **mascara de borda** (`_edge_falloff`,
  distancia Chebyshev ate o centro do mapa — respeita o formato
  RETANGULAR, nao so os cantos) subtraida do ruido de continente, o que
  garante oceano nas bordas e concentra a terra em continentes/ilhas
  separados; e **domain warping** (`_warp_world`, um segundo
  `FastNoiseLite` deslocando as coordenadas antes de amostrar
  elevacao/umidade/vulcanico/arcano) pra litoral e fronteiras de bioma
  organicos em vez de contornos com cara de "curva de nivel". Umidade
  ganhou um **bonus litoraneo** que decai com a distancia ate a agua mais
  proxima (`_coastal_distance_by_coord`, BFS multi-fonte a partir de todo
  tile de agua) — regiao perto da costa fica mais verde/umida que o
  interior, geografia real, e ajuda a transicao Deserto -> Savana ->
  Estepe -> Floresta fazer sentido (deserto nasce longe da costa, nao
  colado nela). Vulcanico e Campos de Cristal deixaram de ser "ruido puro
  acima de um limiar em qualquer terreno" e passaram a exigir elegibilidade
  tematica antes de rolar o ruido (`_is_volcanic_eligible`/
  `_is_crystal_eligible`): Lava so em terra QUENTE perto do oceano/fenda
  OU em Montanha (nunca no meio frio do continente); Campos de Cristal so
  numa transicao fria Colina/Montanha (tundra encontrando montanha) OU
  numa ilha pequena isolada (`_land_component_size_by_coord`, tamanho da
  massa de terra conectada), nunca espalhado em qualquer planicie comum.
  Todos os parametros (frequencia de continente/warp/umidade/vulcanico/
  arcano, forca e raio da mascara de borda) viraram `@export` no
  Inspector do node `HexGrid` — dando pra ajustar tamanho/quantidade de
  continentes sem editar o script. A tabela de decisao de bioma
  (`HexGrid._BIOME_TABLE`, temperatura x umidade) tambem virou um
  dicionario explicito em vez de um if/elif encadeado, pra dar pra
  reajustar qual bioma cada combinacao produz olhando uma unica tabela.
- Rios de verdade (pedido do usuario: "quero que tenha rios",
  `HexGrid._generate_rivers`/`river_edges`): nascem em terreno alto
  (Montanha ou Colina) escolhido por um ruido dedicado, e a agua desce
  gulosamente sempre pro vizinho ainda nao visitado de MENOR elevacao
  (o mesmo ruido que decide oceano/colina/montanha) ate chegar em agua
  ou ficar sem pra onde descer — sem pathfinding de verdade, o proprio
  gradiente de elevacao ja da o caminho. Desenhados como uma faixa azul
  ao longo da aresta entre os dois tiles (mesma tecnica de geometria do
  contorno de territorio da cidade, `HexMetrics.corner`), e todo tile
  encostado num rio rende +1 comida quando trabalhado
  (`City.effective_tile_yield`, `HexTileData.has_river`). Escopo desta
  rodada: rios ficam SEMPRE visiveis, ainda nao reagem a fog of war
  (diferente do terreno em si) — fog-gating por aresta individual exigia
  uma malha por segmento (ou recalcular tudo a cada mudanca de fog),
  escopo maior do que o pedido cobria.
- Mapas bem maiores (pedido do usuario: "o mapa pode ficar bem maior...
  dentro das limitacoes que temos"): Pequeno/Medio/Grande eram raio
  8/12/16 (217/469/817 tiles), agora sao 25/30/37 (1951/2791/4219 tiles),
  aproximando os tamanhos Pequeno/Padrao/Grande do proprio Civilization
  (~2016/2772/4160 tiles, grade retangular, mas comparavel por contagem).
  Medido empiricamente antes de decidir (`test_terrain_generation.gd`,
  `test_generate_map_at_large_radius_completes_quickly`): gerar o mapa
  raio 37 leva uns 60-90ms nesta maquina, entao a folga era grande o
  bastante (testado ate raio 45, ~6200 tiles, ainda menos de 100ms) pra
  nao precisar ficar so na margem do que Civilization usa. Camera
  (`RTSCamera.pan_bounds`) e minimapa ja escalavam com `map_radius`
  automaticamente, sem limite fixo em nenhum dos dois.
- Ambiente com glow, fog de distancia sutil e SSAO ativados (Forward+),
  alem do ceu e luz direcional com sombra.
- O jogador (nome do reino escolhido na tela de titulo) contra 1 a 3
  civilizacoes rivais (escolhido tambem na tela de titulo), cada uma uma
  civilizacao de fantasia de VERDADE, nao mais uma copia generica do
  reino do jogador so trocando nome/cor: Reino Elfico de Verdemata,
  Reino Anao de Ferroeste e Horda Orc das Brumas (nome/lider/cor/raca
  proprios, ver `GameManager.RIVAL_CIVS`), todas com IA propria em 100%
  GDScript sem depender de nenhum plugin externo (`RivalAI.gd`), capital,
  guarda e colonizadores que agem sozinhos. A IA avalia o resultado
  PROVAVEL de um combate antes de atacar (mesma formula do combate de
  verdade, via `CombatResolver.predict()`) em vez de brigar as cegas,
  recua pra perto da propria cidade quando esta fraca, e prioriza
  capturar cidade indefesa sobre uma escaramuca.
- Diplomacia (`Diplomacy.gd`): cada rival comeca em guerra com o jogador
  (mesmo comportamento de sempre antes disso existir), mas agora e
  reversivel pelo botao "Diplomacia" na HUD, "Propor Paz" pode ser
  recusado pela IA (aceita se estiver em desvantagem numerica ou
  empatada; `Diplomacy.propose_peace`), "Declarar Guerra" e sempre
  imediato. Em paz, nenhum dos dois lados consegue atacar o outro
  (`SelectionManager`/`RivalAI` respeitam `PlayerData.is_at_war_with`).
  Escopo desta rodada: so o jogador negocia ativamente, civs rivais
  nunca brigam entre si nem propoem paz sozinhas (evita uma guerra de
  todos contra todos dificil de acompanhar/balancear).
- Covis de Monstro (`MonsterDatabase.gd`, `HexGrid._spawn_monster_lairs`):
  espalhados pelo mapa (longe do centro, pra nunca cair em cima do inicio
  do jogador), guardados por um monstro NEUTRO, Goblin, Troll ou Vivern
  (raro, o que mais paga), sorteio ponderado deterministico pela semente.
  Hostil a todo mundo, sem diplomacia possivel (`SelectionManager`/
  `PlayerData.is_at_war_with` nao se aplicam a ele). Vencer o guardiao
  (jogador OU rival) saqueia ouro na hora (`UnitData.gold_reward`,
  `CombatResolver.resolve`); perder custa a unidade atacante, risco
  contra recompensa, motivo real pra explorar alem da propria fronteira
  em vez de so brigar com o rival mais perto. Escopo desta rodada: guardam
  o proprio tile pra sempre, nunca perseguem ninguem (nao entram em
  nenhuma `PlayerData.units`, entao `GameManager`/`RivalAI` nunca os
  processam num turno). Da pra avaliar o risco ANTES de atacar: clicar no
  tile do covil mostra quem guarda, HP e a recompensa em ouro
  (`HUD._on_tile_selected`), e passar o mouse sobre ele com uma unidade
  selecionada mostra "ATACAR <nome>" em vez de um generico "ATACAR"
  (`SelectionManager._attack_target_name`, vale pra qualquer alvo, nao so
  monstro).
- Covil de Monstro, progressao/persistencia (`HexGrid.gd`,
  `MonsterDatabase.gd`, `SaveManager.gd`): reforco/patrulha turno a turno
  passou a usar um `RandomNumberGenerator` DEDICADO
  (`HexGrid.monster_turn_rng`, semeado por `map_seed`) em vez de
  `randf()`/`randi()` globais — determinismo real, e o `.state` dele agora
  e salvo (como STRING, pra nao perder precisao de inteiro 64-bit virando
  float no JSON) e restaurado no load, entao a sequencia de sorteios futura
  continua exatamente de onde parou em vez de reiniciar do turno 0. Todo o
  mapa de monstros neutros (guardiao sobrevivente, reforco, resultado de
  patrulha) e salvo por inteiro (`HexGrid.neutral_units`/
  `clear_neutral_units`), nao so "quais covis foram limpos" — reforcos
  gerados durante a partida deixaram de sumir ao salvar/carregar.
  Progressao por AMEACA (`HexGrid._threat_level`, distancia do centro do
  mapa MAX turno atual, nunca soma): covil perto do centro (onde a capital
  tende a nascer) so sorteia Goblin, nunca Troll/Vivern por azar
  (`MonsterDatabase.KIND_MIN_THREAT`) — so regiao profunda do mapa destrava
  os tipos mais fortes; reforco (sempre do MESMO tipo do guardiao original,
  isso nunca muda) fica mais frequente conforme o turno avanca
  (`_reinforce_chance`). Covil CHEIO (`LAIR_SPAWN_CAP`) ou sem tile livre
  pro reforco sorteado faz um moradore patrulhar pra outro tile da PROPRIA
  area em vez de ficar parado pra sempre (`_maybe_roam_lair` — nunca sai do
  territorio do proprio covil, nunca gasta `movement_points`, que
  continuam 0 por design).
- Fog of war de verdade pra IA rival (`HexGrid.compute_visible_tiles()` +
  `PlayerData.known_enemy_cities`): ela so mira em unidades inimigas que
  estao VISIVEIS agora pras proprias tropas dela, nao no mapa inteiro
  como antes. Cidade inimiga, por nao andar, entra numa memoria
  permanente assim que escoutada uma vez, continua alvo valido mesmo
  fora de visao depois, como em qualquer 4X de verdade.
- Coordenacao tatica basica: unidade a distancia (arqueiro) sem nenhum
  aliado corpo-a-corpo por perto nao avanca sozinha pra cima de um alvo,
  fica esperando escolta em vez de virar presa facil isolada na linha de
  frente. Ainda revida normalmente se algo entrar no alcance dela.
- Cura por guarnicao: qualquer unidade (sua ou do rival) parada dentro da
  propria cidade recupera 25% do HP maximo por turno, da uma razao real
  pra recuar em vez de so morrer lutando.
- Oito tipos de unidade, Colonizador, Guerreiro, Arqueiro (ataque a
  distancia, 2 tiles, sem sofrer contra-ataque), Cavaleiro (movimento 4, o
  dobro do normal), Catapulta (cerco: o maior ataque do jogo, mas lenta e
  fragil), Mago (ataque magico que ignora o bonus de defesa de terreno do
  defensor), Grifo (`UnitData.flies`, voa por cima de QUALQUER terreno a
  custo fixo de 1/tile e atravessa oceano livremente, algo que nenhuma
  outra unidade consegue; ver `HexGrid.compute_reachable`) e Ent
  (`UnitData.regen_fraction`, lento (1 de movimento) mas se regenera
  sozinho TODO turno em qualquer lugar do mapa, sem precisar guarnecer
  numa cidade como o resto do exercito; ver `GameManager._apply_regen`),
  com movimento por pontos (custo de terreno via Dijkstra simplificado),
  selecao, e destaque visual dos tiles alcancaveis (verde) e atacaveis
  (vermelho, calculado pelo alcance real da unidade).
- Tropas exclusivas por civilizacao (`CivilizationData.race`,
  `RivalAI.RACE_UNIQUE_KIND`): alem do elenco comum acima, cada
  civilizacao de fantasia rival tem UMA tropa que so ela treina, pra
  reforcar a identidade racial na hora do combate, nao so no nome/cor.
  Anoes (Reino de Ferroeste): Guarda-Machado Anao, baixo e largo, mais
  HP/defesa que o Guerreiro comum mas so 1 de movimento. Orcs (Horda das
  Brumas): Berserker Orc, o maior ataque corpo-a-corpo do jogo, mas sem
  quase nenhuma defesa, todo o investimento e ofensivo. Elfos (Reino
  Elfico de Verdemata): Patrulheiro Elfico, alcance 3 (maior que os 2 do
  Arqueiro comum) e o movimento/visao mais altos entre unidades
  terrestres, HP baixo. Escopo desta rodada: so a IA rival usa isso
  (`RivalAI.decide_production`/`_military_kinds_for`) — o jogador humano
  nao tem raca ainda (`CivilizationData.race` fica vazio pra ele), entao
  encontra essas tropas so como inimigo, nao consegue treinar nenhuma;
  escolher a propria raca fica pra uma rodada futura.
- Veterania: unidade que vence um combate (mata o alvo, ou sobrevive
  matando quem a atacou no contra-ataque) ganha abates e sobe de nivel em
  thresholds fixos, Recruta -> Veterano -> Elite -> Lendario, com +10%
  de ataque E defesa por nivel (`CombatResolver.predict()` aplica) e uma
  cura parcial na hora exata da promocao. Da um motivo real pra manter
  unidades experientes vivas em vez de sempre produzir novas.
- Previa de trajeto ao passar o mouse (estilo Civilization): com uma
  unidade selecionada, o tile sob o cursor fica destacado em amarelo com
  o caminho ate ele e o custo em pontos de movimento, ou "ATACAR" se for
  um alvo inimigo no alcance.
- Barra de vida sempre visivel sobre cada unidade (sua ou inimiga, sujeita
  a neblina de guerra), some quando a unidade esta com vida cheia pra
  nao poluir a tela, aparece assim que ela leva o primeiro dano. Numeros
  de dano flutuantes sobem e somem no momento do combate.
- Movimento animado (a unidade desliza ate o destino e vira de frente pra
  direcao que anda) em vez de teletransportar, so a apresentacao, a
  logica do turno ja atualiza na hora.
- Combate com HP, ataque/defesa e bonus de defesa de terreno (colinas,
  florestas, montanhas). Unidades a distancia atacando de fora do alcance
  corpo-a-corpo do alvo nao sofrem contra-ataque. Cidades sem unidade
  defensora podem ser capturadas (mudam de dono) por quem atacar, sem
  isso a condicao de vitoria seria inatingivel.
- Fundacao de cidades (consome o Colonizador), com crescimento populacional
  por comida e fila de producao escolhivel entre os tipos de unidade
  desbloqueados pelo jogador; a IA rival varia sozinha o que produzir
  (e respeita o mesmo bloqueio por tecnologia). Cidades usam uma forma
  procedural (torre + telhado, cor da propria civilizacao, `City.
  _build_visual_procedural()`), assim como toda unidade (ver bullet "Oito
  tipos de unidade" abaixo). O jogo chegou a usar modelos 3D reais
  importados (Kenney Castle Kit pra cidade, Quaternius RPG Character Pack
  pra Colonizador/Guerreiro/Arqueiro) mas foi revertido a pedido do
  usuario, formas nao combinavam com o resto do visual do jogo, ver
  roadmap item 19.
- Predios de cidade posicionaveis (`BuildingData.gd`/`BuildingDatabase.gd`/
  `Building.gd`): entram na MESMA fila de producao das unidades
  (`City.production_item` aceita um kind de unidade ou um id de predio).
  Duas familias: predios de PRODUCAO, Celeiro (+2 comida), Oficina
  (+2 producao), Mercado (+2 ouro) e Muralhas (+50% de defesa pra unidade
  guarnicionada na cidade, ignorado pelo Mago igual bonus de terreno); e
  predios de TREINO, um pra cada tropa de combate (Quartel/Guerreiro,
  Campo de Tiro/Arqueiro, Estabulo/Cavaleiro, Arsenal de Cerco/Catapulta,
  Torre Arcana/Mago, Poleiro de Grifos/Grifo, Bosque Druida/Ent) — ver
  bullet "Cada tropa exige o predio de treino certo" abaixo pra essa regra
  nova. Diferente de unidade, completar um predio nao "gasta" nada: fica
  valendo pra sempre e cada cidade so constroi cada um UMA vez. Ao
  escolher um predio, o jogador ESCOLHE O TILE onde ele vai ficar (um
  vizinho livre da cidade), do mesmo jeito que escolhe onde fundar uma
  cidade, e o modelo 3D aparece de verdade no mapa quando a producao
  completa (`HexGrid.place_building`), com uma forma procedural distinta
  por tipo (silo pro Celeiro, galpao+chamine pra Oficina, banca com toldo
  pro Mercado, segmentos de parede pras Muralhas, fortim com ameias pro
  Quartel, alvo num poste pro Campo de Tiro, celeiro com telhado duplo
  pro Estabulo, galpao com braco de catapulta encostado pro Arsenal de
  Cerco, torre fina com orbe pra Torre Arcana, poleiro elevado com
  telhado pro Poleiro de Grifos, arvore sagrada + pedras pro Bosque
  Druida). Numero total de predios (producao + treino somados) e limitado
  pela populacao da cidade, 1 predio por ponto de populacao
  (`City.max_building_slots()`), entao uma vila que nunca cresceu nao
  acumula varios predios de uma vez; o painel da cidade mostra o limite
  atual ("Predios: 1/2") mesmo antes de esbarrar nele. Enquanto um predio
  esta em obra, um marcador animado (guindaste girando e balancando,
  `HexGrid.refresh_construction_markers`) fica visivel no tile escolhido
  ate a construcao terminar de verdade. Escopo desta rodada: so a cidade
  do jogador constroi predios, a IA rival continua so produzindo unidades
  (e por isso fica de fora do gate de predio de treino tambem, ver
  bullet abaixo).
- Cada tropa de combate segue uma cadeia de 3 passos antes de poder ser
  produzida: PESQUISAR a tecnologia certa libera CONSTRUIR o predio de
  treino correspondente (`City._tech_unlocked_for_building()`, checado
  dentro de `can_build()` — o botao do predio so aparece habilitado
  depois de pesquisado), e so com o predio ja construido NESSA cidade a
  tropa fica liberada pra TREINAR (`City.can_train()`). Dois pedidos do
  usuario, em sequencia: "cada tropa e feita numa construcao... so pode
  treinar as tropas na sua respectiva construcao" (o gate do predio) e,
  na rodada seguinte, "so posso construir esses predios especiais quando
  pesquisar a tecnologia, ai aparece disponivel pra construir" (o gate da
  pesquisa sobre o PREDIO, nao mais so sobre a tropa direto). A tecnologia
  exigida pelo predio nao e um campo novo/duplicado: e derivada achando
  qual tech tem `unlocks_unit` igual ao `trains_unit` do predio
  (`TechDatabase.tech_that_unlocks()`), reaproveitando o mapeamento
  tropa->tecnologia que a arvore de tecnologia ja tinha. Colonizador e
  Guerreiro ficam de fora do gate de PESQUISA (nenhum dos dois nunca
  exigiu tech nenhuma) — Guerreiro ainda assim exige o Quartel construido,
  so nao exige pesquisar nada pra isso; Colonizador fica de fora dos dois
  gates e e o default seguro de producao de uma cidade recem-fundada. Na
  HUD, todo botao bloqueado (de tropa OU de predio) mostra um tooltip
  explicando o proximo passo exato: pesquisar ou construir
  (`HUD._production_lock_reason`/`_building_lock_reason`) — sem isso o
  botao desabilitado pareceria "nao fazer nada", o mesmo tipo de confusao
  ja corrigido antes pro progresso de producao (ver secao de bugs).
  Escopo desta rodada: so vale pro jogador humano, a IA rival nunca
  constroi predio nenhum (limitacao ja existente, ver bullet acima) entao
  continua escolhendo producao so por tecnologia desbloqueada
  (`RivalAI.decide_production`), sem passar pelo gate de predio de treino
  — senao a IA nunca teria como produzir tropa de combate nenhuma.
- Contorno de territorio SEMPRE visivel (tipo a borda cultural do
  Civilization, `HexGrid._update_city_border`): toda cidade (sua ou
  rival) tem uma linha na cor da propria civilizacao contornando seu
  territorio (ela mesma + vizinhos, o mesmo raio usado por worked_tiles e
  posicionamento de predio), sujeito a fog of war igual o resto da cidade
  (so aparece se voce ja viu aquele tile). Capturar uma cidade reconstroi
  o contorno na cor do novo dono. Substitui um destaque anterior que so
  aparecia com a cidade selecionada.
- Tiles trabalhados por cidadao: cada ponto de populacao trabalha UM tile
  vizinho (o tile da propria cidade sempre conta de graca, fora disso),
  a cidade so rende o que os cidadaos realmente estao trabalhando, nao
  mais a soma automatica de todos os vizinhos. Preenchido automaticamente
  ao fundar/crescer (prioriza melhor rendimento), mas o jogador pode
  trocar clicando nos botoes de "Tiles trabalhados" no painel da cidade;
  duas cidades vizinhas nao podem disputar o mesmo tile
  (`City.auto_assign_worked_tiles`/`toggle_worked_tile`,
  `HexGrid.is_tile_worked`).
- Arvore de tecnologia (`TechData.gd`/`TechDatabase.gd`, 11 tecnologias com
  alguns pre-requisitos): Arqueiro/Cavaleiro/Catapulta/Mago/Grifo/Ent
  comecam BLOQUEADOS ate pesquisar Tiro com Arco / Equitacao / Engenharia /
  Arcanismo / Adestramento de Grifos (esta ultima exige Equitacao, a
  progressao "aprende a montar cavalo" -> "aprende a montar grifo" faz
  sentido tematico) / Druidismo, antes disponiveis de graca desde o inicio;
  as outras tecnologias dao bonus permanente de rendimento em biomas especificos
  (Agricultura/Irrigacao em Planicie-Estepe/Deserto, Mineracao/Metalurgia
  em Colinas-Montanhas/Floresta-Taiga-Selva, Pecuaria em Savana/Tundra),
  continua valendo pesquisar mesmo depois de ja ter as unidades novas.
  "Ciencia" e simples de proposito: soma da populacao de todas as cidades
  por turno, sem precisar de mais um tipo de yield no terreno. Escolha
  pelo botao "Tecnologia" na barra superior; a IA rival pesquisa sozinha
  (`RivalAI.decide_research`) e nunca tenta produzir uma unidade que ainda
  nao desbloqueou.
- Recursos estrategicos/luxo nos tiles (`ResourceDatabase.gd`): Ferro
  (colinas/montanhas), Cavalos (planicie/estepe/savana), Gemas e Seda
  (floresta/taiga/selva) aparecem espalhados de forma esparsa e 100%
  deterministica pela semente do mapa, dando bonus de rendimento quando o
  tile e trabalhado. Limitacao conhecida (documentada no proprio
  `ResourceDatabase.gd`): so afetam yield por enquanto, nao gate a
  producao de nenhuma unidade especifica (ex: Cavaleiro nao exige acesso
  a Cavalos), isso exigiria rastrear acesso por cidade/jogador, escopo
  maior do que essa rodada cobriu.
- Fog of war por civilizacao: tiles nunca vistos ficam escuros, tiles ja
  explorados mas fora de visao ficam esmaecidos, tiles visiveis aparecem
  normalmente. Unidades e cidades inimigas so aparecem quando estao
  realmente dentro da visao atual, nao ficam "reveladas" so por ja terem
  sido vistas uma vez.
- Condicao de vitoria/derrota: eliminar todas as unidades e cidades do
  adversario (o seu ou dele) encerra a partida, com banner na tela (turnos
  jogados, cidades, unidades e ouro no final) e botao **"Jogar Novamente"**
  que gera um mapa novo e reinicia tudo sem precisar fechar o Godot.
- Painel de ajuda em jogo (botao "? Ajuda" na barra superior) com o resumo
  dos controles, ninguem precisa ler este README pra jogar.
- Notificacoes em tela (combate, cidade fundada/capturada/perdida), sem
  isso um ataque do rival fora da camera passaria despercebido.
- Minimapa (canto superior direito) desenhado a mao a partir dos dados do
  grid, mostra terreno explorado, unidades e cidades (respeitando a
  neblina de guerra), e clicar nele reposiciona a camera na hora.
- Resumo do imperio (cidades/unidades) e ouro sempre visiveis na barra
  superior, ao lado do turno atual.
- Nome e populacao de cada cidade flutuando sobre ela no mundo 3D
  (`Label3D` com billboard), pra nao precisar clicar pra saber de quem e.
- Camera de estrategia (pan / zoom / rotacao) com limites proporcionais ao
  tamanho real do mapa, que volta pra posicao inicial ao reiniciar.
- Musica de fundo em loop e efeitos sonoros (clique, combate, fundacao/
  captura de cidade, vitoria/derrota) via o autoload `AudioManager`, que
  so escuta sinais que ja existiam, nenhum outro sistema precisa saber
  que audio existe.
- Tela de titulo antes da partida: escolher nome do reino, tamanho do mapa
  (Pequeno/Medio/Grande), numero de reinos rivais (1 a 3) e dificuldade
  (Facil/Normal/Dificil) pra um jogo novo, ou carregar a partida salva
  (botao "Carregar Jogo" so fica habilitado se existir um save). O mundo
  3D so comeca a existir depois dessa escolha, antes disso a HUD fica
  escondida e so a tela de titulo responde a cliques.
- Dificuldade (`GameManager.DIFFICULTY_MULTIPLIERS`): Facil/Normal/Dificil
  multiplica (0.75x/1x/1.5x) o rendimento de comida/producao/ouro de cada
  cidade RIVAL (`PlayerData.yield_multiplier`, aplicado em
  `City.collect_yields()`), o jogador humano fica sempre em 1.0, so a
  economia da IA muda de velocidade. Escolhida na tela de titulo,
  sobrevive a save/load.
- Configuracoes (botao "Configuracoes" na tela de titulo e no menu de
  pausa, mesmo painel reutilizado nos dois lugares, `SettingsPanel.tscn`/
  `.gd`): sliders de volume de musica e efeitos, persistidos em
  `user://settings.cfg` via `ConfigFile` (autoload `Settings.gd`,
  independente do save de partida) e aplicados na hora pelo
  `AudioManager`.
- Salvar/carregar partida (botao "Salvar" na barra superior, salva em
  `user://savegame.json`): guarda so o estado logico (semente do mapa +
  raio recriam o terreno identico, sem precisar serializar cada tile; ouro,
  unidades com hp/movimento/posicao/veterania, cidades com
  populacao/producao/fila, tecnologia, diplomacia, turno atual, tiles ja
  explorados) pra QUALQUER numero de rivais, e reconstroi tudo chamando os
  mesmos caminhos de spawn/fundacao de um jogo novo (`SaveManager.gd`).
- Menu de pausa (tecla **Esc** ou botao "Menu" na barra superior,
  `PauseMenu.gd`): congela o jogo de verdade via `get_tree().paused`
  (camera, animacoes e cliques no mundo param sozinhos, so o proprio menu
  continua respondendo, via `PROCESS_MODE_ALWAYS`) e deixa salvar, carregar
  outra partida ou voltar ao menu principal sem fechar o jogo.
- Painel de Debug (botao "Debug" na barra superior, so aparece rodando
  pelo editor/export de debug — `OS.is_debug_build()`, nunca visivel num
  export de release pro jogador ver; pedido do usuario: "adicione opcoes
  debug onde eu posso tirar a fog do mapa e coisas assim"): **Revelar
  Mapa** desliga a neblina de guerra na hora e mostra o mapa inteiro
  (`HexGrid.set_debug_fog_disabled`, um botao pra ligar/desligar de novo);
  **+100 Ouro**; **Completar Pesquisa Atual** (reaproveita
  `GameManager._process_research()` de verdade, so garante progresso
  suficiente antes); **Vencer Agora**/**Perder Agora** forcam o fim de
  jogo na hora (`GameManager.debug_force_game_over`, mesmo sinal
  `EventBus.game_over` do fim de jogo real) sem precisar eliminar
  unidade/cidade nenhuma, util pra testar a tela de vitoria/derrota sem
  jogar uma partida inteira. Mesma regra de "so um overlay por vez" dos
  outros paineis (Ajuda/Tecnologia/Diplomacia).
- Redesenho visual completo da interface (`UITheme.gd`): antes disso nenhuma
  tela tinha nenhum `Theme`, cada painel renderizava no cinza padrao do
  Godot com espacamento/fonte proprios, sem nenhuma consistencia entre
  telas. Agora um Theme unico (paleta "pergaminho antigo", marrom bem
  escuro + dourado/bronze, sem depender de nenhum asset externo) e montado
  por codigo e aplicado em HUD/TitleScreen/PauseMenu, cascateando
  automaticamente pra todo painel filho (`SettingsPanel` incluso, sem
  precisar setar o tema duas vezes). Todo painel modal (Ajuda/Tecnologia/
  Diplomacia) ganhou o mesmo cabecalho (titulo + botao "X" pra fechar) e um
  fundo escurecido atras dele (`HUD.overlay_backdrop`), deixando claro o
  que esta em primeiro plano.
- Arvore de tecnologia com layout de arvore de verdade (`TechTree.gd`):
  antes o painel so mostrava as tecnologias disponiveis como uma fileira
  de botoes soltos e as ja pesquisadas como uma frase de texto corrida,
  sem nenhuma nocao visual de ramificacao ou pre-requisito. Agora cada
  tecnologia e um card posicionado por coluna (tier = quantos passos de
  pre-requisito ate a raiz, `TechTree._compute_tiers()`), com linhas
  conectando pre-requisito -> tecnologia desbloqueada e 4 estados visuais
  distintos (bloqueada, disponivel, pesquisando com barra de progresso,
  pesquisada).
- Arquitetura data-driven: terrenos, unidades e civilizacoes sao `Resource`
  (`HexTileData`, `UnitData`, `CivilizationData`), prontos para virar arquivos
  `.tres` editaveis por um game designer sem mexer em codigo.
- Autoloads (singletons) para estado global: `GameManager`, `TurnManager`,
  `EventBus`, `SelectionManager`, `Settings`, `AudioManager`, `SaveManager`,
  separando logica de jogo, turnos, selecao, comunicacao UI/mundo,
  preferencias do jogador, audio e persistencia.
- Estrutura de pastas pronta para crescer (assets, resources, addons).

## Como rodar

1. Instale o **Godot 4** (Forward+/Compatibility, engine gratuita e open source):
   https://godotengine.org/download
2. Abra o Godot, clique em "Importar" e selecione a pasta deste projeto
   (`project.godot`).
3. Aperte **F5** (ou o botao Play) para rodar. A cena inicial e
   `scenes/main/Main.tscn`. A janela abre maximizada (`project.godot`,
   secao `[display]`, `window/size/mode=2`) numa resolucao base de
   1600x900 (`viewport_width`/`viewport_height`) — sem essa secao o Godot
   caia no padrao de 1152x648, bem pequeno num monitor atual.

## Controles e como jogar (prototipo atual)

- `W A S D` ou setas: mover a camera
- `Q` / `E`: rotacionar a camera
- Scroll do mouse: zoom
- Clique esquerdo numa unidade sua: seleciona e mostra tiles alcancaveis
  (verde) e inimigos atacaveis (vermelho), o alcance de ataque respeita o
  tipo de unidade (Arqueiro ataca a 2 tiles, o resto e corpo-a-corpo)
- Passe o mouse sobre um tile alcancavel com uma unidade selecionada: veja
  o trajeto ate la destacado em amarelo e o custo em pontos de movimento
- Clique esquerdo num tile verde: move a unidade selecionada ate la
- Clique esquerdo num tile vermelho: ataca a unidade inimiga (ou **captura**
  a cidade inimiga adjacente/no alcance se ela estiver sem defensor)
- Com um Colonizador selecionado: botao "Fundar Cidade" no canto inferior
  esquerdo funda uma cidade no tile atual (consome o colonizador)
- Clique numa cidade sua: painel no canto inferior direito mostra populacao
  e producao atual, com botoes para trocar entre unidades ou predios
  (trocar zera o progresso acumulado do item anterior). Toda cidade tem um
  contorno na cor da civilizacao ao redor do territorio, sempre visivel no
  mapa (nao precisa clicar). Ao escolher um predio, clique num tile azul
  destacado pra posiciona-lo (como fundar uma cidade); um guindaste
  animado marca o tile enquanto a obra roda, e o modelo real so aparece
  quando a producao terminar
- Botao "Finalizar Turno": reseta movimento das unidades, processa
  crescimento/producao das cidades, a IA rival age, e recalcula a neblina
  de guerra
- Clique no minimapa (canto superior direito): centraliza a camera naquele
  ponto do mapa, util pra voltar rapido pra sua capital ou checar onde a
  IA rival apareceu

Comece com 1 Colonizador + 1 Guerreiro perto do centro do mapa. Funde sua
primeira cidade cedo, produza Colonizadores para expandir ou Guerreiros
para se defender/atacar. A civilizacao rival faz o mesmo do lado dela e
pode vir atacar se voce chegar perto. Longe do centro, de olho em Covis de
Monstro guardados por Goblins/Trolls/Viverns, vencer o guardiao saqueia
ouro na hora, perder custa a unidade. Perdeu ou ganhou? O banner de fim de
jogo tem um botao pra comecar outra partida na hora, com um mapa novo.

## Estrutura do projeto

```
scenes/          cenas (.tscn), composicao visual
  main/          cena principal do jogo
  ui/             HUD e telas
scripts/         codigo (.gd)
  autoload/      singletons globais (GameManager, TurnManager, EventBus, SelectionManager, Settings, AudioManager, SaveManager)
  core/          PlayerData, WorldSetup, CombatResolver, RivalAI, regras de jogo puras
  data/          Resources data-driven (HexTileData, UnitData, CivilizationData, BuildingData) + factories (inclui MonsterDatabase)
  world/         geracao do mapa hexagonal (HexMetrics, HexGrid)
  units/         Unit.gd, entidade de unidade no mundo
  city/          City.gd (entidade de cidade), Building.gd (predio posicionado no mapa)
  camera/        controlador de camera RTS
  ui/            scripts da interface (HUD.gd, Minimap.gd)
  main/          script da cena principal
shaders/         shaders .gdshader
assets/          modelos 3D (models/castle), texturas (textures/terrain),
                 audio (audio/music, audio/sfx), todos CC0, ver creditos
resources/       instancias .tres de civilizacoes, unidades, tecnologias
addons/          plugins: gut/ (testes), limboai/ (behavior trees, IA)
test/unit/       testes automatizados (GUT), grid, combate, cidade
```

## Por que Godot 4 e essa arquitetura

- **Forward+ renderer**: suporta shaders customizados, PBR, sombras, pos-
  processamento, sem limite artificial de complexidade grafica depois.
- **MultiMesh** em vez de um `MeshInstance3D` por tile: um mapa 4X pode ter
  milhares de hexagonos; multimesh e a tecnica padrao da industria para isso
  nao virar gargalo de performance mais tarde. A mesma tecnica agora tambem
  serve para pintar a neblina de guerra (recolorir instancias, sem trocar
  geometria), pra decorar o mapa com arvores/pedras sem custo de draw call
  extra por objeto, e pra levar dados por-instancia pro shader (o flag de
  "isso e agua" das ondas vem do canal `custom_data` do MultiMesh).
- **Resources como dados de jogo**: assim como em Unity ScriptableObjects,
  isso separa "dados de design" (atributos de unidade, civilizacao, terreno)
  de codigo, permitindo balancear o jogo sem recompilar nada.
- **Unidades/cidades como Node3D separados do terreno**: o terreno usa
  MultiMesh (estatico, muitos tiles), mas unidades/cidades sao poucos objetos
  que mudam de estado o tempo todo, por isso sao nodes individuais, mais
  faceis de animar/selecionar/destruir no futuro.
- **Autoloads + sinais (EventBus)**: evita acoplamento direto entre UI, mundo
  e regras de jogo, cada sistema novo (diplomacia, tecnologia, comercio)
  pluga nos mesmos sinais sem reescrever o que ja existe. `SelectionManager`
  concentra toda a logica de "o que acontece quando eu clico no mundo", para
  a camera continuar sendo so uma camera.
- **Export nativo**: Godot exporta para Windows/Linux/macOS (e web/mobile se
  quiser depois) direto pelo menu Project > Export, sem infraestrutura extra.

## Status: MVP fechado

O criterio de "MVP fechadinho" era ter um loop jogavel completo sem
depender de reiniciar o Godot ou ler documentacao externa: comecar →
jogar → vencer/perder → jogar de novo, com instrucoes acessiveis dentro do
proprio jogo. Isso esta feito. Depois disso, o foco foi deixar o jogo
legivel enquanto se joga, minimapa, notificacoes de eventos, resumo do
imperio e rotulos de cidade no mundo, porque um MVP jogavel tambem precisa
comunicar o que esta acontecendo, nao so permitir as acoes. O que falta
agora e conteudo e profundidade, nao mais fechar o loop basico.

**Correcoes de bugs de gameplay:**
- Atacar uma cidade inimiga sem defensor movia a unidade pra cima dela em
  vez de capturar (a checagem de "posso mover ate ali" nao excluia tiles
  com cidade inimiga, entao ela ganhava prioridade sobre "posso atacar
  ali"). `HexGrid.compute_reachable()` agora recebe o dono da unidade e
  exclui tiles de cidade inimiga do calculo de movimento.
- Unidades recem-produzidas por uma cidade costeira podiam nascer dentro
  do oceano (o vizinho era escolhido as cegas, sem checar terreno). Agora
  usa `WorldSetup.find_spawn_tile()`, compartilhado entre o spawn inicial
  e a producao de cidades, que so aceita terra firme e tile livre.
- Dava pra atacar o mesmo alvo varias vezes no mesmo turno so clicando de
  novo nele (`SelectionManager._select_unit()` recalculava `attackable`
  olhando so o alcance da unidade, sem checar se ela ja tinha agido.
  Atacar zera `movement_left`, mas isso nunca impedia o alvo de continuar
  marcado como atacavel. Agora so populam `attackable` unidades com
  `movement_left > 0`. A IA rival nao tinha esse bug: `RivalAI.take_turn()`
  processa cada unidade uma unica vez por turno, sem loop de reselecao.
- `City._best_unassigned_neighbor()` (usada tanto pelo auto-assign quanto
  pela IA, sempre) pontuava so o rendimento CRU do terreno pra escolher
  qual tile trabalhar, ignorava os bonus de tecnologia E de recurso que
  `collect_yields()` ja aplicava, entao sugeria uma planicie comum em vez
  de uma colina com ferro mesmo o ferro rendendo mais no total. Extrai a
  logica de bonus pra `City.effective_tile_yield()`, reaproveitada tambem
  pela HUD (os botoes de "Tiles trabalhados" mostravam o rendimento cru
  do terreno, nao o que a cidade realmente ia receber).
- Abrir Ajuda/Tecnologia/Diplomacia (todos paineis centralizados na mesma
  posicao da tela) um por cima do outro deixava tudo empilhado e
  ilegivel, nenhum fechava os outros ao abrir. Agora so um fica visivel
  por vez (`HUD._close_overlay_panels()`).
- Com multiplos rivais (feature nova, ver roadmap item 8), a busca por
  "planicie mais proxima" pra posicionar a capital inicial de cada civ
  (`WorldSetup.find_start_tile()`) nao sabia quais coordenadas outras
  civs ja tinham escolhido nesta mesma geracao de mapa, num mapa Pequeno
  com 2-3 rivais, duas origens diferentes podiam convergir pro mesmo
  tile, e a segunda `HexGrid.found_city()` simplesmente sobrescrevia a
  primeira em `cities_by_coord` (a cidade da primeira civ continuava
  existindo e gerando producao, mas ficava invisivel/inatacavel, ja que
  so uma cidade por coordenada aparece no grid). Agora
  `GameManager._spawn_starting_forces()` rastreia as coordenadas ja
  reivindicadas e passa pra `find_start_tile()` excluir.
- `GameManager.map_radius` (usado por `RTSCamera.reset_view()` pra
  calcular o limite de pan da camera) so era setado ao comecar um jogo
  novo pela tela de titulo. Carregar um save de raio diferente do jogo
  atual (ex: carregar um mapa Grande depois de ter comecado um Pequeno)
  deixava esse valor "preso" no raio errado, e a camera com o limite de
  pan errado. `SaveManager.load_game()` agora atualiza
  `GameManager.map_radius` pro raio de verdade do mapa carregado.
- Pesquisa concluida, paz aceita e guerra declarada notificavam o
  jogador (`EventBus.notify`) mas sempre com `sfx_kind = ""`, sem som
  nenhum. O parametro existe exatamente pra isso (`AudioManager.gd`
  ja mapeia "confirm"/"combat"/etc.), so ficou sem ser preenchido
  quando essas telas foram construidas. Agora usam "confirm" (pesquisa/
  paz aceita, mesmo som do fim de turno) e "combat" (declarar guerra).
- **Dois bugs de verdade so apareceram rodando a suite GUT pela linha de
  comando** (`Godot_v4.7.1..._console.exe --headless -s addons/gut/gut_cmdln.gd`)
  em vez de so ler o codigo, o resto desta lista foi encontrado por
  inspecao, esses dois nao tinham como:
  - `HexGrid.set_highlight()` acessava `_multimesh_instance.multimesh`
    sem checar null, `_apply_fog_colors()` (chamada logo antes, na
    mesma funcao) ja tinha essa guarda, mas `set_highlight()` nao
    repetia. So travava se chamada antes do mapa terminar de gerar
    (`_rebuild_multimesh()` nunca rodou), o que a suite de testes
    expos direto (`test_selection_manager.gd` cria um `HexGrid` sem
    chamar `generate_map()`).
  - `RESOURCE_NOISE_THRESHOLD` (recursos nos tiles) estava em `0.7`,
    tres ordens de grandeza mais restritivo do que o pretendido,
    medindo `FastNoiseLite.get_noise_2d()` de verdade (mesma
    frequencia usada no jogo) em milhares de amostras, so ~0.03% dos
    tiles passavam do limiar, nao os ~15% que o comentario original
    dizia. Na pratica, recurso quase nunca aparecia num mapa de
    verdade. Ajustado pra `0.3` (~12%, confirmado em varias sementes).
- **Reportado pelo usuario**: produzir um predio numa cidade "parecia nao
  fazer nada", a producao acumulava e o predio completava de verdade nos
  dados (confirmado pelos testes de `City.process_turn()`), mas o painel
  da cidade (`HUD.gd`) so se atualizava quando `_on_produce_pressed()` ou
  `_on_worked_tile_pressed()` chamavam `_refresh_viewed_city()`. O
  `_on_turn_changed()`, disparado a cada "Finalizar Turno", nunca
  chamava. Sem reclicar a cidade manualmente, o jogador nunca via o
  progresso mudar nem o predio aparecer na lista, mesmo com tudo
  funcionando por baixo, parecia quebrado sem estar. `_on_turn_changed()`
  agora chama `_refresh_viewed_city()` tambem, entao o painel (progresso,
  predios construidos, tiles trabalhados) fica sempre em dia sozinho
  enquanto uma cidade estiver selecionada.
- Tela de fim de jogo podia aparecer POR CIMA de um overlay (Tecnologia/
  Diplomacia/Ajuda) que estivesse aberto, ficando os dois empilhados, e o
  jogador ainda conseguia clicar nesses botoes depois do fim de jogo e
  fechar a tela de vitoria/derrota sem nenhum jeito de trazer ela de volta
  (so o restart resolvia). `HUD._on_game_over()` agora fecha qualquer
  overlay aberto antes de mostrar o proprio painel, e desabilita os
  botoes Tecnologia/Diplomacia/Ajuda enquanto ela estiver visivel
  (reabilitados no restart).
- **Esc** abria o menu de pausa por cima de um overlay da HUD que
  estivesse aberto, empilhando os dois (o overlay continuava com
  `visible = true` por baixo, reaparecendo assim que a pausa fechasse).
  `PauseMenu._unhandled_input()` agora fecha o overlay da HUD primeiro
  (`HUD.close_topmost_overlay()`) se tiver um aberto, so abre a pausa de
  verdade quando nao tinha nenhum.
- **Reportado pelo usuario**: "quando tiro a neblina crasha o jogo ele
  travou" (botao de Debug > Revelar Mapa). `Minimap._draw()` lia
  `unit.owner_player.civ.color` sem checar null pra desenhar o pontinho
  de cada unidade no minimapa — guardiao de Covil de Monstro
  (`owner_player == null`, ver `MonsterDatabase`) nunca tinha ficado
  visivel nele em massa antes (so organicamente, um de cada vez, ao
  escoutar um covil), entao esse null dereference nunca tinha disparado.
  Revelar o mapa inteiro de uma vez deixa TODO guardiao visivel ao mesmo
  tempo, e o primeiro deles derrubava o redesenho do minimapa inteiro —
  rodando pelo editor (unico jeito do botao de Debug aparecer, ver
  `OS.is_debug_build()`), um erro de script nao tratado pausa a execucao
  no debugger, a sensacao de "travou". Corrigido com o mesmo fallback ja
  usado em `Unit.gd` pra esse caso (`Unit.MONSTER_COLOR`), extraido pra
  `Minimap._unit_dot_color()` (funcao pura, testavel sem precisar de
  contexto de desenho — `draw_circle()`/`draw_rect()` so podem ser
  chamados de dentro do proprio callback `_draw()` de verdade, tentar
  chamar `_draw()` direto num teste falha com "Drawing is only allowed
  inside..."). Testes novos em `test_minimap.gd` (novo arquivo,
  `_unit_dot_color()` cai no fallback sem dono, usa a cor da civilizacao
  com dono).

## Proximos passos sugeridos (roadmap)

1. ~~IA rival mais esperta~~, feito: avalia risco antes de atacar, recua
   quando fraca, prioriza cidade indefesa, tem fog of war propria (so mira
   em unidade inimiga visivel agora; cidade inimiga fica numa memoria
   permanente assim que escoutada, ja que nao anda) e coordenacao tatica
   basica (arqueiro sozinho, sem aliado corpo-a-corpo por perto, nao avanca
   pra linha de frente), ver `RivalAI.gd`. **Decisao**: nao usar LimboAI
   pra isso, o jogo precisa funcionar 100% offline, e um GDExtension de
   terceiros que eu nunca testei rodando e um risco maior do que o ganho
   justifica; melhor evoluir a IA propria em GDScript puro (o addon
   continua instalado em `addons/limboai/` sem uso, pode remover se nao
   for usar). Limitacao conhecida: o check de "cidade esta indefesa" usa o
   estado real do jogo mesmo pra cidades so lembradas (nao fica com uma
   foto antiga da guarnicao), fog of war perfeito rastrearia isso tambem,
   mas o ganho de realismo e pequeno pro custo extra. Ainda falta:
   coordenar ataques de VARIAS unidades ao mesmo tempo num mesmo alvo
   (hoje cada unidade decide sozinha, sem planejar em grupo).
2. ~~Atribuicao de tiles trabalhados por cidadao~~, feito: cada ponto de
   populacao trabalha UM tile vizinho, escolhido automaticamente (melhor
   rendimento) ou manualmente pelo jogador clicando nos botoes no painel
   da cidade; duas cidades vizinhas nao disputam o mesmo tile, ver
   `City.gd` (`worked_tiles`/`auto_assign_worked_tiles`/
   `toggle_worked_tile`) e `HexGrid.is_tile_worked`. A IA rival so usa o
   auto-assign (nao microgerencia manualmente, mesma limitacao que
   producao de cidade).
3. ~~Arvore de tecnologia~~, feito: 9 tecnologias (`TechData.gd`/
   `TechDatabase.gd`, Resource igual `UnitData`), algumas com
   pre-requisito. Arqueiro/Cavaleiro/Catapulta/Mago agora exigem pesquisa
   (antes disponiveis de graca); as outras dao bonus de rendimento por
   bioma. Ciencia = populacao das cidades por turno. IA rival pesquisa
   sozinha e respeita o bloqueio de unidade, ver
   `RivalAI.decide_research`/`decide_production`. Falta: melhorias de
   tile propriamente ditas (o roadmap original citava "melhorias" alem
   de unidade, dei bonus de bioma via tech em vez de um sistema de
   construir/posicionar melhoria no tile, escopo menor mas cobre a
   mesma ideia de "tecnologia deixa o terreno mais produtivo").
4. ~~Veterancia/promocao, mais tipos de unidade e recursos nos tiles~~,
   feito: unidade que vence combate ganha abates e sobe de nivel
   (Recruta/Veterano/Elite/Lendario, +10% ataque/defesa por nivel, cura
   parcial na promocao, ver `Unit.register_kill`/`veterancy_multiplier`
   e `CombatResolver.predict()`); dois tipos de unidade novos, Catapulta
   (cerco, maior ataque do jogo) e Mago (magia que ignora bonus de defesa
   de terreno), ambos gateados por tecnologia; e recursos
   estrategicos/luxo (Ferro/Cavalos/Gemas/Seda) espalhados
   deterministicamente pelos biomas, dando bonus de yield quando
   trabalhados (`ResourceDatabase.gd`), limitacao conhecida: so afetam
   yield, nao gate producao de unidade (documentado no proprio arquivo).
5. ~~Modelos 3D reais para as unidades~~, feito pra Colonizador/
   Guerreiro/Arqueiro (Quaternius, ver secao de assets externos acima),
   depois **revertido** pra forma procedural (ver roadmap item 19), os
   modelos importados nao combinavam com o resto do visual do jogo.
6. ~~Testes automatizados~~, feito, ver `test/unit/` e secao de assets
   externos acima. Cobertura ainda pequena (grid, combate, cidade); vale
   ir adicionando teste pra cada bug de gameplay corrigido daqui pra
   frente, como ja fiz pro bug de captura de cidade.
7. ~~Salvar/carregar partida~~, feito (`SaveManager.gd`, botao "Salvar" na
   HUD, "Carregar Jogo" na tela de titulo). Nao serializa `tiles` direto,
   guarda a semente do ruido + raio do mapa, que recria o terreno
   identico e e muito mais leve que salvar centenas de tiles. Fog of war
   restaurado via lista de tiles ja explorados.
8. ~~Multiplos civs rivais + diplomacia~~, feito: 1 a 3 rivais escolhidos
   na tela de titulo (`GameManager.rival_players`, cada um com nome/lider/
   cor proprios, ver `GameManager.RIVAL_CIVS`), e diplomacia de verdade
   (`Diplomacy.gd`): guerra/paz por par jogador-rival, "Propor Paz" pode
   ser recusado pela IA, unidade/cidade de quem esta em paz nunca fica
   atacavel. **Decisao de escopo**: so o jogador humano negocia
   ativamente, rivais nunca declaram guerra entre si nem propoem paz
   sozinhos (uma guerra de todos contra todos seria bem mais dificil de
   acompanhar/balancear, e o pedido original ja falava em generalizar o
   loop 1 vs 1 existente, nao reescrever a IA do zero pra coordenacao
   entre civs). Sem trocas de verdade (sem tributo, cessao de territorio,
   alianca), so guerra ou paz.
9. ~~Tela de titulo antes da partida~~, feito (`TitleScreen.gd`/`.tscn`):
   nome do reino, tamanho do mapa (Pequeno/Medio/Grande) e numero de
   rivais (1 a 3) pra um jogo novo, ou carregar o save existente.
10. ~~Audio~~, feito, ver secao de assets externos acima
    (`AudioManager.gd`). Mixagem/volume relativo entre musica e SFX
    tambem feito (`Settings.gd` + `SettingsPanel.tscn`, ver bullet
    "Configuracoes" acima). Falta so checar por ouvido se os jingles de
    vitoria/derrota (escolhidos so pelo nome do arquivo) fazem sentido.
11. ~~Predios de cidade~~, feito (`BuildingData.gd`/`BuildingDatabase.gd`,
    ver bullet acima): Celeiro/Oficina/Mercado/Muralhas, mesma fila de
    producao das unidades, bonus permanente de rendimento (ou de defesa,
    Muralhas) uma vez construidos. Itens novos alem do roadmap original
    (10 pontos): dificuldade (Facil/Normal/Dificil, afeta so a economia
    da IA rival) e configuracoes de volume tambem foram adicionados nessa
    mesma rodada de expansao pos-MVP. Falta: dar predios pra IA rival
    construir tambem (hoje so a cidade do jogador constroi, ver
    `BuildingDatabase.gd`), e mais tipos de predio (ex: quartel pra
    unidade nascer com veterania de graca, biblioteca pra ciencia).
12. ~~Covis de Monstro~~, feito (`MonsterDatabase.gd`, ver bullet acima):
    pedido explicito de aprofundar o lado FANTASIA do "Civilization
    medieval-fantasia" (ate aqui o jogo era mais "medieval" com um Mago
    solto do que fantasia de verdade, nada de monstro, magia so num
    unico tipo de unidade). Goblins/Trolls/Viverns guardando covis
    espalhados pelo mapa e a mesma mecanica de risco/recompensa que
    define 4X de fantasia como Age of Wonders/Endless Legend (ruinas/
    covis neutros pra explorar antes mesmo de esbarrar num rival), sem
    exigir sistema de mana/feiticaria completo pra ja mudar a sensacao
    do mundo. Falta, se quiser ir mais fundo nessa direcao: mais
    unidades fantasticas pro jogador/rival produzirem (nao so pra IA
    guardar covil), um recurso de "mana" alimentando o Mago e novos
    predios arcanos, e/ou eventos aleatorios de mundo (ex: um dragao
    desperto atacando cidades perto do covil dele).
13. ~~Unidade fantastica jogavel: Grifo~~, feito (`UnitData.flies`,
    `HexGrid.compute_reachable`, ver bullet "Oito tipos de unidade"
    acima): primeiro item da lista de "falta" do ponto 12 riscado.
    Diferente de Mago (so muda a formula de combate), o Grifo introduz
    uma mecanica de MOVIMENTO nova, voa por cima de qualquer terreno a
    custo fixo e atravessa oceano, algo que nenhuma outra unidade do jogo
    consegue. Gateado por "Adestramento de Grifos" (exige Equitacao
    pesquisada), disponivel pro jogador E pra IA rival (`RivalAI.
    MILITARY_KINDS`) assim que desbloqueado, nao ficou restrito a
    guardiao de covil como os monstros do item 12.
14. ~~Segunda unidade fantastica (Ent) + escoutar risco antes de atacar~~,
    feito: `UnitData.regen_fraction`/`GameManager._apply_regen` (ver
    bullet "Oito tipos de unidade" acima) da ao Ent uma TERCEIRA mecanica
    de unidade inedita (depois de "ignora defesa de terreno" do Mago e
    "voa/ignora custo de movimento" do Grifo), regenera HP sozinho todo
    turno em qualquer lugar, sem depender de guarnicao como o resto do
    exercito, ao custo de ser a unidade mais lenta do jogo (1 de
    movimento). Tambem melhorei a informacao disponivel ANTES de atacar
    (pedido implicito do "risco alto, recompensa alta" dos Covis de
    Monstro do item 12, sem isso o jogador descobria o guardiao so
    apanhando dele): tile info panel mostra o guardiao/HP/recompensa de
    um covil selecionado, e o hover de ataque mostra o nome do alvo
    ("ATACAR Troll") em vez de um "ATACAR" generico, pra QUALQUER alvo
    (unidade ou cidade, nao so monstro). Falta, continuando a lista do
    item 12: recurso de "mana" alimentando o Mago e novos predios
    arcanos, mais unidades com mecanica propria (ex: furtividade), e/ou
    eventos aleatorios de mundo.
15. ~~Limite de predios por cidade + corrigir painel que "nao fazia nada"~~,
    feito, os dois a pedido do usuario. **Bug de verdade**: produzir um
    predio funcionava corretamente nos dados (bonus aplicado, predio
    registrado), mas o painel da cidade so se atualizava ao reclicar
    manualmente, `_on_turn_changed()` nunca chamava
    `_refresh_viewed_city()`, entao "Finalizar Turno" repetidas vezes
    nunca mudava o que aparecia na tela. Sem isso o jogador nao tinha
    como saber que o predio realmente completou (ver secao "Correcoes de
    bugs de gameplay" acima). **Feature nova**: `City.max_building_slots()`
    limita o total de predios de uma cidade a 1 por ponto de populacao,
    antes uma vila que nunca cresceu podia acumular Celeiro+Oficina+
    Mercado+Muralhas ao mesmo tempo, sem nenhum motivo pra crescer alem
    do rendimento puro. O painel sempre mostra o limite atual ("Predios:
    1/2"), mesmo antes do jogador esbarrar nele.
16. ~~Predios posicionaveis no mapa + limite de cidade visivel~~, feito, a
    pedido do usuario apos o item 15: "nao vi nenhum limite visivel da
    cidade e as construcoes ainda nao aparecem no mapa, eu quero poder
    posicionar a construcao, como o castelo". O item 15 corrigiu o bug
    de atualizacao E deu um limite NUMERICO de predios, mas nao resolvia
    o pedido de verdade, o predio continuava sendo so uma entrada
    abstrata em `City.buildings`, sem existir fisicamente no mundo 3D.
    Agora: `Building.gd` (nova classe, mesmo padrao visual de `Unit.gd`/
    `City.gd`) da um modelo procedural proprio pra cada tipo de predio;
    escolher um predio entra num modo de posicionamento
    (`SelectionManager.start_building_placement`) que destaca os tiles
    vizinhos validos da cidade em azul, clicar um deles confirma onde o
    predio vai ficar, exatamente como fundar uma cidade escolhe o tile do
    colonizador; e o "limite da cidade" (o territorio, ela mesma +
    vizinhos, mesmo raio de worked_tiles) fica visivel no PROPRIO MAPA
    (destaque dourado so enquanto a cidade estava selecionada). `SaveManager`
    persiste onde cada predio foi posicionado e recria o modelo 3D certo
    ao carregar.
17. ~~Limite sempre visivel + indicador de construcao em andamento~~,
    feito, a pedido do usuario apos o item 16: o destaque dourado do item
    16 so aparecia com a cidade selecionada, e o jogador queria algo
    permanente "tal qual o Civilization", alem de algum sinal visual pra
    predio EM OBRA (antes, o tile ficava com cara de vazio ate a producao
    completar do nada). Duas mudancas: (1) `HexGrid._update_city_border()`
    substitui o tingimento por selecao por um CONTORNO permanente na cor
    da civilizacao ao redor do territorio de toda cidade (sua ou rival,
    sujeito a fog of war), reconstruido ao fundar/capturar; a geometria e
    generica (percorre os 6 vizinhos de cada tile do territorio, desenha
    uma aresta so quando o vizinho NAO faz parte do territorio), entao
    funciona pra qualquer formato de area, nao so o "flor de 7 hexagonos"
    atual. (2) `HexGrid.refresh_construction_markers()` mostra um
    guindaste animado (gira + balanca) em cima do tile de todo predio EM
    PRODUCAO (`City.pending_building_coord`), reconciliado a cada mudanca
    de turno/posicionamento em vez de rastreado manualmente, o que tambem
    expos e corrigiu um bug latente: trocar de producao no meio de uma
    obra (pra unidade ou outro predio) nao limpava `pending_building_coord`,
    entao o tile antigo ficava "reservado" pra sempre sem nenhum jeito de
    perceber isso de fora.
18. ~~Upgrade profundo dos menus/interfaces~~, feito, a pedido do usuario:
    "faca um upgrade de menus, as arvores de tecnologia, os menus em
    geral, todos tao muito feitos, mal organizados, dificil de entender,
    alguns entram um por cima do outro". Tres frentes: (1) sistema de
    visual unico (`UITheme.gd`, ver bullet de features acima) aplicado em
    HUD/TitleScreen/PauseMenu, acabando com a mistura de paineis no cinza
    padrao do Godot sem nenhuma consistencia entre telas, com cabecalho
    (titulo + "X") e fundo escurecido iguais em todo painel modal; (2) dois
    bugs REAIS de sobreposicao corrigidos, fim de jogo aparecendo por cima
    de overlay aberto e Esc abrindo a pausa por cima de overlay aberto (ver
    secao "Correcoes de bugs de gameplay" acima); (3) arvore de tecnologia
    reescrita como grafo de verdade (`TechTree.gd`), o item mais citado no
    pedido do usuario, trocando a fileira de botoes soltos por colunas de
    pre-requisito com linhas conectando as tecnologias. Testes novos em
    `test/unit/test_hud.gd` (overlays/fim de jogo, primeira suite deste
    projeto a instanciar uma cena `.tscn` inteira em vez de so a classe do
    script) e `test/unit/test_tech_tree.gd` (calculo de tier, layout,
    resumo de efeito).
19. ~~Reverter unidades/cidade pros modelos procedurais~~, feito, a pedido
    do usuario: "volte as pecas pra os modelos default, sem ser esses 3d,
    eles nao fazem sentido". O item 5 tinha substituido Colonizador/
    Guerreiro/Arqueiro pelo Quaternius RPG Character Pack e a cidade pela
    torre+bandeira do Kenney Castle Kit (bullet "Fundacao de cidades"),
    mas o resultado nao combinava com o resto do elenco (Cavaleiro,
    Catapulta, Mago, monstros e unidades fantasticas continuavam
    procedurais de proposito, ver bullet "Oito tipos de unidade" acima,
    entao o visual ficava inconsistente, uns humanoides importados
    misturados com formas geometricas). `Unit._build_visual()` e
    `City._build_visual()` agora sempre constroem a forma procedural, sem
    checar `ResourceLoader.exists()` pra decidir entre real e fallback.
    Os arquivos `.glb`/`.gltf` continuam no repo (`assets/models/
    characters/`, `assets/models/castle/`), so pararam de ser carregados
    pelo codigo, caso valha revisitar depois com um estilo mais coerente.
    Suite GUT continua 207/207 depois da reversao (nenhum teste dependia
    do carregamento de modelo real).
20. ~~Cada tropa exige o predio de treino certo~~, feito, pivot pedido pelo
    usuario: "cada tropa e feita numa construcao... voce so pode construir
    dentro da cidade, porem so pode treinar as tropas na sua respectiva
    construcao". Sete predios novos, um por tropa de combate (Quartel/
    Guerreiro, Campo de Tiro/Arqueiro, Estabulo/Cavaleiro, Arsenal de
    Cerco/Catapulta, Torre Arcana/Mago, Poleiro de Grifos/Grifo, Bosque
    Druida/Ent, cada um com forma procedural propria em `Building.gd`),
    entram na mesma fila/posicionamento de tile ja usada pelos 4 predios
    de producao (mantido de proposito, ver decisao abaixo). Colonizador
    fica de fora da regra (nao e tropa de combate) e virou o novo default
    de producao de cidade nova (`City.production_item`), ja que Guerreiro
    deixou de ser sempre disponivel. `City.can_train(kind)` e o gate novo,
    checado pela HUD antes de deixar escolher uma tropa
    (`HUD._on_produce_pressed`) e refletido nos botoes desabilitados com
    tooltip explicando o motivo (pesquisa ou predio faltando,
    `HUD._production_lock_reason`). **Decisao de escopo** (perguntada
    direto ao usuario antes de implementar): predios continuam sendo
    POSICIONADOS num tile escolhido no mapa, como ja funcionava, em vez
    de voltar a ser um atributo abstrato da cidade — o usuario preferiu
    manter o sistema de posicionamento existente (item 16) e so adicionar
    o gate de treino por cima dele. A IA rival fica de fora do gate
    (limitacao ja existente: ela nunca constroi predio nenhum, ver bullet
    "Predios de cidade posicionaveis" acima), senao nunca teria como
    produzir tropa de combate nenhuma. Painel "Selecione um tile" da HUD
    reorganizado em secoes com rolagem (`ProductionScroll`, "Unidades" /
    "Predios de producao" / "Predios de treino") pra caber os 7 botoes
    novos sem estourar o painel. Testes novos/atualizados em
    `test_city.gd` (`can_train`), `test_buildings.gd`
    (`building_that_trains`) e `test_tech.gd` (`tech_that_unlocks`).
21. ~~Predio de treino tambem exige pesquisa~~, feito, a pedido do usuario
    logo apos o item 20: "faca seguir uma logica eu so posso construir
    esses predios especiais quando pesquisar a tecnologia, ai aparece
    disponivel pra construir, e consequentemente as tropas poderao ser
    treinadas nela". O item 20 fazia o predio gatear a tropa, mas o
    proprio predio ainda podia ser construido a qualquer momento (Campo
    de Tiro sem nunca ter pesquisado Tiro com Arco, por exemplo). Agora e
    uma cadeia de verdade: pesquisar libera CONSTRUIR o predio
    (`City._tech_unlocked_for_building()`, chamado por `can_build()`) e
    so o predio construido libera TREINAR a tropa (`can_train()`, sem
    mudanca). A tecnologia exigida por cada predio nao e um campo
    duplicado — e derivada na hora achando qual tech tem `unlocks_unit`
    igual ao `trains_unit` do predio (`TechDatabase.tech_that_unlocks()`),
    reaproveitando o mapeamento tropa->tecnologia que a arvore ja tinha,
    entao Quartel (treina Guerreiro, que nunca exigiu pesquisa) e os 4
    predios de producao (Celeiro/Oficina/Mercado/Muralhas, sem
    `trains_unit`) ficam de fora do gate automaticamente, sem precisar de
    nenhum caso especial no codigo. **Bug pego ANTES de ir pra producao**,
    durante a propria implementacao: `TechData.unlocks_unit` tambem faz
    default pra `""` nas tecnologias de bioma (Agricultura, Mineracao...)
    que nao desbloqueiam unidade nenhuma, entao `tech_that_unlocks("")`
    (chamado pra todo predio de PRODUCAO, cujo `trains_unit` tambem e
    `""`) "encontraria" a primeira tech de bioma da lista por acidente —
    na pratica, o Celeiro ficaria bloqueado ate pesquisar Agricultura, sem
    nenhuma relacao real entre os dois. Corrigido direto em
    `TechDatabase.tech_that_unlocks()` (devolve null pra `kind == ""`
    explicitamente, antes do loop), com teste de regressao dedicado
    (`test_can_build_yield_building_never_requires_research`). HUD ganhou
    o mesmo tratamento de tooltip que as tropas ja tinham
    (`HUD._building_lock_reason`/`_update_building_tooltips`): um botao de
    predio de treino desabilitado mostra "Requer pesquisar: X" antes de
    ter a tecnologia, ou o aviso de limite de slots depois disso.
22. ~~Civilizacoes rivais viram racas de fantasia de verdade~~, feito, a
    pedido do usuario: "insira outras civilizacoes, ao inves de todas
    serem a copia da sua insira outras civilizacoes de fantasia, tipo os
    anoes, os orcs, os elfos coisas assim. ai voce cria tropas especificas
    pra essas civilizacoes". Antes, os 3 rivais so diferiam por nome/
    lider/cor (`GameManager.RIVAL_CIVS`), copiando a mesma economia e o
    mesmo elenco de unidades do reino do jogador. Agora `CivilizationData`
    ganhou um campo `race` (`"dwarf"`/`"orc"`/`"elf"`, vazio = humano
    generico), e cada um dos 3 rivais e uma raca classica de fantasia com
    UMA tropa exclusiva (`RivalAI.RACE_UNIQUE_KIND` -> `UnitDatabase.
    create_unit`, ver bullet "Tropas exclusivas por civilizacao" acima):
    Reino de Ferroeste = Anoes (Guarda-Machado Anao), Horda das Brumas =
    Orcs (Berserker Orc, ja tinha um Xama como lider, so precisou do
    campo novo), e o antigo "Cla Corvo Negro" virou Reino Elfico de
    Verdemata (Elfos, Patrulheiro Elfico) — reflavorizado pra fechar o
    trio classico anao/orc/elfo que o usuario pediu por nome. **Decisao
    de escopo**: a tropa racial so entra no pool de producao da IA
    (`RivalAI._military_kinds_for`), o jogador humano continua sem raca
    (`CivilizationData.race == ""`) e sem acesso a nenhuma das 3 — ele
    ENCONTRA essas tropas como inimigo (reforca a sensacao de "civilizacao
    diferente de verdade" na hora do combate, nao so no nome), mas nao
    treina nenhuma ainda. Isso evitou ter que estender `City.can_train()`/
    `BuildingDatabase` (o gate de pesquisa+predio dos itens 20/21 e
    especificamente pro jogador) com um terceiro eixo de restricao
    (raca), escopo maior do que o pedido cobria; deixar o JOGADOR escolher
    uma raca na tela de titulo fica pra uma rodada futura, se quiser
    aprofundar mais essa direcao.
23. ~~Mapa procedural mais complexo: rios, mares, gelo, lava, cristal,
    mapas maiores~~, feito, a pedido do usuario: "quero aumentar a
    complexidade do mapa procedural, quero que tenha rios, mares, biomas
    de gelo, biomas de deserto, bioma de lava, algum outra bioma de
    fantasia talvez... o mapa pode ficar bem maior, verifique qual o
    tamanho do mapa pequeno, medio e grande do proprio civilization e...
    chegar a tamanhos aproximados". Deserto ja existia (bullet "16
    biomas" acima, item nao aplicado por ja estar coberto); os outros 4
    ganharam biomas novos (Mar Gelado, Gelo Eterno, Lava, Campos de
    Cristal — este ultimo original, "aprofundar a tematica de fantasia"
    como fez sentido) e um sistema de rios de verdade, ver os 3 bullets
    de features acima ("16 biomas"/"4 biomas novos"/"Rios de verdade")
    pros detalhes tecnicos de cada um. Mapas Pequeno/Medio/Grande
    cresceram de raio 8/12/16 pra 25/30/37 (217/469/817 -> 1951/2791/4219
    tiles, 5 a 9x maior), medido empiricamente pra aproximar os tamanhos
    Pequeno/Padrao/Grande de verdade do Civilization sem estourar o tempo
    de geracao (ver bullet "Mapas bem maiores" acima). **Refinamento de
    shader pego durante a implementacao, nao pedido explicitamente**: o
    shader de terreno so tinha UM canal (`v_is_water`) controlando tanto
    "pula a textura de chao" quanto "anima onda/brilho" — como Mar Gelado
    tambem e agua mas NAO deveria ondular feito o Oceano, isso teria
    feito ele herdar a textura de grama/terra por cima (visualmente
    errado, agua nao deveria ter textura de chao nenhuma) ou ganhar onda
    animada (errado ao contrario, gelo nao ondula). Separado em dois
    canais (`v_is_water`/`v_animate_waves`, `shaders/terrain.gdshader`)
    antes de ir pra producao, nao depois de alguem notar o bug visual.
    Testes novos em `test_terrain_generation.gd` (biomas novos, rios,
    performance no raio Grande novo), `test_hex_grid_movement.gd` (Lava/
    Mar Gelado bloqueiam unidade terrestre, grifo atravessa Lava),
    `test_city.gd` (bonus de comida de rio) e `test_game_manager.gd`
    (pipeline de comeco de jogo completo no tamanho Medio novo).
24. ~~Painel de Debug~~, feito, a pedido do usuario: "adicione opcoes
    debug onde eu posso tirar a fog do mapa e coisas assim". Botao
    "Debug" na barra superior, visivel SO rodando pelo editor ou um
    export de debug (`OS.is_debug_build()`) — nunca aparece pra quem so
    joga um export de release, ja que isso viraria um menu de trapaça
    visivel pro jogador em vez de uma ferramenta de desenvolvimento (ver
    bullet de features acima pra lista completa de acoes: revelar mapa,
    ouro extra, completar pesquisa, forcar vitoria/derrota). Toda acao
    reaproveita a logica de verdade em vez de duplicar (`HexGrid.
    recompute_fog()` ganhou uma flag `debug_fog_disabled` verificada no
    topo da funcao, entao o proximo fim de turno nao desfaz o reveal;
    Vencer/Perder Agora chamam o MESMO `_end_game()`/sinal
    `EventBus.game_over` que um fim de jogo de verdade usa; Completar
    Pesquisa so garante progresso suficiente e chama
    `_process_research()` de verdade). Segue a mesma regra de "so um
    overlay por vez" e fica desabilitado durante o fim de jogo, igual
    Ajuda/Tecnologia/Diplomacia ja funcionavam. Testes novos em
    `test_hexgrid_fog.gd` (fog desligada mostra tudo, inclusive inimigo
    nunca visto de verdade), `test_game_manager.gd` (forcar fim de jogo/
    completar pesquisa) e `test_hud.gd` (integracao com o painel).
25. ~~Crash ao revelar o mapa~~, feito, **reportado pelo usuario**: "quando
    tiro a neblina crasha o jogo ele travou" — bug de verdade exposto
    pelo item 24 (ver secao "Correcoes de bugs de gameplay" acima pro
    diagnostico completo). `Minimap._draw()` presumia que toda unidade
    tinha dono pra pegar a cor do pontinho no minimapa; guardiao de Covil
    de Monstro nunca tinha ficado visivel nele em massa antes (so um de
    cada vez, organicamente), entao esse null dereference nunca tinha
    disparado ate existir um jeito de revelar o mapa inteiro de uma vez
    so. Corrigido com o mesmo fallback que `Unit.gd` ja usava
    (`Unit.MONSTER_COLOR`), extraido pra uma funcao pura testavel
    (`Minimap._unit_dot_color()`) ja que `_draw()`/`draw_circle()` so
    podem rodar dentro do proprio callback de desenho de verdade — um
    teste chamando `_draw()` direto falha com "Drawing is only allowed
    inside...". Primeiro arquivo de teste pra `Minimap.gd`
    (`test_minimap.gd`, antes sem cobertura nenhuma).
26. ~~Biomas mais trabalhados visualmente + garantia de cobertura no
    Grande~~, feito, **reportado pelo usuario**: "os biomas nao parecem
    bem trabalhados, os biomas de neve que eu vi nem pareciam biomas de
    neve, se tinha deserto nao percebi tambem, tambem nao vi o de fogo ou
    quaisquer outro que supostamente tem... acho que faz sentido todos os
    biomas sempre serem gerados pelo menos no grande... e trabalhar
    melhor essa parte visual/grafica/procedural de dar pra perceber que
    bioma e qual, e realmente ficar parecendo ele". Dois problemas reais,
    dois consertos: (1) TODO bioma (inclusive Neve/Deserto, que ja
    existiam) so mudava de COR sob a MESMA textura de chao generica —
    ver bullet de shader acima pra como cada um dos 4 biomas especiais
    ganhou tratamento proprio agora; (2) os biomas raros (Lava, Campos de
    Cristal, Mar Gelado, Gelo Eterno) sao probabilisticos por natureza
    (ruido raro de proposito, ver roadmap item 23) e podiam simplesmente
    nao aparecer em nenhum tile do mapa gerado — `HexGrid._ensure_biome_
    variety()` (ver bullet "4 biomas novos" acima) garante presenca no
    tamanho Grande sem tirar a raridade dos tamanhos menores. Testes
    novos em `test_terrain_generation.gd`: `_material_kind_for()` (funcao
    pura, cada bioma especial mapeia pro numero certo), e a garantia de
    cobertura testada de ponta a ponta gerando o mapa Grande de verdade
    com 2 sementes diferentes (todos os 16 tipos de bioma presentes nos
    dois), continua deterministica, e nao mexe em nada abaixo do limiar
    do tamanho Grande.
27. ~~Texturas reais pros biomas especiais~~, feito, a pedido do usuario
    (pergunta de acompanhamento do item 26: "todos os biomas tem a
    textura correta?... baixe as texturas corretas de assets pra isso").
    O item 26 deixou os 4 biomas especiais 100% procedurais (so cor +
    matematica de ruido, nenhuma textura de verdade). Agora cada um usa
    uma textura CC0 real da ambientCG, escolhida pelo material que
    deveria representar: `Snow006` (neve real fotografada) pra Neve/Gelo
    Eterno, `Ground033` (areia clara) pro Deserto, `Rock035` (pedra
    vulcanica escura rachada) de base pra Lava, `Ice003` (gelo rachado/
    facetado — serve muito bem como "cristal" tingido de roxo) pros
    Campos de Cristal. Os efeitos procedurais do item 26 (brilho de neve,
    duna de deserto, veios de lava, facetas de cristal) continuam por
    cima da textura real em vez de serem substituidos — o resultado e
    textura de verdade + efeito dinamico, nao um ou outro. Fallback pra
    branco (`hint_default_white`) se algum arquivo faltar, mesma
    filosofia do resto do projeto (`HexGrid._set_optional_texture`).
28. ~~Geracao de terreno "sal e pimenta" corrigida~~, feito, **reportado
    pelo usuario**: "melhore a geracao de terreno em geral, ta meio
    bugado os biomas nada faz muito sentido, é um monte de celula
    distribuida aleatoriamente, tem umas celulas de deserto espalhadas,
    umas celulas de vulcanico espalhadas, mas isso nao faz sentido, isso
    nao é bioma de fato". Causa raiz: a frequencia do ruido de elevacao/
    umidade (0.15/0.12) nunca tinha sido re-tunada pro tamanho de mapa
    NOVO (item 23, raio ate 37) nem pro fato do `FastNoiseLite` ja somar
    5 octavas de FBM por padrao (frequencia efetiva da octava mais alta
    chegando perto de 2.4) — um ciclo de ruido completo a cada 6-8 tiles
    e "regiao" nenhuma consegue se formar nessa escala, so ruido fino
    virando bioma tile a tile. Ver bullet "Regioes de verdade, nao 'sal e
    pimenta'" acima pros numeros exatos. **Efeito colateral pego durante
    a correcao**: com ruido mais correlacionado espacialmente, uma
    semente especifica no tamanho Grande podia legitimamente nunca
    alcancar o limiar de elevacao de Montanha em NENHUM lugar do mapa —
    `HexGrid._ensure_biome_variety()` (item 26) so sabia forcar um bioma
    num tile que já batesse a faixa de elevacao EXATA, entao Montanha/
    Lava ficavam sem candidato e a garantia falhava silenciosamente.
    `_find_forceable_tile()` ganhou um fallback (`_find_closest_
    elevation_tile()`): se nao existe tile na faixa exata, usa o de
    elevacao mais PROXIMA disponivel em vez de desistir — pego pelos
    proprios testes (`test_generate_map_at_large_size_contains_every_
    biome_type` comecou a falhar pra Montanha/Lava assim que baixei a
    frequencia, antes de eu sequer rodar o jogo de verdade). Novo teste
    de regressao mede a fracao media de vizinhos do mesmo bioma pro mapa
    inteiro, pra pegar qualquer regressao futura de volta pro "sal e
    pimenta" cedo.
29. ~~Bioma vulcanico redesenhado: pedra negra + rios de lava~~, feito, a
    pedido do usuario: "melhore o bioma vulcanico, ele pode apenas ser
    aquela pedra preta sem o efeito de lava, com rios tal qual os rios que
    ja temos, mas rios de lava. entao ao inves de ser um unico bloco de
    lava como e atualmente, seria um bioma agrupado com os outros com rios
    de lava e pedras negras". Tres mudancas: (1) o shader do tile de Lava
    (`mat_kind == 3`) perdeu o brilho/veios emissivos, agora e so a
    textura real de pedra vulcanica (Rock035, ver item 27) com `tint *
    rock_tex_color * 0.6` e sem `EMISSION` nenhuma — o unico brilho que
    sobra vem dos rios; (2) Lava passou a poder nascer tambem na faixa de
    elevacao de Colina, nao so Montanha (`HexGrid._pick_hills_biome()`,
    mesma regra de `_pick_mountain_biome()` — **essas duas funcoes foram
    removidas no item 30 abaixo**, quando Lava passou a nascer em
    QUALQUER terra firme, nao so Colina/Montanha), pra formar uma REGIAO
    de varios tiles vizinhos em vez de um pico isolado — a mesma mancha de
    ruido vulcanico (ja de baixa frequencia desde o item 28) agora costuma
    cobrir Colinas e Montanhas vizinhas juntas; (3) rios de lava
    (`HexGrid._generate_lava_rivers()`/`lava_river_edges`), mesma tecnica
    geometrica dos rios de agua (item 23, uma malha em ribbon ao longo da
    aresta compartilhada entre dois tiles vizinhos), restrita a tiles de
    Lava vizinhos: nascente = todo tile de Lava que e um pico local dentro
    da propria regiao vulcanica, tracado descendente ate nao ter mais
    vizinho de Lava mais baixo ainda nao visitado. Cor laranja emissiva
    pulsante (`Color(1.0, 0.45, 0.05)`, brilho animado em `_process()` via
    `_lava_river_time`) — mesmo aviso dos rios de agua: nao reagem a fog
    of war, decisao deliberada de escopo. **Efeito colateral necessario**:
    rio de agua normal (`_lowest_unvisited_neighbor()`) ganhou uma guarda
    pra nunca entrar num tile de Lava — antes disso um rio de agua podia
    atravessar por cima da regiao vulcanica, o que nao faz sentido (agua
    nao atravessa lava); agora o rio de agua desvia da regiao, que tem seu
    proprio sistema de rio agora. Testes novos em
    `test_terrain_generation.gd`: `_pick_hills_biome` como funcao pura
    (mesmo padrao de `_pick_mountain_biome`), Lava formando regiao
    agrupada de verdade numa semente/raio confirmados manualmente (fracao
    de tiles de Lava com pelo menos um vizinho tambem de Lava > 0.5),
    determinismo de `lava_river_edges` pela `map_seed`, toda aresta de rio
    de lava ligando dois vizinhos DE VERDADE que sao os dois tiles de Lava,
    `has_lava_river_between()` independente da ordem dos coords, e a
    garantia de que nenhuma aresta de rio de AGUA passa por um tile de
    Lava.

    **Bug encontrado logo depois, corrigido na mesma rodada** —
    **reportado pelo usuario**: "eu gerei o mapa grande 2x e nenhum veio
    com bioma de vulcao, no maximo vem uma celula vulcanica, nao se forma
    regiao vulcanica". Causa raiz dupla: (1) `VOLCANIC_NOISE_THRESHOLD`
    (0.6) e a frequencia do `_volcanic_noise` (0.02, herdada do item 28,
    onde baixar frequencia fazia sentido pros OUTROS biomas) juntos eram
    exigentes demais — medido empiricamente rodando o gerador de mapa
    Grande em varias sementes: so ~10-20% das sementes tinham QUALQUER
    tile acima do limiar antigo em algum lugar do mapa, e mesmo quando
    tinham eram so 1-2 tiles isolados perto do pico da mancha de ruido (frequencia
    0.02 e tao baixa que o mapa inteiro mal cobre 1-2 periodos completos
    de ruido — o pico raramente chegava perto do extremo). Subi a
    frequencia pra 0.07 (mais "manchas" vulcanicas menores espalhadas em
    vez de uma unica mancha gigante, mais chance de pelo menos uma cruzar
    o limiar em QUALQUER semente) e baixei o limiar pra 0.35 — medido de
    novo: agora toda semente testada (30 sementes aleatorias) forma pelo
    menos uma regiao conectada de 3+ tiles, media ~6. (2) Mesmo depois
    disso, `_ensure_biome_variety()` (a garantia de cobertura do tamanho
    Grande, item 26) so checava Lava **existir** em algum lugar do mapa —
    1-2 celulas isoladas (ou uma unica) ja contavam como "coberto" e a
    garantia nunca disparava nenhum reforco, entao o proprio bug relatado
    podia acontecer mesmo com o ajuste de ruido acima cobrindo a maioria
    dos casos. `_ensure_lava_forms_a_region()` substituiu a checagem
    simples: calcula a maior regiao de Lava JA conectada no mapa (BFS por
    vizinhanca real de hexagono, `_largest_lava_cluster()`), e se for
    menor que `FORCED_LAVA_CLUSTER_MIN` (3), cresce a partir de um tile de
    Lava natural existente (ou forca um tile novo do zero se nao existir
    nenhum) ate `FORCED_LAVA_CLUSTER_SIZE` (5) tiles, usando
    `_find_lava_cluster_neighbors()` pra so expandir em vizinhos elegiveis
    (Colina ou Montanha) ainda nao reivindicados por outro bioma forcado
    na mesma chamada. Novo **teste de regressao critico**
    (`test_generate_map_at_large_size_lava_always_forms_a_real_region`):
    roda 8 sementes diferentes no tamanho Grande e exige que TODAS tenham
    uma regiao de Lava conectada de pelo menos `FORCED_LAVA_CLUSTER_MIN`
    tiles — pego especificamente pra nunca deixar essa regressao voltar
    silenciosamente.
30. ~~Lava e um bioma terrestre de verdade, nao mais preso a Colina/
    Montanha~~, feito, **reportado pelo usuario** logo depois do item 29:
    "ainda nao se formou biomas, so algumas celulas, acho que voce ta
    fazendo como se fossem montanhas, o lance do bioma vulcanico e ser um
    bioma terrestre tal qual qualquer outro que agrupa realmente um
    bioma com varias celulas incluindo rios de lava, nao montanhas".
    Causa raiz: mesmo depois do item 29 garantir uma regiao CONECTADA de
    verdade, essa regiao so podia nascer dentro da faixa de elevacao de
    Colina/Montanha (`_pick_hills_biome`/`_pick_mountain_biome`) — uma
    fatia pequena do mapa (~2-5% dos tiles, medido empiricamente). Lava
    nunca conseguia se espalhar pra terreno PLANO (a maioria do mapa,
    onde os outros biomas de verdade tipo Deserto/Tundra vivem), entao
    sempre ficava restrita a uma cadeia de montanhas — exatamente o "ta
    fazendo como se fossem montanhas" que o usuario notou. Correcao:
    `_pick_hills_biome`/`_pick_mountain_biome` foram removidas.
    `_generate_tile_data` agora escolhe o bioma de terra firme normalmente
    primeiro (plano via `_pick_biome`/`_maybe_crystal`, ou Colina/Montanha
    pela faixa de elevacao), e SO DEPOIS aplica `_maybe_volcanic()` — uma
    funcao pura nova, mesma ideia de `_maybe_crystal`, que substitui
    QUALQUER um desses biomas por Lava quando o ruido vulcanico passa do
    limiar, seja terreno plano, Colina ou Montanha. Igual Campos de
    Cristal ja fazia pra terreno plano, so que agora pra terra firme
    inteira. Como a populacao de tiles elegiveis pulou de ~2-5% pra ~95%
    do mapa, a frequencia/limiar do `_volcanic_noise` precisaram subir
    junto (`_volcanic_noise.frequency`: 0.07 → 0.04; `VOLCANIC_NOISE_
    THRESHOLD`: 0.35 → 0.55) pra region continuar do mesmo tamanho "raro
    e especial" de antes (~0.2%-1% da terra do mapa, medido em 20
    sementes) em vez de virar comum. `_BIOME_ELEVATION_TIER`,
    `_find_lava_cluster_neighbors()` (a garantia de regiao minima do item
    29) e o `base_height` do tile no `TerrainDatabase` (era 0.55, nivel de
    Montanha; virou 0.1, nivel de terreno plano, pra nao parecer um monte
    de blocos flutuando numa planicie) foram todos ajustados junto pra
    combinar. Verificado empiricamente rodando 20 sementes novas no mapa
    Grande: 615 dos ~635 tiles de Lava gerados (97%) agora nascem em
    terreno que era originalmente PLANO, so 18 em Colina e 2 em Montanha.
    Testes novos em `test_terrain_generation.gd`: `_maybe_volcanic()`
    como funcao pura (mesmo padrao de `_maybe_crystal`, cobrindo terreno
    plano/Colina/Montanha), e um **teste de regressao critico**
    (`test_generate_map_lava_mostly_occupies_flat_terrain_not_just_
    mountains`) que gera o mapa Grande com 5 sementes diferentes e exige
    que a MAIORIA dos tiles de Lava de cada mapa esteja em elevacao
    originalmente plana, nao Colina/Montanha — pego especificamente pra
    nunca deixar Lava voltar a ficar presa a montanha silenciosamente.
31. ~~Fim das celulas isoladas de bioma, pra todo bioma~~, feito,
    **reportado pelo usuario** pela TERCEIRA vez seguida sobre o mesmo
    assunto: "ele ainda ta formando celulas isoladas... nenhum bioma deve
    ser tao pequeno ao ponto de formar celulas isoladas de um bioma...
    acho que o deserto e o vulcanico sao os piores... tem uma floresta
    gigante e 1 celula de vulcanico... eu to toda hora pedindo rios de
    lava... e ate agora nada". Causa raiz principal, a que faltava: cortar
    um campo de ruido continuo em faixas com limiares fixos (`_pick_biome`
    pro Deserto/Savana/etc., `_maybe_volcanic` pra Lava, `_maybe_crystal`
    pro Cristal) sempre deixa alguns tiles isolados perto das bordas de
    cada faixa — um pixel de ruido que cruza o limiar sozinho, cercado de
    vizinhos de outro bioma, mesmo com ruido ja de baixa frequencia (item
    28). Isso tambem explicava por que o usuario nunca via rio de lava:
    `_generate_lava_rivers()` so cria uma aresta entre DOIS tiles de Lava
    vizinhos, entao um tile de Lava isolado (a maioria dos que ele via)
    nunca gerava rio nenhum, so um pico sem agua-fogo. Correcao principal:
    `HexGrid._smooth_isolated_biome_cells()`, chamada logo apos o loop de
    geracao (ANTES de `_ensure_biome_variety`) pra TODO tamanho de mapa —
    qualquer tile cujo bioma nao bate com NENHUM vizinho vira o bioma mais
    comum entre os vizinhos. Roda em ate 5 passadas (nao so uma): como
    cada passada calcula as mudancas a partir do estado ORIGINAL e aplica
    tudo de uma vez, dois tiles isolados vizinhos um do outro podiam
    "trocar de lugar" numa passada so e continuar sem bater entre si —
    bug pego pelo proprio teste de regressao deste item, resolvido
    repetindo a passada ate estabilizar. Junto, a garantia de regiao do
    item 29 (antes so pra Lava) foi generalizada pra QUALQUER bioma
    forcado por `_ensure_biome_variety` no tamanho Grande
    (`_ensure_lava_forms_a_region` virou `_ensure_forced_region`,
    `_find_lava_cluster_neighbors` virou `_find_cluster_neighbors`,
    `FORCED_LAVA_CLUSTER_SIZE/MIN` viraram `FORCED_CLUSTER_SIZE/MIN`) —
    Montanha e Cristal tambem apareciam como celulas forcadas isoladas
    ocasionalmente, entao a mesma garantia de regiao minima de 3+ tiles
    conectados agora vale pra qualquer um dos 16 tipos. **Tres bugs
    secundarios pegos testando esta generalizacao, todos corrigidos**: (1)
    o tile "semente" de uma regiao forcada do zero nunca era escrito de
    fato em `tiles` (so entrava numa lista local de contagem) — se
    nenhum vizinho elegivel fosse achado depois, o bioma inteiro sumia do
    mapa (Montanha sumiu de vez numa semente durante os testes); (2)
    crescer Montanha/Colina exigia a faixa de elevacao EXATA — uma
    semente cujos picos nunca formam par adjacente entre si ficava presa
    a 1 tile mesmo forcada, corrigido deixando Montanha aceitar vizinho
    de Colina (contraforte) e Colina aceitar vizinho plano (encosta); (3)
    escolher o candidato pra forcar sempre pegava literalmente o primeiro
    em ordem de coordenada, que cai perto da BORDA do mapa hexagonal
    (menos vizinhos de verdade), corrigido preferindo o candidato com
    MAIS vizinhos da mesma faixa de elevacao. Mesmo com tudo isso, forcar
    a regiao de um bioma raro (ex: Cristal) podia CONSUMIR os vizinhos de
    um tile vizinho desavisado, isolando-o de colateral — corrigido
    rodando `_smooth_isolated_biome_cells()` de novo logo depois de
    `_ensure_biome_variety`, seguro porque uma regiao forcada de verdade
    (3+ tiles conectados) nunca fica isolada aos proprios olhos da funcao.
    Verificado empiricamente gerando 75 mapas (15 sementes x 5 tamanhos,
    Pequeno ate Grande): **zero** tiles isolados em qualquer um, e 100%
    dos mapas com Lava tinham pelo menos um rio de lava. Testes novos em
    `test_terrain_generation.gd`:
    `test_generate_map_never_has_isolated_single_tile_biomes` (30 mapas,
    3 tamanhos, exige zero tiles isolados, qualquer bioma) e
    `test_generate_map_at_large_size_lava_always_has_a_river_when_present`
    (todo mapa Grande com Lava tem que ter rio de lava).
32. ~~Mar de Lava (oceano de lava de verdade)~~, feito, **reportado pelo
    usuario**: "nada de oceanos de lava ainda, e literalmente impossivel
    pegar o sistema de oceano que temos e fazer um igual so que vermelho
    num bioma com aquele solo vulcanico?" — pedido diferente dos rios de
    lava (item 29, ja existiam): o usuario queria tiles de verdade
    reusando o MESMO sistema visual do Oceano (`v_is_water`, ondas
    animadas), so vermelho/emissivo, formando pocas/mares dentro da
    regiao vulcanica — nao so ribbons finas nas bordas dos tiles como os
    rios. Novo tipo de terreno, `TerrainType.LAVA_SEA` ("Mar de Lava"),
    seguindo o MESMO padrao ja usado por Mar Gelado (variante de Oceano):
    `HexGrid._maybe_volcanic()` ganhou um SEGUNDO limiar, mais alto
    (`LAVA_SEA_NOISE_THRESHOLD = 0.65`, sobre o MESMO `_volcanic_noise` ja
    usado pra Lava normal, `VOLCANIC_NOISE_THRESHOLD = 0.55`) — o nucleo
    mais "quente" de uma regiao de Lava vira liquido em vez de pedra, o
    que garante que o Mar de Lava SEMPRE nasce dentro/perto da regiao de
    Lava (pedra) ja existente, nunca solto em outro bioma (mesmo campo de
    ruido espacialmente correlacionado). `_rebuild_multimesh()` liga
    `is_water`/`animate_waves` pro Mar de Lava exatamente como faz pro
    Oceano (reusa a mesma animacao de onda do shader); `_material_kind_for`
    devolve 5 pro Mar de Lava, e o shader (`terrain.gdshader`) ganhou um
    branch novo DENTRO do bloco de agua: se `mat_kind == 5`, aplica
    `EMISSION` vermelha (modulada pelo mesmo ruido de "glint" que ja fazia
    a superficie da agua cintilar) por cima do visual de agua padrao — o
    UNICO jeito de um "oceano" ler como lava em vez de agua tingida de
    vermelho. `HexTileData.is_lava()` (novo, mesmo padrao de `is_water()`)
    cobre pedra E Mar de Lava juntos — `blocks_land_units()` passou a usar
    ele, e o rio de AGUA (`_lowest_unvisited_neighbor`) tambem, pra
    continuar desviando de qualquer terreno vulcanico. Rio de LAVA
    (`_trace_lava_river`) ganhou o mesmo comportamento que rio de agua ja
    tinha com o Oceano: para de tracar ao alcancar um Mar de Lava (rio
    "desagua" ali) em vez de continuar tentando fluir dentro de um corpo
    liquido que ja formou. **Garantia no tamanho Grande**: o limiar mais
    alto sozinho ja da Mar de Lava na maioria das sementes com regiao de
    Lava (medido: 14/15), mas nao em todas — `_ensure_lava_sea_present()`
    cobre o resto convertendo 2 tiles VIZINHOS entre si (nunca isolados,
    mesmo principio do item 31) de dentro da maior regiao de Lava ja
    garantida existir pelos itens 29/31, nunca criando uma regiao
    vulcanica nova do zero. Verificado empiricamente gerando 50 mapas (5
    tamanhos): zero regressao em tiles isolados, e **zero** mapas Grande
    com Lava sem Mar de Lava. Testes novos em `test_terrain_generation.gd`:
    `_maybe_volcanic()` cruzando o limiar do Mar de Lava,
    `test_generate_map_at_large_size_always_has_a_lava_sea_when_lava_present`
    (8 sementes, exige Mar de Lava presente E conectado sempre que ha
    Lava), `_material_kind_for(LAVA_SEA) == 5`, e `is_lava()`/
    `blocks_land_units()`/`is_water()` do Mar de Lava (bloqueia unidade
    terrestre, mas NAO conta como agua de verdade).
33. ~~Deserto e regiao vulcanica finalmente do tamanho de um bioma de
    verdade~~, feito, **reportado pelo usuario** pela QUARTA vez seguida
    sobre o mesmo assunto, bem direto: "esse bioma vulcanico ainda ta
    extremamente pequeno, o de deserto tambem esta extremamente pequeno...
    ja foram tipo 5 prompts... pelo amor de deus cara tenha bom senso, e
    um bioma cara, 5 celulaszinhas nao fazem um bioma". Ate aqui, cada
    rodada anterior (itens 28-32) resolvia um problema estrutural
    diferente (regiao nao-conectada, presa a montanha, celula isolada,
    sem oceano de lava) sem nunca medir o TAMANHO absoluto contra os
    outros biomas — o resultado seguia pequeno porque os limiares nunca
    tinham sido calibrados pra isso. Desta vez, medi de verdade: um censo
    completo de bioma no mapa Grande (contar tiles de cada tipo) mostrou
    Deserto/Estepe com so 45-152 tiles (~0.1-1% da faixa de temperatura
    quente/temperada) contra quase 1000 de Savana/Planicie (a categoria
    "moderada" do meio) na MESMA faixa, e Lava com so 5-40 tiles (~0.1-1%
    do mapa) contra 100-400+ de Floresta/Selva (~2.5-9.5%). Duas causas
    raiz distintas, corrigidas junto: (1) **Deserto** — `_pick_biome()`
    particionava umidade em faixas fixas (0.3/0.6 pro lado quente, 0.3/
    0.65 pro temperado) assumindo distribuicao uniforme, mas
    `_moisture_noise` (FBM multi-octava) NUNCA se comporta assim — medindo
    os PERCENTIS reais (5 sementes, so terra firme), os percentis 33/67
    ficam em -0.126/0.109 de ruido cru, virando 0.437/0.555 depois do
    `(n+1)*0.5`, bem mais estreito que 0.3/0.6. `MOISTURE_DRY_THRESHOLD`/
    `MOISTURE_WET_THRESHOLD` (0.44/0.56) substituiram os numeros fixos
    antigos nas 4 faixas de temperatura que usavam umidade (Estepe/
    Planicie/Floresta e Deserto/Savana/Selva — Tundra/Taiga usava 0.5,
    que ja calhava perto da mediana real, entao ficou de fora). (2)
    **Lava** — `VOLCANIC_NOISE_THRESHOLD` (0.55, ver item 30) foi
    escolhido so pensando em "ainda formar regiao conectada", nunca
    comparado ao tamanho de verdade de Floresta/Selva. Medindo os
    percentis do `_volcanic_noise`: 0.28 com frequencia 0.02 (baixada de
    0.04 — mesma frequencia baixa/correlacionada da umidade, pra dar
    poucas regioes GRANDES em vez de varias pequenas espalhadas) da entre
    250-536 tiles por mapa Grande, maior regiao conectada entre 92-154
    tiles — a mesma ordem de grandeza dos outros biomas. `LAVA_SEA_NOISE_
    THRESHOLD` (item 32) foi re-medido junto (0.65 → 0.42) pra manter a
    mesma proporcao de Mar de Lava dentro da regiao (15-25%) mesmo com a
    regiao de pedra bem maior agora. Resultado final, censo depois da
    correcao (5 sementes): Deserto 207-536 tiles, regiao vulcanica
    (pedra + Mar de Lava) 349-526 tiles — comparaveis a Floresta (198-325)/
    Selva (301-536)/Savana (318-534)/Planicie (307-434), finalmente na
    mesma escala. Verificado tambem que nada regrediu: 40 mapas gerados
    (5 tamanhos) com **zero** celulas isoladas (item 31 continua valendo)
    e **todos** os mapas com Lava continuam tendo rio de lava (item 29).
    Novo **teste de regressao critico**
    (`test_generate_map_desert_and_volcanic_are_comparable_in_size_to_other_biomes`):
    gera o mapa Grande com 5 sementes e exige que Deserto e a regiao
    vulcanica fiquem em pelo menos 30% do tamanho MEDIO de Floresta/
    Selva/Tundra/Taiga do mesmo mapa — nao precisam ser identicos (biomas
    diferentes tem area diferente por natureza), mas nunca mais uma ordem
    de grandeza menores.
34. ~~Ajuste fino do bioma vulcanico: menos regioes separadas, Mar de
    Lava um pouco menor~~, feito, **reportado pelo usuario** — satisfeito
    com o TAMANHO conquistado no item 33 ("bacana, era isso, eu adorei
    como apareceu agora grande e com reais oceanos de lava, era isso
    mesmo"), so pediu dois ajustes finos: "agora so deixe os oceanos de
    lava potencialmente menores, apenas um pouco menores pra ter mais
    terra vulcanica, e diminua a taxa de geracao de biomas de lava,
    porque tem muitos sendo gerados, os que foram gerados estao
    perfeitos, so nao precisa de tantos". Dois ajustes independentes,
    nenhum mexendo no TAMANHO que ja estava aprovado: (1) **menos
    regioes, mesmo tamanho total** — `_volcanic_noise.frequency` baixou
    de 0.02 pra 0.015 (mesmo eixo que ja tinha ido de 0.04→0.02 no item
    33, so um pouco mais longe) — frequencia mais baixa correlaciona o
    ruido numa area maior, entao a mesma "energia" de ruido que antes
    formava 10-16 regioes separadas por mapa Grande agora consolida em
    ~4-10 (medido: media 7.2 em 15 sementes), mantendo a MESMA area total
    aprovada (~200-620 tiles por mapa, a mesma faixa de antes); (2) **Mar
    de Lava um pouco menor** — `LAVA_SEA_NOISE_THRESHOLD` subiu de 0.42
    pra 0.46 (mesmo `_volcanic_noise`, so o limiar do "nucleo liquido"
    mais alto), cortando a fracao de Mar de Lava dentro da regiao
    vulcanica de ~30% pra ~18-21% (medido em 20 sementes) sem nunca
    zerar naturalmente — mais pedra negra, poca de lava proporcionalmente
    menor, exatamente como pedido. Verificado que nada regrediu: 15 mapas
    Grande gerados, zero celulas isoladas, 100% com rio de lava, 100% com
    Mar de Lava presente.
35. ~~Covis de Monstro reforcam a propria guarda com o tempo~~, feito, a
    pedido do usuario: "vamos fazer com que ao redor dos covis de
    monstros spawnem os respectivos montros, mas tem que ter um limite
    pra nao spawnar pra sempre, tipo ao redor de um covil de goblin pode
    spawnar ate sei la 5 goblins... faz isso pra todos os covis". Antes
    disso, um Covil de Monstro (`HexGrid._spawn_monster_lairs`) era so um
    guardiao unico parado pra sempre (`movement_points = 0`) — limpar ele
    uma vez esvaziava o covil de vez, sem nenhuma razao pra voltar la.
    `HexGrid.lair_kind_by_coord` (novo, `Vector2i -> String`) grava qual
    monstro cada covil produz assim que ele nasce, junto com
    `lair_coords`. `HexGrid.process_monster_lairs()` (novo, chamado por
    `GameManager._on_turn_changed()` a cada troca de turno, logo apos o
    turno dos rivais e antes de recalcular a neblina) percorre todo covil
    conhecido e, com `LAIR_SPAWN_CHANCE` (25%) de chance por turno, gera
    mais um monstro do MESMO tipo (`MonsterDatabase.create_monster`, cada
    um continua nascendo parado igual o guardiao original) num tile livre
    da propria area do covil (a celula do covil + os 6 vizinhos) — mas so
    se a populacao viva ali (`_count_live_monsters_near_lair`) ainda nao
    bateu `LAIR_SPAWN_CAP` (5, guardiao original incluso). Reusa a mesma
    aresta que ja delimitava a area do covil (raio 1) tanto pra contar
    quanto pra escolher onde nascer — nunca precisa de mais espaco, ja que
    o teto de 5 sempre cabe nos 7 tiles disponiveis (a propria celula + 6
    vizinhos). Se o guardiao original ja foi derrotado, o proprio tile do
    covil tambem conta como candidato livre (um covil pode "voltar a ser
    guardado" com o tempo, nao so crescer ao redor de um guardiao que
    ainda existe). Nao precisou mexer em `CombatResolver`/`Unit`: como a
    contagem e recalculada do zero a cada chamada varrendo
    `units_by_coord` (nao um contador incremental por unidade), matar um
    monstro simplesmente libera espaco pro covil voltar a spawnar no
    turno seguinte, sem precisar rastrear "de qual covil" cada monstro
    veio. Randomness usa `randi()`/`randf()` globais (mesmo padrao ja
    usado por `RivalAI` pra decisao de turno) — determinismo por semente
    (`map_seed`) so importa pra GERACAO do mapa, nao pra eventos de
    partida em andamento. Limitacao conhecida, aceita de proposito: como
    esses monstros extras nao fazem parte da geracao determinística do
    mapa, `SaveManager` nao os persiste — depois de Salvar/Carregar, cada
    covil volta a ter so o guardiao original (ou nenhum, se ja tinha sido
    limpo), e recomeca a acumular reforco dali pra frente. Testes novos
    em `test/unit/test_monsters.gd`: `lair_kind_by_coord` bate com o tipo
    real do guardiao; rodar `process_monster_lairs()` 300 vezes NUNCA
    deixa nenhum covil passar de `LAIR_SPAWN_CAP` monstros vivos na
    propria area; o mesmo teste, mas confirmando que o limite E atingido
    de verdade (nao passaria so porque a funcao nao faz nada); e todo
    monstro gerado perto de um covil sempre bate com o `kind` daquele
    covil especificamente (nunca mistura tipos).
36. ~~Mapa retangular de verdade, com as dimensoes exatas do
    Civilization~~, feito, a pedido do usuario: "Pequeno (Small): 74 x 46
    celulas, totalizando 3.404 hexagonos. Medio/Padrao (Standard): 84 x
    54 celulas, totalizando 4.536 hexagonos. Grande (Large): 96 x 60
    celulas, totalizando 5.760 hexagonos. Deixe o tamanho do mapa assim."
    Ate aqui o mapa era um LOSANGO/HEXAGONO (todo tile a distancia <=
    raio da origem, formato classico de jogos de estrategia em grid
    axial), com os 3 tamanhos aproximando a CONTAGEM de tile do
    Civilization (raio 25/30/37 dando 1951/2791/4219 tiles) mas nunca a
    FORMA retangular de verdade — o usuario pediu as dimensoes exatas
    largura x altura, nao so uma contagem parecida.
    `HexGrid.generate_map()` trocou de `generate_map(radius, seed)` pra
    `generate_map(width, height, seed)`: o armazenamento continua
    puramente axial `(q, r)` (`HexMetrics`, pointy-top, sem nenhum
    conceito de offset coordinate antes disso), mas a escolha de quais
    `(q, r)` entram no mapa agora usa a conversao offset "odd-r" padrao
    (redblobgames.com/grids/hexagons#coordinates-offset) por LINHA: pra
    cada `row`, a coluna `col` (0..width) vira `q = col - (row - (row &
    1)) / 2`, que desloca fileiras impares meio hexagono pra manter as
    bordas verticais retas — sem isso (testando `q` puro) o resultado
    seria um paralelogramo torto, nao um retangulo de verdade quando
    desenhado. Centralizado perto da origem (linhas/colunas de -metade a
    +metade) pra continuar valendo a suposicao usada em varios sistemas
    de que o "centro do mapa" e perto de `(0,0)` (onde o humano comeca).
    Verificado empiricamente: os 3 tamanhos oficiais batem EXATAMENTE
    (3404/4536/5760 tiles) com toda linha tendo exatamente `width`
    colunas consecutivas (retangulo de verdade, nao paralelogramo/losango).

    **Bola de neve de adaptacoes**, ja que `map_radius` era usado como
    "escala" em varios lugares alem da geracao (mapeados antes de comecar
    a mexer, pra nao quebrar nada por engano): `_temperature_for()`
    (gradiente de latitude pela distancia de `r` ao "equador") passou a
    usar `map_height/2` em vez de `map_radius`, ja que so o eixo Norte-Sul
    (`r`) importa pra clima, nao a largura; a distancia minima de covil/
    bioma forcado do centro (`_min_distance_from_center()`, novo) usa a
    MENOR das duas dimensoes (nao a media), pra nunca excluir o mapa
    inteiro no eixo mais estreito; a contagem de covis (`lair_count`)
    virou `(largura + altura) / 16` (formula derivada da antiga
    `raio / 4`, confirmada batendo o mesmo numero — 9 covis — no tamanho
    Grande novo); a garantia de cobertura de bioma no Grande
    (`_is_large_map_or_bigger()`, novo) compara AREA total em vez de um
    raio unico, ja que os 3 tamanhos agora tem proporcoes W:H diferentes
    entre si; e `HexGrid.get_world_half_extents()` (novo, formula unica
    centralizada em vez de cada consumidor duplicar `sqrt(3)`/`1.5`)
    devolve os limites reais do mapa em coordenadas de mundo — usado pela
    colisao do chao (raycast de clique), `Minimap.gd` (projecao 2D) e
    `RTSCamera.gd` (limite de pan, que virou `pan_bounds_x`/`pan_bounds_z`
    separados em vez de um `pan_bounds` simetrico, ja que largura != altura
    em geral agora). `GameManager._rival_origin()` (posicionamento dos
    rivais ao redor do centro) trocou o raio unico com achatamento fixo de
    0.6 (so ajustado pra caber no losango antigo) por uma elipse escalada
    de verdade pela largura/altura reais do retangulo. `TitleScreen.
    MAP_SIZES` virou `{tier: {width, height}}` em vez de `{tier: radius}`,
    com as 3 entradas usando os numeros exatos pedidos. Salvar/Carregar:
    `SaveManager` trocou o campo `"map_radius"` por `"map_width"`/
    `"map_height"` no JSON, `SAVE_VERSION` subiu pra 7 — saves antigos
    (v6 ou anterior) sao rejeitados na hora do load, mesmo padrao ja
    estabelecido nas versoes anteriores (sem migracao automatica, o jogo
    so pede pra comecar um jogo novo). Testes: os ~45 call sites de
    `generate_map(radius, seed)` espalhados por 5 arquivos de teste
    viraram `generate_map(width, height, seed)` — radios "genericos" (so
    testando determinismo/performance, sem depender do tamanho exato)
    converteram por `largura = altura = 2*raio+1`; qualquer raio que
    representava um dos 3 tamanhos oficiais (25/30/37) virou a referencia
    de verdade `TitleScreen.MAP_SIZES.<tier>.width/height`, pra continuar
    testando o mesmo TIER (importa pros testes de `_ensure_biome_variety`/
    `_ensure_lava_sea_present`, que so ligam no tamanho Grande de verdade).
37. ~~Rios (agua e lava) sem mais frestas/buracos no meio do mapa~~,
    feito, **reportado pelo usuario** com screenshot: "resolva esses bugs
    que tem pelo mapa de frestas sem textura" — a screenshot mostrava o
    rio de lava como uma serie de tracinhos laranja soltos, com terreno
    preto intocado entre eles, em vez de um rio continuo. Causa raiz: a
    malha de rio (`_rebuild_river_mesh`/`_rebuild_lava_river_mesh`)
    desenhava, POR ARESTA, so uma cunha fina colada na borda
    compartilhada entre os dois tiles, puxada pra dentro por uma largura
    FIXA pequena (0.14 pra agua, 0.16 pra lava). Como o apotema de um
    hexagono com `hex_size=1.0` e ~0.87, essa cunha cobria so uma fatia
    minuscula perto da borda — quase 0.7 unidade de terreno no MEIO de
    cada tile atravessado pelo rio ficava sem nenhuma geometria de rio em
    cima, e cada aresta era uma "ilha" geometrica propria, sem tocar a
    aresta seguinte do mesmo rio. O bug sempre existiu nos DOIS rios
    (agua e lava, mesma tecnica), mas so foi notado no de lava — laranja
    vibrante sobre pedra preta torna o problema muito mais visivel que
    azul sobre chao comum. Corrigido trocando a fita pra ir do CENTRO de
    um tile ate o CENTRO do vizinho (em vez de so uma cunha perto da
    borda): como duas arestas consecutivas do mesmo rio sempre
    compartilham um tile, e cada uma desenha ate o centro EXATO desse
    tile, as duas se encontram exatamente ali — sem buraco no meio do
    tile nunca mais. Nova funcao pura `_river_segment_corners(a, b,
    height_offset, width)`, compartilhada pelos dois rios, devolve os 4
    cantos da fita (testavel sem precisar de `SurfaceTool`/contexto de
    desenho); `_add_river_segment()` so alimenta esses cantos na malha.
    Removido `_neighbor_direction_index()` (ficou sem nenhum uso depois
    da mudanca — a tecnica antiga precisava saber qual aresta exata do
    hexagono desenhar, a nova so precisa dos dois centros). Testes novos
    em `test_terrain_generation.gd`:
    `test_river_segment_corners_pass_through_the_shared_tile_center`
    (duas arestas consecutivas A-B e B-C, confirma que a fita de CADA UMA
    passa exatamente pelo centro real do tile B compartilhado, provando
    que nao sobra buraco) e `test_river_segment_corners_is_empty_for_zero_length_segment`
    (caso degenerado `a == b`).
38. ~~Rio de lava parou de virar uma mancha densa cobrindo a regiao
    inteira~~, feito, **reportado pelo usuario** com screenshot logo
    depois do item 37: "piorou, o que era pra ser isso?" — a screenshot
    mostrava o mapa coberto por uma rede grossa e blocuda de linhas
    laranja, muito pior que antes. Nao era um bug na correcao do item 37
    em si (a geometria centro-a-centro continuava certa) — era a
    QUANTIDADE de rios. Causa raiz: `_generate_lava_rivers()` tratava
    TODO tile de Lava que fosse um "pico local" (so precisava ser mais
    alto que os 6 vizinhos IMEDIATOS, um criterio bem fraco) como
    nascente de rio. Antes do item 33 (regiao vulcanica pequena, poucos
    tiles) isso raramente dava mais de 1-2 nascentes por regiao. Depois
    do item 33 (regiao vulcanica 10-40x maior), uma regiao grande com
    elevacao ondulada naturalmente tem DEZENAS de picos locais — medido
    empiricamente: uma regiao real de 648 tiles tinha 47 nascentes
    independentes, cada uma tracando o proprio caminho, dando 348 arestas
    de rio (mais da METADE dos tiles da regiao com rio em cima). Juntando
    isso com a correcao do item 37 (cada aresta agora e uma fita cheia
    ate o centro do tile, nao mais so uma lasca fina), o resultado visual
    virou uma mancha solida cobrindo quase a regiao inteira, exatamente a
    screenshot. Corrigido limitando a quantidade de nascentes por REGIAO
    CONECTADA de Lava (nao mais por pico individual): nova funcao pura
    `_lava_river_sources_for_region()` escolhe os tiles de MAIOR elevacao
    de cada regiao, numa quantidade pequena e proporcional ao tamanho
    dela (`LAVA_RIVER_SOURCES_PER_TILES = 60`, 1 nascente extra a cada 60
    tiles conectados; `LAVA_RIVER_MAX_SOURCES_PER_REGION = 4`, nunca mais
    que isso mesmo numa regiao gigante). `_generate_lava_rivers()` passou
    a iterar por REGIAO (`_connected_components_of()`, funcao nova,
    generalizada a partir de `_largest_cluster_of()` que ja existia so
    pra achar a maior — agora tambem usada pra achar TODAS as regioes
    separadas) em vez de por tile individual. Removida
    `_is_local_lava_elevation_peak()` (criterio antigo, sem uso depois da
    troca). Resultado medido nas mesmas 5 sementes: arestas de rio de
    lava cairam de 348 pra 166 numa regiao de 648 tiles (~52% menos,
    ~26% dos tiles com rio em vez de mais da metade). Testes novos:
    `test_lava_river_sources_for_region_scales_with_region_size` (regiao
    pequena = 1 nascente, media = mais de 1 mas nunca passa do teto,
    gigante = bate EXATAMENTE no teto, nunca "uma nascente por tile") e
    `test_generate_map_lava_rivers_are_not_overly_dense` (5 sementes no
    mapa Grande de verdade, exige que arestas de rio de lava fiquem
    abaixo de 50% dos tiles de Lava do mapa).

## Assets e plugins de terceiros avaliados

Pesquisa feita em 2026-08 pra achar recursos gratuitos/licenca permissiva
(CC0 na maioria, uso livre, comercial incluido, sem exigir atribuicao)
que poderiam acelerar o jogo sem comprometer o licenciamento. Guardado
aqui pra nao perder o levantamento entre sessoes.

**Modelos 3D** (substituiriam ou complementariam as formas procedurais
atuais de `Unit.gd`/`City.gd`):
- [Kenney Castle Kit](https://kenney.nl/assets/castle-kit), 75 pecas
  (torres, muralhas, portoes), CC0. **Usado, depois revertido**: a torre
  hexagonal + bandeira chegaram a substituir o castelo procedural de
  `City.gd`, mas voltaram atras a pedido do usuario (ver roadmap item 19).
  Arquivos continuam em `assets/models/castle/`.
- [Kenney Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit),
  160 pecas de construcao, CC0.
- [Kenney + Kay Lousberg Character Assets](https://www.kaylousberg.com/work/kenney-character-assets),
  4 modelos base, 75+ skins, 17 animacoes, 40 acessorios. **Pago** (so
  demo gratis no itch.io), checado depois da primeira pesquisa, entao
  nao usado aqui.
- [Kenney Mini Characters](https://kenney.nl/assets/mini-characters), CC0,
  mas checado e **descartado**: tema e pessoas modernas com acessibilidade
  (cadeira de rodas, bengala, aparelho auditivo), nao da pra reaproveitar
  num jogo medieval.
- [Kenney Modular Characters](https://kenney.nl/assets/modular-characters),
  CC0, 425 pecas, mas provavelmente rig+encaixe de armadura/arma, mais
  complexo de integrar sem poder testar no editor, nao avaliado a fundo.
- **[Quaternius RPG Character Pack](https://quaternius.com/packs/rpgcharacters.html)**,
  **usado, depois revertido**. 6 personagens fantasia riggeds/animados
  (Warrior, Ranger, Rogue, Cleric, Wizard, Monk), CC0, glTF/FBX/OBJ/Blend.
  So disponivel via pasta do Google Drive (nao da pra baixar com curl
  simples); usei Warrior, Ranger e Monk pra Guerreiro/Arqueiro/
  Colonizador, mas voltei pra forma procedural a pedido do usuario (ver
  roadmap item 19). Ver detalhes mais abaixo.
- [Kenney Retro Medieval Kit](https://kenney-assets.itch.io/retro-medieval-kit),
  100 modelos estilo retro, CC0. Nao verificado se tem personagens (so
  hospedado no itch.io, nao consegui listar o conteudo sem baixar).
- [CraftPix Medieval 3D People](https://craftpix.net/freebies/free-medieval-3d-people-low-poly-models/),
  14 personagens (camponeses, mercadores, rei/rainha), licenca livre
  pra uso comercial (nao e CC0, mas sem exigir atribuicao). So FBX. Site
  bloqueia download automatizado (Cloudflare), precisaria baixar manual.
- [Quaternius Medieval Village MegaKit](https://quaternius.com/packs/medievalvillagemegakit.html),
  300+ pecas modulares de vilarejo, CC0.

**Texturas de terreno**:
- [Poly Haven](https://polyhaven.com/textures/ground-terrain), PBR CC0
  ate 8K, sem precisar de login.
- [ambientCG](https://ambientcg.com/), 2000+ materiais PBR CC0. **Usado**:
  [Ground037](https://ambientcg.com/view?id=Ground037) (terreno comum) e,
  pros biomas especiais (roadmap item 27),
  [Snow006](https://ambientcg.com/view?id=Snow006) (Neve/Gelo Eterno),
  [Ground033](https://ambientcg.com/view?id=Ground033) (Deserto),
  [Rock035](https://ambientcg.com/view?id=Rock035) (base de pedra da
  Lava) e [Ice003](https://ambientcg.com/view?id=Ice003) (base facetada
  dos Campos de Cristal) — ver integracao abaixo.

**Audio**, **integrado**, ver detalhes abaixo:
- [OpenGameArt "CC0 Fantasy Music & Sounds"](https://opengameart.org/content/cc0-fantasy-music-sounds),
  usei a faixa ["Town Theme RPG"](https://opengameart.org/content/town-theme-rpg)
  de la como musica de fundo.
- [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio),
  [UI Audio](https://kenney.nl/assets/ui-audio) e
  [Music Jingles](https://kenney.nl/assets/music-jingles), efeitos de
  clique, combate, fundacao/captura de cidade e fanfarra de
  vitoria/derrota.

**Plugins (Godot Asset Library)**:
- [LimboAI](https://godotengine.org/asset-library/asset/4852), behavior
  trees + state machines. Instalado (`addons/limboai/`) mas **decidido
  nao usar** pra IA, jogo precisa rodar 100% offline e um GDExtension
  de terceiros nao testado e risco alto pra IA (ver detalhes abaixo). A
  IA rival melhorou sem isso, so com GDScript proprio.
- [GUT](https://godotengine.org/asset-library/asset/1709), testes
  automatizados. Resolve o item 6 do roadmap.
- [Hex Strategy Map](https://godotengine.org/asset-library/asset/5136),
  addon completo de hex grid (pathfinding, camera), lancado maio/2026.
  Avaliado e **descartado por ora**: nosso `HexGrid`/`RTSCamera` proprio ja
  funciona e esta profundamente integrado com fog of war, combate e
  captura de cidade, trocar seria risco alto pra ganho baixo.

**Integrado, GUT**: instalado em `addons/gut/` e habilitado em
`project.godot` (`[editor_plugins]`). Escrevi testes de verdade em
`test/unit/` cobrindo:
- `test_hex_metrics.gd`, matematica do grid (conversao axial<->mundo,
  distancia, cantos do hexagono).
- `test_combat_resolver.gd`, dano corpo-a-corpo, ataque a distancia sem
  contra-ataque, unidade morta sai do grid e da lista do dono, e
  veterania: abate sobe de nivel/titulo, promocao cura uma fracao do HP
  maximo, defensor que sobrevive matando o atacante tambem ganha credito,
  atacante veterano causa mais dano que um recruta, Mago ignora o bonus
  de defesa de terreno do defensor, Muralhas reduzem o dano recebido por
  uma unidade guarnicionada na cidade, Mago ignora esse bonus tambem, e
  derrotar o guardiao de um Covil de Monstro credita `gold_reward` pro
  dono do atacante em vez de so remover a unidade sem efeito nenhum.
- `test_city.gd`, troca de producao zera progresso (a menos que seja o
  mesmo item), crescimento populacional, unidade spawnada ao completar
  producao, e o sistema de tiles trabalhados: `collect_yields()` so soma
  o que esta em `worked_tiles` (**teste de regressao** pro comportamento
  antigo de somar todo vizinho automaticamente), atribuicao automatica ao
  fundar/crescer, limite pela populacao, alternar manualmente, conflito
  entre cidades vizinhas pelo mesmo tile, `effective_tile_yield()` soma
  bonus de tech + recurso corretamente, `collect_yields()` aplica o
  multiplicador de dificuldade do dono (`PlayerData.yield_multiplier`) no
  total, `production_cost()`/`can_build()` reconhecem um id de predio
  (`BuildingDatabase`) alem de kind de unidade, completar um predio marca
  `buildings[id]=true` e troca a producao de volta pro Colonizador (unico
  kind sempre produzivel, ver `can_train()` abaixo) em vez de tentar
  reconstruir o mesmo predio, `collect_yields()` soma o bonus permanente
  dos predios construidos, `max_building_slots()` bate com a populacao da
  cidade e `can_build()` respeita esse limite mesmo pra um predio novo
  (nao so pro ja construido); `is_valid_building_tile()` aceita um
  vizinho livre de terra firme e rejeita tile longe demais da cidade,
  oceano, ocupado por unidade/cidade, ou ja usado por outro predio;
  `process_turn()` grava `building_coords[id]` e devolve `built_coord` SO
  quando o jogador escolheu um tile (`pending_building_coord`), com
  **graceful degrade** pra quando `set_production()` foi chamado direto
  sem passar pelo posicionamento (o predio ainda conta pro bonus/limite,
  so fica sem coordenada); **teste de regressao** garantindo que
  abandonar um predio em obra (trocar de producao antes de completar)
  limpa `pending_building_coord` em vez de deixar o tile "preso" (mas
  trocar entre unidades sem nenhum predio envolvido nao mexe nele);
  **teste de regressao** pro auto-assign preferir um tile com bonus de
  recurso a uma planicie comum de rendimento cru maior; producao default
  de uma cidade nova e Colonizador (nao mais Guerreiro, que agora exige
  Quartel); `can_train()`: Guerreiro fica bloqueado sem o Quartel
  construido NESTA cidade, libera assim que `buildings["barracks"]` e
  marcado, o predio de treino de uma tropa nao libera outra (ter Quartel
  nao libera Arqueiro), e Colonizador ignora o gate por nao ter nenhum
  predio de treino associado; e `can_build()` de um predio de TREINO
  agora tambem exige a tecnologia certa (Campo de Tiro so fica construivel
  depois de pesquisar Tiro com Arco), Quartel continua sempre construivel
  (Guerreiro nunca exigiu pesquisa), e **teste de regressao critico**
  garantindo que um predio de PRODUCAO (Celeiro, `trains_unit` vazio)
  nunca exige tecnologia nenhuma (pego um bug de verdade nisso, ver
  roadmap item 21: sem uma guarda pra `kind == ""`,
  `TechDatabase.tech_that_unlocks()` acabaria "encontrando" a primeira
  tech de bioma da lista por acidente); e `effective_tile_yield()` da
  +1 comida quando o tile tem rio (`HexTileData.has_river`), nada extra
  quando nao tem.
- `test_hex_grid_movement.gd`, **teste de regressao** pro bug que voce
  encontrou (cidade inimiga entrando em "alcancavel por movimento" e
  atrapalhando a captura), captura de cidade, bloqueio de empilhamento de
  unidades, `tiles_in_range()` (base do alcance de ataque, so tinha
  cobertura indireta antes): devolve os vizinhos certos, exclui o proprio
  centro, respeita o raio; o Grifo (`UnitData.flies`): atravessa oceano
  onde uma unidade terrestre fica presa, e ignora custo de terreno
  (2 pontos de movimento alcancam 2 MONTANHAS voando, nao so 1); e
  predios posicionaveis: `place_building()` registra o modelo no coord
  certo (`get_building_at`), `is_tile_building_site()` reflete isso;
  contorno de cidade: fundar cria um contorno, capturar RECONSTROI ele
  (cor precisa seguir o novo dono), `city_territory_tiles()` inclui a
  propria cidade e todos os vizinhos; e o marcador de "em construcao":
  `refresh_construction_markers()` cria um marcador quando uma cidade tem
  `pending_building_coord` setado e remove quando nao tem mais (predio
  completou ou foi abandonado); e os 2 biomas novos intransitaveis: Lava
  e Mar Gelado bloqueiam unidade terrestre igual Oceano sempre bloqueou,
  mas o Grifo (unico que voa) atravessa os dois sem problema.
- `test_hexgrid_fog.gd`, fog of war nunca tinha teste proprio apesar de
  ser a base do fog do jogador E do "fog of war propria" da IA
  (`RivalAI.take_turn`): uniao de visao de unidade+cidade,
  `recompute_fog()` so escurece pra EXPLORADO (nunca volta a NAO VISTO)
  quando um tile ja visto sai de alcance, e unidade/cidade/**predio**
  inimigo so aparece (`.visible`) em tile ATUALMENTE visivel, nao so por
  ja ter sido explorado antes; e o toggle de Debug
  (`debug_fog_disabled`): com ele ligado, `recompute_fog()` marca o mapa
  inteiro como visivel (inclusive unidade inimiga NUNCA vista de
  verdade), e `set_debug_fog_disabled()` (o metodo publico que a HUD
  chama) liga a flag e reaplica na hora, sem esperar o proximo turno.
- `test_rival_ai.gd`, `CombatResolver.predict()` bate com o dano real de
  `resolve()`, IA nao ataca se for morrer no proprio golpe, cura por
  guarnicao (so cura dentro da propria cidade, nao na do inimigo),
  regeneracao passiva do Ent (`GameManager._apply_regen`: cura em
  QUALQUER lugar, nao so guarnicionado; nunca passa do HP maximo; unidade
  sem `regen_fraction` nao cura sozinha fora de cidade), fog of war da IA
  (ignora unidade inimiga fora de visao, lembra de cidade ja escoutada
  mesmo fora de visao depois), coordenacao tatica (arqueiro sozinho nao
  avanca sem escolta corpo-a-corpo por perto, avanca normal com escolta),
  diplomacia: em paz, a IA nunca mira no jogador humano mesmo com alvo
  visivel no alcance; e tropas raciais (`_military_kinds_for`): o pool de
  producao de um anao inclui Guarda-Machado Anao, mas nunca Berserker Orc
  nem Patrulheiro Elfico (nao vaza pra outra raca), civ sem raca nenhuma
  nao ve tropa exclusiva nenhuma no proprio pool, e `decide_production()`
  de verdade eventualmente sorteia a tropa racial de um rival orc (nao so
  a lista em si, o fluxo completo).
- `test_selection_manager.gd`, **teste de regressao** pro bug de atacar
  em loop infinito (alvo continuava "atacavel" depois da unidade ja ter
  agido no turno), diplomacia: unidade/cidade de um jogador em paz
  nunca aparece como atacavel, guardiao neutro de Covil de Monstro
  sempre atacavel mesmo sem nenhuma guerra declarada contra ele (nao ha
  diplomacia com um monstro), `_attack_target_name()` devolve o nome
  certo pro aviso "ATACAR X" do hover, tanto pra unidade quanto pra
  cidade; e posicionamento de predio: `start_building_placement()` lista
  so vizinhos validos (exclui um ocupado por unidade), clicar um tile
  destacado confirma (seta `production_item`/`pending_building_coord` e
  encerra o modo), e clicar um tile invalido cancela sem mudar nada.
- `test_diplomacy.gd`, jogadores comecam em paz, guerra e sempre
  imediata e simetrica, e a heuristica de aceitacao de paz da IA
  (`Diplomacy._accepts_peace`): aceita em desvantagem numerica ou
  empatada, recusa se estiver "ganhando".
- `test_game_manager.gd`, `setup_players()` cria o numero certo de
  rivais (limitado ao pool disponivel), cada um com nome de civ distinto
  e em guerra com o humano por padrao; `check_game_over()` so declara
  vitoria quando TODOS os rivais forem eliminados, nao mais um unico
  rival fixo; rivais comecam espalhados em pontos diferentes do mapa;
  `setup_players()` aplica o multiplicador de dificuldade certo
  (`DIFFICULTY_MULTIPLIERS`) so aos rivais, humano sempre fica em 1.0;
  **teste de regressao** garantindo que humano e rivais nunca comecam na
  mesma coordenada num mapa pequeno; e `setup_players()` copia o campo
  `race` novo de `RIVAL_CIVS` pro `CivilizationData` de cada rival (todo
  rival do pool atual tem uma raca de fantasia), enquanto o jogador
  humano continua sem raca nenhuma; o pipeline inteiro de
  `start_new_game()` (gerar mapa + espalhar civs) continua funcionando de
  ponta a ponta no tamanho Medio (84x54, 4536 tiles), nao so nos mapas
  pequenos que o resto da suite ja cobria; e os 2 metodos de Debug:
  `debug_force_game_over()` seta o estado e emite o MESMO sinal
  `EventBus.game_over` de um fim de jogo real, e
  `debug_complete_current_research()` completa a pesquisa escolhida (ou
  nao faz nada, sem travar, se nao houver nenhuma selecionada).
- `test_world_setup.gd`, `find_start_tile()` prefere planicie mais
  proxima da origem, cai pro fallback sem planicie, e **teste de
  regressao** garantindo que nunca devolve uma coordenada excluida (nem
  na busca preferida, nem no fallback) nem um tile ja guardado por um
  Covil de Monstro (senao uma capital podia nascer em cima de um
  guardiao).
- `test_save_manager.gd`, round-trip completo de salvar/carregar: mesma
  semente recria o mesmo terreno, ouro/unidades (hp, movimento,
  coordenada, veterania)/cidades (populacao, producao, fila, tiles
  trabalhados), tecnologia (pesquisadas, pesquisa atual, progresso) e
  diplomacia (paz negociada) voltam identicos depois de passar por JSON
  em disco, pra qualquer numero de rivais; dificuldade escolhida
  (`GameManager.difficulty`) sobrevive ao save/load e o multiplicador
  certo e reaplicado aos rivais ao carregar; predios construidos
  (`City.buildings`) sobrevivem ao save/load; um predio POSICIONADO no
  mapa (`City.building_coords`) volta com o modelo 3D recriado no MESMO
  tile (`HexGrid.get_building_at`); todo o mapa de monstros neutros (guardiao
  original sobrevivente, reforco e resultado de patrulha, sem distincao
  entre os tres) sobrevive ao save/load por inteiro — nao so "quais covis
  foram limpos" (ver `HexGrid.neutral_units`/`clear_neutral_units`,
  `SaveManager._serialize_neutral_units`/`_deserialize_neutral_units`) — e
  o `.state` do RNG dedicado de covil (`HexGrid.monster_turn_rng`,
  serializado como STRING pra nao perder precisao de inteiro de 64 bits
  virando float no JSON) volta exatamente de onde parou, pra reforco/
  patrulha futuros continuarem deterministicos mesmo depois de um load; e
  **teste de
  regressao** garantindo que `GameManager.map_radius` (usado pelo limite
  de pan da camera) e atualizado pro raio de verdade do mapa carregado,
  nao fica "preso" no raio da partida anterior.
- `test_monsters.gd`, `MonsterDatabase.gd`: todo monstro tem recompensa
  de ouro positiva e nunca se move, `random_kind()` sempre devolve um
  kind valido e e deterministico pra mesma semente; geracao de mapa:
  `_spawn_monster_lairs()` cria guardioes neutros (owner_player nulo)
  nos coords certos, nunca em oceano, nunca perto demais do centro do
  mapa (onde o humano comeca), a colocacao dos covis e 100%
  deterministica pela `map_seed` (mesma garantia que terreno/recursos), e
  `lair_kind_by_coord` bate com o tipo real do guardiao de cada covil; e
  reforco periodico (roadmap item 35): `process_monster_lairs()` chamado
  300 vezes seguidas NUNCA deixa nenhum covil passar de
  `LAIR_SPAWN_CAP` monstros vivos na propria area (a celula do covil + 6
  vizinhos), o mesmo teste confirmando que o limite E atingido de
  verdade (nao passaria so por `process_monster_lairs()` nao fazer
  nada), e todo monstro gerado perto de um covil sempre bate com o
  `kind` daquele covil especificamente, nunca mistura tipos.
- `test_settings.gd`, `Settings.gd`: volume de musica/efeitos sempre
  fica entre 0 e 1 mesmo passando valores fora da faixa, `set_*_volume()`
  emite `volume_changed`, e o ciclo salvar/carregar via `ConfigFile`
  (`save_settings()`/`load_settings()`, path parametrizavel pro teste
  igual `SaveManager`) preserva os valores, sem arquivo ainda, mantem os
  valores atuais em vez de resetar.
- `test_buildings.gd`, `BuildingDatabase.gd`: consulta por id (id
  desconhecido devolve null), `total_bonus()` soma o rendimento de VARIOS
  predios construidos ao mesmo tempo (so contabiliza food/production/gold
  de quem da esse tipo de bonus), `defense_bonus_for()` soma so o bonus
  de Muralhas (ignora predios de yield), cada predio tem um id unico; e
  `building_that_trains()`: acha o Quartel a partir de "warrior", devolve
  null pro Colonizador (sem predio de treino associado), os 4 predios de
  producao (Celeiro/Oficina/Mercado/Muralhas) tem `trains_unit` vazio, e
  cada uma das 7 tropas de combate tem exatamente um predio de treino
  (nenhuma duplicada, nenhuma faltando).
- `test_terrain_generation.gd`, a matriz temperatura x umidade escolhe o
  bioma certo em cada combinacao (frio/temperado/quente cruzado com seco/
  moderado/umido, agora incluindo Gelo Eterno na faixa mais fria de
  todas), **teste de regressao** pra geracao continuar 100% deterministica
  pela `map_seed` (mesma semente = mesmo terreno; sementes diferentes
  podem divergir), a base que Salvar/Carregar depende pra nunca precisar
  guardar os tiles em si; os biomas raros novos como funcoes puras
  (`_pick_water_biome`/`_pick_mountain_biome`/`_maybe_crystal`): Mar
  Gelado so com temperatura baixa, Lava so com ruido vulcanico alto,
  Campos de Cristal so substitui o bioma "plano" ja escolhido quando o
  ruido arcano passa do limiar (senao devolve o original sem mexer);
  `blocks_land_units()`: Oceano/Mar Gelado/Lava sim, Planicie nao, e
  `is_water()` especificamente NAO inclui Lava (intransitavel mas nao e
  agua); e rios (`_generate_rivers`/`river_edges`): deterministicos pela
  `map_seed` igual todo o resto, um mapa 41x41 com semente fixa produz
  pelo menos uma aresta de rio (evita um teste "vazio" que passaria
  mesmo sem `_generate_rivers()` gerar nada), toda aresta liga vizinhos
  DE VERDADE e marca `has_river` dos dois lados,
  `has_river_between(a, b) == has_river_between(b, a)`; **teste de
  regressao critico** (roadmap item 37, pego pelo bug de "frestas sem
  textura" no rio): `_river_segment_corners()` (funcao pura compartilhada
  pelos rios de agua e lava) passa exatamente pelo centro real do tile
  compartilhado entre duas arestas consecutivas do mesmo rio, provando
  que a malha fica continua sem buraco no meio, mais o caso degenerado
  `a == b`; **teste de regressao critico** (roadmap item 38, pego pelo
  bug de "piorou" logo em seguida — a correcao acima deixou uma rede
  DENSA demais de rio de lava visivel): `_lava_river_sources_for_region()`
  devolve so 1 nascente pra regiao pequena, mais de 1 mas nunca acima do
  teto pra regiao media, e exatamente o teto (nunca "uma nascente por
  tile") pra regiao gigante; e gerando o mapa Grande de verdade com 5
  sementes, arestas de rio de lava ficam sempre abaixo de 50% dos tiles
  de Lava do mapa; **teste de performance**: gerar o mapa Grande (96x60,
  5760 tiles) precisa
  continuar rapido o bastante (limiar bem folgado, so pra pegar uma
  regressao de verdade tipo geracao virar acidentalmente quadratica);
  `_material_kind_for()` (funcao pura que diz ao shader qual tratamento
  visual usar): Neve/Gelo Eterno mapeiam pro mesmo numero (1), Deserto
  (2), Lava (3), Cristal (4), qualquer bioma comum devolve 0; a garantia
  de cobertura no tamanho Grande (`_ensure_biome_variety`, **teste de
  regressao critico**, ver roadmap item 26): gerar o mapa Grande de
  verdade com 2 sementes diferentes sempre contem os 16 tipos de bioma
  (inclusive quando nenhum tile bate a faixa de elevacao EXATA que um
  bioma precisa — `_find_closest_elevation_tile()`, fallback pego pelo
  proprio teste ao baixar a frequencia do ruido, ver roadmap item 28),
  continua deterministico com a mesma semente, e nao mexe em nada abaixo
  do limiar do tamanho Grande; e **teste de regressao critico** pra
  biomas formarem REGIOES continuas em vez de "sal e pimenta" (roadmap
  item 28): a fracao media de vizinhos do MESMO bioma, pro mapa inteiro,
  precisa passar de uma margem folgada (medido empiricamente: ~75% com o
  ruido re-tunado, contra quase-ruido-puro antes da correcao); e o
  redesenho do bioma vulcanico (roadmap itens 29-30): Lava formando
  regiao agrupada de verdade numa semente/raio confirmados manualmente a
  gerar mais de um tile de Lava (fracao com pelo menos um vizinho tambem
  de Lava > 0.5, nao so picos isolados), `lava_river_edges`
  deterministico pela `map_seed`, toda aresta de rio de lava ligando dois
  vizinhos DE VERDADE que sao os dois tiles de Lava (nunca sai da regiao
  vulcanica), `has_lava_river_between(a, b) == has_lava_river_between(b, a)`,
  **teste de regressao** garantindo que nenhuma aresta de rio de AGUA
  passa por um tile de Lava (agua desvia da regiao vulcanica); **teste
  de regressao critico**, pego pelo bug de "no maximo vem uma celula
  vulcanica" reportado logo depois do item 29 (ver detalhes no roadmap):
  gera o mapa Grande de verdade com 8 sementes diferentes e exige que
  TODAS formem uma regiao de Lava conectada de pelo menos
  `FORCED_CLUSTER_MIN` tiles, nunca so celulas isoladas;
  `_maybe_volcanic()` como funcao pura (mesmo padrao de `_maybe_crystal`,
  cobrindo terreno plano/Colina/Montanha, roadmap item 30); **teste de
  regressao critico** pego pelo bug seguinte, "ta fazendo como se fossem
  montanhas" (roadmap item 30): gera o mapa Grande com 5 sementes
  diferentes e exige que a MAIORIA dos tiles de Lava de cada mapa esteja
  em elevacao originalmente PLANA, nao Colina/Montanha; generalizando
  a garantia de regiao pra QUALQUER bioma (roadmap item 31):
  `test_generate_map_never_has_isolated_single_tile_biomes` — gera 30
  mapas (Pequeno/Medio/Grande) e exige ZERO tiles sem nenhum vizinho do
  mesmo bioma, qualquer um dos 17 tipos — e
  `test_generate_map_at_large_size_lava_always_has_a_river_when_present`
  — todo mapa Grande que tem Lava precisa ter pelo menos um rio de lava;
  e o Mar de Lava (roadmap item 32): `_maybe_volcanic()` cruzando o
  segundo limiar (mais alto) vira `LAVA_SEA` em vez de `LAVA`,
  `test_generate_map_at_large_size_always_has_a_lava_sea_when_lava_present`
  (8 sementes, exige Mar de Lava presente E conectado — nunca 1 tile
  isolado — sempre que ha Lava no mapa Grande), `_material_kind_for`
  devolve 5 pro Mar de Lava (o shader usa isso pra tingir de vermelho/
  emissivo em vez do azul padrao de agua), e `is_lava()`/
  `blocks_land_units()`/`is_water()`: Mar de Lava bloqueia unidade
  terrestre igual pedra de Lava mas NAO conta como agua de verdade; e
  **teste de regressao critico** (roadmap item 33), pego pelo bug de
  Deserto/Lava ficarem "extremamente pequenos" comparado aos outros
  biomas: `test_generate_map_desert_and_volcanic_are_comparable_in_size_to_other_biomes`
  — gera o mapa Grande com 5 sementes e exige que Deserto e a regiao
  vulcanica (pedra + Mar de Lava) fiquem em pelo menos 30% do tamanho
  MEDIO de Floresta/Selva/Tundra/Taiga do mesmo mapa.
- `test_tech.gd`, disponibilidade de tecnologia por pre-requisito,
  desbloqueio de Arqueiro/Cavaleiro/Catapulta/Mago/Grifo (este ultimo
  exige Equitacao pesquisada antes) / Ent (Druidismo, sem pre-requisito),
  bonus de rendimento por bioma aplicado em `City.collect_yields()`,
  processamento de pesquisa por turno (ciencia acumula so com uma
  pesquisa escolhida, completa ao bater o custo), **teste de regressao**
  garantindo que a IA nunca produz uma unidade que ainda nao desbloqueou;
  e `tech_that_unlocks()`: acha Tiro com Arco a partir de "archer",
  devolve null pra Guerreiro (nunca exigiu pesquisa nenhuma), e devolve
  null pra `kind == ""` explicitamente (**teste de regressao** pro bug
  descrito no roadmap item 21 — sem essa guarda, `""` "encontraria" a
  primeira tech de bioma da lista, ja que `unlocks_unit` tambem faz
  default pra `""` nelas).
- `test_resources.gd`, elegibilidade de recurso por bioma, bonus de
  yield aplicado em `City.collect_yields()`, oceano nunca tem recurso, e
  **teste de regressao** pra colocacao de recurso continuar
  deterministica pela `map_seed` (mesma logica exigida da geracao de
  bioma, ver `test_terrain_generation.gd`).
- `test_tech_tree.gd`, `TechTree._compute_tiers()`: raiz sem
  pre-requisito fica no tier 0, tecnologia dependente fica num tier maior
  que o proprio pre-requisito; `_effect_summary()` mostra desbloqueio de
  unidade ou bonus de rendimento; `rebuild()` cria exatamente um card por
  tecnologia e posiciona a dependente numa coluna a direita do proprio
  pre-requisito.
- `test_hud.gd`, primeira suite GUT deste projeto a instanciar a cena
  `.tscn` inteira (`add_child_autofree`) em vez de so a classe do script:
  `close_topmost_overlay()` fecha o overlay aberto (e o fundo escurecido
  junto) ou devolve false se nao tinha nenhum, abrir um segundo overlay
  fecha o primeiro, fim de jogo fecha qualquer overlay aberto e desabilita
  os botoes que poderiam fechar a propria tela de fim de jogo (agora
  incluindo o botao de Debug), e reiniciar reabilita esses botoes; e o
  painel de Debug: segue a mesma regra de overlay unico, o botao so fica
  visivel de acordo com `OS.is_debug_build()`, +100 Ouro soma no
  `PlayerData` de verdade E atualiza o label na hora, e Vencer/Perder
  Agora mostram a tela de fim de jogo de verdade (fechando o proprio
  painel de Debug junto, mesmo sinal `EventBus.game_over` de um fim de
  jogo real).
- `test_minimap.gd`, primeira suite pra `Minimap.gd` (sem cobertura
  nenhuma antes): `_unit_dot_color()` (**teste de regressao critico**,
  ver secao de bugs acima) cai no fallback `Unit.MONSTER_COLOR` pra uma
  unidade sem dono (guardiao de Covil de Monstro) em vez de derrubar o
  redesenho do minimapa inteiro, e usa a cor da propria civilizacao pra
  uma unidade normal.

Pra rodar: abra o painel do GUT no editor (Project > Tools > GUT, depois
que o plugin carregar) e aponte pra `res://test/unit` (ja configurado em
`.gutconfig.json`, mas pode precisar apontar manualmente se o painel nao
ler o arquivo automaticamente).

Tambem da pra rodar tudo pela linha de comando, sem abrir o editor,
util pra CI ou pra validar de verdade em vez de so ler o codigo:
```
<caminho-do-Godot>_console.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```
Se aparecer erro de classe global nao reconhecida (`"X" not declared in
the current scope`) num script que criou/moveu recentemente, o cache de
classes do Godot (`.godot/global_script_class_cache.cfg`) esta
desatualizado, rode uma vez `--headless --editor --quit-after 20` pra
forcar uma reescaneada antes de tentar de novo.

**LimboAI, instalado mas descartado pra IA**: binario GDExtension ainda
esta em `addons/limboai/` (release v1.8.0, so binarios Windows), mas a
decisao final foi **nao usa-lo**. Dois motivos: (1) o jogo precisa
funcionar 100% offline/local, e um GDExtension de terceiros que eu nunca
vi carregar de verdade e um risco maior do que o ganho justifica,
diferente de um asset com fallback automatico (modelo errado = flutua
mas o jogo roda), uma IA que depende de um plugin que falha ao carregar
quebraria o turno do rival inteiro; (2) da pra fazer IA decente sem isso,
ver a melhoria de `RivalAI.gd` abaixo, tudo em GDScript puro. Fica
instalado caso mude de ideia depois, mas pode remover a pasta sem
nenhum outro ajuste (nada em `project.godot` referencia ela).

**Integrado, IA rival melhorada** (`RivalAI.gd`, `CombatResolver.gd`,
`GameManager.gd`): a IA agora usa `CombatResolver.predict()`, a mesma
formula que o combate de verdade usa, pra decidir SE vale a pena atacar
antes de se comprometer, em vez de brigar as cegas. So ataca se nao for
morrer no proprio golpe, e (quando o defensor sobrevive) se causar
proporcionalmente mais dano do que leva. Unidades fracas (abaixo de 35%
do HP maximo) recuam pra cidade mais proxima em vez de continuar
lutando, onde se beneficiam de uma mecanica nova, **cura por guarnicao**
(qualquer unidade parada dentro da propria cidade recupera 25% do HP
maximo por turno, vale pros dois lados). Cidade inimiga indefesa dentro
do raio de percepcao vira prioridade de alvo sobre uma escaramuca
qualquer. Testes em `test/unit/test_rival_ai.gd`.

**Revertido**: cidades (`City.gd`) chegaram a usar a torre hexagonal real
do Kenney Castle Kit (`assets/models/castle/tower-hexagon-base.glb`) com
uma bandeira (`flag.glb`) tingida na cor da civilizacao no topo, mas
voltaram pra forma procedural (box+prisma) a pedido do usuario, os modelos
importados destoavam do resto do visual do jogo (ver roadmap item 19). Os
arquivos do modelo continuam em `assets/models/castle/` (nao apagados),
so nao sao mais carregados por `City.gd`.

**Integrado**: o terreno (`shaders/terrain.gdshader`) agora projeta a
textura `Ground037` (ambientCG, CC0) em **triplanar** sobre os tiles que
nao sao agua, sample da textura nos 3 eixos (XY/XZ/YZ) misturado pelo
peso da normal em espaco mundo, pra nao esticar/distorcer nas laterais do
prisma hexagonal como um UV planar simples faria. A textura multiplica a
cor por tipo de terreno que ja existia (`uniform texture_strength`
controla o quanto, ajustavel no Inspector do material sem editar
shader), entao a legibilidade dos biomas e a neblina de guerra continuam
funcionando do mesmo jeito. Baixei tambem os mapas de normal e roughness
(`assets/textures/terrain/ground_normal.jpg` e `ground_roughness.jpg`)
mas ainda nao usei no shader, normal map triplanar exige reconstruir o
espaco tangente por eixo, mais arriscado de acertar sem poder testar no
editor; fica como proximo passo.

**Integrado**: os 4 biomas especiais (roadmap item 27, resposta direta a
"todos os biomas tem a textura correta?") ganharam textura real CC0
propria (mesma tecnica triplanar acima, so um sampler diferente por
`mat_kind`): `snow_albedo.jpg` ([Snow006](https://ambientcg.com/view?id=Snow006),
neve real fotografada), `desert_albedo.jpg` ([Ground033](https://ambientcg.com/view?id=Ground033),
areia clara), `lava_albedo.jpg` ([Rock035](https://ambientcg.com/view?id=Rock035),
pedra vulcanica escura rachada) e `crystal_albedo.jpg`
([Ice003](https://ambientcg.com/view?id=Ice003), gelo rachado/facetado —
sem textura CC0 de "cristal magico" de verdade disponivel, essa serviu
melhor como base facetada tingida na cor arcana do bioma do que qualquer
rocha lisa serviria). Verifiquei cada uma visualmente antes de integrar
(o agente consegue ver imagem, so nao consegue ver o jogo renderizado de
verdade). `HexGrid._set_optional_texture()` so seta o uniform se o
arquivo existir; os 4 uniforms novos no shader usam `hint_default_white`
como fallback (branco, nao preto) caso algum arquivo falte. **Lava
redesenhada depois** (roadmap item 29): o tile de Lava perdeu os veios
brilhando procedurais que tinha aqui originalmente, agora e so a textura
de pedra tingida, sem `EMISSION` nenhuma — o brilho de lava de verdade
virou uma malha separada de RIOS de lava que escorrem pela regiao
vulcanica, mesma tecnica dos rios de agua.

**Revertido, personagens**: Colonizador, Guerreiro e Arqueiro chegaram a
usar modelos reais riggeds e animados do
[Quaternius "RPG Character Pack"](https://quaternius.com/packs/rpgcharacters.html)
(CC0), `Monk.gltf`, `Warrior.gltf` e `Ranger.gltf` em
`assets/models/characters/`, mas voltaram pra forma procedural (a mesma
usada por todo o resto do elenco, cavalaria/catapulta/mago/monstros/
unidades fantasticas) a pedido do usuario: "volte as pecas pra os modelos
default, sem ser esses 3d, eles nao fazem sentido" (ver roadmap item 19).
Cavaleiro sempre ficou procedural (cavalo+cavaleiro de caixa+capsula, ja
que nenhum dos 6 personagens do pacote e montado); agora todo o elenco de
unidades usa o mesmo estilo visual consistente, sem misturar humanoides
importados com formas geometricas. Os arquivos do modelo continuam em
`assets/models/characters/` (nao apagados), so nao sao mais carregados
por `Unit.gd`.

**Integrado**: audio completo via o novo autoload `AudioManager`
(`scripts/autoload/AudioManager.gd`), musica de fundo em loop, e efeitos
de clique (selecionar unidade), confirmacao (finalizar turno), combate,
fundacao/captura de cidade, e fanfarra de vitoria/derrota. Nao acoplado a
mais nada: so escuta os sinais que ja existiam (`EventBus`, `TurnManager`)
e toca o som correspondente, nenhum outro script precisa saber que audio
existe. O sinal `EventBus.notify` ganhou um segundo parametro
(`sfx_kind`) pra dizer qual som tocar em vez do AudioManager tentar
adivinhar pelo texto da notificacao, que quebraria se a redacao mudasse.
Se um arquivo de audio nao existir, o som correspondente e so ignorado
(jogo nao trava). Os sons de vitoria/derrota foram escolhidos pelo nome
do arquivo (nao consigo ouvir audio neste ambiente), ver nota em
`assets/audio/LICENSE.txt` se algum deles soar errado.

## Creditos de assets externos

- **Castle Kit** por [Kenney](https://kenney.nl), licenca CC0
  (`assets/models/castle/LICENSE.txt`). Nao e obrigatorio credito, mas
  Kenney pede apoio via [kenney.nl/donate](https://kenney.nl/donate) ou
  [Patreon](https://patreon.com/kenney) se o projeto usar bastante do
  trabalho dele.
- **Ground037**, **Snow006**, **Ground033**, **Rock035** e **Ice003** por
  [ambientCG](https://ambientcg.com/), licenca CC0
  (`assets/textures/terrain/LICENSE.txt`).
- **"Town Theme RPG"** por cynicmusic.com / pixelsphere.org, via
  [OpenGameArt](https://opengameart.org/content/town-theme-rpg), CC0.
- **RPG Audio**, **UI Audio** e **Music Jingles** por
  [Kenney](https://kenney.nl), licenca CC0
  (`assets/audio/LICENSE.txt`).
- **RPG Character Pack** (Warrior, Ranger, Monk) por
  [Quaternius](https://quaternius.com), licenca CC0
  (`assets/models/characters/LICENSE.txt`). Quaternius pede apoio via
  [patreon.com/quaternius](https://www.patreon.com/quaternius) se o
  projeto usar bastante do trabalho dele.
- **GUT** (Godot Unit Testing) por Butch Wesley,
  `addons/gut/LICENSE.md`.
- **LimboAI** por Serhii Snitsaruk (limbonaut),
  `addons/limboai/LICENSE.md`.

## Nota tecnica

O shader de terreno (e o material das arvores/pedras) esta com
`cull_disabled`/`CULL_DISABLED` de proposito: a geometria e toda gerada por
codigo e a orientacao das faces nunca foi conferida visualmente no editor.
O shader ja corrige a normal por face (`FRONT_FACING`) entao a iluminacao
fica certa dos dois lados de qualquer forma, trocar para `cull_back` mais
tarde e so uma questao de performance, nao de correcao visual.

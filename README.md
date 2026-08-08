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
- Shader proprio (`shaders/terrain.gdshader`) rodando no pipeline Forward+:
  terreno solido usa uma textura real (CC0, ambientCG) projetada em
  triplanar sobre a cor por tipo de tile; tiles de oceano ondulam e
  brilham (deslocamento de vertice + glint animado, via um canal de
  "custom data" por instancia do MultiMesh); a normal e corrigida por
  face (`FRONT_FACING`) pra iluminacao ficar certa mesmo com culling
  desligado.
- 12 biomas (antes eram 6) gerados por dois eixos independentes, tipo
  diagrama de Whittaker simplificado, nao e mais so uma progressao unica
  de elevacao: **elevacao** (`FastNoiseLite`) ainda decide oceano/colina/
  montanha, mas a faixa "plana" do meio agora cruza **umidade** (segundo
  ruido) com **temperatura por latitude** (gradiente pela distancia ao
  "equador" do mapa, com uma pitada de ruido nas bordas das faixas),
  Neve/Tundra/Taiga nos "polos", Planicie/Estepe/Floresta na faixa
  temperada, Deserto/Savana/Selva no "equador". Tudo 100% deterministico
  pela `map_seed` (ver `HexGrid._pick_biome`/`_temperature_for`), condicao
  que Salvar/Carregar depende pra recriar o terreno so com a semente.
  Arvores proceduralmente espalhadas em Floresta/Taiga/Selva e pedras em
  Colinas/Montanhas, tambem via `MultiMesh`, tambem respeitando a
  neblina de guerra.
- Ambiente com glow, fog de distancia sutil e SSAO ativados (Forward+),
  alem do ceu e luz direcional com sombra.
- O jogador (nome do reino escolhido na tela de titulo) contra 1 a 3
  civilizacoes rivais (escolhido tambem na tela de titulo, cada uma com
  nome/lider/cor proprios, ver `GameManager.RIVAL_CIVS`), todas com IA
  propria em 100% GDScript sem depender de nenhum plugin externo
  (`RivalAI.gd`), capital, guarda e colonizadores que agem sozinhos. A IA
  avalia o resultado PROVAVEL de um combate antes de atacar (mesma
  formula do combate de verdade, via `CombatResolver.predict()`) em vez
  de brigar as cegas, recua pra perto da propria cidade quando esta
  fraca, e prioriza capturar cidade indefesa sobre uma escaramuca.
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
  (e respeita o mesmo bloqueio por tecnologia). Cidades
  usam um modelo 3D real (torre hexagonal + bandeira do dono, Kenney
  Castle Kit CC0) em vez de formas procedurais, com fallback automatico
  caso os arquivos do modelo nao estejam presentes.
- Predios de cidade posicionaveis (`BuildingData.gd`/`BuildingDatabase.gd`/
  `Building.gd`): entram na MESMA fila de producao das unidades
  (`City.production_item` aceita um kind de unidade ou um id de predio),
  Celeiro (+2 comida), Oficina (+2 producao), Mercado (+2 ouro) e Muralhas
  (+50% de defesa pra unidade guarnicionada na cidade, ignorado pelo Mago
  igual bonus de terreno). Diferente de unidade, completar um predio nao
  "gasta" nada: fica valendo pra sempre e cada cidade so constroi cada um
  UMA vez. Ao escolher um predio, o jogador ESCOLHE O TILE onde ele vai
  ficar (um vizinho livre da cidade), do mesmo jeito que escolhe onde
  fundar uma cidade, e o modelo 3D aparece de verdade no mapa quando a
  producao completa (`HexGrid.place_building`), com uma forma procedural
  distinta por tipo (silo pro Celeiro, galpao+chamine pra Oficina, banca
  com toldo pro Mercado, segmentos de parede pras Muralhas). Numero total
  de predios e limitado pela populacao da cidade, 1 predio por ponto de
  populacao (`City.max_building_slots()`), entao uma vila que nunca
  cresceu nao acumula os 4 predios de uma vez; o painel da cidade mostra
  o limite atual ("Predios: 1/2") mesmo antes de esbarrar nele. O
  "territorio" da cidade (ela mesma + vizinhos, o mesmo raio de
  worked_tiles e de onde um predio pode ir) fica destacado em dourado no
  mapa enquanto a cidade esta selecionada (`HexGrid.show_city_territory`),
  o limite da cidade fica visivel, nao so um numero no painel. Escopo
  desta rodada: so a cidade do jogador constroi predios, a IA rival
  continua so produzindo unidades.
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
   `scenes/main/Main.tscn`.

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
  (trocar zera o progresso acumulado do item anterior); territorio da
  cidade fica destacado em dourado no mapa. Ao escolher um predio, clique
  num tile azul destacado pra posiciona-lo (como fundar uma cidade), o
  modelo so aparece de verdade no mapa quando a producao terminar
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
   Guerreiro/Arqueiro (Quaternius, ver secao de assets externos acima).
   Cavaleiro continua procedural de proposito. Falta achar acessorios/
   armas condizentes se quiser mais tipos de unidade no futuro.
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
    (destaque dourado, `HexGrid.show_city_territory`), nao so como texto
    no painel. `SaveManager` persiste onde cada predio foi posicionado e
    recria o modelo 3D certo ao carregar.

## Assets e plugins de terceiros avaliados

Pesquisa feita em 2026-08 pra achar recursos gratuitos/licenca permissiva
(CC0 na maioria, uso livre, comercial incluido, sem exigir atribuicao)
que poderiam acelerar o jogo sem comprometer o licenciamento. Guardado
aqui pra nao perder o levantamento entre sessoes.

**Modelos 3D** (substituiriam ou complementariam as formas procedurais
atuais de `Unit.gd`/`City.gd`):
- [Kenney Castle Kit](https://kenney.nl/assets/castle-kit), 75 pecas
  (torres, muralhas, portoes), CC0.
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
  **usado**. 6 personagens fantasia riggeds/animados (Warrior, Ranger,
  Rogue, Cleric, Wizard, Monk), CC0, glTF/FBX/OBJ/Blend. So disponivel via
  pasta do Google Drive (nao da pra baixar com curl simples); usei
  Warrior, Ranger e Monk pra Guerreiro/Arqueiro/Colonizador. Ver
  integracao completa mais abaixo.
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
  [Ground037](https://ambientcg.com/view?id=Ground037) (ver integracao
  abaixo).

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
  `buildings[id]=true` e troca a producao de volta pra Guerreiro em vez de
  tentar reconstruir o mesmo predio, `collect_yields()` soma o bonus
  permanente dos predios construidos, `max_building_slots()` bate com a
  populacao da cidade e `can_build()` respeita esse limite mesmo pra um
  predio novo (nao so pro ja construido); `is_valid_building_tile()`
  aceita um vizinho livre de terra firme e rejeita tile longe demais da
  cidade, oceano, ocupado por unidade/cidade, ou ja usado por outro
  predio; `process_turn()` grava `building_coords[id]` e devolve
  `built_coord` SO quando o jogador escolheu um tile
  (`pending_building_coord`), com **graceful degrade** pra quando
  `set_production()` foi chamado direto sem passar pelo posicionamento
  (o predio ainda conta pro bonus/limite, so fica sem coordenada); e
  **teste de regressao** pro auto-assign preferir um tile com bonus de
  recurso a uma planicie comum
  de rendimento cru maior.
- `test_hex_grid_movement.gd`, **teste de regressao** pro bug que voce
  encontrou (cidade inimiga entrando em "alcancavel por movimento" e
  atrapalhando a captura), captura de cidade, bloqueio de empilhamento de
  unidades, `tiles_in_range()` (base do alcance de ataque, so tinha
  cobertura indireta antes): devolve os vizinhos certos, exclui o proprio
  centro, respeita o raio; o Grifo (`UnitData.flies`): atravessa oceano
  onde uma unidade terrestre fica presa, e ignora custo de terreno
  (2 pontos de movimento alcancam 2 MONTANHAS voando, nao so 1); e
  predios posicionaveis: `place_building()` registra o modelo no coord
  certo (`get_building_at`), `is_tile_building_site()` reflete isso, e
  `show_city_territory()`/`clear_city_territory()` guardam o conjunto de
  tiles que vai ser destacado no mapa.
- `test_hexgrid_fog.gd`, fog of war nunca tinha teste proprio apesar de
  ser a base do fog do jogador E do "fog of war propria" da IA
  (`RivalAI.take_turn`): uniao de visao de unidade+cidade,
  `recompute_fog()` so escurece pra EXPLORADO (nunca volta a NAO VISTO)
  quando um tile ja visto sai de alcance, e unidade/cidade/**predio**
  inimigo so aparece (`.visible`) em tile ATUALMENTE visivel, nao so por
  ja ter sido explorado antes.
- `test_rival_ai.gd`, `CombatResolver.predict()` bate com o dano real de
  `resolve()`, IA nao ataca se for morrer no proprio golpe, cura por
  guarnicao (so cura dentro da propria cidade, nao na do inimigo),
  regeneracao passiva do Ent (`GameManager._apply_regen`: cura em
  QUALQUER lugar, nao so guarnicionado; nunca passa do HP maximo; unidade
  sem `regen_fraction` nao cura sozinha fora de cidade), fog of war da IA
  (ignora unidade inimiga fora de visao, lembra de cidade ja escoutada
  mesmo fora de visao depois), coordenacao tatica (arqueiro sozinho nao
  avanca sem escolta corpo-a-corpo por perto, avanca normal com escolta)
  e diplomacia: em paz, a IA nunca mira no jogador humano mesmo com alvo
  visivel no alcance.
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
  (`DIFFICULTY_MULTIPLIERS`) so aos rivais, humano sempre fica em 1.0; e
  **teste de regressao** garantindo que humano e rivais nunca comecam na
  mesma coordenada num mapa pequeno.
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
  tile (`HexGrid.get_building_at`); um Covil de Monstro ja limpo ANTES de
  salvar nao "ressuscita" ao carregar (generate_map() recriaria o
  guardiao original, ver `_serialize_cleared_lairs`); e **teste de
  regressao** garantindo que `GameManager.map_radius` (usado pelo limite
  de pan da camera) e atualizado pro raio de verdade do mapa carregado,
  nao fica "preso" no raio da partida anterior.
- `test_monsters.gd`, `MonsterDatabase.gd`: todo monstro tem recompensa
  de ouro positiva e nunca se move, `random_kind()` sempre devolve um
  kind valido e e deterministico pra mesma semente; e geracao de mapa:
  `_spawn_monster_lairs()` cria guardioes neutros (owner_player nulo)
  nos coords certos, nunca em oceano, nunca perto demais do centro do
  mapa (onde o humano comeca), e a colocacao dos covis e 100%
  deterministica pela `map_seed` (mesma garantia que terreno/recursos).
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
  de Muralhas (ignora predios de yield), e cada predio tem um id unico.
- `test_terrain_generation.gd`, a matriz temperatura x umidade escolhe o
  bioma certo em cada combinacao (frio/temperado/quente cruzado com seco/
  moderado/umido), e **teste de regressao** pra geracao continuar 100%
  deterministica pela `map_seed` (mesma semente = mesmo terreno; sementes
  diferentes podem divergir), a base que Salvar/Carregar depende pra
  nunca precisar guardar os tiles em si.
- `test_tech.gd`, disponibilidade de tecnologia por pre-requisito,
  desbloqueio de Arqueiro/Cavaleiro/Catapulta/Mago/Grifo (este ultimo
  exige Equitacao pesquisada antes) / Ent (Druidismo, sem pre-requisito),
  bonus de rendimento por bioma aplicado em `City.collect_yields()`,
  processamento de pesquisa por turno (ciencia acumula so com uma
  pesquisa escolhida, completa ao bater o custo), e **teste de
  regressao** garantindo que a IA nunca produz uma unidade que ainda
  nao desbloqueou.
- `test_resources.gd`, elegibilidade de recurso por bioma, bonus de
  yield aplicado em `City.collect_yields()`, oceano nunca tem recurso, e
  **teste de regressao** pra colocacao de recurso continuar
  deterministica pela `map_seed` (mesma logica exigida da geracao de
  bioma, ver `test_terrain_generation.gd`).

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

**Integrado**: cidades (`City.gd`) agora usam a torre hexagonal real do
Kenney Castle Kit (`assets/models/castle/tower-hexagon-base.glb`) com uma
bandeira (`flag.glb`) tingida na cor da civilizacao no topo, a pedra fica
com a textura original, so a bandeira muda de dono. Isso muda o projeto de
"100% procedural" pra usar assets importados em pelo menos uma parte da
cena; ha um fallback procedural automatico (o box+prisma antigo) caso os
arquivos do modelo nao existam, entao o jogo nao quebra se alguem clonar
o repo sem os assets.

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

**Integrado, personagens**: Colonizador, Guerreiro e Arqueiro agora usam
modelos reais riggeds e animados do
[Quaternius "RPG Character Pack"](https://quaternius.com/packs/rpgcharacters.html)
(CC0), `Monk.gltf`, `Warrior.gltf` e `Ranger.gltf` em
`assets/models/characters/`, cada um com 13 animacoes (Idle, Walk, Run,
Death, ataques...) das quais tocamos "Idle" em loop. Pesquisei bastante
antes de achar esse: Kenney nao tem personagem 3D medieval de verdade
(so gente moderna/generica ou sprites 2D), e o pacote de personagens do
Kay Lousberg que eu tinha listado antes acabou sendo **pago** (corrigido
aqui). O Quaternius so fica atras de um link do Google Drive em vez de um
zip direto, nao doleu por curl simples, entao o usuario baixou manual e
eu copiei os 3 arquivos certos pra dentro do projeto.

Cavaleiro continua procedural (cavalo+cavaleiro de caixa+capsula): nenhum
dos 6 personagens do pacote e montado, e trocar por um humanoide a pe
seria uma piora, perderia a leitura visual de "isso e cavalaria" que a
forma procedural ja da.

Escala/posicao dos modelos reais nao foi chutada dessa vez: `Unit.gd`
mede o bounding box de verdade em tempo de execucao (`_combined_aabb()`,
percorre a hierarquia de meshes e transforma cada uma pro espaco local
da unidade) e so entao calcula escala/altura, depois de ter errado a
conta "no papel" duas vezes com a torre e a bandeira do castelo, preferi
deixar o proprio Godot medir. Se os arquivos do modelo nao existirem, cai
automaticamente nas formas procedurais antigas (mesmo padrao de
fallback usado em todo canto que usa asset externo neste projeto).

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
- **Ground037** por [ambientCG](https://ambientcg.com/view?id=Ground037),
  licenca CC0 (`assets/textures/terrain/LICENSE.txt`).
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

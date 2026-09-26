# Aetherlands — Auditoria Integral de UI/UX

**Fase 28A · auditoria e proposta, sem implementação do redesign**
**Data da auditoria:** 26/09/2026
**Escopo observado:** menu, setup, loading, gameplay, seleção, cidade, produção,
pesquisa, diplomacia, vitória, eventos, pausa, configurações, save/load e fim de
jogo.

Este documento descreve o produto que existe, os problemas observados e uma
arquitetura futura. Não altera regras, balanceamento, save, assets ou gameplay.
Referências externas não foram usadas: as conclusões vêm do repositório, da
execução real e das mecânicas já implementadas em Aetherlands.

## Método e evidência

- Auditoria estática das 7 cenas em `scenes/ui`, de `Main.tscn`, dos 12 scripts
  de apresentação em `scripts/ui` e dos produtores de eventos relevantes.
- Execução única, não-headless, de `Main.tscn`, com mapa real 61 × 61, três
  rivais e os fluxos reais de menu → setup → loading → gameplay.
- Capturas novas em 1920 × 1080, 1600 × 900 e 1280 × 720. Foram criadas 16
  imagens `audit28a_*` em `user://`; nenhuma foi adicionada ao repositório.
- Releitura das capturas reais já produzidas nas Fases 18, 22, 23, 25, 26 e
  27 para estados complexos: mira, quatro feitiços, manifestação, ambiente,
  ritual, cidade, unidade, árvore e tela final.
- Medições simples no mesmo smoke, para detectar ordem de grandeza, não para
  servir de benchmark de release: barra superior 64 µs por refresh; seleção e
  painel de unidade 2,47 ms; inspeção de cidade 9,07 ms; refresh cacheado da
  árvore 7 µs; diplomacia 1,83 ms; vitória 4,24 ms; criação de toast 0,69 ms.
- Validação explícita das hipóteses de guerra, pesquisa ociosa, cidade ociosa,
  fim de turno e perda de mensagens importantes.

### Resultado objetivo do teste de resolução

| Superfície | 1920 × 1080 | 1600 × 900 | 1280 × 720 | Diagnóstico |
|---|---|---|---|---|
| Menu principal | Cabe, mas usa pouco do espaço | Cabe | Cabe | Robusto, visualmente genérico |
| Nova partida | Muito espaço vazio | Boa leitura | Cabe sem corte | Lore domina a decisão e falta comparação rápida |
| Loading | Central | Central | Cabe | O layout muda com o texto da fase |
| Barra superior | Confortável | Densa | Quase ocupa toda a largura | Não escala para novos indicadores |
| Unidade | ~35% da largura nas capturas históricas | Legível | ~54% da largura | Mapa perde área; texto e ações não têm hierarquia |
| Cidade | ~35% da largura nas capturas históricas | Legível | ~54% da largura e quase toda a altura | Painel monolítico; mapa e contexto ficam comprimidos |
| Pesquisa | Excelente visão global | Boa | Só N1–N6 e ~4,5 linhas simultâneas | Scroll funciona, mas esconde progressão e rótulos |
| Diplomacia/Vitória | Cabe | Cabe | Cabe | Conteúdo é raso/denso, não um problema de encaixe |
| Pausa/Settings/Load | Cabe | Cabe | Cabe | Estrutura simples e responsiva |

Na Loading Screen, trocar `Gerando o Mapa...` pelo texto real longo de uma fase
moveu a barra de `(460, 441)` para `(150, 454)`: **−310 px em X e +13 px em Y**.
A largura da barra mudou de 312 para 931 px porque o título define a largura do
`VBoxContainer`. O progresso, que deveria ser uma âncora estável, salta durante
o carregamento.

---

# 1. Executive Summary

## Veredito

Aetherlands não sofre de falta de informação. Sofre de falta de **arquitetura
de atenção**. Os dados existem e, em geral, estão corretos; porém estado,
decisão, histórico e ação aparecem misturados em texto corrido, botões e toasts
de 3,1 segundos. O jogador consegue consultar quase tudo se souber onde olhar,
mas o jogo não organiza com segurança o que exige atenção agora.

Foram identificadas **20 interfaces únicas** e **25 superfícies/componentes
auxiliares**. O registro tem **35 achados priorizados**: 5 P0, 11 P1, 12 P2 e
7 P3. P0 aqui significa risco direto de perder uma decisão ou uma mudança
estratégica, não crash.

## O que está forte

- A árvore V2 é a melhor interface existente: boa identidade visual, estados
  coerentes, progressão espacial e atualização orientada a sinais. Deve ser
  preservada como referência interna, com adaptação responsiva.
- O mapa comunica terreno, neblina, alcance, movimento e alvos sem abrir outra
  tela. Mira e cancelamento por ESC são consistentes.
- `TileInspector` já centraliza boa parte da apresentação de entidades e pode
  virar um presenter real sem reescrever regras.
- Painéis principais não fazem rebuild por frame. O custo medido de refresh é
  aceitável; o problema é composição e acoplamento, não throughput bruto.
- Loading, fim de jogo, eventos mundiais e ritual já têm estados especializados;
  não é necessário inventar sistemas de gameplay para melhorar a comunicação.

## Hipóteses críticas — resultado

| Hipótese | Resultado | Evidência |
|---|---|---|
| Guerra pode começar sem feedback adequado | **Confirmada** | Rival emite apenas `notify(text, "")`: toast transitório, sem som dedicado, histórico, banner, foco ou estado persistente no HUD |
| Pesquisa ausente fica invisível | **Confirmada** | Sem projeto, o botão volta a ser apenas `Pesquisa`; não há badge, pendência nem bloqueio contextual |
| Cidade sem produção fica invisível | **Confirmada** | A ociosidade só é descoberta abrindo cada cidade; não há resumo global nem lista |
| Finalizar turno ignora decisões pendentes | **Confirmada** | Espaço/Enter chama fim do turno diretamente quando não há overlay; não consulta pesquisa, cidades ou decisões |
| Informação crítica se perde em toast | **Confirmada** | 56 call sites em 16 arquivos convergem para o mesmo label de 2,5 s + fade de 0,6 s; não existe histórico |

## P0

1. Não existe Attention System nem resumo de pendências antes de finalizar o
   turno.
2. Declaração de guerra da IA usa o mesmo toast descartável de mensagens
   comuns.
3. Ausência de pesquisa ativa não é tratada como decisão pendente.
4. Cidade sem produção não é visível fora do painel da própria cidade.
5. Não existe Event Center/log persistente; fatos críticos podem desaparecer.

## P1

1. Unit Panel é texto corrido + ações empilhadas e não escala com conjuradores,
   Lendárias, Manifestações, passivas, recargas e status.
2. City Panel mistura inspeção, economia, produção, território, defesa e ritual.
3. A árvore perde visão global em 1280 × 720.
4. Victory Progress mistura resumo, explicação e detalhe de rival numa única
   camada.
5. Diplomacia só expõe status textual e guerra/paz, apesar de haver motivos,
   trégua, desgaste e campanha.
6. Loading reflow desloca a barra durante a mudança de fase.
7. Settings não cobre vídeo, janela, escala, controles ou acessibilidade.
8. Debug aparece dentro de Configurações e muda de contexto para um overlay do
   mapa.
9. Não há Empire Overview, City List nem Unit List.
10. Notificações não têm modelo estruturado, severidade, origem ou ação.
11. Voltar ao menu principal não pede confirmação da possível perda desde o
    último save.

## Registro resumido P2/P3

| ID | Pri. | Achado |
|---|---|---|
| U17 | P2 | Setup privilegia lore longa em vez de comparação reconhecível |
| U18 | P2 | Save/Load mostra poucos metadados e nenhum estado de incompatibilidade legível |
| U19 | P2 | Tela final oferece só “Jogar Novamente” e pouca navegação pós-partida |
| U20 | P2 | Top bar é textual, rígida e usa `DIP`/`VIT` |
| U21 | P2 | Não há glossário/codex nem ajuda contextual consistente |
| U22 | P2 | Targeting e relações dependem demais de cor e texto |
| U23 | P2 | Dano, morte, ameaça e log de combate não formam uma narrativa consultável |
| U24 | P2 | Minimap não tem legenda, filtros nem affordance de navegação |
| U25 | P2 | Passivas, recargas e status não têm hierarquia visual comum |
| U26 | P2 | Tooltips têm estrutura e densidade variáveis |
| U27 | P2 | Empty/error states são funcionais, porém pouco acionáveis |
| U28 | P2 | Não há reduced motion nem política de animação |
| U29 | P3 | Menu principal é correto, mas visualmente indiferenciado |
| U30 | P3 | Cursor não comunica modos de mover, atacar, construir ou mirar |
| U31 | P3 | Cor/identidade racial quase não participa da UI |
| U32 | P3 | Hotkeys não aparecem nos controles, exceto Espaço/ESC em poucos textos |
| U33 | P3 | Não há política explícita de largura máxima para ultrawide |
| U34 | P3 | FPS aparece sempre em builds de jogo |
| U35 | P3 | Áudio de UI tem seis categorias e nenhum sinal específico de atenção/diplomacia |

---

# 2. Inventory of Existing UI

## Contagem e critério

“Interface” é uma superfície com objetivo, entrada e ciclo de abertura próprios.
Reuso do mesmo `LoadGameScreen.tscn` no título e na pausa conta uma vez. Variações
de estado do mesmo Game Over também contam uma vez. Com esse critério existem
**20 interfaces únicas**.

## Inventário — existência e contexto

| # | Interface | Cena/script | Abertura | Usuário e frequência | Modal? | Bloqueia mapa? | Categoria |
|---:|---|---|---|---|---|---|---|
| 1 | Menu principal | `TitleScreen.tscn/.gd` | Boot ou retorno da pausa | Todos; por sessão | Sim | Jogo não iniciado | Navegação |
| 2 | Nova partida | `GameSetupScreen.tscn/.gd` | Novo Jogo | Todos; início | Sim | Jogo não iniciado | Configuração |
| 3 | Carregar jogo | `LoadGameScreen.tscn/.gd` | Título ou pausa | Jogador; ocasional | Sim | Sim | Persistência |
| 4 | Configurações | `SettingsScreen.tscn/.gd` | Título ou pausa | Jogador; ocasional | Sim | Sim na pausa | Sistema |
| 5 | Loading | `LoadingScreen.tscn/.gd` | Novo jogo, load, restart | Todos; transição | Sim | Sim | Transição |
| 6 | Gameplay HUD shell | `HUD.tscn/.gd` | Entrada no jogo | Jogador; contínua | Não | Não | HUD |
| 7 | Tile Inspector | HUD + `TileInspector.gd` | Clique no mapa | Jogador; muito alta | Não | Parcial | Inspeção |
| 8 | Cidade e produção | HUD/`TileInfoPanel` | Selecionar cidade | Jogador/dono; alta | Não | Parcial | Gestão |
| 9 | Unidade e ações | HUD/`UnitPanel` | Selecionar unidade | Jogador; muito alta | Não | Parcial | Comando |
| 10 | Pesquisa V2 | `V2ResearchBoard.gd`, criado pelo HUD | Botão Pesquisa | Jogador; recorrente | Sim | Sim | Progressão |
| 11 | Diplomacia | HUD/`DiplomacyPanel` | `DIP` | Jogador; baixa/média | Sim | Sim | Estratégia |
| 12 | Progresso de vitória | HUD/`VictoryPanel` | `VIT` | Jogador; baixa | Sim | Sim | Estratégia |
| 13 | Pausa | `PauseMenu.tscn/.gd` | ESC | Jogador; recorrente | Sim | Sim e pausa árvore | Sistema |
| 14 | Debug | HUD/`DebugPanel` | Settings → Debug | Desenvolvedor | Sim | Sim | Ferramenta |
| 15 | Escolha de evento mundial | HUD/`WorldEventPanel` | Evento anunciado | Jogador; rara | Não estrito | Ocupa mapa | Evento |
| 16 | Anúncio do Dragão | HUD/`DragonAnnouncementPanel` | Fase do evento | Jogador; rara | Sim | Sim | Evento crítico |
| 17 | Resolução do Dragão | HUD/`DragonResolutionPanel` | Evento concluído | Jogador; rara | Sim | Sim | Resultado |
| 18 | Tracker/Boss do evento | HUD/`WorldEventTracker`, `DragonBossBar` | Evento ativo | Jogador; temporária | Não | Não | HUD de evento |
| 19 | Fim de jogo | HUD/`GameOverPanel` | `game_over`/`victory_achieved` | Jogador; uma vez | Sim | Sim | Resultado |
| 20 | Confirmações destrutivas | `ConfirmationDialog` em load/pausa | Load/delete | Jogador; ocasional | Sim | Sim | Prevenção de erro |

## Inventário — dados, ações, dependências e avaliação

| # | Dados e ações | Dependências principais | Visual atual | Problemas | Recomendação preliminar |
|---:|---|---|---|---|---|
| 1 | Novo, carregar, settings, sair | `MenuPager`, `SaveManager`, `AudioManager` | Coluna central em fundo azul-escuro | Genérico, sem identidade/lore contextual | **Reformular**, preservar fluxo |
| 2 | Nome, raça, lore, bônus, rivais, iniciar | `RACE_INFO`, mapa fixo, `GameManager` | Formulário central + painel de lore | Comparação lenta; dificuldade oculta/fixa | **Reformular** com comparação por atributos |
| 3 | Slot, reino/raça, turno/data, load/delete | `SaveManager` | Lista de linhas largas | Pouco contexto e estados de erro pobres | **Reformular** |
| 4 | Música, SFX, VSync, Debug | `Settings`, `AudioManager` | Formulário mínimo | Cobertura incompleta; devtools misturado | **Substituir conteúdo**, manter rota |
| 5 | Fase, percentual, spinner | `HexGrid.generate_map`, Main | Emblema, partículas, barra | Reflow; load ainda síncrono congela | **Reformular layout** |
| 6 | Recursos, mapa, contexto, navegação e turnos | Quase todo runtime | Moldura marrom/dourada, painéis direitos | Não há shell de atenção; `HUD.gd` concentra 126 bindings/conexões | **Substituir arquitetura**, migrar gradualmente |
| 7 | Terreno, entidades, fog, recursos, status | `TileInspector`, `HexGrid` | Texto + abas contextuais | Informação correta, pouco escaneável | **Preservar lógica; reformular componente** |
| 8 | Cidade, outputs, produção, prédios, território, defesa, ritual | `City`, bancos V2, `SelectionManager` | Um painel alto, texto + tabs + botões | Mistura consulta, ação e estado | **Substituir composição** |
| 9 | Stats, classe, ordens, feitiços, técnicas, status | `Unit`, runtimes V2, `SelectionManager` | Um label e HFlow de botões | Escala mal e força leitura textual | **Substituição completa** |
| 10 | 128 nós, estados, custo, progresso, unlocks | `V2ResearchState/Database` | Grade escura, linhas/tiers, footer | Responsividade em 1280 e debug no topo | **Preservar e adaptar** |
| 11 | Relação, guerra/paz, trégua | `Diplomacy`, `PlayerData` | Modal pequeno com linhas | Não mostra motivo, desgaste, objetivo, consequências | **Substituição completa** |
| 12 | 3 vitórias e progresso rival | `VictoryConditions`, V2 victory/ritual | Modal textual com barras | Resumo e detalhe simultâneos | **Substituir por duas camadas** |
| 13 | Continuar, save/load, settings, menu, sair | `MenuPager`, `SaveManager` | Coluna central | Sem confirmação de menu/sair; pouca informação da sessão | **Reformular** |
| 14 | Cheats e painéis internos | `GameManager`, HUD | Overlay de botões | Descoberta dentro de Settings e retorno de contexto abrupto | **Mover para DevTools separado** |
| 15 | Convite, descrição, participar/recusar | `WorldEventManager` | Painel textual | Compete com mapa e não integra histórico | **Mesclar em chrome de eventos** |
| 16 | Entrada dramática e continuar | `DragonEvent` | Modal especializado | Bom uso de modal, mas sistema único | **Preservar; virar variante CriticalEvent** |
| 17 | Ranking, resultado, continuar | `DragonEvent` | Modal especializado | Isolado do futuro Event Center | **Preservar; integrar histórico** |
| 18 | Objetivo e HP | Evento atual | Cards persistentes | Boa persistência; posição compete com contexto | **Preservar; encaixar no shell** |
| 19 | Resultado, motivo, snapshot de vitórias, restart | `GameManager`, condições de vitória | Modal central rolável | Só restart; motivo técnico nem sempre explicativo | **Reformular** |
| 20 | Texto e confirmar/cancelar | Godot dialogs | Janela nativa temática parcial | Aplicação inconsistente; falta no retorno ao menu | **Unificar componente** |

## 25 superfícies/componentes auxiliares

| # | Superfície | Papel atual | Problema-chave | Destino recomendado |
|---:|---|---|---|---|
| 1 | Top bar | Ouro, supply, mana, conhecimento, contagens | Texto rígido | Resource chip reutilizável |
| 2 | Research button | Abre árvore e mostra ativo | Ocioso sem alerta | Progress chip + attention badge |
| 3 | End Turn button | Avança turno | Não conhece pendências | Turn Controller |
| 4 | Toast stack | Mensagens gerais | Efêmero e sem estrutura | Toast presenter sobre Event Center |
| 5 | Minimap | Visão espacial/click | Sem legenda/filtros | Preservar + controles mínimos |
| 6 | Tooltip padrão | Motivos e detalhes | Estrutura variável | Tooltip schema |
| 7 | Production button | Item, custo, lock | Categorias misturadas | ProductionItem component |
| 8 | Production bar/ETA | Progresso local | Só na cidade aberta | Reusar em City Summary |
| 9 | City action row | Evolução, muro, anexação, ritual | Tudo no mesmo nível | Ações por grupo/contexto |
| 10 | Unit core actions | Mover/Fortificar/Explorar | Mesmo peso de habilidades | Command strip |
| 11 | Ability button | Magia/técnica/portal/upgrade | Texto longo e wrap | AbilityButton padrão |
| 12 | Passive lines | Efeitos derivados | Escondidos no corpo textual | PassiveTag/lista colapsável |
| 13 | Cooldown/status lines | Recarga e duração | Repetição textual | Badge/overlay padronizado |
| 14 | Targeting hint | Próximo clique/ESC | Mistura com descrição da unidade | Targeting banner fixo |
| 15 | Reach/attack highlights | Tiles válidos | Dependência de cor | Cor + forma/padrão/ícone |
| 16 | Path preview | Rota e custo | Só mouse; modo pouco explícito | Cursor/mode banner + rota |
| 17 | Hover Label3D | PM/ATACAR | Pequeno e contextual | Preservar, padronizar contraste |
| 18 | Unit selection/status rings | Seleção/técnica | Sem legenda | Vocabulário consistente |
| 19 | City/ritual markers | Estado no mapa | Significado depende de memória | Tooltip + legenda |
| 20 | City/map labels | Nome/população/owner | Legibilidade varia com fundo | Halo/LOD e prioridade |
| 21 | Damage popup | Número de dano | Sem origem/tipo/histórico | Combat feedback component |
| 22 | Research card/edge/footer | Estado e progressão | 1280 exige scroll excessivo | Layout responsivo preservando modelo |
| 23 | Inspection tabs | Entidades no mesmo tile | Labels e ordem contextuais | Tab/chip padrão |
| 24 | Empty/error/status labels | Ausência/falha/save | Pouco acionáveis | EmptyState/ErrorState padrão |
| 25 | Backdrop/close chrome | Modalidade | Gerido manualmente por painel | ModalManager + OverlayFrame |

---

# 3. Gameplay Information Inventory

| Informação | Fonte real | Onde aparece hoje | Persistência | Lacuna |
|---|---|---|---|---|
| Turno e processamento | `TurnManager`, `GameManager` | Top bar/botão | Contínua | Sem fase do turno nem fila de decisões |
| Ouro e líquido | `PlayerData`, `V2EconomyRuntime` | Top bar + tooltip | Contínua | Déficit depende de texto/tooltip |
| Suprimento/tensão | V2 economy/logistics | Top bar | Contínua | Sem severidade nem unidades afetadas |
| Mana/renda | `PlayerData`/economia | Top bar | Contínua | Sem compromissos futuros nem alertas |
| Conhecimento/renda | economia/pesquisa | Top bar | Contínua | Estoque/overflow só no board |
| Pesquisa ativa | `V2ResearchState` | Botão + board | Contínua quando ativa | Ausência não chama atenção |
| Pesquisa concluída/unlocks | estado/unlock | Toast + board | Toast efêmero | Sem histórico ou próximo passo |
| Cidades/unidades totais | `PlayerData` | Top bar | Contínua | Não são navegáveis |
| Produção por cidade | `City` | Cidade selecionada | Local | Sem resumo imperial/ociosidade |
| Espera por Mana | `City.process_turn` | Cidade aberta | Local | Pode passar despercebida |
| Nível/fortificação | runtimes V2 | Cidade/mapa/vitória | Local | Sem comparação/ETA global |
| Outputs e tiles trabalhados | cidade/economia | City Panel | Local | Texto denso |
| Anexação | cidade/selection | City Panel/map highlight | Durante ação | Falta fila de pendência |
| Unidade: HP/stats/movimento | `UnitData/Unit` | Unit Panel/inspector | Seleção | Boa precisão, baixa escaneabilidade |
| Veterania/XP/abates | `Unit` | Unit Panel | Seleção | Sem barra ou próximo marco |
| Classe/traços | databases/runtimes | Texto/inspector | Seleção | Taxonomia visual ausente |
| Feitiços/técnicas | bancos/runtime | Botões | Seleção | Quatro ou mais ações viram parede de texto |
| Recargas/status/passivas | `magic_*` e derivados | Texto/botão/anel | Seleção/mapa | Sem linguagem visual única |
| Movimento/alcance/alvos | `SelectionManager/HexGrid` | Mapa | Temporária | Modo/cursor e acessibilidade |
| Terreno/recurso/melhoria | `HexTileData`/inspector | Mapa + inspector | Seleção | Ícones e explicações inconsistentes |
| Fog/visibilidade | `HexGrid` | Mapa/minimap | Contínua | Sem legenda/explicação |
| Guerra/trégua/desgaste | `Diplomacy/PlayerData` | Diplomacia e toast | Parcial | Sem estado persistente no HUD |
| Campanha/motivo de guerra | `RivalAI`, relações | Quase invisível | Não apresentada | Informação estratégica perdida |
| Progresso de vitória | condições V1/V2 | Vitória | Sob demanda | Sem resumo no HUD |
| Ritual público | transcendência | Toast, mapa, vitória, cidade | Parcial | Falta alerta hierárquico unificado |
| World event/Dragão | manager/event | painéis/tracker/boss | Durante evento | Não vai para histórico comum |
| Combate/off-screen | resolver | Popup + toast | Efêmera | Sem log, localização ou “ir para” |
| Save/load/error | managers | status/dialog/lista | Tela | Diagnóstico limitado |

Princípio para a futura camada: **estado contínuo** fica no HUD; **decisão** vai
para Attention; **evento** entra no Event Center; **detalhe** mora no painel
contextual; **ação irreversível** exige confirmação proporcional ao risco.

---

# 4. Decision / Attention Inventory

| Decisão/pendência | Detecção existente | Comunicação atual | Risco se ignorada | Prioridade futura |
|---|---|---|---|---|
| Escolher pesquisa | `active_id == ""` | Botão neutro | Conhecimento acumula sem direção | P0 Required |
| Cidade sem produção | `production_item == ""` | Só ao abrir cidade | Perda de turnos produtivos | P0 Required |
| Produção esperando Mana | Cidade pronta, Mana insuficiente | Texto local | Bloqueio silencioso | P1 Warning |
| Selecionar nova produção após conclusão | Resultado de turno | Toast | Cidade fica ociosa | P0 Required |
| Guerra declarada contra humano | `RivalAI.decide_war` | Toast sem som | Mudança estratégica pode sumir | P0 Critical |
| Proposta/resultado de paz | Diplomacia/AI | Toast | Relação muda sem registro | P1 Important |
| Cidade ameaçada | `CityDefense.warn_player` | Toast combat | Ataque pode ocorrer fora da tela | P1 Critical |
| Cidade capturada/perdida | `HexGrid` | Toast | Mudança territorial maior | P0 Critical |
| Unidade morta/atacada off-screen | Resolver | Toast | Jogador perde contexto | P1 Important |
| Tensão logística | supply > cap | Texto top bar | Penalidade sistêmica | P1 Warning |
| Déficit de Ouro | líquido < 0 | Tooltip | Prédios a 50% | P1 Warning |
| Ritual próprio pronto/iniciado | Transcendência | Cidade/toast | Vitória depende disso | P1 Objective |
| Ritual rival a 1 rodada | sinal/runtime | Toast | Ameaça de fim de jogo | P0 Critical |
| Evento mundial: participar | WorldEvent | Painel | Decisão expira | P0 Required |
| Builder com carga/recurso melhorável | constructor runtime | Unidade selecionada | Oportunidade local | P2 Suggestion |
| Unidade sem comando necromântico | retinue runtime | Botão/tooltip | Unidade inutilizada | P1 Warning |
| Upgrade disponível | research + cidade | Botão na unidade/cidade | Oportunidade | P2 Suggestion |
| Finalizar turno | botão/Space | Sem revisão | Todas as anteriores podem passar | P0 Gate |

O futuro Attention System deve **consultar estado derivado**, não salvar uma
segunda verdade. Cada item precisa de `id`, severidade, categoria, título,
descrição curta, alvo opcional, ação primária, possibilidade de adiar e regra de
resolução. Nesta fase isso é apenas contrato proposto.

---

# 5. Missing Interfaces

| Interface faltante | Problema concreto que resolve | Por que justifica uma superfície | Prioridade |
|---|---|---|---|
| Attention Center / Turn Checklist | Pesquisa/cidades/decisões esquecidas | Reúne decisões acionáveis e permite navegar | P0 |
| Event Center / histórico | 56 produtores perdem mensagens em segundos | Eventos precisam persistência, filtro e alvo | P0 |
| War Alert | Guerra altera toda a partida | Requer banner/modal e atalho à diplomacia/mapa | P0 |
| Research Complete/Idle flow | Próximo projeto não é escolhido | Pequeno prompt + acesso à árvore | P0 |
| City Production Summary | Ociosidade só local | Lista compacta por cidade com ETA e ação | P0 |
| Empire Overview | Dados imperiais não são navegáveis | Hub de cidades, unidades, economia e objetivos | P1 |
| City List | Muitas cidades não cabem em memória | Ordenação por produção/alerta/nível | P1 |
| Unit List | Exército cresce e unidades somem no mapa | Busca por classe, estado e ação | P1 |
| Victory Summary layer | Painel atual começa no detalhe | Resumo comparável das três vias | P1 |
| Diplomacy Detail | Relação atual é insuficiente | Expõe guerra, trégua, desgaste, motivo e ações | P1 |
| Controls/Keybindings | Só ESC/Espaço são descobertos | Necessário para teclado e futura remarcação | P1 |
| Accessibility settings | Sem escala/reduced motion/contraste | Necessário para resoluções e necessidades diversas | P1 |
| Glossary/Context Help | V2 tem muitos termos e regras | Ajuda sob demanda evita tutorial modal excessivo | P2 |
| Combat Log | Popup/toast não explica sequência | Diagnóstico e confiança em combate | P2 |
| First-run onboarding | Sistemas chegam sem orientação | Sequência contextual curta, não enciclopédia | P2 |

Não se recomenda criar telas separadas para cada recurso, status ou mecânica.
Esses itens devem usar componentes no shell, detalhe contextual ou glossary.

---

# 6. Interfaces to Remove / Merge / Replace

## Remover da experiência de release

- **FPS permanente:** mover para DevTools/overlay de diagnóstico.
- **Debug dentro de Configurações:** remover da navegação de jogador; manter
  DevTools em debug build por atalho/entrada própria.
- **Abreviações `DIP` e `VIT`:** substituir por navegação reconhecível com
  rótulo/ícone e estado, não apenas siglas.
- **Toast como única evidência de evento:** remover esse papel. Toast continua
  como confirmação transitória, nunca como armazenamento.

## Mesclar

- World Event invitation, anúncio, resolução, tracker e boss bar devem usar um
  **Event Framework** comum, preservando variantes dramáticas.
- Os dois contextos de Load e Settings já reutilizam componentes; formalizar
  um `NavigationManager` em vez de pager local em cada raiz.
- Tooltip de lock, descrição e custo deve usar um único schema, inclusive em
  produção, habilidade e pesquisa.
- Unit status, passiva, trait e cooldown devem virar componentes reutilizáveis,
  não linhas especiais acrescentadas ao label.

## Substituição completa

- **Unit Panel:** conteúdo e hierarquia, mantendo dados e ações.
- **City Panel:** shell e arquitetura interna, mantendo produção real.
- **Diplomacy Panel:** precisa representar o sistema real, não só dois botões.
- **Notification Stack:** substituir infraestrutura por eventos estruturados +
  presenters; o toast visual será apenas uma saída.
- **Overlay orchestration do HUD:** substituir lista manual de `visible` por
  `ModalManager`/router.

## Preservar e reformular

- **Research Board:** preservar modelo espacial, visual, estados, tooltips e
  atualização por sinais. Adaptar zoom/densidade/scroll/header para 1280.
- **Minimap:** preservar desenho e clique; acrescentar legenda e shell.
- **Loading:** preservar identidade, emblema e progresso; estabilizar layout.
- **Targeting no mapa:** preservar semântica e ESC; melhorar modo/cursor/forma.

---

# 7. Proposed Information Architecture

```text
Game Shell
├── Global status
│   ├── resources and economy
│   ├── active research
│   ├── turn / phase
│   └── critical strategic states
├── Primary navigation
│   ├── Research
│   ├── Empire
│   ├── Diplomacy
│   ├── Victory
│   └── Event Center
├── Map workspace
│   ├── world labels and markers
│   ├── movement / targeting feedback
│   └── minimap
├── Context panel
│   ├── Tile
│   ├── Unit
│   └── City
├── Attention / Turn Controller
│   ├── required decisions
│   ├── warnings
│   └── end turn
└── Modal layer
    ├── critical alert
    ├── confirmation
    ├── full-screen strategy screen
    └── game result
```

Hierarquia de informação:

1. **Agora:** risco, decisão ou ação deste turno.
2. **Estado:** recursos, pesquisa, guerra, produção e objetivo ativos.
3. **Contexto:** entidade selecionada.
4. **Detalhe:** tela estratégica ou tooltip.
5. **Histórico:** Event Center.

Esse modelo reduz recall: o jogador não precisa lembrar quais cidades estavam
ociosas nem qual toast apareceu durante a IA.

---

# 8. Proposed Gameplay HUD Architecture

## Opção A — Top status + contexto direito + faixa de atenção inferior

```text
┌ Global status / research / primary nav / critical state ┐
│                                                         │
│                        MAPA                      Context │
│                                                  panel  │
│                                                         │
├ Minimap ───── Attention items / targeting ─── End Turn ┤
```

- Topo: chips compactos de recurso, pesquisa ativa e navegação.
- Direita: painel contextual com largura limitada e modo compacto/expandido.
- Base: Attention items, modo de mira e Turn Controller.
- Minimap continua no canto inferior esquerdo.
- Event toasts aparecem abaixo do topo e também entram no histórico.

Vantagens: migração incremental do layout atual, mapa central preservado,
contexto continua próximo do local onde já está. Desvantagem: requer disciplina
de largura no painel direito.

## Opção B — Command bar superior + inspector inferior colapsável

```text
┌ Primary nav / resources / alerts / End Turn ┐
│                                             │
│                    MAPA                     │
│                                             │
├ Minimap ───── Context inspector / actions ──┤
```

Vantagens: mais largura para habilidades e produção; muito boa em ultrawide.
Desvantagens: cobre o eixo vertical do mapa, disputa espaço com target hints e
exige mudança maior nos hábitos atuais.

## Recomendação

Adotar **Opção A**. Ela mantém o mapa como workspace, preserva o investimento no
painel contextual e minimiza risco de migração. Em 1280, o contexto deve usar
largura de 400–460 px ou modo drawer; nunca os ~688 px medidos hoje. Em 21:9,
usar max-width em vez de esticar painéis.

O End Turn deve apresentar três estados:

- **Ready:** nenhuma decisão requerida.
- **Pending (N):** clique abre checklist; primeiro clique não avança.
- **Processing:** bloqueado com progresso/fase da IA quando disponível.

O jogador pode escolher “finalizar mesmo assim” para itens adiáveis; decisões
realmente obrigatórias são definidas pelo produto, não hardcoded no botão.

---

# 9. Unit UX Architecture

## Estrutura proposta

1. **Header:** nome, forma, veterania, owner, classe e foco/câmera.
2. **Vital stats:** HP em barra, ataque, defesa, movimento e alcance com ícones
   + números; deltas em tooltip.
3. **Command strip:** mover, fortificar, explorar e comando contextual.
4. **Ability grid:** técnicas, feitiços, portal, melhorar, dissolver e upgrade.
5. **Passives & traits:** lista compacta colapsável, separada de status.
6. **Temporary status:** duração, origem e efeito.
7. **Context footer:** tile, supply, tensão, ordem e bloqueios.

## `AbilityButton` obrigatório

Cada habilidade deve ter:

- ícone ou placeholder semântico;
- nome curto;
- custo (Mana/Ouro/carga/ação);
- cooldown como overlay numérico, não sufixo textual;
- estado `ready`, `targeting`, `active`, `cooldown`, `blocked`;
- razão de bloqueio no tooltip e texto acessível;
- tipo de alvo e alcance;
- tecla, quando existir.

O componente precisa servir Muralha, Golpe, Saraivada, Retirada, Ataque
Furtivo, Bombardeio e todos os feitiços. Não deve conhecer ids concretos.

## Passivas e status

- Passiva intrínseca, passiva de doutrina e traço são dados permanentes e ficam
  numa seção própria.
- Buff/debuff/stance com duração aparece como chip de status com turnos.
- Lendária e Manifestação são badges de identidade, não linhas no meio do texto.
- Hoste sem comando é warning de ação, com acesso ao motivo.
- O inspector público mostra apenas informação pública; o painel do dono pode
  expor pesquisa e custos.

## Targeting

Ao iniciar mira, a UI entra num modo explícito: banner fixo, cursor coerente,
nome da habilidade, alvo válido, custo e `ESC cancela`. Cor deve ser reforçada
por contorno/padrão e símbolo. O painel não deve reescrever toda a descrição da
unidade só para exibir a instrução.

---

# 10. City UX Architecture

## Estrutura proposta

- **Header persistente:** nome, nível I–IV, owner, população, HP/escudo e foco.
- **Resumo:** outputs, upkeep, slots, território, anexação e alertas.
- **Produção:** atual/ETA/espera por Mana, fila futura se existir, catálogo por
  categoria.
- **Buildings:** construídos, slots e manutenção.
- **Territory:** tiles trabalhados, recursos e ação de anexar.
- **Defense & Projects:** fortificação, ataque da cidade, evolução urbana.
- **Ritual:** aparece somente quando relevante, com estado público claro.

Esses itens podem ser tabs dentro de um painel contextual; não precisam de uma
tela por mecânica.

## Produção

Categorias sugeridas: unidades, doutrina/magia, edifícios econômicos,
infraestrutura urbana, projetos, Lendária/Manifestação. Cada item exibe nome,
custo PP, Mana/Ouro se houver, ETA, requisito principal e consequência. Razões
de bloqueio não devem ficar apenas no hover: o item selecionado apresenta o
motivo em texto persistente.

## City Production Summary

No HUD/Empire Overview, uma linha por cidade:

`Cidade II · Bombarda · 3 turnos` ou `OCIOSA — escolher produção`.

Ordenação inicial: decisão requerida → ameaça → espera de recurso → ETA menor.
Clique foca a cidade e abre diretamente a tab adequada.

---

# 11. Research / Progress / Attention Architecture

## Research Board

Preservar:

- três árvores dentro do mesmo sistema;
- linhas, tiers, conexões e capstone;
- cinco estados visuais;
- footer de detalhe e tooltip rico;
- build lazy e refresh orientado a sinal.

Adaptar:

- modo compacto abaixo de 1440 px, reduzindo largura de card e fonte de
  metadado sem reduzir o alvo de clique;
- header de tiers sticky e coluna de ramo sticky;
- indicação inequívoca de scroll horizontal;
- “ir para ativo”, “ir para disponível” e zoom 80/100%;
- debug fora do chrome de jogador;
- resumo do projeto ativo no HUD com nome, progresso, ETA e pausa;
- completion flow que registra evento e solicita próximo projeto.

## Atenção ligada à pesquisa

- `research_idle`: Required, abre árvore nos disponíveis.
- `research_completed`: Completion, log + toast; se ficar ociosa, promove o
  item `research_idle`.
- `research_blocked/overflow`: Warning/Info conforme regra, nunca silencioso.
- Um projeto ativo não precisa gerar item de atenção; seu chip persistente é
  suficiente.

---

# 12. Notifications, Event Center and Critical Alerts

## Taxonomia proposta

| Categoria | Exemplos | Severidade comum |
|---|---|---|
| Critical | guerra contra humano, cidade perdida, ritual rival em 1 rodada | Critical |
| Decision | pesquisa ociosa, cidade ociosa, convite de evento | Required |
| Completion | pesquisa, prédio, unidade, projeto, melhoria | Success |
| Combat | unidade atacada/morta, cidade ameaçada, saque | Warning/Critical |
| Diplomacy | guerra, paz, trégua, campanha | Important |
| Economy | déficit, tensão, espera por Mana | Warning |
| World Event | anúncio, fase, objetivo, resultado | Important/Critical |
| Progress | ritual, produção, pesquisa | Info |
| System | save, load, erro | Info/Error |
| Debug | cheats e diagnóstico | Debug-only |

## Modelo de evento

`UIEvent` proposto: `event_id`, `turn`, `category`, `severity`, `title`,
`body`, `source_id`, `world_coord`, `primary_action`, `secondary_action`,
`dedupe_key`, `expires_as_toast`, `acknowledged` e payload de apresentação.
O evento pode ser derivado de sinais existentes; não exige mudar o save na
primeira implementação.

## Toast × log × banner × modal

| Saída | Uso | Exemplos |
|---|---|---|
| Toast | Confirmação breve e reversível | construção iniciada, unidade evoluiu |
| Event log | Tudo que merece consulta posterior | combate, unlock, economia, diplomacia |
| Banner | Mudança estratégica que não exige escolha imediata | guerra, paz, cidade capturada |
| Modal | Decisão bloqueante ou fim de partida | evento com escolha, game over |
| Persistent tracker | Objetivo em curso | Dragão, ritual, crise |

War Alert recomendado: banner com facção, motivo conhecido, “Ver Diplomacia” e
“Ir para ameaça” quando houver coordenada. Deve também entrar no log e marcar
Diplomacia; não precisa pausar o jogo como modal em todas as ocorrências.

O Event Center abre por um botão com badge, permite filtros e navegação para a
origem. Mensagens repetidas devem agrupar por `dedupe_key` sem apagar fatos.

---

# 13. Victory / Diplomacy UX

## Vitória em duas camadas

**Summary:** três cards/linhas comparáveis — Dominação, Supremacia e
Transcendência — cada uma com progresso, próximo requisito e risco rival.

**Detail:** abre uma via e mostra requisitos, rivais, cidades elegíveis,
pesquisas e ritual. Explicações longas saem do resumo. A barra superior pode
ter apenas um indicador quando uma via entra em estado crítico.

Na tela final, separar:

- resultado e motivo em linguagem de jogador;
- estatísticas/snapshot;
- detalhes das três vias;
- ações: jogar novamente, menu principal e carregar jogo.

O runtime já emite `victory_type`, mas a apresentação deve garantir motivo
final compreensível e fallback de telemetria para debug.

## Diplomacia

Lista/resumo por facção: identidade, paz/guerra/trégua, duração da trégua,
desgaste, força relativa comunicável e alertas. Detail: motivo da guerra,
objetivo/campanha quando público, efeitos econômicos, propor paz/declarar
guerra e confirmação das consequências.

Declarar guerra pelo jogador deve pedir confirmação. Declaração da IA deve
gerar War Alert. Paz aceita/recusada entra no Event Center e atualiza o estado
persistente; não depender de toast.

---

# 14. Main Menu / Setup / Loading / Pause / Settings / Save-Load

## Main Menu

Manter quatro ações principais. Acrescentar versão/build discreta, identidade
visual do mundo e foco de teclado. “Sair” pode pedir confirmação se a plataforma
não oferecer comportamento padrão previsível.

## Setup

Trocar a predominância de prosa por comparação:

- quatro opções de raça com cor/símbolo/nome;
- painel de resumo com identidade, bônus e dificuldade percebida;
- lore expandível, não bloco obrigatório;
- rivais e parâmetros realmente configuráveis;
- explicação explícita de mapa fixo e dificuldade fixa enquanto continuarem
  sem escolha.

## Loading

- Fixar a largura do container; título faz wrap em área estável.
- Barra e percentual nunca mudam de posição ou largura.
- Motes usam centro/viewport, não posição fixa `(800, 450)`.
- Mensagem curta principal + detalhe da fase em linha separada.
- Load síncrono que congela continua dívida técnica visível; tratar em fase de
  implementação, sem prometer progresso falso.

## Pause / Settings / Debug

- Pausa: resumo curto da partida, save status e confirmação para menu principal
  se há progresso não salvo.
- Settings: áudio, vídeo/window mode/resolução/VSync, UI scale, acessibilidade,
  controles e gameplay presentation.
- Debug: rota exclusiva em debug build, sem morar dentro de Settings e sem
  transição inesperada de página para overlay.

## Save/Load

Cada slot deve mostrar nome do reino, raça, turno, data, versão/save schema,
estado de vitória/derrota e, se barato, miniatura. Estados: vazio, carregando,
corrompido, incompatível e deletado. Delete e load durante partida continuam
confirmados. O relatório não propõe mudar o schema de save nesta fase.

---

# 15. Proposed Design System

Usar a Research Board como referência de **clareza e contraste**, não como
template para transformar tudo em card.

## Tokens

- Espaçamento: 4, 8, 12, 16, 24, 32 px.
- Tipografia: Display 30–36; Title 24–28; Section 18–20; Body 16; Secondary
  14; Caption 12, nunca menor na UI essencial.
- Alvos: mínimo 40 × 40 em desktop, 44 × 44 preferível.
- Raios: 4 para controles, 8 para painéis, 12 para modais.
- Estados: neutral, hover, focused, selected, disabled, warning, critical,
  success e targeting.
- Profundidade: canvas, dock, overlay, modal; no máximo quatro níveis.

## Cor

- Base slate/charcoal da árvore para superfícies estratégicas.
- Bronze/dourado como navegação, seleção e prestígio; não em todo contorno.
- Azul para informação/progresso; âmbar para atenção; vermelho para crítico;
  verde para sucesso. Nenhum estado depende só da cor.
- Cores raciais aparecem em avatar, borda fina, marcador e mapa, não no fundo
  inteiro do painel.

## Component library

`ScreenFrame`, `OverlayFrame`, `ResourceChip`, `NavButton`, `AttentionBadge`,
`SectionHeader`, `StatItem`, `ProgressItem`, `AbilityButton`, `StatusChip`,
`PassiveItem`, `ProductionItem`, `EventItem`, `AttentionItem`, `EmptyState`,
`ErrorState`, `ConfirmDialog`, `TooltipCard` e `TargetingBanner`.

Evitar “card everything”: barras, listas compactas e agrupamento tipográfico
são melhores para dados repetidos. Card deve indicar unidade conceitual ou ser
clicável.

---

# 16. Motion and Feedback Guidelines

- Hover/focus: 80–120 ms; abertura de painel: 150–220 ms; modal crítico:
  200–280 ms. Nada essencial espera animação terminar.
- Mudança de recurso usa pulso discreto e delta; nunca desloca layout.
- Cooldown faz tick no início do turno com mudança visual breve.
- Conclusão de pesquisa/produção usa toast + log + atualização do chip.
- Targeting muda cursor, banner e tiles na mesma frame lógica.
- Dano mantém popup curto, mas morte/ameaça também registra evento.
- Câmera só salta por ação explícita do jogador; alertas oferecem “ir para”.
- Loading spinner/progresso pode animar; texto/barra permanecem estáveis.
- `reduced_motion` desativa pulsos, partículas e grandes transições, mantendo
  feedback por forma/texto.
- Não criar tweens contínuos em listas ou rebuilds por frame.

---

# 17. Accessibility / Resolution / Input

## Resolução

- Baselines obrigatórias: 1920 × 1080, 1600 × 900 e 1280 × 720.
- Ultrawide: mapa expande; painéis usam max-width e safe margins, não stretch.
- 1280: painel contextual compacto/drawer; research em modo compacto.
- UI scale: 80/90/100/110/125/150%, testada com texto português longo.
- Safe area e resize precisam recalcular partículas, minimap e overlays.

## Acessibilidade

- Contraste WCAG como meta operacional para texto e controles.
- Cor sempre acompanhada de ícone, contorno, padrão ou texto.
- Tooltips também acessíveis por foco; não apenas hover.
- Foco visível e ordem previsível em todas as telas.
- Tamanho de fonte nunca usado como única hierarquia.
- Opções de reduced motion, escala, alto contraste e volume por categoria.

## Input

Prioridade proposta: modal → targeting → painel/contexto → mapa → câmera →
atalhos globais. ESC recua um nível; Enter confirma apenas o foco atual; Espaço
não termina turno enquanto um campo/texto/modal tem foco. Um
`NavigationManager` deve registrar stack, foco anterior e back action.

Controles precisam de tela própria e hints consistentes. O sistema atual só
expõe `ui_accept` e `ui_cancel`; mouse/teclado funcionam, mas gamepad,
remapeamento e descoberta não têm arquitetura visível.

---

# 18. Godot UI Architecture

## Diagnóstico atual

- `HUD.gd` tem cerca de 1.900 linhas úteis e 126 declarações/conexões de nodes
  e sinais. Ele apresenta, roteia input, cria overlays, monta botões, formata
  dados e coordena gameplay.
- Overlays são fechados/abertos por uma lista manual de visibilidade.
- `MenuPager` resolve navegação local, mas não existe stack global.
- `TileInspector` é uma boa semente de presenter.
- `V2ResearchBoard` mostra o padrão desejável: estado externo, eventos,
  atualização incremental e construção lazy.

## Arquitetura proposta

```text
Domain / runtime (inalterado)
        │ signals + queries
        ▼
Presenters / view models
  EmpireHUDPresenter
  UnitPresenter
  CityPresenter
  DiplomacyPresenter
  VictoryPresenter
        │ immutable display data
        ▼
UI services
  UIShell · NavigationManager · ModalManager
  AttentionService · UIEventCenter · TooltipService
        │
        ▼
Reusable scenes/components
        │
        ▼
Screens / panels
```

Regras:

- Presenter formata e agrupa; não decide combate, custo ou disponibilidade.
- Attention consulta fontes reais e deduplica; não vira save paralelo.
- `UIEventCenter` recebe eventos estruturados. Uma ponte temporária converte
  `EventBus.notify(text, kind)` para evento `Info/legacy` durante migração.
- `ModalManager` possui uma stack única, backdrop, captura de input e restaura
  foco. Targeting continua fora da stack, mas tem prioridade formal.
- `UIShell` controla top bar, nav, contexto, minimap, attention e modal layer.
- Telas são cenas pequenas; não criadas integralmente em `HUD.gd`.
- Updates são signal-driven. `_process` fica apenas onde há animação/FPS/
  processamento comprovadamente necessário.
- Listas grandes usam cache, diff e virtualização apenas se profiling pedir.

## Migração segura

1. Criar componentes/serviços ao lado do HUD atual.
2. Adicionar adapters para sinais e queries existentes.
3. Migrar uma superfície por vez, com feature flag de desenvolvimento.
4. Remover código legado só depois de paridade funcional e visual.
5. Não mudar regras ou save enquanto a camada antiga e a nova coexistirem.

---

# 19. Implementation Roadmap

## Fase UI-1 — Foundation e Game Shell

- Tokens e component library mínimos.
- `UIShell`, `NavigationManager`, `ModalManager`, focus/back/input priority.
- Modelo `UIEvent`, ponte do `notify` legado e Event Center básico.
- `AttentionService` read-only e contratos de presenter.
- Loading estável e Settings/DevTools separados estruturalmente.

Critério: shell abre/fecha todas as interfaces sem regressão, nenhum evento se
perde e as três resoluções baseline passam.

## Fase UI-2 — HUD, Attention e Turn Controller

- Top bar em chips, research progress/idle e strategic alerts.
- City Production Summary, checklist de pendências e End Turn em estados.
- Toast/banner/log/modal taxonomy.
- War Alert, cidade ameaçada/perdida, ritual crítico, déficit e tensão.
- Minimap dentro do novo shell.

Critério: as cinco hipóteses P0 deixam de ocorrer em fluxos automatizados e
visuais.

## Fase UI-3 — Context Panels e Strategy Screens

- Unit Panel + `AbilityButton`, status/passives/cooldown.
- City Panel + produção categorizada e territory/defense/ritual.
- Tile Inspector componentizado.
- Empire Overview, City List, Unit List.
- Diplomacy e Victory em summary/detail.
- Research responsiva, preservando sua linguagem.

Critério: paridade de todas as ações atuais, estados V2 complexos e 1280 sem
perda de ação ou conteúdo essencial.

## Fase UI-4 — Menus, Save/Load, Accessibility e Polish

- Main menu/setup/loading/pause/settings/save-load finais.
- Controls/keybindings, UI scale, high contrast e reduced motion.
- Glossary/help contextual, empty/error states e confirmações.
- Motion/audio/cursor/faction identity.
- Tela final e motivos de fim de jogo.

Critério: fluxo completo teclado/mouse, smoke 16:9 + ultrawide, navegação/foco,
regressão visual e performance.

## Estratégia de testes

- Unitários para presenters, taxonomy, dedupe, atenção e prioridade de input.
- Integração para cada fluxo: pesquisa concluída/ociosa, produção concluída/
  ociosa, guerra/paz, captura, ritual, evento, fim de jogo, save/load.
- Golden screenshots em 1920 × 1080, 1600 × 900, 1280 × 720 e um 21:9.
- Estados controlados: 4 feitiços, cooldown, buff/debuff, Lendária,
  Manifestação, Hoste sem comando, cidade I–IV, fortificação, espera por Mana,
  déficit, tensão, recurso melhorado, portal e ambiente.
- Testes de foco/ESC/Enter/Space, tooltip por teclado e mudança de resolução em
  runtime.
- Orçamento: refresh de painel contextual < 16 ms no hardware de referência;
  nenhuma reconstrução contínua sem profiling que a justifique.

## Riscos

- “Arrumar o HUD” sem separar eventos/atenção apenas redistribui o mesmo texto.
- Reescrever tudo de uma vez ameaça a enorme cobertura funcional já existente.
- Presenter que replica regra de gameplay cria divergência.
- Alertas demais recriam fadiga; severidade e dedupe são essenciais.
- UI scale pode quebrar strings portuguesas e cards da árvore.
- Um ModalManager mal integrado pode regredir ESC/targeting, hoje funcional.
- Arte final prematura mascararia problemas de hierarquia; componentes e
  contraste devem vir antes.

## Decisão de encerramento

Esta fase termina no plano. Nenhuma das recomendações acima foi implementada.
O próximo escopo deve ser aprovado externamente antes de virar mudança de UI.

# Aetherlands — Game Design Bible

Documento vivo, não um changelog. Três funções, nesta ordem de prioridade:

1. **Registrar o que já existe** — uma fotografia confiável do projeto, para não perdermos a visão do jogo enquanto implementamos sistemas isolados.
2. **Registrar a visão do jogo** — para que toda nova mecânica seja comparada com a experiência que queremos produzir, não só com "dá pra fazer".
3. **Servir como mapa do desenvolvimento macro** — para sabermos quais grandes sistemas ainda faltam antes de voltar a tuning pesado.

Convenção: a Parte II (inventário) deve refletir o código real, não a memória de quem escreveu. Quando o código mudar, atualize a Parte II no mesmo PR/commit que mudou o comportamento — um inventário desatualizado é pior que nenhum inventário, porque engana com confiança.

---

## Parte I — Visão

**O que é o jogo**: Aetherlands é um 4X de fantasia medieval, em Godot 4, para partidas single-player contra 1-3 civilizações rivais controladas por IA e (visão de produto) multiplayer entre jogadores — preservando a mesma identidade de construção de civilização, mundo ativo e interação entre civilizações, com fundação de cidades, gestão de território/economia, pesquisa, magia, diplomacia, guerra e três condições de vitória distintas. *(A implementação hoje é single-player-vs-IA — ver Parte II; multiplayer é visão de produto, não feature implementada, ver "Status das decisões" na Parte III.)*

**Inspiração em Civilization**: a estrutura 4X de turnos, desenvolvimento civilizacional e múltiplas condições de vitória é inspirada nessa tradição; a forma como o mundo, eventos e interação funcionam é parte da identidade própria de Aetherlands, não uma repetição dela.

**O que diferencia**:
- Fantasia como identidade, não como reskin — magia, monstros e raças têm mecânica própria, não são "unidade custom com nome diferente".
- Partidas de ~3 horas: escopo deliberadamente compacto, não uma campanha de dezenas de horas.
- Guerra é importante, mas não deve dominar a experiência — é uma entre várias vias de pressão/oportunidade, nunca a única forma de progresso relevante.
- O mundo é uma força ativa, não um tabuleiro passivo — eventos globais devem criar crises e oportunidades que nenhum jogador controla sozinho.
- A interação entre civilizações é parte central da experiência, tanto contra IAs quanto (visão futura) contra outros jogadores. O mundo ativo deve criar crises, oportunidades e situações que incentivem cooperação, competição e negociação — não precisamos de multiplayer para o jogo parecer social: se uma IA rival muda de decisão porque você ignorou um Dragão, isso já é interação sistêmica.

**Frase-norte** (Parte III, repetida aqui por ser a bússola de qualquer decisão de design):

> Um 4X de fantasia compacto, em que construir uma civilização é importante, guerrear é importante, mas o mundo também é uma força ativa que cria crises, oportunidades e situações que fazem as civilizações interagirem.

E a ideia companheira, talvez mais importante ainda:

> O jogo deve criar histórias memoráveis durante a partida.

Não "Dragon spawned. +50% monster damage." — e sim "O Dragão despertou. Ele está indo para o território Humano. Quem vai ajudar?" seguido de um Orc em guerra pesando se deixa o inimigo mais fraco cair sozinho, um Elfo entrando pela recompensa arcana, um Anão vendendo armas em vez de lutar. Isso é o padrão de qualidade para qualquer sistema macro novo: ele gera essa espécie de decisão, ou é só mais uma unidade/número?

---

## Parte II — Tudo que já construímos

*(Levantamento feito por inspeção direta do código nesta data; ver convenção no topo do documento — atualizar junto com qualquer mudança de comportamento.)*

### Raças e civilizações

4 raças jogáveis (`human`, `elf`, `dwarf`, `orc`), cada uma com nome de civilização e lema próprios (`GameSetupScreen.gd`). Diferenciação mecânica é modesta por design (nunca assimetria estrutural):

| Raça | Bônus econômico (`RaceEconomy.gd`) | Unidade exclusiva |
|---|---|---|
| Human | +5% em todos os yields (generalista, sem nicho) | Cavaleiro Real |
| Elf | +20% mana, +10% ciência | Arqueiro Solar |
| Dwarf | +10% ouro/produção em Colina/Ferro | Guarda-Machado Anão |
| Orc | +10% produção, +15% crescimento populacional | Berserker da Horda |

`CivilizationPersonality.gd` adiciona uma intenção prospectiva por civ (derivada do seed do mapa, nunca salva), com viés: Orc→Militar, Elf→Arcana, Dwarf→Comercial+Industrial, Human→sem viés. Isso é distinto de `CityIdentity`, que é uma leitura retrospectiva ("o que essa cidade já construiu"), não uma intenção.

### Unidades — 47 entradas treináveis (`UnitDatabase.gd`)

O catálogo reúne o elenco original, 21 unidades da progressão mundana e dez unidades mágicas V1. As quatro exclusivas raciais continuam condicionadas à raça; entradas legadas são preservadas para compatibilidade. Existem também seis tipos invocados, incluindo Lich Ancião e Arquidemônio. General concede apoio próximo, Engenheiro repara cerco e Mercador estabelece comércio; armas contra cavalaria, blindagem e cidades possuem efeitos próprios no combate.

### Edifícios — 43 entradas (`BuildingDatabase.gd`)

Infraestrutura econômica, militar, comercial e mágica, com treinamento, requisitos e especializações. Melhorias reutilizam o espaço e a coordenada do prédio anterior. Cada escola possui estrutura inicial e estrutura ritual; o Santuário da Transcendência exige pesquisa própria. Construções são escolhidas na cidade e posicionadas em terreno elegível.

### Tecnologia e magia — 110 pesquisas (`TechDatabase.gd`, `MagicDatabase.gd`)

55 pesquisas mundanas em dez níveis e 55 mágicas: seis escolas de nove níveis mais Transcendência universal. As árvores têm telas próprias, mas compartilham uma pesquisa ativa e a renda de ciência. Trocar de pesquisa conserva o progresso individual. Escolas V1: Sagrada, Infernal, Necromancia, Druidismo, Arcanismo e Elementalismo. As doze pesquisas mágicas antigas continuam reconhecidas para migração e partidas legadas.

### Grimório e rituais (`MagicRuntime.gd`, `SpellManager.gd`)

26 poderes V1, incluindo seis Grandes Rituais, além dos quatro feitiços legados. Conjuradores têm ação, recarga, alcance, manutenção e vulnerabilidade a silêncio. Regiões podem curar, ocultar, causar dano, alterar terreno ou transportar tropas. Rituais comprometem unidades durante vários turnos e anunciam sua sede ao mundo; podem ser interrompidos. Regras, custos e resultados estão em [MAGIC_IMPLEMENTATION.md](MAGIC_IMPLEMENTATION.md).

### Monstros e covis — 5 tipos (`MonsterDatabase.gd`, `MonsterAI.gd`, `HexGrid.gd`)

Goblin, Troll, Wyvern, Esqueleto, Dragão — cada um com bioma, limites de população (por covil e globais) e um de 3 comportamentos: **guardião** (protege o covil, pode ser promovido a invasor), **invasor** (marcha sobre cidades, pilha tiles) ou **caçador** (patrulha caçando presas isoladas/fracas — Wyvern e Dragão). Perigo de covil escala tanto por distância do centro do mapa quanto por número do turno (o mundo fica mais perigoso no espaço E no tempo). Dragão é o mais forte (atk 16, HP 50) e o mais raro (1 por mapa).

### Território e economia

Território (`City.owned_tiles`) cresce organicamente, um tile por ponto de população ganho, sempre escolhendo o tile de maior pontuação entre a fronteira atual (`City._tile_claim_score` — food/produção/ouro/mana ponderados + bônus fixo de recurso − penalidade de covil perigoso). 4 yields: food, produção, ouro, mana. 5 recursos estratégicos, cada um com identidade própria além do yield bruto: Ferro (desconta unidades pesadas), Cavalos (desconta cavalaria), Gemas (desconta compra com ouro), Seda (rota de comércio extra), Nódulo Arcano (desconta custo de mana de feitiço, e é pré-requisito da vitória Arcana).

### Diplomacia e guerra (`Diplomacy.gd`, `TradeManager.gd`)

Guerra, paz e comércio funcionam entre todos os participantes, incluindo pares de IAs. Cansaço de guerra incentiva acordos; a paz aceita estabelece trégua de dez turnos. A interface informa motivo da guerra, cansaço, trégua e rotas. Declarar guerra invalida comércio entre os envolvidos. Unidades militares custam ouro em guerra. Transcendência e rituais ofensivos públicos podem provocar reação militar.

### IA Rival (`RivalAI.gd`, `StrategicAI.gd`, `MagicAI.gd`)

Decide pesquisa, produção, expansão, guerra, campanhas, paz e comércio usando informação explorada e custos normais. Procura recursos/Nódulos, enfrenta monstros, usa suportes e magia, reúne ritualistas e reage a ameaças públicas. Especialização depende de raça e personalidade. O tamanho desejado do exército depende das cidades e da guerra; a preparação contra o Dragão admite reserva maior. Ouro pode acelerar produção. O RNG individual é salvo para preservar decisões após carregar.

### Condições de vitória (`VictoryConditions.gd`, `VictoryCampaign.gd`)

Partidas novas: **Dominação**, **Supremacia Militar** (pesquisa final e conquistas desenvolvidas de rivais) e **Transcendência** (duas escolas, dois rituais distintos concluídos, Nódulos, Santuário e canalização de sete turnos). Há progresso na interface, avisos de ameaça e interrupção. Saves anteriores preservam Domínio Territorial/Ascensão Arcana antigos. A ordem de detecção resolve empates, sem impor prioridade estratégica. Eliminação completa do humano encerra sua participação.

### UI (`scenes/ui/`)

6 telas principais: Título, Configuração de Partida, HUD (a tela de jogo — hospeda internamente os painéis de Produção, Árvore Tecnológica, Diplomacia, Vitória, Grimório, Unidade, Fim de Jogo, Debug e Minimapa), Menu de Pausa, Configurações, Tela de Carregamento.

### Save/Load (`SaveManager.gd`)

`SAVE_VERSION = 21`, com migração explícita de v17–20. JSON com gravação temporária antes da substituição. O mapa base é regenerado por seed e recebe alterações persistidas de terreno/recursos. Estado de unidades, cidades, ordens, pesquisa, diplomacia, comércio, magia, eventos e RNG é restaurado. Participantes e recompensas do Dragão sobrevivem ao JSON sem duplicar pagamentos. Slots aparecem na tela Carregar Jogo.

### Testes e infraestrutura de diagnóstico

48 scripts unitários e harnesses de campanhas com seeds fixas, incluindo mapa 320×84 e partidas naturais até o encerramento. Métricas atuais e limitações estão em [DEVELOPMENT_STATUS.md](DEVELOPMENT_STATUS.md). Os asserts verificam correção; tempo de CPU e vitórias de bots não comprovam diversão nem duração humana.

---

## Parte III — Identidade futura

### A mudança de cadência do roadmap

Até aqui, o ciclo de trabalho foi: **sistema → testes → diagnóstico → tuning → diagnóstico → tuning...** — excelente para sistemas individuais, mas insuficiente para dar ao jogo uma sensação de mundo coeso. A partir daqui, o ciclo passa a ser:

**sistema macro → integração → experiência jogável → próximo sistema macro**, e só depois, quando houver massa crítica de sistemas macro integrados: **grande fase de balanceamento → tuning → pacing → IA → números.**

### Alcance territorial da IA — revisão de setembro/2026

A investigação do gargalo de Nódulos Arcanos (ver histórico de commits, Roadmap Fase F/G) identificou uma causa estrutural: a IA rival cresce território organicamente (um tile por ponto de população, sempre a partir da fronteira já possuída), então um recurso a 15+ tiles de qualquer capital nunca se torna uma opção de posse, não importa o quão bem pontuado. Uma correção pontual na fórmula de pontuação de posse (peso de mana) foi testada e **não teve efeito mensurável** — o mesmo conjunto de 5 seeds de 15 continuou travado em exatamente 2/3 Nódulos. A hipótese corrente é alcance/assentamento, não preferência de pontuação.

**Status atual:** a investigação foi retomada na revisão de conclusão. A IA agora expande além de duas cidades, considera recursos conhecidos e valida caminhos para assentamentos. Campanhas V1 observaram controle de mais de três Nódulos e vitória natural por Transcendência. Isso resolve o bloqueio estrutural observado; distribuição por seed e equilíbrio entre estratégias continuam sujeitos a playtest.

### Checklist de fechamento da fase atual

- ✅ Fundamentos sistêmicos — avançados
- ✅ Três condições de vitória — implementadas
- ✅ IA básica — implementada
- ✅ PvE (monstros/covis) — implementado
- ✅ Magia — implementada
- ✅ Diplomacia/guerra — implementadas
- ✅ Alcance territorial de Nódulos Arcanos — expansão implementada e observada; tuning permanece aberto

### Regras de implementação das próximas mecânicas macro

Regras arquiteturais explícitas, fixadas antes de escrever a primeira linha do `WorldEventManager` — o objetivo é que o World Event nunca vire um grande bloco especial dentro do `GameManager`, e que persistência não seja retrofitada depois de o sistema já existir. Versão detalhada e vinculante destas regras: `docs/WORLD_EVENT_CONTRACT.md` — este documento define o que o sistema deve representar; o contrato define como o código deve obedecer isso, e evolui junto com a implementação enquanto esta seção permanece estável.

1. **Save/Load desde o primeiro commit.** Todo estado necessário para reconstruir um evento mundial após Save/Load deve ser persistível desde a primeira implementação do sistema, nunca uma etapa posterior — mesmo padrão já seguido pelas 3 condições de vitória (`SAVE_VERSION` sobe junto com a feature, não depois dela). Consequência direta: adicionar estado de evento ao save implica incrementar `SAVE_VERSION` e escrever testes de compatibilidade/fallback conforme o padrão já existente (`SaveManager.gd`) — o evento nasce integrado ao sistema de save, nunca como "depois fazemos migration".
2. **Estado persistente mínimo; estado derivável não é duplicado.** Persistir só o que não pode ser recalculado — mesmo princípio já usado pelas vitórias (ex.: `arcane_ritual_streak` é persistido porque é histórico acumulado; `arcane_progress` nunca é, porque é derivável a qualquer momento). Divisão de responsabilidade:
   - `WorldEventManager` → estado persistente mínimo do CICLO: evento atual, fase do FSM, turno de início, turno de término/limites, participantes, decisões dos participantes.
   - `DragonEvent` (e cada evento concreto futuro) → só o estado ESPECÍFICO daquele evento necessário para reconstrução (ex.: coordenada atual do Dragão, alvo escolhido), mais o resultado, se o evento estiver numa fase pós-resolução que ainda precise sobreviver a um save.
   - `WorldEvent` → lógica derivada/comportamento, nunca serializado como objeto inteiro.
   - Seed ou identificador determinístico entra na lista acima só se o evento tiver conteúdo gerado (posição, variação) que precise ser reproduzido de forma estável entre save/load — não é um campo obrigatório em todo evento.
3. **Determinismo sob RNG.** Qualquer resultado de evento que dependa de aleatoriedade deve ser determinístico e rastreável — mesma disciplina já estabelecida no harness de simulação (seed explícito, nunca uma chamada de RNG que não se consiga reproduzir depois).
4. **Mecânica genérica antes de conteúdo específico.** `WorldEventManager`/`WorldEvent` devem existir, com testes próprios, antes de qualquer evento concreto (`DragonEvent` incluído) ser escrito — o primeiro evento nunca deve determinar a forma da arquitetura.
5. **Eventos operam sobre civilizações, não sobre "IA vs jogador".** O sistema de eventos nunca deve assumir qual civilização é humana e qual é IA — cada participante é um `PlayerData`, ponto final. Isso mantém a arquitetura naturalmente compatível com multiplayer futuro (ver Parte I e "Status das decisões" abaixo), sem exigir reescrita do sistema de eventos quando ele chegar.

### Status das decisões

Convenção de leitura para o resto desta Parte III (e para qualquer adição futura) — toda afirmação sobre o futuro do jogo se encaixa em uma destas três categorias, e deveria dizer qual:

- **Implemented** — comportamento já existente e validado no código atual (pertence à Parte II).
- **Committed Direction** — decisão de design assumida para o desenvolvimento futuro, mas ainda não implementada.
- **Future / Hypothesis** — ideia exploratória que pode mudar ou ser descartada conforme aprendermos mais sobre o jogo.

Exemplos atuais:
- *Implemented*: as três condições de vitória.
- *Committed Direction*: o World Event System (`WorldEventManager`/`WorldEvent`).
- *Committed Direction*: o Dragon World Event como primeiro evento global concreto.
- *Committed Direction*: partidas-alvo de ~3 horas.
- *Committed Direction*: multiplayer entre jogadores (visão de produto de longo prazo — ver Parte I).
- *Future / Hypothesis*: Invasão dos Mortos, Eclipse Arcano, Portal Demoníaco, artefatos mundiais, espionagem, e qualquer outro evento/mecânica ainda não desenhado em detalhe.

Isto evita que a Bible vire uma segunda backlog gigantesca — uma ideia listada na Parte III como *Future/Hypothesis* nunca deve ser lida como compromisso de implementação.

### Fase Macro — "O Mundo Está Vivo"

1. World Event System (arquitetura genérica)
2. Dragon World Event (primeiro evento concreto)
3. Participação/cooperatividade entre jogadores
4. Recompensas e consequências globais
5. Persistência/save-load dos eventos
6. Primeiro playtest de experiência completa
7. Revisão do jogo como um todo
8. Identificação das próximas grandes mecânicas

Só depois volta o modo "agora vamos fazer o jogo ficar realmente bem balanceado".

#### Arquitetura: por que genérica antes de concreta

O Dragão não deve determinar a arquitetura inteira. Por isso a ordem é: primeiro `WorldEventManager` (responsável pelo ciclo de vida dos eventos) e `WorldEvent` (representação abstrata), com uma máquina de estados conceitualmente:

```
Dormant → Announced → Preparation → Active → Resolution → Completed
```

O FSM define o ciclo macro do evento; eventos concretos podem utilizar apenas as fases necessárias, desde que respeitem o contrato do sistema — nenhum evento é obrigado a passar artificialmente pelas seis fases.

Só então `DragonEvent` como primeira implementação concreta. Isso deixa o sistema pronto para, sem reescrever nada, adicionar no futuro: Invasão dos Mortos, Horda Goblin, Portal Demoníaco, Eclipse Arcano, Praga, Inverno Sobrenatural, Titã despertando, Continente amaldiçoado, Chuva de meteoros, Grande Migração, Artefato Mundial.

#### A mecânica mais promissora: cooperação sem aliança permanente

Eventos globais que fazem jogadores cooperarem taticamente sem virar aliados permanentes podem ser uma das grandes assinaturas do jogo. Cenário de referência:

> **Turno 72 — ⚠️ EVENTO MUNDIAL — O DRAGÃO DESPERTA**
> Uma criatura ancestral foi avistada nas montanhas do norte. Estimativa: extremamente perigosa. Primeiro alvo provável: território Humano.
> Deseja participar da expedição contra o Dragão?
> Human — Participará · Elf — Participará · Dwarf — Participará · Orc — Não participará

Isso gera situação política de verdade: o Orc pode estar em guerra com o Human e pesar se deixa o Dragão enfraquecê-lo ainda mais, ou se precisa dele vivo para vencer o Dragão depois; os outros três, sem o Orc (a maior força militar), precisam decidir se a expedição é viável sem ele. Um Elfo participa pela recompensa (artefato que aproxima da Ascensão Arcana); um Anão não manda tropas, mas vende armas para quem for. Isso é diplomacia emergente vinda do mundo, não de um menu de alianças.

- **Single-player**: você decide se ajuda uma IA rival.
- **Multiplayer** (visão futura): jogadores podem negociar quem participa, dividir riscos, competir pela recompensa ou até aproveitar a crise para atacar outro jogador.

**Princípio de design, a ser registrado antes de qualquer código de participação em evento**: eventos globais devem permitir cooperação sem exigir aliança diplomática permanente. Participação em um evento não altera automaticamente a relação política entre os participantes. "Participar" não é binário — o espectro inclui não participar, contribuir pouco ou muito, ajudar com tropas, com magia, ou apenas economicamente (vendendo recursos/armas a quem participa), explorar a situação em proveito próprio, e até atacar outro participante durante o próprio evento. O objetivo é cooperação emergente, não uma mecânica formal de "co-op quest" (`join_event = true` seria o oposto do que queremos).

#### Regra para eventos: nunca "só mais uma quest"

Um evento global só é válido se tiver pelo menos uma destas propriedades — checklist obrigatório antes de implementar qualquer evento novo:

- altera prioridades
- cria ameaça
- cria oportunidade
- modifica o mapa
- recompensa cooperação
- cria competição
- altera diplomacia
- cria uma janela temporal
- obriga decisões
- produz consequências persistentes

Sem isso, o jogo vira uma sequência de pop-ups aleatórios em vez de um mundo vivo. "Pelo menos uma" é o mínimo, não o alvo — um evento pequeno pode ter só uma propriedade, mas eventos mundiais maiores como o Dragão devem mirar várias simultaneamente (ameaça + oportunidade + janela temporal + consequência persistente, no exemplo dado).

### Pacing como requisito de produto

Partidas não devem chegar ao fim e revelar que duraram 7 horas por acidente. A partir de agora, pacing é métrica de produto, não só questão de balanceamento — mas **não precisa ser calibrado agora**: primeiro construir o jogo que queremos medir. Quando chegar a hora, medir:

- turno médio e duração real da partida
- duração por fase
- tempo até primeiro conflito
- tempo até primeira guerra
- tempo até primeiro grande evento
- tempo até primeira condição de vitória
- quantidade de decisões relevantes por partida

---

## Como manter este documento vivo

- Parte II muda junto com o código — se um PR muda comportamento listado aqui, o mesmo PR atualiza a linha correspondente.
- Parte I e a frase-norte da Parte III só mudam por decisão explícita de design, não como efeito colateral de uma feature pontual.
- Dívidas documentadas (como o gargalo de Nódulos) ficam registradas aqui com critério de retomada explícito — nunca removidas silenciosamente sem revisão.
- Este documento não substitui os comentários de código (que explicam o *porquê* local) nem o histórico de commits (que explica a evolução passo a passo) — ele existe para a pergunta que nenhum dos dois responde sozinho: "o jogo, hoje, como um todo, é o quê?"

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

### Unidades — 16 tipos jogáveis (`UnitDatabase.gd`)

12 unidades comuns (Colonizador, Guarda, Homem de Armas, Arqueiro, Cavaleiro, Batedor, Catapulta, Mago, Grifo, Ent, Golem de Pedra, Convocador de Sombras) + 4 exclusivas raciais (Cavaleiro Real/human, Guarda-Machado Anão/dwarf, Berserker da Horda/orc, Arqueiro Solar/elf). Cada uma exige uma combinação de tech + prédio específica (ver Tecnologia/Edifícios abaixo) — warrior e settler são as únicas sem gate nenhum.

### Edifícios — 15 tipos (`BuildingDatabase.gd`)

3 de rendimento puro sem treino (Celeiro, Oficina, Mercado), Muralhas (self-placed, defesa), 2 sem gate de tecnologia (Torre dos Sábios, Santuário do Nódulo — ambos "rendimento puro", nunca duplicam a formula de tech-gate), e 9 prédios de treino (um por unidade militar avançada, cada um atrás de uma tech própria — ver árvore abaixo).

### Árvore tecnológica — 21 techs, 4 tiers, 8 "escolas" (`TechDatabase.gd`)

7 escolas mágicas — **Arcanismo, Alquimia, Transmutação, Naturalismo, Geomancia, Elementalismo, Necromancia** — mais uma escola não-mágica, **Doutrina**, para o ramo militar/econômico mundano (Quartel, Estábulo, Arquearia, Batedor Montado, Celeiro, Oficina, Mercado, Muralhas, Navegação). Duas cadeias desconexas de propósito (militar e econômica) mais 2 techs isoladas (Muralhas, Navegação). Pesquisa é paga com "ciência" = soma de população/turno.

### Magia — 4 feitiços com efeito real (`SpellDatabase.gd`, `SpellManager.gd`)

Lança de Arcana (dano direto), Reanimar (cura 50% HP), Ruína Ígnea (dano + splash), Metamorfose de Gaia (transforma terreno tundra/deserto→campina). Cada um tem cooldown próprio e custo de mana descontável por controle de Nódulo Arcano. UI: painel "Grimório" na HUD.

### Monstros e covis — 5 tipos (`MonsterDatabase.gd`, `MonsterAI.gd`, `HexGrid.gd`)

Goblin, Troll, Wyvern, Esqueleto, Dragão — cada um com bioma, limites de população (por covil e globais) e um de 3 comportamentos: **guardião** (protege o covil, pode ser promovido a invasor), **invasor** (marcha sobre cidades, pilha tiles) ou **caçador** (patrulha caçando presas isoladas/fracas — Wyvern e Dragão). Perigo de covil escala tanto por distância do centro do mapa quanto por número do turno (o mundo fica mais perigoso no espaço E no tempo). Dragão é o mais forte (atk 16, HP 50) e o mais raro (1 por mapa).

### Território e economia

Território (`City.owned_tiles`) cresce organicamente, um tile por ponto de população ganho, sempre escolhendo o tile de maior pontuação entre a fronteira atual (`City._tile_claim_score` — food/produção/ouro/mana ponderados + bônus fixo de recurso − penalidade de covil perigoso). 4 yields: food, produção, ouro, mana. 5 recursos estratégicos, cada um com identidade própria além do yield bruto: Ferro (desconta unidades pesadas), Cavalos (desconta cavalaria), Gemas (desconta compra com ouro), Seda (rota de comércio extra), Nódulo Arcano (desconta custo de mana de feitiço, e é pré-requisito da vitória Arcana).

### Diplomacia e guerra (`Diplomacy.gd`, `TradeManager.gd`)

Guerra/paz com cansaço de guerra acumulável (ganha em guerra, decai mais rápido em paz) que empurra a IA a propor paz e aceitar a paz proposta. Unidades militares custam manutenção em ouro durante guerra. Rotas de comércio são um sistema à parte (`TradeManager`/`TradeRoute`), independente de estar em guerra ou paz com o parceiro da rota.

### IA Rival (`RivalAI.gd`) — 7 decisões autônomas por turno

`decide_production` (o que construir/treinar, por pontuação), `decide_war` (quando declarar guerra), `decide_campaign` (mantém objetivo+alvo de guerra persistentes), `decide_peace` (quando propor/aceitar paz), `decide_trade` (propõe rotas de comércio), `decide_arcane_ritual` (constrói Santuário quando elegível, ativa o Ritual quando há condições — deliberadamente sem avaliação de risco/guerra), `decide_research` (próxima tecnologia, por continuidade de cadeia + identidade + personalidade).

### Condições de vitória — exatamente 3 (`VictoryConditions.gd`)

**Dominação** (eliminar todos os rivais), **Domínio Territorial** (50% do mapa habitável, sustentado 5 turnos), **Ascensão Arcana** (4 de 7 escolas mágicas + 3 Nódulos Arcanos controlados + Santuário do Nódulo construído + Ritual ativado e sustentado 5 turnos, com interrupção total — nunca parcial — se cidade cair, nódulos caírem abaixo de 3, ou mana faltar). Ordem de detecção fixa e documentada como regra técnica de desempate, nunca prioridade estratégica.

### UI (`scenes/ui/`)

6 telas principais: Título, Configuração de Partida, HUD (a tela de jogo — hospeda internamente os painéis de Produção, Árvore Tecnológica, Diplomacia, Vitória, Grimório, Unidade, Fim de Jogo, Debug e Minimapa), Menu de Pausa, Configurações, Tela de Carregamento.

### Save/Load (`SaveManager.gd`)

`SAVE_VERSION = 16`. Formato JSON. Persiste apenas estado lógico (nunca visuais 3D) — terreno/recursos/covis/personalidade são regenerados deterministicamente do seed do mapa salvo, em vez de serializados diretamente.

### Testes e infraestrutura de diagnóstico

35 arquivos de teste unitário (911 funções `test_`) + 1 harness de integração (`test_simulation_balance.gd`, 5 funções, roda 200 turnos × 15 seeds fixas reutilizando o loop real de `GameManager`, não uma reimplementação paralela). O harness intencionalmente só tem asserts de correção (nunca de balanceamento) — imprime métricas observadas como baseline para comparação entre fases do roadmap, disciplina "medir antes de calibrar" mantida em todas as fases até aqui.

---

## Parte III — Identidade futura

### A mudança de cadência do roadmap

Até aqui, o ciclo de trabalho foi: **sistema → testes → diagnóstico → tuning → diagnóstico → tuning...** — excelente para sistemas individuais, mas insuficiente para dar ao jogo uma sensação de mundo coeso. A partir daqui, o ciclo passa a ser:

**sistema macro → integração → experiência jogável → próximo sistema macro**, e só depois, quando houver massa crítica de sistemas macro integrados: **grande fase de balanceamento → tuning → pacing → IA → números.**

### Dívida documentada: alcance territorial da IA

A investigação do gargalo de Nódulos Arcanos (ver histórico de commits, Roadmap Fase F/G) identificou uma causa estrutural: a IA rival cresce território organicamente (um tile por ponto de população, sempre a partir da fronteira já possuída), então um recurso a 15+ tiles de qualquer capital nunca se torna uma opção de posse, não importa o quão bem pontuado. Uma correção pontual na fórmula de pontuação de posse (peso de mana) foi testada e **não teve efeito mensurável** — o mesmo conjunto de 5 seeds de 15 continuou travado em exatamente 2/3 Nódulos. A hipótese corrente é alcance/assentamento, não preferência de pontuação.

**Status: congelado deliberadamente.** Isto é dívida de balanceamento/IA documentada, não um bug esquecido. **Critério de retomada**: após a Fase Macro, realizar um primeiro playtest completo e estabilizar minimamente o pacing e os sistemas de expansão. Nesse momento, reavaliar reachability, assentamento e controle de Nódulos em conjunto. O tuning só será retomado se os dados demonstrarem que o problema continua relevante depois das mudanças estruturais — implementar a Fase Macro, por si só, não é o critério; o critério é o pacing estabilizado o suficiente para o esforço de tuning não ser refeito por causa de uma mudança estrutural posterior.

### Checklist de fechamento da fase atual

- ✅ Fundamentos sistêmicos — avançados
- ✅ Três condições de vitória — implementadas
- ✅ IA básica — implementada
- ✅ PvE (monstros/covis) — implementado
- ✅ Magia — implementada
- ✅ Diplomacia/guerra — implementadas
- 🟡 Alcance territorial de Nódulos Arcanos (IA) — dívida de tuning, congelada (ver acima)

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

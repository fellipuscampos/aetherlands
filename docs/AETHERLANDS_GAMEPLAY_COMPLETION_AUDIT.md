# Aetherlands — Gameplay Completion Audit

**Fase:** 33 — Gameplay Completion + Release Balance
**Etapa:** A — Gameplay Completion Audit & Opening Diagnostic
**Data:** 28/09/2026
**Escopo:** auditoria funcional; nenhum ajuste de número, custo, rendimento, regra de IA ou condição de vitória.

Esta auditoria usa como fontes de verdade o jogo atual, `AETHERLANDS_V2_IMPLEMENTATION.md`,
`AETHERLANDS_UI_UX_AUDIT.md` e, quando não substituído por decisão implementada posterior, o documento conceitual da
V2. Ela separa deliberadamente completude, defeito funcional e balanceamento.

## Overall Gameplay Completeness

**Resultado executivo: o loop V2 é completo do Title ao Game Over, mas ainda não deve entrar diretamente no
Balance Lab.** Não foi encontrado P0, dead end de progressão, unlock sem consumidor ou rota de vitória impossível.
Há um P1 localizado no opening: depois de fundar a capital, a UI exige uma decisão de produção quando existe apenas
um item iniciável, o Colonizador, durante os oito primeiros turnos. Isso funciona tecnicamente, mas não oferece uma
decisão de produção real e cria pressão artificial por expansão.

Também foi encontrado um P2 de ciclo de vida da UI: na entrada de uma partida nova, o `UIShell` é ligado antes de o
jogador humano existir e a lista global de Attention fica vazia até um rebind/refresh posterior. O painel da cidade
continua mostrando “Sem produção”; portanto o loop não fica bloqueado.

O restante dos sistemas centrais está implementado e alcançável: 128 pesquisas, cidades I–IV, cinco recursos
econômicos, cinco melhorias territoriais, Construtor, seis Doutrinas, doze Técnicas, seis Lendárias, seis Escolas,
vinte e quatro feitiços, seis Manifestações, combate e captura, diplomacia, IA V2, eventos mundiais, Dragão,
save/load e as três vitórias.

| System | Expected V2 Role | Implemented? | Reachable? | Player-facing? | AI-usable? | Start-to-end tested? | Problem? | Severity | Recommendation |
|---|---|---:|---:|---:|---:|---:|---|---|---|
| Title → Setup → Loading → jogo | Entrada completa da partida | Sim | Sim | Sim | N/A | Sim | COMPLETE | — | Manter |
| Opening de produção | Primeira decisão local da capital | Sim | Sim | Sim | Parcial | Sim | GAMEPLAY GAP | P1 | Pequena rodada de Completion Fix antes do balance |
| Attention no primeiro frame | Expor pesquisa/produção ociosas | Sim | Sim | Sim | N/A | Sim | BUG | P2 | Rebind do jogador ao entrar em gameplay |
| Exploração e fundação | Converter Colonizador em cidade e revelar mapa | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Cidades I–IV | Território, slots, resistência e especialização | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Economia V2 | Ouro, Suprimentos, Mana, Produção e Conhecimento | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Balancear só na F33B |
| Infraestrutura | Sustentar exército, magia, pesquisa e cidade | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Recursos e Construtor | Converter disputa territorial em rendimento | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Pesquisa global | Um slot, progresso preservado, três árvores | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Doutrinas Militares | Seis composições mundanas distintas | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Balancear só na F33B |
| Técnicas | Doze ferramentas sem Mana | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Evolução de unidade | Atualizar tropas preservando investimento | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Lendárias | Um ápice militar global, substituível | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Escolas de Magia | Seis funções mágicas especializadas | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Balancear só na F33B |
| Feitiços | 24 ações mágicas com Mana/cooldown/alvo | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Manifestações | Seis ápices mágicos, um slot por Escola | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Missões autônomas de Manifestação | Fantasia conceitual de entidade autônoma | Não | Não | Não | Não | Não | DEFERRED POST-1.0 | P3 | Não bloquear 1.0 |
| Combate e movimento | Posicionamento, counters, cidade e terreno | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Diplomacia | Paz, guerra, trégua e desgaste | Sim | Sim | Sim | Sim | Sim | COMPLETE — POLISH LATER | P3 | Alianças/comércio profundo ficam fora do 1.0 |
| IA V2 | Estratégia → composição → produção → vitória | Sim | Sim | Indireto | Sim | Sim | COMPLETE | — | Balancear só na F33B |
| Eventos/monstros/Dragão | Pressão neutra e variação mundial | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Dominação | Última civilização sobrevivente | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Supremacia Militar | Exército Supremo + prova por conquistas | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Balancear timing só na F33B |
| Transcendência | Duas Escolas/Manifestações + ritual público | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Balancear timing só na F33B |
| Save/load | Preservar todos os sistemas relevantes | Sim | Sim | Sim | Sim | Sim | COMPLETE | — | Manter |
| Dificuldades adicionais | Variações futuras de desafio | Não | Não | Não | Não | Não | DEFERRED POST-1.0 | P3 | Não bloquear 1.0 |

As respostas binárias para o gate de completude são: o jogador pode alcançar naturalmente as três vitórias; todo
unlock de pesquisa tem consumidor; todo item atual de produção é alcançável; as doze Técnicas e os vinte e quatro
feitiços são utilizáveis; as seis Manifestações e seis Lendárias podem ser criadas; Lendária morta pode ser
substituída; cidades chegam a IV; os cinco recursos podem ser melhorados; a IA participa dos sistemas centrais; e o
save/load preserva os estados relevantes. Os testes controlados aceleram renda quando necessário, mas exercitam as
mesmas cadeias de pré-requisitos e gates do jogo.

## Opening

Foi executada uma partida nova real por `Main.tscn`, em janela, passando por Title, Setup e Loading. A força humana
inicial é **Colonizador + Guarda**. A capital foi fundada pela ação real do Colonizador e permaneceu jogável até T30.

| Marco | UNITS | BUILDINGS | PROJECTS | DEFENSE | OTHER | Pesquisa/estado |
|---|---|---|---|---|---|---|
| T1, antes de escolher | Colonizador disponível, 25 PP | Nenhum | Cidade II bloqueada: “Requer Planejamento Urbano.” | Muralhas I bloqueadas: mesmo motivo | Nenhum | 18 N1 pesquisáveis; nada ativo |
| T1, escolhas feitas | Colonizador em produção | Nenhum | Bloqueado | Bloqueado | Nenhum | Academia I ativa |
| T3 | Colonizador, 8 PP | Nenhum | Bloqueado | Bloqueado | Nenhum | Academia I em progresso |
| T5 | Colonizador, 16 PP | Nenhum | Bloqueado | Bloqueado | Nenhum | Academia I em progresso |
| T8 | Colonizador concluído; cidade ociosa | Nenhum | Bloqueado | Bloqueado | Nenhum | Academia I ainda em progresso |
| T9–T10 | Colonizador disponível | Academia disponível, 24 PP | Bloqueado | Bloqueado | Nenhum | Academia I concluída; Guardião N1 iniciado |
| T15–T20 | Colonizador disponível | Academia disponível | Bloqueado | Bloqueado | Nenhum | Guardião progride N1→N2 |
| T30 | Colonizador disponível | Academia e Salão dos Guardiões disponíveis | Bloqueado | Bloqueado | Nenhum | Guardião N1/N2 completos; N3 ativo |

O primeiro item alternativo surge no **T9**, por completar Academia I com os +2 Conhecimento base da cidade. A
produção do Colonizador termina no T8; produção ociosa não cria item automaticamente e os PP mostrados internamente
durante ociosidade são descartados ao selecionar um novo projeto, coerente com a mensagem “produção desperdiçada”.

O opening já tem decisões reais fora da produção: qual dos 18 N1 pesquisar, onde fundar, onde explorar e se produzir
o Colonizador disponível. A deficiência é especificamente a ausência temporária de alternativa **dentro** do prompt
obrigatório de produção.

## Colonizador Diagnostic

1. **O que pode ser produzido imediatamente?** Somente `Colonizador — 25 PP` pode ser iniciado. Cidade II e
   Muralhas I aparecem, mas estão bloqueadas por Planejamento Urbano; nenhum prédio foi pesquisado.
2. **Quantas escolhas reais existem?** Uma escolha de produção iniciável.
3. **Colonizador é a única produção disponível?** Sim.
4. **Por quanto tempo?** Da fundação até o T8 inclusive; a primeira alternativa aparece no T9 no roteiro auditado.
5. **Qual unlock encerra esse estado?** `Academia I` (`v2_infrastructure_academy_1`), que torna Academia produzível.
6. **Attention pressiona expansão?** Sim. Depois de corretamente ligado ao jogador, “Escolher Produção” é Required
   mesmo havendo uma única opção; “Encerrar mesmo assim” permite prosseguir, mas o destaque incentiva Colonizador.
7. **Existe estado de zero opção?** Não no opening normal: Colonizador permanece disponível. Há uma opção, não zero.
8. **A IA se comporta de forma diferente?** A IA usa os mesmos gates e catálogo, mas não enfrenta o prompt Required;
   ela funda suas cidades e pontua diretamente a produção. O problema é principalmente de decisão/UX humana.
9. **Classificação?** **GAMEPLAY GAP, P1.** Não é crash, deadlock nem questão de custo; é um sistema central que
   apresenta uma falsa escolha no início. Nenhum fix foi aplicado nesta etapa.

## Early Game

Exploração, fundação, primeira pesquisa, primeira produção, primeira infraestrutura e expansão são alcançáveis. A
pesquisa oferece escolha estratégica imediata; a produção local só ganha sua primeira bifurcação no T9. Depois disso,
infraestrutura, edifícios de treinamento e projetos urbanos passam a disputar a fila única da cidade. O early game é
**FUNCTIONAL BUT WEAK** apenas no recorte da produção inicial; não há deadlock.

## Midgame

O midgame possui decisões conectadas: especializar cidades por prédios repetíveis, ampliar nível/território, melhorar
recursos, administrar Ouro/Suprimentos/Mana, aprofundar Doutrina ou Escola, atualizar unidades, formar composição,
declarar guerra e reagir à composição observada. As cadeias de treinamento, Maestria e ritual ocupam slots e fila
normais, portanto não são menus paralelos sem custo de oportunidade. Classificação: **COMPLETE**.

## Late Game

N7–N9, Lendárias, Manifestações, fortificações máximas, Cidade IV e os dois capstones são alcançáveis. Dominação,
Supremacia e Transcendência terminam no pipeline normal de Game Over. A simulação multisseed da Fase 27 demonstrou
Transcendência natural e chegada natural a N9 nas três orientações; o fato de a amostra curta não produzir todas as
rotas é uma questão de pacing/execução para o laboratório, não impossibilidade. Classificação: **COMPLETE**.

## Economy

Ouro, Suprimentos, Mana, Produção local e Conhecimento global possuem fontes, consumidores, UI e persistência. O
Déficit impede novos compromissos econômicos, a Tensão Logística enfraquece exércitos acima da capacidade e upkeep é
recalculado pelo dono atual. As quatro raças têm exatamente dois bônus sistêmicos, aplicados uma vez. Não foi feita
recomendação numérica nesta etapa. Classificação: **COMPLETE**.

## Cities

Cidades avançam de I a IV pela fila comum; cada nível altera HP, slots, alcance territorial e anexação. Prédios
repetíveis e únicos respeitam slot, território, pré-requisito e proprietário atual. Fortificações I–III substituem a
cadeia anterior e participam de escudo, defesa, ataque urbano, captura e save/load. Classificação: **COMPLETE**.

## Resources / Builder

O Construtor é produzido, tem cargas, exige posse do tile e instala a melhoria adequada em Ferro, Cavalos, Gemas,
Seda e Nódulo Arcano. Benefícios são derivados da melhoria e do dono atual; captura territorial não preserva bônus
para o dono anterior. A IA avalia e usa recursos. Classificação: **COMPLETE**.

## Research

Os **128/128 nós** estão conectados: 55 militares, 55 mágicos e 18 de Infraestrutura. Há um único projeto ativo por
civilização, progresso parcial preservado, overflow conservado, pré-requisitos lineares e capstones por duas linhas
N9. Todos os unlock types têm consumidor de gameplay e save/load mantém o estado. Classificação: **COMPLETE**.

## Military Doctrines

As seis linhas têm identidade e fluxo N1–N9 completo:

- Guardião: frontline, formação e anti-montado;
- Guerreiro: dano corpo a corpo e execução;
- Patrulheiro: dano ranged, alcance e anti-Lendária;
- Cavalaria: mobilidade, carga, retirada e voo Lendário;
- Ladino: penetração, anti-caster/cerco e infiltração;
- Cerco: ataque urbano, preparação e artilharia móvel.

Cada linha entrega prédio, três formas convencionais, duas Técnicas, Maestria e uma Lendária. Classificação:
**COMPLETE**.

## Techniques

As doze Técnicas são alcançáveis, herdadas por linha e consumidas pelo runtime comum. Cobrem ativa/passiva, unidade,
tile e cidade, movimento+ataque, reposicionamento, alcance, área, postura, penetração, supressão de revide e ataque
urbano. Ataque básico permanece disponível quando coerente; Mana nunca é usada. UI, motivos de bloqueio, recarga,
efeito, IA e save/load foram exercitados. Classificação: **COMPLETE**.

## Unit Evolution / Legendary

Upgrades preservam o mesmo objeto, HP proporcional, experiência, serial e cooldowns, exigindo pesquisa, Ouro,
cidade própria e prédio correto. A cidade produz apenas a forma convencional mais avançada desbloqueada. As seis
Lendárias são produções separadas, compartilham um slot global ativo/em produção, liberam o slot ao morrer/cancelar e
podem ser substituídas. Classificação: **COMPLETE**.

## Magic Schools

As seis Escolas entregam prédio, conjurador sem ataque básico, quatro feitiços, estrutura ritual e Manifestação. As
identidades são preservadas: Sagrada sustenta; Infernal causa dano; Necromancia comanda Hostes; Druidismo altera
terreno; Arcanismo reposiciona/interrompe; Elementalismo cria condições ambientais. Classificação: **COMPLETE**.

## Spells

Os 24 feitiços têm dado, unlock, botão/targeting quando aplicável, Mana, cooldown, validação, efeito, IA e
persistência:

- Sagrada: Luz Restauradora, Égide Sagrada, Onda de Cura, Milagre;
- Infernal: Chama Infernal, Fogo Voraz, Explosão Infernal, Condenação;
- Necromancia: Erguer Mortos, Recompor Ossos, Comando Macabro, Erguer Legião;
- Druidismo: Brotar Bosque, Restaurar Terreno, Erguer Terreno, Despertar a Mata;
- Arcanismo: Passo Arcano, Silêncio, Dissipar, Portal do Véu;
- Elementalismo: Névoa Cerrada, Vendaval, Tempestade Elétrica, Cataclismo Elemental.

Classificação: **COMPLETE**.

## Necromancy / Druidism / Arcanism / Elementalism

Necromancia limita tokens por Hostes/Comando e mantém comportamento autônomo derivado; Druidismo modifica e restaura
tiles físicos; Arcanismo cobre teleporte, silêncio, dissipação e portais persistentes; Elementalismo aplica zonas por
rodada, inclusive interação com fortificações e dano ambiental antes de ritual. Não são skins do mesmo feitiço.
Classificação: **COMPLETE**.

## Manifestations

Serafim, Arquidemônio, Lich Soberano, Avatar da Natureza, Arconte do Véu e Primordial dos Elementos são produções
alcançáveis com custo de PP+Mana, slot por Escola, identidade mecânica, repertório da Escola, UI, IA e persistência.
Até seis Escolas distintas podem coexistir; elas não consomem o slot Lendário. Classificação do conteúdo atual:
**COMPLETE**.

A direção conceitual de dar missões estratégicas e autonomia completa a toda Manifestação não foi implementada; hoje
elas usam controle de unidade e IA tática comuns, com autonomia específica apenas onde a mecânica exige. Como a
implementação canônica posterior fechou e testou o loop atual sem esse subsistema, isso é **DEFERRED POST-1.0, P3**.

## Combat

Movimento terrestre, aéreo e infiltrador; terreno; fog; ataque melee/ranged; revide; flanco; veterania; Técnicas;
feitiços; auras; cidade; fortificação; captura; morte; XP e efeitos ambientais convergem nos runtimes comuns. Ataques
urbanos usam sua fórmula própria e gates de guerra; Cerco e Elementalismo interagem sem criar fortificação paralela.
Captura atualiza dono, produção, recursos, ritual e condições de vitória. Classificação: **COMPLETE**.

## Diplomacy

Jogadores começam em paz; guerra é simétrica; paz considera força/desgaste; tréguas, upkeep de guerra e abandono de
campanha são persistidos. A UI expõe estado e ações. Alianças, comércio internacional e simulação diplomática profunda
não fazem parte do gameplay 1.0 atual: **COMPLETE — POLISH LATER**, P3 para expansão futura.

## AI Functional Coverage

A IA escolhe orientação, pesquisa nas três árvores, constrói economia, sobe cidade, melhora recursos, produz composição,
atualiza unidades, usa Técnicas/feitiços, administra Mana/Suprimentos/Ouro, guerreia, captura e persegue as vitórias.
O `WorldView` limita decisões ao observado, evitando onisciência estratégica. Um ensaio real até T151 confirmou as
três orientações, todas as árvores, cidades múltiplas, evolução militar/mágica, save/load e máximo de 10 tokens
relevantes; nenhum crash ou inatividade global. Classificação: **COMPLETE**.

## World Events / Monsters / Dragon

Eventos possuem criação, duração, resolução, UI e save/load; monstros agem em turno próprio; covis e hostilidade entram
nos mesmos gates de combate. O evento do Dragão cria ameaça observável, resolve morte/estado e persiste corretamente.
Classificação: **COMPLETE**.

## Domination

Vence quando apenas uma civilização permanece, independentemente de quem eliminou rivais anteriores. Eliminação,
último rival, derrota humana e Game Over foram testados no `GameManager`. Não há requisito debug-only. Classificação:
**COMPLETE**.

## Military Supremacy

Exige duas Doutrinas N9, pesquisa de Exército Supremo e conquista/manutenção das cidades desenvolvidas exigidas; rivais
eliminados contam como satisfeitos. O smoke controlado percorreu Cidade I→Fortaleza, combate de Cerco, quebra da
fortificação, captura e Game Over por Supremacia. Classificação: **COMPLETE**.

## Transcendence

Exige duas Escolas N9, duas Manifestações ativas de Escolas distintas, Transcendência, estrutura ritual e Ritual Final
público de quatro rodadas. Uma civilização mantém um ritual; civilizações diferentes podem ritualizar simultaneamente.
Perda do local/estrutura, captura, cancelamento ou queda abaixo de duas Manifestações interrompe; o ritual pode ser
reiniciado e é salvo. O smoke percorreu início, interrupção, reinício e Game Over. Classificação: **COMPLETE**.

## Save / Load

Os 65 testes dedicados passaram com 424 asserts. Eles cobrem opening/mid/late state, jogadores/cidades/unidades,
pesquisa, economia, produção, técnicas, feitiços, Hostes, terreno, zonas, portais, eventos, campanhas, Lendária,
Manifestação, rituais, vitórias e compatibilidade/sanitização de saves antigos. Os smokes de Fases 15, 16 e 23 também
carregam no meio de seus fluxos. Classificação: **COMPLETE**.

## Content Reachability Matrix

“PASS” significa que existe cadeia natural de pesquisa/produção/ação; fixtures apenas aceleraram recursos quando o
tempo real não acrescentaria cobertura.

| Família | Quantidade | Gate principal | Consumidor observável | Status |
|---|---:|---|---|---|
| Doutrinas | 6 | N1→N9 | prédios, unidades, Técnicas, Lendárias | REACHABLE PASS |
| Técnicas | 12 | N4/N6 + unidade da linha | ações/passivas em combate | REACHABLE PASS |
| Candidatos Lendários | 6 | N9 + Maestria + slot global | produção/unidade especial | REACHABLE PASS |
| Escolas | 6 | N1→N9 | prédio, caster, feitiços, ritual, Manifestação | REACHABLE PASS |
| Feitiços | 24 | N4→N7 + caster + Mana | `V2MagicRuntime` e UI de targeting | REACHABLE PASS |
| Manifestações | 6 | N9 + ritual + PP/Mana + slot da Escola | produção, combate/magia, Transcendência | REACHABLE PASS |
| Infraestrutura | 18 | três níveis por seis linhas | economia, Builder, cidade e fortificação | REACHABLE PASS |
| Prédios econômicos | 5 famílias | pesquisa correspondente | rendimentos/upkeep locais | REACHABLE PASS |
| Níveis de cidade | I–IV | Planejamento Urbano + PP/Ouro | slots, HP, território e vitória | REACHABLE PASS |
| Fortificações | I–III | Planejamento Urbano + PP/Ouro | escudo, defesa, ataque urbano | REACHABLE PASS |
| Recursos/melhorias | 5 | pesquisa + Construtor + posse | rendimento territorial | REACHABLE PASS |
| Construtor | 1 | Infraestrutura/produção | instalação com cargas | REACHABLE PASS |
| Colonizador | 1 | disponível desde a capital | fundação de cidade | REACHABLE PASS |
| Exército Supremo | 1 | duas Doutrinas N9 | acesso à Supremacia | REACHABLE PASS |
| Transcendência | 1 | duas Escolas N9 | acesso ao Ritual Final | REACHABLE PASS |

Não foi encontrado research node sem consumidor, item produzido sem uso, unlock dependente de ferramenta debug ou
conteúdo que só exista como metadata. Ideias conceituais não adotadas pelo jogo atual estão listadas separadamente.

## Bugs

| Achado | Evidência | Classificação | Severidade | Ação recomendada |
|---|---|---|---|---|
| `UIShell` sem jogador no primeiro frame da partida nova | Após fundar a capital, painel mostra “Sem produção”, mas lista global fica vazia; rebind imediato revela “Escolher Pesquisa” e “Escolher Produção” | BUG | P2 | Ligar novamente o shell ao `human_player` em `_enter_gameplay`; adicionar regressão de Main real |

Nenhum bug foi corrigido: ele não bloqueia a auditoria e a Etapa A pede diagnóstico antes da rodada de Completion Fix.

## Gameplay Gaps

| Gap | Impacto | Classificação | Severidade | Ação recomendada |
|---|---|---|---|---|
| Produção inicial só oferece Colonizador até T9, enquanto Attention exige escolha | Falsa escolha e pressão por expansão repetida; não bloqueia o turno | GAMEPLAY GAP | P1 | Fazer pequena Completion Fix com uma alternativa estratégica real ou tratar explicitamente a ociosidade antes do F33B |

O gap é **hard-but-valid**, não deadlocked: o jogador pode encerrar o turno, pesquisar, concluir Academia I e seguir
todo o loop. O problema não é o custo 25 nem a duração exata isoladamente; é a ausência de decisão no prompt central.

## Balance Questions

Itens abaixo são **BALANCE QUESTION, P3** e não foram modificados:

- custo, unlock, repetição e eventual limite do Colonizador;
- T9 como tempo da primeira bifurcação de produção;
- custos de pesquisa, PP, Ouro, Mana e upkeep;
- poder relativo de unidades, Técnicas, feitiços, Lendárias e Manifestações;
- velocidade de Cidade II–IV e fortificações;
- tamanho natural dos exércitos (ensaio observado: máximo 10; alvo conceitual 12–20);
- frequência/timing de guerra, Manifestação, capstone e cada vitória;
- capacidade da IA de converter chegada a N9 em vitória dentro da duração desejada.

Essas perguntas pertencem ao F33B somente depois do P1/P2 de completude.

## Intentionally Deferred / Post-1.0

- Missões estratégicas e autonomia total para todas as Manifestações — **DEFERRED POST-1.0, P3**.
- Dificuldades além de “normal” — **DEFERRED POST-1.0, P3**.
- Alianças, comércio internacional e diplomacia profunda — **INTENTIONALLY OUT OF SCOPE, P3**.
- Navegação/colonização naval como eixo estratégico — **DEFERRED POST-1.0, P3**.
- Stealth/fog especial do Ladino, clima além das zonas atuais e ordens multiturmo para perfis especiais —
  **DEFERRED POST-1.0, P3**.
- Arte, animação, VFX e áudio finais para placeholders V2 — **DEFERRED POST-1.0, P3**.

Nenhum desses itens é necessário para consumir o conteúdo existente ou concluir uma partida 1.0.

## Tests

| Evidência | Resultado | O que fecha |
|---|---|---|
| `GameplayCompletionPhase33A.tscn` em janela | PASS, T1→T30, captura 1600×900 | Title/Setup/Loading, fundação, catálogo, Attention e opening |
| `test_v2_research_integration.gd` | 4/4, 43 asserts | slot único, capstones, overflow, save, isolamento |
| `test_v2_phase15_main_flow.gd` | 1/1, 136 asserts | economia, déficit, logística, Builder e recursos |
| `test_v2_phase16_main_flow.gd` | 3/3, 122 asserts | Cidade/Fortaleza, Cerco, captura e Supremacia |
| `test_v2_phase23_main_flow.gd` | 1/1, 71 asserts | Transcendência, interrupção, reinício, save e vitória |
| `test_game_manager.gd` | 43/43, 117 asserts | turnos, eliminação, Dominação e Game Over |
| `test_save_manager.gd` | 65/65, 424 asserts | persistência transversal e saves legados |
| `test_v2_ai_long_run.gd` | 1/1, 10.598 asserts, até T151 | três orientações, economia, expansão, pesquisa, unidades e save/load |
| Suíte GUT completa | 3416/3416, 166 scripts, 370.748 asserts, código 0 | regressão total |

Warnings de orphans/leaks emitidos por fixtures GUT continuam sendo ruído conhecido de teardown; não houve falha de
assert, crash ou erro de gameplay associado. O harness de opening foi mantido como evidência reexecutável da Fase 33A.

## Performance Observations

O smoke real T1→T30 terminou em aproximadamente 8,1 s no ambiente de auditoria. A IA até T151 terminou em cerca de
16 s headless. Não apareceu polling novo, crescimento sem limite, travamento de turno ou degradação que impeça a
auditoria. Os benchmarks especializados existentes permanecem dentro das ordens de grandeza documentadas nas fases
anteriores. Otimização ampla fica fora desta etapa.

## Recommendation

Antes do F33B, resolver o P1 da produção inicial e o P2 de ligação do Attention; repetir o smoke T1→T30 e a suíte
completa. Não alterar números para “resolver” o P1 sem primeiro restaurar uma decisão real e observável.

**READY AFTER SMALL COMPLETION FIX PASS**

---

## Completion Fix Pass Result

**Data:** 28 de setembro de 2026
**Escopo:** Fase 33, Etapa A.2 — correção pequena de completude, sem tuning de balanceamento.

Os dois achados que impediam a passagem direta ao F33B foram resolvidos. O diagnóstico original desta auditoria foi
preservado acima como registro do estado observado na Etapa A; esta seção registra o estado posterior à correção.

### P1 — Opening Production: RESOLVED

O catálogo real de `CityPresenter` agora é também a fonte usada pelo `AttentionService` para contar itens de produção
iniciáveis. A regra não depende do nome localizado "Colonizador": a unidade fundadora é reconhecida pelo dado canônico
`UnitData.can_found_city` obtido pelo `id` do item.

| Estado da cidade ociosa | Attention | Bloqueia Encerrar Turno |
|---|---|---|
| zero itens iniciáveis | WARNING: sem produção disponível | não |
| somente uma unidade fundadora iniciável | WARNING: somente Colonizador disponível | não |
| uma única opção iniciável que não seja fundadora | REQUIRED: escolher produção | sim |
| duas ou mais opções iniciáveis | REQUIRED: escolher produção | sim |

A produção do Colonizador não foi removida, restringida nem modificada. A cidade pode produzi-lo no T1 exatamente como
antes. A mudança é somente semântica: quando ele é a única opção, a interface apresenta a ociosidade como aviso, não
como decisão obrigatória. Assim que Academia I conclui e a Academia passa a ser iniciável no T9, o mesmo serviço volta
automaticamente a emitir `Escolher Produção` como REQUIRED. Pesquisa ociosa permanece REQUIRED e produção concluída
aguardando Mana permanece WARNING, sem alteração.

### P2 — First-frame Attention: RESOLVED

`Main._enter_gameplay()` religa o `UIShell` ao `GameManager.human_player` no primeiro ponto comum em que o jogador real
já existe. O caminho é usado por partida nova, load e retorno ao gameplay; restart também passou a chamar esse mesmo
ponto depois de criar o novo `PlayerData`. `bind_player` continua idempotente, desconecta o jogador anterior e não cria
callbacks duplicados. Não foi adicionado `_process`, timer, espera artificial ou polling.

O teste de ciclo de vida com `Main.tscn` real confirmou, sem fallback manual:

- nova partida: shell ligado ao jogador correto e pesquisa ociosa visível no primeiro estado útil;
- restart: novo `PlayerData`, novo bind e Attention funcional;
- load: objeto restaurado ligado ao shell e Attention funcional;
- menu principal → nova partida: sessão anterior descartada e novo jogador ligado corretamente.

### Opening T1–T30 após a correção

O smoke real foi repetido de Title → Setup → Loading → capital → pesquisa/produção → T30, com `failures=0`:

| Marco | Produção e Attention observados |
|---|---|
| T1, antes das escolhas | somente Colonizador iniciável; WARNING não bloqueante; pesquisa ociosa REQUIRED |
| T1, após escolhas | Colonizador na fila; nenhum alerta de produção; Academia I ativa |
| T8 | Colonizador concluído; cidade ociosa volta ao WARNING não bloqueante |
| T9 | Academia I concluída; Colonizador + Academia iniciáveis; produção volta a REQUIRED automaticamente |
| T30 | Academia e Salão dos Guardiões iniciáveis; Guardião N1/N2 completos e N3 ativo |

Diagnóstico final: `colonizer_completed_turn=8`, `first_alternative_turn=9`, `idle_pp_t30=91`, `failures=0`. O estado da
partida permaneceu `PLAYING` e nenhum tier de pesquisa foi pulado.

### Testes, performance e validação visual

| Evidência | Resultado |
|---|---|
| `test_ui_attention.gd` | 25/25; semântica 0/1/múltiplas opções, turn controller, rebind e ausência de polling |
| `AttentionLifecyclePhase33A2.tscn` | PASS; new/load/restart/main→new, `failures=0` |
| `GameplayCompletionPhase33A.tscn` headless | PASS; T1→T30, `failures=0` |
| `GameplayCompletionPhase33A.tscn` em janela | PASS; quatro capturas em 1600×900 |
| Suíte GUT completa | **3424/3424**, 166 scripts, **370.779 asserts**, código 0, 778,476 s |

O benchmark deliberadamente conservador executou 100 refreshes sobre 10 cidades e levou **1.806.055 µs** no contexto
da suíte completa (aproximadamente 18,1 ms por refresh de dez cidades). O trabalho só ocorre em eventos discretos já
existentes; não há custo por frame. Os 208 orphans e 6 warnings reportados pelo GUT continuam sendo ruído conhecido de
teardown, sem falha de assert ou erro de gameplay.

Capturas verificadas visualmente:

- `user://phase33a2_only_settler.png`: cidade com apenas Colonizador, `1 pendência · 1 aviso` e pesquisa como pendência;
- `user://phase33a2_attention_expanded.png`: aviso explica que continuar o turno ou produzir Colonizador são válidos;
- `user://phase33a2_second_production_option.png`: Academia visível no T9 e `Escolher Produção` novamente obrigatório;
- `user://phase33a_opening_t30.png`: estado final coerente do recorte T1–T30.

### Integridade de gameplay e recomendação

Nenhum custo de PP, Conhecimento, Ouro ou Mana; rendimento; atributo; unlock; regra de IA; condição de vitória; slot de
pesquisa; conteúdo; schema ou versão de save foi alterado. A Etapa A.2 não iniciou o Release Balance Lab e não resolveu
nenhuma das questões P3 reservadas ao F33B.

**READY FOR F33B — RELEASE BALANCE BASELINE.**

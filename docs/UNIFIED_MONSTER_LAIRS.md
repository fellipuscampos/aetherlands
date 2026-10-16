# Covis regionais unificados — 15/10/2026

Revisão de acabamento: [reação a ataques, ocupação de tiles e análise de balanceamento](MONSTER_SYSTEM_REFINEMENT_2026-10-15.md).

O mundo hostil é pressão sobre exploração e fronteiras, dentro de um 4X compacto. Uma expedição bem-sucedida
deve abrir tempo para colonizar, melhorar recursos e voltar à competição entre civilizações. O mundo selvagem
continua vivo, sem obrigar o jogador a limpar o mesmo encontro a cada poucos turnos.

## Regra de jogo

- Toda origem nova das 12 espécies tem estrutura, população por origem e exatamente um líder identificado.
  Espécies solitárias têm o próprio indivíduo como líder; bandos têm um integrante designado. A designação
  não altera HP, ataque, defesa, movimento, habilidades ou recompensas. Chefes de covis antigos preservam seus
  HP, dano, defesa e multiplicadores existentes; a revisão final recupera o movimento natural da espécie
  nos chefes legados integrados ao controlador, para permitir resposta a disparos.
- Líder vivo protege a estrutura, mesmo patrulhando longe da porta ou subterrâneo. Morto o líder, cessam os
  reforços; a estrutura pode ser destruída com **um ataque válido**, consumindo a ação normal. Não é preciso
  exterminar os companheiros para atacar a estrutura. Criaturas sobreviventes continuam existindo, ancoradas
  na antiga região, sem reposição.
- Destruir a estrutura bloqueia **novos spawns em raio 8 por 20 rodadas globais**. Isso vale também para
  reforços/reocupações de covis vizinhos. Não é uma barreira mágica contra monstros já vivos que se aproximem.
- Um covil sem líder, deixado de pé, só pode receber um novo líder após **12 rodadas** (na próxima oportunidade
  da cadência global), fora de visão/presença de todas as civilizações. Há **3 rodadas de preparação** antes da
  atividade normal; nesse período a população só defende os arredores. Não existe promoção automática de
  sobrevivente nem cura dos companheiros.
- A ecologia pode voltar a ocupar terra selvagem após a trégua. Continua proibido nascer em território,
  cidade, construção, portal, recurso, unidade ou visão atual de civilização. Se não existe local legal,
  espera: não força spawn injusto para cumprir uma cota. Território consolidado permanece uma conquista 4X.

## Distribuição e orçamento

Mantidos os habitats, distribuição inicial das três categorias, distâncias 7/10/14 das âncoras das capitais,
espaçamento 4/6/8, cotas por área e preferências por era. A era muda atividade e pesos, não atributos nem unlocks.
As criaturas nascem em vizinhos legais: a porta é reservada exclusivamente para a estrutura.

O ponto regional da primeira capital continua a 7–10 hexágonos, com 8–12 rodadas de preparo. Ele é um covil
do registro único e consome o orçamento básico; uma capital ainda não fundada tem uma vaga reservada.
Na fundação tardia, o planner pode aproveitar um covil ecológico compatível, sem duplicar população.
Todos os integrantes novos, inclusive o líder da abertura, respeitam a distância de segurança da capital.

Guardiões de recursos continuam sendo oportunidades únicas da Ascensão, com população fixa e sem reposição
do guardião derrotado. Entram no registro e contagem intermediária comuns. A entrada desse encontro especial
pode ultrapassar temporariamente o alvo intermediário de colocação; enquanto isso, nenhuma nova origem
intermediária selvagem é criada. Não há despawn de criaturas existentes para abrir espaço artificialmente.
O Dragão continua um evento mundial, fora da população regional.

Perfis opcionais com continentes especiais preservam seus encontros existentes. As 12 espécies também
entram no controlador único nesses perfis; o retorno de um voador a um covil legado em lava continua
possível. A população nova por habitat continua sendo planejada para o continente principal.

Reforços de um covil ativo chegam **um de cada vez, a cada 6 rodadas**, até o tamanho natural do grupo,
contando patrulheiros onde estiverem e vermes subterrâneos. Espécies solitárias não multiplicam indivíduos.
A Horda Crescente preserva seu teto de habilidade, mas não gera criaturas depois da morte do líder ou da
destruição da origem. Reocupação/novo covil: **no máximo uma origem a cada 2 rodadas**. Todo o controlador
compartilha um teto de **3 nascimentos de reposição por rodada**, incluindo os reforços (nascimentos de
habilidades de combate continuam sob seus próprios limites existentes).

## Arquitetura e compatibilidade

`MonsterEcologySystem` é o controlador único. `RegionalThreatSystem/Planner` continuam como políticas de
colocação especial e registros de descoberta/objetivos; não executam uma população paralela quando o
controlador está ativo. Para essas 12 espécies, o loop antigo do `HexGrid` permanece só para fixtures/
compatibilidade com a flag ecológica desligada. Encontros de Dragão dos perfis opcionais preservam o
tratamento próprio. Humano e IA usam `CombatResolver.can_attack_lair/resolve_lair_attack`.

Save v27 persiste a marca de líder na criatura, relógios, trégua, preparação, sobreviventes e RNG. A marca é
necessária porque saves históricos usam serial 0 em todos os neutros. Carregar não promove sobreviventes,
não adianta rodada e não repete recompensa. Reocupação de uma coordenada remove o histórico de destruição
da estrutura antiga, evitando que o próximo load apague a estrutura nova.

Saves v26 e anteriores continuam aceitos. Nenhuma criatura ou estrutura nova nasce durante deserialize.
Na primeira rodada, origens antigas ganham covis próximos, sem adicionar criaturas nem mudar seus atributos.
Covil já existente é adotado. Se não há tile local livre, a materialização espera outra rodada.

## Desempenho e validação

Seguidas as regras de `PERFORMANCE_GUIDE.md`, especialmente §6: nenhum processamento por frame; uma contagem
de neutros por rodada; índices por origem e líder; visão de cada civilização calculada uma vez por rodada
com trabalho de reposição; candidatos e habitat em cache; até 96 amostras por tentativa de nova origem.
Uma rodada sem déficit/baixas/reocupação pendente retorna antes de calcular visão. Nada reconstrói mapa,
névoa, malhas ou modelos ao consultar um covil. Migração usa somente raio local 2 por origem antiga.

Os 12 GLBs publicados em `assets/generated/monster_lairs_runtime/` têm uma malha/material cada, sem animação
ou `_process`. Texturas BC7; compartilham-se malhas/texturas, duplicando-se só a cor do material para a névoa.
Fontes/prévias da entrega artística permanecem ignoradas e fora do runtime.

Teste principal: `test/unit/test_unified_monster_lairs.gd`. Regressões: ecologia Foundation/World,
regional D2, habilidades E2, legibilidade E3, habitats E4, MonsterAI, monstros, saves e UI.
Benchmark CPU do controlador: `tools/perf/MonsterLairBench.tscn`; comparação do fluxo real:
`tools/perf/PerfBench.tscn`.

### Resultados da validação

- **304 testes relevantes passaram**: 233/233 na execução final com 9 arquivos de covis, ecologia,
  habilidades, habitats, MonsterAI e persistência ecológica; outros 71/71 de UI, settings e bônus raciais
  na execução conjunta anterior. A suíte específica tem 14 testes de contrato, incluindo o covil voador
  em lava dos perfis opcionais.
- Duas simulações reais de quatro IAs (seeds 33102 e 33109) até T120, com save/load bem-sucedido em T60,
  sem erros de script. Médias de turno: 94 e 100 ms; p95: 170 e 188 ms. Limite T120 é smoke técnico,
  não conclusão de balanceamento ou duração de uma partida humana.
- Controlador isolado em mundo Grande 128×72, 100 rodadas, 50 covis / 86 criaturas: média **0,85 ms**,
  p95 **0,81 ms**, máximo **8,95 ms** (inclui conquista e criação de origem nova).
- PerfBench, seed 4242, 3 rivais, 12 turnos: média de turno completo **105 → 101 ms**, p95 **159 → 168 ms**;
  setup **719 → 807 ms**, RAM estática headless **239 → 268 MB**. A arte acrescenta memória e custo de
  carregamento; o processamento de turno fica na mesma faixa nessa amostra. Gameplay mudou e havia
  outros processos Godot abertos: não é prova estatística de ganho nem medição de FPS.
- 12/12 GLBs de runtime idênticos por SHA-256 aos modelos V2 aprovados. Uma malha por covil e 24/24
  texturas extraídas em BC7. Conferência visual não-headless em uma execução isolada, com terreno e
  criaturas reais: [prévia dos 12 covis](previews/monster_lairs/preview_unified_in_game.png).
- A execução adicional de `test_save_manager.gd` encontrou **7 expectativas antigas de arte/balanceamento**:
  marcador de mina (2 filhos esperados, modelo atual 1), HP Cidade III (36 esperado, atual 46), Égide
  (custo esperado 6, atual 8, em dois testes), produção do Serafim (fixture injeta 100 PP, custo atual 84),
  Comando Macabro (1,4 esperado, atual 1,5) e Cataclismo (5 esperado, atual 10). Os atributos e esses
  sistemas foram preservados; essas expectativas ficam registradas para a rodada de manutenção da suíte.

Logs e JSONs reproduzíveis: `user://lair_round_bench.json`, `user://lair_before.json`, `user://lair_after.json`
e `user://balance/unified_lairs_20261015/smoke/F33B-00{1,2}.json`. Cenas de revisão descartáveis removidas.

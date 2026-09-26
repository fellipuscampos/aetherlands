# Aetherlands V2 — Implementação

Documento técnico do progresso da implementação da V2. O conceito e a direção de
design ficam em `docs/# Aetherlands V2 — Conceito e Direção de.md`; aqui só o que
foi de fato construído. Documento vivo: cada fase acrescenta sua seção.

---

## Fase 0 — Esqueleto estrutural das três árvores

**Escopo:** somente dados + relações + UI de visualização. **Nenhum gameplay novo.**
A V1 continua sendo o jogo ativo; a V2 nesta fase é um scaffold que coexiste com ela.

### O que existe

| Árvore | Estrutura | Nós |
|---|---|---|
| Doutrinas Militares | 6 linhas × 9 níveis + Exército Supremo | 55 |
| Escolas de Magia | 6 linhas × 9 níveis + Transcendência | 55 |
| Infraestrutura | 6 linhas × 3 níveis (scaffold) | 18 |
| **Total** | | **128** |

A Infraestrutura é deliberadamente menor (alvo final ≈ 12–18 pesquisas). O 6 × 3 é
só organização do scaffold: uma linha pode terminar com 2 níveis se o 3º não gerar
decisão — não manter nós inúteis por simetria.

### Arquitetura

As três árvores são **categorias (`V2ResearchNode.TreeType`) de um único sistema de
pesquisa V2**. Nada no modelo pressupõe três filas, três pools ou três pesquisas
simultâneas: no futuro a civilização terá **um projeto ativo por vez**, pago em
Conhecimento, qualquer que seja a árvore do nó.

- Um tipo de nó próprio (`V2ResearchNode`, `Resource`) e um banco estático
  (`V2ResearchDatabase`, `RefCounted`) com cache montado uma vez — o mesmo padrão de
  `TechData`/`TechDatabase`, mas **sem herdar de `TechData`**.
- A UI (`V2ResearchBoard`) só lê o banco. O estado (bloqueado / disponível /
  pesquisando / concluído) vem de `set_state(completed, active_id)`; nesta fase o
  único produtor é o botão **"Estados de exemplo"**. Ligar ao projeto de pesquisa
  real é assunto de fase futura.

### Localização

| O quê | Onde |
|---|---|
| Nó (campos, `TreeType`) | `scripts/data/V2ResearchNode.gd` |
| Banco, tabelas de linhas/papéis/custos, consultas, regra dos capstones, estados, tooltip | `scripts/data/V2ResearchDatabase.gd` |
| UI das três árvores | `scripts/ui/V2ResearchBoard.gd` |
| Integração no HUD | `scripts/ui/HUD.gd` (`_build_v2_research_panel`, `_on_debug_v2_trees_pressed`), `scenes/ui/HUD.tscn` (botão `DebugV2TreesButton`) |
| Testes | `test/unit/test_v2_research_database.gd`, `test/unit/test_v2_research_board.gd`, e 4 testes de overlay em `test/unit/test_hud.gd` |

**Como abrir:** Configurações → Debug → **"Árvores V2 (scaffold estrutural)"** (só
builds de desenvolvimento, como o resto do painel de Debug). ESC ou `X` fecha; é um
overlay como os demais (só um por vez).

### Campos do nó (`V2ResearchNode`)

```text
id, display_name, description
tree_type        MILITARY_DOCTRINE | MAGIC_SCHOOL | INFRASTRUCTURE
branch           linha (ex.: "guardian") ou "universal"
tier             1..9 (Doutrinas/Escolas), 1..3 (Infraestrutura), 10 (universais)
tier_role        papel estrutural do tier (tabelas abaixo)
cost             BALANCE PLACEHOLDER
prerequisites    Array[String] — tier anterior da mesma linha
unlock_type / unlock_id / is_placeholder   o que DESBLOQUEARÁ (nada é aplicado)
branch_role      identidade da linha ("sustain", "gold", "tank_frontline"...)
is_universal / requirement                  só nos capstones
```

### IDs

Prefixo `v2_`; o **conteúdo** pode mudar entre fases, o **id** preferencialmente não.

```text
v2_doctrine_<linha>_<1..9>        guardian warrior ranger cavalry rogue siege
v2_magic_<linha>_<1..9>           sacred infernal necromancy druidism arcanism elementalism
v2_infrastructure_<linha>_<1..3>  economy logistics industry academy arcane urbanization
v2_supreme_army                   Exército Supremo
v2_transcendence                  Transcendência
```

Nomes visíveis provisórios: `Guardião I … IX`, `Sagrada I … IX`, `Economia I … III` etc.

### `tier_role` (design oficial, NÃO placeholder)

| Nível | Doutrinas | Escolas |
|---|---|---|
| N1 | `doctrine_unlock` | `school_unlock` |
| N2 | `training_structure` | `school_building` |
| N3 | `base_unit` | `caster` |
| N4 | `technique_1` | `basic_spell` |
| N5 | `evolution_1` | `intermediate_spell` |
| N6 | `technique_2` | `advanced_spell` |
| N7 | `elite_form` | `greater_spell` |
| N8 | `mastery_structure` | `ritual_structure` |
| N9 | `legendary_candidate` | `grand_manifestation` |

Capstones: `military_victory_capstone` (Exército Supremo), `magic_victory_capstone`
(Transcendência). Infraestrutura: `infrastructure_level_1..3` (o pedido não fixa
papéis por nível; um por nível da própria linha).

Função de cada linha em `branch_role` — Doutrinas: `tank_frontline`, `melee_damage`,
`ranged_combat`, `mobility_shock`, `sabotage_assassination`, `city_conquest`.
Escolas: `sustain`, `magical_damage`, `undead_summoning`, `terrain_manipulation`,
`mobility_utility`, `environmental_control`. Infraestrutura: `gold`, `supplies`,
`production`, `knowledge`, `mana`, `city_fortification`.

### Custos — **BALANCE PLACEHOLDER**

Nenhum destes números foi balanceado; só representam progressão consistente.

```text
Doutrinas / Escolas   N1..N9 = 10, 20, 30, 50, 80, 120, 180, 270, 400
Infraestrutura        I..III = 20, 60, 150
Capstones             600   ← NÃO especificado no pedido; valor meu, acima do N9
```

### Capstones

`Exército Supremo` e `Transcendência` são nós universais (`branch = "universal"`,
`tier = 10`) com `prerequisites` vazio e a regra em `requirement`:

```text
{type: "complete_branches", tree_type, branch_count: 2, at_tier: 9}
```

`V2ResearchDatabase.capstone_requirement_met(id, completed)` /
`capstone_progress(id, completed)` só **representam** a condição ("duas Doutrinas /
Escolas completas", contando só o N9 e só a própria árvore). Não existe Vitória por
Supremacia nem Ritual Final; o requisito não está ligado às vitórias da V1.

### Separação V1 / V2

- `V2ResearchNode` **não é** um `TechData`: `TechDatabase`, `MagicDatabase` e
  `GameManager._process_research` só conhecem `TechData` e nunca enxergam um nó V2.
- IDs com prefixo `v2_` — teste garante que nenhum id V1 o usa e que `TechDatabase.get_tech`
  / `MagicDatabase.get_tech` devolvem `null` para todo id V2.
- Nenhum nó V2 é salvo (`SaveManager` intocado), entra na IA, nas vitórias ou em
  `PlayerData.researched_*`. Abrir o painel e ligar os "Estados de exemplo" não altera
  o estado de pesquisa V1 (teste cobre `current_research`/`research_progress`).
- Nada V1 foi removido ou alterado (TechDatabase, MagicContent, unidades, prédios,
  economia, vitórias, saves).

### UI

Três abas (Doutrinas · Magia · Infraestrutura), uma linha por Doutrina/Escola/linha de
Infraestrutura com os tiers em ordem e conexões entre eles (verde = anterior
concluído; clara = próximo disponível; apagada = bloqueado). Cabeçalho de colunas com o
papel de cada tier. Capstone em "NÓ UNIVERSAL" separado, com progresso (`n/2`).
Tooltip por nó: nome, linha · nível, papel, custo, requisito e descrição placeholder.
Reaproveita a paleta local de `TechTierBoard` e `UITheme.panel_style`; o tooltip usa
um tema **local** ao tabuleiro (fundo opaco) — o tema global não foi tocado.

### Testes estruturais

Sem teste de gameplay. `test_v2_research_database.gd` (26 testes) cobre: 6 linhas × 9
nós, 54 normais + capstone = 55 (Doutrinas e Magia); 6 × 3 = 18 (Infraestrutura); 128
no total; `tier_role`, custos, `branch_role`, ids e prefixos; ids únicos; sem colisão V1/V2;
cadeia linear de pré-requisitos; regra dos capstones; estados; consultas independentes;
tooltip. `test_v2_research_board.gd` cobre contagem de cards por aba, ordem dos tiers,
tooltip, estados de exemplo, ausência de `_process` e de reconstrução desnecessária,
construção só quando visível.

### Performance

- Sem `_process`/polling. O tabuleiro só é construído **com o painel visível**: 0 cards
  montados no `_ready` do HUD; abrir custa ~38 ms uma vez (primeira vez, inclui fontes),
  trocar de aba 13–34 ms; reabrir/reselecionar sem mudança não reconstrói.
- Banco: 128 nós montados em ~1,9 ms (uma vez por sessão); consulta ≈ 2 µs.
- As otimizações da rodada de lag (minimapa, fog, `compute_path`) não foram tocadas.

### Validação visual

Não-headless, 1920×1017: três abas acessíveis, seis linhas em cada, tiers em ordem,
conexões corretas, sem sobreposição, nós universais visíveis, hover real mostrando o
tooltip. Um defeito achado e corrigido na validação: nomes longos ("Elementalismo VIII")
quebravam linha e o tooltip padrão ficava ilegível sobre os cards.

### Ainda **não** existe (Fase 0 termina aqui)

Guardião/Guerreiro/Patrulheiro/Cavalaria/Ladino/Cerco funcionais, magos e feitiços V2,
Manifestações, infraestrutura econômica real, Suprimentos, upkeep V2, upgrades de tropas,
técnicas, Unidade Lendária, cidade V2 / níveis urbanos / remoção de população, Construtor,
recursos V2, bônus raciais, IA V2, vitórias V2, conexão ao fluxo real de pesquisa,
persistência em save. `unlock_type`/`unlock_id` são só metadata do que cada nó
desbloqueará.

### Limitações conhecidas

- Os estados exibidos vêm de dados de exemplo, não do jogo.
- Custos e nomes são provisórios; os nomes visíveis são "Linha + numeral romano".
- Uma única pesquisa ativa é só representada (`active_id`); nada impede/aplica isso ainda.
- Sem teste automatizado de aparência: a checagem visual foi manual, uma vez.

---

## Fase 1 — Runtime unificado de pesquisa

**Escopo:** transformar o scaffold em um sistema real e reutilizável de pesquisa —
seleção, progresso, conclusão, troca de projeto, pré-requisitos, capstones, estado
por civilização, save/load e UI ligada ao estado real. **Nenhum efeito de gameplay:**
concluir um nó só o registra; `unlock_type`/`unlock_id` continuam metadata.

### Condição transitória V1 / V2 (documentada de propósito)

A V1 segue sendo o jogo. O runtime V2 corre **em paralelo**, sem ponte: a pesquisa V1
(`PlayerData.current_research`, `GameManager._process_research`) continua processando a
sua, e nada V1 lê o estado V2 nem o contrário. É uma exceção temporária de
desenvolvimento — no design final só existirá o sistema V2. Testes garantem que o V2 nunca
escreve nos campos V1 (nem em `researched_techs`/`researched_magic`) e que o load não os mistura.

### Arquivos

| O quê | Onde |
|---|---|
| Estado por civilização + API + sinais + (de)serialização | `scripts/core/V2ResearchState.gd` (novo) |
| Banco: estado `PARTIAL`, `state_label`, `unavailable_reason`, `capstone_unit_word` | `scripts/data/V2ResearchDatabase.gd` |
| Dono do estado | `scripts/core/PlayerData.gd` (`v2_research`) |
| Persistência | `scripts/autoload/SaveManager.gd` (bloco `v2_research`) |
| UI ligada ao estado real | `scripts/ui/V2ResearchBoard.gd` (reescrita), `scripts/ui/HUD.gd` (liga ao estado humano) |
| Testes | `test_v2_research_state.gd` (53), `test_v2_research_integration.gd` (4), `test_v2_research_board.gd` (33), `test_v2_research_database.gd` (26), mais 4 em `test_save_manager.gd` e 4 em `test_hud.gd` |

### Separação banco × estado

`V2ResearchDatabase` = **o que existe** (estático, compartilhado, sem estado).
`V2ResearchState` = **o que uma civilização pesquisou**: um `RefCounted` puro (sem HUD,
sem `GameManager`, testável sem cena):

```text
active_id          o ÚNICO projeto ativo ("" = nenhum)
completed_ids      id -> true
progress_by_id     id -> float (só nós não concluídos com progresso > 0; inclui o ativo)
research_overflow  Conhecimento guardado (invariante: só existe SEM projeto ativo)
```

### API (a UI nunca mexe nos dicionários)

```text
can_research(id) / is_available(id)     nó existe, não concluído, pré-requisitos e capstone ok
unavailable_reason(id) -> String        "" ou "Requer Guardião V." / "Já concluída." / ...
select_research(id) -> bool             falha SEM alterar nada se inválido
cancel_active_research()                pausa; progresso mantido; ficar sem projeto é válido
add_knowledge(amount)                   única entrada de Conhecimento
complete_research(id) -> bool           só se disponível (nunca pula tier); conclui na hora
get_progress(id) / get_progress_ratio(id) / is_completed(id) / get_completed_ids()
node_state(id) / status_text(id)        LOCKED AVAILABLE RESEARCHING PARTIAL COMPLETED
reset()                                 (dev/testes)
debug_complete_branch(tree, branch) / debug_complete_active()   (dev/testes)
to_dict() / load_dict(data) / from_variant(data)
```

### Regras

- **Slot único.** Doutrina, Magia e Infraestrutura competem pelo mesmo `active_id`.
  Trocar de projeto (inclusive entre árvores) **não perde progresso**: cada nó guarda o
  seu; voltar continua de onde parou. Selecionar o já ativo é no-op.
- **Disponibilidade.** N1 de toda linha começa disponível; N2+ exigem o anterior da linha.
  **Capstones** usam o `requirement` da Fase 0 (`V2ResearchDatabase.capstone_requirement_met`,
  única implementação): N9 concluído em **duas linhas distintas** da própria árvore — nove nós
  quaisquer ou N8s não bastam. O capstone ainda paga o próprio custo; nada de vitória.
- **Conhecimento** (`add_knowledge`): valores ≤ 0, NaN ou INF são ignorados. Com projeto ativo
  soma nele; **sem projeto vai para `research_overflow`** (nunca é descartado). Não há economia
  de Conhecimento ainda: Academias e qualquer sistema futuro entram por esta função.
- **Overflow.** Ao concluir, o excedente vai para `research_overflow` e **nenhum projeto novo é
  escolhido sozinho** (ex.: custo 10, tinha 8, recebeu 5 → conclui, sobram 3). Ao selecionar um
  projeto o overflow é aplicado na hora (pode concluí-lo, deixando o resto). Um teste de
  conservação garante que tudo que entra fica em progresso, concluídos ou overflow.
- **Conclusão.** Marca concluído, apaga o progresso guardado, limpa o ativo se era ele e só então
  emite os sinais (quem escuta vê o estado final).

### Sinais (sem polling)

```text
research_selected(id, previous_id)      research_cancelled(id)
research_progress_changed(id, progress, cost)    (não é emitido ao concluir)
research_completed(id)                  <- ponto de integração dos unlocks futuros
research_availability_changed(newly_available)   (após research_completed; pode ser vazio)
research_overflow_changed(amount)       state_reset
```

Nenhum listener de gameplay existe. As fases seguintes aplicam unidades/prédios/feitiços
conectando-se a `player.v2_research.research_completed`; o `unlock_type`/`unlock_id` do nó
concluído vem de `V2ResearchDatabase.get_node(id)`.

### Estado por civilização

Cada `PlayerData` tem o seu `v2_research` (humano e rivais). Acesso:
`V2ResearchState.for_player(player)` ou `V2ResearchState.for_index(i)` (índice de
`GameManager.players`). A IA de uma fase futura usa exatamente a mesma API; nada do estado
vive no HUD. **A IA ainda não pesquisa V2.**

### Save / load

Bloco opcional `"v2_research"` dentro do dict de **cada** civilização
(`active_id`, `completed_ids`, `progress_by_id`, `research_overflow`).

- **Sem bump de `SAVE_VERSION` (21).** É um campo opcional: save antigo sem o bloco carrega com
  estado V2 vazio, e o `SaveManager` nunca rejeita o save por causa dele (`_valid_save_header` não
  o valida, de propósito). Nenhuma reescrita do SaveManager: duas linhas (serializar e `load_dict`).
- `load_dict` **atualiza o estado no lugar** (quem escuta sinais continua conectado; emite um único
  `state_reset`) e **nunca falha**: ids inexistentes e tipos errados são ignorados; progresso é
  limitado a `[0, custo]` (negativo/zero descartado); Conhecimento guardado inválido vira 0;
  `active_id` só vale se existir, não estiver concluído e estiver disponível (o progresso dele é
  mantido); concluído nunca fica ativo nem guarda progresso; ativo com Conhecimento guardado o
  aplica (invariante do overflow); ativo já no custo é concluído. Os pré-requisitos dos concluídos
  **não são "consertados"** — não destruir progresso por causa de uma mudança futura de estrutura.

### UI (`V2ResearchBoard`)

Substituiu os "Estados de exemplo". Reflete o estado real da civilização humana; o HUD religa o
tabuleiro ao `human_player.v2_research` **a cada abertura** (partida nova/carregada troca o objeto).

- Estados: **Bloqueado / Disponível / Pesquisando / Parcial** (progresso guardado, não ativo; barra
  e `n / custo` no card) **/ Concluído**. O tooltip mostra o progresso; capstones mostram
  `Doutrinas|Escolas completas: n / 2 (N9)`.
- **Clique** no card seleciona (borda clara) e o rodapé mostra identidade, custo, estado, progresso
  e, se bloqueado, o motivo, com o botão `Pesquisar` / `Continuar pesquisa` / `Pausar pesquisa` /
  `Concluído` (inerte) / `Bloqueado` (inerte). Trocar de projeto não pede confirmação. A barra de
  status mostra o projeto ativo e o Conhecimento guardado.
- **Ferramentas de debug** (`+10` e `+100` Conhecimento, completar pesquisa ativa, completar a linha
  do nó selecionado, resetar SÓ o estado V2): só existem com `OS.is_debug_build()`
  (`debug_tools_enabled`) — em build normal a barra **nem é criada** (teste cobre). O painel
  inteiro continua atrás de Configurações → Debug → "Árvores V2 (pesquisa)".
- Não afeta a V1: abrir/usar o painel não toca `current_research` nem `researched_*`.

### Performance

Sem `_process`/polling. Montagem só com o painel visível (0 cards com o HUD fechado).
Progresso/seleção/pausa **trocam só os cards afetados** no lugar (os outros 54 não são tocados);
conclusão/reset/load reconstroem a aba **uma vez por frame** (coalescido: completar uma linha
inteira = 1 rebuild; medido 430–480 ms → ~85 ms, contando 5 frames de espera do script);
reabrir ou reselecionar a aba sem mudança não reconstrói. O banco continua montando os 128 nós em ~2 ms.

### Validação visual (não-headless, 1920×1017, jogo real, cliques de mouse reais)

Abrir o painel pelo Debug; clicar num card; `Pesquisar`; `+10 Conhecimento` até concluir; Guardião II
parcial; trocar para a aba Magia e pesquisar Sagrada I (Guardião II vira Parcial com progresso
guardado); nó bloqueado explicando o motivo; duas Doutrinas completas (debug) → Exército Supremo
`2 / 2` pesquisável; **salvar pelo `SaveManager`, resetar, carregar pelo caminho real do jogo,
reabrir o painel**: estado idêntico e religado ao novo jogador. Defeitos achados na validação e
corrigidos: o card do capstone ficava cortado (layout e rodapé compactados) e "Completar linha"
reconstruía a aba 9 vezes (coalescido).

### Limitações e o que continua fora de escopo

- Sem economia de Conhecimento (Academia/Infraestrutura funcional), sem IA pesquisando V2, sem
  unlocks (unidades, prédios, técnicas, feitiços, Lendária, Manifestações), sem vitórias V2, sem
  migração V1 → V2, sem bônus raciais.
- Custos e nomes continuam placeholders: a Fase 1 valida o **motor**, não o conteúdo.
- Só o jogador humano manipula o estado pela UI; o dos rivais existe e é salvo, mas ninguém o usa.
- O painel só é alcançável em build de desenvolvimento (via Debug).
- A checagem visual foi manual; não há teste automatizado de aparência.

---

## Fase 2 — Conteúdo canônico das Doutrinas Militares

**Escopo:** trocar o placeholder estrutural (`Guardião III`, `Cerco IX`…) pelo conteúdo e
pela metadata definitivos **só da árvore de Doutrinas Militares** (54 nós normais + o
Exército Supremo). **Mecanicamente inerte:** nada foi adicionado ao `UnitDatabase`, à produção,
ao combate, às habilidades, ao voo, à IA, ao upkeep ou ao slot Lendário. Magia e Infraestrutura
seguem exatamente como estavam (placeholders). O runtime da Fase 1 (`V2ResearchState`), o
schema de save e os **IDs de pesquisa não mudaram**.

### O que mudou (e onde)

| O quê | Onde |
|---|---|
| Conteúdo canônico: 54 entradas (nome, descrição, `unlock_id`, função pretendida) + capstone | `scripts/data/V2DoctrineContent.gd` (novo, só dados — mesmo espírito do `MagicContent` da V1) |
| Aplicação sobre os nós, evolução derivada, índice por `unlock_id`, consultas, tooltip | `scripts/data/V2ResearchDatabase.gd` |
| Campos novos do nó | `scripts/data/V2ResearchNode.gd`: `intent`, `upgrade_from`, `upgrade_to`, `gameplay_connected` |
| Card mais largo (168 px, fonte 12) e rótulo de linha canônico no rodapé | `scripts/ui/V2ResearchBoard.gd` |
| Testes | `test_v2_doctrine_content.gd` (novo, 29); ajustes em `test_v2_research_database.gd`, `_state.gd`, `_board.gd` |

O `V2ResearchDatabase` aplica o conteúdo depois de montar o nó estrutural, **sem tocar** `id`,
`tier`, `tier_role`, `cost` nem `prerequisites`. O `unlock_type` continua saindo do papel
(`TIER_ROLE_UNLOCK_TYPES`, fonte única).

### Vocabulário de `unlock_type` (Doutrinas)

| Tier | Papel (`tier_role`, inalterado) | `unlock_type` |
|---|---|---|
| N1 | `doctrine_unlock` | `doctrine` |
| N2 | `training_structure` | `building` |
| N3 | `base_unit` | `unit` |
| N4 / N6 | `technique_1` / `technique_2` | `technique` |
| N5 / N7 | `evolution_1` / `elite_form` | `unit_upgrade` |
| N8 | `mastery_structure` | `mastery_building` |
| N9 | `legendary_candidate` | `legendary_candidate` |
| Exército Supremo | `military_victory_capstone` | `victory_capstone` |

Mudou em relação às Fases 0–1 (só Doutrinas, os papéis de Magia/Infraestrutura não foram tocados):
`unit_evolution` → `unit_upgrade`, `unit` (Elite) → `unit_upgrade`, `building` (N8) →
`mastery_building`, `legendary_unit` → `legendary_candidate`.

### Conteúdo canônico (N1–N9) e `unlock_id`

Todos os `unlock_id` são IDs **V2** de objetos que **ainda não existem**; nenhum coincide com um ID V1
nem com um ID de pesquisa (testes cobrem, inclusive contra `UnitDatabase`/`BuildingDatabase`/
`TechDatabase`/`MagicDatabase`).

**Guardião** — tank / frontline / proteção

| N | Nome | Tipo | `unlock_id` |
|---|---|---|---|
| 1 | Doutrina do Guardião | doctrine | `v2_doctrine_guardian` |
| 2 | Salão dos Guardiões | building | `v2_building_guardian_hall` |
| 3 | Escudeiro | unit | `v2_unit_shieldbearer` |
| 4 | Muralha de Escudos | technique | `v2_technique_shield_wall` |
| 5 | Guardião | unit_upgrade | `v2_unit_guardian` |
| 6 | Preparar Lanças | technique | `v2_technique_brace_spears` |
| 7 | Sentinela | unit_upgrade | `v2_unit_sentinel` |
| 8 | Bastião de Maestria | mastery_building | `v2_building_guardian_mastery` |
| 9 | Campeão Guardião | legendary_candidate | `v2_legendary_guardian_champion` |

**Guerreiro** — dano físico corpo a corpo

| N | Nome | `unlock_id` |
|---|---|---|
| 1 | Doutrina do Guerreiro | `v2_doctrine_warrior` |
| 2 | Salão de Armas | `v2_building_warrior_hall` |
| 3 | Guerreiro | `v2_unit_warrior` |
| 4 | Golpe Poderoso | `v2_technique_power_strike` |
| 5 | Espadachim | `v2_unit_swordsman` |
| 6 | Ataque em Arco | `v2_technique_cleave` |
| 7 | Mestre de Armas | `v2_unit_weapon_master` |
| 8 | Arena dos Campeões | `v2_building_warrior_mastery` |
| 9 | Herói da Lâmina | `v2_legendary_blade_hero` |

**Patrulheiro** — dano ranged constante

| N | Nome | `unlock_id` |
|---|---|---|
| 1 | Doutrina do Patrulheiro | `v2_doctrine_ranger` |
| 2 | Campo dos Patrulheiros | `v2_building_ranger_camp` |
| 3 | Arqueiro | `v2_unit_archer` |
| 4 | Disparo Preciso | `v2_technique_precise_shot` |
| 5 | Caçador | `v2_unit_hunter` |
| 6 | Saraivada | `v2_technique_volley` |
| 7 | Atirador de Elite | `v2_unit_elite_marksman` |
| 8 | Torre dos Patrulheiros | `v2_building_ranger_mastery` |
| 9 | Caçador de Lendas | `v2_legendary_legend_hunter` |

**Cavalaria** — mobilidade / flanco / choque

| N | Nome | `unlock_id` |
|---|---|---|
| 1 | Doutrina da Cavalaria | `v2_doctrine_cavalry` |
| 2 | Estábulo de Guerra | `v2_building_war_stable` |
| 3 | Cavaleiro | `v2_unit_cavalier` |
| 4 | Carga | `v2_technique_charge` |
| 5 | Cavaleiro de Choque | `v2_unit_shock_cavalier` |
| 6 | Retirada Tática | `v2_technique_tactical_retreat` |
| 7 | Cavaleiro Blindado | `v2_unit_armored_cavalier` |
| 8 | Ordem da Cavalaria | `v2_building_cavalry_mastery` |
| 9 | Cavaleiro de Grifo | `v2_legendary_griffon_rider` |

**Ladino** — sabotagem / assassinato / alvos prioritários

| N | Nome | `unlock_id` |
|---|---|---|
| 1 | Doutrina do Ladino | `v2_doctrine_rogue` |
| 2 | Guilda dos Ladinos | `v2_building_rogue_guild` |
| 3 | Ladino | `v2_unit_rogue` |
| 4 | Ataque Furtivo | `v2_technique_sneak_attack` |
| 5 | Sabotador | `v2_unit_saboteur` |
| 6 | Desmantelar | `v2_technique_dismantle` |
| 7 | Assassino | `v2_unit_assassin` |
| 8 | Refúgio das Sombras | `v2_building_rogue_mastery` |
| 9 | Mestre das Sombras | `v2_legendary_shadow_master` |

**Cerco** — destruição de cidades e fortificações

| N | Nome | `unlock_id` |
|---|---|---|
| 1 | Doutrina de Cerco | `v2_doctrine_siege` |
| 2 | Arsenal de Cerco | `v2_building_siege_arsenal` |
| 3 | Catapulta | `v2_unit_catapult` |
| 4 | Munição Demolidora | `v2_technique_demolition_ammo` |
| 5 | Trebuchet | `v2_unit_trebuchet` |
| 6 | Bombardeio Preparado | `v2_technique_prepared_bombardment` |
| 7 | Bombarda | `v2_unit_bombard` |
| 8 | Grande Arsenal | `v2_building_grand_arsenal` |
| 9 | Colosso de Cerco | `v2_legendary_siege_colossus` |

**Exército Supremo** (`v2_supreme_army`, universal): `unlock_type = victory_capstone`,
`unlock_id = v2_military_supremacy_access`. Regra inalterada (duas Doutrinas completas em N9).
**Não é uma unidade**: é o capstone estratégico; as Unidades Lendárias vêm dos N9.

### Linhas de evolução (só metadata)

Três formas convencionais por Doutrina, nos tiers 3 → 5 → 7, derivadas pelo banco (sem repetir dado):
`upgrade_from`/`upgrade_to` guardam **`unlock_id`s** (não ids de pesquisa) e existem só nesses
18 nós. Consultas: `V2ResearchDatabase.unit_line(branch)`.

```text
Guardião    Escudeiro  -> Guardião             -> Sentinela
Guerreiro   Guerreiro  -> Espadachim           -> Mestre de Armas
Patrulheiro Arqueiro   -> Caçador              -> Atirador de Elite
Cavalaria   Cavaleiro  -> Cavaleiro de Choque  -> Cavaleiro Blindado
Ladino      Ladino     -> Sabotador            -> Assassino
Cerco       Catapulta  -> Trebuchet            -> Bombarda
```

Nenhum upgrade real existe. A tooltip mostra a linha (`[Escudeiro] → Guardião → Sentinela`).

### Técnicas (12) e candidatos a Lendário (6)

Exatamente duas técnicas por Doutrina, sempre em N4 e N6 (`V2ResearchDatabase.techniques_for_branch`):
Muralha de Escudos + Preparar Lanças · Golpe Poderoso + Ataque em Arco · Disparo Preciso + Saraivada ·
Carga + Retirada Tática · Ataque Furtivo + Desmantelar · Munição Demolidora + Bombardeio Preparado.
Cada uma registra nome, descrição, função pretendida (`intent`) e ID — **sem cooldown nem número**.

Os seis N9 são `legendary_candidate` (`V2ResearchDatabase.legendary_candidates()`). A regra futura
**"uma Unidade Lendária ativa por civilização"** fica registrada em `MAX_ACTIVE_LEGENDARY_UNITS = 1`
e na descrição de cada N9; **nenhum slot Lendário existe**.

### Decisões

- **`is_placeholder` × `gameplay_connected`.** As Doutrinas passam a `is_placeholder = false`
  (conteúdo canônico) mas `gameplay_connected` continua `false` em **todos** os 128 nós: concluir
  uma pesquisa V2 não altera nada no jogo (teste conclui os 55 nós e compara o estado V1).
- **Descrições curtas, sem números.** Um teste barra qualquer dígito (exceto referências de nível
  `N9`) em descrição e função pretendida. Nenhum HP/ataque/defesa/movimento/alcance/cooldown/
  multiplicador/custo de produção/upkeep foi definido — o `V2ResearchNode` nem tem esses campos
  (teste cobre). Os custos de pesquisa seguem `10…400` + capstone `600` (**BALANCE PLACEHOLDER**).
- **Tooltip** (desenvolvimento): nome, `Doutrina … · Nível n`, papel, custo provisório, pré-requisito,
  linha de evolução (nas unidades), `Desbloqueio futuro: <tipo> (<unlock_id>)`, descrição (quebrada em
  linhas de ≤ 64 caracteres) e `Gameplay V2 ainda não conectado.`; o tabuleiro acrescenta estado/progresso.
- **Cabeçalho e cards:** o cabeçalho mostra `N3 / Unidade-base` e o card `Escudeiro`, como pedido.

### Nomes que precisaram mudar / observações técnicas

- **"Doutrina do Cerco" → "Doutrina de Cerco"**: o título interno da linha (usado nas descrições
  do scaffold) foi alinhado ao nome canônico do N1. Só afeta texto.
- **Ambiguidade de nome (mantida):** o N5 da Doutrina do Guardião se chama **"Guardião"**, igual à
  linha. Isso vale nas mensagens de bloqueio ("Requer Guardião." no N6). É o nome pedido; se virar
  confuso na UI, o ajuste é um texto em `V2DoctrineContent`.
- Nenhum ID de pesquisa, `tier_role`, custo ou pré-requisito foi alterado; os `unlock_id` do N1
  (`v2_doctrine_<linha>`) não têm sufixo numérico, então **não colidem** com `v2_doctrine_<linha>_<n>`.

### Runtime, save e performance

- **Save da Fase 1 continua carregando:** os ids de pesquisa são os mesmos; um teste carrega um bloco
  `v2_research` exatamente como a Fase 1 salvava e continua a pesquisa do "Escudeiro" de onde parou.
- **Performance:** só dado/texto. Nenhum `_process`/polling/rebuild novo (o painel segue montando só
  visível, 1 rebuild ao abrir: 78 ms na medição desta fase, ~ igual à Fase 1). O card ficou 20 px mais largo.

### Validação visual (não-headless, 1920×1017, jogo real)

Percorridas as seis linhas na aba Doutrinas: **nenhum dos 54 nomes quebra linha** (medido: 0 rótulos
com mais de uma linha), altura dos cards estável, seis linhas distintas por cor de identidade,
progressão N1→N9 legível, Exército Supremo separado. Estados continuam corretos (Escudeiro pesquisando
`12.5 / 30`, Doutrina do Guerreiro parcial `4 / 10`, Cavalaria concluída, capstone `1 / 2`). Tooltips
com hover real (Escudeiro, Cavaleiro de Grifo, Colosso de Cerco, Exército Supremo) legíveis, opacos e
sem estourar a tela; clique real em "Campeão Guardião" mostra rodapé com nome canônico e o motivo
do bloqueio ("Requer Bastião de Maestria.").

### O que continua não funcional (de propósito)

Nenhuma unidade, prédio, técnica, evolução, Lendária, slot Lendário, voo, anti-cavalaria, sabotagem,
AoE, produção, upkeep ou IA existe. Magia e Infraestrutura continuam placeholders. Os `unlock_id`
são só endereços estáveis para as próximas fases.

---

## Fase 3 — Primeiro unlock real: Guardião N1–N3

Primeira vez que a pesquisa V2 muda o jogo. **Só** a Doutrina do Guardião N1→N2→N3:

```
Doutrina do Guardião (N1)  →  Salão dos Guardiões (N2, prédio real)  →  Escudeiro (N3, unidade real)
```

N4–N9 do Guardião, as outras cinco Doutrinas, Magia e Infraestrutura seguem **só metadata**
(`gameplay_connected = false`). O objetivo da fase é provar o *caminho* (pesquisa → unlock → construção →
treino → unidade viva → save/load), não entregar conteúdo: tudo o que foi reaproveitado da V1 está marcado
como provisório.

### Arquitetura

```
V2ResearchState.research_completed(id)          ← concluir um nó (Conhecimento, debug ou API)
        │
        ▼
V2UnlockSystem  (1 por PlayerData: player.v2_unlocks)
  · lê unlock_type / unlock_id / gameplay_connected DO PRÓPRIO NÓ (nunca "if id == guardian_2")
  · emite unlock_applied(node_id, unlock_type, unlock_id) UMA vez por nó
        │
        ▼
PlayerData._on_v2_unlock_applied  → (só jogador humano) EventBus.notify (toast) + EventBus.v2_unlock_applied
        │
        ▼
HUD._on_v2_unlock_applied  → atualiza o painel de cidade aberto (ou espera o painel V2 fechar)
```

**A disponibilidade é DERIVADA, não guardada.** "Esta civilização pode construir o Salão?" é
`player.v2_research.is_completed("v2_doctrine_guardian_2")` (via `V2UnlockSystem.is_unlocked(player, unlock_id)`).
Consequências, todas testadas:

- **Não existe um segundo estado** que possa dessincronizar da pesquisa. Nada novo entra no save
  (`SAVE_VERSION` continua 21): o bloco `"v2_research"` da Fase 1 já restaura tudo.
- **Idempotência por construção:** reaplicar um unlock não muda nada; `unlock_applied` só sai na 1ª vez por nó
  (reset/load limpam esse controle transitório).
- **Save antigo** (sem `v2_research`) carrega com nada liberado.
- **Por civilização:** o unlock de uma civ não vaza pra outra. Cidade conquistada com o Salão não treina
  Escudeiro para quem não pesquisou o N3.
- **Sem `_process`/polling:** tudo reage ao sinal; as consultas são funções puras.

`V2UnlockSystem` é fail-closed para ids V2 (`v2_*` sem jogador ou id desconhecido → bloqueado) e fail-open
para todo o resto (id sem prefixo `v2_` não tem gate V2). O gate é barrado por prefixo, então o gameplay V1
paga só uma comparação de string (0,4 µs medidos).

### Onde o gameplay foi tocado (3 pontos, todos com a checagem `is_v2_id` na frente)

| Ponto | Efeito |
|---|---|
| `City._tech_unlocked_for_building` | prédio V2 é liberado só pela pesquisa V2 (alimenta `can_build`, o botão da HUD e a IA) |
| `City.can_train` | unidade V2 exige a pesquisa V2 **além** do prédio de treino de sempre |
| `PlayerData.has_unlocked` | unidade V2 é liberada pela pesquisa V2 (fail-closed, ao contrário do fail-open V1) |

O Salão treina o Escudeiro pelo mecanismo **já existente** `BuildingData.trains_unit` →
`BuildingDatabase.building_that_trains` → `City.can_train`. Não há fila, botão, contador nem regra de
produção V2: o Salão é um `BuildingData` comum, o Escudeiro um `UnitData` comum.

### Arquivos

Novo: `scripts/core/V2UnlockSystem.gd`.

Alterados (Fase 3): `V2DoctrineContent.gd` (`CONNECTED_UNLOCK_IDS`, descrições N2/N3),
`V2ResearchDatabase.gd` (`gameplay_connected` a partir da lista, `node_tooltip`, `unlock_effect_text`),
`BuildingDatabase.gd` (Salão), `UnitDatabase.gd` (Escudeiro + `PLAYER_TRAINABLE_KINDS`), `City.gd`
(2 gates), `PlayerData.gd` (`v2_unlocks`, `has_unlocked`, aviso ao humano), `EventBus.gd`
(`v2_unlock_applied`), `HUD.gd` (atualização do painel de cidade). Comentários de `V2ResearchBoard.gd`.

Como ligar o próximo unlock (guia curto): criar o objeto real no banco V1 correspondente **com o `unlock_id`
como id**, acrescentar o id a `V2DoctrineContent.CONNECTED_UNLOCK_IDS` e, se for um tipo novo
(`technique`, `unit_upgrade`…), acrescentá-lo a `V2UnlockSystem.CONNECTED_TYPES`.

### Definições

**Salão dos Guardiões** — `v2_building_guardian_hall` (nó `v2_doctrine_guardian_2`)

| Campo | Valor |
|---|---|
| Nome | Salão dos Guardiões (o mesmo do nó) |
| `trains_unit` | `v2_unit_shieldbearer` |
| `requires_building` | vazio — **não depende do Quartel V1** |
| Custo | 22 PP — **BALANCE PLACEHOLDER** (Quartel 20, Campo de Tiro 22) |
| Rendimento / defesa | nenhum |
| Slot | ocupa um slot de prédio como qualquer outro (regra V1 intacta) |
| Modelo | **provisório**: o mesmo `building_barracks_blue.gltf` do Quartel |

**Escudeiro** — `v2_unit_shieldbearer` (nó `v2_doctrine_guardian_3`) — **BALANCE PLACEHOLDER**

| | Escudeiro | Guarda (V1) | Homem de Armas (V1) | Homem de Escudo (V1, N5) |
|---|---|---|---|---|
| Vida | **18** | 12 | 16 | 22 |
| Ataque | **3,0** | 4,0 | 5,5 | 3,0 |
| Defesa | **4,5** | 3,0 | 4,5 | 5,5 |
| Movimento | **2** | 2 | 2 | 1 |
| Visão / alcance | 3 / corpo a corpo | 3 / c.a.c. | 3 / c.a.c. | 3 / c.a.c. |
| Custo | **20 PP** | 15 | 22 | 28 |

Regra que os testes fixam (as *relações*, não os valores): mais vida e defesa que o Guarda, ataque menor que
o Guarda, movimento normal, custo entre Guarda e Homem de Armas, não ofusca o Homem de Armas. **Sem upkeep**
(ouro, mana ou Suprimentos — nada disso existe na V2 ainda), sem habilidade especial, não é tropa racial
(todas as raças podem treinar). `visual_kind == "v2_unit_shieldbearer"` de propósito: é o que o `SaveManager`
grava e usa para recriar a unidade no load. Modelo **provisório**: o mesmo `Knight.glb` do Homem de Armas
(as duas unidades ficam visualmente iguais até existir arte V2).

### Regras de produção (o que o jogador enxerga)

| Situação | Salão (construir) | Escudeiro (treinar) |
|---|---|---|
| Sem pesquisa | escondido | escondido |
| N1 | escondido | escondido |
| N2 | **visível** (mesma linha de prédios, mesmo posicionamento de tile) | escondido |
| N2 + Salão, sem N3 | já construído | escondido |
| N3, sem Salão na cidade | — | escondido |
| N3 + Salão na cidade | — | **visível** (mesma linha de tropas) |
| Quartel V1 | irrelevante (nem exigido, nem suficiente) | irrelevante |

### Tooltips (`V2ResearchDatabase.node_tooltip`)

Nós conectados trocam "Desbloqueio futuro: …" + "Gameplay V2 ainda não conectado." pelo unlock real:

- N1: `Desbloqueia a Doutrina do Guardião.`
- N2: `Desbloqueia Salão dos Guardiões.`
- N3: `Desbloqueia Escudeiro. Requer Salão dos Guardiões para treinamento.` (a estrutura exigida é derivada do
  nó `training_structure` da mesma linha — sem repetir dado)
- N4–N9 (e todo o resto): inalterados, com `Gameplay V2 ainda não conectado.`

As descrições canônicas de N2/N3 deixaram de dizer "Futuramente" (texto em `V2DoctrineContent`).

### IA

A IA rival não pesquisa V2, então nunca desbloqueia nada e nunca considera o Salão/Escudeiro
(`can_build`/`has_unlocked` falsos). O Escudeiro entrou em `PLAYER_TRAINABLE_KINDS`, então **quando** uma fase
futura der pesquisa V2 à IA, ele passa a ser candidato de produção, de composição de exército e de
save/load sem código novo (os mesmos gates). Teste: 8 turnos reais com rivais — nenhum Salão/Escudeiro,
nenhum erro, jogo segue em `PLAYING`.

### Save / load

Nenhuma mudança de formato. O Salão é salvo/restaurado como qualquer prédio (`id` + coordenada →
`hex_grid.place_building`), o Escudeiro como qualquer unidade (`visual_kind` → `UnitDatabase.create_unit`) e o
unlock vem do bloco `v2_research`. Coberto: save entre N2 e o Salão (Salão continua liberado, Escudeiro não),
save completo (pesquisas + Salão + unidade voltam, cidade carregada produz outro Escudeiro) e save antigo.

### Testes (+75; suíte completa **1724 / 1724**, 61 scripts)

| Arquivo | Testes | Cobre |
|---|---|---|
| `test_v2_unlock_system.gd` | 19 | pipeline `research_completed` → `unlock_applied`, disponibilidade derivada, idempotência, por civilização, reset, toast só pro humano, sem polling |
| `test_v2_guardian_hall.gd` | 18 | dados do Salão, gate N2, sem Quartel, slots, cidade cheia, por civilização, Salão só vale na própria cidade |
| `test_v2_shieldbearer.gd` | 21 | dados/relações de stats, gate N3 + Salão, Quartel irrelevante, todas as raças, produção pela fila normal |
| `test_v2_guardian_flow.gd` | 5 | **fluxo principal ponta a ponta** (abaixo), sem V2 vazazando, IA 8 turnos, save antigo, save entre N2 e Salão |
| `test_hud.gd` (+11) | 11 | botões do Salão/Escudeiro, `_on_produce_pressed`, atualização do painel de cidade, espera do painel V2, V1 intocada |
| adaptados | — | testes da Fase 1/2 que afirmavam "nenhum nó conectado / nenhum id V2 existe nos bancos" agora afirmam exatamente N1–N3 |

Fluxo principal (`test_guardian_n1_to_n3_flow_…`, pelos mesmos caminhos do jogo): jogo novo → V2 vazio →
funda cidade → pesquisa N1, N2 → constrói o Salão (posicionamento de prédio + fim de turno) → N3 → põe o
Escudeiro em produção → fim de turno → unidade nasce → move (`SelectionManager`) → ataque básico → salva →
carrega → pesquisas, Salão e unidade conferem → a cidade carregada produz um segundo Escudeiro.
(`GameManager.debug_mode` só acelera a produção da cidade humana para 1 turno, como no jogo.)

### Validação visual (não-headless, 1920×1017, `Main.tscn` real, uma execução)

Cidade fundada pelo caminho normal, N1/N2/N3 pesquisados, Salão construído e Escudeiro treinado com
`debug_mode` (1 turno por item). Confirmado nas capturas:

- toasts "Doutrina desbloqueada: Doutrina do Guardião", "Novo prédio disponível: Salão dos Guardiões",
  "Nova unidade disponível: Escudeiro";
- painel de cidade: `Predios: 1/1 (Salão dos Guardiões)` e o botão `Escudeiro — 20 PP` na aba Unidades,
  ao lado do Colonizador (sem botão V2 nem fila V2);
- Salão visível no mapa; Escudeiro nasceu, selecionado com `HP 18/18 | Ataque 3.0 | Defesa 4.5 | Movimento 2.0/2.0`;
- painel V2: N1–N3 do Guardião "Concluído", N4 "Disponível".

Observações honestas: o botão do **Salão** (aba *Construções*) não aparece nas capturas (o roteiro não trocou
de aba) — foi conferido por sonda (`visible = true`, `Salão dos Guardiões — 22 PP`) e por teste de HUD; o
Escudeiro nasceu **no mesmo tile do Salão** (comportamento V1 de spawn: unidades não evitam tile com prédio),
o que dificulta ver o modelo isolado; e Salão/Escudeiro usam modelos reaproveitados (ver abaixo).

### Performance

Nenhum `_process`, timer ou polling novo. Medido (headless, 200 mil chamadas): checagem `is_v2_id` adicionada
aos caminhos V1 = **0,4 µs**; `can_train("warrior")` 17 µs, `_tech_unlocked_for_building("granary")` 6,7 µs,
`can_train(Escudeiro)` liberado 13,7 µs, `can_build(Salão)` 0,65 µs — o custo V2 é o mesmo de um prédio/tropa V1.
Evento discreto (fim de pesquisa): 1 refresh do painel de cidade, só se houver cidade aberta e só para o humano.
Em jogo real (janela): 50–72 FPS nas capturas, sem regressão observada.

### Limitações (de propósito) e ressalvas

- **Assets provisórios:** Salão = modelo do Quartel; Escudeiro = `Knight.glb` do Homem de Armas. Sem arte V2.
- **Números provisórios** (Salão 22 PP; Escudeiro 18/3,0/4,5/2, 20 PP): não balanceados, não use como referência.
- O nó N1 (Doutrina) só é marco + aviso: não há gameplay de "doutrina ativa" ainda.
- Resetar a pesquisa V2 (ferramenta de debug) não remove um Salão já construído; ele só deixa de poder treinar.
- Salão ocupa slot: numa cidade de população 1 (1 slot) ele disputa o slot com qualquer outro prédio (regra V1).
- Fora do escopo, **não implementado**: N4+ do Guardião (Muralha de Escudos, Guardião, Preparar Lanças,
  Sentinela, Bastião de Maestria, Campeão Guardião), evolução "Evoluir para Guardião", outras Doutrinas, técnicas,
  upgrades, Unidade Lendária, upkeep/Suprimentos, economia V2, Magia/Infraestrutura V2, vitória V2, IA
  estratégica V2, variantes raciais.
- Fase encerrada quando o primeiro fluxo V2 real funciona de ponta a ponta. **Não avança para o N4.**

---

## Fase 4 — Guardião N4–N5: Técnica e primeira evolução

Duas fundações genéricas, exercitadas por dois nós da Doutrina do Guardião:

```
N4 Muralha de Escudos  (v2_technique_shield_wall)   →  Técnicas Militares de Doutrina
N5 Guardião            (v2_unit_guardian)           →  Upgrade físico de unidade + "forma mais avançada" na produção
```

N4 e N5 passam a `gameplay_connected = true` (N1–N5). **N6–N9 seguem só metadata**: Preparar Lanças, Sentinela,
Bastião de Maestria e Campeão Guardião não existem no jogo, e nenhuma outra Doutrina foi conectada. As Fases 0–3
(`V2ResearchState`, `V2UnlockSystem`, Salão, Escudeiro, gates, save) foram **expandidas, não refeitas**.

### Técnicas Militares de Doutrina (framework)

Técnica NÃO é magia: sem Mana, sem conjurador, fora do Grimório, sem Escola. Custa a **ação** da unidade e entra em
**recarga**; o ataque básico continua disponível quando a técnica não está.

| Peça | Papel |
|---|---|
| `V2DoctrineTechniqueData` (`scripts/data`) | Resource com o dado: `id` (= unlock_id), `doctrine_branch`, `duration`, `cooldown_turns`, `consumes_action`, `self_defense_bonus`, `adjacent_ally_defense_bonus`, `adjacent_radius` |
| `V2DoctrineTechniqueDatabase` (`scripts/data`) | Registro com cache (mesmo padrão de `BuildingDatabase`). Só a Muralha. Nome vem do nó de pesquisa; a descrição é montada dos números do dado |
| `V2TechniqueRuntime` (`scripts/core`) | Consultas e eventos: `techniques_for_unit`, `unavailable_reason`, `can_use`, `activate`, `expire_finished`, `defense_multiplier`, linhas de UI |
| `V2UnitLine` (`scripts/core`) | Linha de unidades da Doutrina (base → evolução → Elite) derivada da metadata |

**Nenhum id de técnica ou de unidade está escrito na lógica** (`V2TechniqueRuntime`, `V2UnitLine` e `V2UnitUpgrade`;
um teste varre o código sem os comentários). Entrar no registro é o que faz uma técnica existir; o id também vai para
`V2DoctrineContent.CONNECTED_UNLOCK_IDS` e o tipo (`technique`, `unit_upgrade`) para `V2UnlockSystem.CONNECTED_TYPES`.

**Elegibilidade por linha, não por id.** `V2UnitLine.branch_of(unit_id)` diz a Doutrina de qualquer forma de unidade;
a técnica declara `doctrine_branch = "guardian"`. Escudeiro e Guardião a usam; a **Sentinela (N7) já é reconhecida**
na linha (`unit_ids("guardian") == [shieldbearer, guardian, sentinel]`) sem existir no `UnitDatabase` — quando for
conectada, herda a Muralha sem código novo (teste cobre).

**Estado reaproveitado, sem campo novo e sem `SAVE_VERSION`:** a recarga vive em `unit.magic_cooldowns[id]` e o efeito em
`unit.magic_status[id]` — os dois dicionários que o `SaveManager` já valida e persiste (o nome "magic_" é herança da V1;
as chaves ganham o id da técnica). Como o estado fica na **unidade** e não no tipo dela, evoluir mantém a recarga.

### Muralha de Escudos — números (**BALANCE PLACEHOLDER**)

| | |
|---|---|
| Ativação | manual, unidade da linha, N4 pesquisado, fora de recarga, com ação disponível |
| Custo | zero Mana, zero Ouro; consome a ação e **zera o movimento restante** (e cancela Explorar/"mover até") |
| Efeito próprio | **+35%** Defesa |
| Formação | aliados (mesmo dono) num tile adjacente recebem **+15%** enquanto a unidade estiver de Muralha |
| Duração | até o início do próximo turno do dono |
| Recarga | **3** turnos (usou no turno T, volta no T+3) |

- **Por formação, não buff permanente:** `CombatResolver.predict` chama `V2TechniqueRuntime.defense_multiplier(defender,
  hex_grid)`, que olha a unidade e seus vizinhos **na hora do combate**. O aliado que se afasta perde o bônus sozinho e
  ao voltar recebe de novo; sem `_process`.
- **Sem acúmulo:** por técnica vale só o **maior** bônus aplicável — duas Muralhas adjacentes dão +15% (não +30%); quem
  tem a própria Muralha e vizinha com outra fica com +35% (não +35% × +15%). Muralha inimiga não protege ninguém do
  outro dono. Protetor caído não projeta.
- **Único ponto de combate tocado:** uma multiplicação em `CombatResolver.predict` (a mesma função de `resolve`,
  `resolve_city_attack` e IA). Testes conferem o dano previsto **e** a perda de HP real em `resolve`.
- Convive com o Fortificar V1 (multiplicadores independentes; a Muralha multiplica a Defesa já com o bônus de terreno).

**Duração — como "início do próximo turno do dono" foi modelado.** Nesta base de turnos o mundo (IA, monstros) age
*dentro* da troca de turno, já com `turn_number = T+1`, antes de o dono voltar a jogar. Um efeito com expiração "T+1"
nunca protegeria contra ninguém. Por isso o efeito é gravado com expiração `T+2` (cobre a fase de IA) e
`V2TechniqueRuntime.expire_finished` o encerra em `GameManager._finish_turn` — exatamente quando o dono volta a jogar.
O limite `T+2` é só rede de segurança (se ninguém chamar o hook, expira sozinho). A recarga não é tocada pela expiração.

**"Ação gasta".** Segue a convenção V1 dos feitiços: unidade pode agir enquanto `movement_left > 0` (atacar zera o
movimento). Logo uma unidade que já atacou — ou gastou todo o movimento andando — não ativa a técnica nem evolui naquele turno.

### UI e feedback

- **Painel da unidade** (mesmo padrão do `SpellActions`, container dinâmico `V2Actions`, `HUD.tscn` intocado): um botão por
  técnica que a unidade *pode ter* (linha + nó concluído) — `Muralha de Escudos` / `Muralha de Escudos — Ativa` /
  `Muralha de Escudos (recarga 2)`, desabilitado com o motivo no tooltip (`Em recarga: 2 turno(s).`, `A unidade já agiu
  neste turno.`). Só aparece depois do N4.
- **Feedback de estado:** o painel mostra `Muralha de Escudos — Ativa (até o início do próximo turno)` e
  `Muralha de Escudos — recarga: N turno(s)` (também no inspetor, para qualquer observador na parte "ativa"); no mapa,
  um **anel ciano** na base da unidade (`Unit.refresh_technique_marker`, sem asset novo; volta junto com o save).
- O painel da unidade agora se atualiza sozinho quando o mundo muda o estado dela (`fog_updated` e virada de turno).
- **Tooltips** (nós conectados): N4 `Desbloqueia Muralha de Escudos para unidades da Doutrina do Guardião.` + a descrição
  da postura defensiva; N5 `Desbloqueia Guardião. Cidades com Salão dos Guardiões passam a treiná-lo diretamente, e
  Escudeiros existentes podem ser modernizados em cidades próprias.` Nenhum dos dois mostra "Gameplay V2 ainda não conectado."
  (N6–N9 continuam mostrando).
- Toasts novos do `V2UnlockSystem`: "Nova técnica disponível: …", "Nova evolução disponível: …".

### Guardião (N5) — definição (**BALANCE PLACEHOLDER**)

| | Escudeiro | **Guardião** |
|---|---|---|
| Vida | 18 | **24** |
| Ataque | 3,0 | **4,0** |
| Defesa | 4,5 | **6,0** |
| Movimento | 2 | **2** |
| Visão / alcance | 3 / corpo a corpo | 3 / corpo a corpo |
| Custo | 20 PP | **32 PP** |

Continua **tank/frontline** (defende mais do que ataca, não é DPS, sem mobilidade nova, sem upkeep). É o Escudeiro
evoluído, não uma classe nova. `visual_kind == "v2_unit_guardian"` (o `SaveManager` recria a unidade por ele). Registrado
em `PLAYER_TRAINABLE_KINDS` (botão de produção, candidato da IA, cobertura de `ArmyComposition`) e treinado no Salão via
`UNIT_TRAINER_FALLBACK` — a Sentinela **não** foi criada.

**Assets provisórios (nenhum novo):** Guardião = o mesmo `Knight.glb` do KayKit do Escudeiro/Homem de Armas com
`model_scale_multiplier = 1.2` (20% maior, só pra distinguir a evolução); Salão = modelo do Quartel (Fase 3). Nada
foi modificado nos modelos V1.

### Produção: o Salão oferece a forma mais avançada

`V2UnitLine.resolve_trainable_form(player, unit_id)` / `highest_unlocked_form(player, branch)` devolvem a forma mais
avançada da linha que a civilização pesquisou **e** que tem gameplay conectado. `City.can_train` de uma unidade de
linha exige que ela seja essa forma:

| Pesquisa | Salão oferece | Botão |
|---|---|---|
| N3 (até N4) | Escudeiro | `Escudeiro — 20 PP` |
| N5 | **Guardião** (e não mais o Escudeiro) | `Guardião — 32 PP` |
| N7 por debug | Guardião (a Sentinela não está conectada) | — |

Nada de `if N5:` na UI: a HUD só usa `has_unlocked and can_train`, como sempre; o painel de cidade atualiza quando o
unlock chega (Fase 3). Quem já existe continua existindo e evolui. Depois de carregar o save, com N5, continua oferecendo Guardião.

### Upgrade físico (framework genérico) — `V2UnitUpgrade`

API: `get_upgrade_target(unit)`, `upgrade_cost(unit)`, `unavailable_upgrade_reason(player, unit, hex_grid)`,
`can_upgrade`, `perform_upgrade`. O alvo vem do `upgrade_to` do **nó da unidade** (metadata da Fase 2), só se a forma
seguinte estiver conectada; o prédio exigido vem de `BuildingDatabase.building_that_trains(alvo)`; a cidade, de
`HexGrid.city_owning_tile`.

**Custo = `2 × (custo de produção novo − antigo)`** (`GOLD_PER_PRODUCTION_POINT = 2.0`) → Escudeiro→Guardião = 2 × (32 − 20) =
**24 Ouro** (nenhum "24" na lógica). **BALANCE PLACEHOLDER.**

Requisitos, na ordem em que o motivo é mostrado: pesquisa da forma nova (`Requer pesquisa: Guardião.`) → estar em
território de **cidade própria** (`Precisa estar em uma cidade própria.`) → essa cidade ter o **Salão**
(`Requer Salão dos Guardiões na cidade.`) → ação disponível (`A unidade já agiu neste turno.`) → sem técnica ativa
(`Não pode evoluir com Muralha de Escudos ativa.`) → Ouro (`Ouro insuficiente (custa 24).`).

**"Dentro de uma cidade"** = a unidade está num tile do `owned_tiles` de uma cidade **da própria civilização**
(o helper real de território, sem segunda definição). Isso inclui o centro, os vizinhos iniciais e tiles conquistados;
não vale cidade inimiga, campo aberto, nem cidade própria sem Salão (vale o Salão da cidade em cujo território a unidade
está, não o de outra cidade).

**É a MESMA unidade** (`Unit.apply_form`): o objeto continua o mesmo, então dono, tile, `serial_id`, `kills`/veterania,
recargas e estados persistem sem cópia. Só o que depende do tipo é refeito (visual, base, barra de vida, ícone). Nada de
tropa nova, fantasma ou duplicata (teste confere contagens e o ocupante do tile). **HP em percentual** (9/18 → 12/24;
nunca cura, nunca passa do máximo). **Instantâneo** (fora da fila da cidade): desconta o Ouro na hora, gasta a ação
(movimento zerado) e cancela ordens automáticas. **Recarga preservada**: evoluir não reseta a Muralha.

Botão no painel da unidade: `Evoluir para Guardião — 24 Ouro` (aparece quando a civilização já pesquisou a forma
seguinte; as demais condições o **desabilitam com o motivo**). O caso "sem pesquisa" está na API
(`Requer pesquisa: …`) mas não na UI, pelo mesmo critério da Muralha (só aparece o que a civilização já tem).

### Save / load

Nenhuma mudança de formato. Recarga e estado ativo da Muralha viajam em `magic_cooldowns`/`magic_status`; o `SaveManager`
apenas chama `refresh_technique_marker()` depois de restaurar o estado (o anel volta). Guardião salvo volta como
Guardião (`visual_kind`), com HP/veterania/recarga. Cobertos: **Caso A** (recarga preservada, expira no turno certo),
**Caso B** (Muralha ativa salva no meio da duração: volta ativa, com anel, e expira no turno certo), Guardião evoluído
e produção de Guardião depois do load.

### Reset de debug

Resetar a pesquisa V2 **não faz downgrade nem apaga** Salão, Escudeiro ou Guardião existentes. Sem N4 não usa a Muralha;
sem N5 não evolui nem treina Guardião; sem N3 nem Escudeiro; a produção volta a respeitar a pesquisa atual. (Uma Muralha
já ativa termina normalmente; o efeito de formação sobre aliados exige o nó pesquisado, então também some.) É ferramenta
de desenvolvimento, não mecânica.

### IA

A IA continua sem pesquisar V2 e sem usar técnica nem upgrade. Compatibilidade mínima testada: uma civilização rival que
receba N5 (por teste/debug) tem o Guardião como forma treinável no Salão (`can_train`, filtro de candidatos da IA) sem
quebrar; 6 turnos reais de IA com o conteúdo presente, sem erro nem uso de conteúdo V2.

### Testes (+112; suíte completa **1836 / 1836**, 65 scripts)

| Arquivo | Testes | Cobre |
|---|---|---|
| `test_v2_shield_wall.gd` | 41 | dado/registro, "não é feitiço", elegibilidade por linha (Sentinela reconhecida), N4, ativação (zero Mana/Ouro, ação, movimento, ordens), recarga 3, duração/expiração/rede de segurança, anel, linhas de UI, **defesa no cálculo e na resolução real de combate**, +35%/+15%, formação (afastar/voltar), sem acúmulo, sem proteção de outro dono, protetor caído |
| `test_v2_guardian_unit.gd` | 23 | definição (24/4,0/6,0/2/32), relações com o Escudeiro, resolução da forma treinável, produção antes/depois do N5, Salão obrigatório, por civilização, reset de debug, IA |
| `test_v2_unit_upgrade.gd` | 31 | alvo por metadata, fórmula, cada recusa (sem N5, fora de cidade, sem Salão, cidade inimiga, Ouro, ação, técnica ativa), HP proporcional, veterania/kills/serial, recarga, mesma unidade sem fantasma, ação consumida, visual refeito, toast, reset de debug, "sem id hardcoded" |
| `test_v2_guardian_n5_flow.gd` | 6 | **fluxo principal ponta a ponta** (abaixo), Casos A e B de save/load, Guardião evoluído salvo, expiração pelo turno real, IA |
| `test_hud.gd` (+11) | 11 | botão da Muralha (N4, ativo, recarga, sem ação), atualização do painel, botão de evolução (custo, motivos, clique), produção Escudeiro → Guardião |
| adaptados | — | testes das Fases 1–3 que assumiam "N4/N5 não conectados" ou completavam a linha inteira |

Fluxo principal: jogo novo → N1–N3 → Salão → Escudeiro → N4 → Muralha pelo `SelectionManager` (zero Mana/Ouro, movimento 0,
recarga 3, anel) → dano previsto com < sem, e `resolve` real tira exatamente o previsto → virada de turno (expirou, recarga 2)
→ N5 (Escudeiro sai da produção, Guardião entra) → Guardião treinado → Escudeiro (9/18 HP, veterania Elite, em recarga) evolui
→ 12/24, mesma unidade, Ouro −24, recarga preservada → salvar → carregar → pesquisas, Salão, Guardião, HP, veterania e recarga
conferem → a cidade carregada produz outro Guardião.

### Validação visual (não-headless, 1920×1017, `Main.tscn` real)

Fluxo jogado na cena real e conferido nas capturas: toasts de N4/N5; produção **`Escudeiro — 20 PP`** antes do N5 e
**`Guardião — 32 PP`** depois (só um por vez); botão **`Muralha de Escudos`** ao selecionar o Escudeiro; após usar,
o painel mostra **`Muralha de Escudos — Ativa`** e a recarga, e o botão vira `— Ativa` (desabilitado); na virada do turno a
Muralha some e o botão vira `(recarga 2)`; botão **`Evoluir para Guardião — 24 Ouro`**; após evoluir, painel do **Guardião**
(`HP 12/24 | Ataque 4.0 | Defesa 6.0 | Movimento 0.0/2.0`, `+20% ataque/defesa (3 abates)` = veterania preservada, recarga preservada,
toast "Escudeiro evoluiu para Guardião.", Ouro 100→76 na barra superior); no turno seguinte o Guardião tem alcance de movimento
(9 tiles) e ataca (alvo atacável, dano causado).

Defeitos que a validação achou (e foram corrigidos): (1) a linha `Recarga: v2_technique_shield_wall (3)` — o id cru vazava pela
lista de recarga de feitiços, duplicando a nossa (corrigido em `TileInspector.caster_lines` + teste de regressão); (2) o anel
da Muralha era fino demais/de baixo contraste sobre a base azul — engrossado e clareado. Como esses dois ajustes mudaram o
visual, foi feita **uma execução corretiva curta** (a segunda) que confirmou o **anel ciano visível** na base do Escudeiro em
zoom e a linha de recarga única. O nº de lançamentos foi maior que 2 só porque dois lançamentos iniciais do roteiro
descartável falharam ao compilar/rodar (erros do meu script, sem nenhuma captura).

Não coberto visualmente (ressalvas): o bônus de **formação** (+15%) foi verificado só pelos números (o dano previsto no
arqueiro adjacente foi de 14,25 para 14,14 — defesa 1,5 × 1,15; a diferença é pequena porque a Defesa do Arqueiro é baixa),
não por captura; e o modelo do **Guardião evoluído** não foi capturado de perto (a tentativa de zoom foi desfeita pelo
`reset_view` do roteiro) — a evolução aparece pelo painel. O Escudeiro/Guardião nascem no mesmo tile do Salão (spawn V1),
o que dificulta ver o modelo isolado.

### Performance

Nenhum `_process`, timer nem polling novo. Medido (headless): a consulta de defesa por técnica custa **3,5 µs** por previsão
de combate para um jogador sem pesquisa V2 (`predict` inteiro: 18 µs), **10 µs** para um jogador com N4 e vizinhos, **1,6 µs** quando a
própria Muralha está ativa — a busca de aliado adjacente só roda se o dono tem a técnica pesquisada (era 10 µs para todos antes dessa
otimização) e a lista de técnicas defensivas é cacheada. A expiração é 1 passada por turno pelas unidades com estado
(`magic_status` vazio pula: 2 µs para 3 unidades). O upgrade é evento raro (uma chamada). Refresh do painel da unidade com as ações
V2: 0,6 ms por seleção (só ao selecionar/virar turno/atualizar fog); 68–106 FPS nas capturas.

### Limitações (de propósito) e ressalvas

- **Números e modelos provisórios** (Muralha +35/+15/3 turnos; Guardião 24/4,0/6,0/2/32 PP; upgrade 24 Ouro; Knight ×1,2). Sem arte V2.
- A recarga conta a partir do turno de uso (usou no T, volta no T+3); o efeito dura até o dono voltar a jogar (modelo acima).
- "Ação gasta" = `movement_left <= 0` (convenção V1): quem gastou todo o movimento andando também não usa a técnica nem evolui naquele turno.
- Só técnicas defensivas (`+Defesa`) existem no registro; o dado prevê mais efeitos, mas nenhum foi criado (Preparar Lanças, N6, é metadata).
- O botão de evolução só aparece depois de pesquisar a forma seguinte; o motivo "Requer pesquisa" existe na API, não na UI.
- A IA não usa Muralha nem evolui unidades (fase futura).
- Fora do escopo, **não implementado:** N6–N9 do Guardião, Sentinela, upgrade N5→N7, outras Doutrinas e técnicas, Unidade Lendária, upkeep/Suprimentos,
  economia V2, Magia/Infraestrutura V2, vitória V2, IA estratégica V2.
- Fase encerrada quando **Guardião N4–N5 funciona sobre as fundações genéricas de Técnica e Upgrade**. Não avança para o N6.

---

## Fase 5 — Guardião N6–N7: Técnica passiva e forma Elite

Duas provas sobre as fundações da Fase 4, **sem sistema novo para N6/N7**:

```
N6 Preparar Lanças  (v2_technique_brace_spears)   →  Técnica PASSIVA (sem botão, custo, recarga, duração nem estado)
N7 Sentinela        (v2_unit_sentinel)            →  2º upgrade pelo MESMO V2UnitUpgrade: Escudeiro → Guardião → Sentinela
```

N1–N7 do Guardião ficam `gameplay_connected = true`. **N8 (Bastião de Maestria) e N9 (Campeão Guardião) seguem só
metadata** — nenhum prédio, unidade Lendária, slot Lendário ou aura foi criado; as outras cinco Doutrinas, Magia e
Infraestrutura continuam inertes.

### Técnica ativa × passiva (extensão do framework)

`V2DoctrineTechniqueData.activation_mode` (`ACTIVE` | `PASSIVE`, padrão `ACTIVE`) vem do **dado**; nenhuma lógica decide
"tem botão?" por id.

| | Muralha de Escudos (N4) | Preparar Lanças (N6) |
|---|---|---|
| `activation_mode` | `ACTIVE` | `PASSIVE` |
| Botão no painel | sim | **não** |
| Custo / ação / movimento | zero Mana e Ouro; gasta a ação e zera o movimento | nenhum |
| Recarga / duração | 3 turnos / até o início do próximo turno do dono | nenhuma |
| Estado guardado (`magic_status`/`magic_cooldowns`) | sim | **nenhum** — é derivada |
| Efeito | `+35%` Defesa própria, `+15%` aliados adjacentes (consulta em `predict`) | `+50%` no ataque básico contra alvo com o traço `mounted` |

Campos novos do dado (passiva): `basic_attack_bonus` (0,5 = +50%) e `basic_attack_target_trait` (traço de `UnitData`). O
runtime ganhou `active_techniques_for_unit` / `passive_techniques_for_unit` (a UI só cria botão para as ativas),
`passive_lines` e `attack_multiplier(attacker, defender)`. `can_use`/`activate` recusam passiva (`… é passiva: age sozinha, sem
ativação.`); `expire_finished` a ignora. **Elegibilidade continua por linha** (`V2UnitLine.branch_of`) — nada de id concreto
(um teste varre o código sem comentários).

**A passiva é derivada, não salva:** o efeito vale se (a) o **dono** da unidade pesquisou o nó, (b) a unidade é da linha
Guardião e (c) o alvo tem o traço. Logo: unidades antigas recebem sem evoluir nem estar em cidade; save/load funciona sem campo
novo (`SAVE_VERSION` continua 21); resetar a pesquisa por debug remove o efeito; a pesquisa de uma civilização não vaza para outra.

### "Montado" — classificação genérica (reaproveitada, sem lista de ids na lógica)

**Auditoria:** a V1 já tinha uma classificação — `UnitAbilities.MOUNTED`, lista de 7 tropas, usada só pelo bônus +50% do
Lanceiro/Alabardeiro. **Não foi criada uma segunda definição:** essa lista virou o *semeador* de um **traço no dado**.

- `UnitData.traits: Array[String]` + `UnitData.has_trait()` + `UnitData.TRAIT_MOUNTED = "mounted"`.
- `UnitDatabase.create_unit` acrescenta o traço `mounted` a toda tropa V1 de `UnitAbilities.MOUNTED` (uma vez, no fim).
- `UnitAbilities.is_mounted(unit_data)` = `has_trait("mounted")` é a **única** consulta; o bônus do Lanceiro passou a usá-la (mesmo
  resultado: os testes V1 continuam iguais). Nome/id **não** classificam.
- **Cavalaria V2 (futura):** `v2_unit_cavalier`, `v2_unit_shock_cavalier`, `v2_unit_armored_cavalier` só precisarão declarar o traço
  — Preparar Lanças passa a valer contra elas sem código novo (um teste usa uma unidade de teste com o traço e id `v2_unit_cavalier`).
  Nenhuma dessas unidades foi criada.
- O inspetor passou a mostrar o traço público **"Montada"** nas unidades montadas.

### Preparar Lanças — cálculo do bônus (**BALANCE PLACEHOLDER: +50%**)

Integrado no ponto semântico dos bônus "contra tipo de unidade": `UnitAbilities.attack_multiplier(attacker, defender)` (o mesmo
usado por `CombatResolver.predict`, que `resolve` e a IA já usam) recebe `× V2TechniqueRuntime.attack_multiplier(...)`. **Não há
cadeia paralela**: previsão, resolução real e IA veem o mesmo número (teste: perda real de HP == dano previsto, contra montado e
não montado).

- Só o **ataque básico** contra unidade (`attack_multiplier`): `city_attack_multiplier` e `MagicRuntime.attack_multiplier` não
  mudam; feitiço, dano de cidade e efeito de mapa ficam de fora.
- **Combinação:** bônus de origens diferentes **multiplicam** (o +50% do Lanceiro V1, o das Técnicas V2 e o flanco são coisas
  distintas — a unidade Guardião V2 não tem outro bônus anti-montado); a mesma técnica nunca conta duas vezes (uma técnica = um
  fator, mesmo com várias unidades da linha por perto). Ex. medido: sem flanco, Guardião (Ataque 4,0) vs Cavaleiro (Defesa 2):
  dano 3,0 → 5,0; com flanco de 1,15 o acréscimo é `4,0 × 1,15 × 0,5`.
- **Limitação do motor:** o contra-ataque da defesa neste jogo não usa o Ataque do defensor (`predict` calcula
  `max(0, Defesa − Ataque do atacante × fator)`), então a passiva só age nos ataques **iniciados pela** unidade da linha.
- **Compatibilidade V1/V2:** funciona contra a Cavalaria V1 real (`cavalry`, `human_knight`, `batedor_montado`…) sem alterar seus stats.

### UI

Preparar Lanças **não** vira botão. O painel de uma unidade própria da linha (após N6) mostra, sem painel novo:

```
Passiva — Preparar Lanças
+50% de dano de ataque básico contra unidades montadas.
```

(2 linhas curtas para caber na largura do painel; o inspetor mostra o mesmo só para o **dono** — o que um observador vê
(`status_effect_lines`, traços) nunca revela a pesquisa oculta.) Tooltip de N6: `Desbloqueia Preparar Lanças para unidades da
Doutrina do Guardião.` + descrição (passiva, sem botão nem recarga, ataques básicos causam dano adicional contra unidades
montadas). Toasts: "Nova técnica disponível: Preparar Lanças", "Nova evolução disponível: Sentinela".

**Tooltips de evolução sem pronome:** o texto de N5/N7 agora é `Desbloqueia X. Cidades com Salão dos Guardiões passam a treinar X
diretamente, e cada <base> existente pode evoluir em cidades próprias.` — "treiná-lo/treiná-la" e o plural ("Guardiões") dependeriam
de gênero/flexão de cada nome (Guardião m., Sentinela f.); a versão neutra vale para toda forma. (Mudou o texto do N5 da Fase 4.)

### Sentinela (N7) — definição (**BALANCE PLACEHOLDER**)

| | Escudeiro | Guardião | **Sentinela** |
|---|---:|---:|---:|
| Vida | 18 | 24 | **32** |
| Ataque | 3,0 | 4,0 | **5,0** |
| Defesa | 4,5 | 6,0 | **8,0** |
| Movimento | 2 | 2 | **2** |
| Visão / alcance | 3 / c.a.c. | 3 / c.a.c. | 3 / c.a.c. |
| Produção | 20 PP | 32 PP | **48 PP** |
| Escala do modelo (provisório) | 1,0 | 1,2 | **1,4** |

Forma Elite **convencional** (não é Lendária; quantidade normal), continua tank/frontline: mais vida e defesa que o Guardião, ataque
só moderadamente maior (a razão do ataque, ×1,25, fica abaixo da da defesa, ×1,33; ataque < defesa), mobilidade igual, sem upkeep.
`visual_kind == "v2_unit_sentinel"`; registrada em `PLAYER_TRAINABLE_KINDS` e treinada no **Salão dos Guardiões** via
`UNIT_TRAINER_FALLBACK` — o Bastião de Maestria (N8) **não** é requisito. **Herda as duas Técnicas por linha**
(`branch_of == guardian`), sem código próprio.

**Assets provisórios (nenhum novo):** o mesmo `Knight.glb` do KayKit, escalado 1,0 / 1,2 / 1,4 para distinguir as três formas.

**Nota de balanceamento:** Defesa 8,0 é a maior do elenco V1+V2 (o Golem de Pedra V1 tem menos). Um teste V1 que afirmava "o Golem tem a
maior defesa do elenco treinável" passou a ignorar os ids `v2_*` (o elenco V2 é comparado nos testes V2).

### Produção — só a forma normal mais avançada

`V2UnitLine.resolve_trainable_form` (Fase 4) já cobre: N3–N4 Escudeiro · N5–N6 **Guardião** · N7 **Sentinela**, nunca mais de uma forma
da linha ao mesmo tempo (teste percorre N3..N7). Nenhuma mudança de código na cidade nem na HUD além do registro. Vale por
civilização, sobrevive ao save/load e respeita o reset de debug (nada existente é destruído; a produção volta a respeitar a pesquisa).

### Segundo upgrade: Guardião → Sentinela (mesmo `V2UnitUpgrade`)

Nenhuma função nova: o alvo vem de `upgrade_to` do nó do Guardião; o prédio, de `building_that_trains(alvo)` (o Salão); o custo,
da fórmula genérica `2 × (custo novo − antigo)` = `2 × (48 − 32)` = **32 Ouro** (não escrito na lógica). Requisitos idênticos aos
do 1º upgrade (N7, território de cidade própria com Salão, Ouro, ação disponível, sem técnica ativa). Preserva o mesmo objeto,
`serial_id`, dono, tile, kills/veterania, recarga da Muralha; HP em percentual (12/24 → 16/32). **Cadeia completa na mesma unidade**
(testada): Escudeiro (9/18) → Guardião (12/24, −24 Ouro) → Sentinela (16/32, −32 Ouro), um passo por vez, com novo turno entre eles.
Botão do painel: `Evoluir para Sentinela — 32 Ouro`.

### Save / load

Sem formato novo. Sentinela salva/recarrega pelo `visual_kind`; a passiva **não é salva** (derivada); a recarga da Muralha continua
em `magic_cooldowns`. Cobertos: fluxo N6–N7 completo com save no fim, Sentinela evoluída pela cadeia inteira antes de salvar, e reset
depois de carregar remove a passiva sem destruir a unidade.

### IA

Sem decisão nova. Compatibilidade testada: uma civilização com N7 tem a Sentinela como forma treinável (mesmo filtro da produção da
IA), o anti-montado age em `CombatResolver` e a passiva não exige ativação; 6 turnos reais com conteúdo V2 presente, sem erro nem uso
de conteúdo V2 pelos rivais.

### Testes (+66; suíte completa **1902 / 1902**, 68 scripts)

| Arquivo | Testes | Cobre |
|---|---|---|
| `test_v2_brace_spears.gd` | 29 | ACTIVE/PASSIVE por dado, passiva sem botão/recarga/ação/Mana/estado, elegibilidade por linha, sem bônus antes do N6, bônus nas 3 formas, alvo não montado, valor exato, **previsão == resolução real**, Cavalaria V1 real, rival sem N6, sem vazamento entre civilizações, derivação (load/reset), cidade/feitiço fora, Lanceiro V1 inalterado, sem dupla contagem, classificação por traço (não por nome/id), fixture montada, "Montada" no inspetor, sem ids concretos na lógica |
| `test_v2_sentinel.gd` | 25 | dados e relações, progressão monotônica das 3 formas, herança das técnicas por linha, produção por nível (uma forma por vez), duas civilizações, reset, IA, alvo por metadata, custo pela fórmula, cada requisito, preservação (HP %, veterania, serial, recarga…), **cadeia Escudeiro→Guardião→Sentinela na mesma unidade** |
| `test_v2_guardian_n7_flow.gd` | 5 | **fluxo principal ponta a ponta** (abaixo), Sentinela salva depois da cadeia, reset após load, duas civilizações, IA |
| `test_hud.gd` (+7) | 7 | passiva no painel sem botão, botão da Muralha na Sentinela, botão `Evoluir para Sentinela — 32 Ouro`, produção Escudeiro→Guardião→Sentinela (nunca duas), clique de produção |
| adaptados | — | testes das Fases 1–4 que assumiam N6/N7 inertes, o texto neutro dos tooltips de evolução e o teste V1 do Golem |

Fluxo principal: jogo novo → N1–N5 → Salão → Guardião treinado → alvo Montado (Cavaleiro V1) e não montado; dano previsto **antes do N6**
→ N6 (passiva no painel; Muralha continua a única ação; nenhum estado guardado) → previsão com bônus e `resolve` real com a mesma perda
de HP; não montado igual ao de antes → N7 (produção troca Guardião por Sentinela) → Muralha usada (recarga a preservar) → Guardião em
cidade própria com 12/24 HP e veterania Elite evolui → 16/32, custo pela fórmula, recarga preservada → a Sentinela tem Muralha e passiva
→ salvar → carregar → 7 pesquisas, Salão, Sentinela, HP, veterania e recarga conferem, a passiva existe e o bônus anti-montado vale por
derivação → a cidade carregada produz outra Sentinela.

### Validação visual (não-headless, 1920×1017, `Main.tscn` real, uma execução)

Confirmado nas capturas/prints: antes do N6 o painel do Guardião **não** tem a passiva; depois do N6 aparece `Passiva — Preparar Lanças
+50% de dano de ataque básico contra unidades montadas.` e a única ação continua sendo `Muralha de Escudos` (nenhum botão novo); toast
"Nova técnica disponível: Preparar Lanças"; **ataque real** contra um Cavaleiro: perda de 5,65 de vida == previsão 5,65 (antes do N6 a
previsão era 3,35; contra o Guarda não montado, 2,13 nos dois momentos); tooltips de N6/N7 sem "Gameplay V2 ainda não conectado.";
após o N7 a produção mostra só **`Sentinela — 48 PP`** (o Guardião some); botão **`Evoluir para Sentinela — 32 Ouro`**; após evoluir,
painel `Sentinela (Elite) | HP 16/32 | Ataque 5.0 | Defesa 8.0` com veterania (`+20%`), passiva, `Muralha de Escudos` (desabilitada, sem ação
neste turno), toast "Guardião evoluiu para Sentinela.", Ouro 100→68; escalas 1,0/1,2/1,4.

Ressalvas: (1) o Sentinela/Guardião/Escudeiro nascem no **mesmo tile do Salão** (spawn V1), e a Sentinela evoluída ficou atrás do modelo do
prédio — na captura de perto só as outras duas formas (escala 1,0 e 1,2) aparecem isoladas; a diferença de escala foi confirmada por
número (1,0/1,2/1,4), não por captura da Sentinela; (2) depois da captura passei a linha passiva de uma linha longa para duas curtas (o
texto único encostava na borda do painel, que se sobrepõe ao menu da direita — sobreposição já existente); essa mudança de layout foi
conferida por teste, **não** recapturada, pela regra de "uma vez só"; (3) efeito visual próprio para Preparar Lanças não foi criado (fora de escopo).

### Performance

Sem `_process`, timer nem polling. Medido (headless, 100 mil chamadas): `UnitAbilities.attack_multiplier` = 2,9 µs para um atacante V1
(caminho rápido: sai na comparação do prefixo `v2_`), 6–8 µs para unidade da linha (com ou sem N6); `CombatResolver.predict` completo: 19,7 µs
(atacante V1) → 26 µs (Guardião com N6 contra montado). O caminho: 1) o atacante é V2? 2) qual a linha? 3) o dono pesquisou? 4) o alvo tem o
traço? — só dicionários e listas em cache (`attack_bonus_techniques`). Refresh do painel da unidade (Sentinela, com ações e passivas): 0,67 ms
por seleção; 93–133 FPS nas capturas.

### Limitações (de propósito) e ressalvas

- **Números e modelos provisórios** (+50%; Sentinela 32/5,0/8,0/2/48 PP; upgrade 32 Ouro; Knight ×1,4). Sem arte V2 nem efeito visual da passiva.
- A passiva só age nos ataques iniciados pela unidade (o motor não modela contra-ataque com o Ataque do defensor).
- Só existe uma passiva e um tipo de efeito (`+dano de ataque básico` contra um traço); o dado prevê outros, nenhum foi criado.
- Defesa 8,0 supera a maior Defesa V1 (Golem); decisão do escopo, sinalizada acima.
- A IA não usa Muralha nem evolui unidades (fase futura). Resetar a pesquisa por debug remove a passiva, não destrói unidades/prédios.
- Fora do escopo, **não implementado:** Bastião de Maestria (N8), Campeão Guardião/slot Lendário (N9), outras Doutrinas e técnicas, Cavalaria V2,
  upkeep/Suprimentos, economia V2, Magia/Infraestrutura V2, vitória V2, IA estratégica V2.
- Fase encerrada quando **Guardião N1–N7 está funcional, com duas Técnicas distintas em natureza e três formas físicas completas**. Não avança para o N8.

---

## Fase 6 — Guardião N8–N9: Maestria e Unidade Lendária

Fecha a Doutrina do Guardião e entrega o **molde completo** das Doutrinas Militares V2:

```
N8 Bastião de Maestria     (v2_building_guardian_mastery)        →  prédio REAL de Maestria; única função: habilitar o Campeão
N9 Campeão Guardião        (v2_legendary_guardian_champion)      →  unidade LENDÁRIA REAL, produção própria no Bastião
                                                                    (não é upgrade da Sentinela; fora da cadeia Escudeiro→Guardião→Sentinela)
```

Guardião **N1–N9 = `gameplay_connected = true`**. As demais Doutrinas seguem inertes. O Exército Supremo continua inerte: o N9 só contribui
com "Doutrinas completas 1/2" (`capstone_progress`); `v2_military_supremacy_access` não está conectado.

### Arquitetura — `mastery_building` (N8)

Sem sistema novo. O tipo de unlock `mastery_building` entra em `V2UnlockSystem.CONNECTED_TYPES` e o id `v2_building_guardian_mastery` em
`V2DoctrineContent.CONNECTED_UNLOCK_IDS`; o prédio é um `BuildingData` comum, pelo mesmo caminho do Salão (`City.can_build`, slots, fila,
save, captura). O que o torna V2: o gate de pesquisa (id `v2_` → `player.has_unlocked`) e `BuildingData.requires_building` (já existente)
apontando para o Salão.

### Arquitetura — Unidade Lendária (sistema global, `V2LegendarySystem`)

Reutilizável pelas 5 Lendárias futuras: **nenhum `if unit_id == campeão`** na lógica (teste varre o código atrás de ids concretos).

- **O que é Lendária:** por *metadata*, não por nome — `is_legendary_kind(kind)` = id V2 cujo nó de pesquisa tem `unlock_type == "legendary_candidate"`;
  `is_legendary_unit(unit)` = `UnitData` com o traço `legendary` (`UnitDatabase.create_unit` acrescenta o traço a qualquer forma legendária).
- **Limite:** `V2ResearchDatabase.MAX_ACTIVE_LEGENDARY_UNITS = 1` (uma **ativa OU em treinamento** por civilização), lido via `V2LegendarySystem.max_active()`.
- **Como o slot é calculado (nada salvo, nenhum booleano):**
  `slots_used(player, excluding_city) = (unidades vivas do dono com o traço legendary) + (cidades do dono cujo production_item é de um id Lendário)`.
  A cidade que está decidindo **exclui a própria ordem** (senão a cidade que produz o Campeão se bloquearia). `legendary_slot_available(player, city)`
  = `slots_used(...) < max_active()`.
- **Concorrência entre cidades:** a *reserva* é a própria ordem de produção. No instante em que a cidade A põe o Campeão na fila,
  `slots_used` da cidade B passa a ser 1 → B não consegue iniciar (e o botão vira "desabilitado com motivo"). Cancelar/trocar a ordem, perder
  a cidade ou a morte da unidade liberam o slot **na consulta seguinte**.
- **Onde é consultado:** `City.can_train` (dentro do bloco V2, só para ids Lendários), a lista de produção do HUD (botão visível-e-desabilitado
  quando o slot é o *único* impedimento — `slot_only_reason`) e o fim da produção em `GameManager`.
- **Fail-closed no nascimento:** ao completar a produção, `V2LegendarySystem.spawn_allowed(player, kind)` é reconfirmado; se já existir outra
  Lendária ativa (ex.: duas cidades concluindo no mesmo turno), `refuse_spawn` **não cria a unidade**, devolve o custo a `city.stored_production`,
  registra `push_error("V2LegendarySystem: '…' não nasceu em … — …")` e avisa o humano por toast. Nunca há duas ativas.
- **Motivos (ordem de prioridade):** pesquisa ("Requer pesquisa: X.") → prédio ("Requer Bastião de Maestria na cidade.") → slot
  (**"Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização."**).
- **Outras civilizações:** o slot é por dono; uma Lendária rival não bloqueia o jogador.
- **Reset de debug da pesquisa:** não mata a unidade; o slot continua ocupado (a unidade existe).

### Bastião de Maestria — definição (**BALANCE PLACEHOLDER**)

| Campo | Valor |
|---|---|
| id / nome | `v2_building_guardian_mastery` / **Bastião de Maestria** (`mastery_building`) |
| Custo | **55 PP** (~2,5× o Salão de 22; abaixo dos 90 do Campeão) |
| Requisitos | N8 + cidade própria + `v2_building_guardian_hall` **na mesma cidade** (não substitui o Salão) |
| Função | `trains_unit = v2_legendary_guardian_champion` — nada mais (sem rendimento, defesa, aura, upkeep) |
| Slot | um slot de prédio normal (regra V1: máx. de prédios = população) |
| Modelo | reaproveitado: `building_tower_B_blue.gltf` (o KayKit não tem fortaleza; mesmo modelo da Torre Arcana), sem arte nova |
| Tooltip | "Desbloqueia Bastião de Maestria. Requer Salão dos Guardiões e permite treinar o Campeão Guardião após sua pesquisa." |
| Toast | "Novo prédio disponível: Bastião de Maestria" |

### Campeão Guardião — definição (**BALANCE PLACEHOLDER**)

| Campo | Valor |
|---|---|
| id / nome | `v2_legendary_guardian_champion` / **Campeão Guardião** (`legendary_candidate`, traço `legendary`) |
| HP / Ataque / Defesa | **44 / 6,5 / 10,0** (Sentinela: 32 / 5,0 / 8,0) |
| Movimento / Visão / Alcance | 2 / 3 / corpo a corpo |
| Custo | **90 PP**, produzido **no Bastião** (a Sentinela continua no Salão, 48 PP) |
| Modelo | `Barbarian.glb` + `Rig_Medium_General.glb`, escala ×1,5 (Escudeiro 1,0 / Guardião 1,2 / Sentinela 1,4) — distinguível, sem ser gigante |
| Ramo | Guardião — herda **Muralha de Escudos** e **Preparar Lanças** pelo ramo (`V2UnitLine.doctrine_branch_of`), **sem dados de técnica duplicados** |
| Toast | "Unidade Lendária disponível: Campeão Guardião" (pesquisa) e "Unidade Lendária pronta: Campeão Guardião" (nascimento) |

Relação com a cadeia: `V2UnitLine.node_for` só reconhece papéis base/evolução/elite, então o Campeão **não é "unidade da linha"**;
`resolve_trainable_form` continua devolvendo a Sentinela; o Campeão não evolui e a Sentinela não evolui para ele.

### Comando Defensivo — aura intrínseca (`V2UnitAuras`)

Não é Técnica de Doutrina: é dado da *própria unidade* (`UnitData.aura_id/aura_name/aura_radius/aura_defense_bonus`), então continua
funcionando mesmo depois de um reset da pesquisa.

- Aliados do **mesmo dono** a até **2 tiles** recebem **+20% de Defesa**; o Campeão **não** se beneficia.
- **Posição real, sem estado guardado, sem `_process`:** consultada dentro de `CombatResolver.predict` (a mesma conta de defesa da previsão e da
  resolução). Quem sai do raio perde o bônus; ao voltar, recebe. Emissor morto/removido não dá nada.
- **Nunca empilha a mesma aura:** com dois emissores vale só o maior bônus por `aura_id`; `aura_id` diferentes multiplicam.
- **Custo local:** só percorre as unidades da própria civilização (uma comparação de raio cada).

### Combinação com a Muralha de Escudos

Origens diferentes **multiplicam**; cada origem conta **uma vez**: um aliado dentro da formação de uma Muralha (×1,15) **e** do raio do Campeão (×1,20)
recebe **×1,38** de Defesa. Duas Muralhas ou dois Campeões não duplicam a própria origem. O Campeão que usa a *sua* Muralha mantém os +35% próprios
e não recebe a aura de si mesmo.

### Herança de Preparar Lanças e Muralha

`V2TechniqueRuntime.techniques_for_unit / unavailable_reason / attack_multiplier` passaram a usar `V2UnitLine.doctrine_branch_of(unit_id)`
(ramo da linha ou, para o candidato Lendário, o ramo do nó). O Campeão tem, portanto, o botão da Muralha, a passiva anti-montado (+50%) e as
mesmas exigências de pesquisa das demais formas; o dado das técnicas **não** menciona o Campeão (coberto por teste).

### UI

- Produção: no Bastião aparece **"Campeão Guardião — 90 PP"**, ao lado de **"Sentinela — 48 PP"**. Em outra cidade com Bastião enquanto o slot
  está reservado/ocupado, o botão fica **visível e desabilitado** com o motivo no tooltip.
- Painel da unidade: primeira linha **LENDÁRIO**, depois `Campeão Guardião (Recruta) | HP | Ataque | Defesa | Movimento`, **Passiva — Preparar Lanças**,
  **Passiva Lendária — Comando Defensivo / Aliados em raio 2 recebem +20% de Defesa.**, botão **Muralha de Escudos**; nenhum botão de evolução.
- Inspetor de tile (`TileInspector.unit_traits`): fatos públicos "Lendária" e "Comando Defensivo (raio 2, +20% Defesa aliada)"; não expõe pesquisa.

### Save / load

Sem formato novo. O slot é **derivado**: a unidade Lendária é salva como qualquer unidade e a **reserva** é o `production_item` da cidade, que o
`SaveManager` já serializa — logo o slot é preservado (unidade ativa **ou** produção em curso) e a segunda cidade continua bloqueada depois de carregar.
A aura e as passivas são derivadas (nada persistido).

### IA

Sem decisão nova. O Campeão está em `PLAYER_TRAINABLE_KINDS` (a lista que alimenta HUD/IA/ArmyComposition); a IA continua sem pesquisar/usar conteúdo V2
(coberto por 6 turnos reais com o conteúdo presente).

### Testes (+89; suíte completa **1991 / 1991**, 72 scripts)

| Arquivo | Testes | Cobre |
|---|---|---|
| `test_v2_legendary_system.gd` | 27 | reconhecimento por metadata (não por nome/id), limite vindo da constante global, slot vazio/ocupado, **ativa bloqueia**, Lendária de **outra Doutrina** bloqueia o mesmo slot, morte/remoção/morte em combate real liberam, por civilização, reset de pesquisa não mata nem libera, **produção reserva o slot**, cidade produtora não se bloqueia, trocar/cancelar/perder a cidade liberam, produção rival não reserva, conclusão sem janela de duas permissões, ordem dos motivos, `slot_only_reason`, ids não Lendários intactos, **spawn recusado** (reembolso + erro claro + nada criado), sem hook por frame/booleano salvo, sem id concreto na lógica |
| `test_v2_guardian_mastery.gd` | 20 | dados/nome, única função (`trains_unit`), sem rendimento/defesa/upkeep, exige o Salão e não o substitui, custo, sem gate V1, modelo existe/nome por raça, registro único, N8 obrigatório, sem Salão não constrói, Barracks/techs V1 não valem, slot normal e construção única, cidade cheia, por civilização, V1 intacto, fila normal, Campeão exige o Bastião, N9 obrigatório, Sentinela não exige o Bastião |
| `test_v2_guardian_champion.gd` | 30 | baseline, relações (superior mas ainda Guardião), dado Lendário sem upkeep e modelo distinto, unidade treinável por raça, fora da cadeia, Sentinela não evolui para ele e ele não evolui, Sentinela nunca substituída, produção só via Lendária (N9 + Bastião + slot), **herança** de Muralha/Preparar Lanças por ramo (sem citar o Campeão no dado), bônus anti-montado e Muralha normais, aura raio 1/2/3, sem auto-buff, inimigos/outros donos, morto/removido, posição real (sai/volta), previsão == resolução, **dois Campeões não empilham**, aura não é estado/técnica, sobrevive ao reset, **Muralha × aura multiplicam (×1,38)**, cada origem conta uma vez, Campeão com a própria Muralha, linhas do dono e fatos públicos |
| `test_v2_guardian_n9_flow.gd` | 5 | **fluxo principal de 26 passos** (abaixo), produção reservada sobrevive a save/load e ainda bloqueia a 2ª cidade, **duas cidades concluindo no mesmo turno nunca criam duas Lendárias** (`assert_push_error`), Sentinela intacta, IA 6 turnos |
| `test_hud.gd` (+7) | 7 | botão do Bastião (N8 + Salão), Campeão ao lado da Sentinela e sem as formas antigas, clique inicia a produção, 2ª cidade **desabilitada com o motivo**, Lendária ativa desabilita em todas as cidades e a morte reabilita, painel LENDÁRIO com aura e técnicas, painel convencional sem rótulo Lendário |
| adaptados | — | testes das Fases 1–5 que assumiam N8/N9 inertes, "Futuramente" dos textos, contagem de conectados e tooltips |

Fluxo principal (26 passos): jogo novo → N1–N7, Salão e uma Sentinela treinada pela produção normal → N8 e o Bastião (só depois do N8; exige o Salão) → sem N9 o Campeão não treina → N9 (capstone militar 1/2, inerte) → o Bastião oferece o Campeão; a cidade A inicia e a **cidade B (também com Bastião) não pode** → a produção conclui: o Campeão nasce, o slot passa de "em treinamento" a "ativo" e a Sentinela segue no Salão → selecionado: Lendário, Muralha, Preparar Lanças e Comando Defensivo → aliado no raio 2 e combate real: a aura chega à resolução (previsão == resolução) → salvar → carregar (Bastião, Campeão e slot conferem) → o Campeão morre: o slot libera e um novo Campeão pode ser treinado. A combinação Muralha × aura (×1,38) é coberta em `test_v2_guardian_champion.gd`.

### Validação visual (não-headless, 1920×1017, `Main.tscn` real)

Confirmado nas capturas: (1) aba **Construções** com **`Bastião de Maestria — 55 PP`** habilitado depois do N8 e toast "Novo prédio disponível: Bastião de
Maestria"; (2) após construir, o painel lista "Salão dos Guardiões, Bastião de Maestria" e a produção mostra **`Sentinela — 48 PP`** e **`Campeão Guardião — 90 PP`**
lado a lado, com o toast "Unidade Lendária disponível: Campeão Guardião"; (3) segunda cidade com o Campeão em produção na primeira: botão **visível e
escurecido** (desabilitado) e a Sentinela ainda habilitada — o motivo exato foi impresso do tooltip ("Já existe uma Unidade Lendária ativa ou em treinamento
nesta civilização."); (4) Campeão selecionado: `LENDÁRIO | Campeão Guardião (Recruta) | HP 44/44 | Ataque 6.5 | Defesa 10.0 | Movimento 2.0/2.0`, Preparar Lanças, **Comando
Defensivo / Aliados em raio 2 recebem +20% de Defesa.** e só o botão `Muralha de Escudos`; toast "Unidade Lendária pronta: Campeão Guardião"; (5) aliado a distância 1:
multiplicador **1,2**, perda real de HP 14,1 == dano previsto 14,1; (6) morte real do Campeão ("Seu Campeão Guardião foi derrotado…"): slot livre, botão de volta habilitado.
Tooltips de N8/N9 sem "Gameplay V2 ainda não conectado."; Doutrinas completas do Exército Supremo **1/2** (inerte). 90–101 FPS nas capturas.

Ressalvas: (1) a primeira execução do script visual abortou **antes de qualquer captura** por um erro no próprio script temporário (cidade nula no setup; nenhum código
do jogo tocado) — a segunda execução foi a que rendeu as capturas; (2) o Campeão nasce num tile vizinho **ocupado pelo Bastião/Salão** e, como a Sentinela na Fase 5, fica
parcialmente atrás do modelo do prédio; a diferença de escala (×1,5 vs. 1,0/1,2/1,4) foi conferida por número e pelo asset (Barbarian × Knight), **não** por uma captura isolada
das quatro formas lado a lado; (3) o motivo do botão bloqueado aparece no *tooltip* (não capturável em screenshot), confirmado por print e por teste; (4) a segunda cidade
do teste caiu numa região polar inexplorada (primeiro tile válido) — irrelevante para a lógica, feio na captura.

### Performance

Sem `_process`, timer nem polling. Medido (headless, 20–50 mil chamadas):

| Operação | 2 unidades do dono | 32–33 unidades do dono |
|---|---|---|
| `V2UnitAuras.defense_multiplier` | 1,8 µs | **13 µs** (15 µs com o Campeão no raio) |
| `CombatResolver.predict` (defensor V2 / V1) | 39 µs | **58 / 57 µs** (≈ +13 µs pela varredura da aura; antes da Fase 6 ≈ 45 µs) |
| `V2LegendarySystem.has_active_legendary / slots_used` (33 unidades, 2 cidades) | — | 35–39 µs |
| `City.can_train(campeão)` / `unavailable_reason` | — | 45 / 61 µs |

A varredura da aura é O(unidades do próprio dono) em **todo** `predict` (também para defensores V1), ~0,4 µs por unidade; a checagem do slot só roda para ids Lendários,
na atualização do painel de cidade e ao fim da produção. Refresh do painel da unidade (Sentinela): 0,72 ms por seleção; 90–101 FPS nas capturas.

### Limitações (de propósito) e ressalvas

- **Números e modelos provisórios** (Bastião 55 PP; Campeão 44/6,5/10,0/90 PP; aura +20%/raio 2; escala ×1,5; torre azul do KayKit como Bastião). Nenhuma arte nova.
- O Bastião ocupa **um slot de prédio** (regra V1: máx. = população); uma cidade com população 1 não comporta Salão + Bastião.
- O Campeão nasce no tile de spawn V1 (vizinho da cidade, como as demais unidades).
- A aura varre as unidades do dono em cada `predict`; se exércitos de centenas de unidades virarem realidade, o caminho natural é um índice espacial por dono (não necessário hoje).
- Defesa 10,0 (e Sentinela 8,0) superam a maior Defesa V1 (Golem 6,0); decisão do escopo. O teste V1 do Golem já ignora ids `v2_`.
- A IA não pesquisa, não constrói o Bastião nem produz o Campeão (fase futura); uma Lendária rival nunca bloquearia o jogador.
- Só existe **uma** Lendária e **uma** aura; o sistema (slot, traço, metadata, `V2UnitAuras`) foi feito para as 5 futuras, mas nenhuma foi criada.
- Fora do escopo, **não implementado:** Exército Supremo e vitória, demais Doutrinas e Lendárias, IA V2, upkeep/Suprimentos, economia V2, Magia/Infraestrutura V2, bônus racial.
- Fase encerrada quando **a Doutrina do Guardião está funcional de N1 a N9 e constitui o molde completo de implementação das Doutrinas Militares V2.**

---

## Fase 7 — Doutrina do Guerreiro N1–N9

A **segunda Doutrina completa**, implementada de uma vez sobre o molde do Guardião. O critério da fase era arquitetural: se as fundações do Guardião
eram genéricas, o Guerreiro devia ser quase só **conteúdo** (dados, unidades, prédios, duas técnicas). Foi — com **três** extensões genéricas
pequenas, todas por dado (listadas abaixo), e **nenhum** sistema próprio do Guerreiro.

```
N1 Doutrina do Guerreiro   v2_doctrine_warrior_1   doctrine             v2_doctrine_warrior          (sem bônus próprio; só abre o N2)
N2 Salão de Armas          v2_doctrine_warrior_2   building             v2_building_warrior_hall     treina a cadeia convencional
N3 Guerreiro               v2_doctrine_warrior_3   unit                 v2_unit_warrior              melee DPS básico
N4 Golpe Poderoso          v2_doctrine_warrior_4   technique (ATIVA)    v2_technique_power_strike    burst de alvo único, com mira
N5 Espadachim              v2_doctrine_warrior_5   unit_upgrade         v2_unit_swordsman            1º upgrade (V2UnitUpgrade)
N6 Ataque em Arco          v2_doctrine_warrior_6   technique (ATIVA)    v2_technique_cleave          até 3 inimigos adjacentes, sem mira
N7 Mestre de Armas         v2_doctrine_warrior_7   unit_upgrade         v2_unit_weapon_master        2º upgrade / forma Elite
N8 Arena dos Campeões      v2_doctrine_warrior_8   mastery_building     v2_building_warrior_mastery  só habilita o Herói
N9 Herói da Lâmina         v2_doctrine_warrior_9   legendary_candidate  v2_legendary_blade_hero      Lendária; slot GLOBAL compartilhado com o Campeão
```

Guardião N1–N9 **e** Guerreiro N1–N9 = `gameplay_connected = true` (18 ids em `V2DoctrineContent.CONNECTED_UNLOCK_IDS`). As outras quatro Doutrinas,
Magia e Infraestrutura seguem só metadata. **Nenhum ID canônico foi alterado.**

### Reutilizado sem alteração (o Guerreiro só entrou como dado)

| Fundação do Guardião | Como o Guerreiro a usa |
|---|---|
| `V2UnlockSystem` (`CONNECTED_TYPES`, toasts, disponibilidade derivada) | os 9 nós aplicam pelo mesmo mapa de tipos; nenhum arquivo tocado |
| `V2UnitLine` (`unit_ids`, `resolve_trainable_form`, `doctrine_branch_of`) | a cadeia Guerreiro→Espadachim→Mestre e "só a forma mais avançada" saem da metadata dos tiers 3-5-7 |
| `V2UnitUpgrade` (alvo por `upgrade_to`, custo `2 × ΔPP`, HP em %, mesma unidade) | 24 Ouro e 32 Ouro **por fórmula**, nenhum valor escrito |
| `V2LegendarySystem` (slot global, reserva por `production_item`, fail-closed) | o Herói é reconhecido por metadata; disputa o **mesmo** slot do Campeão |
| `V2UnitAuras` | intocada (o Herói não tem aura; tem a Execução) |
| Produção normal (`BuildingData.trains_unit`, `requires_building`, `UNIT_TRAINER_FALLBACK`, `PLAYER_TRAINABLE_KINDS`) | Salão de Armas e Arena são `BuildingData` comuns; HUD, IA e `ArmyComposition` os enxergam sem código |
| `V2ResearchDatabase` (`capstone_progress`, `unlock_effect_text`) | Exército Supremo 2/2 e os tooltips saem dos mesmos textos genéricos |
| `SaveManager`, `City`, `GameManager` | **nenhuma alteração**: unidades por `visual_kind`, recarga em `magic_cooldowns`, reserva em `production_item` |

### Generalizado (extensões genéricas — todas por dado, nenhuma cita o Guerreiro)

1. **Técnica ATIVA de ataque** (novo *tipo* de efeito no framework de técnicas, ao lado de "postura" e "passiva"):
   `V2DoctrineTechniqueData.strike_multiplier/strike_targeting/strike_max_targets/strike_range` + `is_strike()`;
   `V2TechniqueRuntime.strike_targets()` e `perform_strike()`; `unavailable_reason/can_use` ganharam o `hex_grid` opcional e o motivo
   "Nenhum inimigo adjacente."; `activate()` recusa técnica de ataque (ela não tem estado — passa por `perform_strike`).
2. **Multiplicador de um golpe** no combate: `CombatResolver.predict/resolve(…, strike_multiplier = 1.0)` — só mais um fator da MESMA fórmula
   (nenhuma segunda fórmula de dano); e a regra **única** de alvo hostil `CombatResolver.can_attack_unit`, que a seleção (`attackable`) e as
   técnicas passaram a compartilhar.
3. **Passiva intrínseca "ataque contra alvo ferido"**: `UnitData.low_hp_attack_name/threshold/bonus` + `UnitAbilities.low_hp_attack_multiplier`
   (entra em `attack_multiplier`, a cadeia de multiplicadores já existente).

Complementos de UI/entrada (também genéricos): modo de mira de técnica de alvo único em `SelectionManager` (`technique_targeting_*`,
`start/cancel_technique_targeting`), ESC em `PauseMenu` cancela a mira antes de abrir a pausa, `HUD` (rótulo "×1.6", dica de mira, linhas da
passiva) e `TileInspector` (fato público da passiva).

### Código específico do Guerreiro (inevitável, só dado/conteúdo)

`UnitDatabase` (4 unidades: Guerreiro, Espadachim, Mestre de Armas, Herói), `BuildingDatabase` (Salão de Armas, Arena e 2 linhas de `UNIT_TRAINER_FALLBACK`),
`V2DoctrineTechniqueDatabase` (2 técnicas), `V2DoctrineContent` (ids conectados e descrições finais). **Nenhuma classe, sistema ou `if id ==` do Guerreiro.**
Um teste varre os arquivos das fundações (sem comentários) e falha se algum citar um id/nome concreto de qualquer Doutrina.

### Definições (**BALANCE PLACEHOLDER**)

| | HP | Ataque | Defesa | Mov. | PP | Modelo (provisório) |
|---|---:|---:|---:|---:|---:|---|
| Guerreiro (N3) | 16 | 5,0 | 3,5 | 2 | 20 | Barbarian ×1,0 |
| Espadachim (N5) | 21 | 7,0 | 4,5 | 2 | 32 | Barbarian ×1,15 |
| Mestre de Armas (N7) | 28 | 9,5 | 5,5 | 2 | 48 | Barbarian ×1,3 |
| **Herói da Lâmina (N9)** | 38 | 12,0 | 7,0 | 2 | 90 | Barbarian ×1,65 |
| *(Guardião: Escudeiro / Guardião / Sentinela / Campeão)* | *18 / 24 / 32 / 44* | *3,0 / 4,0 / 5,0 / 6,5* | *4,5 / 6,0 / 8,0 / 10,0* | *2* | *20 / 32 / 48 / 90* | *Knight ×1,0/1,2/1,4; Barbarian ×1,5* |

Identidade preservada em **todos os níveis** (testado): o Guerreiro tem mais Ataque e menos Defesa/vida que o correspondente do Guardião; o Mestre de Armas tem
mais Ataque (9,5 > 5,0) e menos Defesa (5,5 < 8,0) que a Sentinela, sem ser glass cannon. O Herói é o oposto do Campeão (38/12/7 × 44/6,5/10).

- **Salão de Armas:** 22 PP (igual ao Salão dos Guardiões, pra comparação em playtest), sem upkeep, sem exigir Quartel V1, Salão dos Guardiões nem outra Doutrina;
  treina o Guerreiro e depois a forma mais avançada (uma por vez). Modelo: ferraria do KayKit.
- **Arena dos Campeões:** `mastery_building`, 55 PP (a escala do Bastião), exige o Salão de Armas na mesma cidade, só habilita o Herói. Modelo: campo de tiro do KayKit.
- **Produção:** antes do N5 `Guerreiro — 20 PP`; depois `Espadachim — 32 PP`; depois do N7 `Mestre de Armas — 48 PP` (nunca duas). O Herói é uma produção **separada** na Arena
  (`Herói da Lâmina — 90 PP`); o Mestre de Armas continua treinável.
- **Upgrades:** Guerreiro→Espadachim **24 Ouro** (`2 × (32−20)`); Espadachim→Mestre **32 Ouro** (`2 × (48−32)`), pela fórmula; mesma unidade, HP em %, veterania/XP/abates/recargas/serial preservados.

### Técnicas ATIVAS de ataque

Uma técnica de ataque **não guarda efeito**: é uma **ação resolvida na hora** pelo combate normal (guerra, terreno, Defesas, Muralha, Comando Defensivo, Execução, contra-ataque,
morte, abates/veterania e recompensas são os de sempre). O único estado é a **recarga** (`unit.magic_cooldowns`), que o save já persiste e a evolução de forma já preserva. Zero Mana, zero Ouro;
gasta a ação e zera o movimento. Alvos: **só unidades hostis** pela mesma regra do ataque comum (nunca aliado, civilização em paz, cidade nem covil); monstro neutro conta como alvo.

| | Golpe Poderoso (N4) | Ataque em Arco (N6) |
|---|---|---|
| Multiplicador | **1,60×** o Ataque | **0,75×** por alvo |
| Alvos | 1 inimigo adjacente **à escolha** (modo de mira) | até **3** inimigos adjacentes, **sem mira** |
| Recarga | **3** turnos | **4** turnos |
| Indisponível | sem inimigo adjacente / em recarga / sem ação | idem (0 inimigos: não gasta ação nem recarga) |

- **Mira (Golpe):** o botão **não gasta nada** — entra no modo de mira e destaca os alvos válidos (vermelho); o clique num deles resolve; **outro clique ou ESC** cancela sem consumir ação nem recarga
  (ESC passa por `PauseMenu` antes da pausa; vale só para a mira de técnica).
- **Seleção determinística (Arco, > 3 alvos):** menor **HP percentual** primeiro; desempate pelo menor **`serial_id`** — nunca a ordem incidental de Dictionary/Array; ordem estável entre chamadas.
- **Por alvo:** cada golpe do Arco é um combate completo (Defesa/terreno/efeitos individuais), sem dividir um dano total. Cada alvo que sobrevive **revida** normalmente (o revide do motor sai da Defesa do
  alvo); se o atacante cai num revide, o resto do Arco **não** é executado (a recarga já foi gravada). Cada abate conta **um** XP/abate (`register_kill` por vítima, sem duplicação).
- **Herança:** por Doutrina (`V2UnitLine.doctrine_branch_of`), nunca por lista: Guerreiro, Espadachim, Mestre de Armas **e o Herói** têm as duas; o Guardião não recebe nenhuma. Nada duplicado no dado do Herói (testado).
- **UI:** `Golpe Poderoso ×1.6`, `Ataque em Arco ×0.75` (o multiplicador vem do dado), `(recarga N)` e o motivo no tooltip; o painel mostra "» Escolha o alvo de Golpe Poderoso (ESC cancela) «" durante a mira.

### Execução (passiva intrínseca Lendária do Herói)

Quando o Herói **ataca** (ataque básico ou técnica de ataque) uma unidade com **50% de HP ou menos** (`<=`: exatamente 50% conta), o Ataque recebe **+30%**. Dado de `UnitData`
(`low_hp_attack_threshold = 0.5`, `low_hp_attack_bonus = 0.3`), condição avaliada **por alvo** dentro de `UnitAbilities.attack_multiplier` — o mesmo lugar dos demais multiplicadores:
combina **multiplicativamente** com o Golpe Poderoso (12 × 1,6 × 1,3 no alvo em 50%, valor **não** escrito em lugar nenhum), vale por vítima no Arco (30% → sim, 80% → não, 45% → sim),
não afeta cidade/estrutura/feitiço/dano de terceiros, não é dado a outro Guerreiro nem a outra Lendária (o traço `legendary` sozinho não basta) e não vale quando o Herói é o defensor.
Aparece no painel do dono (`Passiva Lendária — Execução`) e como fato público no inspetor. Nenhum `if blade_hero` no `CombatResolver` (testado por varredura).

### Slot Lendário GLOBAL: Guardião × Guerreiro

Nenhum mecanismo novo: o Herói respeita **uma Lendária ativa OU em produção por civilização** porque o `V2LegendarySystem` já era por metadata. Cenário obrigatório (testado com combate real e na cena):
Guardião N9 + Guerreiro N9 + Bastião + Arena → Campeão ativo → Herói **bloqueado** ("Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização.") → Campeão morre → Herói **disponível**
→ Herói em produção → o Campeão passa a ficar **bloqueado**. Vale também com o Herói ativo, entre cidades, depois de salvar/carregar, com Lendária rival (não bloqueia) e no nascimento simultâneo (fail-closed: a segunda não nasce,
o custo volta, erro claro).

### Exército Supremo

Com Guardião N9 **e** Guerreiro N9 o runtime existente mostra **Doutrinas completas: 2 / 2** e o nó fica **pesquisável**. Pesquisá-lo só **registra** a pesquisa: `v2_military_supremacy_access` continua fora de
`CONNECTED_UNLOCK_IDS`, sem efeito, e `check_victories()` não dispara vitória (testado; `EventBus.victory_achieved` não emite).

### Save / load

Sem schema novo. Salão de Armas/Arena (prédios), formas (por `visual_kind`), **recargas** dos dois golpes (`magic_cooldowns`), o Herói e o slot (derivado de unidades + `production_item`), e a **Execução**
(derivada do tipo) sobrevivem ao ciclo; um Herói **em produção** continua reservando o slot depois do load.

### IA

Sem decisão nova (não pesquisa V2, não compõe, não usa golpes). Compatibilidade: 6 turnos reais com o conteúdo presente sem uso pelos rivais; uma civilização rival recebendo a pesquisa por debug resolve a forma
correta (Mestre de Armas), oferece o Herói respeitando o slot e não crasha.

### Assets

Só o que já existia: Barbarian do KayKit (escalas 1,0/1,15/1,3/1,65 distinguem as quatro formas), ferraria (Salão de Armas) e campo de tiro (Arena) do KayKit. Nenhum asset V1 alterado.

### Testes (+181; suíte completa **2172 / 2172**, 80 scripts)

| Arquivo | Testes | Cobre |
|---|---|---|
| `v2_combat_fixture.gd` | — | base compartilhada (grid de grama, civilizações em guerra, inimigos com HP/Defesa escolhidos, fórmula independente do motor) |
| `test_v2_warrior_hall.gd` | 15 | N1 sem bônus, 9 unlocks aplicados uma vez, Salão bloqueado antes/liberado depois do N2, sem Quartel/Salão dos Guardiões/V1, custo, slot, isolamento por civilização, Guerreiro exige N3 + Salão, fila |
| `test_v2_power_strike.gd` | 26 | dado, ativa≠postura≠passiva, só N4+ e só ramo Guerreiro, adjacente e hostil (aliado/paz/cidade/monstro), 1,60×, previsão==resolução, ação e recarga 3, zero Mana/Ouro, sem estado, falha não altera nada, cadeia de defesa (Muralha, aura), abate uma vez, revide, multiplicador vem do dado |
| `test_v2_cleave.gd` | 25 | dado, N6, 0 alvos (nada consumido), 1/2/3 alvos a 0,75×, >3 determinístico (HP%, serial, estável, teto do dado), aliado/paz/cidade nunca, defesa/terreno/efeitos por alvo, múltiplos abates e XP, atacante que cai, recarga 4, independência do Golpe |
| `test_v2_execution.gd` | 18 | dado só no Herói, limiar >50% / =50% / <50%, básico, Golpe (combina ×), por vítima no Arco, cidade/terceiros/outros Guerreiros/outros Lendários/Herói defensor não recebem, dirigida por dado, sem id na lógica, linhas de UI |
| `test_v2_warrior_line.gd` | 27 | stats e relações (identidade), produção por nível (uma forma), upgrade 24 e 32 Ouro por fórmula, requisitos com motivo, preservação (HP %, veterania, recarga, serial), cadeia completa na mesma unidade, herança das técnicas |
| `test_v2_warrior_mastery_and_hero.gd` | 32 | Arena (dado, requisitos, 55 PP, slot, fila), Herói (stats, fora da cadeia, Mestre segue treinável, técnicas herdadas), **conflito de slot Guardião×Guerreiro** em ambos os sentidos, produção/ativo/morte, rival, reset, fail-closed |
| `test_v2_doctrine_framework_reuse.gd` | 15 | **as mesmas garantias em laço sobre as DUAS Doutrinas** (linha, produção, upgrade, prédios, técnicas, Lendária), tabela de tipos/anúncios/tooltips genéricos, **nenhuma arquitetura paralela** (nomes de arquivo, `class_name`), fundações sem id/nome concreto de Doutrina |
| `test_v2_warrior_flow.gd` | 11 | **fluxo principal ponta a ponta (28 passos)** com mira/ESC/clique, upgrades, Arco cercado, Arena, Herói, Execução, save/load, Guardião N9 → Exército Supremo 2/2 **sem vitória**; mira cancelada de todos os jeitos, recargas persistem, Herói em produção persiste, Herói×Campeão no mesmo turno, IA |
| `test_hud.gd` (+12) | 12 | botões Salão/Arena, uma forma por nível, Herói desabilitado com o motivo do slot, botões `×1.6`/`×0.75`, mira e dica, recarga, Evoluir 24 Ouro, painel do Mestre, painel LENDÁRIO do Herói, Guardião intacto |
| adaptados | — | testes das Fases 1–6 que assumiam o Guerreiro inerte (conectados, "outras Doutrinas", lista de kinds treináveis, técnicas de outras Doutrinas) |

### Validação visual (não-headless, `Main.tscn` real)

Confirmado nas capturas/prints: `Salão de Armas — 22 PP` (aba Construções) → `Guerreiro — 20 PP`; painel do Guerreiro com `Golpe Poderoso ×1.6` **desabilitado com "Nenhum inimigo adjacente."** e habilitado com um inimigo adjacente;
clique no botão → mira ativa (alvo `(3,-5)`, dica "» Escolha o alvo de Golpe Poderoso (ESC cancela) «"); **ESC real pelo pipeline de input** cancelou a mira sem abrir a pausa, sem gastar movimento nem recarga; golpe real 7,70 == previsto 7,70,
movimento 0 e `Golpe Poderoso ×1.6 (recarga 3)`; após o N5 a produção mostra só `Espadachim — 32 PP` e `Evoluir para Espadachim — 24 Ouro` (Ouro 100→76, recarga preservada); após o N7 só `Mestre de Armas — 48 PP`;
`Arena dos Campeões — 55 PP`; com o N9 `Herói da Lâmina — 90 PP` **ao lado** de `Mestre de Armas — 48 PP`; o Herói selecionado: `LENDÁRIO | Herói da Lâmina | HP 37/38 | Ataque 12.0 | Defesa 7.0`, `Passiva Lendária — Execução
+30% de Ataque contra unidades com 50% de HP ou menos.`, e os botões `Golpe Poderoso ×1.6` e `Ataque em Arco ×0.75`; **Execução**: multiplicador 1,3, dano 12,30 (saudável) → 16,44 (em 50%), real 16,44; **Execução + Golpe** previsto 27,20 == real 27,20;
**slot:** com o Herói vivo o `Campeão Guardião` da 2ª cidade fica visível e desabilitado com o motivo; após a morte real do Herói o Campeão volta, e com o Campeão em produção o Herói é que fica bloqueado;
o quadro de pesquisa mostra **Guardião e Guerreiro N1–N9 concluídos** e `Exército Supremo — Doutrinas completas: 2 / 2 (N9) · Disponível · Pesquisar`; `check_victories()` deixou o jogo em `PLAYING`. 62–141 FPS nas capturas.

Ressalvas da validação: (1) no Arco, o log mostrou 3 inimigos de teste "cercando" mas só 2 deles perderam vida — um **monstro neutro já adjacente** (que a captura mostra) entrou entre os 3 alvos (menor serial primeiro) e deixou um dos inimigos de teste de fora; é o corte
de 3 alvos funcionando, não um erro, mas o log do script não separou os dois; (2) o Herói e o Campeão Guardião usam o **mesmo modelo** (Barbarian) em escalas 1,65 e 1,5 — a distinção é por escala e painel, não uma captura lado a lado; (3) o clique no alvo do Golpe foi feito por chamada
direta a `_handle_technique_targeting_click` (a mira, o realce e o ESC foram reais; o clique de mouse em si não foi simulado), coberto por teste; (4) o tooltip do botão bloqueado não aparece em screenshot — o motivo foi impresso e testado.

### Performance

Sem `_process`, timer nem polling; o Arco só olha os **6 tiles adjacentes**; a Execução é uma comparação de HP dentro de `attack_multiplier`. Medido (headless): `UnitAbilities.low_hp_attack_multiplier` = **0,6 µs líquidos** por chamada
(~2,4% de um `CombatResolver.predict` de ~26 µs; o único caminho crítico de combate alterado, mais um fator no produto); `predict` V1 vs V1 25,7 µs; `predict` do Herói 34 µs (4 unidades do dono) / 43,5 µs (30 unidades, inclui a varredura de aura da Fase 6);
`strike_targets` do Arco (3 inimigos) 22 µs; `unavailable_reason` do botão 36 µs e `techniques_for_unit` 13 µs (refresh do painel); `can_attack_unit` 3,1 µs; `perform_strike` do Arco (3 alvos, combate real com popups) ~350 µs. Sem regressão perceptível (as medidas da Fase 6
e desta rodaram em estados de máquina diferentes; o que importa é o custo do que foi acrescentado, acima).

### Limitações (de propósito) e ressalvas

- **Números e modelos provisórios** (todos os da tabela; Salão 22 PP, Arena 55 PP; ferraria/campo de tiro/Barbarian do KayKit). Nenhuma arte nova; o Herói e o Campeão compartilham o modelo (escala diferente).
- **Nome repetido:** o Espadachim V2 tem o nome canônico "Espadachim" — o mesmo do Espadachim V1 (outro `kind`, 26 PP). Numa civilização com as duas linhas liberadas os dois aparecem na produção com o mesmo rótulo e custos diferentes; pedido explícito do nome, sinalizado.
- **Contra-ataques no Arco:** cada alvo que sobrevive revida (regra normal); é possível o atacante cair no meio do Arco (o restante não executa). Não há efeito de "sem revide" nas técnicas.
- **Monstros neutros** adjacentes contam como alvo (mesma regra do ataque comum) e podem ocupar um dos 3 lugares do Arco.
- ESC cancela **apenas** a mira de técnica; não foi alterado o comportamento de ESC nas miras de feitiço/posicionamento de prédio.
- A IA não pesquisa, não constrói o Salão/Arena, não treina o Guerreiro nem usa Golpe/Arco (fase futura).
- O Exército Supremo pode ser pesquisado mas **não tem efeito** e a Vitória por Supremacia V2 não existe.
- Fora do escopo, **não implementado:** Patrulheiro, Cavalaria, Ladino, Cerco, IA estratégica V2, Exército Supremo funcional, vitória, economia/Suprimentos, bônus raciais, Magia, Infraestrutura.
- Fase encerrada quando **a segunda Doutrina completa foi implementada usando o Guardião como molde, confirmando que a arquitetura das Doutrinas V2 é reutilizável.**

---

## Fase 8 — Doutrina do Patrulheiro N1–N9

A **terceira Doutrina completa**, implementada de uma vez sobre o mesmo molde, e a primeira a exercitar **combate ranged** V2. O critério era o da Fase 7 (conteúdo sobre as
fundações, sem subsistema paralelo) mais uma prova nova: o mesmo molde suporta técnicas de ataque **à distância**. Foram necessárias **três** extensões genéricas pequenas,
todas por dado, nenhuma citando o Patrulheiro.

```
N1 Doutrina do Patrulheiro  v2_doctrine_ranger_1  doctrine             v2_doctrine_ranger           (sem bônus próprio; só abre o N2)
N2 Campo dos Patrulheiros   v2_doctrine_ranger_2  building             v2_building_ranger_camp      treina a cadeia convencional
N3 Arqueiro                 v2_doctrine_ranger_3  unit                 v2_unit_archer               ranged DPS básico (alcance 2)
N4 Disparo Preciso          v2_doctrine_ranger_4  technique (ATIVA)    v2_technique_precise_shot    1 alvo, alcance básico + 1, 1,40x, com mira
N5 Caçador                  v2_doctrine_ranger_5  unit_upgrade         v2_unit_hunter               1º upgrade (V2UnitUpgrade)
N6 Saraivada                v2_doctrine_ranger_6  technique (ATIVA)    v2_technique_volley          alvo primário + vizinhos, até 3 no total, 0,70x
N7 Atirador de Elite        v2_doctrine_ranger_7  unit_upgrade         v2_unit_elite_marksman       2º upgrade / forma Elite (alcance básico 3)
N8 Torre dos Patrulheiros   v2_doctrine_ranger_8  mastery_building     v2_building_ranger_mastery   só habilita o Caçador de Lendas
N9 Caçador de Lendas        v2_doctrine_ranger_9  legendary_candidate  v2_legendary_legend_hunter   Lendária; slot GLOBAL das três Doutrinas
```

Guardião, Guerreiro **e** Patrulheiro N1–N9 = `gameplay_connected = true` (27 ids em `V2DoctrineContent.CONNECTED_UNLOCK_IDS`). Cavalaria, Ladino, Cerco, Magia e Infraestrutura seguem só
metadata. **Nenhum ID canônico foi alterado.**

### Reutilizado sem alteração

| Fundação | Como o Patrulheiro a usa |
|---|---|
| `V2UnlockSystem`, `V2ResearchState`, `V2ResearchDatabase` (`capstone_progress`, `unlock_effect_text`) | os 9 nós aplicam pelo mesmo mapa de tipos; tooltips e toasts genéricos; nenhum arquivo tocado |
| `V2UnitLine` (`unit_ids`, `resolve_trainable_form`, `doctrine_branch_of`) | a cadeia Arqueiro→Caçador→Atirador e "só a forma mais avançada" saem da metadata dos tiers 3-5-7 |
| `V2UnitUpgrade` | 24 e 32 Ouro **por fórmula** (`2 × ΔPP`); mesma unidade, HP em %, veterania/XP/serial/recargas preservados |
| `V2LegendarySystem` | o Caçador de Lendas é reconhecido por metadata; **um slot** para Campeão, Herói e Caçador (ativo OU em produção); fail-closed no nascimento |
| `V2UnitAuras`, `V2TechniqueRuntime.activate/expire`, técnicas passivas | intocados |
| Produção normal (`BuildingData.trains_unit`, `requires_building`, `UNIT_TRAINER_FALLBACK`, `PLAYER_TRAINABLE_KINDS`) | Campo e Torre são `BuildingData` comuns; HUD, IA e `ArmyComposition` os enxergam sem código |
| **Combate ranged V1** (`UnitData.attack_range`, `CombatResolver`: sem revide fora do melee, previsão, terreno, XP) | o Arqueiro só declara `attack_range = 2`; o ataque básico é o de sempre |
| Modo de mira das técnicas (`SelectionManager.technique_targeting_*`), ESC em `PauseMenu`, recarga em `magic_cooldowns` | Disparo Preciso e Saraivada usam o mesmo estado; `SaveManager`, `City`, `GameManager` **sem nenhuma alteração** |

### Generalizado (extensões genéricas — todas por dado)

1. **Alcance da técnica de ataque por dado** (`V2DoctrineTechniqueData.strike_range_mode` + `strike_range`): `FIXED` (o melee do Golpe Poderoso, 1 tile) ou `ATTACK_RANGE_PLUS` = alcance
   básico da unidade + bônus. O mesmo dado serve Arqueiro (2 → Disparo a 3), Atirador de Elite (3 → 4) e Caçador de Lendas sem lista de unidades. `V2TechniqueRuntime.strike_range_of`.
2. **Modo "alvo primário + vizinhos"** (`StrikeTargeting.TARGET_AND_NEIGHBORS`, `strike_splash_radius`, `strike_max_targets`): o jogador escolhe o primário; `V2TechniqueRuntime.strike_victims`
   devolve o primário primeiro e depois os hostis ao redor (menor HP% → menor `serial_id`), até o teto. `needs_target()` decide se há mira (nenhum id na `SelectionManager`). Os motivos ganharam
   "Nenhum inimigo ao alcance." para técnicas com alcance > 1.
3. **Passiva "ataque contra alvo de um tipo"** (`UnitData.trait_attack_name/target_traits/bonus`, `UnitAbilities.trait_attack_multiplier`): o irmão da Execução, agora por **lista de traços** do alvo
   (`["legendary"]`); aceita várias categorias futuras sem refatorar. Entra em `attack_multiplier`, a mesma cadeia dos demais fatores.

Complementos genéricos: `HexMetrics.coords_within` (coordenadas em raio por aritmética, sem BFS — o alcance 4 custa 8 µs em vez de 117 µs); visibilidade das técnicas de longo alcance (abaixo);
`UnitAbilities.intrinsic_attack_lines` (uma chamada para as passivas intrínsecas no HUD); rótulos de traços do alvo (`TRAIT_TARGET_LABELS`).

**Visibilidade (regra nova, só para técnicas de alcance > 1):** o alvo precisa estar **visível** para o jogador humano (quando a neblina já foi calculada). O Disparo Preciso do Atirador de Elite chega a 4
tiles; sem isso alcançaria unidades que ninguém enxerga. Para a IA e em partidas sem neblina calculada não há restrição. O ataque básico ranged continua exatamente como na V1.

### Específico do Patrulheiro (só dado/conteúdo)

`UnitDatabase` (4 unidades: Arqueiro, Caçador, Atirador de Elite, Caçador de Lendas), `BuildingDatabase` (Campo, Torre e 2 linhas de `UNIT_TRAINER_FALLBACK`),
`V2DoctrineTechniqueDatabase` (2 técnicas), `V2DoctrineContent` (ids conectados e descrições finais) e a passiva Lendária (dados em `UnitData`). **Nenhuma classe, sistema ou `if id ==` do Patrulheiro.**
Um teste varre os arquivos das fundações (sem comentários) e falha se qualquer um citar id ou nome concreto das três Doutrinas.

### Definições (**BALANCE PLACEHOLDER**)

| | HP | Ataque | Defesa | Mov. | Alcance | Visão | PP | Modelo (provisório) |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Arqueiro (N3) | 13 | 4,5 | 2,5 | 2 | 2 | 3 | 20 | Ranger ×1,0 |
| Caçador (N5) | 17 | 6,5 | 3,0 | 2 | 2 | 3 | 32 | Ranger ×1,15 |
| Atirador de Elite (N7) | 22 | 8,5 | 3,5 | 2 | **3** | **4** | 48 | Ranger ×1,3 |
| **Caçador de Lendas (N9)** | 30 | 11,0 | 4,5 | 2 | 3 | **4** | 90 | Ranger ×1,5 |

- **Fragilidade preservada em todos os níveis** (testado): menos HP e Defesa que o Guardião **e** que o Guerreiro do mesmo nível; o alcance só cresce no N7 e o movimento nunca. O Caçador de Lendas é muito mais frágil
  que o Campeão Guardião (30/4,5 × 44/10,0) e que o Herói da Lâmina.
- **Visão 4 (decisão minha, sinalizada):** o pedido fixa visão 3 só para o Arqueiro. O Atirador de Elite e o Caçador de Lendas ficaram com visão 4 para que o Disparo Preciso (alcance 3 + 1) alcance um alvo
  que eles próprios enxergam; o teste garante `visão >= alcance do Disparo` em todas as formas.
- **Campo dos Patrulheiros:** 22 PP (igual aos outros Salões), sem upkeep, não exige Campo de Tiro/Quartel V1 nem outra Doutrina; treina o Arqueiro e depois a forma mais avançada (uma por vez).
  Modelo: campo de tiro do KayKit. **Torre dos Patrulheiros:** `mastery_building`, 55 PP, exige o Campo na mesma cidade, só habilita o Caçador de Lendas. Modelo: torre A do KayKit.
- **Produção:** antes do N5 `Arqueiro — 20 PP`; depois `Caçador — 32 PP`; depois do N7 `Atirador de Elite — 48 PP` (nunca duas). O Caçador de Lendas é produção **separada** na Torre (90 PP); o Atirador continua treinável.
- **Upgrades:** Arqueiro→Caçador **24 Ouro**; Caçador→Atirador **32 Ouro**, pela fórmula genérica; o **alcance** só muda quando a forma muda (2 → 2 → 3).

### Ranged: como entrou no combate existente

O Arqueiro só declara `attack_range = 2`. Todo o resto é o sistema de V1: alvo hostil em guerra dentro do alcance, previsão == resolução, Defesa/terreno/Muralha/aura, XP e abates, e **nenhum revide**
quando a distância é maior que 1 (só a distância 1 gera revide, pela regra normal). Nenhum `CombatResolver` novo e **nenhuma linha dele foi alterada** nesta fase (o multiplicador de golpe e `can_attack_unit` já existiam da Fase 7).
O ataque básico a 2 tiles foi conferido no jogo (dano real 1,00 == previsto, HP do Arqueiro 13→13, alvo a 3 tiles fora do destaque).

### Técnicas ATIVAS de ataque à distância

| | Disparo Preciso (N4) | Saraivada (N6) |
|---|---|---|
| Multiplicador | **1,40×** | **0,70×** por alvo |
| Mira | 1 alvo à escolha | 1 alvo **primário** à escolha |
| Alcance | alcance básico **+ 1** (Arqueiro/Caçador 3, Atirador/Caçador de Lendas 4) | alcance **básico** (2 / 3), **sem** o +1 |
| Alvos | 1 | primário + inimigos a **1 tile** dele, **até 3 no total** |
| Recarga | 3 turnos | 4 turnos |

Iguais às outras técnicas de ataque: **não guardam efeito**, a ação é resolvida na hora pelo combate normal, só a recarga fica em `magic_cooldowns`, zero Mana/Ouro, gasta a ação e zera o movimento, **ESC/clique fora cancelam sem gastar
nada**, alvo inválido não aplica o ataque, só unidades hostis (nunca aliado, civilização em paz, cidade, muralha, prédio ou covil; monstro hostil conta), abate = um XP por vítima.

- **Saraivada ≠ Ataque em Arco com mais alcance:** o Arco do Guerreiro não tem mira e ataca os adjacentes; a Saraivada parte de um primário escolhido. O primário **sempre entra**, mesmo com HP% maior que os vizinhos.
  Secundários só a 1 tile do **primário** (não do atirador); com mais candidatos, menor HP% e, no empate, menor `serial_id` — nunca a ordem de Dictionary. Cada vítima é uma resolução completa (Defesa, terreno, Muralha,
  Comando Defensivo e Caçada individuais). Revide segue a regra normal: só quem estiver a distância 1 do atirador revida; se o atacante cai, o resto não executa.
- **Herança por Doutrina** (`doctrine_branch_of`): as quatro formas do Patrulheiro herdam as duas; Guardião/Guerreiro não recebem nenhuma; nada duplicado no dado do Caçador de Lendas.

### Caçada Lendária (passiva intrínseca Lendária do Caçador de Lendas)

Contra um alvo cujo dado tem o **traço** `legendary`, o Ataque do Caçador de Lendas recebe **+40%** (ataque básico, Disparo Preciso e **cada vítima** da Saraivada). Dado de `UnitData`
(`trait_attack_target_traits = ["legendary"]`, `trait_attack_bonus = 0.4`), avaliado em `UnitAbilities.attack_multiplier`; combina **multiplicativamente** com o multiplicador do golpe (11 × 1,4 × 1,4 no Disparo em uma Lendária — valor não
escrito em lugar nenhum). Identifica o alvo **pelo traço**: Campeão Guardião, Herói da Lâmina e outro Caçador de Lendas recebem; Sentinela, Mestre de Armas etc. não; uma unidade de teste com id desconhecido e o traço recebe;
uma com o id/nome do Campeão **sem** o traço não. Não vale contra cidade, quando o Caçador é o defensor, nem para terceiros; funciona igual numa civilização rival. A lista aceita outros traços (boss, monster…) sem refatorar; **só** `legendary` está ligado.
Aparece no painel (`Passiva Lendária — Caçada Lendária / +40% de Ataque contra Unidades Lendárias.`) e como fato público no inspetor. Nenhum `if legend_hunter` no `CombatResolver` (testado por varredura).

### Slot Lendário GLOBAL: as três Doutrinas

Nenhum mecanismo novo. Cenário obrigatório (testado com combate real e na cena): Bastião + Arena + Torre → Campeão ativo → Herói **e** Caçador bloqueados → Campeão morre → Caçador em produção na Torre → Campeão e Herói bloqueados
(na outra cidade; a cidade produtora não se bloqueia) → cancelar libera os três → Herói em produção → Campeão e Caçador bloqueados. Vale com qualquer dos três ativo, entre cidades, depois de salvar/carregar, com Lendária rival
(não bloqueia) e no nascimento simultâneo (fail-closed: o segundo não nasce, o custo volta, erro claro).

### Exército Supremo

Com Guardião, Guerreiro e Patrulheiro completos o `capstone_progress` mostra **2 / 2** (o contador é limitado pelo requisito de duas Doutrinas) e o nó segue **pesquisável**. O efeito
(`v2_military_supremacy_access`) continua inerte e nenhuma vitória foi conectada (`check_victories()` deixa o jogo em `PLAYING`).

### Save / load

Sem schema novo. Campo/Torre (prédios), formas (por `visual_kind`), **recargas** dos dois tiros (`magic_cooldowns`), o Caçador de Lendas e o slot (derivado de unidades + `production_item`) e a **Caçada** (derivada do tipo/traço) sobrevivem ao
ciclo; um Caçador de Lendas **em produção** continua reservando o slot depois do load.

### IA

Sem decisão nova (não pesquisa V2, não compõe, não usa técnicas). Compatibilidade: 6 turnos reais com o conteúdo presente sem uso pelos rivais; uma civilização rival recebendo a pesquisa por debug resolve a forma correta (Atirador de Elite),
oferece o Caçador de Lendas respeitando o slot e executa o Disparo Preciso pelo runtime sem crash.

### Assets

Só o que já existia: o **Ranger** do KayKit (o mesmo do Arqueiro V1) em escalas 1,0/1,15/1,3/1,5 distingue as quatro formas — o Caçador de Lendas é o único Lendário em modelo diferente dos outros dois (Barbarian); campo de tiro
e torre A do KayKit para Campo e Torre. Nenhum asset V1 alterado.

### Testes (+169; suíte completa **2341 / 2341**, 87 scripts)

| Arquivo | Testes | Cobre |
|---|---|---|
| `test_v2_ranger_hall.gd` | 21 | N1 sem bônus, 9 unlocks, Campo bloqueado antes/liberado depois do N2 e independente de V1/outras Doutrinas, custo/slot/isolamento, Arqueiro (stats, N3 + Campo, fila, kind salvo), **ataque básico ranged** (alcance 2, sem revide, revide em melee, defesa/XP, seleção a 2 e não a 3) |
| `test_v2_precise_shot.gd` | 28 | dado, ativa≠postura≠passiva, N4 e só ramo Patrulheiro, **alcance por dado** (3 / 4, rejeição a +1, `strike_range` vindo do dado), hostilidade (aliado/paz/cidade/monstro), **visibilidade**, 1,40×, previsão==resolução, sem revide a distância, ação, recarga 3, defesa (Muralha/aura), abate, herança |
| `test_v2_volley.gd` | 29 | dado, ≠ Arco do Guerreiro, N6/ramo, alcance básico (sem +1), primário sempre incluído e primeiro, 1/2/3 alvos a 0,70×, **>3 determinístico** (HP%, serial, estável), só raio 1 do primário, teto/raio pelo dado, aliados/paz/cidades nunca, monstros, Defesa/Muralha/aura individuais, abates/XP, revide só a distância 1, atacante que cai, recarga 4 |
| `test_v2_ranger_line.gd` | 24 | stats e relações (fragilidade em todos os níveis), alcance 2→2→3, visão ≥ alcance do Disparo, produção por nível, upgrade 24/32 por fórmula com motivos, preservação, cadeia completa, ataque básico a 3 e Disparo a 4 sem exceção específica, herança |
| `test_v2_ranger_mastery_and_hunter.gd` | 26 | Torre (dado, requisitos, 55 PP, slot, fila), Caçador de Lendas (stats, frágil vs Campeão, fora da cadeia, Atirador segue treinável, herança), **slot entre as três Doutrinas passo a passo**, ativo/morte/rival/reset/fail-closed |
| `test_v2_legend_hunt.gd` | 18 | dado só no Caçador de Lendas, alvo por **traço** (não id/nome), Campeão/Herói/outro Caçador sim, Sentinela etc. não, lista de traços, uma vez só, básico/Disparo (×)/**Saraivada por vítima**, defensor/cidade/terceiros, rival igual, sem id na lógica, linhas de UI |
| `test_v2_ranger_flow.gd` | 10 | **fluxo principal (38 passos)** com fog real, ataque a 2, Disparo a 3 (mira/ESC/clique), upgrades, Saraivada em agrupamento, alcance 3/4, Torre, Caçador, Caçada, save/load, slot; mira cancelada de todos os jeitos, alvo na neblina, recargas persistem, Lendária em produção persiste, Caçador×Campeão no mesmo turno, IA |
| `test_v2_doctrine_framework_reuse.gd` | 15 | **as mesmas garantias em laço sobre as TRÊS Doutrinas** (linha, produção, upgrade, prédios, técnicas, Lendária, tooltips) e fundações sem id/nome concreto de nenhuma |
| `test_hud.gd` (+13) | 13 | botões Campo/Torre, uma forma por nível, Caçador de Lendas desabilitado por **qualquer** outra Lendária, botões `×1.4`/`×0.7`, motivo "Nenhum inimigo ao alcance.", mira e dica, alcance 3/4, recarga, Evoluir 24 Ouro, painéis do Atirador e LENDÁRIO do Caçador de Lendas |
| adaptados | — | testes das Fases 1–7 que assumiam o Patrulheiro inerte |

### Validação visual (não-headless, `Main.tscn` real, uma execução)

Confirmado nas capturas/prints: `Campo dos Patrulheiros — 22 PP` (aba Construções) → `Arqueiro — 20 PP`; painel do Arqueiro com **`Alcance de ataque: 2`**; alvo a 2 tiles destacado (realce laranja no mapa) e o de 3 tiles não;
ataque básico a 2 tiles: dano real 1,00 == previsto, **sem revide** (HP 13→13); N4: botão `Disparo Preciso ×1.4`, **mira** com o alvo a 3 tiles destacado e o de 4 não, dica "» Escolha o alvo de Disparo Preciso (ESC cancela) «",
**ESC real pelo pipeline de input** cancelou sem abrir a pausa, sem gastar movimento nem recarga; tiro real 4,80 == previsto 4,80, recarga 3; após o N5 só `Caçador — 32 PP` e `Evoluir para Caçador — 24 Ouro` (Ouro 100→76, recarga preservada);
N6: `Saraivada ×0.7`, mira só dentro do alcance básico, agrupamento de 4 → **3 vítimas**, perda de HP por vítima [2,3; 2,3; 2,3] == previsto, o 4º intacto, recarga 4; N7: só `Atirador de Elite — 48 PP`, alcance 3 (alvo a 3 destacado, a 4 não), **Disparo Preciso com o alvo a 4 destacado**;
`Torre dos Patrulheiros — 55 PP`; com o N9 `Caçador de Lendas — 90 PP` ao lado do Atirador; o Caçador selecionado: `LENDÁRIO | Caçador de Lendas | HP 30/30 | Ataque 11.0 | Defesa 4.5 | Alcance de ataque: 3`,
`Passiva Lendária — Caçada Lendária / +40% de Ataque contra Unidades Lendárias.` e os dois botões; **Caçada**: multiplicador 1,0 (comum) e 1,4 (Campeão Guardião), dano previsto 9,20 × 10,40, real 10,40;
**slot:** com o Caçador vivo o Campeão **e** o Herói ficam visíveis e desabilitados com o motivo; após a morte real o slot libera; com o Herói em produção o Campeão e o Caçador é que ficam bloqueados; o quadro de pesquisa mostra as três Doutrinas concluídas e o Exército Supremo `2 / 2 · Disponível`;
`check_victories()` deixou o jogo em `PLAYING`. 84–116 FPS nas capturas de jogo.

Ressalvas: (1) o clique no alvo foi feito por chamada direta a `_handle_technique_targeting_click` (mira, realce e ESC foram reais); (2) o realce dos alvos é uma tinta laranja discreta no hexágono, visível nas capturas do ataque básico e da mira, mas fácil de perder na câmera afastada —
os alvos destacados foram também conferidos por dados (`technique_target_coords`); (3) o motivo do botão bloqueado aparece no tooltip (não em screenshot), conferido por print e por teste; (4) o FPS medido na última captura (quadro de pesquisa em tela cheia, com o jogo aberto por baixo) foi baixo (23) — os
demais ficaram entre 84 e 116, sem relação com esta fase; (5) o Caçador de Lendas nasce no tile vizinho do prédio, como as demais unidades (spawn V1).

### Performance

Sem `_process`, timer nem polling; sem varredura do mapa: o Disparo Preciso só olha o **alcance necessário** (`HexMetrics.coords_within`) e a Saraivada só o primário e os **6 tiles adjacentes** a ele; a Caçada é uma consulta de traço dentro de `attack_multiplier`.
Medido (headless): `UnitAbilities.trait_attack_multiplier` = **0,6 µs líquidos** por chamada (~2% de um `CombatResolver.predict` de ~29 µs — o único caminho crítico de combate tocado); `predict` do Caçador de Lendas contra Lendária 38 µs;
`strike_targets` do Disparo (alcance 4) **76 µs** (o BFS `tiles_in_range(4)` sozinho custava 118 µs; `coords_within(4)` custa 8 µs), da Saraivada 56 µs, `strike_victims` 86 µs; `unavailable_reason` do botão (refresh do painel) 89 µs; `techniques_for_unit` 13 µs;
`perform_strike` da Saraivada (3 alvos, combate real com popups) ~430 µs. Sem regressão perceptível.

### Limitações (de propósito) e ressalvas

- **Números e modelos provisórios** (todos os da tabela; Campo 22 PP, Torre 55 PP; Ranger/campo de tiro/torre do KayKit). Nenhuma arte nova; visão 4 do Atirador de Elite e do Caçador de Lendas é decisão minha (acima).
- **Nome repetido:** o Arqueiro V2 tem o nome canônico "Arqueiro" — o mesmo do Arqueiro V1 (outro `kind`, 18 PP). Numa civilização com as duas linhas liberadas os dois aparecem na produção com o mesmo rótulo e custos diferentes; dívida transitória V1/V2, não resolvida (pedido explícito).
- **Visibilidade só nas técnicas de alcance > 1** (regra nova); o ataque básico ranged não checa neblina, como na V1.
- **Saraivada e revide:** um secundário a distância 1 do atirador revida; o primário adjacente também. Nenhuma técnica remove o revide.
- **Monstros neutros** hostis contam como alvos (mesma regra do ataque comum) e podem ocupar vagas da Saraivada.
- O contador do Exército Supremo é limitado pelo requisito (2 / 2), mesmo com as três Doutrinas completas.
- A IA não pesquisa, não constrói o Campo/Torre, não treina a linha nem usa Disparo/Saraivada (fase futura).
- Fora do escopo, **não implementado:** Cavalaria, Ladino, Cerco, IA estratégica V2, Exército Supremo funcional, vitória, economia/Suprimentos, bônus raciais, Magia, Infraestrutura.
- Fase encerrada quando **a terceira Doutrina completa foi implementada sobre o mesmo molde, confirmando que a arquitetura V2 também suporta combate ranged sem criar um subsistema paralelo.**

## Fase 9 — Doutrina da Cavalaria N1–N9

A **quarta Doutrina completa**, implementada de uma vez sobre o mesmo molde. O critério era o das Fases 7–8 (conteúdo sobre as fundações, sem subsistema paralelo) mais uma prova nova e mais dura: o mesmo molde
suporta **mobilidade**, técnicas de **mover-e-atacar**, **alvo por tile** e uma unidade que **voa** — sem `CavalryCombatSystem`, `CavalryMovementSystem`, `CavalryTechniqueRuntime`, `CavalryUpgradeSystem`,
`CavalryLegendarySystem`, `FlyingCombatResolver` nem fila de produção própria. Foram necessárias **seis** extensões genéricas pequenas, todas por dado, nenhuma citando a Cavalaria.

```
N1 Doutrina da Cavalaria    v2_doctrine_cavalry_1  doctrine             v2_doctrine_cavalry           (sem bônus próprio; só abre o N2)
N2 Estábulo de Guerra       v2_doctrine_cavalry_2  building             v2_building_war_stable        treina a cadeia convencional
N3 Cavaleiro                v2_doctrine_cavalry_3  unit                 v2_unit_cavalier              mobilidade + traço montado (Mov. 4)
N4 Carga                    v2_doctrine_cavalry_4  technique (ATIVA)    v2_technique_charge           MOVER-E-ATACAR: alvo a 2–4 tiles, rota real, 1,50x
N5 Cavaleiro de Choque      v2_doctrine_cavalry_5  unit_upgrade         v2_unit_shock_cavalier        1º upgrade (V2UnitUpgrade)
N6 Retirada Tática          v2_doctrine_cavalry_6  technique (ATIVA)    v2_technique_tactical_retreat REPOSICIONA por TILE (até 3 passos) + 20% de Defesa
N7 Cavaleiro Blindado       v2_doctrine_cavalry_7  unit_upgrade         v2_unit_armored_cavalier      2º upgrade / forma Elite convencional
N8 Ordem da Cavalaria       v2_doctrine_cavalry_8  mastery_building     v2_building_cavalry_mastery   só habilita o Cavaleiro de Grifo
N9 Cavaleiro de Grifo       v2_doctrine_cavalry_9  legendary_candidate  v2_legendary_griffon_rider    Lendária VOADORA; slot GLOBAL das quatro Doutrinas
```

As quatro Doutrinas militares completas = `gameplay_connected = true` (36 ids em `V2DoctrineContent.CONNECTED_UNLOCK_IDS`). Ladino, Cerco, Magia e Infraestrutura seguem só metadata. **Nenhum ID canônico foi alterado.**

### Reutilizado sem alteração

| Fundação | Como a Cavalaria a usa |
|---|---|
| `V2UnlockSystem`, `V2ResearchState`, `V2ResearchDatabase` (`capstone_progress`, `unlock_effect_text`) | os 9 nós aplicam pelo mesmo mapa de tipos; tooltips e toasts genéricos; nenhum arquivo tocado |
| `V2UnitLine` (`unit_ids`, `resolve_trainable_form`, `doctrine_branch_of`) | a cadeia Cavaleiro→Choque→Blindado e "só a forma mais avançada" saem da metadata dos tiers 3-5-7; o Grifo herda as técnicas por `doctrine_branch_of` |
| `V2UnitUpgrade` | 28 e 36 Ouro **por fórmula** (`2 × ΔPP`); mesma unidade, HP em %, veterania/XP/serial/recargas/status preservados |
| `V2LegendarySystem` | **zero linhas alteradas**: o Grifo é reconhecido por metadata (`legendary_candidate`); **um slot** para Campeão, Herói, Caçador de Lendas e Grifo (ativo OU em produção); fail-closed no nascimento (varredura de teste: o arquivo não conhece a Cavalaria) |
| `V2TechniqueRuntime.activate/expire_finished`, `magic_status`, `_finish_turn` | a Retirada Tática guarda o **mesmo** estado de postura da Muralha de Escudos (`magic_status` + `self_defense_bonus` pela cadeia de defesa que já existia): expira no início do próximo turno do dono, aparece no painel, marca com o anel e trava o upgrade sem uma linha nova |
| `CombatResolver.resolve/predict` (Defesa, terreno, Muralha, aura, veterania, flanco, revide, morte, XP) | a Carga é **um golpe normal** com o multiplicador da técnica, depois de a unidade mover; a **única** linha nova em `predict` é o fator de vulnerabilidade (extensão 5 abaixo) |
| Modo de mira das técnicas (`SelectionManager.technique_targeting_*`), ESC em `PauseMenu`, recarga em `magic_cooldowns` | Carga e Retirada usam o mesmo estado; `SaveManager`, `City`, `GameManager` **sem nenhuma alteração** nesta fase |
| Traço `mounted` + Preparar Lanças (Fase 5) | as quatro formas o declaram **no dado**; o Preparar Lanças do Guardião as contraria sem uma linha de integração entre as Doutrinas |
| Produção normal (`BuildingData.trains_unit`, `requires_building`, `UNIT_TRAINER_FALLBACK`, `PLAYER_TRAINABLE_KINDS`) | Estábulo e Ordem são `BuildingData` comuns; HUD, IA e `ArmyComposition` os enxergam sem código |
| Movimento V1 (`HexGrid.compute_reachable/compute_path/move_unit`, `UnitData.flies`) | a unidade terrestre chama exatamente o mesmo Dijkstra de sempre; o voo V1 (grifo/elemental/monstros) não foi tocado |

### Generalizado (extensões genéricas — todas por dado)

1. **Mover-e-atacar por dado** (`V2DoctrineTechniqueData.strike_reposition` = `MOVE_ADJACENT_TO_TARGET`, `strike_min_range`): a técnica de ataque pode exigir que o alvo esteja a `min..max` tiles e que a unidade
   **percorra a rota** até um tile adjacente antes de golpear. `V2TechniqueRuntime.strike_targets` (janela + "existe tile de aproximação"), `_approach_tile` (escolha determinística), `perform_strike` (move de verdade com
   `grid.move_unit` e resolve pelo combate normal) e `_no_target_reason` ("Requer espaço para realizar a Carga." / "Sem rota até um tile adjacente ao alvo."). Golpe Poderoso, Ataque em Arco, Disparo Preciso e Saraivada
   **não mudam** (defaults: `repositions() == false`, `strike_min_range == 1`; teste).
2. **Alvo por tile / reposicionamento por dado** (`TargetMode {UNIT, TILE}`, `relocate_range`, `relocate_flat_cost`): `V2TechniqueRuntime.relocation_tiles/relocate/target_coords/perform_targeted` (um ponto de entrada
   único para golpe ou reposicionamento); `SelectionManager` destaca e confirma um **tile** ou uma **unidade** pelo mesmo estado (`technique_target_coords`); a dica da HUD troca "alvo" por "tile". `_commit_activation` é
   compartilhado com a ativação de postura.
3. **Perfil de movimento** (`UnitData.MovementProfile {GROUND, FLYING}`): `HexGrid.unit_reachable(unit, budget, flat_cost)` escolhe entre o Dijkstra de sempre e `flight_reachable`; `compute_reachable` ganhou o parâmetro
   `flat_cost` (cada passo custa 1, ignorando o custo do terreno — mesmas regras de bloqueio); `flight_path` + `HexMetrics.axial_line` só animam o voo. O perfil é do **dado**; unidade terrestre = mesma chamada de antes
   (testado por igualdade de resultado). O voo V1 (`flies`) continua um mundo à parte.
4. **Traço `flying`** semeado do perfil em `UnitDatabase.create_unit` (mesmo padrão de `mounted`/`legendary`): a pergunta "voa?" das regras futuras (clima) é um traço. `UnitData.is_flying()` cobre o voo V1 e o novo.
5. **Vulnerabilidade a ataques à distância por dado** (`UnitData.ranged_damage_taken_bonus`, `UnitAbilities.ranged_vulnerability_multiplier`): **um fator** dentro de `CombatResolver.predict` — o defensor declara o bônus e o
   atacante conta como "à distância" quando o seu `attack_range > 1`. Nenhuma unidade citada.
6. **`visual_template`** (`UnitData` + `Unit._build_procedural_body`): uma unidade V2 reaproveita o corpo procedural de um visual V1 ("cavalry", "griffin"), diferenciada pela escala. Sem arte nova.

Complementos genéricos: `UnitAbilities.flight_text` e a linha "Vulnerável a ataques à distância…" no painel do dono; `TileInspector.unit_traits` ganhou "Voa" e "Vulnerável à distância" (fatos públicos, por dado);
`SelectionManager` usa `unit_reachable` ao selecionar, e **não** aceita ordem de movimento de vários turnos para unidade FLYING.

### Específico da Cavalaria (só dado/conteúdo)

`UnitDatabase` (4 unidades: Cavaleiro, Choque, Blindado, Grifo), `BuildingDatabase` (Estábulo, Ordem e 2 linhas de `UNIT_TRAINER_FALLBACK`), `V2DoctrineTechniqueDatabase` (2 técnicas),
`V2DoctrineContent` (ids conectados e descrições finais). **Nenhuma classe, sistema ou `if id ==` da Cavalaria.** Testes varrem os arquivos das fundações (sem comentários) e falham se qualquer um citar id ou nome
concreto das quatro Doutrinas, ou se existir arquivo/classe `Cavalry*`/`FlyingCombatResolver`.

### Definições (**BALANCE PLACEHOLDER**)

| | HP | Ataque | Defesa | Mov. | Visão | PP | Traços | Modelo (provisório) |
|---|---:|---:|---:|---:|---:|---:|---|---|
| Cavaleiro (N3) | 17 | 5,0 | 3,0 | **4** | 4 | 24 | montado | corpo "cavalry" V1 ×1,0 |
| Cavaleiro de Choque (N5) | 22 | 7,0 | 4,0 | 4 | 4 | 38 | montado | "cavalry" ×1,15 |
| Cavaleiro Blindado (N7) | 30 | 8,5 | 6,0 | 4 | 4 | 56 | montado | "cavalry" ×1,3 |
| **Cavaleiro de Grifo (N9)** | 36 | 10,0 | 6,5 | **5** (voo) | **5** | 100 | montado + voa + Lendário | corpo "griffin" V1 ×1,4 |

- **Identidade = mobilidade e choque, nunca o tank nem o dano puro** (testado): o dobro do movimento do Guerreiro/Espadachim/Mestre de Armas do mesmo nível, o **mesmo** Ataque do Guerreiro/Espadachim, menos Defesa e
  vida que o Escudeiro/Guardião/Sentinela; o Blindado (30 HP / 6,0) **nunca supera a Sentinela** (32 / 8,0) e leva mais dano que ela do mesmo golpe. O Grifo é menos que o Campeão (44 / 10,0) e que o Herói (Ataque 12).
- **Estábulo de Guerra:** 22 PP (igual aos outros Salões), sem upkeep, **não** exige o Estábulo V1, o Quartel nem outra Doutrina; treina o Cavaleiro e depois a forma mais avançada (uma por vez). Modelo: mercado azul do KayKit.
  **Ordem da Cavalaria:** `mastery_building`, 55 PP, exige o Estábulo na mesma cidade, só habilita o Grifo. Modelo: torre de catapulta azul do KayKit.
- **Produção:** antes do N5 `Cavaleiro — 24 PP`; depois `Cavaleiro de Choque — 38 PP`; depois do N7 `Cavaleiro Blindado — 56 PP` (nunca duas). O Grifo é produção **separada** na Ordem (100 PP); o Blindado continua treinável.
- **Upgrades:** Cavaleiro→Choque **28 Ouro**; Choque→Blindado **36 Ouro**, pela fórmula genérica. O Blindado **não** evolui para o Grifo (o Grifo não está na cadeia).
- **Traço montado:** as **quatro** formas o declaram no dado (`has_trait("mounted")`); a classificação nunca é por nome/id (teste: um "Guerreiro" renomeado para "Cavaleiro" não é montado; uma unidade de id desconhecido **com** o traço é).

### Carga (N4) — o primeiro mover-e-atacar

Ativa, com mira: o jogador escolhe um inimigo **visível a 2–4 tiles**; a unidade percorre a rota e o ataca na mesma ação a **1,50×** (dado: `strike_multiplier`), pelo `CombatResolver` normal.

- **Espaço:** inimigo adjacente **sozinho** → indisponível com "Requer espaço para realizar a Carga."; um inimigo adjacente **não** impede a Carga contra outro alvo mais longe.
- **Rota real, sem teletransporte:** o tile de aproximação é um vizinho **livre e alcançável** do alvo pelo alcance de movimento restante da unidade (terreno impassável, ocupação e cidade inimiga valem; terrestre não atravessa água).
  Escolha **determinística**: menor **custo real** de caminho → menos **passos** → coordenada estável (menor q, depois menor r) — nunca a ordem de Dictionary (testado, inclusive com o dicionário invertido).
  Sem rota → indisponível ("Sem rota até um tile adjacente ao alvo."), **sem movimento parcial e sem recarga**.
- **A unidade termina de verdade adjacente** (`grid.move_unit`: posição, grid e animação); depois vêm Defesa, terreno, Muralha, aura, veterania, revide (agora a distância 1, então existe), morte, XP e recompensas do combate normal.
  Previsão == resolução; o revide de um alvo de Defesa alta foi conferido pela fórmula.
- **Custos:** gasta a ação e zera o movimento (mesmo com pontos sobrando), recarga **3** (conta o turno de uso), **zero Mana e zero Ouro**, não guarda efeito. **ESC/clique fora cancelam** sem mover, sem gastar ação e sem recarga.
- **Preparar Lanças:** não há integração — o Escudeiro/Guardião simplesmente golpeia qualquer unidade com o traço `mounted` (as quatro formas e o Grifo) com o bônus da técnica passiva, e a Carga contra um Guardião usa só o Ataque do Cavaleiro ×1,5.

### Retirada Tática (N6) — o primeiro alvo por tile

Ativa, com mira **de tile**: o jogador escolhe um tile **livre a até 3 passos**; cada passo custa **1 ignorando o custo do terreno**, mas **nunca** atravessa terreno impassável ou unidade (sem teletransporte; sem ZOC —
uma unidade engajada ainda pode recuar). A unidade se move de verdade, gasta a ação (movimento 0), recarga **4**, e ganha **+20% de Defesa até o início do próximo turno do dono** (mesmo `magic_status` da Muralha:
expira sozinho, anel no mapa, bloqueia o upgrade enquanto ativo, sobrevive ao save/load e à troca de forma). Zero Mana/Ouro; ESC cancela sem gastar nada. Sem tiles livres → "Nenhum tile livre ao alcance.".
Uma unidade cercada de terreno impassável **não** consegue recuar (o terrestre); o Grifo sim.

### Voo tático (Cavaleiro de Grifo)

Regras (decisões abaixo):

- **Alcance:** até o Movimento (5) em **distância geométrica** (`HexMetrics.coords_within`, só o raio de movimento — **sem BFS global**), por cima de **qualquer terreno e de qualquer unidade no meio do caminho**.
- **Pouso legal (decisão, documentada):** o Grifo **termina** apenas num tile que uma unidade terrestre poderia ocupar — nunca água, lava, montanha, tile ocupado, cidade inimiga ou estrutura de covil. Assim save/load, combate,
  cidades, propriedade de tile e o resto do jogo seguem as mesmas regras de qualquer unidade (sem "unidade flutuando sobre o oceano").
- **Carga e Retirada aéreas** usam o mesmo código com o perfil aéreo (nenhum `if flying` nas técnicas): a Carga continua com janela 2–4 (o Movimento 5 não amplia o alcance da técnica); a Retirada continua com raio 3.
  Cavalaria terrestre **barrada** por uma barreira de água não faz a Carga ("Sem rota…"); o Grifo a faz por cima e pousa no tile de terra adjacente de menor custo.
- **Terrestre inalterado:** `unit_reachable` de uma unidade GROUND é exatamente o `compute_reachable` de antes (testado por igualdade de resultado, com terreno caro/água/unidades no mapa); o voo V1 (`flies`) e a IA seguem iguais.
- **Sem ordens de vários turnos** para FLYING (pathfinding terrestre da fila não se aplica). A IA trata a unidade como terrestre (não planeja voo — limitação abaixo).
- **Clima (futuro, não implementado):** os ganchos são o traço `flying` e o perfil `FLYING` (dado); nenhuma regra de clima foi escrita.

### Vulnerabilidade a ataques à distância (Grifo)

O Grifo recebe **+25% de dano de ataques físicos à distância**, por **dado** (`ranged_damage_taken_bonus = 0.25`). "À distância" = o atacante tem `attack_range > 1` num ataque unidade contra unidade: o ataque básico do
Arqueiro/Atirador, o **Disparo Preciso**, **cada vítima** da **Saraivada** (e máquinas de cerco). **Não** vale para melee (inclusive técnicas melee como o Golpe Poderoso), feitiços (não passam por `predict`), cidade nem dano
ambiental; não altera o revide nem o ataque do próprio Grifo. O fator multiplica **depois** do piso de dano (`max(1, ataque − defesa/2) × 1,25`). Uma unidade de teste com id desconhecido e o **mesmo dado** também recebe;
um Grifo com o dado zerado não. `predict == resolve`; só o Grifo (não o Cavaleiro comum) na Saraivada. Aparece no painel do dono e como fato público no inspetor.

### Slot Lendário GLOBAL: as quatro Doutrinas

Nenhum mecanismo novo e **nenhuma alteração em `V2LegendarySystem`**. Cenário obrigatório (testado com combate real): Campeão ativo → Herói, Caçador de Lendas **e** Grifo bloqueados → Campeão morre → Grifo em produção na Ordem →
os outros três bloqueados (na outra cidade; a cidade produtora não se bloqueia) → cancelar libera os quatro → Herói em produção → Campeão, Caçador e Grifo bloqueados. Cada um dos quatro ativo bloqueia os outros três;
vale entre cidades, depois de salvar/carregar, com Lendária rival (não bloqueia), depois do reset de debug e no nascimento simultâneo (fail-closed: o segundo não nasce, o custo volta, erro claro).

### Exército Supremo

Com as quatro Doutrinas completas o `capstone_progress` mostra **2 / 2** (o contador é limitado pelo requisito) e o nó segue **pesquisável**. O efeito (`v2_military_supremacy_access`) continua inerte e nenhuma vitória foi
conectada (`check_victories()` deixa o jogo em `PLAYING`).

### Save / load

Sem schema novo. Estábulo/Ordem (prédios), formas e perfil de voo (por `visual_kind`, o dado recria `movement_profile`/`ranged_damage_taken_bonus`/traços), **recargas** da Carga e da Retirada, o **status ativo** da Retirada
(e sua expiração no turno certo depois do load), o Grifo e o slot (derivado de unidades + `production_item`) sobrevivem ao ciclo; um Grifo **em produção** continua reservando o slot depois do load; o voo continua voo
e o chão continua chão depois do load (conferido por `unit_reachable`).

### IA

Sem decisão nova (não pesquisa V2, não constrói Estábulo/Ordem, não compõe, não usa técnicas, **não planeja voo**). Compatibilidade: 6 turnos reais com o conteúdo presente sem uso pelos rivais; uma civilização rival
recebendo a pesquisa por debug resolve a forma correta (Blindado), oferece o Grifo respeitando o slot, executa a **Carga** pelo runtime, tem um Grifo no mapa por 3 turnos de IA sem crash (a IA o trata como unidade
terrestre no pathfinding) e não pode produzir uma segunda Lendária.

### Assets

Só o que já existia: o corpo procedural **"cavalry"** do V1 (cavalo + cavaleiro na cor da civilização) em escalas 1,0/1,15/1,3 distingue as três formas convencionais; o corpo procedural **"griffin"** do V1 (asas + corpo)
em ×1,4 é o **placeholder do Grifo**; mercado azul e torre de catapulta azul do KayKit para Estábulo e Ordem. **Nenhum asset V1 alterado e nenhum asset novo.**

### Testes (+221; suíte completa **2562 / 2562**, 94 scripts)

| Arquivo | Testes | Cobre |
|---|---:|---|
| `test_v2_cavalry_hall.gd` | 18 | N1 sem bônus, 9 unlocks, Estábulo bloqueado antes/liberado depois do N2 e independente de V1/outras Doutrinas, custo/slot/isolamento, Cavaleiro (stats, mobilidade ≠ dano vs Guerreiro, movimento 4 pelo Dijkstra normal, terreno/ocupação), N3 + Estábulo + fila, **traço `mounted` nas 4 formas** (não por nome), **Preparar Lanças** (multiplicador e combate real, previsão == resolução), sem id de Cavalaria na lógica |
| `test_v2_charge.gd` | 52 | dado, N4/ramo/herança (4 formas + Grifo; V1 e outras Doutrinas nunca), janela 2/3/4 (adjacente → "Requer espaço"; 5 fora), aliado/paz/cidade/monstro, **visibilidade**, unidade termina adjacente com a posição atualizada, **tile de aproximação** (menor custo → menos passos → coordenada; ordem de dicionário invertida), impassável/água/ocupação/cerco total, rota limitada pelo movimento restante, 1,50×, previsão == resolução, ação/recarga 3/zero Mana e Ouro, sem movimento parcial nem recarga em falha, Defesa/terreno/Muralha/aura, abate/XP, revide após chegar, morte no revide, Preparar Lanças, **as outras técnicas de ataque intactas**, motivo com o grid da partida (bug pego pelo teste de HUD) |
| `test_v2_tactical_retreat.gd` | 32 | dado (TILE, raio 3, custo plano, +20%, recarga 4), N6/herança, 36 tiles em raio 3 (nenhum a 4), ordem estável, **custo 1 ignorando o terreno**, impassável/unidade/água/ocupado, cercado → "Nenhum tile livre ao alcance.", **sem ZOC**, move de verdade, parcial 1/2/3, ação/recarga 4, falha não muda nada, um único uso por turno com a Carga, status = `magic_status` da Muralha (ativo/anel/expira no próximo turno do dono/recarga segue), +20% pela cadeia de defesa (previsão == resolução), não empilha, bloqueia o upgrade, sobrevive à troca de forma |
| `test_v2_cavalry_line.gd` | 30 | stats e relações (mobilidade preservada, Blindado nunca supera a Sentinela), escalas provisórias, V1 intacto, produção por nível (uma forma), Grifo fora da cadeia, custos, upgrade 28/36 por fórmula com motivos, preservação (HP %, XP, veterania, recargas, status), cadeia completa, herança |
| `test_v2_cavalry_mastery_and_griffon.gd` | 27 | Ordem (dado, requisitos, 55 PP, slot, fila), Grifo (stats, 3 traços + perfil + vulnerabilidade por dado, menos que as outras Lendárias, fora da cadeia, Blindado segue treinável, herança), sistema do slot sem palavra de Cavalaria, **slot entre as QUATRO Doutrinas passo a passo**, cada um dos quatro bloqueia os outros três, rival/reset/fail-closed |
| `test_v2_flight.gd` | 34 | perfil só no Grifo e traço só com o perfil, **chão idêntico ao chamado antigo**, voo V1 intacto, alcance geométrico, por cima de água/montanha/unidades, **pouso só legal** (água/lava/montanha/gelo/ocupado/cidade inimiga; cidade própria ok), alcance × movimento restante, **sem BFS global** (varredura), move/linha de voo/animação, **Carga aérea** (terrestre barrada pelo mar × Grifo passa; por cima de unidades; nunca pousa na água; desempate estável; janela 2–4), **Retirada aérea** (cercado por montanhas), **vulnerabilidade** (básico à distância +25%, melee/Golpe Poderoso não, Disparo Preciso, Saraivada por vítima, dado e não id, texto, só o combate a usa) |
| `test_v2_cavalry_flow.gd` | 10 | **fluxo principal (46 passos)** com fog real: N1…N9, Carga (mira/ESC/clique, adjacente sozinho, rota), upgrades, Retirada de tile (mira/ESC/clique/efeito/expiração), Ordem, Grifo, alcance de voo no mapa gerado, **arena com anel de oceano** (Carga e Retirada aéreas), +25% à distância, save/load, slot das 4 Doutrinas; mira cancelada de todos os jeitos, alvo na neblina, recarga/status persistem, Grifo em produção persiste, Grifo×Campeão no mesmo turno, sem ordem de vários turnos p/ voo, IA |
| `test_v2_doctrine_framework_reuse.gd` | 18 | as mesmas garantias em laço sobre as **QUATRO Doutrinas** (linha, produção, upgrade, prédios, técnicas, Lendária, tooltips) e as fundações **sem id/nome concreto** de nenhuma; **sem sistema paralelo** (`Cavalry*`, `FlyingCombatResolver`); as extensões da fase são campos de dado com defaults inertes |
| `test_hud.gd` (+15) | 15 | botões Estábulo/Ordem, uma forma por nível, Grifo desabilitado por **qualquer** outra Lendária, `Carga ×1.5`/`Retirada Tática`, motivos (sem alvo / "Requer espaço…"), mira e dicas (alvo × tile), recarga/"Ativa", Evoluir 28/36 Ouro, painéis do Blindado e LENDÁRIO do Grifo (voo + vulnerabilidade), alcance de voo, outras Doutrinas intactas |
| adaptados | — | testes das Fases 1–8 que assumiam a Cavalaria inerte (`test_v2_doctrine_content`, `_research_database`, `_unlock_system`, `_legendary_system`, `_brace_spears`, `_shield_wall`, `_sentinel`, `_guardian_n9_flow`) |

### Validação visual (não-headless, `Main.tscn` real, uma execução)

Confirmado nas capturas/prints: `Estábulo de Guerra — 22 PP` (aba Construções) → `Cavaleiro — 24 PP`; painel do Cavaleiro `HP 17/17 | Ataque 5.0 | Defesa 3.0 | Movimento 4.0/4.0`; N4: botão `Carga ×1.5`, **mira** com os alvos
`[(2,1), (4,-1), (6,-1), (0,2)]` destacados e a dica "» Escolha o alvo de Carga (ESC cancela) «"; **ESC real pelo pipeline de input** cancelou sem abrir a pausa, sem mover, sem gastar movimento nem recarga; a Carga real levou
o Cavaleiro de (3,2) para (1,2), **adjacente ao alvo**, dano real 6,00 == previsto 6,00, recarga 3, movimento 0; `Evoluir para Cavaleiro de Choque — 28 Ouro` (Ouro 200→172, recarga da Carga preservada: 2); N6: `Retirada Tática`,
mira de **tile** (14 tiles, dica "» Escolha o tile de Retirada Tática (ESC cancela) «"), Retirada real (2,2)→(3,4) a distância 3, `Retirada Tática — Ativa (até o início do próximo turno)`, recargas 1 e 4 no painel; `Evoluir para
Cavaleiro Blindado — 36 Ouro` → 30/8,5/6,0, mov. 4; `Ordem da Cavalaria — 55 PP`; com o N9 `Cavaleiro de Grifo — 100 PP` **ao lado** de `Cavaleiro Blindado — 56 PP`; painel do Grifo `LENDÁRIO | … HP 36/36 | Ataque 10.0 | Defesa 6.5 |
Movimento 5.0/5.0`, `Voo tático: atravessa terreno e unidades; pousa só em terra livre.`, `Vulnerável a ataques à distância: +25% de dano recebido.`; alcance de voo **68 tiles × 58** do chão no mesmo ponto; **Carga aérea** no mapa gerado:
de (2,-12) para (-1,-8), adjacente, em terra, dano real 14,625 == previsto 14,625; arqueiro × Grifo `11,91 / 9,53 = 1,25`; **slot:** com o Grifo vivo o Campeão, o Herói, o Caçador de Lendas **e** o próprio Grifo ficam visíveis e desabilitados com o
motivo; o quadro de pesquisa mostra as quatro Doutrinas e o Exército Supremo `2 / 2`; `check_victories()` deixou o jogo em `PLAYING`. 68–121 FPS nas capturas de jogo (42 na última, quadro de pesquisa em tela cheia).

Ressalvas: (1) o clique no alvo/tile foi feito por chamada direta a `_handle_technique_targeting_click` (mira, realce e ESC foram reais); (2) **na captura o modelo do Grifo aparece** (corpo azul com asas abertas, como o grifo V1), mas é pequeno na câmera
padrão — o Cavaleiro das três formas é o corpo de cavalo V1 e as formas só se distinguem pela escala; (3) a geometria "barreira de água" da Carga aérea foi **provada nos testes** (anel de oceano na arena); no mapa gerado o script achou uma Carga só aérea a partir do
tile do Grifo, mas o Blindado terrestre foi posto num tile vizinho de onde a rota existia, então essa comparação **não** foi feita visualmente; (4) o motivo do botão bloqueado aparece no tooltip (não em screenshot), conferido por print e por teste;
(5) o Grifo estava "Veterano (1 abates)" por ter destruído um esqueleto que cercava a cidade (evento normal da partida), o que entra na previsão (×1,1); (6) o realce dos alvos é uma tinta discreta no hexágono, também conferido por dados.

### Performance

Sem `_process`, timer nem polling; sem varredura do mapa: a Carga só olha o **raio da técnica** (`HexMetrics.coords_within`) e um Dijkstra de movimento (uma vez por consulta), a Retirada só o raio 3, o voo só o **raio de movimento**.
Medido (headless, mapa de raio 20, 30 inimigos na janela da Carga): `strike_targets` da Carga (Cavaleiro) **1,45 ms** (o Dijkstra de movimento 4 sozinho custa ~0,6 ms; o teste do alvo + tile de aproximação, 5 µs cada), do Grifo **0,55 ms**;
`unavailable_reason` do botão (refresh do painel) 1,4 ms; `relocation_tiles` da Retirada **0,41 ms** (terrestre) / **0,19 ms** (voo); `flight_reachable` (raio 5) **0,35 ms**; `flight_path` 8 µs.
**Pathfinding terrestre antes × depois** (cópia do `compute_reachable` sem `flat_cost` × o atual, mov. 4, três passadas interpoladas): 590–690 µs × 580–670 µs — **igual**; `unit_reachable` do Guerreiro V2 (mov. 2) 427 µs contra 425 µs da cópia.
Seleção de unidade (`SelectionManager._select_unit`): V1 1,34 ms, Cavaleiro 1,82 ms, Grifo 1,27 ms. `CombatResolver.predict` 60 µs (Cavaleiro) / 44 µs (contra o Grifo); o novo `ranged_vulnerability_multiplier` custa **0,9 µs**
por chamada (~1,5% do `predict` — o único caminho crítico de combate tocado). Sem regressão perceptível.

### Limitações (de propósito) e ressalvas

- **Números e modelos provisórios** (todos os da tabela; Estábulo 22 PP, Ordem 55 PP; corpos "cavalry"/"griffin" V1 e prédios KayKit). Nenhuma arte nova; o Grifo é um **placeholder** (o corpo do grifo V1 em escala 1,4).
- **"Ignorar o custo do terreno" só é observável com terreno de teste:** hoje **todo** terreno do jogo custa 1 de movimento (`movement_cost = 1`); a regra (custo plano por passo) está implementada e testada com tiles de custo 2, mas no jogo real ela ainda
  coincide com o movimento normal (o que a Retirada muda de verdade hoje é o alcance fixo de 3 passos, independente dos pontos de movimento que sobraram).
- **Voo sem pouso na água** (decisão): o Grifo só termina em terra livre; um Grifo não "paira" sobre o oceano.
- **A IA não entende voo:** trata a unidade FLYING como terrestre no pathfinding e não usa Carga/Retirada; a compatibilidade (sem crash, slot respeitado) foi conferida, o comportamento inteligente é fase futura.
- **Sem ordem de movimento de vários turnos** para unidades voadoras (cliques distantes não enfileiram).
- **Vulnerabilidade a distância aplica depois do piso de dano:** um golpe de dano mínimo (1) vira 1,25 contra o Grifo.
- **Carga e visibilidade:** para o humano, o alvo precisa estar visível (mesma regra das técnicas de alcance > 1); a IA não tem restrição.
- **Um inimigo adjacente indisponibiliza a Carga só contra ele:** contra outro alvo mais longe a Carga segue disponível (o espaço exigido é do avanço).
- O contador do Exército Supremo é limitado pelo requisito (2 / 2), mesmo com as quatro Doutrinas completas.
- **Bug encontrado e corrigido pelos testes de HUD:** `V2TechniqueRuntime._no_target_reason` ignorava o grid da partida quando chamado sem grid (como a HUD faz), mostrando "Nenhum inimigo ao alcance." em vez de "Requer espaço para realizar a Carga.".
- Fora do escopo, **não implementado:** Ladino, Cerco, IA estratégica V2, Exército Supremo funcional, vitória, economia/Suprimentos, upkeep, bônus raciais, Magia, Infraestrutura, clima.
- Fase encerrada quando **a quarta Doutrina completa foi implementada sobre o mesmo molde, estendendo a arquitetura V2 para mobilidade, move-then-strike, tile targeting e voo sem criar um subsistema paralelo.**


## Fase 10 — Doutrina do Ladino N1–N9

A **quinta Doutrina completa**, implementada de uma vez sobre o mesmo molde. O critério era o das Fases 7–9 (conteúdo sobre as fundações, sem subsistema paralelo) mais três
provas novas e mais duras: penetração de Defesa e supressão de contra-ataque como PARÂMETROS genéricos da mesma fórmula de combate, uma passiva com **múltiplos** traços-alvo
(generalização da Fase 5), e um TERCEIRO perfil de movimento (infiltração) que atravessa unidades mas nunca terreno impassável — distinto tanto do chão quanto do voo tático da
Fase 9. Foram necessárias **cinco** extensões genéricas pequenas, todas por dado, nenhuma citando o Ladino.

```
N1 Doutrina do Ladino      v2_doctrine_rogue_1  doctrine             v2_doctrine_rogue           (sem bônus próprio; só abre o N2)
N2 Guilda dos Ladinos      v2_doctrine_rogue_2  building             v2_building_rogue_guild     treina a cadeia convencional
N3 Ladino                  v2_doctrine_rogue_3  unit                 v2_unit_rogue               melee frágil e móvel (Mov. 3)
N4 Ataque Furtivo          v2_doctrine_rogue_4  technique (ATIVA)    v2_technique_sneak_attack   1,35x, 40% de penetração de Defesa, SEM revide
N5 Sabotador               v2_doctrine_rogue_5  unit_upgrade         v2_unit_saboteur            1º upgrade (V2UnitUpgrade)
N6 Desmantelar             v2_doctrine_rogue_6  technique (PASSIVA)  v2_technique_dismantle      +50% de Ataque vs. traço `caster` OU `siege`
N7 Assassino               v2_doctrine_rogue_7  unit_upgrade         v2_unit_assassin            2º upgrade / forma Elite convencional
N8 Refúgio das Sombras     v2_doctrine_rogue_8  mastery_building     v2_building_rogue_mastery   só habilita o Mestre das Sombras
N9 Mestre das Sombras      v2_doctrine_rogue_9  legendary_candidate  v2_legendary_shadow_master  Lendário INFILTRATOR; slot GLOBAL das cinco Doutrinas
```

As cinco Doutrinas militares completas = `gameplay_connected = true` (45 ids em `V2DoctrineContent.CONNECTED_UNLOCK_IDS`). Cerco segue só metadata. **Nenhum ID canônico foi alterado.**

### Reutilizado sem alteração

| Fundação | Como o Ladino a usa |
|---|---|
| `V2UnlockSystem`, `V2ResearchState`, `V2ResearchDatabase` (`capstone_progress`, `unlock_effect_text`) | os 9 nós aplicam pelo mesmo mapa de tipos; tooltips e toasts genéricos; nenhum arquivo tocado |
| `V2UnitLine` (`unit_ids`, `resolve_trainable_form`, `doctrine_branch_of`) | a cadeia Ladino→Sabotador→Assassino e "só a forma mais avançada" saem da metadata dos tiers 3-5-7; o Mestre herda as técnicas por `doctrine_branch_of` |
| `V2UnitUpgrade` | 24 e 32 Ouro **por fórmula** (`2 × ΔPP`); mesma unidade, HP em %, veterania/XP/serial/recargas preservados |
| `V2LegendarySystem` | **zero linhas alteradas**: o Mestre é reconhecido por metadata (`legendary_candidate`); **um slot** para as cinco Lendárias (ativo OU em produção); fail-closed no nascimento (varredura de teste: o arquivo não conhece o Ladino) |
| `CombatResolver.resolve/predict` (Defesa, terreno, Muralha, aura, veterania, flanco, morte, XP) | o Ataque Furtivo é **um golpe normal** com dois fatores a mais (penetração, sem-revide); Desmantelar entra pela cadeia já existente de `UnitAbilities.attack_multiplier` |
| Modo de mira das técnicas (`SelectionManager.technique_targeting_*`), ESC em `PauseMenu`, recarga em `magic_cooldowns` | Ataque Furtivo usa o mesmo estado de alvo-em-unidade das outras técnicas de ataque; `SaveManager`, `City`, `GameManager` **sem nenhuma alteração** nesta fase |
| `HexGrid.compute_reachable/compute_path/move_unit`, `reconstruct_path`, `_last_came_from` | o perfil INFILTRATOR reaproveita a MESMA infraestrutura de Dijkstra/reconstrução de rota do chão — nenhuma função de movimento pré-existente foi tocada além do `match` de despacho |
| Produção normal (`BuildingData.trains_unit`, `requires_building`, `UNIT_TRAINER_FALLBACK`, `PLAYER_TRAINABLE_KINDS`) | Guilda e Refúgio são `BuildingData` comuns; HUD, IA e `ArmyComposition` os enxergam sem código |
| `UnitAbilities.MOUNTED`/`SIEGE` (Fases 5/V1) | `SIEGE` é reaproveitada DIRETAMENTE para semear o traço `siege` — mesmo padrão exato do traço `mounted` |
| `UnitData.magic_school` (V1) | reaproveitado DIRETAMENTE para semear o traço `caster` — a única classificação de conjurador que já existia (o "Mago" V1, apesar do nome, não tem `magic_school` e por isso **não** é classificado; documentado como achado do design V1, não corrigido) |

### Generalizado (extensões genéricas — todas por dado)

1. **Penetração de Defesa** (`V2DoctrineTechniqueData.strike_defense_penetration`, fração 0–1): `CombatResolver.predict/resolve` ganharam esse parâmetro a mais (como `strike_multiplier`
   na Fase 7) — a Defesa do alvo é multiplicada por `(1 − penetração)` **antes** da mitigação, só NAQUELE golpe (o revide, se houver, usa a Defesa cheia). 0,0 (todas as técnicas
   anteriores) = comportamento idêntico a antes; nenhuma correção pós-cálculo, nenhuma segunda fórmula.
2. **Supressão de contra-ataque por golpe** (`V2DoctrineTechniqueData.strike_prevents_counterattack`): mais um parâmetro em `predict/resolve` — quando `true`, o bloco de revide
   simplesmente não roda NAQUELE golpe (`damage_to_attacker = 0`, `attacker_dies = false`), reaproveitando o MESMO caminho que já existia pra "revide zero" (defensor de Defesa
   baixa); o alvo sobrevivente não ganha nenhum status e volta a revidar normalmente no próximo combate.
3. **Passiva com múltiplos traços-alvo** (`V2DoctrineTechniqueData.basic_attack_target_trait` (String) generalizado para `basic_attack_target_traits` (Array[String])):
   `V2TechniqueRuntime.attack_multiplier` agora testa "o alvo tem QUALQUER traço da lista" (`_has_any_trait`), contando uma vez mesmo com dois traços batendo. Preparar Lanças (Fase 5)
   migrou para `["mounted"]` sem mudar de comportamento; a migração foi a MENOR generalização suficiente (nenhum campo novo, só o tipo do existente).
4. **Traços `caster`/`siege`** (`UnitData.TRAIT_CASTER`, `UnitData.TRAIT_SIEGE`), semeados em `UnitDatabase._seed_traits` (a mesma função que já semeava `mounted`/`legendary`/`flying`,
   agora compartilhada pelos DOIS caminhos de `create_unit` — o normal e o early-return de `MagicContent` — sem o que magos/invocações nunca ganhariam `caster`).
5. **Perfil de movimento INFILTRATOR** (`UnitData.MovementProfile.INFILTRATOR`, terceiro valor do enum da Fase 9): `HexGrid.infiltrate_reachable` (Dijkstra por dado, como
   `compute_reachable`, mas unidades no meio do caminho não bloqueiam — só o destino precisa estar livre; terreno impassável continua impassável); `unit_reachable` despacha pelos três
   perfis; `_animation_waypoints` usa `reconstruct_path` (não `compute_path`, que bloquearia nas unidades atravessadas) — o mesmo mecanismo que já existia pra reconstruir a rota do chão.

Complementos genéricos: `UnitAbilities.infiltration_text` (texto do painel, nunca menciona "voo"); `TileInspector.unit_traits` ganhou "Passo Sombrio (atravessa unidades)";
`SelectionManager` estendeu os dois guardas que já existiam pra FLYING (pré-visualização de rota longa e ordens de vários turnos) pra também excluir INFILTRATOR — mesma decisão da
Fase 9, agora coberta pelos dois perfis não-GROUND.

### Específico do Ladino (só dado/conteúdo)

`UnitDatabase` (4 unidades: Ladino, Sabotador, Assassino, Mestre das Sombras), `BuildingDatabase` (Guilda, Refúgio e 2 linhas de `UNIT_TRAINER_FALLBACK`), `V2DoctrineTechniqueDatabase`
(2 técnicas), `V2DoctrineContent` (ids conectados e descrições finais). **Nenhuma classe, sistema ou `if id ==` do Ladino.** Testes varrem os arquivos das fundações (sem comentários) e
falham se qualquer um citar id ou nome concreto das cinco Doutrinas, ou se existir arquivo/classe `Rogue*`/`StealthCombatResolver`.

### Definições (**BALANCE PLACEHOLDER**)

| | HP | Ataque | Defesa | Mov. | Visão | PP | Traços | Modelo (provisório) |
|---|---:|---:|---:|---:|---:|---:|---|---|
| Ladino (N3) | 14 | 4,5 | 2,5 | **3** | 4 | 20 | — | Rogue (KayKit) ×1,0 |
| Sabotador (N5) | 18 | 6,0 | 3,0 | 3 | 4 | 32 | — | Rogue ×1,15 |
| Assassino (N7) | 23 | 8,0 | 3,5 | 3 | 4 | 48 | — | Rogue ×1,3 |
| **Mestre das Sombras (N9)** | 30 | 10,5 | 4,5 | **4** (infiltração) | 5 | 95 | legendary | Rogue ×1,45 |

- **Identidade = fragilidade e mobilidade, nunca o tanque nem o dano frontal** (testado): menos HP, Defesa e Ataque que o Guerreiro do mesmo nível; mais Movimento; o Assassino
  (8,0 Ataque / 3,5 Defesa) nunca supera o Mestre de Armas (9,5 / 5,5) num confronto frontal sustentado, nem qualquer forma defensiva de outra linha.
- **Guilda dos Ladinos:** 22 PP (igual aos outros Salões), sem upkeep, não exige outra Doutrina; treina o Ladino e depois a forma mais avançada (uma por vez). Modelo: moinho do
  KayKit. **Refúgio das Sombras:** `mastery_building`, 55 PP, exige a Guilda na mesma cidade, só habilita o Mestre das Sombras. Modelo: torre A do KayKit (a mesma da Torre dos
  Patrulheiros).
- **Produção:** antes do N5 `Ladino — 20 PP`; depois `Sabotador — 32 PP`; depois do N7 `Assassino — 48 PP` (nunca duas). O Mestre das Sombras é produção **separada** no Refúgio
  (95 PP); o Assassino continua treinável.
- **Upgrades:** Ladino→Sabotador **24 Ouro**; Sabotador→Assassino **32 Ouro**, pela fórmula genérica.
- **Modelo reaproveitado sem conflito:** o `Rogue.glb` do KayKit já era usado pelo Batedor V1 (`scout`) — mesmo padrão de reuso de Barbarian.glb/Ranger.glb nas Fases 7–8, só a escala
  distingue as quatro formas.

### Ataque Furtivo (N4) — penetração de Defesa e supressão de contra-ataque, como dado

Ativa, com mira: o jogador escolhe um inimigo **adjacente**; a unidade o ataca a **1,35×** o Ataque, com **40% da Defesa do alvo ignorada** e **sem revide** naquela resolução —
tudo pelo `CombatResolver` normal, com dois parâmetros a mais na MESMA fórmula.

- **Penetração:** `damage_to_defender = max(1, Ataque×mult − Defesa×(1−0,4)×0,5) × vulnerabilidade`. Testado isoladamente (fixture genérica, sem Ladino) e junto da Muralha/aura do
  defensor (a penetração reduz a Defesa ANTES de qualquer outro efeito de defesa multiplicar o resultado — a Muralha ainda ajuda, só que sobre uma base já reduzida).
- **Sem revide:** o defensor, se sobreviver, **não** ganha nenhum status — pode agir normalmente no turno dele e volta a revidar normalmente no próximo combate (testado: um alvo de
  Defesa altíssima que normalmente mataria o atacante no revide não causa NENHUM dano quando o golpe é o Ataque Furtivo, mas revida contra um ATAQUE COMUM de outra unidade logo em
  seguida). Vale também contra um alvo que seria "ranged" — a supressão é da resolução, não do tipo de unidade.
- **Custos:** gasta a ação e zera o movimento; recarga **3** (conta o turno de uso); **zero Mana e zero Ouro**; não guarda efeito (só a recarga). **ESC/clique fora cancelam** sem
  gastar nada. Alvo inválido não aplica o ataque; só unidades hostis (nunca aliado, civilização em paz, cidade, muralha, prédio ou covil; monstro hostil conta).
- **Herança por Doutrina:** as quatro formas do Ladino (incluindo o Mestre das Sombras) herdam o Ataque Furtivo; nenhuma outra Doutrina o recebe.

### Desmantelar (N6) — passiva com múltiplos traços-alvo

+50% de Ataque contra qualquer unidade com o traço `caster` OU `siege` (uma vez, mesmo com os dois) — ataque básico e **qualquer golpe físico da linha** (Ataque Furtivo incluso),
avaliado na MESMA cadeia de `UnitAbilities.attack_multiplier` das outras passivas (Preparar Lanças, Execução, Caçada Lendária). Sem botão, custo, recarga ou estado guardado; deriva
de pesquisa + linha + traço do alvo, então save/load, unidades antigas e IA funcionam sem passo extra.

- **Origem dos traços (auditoria, não lista nova):** `caster` vem de `UnitData.magic_school != ""` — a MESMA classificação que `TileInspector.unit_class_label`/`MagicRuntime` já
  usam para "isto é um conjurador?" (testado com o Clérigo V1 real). `siege` vem de `UnitAbilities.SIEGE` — a MESMA lista que já dá o bônus de dano de máquina de cerco contra
  cidade (testado com a Catapulta V1 real). Nenhuma lista nova foi criada; um conjurador ou máquina de Cerco V2 futuros só precisam declarar o dado existente.
- **Achado do design V1 (documentado, não corrigido):** o "Mago" V1 (`kind == "mage"`) NÃO tem `magic_school` definido (é uma unidade ranged mundana com o nome "Mago", nunca ligada
  a nenhuma Escola) — por isso **não** recebe o traço `caster`, apesar do nome. A classificação é pelo DADO, nunca pelo nome; o teste que prova isso usa o "Mago" exatamente para
  mostrar essa distinção.
- **Futuro Magia/Cerco V2:** quando existirem, um conjurador V2 só precisa declarar `magic_school` (ou o traço direto); uma máquina de Cerco V2 só precisa declarar o traço `siege`
  — Desmantelar passa a valer contra eles automaticamente, sem nenhuma integração nova (testado com fixtures de id arbitrário e com uma unidade de teste "futura" construída à mão).

### Passo Sombrio e o perfil INFILTRATOR (Mestre das Sombras)

Regras (decisões documentadas):

- **Atravessa unidades:** aliadas OU inimigas, no meio do caminho — cada tile atravessável custa **1**, ignorando o custo de terreno. **Nunca termina** num tile ocupado (o próprio
  tile-alvo precisa estar livre).
- **Nunca atravessa terreno realmente impassável** (água, lava, montanha) — nem como destino, nem como passagem. Essa é a diferença central com FLYING (Fase 9): o voo tático ignora
  terreno por completo (inclusive no meio do caminho); a infiltração só ignora UNIDADES. Um teste dedicado prova os três perfis lado a lado contra a MESMA obstrução dupla (parede
  de unidades + parede de água): GROUND fica bloqueado pela parede de unidades; INFILTRATOR atravessa as unidades mas para na água; FLYING atravessa as duas.
- **Não é teleporte:** a unidade percorre uma sequência real de tiles (`HexGrid.infiltrate_reachable` grava os predecessores como `compute_reachable`; a animação usa
  `reconstruct_path`, não `compute_path`, que bloquearia nas unidades atravessadas). Mover até esgotar a ação segue a regra normal — atravessar unidades não dá nenhum ataque ou
  ação extra grátis.
- **Cidade inimiga continua bloqueando** por completo (como para GROUND); cidade própria é destino legal.
- **Sem ordens de vários turnos e sem pré-visualização de rota longa** para INFILTRATOR — mesma decisão já tomada para FLYING na Fase 9 (os dois mecanismos usam `compute_path`
  simples, que não conhece nenhum dos dois perfis especiais); agora os dois guardas em `SelectionManager` cobrem ambos.
- **Infiltração até a backline (cenário obrigatório):** com uma linha de frente inimiga ocupando uma coluna inteira e um conjurador logo atrás, um Assassino convencional não tem
  rota; o Mestre das Sombras atravessa a linha, termina num tile livre adjacente à backline e, em situação válida de turno, usa o Ataque Furtivo (com Desmantelar) contra o
  conjurador — sem teleporte, com a rota real conferida por `reconstruct_path`.

### Slot Lendário GLOBAL: as cinco Doutrinas

Nenhum mecanismo novo e **nenhuma alteração em `V2LegendarySystem`**. Cenário obrigatório (testado com combate real): Campeão ativo → Herói, Caçador de Lendas, Cavaleiro de Grifo
**e** Mestre das Sombras bloqueados → Campeão morre → Mestre em produção no Refúgio → os outros quatro bloqueados (na outra cidade; a cidade produtora não se bloqueia) → cancelar
libera os cinco → Herói em produção → Campeão, Caçador, Grifo e Mestre bloqueados. Cada um dos cinco ativo bloqueia os outros quatro; vale entre cidades, depois de salvar/carregar,
com Lendária rival (não bloqueia), depois do reset de debug e no nascimento simultâneo (fail-closed: o segundo não nasce, o custo volta, erro claro).

### Exército Supremo

Com as cinco Doutrinas completas o `capstone_progress` mostra **2 / 2** (o contador é limitado pelo requisito) e o nó segue **pesquisável**. O efeito
(`v2_military_supremacy_access`) continua inerte e nenhuma vitória foi conectada (`check_victories()` deixa o jogo em `PLAYING`).

### Save / load

Sem schema novo. Guilda/Refúgio (prédios), formas e perfil de movimento (por `visual_kind`, o dado recria `movement_profile`/traços), **recarga** do Ataque Furtivo, o Mestre das
Sombras e o slot (derivado de unidades + `production_item`) sobrevivem ao ciclo; um Mestre **em produção** continua reservando o slot depois do load; a infiltração continua
infiltração e o chão continua chão depois do load (conferido por `unit_reachable`); Desmantelar (derivado do traço do alvo) funciona sem nenhum dado salvo extra.

### IA

Sem decisão nova (não pesquisa V2, não constrói Guilda/Refúgio, não compõe, não usa técnicas, **não planeja infiltração nem escolhe alvos prioritários**). Compatibilidade: 6 turnos
reais com o conteúdo presente sem uso pelos rivais; uma civilização rival recebendo a pesquisa por debug resolve a forma correta (Assassino), oferece o Mestre das Sombras
respeitando o slot, executa o **Ataque Furtivo** pelo runtime sem crash, e um Mestre da IA sobrevive 3 turnos de IA no mapa sem crash (a IA o trata como unidade terrestre no
pathfinding, mesma limitação documentada do voo na Fase 9).

### Assets

Só o que já existia: o `Rogue.glb` do KayKit (já usado pelo Batedor V1) em escalas 1,0/1,15/1,3/1,45 distingue as quatro formas; moinho e torre A do KayKit para Guilda e Refúgio.
**Nenhum asset V1 alterado e nenhum asset novo.**

### Testes (+237; suíte completa **2728 / 2728**, 108 scripts)

| Arquivo | Testes | Cobre |
|---|---:|---|
| `test_v2_rogue_hall.gd` | 18 | N1 sem bônus, 9 unlocks, Guilda bloqueada antes/liberada depois do N2 e independente de outras Doutrinas, custo/slot/isolamento, Ladino (stats, fragilidade+mobilidade vs Guerreiro, movimento 3 pelo Dijkstra normal, terreno/ocupação), N3 + Guilda + fila |
| `test_v2_sneak_attack.gd` | 32 | dado (1,35×, 40% penetração, sem revide), N4/ramo/herança, adjacente e hostil, **penetração isolada da fórmula** (não correção pós-cálculo), previsão==resolução, ação/recarga 3/zero Mana e Ouro, ESC, falha não muda nada, **sem revide** (alvo sobrevive sem status, revida normal depois, alvo "ranged" também suprimido, atacante nunca morre no revide suprimido), cadeia normal de defesa (Muralha/aura/penetração juntas), abate/XP, outras técnicas com penetração/sem-revide zerados por padrão |
| `test_v2_dismantle.gd` | 18 | passiva sem botão/custo/recarga, N6/herança pelas 4 formas, isolamento por civilização, fixture caster/siege reconhecidas por TRAÇO (não nome/id), origem real (Clérigo V1 tem `magic_school`, "Mago" V1 não; Catapulta V1 está em `SIEGE`), caster+siege não duplica, unidade futura só precisa declarar o dado, previsão==resolução, combina com penetração/sem-revide do Ataque Furtivo, nunca afeta dano de cidade |
| `test_v2_rogue_line.gd` | 28 | stats e relações (fragilidade em todos os níveis, Assassino nunca vence de frente), produção por nível, upgrade 24/32 por fórmula com motivos, preservação (HP%, veterania, recarga, serial), cadeia completa, herança das técnicas |
| `test_v2_rogue_mastery_and_shadow_master.gd` | 27 | Refúgio (dado, requisitos, 55 PP, slot, fila), Mestre das Sombras (stats, traço Lendário + perfil INFILTRATOR por dado, menos que as outras Lendárias, fora da cadeia, Assassino segue treinável, herança), sistema do slot sem palavra do Ladino, **slot entre as CINCO Doutrinas passo a passo**, cada um dos cinco bloqueia os outros quatro, rival/reset/fail-closed |
| `test_v2_infiltration.gd` | 22 | perfil só no Mestre e GROUND/FLYING intactos (chamada idêntica à de antes desta fase), alcance a custo plano por passo, atravessa aliado/inimigo, nunca termina ocupado, nunca água/montanha (tile único e PAREDE completa), cidade inimiga bloqueia, alcance encolhe com o movimento, sem BFS global, move de verdade com animação passo a passo, sem ordem de vários turnos, **os três perfis lado a lado contra a mesma obstrução dupla** (unidades + água), **infiltração até a backline atravessando uma linha de frente inteira**, sem teleporte, sem ação extra grátis, texto do painel nunca menciona voo, sem id do Mestre na lógica |
| `test_v2_rogue_flow.gd` | 10 | **fluxo principal (46 passos)** com fog real: N1…N9, Ataque Furtivo (mira/ESC/clique, penetração, sem revide), upgrades, Desmantelar (normal/caster/siege), Refúgio, Mestre, infiltração através de uma formação numa arena controlada (com parede de água limitando o alcance), Ataque Furtivo do Mestre pós-infiltração, save/load, slot das 5 Doutrinas; mira cancelada de todos os jeitos, alvo na neblina (alcance 1 sempre visível), recarga/Desmantelar persistem, Mestre em produção persiste, Mestre×Campeão no mesmo turno, sem ordem de vários turnos p/ infiltração, IA |
| `test_v2_doctrine_framework_reuse.gd` (+3) | 21 | as mesmas garantias em laço sobre as **CINCO Doutrinas** (linha, produção, upgrade, prédios, técnicas, Lendária, tooltips) e as fundações **sem id/nome concreto** de nenhuma; **sem sistema paralelo** (`Rogue*`, `StealthCombatResolver`); as extensões da fase (penetração, sem-revide, traços múltiplos, INFILTRATOR) são campos de dado com defaults inertes |
| `test_hud.gd` (+13) | 13 | botões Guilda/Refúgio, uma forma por nível, Mestre desabilitado por **qualquer** outra Lendária (as quatro anteriores), `Ataque Furtivo ×1.35` (com penetração/sem-revide no tooltip), motivo "Nenhum inimigo adjacente.", mira e dica, recarga, Desmantelar como linha PASSIVA sem botão, Evoluir 24/32 Ouro, painéis do Assassino e LENDÁRIO do Mestre (Passo Sombrio, nunca "voo"), alcance de infiltração via `infiltrate_reachable`, outras Doutrinas intactas |
| adaptados | — | testes das Fases 1–9 que assumiam o Ladino inerte (`test_v2_doctrine_content`, `_research_database`, `_unlock_system`, `_brace_spears`, `_shield_wall`, `_legendary_system`, `_sentinel`, `_guardian_n9_flow`) |

### Validação visual (não-headless, `Main.tscn` real, uma execução)

Confirmado nas capturas/prints: `Guilda dos Ladinos — 22 PP` (aba Construções) → `Ladino — 20 PP`; painel do Ladino `HP 14/14 | Ataque 4.5 | Defesa 2.5 | Movimento 3.0/3.0`; N4:
botão `Ataque Furtivo ×1.35` com o tooltip "Ignora 40% da Defesa do alvo. O alvo não revida este golpe."; **mira** com o alvo adjacente destacado e a dica "» Escolha o alvo de
Ataque Furtivo (ESC cancela) «"; **ESC real pelo pipeline de input** cancelou sem mover, sem gastar movimento nem recarga; o golpe real (contra um alvo de Defesa 14, que
normalmente revidaria) causou dano real 1,875 == previsto 1,875 e **revide recebido 0,0**; após o N5 só `Sabotador — 32 PP` e `Evoluir para Sabotador — 24 Ouro` (recarga do
Ataque Furtivo preservada: 2); N6: painel mostra `Passiva — Desmantelar / +50% de dano de ataque básico contra conjuradores ou unidades de Cerco.`; contra uma fixture conjurador
o multiplicador real foi 1,5 (7,5 de dano real num Ataque 6,0 com Defesa 3,0 do alvo, terreno neutro); após o N7 só `Assassino — 48 PP`; `Refúgio das Sombras — 55 PP`; com o N9
`Mestre das Sombras — 95 PP` **ao lado** de `Assassino — 48 PP`; painel do Mestre `LENDÁRIO | … HP 30/30 | Ataque 10.5 | Defesa 4.5 | Movimento 4.0/4.0`, `Passiva — Desmantelar`,
`Passo Sombrio: atravessa unidades e ignora custo extra de terreno terrestre; não atravessa terreno impassável.` (nunca menciona voo); **infiltração real**: cercado por 4
unidades próprias, o Mestre se moveu 2 tiles através da posição (Movimento 2.0/4.0 restante, coordenada mudou de verdade, painel atualizado); **slot:** com o Mestre vivo o
Campeão, o Herói, o Caçador de Lendas **e** o Cavaleiro de Grifo ficam visíveis e desabilitados com o motivo; o quadro de pesquisa mostra as **cinco** Doutrinas concluídas
(Guardião, Guerreiro, Patrulheiro, Cavalaria, Ladino — Cerco intocado) e o Exército Supremo `2 / 2 · Disponível`; `check_victories()` deixou o jogo em `PLAYING`. FPS entre 73 e
117 nas capturas de jogo (10 na última, quadro de pesquisa em tela cheia — mesmo padrão de FPS baixo já visto nas capturas de tela cheia de fases anteriores, sem relação com esta
fase).

Ressalvas: (1) o clique no alvo foi feito por chamada direta a `_handle_technique_targeting_click`/`_move_selected_to` (mira, realce, ESC e o movimento real foram reais);
(2) **"Classe: Corpo a corpo, Cavalaria"** aparece no painel de TODAS as formas do Ladino — achado, não bug desta fase: `ArmyComposition.roles_for_kind` (pré-existente, nunca
tocado) rotula qualquer unidade com `movement_points` acima da baseline como `ROLE_CAVALRY`, um rótulo genérico de "mobilidade alta" reaproveitado tal como está; o mesmo já
acontecia com o Cavaleiro na Fase 9. Documentado, não corrigido (fora do escopo pedido); (3) na captura da infiltração, a contagem de tiles alcançáveis pelo Mestre coincidiu
numericamente com a de um terrestre na mesma posição (32 vs. 32) — coincidência de CONTAGEM total num terreno aberto com poucos bloqueios (o CONJUNTO de tiles é diferente, como
os testes unitários provam com paredes completas); a screenshot e o log de movimento real (atravessando a própria guarnição) são a evidência definitiva, não a contagem; (4) o
motivo do botão bloqueado aparece no tooltip (não em screenshot), conferido por print e por teste.

### Performance

Sem `_process`, timer nem polling; sem varredura do mapa: `infiltrate_reachable` é um Dijkstra bounded pelo movimento (igual a `compute_reachable`), nunca o mapa inteiro.
Medido (headless, mapa de raio 20, 30 inimigos formando uma parede pro Mestre atravessar): `predict` sem penetração/sem-revide (ataque comum) **33,3 µs**; `predict` COM os dois
fatores (Ataque Furtivo) **32,9 µs** — a diferença é ruído de medição, os dois parâmetros extra não custam nada mensurável; `UnitAbilities.attack_multiplier` com Desmantelar
aplicável **10,8 µs** contra **10,9 µs** sem — o novo laço "qualquer traço da lista" não pesa; `has_trait` isolado **0,5 µs**. `infiltrate_reachable` com 30 unidades na parede
**928 µs** (mais caro que `flight_reachable`, 276 µs, porque expande passo a passo em vez de usar distância geométrica — ainda assim bounded pelo movimento, nunca o mapa).
**Pathfinding terrestre antes × depois** (cópia do `compute_reachable` de antes da Fase 9/10 × o atual): Ladino mov. 3 **412,7 µs × 428,6 µs**; Guerreiro mov. 2 **192,3 µs ×
199,3 µs** — igual, sem regressão. Seleção de unidade (`SelectionManager._select_unit`): V1 932 µs, Ladino 990 µs, Mestre das Sombras (INFILTRATOR) 1,51 ms, Grifo (FLYING,
regressão da Fase 9) 852 µs — todos na mesma ordem de grandeza de antes. Sem regressão perceptível em nenhum caminho pré-existente.

### Limitações (de propósito) e ressalvas

- **Números e modelos provisórios** (todos os da tabela; Guilda 22 PP, Refúgio 55 PP; Rogue.glb do KayKit, moinho/torre A). Nenhuma arte nova; o "Classe: Cavalaria" no painel é
  um rótulo genérico pré-existente (mobilidade alta), não uma afirmação de que o Ladino é montado — ele não tem o traço `mounted`.
- **"Ignora o custo do terreno" só é plenamente observável com terreno de teste:** hoje **todo** terreno do jogo custa 1 de movimento; a regra (custo plano por passo na
  infiltração) está implementada e testada com tiles de custo alto, mas no jogo real ela hoje só muda o comportamento em relação a atravessar UNIDADES, não terreno caro.
- **Sem stealth/invisibilidade** (fora de escopo, por pedido explícito): Ataque Furtivo é uma técnica de combate/posicionamento; Passo Sombrio é uma regra de movimento. Nenhuma
  unidade fica oculta na neblina, nenhuma detecção nova existe.
- **A IA não entende infiltração nem prioriza alvos:** trata a unidade INFILTRATOR como terrestre no pathfinding e não escolhe conjuradores/Cerco para o Desmantelar nem usa o
  Ataque Furtivo estrategicamente; a compatibilidade (sem crash, slot respeitado, técnica executável) foi conferida, o comportamento inteligente é fase futura.
- **Sem ordem de movimento de vários turnos e sem pré-visualização de rota longa** para unidades INFILTRATOR (mesma decisão do voo, Fase 9).
- **Penetração de Defesa aplica só na FORMULA daquele golpe:** um alvo de Defesa muito alta ainda pode sofrer só o dano-piso (1) se o Ataque não superar 60% da Defesa mesmo
  reduzida.
- O contador do Exército Supremo é limitado pelo requisito (2 / 2), mesmo com as cinco Doutrinas completas.
- **`caster`/`siege` cobrem só o que já existe:** o "Mago" V1 (nome enganoso) não é um conjurador pelos dados atuais e por isso fica de fora do bônus de Desmantelar — decisão
  consciente (classificar pelo DADO, nunca pelo nome), documentada, não "corrigida" (mudar `magic_school` do Mago V1 seria uma mudança de gameplay V1 fora do pedido desta fase).
- Fora do escopo, **não implementado:** Cerco, IA estratégica V2, Exército Supremo funcional, vitória, economia/Suprimentos, upkeep, bônus raciais, Magia V2, Infraestrutura V2,
  stealth/fog especial.
- Fase encerrada quando **a quinta Doutrina completa foi implementada sobre o mesmo molde, estendendo a arquitetura V2 para assassinato, penetração de Defesa, counters por
  trait e infiltração sem criar um subsistema paralelo.**


## Fase 11 — Doutrina de Cerco N1–N9

A **sexta e última Doutrina Militar**, implementada de uma vez sobre o mesmo molde. O critério era o das Fases 7–10 (conteúdo sobre as fundações, sem
subsistema paralelo) mais uma prova nova: o mesmo molde suporta **ataque contra cidade/fortificação** — uma Técnica com mira de CIDADE (terceiro
`TargetMode`, ao lado de UNIT e TILE), um requisito de preparação derivado (não um boolean salvo) e uma exceção a esse requisito por dado (a
Lendária). Foram necessárias **cinco** extensões genéricas pequenas, todas por dado, nenhuma citando o Cerco.

```
N1 Doutrina de Cerco     v2_doctrine_siege_1  doctrine             v2_doctrine_siege            (sem bônus próprio; só abre o N2)
N2 Arsenal de Cerco      v2_doctrine_siege_2  building             v2_building_siege_arsenal    treina a cadeia convencional
N3 Catapulta             v2_doctrine_siege_3  unit                 v2_unit_catapult             ranged especializada em Cerco (alcance 2)
N4 Munição Demolidora    v2_doctrine_siege_4  technique (PASSIVA)  v2_technique_demolition_ammo  +40% de ataque de Cerco contra cidade/fortificação
N5 Trebuchet             v2_doctrine_siege_5  unit_upgrade         v2_unit_trebuchet            1º upgrade (V2UnitUpgrade); alcance 3
N6 Bombardeio Preparado  v2_doctrine_siege_6  technique (ATIVA)    v2_technique_prepared_bombardment  mira CIDADE, ×1.5, exige não ter se movido
N7 Bombarda              v2_doctrine_siege_7  unit_upgrade         v2_unit_bombard               2º upgrade / forma Elite convencional
N8 Grande Arsenal        v2_doctrine_siege_8  mastery_building     v2_building_grand_arsenal     só habilita o Colosso de Cerco
N9 Colosso de Cerco      v2_doctrine_siege_9  legendary_candidate  v2_legendary_siege_colossus   Lendário; Artilharia Andante; slot GLOBAL das 6
```

As **seis** Doutrinas Militares completas = `gameplay_connected = true` (54 ids em `V2DoctrineContent.CONNECTED_UNLOCK_IDS` — os 54 nós normais
inteiros). **Nenhum ID canônico foi alterado.**

### Auditoria obrigatória (antes de qualquer bônus contra cidade)

Feita antes de escrever qualquer código, como pedido: **o sistema de ataque contra cidade já existia**, inteiro, na V1 (`CombatResolver.
resolve_city_attack`), com sua **própria fórmula** — multiplicativa/divisória (`dano = ataque × veterania × city_attack_multiplier / (1 + defesa
dos prédios)`), **diferente** da subtrativa usada em combate unidade-contra-unidade (`predict`/`resolve`) desde sempre, não introduzida agora.
Resistência urbana já era só **HP da cidade** (cresce com população) + **`shield`** (só com Muralhas construídas) + o bônus fracionário de
`BuildingDatabase.defense_bonus_for`. **Nenhuma fortificação separada existe** no motor: "alvo de Cerco" nesta fase é `City`, sem entidade nova.
Também já existia um **bônus inato de Cerco** por `kind` (`UnitAbilities.city_attack_multiplier`, 1,5× pra `UnitAbilities.SIEGE`, 2× pra três kinds
"pesados" da V1) e uma **fonte única** para "é uma máquina de Cerco" desde a Fase 10 (o traço `siege`, já semeado da mesma lista `SIEGE`). Nada
disso foi duplicado: a função existente foi **generalizada** pra reconhecer o traço também (ver abaixo), o comportamento V1 ficou **byte a byte
igual** (testado). Covis de monstro **não** foram tratados como cidade (`resolve_lair_attack` continua intocado — Munição Demolidora nunca chega
lá, mesmo reaproveitando o bônus inato que já valia pra ele antes desta fase).

### Reutilizado sem alteração

| Fundação | Como o Cerco a usa |
|---|---|
| `V2UnlockSystem`, `V2ResearchState`, `V2ResearchDatabase` (`capstone_progress`, `unlock_effect_text`) | os 9 nós aplicam pelo mesmo mapa de tipos; tooltips e toasts genéricos; nenhum arquivo tocado |
| `V2UnitLine` (`unit_ids`, `resolve_trainable_form`, `doctrine_branch_of`) | a cadeia Catapulta→Trebuchet→Bombarda e "só a forma mais avançada" saem da metadata dos tiers 3-5-7; o Colosso herda as técnicas por `doctrine_branch_of` |
| `V2UnitUpgrade` | 32 e 40 Ouro **por fórmula** (`2 × ΔPP`); mesma unidade, HP em %, veterania/XP/serial/recargas preservados |
| `V2LegendarySystem` | **zero linhas alteradas**: o Colosso é reconhecido por metadata (`legendary_candidate`); **um slot** para as seis Lendárias (ativo OU em produção); fail-closed no nascimento |
| `CombatResolver.resolve_city_attack` (escudo, vida, captura, resposta) e `resolve`/`predict` (ataque básico ranged normal) | Munição Demolidora e Bombardeio Preparado entram como **fatores a mais na MESMA fórmula urbana**; o ataque básico da Catapulta contra unidade usa o combate ranged de sempre, sem fórmula especial |
| `CombatResolver.can_attack_unit` | a regra de alvo hostil de unidade continua intocada; Bombardeio nunca mira unidade |
| Modo de mira das técnicas (`SelectionManager.start_technique_targeting/_handle_technique_targeting_click/_perform_technique`), ESC em `PauseMenu`, recarga em `magic_cooldowns` | Bombardeio Preparado usa o MESMO pipeline de mira (nenhuma linha de `SelectionManager` citou o id da técnica); `SaveManager`, `City`, `GameManager` **sem nenhuma alteração** nesta fase |
| `UnitAbilities.SIEGE`, traço `siege` (Fase 10) | fonte única de "é máquina de Cerco", generalizada (abaixo), não duplicada |
| Produção normal (`BuildingData.trains_unit`, `requires_building`, `UNIT_TRAINER_FALLBACK`, `PLAYER_TRAINABLE_KINDS`) | Arsenal e Grande Arsenal são `BuildingData` comuns; HUD, IA e `ArmyComposition` os enxergam sem código |

### Generalizado (extensões genéricas — todas por dado)

1. **Mira de CIDADE** (`V2DoctrineTechniqueData.TargetMode` ganhou um terceiro valor, `CITY`, ao lado de `UNIT`/`TILE`; `is_city_strike()`):
   `V2TechniqueRuntime.city_strike_targets`/`perform_city_strike` são os irmãos de `strike_targets`/`perform_strike` (mesmo alcance
   `ATTACK_RANGE_PLUS`, mesma visibilidade de alcance > 1, mesma ordem estável), mas resolvem contra `City`, nunca `Unit`. `target_coords` e
   `perform_targeted` (os DOIS pontos de entrada que `SelectionManager` já chamava) ganharam um `if is_city_strike()` cada — **nenhuma linha
   nova em `SelectionManager`**: a mira, o destaque, o hover e a confirmação já eram genéricos o bastante (o hover já sabia mostrar nome de
   cidade via `_attack_target_name`, criado nas Fases 3-7 pro ataque comum).
2. **Regra única de alvo hostil de CIDADE** (`CombatResolver.can_attack_city`), irmã de `can_attack_unit`: a MESMA condição que já estava embutida
   em `SelectionManager._select_unit` (dono diferente + guerra) virou uma função — `_select_unit` foi refatorado pra chamá-la (mesmo
   comportamento, agora uma fonte única usada também pelo Bombardeio).
3. **Passiva contra CIDADE/FORTIFICAÇÃO** (`V2DoctrineTechniqueData.city_attack_bonus`/`has_city_attack_effect()`, irmã de `basic_attack_bonus`
   mas numa lista SEPARADA — nunca soma com o bônus unidade-contra-unidade): `V2TechniqueRuntime.city_attack_multiplier(unit)` é o irmão do
   `attack_multiplier` unidade-contra-unidade, só que plugado exclusivamente em `CombatResolver.resolve_city_attack` (nunca em
   `resolve_lair_attack`) — mesma cadeia, DERIVADO (pesquisa + linha), nunca salvo.
4. **Requisito de preparação, derivado** (`V2DoctrineTechniqueData.strike_requires_undisturbed`): checado em `unavailable_reason` comparando
   `unit.movement_left` com `unit.unit_data.movement_points` (`is_equal_approx`) — **nenhum boolean novo em `Unit`**, a mesma fonte de verdade que
   já existia pro resto do jogo.
5. **Exceção ao requisito, por dado** (`UnitData.ignores_technique_stationary_requirement`): um campo genérico em `UnitData`, consultado no
   MESMO `if` do item 4 — zero `if unit_id ==`; qualquer unidade futura que declare o campo herda a exceção automaticamente.

Fonte única do bônus inato de Cerco (auditoria da seção 15 do pedido): `UnitAbilities.city_attack_multiplier` agora testa `kind in SIEGE **OU**
has_trait(TRAIT_SIEGE)` (antes só `kind in SIEGE`) — o comportamento V1 (inclusive o bônus MAIOR de `SIEGE_HEAVY`, só por kind literal, que
antecede o sistema de traços) continua byte a byte igual; as quatro unidades V2 de Cerco herdam o MESMO bônus "padrão" (1,5×) só por declarar o
traço, sem entrar na lista V1 nem duplicar a classificação.

### Específico do Cerco (só dado/conteúdo)

`UnitDatabase` (4 unidades: Catapulta, Trebuchet, Bombarda, Colosso de Cerco), `BuildingDatabase` (Arsenal, Grande Arsenal e 2 linhas de
`UNIT_TRAINER_FALLBACK`), `V2DoctrineTechniqueDatabase` (2 técnicas), `V2DoctrineContent` (ids conectados e descrições finais), mais dois textos
de UI por dado (`UnitAbilities.artillery_march_lines`, `TileInspector`'s duas linhas de traço público). **Nenhuma classe, sistema ou `if id ==` do
Cerco.** Testes varrem os arquivos das fundações (sem comentários) e falham se qualquer um citar id ou nome concreto das seis Doutrinas, ou se
existir arquivo/classe `Siege*`/`SiegeCityCombatResolver`.

### Definições

| | HP | Ataque | Defesa | Mov. | Visão | Alcance | PP | Traços | Modelo (provisório) |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| Catapulta (N3) | 16 | 3,5 | 2,5 | 2 | 3 | 2 | 28 | siege | corpo "catapult" (V1) ×1,0 |
| Trebuchet (N5) | 20 | 5,0 | 3,0 | 2 | 3 | 3 | 44 | siege | "catapult" ×1,15 |
| Bombarda (N7) | 26 | 6,5 | 4,0 | 2 | 3 | 3 | 64 | siege | "catapult" ×1,3 |
| **Colosso de Cerco (N9)** | 44 | 9,0 | 8,0 | 2 | 4 | 3 | 110 | siege + legendary | "catapult" ×1,5 |

Números **fixos pelo próprio pedido** (não inventados como BALANCE PLACEHOLDER desta vez — só a visão do Trebuchet/Bombarda, não especificada,
ficou em 3, igual à Catapulta, decisão minha sinalizada).

- **Identidade = destruição de cidades, nunca duelo de unidades** (testado): Ataque MENOR que o Arqueiro/Patrulheiro do mesmo nível em todos os
  tiers; o Ataque básico contra unidade usa o combate ranged normal, sem fórmula especial — o valor vem do **bônus de Cerco** (inato + Munição
  Demolidora), que só existe contra cidade/fortificação. Movimento **nunca** aumenta ao evoluir (2 nas quatro formas) — o Trebuchet ganha
  ALCANCE, não mobilidade.
- **Arsenal de Cerco:** 22 PP (igual aos outros Salões), sem upkeep, não exige outra Doutrina nem o Arsenal V1 (`siege_workshop`, id diferente,
  mesmo nome de exibição — mesma limitação já documentada nas Fases 7-8 pra Espadachim/Arqueiro/Catapulta/Trebuchet/Bombarda/Colosso de Cerco V1,
  que também têm nomes coincidentes); treina a Catapulta e depois a forma mais avançada (uma por vez). Modelo: torre de catapulta do KayKit (já
  reaproveitada pela Ordem da Cavalaria). **Grande Arsenal:** `mastery_building`, 55 PP, exige o Arsenal na mesma cidade, só habilita o Colosso.
  Modelo: torre B do KayKit (já reaproveitada pelo Bastião de Maestria). Também há um "Grande Arsenal" V1 (`grand_arsenal`, id diferente, mesmo
  nome de exibição — mesma limitação).
- **Produção:** antes do N5 `Catapulta — 28 PP`; depois `Trebuchet — 44 PP`; depois do N7 `Bombarda — 64 PP` (nunca duas). O Colosso de Cerco é
  produção **separada** no Grande Arsenal (110 PP); a Bombarda continua treinável.
- **Upgrades:** Catapulta→Trebuchet **32 Ouro**; Trebuchet→Bombarda **40 Ouro**, pela fórmula genérica.
- **Modelo reaproveitado:** o corpo procedural "catapult" já existente do V1 (a mesma Catapulta V1 usa) em escalas 1,0/1,15/1,3/1,5 distingue as
  quatro formas — mesmo padrão do Rogue.glb/"cavalry"/"griffin" reaproveitados nas Fases 7-10; sem prédio/criatura de "colosso" nos pacotes
  gratuitos, decisão honesta de usar o mesmo corpo maior em vez de inventar uma silhueta nova.

### Munição Demolidora (N4) — passiva contra cidade/fortificação

+40% de dano de ataque de Cerco contra cidade/fortificação — ataque básico de Cerco **e** Bombardeio Preparado, ambos dentro da MESMA fórmula de
`CombatResolver.resolve_city_attack` (`V2TechniqueRuntime.city_attack_multiplier`, cadeia irmã de `UnitAbilities.attack_multiplier`). Sem botão,
custo, recarga ou estado guardado; deriva de pesquisa + linha, então save/load, unidades antigas e a IA funcionam sem passo extra.

- **Nunca confundir com o traço `siege`** (testado explicitamente, seção 18 do pedido): o traço identifica "esta unidade É uma máquina de
  Cerco" (semeado na criação); Munição Demolidora é "esta CIVILIZAÇÃO pesquisou o N4" — uma Catapulta **V1** (traço `siege` automático) nunca
  recebe Munição Demolidora sozinha; só uma Catapulta **V2** cujo DONO pesquisou o N4.
- **Nunca duplica**, mesmo com a cidade-alvo tendo várias estruturas defensivas (Muralhas, Fortaleza Imperial, Santuário Arcano) — o número de
  prédios do lado defensor não afeta o multiplicador do atacante.
- **Nunca afeta** unidade, monstro, covil, feitiço ou dano ambiental — só ataque de Cerco contra cidade/fortificação (`resolve_lair_attack`
  nunca chama `V2TechniqueRuntime.city_attack_multiplier`, testado por varredura de código).

### Bombardeio Preparado (N6) — o primeiro ataque de Cerco com mira de cidade

Ativa, com mira **de CIDADE**: o jogador escolhe uma cidade ou fortificação hostil ao alcance BÁSICO + 1 (Catapulta/Trebuchet 3, Bombarda/Colosso
4), resolvida pelo MESMO `CombatResolver.resolve_city_attack` de sempre com **1,50×** o Ataque (mais Munição Demolidora por cima, se pesquisada —
`1,40 × 1,50`, nunca hardcoded 2,10).

- **Exige preparação:** a unidade não pode ter se movido naquele turno — **derivado** de `movement_left == movement_points`, nada salvo. Movida
  uma PARTE → indisponível com o motivo específico ("Bombardeio Preparado exige que a unidade não tenha se movido neste turno."); movimento
  **zero** (já atacou/moveu tudo) → o motivo mais fundamental tem prioridade ("A unidade já agiu neste turno."); um NOVO turno restaura o
  movimento cheio e, com ele, o acesso.
- **Nunca mira unidade nem monstro** — só cidade/fortificação hostil (`target_mode CITY`); a lista de alvos-unidade dela é sempre vazia por
  construção.
- **Cidade própria, aliada e em paz nunca são alvo** (mesma regra de hostilidade do ataque comum). **A cidade nunca revida** (regra normal, sem
  imunidade inventada).
- **Custos:** gasta a ação e zera o movimento; recarga **4** (conta o turno de uso); **zero Mana e zero Ouro**; não guarda efeito (só a recarga).
  **ESC/clique fora cancelam** sem gastar nada.
- **O ataque básico continua disponível** mesmo com o Bombardeio em recarga ou indisponível por movimento — nunca é o único jeito de atacar
  cidade.
- **Visibilidade:** a cidade precisa estar visível ao dono humano (mesma regra já usada pelas técnicas de alcance > 1 desde a Fase 8); sem fog
  calculada, ou pra IA, sem restrição.
- **Herança por Doutrina:** as quatro formas do Cerco (incluindo o Colosso) herdam Munição Demolidora e Bombardeio Preparado; nenhuma outra
  Doutrina os recebe.

### Colosso de Cerco e Artilharia Andante

O Colosso **não** é "a Bombarda com números maiores": é uma Lendária separada, produzida no Grande Arsenal, sob o mesmo slot global, com traços
`siege` **e** `legendary` (origens diferentes, nenhum apaga o outro). Sua singularidade é a passiva **Artilharia Andante**
(`UnitData.ignores_technique_stationary_requirement = true`): pode usar Bombardeio Preparado **mesmo depois de se mover** — as formas
convencionais continuam exigindo posição parada.

- **Sem ação extra** (testado explicitamente, seção 49 do pedido): a exceção remove SÓ o requisito de "não se moveu"; a Técnica continua
  consumindo a ação normalmente, zerando o movimento e entrando em recarga — mover e bombardear no mesmo turno não vira "mover + atacar normal +
  bombardear"; usar de novo no mesmo turno continua bloqueado pela recarga.
- **Ainda precisa de alcance e de uma cidade hostil válida** — a exceção não cria um alvo, só remove UM requisito específico.
- **Modelado por dado, não por id:** `V2TechniqueRuntime.unavailable_reason` lê `UnitData.ignores_technique_stationary_requirement`; nenhuma
  linha das fundações cita `siege_colossus`.
- **UI:** painel mostra `LENDÁRIO`, `Passiva — Munição Demolidora` (herdada, prefixo SEM "Lendária" — mesma convenção das outras passivas de
  Doutrina, ex.: Desmantelar no Mestre das Sombras) e **`Passiva Lendária — Artilharia Andante` / `Pode usar Bombardeio Preparado mesmo depois de
  se mover.`** (texto novo, `UnitAbilities.artillery_march_lines`, mesmo padrão de duas linhas de Execução/Caçada Lendária); fato público
  equivalente no `TileInspector` ("Artilharia Andante (pode usar Bombardeio Preparado mesmo tendo se movido)").

### Interação automática com Desmantelar (Ladino) e Caçada Lendária (Caçador de Lendas)

**Nenhuma integração direta Cerco↔Ladino/Patrulheiro foi escrita.** As quatro unidades de Cerco têm o traço `siege` (a mesma fonte que Desmantelar
já consultava desde a Fase 10); o Colosso também tem `legendary` (a mesma fonte que Caçada Lendária já consultava desde a Fase 8) — os dois
counters passaram a valer contra o Cerco **automaticamente**, testado em combate real:

- Desmantelar (Ladino, N6): **+50%** de Ataque contra qualquer uma das quatro formas de Cerco (traço `siege`); sem o N6 pesquisado, nenhum bônus.
- Caçada Lendária (Caçador de Lendas): **+40%** de Ataque contra o Colosso especificamente (traço `legendary`); a Bombarda comum **não** recebe
  (sem o traço).
- **Origens diferentes combinam, nunca se cancelam:** um Ladino com Desmantelar e um Caçador de Lendas com Caçada Lendária, atacando o MESMO
  Colosso, aplicam cada um o seu próprio fator (1,5× e 1,4× respectivamente) pela cadeia normal de multiplicadores — nenhum deles é "consumido"
  pelo outro; só a MESMA origem nunca soma consigo mesma (testado, ver Desmantelar contra caster+siege na Fase 10).

### Slot Lendário GLOBAL: as seis Doutrinas

Nenhum mecanismo novo e **nenhuma alteração em `V2LegendarySystem`**. Cenário obrigatório (testado com combate real): Campeão ativo → Herói,
Caçador de Lendas, Cavaleiro de Grifo, Mestre das Sombras **e** Colosso de Cerco bloqueados → Campeão morre → Colosso em produção no Grande
Arsenal → os outros quatro bloqueados (na outra cidade; a cidade produtora não se bloqueia) → cancelar libera os seis → Mestre das Sombras em
produção → Campeão, Herói, Caçador, Grifo e Colosso bloqueados. Cada um dos seis ativo bloqueia os outros cinco; vale entre cidades, depois de
salvar/carregar, com Lendária rival (não bloqueia), depois do reset de debug e no nascimento simultâneo (fail-closed: o segundo não nasce, o
custo volta, erro claro).

### Exército Supremo

Com as seis Doutrinas completas o `capstone_progress` mostra **2 / 2** (o contador é limitado pelo requisito de duas Doutrinas) e o nó segue
**pesquisável**. O efeito (`v2_military_supremacy_access`) continua **inerte**: nenhuma vitória foi conectada (`check_victories()` deixa o jogo em
`PLAYING`). Fase 11 fecha as Doutrinas; o capstone continua fora de escopo, conforme instruído.

### Save / load

Sem schema novo. Arsenal/Grande Arsenal (prédios), formas (por `visual_kind`, o dado recria os traços `siege`/`legendary` e
`ignores_technique_stationary_requirement`), **recarga** do Bombardeio Preparado, o Colosso e o slot (derivado de unidades + `production_item`)
sobrevivem ao ciclo; um Colosso **em produção** continua reservando o slot depois do load; Munição Demolidora (derivada de pesquisa + linha) e
Artilharia Andante (derivada do dado) funcionam sem nenhum dado salvo extra.

### IA

Sem decisão nova (não pesquisa V2, não constrói Arsenal/Grande Arsenal, não compõe, não usa técnicas, **não planeja Cerco nem prioriza alvos**).
Compatibilidade: 6 turnos reais com o conteúdo presente sem uso pelos rivais; uma civilização rival recebendo a pesquisa por debug resolve a forma
correta (Bombarda), oferece o Colosso de Cerco respeitando o slot, executa o ataque de Cerco básico contra uma cidade real pelo runtime sem crash,
e um Colosso da IA sobrevive 3 turnos de IA no mapa sem crash (a IA não decide quando declarar Cerco, qual cidade priorizar, como escoltar ou
quando usar o Bombardeio — tudo fase futura).

### Assets

Só o que já existia: o corpo procedural "catapult" do V1 (a mesma Catapulta V1 usa) em escalas 1,0/1,15/1,3/1,5 distingue as quatro formas; torre
de catapulta e torre B do KayKit para Arsenal e Grande Arsenal. **Nenhum asset V1 alterado e nenhum asset novo.**

### Testes (+144; suíte completa **2872/2872**, 107 scripts)

| Arquivo | Testes | Cobre |
|---|---:|---|
| `test_v2_siege_arsenal.gd` | 16 | N1 sem bônus, 9 unlocks, Arsenal bloqueado antes/liberado depois do N2 e independente de V1/outras Doutrinas (inclusive o Arsenal V1 de nome coincidente), custo/slot/isolamento, Catapulta (stats, Ataque menor que o Arqueiro mesmo custando mais, ataque básico ranged normal sem fórmula especial), N3 + Arsenal + fila, **traço `siege` nas quatro formas** (fonte única, Desmantelar reconhece todas) |
| `test_v2_demolition_ammo.gd` | 14 | passiva sem botão/custo/recarga, N4/herança pelas 4 formas, isolamento por civilização, **nunca contra unidade** (só cidade), ataque básico de Cerco com e sem o bônus (fórmula urbana real), nunca duplica com múltiplos prédios defensivos, nunca afeta covil (varredura de código), sem estado guardado |
| `test_v2_prepared_bombardment.gd` | 31 | dado (CITY, ×1,5, alcance +1, `strike_requires_undisturbed`, recarga 4), N6/herança, só cidade/fortificação hostil (nunca cidade própria/em paz/unidade/monstro), alcance por forma (3/4), **requisito de preparação derivado** (cheio/parcial/zero/novo turno, sem boolean), multiplicador via a fórmula urbana real, ação/recarga/Mana/Ouro, ataque básico segue disponível, falha não consome recarga, ESC, visibilidade (fog), cidade nunca revida, **TargetMode CITY genérico** (UNIT/TILE intactos, rejeita unidade/tile vazio, sem id na lógica), **Artilharia Andante** (formas convencionais perdem acesso ao mover, Colosso não; ainda exige alcance/alvo/recarga/ação; sem ação extra; por dado, não por id) |
| `test_v2_siege_line.gd` | 26 | stats e relações (Ataque sempre menor que o Patrulheiro equivalente, movimento nunca aumenta, alcance +1 no N5), produção por nível, upgrade 32/40 por fórmula com motivos, preservação (HP%, veterania, recarga, serial), cadeia completa, herança das técnicas, unidades V1 intactas |
| `test_v2_siege_mastery_and_colossus.gd` | 32 | Grande Arsenal (dado, requisitos, 55 PP, slot, fila, nome coincidente com o V1), Colosso (stats, traços siege+legendary+`ignores_technique_stationary_requirement` por dado, não supera as outras Lendárias, fora da cadeia, Bombarda segue treinável, herança), sistema do slot sem palavra do Cerco, **Desmantelar × Colosso** (siege), **Caçada Lendária × Colosso** (legendary, Bombarda comum não recebe), **origens diferentes combinam sem se cancelar**, **slot entre as SEIS Doutrinas passo a passo**, cada um dos seis bloqueia os outros cinco, rival/reset/fail-closed |
| `test_v2_siege_flow.gd` | 8 | **fluxo principal de ponta a ponta**: N1…N9, ataque básico ranged e de Cerco (antes/depois de N4), upgrades, Bombardeio Preparado (mira de cidade/ESC/clique, indisponível após mover), Grande Arsenal, Colosso, **Artilharia Andante em movimento real** (cenário controlado), Desmantelar e Caçada reais contra o Colosso, slot das 6, save/load; mira cancelada de todos os jeitos, cidade na neblina, recarga/Munição persistem, Colosso em produção persiste, IA (6 turnos de compatibilidade + civ por debug ataca cidade real e respeita o slot) |
| `test_hud.gd` (+14) | 14 | botões Arsenal/Grande Arsenal, uma forma por nível, Colosso desabilitado por **qualquer** outra Lendária (as cinco anteriores), Munição Demolidora como linha PASSIVA sem botão, `Bombardeio Preparado ×1.5` (motivo "Nenhuma cidade hostil ao alcance.", mira de cidade e dica, recarga, motivo de "não se moveu"), Evoluir 32/40 Ouro, painel da Bombarda e LENDÁRIO do Colosso (Artilharia Andante, nunca confundido com Passo Sombrio/voo), botão habilitado mesmo tendo se movido (só o Colosso), outras Doutrinas intactas |
| `test_v2_doctrine_framework_reuse.gd` (+3) | 24 | as mesmas garantias em laço sobre as **SEIS Doutrinas** (linha, produção, upgrade, prédios, técnicas, Lendária, tooltips) e as fundações **sem id/nome concreto** de nenhuma; **sem sistema paralelo** (`Siege*`, `SiegeCityCombatResolver`); as extensões da fase (`TargetMode.CITY`, `city_attack_bonus`, `strike_requires_undisturbed`, `ignores_technique_stationary_requirement`) são campos de dado com defaults inertes |
| adaptados | — | testes das Fases 0-10 que assumiam o Cerco inerte (`test_v2_doctrine_content`, `_research_database`, `_unlock_system`, `_shield_wall`, `_legendary_system`, `_sentinel`, `_guardian_n9_flow`) |

### Validação visual (não-headless, `Main.tscn` real, uma execução)

Confirmado nas capturas (17 screenshots, jogo real, `Main.tscn` instanciada, seed fixa 424242, uma execução — três tentativas anteriores
falharam por bugs do próprio roteiro descartável antes de qualquer captura real, corrigidos no processo: `_on_new_game_requested` precisava de
`await`, `stagger_ai_turns` da cena real atrasa a produção do turno em vários frames — desligado só pro roteiro, como o GUT já fazia — e um alvo de
movimento precisava vir de `SelectionManager.reachable`, não de uma busca de distância às cegas):

`Arsenal de Cerco` construído (toast "Novo prédio disponível: Arsenal de Cerco"); Catapulta selecionada com painel `HP 16.0 | Ataque 3.5 | Defesa
2.5 | Alcance de ataque: 2`; ataque ranged real contra unidade a distância 2: previsto 1,250 == real 1,250, revide sofrido 0,000; ataque de Cerco
básico contra uma cidade inimiga real a distância 3: dano real registrado ANTES do N4; **depois do N4** (Munição Demolidora) o mesmo ataque básico
contra a mesma cidade sai maior, com o painel mostrando `Passiva — Munição Demolidora / +40% de dano de ataque contra cidades e fortificações.`;
Trebuchet evoluído com alcance 3; botão **`Bombardeio Preparado ×1.5`**; **mira de cidade real** — painel mostra "» Escolha o alvo de Bombardeio
Preparado (ESC cancela) «" e a cidade-alvo aparece destacada com um anel amarelo no mapa (`Cidade Rival de Teste`); **ESC real pelo pipeline de
input** cancelou a mira sem gastar nada (`movimento intacto: true`); o golpe real seguinte causou **dano 15,750** — batendo exatamente com
5,0 (Ataque) × 1,5 (bônus inato de Cerco) × 1,5 (Bombardeio) × 1,4 (Munição) = 15,75 — com movimento zerado e recarga 4; depois de mover a unidade,
o motivo exato apareceu: "Bombardeio Preparado exige que a unidade não tenha se movido neste turno."; Bombarda evoluída; `Grande Arsenal`
construído; o Colosso de Cerco nasceu com painel `LENDÁRIO | Colosso de Cerco (Recruta) | HP 44.0 | Ataque 9.0 | Defesa 8.0 | Movimento 2.0/2.0`,
`Passiva — Munição Demolidora` (herdada) **e** `Passiva Lendária — Artilharia Andante / Pode usar Bombardeio Preparado mesmo depois de se mover.`
(texto novo, nunca menciona voo/Passo Sombrio); a produção mostrou `Bombarda — 64 PP` **ao lado** de `Colosso de Cerco — 110 PP`; **Artilharia
Andante real**: o Colosso se moveu de verdade (`Movimento 1.0/2.0`, painel confirmando a nova coordenada, "Neste tile: Colinas (-3, 2)") e AINDA
usou o Bombardeio Preparado contra uma segunda cidade inimiga com sucesso; com o Colosso vivo, as outras cinco Lendárias apareceram **indisponíveis
pra treino** em todas as consultas (`can_train` false pra Campeão, Herói, Caçador de Lendas, Grifo e Mestre das Sombras); o quadro de pesquisa V2
final mostrou as nove entradas da linha **Cerco** — Doutrina de Cerco, Arsenal de Cerco, Catapulta, Munição Demolidora, Trebuchet, Bombardeio
Preparado, Bombarda, Grande Arsenal, Colosso de Cerco — todas em **"Concluído"**, com `Exército Supremo — Doutrinas completas: 1 / 2 (N9)` (só a
Doutrina de Cerco foi pesquisada nesta execução; a regra "2/2 com múltiplas Doutrinas" já está coberta exaustivamente pelos testes automatizados);
`check_victories()` deixou o jogo em `PLAYING`. FPS entre 4 e 5 nas capturas (mapa pequeno de teste com o log de eventos em tela cheia sobre o
mapa — mesmo padrão de FPS baixo já visto em capturas de fases anteriores com overlay cheio, sem relação com esta fase).

Ressalvas: (1) o clique no alvo da mira foi feito por chamada direta a `SelectionManager.use_technique_selected`/`_handle_technique_targeting_click`
(a mira, o destaque no mapa, o ESC e o golpe real foram reais); (2) o print de diagnóstico do dano da Artilharia Andante pós-movimento mediu só
`city.hp` e a segunda cidade-alvo tinha `shield` (o dano real caiu ali primeiro, então o console mostrou "0.000" enquanto a barra de vida da cidade,
visível no HUD por trás do log, já registrava o impacto) — falha de medição do roteiro descartável, não do jogo; o mecanismo em si (sucesso=true,
`pode bombardear mesmo tendo se movido: true`, coordenada mudou de verdade) é a evidência que importa, e a matemática exata do dano já está coberta
por 199+ asserts dedicados nos testes automatizados; (3) o rival de IA (Reino Élfico de Verdemata) atacou minha cidade de verdade durante o roteiro
(visível no log de eventos: "Reino de Cerco - Cidade 1 foi atacada! Vida: 32/36" e depois "28/36") — confirma que a IA e o resto do jogo V1
continuam rodando normalmente ao redor do conteúdo desta fase, sem crash; (4) "Classe: À distância" no painel do Colosso confirma ao vivo a
ressalva já documentada (`ArmyComposition.roles_for_kind` deriva `ROLE_SIEGE` do id do prédio de treino V1, não do traço `siege` — não inclui
"Cerco" na label das unidades V2, sem efeito funcional).

### Performance

Sem `_process`, timer nem polling; `city_strike_targets`/`city_attack_multiplier` só entram no caminho quente quando o
atacante é V2 (early-out por prefixo de id, mesmo padrão de `attack_multiplier`). Medido (headless, mapa de raio 20, 20 cidades no mapa pra medir
a busca de alvos do Bombardeio):

| Operação | Custo |
|---|---:|
| `predict` unidade-contra-unidade, ataque comum (baseline, sem mudança nesta fase) | 34,28 µs |
| `predict` unidade-contra-unidade com Ataque Furtivo (penetração + sem-revide, Fase 10, comparação de regressão) | 33,84 µs |
| `UnitAbilities.city_attack_multiplier` (sem N4 — só o bônus inato de Cerco) | 2,42 µs |
| `V2TechniqueRuntime.city_attack_multiplier` (com N4, Munição Demolidora) | 7,04 µs |
| `CombatResolver.resolve_city_attack` completo (golpe + Munição, ida e volta do HP pro benchmark) | 28,37 µs |
| `V2TechniqueRuntime.city_strike_targets` (alcance 4, 20 cidades espalhadas no mapa) | 52,23 µs |
| checagem isolada do requisito `strike_requires_undisturbed` (comparação de float) | 0,42 µs |
| Pathfinding GROUND, Catapulta (mov. 2) | 237,46 µs |
| Pathfinding GROUND, Guerreiro (mov. 2 — cópia de referência sem o traço `siege`, mesmo perfil GROUND de sempre) | 230,53 µs |
| `SelectionManager._select_unit` (Catapulta) | 1,14 ms |
| `SelectionManager._select_unit` (Colosso de Cerco) | 1,05 ms |

O pathfinding terrestre da Catapulta (237 µs) e do Guerreiro de referência (230 µs) ficam na MESMA ordem de grandeza — nenhuma unidade de Cerco
muda `MovementProfile` (todas continuam GROUND), então nenhuma regressão era esperada nem apareceu. O custo extra de Munição Demolidora dentro de
`resolve_city_attack` é o mesmo tipo de fator multiplicativo já usado desde a Fase 5 (Preparar Lanças) — a diferença entre `city_attack_multiplier`
com e sem N4 pesquisado (2,42 µs vs. 7,04 µs) é dominada pela iteração da lista de técnicas em cache, não por trabalho novo por chamada. A consulta
de alvos do Bombardeio (52,23 µs com 20 cidades no mapa) só examina os tiles dentro do alcance da técnica (`HexMetrics.coords_within`), nunca uma
varredura global do mapa.

### Limitações (de propósito) e ressalvas

- **Números provisórios** (Arsenal 22 PP, Grande Arsenal 55 PP; corpo "catapult"/torres do KayKit); as estatísticas das 4 unidades vieram
  especificadas pelo próprio pedido (não inventadas), só a visão do Trebuchet/Bombarda ficou por minha conta (3, igual à Catapulta).
- **Nomes repetidos com a V1:** "Arsenal de Cerco", "Grande Arsenal", "Catapulta", "Trebuchet", "Bombarda" e "Colosso de Cerco" já existiam como
  objetos V1 com o MESMO nome de exibição e `id`/`kind` diferentes — mesma limitação já documentada nas Fases 7-10 pro Espadachim/Arqueiro; os
  dois convivem no jogo (produção/HUD mostram o mesmo rótulo com custos/stats diferentes conforme a Doutrina pesquisada).
- **"Classe:" no painel** rotula as quatro formas de Cerco como "À distância" (`ArmyComposition.roles_for_kind`, pré-existente, nunca tocado) —
  correto pelo alcance (`attack_range > 1`), mas essa mesma heurística deriva `ROLE_SIEGE` de o PRÉDIO de treino ter o id literal
  `siege_workshop`/`grand_arsenal` (V1), não do traço `siege` — então a label não inclui "Cerco" pras unidades V2. Achado, não bug desta fase
  (heurística pré-existente e intocada, mesmo espírito do "Classe: Cavalaria" documentado na Fase 10); sem efeito funcional (a IA não usa
  conteúdo V2, então essa lista nunca é consultada pra ele).
- **A IA não entende Cerco:** não decide quando atacar uma cidade, qual priorizar, como escoltar as máquinas nem quando usar o Bombardeio; a
  compatibilidade (sem crash, ataque de Cerco básico funcional, slot respeitado) foi conferida, o comportamento estratégico é fase futura.
- **Bombardeio Preparado não tem preview separado de "predição urbana":** a arquitetura de `resolve_city_attack` sempre foi "calcula e aplica na
  hora" (sem uma função `predict_city_attack` companheira, ao contrário do combate unidade-contra-unidade); os testes confirmam o dano REAL
  batendo com o valor calculado pela fórmula, não uma previsão-e-depois-resolução como as demais técnicas de ataque.
- **Penetração de Defesa/sem-revide (Fase 10) não se aplicam a ataque de Cerco** — são campos do combate unidade-contra-unidade; a fórmula
  urbana é a de sempre, com os dois fatores novos desta fase (multiplicador do golpe, Munição Demolidora) plugados nela.
- O contador do Exército Supremo é limitado pelo requisito (2 / 2), mesmo com as seis Doutrinas completas.
- Fora do escopo, **não implementado:** Exército Supremo funcional, vitória, Walls I/II/Fortress, níveis urbanos, Suprimentos/upkeep, economia
  V2, bônus raciais, Magia V2 (Terremoto etc.), IA estratégica V2, Battering Ram/Siege Tower/Ballista (a linha convencional é só
  Catapulta→Trebuchet→Bombarda, por decisão do próprio pedido).
- Fase encerrada quando **a sexta e última Doutrina Militar foi implementada sobre o mesmo molde, fechando Guardião, Guerreiro, Patrulheiro,
  Cavalaria, Ladino e Cerco N1–N9 sem criar um subsistema paralelo.**

---

## Fase 12 — Consolidação Militar e Exército Supremo

Fase deliberadamente **curta**: nenhuma Doutrina nova. Fecha o bloco militar da V2 conectando o
capstone universal **Exército Supremo** ao gameplay (pelo mesmo pipeline dos 54 nós normais) e
corrigindo a classificação semântica das unidades V2 na UI — sem tocar em Ataque, Defesa,
movimento, Técnica, targeting ou custo de nada que já existia.

### O que muda

| Antes (Fases 0–11) | Depois (Fase 12) |
|---|---|
| `v2_supreme_army.gameplay_connected` sempre `false` — capstone inerte mesmo pesquisado | `gameplay_connected = true`; pesquisá-lo desbloqueia de verdade `v2_military_supremacy_access` |
| Painel da unidade V2 usava `ArmyComposition.roles_for_kind` (heurística V1 por movimento/alcance/prédio) | Painel da unidade V2 usa a identidade semântica da própria Doutrina (`branch_role`/`summary`) |
| Ladino (Movimento 3) aparecia como **"Classe: Cavalaria"** | Aparece como **"Sabotagem e alvos prioritários"** |
| Cerco aparecia só como **"Classe: À distância"** | Aparece como **"Conquista e destruição de cidades"** |

### Conexão do capstone — reaproveitando o pipeline existente (nenhuma extensão nova)

`V2UnlockSystem` já era genérico o bastante: bastou (1) acrescentar `"victory_capstone"` a
`CONNECTED_TYPES` e (2) acrescentar `v2_military_supremacy_access` a
`V2DoctrineContent.CONNECTED_UNLOCK_IDS` — a MESMA lista que já dirige os 54 nós normais
(`V2ResearchDatabase._apply_doctrine_content` agora faz `army.gameplay_connected = army.unlock_id
in V2DoctrineContent.CONNECTED_UNLOCK_IDS`, idêntico ao que já fazia pros outros 54). **Nenhuma
classe nova** (`MilitaryCapstoneUnlockSystem` não existe, nem precisou existir). `V2LegendarySystem`
**não foi tocado** — o capstone não interage com o slot Lendário de forma alguma.

O acesso continua **derivado**, nunca guardado: `player.has_unlocked("v2_military_supremacy_access")`
(ou `V2UnlockSystem.is_unlocked(player, "v2_military_supremacy_access")`, equivalentes — `has_unlocked`
já delegava a isso desde a Fase 3) é `true` sse `player.v2_research.is_completed("v2_supreme_army")`.
Não existe `military_supremacy_unlocked` nem qualquer outro campo booleano em `PlayerData`/
`V2ResearchState` — save/load funciona sem NENHUM campo novo (o bloco `"v2_research"` da Fase 1
já persiste `completed_ids`, de onde o acesso é sempre recalculado). Um save antigo, sem o capstone
concluído, carrega com o acesso `false`; resetar a pesquisa V2 (debug) remove o acesso porque remove
a conclusão — nunca destrói unidade, prédio ou upgrade algum.

### Requisito de pesquisa — inalterado

Continua **duas Doutrinas completas em N9** (`V2ResearchNode.requirement`, `capstone_requirement_met`,
`capstone_progress` — nenhuma linha tocada). Qualquer par das seis Doutrinas habilita o capstone;
completar as seis mostra `2 / 2`, nunca `6 / 2`; completar a mesma Doutrina duas vezes não conta
como duas. O capstone continua competindo pelo **mesmo `active_id`** de `V2ResearchState` — sem
slot de pesquisa especial. Concluir o N9 de uma Doutrina conta pro requisito mesmo sem a Unidade
Lendária ter sido produzida ou estar viva: pesquisa e produção continuam conceitos separados.

### Feedback e tooltip

Toast ao concluir (`PlayerData._on_v2_unlock_applied`, só o humano, sem cinemática):
**"Via de vitória desbloqueada: Exército Supremo."** — a frase vem de
`V2UnlockSystem.announcement_text("victory_capstone", display_name)`, genérica por `display_name`
(serve à Transcendência futura sem mudar).

`V2ResearchDatabase.unlock_effect_text`/`node_tooltip` ganharam um parâmetro opcional
`completed: bool = false` (default preserva o comportamento de todo chamador antigo) só pra
diferenciar o texto do capstone nos dois momentos — nenhum outro `unlock_type` usa o parâmetro:

- **Disponível, não concluído:** "Desbloqueia o acesso à Supremacia Militar."
- **Concluído:** "Acesso à Supremacia Militar desbloqueado."
- **Sempre** (as duas situações): "A condição territorial será conectada ao sistema de desenvolvimento
  urbano V2." — nunca apresentado como regra definitiva.

"Supremacia Militar" (o nome da VIA DE VITÓRIA) vem de `V2ResearchDatabase.CAPSTONE_VICTORY_LABELS`,
uma tabela de 2 entradas chaveada por `tree_type` (`MILITARY_DOCTRINE → "Supremacia Militar"`,
`MAGIC_SCHOOL → "Transcendência"`) — não pelo id/nome do nó (`"Exército Supremo"` é o nó; a vitória
que ele desbloqueia tem outro nome, ver `docs/# Aetherlands V2 — Conceito e Direção de.md` #48).
Isso é o que torna o mecanismo genérico o bastante pra conectar `v2_transcendence` no futuro sem um
segundo capstone: só trocar `false`/`true` pelo estado de `v2_transcendence` e a mesma função responde.
`V2ResearchBoard._card_shell` passa `_state.is_completed(node.id)` no lugar do `false` implícito de antes.

### `check_victories` — nunca dispara vitória (e nunca toca a Supremacia V1)

Concluir o capstone só seta `completed_ids["v2_supreme_army"] = true` e emite os sinais de sempre;
`GameManager.check_victories()` (**intocado**) não lê `v2_research` em lugar nenhum. Auditoria
importante: já existia no jogo uma vitória V1.5 **inteiramente separada** chamada "Supremacia
Militar" (`VictoryCampaign.supremacy_achieved`, ativa com `victory_rules_version >= 2`), que lê
`player.researched_techs.has("exercito_supremo")` — um id e um dicionário **totalmente diferentes**
de `v2_research`/`v2_supreme_army`. As duas nunca se tocam (testado explicitamente); completar o
capstone V2 não marca `"exercito_supremo"` em `researched_techs`, então a Supremacia V1 nunca
dispara por causa da V2. As vitórias V1 (Dominação, Territorial, Arcana, e a própria Supremacia
V1.5) continuam exatamente como estavam — nenhuma linha de `GameManager.gd`/`VictoryConditions.gd`/
`VictoryCampaign.gd` foi tocada.

### Classificação semântica das unidades V2 (correção Ladino/Cerco)

**Fonte canônica reaproveitada, sem lista nova:** `V2ResearchNode.branch_role` já existia desde a
Fase 0 (`"tank_frontline"`, `"melee_damage"`, `"ranged_combat"`, `"mobility_shock"`,
`"sabotage_assassination"`, `"city_conquest"`), replicado em **todo** nó da linha — inclusive o N9
(Lendária), que passa pelo mesmo loop de `_add_branches`. Novo helper genérico, `V2UnitLine.role_of
(unit_id)`, resolve a Doutrina de `unit_id` via `doctrine_branch_of` (já cobria N3/N5/N7 e a
Lendária desde a Fase 6) e lê `branch_info(...).role` — **nenhuma lista de seis entradas nova em
HUD/IA/UnitDatabase**, exatamente como pedido. Mesma identidade em toda forma da linha (testado:
Escudeiro = Guardião = Sentinela = Campeão Guardião = `tank_frontline`).

`TileInspector.unit_class_label` ganhou um desvio **antes** de cair na heurística V1
(`ArmyComposition.roles_for_kind`): se `V2UnitLine.doctrine_branch_of(data.visual_kind) != ""`, usa
`branch_info(...).summary` (o mesmo texto que a coluna da árvore de pesquisa já mostrava desde a
Fase 0 — ex.: "Sabotagem e alvos prioritários", "Conquista e destruição de cidades") em vez da
heurística. **`ArmyComposition.roles_for_kind` não foi reescrito nem teve exceção adicionada** — a
mesma função, com a mesma assinatura, continua servindo `RivalAI` (V1) exatamente como antes; só a
UI parou de chamá-la para unidades V2. Traits continuam ortogonais ao papel: o Cavaleiro de Grifo é
`mobility_shock` com os traços `mounted`+`flying`+`legendary`; o Colosso de Cerco é `city_conquest`
com `siege`+`legendary` — nenhum dos dois conjuntos substitui o outro.

Nenhum balanceamento: Ataque/Defesa/movimento/alcance/Técnica/targeting continuam intocados; a
correção é 100% semântica/UI, preparação para uma IA V2 futura poder perguntar "qual é o papel
desta unidade?" (`V2UnitLine.role_of`) sem inferir por nome, movimento, alcance ou prédio de treino
V1 — sem ainda usar essa resposta em nenhuma decisão (nenhuma composição, produção, pesquisa ou
`target_selection` foi alterada).

### Auditoria e totais (as seis Doutrinas, todas juntas)

Confirmado por teste sobre as 54 pesquisas normais + o capstone:

| | |
|---|---:|
| Doutrinas Militares | 6 |
| Pesquisas normais (6 × 9) | 54 |
| Capstone universal | 1 (Exército Supremo) |
| `gameplay_connected = true` no total | 55 (54 + capstone) |
| Técnicas de Doutrina registradas | 12 (2 por Doutrina) |
| Formas convencionais (N3/N5/N7) | 18 (3 por Doutrina) |
| Unidades Lendárias (N9) | 6 |
| Unidades V2 militares totais | 24 |
| Prédios de treino | 6 |
| Prédios de Maestria | 6 |
| Prédios militares V2 totais | 12 |

Cada uma das seis Doutrinas tem exatamente 9 nós com os papéis fixos na ordem
`doctrine_unlock → training_structure → base_unit → technique_1 → evolution_1 → technique_2 →
elite_form → mastery_structure → legendary_candidate`; N3/N5/N7 formam a linha convencional
(`V2UnitLine.unit_ids`); N9 pertence à Doutrina (`doctrine_branch_of`) mas está fora da cadeia
(`is_line_unit` falso). Nós de Magia/Infraestrutura (e `v2_transcendence`) seguem **inertes** — só o
capstone MILITAR foi conectado nesta fase.

### Interações cruzadas entre Doutrinas (amostra, não repete os testes unitários de cada fase)

Confirmadas com unidades **reais** (não só fixtures sintéticas), cada uma no seu próprio teste:

- **Guardião × Cavalaria** — Preparar Lanças (passiva do Guardião, Fase 5) reconhece o traço
  `mounted` de um Cavaleiro V2 real (+50%, testado com e sem o N6 pesquisado).
- **Ladino × Cerco** — Desmantelar (passiva do Ladino, Fase 10) reconhece o traço `siege` de uma
  Catapulta V2 real (+50%).
- **Patrulheiro × Lendária** — Caçada Lendária (passiva intrínseca do Caçador de Lendas, Fase 8)
  reconhece o traço `legendary` de uma Lendária de **outra** Doutrina (Campeão Guardião, +40%) —
  por traço, nunca por nome/id.
- **Mestre das Sombras × Cavaleiro de Grifo** — os dois perfis de movimento (INFILTRATOR/FLYING,
  Fases 9–10) continuam distintos com as duas Lendárias de Doutrinas diferentes vivas ao mesmo
  tempo: o Mestre atravessa uma parede de unidades mas para na água; o Grifo atravessa as duas e
  pousa do outro lado (nunca *sobre* a água — regra de pouso legal da Fase 9 intacta).
- **Cerco** — Munição Demolidora (Fase 11) continua exclusiva de ataque a cidade: um Cerco
  totalmente pesquisado contra uma unidade real não recebe nenhum bônus (dano bate exatamente com a
  fórmula normal, sem o fator de Cerco).

### Smoke test de exército misto e conclusão completa das 54 pesquisas

Seis unidades Elite (uma por Doutrina — Sentinela, Mestre de Armas, Atirador de Elite, Cavaleiro
Blindado, Assassino, Bombarda) coexistem no mesmo grid, cada uma no seu tile: selecionam
(`SelectionManager._select_unit`), movem (`HexGrid.move_unit`), atacam (`CombatResolver.predict`
contra um alvo comum) e mantêm exatamente as suas próprias duas Técnicas
(`V2TechniqueRuntime.techniques_for_unit`) — nenhuma branch vaza pra outra.

Uma civilização de teste completando as 54 pesquisas normais (sem o capstone) tem: os 54 unlocks
consultáveis (`V2UnlockSystem.unlocked_ids`), as 18 formas convencionais + os 6 prédios de treino +
os 6 de Maestria + as 6 Lendárias todas `has_unlocked`, `V2UnitLine.highest_unlocked_form` sempre
apontando pra Elite (N7) em cada linha, e o capstone **disponível** (2/2) mas **não concluído**.

### Save / load

Sem schema novo: nenhum campo foi acrescentado a `PlayerData`, `V2ResearchState` ou ao bloco
`"v2_research"` do save (`SAVE_VERSION` continua 21). O acesso ao capstone é recalculado a cada
`has_unlocked`/`is_unlocked` a partir de `completed_ids`, então sobrevive a save/load, save antigo
(sem o capstone concluído → acesso `false`) e reset de debug (remove `completed_ids["v2_supreme_army"]`
→ acesso `false` de novo) sem nenhum código de migração.

### Correção de documentação (Catapulta, Fase 11)

Auditoria pedida explicitamente (comparar `UnitDatabase` real × teste × documentação × intenção de
identidade anti-cidade): a tabela de definições da Fase 11 registrava Ataque **4,5** pra Catapulta,
mas `UnitDatabase.gd` e `test_v2_siege_arsenal.gd` (que testa explicitamente "Ataque menor que o
Arqueiro, mesmo custando mais") sempre usaram **3,5** — 4,5 empataria com o Arqueiro (Ataque 4,5),
violando a identidade "Cerco nunca ganha de ranged puro". Único ponto de divergência encontrado;
código e teste já concordavam entre si, então a correção foi só na tabela da documentação (linha
única, sem tocar em `UnitDatabase.gd` nem em nenhum teste) — não é um rebalanceamento, é eliminar
uma inconsistência acidental de transcrição.

### Testes (+62; suíte completa **2934 / 2934**, 110 scripts)

| Arquivo | Testes | Cobre |
|---|---:|---|
| `test_v2_supreme_army.gd` | 32 | conexão estrutural (`gameplay_connected`, `CONNECTED_UNLOCK_IDS`/`CONNECTED_TYPES`, sem classe paralela), acesso derivado (antes/depois, duas formas equivalentes, nunca vaza entre civilizações, sem campo novo), requisito/custo inalterados, 0/2·1/2·2/2, mesma Doutrina não conta duas vezes, qualquer par das seis habilita, seis completas ainda mostram 2/2, capstone não exige Lendária viva, pesquisa real ponta a ponta, slot único de pesquisa compartilhado com Magia/Infraestrutura, toast só pro humano (com o texto exato) e nunca pro rival, `announcement_text` genérico, tooltip nos três momentos (antes/disponível/concluído, sempre com a ressalva territorial, larguras de linha ok), `V2ResearchBoard` repassando o estado real pro tooltip, sem bônus de combate/slot Lendário, não é unidade/prédio/técnica/Lendária, `check_victories` continua PLAYING, nunca toca `researched_techs`/"exercito_supremo" (Supremacia V1), save/load (progresso parcial, conclusão, save antigo, sem campo novo), reset de debug |
| `test_v2_unit_roles.gd` | 12 | `role_of` bate com o papel canônico nas 6 Doutrinas × 4 formas (N3/N5/N7/N9), mesma identidade em toda forma, "" pra id V1/desconhecido/prédio/técnica, nunca infere por nome/movimento/alcance (Assassino com Movimento 3 continua `sabotage_assassination`; Colosso com alcance 3 continua `city_conquest`), traits ortogonais ao papel (Grifo, Colosso), `unit_class_label` usa o summary V2 nas 24 formas, Ladino nunca "Cavalaria", Cerco nunca só "À distância", V1 continua na heurística antiga, `ArmyComposition.roles_for_kind` intocada (mesma assinatura, ainda classificaria o Ladino como cavalaria se chamada direto — é por isso que a UI parou de usá-la) |
| `test_v2_military_consolidation.gd` | 18 | auditoria estrutural das seis Doutrinas (9 nós, papéis fixos, linha N3/N5/N7, N9 fora da cadeia mas na Doutrina, duas Técnicas, prédios), `gameplay_connected` = exatamente 54+1, Magia/Infraestrutura/Transcendência inertes, totais finais, as seis Lendárias (forma, produção separada, papel correto), slot global (cada uma das seis bloqueia as outras cinco), 5 interações cruzadas (Guardião×Cavalaria, Ladino×Cerco, Patrulheiro×Lendária, Mestre das Sombras×Grifo, Cerco exclusivo de cidade), smoke test de exército misto (6 papéis coexistindo, selecionam, movem, atacam, técnicas isoladas), conclusão completa das 54 pesquisas, varredura anti-hardcode das novas consultas (`V2UnitLine`, `V2UnlockSystem`, `TileInspector`, `V2ResearchDatabase`) |
| adaptados | — | `test_v2_guardian_n9_flow.gd`, `test_v2_siege_flow.gd`, `test_v2_warrior_flow.gd` (assumiam `v2_supreme_army` inerte mesmo depois de pesquisado), `test_v2_doctrine_content.gd`/`test_v2_research_database.gd` (contagem de nós conectados agora inclui o capstone), `test_v2_doctrine_framework_reuse.gd` (`CONNECTED_UNLOCK_IDS.size()` 54→55), `test_v2_unlock_system.gd` (`announcement_text("victory_capstone", ...)` deixou de ser um passthrough) |

### Validação visual (não-headless, `Main.tscn` real, uma execução)

Fluxo: jogo novo (mapa Grande, 1 rival) → Doutrina do Guardião e do Guerreiro completas via debug
(`capstone_progress` confirmado `(2, 2)` em código) → painel V2 aberto pelo botão de Debug real →
**captura 1**: card "Exército Supremo" no NÓ UNIVERSAL mostrando `Capstone de Vitória Militar`,
`Doutrinas completas: 2 / 2 (N9)`, `Custo 600 · Disponível` → pesquisa selecionada e paga
(`add_knowledge(600)`) pelo runtime real → `is_completed`/`has_unlocked(v2_military_supremacy_access)`
confirmados `true` em código, tooltip antes contendo "Desbloqueia o acesso" e depois contendo
"desbloqueado" → **captura 2**: o mesmo card agora `Custo 600 · Concluído` → `GameManager.
check_victories()` chamado de verdade: estado antes e depois idênticos (`PLAYING`), sem transição →
uma Capital fundada pro humano (o jogo não funda uma sozinha; usa o Colonizador inicial) → Assassino,
Colosso de Cerco e Sentinela spawnados e selecionados pelo `SelectionManager` real: o painel da
unidade (`hud.unit_info_label.text`, lido ao vivo) mostrou exatamente `Classe: Sabotagem e alvos
prioritários` pro Assassino (nunca "Cavalaria"), `Classe: Conquista e destruição de cidades` pro
Colosso (nunca só "À distância") e `Classe: Tank / linha de frente / proteção` pra Sentinela.

Ressalva: a **captura 3** (unidades selecionadas) foi tirada com o painel V2 ainda aberto por cima —
erro do roteiro descartável (esqueceu de fechar o painel antes do print), não do jogo; o rótulo
correto de cada unidade foi confirmado pelo texto real do painel (`hud.unit_info_label.text`, lido
diretamente do nó ao vivo, impresso no console), não só calculado — só a imagem da captura 3 não
mostra o painel de unidade por trás do overlay. Não recapturado, pela regra de "uma vez só".

### Performance

Sem `_process`, timer nem polling novo. Medido (headless, benchmark descartável, menor de 20000
repetições): `V2UnitLine.role_of` **3 µs** contra **24 µs** de `ArmyComposition.roles_for_kind`
(a V2 é mais barata que a heurística V1 que substituiu, porque não olha `UnitDatabase.create_unit`
nem `BuildingDatabase.building_that_trains` — só dois lookups em `Dictionary`);
`TileInspector.unit_class_label` **7 µs** pra unidade V2 contra **28 µs** pra unidade V1 (mesma
razão); `player.has_unlocked(v2_military_supremacy_access)` **2 µs**; `V2ResearchDatabase.
capstone_progress` **25 µs** (percorre as 6 linhas, olhando só o N9 de cada — igual às Fases 0–1);
`node_tooltip` do capstone concluído **70 µs** (inclui a quebra de linha do texto, operação de UI,
não por frame). Nenhuma consulta nova varre as 55 pesquisas por chamada.

### Limitações (de propósito) — pendências explicitamente adiadas

- **City Level / Urbanização (Infraestrutura V2):** não implementado. É a dependência direta da
  condição territorial final da Supremacia Militar.
- **Condição territorial de Supremacia:** não implementada. Direção de design já registrada
  (`docs/# Aetherlands V2 — Conceito e Direção de.md` #48): após o Exército Supremo, conquistar e
  manter pelo menos uma cidade Nível III+ de cada rival relevante (rival eliminado conta como
  satisfeito); o requisito exato será calibrado depois de existir City Level. **Não é um bug** — é
  uma dependência estrutural ainda inexistente, documentada de propósito.
- **Infraestrutura V2** (os 18 nós estruturais das Fases 0–1): não iniciada.
- **Magia V2** (Escolas, conjuradores, feitiços, Manifestações, Transcendência funcional): não
  iniciada — só a metadata estrutural das Fases 0–1 continua no lugar.
- **IA estratégica V2:** não ensinada a escolher Doutrina, pesquisar, montar composição, usar
  Técnica ou produzir counters — mesmo com `V2UnitLine.role_of` agora disponível como consulta
  limpa pra uma IA futura perguntar o papel de uma unidade.
- **Upkeep/Suprimentos:** não implementados.
- Nenhum número de combate/produção/custo foi alterado nesta fase (só a documentação da Catapulta,
  que já batia com o código e o teste).

**Frase de encerramento:** a árvore de Doutrinas Militares V2 está completa de ponta a ponta,
incluindo o capstone Exército Supremo e uma classificação semântica consistente das seis funções
militares. A vitória por Supremacia permanece deliberadamente pendente até existir City Level V2.

---

## Fase 13 — Fundação Urbana V2 (City Level, slots, prédios repetíveis, expansão manual)

**Objetivo:** substituir população como estrutura de desenvolvimento urbano por **City Level
(I–IV)** — um estado LOCAL e explícito por cidade, nunca derivado — e construir, sobre ele, os
quatro fundamentos que a Economia V2 (Fase 14) vai precisar: slots por nível, suporte genérico a
prédios repetíveis, Pontos de Anexação e expansão territorial **manual**. **Não** implementa
Economia (Mercado/Fazenda/Oficina/Academia/Santuário Arcano continuam inexistentes), Suprimentos,
Construtor, Muralhas ou a condição territorial da Supremacia — só a fundação.

### Princípio de design

A progressão é **explícita e local**: `Cidade I → II → III → IV`. Pesquisar Urbanização
**permite** o próximo nível para TODA cidade da civilização; **nenhuma cidade sobe sozinha** —
cada uma precisa produzir seu próprio projeto local. Sem população detalhada, habitação,
felicidade ou aquisição aleatória de tile: cada mecanismo tem uma fonte de dados única e uma regra
simples.

### Auditoria de população (§5/§109 do pedido) — o que foi encontrado, o que mudou

| Uso | Classificação | O que aconteceu nesta fase |
|---|---|---|
| `City.max_building_slots() == population` | **A) limite de prédio** | **Removido.** Agora `V2CityLevelData.max_building_slots(city_level)`. |
| `process_turn()` → `_claim_frontier_tile(hex_grid)` ao crescer população | **B) expansão de território** | **Removida a chamada automática.** `_claim_frontier_tile`/`claim_tile` continuam existindo (usadas por `annex_tile`), só não são mais chamadas sozinhas. |
| `auto_assign_worked_tiles`/`toggle_worked_tile` (capacidade de `worked_tiles` = população) | C) econômico V1 | **Mantido.** Compatibilidade transitória — será substituído pela Economia V2 na Fase 14. |
| Consumo de comida (`population * FOOD_CONSUMPTION_PER_POP`) e o próprio crescimento (`population += 1`) | C) econômico V1 | **Mantido.** A população continua crescendo e alimentando `worked_tiles`/comida — só parou de controlar slots/território. |
| `max_hp()` (`CITY_BASE_MAX_HP + population * CITY_MAX_HP_PER_POPULATION`) | F) combate | **Mantido**, fora de escopo (§102/§54: City Level não mexe em HP/Defesa nesta fase). |
| `CityDefense.gd` (stakes de ameaça, dano da milícia automática) | E/F) IA e combate | **Mantido**, fora de escopo. |
| `GameManager.science_per_turn_for` (`science += population * SCIENCE_PER_POPULATION`) | C) econômico V1 | **Mantido** — Conhecimento é outro eixo econômico que a Fase 14 vai revisitar. |
| `VictoryCampaign.developed(city)` = `population >= 3 and used_building_slots() >= 2` | F) heurística de vitória V1.5 | **Intocado de propósito** — é a Supremacia **V1.5** (`VictoryCampaign.supremacy_achieved`, tech `"exercito_supremo"`), um conceito de "desenvolvida" **diferente** de `City.is_developed_v2()` (Fase 13). Mesmo cuidado de nomenclatura já documentado na Fase 12 (Exército Supremo × "exercito_supremo"). |
| `RivalAI`/`StrategicAI` (gates de população para decisão de IA) | E) IA | **Mantido**, fora de escopo — a IA V2 estratégica continua futura. |
| `HUD`/`TileInspector` (rótulos "População: N", "Tiles trabalhados: N/pop") | D) UI | **Mantido** (população ainda é útil pro jogador entender `worked_tiles`); a linha "Prédios: X/Y" passou a refletir City Level, e o cabeçalho do painel de cidade mostra o nível (`Cidade N`) como informação primária (§69). |

**Nenhuma refatoração destrutiva:** `population` continua no save, sem bump de versão, sem
remoção de campo. Nenhum uso econômico (C) foi tocado. Os nomes literais `max_buildings`,
`city_growth`, `territory_growth` e `expand_territory` **não existem** no código (o pedido os usa
como descrição conceitual, não como símbolos reais) — confirmado por busca no repositório inteiro.

### `V2CityLevelData` — fonte única dos números (novo, `scripts/data/V2CityLevelData.gd`)

Nenhuma outra classe hardcoda slots/limite repetível/raio/Pontos de Anexação/custo — todas
consultam aqui. **BALANCE PLACEHOLDER** (nenhum número balanceado):

| Nível | Slots | Cópias/prédio repetível | Raio territorial | Pontos de Anexação ao chegar | Pesquisa exigida |
|---|---:|---:|---:|---:|---|
| I | 4 | 1 | 1 | 0 (nasce nele) | nenhuma |
| II | 7 | 2 | 2 | 4 | Planejamento Urbano (N1) |
| III | 10 | 3 | 3 | 5 | Cidade Fortificada (N2) |
| IV | 13 | 4 | 4 | 6 | Metrópole (N3) |

Custo do **projeto local** (produção da própria cidade) por transição: I→II = 60 PP + 30 Ouro;
II→III = 120 PP + 70 Ouro; III→IV = 220 PP + 140 Ouro. `is_developed(level) = level >= 3` — única
fonte da regra "Cidade Desenvolvida" (`DEVELOPED_MIN_LEVEL`).

### Conteúdo canônico das 18 pesquisas de Infraestrutura (novo, `V2InfrastructureContent.gd`)

Mesmo padrão de `V2DoctrineContent` (Fase 2), mas com uma diferença deliberada: as **cinco**
linhas econômicas (Economia, Logística, Indústria, Academia, Arcano) ganham nome/descrição/intent
canônicos (`is_placeholder = false`) mas **sem `unlock_id` definitivo** (fica `"placeholder"`) —
pedido explícito de não inventar endereço estável antes de a Fase 14 decidir os objetos reais
(diferente da Fase 2, que já tinha o desenho completo das Doutrinas). Só **Urbanização** ganha
`unlock_id` real (`v2_city_level_2/3/4`) e `unlock_type = "city_level"` (troca o tipo estrutural
`infrastructure_upgrade` só nesses três nós) — `V2ResearchDatabase._apply_infrastructure_content`
aplica isso do mesmo jeito que `_apply_doctrine_content` já fazia pras Doutrinas.
`gameplay_connected = true` só nesses três; as outras 15 pesquisas continuam inertes
(`GAMEPLAY_NOTICE` no tooltip). O tooltip de um nó canônico-mas-não-endereçado não imprime mais o
literal `"(placeholder)"` — pequeno ajuste em `node_tooltip` pra não parecer um bug.

N2 ("Cidade Fortificada") deliberadamente **não** cria Muralhas: o tooltip explica "Fortificações
avançadas serão conectadas posteriormente." — o nome representa o estágio urbano, não um efeito.

### Conexão ao gameplay — reaproveitando o `V2UnlockSystem` (nenhuma classe nova)

`"city_level"` entrou em `V2UnlockSystem.CONNECTED_TYPES` (ao lado de `victory_capstone` da Fase
12) — **nenhuma** `UrbanizationUnlockSystem` foi criada. Toast genérico:
`announcement_text(unlock_type, display_name, unlock_id)` ganhou um terceiro parâmetro opcional
(mesmo padrão do `completed` da Fase 12) só pro caso `"city_level"`, que precisa nomear o **nível**
("Cidade II"), nunca o nó de pesquisa ("Planejamento Urbano") — `V2CityLevelData.
level_name_for_unlock`. Pesquisar Urbanização nunca sobe nenhuma cidade sozinha (testado
explicitamente com múltiplas cidades).

### City Level é local, nunca derivado

`City.city_level: int = 1` (novo campo) — nova cidade nasce em I; cidade capturada mantém seu
nível (`HexGrid.capture_city` nunca toca o campo); nada deriva `city_level` de população, número
de prédios, território, HP ou produção. `City.annexation_points: int = 0` (novo campo) — LOCAL à
cidade, nunca um recurso de `PlayerData`; nunca expira; nunca reseta ao subir de nível (acumula).

### O upgrade urbano é um **projeto local de produção**, não instantâneo

**Decisão arquitetural central da fase:** City Level usa a MESMA fila de produção que unidade e
prédio (`City.production_item`) — nenhuma segunda fila (`urban_production_queue` não existe).
IDs de PROJETO (`v2_city_upgrade_2/3/4`, entram em `production_item`) são **distintos** dos IDs de
UNLOCK da pesquisa (`v2_city_level_2/3/4`) — `V2CityLevelData.target_level_for_project` é o único
lugar que faz essa tradução; nenhum outro código confunde os dois.

**Ouro só é cobrado na conclusão, nunca reservado ao selecionar** (evita depósito/refund/double-
charge em load): `City.production_cost()` ganhou um desvio pra `V2CityLevelData.
upgrade_production_cost` antes do fallback de unidade; `process_turn()` ganhou um ramo cedo (antes
do fluxo normal de unidade/prédio) que, ao atingir o custo em PP, tenta pagar o Ouro
**atomicamente**: paga e conclui, ou — sem Ouro suficiente — trava `stored_production` no custo
total (nunca perde PP, nunca fica negativo) até a cidade ser processada de novo com Ouro
suficiente. **Nenhum boolean de reserva** foi criado; `City.city_upgrade_waiting_for_gold()` é uma
consulta pura derivada de `stored_production >= cost and gold < gold_cost`.

`City.city_upgrade_unavailable_reason()` (única fonte do texto de bloqueio, "" = pode) verifica,
nesta ordem: pesquisa da civilização → **Ouro em mãos pra INICIAR** (não só pra concluir — §12 do
pedido) → produção da cidade já ocupada por outra coisa. Concluir seta `city_level += 1`,
`annexation_points += V2CityLevelData.annexation_grant(city_level)` e devolve `city_level_up` no
dict de `process_turn()` (mesmo padrão de `built_kind`/`spawn_unit_kind`) — `GameManager.gd`
emite o toast só pro humano ("`<Cidade> alcançou Cidade II.`"), sem overlay novo.

### Slots por City Level — nunca mais população

`City.max_building_slots()` chama `V2CityLevelData.max_building_slots(city_level)`. Save legado
**acima** do cap atual nunca perde prédio nenhum (`used_building_slots()` reporta o valor real,
mesmo maior que o cap) — `can_build()` só bloqueia **novo** prédio enquanto isso; subir de nível
eventualmente libera espaço.

### `CopyLimitMode` — suporte genérico a prédios repetíveis (mecanismo, sem conteúdo real)

`BuildingData.copy_limit_mode` (novo enum: `UNIQUE` padrão / `CITY_LEVEL`) — **todo** prédio V1 e
militar V2 continua `UNIQUE` sem alteração de dado nenhum. `City.repeatable_building_counts`
(novo, `id -> int`) guarda a contagem real por prédio `CITY_LEVEL`; `City.buildings` (Dictionary
`id -> true`) continua com a MESMA semântica de sempre ("existe pelo menos uma cópia" —
`requires_building` nunca mudou de significado, uma cópia já satisfaz). `building_count(id)` /
`max_copies_for_building(building)` são os helpers corretos (nunca só `has_building()`).
`used_building_slots()` passou a somar `building_count(id)` por prédio presente em vez de contar
1 por chave — comportamento IDÊNTICO pra todo prédio `UNIQUE` (`building_count` devolve 1), só
muda pra um `CITY_LEVEL` (nenhum existe ainda). **Nenhum prédio real foi registrado** — Mercado,
Fazenda, Oficina, Academia e Santuário Arcano continuam inexistentes; o mecanismo foi provado com
uma fixture de teste (`BuildingData` mock, `copy_limit_mode = CITY_LEVEL`, injetada só durante o
teste em `BuildingDatabase._cache`).

### Expansão territorial — fim do automático, início do manual

`process_turn()` não chama mais `_claim_frontier_tile` (removida a ÚNICA chamada automática do
jogo inteiro, confirmado por auditoria). A função em si **não foi apagada** (reutilizada por
`annex_tile`/`claim_tile`) — nenhuma refatoração destrutiva. Footprint inicial de fundação
(célula + 6 vizinhos, `HexGrid.found_city`) continua igual; território legado além do raio atual
nunca é reduzido.

`City.annex_unavailable_reason(target, hex_grid)` (única fonte do motivo) reutiliza a MESMA
definição de "tile territorialmente válido" que a posse automática já usava (nenhuma restrição de
terreno nova — água já podia ser território, continua podendo): tile precisa existir, não já ser
desta cidade, não pertencer a outra cidade/civilização (inclusive outra cidade do MESMO jogador —
sem transferência), estar dentro de `max_territory_radius(city_level)` (distância hexagonal real,
`HexMetrics.axial_distance`) e ser **contíguo** (vizinho de algum `owned_tiles` já possuído).
`annex_tile()` é atômico: gasta exatamente 1 ponto e reivindica via `claim_tile()`, ou não gasta
nada se inelegível. `eligible_annexation_tiles()` é bounded pelo raio (`HexMetrics.coords_within`,
nunca varre o mapa inteiro).

### Modo de anexação — `SelectionManager` (estado genérico de CIDADE, irmão de `placing_city`)

`annexing_city`/`annexable_coords` (novo, mesmo padrão de `placing_city`/`placeable_coords` da
Fase 3) — nunca misturado com `TargetMode` de Técnica (que pertence a unidades). Clique num tile
elegível anexa e, com pontos restantes, **continua no modo** (diferente de posicionar prédio, que
sempre sai após um clique — decisão explícita do pedido, §50); ESC (`PauseMenu`) ou ficar sem
pontos encerra. Clique num tile inelegível não gasta nada e não sai do modo. Refresh visual
reaproveita `HexGrid.recompute_fog` (o mesmo pipeline que já atualiza o tingimento de território
a cada evento discreto — nenhum gancho novo, ver comentário em `HexGrid._apply_fog_visuals`).

### API semântica "Cidade Desenvolvida" — nunca conecta vitória

`City.is_developed_v2() -> bool` = `city_level >= 3`. **Não** está ligada a `check_victories()` —
testado explicitamente: uma cidade Nível III + Exército Supremo concluído (Fase 12) continua sem
disparar vitória nenhuma. A condição territorial real (conquistar e manter uma cidade Nível III+
de cada rival) fica para fase futura, quando existir uma razão para revisitá-la.

### UI (painel de cidade)

Cabeçalho: `Cidade N (sua/rival) | População: P`; `Prédios: X/Y` já reflete o novo cap
automaticamente (mesma função); nova linha `Anexação: N` (só o dono vê). Container dinâmico
`V2CityActions` (mesmo padrão de `V2Actions` da Fase 4, sem mexer no `HUD.tscn`): botão
`Evoluir para Cidade N — X PP + Y Ouro` (ausente em Cidade IV; mostra "Aguardando N Ouro." quando
os PP já completaram mas falta Ouro) e `Anexar território (N)` (desabilitado com 0 pontos).

### Save / load

Três campos opcionais por cidade (`city_level`, `annexation_points`,
`repeatable_building_counts`) — sem bump de `SAVE_VERSION` (mesmo padrão do bloco `v2_research`
da Fase 1). Save antigo sem eles carrega em Cidade I / 0 pontos (nunca inferido). Um projeto de
upgrade em andamento — inclusive parado esperando Ouro — sobrevive ao ciclo sem estado extra
(`stored_production`/`production_item`, já salvos, já bastam).

### Captura

`HexGrid.capture_city` nunca tocava `population`/`buildings`/`owned_tiles`, e continua não tocando
os três campos novos — nível, pontos, prédios e território sobrevivem à captura automaticamente,
sem nenhuma linha de código nova (a preservação "veio de graça" da arquitetura existente). Uma
produção de City Project em andamento persiste na captura, mesma semântica de qualquer produção
em andamento (nenhuma exceção específica criada).

### IA

Sem decisão nova. Compatibilidade testada: cidade rival nasce e permanece Cidade I (4 slots), não
expande território automaticamente, e 6 turnos reais com o conteúdo presente não crasham nem são
usados pelo rival (a IA não pesquisa Urbanização nesta fase).

### Testes (+83; suíte completa **2995 / 2995**, 113 scripts)

| Arquivo | Cobre |
|---|---|
| `test_v2_city_level.gd` | `V2CityLevelData` (números, clamp, next_level, is_developed, ids de projeto×unlock), as 18 pesquisas de Infraestrutura (nomes canônicos, só Urbanização conectada, tooltip sem "(placeholder)"), nova cidade (nível 1, 0 pontos), fluxo completo de upgrade I→II→III→IV (custo, Ouro só na conclusão, Ouro insuficiente esperando sem perder PP nem cobrar duas vezes), uma pesquisa não sobe todas as cidades, isolamento entre civilizações, `is_developed_v2`, slots (cap por nível, save legado over-cap), `CopyLimitMode` (UNIQUE nunca permite 2ª cópia, CITY_LEVEL escala com o nível via fixture, `requires_building` continua "uma cópia basta"), anti-hardcode |
| `test_v2_city_annexation.gd` | expansão automática desligada, elegibilidade completa (pontos, raio, contiguidade, tile de outra cidade/civ, água permitida), atomicidade, pontos acumulam sem resetar, território legado preservado, modo do `SelectionManager` (mira, clique válido continua no modo, clique inválido não gasta nem sai, ESC, exclusão mútua com outros modos), bounded pelo raio |
| `test_v2_city_level_flow.gd` | save/load real via `SaveManager` (nível, pontos, projeto em andamento, projeto esperando Ouro, território anexado, save antigo sem os campos), captura preserva tudo, IA (Cidade I estável, 6 turnos sem crash), Cidade Desenvolvida + Exército Supremo nunca vencem, fluxo principal ponta a ponta completo (fundação → pesquisa → upgrade → anexação → turnos sem crescimento automático → III → IV → save/load → Exército Supremo independente → `check_victories` ainda `PLAYING`) |
| `test_v2_city_hud.gd` | botão de upgrade (texto com custo, motivo de bloqueio, ausente em Cidade IV, "Aguardando Ouro", clique inicia o projeto), botão de anexação (contador, desabilitado em 0, clique entra no modo do `SelectionManager`) |
| adaptados | `test_v2_doctrine_content.gd`, `test_v2_research_database.gd`, `test_v2_military_consolidation.gd` (Infraestrutura deixou de ser 100% inerte/estrutural); `test_v2_guardian_hall.gd`, `test_v2_guardian_mastery.gd`, `test_v2_warrior_mastery_and_hero.gd`, `test_v2_{cavalry,ranger,rogue,siege}_mastery_and_*.gd` (assumiam `population` controlando slots); `test_city.gd` (slots e expansão automática de território) |

### Validação visual (não-headless, `Main.tscn` real, uma execução)

Fluxo: jogo novo → capital fundada pelo Colonizador inicial → `city_level=1`,
`max_building_slots=4` confirmados em código → pesquisa de Planejamento Urbano (debug) → HUD real
mostra o botão **`Evoluir para Cidade II — 60 PP + 30 Ouro`** habilitado → clique real
(`.pressed.emit()`) inicia `production_item = v2_city_upgrade_2` → produção completada (debug) →
toast **"Desenvolvimento urbano disponível: Cidade II"** (da pesquisa) visível na captura, cidade
sobe para **Cidade II**, Ouro 100→70 → **captura 1**: painel real mostra
`Cidade II (sua) | População: 1`, `Predios: 0/7`, `Anexação: 4`, e os dois botões
(`Evoluir para Cidade III — 120 PP + 70 Ouro` / `Anexar território (4)`) → clique real no botão de
anexação chama `SelectionManager.start_city_annexation`, confirmado `annexing_city == city` com
**12 tiles elegíveis** (raio 2) → **captura 2** (mira ativa) → um tile real a distância 2 é
anexado via `_handle_city_annexation_click`: `owned_tiles` 7→8, `Anexação` 4→3, toast real
**"Capital de Teste anexou um novo tile ao território."** → 5 turnos reais processados
(`city.process_turn`) → `owned_tiles` continua em 8, **confirmando que território NÃO cresce mais
sozinho** → **captura 3**: painel atualizado (`Anexação: 3`, população cresceu pra 3 por
economia normal, `Tiles trabalhados: 3/3`).

Ressalva: o destaque visual dos tiles elegíveis de anexação (captura 2) é uma tinta discreta no
hexágono, difícil de distinguir da captura anterior numa câmera afastada — mesma limitação já
documentada em fases anteriores para o realce de alvo de Técnica; os 12 tiles elegíveis foram
confirmados por dado (`SelectionManager.annexable_coords.size()`), não só pela imagem. A primeira
execução do roteiro abortou antes de qualquer captura por um erro de tipagem no próprio script
descartável (`var row := ...` sem anotação de tipo explícita — erro do script, não do jogo); a
segunda execução é a documentada acima.

### Performance

Sem `_process`/polling novo. Medido (headless, benchmark descartável, menor de 20000 repetições):
`V2CityLevelData.max_building_slots`/`upgrade_gold_cost` **< 1 µs** (consulta O(1) em Dictionary
por nível); `city.max_building_slots()` **1 µs**; `city.used_building_slots()` **4 µs**;
`city.building_count()` **1 µs**; `city.can_build()` **14 µs** (mesma ordem de grandeza de
`can_build` de um prédio V1/V2 qualquer, nenhuma regressão); `city.is_developed_v2()` **< 1 µs**;
`city.city_upgrade_unavailable_reason()` **6 µs**; `city.annex_unavailable_reason()` **4 µs**;
`city.eligible_annexation_tiles()` (raio 2, 2000 repetições) **73 µs** — bounded pelo raio
(`HexMetrics.coords_within`), nunca varre o mapa inteiro; recalculado só ao entrar no modo, anexar
um tile ou quando level/pontos mudam — nunca por frame.

### Limitações (de propósito)

- **Números provisórios** (slots, custos, Pontos de Anexação) — nenhum balanceamento.
- **Nenhum prédio repetível real** — Mercado/Fazenda/Oficina/Academia/Santuário Arcano ficam pra
  Fase 14; o mecanismo `CopyLimitMode.CITY_LEVEL` só foi provado com fixture de teste.
- **UI de anexação sem clique de mouse simulado de verdade** nos testes automatizados (mira,
  realce e ESC reais; o clique em si foi chamado direto, mesmo padrão das Fases 7-11).
- **City Level não afeta visão, HP/Defesa, Produção ou geração de recurso** — intencional, fora do
  escopo desta fase (§53-56 do pedido).
- **A IA não pesquisa Urbanização nem produz City Project** — comportamento estratégico é fase
  futura.
- Fora do escopo, **não implementado:** Mercado, Fazenda, Oficina, Academia, Santuário Arcano,
  Economia V2, Suprimentos, upkeep, Construtor, melhorias de recurso, Muralhas, ataque ativo de
  cidade, condição territorial da Supremacia, Magia V2, IA estratégica V2.

**Frase de encerramento:** a Fundação Urbana V2 está funcional: City Level substitui população
como estrutura de desenvolvimento, cidades possuem slots e expansão territorial controlados
explicitamente, e a base para a Economia V2 e para a futura Supremacia está pronta.

---

## Fase 14 — Economia V2 (Ouro, Suprimentos, Produção, Conhecimento, Mana)

**Objetivo:** substituir a economia de cidade herdada da V1 (tiles trabalhados + bônus de prédio,
alimentando Ouro/Produção/Mana ao mesmo tempo que Comida) por uma pipeline V2 explícita e única —
cinco recursos funcionais, cinco prédios econômicos repetíveis reais e as 18 pesquisas de
Infraestrutura totalmente conectadas. **Não implementa:** consumo de Suprimentos, Tensão
Logística, upkeep de Ouro/Mana, Déficit, Construtor, melhorias de recurso do mapa, Muralhas,
ataque ativo de cidade, condição territorial da Supremacia, Magia V2, IA estratégica V2.

### Auditoria da economia V1 (obrigatória antes de qualquer mudança, §29/§47 do pedido)

| Renda | Fonte V1 encontrada | Classificação | O que aconteceu nesta fase |
|---|---|---|---|
| Ouro (recorrente) | `City.collect_yields()` — tile `gold_yield` + `BuildingDatabase.total_bonus().gold` (Mercado/Grand Market/Trading Post V1 bonus_gold) | B) renda de cidade/tile | **Desligada como fonte ATIVA.** `GameManager` parou de somar `result.gold` (retorno de `City.process_turn()`) a `player.gold`. |
| Ouro (eventos) | `TradeManager` (rota comercial), `CombatResolver` (saque de combate), `HexGrid` (recompensa de ruína), `DragonEvent`, `UnitAbilities` | D) evento/recompensa | **Mantida intocada** — nenhuma dessas linhas foi tocada; continuam somando direto em `player.gold` (§48: "recompensas/eventos externos continuam funcionando", coberto por teste). |
| Mana (recorrente) | Mesmo `collect_yields()` (`mana_yield` de recurso estratégico/tech + `bonus_mana` de Torre dos Sábios/Santuário Arcano V1) | B) renda de cidade/tile | **Desligada como fonte ativa** — mesmo ponto de corte do Ouro. |
| Mana (eventos) | `HexGrid` (ruína), `DragonEvent` | D) evento/recompensa | **Mantida intocada.** |
| Produção local | Mesmo `collect_yields()` (`production_yield` de tile + `bonus_production` de Oficina/Workshop II V1 + `CITY_CENTER_MIN_PRODUCTION`) | B) renda de cidade/tile | **Desligada como fonte ativa** de `City.stored_production`. |
| Produção (eventos) | `TradeManager` (rota), `V2LegendarySystem` (reembolso de Lendária recusada) | D) evento/recompensa | **Mantida intocada.** |
| Conhecimento V1 ("Ciência") | `GameManager.science_per_turn_for` (população × `SCIENCE_PER_POPULATION`) → `player.research_progress`/`current_research` (árvore V1) | C) econômico V1, pipeline PARALELA | **Intocada, nunca tocou Conhecimento V2** — são dois recursos e dois pipelines diferentes (§38/§49 do pedido; `V2ResearchState` nunca leu/escreveu `research_progress`). |
| Comida/população | `collect_yields().food` + `FOOD_CONSUMPTION_PER_POP` + `food_storage_cap()` | C) econômico V1 | **Intocada.** Não existe Comida V2 (§50) — a Fazenda produz Capacidade de Suprimentos, nunca comida. |
| Suprimentos | Não existia antes desta fase | — | **Novo fundamento**, capacidade pura (nunca estoque). |

**Caminho desligado, exatamente:** `City.process_turn()` parou de fazer
`stored_production += yields.production`; `GameManager._on_turn_changed()` parou de fazer
`player.gold += result.gold` / `mana_income += result.mana` por cidade. `City.collect_yields()`
**continua computando** `food`/`production`/`gold`/`mana` do jeito de sempre (tile + bônus de
prédio V1) — só a comida desse retorno ainda alimenta algo ativo (`stored_food`); os outros três
campos continuam existindo no dict só porque `effective_tile_yield`/`_tile_claim_score`
(pontuação de tile pra trabalho) ainda os consultam, e a API pública não foi alterada. Nenhuma
linha de `ResourceDatabase`/`RaceEconomy`/`CityIdentity`/`TechDatabase.yield_bonus_for` foi
tocada — continuam computando os mesmos números de sempre, só não chegam mais a
`player.gold`/`player.mana`/`City.stored_production`.

**Efeito colateral honesto, documentado (não escondido):** os prédios econômicos **V1**
(Mercado, Mercado Grande, Empório, Posto Comercial, Oficina, Oficina II, Torre dos Sábios,
Santuário Arcano V1) continuam existindo, ocupando slot e sendo pesquisáveis/construíveis — mas o
`bonus_gold`/`bonus_production`/`bonus_mana` deles ficou **vestigial**: o número ainda é somado por
`BuildingDatabase.total_bonus()` (intocado, ainda testado por `test_buildings.gd`), só que esse
total não alimenta mais nenhum recurso ativo do jogador. Isso é uma consequência direta e
pretendida de "a economia urbana V2 é a fonte ATIVA" (§48); não há um substituto automático para
essas oito estruturas nesta fase — ficam como uma pendência de conteúdo V1 legado, fora do escopo
pedido (que era conectar os CINCO prédios V2, não migrar os V1).

### Modelo canônico e fonte única dos números

`V2InfrastructureEconomyData` (novo, `scripts/data/`) é a fonte única: base por cidade (Ouro +2,
Suprimentos +4, Produção +4, Conhecimento +2, Mana +1 — **BALANCE PLACEHOLDER**, nunca dependem de
população/worked_tiles/City Level/território/recursos do mapa, §3) e, por linha econômica, o id do
prédio, o `resource` que ele afeta, o custo de produção e os três yields por cópia (tier 1/2/3).
Os 15 `unlock_id` das cinco linhas econômicas (§65 do pedido) são os literais exatos pedidos —
nunca alterados depois de escritos.

| Linha | Prédio | Recurso | Custo | Yield N1/N2/N3 por cópia |
|---|---|---|---|---|
| Economia | Mercado (`v2_building_market`) | Ouro | 20 PP | 4 / 6 / 8 |
| Logística | Fazenda (`v2_building_farm`) | Suprimentos (capacidade) | 20 PP | 4 / 6 / 8 |
| Indústria | Oficina (`v2_building_workshop`) | Produção (LOCAL) | 24 PP | 2 / 3 / 4 |
| Academia | Academia (`v2_building_academy`) | Conhecimento | 24 PP | 2 / 3 / 4 |
| Arcano | Santuário Arcano (`v2_building_arcane_shrine`) | Mana | 24 PP | 2 / 3 / 4 |

### Runtime genérico — `V2EconomyRuntime`

Um único `RefCounted` estático (`scripts/core/`), sem `_process`, sem cache próprio, sem estado —
tudo derivado a cada chamada. **Nenhuma classe irmã por recurso** (não existe `GoldSystem`/
`SupplySystem`/`WorkshopSystem`/`AcademySystem`/`ManaSystem`, §5 do pedido). API:
`infrastructure_tier(player, branch)` (1..3, sempre ≥1 mesmo sem pesquisa — ver captura abaixo),
`building_output(player, building_id)`, `city_gold_income`/`city_supply_capacity`/
`city_production_income`/`city_knowledge_income`/`city_mana_income` (todas por cidade — a mesma
função interna `_city_branch_income(city, branch, base)` compartilhada pelas cinco, dirigida pelo
dado, nunca por `if building_id == "..."`), `player_gold_income`/`player_supply_capacity`/
`player_knowledge_income`/`player_mana_income` (soma as cidades do jogador), `apply_turn_income`
(credita Ouro+Mana+Conhecimento uma vez) e `city_income_breakdown` (números pra UI/teste, §73).
Um teste varre o arquivo (sem comentários) e confirma que nenhum dos cinco ids de prédio aparece
no código — só no dado central (§128/§129).

### Processamento de turno (§51)

Em `GameManager._on_turn_changed()`, por civilização: `V2EconomyRuntime.apply_turn_income(player)`
roda **uma vez**, **antes** do laço de cidades que chama `city.process_turn(hex_grid)` — o
snapshot de prédios usado é sempre o do INÍCIO do turno (nenhuma cidade completou produção ainda
nesse ponto). Suprimentos não entra em `apply_turn_income` (é consulta pura, nunca creditada —
§53). Produção não entra (é local: cada `City.process_turn()` lê
`V2EconomyRuntime.city_production_income(self)` diretamente, substituindo o antigo
`stored_production += yields.production`). Um prédio que **termina de construir NESTE turno**
nunca conta pra ele mesmo (a leitura de `city_production_income`/`apply_turn_income` acontece antes
da conclusão da fila de produção daquele mesmo `process_turn`) — só passa a valer no turno
seguinte (§52/§104, testado).

### Suprimentos: capacidade pura, nunca estoque (§19/§53)

Não existe `player.supplies`. `V2EconomyRuntime.player_supply_capacity(player)` é uma soma
recalculada a cada chamada; perder ou capturar uma Fazenda muda o resultado na consulta
**seguinte**, sem hook de turno, sem estado sincronizado. Consumo militar (§20/§124) **não existe
ainda** — é Fase 15; os tooltips de Logística dizem isso explicitamente.

### Os cinco prédios — repetição real (§7-10/§58/§98)

Todos usam `BuildingData.CopyLimitMode.CITY_LEVEL` (mecanismo da Fase 13, agora com conteúdo real
pela primeira vez), sem `requires_building` (cada um é infraestrutura básica independente) e sem
`trains_unit`. Diferente dos prédios militares V2 (Salão dos Guardiões etc.), o yield de cada
cópia **não** vem de `bonus_gold`/`bonus_production`/`bonus_mana` (ficam 0 nos cinco) — vem inteiro
de `V2EconomyRuntime`, evitando a duplicação com `BuildingDatabase.total_bonus()`.

**Múltiplas cópias físicas reais** (§8/§58/§98, testado no mapa real, não só fixture): cada cópia
ocupa seu próprio tile (`City.repeatable_building_coords`, novo — `Dictionary` `id -> Array[Vector2i]`,
**separado** de `building_coords`, que continua guardando 1 coord por id pra todo prédio `UNIQUE`
sem alteração nenhuma — mesma decisão de design aditiva de `repeatable_building_counts` na Fase
13), tem seu próprio modelo 3D (`HexGrid.place_building` chamado uma vez por cópia) e sobrevive a
save/load/captura. `City.buildings[id]` continua significando "existe pelo menos uma" (nunca
alterado); `City.building_count(id)`/`repeatable_building_counts[id]` são as fontes da contagem
real.

**N2/N3 nunca criam um prédio novo** (§10/§63/§101): só mudam `unlock_type`/`gameplay_connected`
do NÓ de pesquisa; o yield por cópia já existente muda **imediatamente** na consulta seguinte
(nenhum "reconstruir" nem upgrade físico).

### As 18 pesquisas de Infraestrutura — 18/18 conectadas (§64-70/§92)

`V2InfrastructureContent` ganhou os 15 `unlock_id` das linhas econômicas (literais exatos do
pedido); `V2ResearchDatabase._apply_infrastructure_content` decide o `unlock_type` por branch:
Urbanização continua `"city_level"` (Fase 13, intocado); as cinco linhas econômicas usam
`"building"` no N1 e `"infrastructure_upgrade"` no N2/N3 (`"infrastructure_upgrade"` entrou em
`V2UnlockSystem.CONNECTED_TYPES`). Texto do efeito (`V2ResearchDatabase.unlock_effect_text`) é
gerado por uma função nova (`_infrastructure_economy_effect_text`), dirigida pelo `resource` do
dado central — nunca um texto fixo por nó: "Desbloqueia Mercado. Cada Mercado produz 4 Ouro por
turno." (N1), "Mercados passam a produzir 6 Ouro por turno." (N2), com a ressalva de Logística
("Suprimentos são capacidade logística, não estoque. O consumo militar será conectado
posteriormente.") sempre anexada nas três pesquisas dessa linha, e a nota de Indústria N1
("Também habilitará a infraestrutura de Construtores na próxima etapa econômica.") na descrição
do nó. Nenhum tooltip de Infraestrutura mostra mais "Gameplay V2 ainda não conectado." — as 18
pesquisas (3 Urbanização + 15 econômicas) somam `gameplay_connected = true`; só Magia (55 nós +
Transcendência) continua inerte.

**Toasts** (§67): N1 usa o texto normal de prédio, mas resolvido pelo `BuildingDatabase` (não pelo
nome da pesquisa) — `V2UnlockSystem.announcement_text("building", ...)` agora busca
`BuildingDatabase.get_building(unlock_id).display_name` primeiro, então "Mercados Locais" (nó) vira
corretamente "Novo prédio disponível: Mercado." (prédio); Doutrinas continuam batendo os dois
nomes, então esse fallback nunca muda nada nelas. N2/N3 usam o genérico novo
`"Melhoria de infraestrutura desbloqueada: <nome do nó>."`.

### Prédio capturado sem a pesquisa do novo dono (§55-57/§102)

Decisão canônica testada: um Mercado físico capturado continua rendendo — nunca 0 — porque
`V2EconomyRuntime.infrastructure_tier` **sempre** devolve pelo menos 1, mesmo que o dono atual não
tenha NENHUMA pesquisa da linha (o gate de pesquisa só bloqueia construir uma cópia NOVA, em
`City._tech_unlocked_for_building`, via `V2UnlockSystem.is_unlocked` — pipeline intocado da Fase
3). A eficiência é sempre do **dono atual** (nunca de quem construiu, nunca salva no prédio): se o
novo dono pesquisar N2/N3 depois, o Mercado capturado sobe de tier imediatamente, sem reconstrução.
Reset de pesquisa por debug segue a mesma regra (o prédio nunca é destruído, só o yield recua).

### Save / load e captura

Campo novo opcional por cidade: `repeatable_building_coords` (mesmo padrão de
`repeatable_building_counts` na Fase 13 — sem bump de `SAVE_VERSION`; save antigo carrega com o
dict vazio, nunca inferido). Nenhum outro schema novo: Ouro/Mana usam os campos já existentes;
Conhecimento já vivia em `V2ResearchState` (progresso/overflow, Fase 1); Suprimentos/renda por
turno **nunca são salvos** (§6/§81 — tudo derivado). `HexGrid.capture_city` ganhou um segundo laço
(além do já existente pra `building_coords`) iterando `repeatable_building_coords.values()` pra
repintar CADA cópia física pro novo dono — sem isso um Mercado capturado ficaria com a cor do dono
antigo no mapa.

### UI

Barra superior (`HUD._refresh_stats`, §71): Ouro passou a mostrar renda também
(`"Ouro: 112 (+8)"`, igual ao padrão que Mana já usava) — a renda vem inteira de
`V2EconomyRuntime.player_gold_income`, nunca somada com a antiga renda V1. Dois indicadores novos,
criados em código no `_ready()` (mesmo padrão de `V2Actions`/`V2CityActions` — sem editar
`HUD.tscn`): `"Conhecimento: +N/turno"` e `"Suprimentos: capacidade N"` (nunca `"0 / N"`, pra não
sugerir consumo que ainda não existe, §71). Painel da cidade (`TileInspector._city_entry`, §72):
nova linha `"Produção: +X PP/turno"` e `"Ouro: +X | Suprimentos: +X | Conhecimento: +X | Mana: +X"`
(o que ESTA cidade contribui); a lista de prédios ganhou contagem (`"Mercado ×2"`) pra prédio
repetível. Botão de produção dos cinco prédios: **nenhuma linha nova em HUD.gd** —
`_build_additional_building_buttons()` (Fase 3) já itera `BuildingDatabase.all_buildings()`
genericamente, então os cinco entraram de graça.

### IA

Sem decisão nova (não pesquisa Infraestrutura, não constrói os cinco prédios). Sistêmica, não
cheat: rivais recebem a MESMA renda base de qualquer cidade seguindo o MESMO runtime; um prédio
econômico capturado passaria a contribuir pra eles também, pelo mesmo mecanismo do jogador. Testado
com 6 turnos reais (`TurnManager.end_turn()`): sem crash, rival segue sem nenhum dos cinco prédios,
renda base presente.

### Testes (+63; suíte completa **3058 / 3058**, 121 scripts)

| Arquivo | Cobre |
|---|---|
| `test_v2_economy_data.gd` | `V2InfrastructureEconomyData` (base, ids, custos, yields, clamp de tier), as 18 pesquisas conectadas (§92), distribuição de `unlock_type` (5 building + 10 infrastructure_upgrade + 3 city_level), textos dinâmicos com números reais, nota de Logística, nota de Construtor futuro em Indústria, anti-hardcode do runtime |
| `test_v2_economy_buildings.gd` | Dados dos 5 prédios, construção real por linha (Mercado/Fazenda/Oficina/Academia/Santuário — gate de pesquisa, yield por tier, isolamento local da Oficina, isolamento entre civilizações), **2 cópias reais no mapa** (não fixture) numa Cidade II, cap de cópias por nível, cap de slots em Cidade I, N2/N3 nunca criam prédio novo, prédio capturado sem pesquisa do novo dono (tier 1) e eficiência do novo dono após pesquisar |
| `test_v2_economy_turn.gd` | Produção/Ouro/Mana V1 (terreno de yield absurdo + população alta) nunca vazam pra V2, trade route/loot continuam funcionando, Ciência V1 ≠ Conhecimento V2 nos dois sentidos, Suprimentos ≠ Comida, overflow de Conhecimento acumula sem projeto ativo, reset de debug (prédio fica, yield volta ao tier 1, sem cópia nova), cidade sem prédio econômico ainda rende a base inteira |
| `test_v2_economy_flow.gd` | Especialização por City Level (4 Fazendas numa Cidade IV sem 4 pesquisas), captura transfere Ouro/Suprimentos/Conhecimento/Mana imediatamente, 6 turnos reais (IA recebe base, nunca constrói), **fluxo principal ponta a ponta** (Cidade I → pesquisa real sem debug → os 5 prédios com N2/N3 → Cidade II com 2ª cópia → save/load → Doutrinas intactas), Oficina acelera produção militar V2, Ouro do Mercado disponível pro upgrade de unidade, Conhecimento da Academia completa uma pesquisa de Doutrina real |
| adaptados | `test_city.gd` (produção-base não depende mais de terreno), `test_hud.gd` (rótulo de Ouro com renda), `test_v2_cavalry_flow.gd` (snapshot de Mana desatualizado por renda de turno real — bug do teste, corrigido), `test_v2_city_level.gd`/`test_v2_doctrine_content.gd`/`test_v2_military_consolidation.gd`/`test_v2_research_database.gd`/`test_v2_unlock_system.gd` (assumiam a Infraestrutura econômica inerte) |

### Validação visual (não-headless, `Main.tscn` real, uma execução — mais uma corretiva por dois
bugs do PRÓPRIO roteiro descartável, nunca do jogo: caminho de `Main.tscn` errado na 1ª tentativa,
e duas capturas de tela idênticas seguidas na 2ª por faltar `await get_tree().process_frame` antes
de cada screenshot — o viewport só re-renderiza depois de um frame processado)

Fluxo: Colonizador funda a capital pelo caminho real (`SelectionManager.found_city_with_selected`)
→ pesquisa real de Mercados Locais **sem** debug de Conhecimento (10 créditos de
`apply_turn_income`, nenhum botão "+Knowledge") → botão real `Mercado — 20 PP` entra em modo de
posicionamento (`SelectionManager.placing_city`), clique real num tile → `TurnManager.end_turn()`
completa (debug_mode) → toasts reais confirmados: "Novo prédio disponível: Mercado.",
"...concluiu: Mercado", "Melhoria de infraestrutura desbloqueada: Contabilidade." → barra superior
`Ouro: 22 (+6)` (base 2 + tier 1 = 4) → depois de Contabilidade (N2, sem reconstruir): `Ouro: 22
(+8)` (base 2 + tier 2 = 6), `cópias: 1` confirmado → Cidade II, segunda cópia real construída num
segundo tile: painel mostra `Predios: 2/7 (Mercado ×2)`, `Ouro: +14` (base 2 + 2×6), barra superior
`Ouro: 30 (+14)`, dois prédios físicos confirmados (`hex_grid.get_building_at` nos dois tiles) →
Fazenda/Oficina/Academia construídas (Santuário Arcano ficou sem tile livre nesta execução — mapa
real gerado com água/relevo, só 5 dos 6 vizinhos da cidade eram terreno construível; achado da
execução, não bug, registrado abaixo) → `Suprimentos: capacidade 8`, `Conhecimento: +4/turno`,
`Mana: 15 (+1)`, Produção local `6.0` (base 4 + Oficina 2) → aba Infraestrutura do painel V2 (
`show_tree`): as seis linhas visíveis com nomes canônicos, custos 20/60/150, N1 "Concluído" nas
cinco linhas econômicas + Urbanização, N2 "Disponível" (Economia com N3 também "Disponível", as
outras "Bloqueado" — coerente com só ter pesquisado até N2/N1 em cada), nenhum texto "Gameplay V2
ainda não conectado." confirmado por varredura de todos os 18 nós.

### Performance (headless, benchmark descartável, mínimo de 5×20000 repetições ou 5×4000 pra
consultas agregadas de 5 cidades)

| Operação | Custo |
|---|---:|
| `infrastructure_tier` | 4,16 µs |
| `building_output` | 5,95 µs |
| `city_gold_income` | 8,77 µs |
| `city_production_income` | 9,59 µs |
| `player_gold_income` (5 cidades) | 15,47 µs |
| `player_supply_capacity` (5 cidades) | 15,90 µs |
| `player_knowledge_income` (5 cidades) | 16,88 µs |
| `apply_turn_income` (5 cidades, sem projeto ativo) | 51,34 µs |
| `city.can_build(market)` | 3,44 µs |
| `city.used_building_slots` | 11,04 µs |
| `city.process_turn` completo (5 cidades no grid, 1 com os 5 prédios) | 220,82 µs/chamada |

Sem `_process`/polling/scan global: `V2EconomyRuntime` só itera as cidades do PRÓPRIO jogador (nunca
o mapa, nunca todas as unidades, nunca os 128 nós de pesquisa) e o tier de pesquisa é uma consulta
O(1) em `Dictionary` (via `V2ResearchState.is_completed`, já cacheado desde a Fase 1).

### Limitações (de propósito) e ressalvas

- **Números provisórios** (base, yields, custos dos 5 prédios) — nenhum balanceamento.
- **Prédios econômicos V1** (Mercado/Mercado Grande/Empório/Posto Comercial/Oficina/Oficina
  II/Torre dos Sábios/Santuário Arcano da árvore V1) ficaram com o bônus de Ouro/Produção/Mana
  **vestigial** — continuam existindo, ocupando slot, mas não alimentam mais nenhum recurso ativo
  (consequência documentada da fonte econômica V2 se tornar ativa, §48; nenhuma migração desses
  prédios foi pedida nesta fase).
- **Santuário Arcano só tem um tile candidato limitado** por cidade fundada em mapa real (6
  vizinhos, alguns podem ser água/relevo) — não é um bug, é o território pequeno de uma Cidade
  I/II sem anexação; a validação visual encontrou esse limite na prática.
- **Suprimentos sem consumo** (§20/§124) — capacidade existe, nada a consome ainda.
- **Nenhum prédio V1 de economia foi removido ou migrado.**
- Fora do escopo, **não implementado:** Construtor, cargas, melhorias de recurso do mapa, consumo
  de Suprimentos, supply_cost das unidades, Tensão Logística, upkeep de prédios, Déficit de Ouro,
  Muralhas, ataque ativo de cidade, Supremacia territorial, Magia V2, IA estratégica V2.

**Frase de encerramento:** a Economia V2 está funcional: cidades geram Ouro, Suprimentos, Produção,
Conhecimento e Mana por uma pipeline única, os cinco prédios econômicos são repetíveis conforme
City Level, as 18 pesquisas de Infraestrutura estão conectadas e a árvore militar agora é
sustentada por uma economia V2 real.


---

## Fase 15 — Integração Econômica V2 (Suprimentos, upkeep, Déficit, Construtor e recursos do mapa)

**Objetivo:** fechar o circuito economia ↔ exército. Suprimentos passam a ser CONSUMIDOS pelas
unidades militares V2 (a Fase 14 só criou a capacidade); prédios V2 passam a custar Ouro por turno;
Ouro vira bruto/upkeep/líquido com um Déficit derivado; o Construtor transforma território anexado
em economia real, melhorando os cinco recursos do mapa. **Não implementa:** Muralhas I/II/Fortaleza,
ataque ativo de cidade, condição territorial da Supremacia, Magia V2, IA estratégica V2, requisito
de recurso para treinar unidade.

### Suprimentos: `UnitData.supply_cost` (dado puro, nunca por id em runtime)

Campo novo `@export var supply_cost: int = 0` em `UnitData`. Padrão 0 = toda unidade V1, o
Colonizador e o Construtor — nenhuma participa da conta. Só as 24 formas militares V2 declaram
valor (BALANCE PLACEHOLDER), nas quatro categorias:

| Categoria | Custo | Guardião | Guerreiro | Patrulheiro | Cavalaria | Ladino | Cerco |
|---|---:|---|---|---|---|---|---|
| N3 (forma básica) | 1 | Escudeiro | Guerreiro | Arqueiro | Cavaleiro | Ladino | Catapulta |
| N5 (evolução) | 2 | Guardião | Espadachim | Caçador | Cav. de Choque | Sabotador | Trebuchet |
| N7 (elite) | 3 | Sentinela | Mestre de Armas | Atirador de Elite | Cav. Blindado | Assassino | Bombarda |
| N9 (Lendária) | 5 | Campeão Guardião | Herói da Lâmina | Caçador de Lendas | Cav. de Grifo | Mestre das Sombras | Colosso de Cerco |

**Usado = vivos + reserva em produção** (`V2LogisticsRuntime.player_supply_used`): soma
`supply_cost` das unidades vivas (`hp > 0`) do jogador e o custo do `production_item` de CADA
cidade dele. A própria fila de produção É a reserva — não existe um segundo estado "reservado".
Por isso morte, cancelamento, troca de produção ou perda de cidade liberam a reserva na consulta
seguinte, sem nenhum hook de reembolso (tudo recalculado do zero). Prédio, projeto de City Level e
unidade de custo 0 nunca reservam nada.

**Capacidade** continua a da Fase 14 (base 4 por cidade + Fazendas + melhorias de Cavalos),
consultada por `V2EconomyRuntime.player_supply_capacity`.

**Gate de treino** (`City.can_train` → `V2LogisticsRuntime.can_afford_training`): só para kind
com `supply_cost > 0`. Ao decidir se `city` pode INICIAR um treino, a reserva da PRÓPRIA cidade é
excluída (ela nunca compete contra si mesma — trocar de ideia na fila sempre é possível), mas a
das outras cidades conta. Bloqueia se `usado_sem_esta_cidade + custo > capacidade`, com a
mensagem exata "Suprimentos insuficientes: requer X, disponíveis Y." — nunca escondida atrás de
"Indisponível": `training_soft_reason` mantém o botão visível e desabilitado com o motivo (mesmo
padrão do slot Lendário da Fase 6).

**Evolução** (`V2UnitUpgrade`): só o DELTA entre a forma nova e a atual precisa caber
(`upgrade_supply_delta`) — a unidade atual já está contada como viva.

### Tensão Logística (derivada, nunca salva)

`V2LogisticsRuntime.is_logistically_strained(player)` = `usado > capacidade`. Excesso NUNCA destrói,
mata ou remove unidade (pode surgir por perda de Fazenda, captura ou Déficit — ver abaixo); só
ativa a penalidade de combate.

**Modificador:** `V2LogisticsRuntime.combat_multiplier(unit)` — `TENSION_MULTIPLIER = 0.85` (BALANCE
PLACEHOLDER) se a unidade tem `supply_cost > 0` E o dono está em Tensão; 1.0 caso contrário. Uma
função só, genérica (nenhum `visual_kind ==`), aplicada nos DOIS lados de `CombatResolver.predict`
(multiplica o Ataque do atacante e a Defesa do defensor); `resolve()` usa `predict()`, então
previsão == resolução continua valendo. Compõe multiplicativamente com veterania, técnicas, auras,
terreno e penetração — nunca substitui nenhum fator. Movimento, cidades, civis e todo conteúdo V1
(custo 0) nunca são afetados.

### Upkeep de prédios, Ouro líquido e Déficit

Campo novo `@export var gold_upkeep: float = 0.0` em `BuildingData` (padrão 0 para todo prédio V1).
Cada CÓPIA paga (cópias repetíveis multiplicam o upkeep). BALANCE PLACEHOLDER:

| Prédio | Upkeep/turno |
|---|---:|
| Mercado | 0 (rota de recuperação do Déficit — sempre livre) |
| Fazenda, Oficina, Academia, Santuário Arcano | 1 por cópia |
| Os 6 prédios de treino (Salão dos Guardiões, Salão de Armas, Campo dos Patrulheiros, Estábulo de Guerra, Guilda dos Ladinos, Arsenal de Cerco) | 1 |
| Os 6 prédios de maestria (Bastião, Arena, Torre, Ordem, Refúgio, Grande Arsenal) | 2 |
| Projetos de City Level, melhorias de recurso, prédios V1 | 0 |

**Ouro bruto/upkeep/líquido:** `player_gold_gross_income` (renda já efetiva, com o desconto de
Déficit se ativo), `player_gold_upkeep`, `player_gold_net_income = bruto − upkeep`.
`apply_turn_income` aplica `player.gold = max(0, gold + bruto − upkeep)` — **Ouro nunca fica
negativo**.

**Déficit** (`is_gold_deficit`, derivado, nunca salvo): `player.gold <= 0` E líquido NOMINAL < 0.
Caixa positivo financiando um líquido temporariamente negativo **não** é Déficit. O líquido nominal
usa `_nominal_player_gold_income` (renda de Ouro SEM o desconto de Déficit) — é isso que quebra a
recursão (o desconto depende do Déficit, então o Déficit nunca pode ler a renda descontada).

**Efeitos do Déficit:**
- prédio com `gold_upkeep > 0` rende 50% (`DEFICIT_OUTPUT_MULTIPLIER = 0.5`, BALANCE PLACEHOLDER) —
  Fazenda/Oficina/Academia/Santuário; decidido pelo dado, nunca por id;
- base por cidade, Mercado (upkeep 0) e melhorias de recurso seguem a 100%;
- bloqueia INICIAR treino de unidade com `supply_cost > 0` ("Déficit de Ouro: estabilize a economia
  antes de treinar novas tropas."); o Construtor (custo 0) continua treinável;
- bloqueia INICIAR prédio com upkeep ("Déficit de Ouro: estabilize a economia antes de adicionar
  manutenção." — `City.deficit_build_reason`); o Mercado continua construível;
- nunca cancela produção já em andamento.

### Construtor (`v2_unit_builder`)

Unidade civil: HP 8, Ataque 0, Defesa 1, Movimento 2, Visão 3, 16 PP, `supply_cost` 0 (BALANCE
PLACEHOLDER), modelo KayKit `Rogue.glb` reaproveitado (escala 0,9). Fora de composição militar, slot
Lendário, Doutrina e Suprimentos. Treinado pela Oficina (`v2_building_workshop.trains_unit`).

**Gate genérico:** campo novo `UnitData.required_v2_unlock_id` (Construtor = `v2_building_workshop`),
resolvido por `V2UnlockSystem.is_unit_unlocked(player, kind)`, que `PlayerData.has_unlocked` e
`City.can_train` usam igualmente. Pesquisar "Oficinas" (Indústria N1) libera a Oficina E o
Construtor — nenhum segundo unlock no mesmo nó, nenhum `if kind == "v2_unit_builder"` no caminho
genérico (teste de varredura de fonte garante).

**Cargas:** fixadas UMA vez, no nascimento, pelo tier ATUAL de Indústria do dono (N1 = 1, N2 = 2,
N3 = 3; `V2ConstructorRuntime.charges_for_new_builder`, chamado pelo spawn de produção do
`GameManager`). Pesquisa posterior nunca recarrega um Construtor existente. Campo novo
`Unit.work_charges_remaining` (salvo).

**Melhoria** (`V2ConstructorRuntime.improve_resource`): instantânea (fora da fila de produção), sem
Ouro/Mana/Suprimentos, consome 1 carga e a ação do turno. A última carga consome a unidade via
`HexGrid.remove_unit` (remoção genérica: sem morte, abate ou XP). Elegibilidade, em ordem
(`unavailable_reason`, uma frase clara cada): é Construtor; tem carga; não agiu; tile tem recurso
reconhecido; tile sem construção; tile no território de uma cidade PRÓPRIA; recurso ainda não
melhorado (no máximo uma melhoria por tile, para sempre). A unidade precisa estar EM CIMA do
recurso. UI: botão "Construir <melhoria>" no painel do Construtor
(`SelectionManager.improve_resource_with_selected`), com o motivo no tooltip quando indisponível;
o painel mostra "Cargas restantes: N".

### Auditoria dos recursos reais e `V2ResourceImprovementData`

Auditados em `ResourceDatabase` (a fonte que a geração de mapa já usa): `iron`, `horses`, `gems`,
`silk`, `mana_node` — os cinco ids REAIS do mapa. Nenhum id V2 duplicado foi criado.

`V2ResourceImprovementData` (novo, `scripts/data/`) é o catálogo único: por recurso, o id da
melhoria, o nome exibido, o modelo KayKit reaproveitado e uma LISTA de efeitos
`{resource, branch, yields[3]}` (a Seda tem dois). Consultas: `improvement_id_for_resource`,
`resource_for_improvement`, `effects_for_resource`, `yield_for_effect(effect, tier)`. Nenhum
`if resource == "iron"` em runtime V2 (teste de varredura).

| Recurso | Melhoria | Efeito | Linha (tier) | Yield N1/N2/N3 | Modelo reaproveitado |
|---|---|---|---|---|---|
| Ferro | Mina de Ferro (`v2_improvement_iron_mine`) | Produção LOCAL | Indústria | 2 / 3 / 4 | `building_blacksmith_blue` |
| Cavalos | Haras (`v2_improvement_horse_ranch`) | Capacidade de Suprimentos | Logística | 4 / 6 / 8 | `building_market_blue` |
| Gemas | Mina de Gemas (`v2_improvement_gem_mine`) | Ouro | Economia | 4 / 6 / 8 | `building_tower_A_blue` |
| Seda | Entreposto de Seda (`v2_improvement_silk_post`) | Ouro + Conhecimento | Economia + Academia | 2/3/4 + 1/2/3 | `building_windmill_blue` |
| Nódulo Arcano | Conduíte Arcano (`v2_improvement_arcane_conduit`) | Mana | Arcano | 2 / 3 / 4 | `building_tower_B_blue` |

Tier: mesma regra dos prédios capturados da Fase 14 (`V2EconomyRuntime.infrastructure_tier`,
sempre ≥ 1, pesquisa do DONO ATUAL, nunca de quem construiu). O rendimento entra pela MESMA
pipeline dos prédios (`_city_improvement_income`, dentro de `_city_branch_income`), olhando só
`City.resource_improvements` das cidades do jogador — nunca varre o mapa.

### Armazenamento, captura e save/load

- `City.resource_improvements: Dictionary` (coord → improvement_id) — na CIDADE, nunca global,
  nunca em `buildings`, nunca ocupa slot nem passa por CopyLimitMode.
- **Captura:** a cidade inteira muda de dono, a melhoria vai junto sem código novo e passa a render
  pelo tier do NOVO dono.
- **Save/load:** só `improvement_id` + coord (chave `"x,y"`) e `Unit.work_charges_remaining`, ambos
  opcionais (sem bump de `SAVE_VERSION`: saves antigos carregam com `{}`/0). Rendimento, Déficit,
  Tensão, usado e capacidade nunca são salvos — o load os re-deriva idênticos (teste compara).
  `PlayerData` não ganhou `supply`/`deficit`/`logistics_tension` (teste de varredura das propriedades).
- **Visual:** `HexGrid.refresh_resource_improvement_marker` põe o modelo KayKit declarado no catálogo
  em escala 0,55 com um pequeno selo dourado procedural por cima (lê como "melhoria", não "prédio");
  sem modelo, fica só o selo. Reconstruído no load. Nenhum asset novo.

### UI

- Barra superior: `Ouro: 12 (+3)` / `Ouro: 0 (-2)` (líquido com sinal); tooltip com renda,
  manutenção, líquido e, em Déficit, "prédios com manutenção operam a 50%.";
  `Suprimentos: 14 / 20`, ou `Suprimentos: 23 / 20 — TENSÃO` com tooltip "-15% Ataque e Defesa".
- Painel da unidade: "Suprimentos: N" e, em Tensão, "Tensão Logística: -15% Ataque / Defesa.";
  Construtor: "Cargas restantes: N" + botão da melhoria.
- Botões de produção/construção bloqueados por Suprimentos/Déficit ficam visíveis, desabilitados,
  com o motivo exato no tooltip.
- TileInspector: título "Recurso: Ferro — Mina de Ferro" e as linhas de rendimento derivado
  ("+2 Produção para esta cidade").

### Interação economia ↔ militar (o circuito)

Infraestrutura (Fazendas) e recursos do mapa (Haras) definem QUANTO exército o império sustenta;
Ouro mantém os prédios que produzem esse sustento; o Déficit derruba as Fazendas a 50%, o que pode
derrubar a capacidade abaixo do usado e criar Tensão no exército sem nenhuma unidade nova; corrigir
o Ouro (Mercado ou Mina de Gemas) devolve as Fazendas a 100% e a Tensão some. Território (anexação
da Fase 13) → recurso → Construtor → economia fecha o outro lado.

### Performance (medida antes de decidir cache, §119-122)

Benchmark headless descartável (mapa Grande 320×84, seed 4242, 3 rivais, 6 cidades humanas com
produção ativa, 3 melhorias por cidade), menor tempo de 300 repetições:

| Unidades humanas | Caixa | `player_supply_used` | `is_logistically_strained` | `predict` (atacante com custo) | `player_gold_net_income` |
|---:|---|---:|---:|---:|---:|
| 21 | positivo | 0,088 ms | 0,218 ms | 0,262 ms | 0,198 ms |
| 21 | zerado | 0,088 ms | 0,420 ms | 0,467 ms | 0,398 ms |
| 41 | positivo | 0,095 ms | 0,225 ms | 0,276 ms | 0,199 ms |
| 41 | zerado | 0,095 ms | 0,429 ms | 0,481 ms | 0,399 ms |
| 61 | positivo | 0,141 ms | 0,278 ms | 0,328 ms | 0,203 ms |
| 61 | zerado | 0,146 ms | 0,488 ms | 0,545 ms | 0,398 ms |

Referência: `predict` sem nenhuma unidade com custo (caminho rápido) = 0,048 ms;
`player_gold_upkeep` 0,073 ms; `city_gold_income` com 3 melhorias 0,022 ms; `apply_turn_income`
0,44 ms; `TurnManager.end_turn` completo (3 IAs, 60 unidades V2 humanas) 42,6 ms.

**Correção feita por causa da medição:** a primeira medida mostrou `player_supply_capacity`
O(cidades²) com caixa zerado (0,77 ms com 6 cidades): cada cidade chamava `is_gold_deficit`, que
soma todas as cidades. Agora o Déficit é decidido UMA vez por consulta agregada
(`_player_branch_income`) e passado adiante — sem cache, sem estado (0,77 → 0,17 ms; `predict`
0,93 → 0,33 ms no pior caso). **Sem cache** (§120): tudo é sub-milissegundo, limitado às cidades e
unidades do próprio jogador e disparado só por evento discreto (clique, fim de turno, previsão de
combate) — nenhum `_process`/polling (a HUD só recalcula em `_refresh_stats`, por evento). Custo
honesto: uma previsão de combate envolvendo unidade com Suprimentos custa ~5-11× o caminho rápido
em termos relativos (+0,2 a 0,5 ms absolutos).

### Testes

106 testes novos em 8 arquivos + 3 em `test_save_manager.gd`: `test_v2_supply_cost` (5),
`test_v2_supply_used` (21), `test_v2_logistics_tension` (15), `test_v2_gold_economy` (21),
`test_v2_constructor` (20), `test_v2_resource_improvements` (13), `test_v2_phase15_integration`
(10: §113 anexação → melhoria, §114 Economia → Logística → Militar, §115 Déficit → Tensão, §123 rival,
§124 recurso nunca gateia, §129-131 anti-hardcode/estado derivado) e `test_v2_phase15_main_flow`
(1: o fluxo principal de 43 passos do §116, num jogo real, com save/load). Fixtures pré-existentes
que treinam/constroem conteúdo V2 foram ajustados (Fazenda/Ouro/City Level de sobra onde
Suprimentos/Déficit não são o assunto do teste). `test_v2_city_annexation.gd` (Fase 13) tinha um
erro de parse (`assert_le` não existe no GUT) e nunca rodava; corrigido, e dois testes dele com
premissa de fixture errada foram ajustados (sem mudança de código de jogo). **Suíte: 3189/3189.**

### Validação visual (não-headless, `Main.tscn` real, uma execução + uma corretiva)

A 1ª execução travou no PRÓPRIO roteiro descartável (chamou método num Construtor já liberado,
depois da 4ª captura) e revelou um bug real: os tooltips mostravam `-15%%` e `50%%` literais (as
strings não passavam por formatação `%`) — corrigido; a execução corretiva confirmou os textos.

Confirmado nas capturas (mapa gerado 60×40, capital fundada pelo caminho real): barra superior
`Ouro: 60 (+0)` / `Suprimentos: 0 / 4`; com 5 Escudeiros, `Suprimentos: 5 / 4 — TENSÃO` e o painel
"Suprimentos: 1 / Tensão Logística: -15% Ataque / Defesa."; com Bastião e caixa zerado,
`Ouro: 0 (-2)`, tooltip "DÉFICIT: prédios com manutenção operam a 50%.", Sentinela visível e
desabilitada com o motivo de Déficit, Fazenda desabilitada com o motivo de manutenção, Mercado e
Construtor habilitados; depois do Mercado, `Ouro: 40 (+2)` (renda 6 − manutenção 4); Construtor
sobre Ferro com "Cargas restantes: 1" e botão "Construir Mina de Ferro"; após o clique, toasts
"construiu: Mina de Ferro." e "O Construtor foi consumido pelo trabalho.", marcador no tile,
TileInspector "Recurso: Ferro — Mina de Ferro / +2 Produção para esta cidade", Produção da cidade
base 4 + melhoria 2.

**Não capturado em tela** (coberto só por teste headless): bloqueio de treino por Suprimentos no
botão (mesmo caminho de `training_soft_reason` que o de Déficit, capturado), dano reduzido aplicado
num combate real, Academia/Oficina a 50%, save/load pela UI, e o modelo KayKit do marcador — ele foi
ligado DEPOIS da validação visual (as capturas mostram o marcador anterior, só o cone); a presença
do modelo é verificada por teste, a aparência não foi reinspecionada.

### Limitações (de propósito) e ressalvas

- **Números provisórios:** custos de Suprimentos, 0,85, upkeep, 50%, stats/cargas do Construtor,
  yields das melhorias — nenhum balanceamento.
- **IA (§123):** os sistemas valem igual para rivais (unidade V2 consome Suprimentos, gate e Déficit
  funcionam, prédio/melhoria capturados rendem pro novo dono — testado), mas a IA NÃO constrói
  Fazendas, não escolhe recursos, não treina Construtor e não corrige Déficit.
- **Recurso nunca gateia conteúdo** (§124): Cavalaria sem Cavalos e Guerreiro sem Ferro continuam
  treináveis (testado).
- **V1 transitório:** o TileInspector ainda mostra, junto do texto V2, as linhas V1 do recurso
  ("rendimento extra ao ser trabalhado", descontos de custo de até -30% de `ResourceDatabase`), e
  `City.collect_yields` ainda tem o bônus racial V1 de Ferro. Os prédios econômicos V1 continuam
  vestigiais (dívida registrada de novo, §128 — nada deletado, migrado ou convertido).
- O tooltip de botão de produção bloqueado termina com uma quebra de linha vazia (padrão
  pré-existente: motivo + "\n" + descrição, e unidades V2 não têm descrição).
- Nenhuma Magia V2 além de o Nódulo Arcano render Mana.

**Frase de encerramento:** A economia e o exército V2 agora pertencem ao mesmo sistema:
infraestrutura e recursos do mapa determinam quanto o império produz e sustenta, Suprimentos
limitam organicamente a escala militar, Ouro mantém a infraestrutura e Construtores transformam
expansão territorial em capacidade econômica real.

---

## Fase 16 — Fortificação e Supremacia Militar V2

**Objetivo:** dar à cidade V2 um fundamento defensivo próprio (Fortificação local em 3 níveis,
escudo, defesa urbana e um Ataque da Cidade explícito) e conectar a primeira vitória V2 real
(Supremacia Militar), sem reescrever o combate urbano nem a Supremacia V1.5. **Não implementa:**
Magia V2, IA estratégica V2, rebalanceamento, limpeza/migração final V1→V2, migração dos prédios
econômicos V1, remoção física de população/comida/tiles trabalhados, bônus raciais.

### Auditoria (antes de mudar)

- Vida V1: `20 + 4 × população`; escudo 15 só com o prédio V1 `walls`; regeneração 15%/turno do
  escudo e 8% da vida, suspensa depois de 2 turnos de inimigo adjacente (mantida sem mudança).
- Defesa V1 por prédio: `walls` 0,5 / `walls_2` 0,35 / `fortress` 0,75 / `imperial_fortress` 1,0
  (cadeia de muralha) + `watchtower` 0,2 / `garrison` 0,2.
- Fórmula única de dano contra cidade (`CombatResolver.resolve_city_attack`): ataque × veterania ×
  multiplicador de cidade da unidade × golpe × Munição ÷ (1 + defesa); o escudo absorve primeiro
  (Torre de Cerco atravessa).
- Milícia V1: dano fixo `1,5 + 0,25 × pop` (máx. 3), +1 com muralha, só em monstro neutro
  adjacente, sem recompensa, chamada AUTOMATICAMENTE todo turno para todo jogador.
- Eliminação (Dominação): sem unidades e sem cidades. Identidade estável de jogador: índice em
  `GameManager.players` (a mesma de `City.original_owner_index`, preservada pelo save).
- `capture_city` curava vida E escudo ao máximo para o novo dono.

### Fonte única: `V2FortificationData` (nova, `class_name`)

| Nível | Nome | PP | Ouro/turno | Escudo | Defesa | Ataque | Alcance | Requer |
|---:|---|---:|---:|---:|---:|---:|---:|---|
| 0 | Nenhuma | — | 0 | 0 | +0% | — | — | — |
| 1 | Muralhas I | 40 | 1 | 8 | +10% | 3 | 2 | Urbanização N1 + Cidade II |
| 2 | Muralhas II | 70 | 2 | 14 | +20% | 5 | 2 | Urbanização N2 + Cidade III |
| 3 | Fortaleza | 110 | 3 | 22 | +30% | 7 | 3 | Urbanização N3 + Cidade IV |

Números **provisórios** (sem balanceamento). A pesquisa é a MESMA dos níveis de cidade (segundo
efeito de `v2_city_level_2/3/4`, nenhum nó novo); o rótulo vem de
`V2ResearchDatabase.urbanization_unlock_label` ("Cidade II e Muralhas I") — tooltip do nó
("Desbloqueia Cidade II e Muralhas I."), toast ("Desenvolvimento urbano disponível: Cidade II e
Muralhas I.") e as descrições de `V2InfrastructureContent` (a nota "fortificações reais serão
conectadas em fase posterior" saiu). `V2CityLevelData.MAX_HP_BY_LEVEL`: vida máxima 24 / 30 / 36 / 44.

### Fortificação na cidade

- `City.fortification_level` (0..3, LOCAL). Projeto `v2_city_fortification_N` na MESMA fila de
  produção (`production_item`), concluído por `process_turn` (`fortification_level_up` no
  resultado), **nunca** um `BuildingData`: não ocupa slot, não entra em `City.buildings`, não conta
  Suprimentos (`V2LogisticsRuntime._supply_cost_for_kind` exclui). Níveis sequenciais.
- `fortification_unavailable_reason()`: máximo / "Requer <nó>." / "Requer Cidade N." / "Produção da
  cidade já está ocupada." / Déficit. O **Déficit** bloqueia só o INÍCIO ("Déficit de Ouro: estabilize
  a economia antes de ampliar a fortificação."); um projeto em andamento continua.
- Upkeep: `V2EconomyRuntime.city_gold_upkeep` soma o upkeep do nível ATUAL (substitui, não acumula).
- Escudo: `max_shield()` vem do nível; `apply_fortification_level` preserva o dano absoluto
  (`novo = clamp(novo_max − (antigo_max − atual), 0, novo_max)`) — upgrade nunca cura de graça.
- Vida: `max_hp()` vem do City Level (população não conta mais); `apply_city_level` preserva a
  FRAÇÃO (15/30 → 18/36).
- Defesa: `City.defense_bonus()` = prédios não-muralha + `V2FortificationData.city_defense_bonus`,
  usada por `predict` (guarnição) e por `resolve_city_attack` (a mesma fórmula; Cerco, Munição e
  Bombardeio continuam funcionando, sem imunidade). A cadeia V1 de muralhas ficou **vestigial**
  (`BuildingData.superseded_by_v2_fortification`): `defense_bonus_for` a ignora, `can_build` recusa, a
  HUD esconde os botões V1. A RivalAI olha `has_fortification()` em vez de `buildings.has("walls")`.
- Visual: o anel de muralha (hexágono de segmentos + pilares, já existente) reflete
  `has_fortification()`; a barra de escudo aparece quando `max_shield() > 0`.
- Captura: a fortificação fica como está (escudo **limitado**, nunca recarregado); o novo dono paga
  o upkeep, ganha escudo/defesa/ataque, e só avança com a própria pesquisa e o próprio City Level.

### Ataque da Cidade (`CityDefense`)

- Ação EXPLÍCITA, uma vez por turno do dono (`City.last_city_attack_turn`, salvo), só com
  fortificação ("Requer fortificação (Muralhas I ou superior)."), contra unidade hostil válida no
  alcance (`HexMetrics.coords_within`, nunca o mapa): dono diferente em guerra, ou monstro neutro
  (exceto os geridos por evento mundial). Ordem estável: menor HP%, depois menor `serial_id`.
- Dano FIXO = poder do nível (semântica herdada da milícia: sem Defesa do alvo), sem revide, sem os
  +25% contra voadores, sem XP/recompensa. A Tensão Logística não entra; o Déficit reduz ×0,5 SÓ o
  poder (escudo e defesa continuam 100%).
- Visibilidade: o humano só mira tile VISÍVEL — a MESMA regra de
  `V2TechniqueRuntime._visible_to_owner` (lê `HexGrid.visibility`, O(1)); IA sem restrição.
- Mira pela `SelectionManager` (`start_city_attack_targeting`; dica "Escolha o alvo do Ataque da
  Cidade (ESC cancela)"); ESC e clique inválido não gastam; clique válido dispara e sai da mira.
  Não é uma Técnica de Doutrina.
- A captura marca o disparo como gasto no turno (sem tiro grátis na troca de dono).
- IA: paridade tática mínima — `ai_city_defense_turn` no laço de turno de cada rival: cidade
  fortificada dispara uma vez no primeiro alvo da ordem estável. Sem estratégia.
- **Milícia automática removida** (`militia_damage`/`militia_strike` e a chamada por turno).
  Continuam: ameaça/aposta (`assess`), mobilização/defesa da IA (`defend_turn`) e o aviso ao
  jogador (`warn_player`).

### Supremacia Militar V2 (`V2VictoryConditions`, nova, `class_name`)

- Fundação genérica das vitórias V2 (a Transcendência futura mora aqui). Tudo derivado a cada
  chamada — nenhum progresso salvo, nenhum polling.
- Acesso: `v2_military_supremacy_access` (Exército Supremo). Para CADA rival major: eliminado (mesma
  definição da Dominação — um Colonizador vivo mantém o rival vivo) OU o jogador mantém AGORA uma
  cidade que era **Cidade III+ no instante da captura** daquele rival. `capture_city` grava
  `City.v2_supremacy_captured_from` (id estável; sempre reescrito — a captura de cidade pequena zera
  um crédito antigo; desenvolver depois não conta; perder a cidade perde o crédito; reconquistá-la
  devolve). Zero rivais nunca vence. O toast "Supremacia: conquista válida contra <rival>." sai só na
  primeira conquista válida contra cada rival.
- `GameManager.check_victories` avalia a V2 DEPOIS de todas as vitórias legadas; id
  `v2_military_supremacy`; tela "Vitória por Supremacia Militar — <reino>" + "Seu império provou sua
  supremacia conquistando os centros desenvolvidos de seus rivais.".
- Progresso no tooltip/rodapé do Exército Supremo ("Supremacia Militar: 1 / 2 rivais satisfeitos ·
  Reino A — Conquista mantida · Reino B — Pendente/Eliminado"). A Supremacia V1.5
  (`VictoryCampaign`, `exercito_supremo`) continua intocada e independente.

### Save / load

`fortification_level`, `last_city_attack_turn` e `v2_supremacy_captured_from` por cidade. Save antigo
sem o campo: migração determinística da cadeia V1 (fortress/imperial_fortress → 3, walls_2 → 2,
walls → 1, nenhuma → 0); vida/escudo antigos acima do novo máximo são LIMITADOS (a cidade nunca é
destruída pela migração).

### UI

Painel da cidade (TileInspector, visível a qualquer observador): "Muralhas I / Escudo: 8 / 8 /
Defesa urbana: +10% / Ataque da Cidade: 3 | Alcance 2" (o escudo aparece uma vez, só com
fortificação). Ações da cidade: "Construir Muralhas I — 40 PP" (tooltip com o motivo ou o upkeep;
"(em progresso)") e "Ataque da Cidade" / "Ataque da Cidade — Usado neste turno" (desabilitado com o
motivo, inclusive "Nenhum alvo hostil visível ao alcance."). **Correção achada na validação
visual:** selecionar um tile sem cidade deixava a fileira de ações da cidade anterior na tela (e
clicável) — bug latente desde a Fase 13; agora a fileira é limpa.

### Performance (headless, benchmark descartável)

Mapa Grande 320×84, seed 4242, 3 rivais, 6 cidades humanas Cidade IV/Fortaleza, 6 cidades rivais
Cidade III/Muralhas II, 42 unidades humanas; menor tempo de 300 repetições.

| Medida | Tempo |
|---|---:|
| `city_attack_targets` Fortaleza humana (alcance 3, neblina) / IA (alcance 2) | 0,047 / 0,016 ms |
| `ai_city_defense_turn` × 6 cidades sem alvo | 0,07 ms |
| `military_supremacy_status` / `_achieved` (3 rivais) | 0,033 / 0,032 ms |
| `check_victories` completo | 0,14 ms |
| `City.defense_bonus` / `city_gold_upkeep` / `fortification_unavailable_reason` | ≤ 0,001 ms |
| `predict` atacante com Suprimentos, caixa positivo / zerado (re-benchmark §133) | 0,090 / 0,117 ms |
| `predict` V1 × V1 (caminho rápido) | 0,045 ms |
| `process_turn` × 12 cidades: fortificadas (escudo abaixo do máximo) / sem fortificação | 3,2 / 1,9 ms |
| `TurnManager.end_turn` (sync, 3 IAs) com / sem fortificações | 59–78 ms (ruído; sem diferença mensurável) |

**Correção feita por causa da medição:** a primeira versão filtrava a visibilidade humana com
`compute_visible_tiles` (3,3 ms no mapa Grande, a cada refresh do botão, início de mira e disparo);
agora lê a neblina já calculada, como as técnicas de longo alcance (0,047 ms). O único custo novo por
turno é o caminho PRÉ-EXISTENTE de regeneração do escudo, agora ativo em mais cidades (~0,12 ms por
cidade fortificada). O `predict` com Suprimentos saiu mais barato que o 0,26/0,47 ms da Fase 15
porque o cenário é outro (sem produção ativa nem melhorias por cidade) — não é comparável 1:1; nada
no `predict` mudou nesta fase além de usar `city.defense_bonus()`. Sem cache, sem `_process`.

### Testes (88 novos, líquido +84 com a seção de milícia reescrita; suíte completa **3273 / 3273**, 130 scripts)

Novos: `test_v2_fortification` (31), `test_v2_city_attack` (22), `test_v2_military_supremacy` (21) e
`test_v2_phase16_main_flow` (3: §127 infraestrutura defensiva de Cidade I à Fortaleza com
mira/ESC/save/load/IA/Déficit; §128 Supremacia com Cidade II não contando, Cidade III contando,
save/load, perda e reconquista, vitória pela própria ação; §129 Cerco × Fortaleza × vitória), +7 em
`test_v2_city_hud` (botões e a correção da fileira) e +4 em `test_save_manager` (campos, migração
legada, progresso nunca salvo). Ajustados à regra nova (sem mudar o que verificam): testes V1 de
muralha/vida por população/escudo (`test_city`, `test_buildings`, `test_combat_resolver`,
`test_rival_ai`, `test_save_manager`), os textos de tooltip (`test_v2_city_level`,
`test_v2_supreme_army`), a seção de milícia de `test_city_defense` (reescrita para o Ataque da
Cidade) e os fluxos das Doutrinas de Cavalaria/Patrulheiro/Ladino/Cerco/Guerreiro, que dependiam
sem querer da milícia automática para limpar monstros errantes do mapa gerado ao redor da cidade
(agora um helper explícito faz isso; o fluxo do Cerco também passou a dar Cidade IV à cidade
inimiga em vez de população 6, porque a vida vem do nível).

### Validação visual (não-headless, `Main.tscn` real, uma execução)

Capturas (mapa gerado 60×40, capital fundada pelo caminho real): painel "Cidade II / Vida: 30/30 /
Muralhas I / Escudo: 8 / 8 / Defesa urbana: +10% / Ataque da Cidade: 3 | Alcance 2", anel de muralha
fechado, botões "Evoluir para Cidade III", "Construir Muralhas II — 70 PP" e "Ataque da Cidade";
toast "Desenvolvimento urbano disponível: Cidade II e Muralhas I."; dica da mira; após o clique,
"-3" no Guarda inimigo, toast "O Ataque da Cidade de … atingiu Guarda." e o botão "Ataque da Cidade
— Usado neste turno"; o marcador KayKit da melhoria da Fase 15 (Mina de Ferro) de perto, legível ao
lado da cidade; Fortaleza capturada ("Cidade IV / Vida 44/44 / Fortaleza / Escudo 22/22 / +30% / 7 |
Alcance 3", disparo já gasto) com os toasts "Voce capturou …" e "Supremacia: conquista válida contra
…"; rodapé do Exército Supremo "Supremacia Militar: 1 / 2 rivais satisfeitos · … — Conquista
mantida · … — Pendente"; tela final "Vitória por Supremacia Militar — Reino de Teste" com o texto do
resumo. Revelou a fileira de ações "presa" (corrigida, acima). Não capturado em tela: uma cidade da
IA disparando no turno dela (coberto pelo fluxo §127) e o Déficit reduzindo o disparo (teste).

### Limitações (de propósito) e ressalvas

- **Números provisórios.** Uma Fortaleza sozinha (upkeep 3) supera a renda base de uma cidade (2):
  com o caixa zerado isso já é Déficit — interação real registrada, não rebalanceada.
- **V1 transitório:** a tela de vitória ainda lista as barras legadas (inclusive "Supremacia 0%" da
  V1.5 com o texto da regra V1.5) abaixo do título da vitória V2 — a V1.5 continua independente e
  nada foi removido. A cadeia V1 de muralhas continua nos dados, vestigial.
- IA: só a paridade tática do disparo; ela não constrói fortificação nem persegue a Supremacia V2.
- A captura continua curando a VIDA da cidade (comportamento V1); só o escudo deixou de ser curado.

**Frase de encerramento:** a cidade V2 agora se defende com o que construiu — muralhas que custam
produção e Ouro, um escudo que só se reconstrói com o tempo e um disparo que o jogador escolhe usar —
e a Supremacia Militar V2 recompensa conquistar os centros desenvolvidos dos rivais, não apenas
vencer batalhas.

---

## Fase 17 — Fundação da Magia V2: Escola Sagrada N1–N9

**Objetivo:** provar o molde inteiro de uma Escola de Magia (pesquisa → prédio da Escola → conjurador →
repertório → Mana → estados → estrutura ritual → Grande Manifestação → save/load → UI → integração com
economia e militar) sobre fundações GENÉRICAS, sem nenhum subsistema específico da Sagrada. **Não
implementa:** as outras cinco Escolas, dano mágico V2, invocações, terreno, teleporte/portal, clima,
Transcendência funcional, Ritual Final, IA estratégica V2, limpeza V1→V2, balanceamento.

### Auditoria da Magia V1 (antes de criar runtime)

- **Escolas V1:** ids `"sagrada"`, `"infernal"`, `"necromancia"`... (`MagicContent.SCHOOLS`). A Escola V2 usa
  `"sacred"` (o id da linha de pesquisa V2) — ids DISTINTOS de propósito: um feitiço V1 nunca é conjurado por
  um conjurador V2 (`MagicRuntime.eligible_caster` compara a Escola).
- **Mana:** `player.mana`, abastecida desde a Fase 14 por `V2EconomyRuntime.apply_turn_income`; V1 gasta com
  `player.mana -= custo`. **Reutilizado sem alteração.**
- **`magic_cooldowns` / `magic_status`:** dicionários por unidade, já salvos/validados pelo SaveManager e já
  usados pelas Técnicas (Fase 4). **Reutilizados** (chave = id do feitiço).
- **Mira V1 (`casting_spell_name`)** valida no clique, sem lista pré-calculada; a mira de Técnica V2 (Fase 7)
  destaca alvos e usa ESC via PauseMenu. A mira de feitiço V2 segue o molde da Técnica, com estado PRÓPRIO.
- **Cura V1** (`MagicRuntime.cast`, efeito "heal"): 30% da vida máxima, custo/recarga por nome — outra regra,
  não reaproveitada; a V2 usa a atribuição de `hp` (o setter já atualiza a barra).
- **"Até o início do próximo turno do dono":** a regra T+2 + `expire_finished` em `GameManager._finish_turn`
  existia só em `V2TechniqueRuntime`. **Extraída** para `V2OwnerTurnEffect` (usada pelas Técnicas e feitiços).
- **`caster`:** semeado de `magic_school != ""` (Fase 10) — o Clérigo e o Serafim o recebem sem lista nova.
- **Consumidores V1 de `magic_school` que precisavam de guarda:** o emblema da unidade
  (`MagicOverlay.COLORS[escola]` quebraria com "sacred"), a Transcendência V1.5 (`VictoryCampaign.candidates`
  contaria conjuradores V2), `MagicAI.prepare_ritualists` e a lista V1 de recargas do painel (mostraria o id
  cru). Todos restritos às Escolas V1 / com fallback — comportamento V1 idêntico.
- **IA:** toda a IA já trata `attack <= 0` como não-combatente (RivalAI/StrategicAI/CityDefense/ArmyComposition).

### Conteúdo e pesquisa (`V2MagicContent`, novo)

| N | Nome | Tipo | `unlock_id` |
|---|---|---|---|
| 1 | Escola Sagrada | school | `v2_magic_school_sacred` |
| 2 | Templo Sagrado | school_building | `v2_building_sacred_temple` |
| 3 | Clérigo | caster | `v2_unit_sacred_cleric` |
| 4 | Luz Restauradora | spell | `v2_spell_restoring_light` |
| 5 | Égide Sagrada | spell | `v2_spell_sacred_aegis` |
| 6 | Onda de Cura | spell | `v2_spell_healing_wave` |
| 7 | Milagre | spell | `v2_spell_miracle` |
| 8 | Catedral Sagrada | ritual_building | `v2_building_sacred_ritual` |
| 9 | Serafim | grand_manifestation | `v2_manifestation_seraph` |

`V2ResearchDatabase._apply_magic_content` aplica o conteúdo como `_apply_doctrine_content` (ids de pesquisa,
tiers, custos 10…400 e pré-requisitos intactos). Os tipos estruturais de Magia passaram a ser os próprios
(`school_building`, `ritual_building`, `grand_manifestation` no lugar de `building`/`manifestation`). Sagrada
**9/9 `gameplay_connected`**; Infernal, Necromancia, Druidismo, Arcanismo e Elementalismo **0/9**;
Transcendência inerte (estrutura "duas Escolas completas" intacta, nunca vitória). `V2UnlockSystem` ganhou os
seis tipos e toasts genéricos por tipo ("Escola desbloqueada: …", "Novo prédio mágico disponível: …", "Novo
conjurador disponível: …", "Novo feitiço disponível: …", "Nova estrutura ritual disponível: …", "Grande
Manifestação disponível: …"). Tooltips com os números reais montados do dado; nenhum mostra "Gameplay V2 ainda
não conectado.". Nada é escrito em `researched_magic`/pesquisa V1.

### Fundação de feitiços (genérica)

- **`V2SpellData`** (Resource): `id`, `school_branch`, `mana_cost`, `cooldown_turns`, `target_mode` (só
  `OWN_UNIT`), `cast_range`, `consumes_action`, `heal_amount`, `heal_to_full`, `splash_radius`,
  `defense_bonus`, `duration` — defaults inertes; nenhum campo especulativo de dano/terreno/portal/clima.
- **`V2SpellDatabase`**: 4 registros, cache, `for_school` na ordem dos nós (N4..N7), `defensive_spells`
  (lista curta para o combate), `effect_text` montado do dado.
- **`V2MagicRuntime`**: repertório DERIVADO (`magic_school` + Escola do feitiço + pesquisa do DONO — nada
  salvo), alvos (só unidades próprias vivas, o próprio conjurador incluso, alcance por
  `HexMetrics.coords_within`, visibilidade = a regra das técnicas), `unavailable_reason`, `cast` (valida tudo;
  só então desconta a Mana, inicia a recarga, aplica, zera o movimento e cancela explorar/marcha),
  `defense_multiplier` (UM fator em `CombatResolver.predict`, caminho rápido sem `magic_status`),
  `expire_finished` (turno do dono), linhas de UI. Nenhum id/Escola/unidade concreto no código (teste varre).
- **Regra de ação:** conjura enquanto `movement_left > 0` (mover parte e conjurar vale; mover tudo não).
  Sem XP, abate, Ouro ou Suprimentos; o Déficit e a Tensão não reduzem a potência (o Déficit só reduz a Mana
  produzida pelos Santuários).

### Os quatro feitiços (BALANCE PLACEHOLDER)

| Feitiço | Mana | Alcance | Recarga | Efeito |
|---|---:|---:|---:|---|
| Luz Restauradora | 4 | 2 | 0 | cura 8 (sem overheal); alvo precisa estar ferido |
| Égide Sagrada | 6 | 2 | 2 | +35% Defesa até o início do próximo turno do dono; não empilha consigo (outro conjurador renova) |
| Onda de Cura | 9 | 3 | 3 | cura 6 no alvo e em TODA unidade própria a 1 tile dele; vale se ao menos uma estiver ferida (o alvo pode estar cheio) |
| Milagre | 16 | 3 | 5 | restaura ao máximo; alvo cheio é inválido ("O alvo já está com a Vida máxima."); não ressuscita |

Nenhum feitiço cura cidade, escudo ou fortificação, nem cura inimigo/outra civilização, nem causa dano.
Nenhuma fórmula de dano mágico foi criada.

### `can_basic_attack` (UnitData, default true)

Clérigo e Serafim = false. `CombatResolver`: `can_attack_unit`/`can_attack_city` recusam; `resolve` e
`resolve_city_attack` saem antes de qualquer conta (fail-closed); `predict` devolve 0 de dano para o atacante
(bloqueado ANTES do piso de 1) e o defensor sem ataque nunca revida. `SelectionManager` não marca alvo
atacável. A unidade continua sendo atacada, movendo e conjurando. Toda unidade existente segue `true`.

### Templo, Clérigo e Catedral

- **Templo Sagrado:** 24 PP, 1 Ouro/turno, UNIQUE, sem prédio exigido, treina o Clérigo, **não produz Mana**.
- **Clérigo:** 12 HP / 0 / 2,0 / mov. 2 / visão 3 / 24 PP / **2 Suprimentos** / alcance 0 / `magic_school`
  "sacred" (→ `caster`, Desmantelar do Ladino vale sozinho). Gate: N3 + Templo na MESMA cidade + fila +
  Suprimentos + Déficit (as regras de sempre). A Tensão reduz a Defesa dele, nunca a cura.
- **Catedral Sagrada:** 60 PP, 2 Ouro/turno, UNIQUE, exige o Templo na mesma cidade (não o substitui), ocupa
  slot, fila normal, Déficit bloqueia iniciar; só habilita o Serafim.

### Grande Manifestação: Serafim

- 38 HP / 0 / 7,0 / mov. 3 / visão 4 / 100 PP + **60 Mana** / **0 Suprimentos** / FLYING (o MESMO perfil da
  Fase 9, pousa só em terra livre) / `ranged_damage_taken_bonus` 0 (voar não implica a vulnerabilidade do Grifo)
  / sem ataque básico / `magic_school` "sacred" → conhece o repertório Sagrado do dono.
- Traços: `caster`, `flying`, **`grand_manifestation`** (novo `UnitData.TRAIT_GRAND_MANIFESTATION`, semeado
  da metadata do nó) — **nunca `legendary`**: a Caçada Lendária não vale contra ele; o Desmantelar vale.
- **Presença Sagrada:** aliados do mesmo dono a até 2 tiles +15% Defesa, pela MESMA infraestrutura de aura do
  Comando Defensivo (`UnitData.aura_*`). **Mudança de regra em `V2UnitAuras`:** auras defensivas nunca
  acumulam entre si — vale o MAIOR bônus (Campeão +20% e Serafim +15% = +20%). Antes desta fase só existia uma
  aura, então a regra antiga ("auras de ids diferentes multiplicam") nunca tinha sido exercida.
- **`V2ManifestationSystem`** (novo, genérico): **1 por Escola** por civilização (a Lendária é 1 no TOTAL),
  ativa OU em produção, derivado de unidades vivas + `production_item` (nada salvo); outra cidade bloqueada;
  cancelar/morrer libera; rival não interfere; reset de pesquisa não apaga; fail-closed no nascimento (a segunda
  conclusão é recusada, os PP voltam, erro no log). Independente do slot Lendário (Campeão + Serafim coexistem).
- **`UnitData.production_mana_cost`** (novo, default 0): exigido para INICIAR (sem reservar nem descontar);
  na conclusão sem Mana suficiente a produção ESPERA completa (`City.production_waiting_for_mana`, PP travados
  no custo, sem perder nada, slot reservado); com Mana, o GameManager desconta UMA vez e o Serafim nasce.
  Cancelar não exige reembolso. Se a Mana mudar entre a checagem da cidade e o nascimento (duas conclusões no
  mesmo ciclo), a cidade volta a esperar — nunca Mana negativa.

### Mira, UI e save/load

- Mira de feitiço V2: estado próprio na `SelectionManager` (`v2_spell_targeting_*`), alvos em VERDE (cor de
  alvo amigo), dica "Escolha o alvo de <feitiço> (ESC cancela)", ESC via PauseMenu e clique inválido não gastam
  Mana/recarga/ação; exclusiva com mira de Técnica, Ataque da Cidade, anexação e mira V1.
- Painel do conjurador: "Sem ataque básico.", "Magia — Escola Sagrada" e botões "Luz Restauradora — 4 Mana",
  "(recarga N)", desabilitados com motivo (inclusive "Nenhuma unidade ferida ao alcance." e "Mana
  insuficiente: requer N."). Produção: "Serafim — 100 PP + 60 Mana", "Requer 60 Mana.", slot ocupado, e
  "Aguardando 60 Mana." no progresso. Estado ativo (Égide) é fato público (inspetor + o mesmo anel ciano das
  Técnicas); repertório e recargas só para o dono. Cura mostra "+N" verde (o mesmo popup do dano).
- Save/load **sem campo novo**: recargas/estados em `magic_cooldowns`/`magic_status`, Mana no `player.mana`,
  Serafim/Clérigo por `visual_kind`, produção esperando Mana pelo `production_item`/`stored_production`;
  repertório e slot re-derivados. A Égide carregada expira no turno certo.

### Performance (headless, benchmark descartável; mapa Grande 320×84, seed 4242, 3 rivais, 45 unidades humanas; menor de 300 repetições)

| Medida | Tempo |
|---|---:|
| `spells_for_unit` (4 feitiços) | 0,011 ms |
| alvos alcance 2 (Luz) / alcance 3 (Onda, checando o raio 1 de cada candidato) | 0,015 / 0,032 ms |
| `unavailable_reason` (refresh do botão) | 0,021 ms |
| `defense_multiplier` sem estado / com Égide | < 0,001 / 0,001 ms |
| `predict` V1 × V2 sem Égide / com Égide | 0,139 / 0,137 ms (diferença = ruído) |
| `predict` V1 × V1 (caminho rápido) | 0,026 ms |
| `can_attack_unit` (com `can_basic_attack`) | 0,002 ms |
| `V2UnitAuras.defense_multiplier` (41 aliados) | 0,014 ms |
| `V2ManifestationSystem.slot_available` (6 cidades) / `can_train(Serafim)` | 0,040 / 0,069 ms |
| `V2MagicRuntime.expire_finished` (42 unidades) | 0,005 ms |
| `TurnManager.end_turn` (sync, 3 IAs) | 47,5 ms |

O `predict` V1 × V2 caro (0,14 ms) é a consulta de Tensão Logística da Fase 15 (unidade com Suprimentos), não a
Magia. Nenhuma varredura de mapa, nenhum `_process`, nenhum scan das 55 pesquisas por conjuração. Sem seção
nova em `docs/PERFORMANCE_GUIDE.md` (números irrelevantes para o caminho quente).

### Testes (106 novos; suíte completa **3379 / 3379**, 137 scripts)

`test_v2_magic_content` (13: estrutura, nomes, ids, tipos, 9/9 × 0/45, Transcendência, tooltips, toasts, N1
sem bônus, nada em pesquisa V1, varredura anti-hardcode, sem arquitetura paralela), `test_v2_sacred_units`
(20: Templo, Clérigo, piso de dano, sem revide, sem ataque a cidade, seleção, Déficit/Suprimentos, Catedral),
`test_v2_sacred_spells` (36: repertório, os quatro feitiços, Mana insuficiente/exata, Égide × origens/Tensão/
expiração/reset, Onda com 7 aliados, Milagre, mira/ESC/exclusividade, linhas de UI),
`test_v2_seraph_manifestation` (22: dados/traços, voo, contadores, Presença e empilhamento, slot por Escola
com fixture de outra Escola, Lendária × Manifestação, Mana de produção/espera/fail-closed, turno real,
Transcendência inerte), `test_v2_sacred_integration` (6: Santuário Arcano → Mana → feitiço → Mana reposta;
Luz + Égide + Muralha + Comando em combate real; Ladino × Égide pela fórmula existente; Tensão; cidade
intocada; IA com conteúdo Sagrado por 3 turnos), `test_v2_magic_hud` (6), `test_v2_phase17_main_flow` (1:
o fluxo de 57 passos do §147 num jogo real, com save/load) e +2 em `test_save_manager`. Ajustados (sem mudar o
que verificam): testes das Fases 0–16 que usavam a Sagrada como exemplo de Escola inerte (agora a Infernal) e
as listas de kinds treináveis/perfis de voo.

### Validação visual (não-headless, `Main.tscn` real, uma execução)

Capturas (mapa 60×40, cidade fundada pelo caminho real): aba Magia com a linha Sagrada canônica (Escola
Sagrada … Serafim) e as outras cinco Escolas "Infernal I…IX" etc. + Transcendência bloqueada; toasts da
Escola/Templo/Clérigo/Luz; painel do Clérigo ("Sem ataque básico.", "Conjurador — Escola Sagrada",
"Suprimentos: 2", "Magia — Escola Sagrada / Luz Restauradora — 4 Mana") com o emblema "SA"; dica da mira;
**ESC real** pelo pipeline de input cancelou sem pausar e sem gastar (Mana 60); cura real +8 (popup verde,
Mana 60→56); Égide ativa no Guarda com o anel ciano e a linha pública; Onda curando 3 unidades (2→8 cada);
Milagre (0,5→12); Catedral construída; "Serafim — 100 PP + 60 Mana"; na segunda Catedral o botão desabilitado
(slot); "Produzindo: Serafim — 100/100 PP. Aguardando 60 Mana."; Serafim nascido com uma cobrança só (90 − 60 +
2 de renda = 32) e o painel com Presença Sagrada, voo tático e os quatro feitiços; save/load pelo SaveManager
preservou pesquisa, Serafim, Clérigo, slot e Mana. Achado corrigido antes da validação (pelos testes): o
próprio conjurador não era alvo (`coords_within` não inclui o centro). Depois da validação: o resumo da linha
Sagrada dizia "purificação" (não existe nesta fase) — trocado por "cura, proteção e suporte de formação".

### Limitações (de propósito) e ressalvas

- **Números e modelos provisórios:** Clérigo = Mage do KayKit; Serafim = o mesmo Mage em escala 1,5 (não há
  anjo nos pacotes gratuitos — placeholder honesto, pequeno na câmera padrão); Templo = torre A, Catedral =
  torre B do KayKit.
- **IA:** convive com o conteúdo (sem crash, sem ataque inválido, Mana e slot respeitados) mas não pesquisa,
  não constrói, não conjura nem produz Manifestação.
- **V1 transitório:** a Magia V1 (Grimório, Escolas "sagrada" etc., Transcendência V1.5) continua existindo e
  independente; a barra "Supremacia 0%" da V1.5 na tela de vitória continua (limpeza V1 é fase própria).
- **Aura:** a troca para "maior bônus entre todas as auras" é uma mudança de regra da Fase 6 — sem efeito em
  jogo antes desta fase (só existia uma aura).

**Frase de encerramento:** a Fundação da Magia V2 está funcional: a Escola Sagrada prova o ciclo completo de
pesquisa, conjurador sem ataque básico, repertório derivado, Mana, feitiços, estados temporários, estrutura
ritual e Grande Manifestação, estabelecendo um molde reutilizável para as outras cinco Escolas sem criar um
subsistema específico da Sagrada.

---

# Fase 18 — Escola Infernal N1–N9 e Dano Mágico V2

## Reutilizado sem alteração

- A Infernal usa o mesmo `V2ResearchState`/`V2UnlockSystem`, Conhecimento, Mana, fila de produção, Suprimentos,
  Déficit, cooldowns (`magic_cooldowns`), traits, save/load por `visual_kind`, HUD e targeting criados nas fases
  anteriores. Feitiço continua sendo ação da unidade e não é Técnica Militar.
- O Santuário e o Círculo são `BuildingData` normais; Bruxo e Arquidemônio são `UnitData` normais. A Grande
  Manifestação continua usando o slot derivado do `V2ManifestationSystem`; a Lendária Militar permanece em
  outro limite.
- A remoção da vítima, `register_kill`, veterania/XP, loot já associado ao abate, alerta de covil, eventos e
  limpeza do grid continuam na pipeline de combate. Não foi criado um segundo sistema de morte.
- A Sagrada permaneceu mecanicamente igual: curas, Égide, Onda, Milagre, aura do Serafim, produção com Mana e
  slot Sagrado continuam funcionando.

## Generalizado

- `V2SpellData.TargetMode` agora comporta `OWN_UNIT` e `HOSTILE_UNIT`; os mesmos métodos de consulta, mira,
  disponibilidade e cast resolvem Sagrada e Infernal por dados.
- `V2SpellData` ganhou somente `damage_amount`, `low_hp_threshold` e `low_hp_damage_bonus`. O texto de efeito
  também é montado pelo `V2SpellDatabase`, inclusive dano em área e bônus contra Vida baixa.
- `UnitData` ganhou `spell_damage_multiplier` (default `1.0`) e o rótulo genérico opcional da passiva. O HUD e
  o inspetor não conhecem Arquidemônio nem Chama Primordial por id.
- `CombatResolver.is_hostile_unit_target(owner, target, grid)` extrai a regra diplomática/monstro/world-event
  que já existia. Ataque básico compõe `can_basic_attack` com esse helper; spell hostil usa apenas a parte de
  hostilidade. Assim um conjurador com Ataque 0 pode mirar um inimigo sem ganhar ataque básico.
- `CombatResolver.apply_direct_unit_damage` concentra dano direto + popup + evento + morte/abate. Tanto o
  golpe físico quanto a magia chegam à mesma conclusão de morte, mas só o primeiro usa a fórmula física e
  contra-ataque.
- O AoE é local: alvo primário primeiro; secundários hostis num raio 1 ordenados por menor HP% e depois
  `serial_id`. Todas as vítimas são reunidas antes do dano, então a morte do primário não interrompe a explosão.

## Separação V1/V2 corrigida

A auditoria encontrou a colisão literal `"infernal"`: ela é id de Escola tanto no legado quanto na V2. O campo
antigo não podia continuar representando as duas gerações.

- `UnitData.magic_school` agora é exclusivamente V1; `UnitData.v2_magic_school` é exclusivamente V2.
- Clérigo e Serafim foram migrados de `magic_school = "sacred"` para `v2_magic_school = "sacred"`; Bruxo e
  Arquidemônio têm apenas `v2_magic_school = "infernal"`.
- `MagicRuntime`, `MagicAI`, `VictoryCampaign`, Grimório e rituais legados continuam lendo somente
  `magic_school`. `V2MagicRuntime` e `V2ManifestationSystem` leem somente `v2_magic_school`.
- A pergunta pública “é conjurador?” continua unificada no trait `caster`. `_seed_traits` usa `is_caster()`,
  que compõe `is_v1_caster()` e `is_v2_caster()` sem classificar nome ou kind.
- Não há campo novo no save: escola é dado imutável recriado pelo kind. Saves antigos continuam no mesmo
  schema e Clérigo/Serafim recarregam com a classificação nova pelo `UnitDatabase`.
- O teste de colisão usa o Cultista V1 `infernal` real e o Bruxo V2 `infernal`: ambos têm o trait público, mas
  repertórios, Grimório, `MagicAI`, ritualistas da Transcendência V1.5 e UI permanecem isolados.

## Novo fundamento de dano mágico

Fórmula canônica, usada por `predict_damage` e pelo cast real:

```text
damage_amount × caster.spell_damage_multiplier × conditional_spell_multiplier
```

O último fator vale `1 + low_hp_damage_bonus` quando o limite está configurado e
`target.hp / target.max_hp <= low_hp_threshold`; caso contrário vale `1.0`. O limiar de 50% é inclusivo.

- Não consulta Ataque, Defesa, terreno, Fortify, Shield Wall, Égide, Comando/Presença, Retirada Tática,
  Tensões logísticas ou veterania defensiva. Não existe piso artificial nem resistência mágica.
- Não usa `CombatResolver.resolve`, não causa contra-ataque e nunca aceita cidade como alvo.
- Cada morte de spell chama uma vez a pipeline compartilhada e credita uma vez o caster; uma Explosão com
  três mortes produz três abates, sem duplicação.
- A mira humana exige visibilidade já calculada no `HexGrid.visibility`; não recalcula fog. Range 3/4 usa
  `HexMetrics.coords_within`, e o splash raio 1 nunca varre o mapa.

## Específico da Infernal

Os únicos dados específicos ficaram nos bancos de conteúdo:

| Nível | Nome | Unlock id |
|---:|---|---|
| N1 | Escola Infernal | `v2_magic_school_infernal` |
| N2 | Santuário Infernal | `v2_building_infernal_sanctum` |
| N3 | Bruxo Infernal | `v2_unit_infernal_warlock` |
| N4 | Chama Infernal | `v2_spell_infernal_flame` |
| N5 | Fogo Voraz | `v2_spell_devouring_fire` |
| N6 | Explosão Infernal | `v2_spell_infernal_blast` |
| N7 | Condenação | `v2_spell_damnation` |
| N8 | Círculo Profano | `v2_building_infernal_ritual` |
| N9 | Arquidemônio | `v2_manifestation_archdemon` |

- Santuário: 24 PP, upkeep 1, `UNIQUE`, treina Bruxo, zero Mana. Bruxo: 10 HP, Ataque 0, Defesa 1,5,
  Movimento 2, Visão 3, 24 PP, Supply 2, alcance 0, terrestre, sem ataque básico, potência 1,0.
- Chama: 5 Mana, range 3, recarga 0, dano 6. Fogo Voraz: 8 Mana, range 3, recarga 2, dano 8 e +50% em
  alvo com até 50% de Vida. Explosão: 11 Mana, range 3, recarga 3, dano 5 por hostil no alvo/raio 1, sem
  friendly fire. Condenação: 18 Mana, range 4, recarga 5, dano 15 em uma unidade.
- Círculo: 60 PP, upkeep 2, `UNIQUE`, exige Santuário e treina Arquidemônio. Arquidemônio: 36 HP, Ataque 0,
  Defesa 6, Movimento 3, Visão 4, 105 PP + 70 Mana, Supply 0, voo, caster, Grande Manifestação, não Lendária,
  sem ataque básico; Chama Primordial é apenas `spell_damage_multiplier = 1.25` por dado.
- Serafim e Arquidemônio coexistem porque o slot é por Escola; um segundo Arquidemônio é bloqueado. Sagrada
  N9 + Infernal N9 produz 2/2 e torna `v2_transcendence` pesquisável, mas o nó continua
  `gameplay_connected = false`: sem Ritual Final, exigência de Manifestações, botão ou vitória.
- Não existe `InfernalRuntime`, `InfernalCombatResolver` nem targeting específico. Runtime, combate, seleção,
  unidade e manifestação foram auditados contra ids/nome da Infernal.

## Compatibilidade transitória V1

A Magia V1, o Grimório, a Transcendência V1.5, seus rituais e a IA mágica V1 continuam presentes. A mudança
desta fase é somente o namespace explícito dos casters V2; não é a limpeza V1→V2. Um Cultista V1 Infernal
continua integralmente V1, e um Bruxo V2 nunca vira ritualista ou usuário de spell legado.

### Save/load e UI

- Round-trip com Clérigo, Bruxo, Serafim, Arquidemônio, ambas as pesquisas, Mana, Égide, cooldowns e slots
  rederivados passou sem bump de schema. Também há cobertura da produção Infernal aguardando Mana.
- Árvore mostra Sagrada 9/9 + Infernal 9/9, outras 36 pesquisas inertes e Transcendência 2/2 ainda inerte.
  Painel de unidade mostra Escola Infernal, sem ataque básico, Supply, os quatro spells na ordem N4–N7 e
  Chama Primordial/+25% no Arquidemônio. Targeting hostil usa o canal vermelho já existente.
- Os modelos são provisórios e reutilizados: torres existentes nos dois prédios, Mage/KayKit no Bruxo e
  `assets/generated/magic/archdemon/archdemon.glb` no Arquidemônio. Nenhum asset foi criado ou baixado.

### Testes

Foram adicionados 39 testes: 18 de spells/dano/hostilidade/defesas/mortes; 16 de conteúdo, namespace,
prédios, unidades, slots, produção e Transcendência; 3 de HUD; 1 fluxo real de 63 passos; e 1 round-trip no
SaveManager. Também foram migradas expectativas históricas que usavam Infernal como placeholder ou listas
fechadas antes do Bruxo/Arquidemônio. Resultados finais: **37/37** na bateria Infernal, **1/1** no fluxo
principal e **3418/3418** na suíte completa.

### Performance

Benchmark headless descartável, mapa Grande 320×84, seed 4242, três rivais; menor média de cinco passagens:

| Consulta | Tempo por chamada |
|---|---:|
| `spells_for_unit` Infernal | 0,0134 ms |
| alvos hostis range 3 / range 4 | 0,0672 / 0,1089 ms |
| `predict_damage` | 0,00127 ms |
| vítimas da Explosão, raio 1 | 0,0221 ms |
| helpers de namespace de Escola | 0,00159 ms |
| slot de Manifestação com duas Escolas | 0,0101 ms |
| `can_attack_unit` básico | 0,00370 ms |
| `predict` físico V1×V1 / unidade com Supply | 0,0507 / 0,0705 ms |
| `TurnManager.end_turn`, síncrono, 3 IAs | 49,2 ms |

O dano mágico só roda ao consultar/conjurar spell; o caminho físico não consulta `V2MagicRuntime` nem
`V2SpellDatabase`. As buscas são discos hexagonais limitados a range 4/raio 1. Não houve regressão material,
portanto `docs/PERFORMANCE_GUIDE.md` não recebeu regra nova nesta fase.

### Validação visual (não-headless, 1600×900, `Main.tscn` real, uma execução)

Confirmados em Vulkan/Forward+ no jogo real: árvore com as nove cartas Sagradas e nove Infernais concluídas,
as demais quatro linhas inertes e Transcendência exibindo 2/2; Santuário e Círculo renderizados; Bruxo com
Escola Infernal, Supply 2 e “Sem ataque básico”; Arquidemônio com 36 HP, Defesa 6, voo, Escola Infernal,
Chama Primordial +25% e os quatro spells; Serafim e Arquidemônio simultâneos; mira de Chama no canal hostil;
ESC real pelo `Input` cancelando a mira com Mana intacta; novo cast consumindo 5 Mana e causando exatamente
6 de dano, com ação consumida e sem revide. O fluxo funcional automatizado cobre ainda Fogo Voraz,
Explosão, Condenação, produção/espera e save/load.

## Ainda propositalmente pendente

- Necromancia e retinues undead; Druidismo e manipulação de terreno; Arcanismo, teleport, silence, dispel e
  portais; Elementalismo, clima e zonas ambientais.
- As outras quatro Grandes Manifestações; Transcendência funcional; Ritual Final; IA estratégica V2.
- Resistência mágica, DoT, summons menores, dano mágico a cidades e qualquer outro campo especulativo.
- Limpeza final V1→V2, bônus raciais, balanceamento definitivo e assets finais.

**Frase de encerramento:** a Escola Infernal está funcional sobre o molde mágico V2: V1 e V2 agora possuem
namespaces de Escola semanticamente separados, o jogo possui uma pipeline genérica de dano mágico independente
do combate físico, e Sagrada + Infernal demonstram que duas Escolas completas e duas Grandes Manifestações
podem coexistir sem ainda ativar a Transcendência.

---

# Fase 19 — Necromancia N1–N9, Hostes e Comando

**Objetivo:** terceira Escola de Magia completa, sem virar uma segunda Escola de dano: Necromantes transformam Mana e
capacidade de COMANDO em Hostes persistentes agrupadas (um token = uma formação), a perda de comandantes deixa parte
da horda SEM ORDENS em vez de apagá-la e o Lich Soberano amplia a capacidade pelo mesmo sistema genérico. **Não
implementa:** Druidismo, Arcanismo, Elementalismo, terreno, teleporte, silêncio, dissipar, portais, clima, zonas,
Transcendência funcional, Ritual Final, IA estratégica V2, resistência mágica, cadáveres, almas, conversão de
inimigos, ressurreição, summon temporário, upkeep de Mana por turno.

## Reutilizado sem alteração

- `V2ResearchState`/`V2UnlockSystem` (os seis tipos de unlock mágicos da Fase 17 — nenhum tipo novo), toasts genéricos
  por tipo, Conhecimento, Mana (`player.mana`), fila de produção, Suprimentos/Tensão, Déficit, slots de prédio.
- `V2ManifestationSystem` (1 por Escola, derivado, fail-closed) e `UnitData.production_mana_cost` (a mesma pipeline
  de espera do Serafim/Arquidemônio) — o Lich entra só por dado.
- `magic_cooldowns`/`magic_status`, `V2OwnerTurnEffect` ("até o início do próximo turno do dono"), o anel de estado
  ativo das Técnicas/Égide, `HexGrid.spawn_unit` (grid, `serial_id`, roster, save), `HexGrid.remove_unit`,
  `CombatResolver.predict/resolve` (morte, abate, veterania), ESC via PauseMenu, `SaveManager` sem campo novo.
- Traço `caster` semeado de `v2_magic_school` (Desmantelar do Ladino vale sozinho no Necromante e no Lich);
  `grand_manifestation` semeado da metadata do nó (Caçada Lendária não vale no Lich).

## Generalizado

- **`V2SpellData`** ganhou só quatro extensões: `TargetMode.EMPTY_TILE`, `required_target_trait`, `summon_unit_id`,
  `attack_bonus` (+ `is_summon()`; `is_buff()` passa a aceitar `attack_bonus`). Defaults inertes; a Sagrada e a
  Infernal não mudaram de dado.
- **`V2SpellDatabase`**: caches `offensive_spells()` (estado de Ataque) e `status_spells()` (todo estado temporário:
  expiração, marcador e linhas de UI agora iteram este, não só os defensivos); `effect_text` monta invocação
  ("Invoca uma Hoste Esquelética (Comando 1)."), bônus de Ataque e o qualificador do traço-alvo a partir do dado.
- **`V2MagicRuntime`**: `tile_reason`/`target_tiles` (EMPTY_TILE), filtro `required_target_trait` no alvo primário E
  na área (Onda futura com traço já funciona), `summon_data` (cache do UnitData invocado), `_cast_on_tile`,
  `attack_multiplier` (paralelo de `defense_multiplier`), `command_tooltip_line`, `_commit_action` extraído.
  `unavailable_reason` consulta `Unit.can_receive_orders()` (caminho rápido) e, para invocação, a capacidade ANTES
  da mira.
- **`CombatResolver.predict`**: UM fator `V2MagicRuntime.attack_multiplier(attacker)` no Ataque físico e o mesmo fator
  do DEFENSOR no revide (o revide deste motor sai da Defesa; ver "Retaliação" abaixo). `can_attack_unit`,
  `can_attack_city`, `resolve`, `resolve_city_attack`, `resolve_lair_attack` recusam quem não pode receber ordens.
- **`Unit.can_receive_orders()` / `order_block_reason()`**: helper genérico de ordem (default true); hoje compõe só o
  estado de retinue. HUD, SelectionManager, CombatResolver, HexGrid e V2MagicRuntime perguntam a ele — nenhum
  duplica a regra.
- **`UnitData.model_formation_count`** (visual, default 1) + `Unit._build_formation_copies`: N corpos como malha filha
  da MESMA Unit (sem HP/seleção/caminho individual), animando junto.
- `UnitData.own_target_phrase/plural` (texto de UI por traço) e `V2MagicContent.command_label/uncommanded_reason`
  (rótulos por Escola, dado de apresentação).

## Novo fundamento de retinues

`scripts/core/V2RetinueSystem.gd` (novo, `class_name`) — genérico; nenhum id/Escola concreto no código (teste varre).

- **Dados (`UnitData`, defaults inertes):** `retinue_school` + `retinue_command_cost` > 0 = retinue que OCUPA comando
  (`is_retinue()`; o traço `retinue` é semeado disso em `_seed_traits`); `retinue_command_capacity` > 0 num caster V2
  CONTRIBUI capacidade para a própria `v2_magic_school` (`is_retinue_commander()`); `retinue_command_capacity_name`
  (nome público opcional da passiva). Novos traços `undead` (declarado) e `retinue` (semeado).
- **Modelo:** capacidade GLOBAL por civilização e Escola (nunca caster→summon). Capacidades somam (Necromante 2,
  Lich 4: 1 N = 2, 2 N = 4, N + Lich = 6). Rival não soma.
- **API (tudo derivado de `player.units` vivas):** `command_state` (uma passada: capacidade, retinues por serial,
  comandadas, `total_cost`, `commanded_cost`), `command_capacity`, `command_used` (custo TOTAL, comandadas ou não — o
  "5" de "5 / 4"), `command_available` (nunca negativo), `can_add_retinue`, `retinues_for`, `commanded_retinues`,
  `uncommanded_retinues`, `is_commanded`, `summon_reason`, `dissolve`, `summary_lines`, `refresh_markers`.
  **Nada salvo:** nem capacidade, nem uso, nem quem está comandada, nem lista de summons.
- **Overload e escolha determinística:** só aparece por PERDA de capacidade (feitiço nunca cria overload: a
  capacidade é checada antes da mira e revalidada no clique). Retinues ordenadas por `serial_id` crescente; cada uma
  fica comandada se o custo cabe no restante, senão fica SEM COMANDO e a avaliação continua (A2/B1/C1 com cap 2 → só
  A; A1/B2/C1 → A e C).
- **Identidade estável:** `Unit.serial_id` — auditado: `HexGrid.spawn_unit` atribui `next_unit_id` crescente,
  `SaveManager` persiste e restaura o serial e sobe `next_unit_id`; nunca o instance id do objeto. Após load o mesmo
  greedy re-deriva as mesmas comandadas (teste com 3 Hostes / 1 Necromante).
- **Caminho rápido:** `is_commanded` devolve true na hora para quem não é retinue (`unit_data.is_retinue()` falso) —
  unidades normais, V1, casters, Manifestações, Construtor, Colonizador não pagam varredura (teste: unidade sem dono
  continua "comandada", prova de que não houve scan).
- **Sem comando** (a retinue continua no mapa com HP, Defesa, dono, veterania e estados; pode ser atacada):
  - movimento: gate central em `HexGrid.move_unit` (cobre seleção, marcha, explorar, IA rival/monstro, técnicas) +
    `unit_reachable` vazio (UI) + `continue_move_order`/`explore_step` retornam sem cancelar a ordem/modo;
    `movement_left` NUNCA é zerado — se o comando volta no mesmo turno, o resto do movimento vale;
  - ataque: `can_attack_unit`/`can_attack_city` recusam; `resolve`/`resolve_city_attack`/`resolve_lair_attack`
    fail-closed (nem captura cidade por ataque);
  - ação: `SelectionManager._accepts_manual_orders` e `V2MagicRuntime.unavailable_reason` usam o mesmo helper;
  - motivo: "Hoste sem comando necromântico." (tooltip do Mover, painel "SEM COMANDO — não pode receber ordens.").
- **Retaliação:** defender/revidar NÃO passa pelo helper de ordem — `can_basic_attack` continua true para as
  Hostes; o revide é resolvido do lado do defensor pela conta física normal. Teste: Hoste sem comando atacada revida
  exatamente o previsto.
- **Recuperação:** treinar outro comandante devolve o comando na próxima consulta, sem rebind, feitiço, botão ou
  custo; o anel cinza some.
- **Dissolver:** `V2RetinueSystem.dissolve` → `HexGrid.remove_unit`; nunca `register_kill`: sem abate, XP, saque,
  Mana nem notificação de combate; libera o custo por derivação. Botão "Dissolver Hoste" só em retinue, vale MESMO
  sem comando (é como se resolve um overload); não havia padrão simples de confirmação na HUD, então não há modal.
- **Marcador:** `Unit.refresh_command_marker` — anel CINZA neutro (maior que o ciano de Técnica/Égide), sem asset.
  Re-derivado por `V2RetinueSystem.notify_roster_changed` em `spawn_unit`/`remove_unit` (só age se a unidade é
  retinue ou comandante) e por `refresh_all_markers` no fim do load de cada jogador.
- **Sem `_process`, sem varrer mapa:** consultas só em UI/movimento/ataque/feitiço/nascimento/morte/load; a mira de
  tile usa só o disco do alcance.

## Específico da Necromancia (só dado/conteúdo)

| N | Nome | Tipo | `unlock_id` |
|---|---|---|---|
| 1 | Escola da Necromancia | school | `v2_magic_school_necromancy` |
| 2 | Ossuário | school_building | `v2_building_necromancy_ossuary` |
| 3 | Necromante | caster | `v2_unit_necromancer` |
| 4 | Erguer Mortos | spell | `v2_spell_raise_dead` |
| 5 | Recompor Ossos | spell | `v2_spell_mend_undead` |
| 6 | Comando Macabro | spell | `v2_spell_macabre_command` |
| 7 | Erguer Legião | spell | `v2_spell_raise_legion` |
| 8 | Mausoléu Negro | ritual_building | `v2_building_necromancy_ritual` |
| 9 | Lich Soberano | grand_manifestation | `v2_manifestation_lich_sovereign` |

As 9 entradas vivem em `V2MagicContent` (nenhum `V2NecromancyContent`). **Totais:** Sagrada 9/9, Infernal 9/9,
Necromancia 9/9 = **27/54** nós mágicos normais conectados; Druidismo/Arcanismo/Elementalismo 0/9;
Transcendência `gameplay_connected = false`, requisito continua "2 Escolas completas" (três completas saturam 2/2).

**Prédios (BALANCE PLACEHOLDER):** Ossuário 24 PP, 1 Ouro/turno, UNIQUE, sem prédio exigido, treina o Necromante,
0 Mana. Mausoléu Negro 60 PP, 2 Ouro/turno, UNIQUE, exige o Ossuário na mesma cidade, ocupa slot, fila normal,
Déficit bloqueia iniciar, produz o Lich. Nenhum prédio treina Hoste.

**Unidades (BALANCE PLACEHOLDER):**

| Unidade | HP | Atq | Def | Mov | Visão | PP | Supply | Comando | Traços |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| Necromante | 10 | 0 | 1,5 | 2 | 3 | 24 | 2 | capacidade +2 | caster |
| Hoste Esquelética | 18 | 4,0 | 3,0 | 2 | 2 | — | 0 | custo 1 | undead, retinue |
| Hoste Macabra | 30 | 7,0 | 5,0 | 2 | 3 | — | 0 | custo 2 | undead, retinue |
| Lich Soberano | 34 | 0 | 6,0 | 2 | 4 | 100 + 65 Mana | 0 | capacidade +4 (Soberania dos Mortos) | caster, undead, grand_manifestation |

Necromante e Lich: `can_basic_attack = false`, `v2_magic_school = "necromancy"`, `magic_school = ""`, GROUND. Hostes:
melee, combate físico normal (Shield Wall, terreno, técnicas, feitiços, Ataque da Cidade valem normalmente; sem bônus
de Cerco; veterania pela pipeline normal), não conjuram, não são Manifestação nem Lendária, fora de
`PLAYER_TRAINABLE_KINDS` (e `City.can_train` recusa mesmo com tudo pesquisado). Hostes e Lich: 0 Suprimentos (perder
Fazendas não põe as Hostes em Tensão; os Necromantes, com 2, sim). Hoste Macabra não é upgrade da Esquelética:
coexistem como opções de custo (um Necromante: 2 Esqueléticas OU 1 Macabra, nunca as duas).

**Feitiços (BALANCE PLACEHOLDER; nenhum causa dano — `damage_amount == 0` nos quatro):**

| Feitiço | Alvo | Mana | Alcance | Recarga | Efeito |
|---|---|---:|---:|---:|---|
| Erguer Mortos | EMPTY_TILE | 7 | 2 | 2 | invoca 1 Hoste Esquelética (comando 1 do UnitData) |
| Recompor Ossos | OWN_UNIT, `undead` | 6 | 3 | 1 | cura 8, sem overheal; alvo cheio inválido |
| Comando Macabro | OWN_UNIT, `retinue` | 7 | 3 | 2 | +40% Ataque até o início do próximo turno do dono |
| Erguer Legião | EMPTY_TILE | 15 | 2 | 4 | invoca 1 Hoste Macabra (comando 2) |

- **EMPTY_TILE:** tile existe, visível ao humano (a mesma regra de visibilidade dos feitiços), distância 1..alcance,
  sem unidade, sem covil, sem cidade alheia (a própria vale), terreno legal para o UnitData invocado (terrestre/voo
  tático só em terra — oceano/montanha/lava recusados). Território não importa (próprio, neutro, inimigo em guerra).
  Mira no canal AZUL utilitário (o do posicionamento de prédio), dica "Escolha o tile livre de … (ESC cancela)";
  ESC/clique fora não gastam Mana, recarga, ação nem comando.
- **Invocação:** nasce por `HexGrid.spawn_unit` (nunca pelo combate), dono = do conjurador, Vida cheia,
  `movement_left = 0` (age a partir do próximo turno do dono; pode retaliar desde já). Mana/recarga/ação só são
  cobradas DEPOIS de nascer; se a capacidade caiu entre a mira e o clique, nada nasce e nada é gasto. Persistente:
  sem timer, sem upkeep.
- **Comando Macabro:** o mesmo feitiço não acumula consigo (segundo conjurador refresca, nunca 1,4×1,4); combina
  com os outros fatores de Ataque sem código específico; vale no revide enquanto ativo; uma Hoste sem comando mantém
  o estado mas não inicia ataque até o comando voltar.
- **Repertório** por `v2_magic_school` + pesquisa do dono: Necromante e Lich conhecem os quatro; reset de pesquisa
  mantém unidades e capacidade física, tira o repertório (nenhuma invocação nova) e o buff ativo expira normalmente.
- **Lich Soberano:** Soberania dos Mortos = `retinue_command_capacity = 4` + `retinue_command_capacity_name` (nenhum
  LichSystem); `retinue_command_cost = 0` (cria capacidade, não a consome). Slot "necromancy" do
  `V2ManifestationSystem`: Serafim + Arquidemônio + Lich coexistem; segundo Lich bloqueado (e fail-closed no
  nascimento); a Sagrada continua bloqueando o segundo Serafim independentemente. Mana de produção 65: exigida para
  iniciar, não reservada, a produção completa espera sem perder PP (sobrevive a save/load), cobrada uma vez.

## Integrações entre Escolas

- **Sagrada × Hostes:** Luz, Onda e Milagre curam Hostes (unidades próprias) e a Égide as protege; Recompor cura só
  undead, a Luz cura qualquer próprio — sem regra de exclusão ("Holy não cura undead" não existe).
- **Infernal × Hostes:** Chama/Explosão/Condenação atingem Hostes normalmente, ignorando a Defesa física (Chama 6
  numa Hoste de Defesa 3 = 6); a Explosão pega várias Hostes hostis. Sem exceção undead.
- **Ladino:** Desmantelar vale contra Necromante e Lich (caster); Hostes não são caster (só o ataque físico normal).
  **Caçada Lendária:** não vale contra Lich nem Hostes.
- **Militar:** Hostes não pertencem a Doutrina (sem Técnicas), mas o `attack_multiplier` é um fator genérico que
  compõe com qualquer outro.

## Compatibilidade transitória V1

A Necromancia V1 (Escola `necromancia`, `necromancer`/`bound_skeleton`/`elder_lich`, invocações com `summoner_id`/
`expires_turn`, IA autônoma do Lich Ancião) continua existindo e independente: namespaces de Escola separados
(`magic_school` × `v2_magic_school`), o Necromante V1 continua V1. As retinues V2 não usam `summoner_id` nem
`expires_turn`.

## Save / load

Sem campo novo: Hostes, Necromantes e Lich são Units normais recriadas pelo `visual_kind` (kind, HP, posição,
movimento, veterania, recargas, estados); `serial_id` restaurado; comando, capacidade e marcadores re-derivados
(`refresh_all_markers` no fim do load de cada jogador); a espera de Mana do Lich pelo `production_item`/
`stored_production`; slots re-derivados. Testes varrem o JSON: nenhum `command_*`, `commanded`, `retinue` ou lista de
summons salvos.

## IA

Sem IA Necromante (não pesquisa, não invoca, não escolhe Hoste nem buff). Com Hostes via fixture, três turnos reais
de `TurnManager.end_turn` passam sem crash, as Hostes persistem e a Hoste sem comando não é movida por nenhuma rotina
genérica (o gate de `move_unit` e o fail-closed do combate cobrem a IA).

## Testes

79 testes novos em 6 scripts + 1 no SaveManager; suíte completa **3497 / 3497**, 147 scripts.

- `test_v2_necromancy_content` (15): nove nós (ids/tipos/custos/pré-requisitos), totais 27 conectados × 27 inertes,
  Transcendência inerte com requisito 2, objetos reais sem colisão V1, tooltips/toasts/N1 sem bônus, Ossuário e
  Mausoléu, Necromante, Hostes (Supply 0, traços, não treináveis nem com tudo pesquisado), Lich, defaults inertes de
  `UnitData`/`V2SpellData`, registros dos feitiços, nenhum dano mágico, varredura anti-hardcode (V2RetinueSystem,
  V2MagicRuntime, CombatResolver, SelectionManager, Unit, HUD, V2SpellData, V2ManifestationSystem, HexGrid) e
  ausência de arquitetura paralela.
- `test_v2_retinue_system` (16): capacidade 0/2/4/6/4 e rival; uso (morta/dissolvida não contam); caminho rápido;
  os dois exemplos de overload do §19; save/load com a mesma escolha e o anel re-derivado (JSON sem campo de
  comando); sem comando não move por nenhum caminho (movimento restante preservado, marcha/explorar pendentes), não
  inicia ataque (unidade/cidade), pode ser atacada, mantém Defesa, revida; recuperação sem custo; morte do
  Necromante (§147) e perda parcial (§148); Dissolver (sem ouro/abate/Mana) só em retinue, pela seleção mesmo sem
  comando e nunca a de outro dono; três turnos reais com Hostes rivais sem ordem inválida.
- `test_v2_necromancy_spells` (26): repertório compartilhado com o Lich; EMPTY_TILE (livre, ocupado, água, montanha,
  fora de alcance, o próprio tile, inválido, oculto, própria cidade, cidade alheia, território inimigo em guerra,
  neutro); Erguer Mortos (Mana 7 uma vez, recarga 2, movimento 0, serial, ação); capacidade antes da mira e
  revalidação no clique sem gastar nada; mira no canal utilitário e ESC; persistência em save/load; Recompor
  (Hoste/Macabra/Lich sim; vivo/Necromante/cheio não; +8, clamp); Comando Macabro (só retinue, +40%, predict ==
  resolve, revide ×1,4, refresca sem empilhar, expira no turno do dono, sobrevive ao load, sem comando mantém o
  estado); caminho rápido e buff defensivo que não mexe no Ataque; Erguer Legião (15/2/4, custo 2, persistente);
  capacidade 1 bloqueia a Legião; 2 Esqueléticas × 1 Macabra; feitiço nunca cria overload; reset de pesquisa;
  Sagrada/Infernal/Ladino/Caçada Lendária × Hostes e Lich.
- `test_v2_lich_manifestation` (14): Ossuário (N2/N3), Mausoléu (N8 + Ossuário, slot, Déficit), Lich (N9 + Mausoléu),
  +4 e repertório (o Lich não ocupa o próprio comando), morte do Lich, curas, Desmantelar sim / Caçada não, três
  Manifestações e bloqueios por Escola, fail-closed do segundo Lich, bateria de Mana 65 com save/load da espera,
  cancelamento, identidade após load, Transcendência inerte com três Escolas e três Manifestações.
- `test_v2_necromancy_hud` (6): seção de comando, ordem dos quatro botões, tooltips "Comando disponível" e
  "insuficiente", Hoste com "Dissolver Hoste", SEM COMANDO com Mover/Fortificar/Explorar desabilitados e Dissolver
  ativo, unidades normais sem nada novo, Soberania dos Mortos.
- `test_v2_phase19_main_flow` (1): o fluxo §154 (66 passos) num jogo real com GameManager, fila, turnos, mira pela
  SelectionManager, combate real, perda de comando, Lich esperando Mana, três Manifestações e save/load.
- `test_save_manager` (+1): round-trip de Hostes/Necromante/Lich com comando re-derivado e nada salvo.
- Migrados (sem mudar o que verificam): testes das Fases 3–18 que usavam a Necromancia como exemplo de Escola inerte
  (agora o Druidismo) e as listas fechadas de conectados/treináveis/não-combatentes.

## Performance

Benchmark headless descartável (`scripts/_perf_bench.gd`, apagado), mapa Grande 320×84, seed 4242, 3 rivais; o
humano com 36 unidades normais, 4 Necromantes, 10 retinues (capacidade 12, uso 14 — overload de propósito, 9
comandadas) e 3 Manifestações (58 unidades); menor média de 5 passagens × 2000–20000 chamadas:

| Consulta | Tempo por chamada |
|---|---:|
| `command_capacity` / `command_used` | 0,056 / 0,059 ms |
| `commanded_retinues` (10, com overload) | 0,086 ms |
| `is_commanded` unidade normal (caminho rápido) / `Unit.can_receive_orders` | 0,0010 / 0,0013 ms |
| `is_commanded` retinue | 0,081 ms |
| EMPTY_TILE `target_tiles` alcance 2 | 0,063 ms |
| `unavailable_reason` Erguer Mortos (capacidade + tiles) | 0,135 ms |
| alvo com `required_target_trait` alcance 3 (Recompor) | 0,140 ms |
| `attack_multiplier` sem estado / com Comando Macabro | 0,0006 / 0,0020 ms |
| `predict` normal × inimigo / retinue × inimigo | 0,095 / 0,060 ms |
| `can_attack_unit` normal / retinue | 0,005 / 0,082 ms |
| `unit_reachable` retinue sem comando | 0,084 ms |
| `TurnManager.end_turn` (síncrono, 3 IAs) | 50,1 ms |

Unidades normais pagam só o caminho rápido (~1 µs); o custo de ~0,08 ms é só de retinue, e só quando ela é
consultada (seleção, passo de movimento, ataque). O turno completo (50,1 ms com 58 unidades humanas) ficou no
patamar da Fase 18 (49,2 ms com 45). Sem regressão relevante: **nenhum cache** (nada a invalidar) e nenhuma seção
nova em `docs/PERFORMANCE_GUIDE.md`.

## Validação visual (não-headless, `Main.tscn` real, uma execução)

Uma execução no `Main.tscn` real, 1600×900, partida 60×40 criada pelo `_on_new_game_requested` (uma primeira
tentativa do roteiro descartável parou antes da 2ª captura porque esperava só 4 frames pelo turno escalonado das
IAs — o roteiro foi corrigido para aguardar `is_turn_processing`, validado em headless sem capturas e então
executado UMA vez com janela). Confirmado nas capturas: aba Magia com as linhas Sagrada/Infernal intactas e a linha
"Necromancia — Mortos-vivos e Retinues" N1–N9 concluída (Druidismo/Arcanismo/Elementalismo placeholders); Ossuário
construído; painel do Necromante ("Sem ataque básico.", "Comando Necromântico: 0 / 2", "Suprimentos: 2", os quatro
botões); mira de Erguer Mortos com a dica "Escolha o tile livre de Erguer Mortos (ESC cancela)" e os tiles em azul;
Hoste Esquelética em formação de três corpos no mesmo tile (movimento 0/2, "Comando Necromântico: 1 / 2",
"Dissolver Hoste"); com 2/2 os botões Erguer Mortos e Erguer Legião desabilitados; Hoste Macabra em formação de
cinco; após a morte de um Necromante, "SEM COMANDO — não pode receber ordens.", "Comando Necromântico: 4 / 2",
"2 Hostes sem comando" e Mover/Fortificar/Explorar desabilitados com Dissolver ativo; Mausoléu Negro; Lich com
"Passiva da Manifestação — Soberania dos Mortos / Concede +4 de capacidade de Comando Necromântico." e "3 / 6", e o
botão de produção de um segundo Lich desabilitado; Serafim, Arquidemônio e Lich juntos (slots 1/1/1 no log);
save/load pelo SaveManager com "Comando Necromântico: 3 / 6" antes e depois e as duas Hostes restantes. **Ressalva
honesta:** o anel cinza de "sem comando" existe (coberto por teste de nó), mas ficou pouco legível na captura sob o
painel/toasts de debug; nenhuma arte nova foi feita para ele.

## Assets (provisórios, nenhum criado/baixado)

Ossuário = torre A e Mausoléu = torre B do KayKit (o mesmo placeholder das outras Escolas); Necromante = Mage do
KayKit (escala 0,95); Hostes = o esqueleto da Asset Factory (`skeleton_blocky.glb`, o mesmo do monstro Esqueleto)
em formação de 3 (Esquelética) e 5 (Macabra) corpos dentro da MESMA Unit, escala 1:1 (altura do preset); Lich = o
`elder_lich.glb` da Asset Factory (Lich Ancião V1).

## Ainda propositalmente pendente

- Druidismo e manipulação de terreno; Arcanismo, teleporte, silêncio, dissipar e portais; Elementalismo, clima e
  zonas ambientais.
- As outras três Grandes Manifestações; Transcendência funcional; Ritual Final; IA estratégica V2.
- Resistência mágica, cadáveres/almas, conversão, ressurreição, summon temporário, upkeep de Mana, comandos de grupo
  autônomos das Hostes ("seguir/proteger/atacar região" do conceito).
- Limpeza final V1→V2, bônus raciais, balanceamento definitivo e assets finais.

**Frase de encerramento:** a Necromancia V2 está funcional sem virar uma segunda Escola de dano: Necromantes
transformam Mana e capacidade de comando em Hostes persistentes agrupadas, a perda de comandantes deixa parte da
horda sem ordens em vez de apagá-la, e o Lich Soberano expande essa capacidade pelo mesmo sistema genérico de
retinues, mantendo Sagrada, Infernal e as três Grandes Manifestações interoperáveis.

---

# Fase 20 — Druidismo N1–N9 e Modificação Física de Terreno

**Objetivo:** quarta Escola de Magia completa, como manipulação FÍSICA do campo de batalha: Druidas criam e restauram
modificações persistentes de terreno que alteram movimento e Defesa física sem substituir o terreno-base do mapa, e o
Avatar da Natureza amplia o alcance dessa linguagem. **Não implementa:** Arcanismo, teleporte, silêncio, dissipar,
portais, Elementalismo, clima, zonas ambientais, DoT, resistência mágica, dano mágico novo/contra cidade, terremoto,
destruição de prédio, mudança de recurso, criação de água/terra, transformação de montanha, tile impassável, root,
dono de terreno, bônus de recurso, Transcendência funcional, Ritual Final, IA estratégica V2.

## Auditoria do terreno (antes de mudar)

- **Tile:** `HexGrid.tiles[coord]` → `HexTileData` (tipo/bioma, `movement_cost` — hoje 1 em TODO terreno —,
  `defense_bonus`, rendimentos, `resource`). A magia V1 (`transform_tile_terrain`, Metamorfose de Gaia) **troca o
  objeto** do tile e grava `terrain_changes` (reaplicado sobre o mapa da semente no load). Por isso a modificação V2
  NÃO fica num campo do `HexTileData`: seria apagada por essa troca.
- **Custo de movimento** era lido em 6 lugares: `compute_reachable` (alcance/UI/Carga/IA), `compute_path` (A*: marcha,
  explorar, IA), os laços passo a passo de `continue_move_order` e `explore_step`, e `RivalAI.move_unit_toward`.
  `flight_reachable` (voo tático) usa distância geométrica, `infiltrate_reachable` (Passo Sombrio) e `flat_cost`
  (Retirada Tática) custam 1 por passo, e o voo V1 (`flies`) paga 1 — **todos já ignoram o custo do terreno-base**.
- **Defesa:** `CombatResolver.predict` soma o `defense_bonus` do terreno do defensor (voadores inclusive); o Mago V1
  (`ignores_terrain_defense`) ignora terreno/prédio/Fortificar. O dano mágico V2 (`predict_damage`) nunca lê Defesa.
- **Estruturas:** `buildings_by_coord` (prédios), `City.resource_improvements` + `improvement_markers_by_coord`
  (melhorias V2), `lairs_by_coord` (covis), `cities_by_coord`. Colocação: `HexGrid.place_building` (fila e load),
  `V2ConstructorRuntime.improve_resource`, `HexGrid.found_city`.
- **Save:** mapa regenerado pela semente + listas esparsas (`terrain_changes`, `terrain_resources`, `pillaged_tiles`).
  Visual: multimesh de terreno + props de árvore/recurso; entidades seguem a neblina em `_apply_fog_to_entities`.
- **Cache de caminho/alcance:** não existe (só `_last_came_from`, transitório) — nada a invalidar.

## Reutilizado sem alteração

- Todo o molde mágico das Fases 17–19: `V2ResearchState`/`V2UnlockSystem` (os seis tipos, toasts genéricos),
  Mana, fila, Suprimentos/Tensão, Déficit, slots, `V2ManifestationSystem` (1 por Escola, fail-closed),
  `production_mana_cost` (espera sem perder PP), `magic_cooldowns`, repertório por `v2_magic_school`, mira com ESC via
  PauseMenu, canal AZUL utilitário da mira EMPTY_TILE, `splash_radius` (o raio da área de Despertar), save por
  `visual_kind`.
- O A*/Dijkstra, `HexMetrics.coords_within`, a regra de visibilidade dos feitiços (`HexGrid.visibility`, nunca
  recalcula neblina), `_apply_fog_to_entities`, as árvores KayKit (`_tree_mesh`) e o `visual_template` da Fase 9.
- Traço `caster` (Desmantelar vale no Druida e no Avatar), `grand_manifestation` (Caçada Lendária não vale no Avatar).

## Generalizado

- **`V2SpellData`**: `TargetMode.TILE` (qualquer tile existente/visível/ao alcance, MESMO com unidade, e o próprio tile do
  conjurador — alcance 0..N, corrigindo de saída o achado da Fase 17 de que `coords_within` não inclui o centro),
  `terrain_modification_id`, `remove_terrain_modification`, `requires_existing_terrain_modification`; helpers
  `is_terrain_spell()`/`targets_tile()`. Nenhum campo de clima/zona/duração.
- **`V2MagicRuntime`**: `effective_range` (alcance do primário = `cast_range` + `UnitData.spell_range_bonus`, usado em
  TODA mira — unidade e tile); `tile_reason` cobre EMPTY_TILE e TILE e os requisitos de terreno; `terrain_area_tiles`
  (área do feitiço de terreno: primário primeiro, depois `coords_within` em ordem estável, só elegíveis e — para o humano
  — só visíveis); `_cast_on_tile` decide toda a área ANTES de mudar qualquer tile (zero tiles = nada gasto);
  `tile_target_label` (rótulo da mira sem saber o que é). A Sagrada/Infernal/Necromancia não mudaram de dado.
- **`UnitData.spell_range_bonus`** (+ `spell_range_bonus_name`), default 0: idêntico a antes para toda Escola.
- **`V2SpellDatabase.effect_text`** monta o texto de terreno do dado ("Cria Bosque Denso: +1 custo de movimento e +20%
  Defesa física.", área com o raio, "Remove uma modificação física V2 de terreno do tile…").
- **`SelectionManager`**: mira TILE no mesmo canal azul e rótulo genérico; exclusividade e ESC como antes.
- **HUD**: passiva de alcance por dado ("Passiva da Manifestação — Domínio Natural / +1 alcance de feitiços.") e
  "Alcance efetivo: N." no tooltip do botão quando há bônus (o texto do dado segue mostrando o alcance BASE).

## Novo fundamento de terreno V2

Arquivos novos (`class_name`, genéricos — varredura de teste garante que nenhum cita conteúdo Druídico):
`scripts/data/V2TerrainModificationData.gd`, `scripts/data/V2TerrainModificationDatabase.gd`,
`scripts/core/V2TerrainRuntime.gd`.

- **Onde fica o estado:** `HexGrid.v2_terrain_modifications` — `Dictionary` coord → id, no MAPA. Não na cidade (o tile
  pode ser neutro ou mudar de dono), não em unidade (nunca vira `magic_status`), não no `HexTileData` (a magia V1 troca
  o objeto do tile; teste prova que a camada sobrevive a `transform_tile_terrain`). **No máximo uma por tile.**
- **Por que não altera o terreno-base:** `terrain_type`, bioma, recurso, rendimento, `movement_cost` e `defense_bonus`
  do tile continuam os gerados — map gen, saves antigos, fundação, recursos e a V1 transitória leem o mesmo dado, e
  remover a modificação devolve exatamente o terreno original (teste compara o objeto e todos os campos).
- **Sem dono:** nada de criador salvo. Qualquer civilização paga o custo, recebe a Defesa (inclusive o inimigo que
  ocupa o tile), anexa ou captura o território sem mudar nada; qualquer Druida com Restaurar remove qualquer uma.
- **Persistência:** entre turnos, sem conjurador, após a morte do Druida, após captura/anexação e após save/load. Só sai
  por um efeito que a remova explicitamente ou por uma construção física permanente que ocupe o tile.
- **Lookup O(1):** `modification_id_at` → `movement_cost_delta` / `defense_multiplier_at` (caminho rápido: dicionário
  vazio = 0 / 1.0). Nada varre a lista; nada por frame.
- **Movimento:** fonte única `HexGrid.terrain_step_cost(coord)` = custo-base + delta, usada pelos 6 leitores auditados
  (alcance, A*, marcha, explorar, IA). **Semântica dos perfis preservada** (princípio §16/§20 — terreno-base e
  modificação nunca divergem): voo tático, voo V1, Passo Sombrio (INFILTRATOR) e custo plano da Retirada Tática já
  ignoravam o custo do terreno e **ignoram o delta também** (o próprio texto do Passo Sombrio já dizia "ignora custo
  extra de terreno terrestre"); GROUND, Cavalaria, Cerco, Hostes, Construtor, IA pagam. Ver ressalva abaixo.
- **Regra do primeiro passo (nova, genérica):** um passo mais caro que o movimento restante só vale como o PRIMEIRO
  passo do trecho e consome todo o resto (`compute_reachable` e `HexGrid.affordable_step_cost` nos laços passo a
  passo). Sem ela, Terreno Elevado (custo 3) seria um MURO para toda unidade de Movimento 2 — o que o §14 proíbe.
  Inerte para a V1: todo terreno-base custa 1.
- **Pathfinding:** o A* (heurística 1/passo, ainda admissível) desvia quando o contorno é mais barato e atravessa quando
  não é (teste com os dois casos). Ordens de vários turnos recalculam o caminho a cada turno (comportamento existente),
  então herdam o custo novo sem replanejamento global. Nenhum cache a invalidar.
- **Defesa:** UM fator `V2TerrainRuntime.defense_multiplier_at` na Defesa física de `CombatResolver.predict`
  (`predict == resolve`), pela MESMA regra do bônus do terreno-base: o Mago V1 que ignora terreno ignora também;
  voadores recebem (como recebem o terreno-base). O revide deste motor sai da Defesa, então cresce junto, sem exceção.
  Ataque, HP, cidade e dano mágico intocados (Chama 6 = 6 sem/Bosque/Elevado/Elevado+Égide).
- **Elegibilidade (`application_reason`):** tile existe; não bloqueia unidade terrestre (água/montanha/lava); sem cidade;
  sem prédio, melhoria de recurso V2 nem covil; sem outra modificação. Unidade no tile NÃO impede a camada (quem exige
  tile vazio é o modo de mira EMPTY_TILE). Recurso natural bruto pode ficar — rendimento e anexação não mudam.
- **Construção limpa (transacional):** `V2TerrainRuntime.clear_for_construction` é chamado só no momento em que a
  estrutura ocupa o tile — `HexGrid.place_building` (fila/colocação real), `V2ConstructorRuntime.improve_resource` (no
  sucesso, antes de gravar a melhoria) e `HexGrid.found_city` (só o tile central; o resto do território fica). Sem
  custo, Druida, Mana, recarga. Construção que falha (colocação fora da área, Construtor sem carga) não limpa. Isso
  impede lock econômico permanente: o rival constrói normalmente sobre um Bosque.
- **Anexação e captura não limpam** (a modificação é parte do terreno).
- **Visual:** `HexGrid.refresh_terrain_modification_marker(coord)` — só o tile tocado; Bosque = 5 árvores KayKit
  reaproveitadas na borda do hexágono (tom mais verde), Terreno Elevado = monte baixo + 6 rochas por primitivas
  (nenhum asset criado/baixado). Sem colisão (nunca bloqueia clique), corpos na borda (nunca cobrem a unidade), terreno
  base continua renderizado, nenhum rebuild de mesh global/minimapa. Load recria os marcadores.
- **Neblina:** aplicar não concede visão; o marcador segue a visão ATUAL do tile (`_apply_fog_to_entities`), nunca
  revela área oculta, e quando o tile volta a ser visto mostra o estado atual (a neblina nunca apaga o estado). O
  inspetor só mostra a modificação com o tile VISÍVEL. Para o humano, a área de Despertar ignora tiles ocultos.
- **Save/load:** bloco opcional GLOBAL `v2_terrain_modifications` = lista esparsa `[x, y, id]` (sem bump de versão;
  save antigo = nenhuma). Restaurado logo depois de `terrain_changes`, antes de cidades/prédios (que limpam o próprio
  tile ao serem recolocados). Fail-safe: entrada malformada, tile inexistente ou id desconhecido são ignorados sem
  derrubar o save. Custo/Defesa nunca salvos (derivados do id).
- **Inspetor:** "Modificação: Bosque Denso / Movimento: +1 custo / Defesa física: +20%" abaixo do terreno-base; sem
  modificação, nenhuma seção vazia.
- **Performance:** ver a seção abaixo e `docs/PERFORMANCE_GUIDE.md` §2.8.

## Específico do Druidismo (só dado/conteúdo)

| N | Nome | Tipo | `unlock_id` |
|---|---|---|---|
| 1 | Escola Druídica | school | `v2_magic_school_druidism` |
| 2 | Círculo Druídico | school_building | `v2_building_druidic_circle` |
| 3 | Druida | caster | `v2_unit_druid` |
| 4 | Brotar Bosque | spell | `v2_spell_grow_grove` |
| 5 | Restaurar Terreno | spell | `v2_spell_restore_terrain` |
| 6 | Erguer Terreno | spell | `v2_spell_raise_ground` |
| 7 | Despertar a Mata | spell | `v2_spell_awaken_forest` |
| 8 | Bosque Ancestral | ritual_building | `v2_building_druidic_ritual` |
| 9 | Avatar da Natureza | grand_manifestation | `v2_manifestation_nature_avatar` |

Nove entradas em `V2MagicContent`; o título da linha passou a "Escola Druídica" (o painel pedido). **Totais:**
Sagrada, Infernal, Necromancia e Druidismo 9/9 = **36/54**; Arcanismo e Elementalismo 0/9; Transcendência
`gameplay_connected = false`, requisito continua 2 Escolas (quatro completas saturam 2/2).

**Modificações (BALANCE PLACEHOLDER):** Bosque Denso `v2_terrain_dense_grove` (+1 custo, ×1,20 Defesa física); Terreno
Elevado `v2_terrain_raised_ground` (+2 custo, ×1,35). Nenhuma torna o tile impassável.

**Prédios (BALANCE PLACEHOLDER):** Círculo Druídico 24 PP, 1 Ouro/turno, UNIQUE, sem prédio exigido, treina o Druida, 0
Mana (moinho do KayKit). Bosque Ancestral 60 PP, 2 Ouro/turno, UNIQUE, exige o Círculo na mesma cidade, slot, fila,
Déficit bloqueia iniciar, produz o Avatar (torre A do KayKit).

**Unidades (BALANCE PLACEHOLDER):**

| Unidade | HP | Atq | Def | Mov | Visão | PP | Supply | Traços / passiva |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Druida | 12 | 0 | 2,0 | 2 | 3 | 24 | 2 | caster |
| Avatar da Natureza | 42 | 0 | 8,0 | 3 | 4 | 105 + 65 Mana | 0 | caster, grand_manifestation; Domínio Natural (`spell_range_bonus` 1) |

Ambos sem ataque básico, `v2_magic_school = "druidism"`, `magic_school = ""`, GROUND. O Avatar nunca é legendary/
retinue/undead; slot "druidism" coexiste com Serafim, Arquidemônio e Lich (quatro Manifestações); segundo Avatar
bloqueado (e fail-closed); Mana de produção 65 pela mesma pipeline (inicia com 65, não reserva, espera completa,
sobrevive ao load, cobra uma vez, cancelar não reembolsa).

**Feitiços (BALANCE PLACEHOLDER; nenhum causa dano, cura, status ou dono):**

| Feitiço | Alvo | Mana | Alcance | Recarga | Efeito |
|---|---|---:|---:|---:|---|
| Brotar Bosque | EMPTY_TILE | 6 | 3 | 1 | Bosque Denso no tile |
| Restaurar Terreno | TILE (com unidade / o próprio tile) | 5 | 3 | 1 | remove a modificação física do tile |
| Erguer Terreno | EMPTY_TILE | 9 | 3 | 3 | Terreno Elevado no tile |
| Despertar a Mata | EMPTY_TILE, `splash_radius` 1 | 16 | 4 | 5 | Bosque Denso no primário + vizinhos elegíveis |

- Motivos: "Este tile já possui uma modificação de terreno.", "O terreno está ocupado por uma estrutura permanente.",
  "Não há modificação de terreno para restaurar.", "Nenhum tile com modificação de terreno ao alcance.".
- **Restaurar** remove só a camada física V2 — nunca terreno-base, recurso, melhoria, status mágico de unidade, clima
  futuro (não é o dissipar do Arcanismo). Pode remover sob uma unidade, sem dano/movimento.
- **Despertar a Mata:** o primário precisa ser vazio e elegível (logo pelo menos 1 tile); os vizinhos recebem mesmo
  ocupados por unidade (efeito imediato na Defesa dela, ninguém se move); prédio/cidade/melhoria/covil/Elevado/Bosque
  existente são ignorados (nunca sobrescreve); tile oculto ao humano é ignorado. Área livre = exatamente 7 Bosques.
  Mana uma vez. Ordem estável (primário, depois a ordem de `coords_within`).
- **Domínio Natural:** Brotar/Restaurar/Erguer 3→4, Despertar 4→5; área, Mana, recarga e visão iguais; mirar a 5
  exige o tile visível por outra fonte (nenhuma neblina revelada).

## Integrações com as outras Escolas

- **Sagrada:** curas e Égide funcionam no Druida/Avatar; a Égide combina com o Bosque pela cadeia física; nenhum
  feitiço Sagrado mexe em terreno.
- **Infernal:** dano mágico ignora a camada (Chama 6 = 6 em Elevado + Égide).
- **Necromancia:** Hostes comandadas pagam o custo e recebem a Defesa; Hoste sem comando continua sem mover (o
  terreno nunca libera); Restaurar não mexe no comando; comando de volta = move respeitando o custo.
- **Militar:** Ladino (INFILTRATOR) segue atravessando unidades pela regra dele; Cavalaria e Cerco só o custo/Defesa
  genéricos, sem regra especial; nenhuma Técnica rebalanceada.

## Compatibilidade transitória V1

A Magia V1 (Druida V1 `druid` da Escola `druidismo`, Metamorfose de Gaia/`transform_tile_terrain`, Grimório,
Transcendência V1.5) continua intocada e independente; a camada V2 sobrevive a uma transformação V1 do tile. Nada de
população/comida/tiles trabalhados/ciência/barras de vitória antigas foi mexido.

## IA

Sem IA Druídica (não pesquisa, não conjura, não produz Avatar). O pathfinding genérico da IA (A* e `move_unit_toward`)
paga o custo pela mesma fonte, com a mesma regra do primeiro passo; turno real sem crash.

## Testes

74 novos em 6 scripts + 1 no SaveManager; suíte completa **3571 / 3571**, 153 scripts.

- `test_v2_terrain_modification` (27): dado/defaults/lookup/id inválido; matriz de elegibilidade (água, montanha, lava,
  cidade, prédio, melhoria, recurso bruto, unidade, já modificado); terreno-base e recurso intactos, remover/remover
  nada; sem dono em território próprio/neutro/inimigo, captura e anexação não limpam; custo no alcance (+1/+2), regra
  do primeiro passo, A* desviando/atravessando, marcha recalculando; voo tático/V1, Passo Sombrio e custo plano
  ignorando o delta como o terreno-base; IA pagando; Defesa ×1,20/×1,35 com predict == resolve e revide; Mago V1
  ignorando; voador recebendo; dano mágico idêntico; prédio/melhoria/fundação limpando só quando acontece; rival
  constrói sobre o Bosque; save/load global, save antigo, entradas inválidas; marcador por tile e neblina; inspetor;
  caminho rápido; transformação V1 preservando a camada; anti-hardcode e ausência de arquitetura paralela.
- `test_v2_druidism_content` (10): nove nós, 36/54, Transcendência 2/2 inerte, ids/colisão V1, toasts e título,
  prédios, Druida, Avatar, registros e textos dos feitiços, defaults inertes (nenhuma outra Escola ganhou alcance).
- `test_v2_druidism_spells` (19): repertório compartilhado; Brotar (Mana 6 uma vez, recarga 1, ação, validação
  completa inclusive oculto/estrutura/recurso bruto); mira azul e ESC; Restaurar (TILE, próprio tile, sob unidade,
  nada a restaurar, não toca base/recurso/status, qualquer Druida); Erguer; Despertar (7 exatos, ordem, secundários
  ignorados, efeito imediato na Defesa, primário inválido não gasta nada, save/load); alcance do Avatar genérico e sem
  revelar neblina; Sagrada, Infernal, Necromancia, Ladino e Cavalaria × Druidismo.
- `test_v2_nature_avatar` (12): Círculo (N2/N3, sem Mana), Druida (Déficit/Suprimentos, Tensão só na Defesa),
  Bosque Ancestral (N8, Círculo, slot, Déficit), Avatar (N9, sem ataque/revide, Desmantelar sim/Caçada não), quatro
  Manifestações e bloqueio por Escola, fail-closed, bateria de Mana 65 com save/load, cancelamento, identidade e alcance
  após load, Transcendência pesquisada sem vitória.
- `test_v2_druidism_hud` (4): painel do Druida (Escola, sem ataque, Suprimentos, 4 botões e tooltip do dado),
  Restaurar desabilitado com motivo, Avatar com Domínio Natural e "Alcance efetivo: 5.", inspetor.
- `test_v2_phase20_main_flow` (1): o fluxo §156 (55 passos) num jogo real — pesquisa, Círculo e Druida pela fila, mira
  com ESC, Bosque, movimento pagando +1, combate com predict == resolve, Restaurar, Erguer, Despertar com unidade,
  Mercado construído sobre Bosque pela fila, Mina sobre Bosque pelo Construtor, save/load, Bosque Ancestral, Avatar
  esperando Mana, Brotar a 4 e Despertar a 5 com visão de outra unidade, quatro Manifestações, árvores intactas.
- `test_save_manager` (+1): bloco global esparso, nada derivado salvo.
- Migrados (sem mudar o que verificam): testes que usavam o Druidismo como Escola inerte de exemplo (agora o
  Arcanismo) e as listas fechadas de conectados/treináveis/não-combatentes.

## Performance

Benchmark headless descartável (apagado), mapa Grande 320×84, seed 4242, 3 rivais, 51 unidades humanas, 76 tiles
modificados (corredor em volta do exército + toda a rota longa de 14 passos + área no destino); menor média de 5
passagens:

| Consulta | Sem modificação | Com modificações |
|---|---:|---:|
| `modification_id_at` (tile sem / com) | 0,0005 ms | 0,0007 / 0,0007 ms |
| `terrain_step_cost` | 0,0007 ms | 0,0027 ms |
| `movement_cost_delta` / `defense_multiplier_at` | — | 0,0020 / 0,0022 ms |
| `unit_reachable` Cavaleiro Mov. 4 | 1,27 ms | 1,49 ms |
| `compute_path` rota longa (14 passos, toda coberta) | 0,51 ms | 3,82 ms |
| `predict` (defensor em Terreno Elevado) | 0,047 ms | 0,048 ms |
| TILE `target_tiles` alcance 3 / EMPTY_TILE alcance 4 / alcance 5 (Avatar) | — | 0,18 / 0,28 / 0,40 ms |
| `terrain_area_tiles` raio 1 / `effective_range` | — | 0,007 / 0,0008 ms |
| `unavailable_reason` de Despertar (refresh do botão) | — | 0,29 ms |
| recriar 76 marcadores (restore do load) | — | 25,7 ms (uma vez, no load) |
| `TurnManager.end_turn` (sync, 3 IAs) | — | 38,6 ms |

O lookup é O(1) e o caminho rápido praticamente constante. O aumento do A* numa rota totalmente coberta é algorítmico
(heurística 1/passo fica folgada com custos > 1), não custo de consulta; como afeta o caminho quente de pathfinding de
forma mensurável, foi registrado em `docs/PERFORMANCE_GUIDE.md` §2.8. Turno completo no patamar das fases anteriores.

## Validação visual (não-headless, `Main.tscn` real, uma execução)

Partida 60×40 pelo `_on_new_game_requested` (o roteiro foi validado antes em headless, sem capturas; a execução com
janela foi uma só). Confirmado nas capturas: aba Magia com Sagrada/Infernal/Necromancia intactas e a linha Druidismo
N1–N9 (Escola Druídica … Bosque Ancestral) concluída, Arcanismo/Elementalismo placeholders; inspetor sobre um tile de
Selva mostrando o terreno-base intacto ("Selva … Mov. 1 | Def. +25%") e "Modificação: Terreno Elevado / Movimento: +2
custo / Defesa física: +35%"; o monte de rochas do Terreno Elevado no mapa; a área do Despertar como um bosque de
árvores sobre grama, com o Guarda secundário dentro (Defesa ×1,2 no log); painel do Avatar ("Passiva da Manifestação —
Domínio Natural / +1 alcance de feitiços.", "Conjurador — Escola Druídica", os quatro botões), a mira azul de Brotar
com alvo mais distante a 4 no log e o botão do segundo Avatar desabilitado; quatro Manifestações (slots 1/1/1/1 no log);
save/load com as 8 modificações e os 8 marcadores recriados idênticos. Confirmado pelo log do mesmo run: custo 2 para
entrar no Bosque, Restaurar removendo, Mercado construído sobre o Bosque e a modificação sumindo. **Ressalvas
honestas:** as notificações de debug (toasts de todas as pesquisas) cobrem o centro da tela em quase todas as capturas;
o Bosque sobre um tile que JÁ era Floresta/Selva no mapa gerado é visualmente quase igual à floresta base (é mais
legível sobre grama); o marcador da mira no tile de Bosque não foi capturado de perto.

## Assets (provisórios, nenhum criado/baixado)

Bosque = árvores KayKit (`Tree_1_A`, o mesmo das florestas do mapa); Terreno Elevado = primitivas (cilindro + esferas);
Círculo = moinho, Bosque Ancestral = torre A do KayKit; Druida = Mage do KayKit (escala 1,05, emblema "DR"); Avatar =
corpo procedural do Ent V1 (`visual_template = "treant"`, escala 1,7) — placeholder honesto, não há avatar natural nos
pacotes.

## Limitações e decisões a revisar

- **Passo Sombrio × terreno:** seguindo "preservar a semântica atual" (§16/§20), o INFILTRATOR ignora o delta como já
  ignorava o custo do terreno-base (o texto dele já dizia isso). Se a intenção do §98/§154 era que o Mestre das Sombras
  PAGASSE o custo do Bosque, a mudança é uma linha em `infiltrate_reachable` (trocar o custo plano por
  `terrain_step_cost`) — decisão sinalizada, não tomada por mim.
- **Regra do primeiro passo:** nova regra genérica de movimento, necessária para o §14; inerte na V1 hoje.
- Números provisórios; a IA não usa Druidismo; nenhum desenho no minimapa; o marcador do Bosque sobre floresta base é
  pouco distinto.

## Ainda propositalmente pendente

- Arcanismo N1–N9, teleporte, silêncio, dissipar e portais; Elementalismo N1–N9, clima e zonas ambientais.
- As outras 2 Grandes Manifestações; Transcendência funcional; Ritual Final; IA estratégica V2.
- Limpeza final V1→V2, bônus raciais, balanceamento definitivo e assets finais.

**Frase de encerramento:** o Druidismo V2 está funcional como manipulação física do campo de batalha: Druidas criam e
restauram modificações persistentes de terreno que alteram movimento e Defesa sem substituir o terreno-base do mapa, o
pathfinding e o combate consomem essa camada de forma genérica, e o Avatar da Natureza amplia o alcance dessa mesma
linguagem sem criar um runtime específico da Escola.

---

## Fase 21 — Arcanismo N1–N9, Teleporte, Silêncio, Dissipação e Portais

A quinta Escola de Magia está funcional de ponta a ponta e fecha **45/54 nós mágicos normais conectados**. Arcanismo é
a Escola de mobilidade e utilidade: deslocamento direto do próprio conjurador, interferência em feitiços V2 e um par de
Portais persistentes atravessado por uma ação explícita. Elementalismo N1–N9 e Transcendência permanecem inertes.

Antes da implementação foram auditados os sistemas existentes. A V1 já tinha `blink`, `silence` e uma região temporária
chamada `portal` em `MagicRuntime`; eles pertencem ao Grimório V1, usam ids/efeitos/regras próprias e não foram
reaproveitados nem alterados. A V2 já tinha o pool único de Mana, repertório derivado da pesquisa, recargas e estados em
`Unit.magic_cooldowns`/`magic_status`, duração por turno do dono, mira/ESC, voo tático, save de unidades e o slot de
Grande Manifestação por Escola. Esses fundamentos foram mantidos; a fase acrescentou apenas dados e extensões genéricas.

### Conteúdo canônico

| N | Conteúdo | Tipo | `unlock_id` | Gameplay |
|---|---|---|---|---|
| 1 | Escola do Arcanismo | school | `v2_magic_school_arcanism` | marco da Escola |
| 2 | Conclave Arcano | building | `v2_building_arcane_conclave` | prédio de treino |
| 3 | Arcanista | caster | `v2_unit_arcanist` | conjurador V2 |
| 4 | Passo Arcano | spell | `v2_spell_arcane_step` | teleporte próprio |
| 5 | Silêncio | spell | `v2_spell_silence` | bloqueio de feitiços V2 |
| 6 | Dissipar | spell | `v2_spell_dispel` | remove efeitos pela polaridade |
| 7 | Portal do Véu | spell | `v2_spell_veil_portal` | par persistente A/B |
| 8 | Torre do Véu | ritual_building | `v2_building_arcane_ritual` | prédio da Manifestação |
| 9 | Arconte do Véu | grand_manifestation | `v2_manifestation_veil_archon` | quinta Grande Manifestação |

Os ids de pesquisa continuam `v2_magic_arcanism_1` … `_9`; custos, papéis e pré-requisitos lineares continuam os do
runtime estrutural (`10, 20, 30, 50, 80, 120, 180, 270, 400`). Todos os nove nós são canônicos,
`gameplay_connected = true` e `is_placeholder = false`. `V2MagicContent.CONNECTED_UNLOCK_IDS` tem 45 entradas; os nove
nós de Elementalismo continuam desconectados e `v2_transcendence` continua sem efeito.

### Definições (**BALANCE PLACEHOLDER**)

| Conteúdo | Vida | Ataque | Defesa | Mov. | Visão | PP | Mana de produção | Suprimentos |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Arcanista | 10 | 0 | 1,5 | 2 | 4 | 24 | 0 | 2 |
| Arconte do Véu | 34 | 0 | 5,5 | 4 | 5 | 105 | 70 | 0 |

Ambos não têm ataque básico nem revide. O Arcanista é terrestre, `caster`, tem `v2_magic_school = "arcanism"` e
`magic_school = ""` (isolamento V1/V2). O Arconte é `caster + flying + grand_manifestation`, não é `legendary`,
`retinue` nem `undead`, e declara `spell_cooldown_reduction = 1` com a passiva **Fluxo do Véu**. Conclave: 24 PP,
upkeep 1 Ouro, único, não gera Mana, treina o Arcanista. Torre: 60 PP, upkeep 2, única, exige o Conclave na mesma cidade
e só treina o Arconte. Déficit, slots, fila, bateria de Mana, save e gates usam os sistemas já existentes.

| Feitiço | Mana | Alcance | Recarga | Regra principal |
|---|---:|---:|---:|---|
| Passo Arcano | 6 | 4 | 2 | move o próprio conjurador diretamente para tile visível, terrestre e livre |
| Silêncio | 8 | 3 | 3 | status harmful em conjurador V2 hostil até o próximo turno do dono |
| Dissipar | 7 | 3 | 2 | remove todos os efeitos elegíveis do tile em um único cast |
| Portal do Véu | 18 | 6 | 5 | liga a posição do conjurador a um endpoint escolhido |

O Arconte grava recargas efetivas `1 / 2 / 1 / 4`; redução nunca fica abaixo de zero e não recalcula uma recarga antiga.
Todos os casts gastam Mana uma vez, consomem a ação, zeram movimento e cancelam Fortificar/Explorar/marcha somente após
validação completa. ESC e clique inválido não alteram nada.

## Reutilizado sem alteração

- `V2ResearchState`, `V2UnlockSystem`, a fila única de pesquisa, save dos ids e o conteúdo estrutural N1–N9.
- `PlayerData.mana`, economia Arcana, déficit/upkeep, Suprimentos/Tensão Logística e a fila comum de cidade.
- Repertório derivado de `v2_magic_school + pesquisa`, `magic_cooldowns`, `magic_status`, `V2OwnerTurnEffect`, mira da
  `SelectionManager`, cancelamento por ESC e persistência de unidade do `SaveManager`.
- `HexGrid.teleport_unit` para deslocamento direto; Passo e travessia não criam uma rota, não pagam custo intermediário
  e não capturam cidade. `unit_destination_reason` mantém pouso terrestre, ocupação e cidade hostil como fonte única.
- `V2ManifestationSystem`: um slot ativo ou em produção **por Escola**. As cinco Manifestações coexistem e um segundo
  Arconte é bloqueado/fail-closed; o slot militar de `V2LegendarySystem` é independente.
- Movimento GROUND/FLYING, neblina, marcadores, inspetor, HUD e modelos provisórios existentes.

## Generalizado

`V2SpellData` ganhou propriedades inertes por padrão: teleporte do conjurador, exigência de alvo conjurador V2,
polaridade/dispellable, gate de Silêncio, Dissipar no tile e criação de par de Portal. `UnitData` ganhou redução de
recarga de feitiço por dado. `V2MagicRuntime` ganhou `effective_cooldown`, o gate central de Silêncio, resolução de
teleporte/Dissipar/Portal e consultas de status dissipável. Nenhuma função contém id ou nome do Arcanismo.

`HexGrid` ganhou uma consulta genérica de destino de unidade, armazenamento/índices/marcadores de Portal e limpeza nos
eventos de construção/fundação; `V2ConstructorRuntime` fecha o par quando uma melhoria de recurso realmente é concluída.
`SelectionManager`, HUD e `TileInspector` só consomem as APIs genéricas (mira e botão **Atravessar Portal**).

Arquivos criados nesta fase: `scripts/core/V2PortalSystem.gd` e quatro scripts de teste
(`test_v2_arcanism`, `test_v2_portal_system`, `test_v2_arcanism_hud`, `test_v2_phase21_main_flow`). Principais arquivos
alterados: `V2MagicContent`, `V2SpellData`, `V2SpellDatabase`, `V2MagicRuntime`, `V2ResearchDatabase`, `UnitData`,
`UnitDatabase`, `BuildingDatabase`, `HexGrid`, `V2ConstructorRuntime`, `SelectionManager`, `HUD`, `TileInspector` e
`SaveManager`, além das expectativas históricas de conteúdo conectado.

## Novo fundamento de interferência mágica

`V2SpellData.StatusPolarity` define `NONE`, `BENEFICIAL` e `HARMFUL`; `status_dispellable` é uma decisão separada.
Defaults são `NONE/false`. **Égide Sagrada** e **Comando Macabro** são `BENEFICIAL/true`; **Silêncio** é
`HARMFUL/true`. Uma Technique Militar não resolve para `V2SpellData`, portanto nunca vira status mágico dissipável
mesmo que compartilhe o dicionário histórico `magic_status`.

Silêncio usa um único gate em `V2MagicRuntime.unavailable_reason`, antes de Mana/alvo: qualquer conjurador das cinco
Escolas V2 e qualquer Grande Manifestação fica impedido de lançar feitiços V2. Movimento, ataque/técnica quando a
unidade possuir, ações comuns e travessia de Portal continuam; conjuradores e feitiços V1 não consultam esse gate.
Reaplicar renova a duração sem empilhar, e `V2OwnerTurnEffect` encerra o estado no início do próximo turno do dono.

Dissipar consulta a polaridade em tempo real:

- na própria unidade remove **todos** os `HARMFUL + dispellable`;
- numa unidade realmente hostil remove **todos** os `BENEFICIAL + dispellable`;
- no endpoint de qualquer Portal visível fecha o par completo;
- unidade e endpoint no mesmo tile são resolvidos pelo mesmo cast e custo;
- efeito inexistente torna o cast inválido, sem Mana, recarga ou ação;
- efeitos benéficos próprios, harmful hostis, Techniques, terreno Druídico, terreno-base e status V1 ficam intactos.

O caminho rápido de Silêncio com `magic_status` vazio mediu **0,49 µs**; com o status ativo, **2,35 µs**. Consultar
Dissipar sobre três estados (dois mágicos elegíveis + uma Technique) mediu **9,20 µs**. São consultas sob demanda na
UI/cast, sem `_process`, timer ou varredura de mapa.

## Novo fundamento de Portais

`V2PortalSystem` guarda o estado canônico global no próprio `HexGrid.v2_portal_pairs`: `owner_index` estável na ordem de
`GameManager.players`, `school` e endpoints `a/b`. Há no máximo **um par por civilização/Escola**. Dicionários
transitórios indexam `owner+school` e coordenada; criar/substituir valida o novo par inteiro antes de remover o antigo.
Falha é transacional. Endpoints de donos/Escolas diferentes não podem ocupar o mesmo tile.

O endpoint A é a posição do conjurador e pode estar numa cidade própria. B exige tile visível, terrestre, livre de
unidade/cidade/prédio/melhoria/covil; recurso bruto, território inimigo e modificação Druídica são permitidos. Os dois
ganham anéis arcanos próprios no mapa, sujeitos à neblina normal; o Portal não revela nem mantém visão.

Travessia é uma ação explícita de qualquer unidade do mesmo dono parada em A ou B: exige ordens, movimento > 0 e saída
visível; custa zero Mana, não altera recargas, zera o movimento e cancela marcha/Explorar. Tenta primeiro o endpoint
exato e depois os seis vizinhos na ordem canônica do `HexGrid`; nunca empilha. Com saída e seis vizinhos inválidos fica
bloqueada sem mover. Unidades de outra civilização não usam o par; retinues sem comando não usam; Silêncio não impede.
Chegar por Portal nunca captura cidade.

Portal **não é aresta do A\***, não participa de `compute_path`, `compute_reachable`, ordens automáticas ou IA. Construir
um prédio, concluir uma melhoria ou fundar cidade em endpoint fecha A+B; falha de construção não fecha. Captura/anexação
preservam o par. Dissipar em qualquer endpoint fecha ambos; Restaurar Terreno não. O bloco opcional global
`v2_portal_pairs` foi acrescentado ao save **sem bump de `SAVE_VERSION` (21)**. O load recria índices/marcadores depois
de jogadores/cidades/prédios e ignora owner/Escola/coordenada inválidos, endpoints iguais e duplicatas sem falhar; save
antigo carrega com zero pares.

Benchmark headless: `target_tiles` do Portal em alcance 6 = **1,195 ms**; lookup de endpoint = **1,02 µs**; endpoint
pareado = **1,44 µs**; escolha de landing = **11,57 µs**. A mesma rota longa de teste ficou em **1,493 ms sem Portal**
e **1,495 ms com Portal** (diferença de ruído, ~0,1%); o watchpoint da Fase 20 permanece 0,51 ms sem modificação e
3,82 ms quando a rota inteira paga terreno modificado. Como Portal não mudou materialmente pathfinding, a seção 2.8 do
`PERFORMANCE_GUIDE` não foi alterada.

## Específico do Arcanismo

O conteúdo específico se limita a **9 registros canônicos**, **2 prédios**, Arcanista, Arconte, **4 registros de
feitiço** e `spell_cooldown_reduction = 1` no dado do Arconte. Não existe `ArcanismRuntime`, `TeleportPathfinder`, prédio
Portal, HP/upkeep/Suprimentos de Portal, travessia automática, cadeia de Portais, blink de outra unidade, swap,
counterspell reativo ou resistência mágica.

Assets provisórios: Conclave e Torre reutilizam construções KayKit; Arcanista/Arconte reutilizam modelos de conjurador
já presentes, com emblema **AR** e escala/cor distintas; endpoints usam primitivas emissivas. Nenhum asset foi criado ou
baixado e nenhum asset V1 foi alterado.

## Integrações entre Escolas

- **Sagrada:** Dissipar remove Égide de inimigo; curas e a fórmula física da Égide continuam iguais.
- **Infernal:** Bruxo/Arquidemônio silenciados não lançam feitiços V2; após expirar, o dano mágico volta pelo pipeline
  normal, sem alteração na fórmula.
- **Necromancia:** Dissipar remove Comando Macabro hostil, mas não dissolve Hoste nem altera comando/capacidade; Hoste
  comandada atravessa Portal, sem comando é recusada e volta a atravessar quando a capacidade retorna.
- **Druidismo:** Passo e Portal ignoram custo de Bosque/Terreno Elevado no deslocamento direto, mas a unidade recebe a
  Defesa da modificação ao chegar. Portal e modificação coexistem; Dissipar remove só Portal, Restaurar remove só terreno.
- **Cinco Manifestações:** Serafim, Arquidemônio, Lich Soberano, Avatar da Natureza e Arconte do Véu coexistem, um slot
  por Escola. Todas passam pelo mesmo gate de Silêncio.

## Compatibilidade transitória V1

`MagicRuntime` V1 continua com `blink`, `silence`, região `portal`, `magic_school`, Grimório e rituais próprios. Silêncio
V2 não bloqueia feitiço/ritual V1; Dissipar V2 não apaga status/região V1; Portal V2 não usa a âncora/região temporária
V1. O compartilhamento físico de `magic_cooldowns`/`magic_status` é apenas persistência: ids V2 namespaced e resolução
pelo banco impedem mistura sem criar um segundo bloco de save. Nenhuma Doutrina, Infraestrutura, vitória ou pesquisa V1
foi alterada pela fase.

### Testes

**31 testes novos em 4 scripts** (455 asserts da fase):

- `test_v2_arcanism` (14): conteúdo 45/54, dados exatos, quatro feitiços, teleporte direto e destinos inválidos,
  Silêncio/refresh/expiração/V1/travessia, dez tipos de conjurador V2 no gate, matriz completa de polaridade e Dissipar
  múltiplo, Terrain/Technique preservados, cooldown do Arconte, cinco Manifestações e anti-hardcode.
- `test_v2_portal_system` (11): criação/lookup/owner/Escola, substituição transacional, travessia bidirecional e landing,
  fog/espaço/comando, construção/melhoria/fundação/captura, recurso+Druidismo+território inimigo, save/load real com
  índices/marcadores, corrupt/legacy e igualdade exata de pathfinding com/sem Portal.
- `test_v2_arcanism_hud` (5): quatro botões/custos/tooltips, Silêncio público, travessia ainda disponível, motivo de fog,
  Fluxo do Véu/recargas reduzidas e inspetor dos endpoints.
- `test_v2_phase21_main_flow` (1, 104 asserts): partida e cidade reais, Conhecimento/Mana, Conclave/Arcanista pelas filas,
  mira+ESC+Passo, Silêncio/movimento/expiração, Dissipar benefício/harmful sem remover Technique, duas travessias sem
  stack, fog, Druidismo, save/load do par, Torre, bateria de 70 Mana, Arconte, save da recarga efetiva, cinco
  Manifestações, árvores anteriores e Transcendência inerte.

Suíte V2: **1.997 / 1.997** (106 scripts). Suíte completa: **3.602 / 3.602** (157 scripts).

### Validação visual (não-headless, `Main.tscn` real, 1920×1017, uma execução)

Executada com Vulkan Forward+ numa RTX 3060. Confirmados: aba Magia com as quatro Escolas anteriores intactas,
Arcanismo N1–N9 canônico/concluído e Elementalismo placeholder; Transcendência `1/2` bloqueada; Conclave e Torre no
mapa; anéis dos dois endpoints; Arcanista selecionado (`10/10`, Ataque 0, Defesa 1,5, Movimento 2, Suprimentos 2), estado
e ação pública de Silêncio, quatro botões com custos e **Atravessar Portal** ainda habilitado; Arconte (`34/34`, Ataque
0, Defesa 5,5, Movimento 4), voo tático, Fluxo do Véu e o mesmo repertório. Os marcadores ficaram distinguíveis sobre
Selva/grama e os painéis não estouraram a tela. Ressalvas honestas: os toasts dos nove unlocks cobriram o topo central;
os modelos/prédios são placeholders reutilizados; a execução visual preparou o estado por script depois de abrir a cena
real (filas/casts/save foram exercitados pelo fluxo automatizado, não repetidos manualmente na captura).

## Ainda propositalmente pendente

- Elementalismo N1–N9, clima, zonas ambientais e a sexta Grande Manifestação.
- Transcendência funcional, Ritual Final e qualquer vitória mágica V2.
- IA estratégica V2 (pesquisa, produção, escolha de feitiço, Portal e interferência).
- Limpeza final V1→V2, bônus raciais, balanceamento definitivo e assets finais.

**Frase de encerramento:** O Arcanismo V2 está funcional como Escola de mobilidade e utilidade: Arcanistas atravessam espaço sem transformar teleporte em pathfinding, Silêncio e Dissipar formam uma camada genérica de interferência sobre feitiços V2, e Portais persistentes conectam dois pontos por uma ação explícita de unidade, com contraplay por visibilidade, espaço, construção e dissipação, enquanto o Arconte do Véu acelera o repertório pelo mesmo runtime genérico.

---

## Fase 22 — Elementalismo N1–N9 e Zonas Ambientais

A **sexta e última Escola de Magia normal** foi implementada sobre o runtime comum. Elementalismo não reescreve
terreno, não cria clima global e não entra no pathfinding: ele acrescenta uma camada esparsa e temporária por tile,
capaz de alterar visão, ataque físico à distância e aplicar dano fixo no fechamento da rodada global.

```
N1 Escola do Elementalismo  v2_magic_elementalism_1  school               v2_magic_school_elementalism
N2 Observatório Elemental   v2_magic_elementalism_2  school_building      v2_building_elemental_observatory
N3 Elementalista            v2_magic_elementalism_3  caster               v2_unit_elementalist
N4 Névoa Cerrada            v2_magic_elementalism_4  spell                v2_spell_dense_mist
N5 Vendaval                 v2_magic_elementalism_5  spell                v2_spell_gale
N6 Tempestade Elétrica      v2_magic_elementalism_6  spell                v2_spell_lightning_storm
N7 Cataclismo Elemental     v2_magic_elementalism_7  spell                v2_spell_elemental_cataclysm
N8 Nexo dos Elementos       v2_magic_elementalism_8  ritual_building      v2_building_elemental_ritual
N9 Primordial dos Elementos v2_magic_elementalism_9  grand_manifestation  v2_manifestation_elemental_primordial
```

Os **54/54 nós mágicos normais** (seis Escolas × nove níveis) agora têm conteúdo canônico e
`gameplay_connected = true`. A **Transcendência** permanece estrutural, pesquisável quando duas Escolas chegam ao N9,
mas sem Ritual Final, efeito ou vitória.

### Auditoria do ciclo global

Antes da implementação foi auditado o caminho real do turno. A ação humana dispara o turno; cidades e pesquisas
são processadas; rivais e monstros agem de forma síncrona ou pela fila escalonada; os dois caminhos convergem uma
única vez em `GameManager._finish_turn()`. O tick ambiental foi colocado ali, **depois** de toda IA e monstro e
**antes** do único `recompute_fog` e da checagem de eventos/vitória. A ordem dentro do tick é fixa:

1. aplicar dano ambiental nas unidades presentes;
2. reduzir `remaining_rounds` uma vez em todas as zonas;
3. remover entradas que chegaram a zero;
4. atualizar somente os markers removidos;
5. deixar `_finish_turn()` recalcular a fog uma vez para o estado final.

Assim, uma zona de duração 2 causa dois ticks, inclusive no tick em que expira; processamento escalonado não a
duplica. Chamadas diretas do sistema fora do turno ainda atualizam a fog uma vez quando uma zona de visão expira.

## Reutilizado sem alteração

- `V2ResearchState`, `V2UnlockSystem`, produção de cidade, gates de prédio/conjurador e toasts recebem os nove
  registros pelos mesmos tipos mágicos das cinco Escolas anteriores.
- `V2MagicRuntime` continua sendo o único runtime de feitiços V2: mira TILE, alcance, visibilidade, Mana, ação,
  recarga, ESC e Silêncio não ganharam um caminho Elementalista paralelo.
- `V2ManifestationSystem` fornece o slot por Escola, a reserva pela fila, a cobrança de Mana na conclusão e o
  fail-closed. As seis Grandes Manifestações coexistem; um segundo Primordial não.
- terreno-base, `V2TerrainRuntime`, Portais, cidades, prédios, recursos e melhorias continuam donos dos seus estados.
  Construção, fundação, captura e anexação não limpam ambiente.
- a remoção canônica de unidade é usada quando o ambiente mata, preservando a derivação de retinues e slots,
  mas sem passar por registro de abate, XP, saque, recompensa ou crédito de evento.

## Generalizado

- `V2SpellData.environmental_zone_id`: uma extensão mínima de dado para qualquer feitiço TILE criar uma zona.
- `UnitData.environmental_zone_duration_bonus` e seu nome visível: qualquer unidade futura pode materializar zonas
  mais duradouras; não há checagem do id do Primordial.
- a fonte de visão de unidade em `HexGrid.compute_visible_tiles` consulta `effective_unit_vision`; cidade conserva
  exatamente sua visão anterior e o valor de unidade nunca cai abaixo de 1.
- `CombatResolver.predict` multiplica somente o componente de ataque físico de uma unidade com
  `attack_range > 1` pelo ambiente no **tile do atacante**. Melee, revide, feitiço, ataque de cidade e dano ambiental
  não passam por esse fator.
- Dissipar passou a reconhecer uma célula ambiental dissipável. Num mesmo cast remove todos os status elegíveis da
  unidade, a zona daquele tile e o par inteiro de Portal, mantendo terreno Druídico.
- save/load global ganhou o bloco opcional `v2_environmental_zones`, sem bump de `SAVE_VERSION` (21).

## Novo fundamento ambiental

Três arquivos genéricos formam o fundamento:

| Arquivo | Responsabilidade |
|---|---|
| `V2EnvironmentalZoneData.gd` | dado imutável: id/nome, duração, delta de visão, fator ranged, dano por rodada, dissipável e visual |
| `V2EnvironmentalZoneDatabase.gd` | registro/cache e texto derivado dos efeitos |
| `V2EnvironmentalZoneSystem.gd` | aplicação/remoção, consultas O(1), tick global, fog em batch e serialização robusta |

O estado canônico fica em `HexGrid.v2_environmental_zones`:

```text
Vector2i -> {zone_id, owner_index, school, remaining_rounds}
```

Existe **no máximo uma zona ambiental por tile**. Primary já ocupado torna o cast inválido; secondary ocupado é
apenas ignorado. O primary entra primeiro e a área segue a ordem canônica de `HexMetrics.coords_within`; para o
humano, secondaries ocultos também são ignorados. Qualquer terreno ou entidade pode estar sob clima: água,
montanha, cidade, prédio, unidade, recurso, melhoria, terreno Druídico e Portal continuam coexistindo no mesmo tile.

`owner_index` e `school` preservam autoria para inspeção e save, não imunidade. Os efeitos são **imparciais**:
atingem unidade própria, aliada, inimiga, monstro ou manifestação presente; continuam depois da morte do conjurador
ou eliminação da civilização. Cidade e prédio nunca recebem dano.

O tick percorre apenas as entradas esparsas e faz lookup O(1) do ocupante, nunca o mapa inteiro. Dano é fixo,
mágico-ambiental e sem defesa, terreno, Égide, resistência, `spell_damage_multiplier`, revide ou crédito. O marker é
um aro/disco emissivo baixo, estático, sem colisão nem `_process`, visível apenas sob fog atual e sem cobrir a unidade.

O save grava coordenada, id, owner, Escola e rodadas restantes. O load limpa a camada, aceita bloco ausente como vazio,
ignora registros/tipos/ids/owner/Escola/coordenada/duração inválidos, faz o primeiro registro válido vencer em
coordenada duplicada e recria markers depois das entidades. Efeitos derivados nunca são persistidos.

### Registros ambientais

| Zona | Duração-base | Visão de unidade | Ataque físico ranged | Dano/rodada |
|---|---:|---:|---:|---:|
| Névoa Cerrada | 2 | −2 (mínimo 1) | ×1,00 | 0 |
| Vendaval | 2 | 0 | ×0,70 | 0 |
| Tempestade Elétrica | 2 | 0 | ×1,00 | 4 |
| Cataclismo Elemental | 2 | −1 (mínimo 1) | ×0,80 | 5 |

Névoa/Cataclismo recalculam fog imediatamente ao entrar, sair ou serem dissipados quando afetam uma unidade humana;
áreas e expirações coalescem em um refresh. Vendaval não reduz alcance e Cataclismo não espalha, transforma,
destrói ou remove nada de outras camadas.

## Específico do Elementalismo

O código específico se limita a **9 registros de conteúdo, 2 prédios, 2 unidades, 4 feitiços, 4 zonas** e ao
bônus genérico de duração no dado do Primordial. Não existe `ElementalismRuntime`, weather em `magic_status`,
`WeatherPathfinder`, elemento/resistência, imunidade, spread, aleatoriedade, knockback, freeze ou stun.

- **Observatório Elemental:** prédio mágico único, 24 PP, 1 Ouro/turno, sem Mana passiva; treina Elementalista.
- **Elementalista:** 11 HP, Ataque 0, Defesa 1,5, Movimento 2, Visão 4, 24 PP, 2 Suprimentos, terrestre, caster V2 de
  Elementalismo, sem ataque básico e sem `magic_school` V1.
- **Névoa Cerrada:** 6 Mana, alcance 4, recarga 2, raio 1; cria Névoa sem dano imediato.
- **Vendaval:** 8 Mana, alcance 4, recarga 2, raio 1; penaliza ataques ranged originados na área.
- **Tempestade Elétrica:** 12 Mana, alcance 4, recarga 3, raio 1; dano 4 nos dois fechamentos de rodada.
- **Cataclismo Elemental:** 20 Mana, alcance 5, recarga 5, raio 2; até 19 células válidas, efeitos compostos.
- **Nexo dos Elementos:** estrutura ritual única, 60 PP, 2 Ouro/turno, exige Observatório na mesma cidade; produz
  apenas o Primordial.
- **Primordial dos Elementos:** 40 HP, Ataque 0, Defesa 6,5, Movimento 4, Visão 5, 110 PP + 75 Mana na conclusão,
  0 Suprimentos, voador, caster e Grande Manifestação, sem ataque básico. **Coração Elemental** acrescenta +1
  rodada somente às zonas que ele próprio cria; duração é materializada na entrada, portanto zona existente não
  muda e a morte posterior do Primordial não a encurta.

Mana é cobrada uma vez por cast, independentemente do número de secondaries aceitos; área sem secondaries ainda
consome normalmente porque o primary garantiu validade. Todas as quatro magias gastam a ação, iniciam recarga e
respeitam Silêncio pelo mesmo pipeline.

## Integrações entre as seis Escolas

- **Sagrada:** Égide não mitiga o dano fixo ambiental; cura recupera normalmente a unidade depois do tick.
- **Infernal:** `spell_damage_multiplier` não amplifica clima e feitiços Infernais não sofrem Vendaval.
- **Necromancia:** Hostes e comandantes sofrem clima imparcialmente; se um comandante morre no tick, capacidade e
  estado sem comando são rederivados pelo sistema existente, sem crédito de abate.
- **Druidismo:** Bosque/Terreno Elevado e ambiente coexistem. Restaurar Terreno remove apenas a modificação física;
  construir/fundar também não remove clima.
- **Arcanismo:** Dissipar remove a célula ambiental e, no mesmo cast, Portal/status elegível; terreno Druídico fica.
  Portal e ambiente coexistem, mas Névoa pode tirar da visão a saída e bloquear a travessia até ela voltar a ser vista.
- **Elementalismo:** fornece as zonas temporárias e o Primordial amplia a duração por dado.

As **seis Grandes Manifestações** ocupam slots independentes por Escola e podem coexistir na mesma civilização.
Todas são unidades: voadoras ou terrestres, próprias ou rivais, sofrem Tempestade/Cataclismo sem imunidade elemental.

## Compatibilidade transitória V1

Clima V2 não altera terreno-base, `MagicRuntime`, regiões/rituais V1, `magic_school`, Grimório, IA mágica V1,
pathfinding, custo de movimento ou ataque de cidade. `UnitData.magic_school` do Elementalista/Primordial continua vazio;
a classificação V2 usa `v2_magic_school` e o traço `caster`. Saves antigos não têm o bloco ambiental e carregam com
a camada vazia. Nenhuma Doutrina ou Infraestrutura ganhou dependência ambiental.

### Testes

**28 testes novos/adicionados em 4 scripts**, além das adaptações de contratos históricos:

- `test_v2_elementalism` (22, 326 asserts): conteúdo/dados, zonas/uma por tile/qualquer terreno, primary e secondaries,
  duração/tick/dano/friendly fire/morte sem crédito, visão/fog, Vendaval em toda a matriz física, quatro feitiços,
  coexistência com terreno/Portal/cidade/prédio, Dissipar múltiplo, prédios/unidades/slots e anti-hardcode.
- `test_v2_elementalism_hud` (3, 30 asserts): quatro botões/custos/recargas, linhas ambientais e Coração Elemental,
  mais TileInspector com efeitos, duração e criador.
- `test_v2_phase22_main_flow` (1, 151 asserts): partida/cidade/filas reais, N1–N9, mira+ESC, fog, rodada global,
  Vendaval, Tempestade, Cataclismo, Grove+Portal+Dissipar, Nexo/Primordial, seis Manifestações, save/load e
  Transcendência pesquisada sem vitória.
- `test_save_manager` (+2): round-trip ambiental por owner/Escola/duração/marker e save legado sem bloco.

Suíte completa: **3.630 / 3.630** (160 scripts; 368.345 asserts).

### Performance

Medição headless (Godot 4.7.1, mapa de benchmark): lookup vazio **1,22 µs**, ocupado **2,27 µs**; visão efetiva
sem zona **2,43 µs**, com Névoa **3,45 µs**; fator ranged sem zona **2,39 µs**, com Vendaval **3,40 µs**.
Tick: 0 zonas **1,46 µs**, 50 sem ocupantes **134,72 µs**, 100 **293,44 µs**, 50 zonas/50 unidades
**976,28 µs**. Mira TILE: alcance 4 **337,05 µs**, alcance 5 **455,18 µs**. Aplicar + fog: Névoa raio 1
**1,64 ms**, Cataclismo raio 2 **4,06 ms**; Dissipar uma célula **349,13 µs**; restaurar 100 markers no load
**19,66 ms**; rodada completa com três rivais **28,05 ms**.

A mesma rota mediu **700,89 µs sem zonas** e **700,03 µs com 100 zonas**: diferença de ruído e nenhuma consulta
ambiental vazando no pathfinding. Como os custos novos são eventos raros/esparsos, sem impacto material nos caminhos
persistentes documentados, `PERFORMANCE_GUIDE` não ganhou uma seção meramente nominal.

### Validação visual (não-headless, `Main.tscn` real, 1920×1017, uma execução final)

Executada com Vulkan Forward+ numa RTX 3060. A captura do mapa confirmou os quatro markers ambientais baixos e
distintos no mesmo recorte, com Bosque Denso e um par de Portal coexistindo nas mesmas coordenadas; Elementalista e
Primordial materializados; e o painel real do Primordial mostrando `40/40`, Ataque 0, Defesa 6,5, Movimento 4,
Escola de Elementalismo, quatro feitiços e **Coração Elemental — +1 rodada** sem estourar a tela. O marker deixa o
terreno e as unidades legíveis e não adicionou colisão visual.

A segunda captura confirmou a aba **Magia** inteira: seis linhas canônicas, 54 cards normais mais Transcendência,
Elementalismo N1–N9 concluído com `Observatório Elemental`, `Elementalista`, `Névoa Cerrada`, `Vendaval`,
`Tempestade Elétrica`, `Cataclismo Elemental`, `Nexo dos Elementos` e `Primordial dos Elementos`, sem nenhum rótulo
placeholder. A Transcendência apareceu bloqueada e inerte; as outras cinco Escolas permaneceram intactas.

Ressalvas honestas: os nove toasts de unlock ficaram sobre o topo central da captura do mapa; assets continuam
reaproveitados e os markers são representação funcional, não efeitos climáticos finais. O estado foi preparado por
roteiro depois de abrir a cena real; filas, casts, ticks, dissipação e save/load foram exercitados pelo fluxo
automatizado, não repetidos manualmente na captura. Antes da execução final houve duas tentativas descartadas do
roteiro: a primeira abortou no parse antes de instanciar a cena porque `--script` não carregava autoloads; a segunda
parou antes das capturas por coordenadas de teste inadequadas. Nenhuma delas gerou evidência visual usada aqui.

## Ainda propositalmente pendente

- Transcendência funcional, requisito de duas Manifestações reais, Ritual Final e vitória mágica V2.
- IA estratégica V2: pesquisa, construção, produção e escolha/posicionamento de feitiços ambientais.
- limpeza final V1→V2, bônus raciais, balanceamento definitivo e assets finais.
- não existem clima global, spread, elementos/resistências, imunidade, tempestade sobre cidade/prédio, animação
  dedicada ou alteração de pathfinding.

**Frase de encerramento:** O Elementalismo V2 está funcional como controle ambiental temporário: zonas locais de Névoa, Vendaval, Tempestade e Cataclismo alteram visão, combate à distância e risco por rodada sem reescrever terreno ou pathfinding; a camada ambiental coexiste com Druidismo e Portais, é dissipável pelo Arcanismo e persiste por duração própria, enquanto o Primordial dos Elementos amplia genericamente sua permanência. As seis Escolas N1–N9 e os 54 nós mágicos normais estão agora funcionalmente completos, permanecendo somente a Transcendência fora do gameplay.

---

## Fase 23 — Transcendência, Ritual Final e Vitória Mágica V2

A Transcendência deixou de ser o último placeholder da árvore. O capstone agora concede acesso real à via de
vitória mágica V2; uma civilização com esse acesso, duas Grandes Manifestações ativas de Escolas distintas e uma
Estrutura Ritual N8 física e pesquisada pode pagar **120 Mana** para iniciar, em uma cidade própria, um Ritual Final
público de **quatro rodadas globais**. O ritual não usa produção, pode coexistir com a produção da cidade e só vence
se todos os seus requisitos ainda forem verdadeiros quando o contador chegar a zero.

### Reutilizado sem alteração

- `V2ResearchState` continua sendo a fonte única da conclusão do capstone. A regra estrutural existente continua
  exigindo N9 em **duas Escolas distintas**, o progresso continua saturado em `2 / 2` e o custo segue em 600
  Conhecimento.
- `V2UnlockSystem` aplica o acesso pelo mesmo mecanismo derivado dos demais unlocks. Nenhum segundo booleano de
  acesso foi criado e resetar a pesquisa o remove imediatamente.
- os seis N8 permanecem `BuildingData` comuns e as seis Grandes Manifestações permanecem unidades comuns com slot
  próprio por Escola no `V2ManifestationSystem`. Produção reservada não conta como manifestação ativa.
- o save de jogadores, cidades, prédios, unidades, produção, fog, zonas ambientais, Portais e pesquisas não mudou.
  `SAVE_VERSION` permanece 21.
- `GameManager.check_victories()` segue como autoridade única. Dominação e todas as vitórias V1/V1.5 conservam sua
  precedência; Supremacia Militar V2 continua sendo verificada antes da nova Transcendência V2.

### Generalizado

- `V2ManifestationSystem` ganhou consultas derivadas para as **Escolas distintas** representadas por Grandes
  Manifestações vivas do jogador. Unidade morta/removida, item em produção, caster comum e Lendária Militar nunca
  contam; duas unidades da mesma Escola contam uma vez.
- `V2VictoryConditions` agora expõe `transcendence_status`, `transcendence_lines` e
  `transcendence_achieved`, mantendo as duas vitórias V2 sob a mesma interface.
- `HexGrid` hospeda markers públicos por índice estável de civilização e chama a validação canônica quando uma
  cidade muda de dono ou uma unidade é removida. Não existe busca por nome/id de Escola ou Manifestação.
- o HUD de cidade deriva a elegibilidade a partir dos N8 reais do banco; o quadro de pesquisa e o painel de
  vitórias apenas formatam o estado fornecido pelos runtimes.

### Capstone de Transcendência conectado

| Campo | Valor |
|---|---|
| Research id | `v2_transcendence` |
| Unlock id | `v2_transcendence_access` |
| Tipo | `victory_capstone` |
| Requisito | N9 completo em 2 Escolas distintas |
| Custo | 600 Conhecimento |
| `gameplay_connected` | `true` |

O acesso é `player.has_unlocked("v2_transcendence_access")`, portanto é inteiramente derivado da pesquisa. O tooltip
explica o Ritual Final, as duas Manifestações, a Estrutura Ritual, os 120 Mana e as quatro rodadas; o toast usa o
anúncio genérico de capstone. Pesquisar duas Escolas ou o capstone, por si só, **não vence** e não inicia nada.

### Novo fundamento do Ritual Final

`V2TranscendenceSystem` é um `RefCounted` estático e genérico. Cada `PlayerData` possui no máximo um dicionário
`v2_transcendence_ritual`; vazio significa nenhum ritual:

```text
site_coord          coordenada da cidade ritual
remaining_rounds    4..1 no save; 0 apenas entre o tick final e check_victories
last_progress_turn  guarda de idempotência do tick global
```

O início é transacional e exige, nesta ordem: partida ainda ativa, civilização major não eliminada, acesso,
nenhum ritual já ativo, cidade válida e própria, ao menos um N8 físico **e pesquisado** na própria cidade, duas
Grandes Manifestações vivas de Escolas distintas e 120 Mana. Falhar não muda Mana, fila ou estado. Sucesso cobra a
Mana **uma única vez**, cria o estado/marker, emite o evento público e deixa a fila de produção intacta. Ouro,
déficit, unidade guarnecida e produção da cidade não são recursos do ritual.

`GameManager._finish_turn()` preserva uma ordem explícita: toda IA e monstros agem; efeitos de dono expiram; zonas
ambientais causam dano e expiram; o Ritual Final valida e avança; a fog é recalculada; eventos do mundo avançam; e
só então as vitórias são verificadas. Assim, uma Manifestação morta pela Tempestade/Cataclismo interrompe o ritual
antes de um possível último tick. `last_progress_turn` impede avanço duplo por chamadas repetidas ou por load no
mesmo turno.

Várias civilizações podem canalizar simultaneamente, mas cada uma mantém somente uma tentativa. O estado público
expõe dono, coordenada e rodadas restantes. Um marker procedural violeta/rosa (anel, feixe e orbe; sem asset novo,
colisão ou `_process`) permanece visível mesmo sob tile `UNSEEN`, sem mudar a matriz de visibilidade, revelar terreno,
cidade, tropas ou área ao redor. O painel de vitórias mostra também o countdown rival.

O bloco raiz opcional do save é:

```text
v2_transcendence_rituals: [
  {owner_index, site: [q, r], remaining_rounds, last_progress_turn}
]
```

Ele é restaurado **depois** de cidades, prédios e unidades. Bloco ausente vira vazio. Tipos errados, número não
inteiro/NaN/INF, dono/coordenada/contador/turno inválido, duplicata por dono ou requisito mundial não satisfeito são
ignorados silenciosamente; nenhuma falsa interrupção é anunciada. O primeiro registro íntegro por dono vence e o
marker é reconstruído. Estado `remaining_rounds = 0` não é persistido: zero só produz vitória no pipeline do mesmo
tick e apenas se os requisitos continuarem válidos.

### Vitória V2 conectada

O id de resultado é `v2_transcendence`. Quando o quarto tick válido deixa `remaining_rounds == 0`,
`V2VictoryConditions.transcendence_achieved` ainda revalida acesso, cidade/estrutura e Manifestações; então o
`GameManager` encerra a partida pelo pipeline normal (`_end_game`, `victory_achieved`, snapshot e tela final). O HUD
possui título e resumo próprios para a vitória e nunca confunde o resultado com a Transcendência V1/V1.5.

### Interrupções e contraplay

Interrompem e zeram integralmente a tentativa: cair abaixo de duas Manifestações distintas ativas; perder/capturar a
cidade ritual; perder a Estrutura Ritual utilizável; perder o acesso por reset; eliminação; ou cancelamento manual na
própria cidade-sede. A Mana não é devolvida, não existe pausa e reconstruir o requisito exige novo pagamento e quatro
rodadas completas. Perder uma de três Manifestações e ainda manter duas não interrompe.

**Silêncio não interrompe**, pois Manifestação ativa é uma unidade viva, não a capacidade atual de conjurar.
**Dissipar não remove** o ritual nem seu marker. Clima interfere apenas indiretamente ao matar uma Manifestação;
terreno Druídico e Portais coexistem sem interação especial. O contraplay territorial é conquistar a cidade ritual;
recapturá-la não restaura uma tentativa antiga.

### Compatibilidade transitória V1

O Ritual Final V2 não lê nem escreve `arcane_ritual_active`, `arcane_ritual_streak`, `arcane_ritual_city_coord`,
`researched_magic`, rituais V1, Grimório ou as condições de Transcendência V1/V1.5. O id, acesso, estado, custo e
contador são namespaced. A precedência de Dominação/V1/V1.5 e da Supremacia Militar V2 foi preservada e coberta por
testes; concluir Escolas, manter Manifestações ou pesquisar o capstone sem executar o Ritual Final nunca vence.

### Estado das três árvores V2

| Árvore | Conectados |
|---|---:|
| Doutrinas Militares | **55 / 55** |
| Escolas de Magia | **55 / 55** |
| Infraestrutura | **18 / 18** |
| **Total** | **128 / 128 `gameplay_connected`** |

### Testes

**39 testes adicionados nesta fase**, além das adaptações de contratos históricos:

- `test_v2_transcendence_system` (29, 264 asserts): capstone/acesso, contagem distinta e viva, N8 utilizável, todos
  os gates e motivos, cobrança/estado público/marker/fog, fila independente, tick idempotente, interrupções, duas
  civilizações, eventos, ordem ambiental, save corrompido, vitória/precedência/V1 e anti-hardcode.
- `test_v2_phase23_main_flow` (1, 71 asserts): jogo/cidade/prédios/produção reais, Serafim + Arquidemônio, início,
  interrupção por morte, reinício, quatro rodadas, save/load e tela de vitória pelo caminho normal.
- `test_save_manager` (+4): round-trip/marker/guarda de turno, legado sem bloco, corrupção descartada e retomada do
  último tick.
- `test_hud` (+5): gates e motivos, início/countdown/cancelamento privado, informação rival pública sem pesquisa,
  cidade rival sem ações privadas e tela final.

Suíte completa: **3.669 / 3.669** (162 scripts; 368.820 asserts).

### Performance

Benchmark headless (Godot 4.7.1): `has_access` **21,71 µs**; contar 2 de 6 Manifestações **4,96 µs**; verificar
estrutura ritual **40,15 µs**; `can_start` pronto **75,01 µs**; tick com 0 rituais **2,68 µs**; consulta pública com
1 ritual **6,43 µs**; tick com 1 **81,30 µs**; consulta pública com 4 **18,08 µs**; tick com 4 **316,35 µs**;
restaurar 4 markers **2,25 ms**. `check_victories` mediu **170,76 µs** antes e **843,46 µs** no fechamento da
vitória. A comparação de pathfinding com/sem ritual foi exatamente igual. É um sistema esparso e dirigido por
eventos, sem timer, polling ou varredura do mapa; por isso `PERFORMANCE_GUIDE.md` não ganhou seção nominal.

### Validação visual (não-headless, `Main.tscn` real, 1920×1017, uma execução final)

Executada com Vulkan Forward+ numa RTX 3060. Foram confirmados: quadro real com 55 cards de Magia, duas Escolas
completas e Transcendência `2 / 2`; tooltip canônico com Ritual Final/120 Mana; Catedral Sagrada física; Serafim e
Arquidemônio vivos; botão elegível; cobrança 500→380; countdown 4; marker público permanecendo visível com o tile
forçado para `UNSEEN` sem alterar a fog; avanço para 3; interrupção ao remover o Serafim sem reembolso e com remoção
do marker; reconstrução/reinício; quatro rodadas; e painel final real com título/resumo da Transcendência V2. Os
painéis não cortaram texto nem se sobrepuseram funcionalmente.

Ressalvas: o marker é geometria procedural provisória e pode competir visualmente com modelos no mesmo tile; os
toasts ficaram empilhados porque o roteiro completou 18 pesquisas de uma vez, situação artificial. Prédios e
Manifestações continuam usando os assets provisórios das Escolas; nenhum asset novo foi criado.

### Ainda propositalmente pendente

- IA estratégica V2 e IA pesquisando as três árvores.
- IA montando composição, produzindo infraestrutura e usando magia.
- IA reagindo estrategicamente a Ritual Final e Supremacia Militar.
- limpeza final V1→V2 e remoção da convivência transitória.
- UX/UI cleanup, bônus raciais, balanceamento definitivo e assets finais.
- auditoria final de release.

**Frase de encerramento:** A Transcendência V2 está funcional como uma verdadeira via de vitória: duas Escolas completas liberam o capstone, duas Grandes Manifestações ativas e uma Estrutura Ritual permitem iniciar um Ritual Final público de quatro rodadas por 120 Mana, e adversários podem interrompê-lo conquistando a cidade ritual ou reduzindo as Manifestações abaixo do requisito. Com sua conclusão, a Vitória por Transcendência é concedida pelo pipeline normal de vitórias. Doutrinas, Magia e Infraestrutura agora totalizam 128/128 pesquisas V2 funcionalmente conectadas.

---

## Fase 24 — IA V2 Completa: estratégia, economia, pesquisa, combate e vitórias

A IA dos rivais major passou a jogar pelo runtime V2. Cada rival recebe uma orientação estável, pesquisa pelo slot
único, administra a economia e as cidades, monta uma força por papéis, produz/evolui unidades, usa Técnicas e Magia
e persegue ou contesta as duas vitórias V2. Não existe bônus de recurso, pesquisa instantânea, produção paralela ou
leitura do estado privado do adversário.

### Reutilizado sem alteração

- `RivalAI` continua sendo o executor do turno no mapa: fog, campanhas, diplomacia, paz/comércio, colonizadores,
  combate comum, exploração, defesa local, eventos do mundo e processamento escalonado por unidade.
- pesquisa, cidade, produção, upgrade, Construtor, anexação, recursos, Técnicas, feitiços, Portais,
  Manifestações, Lendárias, Ritual Final e vitórias continuam validados pelos mesmos runtimes usados pelo humano.
- `GameManager` mantém a ordem de turno, economia, conclusão de filas, efeitos globais e verificação de vitória.
  A IA só escolhe; nunca escreve o resultado final de uma regra.
- `StrategicAI` permanece disponível para a estratégia legada e seus helpers neutros. Não foi reescrito nem
  removido nesta fase.

### Isolamento da estratégia V1

Para rivais V2, `GameManager` chama `V2StrategicAI.plan_turn` e desliga exatamente os decisores V1 que competiriam
pelo mesmo estado: `RivalAI.decide_production`, `RivalAI.decide_research`, `StrategicAI.cast_spells` e
`RivalAI.decide_arcane_ritual`. Diplomacia, campanhas, comércio, eventos e execução física de `RivalAI` permanecem.
O humano nunca satisfaz `V2StrategicAI.is_enabled_for` e segue 100% manual. Testes preservam também os campos V1
`current_research`, `research_progress`, `researched_*` e o Ritual Arcano legado.

### Novo fundamento da IA V2

| Peça | Responsabilidade |
|---|---|
| `V2AITuning` | pesos centralizados e explicitamente provisórios; nenhum custo/regra do jogo |
| `V2AIStrategyState` | personalidade e memória mínima persistente por rival |
| `V2AIWorldView` | fronteira única de informação inimiga observável/pública |
| `V2StrategicAI` | pesquisa, economia, filas, upgrades, expansão e objetivos de vitória |
| `V2AITacticalAI` | Técnica, magia, Portal, Construtor e movimento especial antes da ação comum |

As fundações não contêm ids concretos de Doutrina, Escola, unidade, prédio, Técnica ou feitiço. Escolhas vêm de
metadata (`tree_type`, `branch_role`, `tier_role`, traços, papéis, efeitos do dado e bancos existentes). Não há
`_process`, timer ou polling: uma revisão estratégica por turno e uma tentativa tática quando cada unidade age.

### Informação e anti-omniscience

`V2AIWorldView.capture` contém unidades inimigas atualmente visíveis e não ocultas, cidades vistas/lembradas apenas
como objetivos territoriais, cidades próprias qualificadas perdidas e Rituais públicos. Não expõe Ouro, Mana,
Conhecimento, pesquisa, fila, recarga ou composição escondida do rival. Nível de cidade só especializa alvo de
Supremacia quando a cidade está visível; uma cidade lembrada sob fog continua apenas alvo normal de campanha.
Concealment é respeitado, enquanto o local/countdown de Ritual é público por regra da Fase 23.

### Orientações e adaptação gradual

As orientações são `MILITARY`, `ARCANE` e `BALANCED`. A distribuição usa seed do mapa + índice estável, não consome
o RNG global, e com três rivais garante exatamente um de cada. Militar começa focado em Supremacia; Arcano em
Transcendência; Balanceado decide pelo progresso real e, no limite, por desempate determinístico tardio.

A memória adaptativa observa apenas papéis/traços visíveis. A amostra entra com 20% e a memória anterior decai para
80%; uma visão isolada não troca o plano. Pressão montada favorece Guardião, caster/Cerco favorecem Ladino, Lendária
favorece Patrulheiro e ranged favorece Cavalaria. Quando o inimigo deixa de ser observado, a pressão decai.

### Pesquisa

Todos os 128 nós competem pelo único `V2ResearchState.active_id`. O score combina orientação, infraestrutura-base,
papel econômico urgente, ramo preferido/adaptativo, caminho de vitória, tier/custo e progresso já investido. A IA
só chama `select_research`; Conhecimento entra exclusivamente por `V2EconomyRuntime.apply_turn_income`. Troca exige
urgência real, margem de 18 pontos e menos de 50% de progresso, evitando oscilação e perda de investimento.

### Economia e cidades

A cada turno a IA pontua Ouro, Suprimentos, Produção, Conhecimento, Mana e desenvolvimento urbano. Déficit prioriza
Mercado; pressão logística prioriza Fazenda e preserva buffer; cidades cheias pesquisam Urbanização e entram no
City Project real, respeitando custo e reserva de Ouro. Oficina/Academia/Santuário Arcano, prédios de linha e
estruturas de Maestria/Ritual usam a fila comum e tiles físicos válidos.

Anexação usa Pontos de Anexação reais, escolhe recurso/fronteira útil e nunca reivindica tile ilegal. Construtores
são produzidos pela fila, obedecem cargas e melhoram recursos pela API da Fase 15. Nenhum valor é creditado pela IA.

### Composição e produção militar

O alvo de força é derivado de cidades, City Level e ramos concluídos (8–20 fichas relevantes), com hard stop em
24. Colonizadores/Construtores não contam; unidades já em produção contam. A composição pontua papéis de linha
(`tank_frontline`, melee, ranged, mobilidade, sabotagem e Cerco), casters e necessidades observadas. A cidade sempre
resolve a forma convencional mais avançada; unidades antigas elegíveis usam `V2UnitUpgrade` com Ouro/reserva/ação
reais. Lendárias e Manifestações passam pelos slots globais/escolares existentes e pelos mesmos gates de prédio,
Mana e produção do humano.

### Técnicas e Magia

Antes da ação comum, `V2AITacticalAI` avalia, por dado e utilidade, posturas defensivas, golpes unitários/AoE,
mover-e-atacar, retirada, ataque de cidade, Cura, buff, dano, invocação, Silêncio, Dissipar, terreno Druídico,
Passo Arcano, Portais e efeitos ambientais. A execução sempre chama `V2TechniqueRuntime`, `V2MagicRuntime`,
`V2PortalSystem`, `V2ConstructorRuntime` ou movimento do `HexGrid`; Mana, ação, recarga, alvo, guerra, fog e friendly
fire são revalidados pelo runtime. Caster ferido busca segurança/alcance; Portal só é usado com ganho mínimo;
FLYING e INFILTRATOR usam `unit_reachable`; retinue sem comando não recebe ordem.

### Planejamento de vitórias

`MILITARY` prioriza dois ramos completos, Exército Supremo e cidades desenvolvidas **visíveis** de rivais ainda
pendentes. Captura e crédito continuam em `HexGrid.capture_city`/`V2VictoryConditions`; a IA não marca progresso.
`ARCANE` prioriza duas Escolas, estruturas N8, duas Manifestações e Transcendência; com requisitos e 120 Mana, inicia
o Ritual real na cidade própria mais segura. Manifestações defendem a sede. Um Ritual rival público vira objetivo
estratégico e aumenta a pressão diplomática gradualmente conforme 4→1 rodadas, ainda sujeito a
`Diplomacy.can_declare_war`, prontidão e RNG — nunca guerra automática nem dissipação inventada.

### Compatibilidade transitória V1

O save ganhou somente o bloco opcional `v2_ai_strategy` para rivais. Orientação, foco, ramos preferidos, ramo
adaptativo, pressões, último turno de revisão e seed são sanitizados; views, alvos e explicações são transitórios.
Save antigo rederiva a personalidade deterministicamente. `SAVE_VERSION` continua 21. Nenhum campo é gravado para
o humano e nenhum estado V1 é migrado ou apagado.

### Testes

- `test_v2_ai_strategy.gd` (**22**): orientação, determinismo, save/legado, humano manual, fog/concealment,
  adaptação/decay, slot único/hysteresis, isolamento V1, economia/Supply/City Level, filas/cap, Ritual e Supremacia
  reais e anti-hardcode/polling.
- `test_v2_ai_tactical.gd` (**16**): técnica ofensiva/defensiva, cooldown, Cura, reserva de Mana, retinue,
  FLYING/INFILTRATOR, dano, summon, Silêncio, Dissipar, ambiental sem friendly fire, cidade, Retirada e terreno.
- `test_save_manager.gd` (+2): round-trip do estado estratégico e reconstrução determinística de save legado.
- `test_v2_ai_long_run.gd` (**1**, 4.066 asserts): 150 turnos reais, três rivais, save/load no turno 60 e invariantes
  de recursos, filas, serial, cap, pesquisa, prédios, cidade, força e magia.

Suíte unitária completa: **3.709 / 3.709** (164 scripts; 369.408 asserts), mais long-run e benchmark isolados,
todos verdes.

### Performance e long-run

Benchmark headless (Godot 4.7.1, cenário controlado): WorldView com 12 inimigos visíveis **231 µs**; score dos 128
nós **1,42 ms**; alvo estratégico **47,1 µs**; tentativa tática vazia **9,8 µs**; plano estratégico de um rival
**1,23 ms**; três rivais **3,91 ms**. Nada roda por frame.

O long-run determinístico alcançou o turno 151 em **13,2 s**. Máximo observado: **7 fichas relevantes por rival**
(hard cap 24). Todos usaram Infraestrutura e pelo menos uma árvore de conteúdo: Militar concluiu 9 Infra + 9
Doutrinas; Arcano, 7 Infra + 6 Magia; Balanceado, 8 Infra + 8 Doutrinas antes de fixar foco em Transcendência.
Foram construídos Mercado, Fazenda, Oficina, Academia, Santuário Arcano, Círculo Druídico, Salões/Campos e prédios
de Maestria. Houve cidades II–IV, formas Elite, casters e uma Lendária em produção. Ouro, Mana e Supply ficaram
finitos/não negativos; save/load preservou personalidade e memória no turno 60.

### Validação visual

Execução não-headless real de `Main.tscn`, 1920×1017, Vulkan/RTX 3060: 60 turnos sem debug de recursos, logs de
decisão por rival e captura do mapa. Confirmados os três perfis, pesquisa V2 ativa, prédios/linhas físicas, cidades
em expansão, produção militar e hard cap (máximo 5 naquele recorte). A captura ficou em
`user://phase24_v2_ai_real_game.png`. O aviso público de Caçada ao Dragão estava ativo sobre o mapa; é estado real
da partida, não UI nova da IA.

### Ainda propositalmente pendente

- limpeza final V1→V2 e, quando seguro, remoção de população/comida/tiles trabalhados e prédios econômicos V1;
- limpeza das barras/vitórias V1 e UX/UI final;
- bônus raciais V2, balanceamento definitivo e assets finais;
- auditoria final de release. Não foi iniciada nesta fase nenhuma dessas limpezas amplas.

**Frase de encerramento:** A IA V2 agora joga o mesmo jogo que o jogador: cada rival possui uma orientação estratégica estável, pesquisa pelo slot único, constrói e corrige a própria economia, forma exércitos por papéis em vez de spam de unidades, adapta-se gradualmente apenas ao que observa, produz e evolui tropas, usa Técnicas e Magia pelo mesmo runtime, desenvolve cidades e recursos e persegue ou reage às vias de Supremacia Militar e Transcendência sem informação oculta nem recursos gratuitos.

# Fase 25 — Migração Final V1→V2 e Limpeza Funcional

Objetivo: tirar a V1 do gameplay normal (jogador e IA). Uma partida nova agora usa só a progressão, economia,
cidades, exércitos, magia, IA e vitórias da arquitetura V2. Não houve balanceamento, bônus racial V2, asset final
nem redesign; números e conteúdo canônico (128 pesquisas, ramos, feitiços, técnicas, Manifestações, linhas de
unidade, requisitos de vitória) ficaram intocados.

Decisões do usuário registradas nesta fase:

- **Navegação**: o embarque era liberado pela tech V1 "Navegação", que deixou de existir. Decisão: **desligado por
  ora** — botão/atalho de embarcar removidos; unidade que já estava embarcada num save antigo continua se movendo e
  desembarcando normalmente (pathfinding embarcado intacto).
- **Dificuldade**: o multiplicador V1 de rendimento por dificuldade não tem efeito na economia V2. Decisão:
  **seletor escondido** (a tela de nova partida não o mostra); `GameManager.difficulty` continua existindo e viajando
  no save só por compatibilidade, sempre "normal" em partida nova.

## Auditoria final da convivência V1/V2

Classificação usada: **A** removido, **B** desativado (existe, não participa), **C** compartilhado (serve à V2),
**D** só compatibilidade de save, **E** mantido por depender de sistemas de mundo.

### Removido (A)

Scripts apagados (20): `TechDatabase`, `TechData`, `MagicDatabase`, `MagicContent`, `SpellDatabase`, `SpellData`,
`RaceEconomy`, `CityIdentity`, `CivilizationPersonality` (data); `MagicRuntime`, `MagicAI`, `SpellManager`,
`VictoryCampaign`, `TradeManager`, `TradeRoute` (core); `TechTree`, `TechTierBoard`, `MagicSchoolBoard`,
`TechFamilyIcon` (ui); `MagicOverlay` (world).

Estado/código removido de scripts que continuam:

- `PlayerData`: pesquisa V1 (`researched_techs`, `researched_magic`, `current_research`, `research_progress`,
  `select_research`), personalidade V1, `yield_multiplier`, `magic_effects`/`rituals`/`completed_rituals`/
  `spell_cooldowns`, `trade_routes`, estado das vitórias Territorial/Arcana/Supremacia V1.5.
- `City`: `population`, `stored_food`, `worked_tiles`, `food_storage_cap`, `max_trade_routes`, `captured_developed`,
  `collect_yields`, `effective_tile_yield`, atribuição automática/manual de tiles trabalhados, reivindicação de
  fronteira por crescimento, compra rápida, descontos de custo por identidade/recurso. `process_turn` só acumula a
  Produção V2 (`V2EconomyRuntime.city_production_income`); Ouro/Mana entram só por `V2EconomyRuntime.apply_turn_income`.
- `GameManager`: Ciência (`SCIENCE_PER_POPULATION`, `science_per_turn_for`, `_process_research`), multiplicadores de
  dificuldade, `victory_rules_version`, decisores V1 dos rivais (produção/pesquisa/comércio/ritual), processamento
  de magia/comércio V1, streaks e ativação das vitórias V1.
- `RivalAI`: `decide_production`, `decide_research`, `decide_trade`, `decide_arcane_ritual`,
  `prepare_for_world_event`, candidatos/pontuação de produção e pesquisa V1. O que sobrou (guerra/paz, campanha,
  movimento/ataque de unidade, defesa contra monstros e Dragão) é compartilhado e usado pela IA V2.
- `StrategicAI`: só `choose_opponent`, `engage_nearby_monster`, `explore`, `move_support`.
- `BuildingDatabase`/`BuildingData`: só os 29 prédios V2; campos `bonus_*`, `storage_bonus`, `defense_bonus`,
  `self_placed`, `upgrades_building`, `superseded_by_v2_fortification` removidos.
- `UnitDatabase`/`UnitData`: tropa racial exclusiva (`RACE_UNIQUE_KIND`, `race_for_unique_kind`), ramo de conteúdo
  mágico V1, `magic_school`, `mana_upkeep`, `is_v1_caster`.
- `ResourceDatabase`: rendimento por tile trabalhado (`YIELDS`/`yield_for`) e todos os descontos/capacidades V1
  (Cavalos→Cavalaria, Ferro→unidade pesada, Nódulo→feitiço, Gemas→compra rápida, Seda→rotas).
- `VictoryConditions`: Domínio Territorial e Ascensão Arcana (só sobra Dominação).
- `HUD.tscn`/`HUD.gd`: painéis Tecnologia/Magia/Grimório, botões Magia/Grimório/Embarcar/Compra rápida, linha de tiles
  trabalhados, botões fixos de prédios V1, botão debug "Árvores V2", barras de vitória V1.
- `SelectionManager`: mira de feitiço V1 e alternância de embarque.
- `GameSetupScreen`: seção "Tropa Exclusiva".

### Desativado (B)

- Metadados de rendimento do terreno (`HexTileData.food_yield/production_yield/gold_yield`): continuam no dado (geração
  e visual), **nenhuma economia os lê**.
- Embarque: sem forma de iniciar; o estado `embarked` de save antigo continua funcionando.
- `GameManager.difficulty`: viaja no save, sem efeito.

### Compartilhado (C)

Mapa/geração, terreno e recursos (ids, pesos por bioma, visual), combate (`CombatResolver`, flanqueio, veterania,
`UnitAbilities` de comando/cerco/montado), diplomacia, campanha de guerra, `CityDefense` (defesa contra monstros e
ataque de cidade V2), `CitySite` (avaliação de local — agora pela orientação V2 e pelos rendimentos das Melhorias V2),
`ArmyComposition` (papéis: Doutrina V2 pelo `branch_role`; unidade legada por alcance + traços), `RaceTheme` (só
nomes das tropas mundanas e kit visual), Guarda inicial (`warrior`) e Colonizador (`settler`, único item treinável
fora da V2 — `UnitDatabase.CORE_TRAINABLE_KINDS`).

### Só compatibilidade de save (D)

- Unidades V1 (`cavalry`, `catapult`, `human_knight`...) continuam criáveis por kind para restaurar save antigo;
  **nenhuma tem linha de produção**. Kind desconhecido é descartado no load.
- `SaveManager._sanitize_legacy_city` / `_is_valid_production_item` / `_sanitize_magic_dict` / `_valid_player_state`
  (ver Save abaixo).
- Traços `mounted`/`siege` semeados das listas V1 de `UnitAbilities` para essas unidades legadas.

### Mantido por sistemas de mundo (E)

Monstros e covis (`MonsterAI`, `LairStructure`), Dragão (`DragonEvent`/`WorldEventManager`), eventos, pilhagem. A
pilhagem de Invasor/Saqueador passou a mirar tiles com **Melhoria de Recurso V2** (a única fonte de rendimento por
tile da economia V2); tile pilhado não rende a Melhoria enquanto durar a pilhagem.

## Cidade

Decisão final: **população, comida e tiles trabalhados não existem mais** (campos, métodos e UI removidos).
`collect_yields` foi removido. Vida máxima, slots, raio de território e Pontos de Anexação vêm do Nível de Cidade;
defesa vem só da Fortificação V2; território cresce só por anexação. O rótulo da cidade no mapa mostra
`Nome (I–IV)`; o visual escala pelo Nível de Cidade. Save: nada disso é gravado; campos antigos são ignorados no load.

## Pesquisa

- Ciência removida; o único recurso de pesquisa é **Conhecimento** (`V2EconomyRuntime`).
- Pesquisa V1 inexistente: nenhuma UI, nenhum campo, nenhuma leitura.
- O botão normal **"Pesquisa"** da barra de ações abre o `V2ResearchBoard` (Doutrinas/Magia/Infraestrutura,
  capstones) como overlay normal, sem modo debug; mostra o nó ativo e o percentual.
- Ferramentas de desenvolvimento (+Conhecimento, completar, resetar) só existem em build de debug
  (`V2ResearchBoard.debug_tools_enabled = OS.is_debug_build()`); `GameManager.set_debug_mode` só liga a flag e não
  concede pesquisa; "completar pesquisa atual" do painel de debug completa o projeto V2 ativo.

## Economia

V2 é a fonte única (Ouro/Suprimentos/Produção/Conhecimento/Mana via `V2EconomyRuntime`/`V2LogisticsRuntime`). A
barra superior mostra **Ouro | Suprimentos | Mana | Conhecimento**. Prédios econômicos/militares V1: fora do
catálogo; saves antigos os perdem na sanitização, sem reembolso. `ResourceDatabase` mantém só ids, elegibilidade/peso
por bioma, nomes e a contagem de fontes controladas (usada pela avaliação de local); o recurso rende apenas pela
Melhoria V2. O `TileInspector` de recurso mostra só a semântica V2 (Melhoria, efeito, quem constrói, pilhagem).

## Magia

A magia V1 (escolas, rituais, Grimório, feitiços, véu/aurora, overlay mágico, IA mágica) saiu inteira do caminho
normal e do código. Permaneceu apenas: chaves de recarga/estado de Técnicas Militares e feitiços V2 em
`magic_cooldowns`/`magic_status` (as chaves V1 são descartadas no load). Conjurador é só quem tem Escola V2.

## Vitórias

Três condições finais, avaliadas por `GameManager.check_victories` nesta precedência, varrendo os jogadores em ordem
fixa `[humano] + rivais` dentro de cada tipo: **Dominação → Supremacia Militar V2 → Transcendência V2**. Eliminação
do humano encerra como derrota. Painel "Vitória" e tela final mostram só essas três (título, barra, detalhe); nenhuma
barra antiga. `VictoryCampaign` não existe mais.

## Save

- `SAVE_VERSION` **continua 21**: o formato só perdeu chaves (nenhum campo novo obrigatório), e o load já tolera
  chaves ausentes/extras — não havia necessidade de bump.
- Deixaram de ser gravados: pesquisa/magia/Ciência V1, personalidade, `trade_routes`, `victory_rules_version`,
  estado das vitórias V1, `spell_cooldowns`/efeitos mágicos V1, `population`, `stored_food`, `worked_tiles`,
  `captured_developed`, campos mágicos V1 de unidade.
- Save antigo carrega sem crash; **nenhum progresso V1 é convertido** (pesquisa, magia, Ciência, população, comida).
- Sanitização única no load (`SaveManager._sanitize_legacy_city`): Muralhas V1 (`walls`/`walls_2`/`fortress`/
  `imperial_fortress`) viram `fortification_level` quando o campo não existe; prédios fora do catálogo saem de
  `buildings`/coords/contagens (não ocupam slot); item de produção inválido é cancelado com `stored_production = 0`
  (sem reembolso). Unidade de kind desconhecido é pulada; chaves mágicas V1 descartadas.
- Blocos V2 (pesquisa, estratégia da IA, portais, terreno, zonas, Ritual) intactos.

## UI

Removidos/desconectados: painel e botão Tecnologia, painel e botão Magia, Grimório, botão Embarcar, Compra rápida,
linha de tiles trabalhados, informações de população/comida no painel de cidade e no inspetor, botões fixos de
prédios V1 e seção de treino V1, botão debug "Árvores V2" (o quadro abre pelo botão normal), seção "Tropa Exclusiva"
da tela de nova partida, barras de vitória Territorial/Arcana. Strings de jogador sem "V2"/ids internos (tooltips de
pesquisa sem `unlock_id`, "Custo: N Conhecimento", avisos de feitiço/ritual).

## Bugs preexistentes revelados pela limpeza

- `test_pause_menu` dependia de rivais deixados em `GameManager` por outro arquivo de teste (cidades já
  liberadas); só aparecia com a ordem de execução desta fase. O teste passou a isolar `rival_players`.

Regressões introduzidas durante a própria migração e corrigidas antes do fechamento (registradas por transparência):

- ao trocar o contra-ritual da magia V1 em `RivalAI._handle_attacker`, usei primeiro o alvo estratégico completo da
  IA V2, que devolvia o alvo de campanha sem validação e pulava o fallback tático. Corrigido para o equivalente
  exato: só o Ritual Final público de um rival tem prioridade (`V2StrategicAI.public_ritual_target_coord`), depois
  a campanha validada, depois o alvo tático.
- a reescrita de `ArmyComposition.roles_for_kind` perdeu o filtro que impedia id de prédio/desconhecido de virar
  "corpo a corpo" (defaults de `UnitData`); restaurado via `UnitDatabase.is_known_kind`.

## Testes

Suíte unitária completa: **3.240 / 3.240** (155 scripts; 363.959 asserts), sem erro de script. Na Fase 24 eram
3.709 (164 scripts): a contagem **caiu 469**, de propósito — esta é uma fase de limpeza e os testes removidos
exigiam comportamento V1 oficialmente retirado. Nenhum teste de pesquisa, economia, combate, cidade, Supply, magia,
IA, vitórias ou save V2 foi retirado; vários foram adaptados para o contrato novo.

Integração (fora de `test/unit`, execução isolada): `test_v2_ai_long_run.gd` verde (151 turnos, 9.213 asserts,
agora também conferindo a cada turno que nenhum prédio/item/tropa V1 aparece e que o save do turno 60 não grava
campos V1); `test_city_placement.gd` verde (harness portado para a orientação V2 e `is_usable_land`).

**Novo:** `test_v2_phase25_migration.gd` (**16**): estado canônico sem campos V1 (jogador, cidade, GameManager),
cidade por 100 turnos só com Produção V2 e território fixo, cidade nunca credita Ouro/Mana direto, neutralidade
racial (economia, cidade, custos, treino), ausência de módulos raciais/de identidade, recurso no inspetor só com a
semântica V2, só três vitórias com precedência fixa, Dominação declarada, ferramentas de debug só em build de debug,
modo debug não concede pesquisa, barra superior na ordem Ouro/Suprimentos/Mana/Conhecimento sem termos V1/internos,
forças iniciais Colonizador + Guarda, sanitizador central recusa itens V1, Muralhas V1 → Fortificação.
Também novos: `test_save_manager` +4 (estado V1 de jogador descartado sem conversão; cidade legada sanitizada sem
reembolso; unidade de kind desconhecido pulada; save novo sem campos V1), `test_hud` +1 (nenhum painel/botão V1 na
HUD) e testes reescritos para o botão "Pesquisa" e o painel/tela de vitória.

**Arquivos de teste removidos** (contrato deixou de existir junto com o sistema):

| Arquivo | Testes | Por quê |
|---|---|---|
| `test_tech.gd`, `test_tech_tree.gd`, `test_tech_tier_board.gd` | 59 + 18 + 28 | árvore de Tecnologia V1 e suas UIs |
| `test_magic.gd`, `test_magic_v1.gd`, `test_spells.gd` | 27 + 24 + 28 | magia V1 (escolas, rituais, Grimório, feitiços) |
| `test_trade.gd` | 13 | rotas comerciais/Mercador |
| `test_city_identity.gd`, `test_civilization_personality.gd`, `test_race_economy.gd` | 22 + 11 + 9 | identidade de cidade, personalidade V1, economia racial |
| `integration/test_campaign_v21.gd`, `integration/test_simulation_balance.gd` | 2 + 5 | campanha de vitória V1.5 e simulação de balanço da economia V1 |

**Testes removidos/adaptados dentro de arquivos que continuam** (líquido por arquivo):

- `test_city` −70: crescimento de população/comida, reivindicação de fronteira, `collect_yields`/tiles trabalhados,
  compra rápida, descontos de identidade/recurso, gates de tech V1 de prédios/tropas V1, tropa racial.
  Reescritos para V2: fila de produção, `can_build` exige pesquisa, tropa V2 exige prédio + pesquisa.
- `test_rival_ai` −28: decisores V1 de produção/pesquisa/comércio/ritual, `_role_gap_bonus`, eixo de identidade de
  tech, roster/tropa racial, `prepare_for_world_event`.
- `test_game_manager` −26: personalidade, multiplicador de dificuldade, Ciência, streaks/ativação das vitórias V1;
  reescritos: modo debug só liga a flag, "completar pesquisa" usa o projeto V2.
- `test_victory_conditions` −23: Domínio Territorial e Ascensão Arcana (restam os de Dominação).
- `test_hud` −22: painéis Tecnologia/Magia/Grimório, compra rápida, comida no painel de cidade, botões de prédios V1.
- `test_resources` −15: rendimento por tile trabalhado e descontos/capacidades V1 dos recursos; +2 (todo recurso tem
  Melhoria V2; sem semântica econômica V1).
- `test_buildings` −13: bônus de rendimento/defesa, Muralhas, prédios V1; reescrito para o catálogo V2.
- `test_naval` −8: tech Navegação e alternância de embarque (embarque desligado por decisão do usuário).
- `test_selection_manager` −8: mira de feitiço V1.
- `test_race_theme` −6: nomes/descrições de techs e prédios V1 por raça.
- `test_save_manager` −4 líquido (−8 +4): round-trip de pesquisa/magia/streaks V1, reconstrução de personalidade,
  migrações v17/v18 da árvore V1.
- `test_system_completion` −4, `test_city_defense` −4 (produção emergencial V1), `test_v2_infernal_content_and_namespace`
  −4 (colisão de namespace com a Escola V1), `test_v2_economy_turn` −3 (comércio/Ciência), `test_tile_inspector` −2
  (véu/região mágica V1), `test_unit_database` −1, `test_v2_ai_strategy` −1, `test_v2_research_state` −1,
  `test_v2_research_database` −1, `test_v2_gold_economy` −1 (campos/prédios V1 que não existem mais).

Conferência: a itemização acima soma −468 dos −469; um teste de diferença não foi localizado arquivo a arquivo (a
Fase 24 não deixou contagem por arquivo para comparar).

## Performance

Fase essencialmente de remoção: nenhum `_process` novo, nenhum polling, nenhum cache novo.

Benchmark de IA da Fase 24 (`benchmark_v2_ai.gd`, mesmo cenário) — igual ou melhor:

| Medida | Fase 24 | Fase 25 |
|---|---|---|
| WorldView (12 inimigos visíveis) | 231 µs | 213 µs |
| score dos 128 nós | 1,42 ms | 1,17 ms |
| alvo estratégico | 47,1 µs | 43,5 µs |
| tentativa tática vazia | 9,8 µs | 9,3 µs |
| plano de um rival | 1,23 ms | 1,08 ms |
| plano de três rivais | 3,91 ms | 3,46 ms |
| long-run (151 turnos) | 13,2 s | 10,6 s |

Novo `benchmark_v2_phase25.gd` (mapa real 61×61, partida nova, mediana de 21 turnos após 5 de aquecimento; sem
equivalente na Fase 24 para comparar): turno real **22,0 ms** (só humano), **24,0 ms** (1 rival), **21,6 ms**
(3 rivais); refresh da HUD **60 µs**; painel de cidade (clique) **11,6 ms**; quadro de pesquisa abrir+fechar
**1,8 ms**; save **4,1 ms**; load **665 ms** (inclui regenerar o mapa 61×61 pela semente). O painel de cidade é um
custo de clique pontual; não foi otimizado aqui (não é regressão demonstrada — §111).

## Validação visual

Uma execução não-headless real de `Main.tscn` (1920×1017), partida nova (mapa 41×41, semente fixa, raça Anões,
2 rivais), 20 turnos reais pelo pipeline normal, com um script descartável apagado em seguida:

- **HUD**: barra superior `Ouro | Suprimentos | Mana | Conhecimento` (+ Cidades/Unidades); sem Ciência, Comida,
  População, V1/V2. Forças iniciais conferidas: Colonizador + Guarda.
- **Cidade** (fundada pelo Colonizador): Cidade I, Vida 24/24, Prédios 0/4, Território/Anexação, Produção e rendimentos
  V2 da cidade; fila só com o Colonizador; ações de Nível de Cidade, Muralhas I e Anexar. Sem população/comida/tiles
  trabalhados/prédios V1.
- **Pesquisa**: aberta pelo botão normal "Pesquisa", com Doutrinas/Magia/Infraestrutura e capstone; a barra de debug
  aparece só porque o executável usado é build de debug (o teste unitário cobre a ausência em build normal).
- **Unidades**: Escudeiro e Elementalista selecionados — classe, ações e seção de Magia V2; sem Grimório.
- **Tiles**: recurso bruto (Gemas: "Melhoria: Mina de Gemas (Construtor, em território próprio) / Efeito: +4 Ouro") e
  melhorado (Ferro: "Mina de Ferro / Efeito: +2 Produção local") — só semântica V2. (A única checagem que falhou foi
  do próprio script, que exigia a palavra "Melhoria" também no tile já melhorado; o texto está correto.)
- **Vitória**: painel com Dominação, Supremacia Militar e Transcendência; tela final provocada pelo mesmo sinal de
  `check_victories` com título "Vitória por Dominação — …" e o snapshot das três vitórias, sem barras antigas.
- **Debug**: painel de debug continua acessível à parte.

Capturas: `user://phase25_city_hud.png`, `phase25_research_panel.png`, `phase25_unit_panel.png`,
`phase25_victory_panel.png`, `phase25_final_screen.png`.

## Estado após a fase

Aetherlands passa a ser **feature-complete em sistemas**. Próximas fases (produto/polimento): bônus raciais V2;
balanceamento e UX fina; assets/VFX; auditoria final de release. Pontos notados e **não** corrigidos aqui (fora do
escopo de limpeza): a produção emergencial da IA durante a Preparação do Dragão era do decisor V1 (já desligado para rivais V2 desde a
Fase 24) — hoje a IA reage pela pontuação de ameaça local e pela interceptação (`defend_against_dragon`); os
metadados de rendimento do terreno seguem no dado sem uso; os scripts de validação visual das Fases 22–24
(`test/integration/visual_v2_phase2{2,3,4}.*`) continuam no projeto como estavam (não criados nesta fase).

**Frase de encerramento:** A migração V1→V2 terminou: uma partida normal de Aetherlands usa exclusivamente a
progressão, economia, cidades, exércitos, magia, IA e vitórias finais da nova arquitetura. Ciência, Comida, população
estratégica, tiles trabalhados, prédios econômicos legados, pesquisa/magia antigas e vitórias V1 deixaram de
participar do gameplay e da interface, enquanto sistemas compartilhados de mapa, combate, diplomacia, monstros e
eventos foram preservados. Saves V2 recentes continuam íntegros e dados legados são tratados apenas como
compatibilidade de carregamento, não como regras ativas.

---

# Fase 26 — Identidade Racial V2

Quatro perfis raciais pequenos e data-driven devolvem identidade mecânica à escolha de raça sem fragmentar o
conteúdo consolidado na Fase 25. Cada raça real da build tem **exatamente dois bônus positivos**, todos
**BALANCE PLACEHOLDER**, derivados exclusivamente do `CivilizationData.race` que já existia. Não há unidade,
prédio, pesquisa, feitiço, vitória ou regra de IA exclusiva.

## Auditoria do roster racial

O código, e não um arquétipo presumido, foi usado como autoridade. `GameSetupScreen.RACE_INFO` e os quatro botões
da tela de nova partida formam o roster jogável; `GameManager.RIVAL_CIVS` fornece as mesmas três raças rivais quando
o humano ocupa uma delas. O id canônico vive em `CivilizationData.race`: o humano o escolhe no setup e ele é salvo
em `human_race`; rivais são reconstruídos pelas entradas canônicas do `GameManager`. `RaceTheme` continua cuidando
somente de nomes/cores/escala visual.

| ID | Nome visível | Tema preexistente | Bônus 1 | Bônus 2 |
|---|---|---|---|---|
| `human` | Reino de Aldenmark | organização, ordem e expansão | +1 carga para novos Construtores | +1 Ponto de Anexação ao evoluir cidade |
| `elf` | Império de Elenor | erudição e afinidade mágica | +10% Conhecimento/turno | +10% Mana/turno |
| `dwarf` | Liga dos Clãs de Ferro | riqueza mineral e forja | +10% Ouro bruto | +10% Produção local |
| `orc` | Horda dos Clãs Primordiais | hordas numerosas e força ofensiva | +10% capacidade de Suprimentos | +5% Ataque das unidades |

Rationale: Humanos aceleram expansão territorial sem ganhar economia recorrente; Elfos aceleram os dois recursos
arcanos sem reduzir custos; Anões melhoram caixa e filas locais sem alterar upkeep; Orcs sustentam um exército maior
e recebem o único bônus direto de combate, deliberadamente menor. As quatro combinações são distintas e nenhuma
escolha libera conteúdo. A Fase 27 deve avaliar as magnitudes; esta fase não faz balanceamento competitivo global.

## Novo fundamento racial V2

| Responsabilidade | Arquivo |
|---|---|
| Resource com apenas os oito eixos mecânicos realmente usados | `scripts/data/V2RaceBonusData.gd` |
| Fonte única dos quatro perfis, cache `race_id -> profile` O(1), resumo e linhas de UI | `scripts/data/V2RaceBonusDatabase.gd` |
| Consultas semânticas neutras para jogador nulo/id vazio/desconhecido | `scripts/core/V2RaceBonusRuntime.gd` |

Não existe `HumanRuntime`, `OrcRuntime`, estado no `PlayerData` nem cópia de perfil por jogador. Os perfis são
dados compartilhados sem API de mutação; Ouro, Supply, Produção, Conhecimento, Mana, cargas, anexação e Ataque
são consultados pelo runtime no ponto semântico de cada sistema. Os consumidores não contêm branches por id de
raça. `RaceEconomy`, `CityIdentity`, `CivilizationPersonality` e `RACE_UNIQUE_KIND` continuam ausentes.

## Integração econômica

- **Ouro:** o multiplicador Anão entra uma vez sobre a renda bruta final das cidades (base + Mercado + Melhoria,
  depois do desconto operacional quando houver Déficit). Upkeep não muda. A versão nominal usada para derivar
  Déficit recebe o mesmo fator, evitando decisão inconsistente.
- **Suprimentos:** o multiplicador Orc entra uma vez na capacidade total; uso, custo por unidade e Tensão Logística
  não mudam.
- **Produção:** o multiplicador Anão entra uma vez no rendimento local lido por `City.process_turn`; não existe
  pool global nem alteração de custo.
- **Conhecimento/Mana:** os multiplicadores Elfos entram nas rendas recorrentes finais antes do crédito por turno;
  custo de pesquisa, reserva estratégica de Mana e custo de feitiço/manifestação não mudam.
- `city_income_breakdown` preserva base/prédios/melhorias e acrescenta `pre_racial_total`,
  `racial_multiplier` e `racial_bonus`; o `total` é exatamente o valor efetivo exibido/consumido.

## Integração militar/mágica

- Novos Construtores materializam `tier de Indústria + 1` carga para Humanos. Cargas de unidades existentes não
  mudam quando o dono/raça muda e continuam sendo salvas como estado da unidade.
- Cada upgrade real de Cidade II–IV concede o valor do nível +1 Ponto de Anexação para Humanos. Fundação de
  cidade não recebe o bônus.
- O Ataque Orc é um único fator na cadeia de `CombatResolver.predict`; `resolve` usa a mesma previsão, portanto
  dano previsto e real coincidem. Stats-base, Defesa, HP, veterania, técnicas e custos permanecem iguais.
- Não foi escolhido modificador de custo, feitiço, cura, movimento, Defesa ou HP. Assim não existem integrações
  vazias nem regras raciais paralelas nesses sistemas.

Toda renda de cidade consulta o **dono atual**. Ao capturar, Ouro/Supply/Produção/Conhecimento/Mana passam a usar
imediatamente a raça do novo dono, sem dado gravado na cidade. Ataque consulta o dono atual da unidade. Os dois
bônus que se materializam no momento de criação (cargas) ou evento (anexação) não são retroativos.

## IA e identidade estratégica

A orientação determinística MILITARY/ARCANE/BALANCED continua independente da raça. Nenhuma linha de
`V2AITuning` mudou. A IA entende os bônus sem conhecimento duplicado: seus scores consultam
`V2EconomyRuntime.player_gold_net_income`, capacidade de Supply, Produção local e reserva real de Mana; decisões
táticas chamam o mesmo `CombatResolver.predict` com o fator racial. O `V2AIWorldView` continua sendo a fronteira de
informação pública, sem inspeção nova de estado oculto adversário.

## UI

- `GameSetupScreen`: cada seleção mostra nome, tagline/lore e `Especialidades:` com exatamente duas linhas vindas
  de `V2RaceBonusDatabase.effect_lines`; mudar uma magnitude no banco muda o texto.
- HUD: passar o cursor sobre `Cidades | Unidades` mostra `Raça: <nome>`, resumo e as duas especialidades. O label
  usa cursor de ajuda e recebe mouse explicitamente. Nenhum id, `V2` ou `placeholder` chega ao jogador.
- Barra superior e painel de cidade continuam compactos: os valores finais já incluem os bônus; não foi criado
  contador racial nem repetido o bônus em cada unidade.

## Save/load

`SAVE_VERSION` permanece **21**. O `human_race`/`CivilizationData.race` já persistido é suficiente; não existe
bloco `v2_race_bonuses`, snapshot de multiplicador ou novo campo derivado. Round-trip real com Anão restaura o id e
rederiva 1,10× Ouro/Produção. Um save representativo da Fase 25 contendo só `elf` recebe automaticamente
1,10× Conhecimento/Mana no load.

## Testes

`test_v2_race_bonuses.gd` adiciona **23 testes / 660 asserts**: roster exato, dois bônus positivos e combinações
distintas, magnitudes, neutralidade defensiva, ausência de ids de conteúdo/exclusivos, comparação econômica
controlada, composição única, Déficit/upkeep, fila local, Supply/Tensão, Construtor, anexação, captura, combate
`predict == resolve`, isolamento, catálogos compartilhados (128 pesquisas, unidades, prédios e feitiços),
orientação da IA, setup/HUD, formato de save e ausência de branches raciais nos consumidores.

`test_save_manager.gd` adiciona 2 casos reais (round-trip e save F25). O fluxo histórico da Fase 15 usa uma
fixture racial desconhecida/neutra para continuar validando seus números originais; a Fase 26 cobre os efeitos
Humanos separadamente. `test_v2_race_new_game.gd`, executado como integração isolada, inicia uma partida real para
cada uma das quatro raças, funda a capital, observa os dois eixos declarados e processa três turnos: **1/1 teste,
68 asserts**, cobrindo os quatro casos sem crash.

Suíte unitária completa: **3.265 / 3.265** (156 scripts; **364.878 asserts**; 439,564 s), sem erro de script. Além
dela, passaram isoladamente o smoke de nova partida acima, o long-run, o benchmark e a validação visual.

## Performance

`benchmark_v2_phase26.gd`, mapa real 61×61, Godot 4.7.1 headless nesta máquina:

| Operação | Tempo |
|---|---:|
| lookup O(1) de profile | 2,03 µs |
| getters Gold/Supply/Produção/Conhecimento/Mana/Builder/Anexação | 2,37–2,51 µs |
| getter de Ataque | 2,87 µs |
| renda completa de Ouro / Supply / Produção local | 14,78 / 14,87 / 14,88 µs |
| `CombatResolver.predict` com fator racial | 36,56 µs |
| refresh da HUD / painel de cidade | 0,118 / 9,82 ms |
| plano estratégico 1 / 3 rivais | 7,98 / 10,92 ms |
| turno real completo, 3 rivais (mediana) | 38,70 ms |

Nenhum `_process`, timer, polling ou varredura de perfis foi adicionado. Não há consulta de custo de feitiço
para medir porque nenhum bônus escolhido toca custos.

## Métricas para balanceamento

Long-run existente: **151 turnos**, humano passivo + três rivais de raças distintas, save/load no turno 60,
10.093 asserts, 15,4 s. IA estável; Ouro/Mana/Supply finitos e não negativos; hard token cap respeitado; pesquisa,
Cidade II+, militar, magia e forma evoluída observados. O race id e o profile foram conferidos a cada turno e depois
do load. O humano deliberadamente não funda cidade nesse smoke, preservando o cenário passivo histórico; seus
números econômicos comparáveis vêm do teste controlado.

| Raça | Ouro final / médio | renda líquida média | Supply médio | Prod./cidade | Conhecimento | Mana | Nível médio | unidades observadas/finais | 1º N9 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Humano passivo | 0 / 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 / 2 | — |
| Elfo (IA militar) | 0 / 51,97 | -1,75 | 10,72 | 5,47 | 10,11 | 3,36 | 1,28 | 17 / 8 | 147 |
| Anão (IA arcana) | 74,80 / 45,05 | 0,50 | 10,75 | 5,96 | 5,37 | 6,29 | 1,00 | 13 / 7 | — |
| Orc (IA balanceada) | 840 / 193,43 | 5,72 | 13,82 | 5,87 | 10,69 | 2,56 | 1,65 | 20 / 9 | 149 |

Nenhuma raça chegou a capstone, Lendária ou Manifestação nessa semente. Os números **não isolam causalidade
racial**: cada rival teve orientação, geografia e pressão diferentes. Servem como telemetria inicial para a Fase 27,
não como ranking; a comparação causal de +10%/+5% está nos testes controlados e não mostrou dupla aplicação.

## Validação visual

Execução não-headless real, Vulkan/RTX 3060, `Main.tscn`, 1920×1017. As quatro raças foram percorridas no
seletor: nome/lore e as duas especialidades ficaram legíveis, dentro do painel e sem termos internos. Uma partida
Orc foi iniciada pelo fluxo real; o hover real sobre `Cidades | Unidades` exibiu o tooltip `Raça: Horda dos Clãs
Primordiais`, resumo, +10% Supply e +5% Ataque. Capturas: `user://phase26_setup_{human,elf,dwarf,orc}.png` e
`user://phase26_ingame_race_summary.png`. O primeiro lançamento do roteiro teve um erro de tipagem antes de qualquer
captura; execuções posteriores diagnosticaram o fade assíncrono da LoadingScreen no hover; a execução final passou
com `failures=0` e o tooltip efetivamente visível.

## Ainda propositalmente pendente

- balanceamento/tuning sistêmico dos valores raciais (Fase 27) e estatística com muitas sementes;
- UX/UI fina, dificuldade caso seja reintroduzida, navegação/embarque e auditoria final de release;
- assets finais e VFX. Nenhum asset, número de unidade/feitiço/pesquisa ou sistema V1 foi criado/alterado aqui.

**Frase de encerramento:** As raças de Aetherlands agora possuem identidade mecânica própria sem fragmentar o
conteúdo do jogo: todas compartilham as mesmas 128 pesquisas, unidades, prédios, feitiços e condições de vitória,
enquanto dois bônus passivos por raça modificam de forma transparente sistemas já existentes por uma única camada
data-driven. Os bônus são derivados apenas do race id, não criam estado paralelo, são compreendidos pela IA através
dos mesmos valores efetivos usados pelo jogador e permanecem isolados do conteúdo e das regras fundamentais.

---

# Fase 27 — Balanceamento Sistêmico V2

Primeiro passe sistêmico de balanceamento depois da migração completa e da identidade racial. Esta fase não
cria conteúdo, sistemas, assets, dificuldade, navegação ou regras V1: mede o jogo atual, altera somente valores com
evidência independente e confirma que economia, progressão, cidades, combate, magia, raças, IA e vitórias continuam
coerentes entre si. Os valores finais deixam de ser `BALANCE PLACEHOLDER` para este primeiro baseline jogável; não
são uma promessa de equilíbrio competitivo perfeito.

## Baseline F26

O baseline foi registrado **antes de qualquer edição numérica**, reutilizando o long-run real da Fase 26: mapa
61×61, semente 24024, humano passivo, três rivais, 150 turnos processados e save/load no turno 60. Resultado:
**1/1 teste, 10.093 asserts, 12,745 s**, sem crash ou estado inválido.

| Rival | Orientação | Conhecimento médio | Ouro líquido médio | Unidades finais | Primeiro N9 | Capstone |
|---|---|---:|---:|---:|---:|---:|
| Elfo | militar | 10,11 | -1,75 | 8 | 147 | — |
| Anão | arcana | 5,37 | +0,50 | 7 | — | — |
| Orc | balanceada | 10,69 | +5,72 | 9 | 149 | — |

O Anão arcano acumulou Mana (803 no fim; renda média 6,29), mas não chegou ao primeiro N9 nem a uma
Manifestação. O máximo foi 7 tokens; nenhuma civilização alcançou Lendária, Manifestação ou capstone. Os dois
sinais iniciais independentes foram, portanto: (a) o long-run histórico e (b) a amostra multi-seed F26 abaixo.

Antes do tuning, 36 observações (12 sementes × 3 orientações, até o turno 200) mostraram:

| Orientação | 1º N3 mediano | N5 | N7 | N9 | 2º N9 | Capstone |
|---|---:|---:|---:|---:|---:|---:|
| Militar | 37 | 82 | 108 | 145 (9/12) | 174 (4/12) | 188 (3/12) |
| Arcana | 44 | 107,5 | 150 | 184 (2/12) | — | — |
| Balanceada | — | — | — | 145 (5/12) | 185 (4/12) | 197 (1/12) |

Só 2/12 arcanas produziram a primeira Manifestação (mediana 198); nenhuma via venceu. O problema era sistêmico:
a progressão de pesquisa chegava tarde, especialmente para a rota arcana, apesar de haver Mana suficiente.

## Metodologia de balanceamento

Foi criado `test/integration/balance_v2_phase27.gd`, um laboratório isolado e executado explicitamente (o nome não
começa com `test_`, portanto não encarece a suíte comum). Ele combina:

- microcenários determinísticos para renda, produção, Supply, cidade, fortificação, pesquisa, 12 Técnicas e 24
  feitiços;
- partidas estratégicas em mapa real 61×61, três rivais, todas as combinações de raça/orientação e teto de 200
  turnos;
- 12 sementes fixas (27001–27012), totalizando 36 observações, com round-trip real de save/load nas sementes
  27001 e 27007;
- telemetria por turno de economia, Déficit, Tensão, pesquisa, cidade, exército, tokens, Manifestações, ritual e
  vitória; marcos resumidos por mediana, p25, p75, mínimo e máximo;
- invariantes em todo turno: números finitos/não negativos, slot único de pesquisa, cap de tokens, reservas e
  exclusividade de Lendárias/Manifestações.

As bandas N3 15–35, N5 30–60, N7 50–90, N9 80–130, segundo N9 110–170 e capstone 125–190 foram usadas como
**guardrails**, nunca como asserts. Cada mudança exigiu pelo menos dois sinais; não houve tuning por uma única seed,
por igualdade artificial de taxa de vitória ou para fazer a IA acertar um turno exato.

## Economia e infraestrutura

A curva econômica estava estável: Ouro, Supply, Produção e Mana mostraram tradeoffs reais, sem explosão numérica
nem colapso geral. Seus valores foram preservados. A única correção foi Conhecimento, apoiada pelo baseline e pela
amostra F26:

| Dado central | F26 | F27 |
|---|---:|---:|
| Academia I | +2 Conhecimento | **+3** |
| Academia II | +3 | **+4** |
| Academia III | +4 | **+5** |

Base por cidade continua Ouro 2, Supply 4, Produção 4, Conhecimento 2 e Mana 1. Mercado permanece 4/6/8,
Fazenda 4/6/8, Oficina 2/3/4 e Santuário Arcano 2/3/4. Custos de produção, upkeep, Déficit (50% sobre prédios
operacionais), Tensão e melhorias de recurso não mudaram. A Academia continua competindo por slot e Produção;
não foi transformada em renda base gratuita.

## Progressão e ritmo de pesquisa

Os custos eram a parede dominante. A fonte única em `V2ResearchDatabase` mudou assim:

| Tier | N1 | N2 | N3 | N4 | N5 | N6 | N7 | N8 | N9 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| F26 | 10 | 20 | 30 | 50 | 80 | 120 | 180 | 270 | 400 |
| **F27** | **8** | **16** | **24** | **28** | **40** | **80** | **128** | **196** | **268** |
| acumulado F27 | 8 | 24 | 48 | 76 | 116 | 196 | 324 | 520 | 788 |

Infraestrutura mudou de 20/60/150 para **16/48/120**; Exército Supremo e Transcendência, de 600 para **400**.
A curva continua estritamente crescente e o capstone continua mais caro que N9. N4/N5 foram aproximados para que
o midgame apareça; N6–N9 ainda concentram o investimento tardio. Não houve fila adicional, desconto racial,
Conhecimento grátis, mudança de pré-requisito ou alteração nas 128 pesquisas.

Microcenário humano, uma cidade e economia saudável: sem Academia, N3/N5/N7/N9 aparecem em 24/58/162/394
turnos; com Academia I, em 10/24/65/158; com duas Academias I, 5/12/33/79; com três, 4/8/22/53. Duas linhas N9
mais capstone custam 1.976 Conhecimento no total. O Elfo permanece exatamente 10% mais rápido pelo multiplicador
racial, aplicado uma vez.

## Cidades e fortificações

Nenhum número mudou. A auditoria confirmou custo de oportunidade real:

- Cidade I–IV: **24/30/36/44 HP**; os requisitos, custos e Pontos de Anexação continuam os da Fase 25;
- Fortificação I/II/III: **40/70/110 PP**, upkeep **1/2/3**, escudo **8/14/22**, Defesa **10/20/30%** e
  ataque **3/5/7**;
- sem Oficina, Construtor/N3/N5/N7/Salão/Maestria/Cidade II/Fortificação I/Manifestação levam
  4/5/8/12/6/14/15/10/25 turnos; Oficina I reduz para 3/4/6/8/4/10/10/7/17.

Isso preserva o tradeoff entre desenvolver a cidade, fortificá-la, especializá-la e produzir força. O ataque de
cidade, captura, escudo e regeneração não foram tocados.

## Doutrinas e unidades

As seis linhas foram comparadas por tier, custo, Supply, HP, Ataque, Defesa, movimento, alcance, papel e confronto
controlado. N3 < N5 < N7 em poder/custo e N9 continua uma peça especial fora da cadeia. Guardião segue tank;
Guerreiro, DPS melee; Patrulheiro, DPS ranged frágil; Cavalaria, mobilidade/choque; Ladino, assassino/counter;
Cerco, pressão urbana. Nenhuma unidade, custo de Produção, Supply, stat, upgrade em Ouro, slot Lendário ou
multiplicador de combate mudou: as matrizes não mostraram duas evidências independentes de dominância estrutural.

O novo teste `test_v2_balance_invariants.gd` percorre as seis linhas e fixa progressão, identidade e invariantes
sem duplicar ids concretos na lógica de gameplay. O hard cap de IA permaneceu 24; a amostra F27 chegou no máximo a
20 tokens, sem bypass de Supply.

## Técnicas militares

As 12 Técnicas foram auditadas em microcenários pelo mesmo runtime: custo, recarga, duração, alcance, alvo,
multiplicador, penetração, revide, reposicionamento, cidade e passivas. Todos os valores permaneceram finitos,
não negativos e com recarga máxima 5; técnicas ativas continuam exigindo ação e as passivas continuam derivadas.
Nenhuma foi alterada: não havia evidência multi-seed de uso automático dominante nem de inutilidade sistêmica, e
o pedido proibia balancear por gosto ou por um duelo isolado.

## Magia e Manifestações

Os 24 feitiços, seis conjuradores, seis Manifestações, Mana, slots e recargas foram auditados. Dano, cura, controle,
terreno, mobilidade e zonas mantêm as identidades das Escolas; custos/recargas são finitos e a recarga máxima é 5.
Nenhum valor mágico mudou. A rota arcana F26 falhava por chegar tarde aos nós de pesquisa, não por falta de Mana:
corrigir Academia/custos levou a primeira Manifestação arcana multi-seed para mediana 156, sem baratear feitiços
ou remover o investimento de N8/N9, estrutura ritual, 120 Mana e quatro rounds da Transcendência.

## Bônus raciais

Os quatro perfis continuam com exatamente dois bônus e nenhum conteúdo exclusivo:

- Humanos: +1 carga de Construtor e +1 Anexação por upgrade;
- Elfos: +10% Conhecimento e +10% Mana;
- Anões: +10% Ouro bruto e +10% Produção local;
- Orcs: +10% Supply e +5% Ataque.

Comparativos controlados confirmaram aplicação única (por exemplo, Produção Anã e Supply Orc exatamente
1,10×) e nenhum bônus defensivo/custo oculto. A variação estratégica entre raças não isolou duas evidências de
dominância causal; por isso nenhum percentual foi alterado e nenhuma compensação por raça entrou na IA.

## IA

A IA não recebeu recurso, pesquisa, unidade, visão ou desconto gratuito. Houve um único ajuste de prioridade
central: `KNOWLEDGE_RESEARCH_URGENCY`, antes um literal 22, passa a **32** em `V2AITuning`. Ele torna a Academia
competitiva com os prédios temáticos quando a rota precisa de Conhecimento; não escolhe pesquisa, raça ou orientação
específica. MILITARY/ARCANE/BALANCED continuam determinísticas e distintas.

No long-run F27 equivalente ao baseline, os primeiros N9 foram 106 (Elfo militar), 116 (Anão arcano) e 106 (Orc
balanceado), contra 147/—/149 na F26. Conhecimento médio foi 15,11/11,04/21,23; o máximo foi 10 tokens. Nenhuma
chegou a capstone até 151, o que evita transformar a correção de pesquisa em vitória automática.

## Ritmo das vitórias

As condições não mudaram. Supremacia ainda exige duas Doutrinas N9, Exército Supremo e conquista militar de
cidade qualificada; Transcendência ainda exige duas Escolas N9/N8, duas Manifestações, capstone, 120 Mana e ritual
interruptível de quatro rounds. Research e capstone não são a vitória inteira.

Na amostra F27 houve uma Transcendência no turno **188**, dentro da meta inicial de 120–200. Não houve Supremacia:
as IAs militares chegaram a capstone, mas a conquista territorial qualificada continuou sendo o limitante. Isso é
evidência de que a rota está alcançável e ainda depende da execução estratégica; não justifica reduzir a condição
de vitória ou dar alvo/captura artificial à IA.

## Multi-seed

Resultado final: **2/2 testes, 66.831 asserts, 244,021 s**, 12 sementes, 36 observações, com save/load estável.

| Orientação | N3 med. | N5 med. | N7 med. | N9 med. (alcançaram) | 2º N9 med. | Capstone med. | Conhecimento med. | Tokens med./máx. |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Arcana | 32,5 | 70 | 88 | 122,5 (10/12) | 169,5 (8/12) | 178 (5/12) | 11,33 | 6 / 13 |
| Balanceada | 44,5 | 72 | 81 | 99,5 (10/12) | 125 (8/12) | 141,5 (6/12) | 20,16 | 5 / 17 |
| Militar | 29 | 67 | 83 | 111 (11/12) | 149 (10/12) | 163 (10/12) | 20,97 | 12 / 20 |

Faixas completas (p25/p75; min–max): arcana N9 120,5/125; 107–158, segundo N9 160/175,75; 152–184,
capstone 172/185; 167–188. Militar N9 e balanceado N9 permaneceram dentro/ao redor do guardrail; N5 estratégico
ficou em 67–72 porque a IA primeiro estabelece as duas fundações de Infraestrutura e a economia real. O cenário
controlado saudável fica dentro da banda, portanto a IA não foi manipulada para produzir um número nominal.

Por raça, a mediana de primeiro N9 foi 112 (Anão), 108 (Elfo) e 123 (Orc); segundo N9 161/144/133; capstone
177,5/157,5/144. Geografia e orientação não foram isoladas nessas medianas, logo isso não constitui ranking racial.
A amostra melhora a confiança contra uma seed única, mas **não prova equilíbrio competitivo perfeito**.

Validação automatizada final: `test_v2_balance_invariants.gd` acrescenta **10 testes** de relação sobre custos,
economia, fortificações, seis linhas militares, 12 Técnicas, 24 feitiços, quatro raças, cap de tokens, slots e
ritual. Testes históricos que fixavam os placeholders foram atualizados para consultar o dado central. Suíte completa:
**3.275 / 3.275**, 157 scripts, **365.266 asserts**, 370,719 s, sem erro de script. O long-run final passou com
10.598 asserts; balance lab, benchmark e validação visual rodam isoladamente e também passaram.

## Bugs revelados pelo balanceamento

Não foi encontrado bug novo de gameplay nos sistemas balanceados. O trabalho revelou três problemas de validação:

1. testes antigos fixavam custos 10/20 e rendimento 2 da Academia em vez de consultar as fontes centrais; foram
   adaptados sem reverter o tuning;
2. o teste de IA usava 8 como "alto progresso" no N1; com custo 8 isso agora concluía a pesquisa. A fixture passou a
   usar 75% do custo real;
3. a semente 27010 terminou no turno 93 para as três observações porque a partida chegou a estado terminal sem
   evento de vitória V2. O harness preservou a duração real; classificar o motivo detalhado de derrota terminal é
   uma melhoria futura de telemetria, não autoriza mudar a regra de jogo nesta fase.

## Performance

`benchmark_v2_phase27.gd`, Godot 4.7.1 headless, mapa 61×61:

| Operação | F26 | F27 |
|---|---:|---:|
| renda de Ouro / Supply / Produção | 14,780 / 14,870 / 14,880 µs | 13,024 / 12,855 / 12,977 µs |
| disponibilidade de pesquisa | — | 1,872 µs |
| `CombatResolver.predict` | 36,560 µs | 32,095 µs |
| validação dos 24 feitiços | — | 36,387 µs por conjunto |
| save / load de 3 rivais | — | 2,564 / 508,372 ms |
| plano da IA, 1 / 3 rivais | 7,980 / 10,920 ms | 1,351 / 3,457 ms |
| turno completo, 3 rivais | mediana 38,700 ms | mediana 35,711 ms; máximo 66,378 ms |

Os quatro ajustes são lookup de constantes existentes; nenhum `_process`, timer, polling, nova varredura ou caminho
quente foi introduzido. As duas execuções usam o mesmo tamanho/quantidade de rivais, mas sementes diferentes, então
os deltas são um detector de regressão, não uma reivindicação de otimização. O benchmark F27 passou **2/2, 8
asserts, 9,63 s**. Avisos de `PhysicalBoneSimulator3D` aparecem
no encerramento de ciclos repetidos de save/load e já pertencem ao ciclo de cena; não houve falha nem regressão de
tempo demonstrada.

## Validação visual

Uma execução não-headless real de `Main.tscn`, Vulkan/RTX 3060, 1920×1017, mapa 61×61 e três rivais confirmou:

- quadro de Doutrinas com 8/16/24/28/40/80/128/196/268 e Exército Supremo 400, sem clipping;
- Infraestrutura com 16/48/120, seis linhas inteiras e rodapé canônico;
- Academia I custando 16 Conhecimento e a economia da cidade refletindo o runtime;
- barra superior, painel da cidade e quadro de pesquisa legíveis, sem sobreposição ou texto placeholder.

Capturas: `user://phase27_research_curve.png`, `phase27_infrastructure_curve.png` e
`phase27_city_economy.png`. Todos os checks do roteiro passaram; o jogo foi iniciado pela cena principal, a capital
foi fundada pelo fluxo real e os textos observados vieram das mesmas fontes centrais usadas no gameplay.

## Ainda propositalmente pendente

- UX/UI fina, qualidade de mensagens/tooltips, acessibilidade e layout;
- decisão futura sobre dificuldade;
- decisão futura sobre naval/embarque;
- assets finais, VFX e áudio quando aplicável;
- telemetria que classifique o motivo de toda terminação antecipada;
- nova rodada de balanceamento apenas depois de playtests humanos e amostra maior;
- auditoria final de release com Astra.

Nenhuma tarefa dessa lista foi antecipada. A Fase 27 termina aqui: o primeiro balanceamento sistêmico de Aetherlands
está concluído sobre dados medidos, não sobre uma única partida. Economia, progressão, cidades, seis Doutrinas,
seis Escolas, Lendárias, Manifestações, raças, IA e vias de vitória foram avaliadas por cenários controlados e
runs multi-seed; os valores que exigiam correção foram ajustados centralmente, os que não tinham evidência para
mudança foram preservados, e o jogo apresenta progressão coerente do opening ao endgame sem apagar a identidade
dos papéis ou introduzir cheats e sistemas paralelos.

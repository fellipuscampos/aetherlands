# Aetherlands — Referência de Balanceamento

Snapshot de **19/09/2026**, extraído do código (não de docs antigos). Serve
de base para avaliar o que está certo, o que precisa de balanceamento e o que
deve ser adicionado ou removido. **Nada aqui altera o jogo.**

Fontes de verdade (se um número divergir daqui, o código vence):

| Assunto | Arquivo |
|---|---|
| Árvore de tecnologia (mundana) | `scripts/data/TechDatabase.gd` |
| Árvore de magia (6 escolas), conjuradores, invocações | `scripts/data/MagicContent.gd` |
| Árvore de magia legada (não alcançável, ver §9) | `scripts/data/MagicDatabase.gd`, `SpellDatabase.gd` |
| Efeito real dos feitiços | `scripts/core/MagicRuntime.gd` |
| Unidades | `scripts/data/UnitDatabase.gd`, `scripts/core/UnitAbilities.gd` |
| Monstros | `scripts/data/MonsterDatabase.gd`, `scripts/core/MonsterAI.gd` |
| Prédios | `scripts/data/BuildingDatabase.gd` |
| Combate | `scripts/core/CombatResolver.gd` |
| Economia | `City.gd`, `GameManager.gd`, `RaceEconomy.gd`, `ResourceDatabase.gd`, `CityIdentity.gd` |

Convenções: **PM** = pontos de movimento (hexágonos/turno, todo terreno custa 1);
**Alc.** = alcance de ataque (1 = corpo a corpo); **Vis.** = raio de visão;
**cd** = recarga em turnos.

---

## 1. Regras gerais que afetam todos os números

### 1.1 Combate (`CombatResolver.predict`)

```
ATQ  = ataque × veterania × flanco × habilidade × maldição/tempestade
DEF  = defesa × (1 + terreno + prédio + fortificar) × veterania × comando
dano ao defensor  = max(1, ATQ − 0,5 × DEF)
contra-ataque     = max(0, DEF − 0,5 × ATQ) × 0,5      (só se o defensor sobreviver e a distância for 1)
```

- Unidade à distância (Alc. ≥ 2) atacando de longe **não sofre contra-ataque**.
- Atacar consome todo o movimento restante.
- **Veterania:** kills 0 / 1 / 3 / 6 → Recruta / Veterano / Elite / Lendário, **+10% por nível** (máx. +30%) em ataque *e* defesa.
- **Flanco:** +15% de ataque por aliado adjacente ao alvo (máx. 2 → +30%).
- **Fortificar:** +25% de defesa e cura 10% do HP máx./turno.
- **Guarnição em cidade própria:** cura 25% do HP máx./turno.
- **Ignora terreno e prédio** (`ignores_terrain_defense`): todos os conjuradores, Lich, Arquidemônio, Elemental da Tempestade, Golem Arcano, Convocador de Sombras, Mago legado. Também ignoram o bônus de Fortificar.
- **Bônus de terreno na defesa:** Taiga/Selva/Floresta +25%, Colinas/Colinas Vulcânicas +50%, Montanhas/Montanhas Vulcânicas/Picos de Cristal +100%.
- **Bônus de prédio na defesa** (só cidade própria, soma de todos): Muralhas +50%, Torre de Vigia +20%, Guarnição +20%, Muralhas II +35%, Fortaleza +75%, Fortaleza Imperial +100%. Máximo somado: **+300%** (defesa ×4).
- **Cerco a cidade** (`resolve_city_attack`): dano = `ATQ × mult. de cerco ÷ (1 + bônus de prédio)`, mínimo 1. Vai primeiro ao **escudo** (15, só com Muralhas, recarrega 15%/turno) e depois à **vida da cidade** (20 + 4 × população, regenera 8%/turno; a regeneração para depois de 2 turnos de cerco). Vida 0 = captura.
- **Milícia da cidade:** golpe automático em monstro adjacente: 1,5 + 0,25 × população (máx. 3, +1 com Muralhas). Nunca dá recompensa.

### 1.2 Economia

- **Ciência/turno** = soma da população de todas as cidades (× 1,1 para Elfos, × multiplicador de dificuldade só para IA).
- **Um único slot de pesquisa** compartilhado entre Tecnologia e Magia. Trocar de projeto **preserva** o progresso individual.
- **Slots de prédio por cidade = população.** Upgrades (Quartel II/III/Elite, Campo de Tiro II, Estábulo II, Oficina II, Celeiro II, Mercado II, Muralhas II, Fortaleza, Fortaleza Imperial, Grande Mercado, Grande Empório, Grande Arsenal) **não ocupam slot extra** enquanto o prédio base existir. Prédios mágicos ocupam slot normalmente.
- **Comida:** cada habitante consome 1/turno; teto base 15 (+ Celeiro). Estoque cheio = +1 população.
- **Rush-buy** (só com Mercado): 2 ouro por ponto de produção faltante (−5% por Gema controlada, máx. −30%).
- **Manutenção em ouro:** só **em guerra**, 0,5 ouro/turno por unidade com ataque > 0. Nunca gera dívida.
- **Manutenção em mana** (`MagicRuntime.process_turn`): cada unidade com `mana_upkeep` paga todo turno. Sem mana: criatura sem escola (Golem, Guardião, Fera, Lich, Arquidemônio…) **é destruída**; conjurador com escola fica **silenciado** por 1 turno.
- **Mana/turno** vem de: tecnologia N1 de cada escola (+1 por cidade), prédio da escola (+4), prédio ritual (+8), Torre dos Sábios (+3), Santuário (+2), Nódulo Arcano trabalhado (+2). Multiplicadores: Elfo ×1,2, Humano ×1,05, identidade Arcana da cidade até ×1,15.
- **Desconto de feitiço:** −5% de mana por Nódulo Arcano controlado (máx. −30%). Não vale para Grandes Rituais.
- **Bônus raciais:** Humano ×1,05 em tudo · Anão ×1,10 ouro/produção se trabalha Colina ou Ferro · Orc ×1,10 produção e crescimento 15% mais rápido · Elfo ×1,2 mana e ×1,1 ciência.
- **Descontos de recurso:** Cavalos −5%/fonte no Cavaleiro (máx. −30%); Ferro −5%/fonte em Homem de Armas, Catapulta, Golem de Pedra, Guarda-Machado Anão, Berserker (máx. −30%). Identidade Militar da cidade: até −15% em qualquer unidade treinada em prédio militar.

---

## 2. Árvore de Tecnologia (mundana) — 55 pesquisas, 10 níveis

**Regra de liberação:** pesquisar **quaisquer 2** tecnologias do nível N libera **todo** o nível N+1
(`TIER_UNLOCK_THRESHOLD = 2`). Pré-requisitos individuais **não bloqueiam** — são só âncora de
layout e preferência da IA. Consequência prática: o gate real de uma unidade é a **cadeia física de prédios**
(ver §4), não a árvore.

**Custo por nível (igual para todas as techs do nível):**

| Nível | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Custo (ciência) | 13 | 20 | 32 | 50 | 78 | 123 | 192 | 302 | 473 | 741 |
| Qtd. de techs | 4 | 5 | 6 | 5 | 4 | 8 | 6 | 6 | 7 | 4 |

- Árvore inteira: **11.129** de ciência.
- Caminho mínimo até *abrir* o nível 10 (2 techs por nível, as mais baratas): **2.566**; cada tech do N10 custa mais 741.

Família: **M**ilitar · **E**conomia · **D**efesa · **X** Exploração/Utilidade (apenas apresentação na UI).

### Nível 1 — 13
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Quartel | M | Prédio Quartel |
| Celeiro | E | Prédio Celeiro |
| Guarda | M | Unidade Guarda |
| Batedor | X | Unidade Batedor |

### Nível 2 — 20
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Guarnição | D | Prédio Guarnição (+20% defesa) |
| Campo de Tiro | M | Prédio Campo de Tiro |
| Oficina | E | Prédio Oficina |
| Arqueiro | M | Unidade Arqueiro |
| Homem de Armas | M | Unidade Homem de Armas |

### Nível 3 — 32
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Estábulo | M | Prédio Estábulo (exige Quartel construído) |
| Mercado | E | Prédio Mercado (rush-buy, +2 rotas) |
| Cavaleiro | M | Unidade Cavaleiro |
| Batedor Montado | X | Unidade Batedor Montado |
| Mercador | X | Unidade Mercador |
| Navegação | X | Modo **Embarcar** (único jeito de chegar aos continentes Vulcânico/Cristal) |

### Nível 4 — 50
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Arsenal de Cerco | M | Prédio Arsenal de Cerco |
| Lanceiro | D | Unidade Lanceiro |
| Espadachim | M | Unidade Espadachim |
| Quartel II | M | Prédio Quartel II (exige Quartel) |
| Infraestrutura Rural | E | +1 produção em Planície e Campina trabalhadas |

### Nível 5 — 78
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Muralhas | D | Prédio Muralhas (+50% defesa, escudo 15) |
| Torre de Vigia | D | Prédio Torre de Vigia (+20%) |
| Homem de Escudo | D | Unidade Homem de Escudo |
| Catapulta | M | Unidade Catapulta |

### Nível 6 — 123
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Besteiro | M | Unidade Besteiro |
| Cavaleiro Pesado | M | Unidade Cavaleiro Pesado |
| Balista | M | Unidade Balista |
| Campo de Tiro II | M | Prédio (exige Campo de Tiro) |
| Estábulo II | E | Prédio (exige Estábulo) |
| Oficina II | E | Prédio (exige Oficina): +3 produção |
| Celeiro II | E | Prédio (exige Celeiro): +12 armazenamento |
| Mercado II | E | Prédio (exige Mercado): +3 ouro |

### Nível 7 — 192
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Halberdier | D | Unidade Halberdier |
| Cavaleiro de Choque | M | Unidade Cavaleiro de Choque |
| Aríete | M | Unidade Aríete |
| Torre de Cerco | M | Unidade Torre de Cerco |
| Quartel III | M | Prédio (exige Quartel II) |
| Muralhas II | D | Prédio (exige Muralhas): +35% |

### Nível 8 — 302
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Fortaleza | D | Prédio (exige Muralhas): +75% |
| Grande Mercado | E | Prédio (exige Mercado): +4 ouro |
| Trebuchet | M | Unidade Trebuchet |
| Campeão | M | Unidade Campeão |
| Cavalaria Blindada | M | Unidade Cavalaria Blindada |
| Engenheiro de Cerco | X | Unidade Engenheiro de Cerco |

### Nível 9 — 473
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Grande Arsenal | X | Prédio (exige Arsenal de Cerco) |
| Quartel de Elite | X | Prédio (exige Quartel III) |
| General | M | Unidade General |
| Cavaleiro Imperial | M | Unidade Cavaleiro Imperial |
| Bombarda | M | Unidade Bombarda |
| Posto Avançado | X | **+1 de visão** em todas as unidades e cidades |
| Rotas Comerciais | E | Prédio Posto Comercial (exige Grande Mercado): +5 ouro |

### Nível 10 — 741
| Tech | Fam. | Libera / efeito |
|---|---|---|
| Fortaleza Imperial | D | Prédio (exige Fortaleza): +100% |
| Grande Empório | E | Prédio (exige Grande Mercado): +6 ouro |
| **Exército Supremo** | M | Unidade Campeão do Reino; **pré-requisito da Vitória por Supremacia** |
| Colosso de Cerco | M | Unidade Colosso de Cerco |

---

## 3. Unidades mundanas e raciais

**Poder** = ataque + defesa + 0,15 × HP (mesma fórmula da IA em `CityDefense.unit_power`).
Ignora alcance e habilidades — é só uma régua rápida. **P/C** = poder ÷ custo.

| Unidade | Custo | PM | Atq | Def | HP | Alc. | Vis. | Poder | P/C |
|---|---|---|---|---|---|---|---|---|---|
| Colonizador | 25 | 2 | 0 | 1 | 8 | – | 3 | 2,2 | – |
| **Guarda** | 15 | 2 | 4 | 3 | 12 | 1 | 3 | 8,8 | **0,59** |
| Homem de Armas | 22 | 2 | 5,5 | 4,5 | 16 | 1 | 3 | 12,4 | 0,56 |
| Arqueiro | 18 | 2 | 3 | 1,5 | 9 | 2 | 4 | 5,9 | 0,33 |
| Cavaleiro | 22 | 4 | 5 | 2 | 14 | 1 | 4 | 9,1 | 0,41 |
| Batedor | 16 | 3 | 1,5 | 1 | 8 | 1 | 5 | 3,7 | 0,23 |
| Batedor Montado | 22 | 5 | 2 | 1,5 | 10 | 1 | 5 | 5,0 | 0,23 |
| Mercador | 20 | 2 | 0 | 1 | 10 | – | 3 | 2,5 | – |
| Lanceiro | 24 | 2 | 4,5 | 4 | 15 | 1 | 3 | 10,8 | 0,45 |
| Espadachim | 26 | 2 | 6,5 | 3 | 15 | 1 | 3 | 11,8 | 0,45 |
| Homem de Escudo | 28 | 1 | 3 | 5,5 | 22 | 1 | 3 | 11,8 | 0,42 |
| Besteiro | 26 | 2 | 4,5 | 2 | 10 | 2 | 4 | 8,0 | 0,31 |
| Cavaleiro Pesado | 30 | 3 | 5,5 | 3,5 | 17 | 1 | 4 | 11,6 | 0,39 |
| Catapulta | 30 | 1 | 6 | 1 | 8 | 2 | 3 | 8,2 | 0,27 |
| Balista | 34 | 1 | 7 | 1 | 8 | 2 | 3 | 9,2 | 0,27 |
| Halberdier | 38 | 2 | 5,5 | 5 | 18 | 1 | 3 | 13,2 | 0,35 |
| Cavaleiro de Choque | 40 | 4 | 7 | 2,5 | 16 | 1 | 4 | 11,9 | 0,30 |
| Aríete | 38 | 1 | 6,5 | 2 | 14 | 1 | 3 | 10,6 | 0,28 |
| Torre de Cerco | 42 | 1 | 5 | 2,5 | 16 | 1 | 3 | 9,9 | 0,24 |
| Campeão | 46 | 2 | 7,5 | 4 | 20 | 1 | 3 | 14,5 | 0,32 |
| Cavalaria Blindada | 48 | 3 | 6 | 5,5 | 20 | 1 | 4 | 14,5 | 0,30 |
| Trebuchet | 50 | 1 | 7,5 | 1 | 9 | 3 | 3 | 9,9 | 0,20 |
| Engenheiro de Cerco | 30 | 2 | 0 | 1 | 10 | – | 3 | 2,5 | – |
| General | 55 | 2 | 0 | 2 | 14 | – | 4 | 4,1 | 0,08 |
| Cavaleiro Imperial | 60 | 3 | 8 | 5,5 | 22 | 1 | 4 | 16,8 | 0,28 |
| Bombarda | 65 | 1 | 9 | 1 | 10 | 2 | 3 | 11,5 | 0,18 |
| Campeão do Reino | 90 | 2 | 9,5 | 5,5 | 26 | 1 | 4 | 18,9 | 0,21 |
| Colosso de Cerco | 100 | 1 | 10 | 3 | 20 | 2 | 3 | 16,0 | 0,16 |

### 3.1 Tropas raciais (só a raça dona treina; sem tech, só o prédio)

| Raça | Unidade | Prédio | Custo | PM | Atq | Def | HP | Alc. | Vis. | Poder | P/C |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Humano | Cavaleiro Real | Estábulo | 26 | 3 | 5 | 4 | 15 | 1 | 4 | 11,3 | 0,43 |
| Anão | Guarda-Machado | Quartel | 24 | 1 | 5 | 5 | 16 | 1 | 3 | 12,4 | 0,52 |
| Orc | Berserker da Horda | Quartel | 18 | 2 | 6 | 1 | 10 | 1 | 3 | 8,5 | 0,47 |
| Elfo | Arqueiro Solar | Quartel | 26 | 3 | 3,5 | 1 | 8 | **3** | 5 | 5,7 | 0,22 |

### 3.2 Habilidades (`UnitAbilities.gd`)

Nenhum bônus de suporte acumula.

| Unidade | Efeito |
|---|---|
| **General** | Aliados a ≤ 2 hexágonos: **+25% ataque e defesa**. Não se aplica a si mesmo. Não acumula com outro General. |
| **Lanceiro, Halberdier** | +50% de ataque contra montados (Cavaleiro, Cavaleiro Real, Batedor Montado, Pesado, de Choque, Blindada, Imperial). |
| **Besteiro** | +30% de ataque contra blindados (Homem de Armas, Homem de Escudo, Golem de Pedra, Campeão, Campeão do Reino, Cavaleiro Pesado, Cavalaria Blindada, Cavaleiro Imperial). |
| **Cavaleiro de Choque** | +25% de ataque se já se moveu neste turno. |
| **Catapulta** | +50% contra cidades; ao atacar unidade, 30% de dano nas inimigas adjacentes ao alvo (raio 1, sem contra-ataque). É a única com dano em área. |
| **Balista, Trebuchet, Torre de Cerco** | +50% contra cidades. **Torre de Cerco** também ignora o escudo das Muralhas. |
| **Aríete, Bombarda, Colosso de Cerco** | +100% contra cidades. |
| **Engenheiro de Cerco** | Cura 25% do HP máx. de máquinas de cerco a ≤ 1 hexágono, por turno. |
| **Mercador** | Terminar o turno a ≤ 2 hexágonos de cidade estrangeira **em paz**: cria rota, **consome o Mercador**, +25 ouro. Ambas as cidades precisam de capacidade de rota (Mercado = 2; Seda dá até +2). |
| **Colonizador** | Funda cidade. |
| **Grifo (legado)** | Voa: ignora custo de terreno e cruza oceano. |
| **Ent, Convocador de Sombras (legado)** | Regeneram 15% / 10% do HP máx. por turno em qualquer lugar. |

---

## 4. Cadeia de produção: tecnologia → prédio → unidade

Três gates independentes: **(1)** tech do prédio, **(2)** prédio anterior da cadeia construído **nesta cidade**, **(3)** tech da unidade.

| Unidade | Tech da unidade (nível) | Prédio de treino | Tech do prédio (nível) | Exige construído |
|---|---|---|---|---|
| Colonizador | – | – | – | – |
| Guarda | Guarda (1) | – | – | – |
| Batedor | Batedor (1) | – | – | – |
| Homem de Armas | Homem de Armas (2) | Quartel | Quartel (1) | – |
| Homem de Escudo | (5) | Quartel | Quartel (1) | – |
| Arqueiro | Arqueiro (2) | Campo de Tiro | Campo de Tiro (2) | – |
| Cavaleiro | Cavaleiro (3) | Estábulo | Estábulo (3) | Quartel |
| Batedor Montado | (3) | Estábulo | idem | Quartel |
| Mercador | (3) | Mercado | Mercado (3) | – |
| Lanceiro, Espadachim | (4) | Quartel II | Quartel II (4) | Quartel |
| Catapulta | Catapulta (5) | Arsenal de Cerco | Arsenal (4) | – |
| Balista, Aríete, Torre de Cerco, Trebuchet, Eng. de Cerco | (6, 7, 7, 8, 8) | Arsenal de Cerco | Arsenal (4) | – |
| Besteiro | (6) | Campo de Tiro II | (6) | Campo de Tiro |
| Cavaleiro Pesado | (6) | Estábulo II | (6) | Estábulo |
| Cavaleiro de Choque, Cav. Blindada, Cav. Imperial | (7, 8, 9) | Estábulo II | (6) | Estábulo |
| Halberdier, Campeão | (7, 8) | Quartel III | (7) | Quartel II |
| General, Campeão do Reino | (9, 10) | Quartel de Elite | (9) | Quartel III |
| Bombarda, Colosso de Cerco | (9, 10) | Grande Arsenal | (9) | Arsenal de Cerco |
| Cavaleiro Real (humano) | – | Estábulo | (3) | Quartel |
| Guarda-Machado, Berserker, Arqueiro Solar | – | Quartel | (1) | – |

Observação estrutural: a **unidade** e o **prédio** têm techs separadas. Ex.: dá para pesquisar Campeão do Reino (N10) e
não conseguir treiná-lo se nunca pesquisar Quartel de Elite (N9).

---

## 5. Prédios

Custo em produção. "Slot" = ocupa slot de população (upgrades não ocupam).

### 5.1 Economia
| Prédio | Custo | Efeito | Exige |
|---|---|---|---|
| Celeiro | 20 | +1 comida, +10 armazenamento | – |
| Celeiro II | 45 | +1 comida, +12 armazenamento | Celeiro |
| Oficina | 25 | +2 produção | – |
| Oficina II | 40 | +3 produção | Oficina |
| Mercado | 25 | +2 ouro, rush-buy, +2 rotas, treina Mercador | – |
| Mercado II | 45 | +3 ouro | Mercado |
| Grande Mercado | 65 | +4 ouro | Mercado |
| Posto Comercial | 85 | +5 ouro | Grande Mercado |
| Grande Empório | 95 | +6 ouro | Grande Mercado |

### 5.2 Defesa (bônus somam entre si)
| Prédio | Custo | Bônus de defesa | Exige |
|---|---|---|---|
| Guarnição | 18 | +20% | – |
| Torre de Vigia | 26 | +20% | – |
| Muralhas | 30 | +50% e escudo 15 (anel visual na cidade) | – |
| Muralhas II | 65 | +35% | Muralhas |
| Fortaleza | 70 | +75% | Muralhas |
| Fortaleza Imperial | 100 | +100% | Fortaleza |

### 5.3 Treino
| Prédio | Custo | Treina | Exige |
|---|---|---|---|
| Quartel | 20 | Homem de Armas, Homem de Escudo, Guarda-Machado, Berserker, Arqueiro Solar | – |
| Quartel II | 40 | Espadachim, Lanceiro | Quartel |
| Quartel III | 60 | Halberdier, Campeão | Quartel II |
| Quartel de Elite | 85 | General, Campeão do Reino | Quartel III |
| Campo de Tiro | 22 | Arqueiro | – |
| Campo de Tiro II | 42 | Besteiro | Campo de Tiro |
| Estábulo | 26 | Cavaleiro, Cavaleiro Real, Batedor Montado | Quartel |
| Estábulo II | 44 | Cavaleiro Pesado, de Choque, Blindada, Imperial | Estábulo |
| Arsenal de Cerco | 32 | Catapulta, Balista, Aríete, Torre de Cerco, Trebuchet, Eng. de Cerco | – |
| Grande Arsenal | 80 | Bombarda, Colosso de Cerco | Arsenal de Cerco |

### 5.4 Mágicos
| Prédio | Custo | Efeito | Exige |
|---|---|---|---|
| **Torre dos Sábios** | 28 | +3 mana | **nenhuma tech** (ver §9) |
| Prédio da escola (N2) — 6 tipos | 50 | +4 mana, treina o conjurador (e o avançado, quando é unidade treinável) | tech N2 da escola |
| Prédio ritual (N8) — 6 tipos | 160 | +8 mana; necessário ao Grande Ritual | tech N8 + prédio da escola |
| Santuário do Nódulo | 45 | +2 mana; necessário à Transcendência | tech Transcendência Arcana |

---

## 6. Árvore de Magia — 6 escolas × 9 níveis + Transcendência

**Regras da árvore:** cada escola é uma cadeia linear (N1 → N9); **pré-requisito bloqueia de verdade**
(diferente da árvore mundana). Escolas são independentes entre si.

**Custo por nível (todas as escolas):**

| Nível | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| Custo | 16 | 24 | 36 | 55 | 85 | 130 | 195 | 295 | 445 |

Uma escola completa = **1.281** de ciência. **Transcendência Arcana = 740**, exige **duas escolas no N9**
(total mínimo ≈ 3.302, ~30% do custo da árvore mundana inteira).

**Estrutura fixa de cada escola:**

| Nível | O que dá |
|---|---|
| 1 | Abre a escola. **+1 mana/turno por cidade.** |
| 2 | Prédio da escola (+4 mana, treina conjurador) |
| 3 | Conjurador da escola |
| 4 | Feitiço 1 |
| 5 | Feitiço 2 |
| 6 | **Necromancia e Druidismo:** feitiço de invocação. **As outras 4:** unidade avançada (custo 110, manutenção 2 mana) |
| 7 | Grande Feitiço |
| 8 | Prédio ritual (+8 mana) |
| 9 | Grande Ritual |

### 6.1 Nomes por escola

| Escola | N1 | N2 | N3 | N4 | N5 | N6 | N7 | N8 | N9 |
|---|---|---|---|---|---|---|---|---|---|
| **Sagrada** | Doutrina Sagrada | Igreja da Luz | Clérigo | Cura Sagrada | Purificação | Hierofante | Domínio Consagrado | Grande Catedral | Aurora Divina |
| **Infernal** | Artes Infernais | Altar Abissal | Cultista | Fogo Infernal | Pacto de Sangue | Bruxo Infernal | Chuva de Enxofre | Portal Abissal | Manifestação do Arquidemônio |
| **Necromancia** | Necromancia | Cripta dos Sussurros | Necromante | Solo Amaldiçoado | Erguer os Mortos | Guardião Sepulcral | Legião dos Mortos | Mausoléu Negro | Ascensão do Lich Ancião |
| **Druidismo** | Druidismo | Círculo Druídico | Druida | Floresta Súbita | Flores do Véu | Fera do Bosque | Erguer Cordilheira | Coração da Terra Viva | Domínio da Terra Viva |
| **Arcanismo** | Arcanismo | Torre Arcana | Arcanista | Salto Arcano | Selo de Mana | Golem Arcano | Portal de Campanha | Obelisco de Convergência | Grande Convergência |
| **Elementalismo** | Elementalismo | Conclave Elemental | Elementalista | Relâmpago Encadeado | Onda Glacial | Elemental da Tempestade | Frente de Tempestade | Olho dos Quatro Ventos | Cataclismo Elemental |

### 6.2 Transcendência Arcana (N10 universal)
Custo 740. Só aparece quando **duas escolas estão no N9**. Libera o Santuário do Nódulo e a preparação da Vitória por Transcendência (§8).

### 6.3 Conjuradores e unidades mágicas

**Conjurador base** (Clérigo, Cultista, Necromante, Druida, Arcanista, Elementalista) — treinado no prédio da escola:

| Custo | PM | Atq | Def | HP | Alc. | Vis. | Manutenção |
|---|---|---|---|---|---|---|---|
| **65** | 2 | 4 | 2 | 11 | 2 | 3 | 1 mana/turno |

Só um conjurador **da escola certa**, vivo, **com movimento restante > 0**, não silenciado e sem recarga própria pode lançar o feitiço.
Lançar consome todo o movimento e **revela** a unidade por 1 turno. Cada conjurador tem sua própria recarga por feitiço.

**Unidades avançadas** (N6) — custo 110:

| Unidade | Escola | PM | Atq | Def | HP | Alc. | Vis. | Manut. | Notas |
|---|---|---|---|---|---|---|---|---|---|
| Hierofante | Sagrada | 2 | 5 | 3 | 15 | 2 | 5 | 2 | **É conjurador** da escola; treina no Igreja da Luz |
| Bruxo Infernal | Infernal | 2 | 5 | 3 | 15 | 2 | 5 | 2 | **É conjurador**; treina no Altar Abissal |
| Golem Arcano | Arcanismo | 1 | 8 | 7 | 30 | 1 | 3 | 3 | Não conjura; ignora terreno; treina na Torre Arcana |
| Elemental da Tempestade | Elementalismo | 3 | 7 | 4 | 22 | 2 | 3 | 2 | Voa; não conjura; ignora terreno |

**Invocações** (não treináveis):

| Unidade | Vem de | PM | Atq | Def | HP | Alc. | Manut. | Limite / duração |
|---|---|---|---|---|---|---|---|---|
| Esqueleto Vinculado | Erguer os Mortos / Legião / Lich | 2 | 4 | 2 | 9 | 1 | 0 | Máx. **3** por Necromante (Erguer); some se o invocador morrer. Legião: expira em **8 turnos** |
| Guardião Sepulcral | Guardião Sepulcral | 1 | 8 | 7 | 30 | 1 | 2 | Máx. **1** por Necromante |
| Fera do Bosque | Fera do Bosque | 3 | 8 | 7 | 30 | 1 | 2 | Máx. **1** por Druida |
| Demônio Menor | Arquidemônio | 2 | 6 | 2 | 14 | 1 | 0 | Até 4 por Arquidemônio |
| **Lich Ancião** | Ritual Necromancia | 2 | 12 | 5 | 48 | **3** | 5 | 1 por ritual; até 10 esqueletos |
| **Arquidemônio** | Ritual Infernal | 2 | 15 | 9 | 100 | 1 | 5 | 1 por ritual; até 4 demônios |

Invocações surgem sem movimento no turno em que aparecem. Lich e Arquidemônio agem **sozinhos** a partir do turno seguinte (§6.6).

### 6.4 Feitiços (não-rituais)

Alcance de lançamento: **3** (N4–N6) e **4** (N7). O alvo precisa estar **visível** e o conjurador dentro do alcance.
Unidades ocultas pelo Véu não podem ser alvo. "Duração N" = a região expira no turno T+N,
resultando em aproximadamente **N−1 aplicações** do efeito por turno (derivado do código).

| Escola | Feitiço (nível) | Mana | cd | Alvo | Efeito real |
|---|---|---|---|---|---|
| Sagrada | **Cura Sagrada** (4) | 18 | 3 | Unidade aliada | Cura 30% do HP máx. |
| Sagrada | **Purificação** (5) | 24 | 4 | Unidade aliada | Remove maldição, lentidão, silêncio, tempestade do alvo e **dissipa regiões hostis** no raio do alvo |
| Sagrada | **Domínio Consagrado** (7) | 65 | 8 | Tile | Região raio 2, duração 5: aliados purificados e curados **8%** HP máx./turno, ganham bênção; mortos-vivos e demônios inimigos ficam com **−20% ataque** (não causa dano) |
| Infernal | **Fogo Infernal** (4) | 18 | 3 | Inimigo | **12 dano** no alvo, **4** (12÷3) em cada inimigo adjacente. Com Pacto de Sangue ativo: ×1,6 (19,2 / 6,4) |
| Infernal | **Pacto de Sangue** (5) | 24 | 4 | O próprio conjurador | Perde **30% do HP atual** (nunca mata). Amplifica o próximo Fogo Infernal por 3 turnos |
| Infernal | **Chuva de Enxofre** (7) | 65 | 8 | Tile | Região raio 1, duração 4: **5 dano/turno em TODAS as unidades**, inclusive aliadas |
| Necromancia | **Solo Amaldiçoado** (4) | 18 | 3 | Tile | Região raio 1, duração 4: inimigos **vivos** (não mortos-vivos, sem bênção) recebem **3 dano/turno** e −20% ataque |
| Necromancia | **Erguer os Mortos** (5) | 24 | 4 | Tile adjacente ao conjurador | 1 Esqueleto Vinculado. Máx. 3 por Necromante |
| Necromancia | **Guardião Sepulcral** (6) | 45 | 6 | Tile adjacente | 1 Guardião (máx. 1) |
| Necromancia | **Legião dos Mortos** (7) | 65 | 8 | Tile adjacente | Até **4** esqueletos de uma vez, expiram em 8 turnos. **Sem limite de quantidade total** |
| Druidismo | **Floresta Súbita** (4) | 18 | 3 | Tile livre | Vira Floresta por 5 turnos; preserva recurso. Não vale em cidade, prédio, unidade, água/montanha |
| Druidismo | **Flores do Véu** (5) | 24 | 4 | Tile | Região raio 1, duração 5: **oculta aliados**. Inimigo adjacente revela; atacar/lançar revela por 1 turno |
| Druidismo | **Fera do Bosque** (6) | 45 | 6 | Tile adjacente | 1 Fera (máx. 1) |
| Druidismo | **Erguer Cordilheira** (7) | 65 | 8 | Tile livre | Até **3** montanhas no raio 1, por 4 turnos. Nunca sobre cidade/prédio/unidade |
| Arcanismo | **Salto Arcano** (4) | 18 | 3 | Tile livre visível | Teletransporta o próprio conjurador (fica sem movimento) |
| Arcanismo | **Selo de Mana** (5) | 24 | 4 | Inimigo **com escola** | Silêncio por **2 turnos** (não lança feitiço, **interrompe ritual**). Não afeta Lich, Elemental etc. (sem escola) |
| Arcanismo | **Portal de Campanha** (7) | 65 | 8 | Âncora própria | Âncora = tile de **Nódulo Arcano em território próprio** ou ≤ 1 de cidade com Obelisco. Por 5 turnos, até **2 unidades** a ≤ 1 da posição do conjurador atravessam por turno |
| Elementalismo | **Relâmpago Encadeado** (4) | 18 | 3 | Inimigo | **9 / 6 / 4** dano em até 3 inimigos (alvo + até 2 a ≤ 2 dele) |
| Elementalismo | **Onda Glacial** (5) | 24 | 4 | Inimigo | 5 dano em todos os inimigos no raio 1 do alvo; **movimento pela metade por 2 turnos** |
| Elementalismo | **Frente de Tempestade** (7) | 65 | 8 | Tile | Região raio 2, duração 5: **3 dano/turno em todos (inclusive aliados)**, lentidão, **−25% ataque à distância** |

### 6.5 Grandes Rituais (N9)

| Ritual | Canalização | Efeito | Custo total de mana |
|---|---|---|---|
| **Aurora Divina** (Sagrada) | 7 turnos | Região raio 4, duração 9: cura aliados **15%**/turno, purifica, enfraquece mortos-vivos/demônios; ao concluir **dissipa** regiões hostis no raio | 300 + 7×20 = **440** |
| **Manifestação do Arquidemônio** (Infernal) | 7 | Arquidemônio autônomo | **440** |
| **Ascensão do Lich Ancião** (Necromancia) | **9** | Lich autônomo | 300 + 9×20 = **480** |
| **Domínio da Terra Viva** (Druidismo) | 7 | Região raio 4, duração 9: transforma tiles livres em **Floresta** (bordas às vezes Montanha), ocultação | **440** |
| **Grande Convergência** (Arcanismo) | 7 | Transporta até **8** unidades da sede para uma âncora própria (Nódulo ou Obelisco) | **440** |
| **Cataclismo Elemental** (Elementalismo) | **8** | Região raio 3, duração 7: **6 dano/turno em todos (inclusive aliados)**, lentidão, pilhagem de tiles; **cidades inimigas −8 HP/turno** (mín. 1, sem destruição instantânea) | 300 + 8×20 = **460** |

**Condições de qualquer Grande Ritual:**
- Pesquisa do N9 + prédio ritual (N8) na cidade-sede.
- **4 conjuradores da escola** a ≤ 2 hexágonos da sede (**5 para Necromancia**). Só contam unidades com escola própria (conjuradores base, Hierofante, Bruxo).
- **300 mana** iniciais + **20 mana por turno**. Sem mana em qualquer turno = interrompe, **sem reembolso**.
- Um único ritual em canalização por civilização. Recarga de **25 turnos** após concluir.
- Sede, participantes e progresso são **públicos**. Os participantes ficam imobilizados.
- **Interrompe** se: sede/prédio ritual perdido, participante morto/afastado/silenciado, mana < 20, âncora perdida (Convergência).
- Custo real em unidades: 4 conjuradores × 65 = **260 produção** (325 para Necromancia) + 4–5 mana/turno de manutenção, além do prédio de 160.

### 6.6 Comportamento do Lich e do Arquidemônio

- Surgem a ≤ 3 hexágonos da sede, agem a partir do **turno seguinte**, não aceitam ordens.
- **Manutenção de 5 mana/turno**. Se o dono ficar sem mana, **desaparecem** (não têm escola).
- Todo turno par, invocam 1 subordinado (Esqueleto/Demônio Menor) adjacente, até **10** (Lich) ou **4** (Arquidemônio).
- Atacam qualquer inimigo visível ao alcance, com **dano em área** (40% em raio 1). Sem inimigo, atacam a cidade inimiga conhecida mais próxima (ou o alvo do ritual) ou marcham até ela.
- O Lich **recua** para não ficar adjacente a inimigos com ataque > 0.

### 6.7 Estados de status

| Status | Duração | Efeito |
|---|---|---|
| Silêncio | 2 turnos | Não lança feitiço; interrompe ritual |
| Lentidão | 2 turnos | Movimento pela metade |
| Maldição | 1 turno após o último tick | −20% ataque |
| Tempestade | 1 turno após o último tick | −25% ataque à distância |
| Revelado | 1 turno | Quebra a ocultação (após atacar ou lançar) |
| Bênção | 1 turno | Imune ao Solo Amaldiçoado |

---

## 7. Monstros neutros

Os covis são gerados no mapa; o ocupante original é o **chefe do covil** (imóvel, **HP ×2,5**, **ataque ×1,3**).
Reforços nascem por turno com chance `25% + 15% × ameaça(turno)` (ameaça satura em 60 turnos), limitados por
**teto local** (área do covil) e **global** (mapa). Destruir a estrutura do covil (só possível sem guardiões vivos)
paga a recompensa de covil.

| Monstro | Bioma do covil | Peso / ameaça mín. | Cap. local / global | Lote | Comportamento |
|---|---|---|---|---|---|
| **Goblin** | Floresta, Planície, Campina | 60 / 0,00 | 4 / 5 | 1 | **Saqueador** (raio 4). Em grupo de ≥ 2 ociosos é promovido a **Invasor** permanente |
| **Troll** | Montanha, Taiga, Tundra | 30 / 0,30 | 2 / 5 | 1 | **Guardião** raio 5 |
| **Esqueleto** | Deserto, Tundra | 25 / 0,15 | 4 / 5 | **3** | **Invasor** (marcha na cidade mais próxima do mapa) |
| **Vivern** | Lava, Cristal e biomas dos continentes especiais | 10 / 0,65 | 2 / 2 | 1 | **Caçador** (raio 6, ataca presa isolada/fraca) |
| **Dragão** | Lava | 5 / 0,85 | 1 / 1 | 1 | **Caçador** |

| Monstro | PM | Atq | Def | HP | Vis. | Voa | Ouro por kill | Recompensa de covil |
|---|---|---|---|---|---|---|---|---|
| Goblin | 1 | 3 | 2 | 8 | 1 | não | 15 | 75 ouro |
| Troll | 1 | 6 | 4 | 20 | 1 | não | 35 | 100 ouro |
| Esqueleto | 2 | 4 | 1 | 6 | 1 | não | 10 | 85 ouro + 10 mana |
| Vivern | 3 | 8 | 3 | 16 | 1 | **sim** | 70 | 130 ouro + 20 mana |
| Dragão | 2 | 16 | 8 | 50 | 2 | **sim** | 200 | 150 ouro + 35 mana |

Chefe de covil (×2,5 HP, ×1,3 atq): Goblin 20 HP/3,9 atq · Troll 50/7,8 · Esqueleto 15/5,2 · Vivern 40/10,4 · Dragão 125/20,8.

**Comportamentos** (`MonsterAI.gd`):
- **Guardião:** fica no raio do covil (padrão 2; Troll 5), ataca quem invade ou cidade/melhoria que se aproxime.
- **Saqueador:** procura presa fraca/isolada em raio 4, aproxima-se de cidades do raio, **saqueia tiles**.
- **Invasor:** vai à cidade inimiga mais próxima do mapa inteiro, luta no caminho, saqueia.
- **Caçador:** patrulha raio 6; só ataca se for favorável (presa isolada a > 2 de aliados, ou < 50% HP).
- **Alerta:** atacar um monstro põe o covil em alerta por 8 turnos (+3 no raio de Guardião/Saqueador).
- **Saque de tile:** o tile rende 0 por 6 turnos e o dono perde 15 de ouro.
- **Monstros comuns não atacam cidade diretamente** (só saqueiam e cercam); o Dragão-evento é a exceção. Cidade sitiada por 2 turnos para de regenerar.

### 7.1 Dragão como evento mundial (`DragonEvent`)
Usa a mesma ficha do Dragão acima (50 HP, 16 atq, 8 def), mas com ciclo próprio: anúncio → 3 turnos de preparação → ativo.
Voando percorre **10 hexágonos/turno**, causa **40% de dano em área** (raio 1) e, contra cidade, **35% do HP atual por passagem**
(nunca captura, deixa a cidade com 1 HP no mínimo). Fecha com ranking de dano por civilização, **sem recompensa em v1**.
Detalhes em `docs/DRAGON_EVENT_DESIGN.md`.

---

## 8. Condições de vitória

| Vitória | Condições |
|---|---|
| **Dominação** | Eliminar todas as demais civilizações |
| **Supremacia Militar** | Pesquisar **Exército Supremo** e manter ao menos uma cidade **desenvolvida** (população ≥ 3 e ≥ 2 slots usados na captura) capturada de **cada** rival vivo; mínimo de 2 conquistas desenvolvidas (ou dominação total). Recapturar impede. Aviso a 80% |
| **Transcendência** | Transcendência Arcana pesquisada (2 escolas no N9) · 2 Grandes Rituais **diferentes** concluídos · 3 Nódulos Arcanos · **30 mana/turno** de renda · Santuário construído · **5 conjuradores de ≥ 2 escolas** a ≤ 2 do Santuário · **400 mana** iniciais + **40/turno por 7 turnos**. Perder qualquer participante, a sede, Nódulos, mana ou sofrer silêncio interrompe |

Partidas antigas mantêm as vitórias legadas (Territorial 50% por 5 turnos; Ascensão Arcana).

---

## 9. Pontos de atenção para a avaliação

Observações extraídas da leitura do código. **Não são decisões** — são os pontos que mais merecem
uma conversa de balanceamento ou de limpeza.

### 9.1 Conteúdo que provavelmente é inalcançável numa partida nova
As unidades **Mago, Grifo, Ent, Golem de Pedra e Convocador de Sombras**, os prédios **Poleiro de Grifos, Bosque Druida,
Bigorna Rúnica e Cripta Sombria**, e os feitiços **Lança de Arcana, Reanimar, Ruína Ígnea e Metamorfose de Gaia**
pertencem à árvore mágica **antiga** (`MagicDatabase._build_all`). A árvore nova não oferece essas techs
(`available_techs` usa só `MagicContent`), então o gate `has_unlocked` nunca abre. Só existem em saves antigos.
Eles ainda estão em `PLAYER_TRAINABLE_KINDS` e nos botões de produção. **Decisão pendente:** remover, reintegrar
à árvore nova (ex.: Grifo/Ent/Golem como unidades de escola) ou manter como legado.
*(Conclusão por leitura de código. Tentei confirmar por execução headless, mas o projeto não carregou nesse momento — o Godot reportou erro de parse em `HexGrid.gd`, que tem alterações não commitadas; não investiguei a causa.)*

### 9.2 Colisão de id: `arcane_tower`
`MagicContent.add_buildings` reescreve o prédio `arcane_tower`. O antigo (30 prod, treina Mago) foi **substituído**
pelo do Arcanismo (50 prod, +4 mana, treina Arcanista/Golem). `BuildingDatabase.building_that_trains("mage")`
ainda aponta para ele.

### 9.3 Torre dos Sábios é dominante no início
Custa **28**, dá **+3 mana**, **não exige tecnologia** e está disponível desde o turno 1. O prédio da escola N2
custa 50 por +4 (e exige N1 + N2 = 40 de ciência). Na prática, mana barata sem pesquisa.

### 9.4 Custo dos conjuradores
Conjurador base custa **65** (o antigo Mago custava 28) com manutenção de 1 mana; unidade avançada custa 110.
Um Grande Ritual exige 4–5 conjuradores parados por 7–9 turnos, ou seja, 260–325 de produção além do prédio ritual (160)
e dos 440–480 de mana. Vale checar se o custo total é proporcional ao poder do resultado.

### 9.5 Eficiência (poder por custo) cai muito nos níveis altos
O **Guarda** (nível 1, sem prédio, custo 15) tem P/C **0,59**, o melhor do jogo, acima do Homem de Armas (0,56).
No topo, Campeão do Reino 0,21, Bombarda 0,18, Colosso 0,16 e General 0,08. O poder ignora habilidades e alcance,
então cerco e General têm valor que a régua não mostra — mas o contraste sugere revisar custos ou dar mais
diferenciação de papel nas unidades caras.

### 9.6 Unidades de nicho com P/C baixo
- **Batedor Montado** (custo 22, poder 5,0, P/C 0,23) só se justifica por PM 5.
- **Arqueiro Solar** (custo 26, ataque 3,5, 8 HP) depende do alcance 3; treina no Quartel, não no Campo de Tiro.

### 9.7 Efeito "fogo amigo" e regras assimétricas
Chuva de Enxofre, Frente de Tempestade e Cataclismo atingem **aliados**. Isso é intencional, mas a Frente de
Tempestade e o Cataclismo também dão −25% de ataque à distância / lentidão a quem o conjurador queria proteger.
O Solo Amaldiçoado poupa mortos-vivos e o Domínio Consagrado **não causa dano**, só enfraquece.

### 9.8 Regras de manutenção do Lich/Arquidemônio
Custam 5 mana/turno cada e **somem** sem mana. Um ritual em canalização custa 20/turno. Uma civilização com mana
apertada perde a invocação exatamente quando mais precisa dela.

### 9.9 Legião dos Mortos sem teto
Erguer os Mortos limita a 3; Legião (65 mana, cd 8) invoca 4 por conjuração **sem contar no limite**, e por conjurador.
Vários Necromantes multiplicam isso.

### 9.10 Prédios de defesa sem pré-requisito
Guarnição, Torre de Vigia e Muralhas não exigem outro prédio. Fortaleza e Muralhas II exigem Muralhas; a Fortaleza Imperial exige a Fortaleza.
A soma máxima de defesa (+300%) exige os 6 prédios, mas só 3 ocupam slot (Muralhas, Torre de Vigia, Guarnição — os demais são upgrades).

### 9.11 Grande Empório exige Grande Mercado, não Posto Comercial
No código, `grand_emporium.requires_building = "grand_market"`. O texto da tech Rotas Comerciais o chama de "degrau antes
do Grande Empório", mas o Posto Comercial **não** é requisito dele.

### 9.12 Pré-requisitos mundanos são cosméticos
Como a liberação é por contagem (2 de N), dá para chegar ao nível 10 pesquisando só 2 techs por nível. Combinado com
a soma de custos (§2), o ritmo de progressão depende quase inteiramente da ciência (população), não de escolhas.

### 9.13 Docs antigos
`docs/MAGIC_SYSTEM_V1.md` (2.288 linhas) descreve o desenho original da magia; `docs/MAGIC_IMPLEMENTATION.md` descreve o executado.
Este documento segue o **código**; onde divergir, o código é a verdade.

---

## 10. Fora do escopo deste documento

Não foram cobertos: comportamento detalhado da IA rival (`RivalAI`, `StrategicAI`, `MagicAI`), geração de terreno e
recursos além do que afeta os números acima, diplomacia, rotas comerciais em profundidade, modelos 3D e UI.

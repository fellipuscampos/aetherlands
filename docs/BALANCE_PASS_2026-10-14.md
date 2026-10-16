# Aetherlands — Rodada de balanceamento de 14/10/2026

Documento vivo da primeira rodada de balanceamento de valores com o jogo completo (V2 + V3). Até aqui os números de
unidades e feitiços eram marcados no código como `BALANCE PLACEHOLDER`, ou seja, nunca tinham sido balanceados entre
si. Fontes de verdade continuam sendo o código; este arquivo explica **por que** cada número é o que é e como medir de
novo.

Pedido do produto: o jogo deve durar **3–4 h**, com turnos de **1,5–2 min** (≈ 90–160 turnos). As unidades devem estar
proporcionais ao custo e ao tempo de produção. Os magos devem ser muito fortes, mas os efeitos "quebrados" precisam de
um preço alto: muita mana e, nos de dano, Vida do conjurador.

---

## 1. Como medir (ferramentas permanentes, fora da exportação)

| Ferramenta | O que faz |
|---|---|
| `tools/balance/DumpBalanceData.tscn` | Despeja em JSON os valores **atuais** do jogo: 40 unidades treináveis + Hostes, 13 monstros, 24 feitiços, 12 técnicas e 119 nós de pesquisa. |
| `tools/balance/unit_duel_model.py` | Aplica a fórmula real de combate e imprime, por nível (N3/N5/N7/N9), a matriz "golpes para matar / revide" e os duelos 1 contra 1. |
| `tools/balance/BalanceLab.tscn` | Partidas reais com 4 IAs (já existia; ver `docs/AETHERLANDS_RELEASE_BALANCE_BASELINE.md`). |

```
godot --headless --path . res://tools/balance/DumpBalanceData.tscn -- --out=C:/tmp/balance_data.json
python tools/balance/unit_duel_model.py C:/tmp/balance_data.json
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --run=<nome> --tag=<etiqueta> --matches=0-3   # 4 processos em paralelo
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --run=<nome> --tag=<etiqueta> --report
```

A régua do modelo de duelo **não** inclui técnicas, auras, flanco, terreno nem mobilidade. Ela serve para comparar
"força bruta por PP" dentro de um nível. Os papéis que vivem de outra coisa (tanque, cerco, ladino) estão explicados
na seção 3.

## 2. A fórmula que manda em tudo

```
dano    = max(1, ATQ − 0,5 × DEF)                 (CombatResolver.predict)
revide  = max(0, DEF − 0,5 × ATQ) × 0,5           (só corpo a corpo; quem ataca de alcance ≥ 2 não sofre revide)
cidade  = ATQ × multiplicador de cerco ÷ (1 + bônus de defesa da cidade); o escudo absorve primeiro
```

Consequência: multiplicar ATQ **e** DEF de todo mundo pelo mesmo fator multiplica o dano exatamente por esse fator e
preserva todas as relações relativas (quem vence quem). É assim que esta rodada mudou a letalidade sem desmontar o que
já funcionava.

## 3. Diagnóstico (antes)

1. **Combate lento demais.** Entre unidades do mesmo nível eram 4–8 golpes para matar. Um tanque levava 12–32 (Sentinela
   contra Sentinela: 32 golpes). Com 1 ataque por turno e a guarnição curando 25% por turno, um tanque guarnecido era
   praticamente imortal. Isso bate com o baseline: o **impasse militar** era a causa nº 1 de partidas longas (guerras
   longas e rasas, mediana de 0 capturas por guerra).
2. **A linha do Guerreiro dominava todos os níveis** (9–10 de 10 duelos vencidos pelo menor custo do nível). A
   Cavalaria custava só +4 PP pelos mesmos atributos mais 2 de movimento. O Ladino e o Mestre das Sombras perdiam quase
   tudo, mesmo considerando as técnicas.
3. **Mana sobrando.** No baseline, a IA tinha ~600 de mana parada na hora da primeira Manifestação. O custo de mana dos
   feitiços não limitava nada; só a recarga limitava.
4. **Ritmo.** Laboratório com o código de 14/10, antes desta rodada (12 partidas, limite 240): 7 vitórias entre os turnos
   172 e 238 (mediana ~217) e **5 partidas sem vencedor**.

## 4. Princípios usados

- **Letalidade:** dois guerreiros do mesmo nível se matam em ~3–4 golpes; um tanque aguenta 5–6; tanque contra tanque
  continua lento (é o papel dele).
- **Curva por nível:** atributos ~×1,0 (N3) → ×1,4 (N5) → ×1,85 (N7) → ×2,4 (Lendária), contra custo 20 / 32 / 48 /
  90–110 PP e Suprimento 1 / 2 / 3 / 5. O nível alto rende mais por PP (premia a pesquisa) e fica ~igual por Suprimento,
  que é o teto real do exército.
- **Papéis:** o Guerreiro é a régua do corpo a corpo. Mobilidade custa PP (Cavalaria). Alcance custa Vida (Patrulheiro).
  O tanque perde duelo, mas segura linha e cidade. O cerco é fraco em campo e forte contra cidade. O ladino troca
  defesa por ataque e conta com as técnicas (Ataque Furtivo: ×1,35, ignora 40% da Defesa, sem revide; Desmantelar: +50%
  contra conjurador/cerco).
- **Faixa de aceitação no modelo:** cada linha de combate de campo fica entre 2 e 8 vitórias de 10 no próprio nível.

## 5. Unidades — antes → depois

Regra-base: ATQ e DEF ×1,5 em **todas** as unidades e monstros (arredondado a 0,5). Por cima, os ajustes de papel em
negrito. Vida, alcance e movimento só mudam onde aparece a seta.

| Unidade | PP | Supr. | Vida | ATQ | DEF | Alc. | Mov. |
|---|---|---|---|---|---|---|---|
| Escudeiro | 20 | 1 | 18 → **20** | 3 → **4,5** | 4,5 → **7** | 1 | 2 |
| Guardião | 32 | 2 | 24 → **26** | 4 → **6** | 6 → **10** | 1 | 2 |
| Sentinela | 48 | 3 | 32 → **34** | 5 → **7,5** | 8 → **12,5** | 1 | 2 |
| Campeão Guardião | 90 | 5 | 44 → **46** | 6,5 → **11** | 10 → **15,5** | 1 | 2 |
| Guerreiro | 20 | 1 | 16 | 5 → **7,5** | 3,5 → **4,5** | 1 | 2 |
| Espadachim | 32 | 2 | 21 | 7 → **10,5** | 4,5 → **6,5** | 1 | 2 |
| Mestre de Armas | 48 | 3 | 28 | 9,5 → **14,5** | 5,5 → **7,5** | 1 | 2 |
| Herói da Lâmina | 90 | 5 | 38 | 12 → **18** | 7 → **10** | 1 | 2 |
| Arqueiro | 20 | 1 | 13 | 4,5 → **6,5** | 2,5 → **3,5** | 2 | 2 |
| Caçador | 32 | 2 | 17 | 6,5 → **9,5** | 3 → **4,5** | 2 | 2 |
| Atirador de Elite | 48 | 3 | 22 | 8,5 → **12,5** | 3,5 → **5** | 3 | 2 |
| Caçador de Lendas | 90 | 5 | 30 | 11 → **16,5** | 4,5 → **7** | 3 | 2 |
| Cavaleiro | 24 → **26** | 1 | 17 | 5 → **7,5** | 3 → **4** | 1 | 4 |
| Cavaleiro de Choque | 38 → **42** | 2 | 22 | 7 → **10,5** | 4 → **6** | 1 | 4 |
| Cavaleiro Blindado | 56 → **60** | 3 | 30 | 8,5 → **12,5** | 6 → **9** | 1 | 4 |
| Cavaleiro de Grifo | 100 → **95** | 5 | 36 → **40** | 10 → **16** | 6,5 → **10** | 1 | 5 (voa) |
| Ladino | 20 | 1 | 14 → **15** | 4,5 → **7** | 2,5 → **4** | 1 | 3 |
| Sabotador | 32 | 2 | 18 → **20** | 6 → **10** | 3 → **5** | 1 | 3 |
| Assassino | 48 | 3 | 23 → **26** | 8 → **14** | 3,5 → **5,5** | 1 | 3 |
| Mestre das Sombras | 95 → **90** | 5 | 30 → **34** | 10,5 → **17,5** | 4,5 → **8** | 1 | 4 |
| Catapulta | 28 | 1 | 16 | 3,5 → **5** | 2,5 → **3,5** | 2 | 2 |
| Trebuchet | 44 | 2 | 20 | 5 → **7,5** | 3 → **4,5** | 3 | 2 |
| Bombarda | 64 | 3 | 26 | 6,5 → **10** | 4 → **6** | 3 | 2 |
| Colosso de Cerco | 110 | 5 | 44 | 9 → **12** | 8 → **10** | 3 | 2 |
| Hoste Esquelética (invocada) | — | — | 18 | 4 → **6** | 3 → **4,5** | 1 | 2 |
| Hoste Macabra (invocada) | — | — | 30 | 7 → **10,5** | 5 → **7,5** | 1 | 2 |

Conjuradores (24 PP, Suprimento 2, sem ataque básico) e Grandes Manifestações: só a DEF ×1,5 (1,5–2 → 2,5–3; Manifestações
5,5–8 → 8,5–12). As Manifestações também ficaram mais baratas: **100/105/110 → 84/88/92 PP** (mana de produção igual,
60–75). O caminho arcano exige duas, e a produção era o gargalo medido (~17 turnos de uma cidade cada).

Por que cada ajuste de papel:

- **Guerreiro, DEF um pouco menor que o ×1,5 puro:** era a linha que vencia tudo pelo menor custo. Continua a melhor em
  duelo direto (6–8/10), mas deixa espaço para os outros papéis.
- **Escudeiro/Guardião/Sentinela/Campeão, mais Vida e DEF:** tanque de verdade (5–6 golpes de um atacante do mesmo
  nível). Perdem duelos; ganham pela Muralha de Escudos (+35% própria, +15% aos adjacentes), pelo Preparar Lanças
  (+50% contra montados) e pela aura do Campeão (+20%).
- **Cavalaria, +2/+4/+4 PP e o Cavaleiro com DEF 4 (abaixo do Guerreiro):** mobilidade 4 e Carga (×1,5) valem mais que
  4 PP; "é mobilidade, não atributo" (intenção de design protegida por teste). O Grifo ficou 5 PP mais barato e ganhou
  Vida/ATQ, porque voar com +25% de vulnerabilidade a tiros o deixava atrás das outras Lendárias.
- **Ladino, ATQ logo abaixo do Guerreiro de cada nível (7 / 10 / 14 / 17,5) e um pouco mais de Vida:** a intenção
  original (protegida por teste) é "não vence pelo ataque básico". O valor dele é o Ataque Furtivo (×1,35, ignora 40% da
  DEF, sem revide), Desmantelar (+50% contra conjurador/cerco), mobilidade 3 e infiltração. No duelo direto do modelo,
  que não vê técnica, ele perde 7–9 de 10, de propósito. Uma primeira versão desta rodada deixou o ATQ dele acima do
  Guerreiro; os testes de intenção apontaram, e voltou.
- **Colosso de Cerco, ATQ/DEF abaixo do ×1,5:** com alcance 3 e 44 de Vida vencia 10/10 em campo aberto. O lugar dele é
  contra cidade (×1,5 de cerco, Munição Demolidora).

Resultado no modelo de duelo (vitórias de 10, mesmo nível):

| Nível | Tanque | Guerreiro | Patrulheiro | Cavalaria | Ladino | Cerco |
|---|---|---|---|---|---|---|
| N3 | 3 | 8 | 5 | 7 | 2 | 1 |
| N5 | 4 | 8 | 6 | 8 | 1 | 1 |
| N7 | 4 | 8 | 4 | 7 | 3 | 2 |
| N9 | 3 | 8 | 5 | 5 | 1 | 4 |

Antes, a linha do Guerreiro tinha 9–10 em todos os níveis. O Ladino fica baixo **de propósito**: o modelo não vê o
Ataque Furtivo, que é a arma dele. O tanque fica baixo porque o papel dele é aguentar, não vencer duelo.

### Monstros e cidades

- **Monstros:** ATQ e DEF ×1,5 (as 13 espécies), mesma regra das unidades. A ameaça relativa da ecologia V3 fica igual;
  só a luta fica mais rápida. Chefe de covil continua ×2,5 Vida e ×1,3 ATQ.
- **Ataque das fortificações:** 3 / 5 / 7 → **4,5 / 7,5 / 10,5** (é dano fixo, sem Defesa: acompanha o ×1,5).
- **Vida das cidades:** 24 / 30 / 36 / 44 → **30 / 38 / 46 / 56** (×1,25). O cerco fica só ~1,2× mais rápido (dano ×1,5 ÷
  Vida ×1,25), para a conquista andar sem tornar fácil o rush na capital do começo.

## 6. Magia — antes → depois

### Mecânica nova: preço em Vida (`V2SpellData.health_cost_fraction`)

Fração da Vida **máxima** do conjurador paga a cada conjuração, junto com a mana. O feitiço fica indisponível se a Vida
atual não bastar ("Vida insuficiente: o feitiço custa N de Vida."). **Nunca mata.** O botão mostra "— 34 Mana + 4 Vida",
e o tooltip explica a regra. É cobrado sem reação de dano e sem passar pela Barreira Arcana (é um preço pago, não um
golpe). Código: `V2MagicRuntime.health_cost` / `_pay_health`; a IA respeita sozinha, porque usa o mesmo
`unavailable_reason`.

### Escala de custos

Renda de mana de referência: ~2/turno no início, 4–6 no turno 100–150 para a IA (mais para quem investe em
Santuários), 6–10 para quem foca magia.

| Faixa | Mana | Ideia |
|---|---|---|
| Básico (N4) | 4–6, sem recarga | sustentável: o "ataque" do conjurador, um por turno |
| Intermediário/avançado (N5–N6) | 8–18 | 1–3 turnos de renda |
| Maior (N7), o "quebrado" | 24–36 | 4–6 turnos de renda; os de dano também custam 35% da Vida |

| Escola | Feitiço | Antes | Depois |
|---|---|---|---|
| Sagrada | Luz Restauradora | 4 mana, cura 8 | 5 mana, **cura 12** |
| Sagrada | Égide Sagrada | 6 mana, +35% DEF | 8 mana, **+40% DEF** |
| Sagrada | Onda de Cura | 9 mana, cura 6 em raio 1 | 16 mana, **cura 12 em raio 1** |
| Sagrada | **Milagre** | 16 mana, cura total de 1 alvo, recarga 5 | **36 mana, cura total do alvo E de todos os aliados adjacentes**, recarga 5 (o teto de recarga dos feitiços é 5, invariante) |
| Infernal | Chama Infernal | 5 mana, 6 de dano | 6 mana, **9 de dano** |
| Infernal | Fogo Voraz | 8 mana, 8 (+50% abaixo de 50% de Vida) | 12 mana, **13** (+50%) |
| Infernal | Explosão Infernal | 11 mana, 5 em raio 1 | 18 mana, **9 em raio 1** |
| Infernal | **Condenação** | 18 mana, 15 de dano | **34 mana + 35% da Vida, 32 de dano** (mata qualquer N5 e quase todo N7; com o Arquidemônio, 40) |
| Necromancia | Erguer Mortos | 7 mana | 10 mana (Hoste 18/6/4,5 ≈ um Guerreiro) |
| Necromancia | Recompor Ossos | 6 mana, cura 8 | 6 mana, **cura 12** |
| Necromancia | Comando Macabro | 7 mana, +40% ATQ | 9 mana, **+50% ATQ** |
| Necromancia | Erguer Legião | 15 mana, recarga 4 | **30 mana**, recarga 5 (Hoste 30/10,5/7,5 ≈ N5–N7 de graça) |
| Druidismo | Brotar Bosque / Restaurar Terreno | 6 / 5 mana | 5 / 4 mana |
| Druidismo | Erguer Terreno / Despertar a Mata | 9 / 16 mana | 12 / 24 mana |
| Arcanismo | Passo Arcano / Silêncio / Dissipar / Portal do Véu | 6 / 8 / 7 / 18 | 6 / 10 / 9 / 26 |
| Elementalismo | Névoa Cerrada / Vendaval | 6 / 8 | 5 / 9 |
| Elementalismo | Tempestade Elétrica | 12 mana, 4/rodada | 18 mana, **6/rodada** |
| Elementalismo | **Cataclismo Elemental** | 20 mana, 5/rodada em raio 2 | **36 mana + 35% da Vida, 10/rodada em raio 2** (+ visão −1, tiro físico ×0,8) |

**Atenção ao Cataclismo e à Tempestade:** a zona atinge **todos** no raio, aliados inclusive (regra antiga, não mudou).
Com 10 de dano por rodada, um Elementalista (11 de Vida, já pagando 35% para conjurar) que lance o Cataclismo com ele
mesmo dentro do raio 2 **morre** na segunda rodada. É o preço brutal pedido; a IA e o jogador precisam lançar de longe
(alcance 5).

Os números de dano/cura subiram ~×1,5, como o dano físico, para a magia não ficar para trás. Os quatro feitiços N7
das escolas de impacto (Milagre, Condenação, Erguer Legião, Cataclismo) foram empurrados para "quebrado com preço".
Druidismo e Arcanismo são controle/utilidade, então só os custos foram ajustados.

## 7. Ritmo (macro)

| Alavanca | Antes | Depois | Por quê |
|---|---|---|---|
| Pesquisa N5–N9 das Doutrinas e Escolas | 40/80/128/196/268 | 36/60/92/132/180 | os últimos níveis eram ~80% do custo da linha |
| Exército Supremo / Transcendência | 400 | 280 | capstones |
| Infraestrutura II/III | 48/120 | 40/96 | |
| Produção-base por cidade | 4 | 5 | o caminho arcano travava em produção |
| Conhecimento-base por cidade | 2 | 3 | o início quase não tem Academias |
| Projeto de nível de cidade II/III/IV | 60/120/220 PP (+30/70/140 Ouro) | 45/90/165 PP (+25/55/110 Ouro) | 27% dos rivais não tinham cidade III+ capturável |
| Estrutura Ritual | 60 PP | 48 PP | gargalo de produção da Transcendência |

Uma linha completa de Doutrina/Escola caiu de 780 para 568 de Conhecimento. O mínimo matemático da pesquisa de vitória
(2 linhas + capstone) caiu de 1.960 para **1.416**.

## 8. Resultado no laboratório (4 IAs, mapa Grande, limite 240)

Mesmo seed set e harness do baseline F33B (`BalanceSeedSet`, 4 IAs pelas mesmas regras), mapa Grande 128×72.
Execuções: `pretune1014/pre` (12 partidas, código de 14/10 antes da rodada) e `balance1014/post2` (16 partidas, pacote
completo). O `post2` rodou antes do último ajuste fino de papel (Ladino com ATQ abaixo do Guerreiro, Cavaleiro DEF 4,
recarga do Milagre de volta a 5); são mudanças de unidade isolada, que não movem o ritmo macro. Há uma intermediária, `balance1014/post1`, sem a redução de Manifestação/Estrutura Ritual. Dados em
`user://balance/<run>/<tag>/` (não versionados).

| Medida (mediana) | Antes | Depois |
|---|---|---|
| Vitórias / partidas | 7 / 12 | **13 / 16** |
| Sem vencedor no T240 | 5 / 12 (42%) | **3 / 16 (19%)** |
| Turno da vitória | ~217 (172–238) | **200 (178–240)** |
| Pesquisa da Transcendência pronta | T185 | **T144** |
| Pesquisa do Exército Supremo pronta | T177 | **T144** |
| Cidade nível III / IV | T118 / T192 | **T76 / T149** |
| 1ª Grande Manifestação | T185 | **T162** |
| Ritual pronto | T223 | **T200** |

**Leitura.** Os valores fizeram o que valores podem fazer: a pesquisa de vitória chega ~40 turnos antes e as cidades
desenvolvidas também. O que segura as partidas de IA contra IA perto do T200 é a **execução da IA**:

- Transcendência: depois da pesquisa pronta, foram **394 turnos** (somados entre civs) com a Estrutura Ritual
  construível e as cidades ocupadas com outra coisa, e **298** com uma cidade **ociosa** que não a escolheu.
- Supremacia: as civs com o Exército Supremo pesquisado fazem mediana de **0 capturas qualificadas**. Elas quase não
  vão à guerra para fechar a condição.
- Mana virou limite de verdade (como pedido): 50 turnos de Ritual "aguardando mana", contra 2 no baseline. Os feitiços
  agora competem com o Ritual pelo mesmo estoque.

**Para um jogador humano** (não tem essas ineficiências e expande antes: a IA tem 2 cidades no T100), a pesquisa de
vitória fica pronta por volta do T110–130. Somando as duas Manifestações (~13 turnos cada, em paralelo) e o Ritual (4
rodadas), ou as capturas de cidades nível III que agora existem mais cedo, a vitória cai em ~T125–145. Isso dá
**~3,1–4,8 h** a 1,5–2 min por turno. A ponta lenta só sai da meta se o turno médio passar de ~1,7 min; a medição humana
real (§10) decide se vale cortar mais pesquisa.

## 9. Testes

Suíte GUT completa depois da rodada: **4.149 de 4.162** passando.

- **Teste novo:** `test/unit/test_spell_health_cost.gd` (6 testes). Cobre: só Condenação e Cataclismo custam Vida; o preço
  é pago no cast de alvo e de tile; sem Vida bastante, nada é gasto; o botão e o tooltip mostram o preço; o Milagre cura
  o alvo e o vizinho.
- **~90 arquivos atualizados**, quase todos fixações dos números provisórios (atributos, custos, textos de botão, danos
  calculados à mão). Onde o teste protegia uma **intenção**, ela foi mantida:
  - Ladino abaixo do Guerreiro no ataque básico: o valor foi corrigido, não o teste.
  - Cavaleiro com menos DEF que o Guerreiro: idem.
  - Recarga ≤ 5 em todo feitiço: idem.
  - "O tanque não vira DPS": passou a comparar com a linha de dano V2 do mesmo nível, em vez do Homem de Armas V1, que
    saiu do jogo e não escalou.
- **Comportamentos que mudaram de verdade e foram aceitos**, com o motivo no próprio teste:
  - O Trebuchet pode capturar a cidade com o ataque básico.
  - A Explosão mata a Hoste ferida pela Chama.
  - O Bombardeio quebra o escudo inteiro da Fortaleza.
  - Um abate no meio do Ataque em Arco dá veterania ao Herói (o teste passou a evitar o abate, para medir só a Execução).
  - O Cataclismo mata o próprio conjurador dentro do raio.
- **Cenários de defesa de cidade contra monstros:** a guarnição deles era o Guarda V1, que não escalou, contra monstros
  que escalaram. Passou a ser o Guerreiro V2, a guarnição real do jogo.
- **Dois testes antigos que falhavam por outro motivo**, corrigidos na janela do teste (sem mexer no jogo):
  - Minimapa "contínuo": a janela fixa pegava a borda do mapa depois do enquadramento novo de 13/10.
  - Obra concluída: contava a obra legítima da IA rival como resto.

Falhas restantes (13), nenhuma desta rodada:

- 7 antigas e conhecidas: assets KayKit apagados, escalas provisórias do Ladino e do Cerco, marcador de melhoria,
  rótulos da página Vídeo.
- 6 da reforma de covis regionais que estava em andamento em paralelo (`docs/UNIFIED_MONSTER_LAIRS.md`):
  - textos "Chefe" → "Líder do covil" no inspetor (`test_hud_inspection`, `test_tile_inspector` ×2);
  - `test_phase33d2_world`;
  - os fluxos da Cavalaria e do Ladino, que não encontram mais "um pedaço remoto do mapa para a arena". Ambos passavam
    com esta rodada antes da mudança de mapa/covis.

## 10. Próximos passos (fora desta rodada)

- **Execução da IA:** com a pesquisa pronta, a IA quase não captura cidades (mediana 0 capturas) e deixa a Estrutura
  Ritual de lado com cidades ociosas. Isso é decisão da IA (`RivalAI.decide_war`, `WAR_DECLARE_CHANCE_WHEN_READY` 0,2,
  prioridade de produção em `V2StrategicAI._plan_production`), não número de unidade. É o que ainda segura as partidas
  de IA contra IA acima de 150 turnos. Merece uma rodada própria, validada no laboratório, porque muda decisões.
- **Expansão da IA:** 2 cidades no turno 100 (mediana). Um humano expande antes, e é por isso que a meta de 3–4 h é
  realista para o jogador, mas não para a IA hoje.
- **Medição humana:** a conversão turno → minutos ainda é estimativa (1,5–2 min). `HumanTimingTelemetry` (ver baseline
  §18) mede de verdade.

# Aetherlands — Árvore de Magia, Grimório e Condições de Vitória

> **Status:** Design V1 / Direção conceitual  
> **Escopo:** Árvore de Magia, escolas mágicas, conjuradores, criaturas, feitiços, Grandes Feitiços, Grandes Rituais, Grimório, Vitória de Supremacia e Vitória por Transcendência.

---

# 1. Status e intenção deste documento

Este documento define a **direção conceitual V1** para os sistemas mágicos de Aetherlands.

Ele **não deve ser tratado como uma especificação absolutamente imutável**.

Durante a implementação, o responsável pelo desenvolvimento pode:

- alterar nomes;
- ajustar valores;
- mudar custos;
- alterar ordem de pesquisas;
- substituir uma habilidade por outra;
- adaptar pré-requisitos;
- simplificar mecânicas excessivamente complexas;
- fortalecer ou enfraquecer efeitos;
- reaproveitar sistemas existentes;
- mudar detalhes caso uma proposta se revele pouco divertida;
- modificar algo caso quebre o balanceamento;
- modificar algo caso a arquitetura existente permita uma solução claramente melhor;
- remover redundâncias;
- melhorar ideias deste documento.

A prioridade é:

> **Preservar a intenção de design, não obedecer literalmente cada número ou nome deste documento.**

Qualquer adaptação substancial deve continuar preservando:

1. identidade distinta entre as escolas;
2. diferença clara entre Tecnologia e Magia;
3. fragilidade dos conjuradores;
4. alto potencial da magia;
5. preparação necessária para poderes extremos;
6. possibilidade de misturar tropas tecnológicas e mágicas;
7. counterplay;
8. integração com IA;
9. duração-alvo de aproximadamente 3–4 horas;
10. Grandes Rituais como acontecimentos importantes no mapa.

---

# 2. Filosofia geral

Tecnologia e Magia representam formas diferentes de poder.

## 2.1 Tecnologia

Tecnologia representa:

- organização;
- infraestrutura;
- indústria;
- tropas;
- fortificação;
- comércio;
- logística;
- produção;
- domínio material;
- capacidade de guerra convencional.

Seu poder deve ser:

- confiável;
- relativamente barato;
- relativamente rápido de produzir;
- resistente;
- simples de utilizar;
- fácil de substituir;
- escalável em quantidade.

Um jogador tecnológico consegue colocar muitas unidades úteis no mapa sem precisar de preparação arcana complexa.

---

## 2.2 Magia

Magia representa:

- conhecimento sobrenatural;
- estudo;
- manipulação das regras naturais;
- criaturas mágicas;
- fenômenos impossíveis;
- feitiços;
- rituais;
- transformação territorial;
- poderes de escala extraordinária.

Seu poder deve ser:

- mais alto;
- mais especializado;
- mais caro;
- mais lento;
- mais dependente de infraestrutura;
- mais dependente de Mana;
- mais vulnerável a interrupção.

Magia **não precisa possuir o mesmo teto de poder da Tecnologia**.

É aceitável e desejável que magia avançada seja muito mais poderosa.

O equilíbrio não deve vir de:

> Guerreiro = Mago.

O equilíbrio deve vir de:

> **Guerreiros são numerosos, resistentes, simples e confiáveis.**

versus

> **Magos são raros, frágeis, demorados e capazes de coisas extraordinárias.**

---

# 3. Composição de exércitos

O jogo não deve incentivar uma divisão rígida entre:

- "exército tecnológico";
- "exército mágico".

A composição normal deve poder misturar ambos.

Exemplo:

```text
Homens de Escudo
Espadachins
Besteiros
Cavalaria

+

Clérigo
Elementalista
Arcanista
```

As tropas mundanas protegem os conjuradores.

Os conjuradores oferecem:

- cura;
- controle;
- mobilidade;
- dano em área;
- invocações;
- utilidade;
- manipulação do mapa.

Uma Cavalaria inimiga que consegue atravessar a linha de frente e alcançar diretamente os magos deve representar uma ameaça séria.

---

# 4. Regra geral dos conjuradores

Conjuradores são, em princípio, **glass cannons e supports**.

Como baseline inicial:

| Atributo | Conjurador vs. tropa mundana equivalente |
|---|---:|
| HP | ~55–65% |
| Defesa | ~60–75% |
| Tempo de treinamento | ~150–200% |
| Ataque básico | ~70–100% |
| Poder das habilidades | Muito superior |
| Manutenção em Mana | Possível / frequente |
| Facilidade de reposição | Baixa |

Esses números são provisórios.

O princípio é mais importante:

> Um mago não deve ser extraordinário porque seu ataque básico possui números absurdos.

Ele deve ser extraordinário porque **consegue realizar ações que uma unidade convencional não consegue**.

---

# 5. Criaturas mágicas não precisam ser frágeis

A fragilidade se aplica principalmente aos **conjuradores humanoides**.

Criaturas mágicas podem assumir papéis resistentes.

Exemplos:

- Ent;
- Golem Arcano;
- Guardião Sepulcral;
- Demônios;
- Elementais.

Entretanto, criaturas mágicas resistentes precisam ser limitadas através de uma combinação de:

- custo alto;
- Mana;
- manutenção;
- limite por conjurador;
- cooldown;
- infraestrutura;
- tempo de produção;
- invocação;
- duração temporária.

Magia não deve conseguir simplesmente produzir dezenas de tanques mágicos baratos.

---

# 6. Relação entre pesquisa tecnológica e mágica

A direção preferencial é que Tecnologia e Magia disputem **a mesma capacidade principal de pesquisa**.

O jogador deve poder enfrentar decisões como:

> "Pesquiso Cavalaria Pesada ou aprofundo minha Necromancia?"

Mana deve representar principalmente:

> **combustível para utilizar magia.**

Pesquisa representa:

> **tempo e conhecimento necessários para aprendê-la.**

Caso a arquitetura existente torne outra solução claramente superior, pode-se adaptar, mas deve continuar existindo **custo de oportunidade real** entre investir fortemente em Tecnologia e investir fortemente em Magia.

---

# 7. Estrutura geral da Árvore de Magia

A proposta V1 utiliza:

- **6 escolas mágicas**;
- **9 níveis próprios por escola**;
- **1 nível final universal de Transcendência**.

Estrutura conceitual:

```text
N1  Escola
 ↓
N2  Prédio da escola
 ↓
N3  Conjurador básico
 ↓
N4  Feitiço básico
 ↓
N5  Feitiço característico
 ↓
N6  Unidade / criatura / poder avançado
 ↓
N7  Grande Feitiço
 ↓
N8  Estrutura Ritual
 ↓
N9  Grande Ritual

        ↓

N10 — TRANSCENDÊNCIA
```

Total conceitual:

**6 × 9 + 1 = 55 pesquisas.**

Esse número não precisa ser preservado se durante a implementação outro total produzir um sistema melhor.

---

# 8. Progressão por escola

Cada escola possui sua própria progressão.

Para pesquisar:

> Necromancia Nível 5

é necessário possuir:

> Necromancia Nível 4.

Entretanto, o jogador é livre para iniciar outras escolas.

Exemplo:

```text
Necromancia 5
Arcanismo 3
Sagrada 2
```

Isso representa uma civilização mágica diversificada.

Uma civilização especializada pode aprofundar fortemente uma escola antes de estudar outras.

---

# 9. As seis escolas

| Escola | Identidade mecânica principal |
|---|---|
| **Sagrada** | Cura, proteção, purificação |
| **Artes Infernais** | Burst, sacrifício, risco/recompensa, demônios |
| **Necromancia** | Invocação, mortos-vivos, maldição, guerra de atrito |
| **Druidismo** | Terreno físico, ocultação, bloqueio territorial |
| **Arcanismo** | Teleporte, Mana, anti-magia, espaço |
| **Elementalismo** | Área, clima, hazards, destruição ambiental |

Esses domínios devem ser mantidos claros.

Exemplos:

- Druidismo não deve virar outra escola de cura;
- Sagrada não deve possuir os melhores teleportes;
- Arcanismo não deve possuir o melhor dano em área;
- Elementalismo não deve invocar exércitos melhor que Necromancia;
- Necromancia não deve substituir controle geográfico Druídico;
- Infernal não deve ser apenas "Elementalismo vermelho".

Pode existir alguma sobreposição, mas o **motivo estratégico para pesquisar cada escola deve continuar distinto**.

---

# 10. Escola Sagrada

## 10.1 Identidade

A Escola Sagrada domina:

- cura;
- purificação;
- proteção;
- bênçãos;
- sustentação do exército.

Ela deve ser a principal fonte de **cura direta eficiente** entre as escolas.

---

## Nível 1 — Doutrina Sagrada

**Tipo:** Escola

Abre a progressão Sagrada.

Representa o conhecimento inicial necessário para estudar magia divina.

---

## Nível 2 — Igreja da Luz

**Tipo:** Prédio

Permite treinar conjuradores da Escola Sagrada.

Funções possíveis:

- treinar Clérigos;
- posteriormente treinar Hierofantes;
- pequena geração de Mana, caso isso faça sentido no sistema econômico.

---

## Nível 3 — Clérigo Sagrado

**Tipo:** Unidade

Conjurador básico.

Características:

- HP baixo;
- defesa baixa;
- ataque ranged;
- ataque luminoso básico relativamente fraco.

Sua importância aparece principalmente após pesquisar os feitiços da escola.

---

## Nível 4 — Cura Sagrada

**Tipo:** Feitiço tático

Requer um conjurador Sagrado.

Efeito inicial sugerido:

- alvo aliado em alcance curto/médio;
- recupera aproximadamente 20–30% do HP máximo;
- cooldown aproximado de 3 turnos;
- custo de Mana.

O valor deve impedir cura infinita sem custo.

---

## Nível 5 — Purificação

**Tipo:** Feitiço tático

Pode:

- remover maldição de uma unidade;
- remover debuffs mágicos;
- limpar corrupção de um tile;
- combater efeitos de Necromancia;
- combater efeitos Infernais.

Seu principal valor é **remover condições negativas**, não simplesmente curar mais.

---

## Nível 6 — Hierofante

**Tipo:** Unidade avançada

Conjurador Sagrado avançado.

Características:

- continua frágil;
- melhor eficiência de Mana;
- maior alcance mágico;
- acesso eficiente às magias Sagradas;
- possível pequena proteção passiva para aliados próximos.

Não deve se transformar em tanque.

---

## Nível 7 — Domínio Consagrado

**Tipo:** Grande Feitiço

Seleciona uma pequena região.

Duração inicial sugerida:

**5 turnos.**

Enquanto ativo:

- maldições existentes são removidas;
- tropas aliadas reduzem ou ignoram penalidades de terreno;
- tropas aliadas recebem pequena regeneração;
- debuffs mágicos têm duração reduzida;
- mortos-vivos e demônios inimigos podem receber penalidades.

Usos:

- defender uma cidade;
- sustentar uma ofensiva;
- atravessar terreno difícil;
- combater Necromancia.

---

## Nível 8 — Grande Catedral

**Tipo:** Prédio Ritual

Estrutura avançada.

Necessária para o Grande Ritual Sagrado.

Sua destruição deve impedir ou interromper o ritual.

---

## Nível 9 — Aurora Divina

**Tipo:** Grande Ritual

Não invoca uma criatura.

Requisitos iniciais sugeridos:

- Grande Catedral;
- 4–5 conjuradores Sagrados;
- grande reserva de Mana;
- aproximadamente 6–8 turnos de canalização.

Quando concluída, seleciona uma região ampla.

Durante aproximadamente 8–10 turnos:

- maldições são removidas;
- unidades aliadas recuperam HP por turno;
- recebem resistência a efeitos mágicos negativos;
- ignoram grande parte das penalidades do terreno;
- mortos-vivos e demônios inimigos são enfraquecidos;
- novas maldições têm eficiência reduzida.

A Aurora Divina é um ritual de **sustentação estratégica massiva**.

---

# 11. Artes Infernais

## 11.1 Identidade

Artes Infernais representam:

- poder imediato;
- destruição;
- sacrifício;
- risco;
- demônios;
- recompensa proporcional ao perigo.

Diferença principal:

> **Infernal = burst + risco + sacrifício.**

> **Elementalismo = área + clima + persistência.**

---

## Nível 1 — Artes Infernais

**Tipo:** Escola

Abre a linha Infernal.

---

## Nível 2 — Altar Abissal

**Tipo:** Prédio

Permite treinar:

- Cultistas;
- posteriormente Bruxos Infernais.

---

## Nível 3 — Cultista Infernal

**Tipo:** Unidade

Características:

- muito frágil;
- ranged;
- ataque mágico básico;
- potencial ofensivo superior ao de suportes;
- péssimo corpo a corpo.

---

## Nível 4 — Fogo Infernal

**Tipo:** Feitiço ofensivo

Ataque de burst.

Proposta:

- alvo principal recebe dano alto;
- pequena quantidade de splash;
- cooldown aproximado de 3 turnos;
- custo relevante de Mana.

Elementalismo deve continuar superior em **grandes áreas**.

---

## Nível 5 — Pacto de Sangue

**Tipo:** Feitiço de risco/recompensa

O conjurador sacrifica parte do próprio HP.

Exemplo:

- perde 25–35% do HP atual;
- próximo feitiço Infernal recebe grande amplificação;
- ou recebe redução significativa de custo;
- efeito expira após poucos turnos.

Isso cria potencial de burst enquanto deixa o conjurador vulnerável.

---

## Nível 6 — Bruxo Infernal

**Tipo:** Unidade avançada

Especializado em:

- dano;
- pactos;
- manipulação demoníaca.

Continua frágil.

Pode possuir eficiência superior no controle de criaturas demoníacas.

---

## Nível 7 — Chuva de Enxofre

**Tipo:** Grande Feitiço

Seleciona região pequena/média.

Duração aproximada:

**3–4 turnos.**

Na área:

- unidades recebem dano periódico;
- terrenos podem incendiar;
- agrupamentos ficam perigosos;
- permanecer na região é arriscado.

Possui mais intensidade imediata que o equivalente Elemental, mas menor duração/escala.

---

## Nível 8 — Portal Abissal

**Tipo:** Prédio Ritual

Necessário para o Grande Ritual Infernal.

É uma estrutura importante e perigosa.

---

## Nível 9 — Manifestação do Arquidemônio

**Tipo:** Grande Ritual

Requisitos iniciais:

- Portal Abissal;
- 4–5 conjuradores Infernais;
- grande quantidade de Mana;
- aproximadamente 6–8 turnos.

Quando concluído:

surge um **Arquidemônio**.

O Arquidemônio não é simplesmente uma unidade comum entregue ao jogador.

Ele funciona como:

> **boss alinhado ao invocador, controlado por IA própria.**

O jogador escolhe uma cidade ou região inimiga como objetivo.

O Arquidemônio:

- avança até o alvo;
- combate tropas;
- possui ataques em área;
- pode invocar demônios menores;
- fortalece demônios próximos;
- tenta destruir ou devastar seu objetivo.

Deve ser possível derrotá-lo.

---

# 12. Necromancia

## 12.1 Identidade

Necromancia é a escola de:

- invocação;
- mortos-vivos;
- quantidade;
- guerra de atrito;
- maldição;
- utilização de criaturas para proteger o conjurador.

O Necromante em si continua frágil.

Seu exército é sua proteção.

---

## Nível 1 — Necromancia

**Tipo:** Escola

Abre a linha.

---

## Nível 2 — Cripta dos Sussurros

**Tipo:** Prédio

Permite treinar Necromantes.

---

## Nível 3 — Necromante

**Tipo:** Unidade

Características:

- HP baixo;
- defesa baixa;
- ranged;
- dano básico moderado/baixo;
- vulnerável quando alcançado.

---

## Nível 4 — Solo Amaldiçoado

**Tipo:** Feitiço territorial

Seleciona pequeno grupo de tiles.

Duração aproximada:

**4 turnos.**

Efeito:

- tropas inimigas vivas recebem dano periódico ou penalidade;
- mortos-vivos ignoram ou reduzem o efeito;
- terreno recebe representação visual clara.

Diferença para Druidismo:

> Druidismo altera **geografia e movimento**.

> Necromancia cria **zonas de corrupção e atrito**.

---

## Nível 5 — Erguer os Mortos

**Tipo:** Feitiço / habilidade desbloqueada

Cada Necromante pode:

- invocar 1 Esqueleto;
- cooldown aproximado de 4 turnos;
- custo de Mana;
- manter no máximo **3 Esqueletos próprios**.

Esqueletos são:

- fracos;
- descartáveis;
- úteis para cercar;
- úteis para absorver ataques;
- úteis para proteger Necromantes.

---

## Nível 6 — Guardião Sepulcral

**Tipo:** Invocação avançada

Desbloqueia criatura morta-viva pesada.

Características:

- HP alto;
- defesa alta;
- lento;
- dano moderado;
- função principal de proteção.

Limite sugerido:

**máximo 1 por Necromante.**

---

## Nível 7 — Legião dos Mortos

**Tipo:** Grande Feitiço

Seleciona região válida.

Invoca temporariamente uma pequena força morta-viva.

Exemplo:

- 3–5 unidades;
- combinação de Esqueletos e mortos-vivos superiores;
- duração temporária ou manutenção elevada em Mana;
- cooldown longo.

Não deve substituir completamente produção militar convencional.

---

## Nível 8 — Mausoléu Negro

**Tipo:** Prédio Ritual

Necessário para o Grande Ritual Necromântico.

---

## Nível 9 — Ascensão do Lich Ancião

**Tipo:** Grande Ritual

Requisitos conceituais:

- Mausoléu Negro;
- aproximadamente 5 Necromantes;
- grande reserva de Mana;
- aproximadamente 8–10 turnos de canalização.

Quando concluído:

surge o **Lich Ancião** próximo da região escolhida.

O Lich funciona como boss aliado controlado por IA.

Pode manter aproximadamente:

**10 mortos-vivos.**

Comportamento:

- escolhe cidade inimiga como objetivo;
- produz/reanima aproximadamente 1 morto-vivo a cada 2 turnos quando abaixo do limite;
- manda a horda avançar;
- mantém parte da horda próxima para proteção;
- amaldiçoa terreno;
- possui ataque ranged mágico;
- possui ataque defensivo em área;
- evita entrar sozinho em melee quando possível.

O Lich não deve possuir resistência absurda.

Sua principal força é:

> **ser um general mágico acompanhado por uma horda.**

---

# 13. Druidismo

## 13.1 Identidade

Druidismo é a escola de **controle territorial físico**.

Não deve ser uma segunda escola de cura.

Seu domínio é:

- floresta;
- relevo;
- ocultação;
- corredores;
- bloqueio de movimento;
- criaturas naturais;
- manipulação física do mapa.

---

## Nível 1 — Druidismo

**Tipo:** Escola

Abre a linha.

---

## Nível 2 — Círculo Druídico

**Tipo:** Prédio

Permite treinar Druidas.

---

## Nível 3 — Druida

**Tipo:** Unidade

Características:

- frágil;
- ranged;
- ataque natural básico;
- especializado em manipulação territorial.

---

## Nível 4 — Floresta Súbita

**Tipo:** Feitiço territorial

Seleciona tile elegível.

O tile se transforma temporariamente em floresta.

Duração inicial:

**5 turnos.**

Efeitos possíveis:

- aumenta custo de movimento inimigo;
- interfere em linha de visão;
- Druidas e criaturas naturais reduzem essas penalidades.

Não pode ser utilizado sobre:

- cidades;
- Ocean;
- Lava;
- tiles incompatíveis;
- posições que quebrem o mapa.

---

## Nível 5 — Flores do Véu

**Tipo:** Feitiço de ocultação territorial

Cria pequena região de vegetação/floração mágica.

Duração:

**4–5 turnos.**

Unidades aliadas dentro dela:

- ficam ocultas à visão normal a distância;
- tornam-se visíveis caso inimigo fique adjacente;
- tornam-se visíveis ao atacar;
- podem ser reveladas por futuros sistemas de detecção.

Usos:

- emboscadas;
- proteção de magos;
- ocultação de movimentação;
- preparação de ataques.

---

## Nível 6 — Invocar Fera do Bosque

**Tipo:** Invocação

Cria uma criatura controlável.

Exemplo conceitual:

**Fera do Bosque**

Pode ser:

- urso mágico;
- besta chifruda;
- criatura original de Aetherlands.

Características:

- melee;
- HP razoável;
- dano alto/moderado;
- movimentação eficiente em floresta;
- custo/manutenção em Mana.

Limite inicial sugerido:

**1 Fera ativa por Druida.**

---

## Nível 7 — Erguer Cordilheira

**Tipo:** Grande Feitiço territorial

Seleciona aproximadamente:

**2–3 tiles terrestres adjacentes válidos.**

Durante aproximadamente:

**4 turnos**

eles se tornam montanhas/elevações mágicas.

Efeitos:

- tropas terrestres comuns não atravessam;
- bloqueia corredores;
- pode bloquear linha de visão;
- divide exércitos;
- cria gargalos;
- protege cidades.

Não pode ser utilizado:

- sobre cidades;
- sobre unidades;
- em Ocean;
- em Lava;
- sobre posições incompatíveis;
- de maneira que corrompa o mapa.

---

## Nível 8 — Coração da Terra Viva

**Tipo:** Prédio Ritual

Estrutura necessária para o Grande Ritual Druídico.

---

## Nível 9 — Domínio da Terra Viva

**Tipo:** Grande Ritual

O Grande Ritual Druídico deve representar a forma máxima de **controle territorial**.

Seleciona uma região ampla válida.

Exemplo inicial:

**raio aproximado de 4 tiles em torno de um centro.**

Durante aproximadamente:

**8–10 turnos**

a região é remodelada.

Possíveis efeitos:

- terrenos abertos elegíveis viram floresta;
- algumas bordas estratégicas recebem montanhas temporárias;
- áreas recebem Flores do Véu;
- movimento inimigo fica severamente prejudicado;
- unidades Druídicas e criaturas naturais atravessam com maior facilidade;
- corredores militares são alterados;
- o inimigo precisa contornar ou lutar em terreno favorável ao Druida.

Quando o ritual termina:

- montanhas artificiais desaparecem;
- Flores do Véu desaparecem;
- parte das florestas pode permanecer permanentemente se isso for seguro para o mapa.

O objetivo é:

> **redesenhar temporariamente a geografia de uma guerra inteira.**

Não é cura.

Não é um boss.

Não é apenas um modificador percentual.

---

# 14. Arcanismo

## 14.1 Identidade

Arcanismo representa:

- espaço;
- teleporte;
- Mana;
- anti-magia;
- manipulação das próprias regras mágicas.

É a escola do **cientista arcano**.

---

## Nível 1 — Arcanismo

**Tipo:** Escola

Abre a linha.

---

## Nível 2 — Torre Arcana

**Tipo:** Prédio

Permite treinar Arcanistas.

---

## Nível 3 — Arcanista

**Tipo:** Unidade

Conjurador frágil.

Características:

- ranged;
- ataque básico moderado/baixo;
- alto valor utilitário.

---

## Nível 4 — Salto Arcano

**Tipo:** Feitiço de mobilidade

Teleporta:

- o próprio Arcanista;
- ou uma unidade aliada adjacente.

Distância inicial sugerida:

**até 3 tiles.**

Deve respeitar:

- tiles válidos;
- ocupação;
- fog/visibilidade conforme regras do jogo;
- limites do mapa.

Cooldown significativo.

---

## Nível 5 — Selo de Mana

**Tipo:** Feitiço anti-magia

Alvo:

conjurador inimigo.

Pode:

- impedir utilização de feitiços por 1–2 turnos;
- aumentar cooldowns;
- ou bloquear determinada recuperação de Mana.

Não impede necessariamente ataques básicos.

---

## Nível 6 — Golem Arcano

**Tipo:** Criatura / Constructo

Características:

- resistente;
- lento;
- caro;
- alta manutenção em Mana;
- bom protetor de Arcanistas.

É resistente porque não é um conjurador.

---

## Nível 7 — Portal de Campanha

**Tipo:** Grande Feitiço

Cria dois portais temporários entre posições válidas.

Duração:

**4–5 turnos.**

Durante esse período:

- uma quantidade limitada de unidades pode atravessar por turno;
- inimigos podem identificar/interagir com o portal caso o descubram;
- perder a âncora pode encerrar o efeito.

É mobilidade estratégica poderosa, porém limitada.

---

## Nível 8 — Obelisco de Convergência

**Tipo:** Prédio Ritual

Estrutura necessária para magia espacial de escala extrema.

---

## Nível 9 — Grande Convergência

**Tipo:** Grande Ritual

Permite transportar uma força militar inteira.

Requisitos:

- Obelisco;
- vários Arcanistas;
- Mana;
- canalização.

O jogador escolhe:

- origem;
- destino válido.

Quantidade inicial sugerida:

**6–10 unidades.**

O destino deve possuir âncora lógica, por exemplo:

- outro Obelisco;
- Nódulo Arcano controlado;
- estrutura apropriada.

Evitar teleporte completamente arbitrário sem counterplay.

Esse ritual deve possuir capacidade real de alterar uma guerra.

---

# 15. Elementalismo

## 15.1 Identidade

Elementalismo domina:

- dano em área;
- clima;
- hazards;
- controle destrutivo do campo;
- fenômenos naturais violentos.

Diferença:

> **Infernal = explosão, sacrifício e demônios.**

> **Elemental = área, persistência e ambiente.**

---

## Nível 1 — Elementalismo

**Tipo:** Escola

Abre a linha.

---

## Nível 2 — Conclave Elemental

**Tipo:** Prédio

Permite treinar Elementalistas.

---

## Nível 3 — Elementalista

**Tipo:** Unidade

Conjurador ofensivo frágil.

Ataque básico ranged.

---

## Nível 4 — Relâmpago Encadeado

**Tipo:** Feitiço ofensivo

O dano passa entre inimigos próximos.

Exemplo:

- alvo principal: 100%;
- segundo alvo: ~60%;
- terceiro alvo: ~35–40%.

Cooldown e Mana impedem spam.

---

## Nível 5 — Onda Glacial

**Tipo:** Feitiço de controle

Pequena área.

Causa:

- dano moderado;
- redução severa de movimento;
- possível redução de capacidade ofensiva por curto período.

Serve para controlar agrupamentos.

---

## Nível 6 — Elemental da Tempestade

**Tipo:** Criatura

Características:

- boa movimentação;
- dano em área limitado;
- manutenção em Mana;
- custo alto;
- resistência média.

---

## Nível 7 — Frente de Tempestade

**Tipo:** Grande Feitiço

Cria uma tempestade localizada.

Duração:

**4–6 turnos.**

Na área:

- movimento é prejudicado;
- ataques ranged podem receber penalidade;
- raios atingem unidades ocasionalmente;
- podem surgir hazards temporários.

Funciona como zona de negação.

---

## Nível 8 — Olho dos Quatro Ventos

**Tipo:** Prédio Ritual

Necessário ao ritual máximo da escola.

---

## Nível 9 — Cataclismo Elemental

**Tipo:** Grande Ritual

Seleciona região grande.

Durante aproximadamente:

**6–8 turnos**

fenômenos elementais atingem a área.

Podem incluir:

- tempestades;
- relâmpagos;
- incêndios;
- gelo;
- tremores;
- redução severa de movimento;
- danos periódicos.

Não deve funcionar como:

> "cause 500 de dano e termine".

O Cataclismo deve transformar a região em um **desastre ativo durante vários turnos**.

Cidades não devem simplesmente desaparecer sem counterplay.

---

# 16. Comparação das escolas

| Escola | Papel principal | Grande Ritual |
|---|---|---|
| **Sagrada** | Sustain / purificação | Aurora Divina |
| **Infernal** | Burst / risco | Manifestação do Arquidemônio |
| **Necromancia** | Invocações / atrito | Ascensão do Lich Ancião |
| **Druidismo** | Território / geografia | Domínio da Terra Viva |
| **Arcanismo** | Mobilidade / anti-magia | Grande Convergência |
| **Elementalismo** | AoE / clima | Cataclismo Elemental |

Mesmo após ajustes futuros, esta tabela deve continuar conceitualmente verdadeira.

---

# 17. Grimório

O Grimório **não é outra árvore de pesquisa**.

A Árvore de Magia responde:

> **O que minha civilização conhece?**

O Grimório responde:

> **O que minha civilização consegue conjurar agora?**

---

## 17.1 Categorias do Grimório

### Feitiços

Exemplos:

- Cura Sagrada;
- Fogo Infernal;
- Solo Amaldiçoado;
- Floresta Súbita;
- Salto Arcano;
- Relâmpago Encadeado.

### Grandes Feitiços

Exemplos:

- Domínio Consagrado;
- Chuva de Enxofre;
- Legião dos Mortos;
- Erguer Cordilheira;
- Portal de Campanha;
- Frente de Tempestade.

### Grandes Rituais

Exemplos:

- Aurora Divina;
- Manifestação do Arquidemônio;
- Ascensão do Lich Ancião;
- Domínio da Terra Viva;
- Grande Convergência;
- Cataclismo Elemental.

### Transcendência

Ritual final da rota mágica.

---

# 18. Feitiços e seleção de unidades

Quando determinado feitiço exigir um conjurador, a habilidade também deve aparecer na interface da própria unidade.

Exemplo:

Selecionar Necromante pode mostrar:

- ataque básico;
- Solo Amaldiçoado;
- Erguer os Mortos;
- Legião dos Mortos, quando aplicável.

O Grimório continua funcionando como:

- catálogo;
- gerenciamento;
- apresentação;
- acesso a poderes estratégicos;
- Grandes Feitiços;
- Grandes Rituais.

Evitar UX em que o jogador precise abrir uma tela separada para realizar toda pequena habilidade tática.

---

# 19. Grandes Rituais

Grandes Rituais precisam possuir estado persistente.

Modelo conceitual:

```text
Disponível
    ↓
Preparando
    ↓
Canalizando
    ↓
Concluído
```

ou:

```text
Canalizando
    ↓
Interrompido
```

O estado deve ser corretamente salvo e carregado.

---

# 20. Requisitos dos Grandes Rituais

Em geral, Grandes Rituais devem exigir uma combinação de:

- pesquisa Nível 9;
- prédio ritual Nível 8;
- conjuradores;
- Mana inicial;
- Mana por turno;
- vários turnos.

Baseline inicial:

```text
4–5 conjuradores
300–500 Mana inicial
20–50 Mana/turno
6–10 turnos
```

Os valores podem variar significativamente entre escolas.

---

# 21. Interrupção dos Grandes Rituais

Grandes Rituais precisam possuir counterplay.

Possíveis condições de interrupção:

- cidade ritualística conquistada;
- prédio ritual destruído;
- conjuradores mínimos mortos;
- Mana insuficiente;
- perda de Nódulos necessários;
- perda de requisito territorial;
- condição especial da escola.

O adversário precisa conseguir reagir.

---

# 22. Comprometimento dos ritualistas

Conjuradores envolvidos em Grande Ritual não devem continuar operando normalmente.

Durante canalização, podem:

- ficar impedidos de mover;
- ficar impedidos de conjurar outros feitiços;
- ficar vinculados à área;
- perder alguma capacidade defensiva.

Isso cria uma vulnerabilidade real.

Exemplo:

> "Não preciso conquistar o império inteiro. Preciso matar dois dos cinco ritualistas."

---

# 23. Comunicação mundial

Grandes Rituais realmente perigosos devem gerar avisos apropriados.

Especialmente:

- Aurora Divina;
- Arquidemônio;
- Lich;
- Domínio da Terra Viva;
- Grande Convergência;
- Cataclismo;
- Transcendência.

Pequenos feitiços não precisam gerar anúncios globais.

---

# 24. Nível 10 — Transcendência Arcana

O Nível 10 não pertence a nenhuma escola individual.

Ele representa compreensão mágica além das escolas.

## Requisito sugerido

Para pesquisar **Transcendência Arcana**:

> possuir Nível 9 em pelo menos **duas escolas diferentes**.

Isso impede que a vitória mágica seja obtida pesquisando apenas uma linha até o fim.

A rota exige alguma amplitude intelectual.

---

# 25. Santuário da Transcendência

Pesquisar Transcendência libera uma estrutura final.

Nome provisório:

**Santuário da Transcendência**

Pode reaproveitar ou adaptar o Santuário Arcano existente caso seja melhor para o código e para o conteúdo.

É necessário para o ritual final.

---

# 26. Vitória de Supremacia

A vitória mundana/tecnológica não deve exigir conquistar todas as capitais.

Também não deve aceitar como grande feito conquistar uma colônia recém-fundada irrelevante.

## 26.1 Requisito tecnológico

Desbloquear:

**Nível 10 de Tecnologia**

e pesquisar:

**Exército Supremo**

ou equivalente final da árvore tecnológica.

Não exigir todas as 55 tecnologias.

A árvore tecnológica foi desenhada para permitir escolha e especialização.

---

## 26.2 Requisito militar

Para cada civilização rival:

- controlar ao menos uma **Cidade Desenvolvida** originalmente pertencente àquele rival;

**OU**

- ter eliminado completamente aquela civilização.

Uma Cidade Desenvolvida deve representar uma cidade relevante.

Direção inicial:

> **Cidade Nível 3 ou superior.**

Caso não exista sistema formal de níveis urbanos, não criar um sistema gigantesco exclusivamente para esta condição.

Pode-se definir temporariamente `developed_city()` através de:

- população;
- quantidade de prédios;
- produção;
- infraestrutura;
- outro indicador existente.

---

## 26.3 Proteção para partidas pequenas

Também deve existir um mínimo global.

Sugestão:

> possuir pelo menos **2 cidades desenvolvidas conquistadas**.

Em 1v1, eliminar completamente o rival também satisfaz a condição.

Isso evita vitória instantânea após tomar uma única cidade em uma partida pequena.

---

# 27. Filosofia da Vitória de Supremacia

A condição deve ser fácil de compreender:

> desenvolver sua civilização materialmente;

> construir poder militar;

> demonstrar superioridade real contra os rivais.

Ela não exige:

- pesquisar toda a árvore;
- conquistar todas as capitais;
- eliminar todo mundo obrigatoriamente.

---

# 28. Vitória por Transcendência

A vitória mágica deve ser mais complexa em preparação.

Ela não exige guerra diretamente.

Entretanto, quem busca essa vitória fica vulnerável enquanto prepara:

- escolas;
- Mana;
- Nódulos;
- rituais;
- infraestrutura;
- ritual final.

---

## 28.1 Conhecimento

Pesquisar:

**Transcendência Arcana — Nível 10.**

---

## 28.2 Grandes Rituais

Ter concluído com sucesso:

**2 Grandes Rituais diferentes.**

Exemplos:

- Domínio da Terra Viva;
- Grande Convergência.

Não basta pesquisá-los.

Precisam ter sido executados.

---

## 28.3 Nódulos Arcanos

Controlar:

**3 Nódulos Arcanos.**

Valor provisório.

---

## 28.4 Economia de Mana

Produzir aproximadamente:

**30 Mana por turno.**

Valor provisório.

---

## 28.5 Estrutura final

Possuir:

**Santuário da Transcendência.**

---

# 29. Ritual da Transcendência

Após cumprir os requisitos, o jogador pode iniciar o ritual final.

Baseline inicial:

```text
5 conjuradores
de pelo menos 2 escolas diferentes

400 Mana inicial

40 Mana/turno

3 Nódulos Arcanos

7 turnos de canalização
```

Todos os números são provisórios.

---

# 30. Interrupção da Transcendência

Durante a canalização:

- o Santuário não pode ser destruído;
- a cidade ritualística não pode ser conquistada;
- Nódulos não podem cair abaixo do mínimo;
- Mana precisa continuar sendo paga;
- número mínimo de conjuradores precisa permanecer.

Falha crítica:

> **Transcendência interrompida.**

A sequência de vitória volta ao estado apropriado.

---

# 31. Aviso mundial da Transcendência

Quando o Ritual da Transcendência começar:

> **todas as civilizações devem ser informadas.**

A interface deve comunicar:

- quem iniciou;
- onde aproximadamente;
- quantos turnos faltam;
- que a vitória ocorrerá se o ritual não for interrompido.

Isso cria counterplay de late game.

---

# 32. Paridade entre condições de vitória

As duas rotas não precisam ter a mesma complexidade.

Precisam ser **competitivas em duração média**.

Objetivo inicial:

| Marco | Supremacia | Transcendência |
|---|---:|---:|
| Estratégia definida | ~T40 | ~T40 |
| Midgame forte | ~T80 | ~T80 |
| Corrida de vitória perceptível | ~T130 | ~T130 |
| Requisitos finais possíveis | ~T170–190 | ~T170–190 |
| Vitória média | **~T190–220** | **~T190–220** |

Meta geral:

> **3–4 horas por partida.**

Se uma condição estiver consistentemente uma hora mais rápida que a outra, o balanceamento precisa ser revisado.

---

# 33. Especialização não significa exclusividade

Escolher uma condição de vitória não impede utilizar a outra árvore.

Um jogador de Supremacia pode utilizar:

- Clérigos;
- Elementalistas;
- Portais Arcanos.

Um jogador de Transcendência pode utilizar:

- Homens de Escudo;
- Cavalaria;
- Bombardas.

As árvores definem capacidades.

As condições de vitória definem como a partida termina.

---

# 34. Regras anti-redundância

## Cura direta

Principalmente:

**Sagrada**

## Invocação massiva

Principalmente:

**Necromancia**

## Demônios

Principalmente:

**Artes Infernais**

## Manipulação física do terreno

Principalmente:

**Druidismo**

## Teleporte e anti-magia

Principalmente:

**Arcanismo**

## Dano amplo e clima

Principalmente:

**Elementalismo**

## Burst sacrificial

Principalmente:

**Artes Infernais**

Regra:

> Se uma nova magia poderia entrar igualmente em três escolas sem mudança, provavelmente sua identidade ainda está fraca.

---

# 35. Critérios para novos feitiços

Um feitiço novo deve responder:

1. Qual escola possui esse domínio?
2. Qual decisão estratégica ele cria?
3. O que permite fazer que antes não era possível?
4. Como o adversário pode reagir?
5. Por que ele não é somente um bônus numérico?
6. Ele é redundante com alguma magia existente?

Evitar encher a árvore com:

- +5% dano;
- +5% Mana;
- +5% cura;
- +5% defesa.

Bônus numéricos podem existir, mas devem apoiar mecânicas relevantes.

---

# 36. Limites de invocações

Invocações precisam de limites claros.

## Esqueletos

Máximo sugerido:

**3 por Necromante.**

## Guardião Sepulcral

Máximo sugerido:

**1 por Necromante.**

## Fera do Bosque

Máximo sugerido:

**1 por Druida.**

## Golem Arcano

Quantidade pequena e manutenção alta em Mana.

Grandes entidades de ritual possuem regras próprias.

---

# 37. Mana

Mana precisa funcionar como limitador real.

Magia forte não deve poder ser utilizada todo turno indefinidamente.

Pode-se usar combinação de:

- custo inicial;
- cooldown;
- manutenção;
- canalização;
- limite de criaturas;
- infraestrutura;
- requisitos.

Não é necessário utilizar todos simultaneamente em todo feitiço.

---

# 38. Magia e counterplay

Toda capacidade extremamente poderosa precisa possuir alguma resposta.

## Magos frágeis

Resposta:

> romper a formação e alcançar o conjurador.

## Invocações

Resposta:

> matar invocadores, cortar Mana ou destruir criaturas.

## Grandes Rituais

Resposta:

> atacar estrutura, cidade ou ritualistas.

## Teleporte

Resposta:

> ameaçar âncoras.

## Domínio Druídico

Resposta:

> contornar, esperar expirar, usar voadores ou contramedidas mágicas.

## Necromancia

Resposta:

> eliminar Necromantes e utilizar Purificação.

---

# 39. IA

A IA precisa entender a identidade das escolas.

Não basta pesquisar magia aleatoriamente.

## Exemplo — IA Necromante

Deve compreender que:

- precisa de Cripta;
- precisa treinar Necromantes;
- precisa protegê-los;
- precisa manter Mana;
- deve invocar antes de expor o conjurador;
- pode preparar o Lich no late game.

## Exemplo — IA Druídica

Deve usar terreno para:

- proteger cidades;
- fechar passagens;
- esconder tropas;
- preparar emboscadas;
- dificultar invasões.

## Exemplo — IA Sagrada

Deve:

- manter Clérigos atrás da linha;
- priorizar aliados feridos;
- purificar debuffs relevantes;
- usar Domínio Consagrado em batalhas importantes.

O comportamento precisa produzir **intenção estratégica perceptível**.

---

# 40. Save / Load

Devem ser persistidos corretamente:

- escolas pesquisadas;
- feitiços;
- cooldowns relevantes;
- invocações;
- vínculos invocador → criatura;
- terrenos temporariamente modificados;
- duração de efeitos territoriais;
- Grandes Feitiços;
- Grandes Rituais;
- ritualistas;
- turnos restantes;
- bosses invocados;
- alvo de bosses;
- progresso da Transcendência.

Terreno temporário precisa continuar corretamente após carregar um save.

---

# 41. Conteúdo mágico antigo

Conteúdo existente pode ser:

- reaproveitado;
- renomeado;
- remapeado;
- adaptado;
- removido se redundante.

Conteúdos antigos como:

- Reanimate;
- Fiery Ruin;
- Gaia Metamorphosis;
- Arcane Spear;

devem ser avaliados.

Não precisam desaparecer automaticamente.

Devem ser encaixados quando possuírem função útil dentro da nova identidade das escolas.

Compatibilidade de save deve ser considerada.

---

# 42. Critério de sucesso da Árvore de Magia

A árvore estará produzindo boas decisões quando o jogador pensar:

> "Quero cura ou controle territorial?"

> "Aprofundo Necromancia ou começo Arcanismo?"

> "Uso minha Mana agora ou guardo para o Grande Ritual?"

> "Protejo meus cinco Necromantes ou continuo atacando?"

> "Uso Grande Convergência para invadir ou para salvar meu exército?"

> "Bloqueio esta passagem com montanhas ou guardo o cooldown?"

> "Ataco o ritual inimigo agora ou tento terminar minha própria vitória?"

A experiência não deve ser:

> "Escolhi a escola que concede mais +10%."

---

# 43. Escala de progressão mágica

A progressão deve transmitir aumento claro de escala.

## Early game

Pequenas violações das regras naturais:

- cura;
- dano mágico;
- floresta temporária;
- pequeno teleporte;
- maldição localizada.

## Midgame

Poderes capazes de mudar batalhas:

- invocações;
- ocultação;
- criaturas;
- anti-magia;
- grande controle de área.

## Late game

Poderes capazes de mudar guerras:

- cordilheiras temporárias;
- exércitos mortos-vivos;
- portais;
- tempestades;
- regiões sagradas.

## Endgame

Poderes capazes de mudar o mundo:

- Lich Ancião;
- Arquidemônio;
- remodelação territorial regional;
- teleporte de exército;
- Cataclismo;
- Transcendência.

---

# 44. Resultado esperado

A Tecnologia deve transmitir:

> **"Meu reino está ficando mais desenvolvido."**

A Magia deve transmitir:

> **"Minha civilização está aprendendo progressivamente a violar as regras do mundo."**

No começo:

> pequenas manipulações.

No meio:

> conjuradores especializados e efeitos que mudam batalhas.

No final:

> regiões mudam, exércitos teleportam, mortos marcham, cataclismos surgem e entidades impossíveis entram no mundo.

Esse aumento de escala é parte central da identidade da Magia em Aetherlands.

---

# 45. Resumo da Árvore V1

| Nível | Sagrada | Infernal | Necromancia | Druidismo | Arcanismo | Elementalismo |
|---|---|---|---|---|---|---|
| **1** | Doutrina Sagrada | Artes Infernais | Necromancia | Druidismo | Arcanismo | Elementalismo |
| **2** | Igreja da Luz | Altar Abissal | Cripta dos Sussurros | Círculo Druídico | Torre Arcana | Conclave Elemental |
| **3** | Clérigo | Cultista | Necromante | Druida | Arcanista | Elementalista |
| **4** | Cura Sagrada | Fogo Infernal | Solo Amaldiçoado | Floresta Súbita | Salto Arcano | Relâmpago Encadeado |
| **5** | Purificação | Pacto de Sangue | Erguer os Mortos | Flores do Véu | Selo de Mana | Onda Glacial |
| **6** | Hierofante | Bruxo Infernal | Guardião Sepulcral | Fera do Bosque | Golem Arcano | Elemental da Tempestade |
| **7** | Domínio Consagrado | Chuva de Enxofre | Legião dos Mortos | Erguer Cordilheira | Portal de Campanha | Frente de Tempestade |
| **8** | Grande Catedral | Portal Abissal | Mausoléu Negro | Coração da Terra Viva | Obelisco de Convergência | Olho dos Quatro Ventos |
| **9** | Aurora Divina | Arquidemônio | Lich Ancião | Domínio da Terra Viva | Grande Convergência | Cataclismo Elemental |
| **10** | colspan | **TRANSCENDÊNCIA ARCANA — progressão universal final** | | | | |

---

# 46. Princípio final

A Árvore de Magia não deve existir apenas para fornecer mais unidades ou números maiores.

Ela deve permitir ao jogador fazer coisas que parecem **impossíveis dentro das regras normais do jogo**.

A progressão ideal é:

```text
Aprender magia
        ↓
Treinar conjuradores
        ↓
Manipular pequenas situações
        ↓
Mudar batalhas
        ↓
Mudar guerras
        ↓
Mudar regiões
        ↓
Tentar transcender as regras do próprio mundo
```

Esse é o papel da Magia em Aetherlands.
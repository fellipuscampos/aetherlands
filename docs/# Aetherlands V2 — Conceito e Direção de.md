# Aetherlands V2 — Conceito e Direção de Design

**Status:** direção oficial de design para a próxima grande revisão do projeto
**Versão conceitual:** V2
**Objetivo:** substituir a filosofia de design da V1 nas áreas descritas neste documento

---

# 1. Visão geral

Aetherlands V2 é um **4X de fantasia focado principalmente em guerra, composição de exércitos, magia, controle territorial e construção de uma infraestrutura capaz de sustentar conflitos de grande escala**.

A V1 de Aetherlands nasceu muito próxima da estrutura tradicional de Civilization.

Ao longo do desenvolvimento, isso gerou vários sistemas paralelos:

* população;
* comida;
* comércio;
* cadeias extensas de construções;
* inúmeras unidades militares semelhantes;
* economia;
* pesquisa mundana;
* pesquisa mágica;
* cidades;
* diplomacia;
* rituais;
* recursos;
* diferentes formas de progressão.

Esses sistemas funcionam, mas começaram a tornar o jogo maior e mais complexo sem necessariamente tornar suas decisões proporcionalmente melhores.

A V2 muda essa filosofia.

O objetivo não é competir com Civilization em quantidade de sistemas civis, políticos, econômicos e culturais.

O objetivo é criar uma identidade própria:

> **Aetherlands é um jogo sobre construir uma civilização fantástica capaz de formar, sustentar e comandar exércitos extremamente diversos.**

A cidade existe para sustentar esse conflito.

A economia existe para sustentar esse conflito.

A pesquisa existe para oferecer novas estratégias nesse conflito.

Magia existe para transformar como as batalhas acontecem.

Território existe porque determinados lugares oferecem vantagens estratégicas.

Diplomacia continua relevante porque determina contra quem, quando e por que essas guerras acontecem.

A complexidade do jogo deve convergir para:

**decisões estratégicas interessantes no mapa e no campo de batalha.**

---

# 2. Objetivos fundamentais da V2

A V2 deve tornar Aetherlands:

* menor em quantidade de sistemas paralelos;
* maior em possibilidades estratégicas;
* mais fácil de compreender;
* mais difícil de dominar;
* mais focado em composição de exércitos;
* mais claramente fantástico;
* menos burocrático;
* menos dependente de microgerenciamento;
* mais legível;
* mais amigável à IA;
* mais eficiente em performance;
* mais adequado a partidas de aproximadamente 3–4 horas.

A complexidade deve vir principalmente de:

* quais unidades escolho;
* quais escolas mágicas pesquiso;
* quais doutrinas militares aprofundo;
* como posiciono minhas tropas;
* como respondo à composição inimiga;
* quanto do meu império dedico à economia;
* quanto consigo sustentar militarmente;
* onde coloco minhas cidades;
* quais recursos territoriais disputo;
* quando começo ou evito uma guerra.

E não de:

* dezenas de sistemas administrativos pouco conectados;
* inúmeros prédios com bônus pequenos;
* unidades redundantes;
* árvores enormes compostas por upgrades percentuais sem personalidade.

---

# 3. Os três pilares de progressão

Aetherlands V2 possui três sistemas centrais de pesquisa.

## 3.1 Doutrinas Militares

Respondem:

> **Que tipo de exército mundano minha civilização consegue formar?**

As Doutrinas desenvolvem:

* classes militares;
* atributos;
* técnicas;
* habilidades;
* formas avançadas;
* unidades de elite;
* candidatos a Unidade Lendária.

---

## 3.2 Escolas de Magia

Respondem:

> **Que capacidades extraordinárias posso adicionar ao meu exército?**

As Escolas oferecem:

* um único tipo de conjurador por escola;
* repertório crescente de feitiços;
* especialização extrema;
* Grandes Manifestações.

---

## 3.3 Infraestrutura

Responde:

> **Como minha civilização consegue sustentar seu exército, sua magia e sua pesquisa?**

Infraestrutura desenvolve:

* ouro;
* suprimentos;
* mana;
* produção;
* conhecimento;
* cidades;
* fortificações;
* eficiência territorial.

A árvore de Infraestrutura deve ser significativamente menor que as outras duas.

Ela não existe como terceira condição de vitória.

Ela é a fundação sobre a qual as outras duas funcionam.

---

# 4. Pesquisa global

A civilização possui **um único projeto de pesquisa ativo por vez**.

Doutrina, Magia e Infraestrutura competem pelo mesmo recurso de pesquisa:

**Conhecimento.**

Isso cria custo de oportunidade real.

Exemplo:

o jogador pode precisar decidir entre:

* desbloquear Bola de Fogo;
* desenvolver uma nova forma do Guerreiro;
* pesquisar Academia II;
* desenvolver Muralhas II;
* aprofundar Arcanismo.

Trocar de pesquisa deve preservar o progresso já acumulado no projeto abandonado.

---

# 5. Filosofia das composições

Nenhuma árvore deve conseguir substituir completamente as outras.

Um exército ideal possui uma combinação de:

**unidades mundanas + especialistas mágicos.**

Unidades mundanas:

* ocupam território;
* seguram linhas;
* atacam constantemente;
* absorvem dano;
* cercam cidades;
* flanqueiam;
* protegem os magos.

Conjuradores:

* alteram momentaneamente as regras da batalha;
* possuem efeitos extremamente poderosos;
* dependem de mana;
* possuem cooldown;
* são frágeis;
* precisam ser protegidos.

Um jogador deve conseguir olhar para um exército inimigo e entender aproximadamente sua composição.

Exemplo:

* 4 Guardiões;
* 3 Patrulheiros;
* 2 Guerreiros;
* 1 Catapulta;
* 2 Infernalistas;
* 1 Clérigo;
* 1 Arcanista.

A partir disso, deve ser possível pensar:

> “A linha de frente é resistente. O dano principal vem dos Infernalistas. Preciso alcançar esses magos ou interromper seus feitiços.”

Essa leitura é central para o design da V2.

---

# 6. Escala desejada dos exércitos

A V2 não deve incentivar exércitos de 40–60 unidades por civilização.

Não será necessariamente utilizado um hard cap rígido.

O próprio sistema econômico deve criar limites naturais.

A escala desejada para um exército principal deve ficar aproximadamente na ordem de:

**12–20 unidades/tokens relevantes.**

Uma civilização poderá possuir:

* guarnições;
* forças secundárias;
* unidades de exploração;
* outros destacamentos.

Entretanto, o jogo deve favorecer:

**qualidade + composição + estratégia**

em vez de:

**quantidade infinita.**

---

# 7. Doutrinas Militares

A árvore militar será reformulada em:

**6 Doutrinas × 9 níveis + 1 descoberta universal final.**

Total:

**55 pesquisas militares.**

Estrutura conceitual:

| Nível | Conteúdo                     |
| ----- | ---------------------------- |
| N1    | Doutrina                     |
| N2    | Estrutura de treinamento     |
| N3    | Unidade-base                 |
| N4    | Técnica I                    |
| N5    | Primeira evolução            |
| N6    | Técnica II                   |
| N7    | Forma Elite                  |
| N8    | Estrutura de Maestria        |
| N9    | Candidato a Unidade Lendária |

Além das seis linhas existe:

**Exército Supremo**, descoberta universal relacionada à Vitória por Supremacia Militar.

---

# 8. Diferença fundamental entre soldado e mago

Esta é uma regra central da V2.

## Unidade mundana

**Evolui fisicamente.**

Pode ganhar:

* mais HP;
* ataque;
* defesa;
* movimento;
* alcance;
* habilidades;
* resistências;
* características novas.

Uma unidade inicial pode ser transformada em uma versão superior.

---

## Conjurador

**Não evolui fisicamente.**

O conjurador do fim da partida continua aproximadamente tão vulnerável quanto quando foi treinado.

Ele não ganha automaticamente:

* mais HP;
* mais defesa;
* mais movimento;
* ataque convencional melhor.

O que cresce é:

**seu repertório de magia.**

Isso impede que magos poderosíssimos também se transformem em excelentes tanks.

---

# 9. Magos não possuem ataque básico

Conjuradores da V2 **não realizam ataques normais**.

Um Infernalista não possui um ataque ranged gratuito.

Um Clérigo não golpeia inimigos normalmente.

Um Arcanista não dispara projéteis básicos.

Sua capacidade ofensiva ou utilitária vem exclusivamente de:

* feitiços;
* mana;
* cooldown;
* posicionamento.

Isso diferencia claramente:

**Patrulheiro = DPS ranged constante**

de:

**Infernalista = explosões mágicas extremamente poderosas porém limitadas.**

Se todos os feitiços de um mago estiverem indisponíveis, ele deve:

* reposicionar-se;
* proteger-se;
* recuar;
* esperar cooldown;
* cumprir função estratégica.

---

# 10. Seis Doutrinas Militares

## 10.1 Guardião

Função:

**tank / frontline / proteção.**

Especialidades possíveis:

* defesa elevada;
* interceptação;
* proteção de aliados;
* formação defensiva;
* resistência;
* controle de passagem;
* preparação contra cargas.

Pode absorver conceitos atualmente espalhados entre:

* Guarda;
* Homem de Escudo;
* Lanceiro;
* Halberdier.

Anti-cavalaria pode ser uma **técnica**, e não necessariamente outra unidade inteira.

---

## 10.2 Guerreiro

Função:

**dano físico corpo a corpo.**

É o combatente ofensivo padrão.

Pode evoluir conceitualmente através de arquétipos como:

* combatente;
* espadachim;
* guerreiro veterano;
* mestre de armas.

É diferente do Guardião porque troca resistência por capacidade ofensiva.

---

## 10.3 Patrulheiro

Função:

**combate ranged.**

Progressão pode utilizar arquétipos como:

* arqueiro;
* besteiro;
* ranger;
* atirador elite.

Pode desenvolver técnicas como:

* disparo perfurante;
* volley;
* melhor alcance;
* bônus de posição;
* ataque contra blindagem.

---

## 10.4 Cavalaria

Função:

**mobilidade, flanco e choque.**

Características:

* alto movimento;
* possibilidade de contornar linhas;
* carga;
* perseguição;
* alcance rápido de conjuradores e artilharia.

A V1 possui muitas variantes redundantes de cavalaria.

Na V2, elas se tornam **estágios de uma única linha de progressão**.

---

## 10.5 Ladino

Função:

**sabotagem e eliminação de alvos prioritários.**

É uma classe deliberadamente inspirada em arquétipos de RPG/fantasia.

Não deve ser excelente em combate frontal.

Pode possuir características como:

* mobilidade;
* infiltração;
* ocultação limitada;
* grande dano contra conjuradores;
* sabotagem de máquinas;
* dano contra cerco;
* desabilitação temporária;
* capacidade de atravessar ou ignorar determinadas zonas de controle.

É uma resposta mundana contra determinadas composições especializadas.

---

## 10.6 Cerco

Função:

**conquista e destruição de cidades.**

A V1 possui quantidade excessiva de máquinas com funções muito próximas.

Na V2, a linha será consolidada.

Possível progressão conceitual:

**Catapulta → Trebuchet/Bombarda → Máquina Elite.**

Balista pode sobreviver caso possua função realmente distinta, por exemplo:

* anti-monstro;
* anti-Manifestação;
* anti-unidade grande.

Aríete ou Torre de Cerco podem virar:

* técnica;
* equipamento;
* efeito da doutrina;

em vez de unidades independentes.

---

# 11. Evolução das unidades

Ao desbloquear uma nova forma, tropas antigas **não devem simplesmente permanecer no mapa ao lado das novas gerações indefinidamente**.

O sistema deve permitir upgrade.

Exemplo conceitual:

**Arqueiro → Besteiro/Ranger → Patrulheiro Elite**

O upgrade pode exigir:

* ouro;
* cidade apropriada;
* estrutura da doutrina;
* algum tempo ou ação.

A veterania deve ser preservada sempre que possível.

Isso transforma tropas antigas em investimentos duradouros.

Uma unidade produzida depois que uma evolução já foi pesquisada pode ser treinada diretamente em sua forma atual.

---

# 12. Técnicas militares

Unidades mundanas podem possuir habilidades.

Entretanto, suas técnicas devem ser significativamente mais simples que magia.

Elas podem utilizar:

* cooldown;
* condição posicional;
* movimento;
* alvo específico.

Mas não Mana.

Exemplos conceituais:

Guardião:

* Interceptar;
* Formação Defensiva.

Guerreiro:

* Golpe Pesado;
* Ataque em Arco.

Patrulheiro:

* Volley;
* Disparo Perfurante.

Cavalaria:

* Carga;
* Retirada.

Ladino:

* Sabotagem;
* Ataque Furtivo.

Cerco:

* Munição Demolidora;
* Bombardeio.

A unidade continua útil mesmo com habilidades indisponíveis porque mantém seu ataque básico.

---

# 13. Unidade Lendária

Cada Doutrina completa oferece um **candidato a Unidade Lendária**.

Entretanto:

> **cada civilização pode possuir apenas UMA Unidade Lendária ativa por vez.**

Isso cria uma escolha estratégica.

Uma civilização que domina Guerreiro e Cavalaria precisa decidir qual ápice deseja colocar em campo.

A Unidade Lendária não deve ser simplesmente:

“a mesma unidade com +50% de status”.

Ela deve alterar alguma regra.

Exemplos conceituais:

### Cavalaria

**Cavaleiro de Grifo**

* voa;
* atravessa obstáculos;
* ignora certas limitações de terreno;
* pode alcançar backline com facilidade;
* pode ser particularmente vulnerável a Patrulheiros ou condições climáticas.

### Cerco

**Colosso de Cerco**

* enorme capacidade contra cidades;
* lento;
* extremamente vulnerável se isolado.

### Guerreiro

**Herói da Lâmina**

* combatente excepcional;
* excelente em duelos/frontline;
* ainda possui counters.

### Guardião

**Campeão Guardião**

* enorme capacidade de proteger aliados;
* baixa capacidade de projeção ofensiva.

Cada Lendário precisa possuir:

* força evidente;
* função clara;
* fraqueza real.

Se morrer, pode ser substituído futuramente após:

* custo;
* cooldown;
* condições adequadas.

---

# 14. Identidade racial

A V2 não terá árvores de unidades exclusivas inteiras por raça.

Todas as civilizações usam as mesmas:

* seis Doutrinas;
* seis Escolas;
* infraestruturas básicas.

A diferença racial vem de:

* modelos/skins;
* identidade visual;
* bônus sistêmicos simples.

Isso mantém o escopo controlado.

## Direções provisórias

### Humanos

**Generalistas.**

Recebem pequeno bônus global.

Faixa inicial para balanceamento:

**aproximadamente 5–8%.**

O bônus não deve necessariamente significar +8% em absolutamente todos os atributos de combate simultaneamente.

Pode ser distribuído entre:

* eficiência;
* economia;
* pesquisa;
* treinamento.

---

### Orcs

**Especialistas militares.**

Possível bônus:

* unidades mundanas treinadas aproximadamente 15–25% mais rápido.

Isso combina com a fantasia de Horda.

---

### Elfos

**Especialistas mágicos.**

Possíveis bônus:

* maior eficiência mágica;
* mais Mana;
* efeitos mais fortes;
* alcance mágico;
* redução moderada de custos.

O formato exato será definido por balanceamento.

---

### Anões

**Especialistas em infraestrutura.**

Possível bônus:

* construções;
* upgrades urbanos;
* fortificações;

aproximadamente 20–30% mais rápidos ou eficientes.

---

Esses valores são provisórios.

A identidade importa mais que os números iniciais.

---

# 15. Escolas de Magia

A árvore mágica continuará com:

**6 Escolas × 9 níveis + Transcendência.**

Total:

**55 pesquisas mágicas.**

Estrutura padrão:

| Nível | Conteúdo              |
| ----- | --------------------- |
| N1    | Escola                |
| N2    | Prédio da Escola      |
| N3    | Conjurador            |
| N4    | Feitiço Básico        |
| N5    | Feitiço Intermediário |
| N6    | Feitiço Avançado      |
| N7    | Grande Feitiço        |
| N8    | Estrutura Ritual      |
| N9    | Grande Manifestação   |

Uma Escola deve possuir uma função extremamente clara.

---

# 16. Sagrada

Função exclusiva:

**sustentação.**

Sua pergunta é:

> **Como mantenho meu exército vivo e funcional?**

Possíveis capacidades:

### N4

Cura individual.

### N5

Purificação.

### N6

Proteção, escudo ou bênção.

### N7

Sustentação em área.

Não precisa causar dano.

Mesmo o feitiço mais avançado deve continuar ligado a:

* cura;
* proteção;
* purificação;
* resistência.

---

# 17. Infernal

Função exclusiva:

**dano mágico.**

Sua pergunta é:

> **Como destruo algo rapidamente?**

Infernal não precisa:

* debuffar;
* teleportar;
* invocar tropas convencionais;
* curar.

Tudo causa dano de alguma forma.

Possível progressão:

### N4

Dano single-target eficiente.

### N5

Explosão em área.

### N6

Dano pesado contra alvo resistente ou dano contínuo.

### N7

Grande devastação territorial.

Efeitos como:

**Incendiado**

continuam coerentes porque representam dano diferido.

O Infernalista deve ser extremamente perigoso.

Também extremamente frágil.

---

# 18. Necromancia

Função exclusiva:

**invocação e comando de mortos-vivos.**

A escola não precisa de maldição genérica.

O Necromante existe para transformar Mana em forças descartáveis ou especializadas.

Possíveis progressões:

### N4

Hoste Esquelética.

### N5

Arqueiros Mortos.

### N6

Guarda Sepulcral.

### N7

Legião dos Mortos.

---

# 19. Retinues e exércitos necromânticos

Necromancia não deve recriar o problema de dezenas de tokens individuais.

Um grupo de vários esqueletos pode ser representado mecanicamente como:

**uma única unidade/squad.**

Visualmente pode conter vários corpos.

Mecanicamente ocupa:

**um token.**

Um Necromante pode controlar uma ou mais Retinues limitadas.

O objetivo é evitar:

* cinco Necromantes;
* vinte e cinco esqueletos;
* vinte e cinco comandos manuais.

O jogador controla principalmente:

**o Necromante e as ordens de suas hostes.**

Comandos possíveis:

* seguir;
* proteger;
* atacar alvo;
* atacar região;
* recuar.

Os mortos-vivos executam essas ordens através de comportamento próprio.

Pode existir controle direto limitado quando houver apenas uma entidade simples, mas o sistema deve priorizar **comando de grupo**.

Retinues desaparecem ou entram em estado crítico caso percam sua ligação com o Necromante, conforme a regra final definida posteriormente.

---

# 20. Druidismo

Função exclusiva:

**manipulação física do campo de batalha.**

O Druida modifica:

**por onde os exércitos conseguem lutar.**

Não é escola de dano.

Não é escola de cura.

Possíveis capacidades:

### Enraizar

Impede ou reduz drasticamente movimento.

### Bosque Oculto

Cria uma região física/vegetal favorável à ocultação.

### Barreira Natural

Cria obstáculo temporário.

### Remodelar Terreno

Alteração maior capaz de criar caminhos, bloquear passagens ou redesenhar uma zona.

O Druida funciona quase como:

**um level designer durante a batalha.**

---

# 21. Arcanismo

Função exclusiva:

**mobilidade e utilidade mágica.**

O Arcanista quebra regras normais de posicionamento.

Possíveis capacidades:

### Salto Arcano

Teleporte próprio.

### Transposição

Teleporte de unidade aliada.

### Ruptura Arcana

Interferência mágica, dissipação ou silêncio.

### Portal

Transporte de múltiplas unidades.

O Arcanista pode possuir pouco ou nenhum dano direto.

Seu poder é permitir:

**estar no lugar certo no momento certo.**

---

# 22. Elementalismo

Função exclusiva:

**controle ambiental.**

Diferença fundamental:

> **Druidismo altera fisicamente o terreno.**

> **Elementalismo altera temporariamente as condições ambientais sobre o terreno.**

Possíveis feitiços:

### Nevasca

Reduz movimento de unidades dentro da região.

Unidades extremamente lentas podem ficar temporariamente imobilizadas.

### Tempestade

Área perigosa com raios periódicos ou microdanos.

### Vendaval / Chuva Torrencial

Prejudica ataques ranged, visão ou movimento.

### Terremoto

Fragiliza estruturas.

Exemplo:

durante o efeito, fortificações recebem:

**+X% dano de cerco.**

Isso cria combos como:

**Elementalista → Terremoto → Catapulta → quebra das muralhas.**

Elementalismo deve modificar:

**como é lutar em determinada região.**

---

# 23. Grandes Manifestações

Todos os Grandes Rituais da V2 culminam em algo extraordinário e visível no mundo:

**uma Grande Manifestação.**

Isso cria consistência de espetáculo entre Escolas.

Entretanto, Manifestação não significa:

“seis bosses iguais com skins diferentes”.

Cada entidade segue a filosofia de sua Escola.

---

## Sagrada — Arcanjo

Função:

* cura;
* proteção;
* purificação;
* combate contra ameaças profanas.

---

## Infernal — Arquidemônio

Função:

* destruição;
* dano;
* pressão ofensiva;
* ataque de cidades/exércitos.

Não precisa comandar pequenos demônios.

Seu diferencial pode ser simplesmente:

**capacidade destrutiva absurda.**

---

## Necromancia — Lich Ancião

Função:

* comandar mortos;
* gerar hostes;
* avançar com seu próprio mini-exército.

Funciona quase como:

**um exército autônomo.**

---

## Druidismo — Ent Primordial / Ancião da Terra

Função:

* remodelar terreno;
* criar vegetação;
* bloquear caminhos;
* controlar regiões.

---

## Arcanismo — Arquonte / Colosso Arcano

Função:

* teleportes;
* portais;
* reposicionamento;
* interferência mágica.

---

## Elementalismo — Avatar da Tempestade / Titã Elemental

Função:

* carregar fenômenos climáticos;
* transformar regiões em zonas perigosas;
* dominar grandes áreas do campo.

---

# 24. Autonomia das Grandes Manifestações

Grandes Manifestações não devem funcionar como tropas convencionais.

O jogador dá uma **missão estratégica**.

Exemplos:

* atacar esta cidade;
* defender esta cidade;
* acompanhar este exército;
* dominar esta região;
* proteger este ritual.

Depois disso, a Manifestação utiliza IA própria.

Isso preserva a fantasia de:

> “eu liberei uma entidade poderosa no mundo.”

Em vez de:

> “ganhei uma unidade de 100 HP para microgerenciar”.

---

# 25. Limite de Grandes Manifestações

Não deve ser possível acumular infinitamente Manifestação da mesma Escola.

Como princípio inicial:

**máximo de uma Manifestação ativa daquela Escola por civilização.**

Novos rituais podem ser realizados depois que:

* a anterior morreu;
* desapareceu;
* foi dissipada;

e o cooldown/requisitos forem novamente satisfeitos.

---

# 26. Infraestrutura

A terceira árvore será chamada provisoriamente de:

**Infraestrutura.**

Ela deve ser pequena.

Não terá 55 pesquisas.

Alvo conceitual:

**aproximadamente 12–18 pesquisas.**

Possível estrutura:

6 linhas × 2–3 níveis.

Linhas principais:

* Logística;
* Economia;
* Indústria;
* Academia;
* Arcana;
* Urbanização/Fortificação.

---

# 27. Cinco recursos econômicos fundamentais

A economia V2 será organizada ao redor de cinco valores centrais.

## 27.1 Ouro

Função:

* manutenção;
* upgrades;
* compras;
* operação da infraestrutura;
* custos especiais.

É uma moeda acumulável.

---

## 27.2 Suprimentos

Substitui a necessidade de tratar comida/população como sistema civil completo.

Representa:

* alimentação;
* logística;
* equipamento;
* capacidade de manter tropas convencionais.

Unidades mundanas consomem Suprimentos continuamente.

Isso cria limite orgânico para exércitos.

---

## 27.3 Mana

Serve para:

* manter conjuradores;
* sustentar invocações;
* conjurar feitiços;
* realizar rituais;
* manter Grandes Manifestações.

---

## 27.4 Produção

É principalmente local à cidade.

Determina velocidade de:

* construções;
* unidades;
* upgrades.

---

## 27.5 Conhecimento

É a pesquisa global.

Alimenta:

* Doutrinas;
* Magia;
* Infraestrutura.

---

# 28. Sistemas removidos ou drasticamente simplificados

A V2 deve eliminar ou reduzir como sistemas centrais:

* população tradicional;
* crescimento populacional por comida;
* armazenamento complexo de comida;
* slots de prédio baseados em população;
* comércio entre cidades no estilo Civilization;
* Mercadores como sistema principal;
* cadeias extensas de comércio;
* grande quantidade de prédios econômicos diferentes;
* unidades militares redundantes;
* segundos tiers físicos de magos;
* unidades mágicas treináveis genéricas;
* conteúdo legado sem função;
* dependências desnecessariamente complexas de prédios.

A V2 não precisa preservar complexidade simplesmente porque ela já existe na V1.

---

# 29. Manutenção de unidades

Esse sistema é fundamental para evitar novamente exércitos infinitos.

## Tropas mundanas

Consomem principalmente:

**Suprimentos.**

Unidades avançadas, máquinas ou Lendários podem possuir também pequena manutenção em Ouro.

Exemplo conceitual:

| Tipo          | Suprimentos |
| ------------- | ----------: |
| unidade comum |           1 |
| elite         |           2 |
| cavalaria     |           2 |
| cerco         |         2–3 |
| Lendária      |         3–4 |

Valores completamente provisórios.

---

## Conjuradores

Consomem:

**Mana por turno.**

Possível baseline:

1 Mana/turno.

Além disso, feitiços consomem Mana individualmente.

---

## Necromancia

Retinues também consomem Mana.

O custo pode ser agregado ao Necromante.

Quanto maior o exército morto-vivo:

**maior o peso arcano.**

---

## Grandes Manifestações

Possuem manutenção relevante em Mana.

São extremamente poderosas.

Precisam exigir economia compatível.

---

# 30. O tamanho do exército como escolha econômica

Não existe necessariamente:

**limite máximo de 20 unidades.**

Em vez disso:

um exército maior significa:

* mais infraestrutura logística;
* mais manutenção;
* menos território usado para outras funções;
* mais ouro gasto;
* mais Suprimentos consumidos.

Portanto:

**ter 40 unidades deve ser possível, mas extremamente caro e deliberado.**

Não a consequência automática de jogar 150 turnos.

---

# 31. Prédios econômicos básicos

As cidades possuem um conjunto pequeno de construções facilmente compreensíveis.

## Fazenda / Centro Logístico

Gera:

**Suprimentos.**

---

## Mercado / Tesouraria

Gera:

**Ouro.**

---

## Oficina

Gera:

**Produção.**

---

## Academia

Gera:

**Conhecimento.**

---

## Condutor Arcano / Santuário Arcano

Gera:

**Mana.**

O nome final deve combinar com a estética do jogo.

---

# 32. Upgrades de infraestrutura

Cada família possui poucos níveis.

Exemplo:

**Academia I → Academia II → Academia III**

Versões superiores devem possuir:

* mais eficiência por tile;
* melhor relação produção/manutenção;
* possivelmente efeitos secundários simples.

Assim:

5 Academias I

podem produzir valor semelhante a:

2–3 Academias III.

A vantagem do avanço é:

**eficiência territorial.**

---

# 33. Manutenção de prédios

A economia deve possuir ciclos.

Entretanto, eles devem permanecer simples.

Princípio recomendado:

> **Ouro será o principal custo operacional das infraestruturas.**

Exemplo:

Academia:

* gera Conhecimento;
* custa Ouro/turno.

Oficina:

* gera Produção;
* custa Ouro.

Estrutura Arcana:

* gera Mana;
* custa Ouro.

Centro Logístico:

* gera Suprimentos;
* pode custar pouco ou nenhum Ouro no primeiro nível.

Isso cria uma rede econômica sem transformar o jogo em uma planilha.

Evitar, inicialmente, regras como:

> “Academia consome Ouro + Mana + Suprimentos + outro recurso.”

A V2 busca simplificação.

Dependências múltiplas podem ser adicionadas somente se playtests demonstrarem necessidade real.

---

# 34. Múltiplos prédios iguais

Uma cidade pode construir várias cópias de uma infraestrutura econômica.

Exemplo:

uma cidade extremamente acadêmica pode possuir:

* Academia;
* Academia;
* Academia;
* Academia.

Isso é permitido.

A limitação ocorre através de:

* território;
* custo;
* manutenção;
* oportunidade perdida.

Cada tile utilizado para uma Academia deixa de ser utilizado para:

* Suprimentos;
* Ouro;
* Mana;
* Produção;
* defesa.

Especialização emerge naturalmente.

---

# 35. Prédios das Doutrinas e Escolas

Além das infraestruturas básicas, cidades podem possuir:

* prédio de treinamento de Doutrina;
* prédio de Escola Mágica;
* estrutura ritual;
* estrutura de Maestria;
* fortificações;
* construções especiais.

Esses prédios concorrem fisicamente por território com a economia.

Isso cria decisões importantes.

---

# 36. População deixa de existir como sistema central

Cidades não precisam mais crescer através de:

**comida → estoque → população → slots.**

Isso será removido ou reduzido a algo puramente visual, caso necessário.

O tamanho funcional da cidade será representado por:

**Nível da Cidade.**

---

# 37. Níveis de cidade

Proposta inicial:

**Cidade Nível I → II → III → IV**

O Centro Urbano pode ser melhorado através de Infraestrutura.

Cada nível oferece:

* maior território;
* mais resistência;
* acesso a determinadas construções;
* melhor capacidade urbana.

Valores e alcance exatos serão definidos posteriormente.

---

# 38. Expansão territorial

Uma nova cidade começa com território limitado.

Upgrades de nível aumentam sua capacidade territorial.

Possível estrutura:

### Cidade I

núcleo inicial.

### Cidade II

primeira expansão.

### Cidade III

cidade desenvolvida.

### Cidade IV

grande centro urbano.

Após o nível máximo, a cidade pode adquirir lentamente novos tiles automaticamente.

Esse crescimento deve ser lento.

A intenção é permitir evolução territorial sem reintroduzir uma simulação populacional completa.

---

# 39. Cidade desenvolvida

Para sistemas como condições de vitória, uma cidade desenvolvida pode ser definida simplesmente como:

**Cidade Nível III ou superior.**

Isso é muito mais claro que utilizar combinações como:

* população mínima;
* quantidade de slots;
* quantidade de construções.

---

# 40. Fortificações

Fortificações também serão simplificadas.

Exemplo:

**Muralhas I → Muralhas II → Fortaleza**

Cada nível substitui/aprimora o anterior.

Evitar acumular seis prédios diferentes de defesa cujos bônus são simplesmente somados.

Fortificações devem ser fortes o suficiente para exigir:

* Cerco;
* magia;
* planejamento.

Mas não tornar cidades invulneráveis.

---

# 41. Sinergia entre Cerco e Elementalismo

O jogo deve deliberadamente possuir interações entre árvores.

Exemplo:

1. cidade inimiga possui Fortaleza;
2. Elementalista usa Terremoto;
3. estrutura fica temporariamente fragilizada;
4. unidades de Cerco atacam;
5. dano contra muralha aumenta significativamente.

Isso exemplifica a filosofia da V2:

> **as melhores estratégias misturam sistemas.**

---

# 42. Recursos do mapa serão preservados

A V2 não eliminará o sistema atual de recursos territoriais.

O trabalho já realizado em:

* distribuição;
* biomas;
* clustering;
* geração;
* IA;

continua relevante.

Recursos passam a funcionar principalmente como:

**vantagens territoriais estratégicas.**

Eles não precisam criar novos inventários complexos.

---

# 43. Construtor

Será considerada uma unidade utilitária:

**Construtor.**

Função:

criar instalações em recursos existentes no mapa.

Possível funcionamento:

* possui aproximadamente 3 cargas;
* entra em um tile de recurso controlado;
* constrói a instalação correspondente;
* consome uma carga;
* instalação passa a gerar benefício.

O objetivo é criar vantagem rápida baseada em território.

A construção pode ser:

* instantânea após ação;
* ou exigir apenas tempo mínimo.

Não precisa competir diretamente com construções urbanas longas.

---

# 44. Função dos recursos territoriais

Proposta inicial:

## Ferro

Instalação:

**Mina de Ferro**

Possíveis benefícios:

* Produção;
* redução de custo de upgrades militares;
* bônus para Guerreiro/Guardião/Cerco.

---

## Cavalos

Instalação:

**Haras**

Possíveis benefícios:

* Suprimentos;
* velocidade de treino da Cavalaria;
* redução de custo de Cavalaria.

---

## Gemas

Instalação:

**Mina de Gemas**

Possíveis benefícios:

* Ouro;
* redução do custo monetário de upgrades;
* apoio à economia de elite.

---

## Seda

Instalação:

**Entreposto de Seda**

Benefício principal:

* Ouro.

Pode receber algum bônus adicional econômico simples se necessário.

---

## Nódulo Arcano

Instalação:

**Santuário do Nódulo**

Benefícios:

* Mana;
* eficiência ritual;
* importância para objetivos mágicos.

Nódulos devem continuar sendo territórios altamente disputados.

---

# 45. Recursos sem função devem ser removidos

Preservar o sistema não significa preservar todo recurso apenas por sunk cost.

Se um recurso:

* não gera decisão;
* duplica completamente outro;
* não possui razão estratégica;

pode ser removido.

A V2 deve preservar:

**o sistema de disputa territorial**

e não necessariamente:

**cada item existente na V1.**

---

# 46. Condições de vitória

A V2 possui três vitórias principais.

---

# 47. Vitória por Transcendência

Estrutura:

1. completar duas Escolas de Magia;
2. concluir duas Grandes Manifestações diferentes;
3. desbloquear Transcendência;
4. realizar o Ritual Final da Transcendência.

O Ritual Final deve:

* ser público;
* levar múltiplos turnos;
* custar Mana significativa;
* poder ser interrompido.

A vitória não precisa continuar exigindo inúmeros checklists paralelos se a nova economia já demonstra que aquela civilização possui infraestrutura arcana suficiente.

---

# 48. Vitória por Supremacia Militar

Estrutura geral:

1. completar duas Doutrinas;
2. desbloquear **Exército Supremo**;
3. provar supremacia através de conquistas de cidades desenvolvidas.

Direção recomendada:

> após atingir Exército Supremo, conquistar e manter pelo menos uma Cidade Nível III+ de cada rival relevante.

Civilizações já eliminadas contam como satisfeitas.

O requisito exato poderá ser calibrado após playtests.

O ponto principal é:

**a vitória deve exigir que o ápice militar seja demonstrado através de guerra real.**

---

# 49. Vitória por Dominação

Regra:

> **somente uma civilização permanece no jogo.**

Não importa quem eliminou os demais.

Se diferentes civilizações destruíram umas às outras e o jogador elimina o último rival restante:

vitória por Dominação.

É a condição mais absoluta de conquista.

---

# 50. Infraestrutura não possui vitória

Infraestrutura existe para suportar:

* guerra;
* magia;
* pesquisa;
* expansão.

Não existe:

* vitória econômica;
* vitória comercial;
* vitória industrial.

Isso preserva o foco de Aetherlands.

---

# 51. Diplomacia

Diplomacia continua existindo.

Mas ela deve servir principalmente para:

* guerra;
* paz;
* alianças;
* ameaças;
* relações estratégicas;
* reação a rituais;
* competição territorial.

A V2 não precisa desenvolver uma enorme simulação comercial/diplomática apenas para imitar Civilization.

---

# 52. Comércio tradicional deixa de ser prioridade

Sistemas como:

* rotas comerciais complexas;
* Mercadores;
* cadeias comerciais entre cidades;
* economia internacional detalhada;

podem ser removidos ou drasticamente simplificados.

Ouro deve vir principalmente de:

* território;
* infraestrutura;
* recursos;
* eventos;
* conquista.

---

# 53. Navegação e exploração

Mecânicas utilitárias ainda necessárias, como:

* embarque;
* exploração marítima;
* visão;
* postos avançados;

podem ser incorporadas principalmente na linha de:

**Logística/Infraestrutura**

ou oferecidas por progressão urbana apropriada.

Não precisam ocupar uma árvore de tecnologia generalista separada.

---

# 54. IA — direção futura

A IA será reformulada posteriormente com base no V2.

Ela deve pensar primeiro em:

**estratégia → composição → produção.**

E não:

**“qual unidade consigo produzir agora?”**

---

# 55. Estratégias da IA

Uma IA deve escolher uma orientação, por exemplo:

* Supremacia;
* Transcendência;
* defesa;
* expansão;
* guerra oportunista.

Essa orientação pode mudar durante a partida.

---

# 56. Composição da IA

A IA deve pensar em funções.

Exemplo:

* frontline;
* DPS;
* ranged;
* mobilidade;
* cerco;
* suporte mágico;
* counter.

Ela não deve produzir 40 unidades iguais apenas porque elas possuem bom score individual.

---

# 57. Adaptação da IA

A IA deve observar o inimigo.

Exemplos:

Inimigo possui muitos tanks:

→ aumentar dano mágico ou anti-blindagem.

Inimigo possui muitos Infernalistas:

→ Ladinos, mobilidade ou anti-magia.

Inimigo utiliza muita Cavalaria:

→ Guardiões preparados contra carga.

Inimigo utiliza fortificações:

→ Cerco + Elementalismo.

Inimigo utiliza muitos status prejudiciais:

→ Sagrada.

Essa adaptação deve ser gradual.

A IA não deve magicamente conhecer coisas que ainda não observou.

---

# 58. Grupos militares

A IA deve eventualmente pensar em exércitos como grupos.

Exemplo:

**Exército Norte**
Objetivo: capturar Cidade X.

**Reserva Central**
Objetivo: defender capital.

**Força Ritual**
Objetivo: defender Manifestação/Ritual.

Isso deve substituir comportamento de dezenas de unidades agindo sem coordenação.

---

# 59. Performance como requisito de design

A V2 deve deliberadamente reduzir:

* quantidade de unidades;
* quantidade de entidades mágicas;
* quantidade de microgerenciamento;
* quantidade de sistemas econômicos paralelos.

Necromancia em squads, upgrades de unidades e manutenção econômica também são decisões de performance.

Design e performance devem se apoiar.

---

# 60. Conteúdo legado

O conteúdo legado da V1 deve ser avaliado individualmente.

Ele pode ser:

* removido;
* convertido;
* incorporado;
* reutilizado.

Não deve permanecer apenas porque já existe.

Exemplos de assets/conceitos que podem ganhar nova função:

* Grifo → possível Lendário da Cavalaria;
* Golem → possível Manifestação Arcana ou outro elemento;
* Ent → possível Manifestação Druídica;
* unidades antigas → skins/evoluções;
* prédios antigos → reutilização visual.

---

# 61. Compatibilidade com saves

A V2 representa alteração estrutural suficientemente grande para que o design **não deva ser limitado pela necessidade de preservar perfeitamente saves da V1**.

Compatibilidade/migração será uma decisão técnica separada.

Durante desenvolvimento, é aceitável que partidas novas usem exclusivamente as regras V2.

---

# 62. O que Aetherlands V2 NÃO pretende ser

Aetherlands V2 não tenta ser:

* Civilization com magia;
* simulador político;
* simulador econômico profundo;
* simulador diplomático;
* city builder;
* grand strategy administrativa;
* RPG de personagem individual;
* RTS de centenas de tropas.

Ele utiliza elementos desses gêneros para criar:

> **um 4X de fantasia focado em composição e guerra estratégica.**

---

# 63. Princípios obrigatórios de design

Ao criar qualquer feature nova, perguntar:

### 1.

Isso cria uma decisão estratégica?

### 2.

Isso melhora composição de exército?

### 3.

Isso melhora guerra, posicionamento ou controle territorial?

### 4.

Isso sustenta algum desses sistemas?

### 5.

Isso é compreensível?

Se a resposta for não para praticamente tudo:

a feature provavelmente não pertence à V2.

---

# 64. Princípio da especialização

Cada sistema deve possuir uma função claramente reconhecível.

Uma Escola não deve tentar:

* causar dano;
* curar;
* teleportar;
* invocar;

ao mesmo tempo.

Uma Doutrina não deve tentar fazer tudo.

Uma unidade deve possuir:

**razão clara para existir numa composição.**

---

# 65. Princípio da counterplay

Toda estratégia forte deve possuir alguma resposta.

Exemplos:

Magos extremamente poderosos:

→ frágeis fisicamente.

Cavalaria extremamente móvel:

→ Guardião/anti-cavalaria/controle climático.

Cerco devastador:

→ Ladinos, mobilidade, ataques de flanco.

Necromancia numerosa:

→ dano em área, ataque ao Necromante.

Grande Manifestação:

→ Lendários, exércitos coordenados, counters específicos.

Fortaleza:

→ Cerco + magia apropriada.

Nenhuma estratégia deve ser universalmente correta.

---

# 66. Princípio do poder concentrado

Unidades avançadas devem oferecer:

**mais poder por tile.**

Um exército moderno e especializado deve conseguir enfrentar numericamente tropas ultrapassadas.

O jogador não deve ser incentivado a manter 40 soldados iniciais porque continuam sendo economicamente a melhor escolha.

---

# 67. Princípio da fragilidade mágica

Magia é poderosa porque possui:

* alto impacto;
* flexibilidade;
* capacidade de quebrar regras.

Por isso possui:

* Mana;
* cooldown;
* fragilidade;
* posicionamento;
* necessidade de proteção.

Um mago pego sozinho por uma unidade militar apropriada deve estar em sério perigo.

---

# 68. Princípio da simplicidade econômica

Economia deve criar restrições.

Não burocracia.

Se cinco recursos principais conseguem produzir decisões suficientes:

**não adicionar um sexto sem necessidade.**

Se um prédio pode simplesmente custar Ouro:

não fazê-lo consumir quatro recursos apenas para parecer profundo.

---

# 69. Princípio da cidade como suporte estratégico

Cidades existem para:

* produzir;
* pesquisar;
* sustentar;
* defender;
* projetar poder.

Não precisam possuir:

* dezenas de subsistemas civis;
* população detalhada;
* políticas locais;
* felicidade;
* religião;
* turismo;
* incontáveis especializações administrativas.

---

# 70. Identidade final do projeto

Aetherlands V2 deve produzir situações como:

> “Meu inimigo construiu uma composição extremamente defensiva de Guardiões e Necromantes. Vou aprofundar Infernal para ter AoE e usar Ladinos para tentar alcançar os Necromantes.”

Ou:

> “A cidade está fortificada demais. Vou pesquisar Terremoto no Elementalismo e combinar com minha doutrina de Cerco.”

Ou:

> “Estou perdendo a guerra, então vou usar Druidismo para fechar uma passagem enquanto termino minha Grande Manifestação.”

Ou:

> “Meu exército é pequeno, mas possui Patrulheiros Elite, um Arcanista e um Clérigo. Se eu conseguir manter posição, posso derrotar uma força numericamente maior.”

Ou:

> “Completei Guerreiro e Cavalaria. Preciso decidir se minha única Unidade Lendária será um Herói da Lâmina ou um Cavaleiro de Grifo.”

Essas são as histórias que a V2 deve produzir.

---

# 71. Resumo estrutural

## Progressão

**3 árvores:**

1. Doutrinas Militares;
2. Escolas de Magia;
3. Infraestrutura.

---

## Doutrinas

**6 × 9 + Exército Supremo = 55 pesquisas.**

* Guardião;
* Guerreiro;
* Patrulheiro;
* Cavalaria;
* Ladino;
* Cerco.

---

## Magia

**6 × 9 + Transcendência = 55 pesquisas.**

* Sagrada — sustain;
* Infernal — dano;
* Necromancia — mortos-vivos;
* Druidismo — terreno;
* Arcanismo — utilidade/mobilidade;
* Elementalismo — ambiente/clima.

---

## Infraestrutura

Aproximadamente:

**12–18 pesquisas.**

Focadas em:

* Ouro;
* Suprimentos;
* Mana;
* Produção;
* Conhecimento;
* cidades/fortificações.

---

## Economia

Cinco recursos fundamentais:

* Ouro;
* Suprimentos;
* Mana;
* Produção;
* Conhecimento.

---

## Unidades

Mundanas:

* ataque básico;
* evoluções físicas;
* técnicas;
* upkeep de Suprimentos.

Magos:

* sem ataque básico;
* sem progressão física;
* repertório crescente;
* Mana + cooldown.

---

## Grandes Rituais

Todos culminam em:

**Grandes Manifestações autônomas.**

---

## Lendários

**Uma Unidade Lendária ativa por civilização.**

---

## Cidade

Sem população tradicional.

Progressão através de:

**níveis urbanos.**

---

## Recursos do mapa

Continuam existindo.

Explorados através de:

**Construtor + instalações territoriais.**

---

## Vitórias

### Transcendência

duas Escolas + duas Manifestações + Ritual Final.

### Supremacia

duas Doutrinas + Exército Supremo + grandes conquistas militares.

### Dominação

última civilização restante.

---

# 72. Regra final da V2

A regra mais importante deste documento é:

> **Toda complexidade criada fora do campo de batalha deve, direta ou indiretamente, terminar em uma decisão interessante dentro dele.**

Aetherlands V2 não busca possuir mais sistemas.

Busca fazer seus sistemas restantes conversarem melhor entre si.

O objetivo é ser:

**menor em escopo, maior em profundidade.**

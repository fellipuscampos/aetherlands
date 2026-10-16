# Grandes Manifestações vinculadas — 15/10/2026

As seis entidades N9 passam a ser comandadas por objetivos persistentes. A lore de entidades submetidas aos
invocadores vira uma decisão estratégica: escolher **quem atacar ou proteger**, sem mover e lançar cada feitiço
manualmente. A entidade usa os mesmos resolvedores de movimento, combate, magias e efeitos visuais do restante do jogo.

## Uso e regras

- Selecionar a entidade abre quatro comandos: **Atacar cidade**, **Atacar unidade**, **Proteger cidade** e
  **Proteger unidade**. Escolher o alvo no mapa confirma; ESC cancela sem custo. A ordem atual aparece no painel.
- Atacar cidade exige guerra e cidade conhecida; atacar unidade exige hostilidade e visão. Proteção é de cidades
  e unidades próprias. A ordem não declara guerra. Alvos neutros hostis também podem ser atacados.
- A entidade decide ao encerrar o turno. Pode avançar e atacar se restar movimento, ou usar uma habilidade;
  consumir todo o movimento encerra suas ações. Reemitir uma ordem nunca concede ação adicional na mesma rodada.
- Uma entidade recém-invocada desperta na rodada seguinte. Sem ordem, guarda a cidade própria mais próxima;
  sem cidade, permanece no local e reage às ameaças que alcança.
- Proteção acompanha a unidade protegida, intercepta ameaças num raio de quatro tiles e mantém esse limite
  de perseguição depois de chegar à área. Ociosa e próxima ao alvo, fortifica para recuperar-se pelas regras normais.
- Um alvo que sai da visão é procurado no último local observado; sua posição real oculta não é seguida.
  Depois de duas rodadas de busca sem resultado em local visível, a entidade volta à proteção padrão.
  A morte de uma unidade protegida libera sua ordem; outra unidade no mesmo tile não herda sua identidade.
- Uma cidade conquistada passa a ser protegida. Paz, perda da cidade protegida ou alvo inexistente encerram
  objetivos incompatíveis. Guarnições precisam ser derrotadas antes de danificar uma cidade, dentro do alcance.
- Prioriza dano útil, abates, cura necessária, proteção e controle. Zonas de dano evitam tropas próprias e
  terceiros em paz. Terreno defensivo só conta se alguma unidade realmente receber a nova cobertura.
- A IA escolhe os mesmos quatro objetivos, incluindo proteção de sede de Transcendência e reação a cidades
  ameaçadas. A reação ao Dragão atribui objetivos, sem conceder uma segunda ação fora da fila.

## Balanceamento

Referência: atributos e custos da rodada de 14/10 (`BALANCE_PASS_2026-10-14.md`) e IA de 15/10
(`AI_ROUND_2026-10-15.md`). Nenhum mago mortal, tropa militar, técnica, fórmula de dano, pesquisa ou prédio foi
rebalanceado nesta alteração. Os valores específicos das seis entidades ficam em `V2ManifestationBalance.gd`.

| Entidade | Vida | Ataque | Alcance | Defesa mantida | PP mantidos | Mana de invocação |
|---|---:|---:|---:|---:|---:|---:|
| Serafim | 50 | 12 | 2 | 10,5 | 84 | 120 |
| Arquidemônio | 50 | 15 | 2 | 9 | 88 | 140 |
| Lich Soberano | 46 | 12 | 2 | 9 | 84 | 130 |
| Avatar da Natureza | 60 | 16 | 1 | 12 | 88 | 130 |
| Arconte do Véu | 46 | 13 | 2 | 8,5 | 88 | 140 |
| Primordial dos Elementos | 54 | 14 | 2 | 10 | 92 | 150 |

O ataque básico permite que as seis cumpram um cerco, inclusive Escolas de cura e controle. A Vida adicional
dá margem para a autonomia tomar decisões e para suportar sacrifícios, sem aumentar as defesas. Movimento,
voo, passivas, Suprimentos zero e limite de uma entidade ativa/em produção por Escola foram mantidos.

Feitiços comuns dessas entidades custam **zero Mana**. **Erguer Mortos e Erguer Legião mantêm 10/30 Mana e
os limites de Comando**: unidades permanentes adicionais continuam sendo investimento. Essas Hostes seguem
o controle normal já existente. Magias avançadas continuam pagando **35% da Vida máxima**, com as mesmas
recargas e efeitos da rodada anterior. A autonomia recusa um sacrifício que a deixaria abaixo de 25% da Vida.
Silêncio continua impedindo conjuração. Invocação é cobrada uma vez na conclusão da produção; falta de Mana
mantém o projeto pronto aguardando, sem perda dos PP.

O preço inicial em Mana dobrou, pagando a disponibilidade continuada das magias; os PP foram preservados
para não desfazer o ajuste recente do ritmo de produção. Serafim sustenta, Arquidemônio explode alvos,
Lich fornece Hostes/Comando, Avatar combina corpo a corpo e cobertura, Arconte mobilidade/controle,
Primordial usa áreas persistentes. Apoio e controle continuam precisando de escolta contra concentração de fogo.

Três partidas completas do laboratório, quatro IAs, mapa Grande e ecologia ativada (índices 0–2 da matriz
existente, limite 240), terminaram por Transcendência nos turnos **196, 157 e 151**. Houve produção e perda de
Manifestações durante as partidas. O novo investimento não bloqueou a vitória mágica nessa amostra; três
sementes não estabelecem distribuição de vitórias ou duração típica. Resumo reproduzível:
[bound_manifestations_matches_2026-10-15.json](balance/bound_manifestations_matches_2026-10-15.json).

### Verificação de combate

Na implementação inicial, `tools/balance/BoundManifestationProbe.tscn` executou 18 arenas com as ordens reais: cada entidade enfrentou um
Atirador de Elite N7, três Atiradores ou um Herói da Lâmina. Usa terreno plano, sem técnicas militares ou
veterania inicial; promoções conquistadas e suas curas continuam valendo. Hostes existentes usam a IA normal.
O inimigo concentra ataques respeitando alcance/movimento. Sem tiro de cidade ou cura entre rodadas.

Resultado bruto: [bound_manifestations_2026-10-15.json](balance/bound_manifestations_2026-10-15.json).
Todas vencem o Atirador isolado. Concentração de três Atiradores derruba Lich e Arconte; outras entidades
aguentam esse encontro. Arconte também perde o duelo com Herói da Lâmina. São testes de sanidade das
especializações, **não uma prova de balanceamento de todas as composições**. Serafim é particularmente forte
contra dano parcelado por sua cura, e Arquidemônio mantém a Condenação de 40 de dano com sacrifício.

## Desempenho e persistência

Não há novo `_process`, timer de IA ou busca durante frames ociosos. As ações humanas entram na fila gradual
já existente (dois itens por lote, intervalo de 0,12 s); rivais usam o mesmo executor dentro de sua própria fila.
No caminho síncrono dos testes, o resultado é equivalente. Um marcador por entidade impede repetir a ação.

Visibilidade de dono é calculada uma vez por rodada com entidades; ao avançar, só se incorpora o pequeno raio
local de visão. Alvos de habilidades vêm de raios locais e custos/recargas são validados sem uma segunda
varredura preliminar de alvos; a conjuração final mantém a validação canônica completa. O avanço usa uma
busca de alcançáveis. Apenas um desvio terrestre travado consulta A*; falhas repetidas alternam aproximações
e tentam novamente a cada terceira rodada. Embarque utiliza o roteador existente.

A rota de um contorno fica num cache transitório da entidade, revalidado contra os destinos alcançáveis
de cada rodada. Isso evita desfazer o contorno numa passagem em U e reduz buscas repetidas. Mudar o alvo
invalida o cache; renovar a mesma ordem o preserva. O cache não entra no save e é replanejado ao carregar.

O probe inclui uma medição de seis entidades com repertórios completos protegendo uma cidade num mapa
128×72. A versão inicial media vinte rodadas; desde o tuning, são 200 rodadas após vinte de aquecimento,
com a primeira rodada registrada separadamente. Ações de combate incluem execução dos efeitos existentes.
CPU de rodada não é FPS.

Saves persistem modo, identidade serial do alvo, última coordenada vista, busca, espera de nascimento e última
rodada de ação. Saves anteriores mantêm a fração de Vida ao migrar os seis novos máximos; ordens antigas de
Explorar/marcha são removidas apenas dessas entidades. Recargas, estados, Mana e identidades são preservados.
Não há cobrança retroativa de invocação.

Cobertura automatizada: quatro objetivos, nascimento, repetição de ordem, cerco/guarnição/alcance, proteção,
neblina e visão após avanço, paz/captura, alvo substituído, Mana, sacrifício, áreas, desvio terrestre, fila humana,
IA rival, seleção, banner/ESC, painel compacto e save/load antigo/atual. Conferência nativa não-headless:
1280×720 e 1920×1080, botões reais, atribuição do alvo, banner e avanço pelo turno gradual; cena descartável removida.

Verificação registrada: bateria de 34 arquivos, **525/525 testes e 8.695 asserts**; após o contorno persistente,
**118/118** nos fluxos/turnos/arte/IA e **40/40** na confirmação final das ordens e IA, incluindo o novo caso em U.
Os testes antigos de seleção/turnos/contexto foram isolados do estado global deixado por outros arquivos;
asserts de custo/ataque antigos foram atualizados apenas para as entidades. Magos mortais mantêm seus asserts.

## Revisão e tuning — 16/10/2026

Correções aplicadas exclusivamente à autonomia e à apresentação das entidades:

- Terreno explorado não revela uma cidade construída depois sob neblina: atacar exige visão ou memória
  explícita daquela cidade. Paz com um alvo de unidade observado encerra imediatamente a perseguição.
- Escolta retoma a aproximação ao protegido antes de apoio incidental quando está distante; sem ameaça
  imediata, mantém distância de até dois tiles. Curas pequenas não interrompem uma marcha ofensiva.
- A avaliação de cura considera a redução micótica e o custo de oportunidade de recargas longas.
- Cerco compara o dano previsto e a captura com ações contra unidades: eliminar uma ameaça importante pode
  superar um golpe comum na muralha. Uma captura possível continua tendo prioridade elevada.
- Um desvio terrestre pode terminar no anel de alcance da entidade, mesmo quando nenhum vizinho da cidade
  é transitável. Componentes de navegação descartam destinos desconectados antes do único A* permitido.
- Movimento e Passo Arcano evitam destinos com dano ambiental conhecido; a entidade tenta sair de uma zona
  de dano antes de comprometer sua ação. Desvios também revalidam destinos perigosos. Usa consultas esparsas
  de zona/infecção, sem reconstruir mapas de perigo ou conhecer ameaças em terreno não explorado.
- Arconte considera buffs inimigos, estados prejudiciais e zonas que afetam aliados para Dissipar; não fecha
  portais próprios como efeito colateral nem remove uma zona que esteja prejudicando o inimigo.
- Vendaval passa a contar a redução real do ataque à distância. Zonas sem dano avaliam penalidades aos
  aliados, em vez de proibir qualquer área que contenha um aliado. Zonas de dano continuam recusando
  ocupantes não hostis observados. Redução de visão tem peso menor que dano/controle direto.
- Apoio de baixo valor e zonas sem dano não substituem indefinidamente avançar numa ordem ofensiva.
  A entidade reconsidera essas opções depois de tentar aproximar-se, sem outra busca de alcançáveis.
- Ordem atribuída aparece mesmo durante a espera de nascimento. Habilidades exibem **Automática**, Mana e
  preço em Vida numa linha curta; explicação e impedimentos ficam no tooltip. A UI não procura alvos manuais
  para habilidades que não podem ser acionadas manualmente.

### Balanceamento e amostra

Vida, Ataque, Defesa, Mana/PP de invocação e atributos de tropas/magos mortais foram mantidos. O probe agora
executa **30 arenas**: além dos três cenários originais, três Guardiões e dois Heróis da Lâmina por entidade.
As entidades venceram **22/30** cenários antes e depois. Concentrar três Atiradores continua derrubando Lich
e Arconte; dois Heróis derrubam cinco das seis entidades. Arquidemônio vence os dois Heróis, pagando Vida
nas magias; Arconte continua sendo apoio/controle, não um duelista contra Lendários. Os inimigos do probe
usam ataques físicos concentrados, sem técnicas, kiting ou magias, portanto a amostra não mede adequadamente
o valor de Silêncio/Dissipar em composições. Esses usos têm cenários automatizados próprios.

Não há evidência nessa amostra para aumentar todos os atributos ou reduzir todos os custos. As decisões
melhoraram alguns tempos de abate sem alterar quais dos 30 encontros são vencidos. Isso não estabelece
equilíbrio de todas as formações, mapas ou durações de partida.

### Custo medido e validação

Comparação local sequencial, mesmo probe/mapa/repertórios, seis entidades ociosas, vinte rodadas de aquecimento
e **200 medidas**. Inclui uma varredura de visão do dono e as seis ações por rodada:

| CPU | Antes | Depois |
|---|---:|---:|
| Lote ocioso, mediana | 8,675 ms | 7,683 ms |
| Lote ocioso, p95 | 8,951 ms | 7,917 ms |
| Primeira rodada, incluindo inicialização | 63,659 ms | 50,879 ms |
| Decisões de combate, mediana | 2,281 ms | 1,999 ms |
| Decisões de combate, p95 | 15,073 ms | 11,756 ms |

O combate tem 120 decisões antes e 117 depois, pois a tática muda a duração de alguns encontros; seus
percentis descrevem o conjunto executado, não ações idênticas pareadas. A redução do lote ocioso é de cerca
de 11%; não é ganho de FPS nem garantia para toda configuração. Não houve novo trabalho por frame.
Identidade do alvo usa o último ocupante conhecido ou o índice esparso de unidades, em lugar de percorrer
todos os tiles visíveis. Passo Arcano ocioso não enumera destinos sem necessidade.

Dados: [antes](balance/manifestations_tuning_before_2026-10-15.json) e
[depois](balance/manifestations_tuning_after_2026-10-15.json). Para comparar um controlador anterior sem
trocar arquivos do jogo, o probe aceita `--orders-source=<cópia.gd>`; carrega a classe como script anônimo
somente dentro do laboratório. Comando normal:

```text
godot --headless --path . res://tools/balance/BoundManifestationProbe.tscn -- --out=user://manifestations_tuning.json
```

Bateria ampla: **537/537 testes, 8.747 asserts, 34 arquivos**. Após os últimos ajustes de prioridade/UI e
dois casos novos, confirmação dos fluxos, turnos, contexto e IA: **146/146 testes, 1.524 asserts**. São
13 casos novos de regressão nas ordens em relação à implementação inicial. A bateria ampla ainda emite
avisos de órfãos/recursos de fixtures antigas; o probe final e a confirmação dos fluxos encerraram sem
esses avisos. Conferência nativa única em 1280×720 e 1920×1080; o texto curto final foi conferido também
pelas medidas reais dos labels/fontes. Cena, script e UID descartáveis foram removidos.

Três smokes de quatro IAs com save/load no turno 60 carregaram com sucesso: duas Transcendências nos
turnos 157/151 e um timeout em 240. Na semente do timeout, a execução contínua venceu no turno 196.
O carregamento não reproduziu o mesmo desenrolar da partida; esses smokes verificam carregamento e
continuidade, não determinismo da simulação nem distribuição estatística de vitórias.

Com as prioridades finais, três execuções contínuas da mesma matriz terminaram por Transcendência nos
turnos **196, 157 e 151**. Resumo com sementes, carregamento, resultados e tempos:
[manifestations_tuning_matches_2026-10-16.json](balance/manifestations_tuning_matches_2026-10-16.json).

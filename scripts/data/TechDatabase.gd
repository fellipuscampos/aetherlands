class_name TechDatabase
extends RefCounted

## Arvore de TECNOLOGIA (mundana) — redesenho completo em 10 NIVEIS, pedido
## explicito do usuario com diagrama pronto (substitui a arvore anterior de
## 9 tecnologias numa cadeia classica de pre-requisito especifico).
##
## Regra de progressao NOVA — "2 de N do nivel atual libera o proximo
## INTEIRO": pesquisar QUAISQUER 2 tecnologias do Nivel N libera todas as
## do Nivel N+1 pra pesquisa (nao sao cumulativas, o jogador escolhe seu
## proprio caminho e ignora o resto). Tecnologias de niveis ja liberados
## continuam pesquisaveis pra sempre — desbloquear o nivel seguinte NAO
## torna as anteriores obsoletas. Implementado via TechData.tier (1..10,
## ver TechData.gd) + available_techs() abaixo, que substitui o antigo
## "todos os pre-requisitos concluidos" por uma contagem por nivel.
##
## TechData.prerequisites CONTINUA existindo em cada tech, mas mudou de
## papel: nao decide mais disponibilidade (isso agora e so tier +
## contagem), vira uma ancora cosmetica de familia — TechTree.gd continua
## usando isso pra agrupar/alinhar/desenhar linha entre techs da mesma
## familia (_compute_components/_compute_rows/_align_rows_within_group/
## _draw, nenhum desses mudou) — e RivalAI._score_research_candidate
## continua lendo isso como uma PREFERENCIA suave (nao mais um bloqueio).
## Ver comentario do campo em TechData.gd pra mais detalhe.
##
## A arvore de MAGIA (MagicDatabase.gd) NAO muda nesta rodada — continua
## 100% no modelo antigo de pre-requisito em cadeia, 4 tiers, 7 escolas.
##
## Familias cosmeticas de PREREQUISITES (ancora de layout/preferencia de IA,
## NAO confundir com TechData.display_family, ver abaixo) desta rodada
## (blocos que TechTree.gd agrupa visualmente por conectividade de
## prerequisites, maior primeiro):
## - MILITAR (o tronco principal): Quartel -> Homem de Armas/Quartel II/
##   Estabulo/Campo de Tiro/Arsenal de Cerco -> ramifica em infantaria
##   (Espadachim/Lanceiro/Quartel III/Homem de Escudo/Halberdier/Campeao/
##   Quartel de Elite/General/Exercito Supremo), cavalaria (Cavaleiro/
##   Batedor Montado/Estabulo II/Cavaleiro Pesado/Cavaleiro de Choque/
##   Cavalaria Blindada/Cavaleiro Imperial), arqueiros (Arqueiro/Campo de
##   Tiro II/Besteiro) e cerco (Balista/Ariete/Torre de Cerco/Catapulta/
##   Trebuchet/Engenheiro de Cerco/Grande Arsenal/Bombarda/Colosso de
##   Cerco).
## - ECONOMIA: Celeiro -> Oficina -> Mercado -> Mercador/Grande Mercado ->
##   Grande Emporio/Rotas Comerciais; Oficina II/Celeiro II/Mercado II
##   tambem ancoram nos respectivos originais.
## - DEFESA: Muralhas -> Torre de Vigia -> Fortaleza -> Fortaleza Imperial;
##   Muralhas II tambem ancora em Muralhas (proprio componente, nao cruza
##   com Militar — mesmo espirito de Muralhas ser standalone na arvore
##   anterior).
## - Guarda, Batedor, Navegacao, Guarnicao, Infraestrutura Rural e Posto
##   Avancado ficam cada um sozinho no proprio componente (sem ancora
##   nenhuma) — opcoes que nao puxam nem sao puxadas por nenhuma outra tech
##   tematicamente.
##
## TechData.display_family (Roadmap "polimento definitivo V1") e uma
## classificacao DIFERENTE e INDEPENDENTE — campo de dado real (nao mais
## inferencia hardcoded em TechTierBoard.gd), usado SO pra apresentacao
## visual/filtro da UI (agrupamento MILITAR/ECONOMIA/DEFESA/EXPLORACAO_
## UTILIDADE dentro de cada nivel) — nunca afeta disponibilidade. Setado
## tech a tech abaixo, sem tabela central (ver cada var.display_family).
##
## Pesquisa e paga com "ciencia" = soma da populacao das cidades por turno
## (ver GameManager._process_research) — isso nao mudou. O slot de
## pesquisa ativa (PlayerData.current_research/research_progress) continua
## UNICO e compartilhado com MagicDatabase — o jogador so pesquisa uma
## coisa de cada vez, seja Tecnologia ou Magia.
##
## Roadmap "polimento definitivo V1" (SEGUNDA e ULTIMA calibracao de
## pacing, pedido explicito do usuario — nao itero mais alem desta):
## custo = round(13 * 1.567^(tier-1)), MESMO valor pra TODAS as techs de
## um nivel (sem ajuste tech a tech) — 13, 20, 32, 50, 78, 123, 192, 302,
## 473, 741 pros niveis 1-10. Alvo desta rodada (mais permissivo que a
## rodada anterior): Nivel 5 ~T60-80, Nivel 7 ~T100-130, Nivel 10
## ~T150-180, "fim efetivo do endgame tecnologico" ~T180-220.
##
## Historico: a calibracao da rodada "polimento e coesao" (base 13,
## crescimento 1.358 — Nivel 10 = 204) rodou no harness (test_simulation_
## balance.gd, 15 seeds x 200 turnos) e saiu Nivel 10 medio T109.7 —
## abaixo do alvo daquela rodada (T195-210), mas coincidentemente PERTO do
## alvo desta rodada nova (T150-180), sinal empirico de que turno de
## chegada escala BEM mais devagar que o custo (aproximadamente
## custo^0.32) — a populacao/ciencia do jogo cresce rapido demais pro
## custo sozinho conseguir esticar o jogo proporcionalmente. Aumentei
## o expoente de novo (1.358 -> 1.567) mirando o novo alvo T150-180 no
## Nivel 10; o resultado REAL desta rodada fica registrado no relatorio da
## tarefa, nao neste comentario (evita ficar desatualizado a cada nova
## observacao de harness) — pedido explicito do usuario: medir uma vez e
## reportar com honestidade, mesmo que fique fora da faixa, sem uma
## terceira rodada de ajuste.

static var _cache: Dictionary = {} # id -> TechData, montada uma vez por sessao

## Quantas tecnologias pesquisadas de um NIVEL sao necessarias pra abrir o
## nivel seguinte inteiro — pedido do usuario: "pesquisar 2 tecnologias do
## nivel atual" (nao e cumulativo, nao importa QUAIS 2, so a contagem).
const TIER_UNLOCK_THRESHOLD := 2

static func _build_all() -> Dictionary:
	var techs: Dictionary = {}

	# --- NIVEL 1 — Fundacao (4 techs, sem pre-requisito) --------------------

	var quartel := TechData.new()
	quartel.id = "quartel"
	quartel.tier = 1
	quartel.display_name = "Quartel"
	quartel.cost = 13.0
	quartel.unlocks_building = "barracks"
	quartel.display_family = TechData.FAMILY_MILITAR
	quartel.effect_text = "Permite construir o Quartel e treinar infantaria."
	quartel.description = "Um conselho de veteranos formaliza turnos de guarda, manobras e a forja de armaduras — o primeiro passo de qualquer exercito de verdade."
	techs[quartel.id] = quartel

	var celeiro := TechData.new()
	celeiro.id = "celeiro"
	celeiro.tier = 1
	celeiro.display_name = "Celeiro"
	celeiro.cost = 13.0
	celeiro.unlocks_building = "granary"
	celeiro.display_family = TechData.FAMILY_ECONOMIA
	celeiro.effect_text = "Permite construir o Celeiro: aumenta o limite de armazenamento de comida."
	celeiro.description = "Mestres-celeireiros aprendem a selar silos contra umidade, ratos e o inverno mais longo — o alicerce de qualquer excedente de comida de verdade."
	techs[celeiro.id] = celeiro

	# unlocks_unit = "warrior" — Guarda deixa de ser sempre-liberado
	# (fail-open hardcoded de antes) e vira uma escolha de verdade do Nivel
	# 1, pedido do usuario no desenho novo. Sem predio associado (mesmo
	# padrao zero-predio que Colonizador ja usa) — Guarda continua a tropa
	# mais barata e simples do jogo, so agora precisa ser pesquisada.
	var guarda := TechData.new()
	guarda.id = "guarda"
	guarda.tier = 1
	guarda.display_name = "Guarda"
	guarda.cost = 13.0
	guarda.unlocks_unit = "warrior"
	guarda.display_family = TechData.FAMILY_MILITAR
	guarda.effect_text = "Libera o Guarda: unidade de combate barata e simples, disponível desde já."
	guarda.description = "Treinamento rapido, dano baixo, defesa modesta — a tropa mais simples do jogo, ideal pra formar exercito rapido no comeco de qualquer campanha."
	techs[guarda.id] = guarda

	# unlocks_unit = "scout" — mesma logica de Guarda acima: Batedor vira
	# escolha de Nivel 1, sem predio. "Batedor Montado" (Nivel 3, unidade
	# NOVA e distinta) e quem agora usa o Estabulo — Batedor simples fica
	# livre de qualquer requisito de construcao.
	var batedor := TechData.new()
	batedor.id = "batedor"
	batedor.tier = 1
	batedor.display_name = "Batedor"
	batedor.cost = 13.0
	batedor.unlocks_unit = "scout"
	batedor.display_family = TechData.FAMILY_EXPLORACAO_UTILIDADE
	batedor.effect_text = "Libera o Batedor: unidade de exploração rápida, visão ampla, combate fraco."
	batedor.description = "Movimentacao alta, visao ampla, combate fraco — a opcao de reconhecimento barata pra mapear o territorio antes de qualquer outra coisa."
	techs[batedor.id] = batedor

	# --- NIVEL 2 (adicional) — nova, ver secao "redistribuicao de familia" do
	# roadmap "polimento definitivo V1": Nivel 2 tinha 3 Militar/1 Economia,
	# nenhuma opcao de Defesa. Guarnicao preenche essa lacuna com uma opcao
	# defensiva barata e cedo, sem depender de Muralhas (Nivel 5) — reusa so
	# BuildingData.defense_bonus, mesmo campo que Muralhas/Torre de
	# Vigia/Fortaleza ja usam.
	var guarnicao := TechData.new()
	guarnicao.id = "guarnicao"
	guarnicao.tier = 2
	guarnicao.display_name = "Guarnição"
	guarnicao.cost = 20.0
	guarnicao.prerequisites = ["quartel"]
	guarnicao.unlocks_building = "garrison"
	guarnicao.display_family = TechData.FAMILY_DEFESA
	guarnicao.effect_text = "Permite construir a Guarnição: pequeno bônus de defesa para a cidade."
	guarnicao.description = "Postos de vigilancia e paliçadas simples ao redor da cidade — pouco custo, defesa modesta, disponivel bem cedo."
	techs[guarnicao.id] = guarnicao

	# --- NIVEL 2 — Primeiras especializacoes (4 techs) ----------------------

	# id novo ("campo_de_tiro", nao mais "arquearia") — separado da unidade
	# que desbloqueia (ver tech "arqueiro" abaixo): a arvore antiga
	# misturava predio+unidade numa tech so, a nova separa os dois nos.
	var campo_de_tiro := TechData.new()
	campo_de_tiro.id = "campo_de_tiro"
	campo_de_tiro.tier = 2
	campo_de_tiro.display_name = "Campo de Tiro"
	campo_de_tiro.cost = 20.0
	campo_de_tiro.prerequisites = ["quartel"]
	campo_de_tiro.unlocks_building = "archery_range"
	campo_de_tiro.display_family = TechData.FAMILY_MILITAR
	campo_de_tiro.effect_text = "Permite construir o Campo de Tiro e treinar unidades de ataque à distância."
	campo_de_tiro.description = "Permite treinar unidades de ataque a distancia — o primeiro passo pra qualquer exercito deixar de depender so de combate corpo a corpo."
	techs[campo_de_tiro.id] = campo_de_tiro

	var oficina := TechData.new()
	oficina.id = "oficina"
	oficina.tier = 2
	oficina.display_name = "Oficina"
	oficina.cost = 20.0
	oficina.prerequisites = ["celeiro"]
	oficina.unlocks_building = "workshop"
	oficina.display_family = TechData.FAMILY_ECONOMIA
	oficina.effect_text = "Permite construir a Oficina: aumenta a produção da cidade."
	oficina.description = "Com os celeiros cheios e a fome afastada, sobra tempo pra especializar: bancadas, foles e ferramentas num unico telhado aumentam a producao da cidade."
	techs[oficina.id] = oficina

	var arqueiro := TechData.new()
	arqueiro.id = "arqueiro"
	arqueiro.tier = 2
	arqueiro.display_name = "Arqueiro"
	arqueiro.cost = 20.0
	arqueiro.prerequisites = ["campo_de_tiro"]
	arqueiro.unlocks_unit = "archer"
	arqueiro.display_family = TechData.FAMILY_MILITAR
	arqueiro.effect_text = "Libera o Arqueiro: dano à distância barato, útil em qualquer composição de exército."
	arqueiro.description = "Puxar a corda, mirar e soltar parece simples ate a centesima flecha perdida — dano a distancia barato, util em qualquer composicao de exercito."
	techs[arqueiro.id] = arqueiro

	var homem_de_armas := TechData.new()
	homem_de_armas.id = "homem_de_armas"
	homem_de_armas.tier = 2
	homem_de_armas.display_name = "Homem de Armas"
	homem_de_armas.cost = 20.0
	homem_de_armas.prerequisites = ["quartel"]
	homem_de_armas.unlocks_unit = "men_at_arms"
	homem_de_armas.display_family = TechData.FAMILY_MILITAR
	homem_de_armas.effect_text = "Libera o Homem de Armas: infantaria profissional, mais forte que o Guarda."
	homem_de_armas.description = "Infantaria profissional: mais forte que o Guarda comum, em troca de treino mais lento e caro — o generalista de qualquer exercito serio."
	techs[homem_de_armas.id] = homem_de_armas

	# --- NIVEL 3 — Cavalaria e economia (6 techs) ---------------------------

	var estabulo := TechData.new()
	estabulo.id = "estabulo"
	estabulo.tier = 3
	estabulo.display_name = "Estábulo"
	estabulo.cost = 32.0
	estabulo.prerequisites = ["quartel"]
	estabulo.unlocks_building = "stable"
	estabulo.display_family = TechData.FAMILY_MILITAR
	estabulo.effect_text = "Permite construir o Estábulo e treinar cavalaria."
	estabulo.description = "Um mestre-cavalarico codifica as tecnicas de doma, ferracao e equipagem de guerra — o alicerce necessario antes de qualquer cavalo de batalha de verdade."
	techs[estabulo.id] = estabulo

	var mercado := TechData.new()
	mercado.id = "mercado"
	mercado.tier = 3
	mercado.display_name = "Mercado"
	mercado.cost = 32.0
	mercado.prerequisites = ["oficina"]
	mercado.unlocks_building = "market"
	mercado.display_family = TechData.FAMILY_ECONOMIA
	mercado.effect_text = "Permite construir o Mercado: mais ouro por turno e libera comprar produção com ouro (rush-buy)."
	mercado.description = "Um conselho de mercadores padroniza pesos, cambio e cadernos de credito — libera rotas comerciais e o uso de ouro pra apressar producao (rush-buy)."
	techs[mercado.id] = mercado

	var cavaleiro := TechData.new()
	cavaleiro.id = "cavaleiro"
	cavaleiro.tier = 3
	cavaleiro.display_name = "Cavaleiro"
	cavaleiro.cost = 32.0
	cavaleiro.prerequisites = ["estabulo"]
	cavaleiro.unlocks_unit = "cavalry"
	cavaleiro.display_family = TechData.FAMILY_MILITAR
	cavaleiro.effect_text = "Libera o Cavaleiro: alta mobilidade, bom dano, ótimo para perseguir inimigos em fuga."
	cavaleiro.description = "Alta mobilidade, bom dano, capacidade de perseguir unidades em fuga — a base de qualquer forca de choque montada."
	techs[cavaleiro.id] = cavaleiro

	# unlocks_unit = "batedor_montado" (kind NOVO, distinto de "scout") —
	# pedido do usuario: "transforma a linha de Batedor numa unidade muito
	# mais rapida". Diferente da arvore antiga (onde essa tech desbloqueava
	# o MESMO kind "scout"), agora e uma unidade propria mais forte, ver
	# UnitDatabase.
	var batedor_montado := TechData.new()
	batedor_montado.id = "batedor_montado"
	batedor_montado.tier = 3
	batedor_montado.display_name = "Batedor Montado"
	batedor_montado.cost = 32.0
	batedor_montado.prerequisites = ["estabulo"]
	batedor_montado.unlocks_unit = "batedor_montado"
	batedor_montado.display_family = TechData.FAMILY_EXPLORACAO_UTILIDADE
	batedor_montado.effect_text = "Libera o Batedor Montado: exploração mais rápida e com mais alcance de visão que o Batedor comum."
	batedor_montado.description = "Um batedor a cavalo troca ainda mais dano por velocidade e alcance de visao — enxerga o que esta alem da proxima colina antes de qualquer outra pessoa."
	techs[batedor_montado.id] = batedor_montado

	var mercador := TechData.new()
	mercador.id = "mercador"
	mercador.tier = 3
	mercador.display_name = "Mercador"
	mercador.cost = 32.0
	mercador.prerequisites = ["mercado"]
	mercador.unlocks_unit = "mercador"
	mercador.display_family = TechData.FAMILY_EXPLORACAO_UTILIDADE
	mercador.effect_text = "Libera o Mercador: envie a uma cidade em paz para estabelecer uma rota e receber 25 ouro."
	mercador.description = "Uma unidade civil dedicada a abrir e manter rotas comerciais entre cidades — o excedente da Oficina finalmente tem pra onde escoar."
	techs[mercador.id] = mercador

	# Standalone (sem ancora de familia, proprio componente) — mesmo
	# espirito de Muralhas na arvore anterior. Preserva o modo "Embarcar"
	# que ja existe (Unit.embarked/SelectionManager.toggle_embark_selected),
	# unica forma de alcancar os continentes Vulcanico/de Cristal. Conta
	# NORMALMENTE pra regra "2 de N" do Nivel 3 — sem excecao especial.
	var navegacao := TechData.new()
	navegacao.id = "navegacao"
	navegacao.tier = 3
	navegacao.display_name = "Navegação"
	navegacao.cost = 32.0
	navegacao.display_family = TechData.FAMILY_EXPLORACAO_UTILIDADE
	navegacao.effect_text = "Libera o modo Embarcar: move unidades pelo oceano até avistar terra de novo."
	navegacao.description = "Cascos calafetados e a leitura das correntes permitem que um exercito inteiro se arrisque mar adentro ate avistar terra de novo."
	techs[navegacao.id] = navegacao

	# --- NIVEL 4 — Guerra especializada (4 techs) ---------------------------

	var arsenal_de_cerco := TechData.new()
	arsenal_de_cerco.id = "arsenal_de_cerco"
	arsenal_de_cerco.tier = 4
	arsenal_de_cerco.display_name = "Arsenal de Cerco"
	arsenal_de_cerco.cost = 50.0
	arsenal_de_cerco.prerequisites = ["quartel"]
	arsenal_de_cerco.unlocks_building = "siege_workshop"
	arsenal_de_cerco.display_family = TechData.FAMILY_MILITAR
	arsenal_de_cerco.effect_text = "Permite construir o Arsenal de Cerco e treinar máquinas de guerra."
	arsenal_de_cerco.description = "Permite treinar maquinas de guerra — o primeiro passo de qualquer exercito capaz de derrubar muros, nao so tropas."
	techs[arsenal_de_cerco.id] = arsenal_de_cerco

	# Reclassificada Militar -> Defesa (pedido do usuario, revisao do plano):
	# a descricao ja a enquadra como anti-cavalaria/defensiva ("bom controle
	# defensivo e vantagem contra cavalaria") — nao e reclassificacao
	# arbitraria, so torna explicito o que o texto ja dizia. Tier/custo/
	# unlocks_unit continuam identicos.
	var lanceiro := TechData.new()
	lanceiro.id = "lanceiro"
	lanceiro.tier = 4
	lanceiro.display_name = "Lanceiro"
	lanceiro.cost = 50.0
	lanceiro.prerequisites = ["quartel"]
	lanceiro.unlocks_unit = "lanceiro"
	lanceiro.display_family = TechData.FAMILY_DEFESA
	lanceiro.effect_text = "Libera o Lanceiro: forte contra cavalaria, fraco contra alvos blindados."
	lanceiro.description = "Bom controle defensivo e vantagem contra cavalaria, em troca de fraqueza contra alvos fortemente blindados."
	techs[lanceiro.id] = lanceiro

	var espadachim := TechData.new()
	espadachim.id = "espadachim"
	espadachim.tier = 4
	espadachim.display_name = "Espadachim"
	espadachim.cost = 50.0
	espadachim.prerequisites = ["quartel"]
	espadachim.unlocks_unit = "espadachim"
	espadachim.display_family = TechData.FAMILY_MILITAR
	espadachim.effect_text = "Libera o Espadachim: ataque forte, ótimo para romper linhas inimigas."
	espadachim.description = "Ataque forte, defesa mediana, custo maior — excelente pra romper linhas inimigas."
	techs[espadachim.id] = espadachim

	var quartel_2 := TechData.new()
	quartel_2.id = "quartel_2"
	quartel_2.tier = 4
	quartel_2.display_name = "Quartel II"
	quartel_2.cost = 50.0
	quartel_2.prerequisites = ["quartel"]
	quartel_2.unlocks_building = "barracks_2"
	quartel_2.display_family = TechData.FAMILY_MILITAR
	quartel_2.effect_text = "Melhora o Quartel: abre a porta para infantaria mais especializada."
	quartel_2.description = "Melhora o Quartel original — mais eficiencia de treinamento, e a porta de entrada pra infantaria mais especializada (Espadachim/Lanceiro)."
	techs[quartel_2.id] = quartel_2

	# Nova (roadmap "polimento definitivo V1"): Nivel 4 era 100% Militar
	# (regra dura do pedido: nenhum nivel pode ficar assim). Sem
	# predio/unidade propria — reusa bonus_terrain_types/bonus_production
	# (TechDatabase.yield_bonus_for/City.collect_yields), o MESMO mecanismo
	# que MagicDatabase ja usa pra bonus de bioma, nunca usado por
	# Tecnologia ate agora.
	var infraestrutura := TechData.new()
	infraestrutura.id = "infraestrutura"
	infraestrutura.tier = 4
	infraestrutura.display_name = "Infraestrutura Rural"
	infraestrutura.cost = 50.0
	infraestrutura.bonus_terrain_types = [HexTileData.TerrainType.PLAINS, HexTileData.TerrainType.GRASSLAND]
	infraestrutura.bonus_production = 1
	infraestrutura.display_family = TechData.FAMILY_ECONOMIA
	infraestrutura.effect_text = "+1 de produção em qualquer terreno de Planície ou Campina trabalhado."
	infraestrutura.description = "Estradas de terra batida, celeiros comunais e turnos de trabalho organizados — nada revolucionario, so o campo produzindo um pouco mais todo santo dia."
	techs[infraestrutura.id] = infraestrutura

	# --- NIVEL 5 — Defesa e maquinas de guerra (4 techs) --------------------

	var muralhas := TechData.new()
	muralhas.id = "muralhas"
	muralhas.tier = 5
	muralhas.display_name = "Muralhas"
	muralhas.cost = 78.0
	muralhas.unlocks_building = "walls"
	muralhas.display_family = TechData.FAMILY_DEFESA
	muralhas.effect_text = "Permite construir Muralhas ao redor da cidade: bônus de defesa para tropas guarnecidas."
	muralhas.description = "Um mestre-pedreiro ergue um anel de pedra alto o bastante pra deter um ariete — o alicerce de qualquer cidade que pretenda sobreviver a um cerco."
	techs[muralhas.id] = muralhas

	var torre_de_vigia := TechData.new()
	torre_de_vigia.id = "torre_de_vigia"
	torre_de_vigia.tier = 5
	torre_de_vigia.display_name = "Torre de Vigia"
	torre_de_vigia.cost = 78.0
	torre_de_vigia.prerequisites = ["muralhas"]
	torre_de_vigia.unlocks_building = "watchtower"
	torre_de_vigia.display_family = TechData.FAMILY_DEFESA
	torre_de_vigia.effect_text = "Permite construir a Torre de Vigia: bônus de defesa adicional para a cidade."
	torre_de_vigia.description = "Melhora a visao, o alerta e a defesa local da cidade — sentinelas avistam o inimigo antes dele chegar ao pe do muro."
	techs[torre_de_vigia.id] = torre_de_vigia

	# Reclassificada Militar -> Defesa (pedido do usuario, revisao do plano):
	# a propria descricao ja a enquadra como defensiva ("o tanque da
	# infantaria... excelente pra proteger"). Tier/custo/unlocks_unit
	# continuam identicos.
	var homem_de_escudo := TechData.new()
	homem_de_escudo.id = "homem_de_escudo"
	homem_de_escudo.tier = 5
	homem_de_escudo.display_name = "Homem de Escudo"
	homem_de_escudo.cost = 78.0
	homem_de_escudo.prerequisites = ["quartel"]
	homem_de_escudo.unlocks_unit = "homem_de_escudo"
	homem_de_escudo.display_family = TechData.FAMILY_DEFESA
	homem_de_escudo.effect_text = "Libera o Homem de Escudo: HP e defesa altos, ótimo para proteger tropas atrás da linha de frente."
	homem_de_escudo.description = "O tanque da infantaria: HP alto, defesa alta, dano baixo — excelente pra proteger arqueiros e maquinas de cerco atras da linha de frente."
	techs[homem_de_escudo.id] = homem_de_escudo

	var catapulta := TechData.new()
	catapulta.id = "catapulta"
	catapulta.tier = 5
	catapulta.display_name = "Catapulta"
	catapulta.cost = 78.0
	catapulta.prerequisites = ["arsenal_de_cerco"]
	catapulta.unlocks_unit = "catapult"
	catapulta.display_family = TechData.FAMILY_MILITAR
	catapulta.effect_text = "Libera a Catapulta: dano de cerco contra cidades e grupos de inimigos agrupados."
	catapulta.description = "Cerco basico: dano contra cidades, estruturas e grupos de inimigos agrupados."
	techs[catapulta.id] = catapulta

	# --- NIVEL 6 — Exercito profissional (6 techs) --------------------------

	var besteiro := TechData.new()
	besteiro.id = "besteiro"
	besteiro.tier = 6
	besteiro.display_name = "Besteiro"
	besteiro.cost = 123.0
	besteiro.prerequisites = ["campo_de_tiro"]
	besteiro.unlocks_unit = "besteiro"
	besteiro.display_family = TechData.FAMILY_MILITAR
	besteiro.effect_text = "Libera o Besteiro: disparos com +30% de ataque contra unidades blindadas."
	besteiro.description = "Projéteis de aço atravessam as armaduras que detêm as flechas comuns."
	techs[besteiro.id] = besteiro

	var cavaleiro_pesado := TechData.new()
	cavaleiro_pesado.id = "cavaleiro_pesado"
	cavaleiro_pesado.tier = 6
	cavaleiro_pesado.display_name = "Cavaleiro Pesado"
	cavaleiro_pesado.cost = 123.0
	cavaleiro_pesado.prerequisites = ["estabulo"]
	cavaleiro_pesado.unlocks_unit = "cavaleiro_pesado"
	cavaleiro_pesado.display_family = TechData.FAMILY_MILITAR
	cavaleiro_pesado.effect_text = "Libera o Cavaleiro Pesado: mais resistente e com mais poder de choque, menos mobilidade."
	cavaleiro_pesado.description = "Mais resistente que o Cavaleiro comum, em troca de menos mobilidade — mais poder de choque, menos velocidade de perseguicao."
	techs[cavaleiro_pesado.id] = cavaleiro_pesado

	var balista := TechData.new()
	balista.id = "balista"
	balista.tier = 6
	balista.display_name = "Balista"
	balista.cost = 123.0
	balista.prerequisites = ["arsenal_de_cerco"]
	balista.unlocks_unit = "balista"
	balista.display_family = TechData.FAMILY_MILITAR
	balista.effect_text = "Libera a Balista: cerco de alto dano contra um único alvo."
	balista.description = "Cerco direcionado: muito dano contra um unico alvo, pouca area de efeito — o oposto complementar da Catapulta."
	techs[balista.id] = balista

	var campo_de_tiro_2 := TechData.new()
	campo_de_tiro_2.id = "campo_de_tiro_2"
	campo_de_tiro_2.tier = 6
	campo_de_tiro_2.display_name = "Campo de Tiro II"
	campo_de_tiro_2.cost = 123.0
	campo_de_tiro_2.prerequisites = ["campo_de_tiro"]
	campo_de_tiro_2.unlocks_building = "archery_range_2"
	campo_de_tiro_2.display_family = TechData.FAMILY_MILITAR
	campo_de_tiro_2.effect_text = "Melhora o Campo de Tiro: abre a porta para o Besteiro."
	campo_de_tiro_2.description = "Melhora o Campo de Tiro original — abre a porta pro Besteiro e futuras tropas de longo alcance."
	techs[campo_de_tiro_2.id] = campo_de_tiro_2

	# Reclassificada Militar -> Economia (pedido do usuario, revisao do
	# plano): so desbloqueia um PREDIO, nenhuma unidade nova — estruturalmente
	# identica a Oficina II abaixo, que ja e Economia pela mesma razao.
	# Corrige o Nivel 6, que estava concentrado demais (5 Militar/1 Economia).
	var estabulo_2 := TechData.new()
	estabulo_2.id = "estabulo_2"
	estabulo_2.tier = 6
	estabulo_2.display_name = "Estábulo II"
	estabulo_2.cost = 123.0
	estabulo_2.prerequisites = ["estabulo"]
	estabulo_2.unlocks_building = "stable_2"
	estabulo_2.display_family = TechData.FAMILY_ECONOMIA
	estabulo_2.effect_text = "Melhora o Estábulo: abre a porta para cavalaria mais pesada."
	estabulo_2.description = "Melhora o Estabulo original — abre a porta pra cavalaria mais pesada."
	techs[estabulo_2.id] = estabulo_2

	var oficina_2 := TechData.new()
	oficina_2.id = "oficina_2"
	oficina_2.tier = 6
	oficina_2.display_name = "Oficina II"
	oficina_2.cost = 123.0
	oficina_2.prerequisites = ["oficina"]
	oficina_2.unlocks_building = "workshop_2"
	oficina_2.display_family = TechData.FAMILY_ECONOMIA
	oficina_2.effect_text = "Melhora a Oficina: mais produção para a cidade."
	oficina_2.description = "Melhora a Oficina original — mais producao, ferramentas mais especializadas."
	techs[oficina_2.id] = oficina_2

	# Nova (roadmap "polimento definitivo V1"): preenche a unica cadeia
	# economica sem upgrade nenhum ate agora (Oficina/Estabulo/Campo de
	# Tiro/Quartel ja tem "II", Celeiro nunca ganhou).
	var celeiro_2 := TechData.new()
	celeiro_2.id = "celeiro_2"
	celeiro_2.tier = 6
	celeiro_2.display_name = "Celeiro II"
	celeiro_2.cost = 123.0
	celeiro_2.prerequisites = ["celeiro"]
	celeiro_2.unlocks_building = "granary_2"
	celeiro_2.display_family = TechData.FAMILY_ECONOMIA
	celeiro_2.effect_text = "Melhora o Celeiro: aumenta ainda mais o limite de armazenamento de comida."
	celeiro_2.description = "Silos maiores, secagem mais eficiente — o excedente de comida da cidade cresce de novo."
	techs[celeiro_2.id] = celeiro_2

	var mercado_2 := TechData.new()
	mercado_2.id = "mercado_2"
	mercado_2.tier = 6
	mercado_2.display_name = "Mercado II"
	mercado_2.cost = 123.0
	mercado_2.prerequisites = ["mercado"]
	mercado_2.unlocks_building = "market_2"
	mercado_2.display_family = TechData.FAMILY_ECONOMIA
	mercado_2.effect_text = "Melhora o Mercado: mais ouro por turno para a cidade."
	mercado_2.description = "Cadernos de credito mais sofisticados e uma segunda praca de negocios — o Mercado original ganha companhia."
	techs[mercado_2.id] = mercado_2

	# --- NIVEL 7 — Guerra avancada (5 techs) --------------------------------

	var halberdier := TechData.new()
	halberdier.id = "halberdier"
	halberdier.tier = 7
	halberdier.display_name = "Halberdier"
	halberdier.cost = 192.0
	halberdier.prerequisites = ["lanceiro"]
	halberdier.unlocks_unit = "halberdier"
	halberdier.display_family = TechData.FAMILY_DEFESA
	halberdier.effect_text = "Libera o Halberdier: evolução do Lanceiro, anti-cavalaria pesado."
	halberdier.description = "Evolucao do Lanceiro — anti-cavalaria pesado, ainda mais dificil de derrubar em carga."
	techs[halberdier.id] = halberdier

	var cavaleiro_de_choque := TechData.new()
	cavaleiro_de_choque.id = "cavaleiro_de_choque"
	cavaleiro_de_choque.tier = 7
	cavaleiro_de_choque.display_name = "Cavaleiro de Choque"
	cavaleiro_de_choque.cost = 192.0
	cavaleiro_de_choque.prerequisites = ["estabulo_2"]
	cavaleiro_de_choque.unlocks_unit = "cavaleiro_de_choque"
	cavaleiro_de_choque.display_family = TechData.FAMILY_MILITAR
	cavaleiro_de_choque.effect_text = "Libera o Cavaleiro de Choque: grande dano no primeiro contato de uma carga."
	cavaleiro_de_choque.description = "Evolucao ofensiva da cavalaria — grande dano no primeiro contato de uma carga."
	techs[cavaleiro_de_choque.id] = cavaleiro_de_choque

	var ariete := TechData.new()
	ariete.id = "ariete"
	ariete.tier = 7
	ariete.display_name = "Aríete"
	ariete.cost = 192.0
	ariete.prerequisites = ["arsenal_de_cerco"]
	ariete.unlocks_unit = "ariete"
	ariete.display_family = TechData.FAMILY_MILITAR
	ariete.effect_text = "Libera o Aríete: excelente contra muralhas e estruturas."
	ariete.description = "Excelente contra muralhas e estruturas — feito pra derrubar portoes, nao pra lutar contra tropas."
	techs[ariete.id] = ariete

	var torre_de_cerco := TechData.new()
	torre_de_cerco.id = "torre_de_cerco"
	torre_de_cerco.tier = 7
	torre_de_cerco.display_name = "Torre de Cerco"
	torre_de_cerco.cost = 192.0
	torre_de_cerco.prerequisites = ["arsenal_de_cerco"]
	torre_de_cerco.unlocks_unit = "torre_de_cerco"
	torre_de_cerco.display_family = TechData.FAMILY_MILITAR
	torre_de_cerco.effect_text = "Libera a Torre de Cerco: permite assaltar cidades fortificadas por cima do muro."
	torre_de_cerco.description = "Permite assaltar cidades fortificadas por cima do muro, nao so por baixo dele."
	techs[torre_de_cerco.id] = torre_de_cerco

	var quartel_3 := TechData.new()
	quartel_3.id = "quartel_3"
	quartel_3.tier = 7
	quartel_3.display_name = "Quartel III"
	quartel_3.cost = 192.0
	quartel_3.prerequisites = ["quartel_2"]
	quartel_3.unlocks_building = "barracks_3"
	quartel_3.display_family = TechData.FAMILY_MILITAR
	quartel_3.effect_text = "Melhora o Quartel: abre a porta para o Halberdier e o Campeão."
	quartel_3.description = "Mais eficiencia de treinamento ainda — a porta de entrada pro Halberdier e pro Campeao de elite."
	techs[quartel_3.id] = quartel_3

	# Nova (roadmap "polimento definitivo V1"): Nivel 7 era 100% Militar
	# (regra dura do pedido). Predio novo de defesa (NAO self_placed — so
	# "walls" usa esse fluxo, ver BuildingDatabase.gd) — um degrau de
	# defesa intermediario antes de Fortaleza (Nivel 8).
	var muralhas_2 := TechData.new()
	muralhas_2.id = "muralhas_2"
	muralhas_2.tier = 7
	muralhas_2.display_name = "Muralhas II"
	muralhas_2.cost = 192.0
	muralhas_2.prerequisites = ["muralhas"]
	muralhas_2.unlocks_building = "walls_2"
	muralhas_2.display_family = TechData.FAMILY_DEFESA
	muralhas_2.effect_text = "Melhora as Muralhas: mais bônus de defesa para a cidade."
	muralhas_2.description = "As muralhas originais ganham reforcos, ameias e um segundo anel de pedra — um degrau defensivo antes da Fortaleza."
	techs[muralhas_2.id] = muralhas_2

	# --- NIVEL 8 — Reino poderoso (6 techs) ---------------------------------

	var fortaleza := TechData.new()
	fortaleza.id = "fortaleza"
	fortaleza.tier = 8
	fortaleza.display_name = "Fortaleza"
	fortaleza.cost = 302.0
	fortaleza.prerequisites = ["torre_de_vigia"]
	fortaleza.unlocks_building = "fortress"
	fortaleza.display_family = TechData.FAMILY_DEFESA
	fortaleza.effect_text = "Permite construir a Fortaleza: grande bônus de defesa, muito além das Muralhas."
	fortaleza.description = "Upgrade poderoso das defesas urbanas, muito alem do que as Muralhas sozinhas conseguem oferecer."
	techs[fortaleza.id] = fortaleza

	var grande_mercado := TechData.new()
	grande_mercado.id = "grande_mercado"
	grande_mercado.tier = 8
	grande_mercado.display_name = "Grande Mercado"
	grande_mercado.cost = 302.0
	grande_mercado.prerequisites = ["mercado"]
	grande_mercado.unlocks_building = "grand_market"
	grande_mercado.display_family = TechData.FAMILY_ECONOMIA
	grande_mercado.effect_text = "Permite construir o Grande Mercado: mais ouro por turno que o Mercado comum."
	grande_mercado.description = "Evolucao do Mercado — mais ouro, mais capacidade de comercio entre cidades."
	techs[grande_mercado.id] = grande_mercado

	var trebuchet := TechData.new()
	trebuchet.id = "trebuchet"
	trebuchet.tier = 8
	trebuchet.display_name = "Trebuchet"
	trebuchet.cost = 302.0
	trebuchet.prerequisites = ["arsenal_de_cerco"]
	trebuchet.unlocks_unit = "trebuchet"
	trebuchet.display_family = TechData.FAMILY_MILITAR
	trebuchet.effect_text = "Libera o Trebuchet: grande alcance e dano de cerco."
	trebuchet.description = "Grande alcance e dano de cerco — golpeia muito antes do inimigo conseguir revidar."
	techs[trebuchet.id] = trebuchet

	var campeao := TechData.new()
	campeao.id = "campeao"
	campeao.tier = 8
	campeao.display_name = "Campeão"
	campeao.cost = 302.0
	campeao.prerequisites = ["quartel_3"]
	campeao.unlocks_unit = "campeao"
	campeao.display_family = TechData.FAMILY_MILITAR
	campeao.effect_text = "Libera o Campeão: infantaria ofensiva de elite, cara e muito forte."
	campeao.description = "Infantaria ofensiva de elite — cara, mas capaz de virar sozinha o rumo de uma batalha."
	techs[campeao.id] = campeao

	var cavalaria_blindada := TechData.new()
	cavalaria_blindada.id = "cavalaria_blindada"
	cavalaria_blindada.tier = 8
	cavalaria_blindada.display_name = "Cavalaria Blindada"
	cavalaria_blindada.cost = 302.0
	cavalaria_blindada.prerequisites = ["estabulo_2"]
	cavalaria_blindada.unlocks_unit = "cavalaria_blindada"
	cavalaria_blindada.display_family = TechData.FAMILY_MILITAR
	cavalaria_blindada.effect_text = "Libera a Cavalaria Blindada: a unidade montada mais resistente do elenco comum."
	cavalaria_blindada.description = "A unidade montada mais resistente do elenco comum — poder de choque com armadura de verdade."
	techs[cavalaria_blindada.id] = cavalaria_blindada

	# Sem comportamento especial de jogo ainda (reparar/montar/desmontar
	# maquinas de cerco) — a pesquisa e a unidade existem primeiro, o
	# comportamento entra quando a infraestrutura estiver pronta (mesmo
	# principio ja usado pra unlocks_spell/terrain_transform de rituais
	# ainda sem efeito, ver MagicDatabase.gd).
	var engenheiro_de_cerco := TechData.new()
	engenheiro_de_cerco.id = "engenheiro_de_cerco"
	engenheiro_de_cerco.tier = 8
	engenheiro_de_cerco.display_name = "Engenheiro de Cerco"
	engenheiro_de_cerco.cost = 302.0
	engenheiro_de_cerco.prerequisites = ["arsenal_de_cerco"]
	engenheiro_de_cerco.unlocks_unit = "engenheiro_de_cerco"
	engenheiro_de_cerco.display_family = TechData.FAMILY_EXPLORACAO_UTILIDADE
	engenheiro_de_cerco.effect_text = "Libera o Engenheiro de Cerco: repara 25% da vida de máquinas adjacentes por turno."
	engenheiro_de_cerco.description = "Oficiais de manutenção acompanham o exército e recuperam suas máquinas."
	techs[engenheiro_de_cerco.id] = engenheiro_de_cerco

	# --- NIVEL 9 — Poder Imperial (5 techs) ---------------------------------

	var grande_arsenal := TechData.new()
	grande_arsenal.id = "grande_arsenal"
	grande_arsenal.tier = 9
	grande_arsenal.display_name = "Grande Arsenal"
	grande_arsenal.cost = 473.0
	grande_arsenal.prerequisites = ["arsenal_de_cerco"]
	grande_arsenal.unlocks_building = "grand_arsenal"
	grande_arsenal.display_family = TechData.FAMILY_EXPLORACAO_UTILIDADE
	grande_arsenal.effect_text = "Permite construir o Grande Arsenal: abre a porta para Bombarda e Colosso de Cerco."
	grande_arsenal.description = "Grande centro militar de cerco — a porta de entrada pra Bombarda e pro Colosso de Cerco."
	techs[grande_arsenal.id] = grande_arsenal

	# Reclassificada Militar -> Exploração/Utilidade (pedido do usuario,
	# revisao do plano): so desbloqueia um PREDIO, nenhuma unidade nova —
	# mesmo padrao estrutural de Grande Arsenal, que ja e Exploração/
	# Utilidade neste MESMO nivel pela mesma razao. Corrige o Nivel 9, que
	# estava concentrado demais (4 Militar/1 Utilidade).
	var quartel_de_elite := TechData.new()
	quartel_de_elite.id = "quartel_de_elite"
	quartel_de_elite.tier = 9
	quartel_de_elite.display_name = "Quartel de Elite"
	quartel_de_elite.cost = 473.0
	quartel_de_elite.prerequisites = ["quartel_3"]
	quartel_de_elite.unlocks_building = "barracks_elite"
	quartel_de_elite.display_family = TechData.FAMILY_EXPLORACAO_UTILIDADE
	quartel_de_elite.effect_text = "Versão final do Quartel: abre a porta para o General e o Exército Supremo."
	quartel_de_elite.description = "Versao final do Quartel — a porta de entrada pro General e pro Exercito Supremo."
	techs[quartel_de_elite.id] = quartel_de_elite

	# unlocks_unit = "general" — unidade de SUPORTE (attack 0.0, ver
	# UnitDatabase), pedido do usuario: "nao e pra causar dano diretamente...
	# ele fortalece tropas proximas". Aura ainda nao implementada, so a
	# unidade existe por enquanto.
	var general := TechData.new()
	general.id = "general"
	general.tier = 9
	general.display_name = "General"
	general.cost = 473.0
	general.prerequisites = ["quartel_de_elite"]
	general.unlocks_unit = "general"
	general.display_family = TechData.FAMILY_MILITAR
	general.effect_text = "Libera o General: aliados a até 2 hexágonos recebem +25% de ataque e defesa."
	general.description = "Coordena as tropas próximas com uma aura de comando; vários generais não acumulam o bônus."
	techs[general.id] = general

	var cavaleiro_imperial := TechData.new()
	cavaleiro_imperial.id = "cavaleiro_imperial"
	cavaleiro_imperial.tier = 9
	cavaleiro_imperial.display_name = "Cavaleiro Imperial"
	cavaleiro_imperial.cost = 473.0
	cavaleiro_imperial.prerequisites = ["estabulo_2"]
	cavaleiro_imperial.unlocks_unit = "cavaleiro_imperial"
	cavaleiro_imperial.display_family = TechData.FAMILY_MILITAR
	cavaleiro_imperial.effect_text = "Libera o Cavaleiro Imperial: extremamente forte, caro e raro."
	cavaleiro_imperial.description = "Extremamente forte, caro e raro — o auge da linhagem de cavalaria comum."
	techs[cavaleiro_imperial.id] = cavaleiro_imperial

	var bombarda := TechData.new()
	bombarda.id = "bombarda"
	bombarda.tier = 9
	bombarda.display_name = "Bombarda"
	bombarda.cost = 473.0
	bombarda.prerequisites = ["grande_arsenal"]
	bombarda.unlocks_unit = "bombarda"
	bombarda.display_family = TechData.FAMILY_MILITAR
	bombarda.effect_text = "Libera a Bombarda: arma de cerco pesada, grande dano contra cidades."
	bombarda.description = "Arma de cerco pesada — grande dano contra cidades, um passo abaixo do Colosso de Cerco."
	techs[bombarda.id] = bombarda

	# Nova (roadmap "polimento definitivo V1"): sem predio/unidade propria
	# (mesmo principio ja usado por General/Engenheiro de Cerco — a pesquisa
	# existe primeiro, a mecanica especifica de alcance de exploracao entra
	# depois). Contribui pra corrigir a concentracao do Nivel 9.
	var posto_avancado := TechData.new()
	posto_avancado.id = "posto_avancado"
	posto_avancado.tier = 9
	posto_avancado.display_name = "Posto Avançado"
	posto_avancado.cost = 473.0
	posto_avancado.display_family = TechData.FAMILY_EXPLORACAO_UTILIDADE
	posto_avancado.effect_text = "Postos de observação ampliam em 1 hexágono a visão de todas as unidades e cidades."
	posto_avancado.description = "Registros de rotas seguras e pontos de apoio distantes das cidades — a exploracao do reino comeca a se organizar de verdade."
	techs[posto_avancado.id] = posto_avancado

	# Nova: prédio de rendimento novo, mesmo padrao de Mercado/Grande
	# Mercado (bonus_gold puro) — evolucao final da cadeia comercial ANTES
	# do Grande Emporio (Nivel 10).
	var posto_comercial := TechData.new()
	posto_comercial.id = "posto_comercial"
	posto_comercial.tier = 9
	posto_comercial.display_name = "Rotas Comerciais"
	posto_comercial.cost = 473.0
	posto_comercial.prerequisites = ["grande_mercado"]
	posto_comercial.unlocks_building = "trading_post"
	posto_comercial.display_family = TechData.FAMILY_ECONOMIA
	posto_comercial.effect_text = "Permite construir o Posto Comercial: mais ouro por turno para a cidade."
	posto_comercial.description = "Rotas formalizadas entre o Grande Mercado e as cidades vizinhas — mais um degrau de ouro antes do Grande Emporio."
	techs[posto_comercial.id] = posto_comercial

	# --- NIVEL 10 — Apice da civilizacao (4 techs) --------------------------

	var fortaleza_imperial := TechData.new()
	fortaleza_imperial.id = "fortaleza_imperial"
	fortaleza_imperial.tier = 10
	fortaleza_imperial.display_name = "Fortaleza Imperial"
	fortaleza_imperial.cost = 741.0
	fortaleza_imperial.prerequisites = ["fortaleza"]
	fortaleza_imperial.unlocks_building = "imperial_fortress"
	fortaleza_imperial.display_family = TechData.FAMILY_DEFESA
	fortaleza_imperial.effect_text = "Permite construir a Fortaleza Imperial: a maior construção defensiva do jogo."
	fortaleza_imperial.description = "A maior construcao defensiva do jogo — o ápice de toda a cadeia de fortificacao."
	techs[fortaleza_imperial.id] = fortaleza_imperial

	var grande_emporio := TechData.new()
	grande_emporio.id = "grande_emporio"
	grande_emporio.tier = 10
	grande_emporio.display_name = "Grande Empório"
	grande_emporio.cost = 741.0
	grande_emporio.prerequisites = ["grande_mercado"]
	grande_emporio.unlocks_building = "grand_emporium"
	grande_emporio.display_family = TechData.FAMILY_ECONOMIA
	grande_emporio.effect_text = "Permite construir o Grande Empório: a estrutura econômica final do jogo."
	grande_emporio.description = "A estrutura economica final — o ápice de toda a cadeia de comercio."
	techs[grande_emporio.id] = grande_emporio

	# unlocks_unit = "campeao_do_reino" — "Exercito Supremo" e a tech que
	# desbloqueia a unidade terrestre FINAL do jogo (ver UnitDatabase
	# "campeao_do_reino"). Cada raca podera futuramente ter sua propria
	# variante visual (Cavaleiro Real/Campeao Elfico/Guardiao Ancestral/
	# Senhor da Guerra, mesma tech) — por enquanto todas usam a mesma
	# entrada, ver comentario em UnitDatabase.gd.
	var exercito_supremo := TechData.new()
	exercito_supremo.id = "exercito_supremo"
	exercito_supremo.tier = 10
	exercito_supremo.display_name = "Exército Supremo"
	exercito_supremo.cost = 741.0
	exercito_supremo.prerequisites = ["quartel_de_elite"]
	exercito_supremo.unlocks_unit = "campeao_do_reino"
	exercito_supremo.display_family = TechData.FAMILY_MILITAR
	exercito_supremo.effect_text = "Libera a unidade terrestre final da civilização — extremamente poderosa e cara."
	exercito_supremo.description = "Desbloqueia a unidade terrestre final da civilizacao — extremamente poderosa, extremamente cara."
	techs[exercito_supremo.id] = exercito_supremo

	var colosso_de_cerco := TechData.new()
	colosso_de_cerco.id = "colosso_de_cerco"
	colosso_de_cerco.tier = 10
	colosso_de_cerco.display_name = "Colosso de Cerco"
	colosso_de_cerco.cost = 741.0
	colosso_de_cerco.prerequisites = ["grande_arsenal"]
	colosso_de_cerco.unlocks_unit = "colosso_de_cerco"
	colosso_de_cerco.display_family = TechData.FAMILY_MILITAR
	colosso_de_cerco.effect_text = "Libera o Colosso de Cerco: a máquina de guerra final, muito poderosa e extremamente lenta."
	colosso_de_cerco.description = "A maquina de guerra final — muito poderosa contra cidades, extremamente lenta."
	techs[colosso_de_cerco.id] = colosso_de_cerco

	return techs

static func _all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build_all()
	return _cache

static func get_tech(id: String) -> TechData:
	return _all().get(id, null)

static func all_techs() -> Array:
	return _all().values()

## Quantas tecnologias de um NIVEL especifico ja foram pesquisadas — usado
## por available_techs() abaixo pra decidir se o nivel seguinte abriu.
static func _researched_count_in_tier(tier: int, researched: Dictionary) -> int:
	var count := 0
	for tech in all_techs():
		if tech.tier == tier and researched.has(tech.id):
			count += 1
	return count

## true se o NIVEL inteiro esta liberado pra pesquisa — Nivel 1 sempre;
## Nivel N>1 exige TIER_UNLOCK_THRESHOLD tecnologias JA pesquisadas do
## Nivel N-1 (nao importa quais, ver comentario de topo do arquivo).
static func is_tier_unlocked(tier: int, researched: Dictionary) -> bool:
	if tier <= 1:
		return true
	return _researched_count_in_tier(tier - 1, researched) >= TIER_UNLOCK_THRESHOLD

## Tecnologias ainda nao pesquisadas cujo NIVEL ja esta liberado (ver
## is_tier_unlocked acima) — e o que aparece pra escolher como proxima
## pesquisa. Substitui o antigo "todos os pre-requisitos concluidos"
## (TechData.prerequisites nao decide mais isto, ver comentario de topo).
static func available_techs(researched: Dictionary) -> Array:
	var result := []
	for tech in all_techs():
		if researched.has(tech.id):
			continue
		if is_tier_unlocked(tech.tier, researched):
			result.append(tech)
	return result

## Colonizador e Guarda eram os UNICOS kinds sempre liberados aqui antes
## deste redesenho — Guarda perdeu o fail-open (ver tech "guarda" acima,
## Nivel 1), so Colonizador continua hardcoded (nunca teve tech nenhuma
## associada, nem faria sentido ter). Resto do kind sem tecnologia
## associada fica liberado por padrao (fail-open — nao trava um tipo de
## unidade novo que ainda nao ganhou tech propria). Kinds cuja tech fica em
## MagicDatabase (ex: "mage") tambem caem no fail-open AQUI de proposito —
## quem combina as duas arvores e PlayerData.has_unlocked, nao esta funcao.
static func is_unit_unlocked(kind: String, researched: Dictionary) -> bool:
	if kind == "settler":
		return true
	for tech in all_techs():
		if tech.unlocks_unit == kind:
			return researched.has(tech.id)
	return true

## Tecnologia cujo unlocks_unit bate com `kind`, ou null se nenhuma
## tecnologia MUNDANA trava esse kind (so Colonizador — ver comentario de
## is_unit_unlocked; kinds magicos como "mage" ficam em MagicDatabase.
## tech_that_unlocks, nao aqui) — usado por City._tech_unlocked_for_
## building() pra saber se um predio de treino ja pode ser construido. kind
## == "" tem que devolver null explicitamente ANTES do loop: TechData.
## unlocks_unit tambem default pra "" nas tecnologias que nao desbloqueiam
## unidade nenhuma, entao sem essa guarda tech_that_unlocks("") "encontraria"
## a primeira tech sem unlocks_unit da lista por acidente.
static func tech_that_unlocks(kind: String) -> TechData:
	if kind == "":
		return null
	for tech in all_techs():
		if tech.unlocks_unit == kind:
			return tech
	return null

## Mesma ideia de tech_that_unlocks, so que pra um predio SEM trains_unit
## (ex: Muralhas, Celeiro, Quartel — ver TechData.unlocks_building) —
## City._tech_unlocked_for_building() consulta essa aqui quando
## tech_that_unlocks(building.trains_unit) nao acha nada.
static func tech_that_unlocks_building(building_id: String) -> TechData:
	if building_id == "":
		return null
	for tech in all_techs():
		if tech.unlocks_building == building_id:
			return tech
	return null

## Nenhuma tech de Tecnologia concede feitico — devolve sempre null aqui.
## Existe so pra manter a API simetrica com MagicDatabase (a fonte real,
## ver SpellManager.gd).
static func tech_that_unlocks_spell(spell_name: String) -> TechData:
	if spell_name == "":
		return null
	for tech in all_techs():
		if tech.unlocks_spell == spell_name:
			return tech
	return null

## Soma os bonus de TODAS as tecnologias MUNDANAS pesquisadas que afetam
## este bioma. Nenhuma tech de Tecnologia tem bonus_terrain_types hoje, mas
## City.gd soma isto junto com MagicDatabase.yield_bonus_for pra nao
## depender de qual arvore acaba ganhando um bonus de bioma no futuro.
static func yield_bonus_for(terrain_type: int, researched: Dictionary) -> Dictionary:
	var bonus = {"food": 0, "production": 0, "gold": 0, "mana": 0}
	for id in researched.keys():
		var tech: TechData = get_tech(id)
		if tech and terrain_type in tech.bonus_terrain_types:
			bonus.food += tech.bonus_food
			bonus.production += tech.bonus_production
			bonus.gold += tech.bonus_gold
			bonus.mana += tech.bonus_mana
	return bonus

## Nenhuma tech de Tecnologia concede feitico — devolve sempre vazio aqui.
## Existe so pra manter a API simetrica com MagicDatabase.
## unlocked_spells_for (a fonte real, ver SpellManager.gd).
static func unlocked_spells_for(researched: Dictionary) -> Array[String]:
	var spells: Array[String] = []
	for tech in all_techs():
		if tech.unlocks_spell != "" and researched.has(tech.id):
			spells.append(tech.unlocks_spell)
	return spells

## Roadmap 2.0 Parte 1 (C1) — unica checagem que o modo "Embarcar" precisa
## (ver SelectionManager.toggle_embark_selected).
const NAVEGACAO_TECH_ID := "navegacao"
static func is_navigation_researched(researched: Dictionary) -> bool:
	return researched.has(NAVEGACAO_TECH_ID)

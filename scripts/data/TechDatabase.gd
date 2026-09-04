class_name TechDatabase
extends RefCounted

## Arvore de tecnologia MAGICA (pivot pedido pelo usuario: "deixe de ser uma
## arvore Generica/Historica... e se torne um sistema focado em MAGIA,
## FANTASIA E MANIPULACAO DO MUNDO" — substitui a arvore anterior de
## Agricultura/Mineracao/Irrigacao inteira), com um pequeno ramo MUNDANO
## (escola "Doutrina", sem magia) enxertado nela. 20 tecnologias em 4 tiers.
##
## 21a tecnologia (Roadmap 2.0 Parte 1, C1): "Navegação", standalone (nem
## militar nem economica, mesmo padrao de Muralhas abaixo) — libera o modo
## "Embarcar" (ver Unit.embarked), unica forma de alcancar os continentes
## Vulcanico/de Cristal.
##
## Doutrina em si tem DUAS familias/cadeias INDEPENDENTES por proposito —
## pedido do usuario ao reorganizar a arvore: "ajuste as familias na
## arvore[,] a maioria da dispers[ã]o precisa[m] ter uma logica de
## familia, o que é construido apos o outro... não faz sentido a parte de
## unidades militares resultar em poder fazer o mercado, mas faz sentido
## uma parte de construções e assim vai": a MILITAR (Quartel -> Estabulo/
## Arquearia -> Batedor Montado) e a ECONOMICA (Celeiro -> Oficina ->
## Mercado), mais Muralhas sozinha (nem uma coisa nem outra, ver comentario
## dela mais abaixo) — nenhuma aresta liga as duas cadeias nem Muralhas a
## elas (ver TechTree._compute_components, que ja separa por componente
## conexo automaticamente).
##
## TIER 0 (bases elementares, sem pre-requisito): Canalizacao da Trama
## (arcanismo puro, raiz de Invocacao de Espiritos), Alquimia Botanica
## (vegetacao encantada), Transmutacao de Rochas (forja elemental) — as
## duas ultimas sao a raiz das duas "escolas" de bioma (floresta/gelo vs.
## colina/deserto) que se ramificam no Tier 1 —, Quartel (raiz da cadeia
## militar inteira, ver Tier 1/2), Celeiro (raiz da cadeia economica, ver
## Tier 1/2) e Muralhas (isolada, ver comentario dela).
## TIER 1 (especializacoes): Invocacao de Espiritos (Mago Arcano), Pacto
## Florestal (Ent), Forja Runica (Golem de Pedra), Geomancia (bonus de
## deserto/savana), Estábulo (raiz do Cavaleiro comum e do Cavaleiro Real,
## prerequisito "quartel"), Arquearia (raiz do Arqueiro, prerequisito
## "quartel" TAMBEM — irmã de Estábulo, nao filha dela) e Oficina (segundo
## elo da cadeia economica, prerequisito "celeiro" — uma vila so
## especializa mao de obra em ofício depois que a fome deixa de ser
## problema diario). Diagrama exato pedido pelo usuario pro ramo militar,
## apos eu ter errado a primeira versao (Estábulo/Arquearia tinham ido pra
## Tier 0 sem pre-requisito nenhum): "quartel -> estabulo -> batedor
## montado, \/ arquearia... o quartel libera a pesquisa de estabulo e
## arquearia, mas pesquisando o estabulo voce libera a pesquisa de
## batedor".
## TIER 2 (avancadas): Lordes dos Ventos (Grifo), Necromancia Pratica
## (Convocador de Sombras), Constructos de Guerra (Catapulta Cadenciada),
## Batedor Montado (Batedor, prerequisito "estabulo" — dois saltos de
## Quartel, mesma profundidade das outras techs de Tier 2 acima) e Mercado
## (terceiro/ultimo elo da cadeia economica, prerequisito "oficina" — o
## excedente da oficina especializada finalmente tem pra onde escoar,
## liberando tambem o rush-buy de producao com ouro, ver City.rush_buy()).
## TIER 3 (rituais supremos): Cataclismo Elemental e Transcendencia
## Florestal — puramente rituais/feiticos por enquanto (ver TechData.
## unlocks_spell/terrain_transform), sem unidade nem bonus de bioma novo.
##
## Limitacao conhecida (documentada de proposito em vez de fingir que
## funciona): "Canalizacao da Trama" e descrita no pedido original como
## "+1 Comida/Producao na CAPITAL", mas o mecanismo de bonus existente
## (bonus_terrain_types, ver yield_bonus_for) so sabe mirar um BIOMA, nao
## um tile especifico — implementar bonus exclusivo da capital exigiria
## logica nova em City.gd, fora do escopo desta rodada (so TechData/
## TechDatabase/TechTree). Por ora essa tech fica sem bonus_food/
## bonus_production numerico — o valor dela hoje e ser a raiz de
## Invocacao de Espiritos. unlocks_spell e terrain_transform (Tier 3) sao
## registros de DADOS pro mesmo motivo: nenhuma logica de HexGrid/City
## consome isso ainda, fica pronto pra um passe futuro ligar de verdade.
##
## Pesquisa e paga com "ciencia" = soma da populacao das cidades por turno
## (ver GameManager._process_research) — simples de proposito, sem
## introduzir mais um tipo de yield em HexTileData. Isso nao mudou.

static var _cache: Dictionary = {} # id -> TechData, montada uma vez por sessao

static func _build_all() -> Dictionary:
	var techs: Dictionary = {}

	var canalizacao_base := TechData.new()
	canalizacao_base.id = "canalizacao_base"
	canalizacao_base.display_name = "Canalização da Trama"
	canalizacao_base.cost = 25.0
	canalizacao_base.school = "Arcanismo"
	canalizacao_base.description = "Os primeiros sábios aprendem a sentir os fios invisíveis que tecem o mundo — a Trama — e a puxá-los sem se queimar. Ergue a Torre dos Sábios, primeiro posto de estudo arcano da civilização."
	techs[canalizacao_base.id] = canalizacao_base

	var alquimia_botanica := TechData.new()
	alquimia_botanica.id = "alquimia_botanica"
	alquimia_botanica.display_name = "Alquimia Botânica"
	alquimia_botanica.cost = 20.0
	alquimia_botanica.bonus_terrain_types = [HexTileData.TerrainType.FOREST, HexTileData.TerrainType.JUNGLE, HexTileData.TerrainType.TUNDRA]
	alquimia_botanica.bonus_food = 1
	alquimia_botanica.school = "Alquimia"
	alquimia_botanica.description = "Poções e enzimas alquímicas aceleram a seiva das plantas e prolongam o verão nas folhas — florestas, selvas e até a tundra gelada aprendem a florescer fora de época."
	techs[alquimia_botanica.id] = alquimia_botanica

	var transmutacao_rocha := TechData.new()
	transmutacao_rocha.id = "transmutacao_rocha"
	transmutacao_rocha.display_name = "Transmutação de Rochas"
	transmutacao_rocha.cost = 25.0
	transmutacao_rocha.bonus_terrain_types = [HexTileData.TerrainType.HILLS, HexTileData.TerrainType.MOUNTAINS]
	transmutacao_rocha.bonus_production = 1
	transmutacao_rocha.school = "Transmutação"
	transmutacao_rocha.description = "A pedra bruta é convencida, átomo a átomo, a ceder seus veios de minério — colinas e montanhas rendem mais sob o cinzel de um transmutador treinado."
	techs[transmutacao_rocha.id] = transmutacao_rocha

	# Duas techs MUNDANAS da arvore, de proposito (pedido do usuario:
	# "quartel tem que ter uma pesquisa... quando pesquisar o quartel,
	# pode construir o quartel", estendido depois pro Estabulo: "voce
	# precisa pesquisar[,] o estabulo [pra poder] construir"). Mesmo
	# mecanismo pras duas: unlocks_unit == building.trains_unit e o que
	# faz TechDatabase.tech_that_unlocks(kind) deixar de devolver null —
	# City._tech_unlocked_for_building() passa a exigir a tech pesquisada
	# antes do predio poder ser construido. Sem escola magica de verdade
	# (school "Doutrina", cor propria em TechTree.SCHOOL_COLORS) e custo
	# baixo — e treino e disciplina, nao arcanismo.
	#
	# unlocks_unit = "men_at_arms" (NAO "warrior") — pedido do usuario numa
	# rodada seguinte: "o guarda comum nao precisa de quartel pra ser
	# feito". BuildingDatabase.barracks.trains_unit tambem mudou pra
	# "men_at_arms" junto, os dois precisam bater (ver comentario de
	# _tech_unlocked_for_building em City.gd).
	# Tier 0, SEM prerequisito — irma solta de Quartel, mesma familia
	# Raiz da "cadeia economica" da Doutrina (Tier 0, SEM prerequisito) —
	# pedido do usuario: "ajuste as familias na arvore[,] a maioria da
	# dispers[ã]o precisa[m] ter uma logica de familia, o que é construido
	# apos o outro... não faz sentido a parte de unidades militares
	# resultar em poder fazer o mercado, mas faz sentido uma parte de
	# construções". Celeiro/Oficina/Mercado formam essa cadeia (Celeiro ->
	# Oficina -> Mercado, ver prerequisites de cada uma abaixo) SEPARADA da
	# cadeia militar (Quartel -> Estabulo/Arquearia -> Batedor Montado) —
	# as duas ficam em componentes DIFERENTES da arvore (nenhuma aresta
	# ligando uma a outra, ver TechTree._compute_components), exatamente
	# como o usuario pediu. Trava a CONSTRUCAO do Celeiro via unlocks_
	# building (mesmo mecanismo de Muralhas, ver TechDatabase.tech_that_
	# unlocks_building/City._tech_unlocked_for_building), nao unlocks_unit
	# (Celeiro nao treina tropa nenhuma).
	var celeiro_tech := TechData.new()
	celeiro_tech.id = "celeiro"
	celeiro_tech.display_name = "Celeiro"
	celeiro_tech.cost = 15.0
	celeiro_tech.unlocks_building = "granary"
	celeiro_tech.school = "Doutrina"
	celeiro_tech.description = "Um grão guardado é meio grão poupado: mestres-celeireiros aprendem a selar silos contra umidade, ratos e o inverno mais longo — o alicerce que permite a uma vila armazenar excedente de verdade em vez de vê-lo apodrecer nos campos."
	techs[celeiro_tech.id] = celeiro_tech

	# Tier 1 da cadeia economica, prerequisito ["celeiro"] — logica de
	# familia pedida pelo usuario: uma vila so consegue liberar mao de obra
	# pra especializar em ofícios depois que a fome deixa de ser um
	# problema diario (Celeiro construido). Trava a CONSTRUCAO da Oficina
	# via unlocks_building (mesmo mecanismo de Muralhas/Celeiro), nao
	# unlocks_unit (Oficina nao treina tropa nenhuma). Mecanica em si
	# (bonus_production da Oficina, ver BuildingDatabase.gd) continua a
	# mesma por enquanto — o usuario pediu pra manter simples nessa rodada
	# ("vamos fazer assim, depois deixamos mais complexo").
	var oficina_tech := TechData.new()
	oficina_tech.id = "oficina"
	oficina_tech.display_name = "Oficina"
	oficina_tech.cost = 20.0
	oficina_tech.prerequisites = ["celeiro"]
	oficina_tech.unlocks_building = "workshop"
	oficina_tech.school = "Doutrina"
	oficina_tech.description = "Com os celeiros cheios e a fome afastada, sobra tempo pra especializar: um mestre-artesão organiza bancadas, foles e ferramentas num único telhado — o mesmo ofício que antes se espalhava pelos quintais da vila agora rende mais, com menos desperdício de material e esforço."
	techs[oficina_tech.id] = oficina_tech

	# Tier 2 da cadeia economica, prerequisito ["oficina"] — fecha a familia
	# Celeiro -> Oficina -> Mercado (comida segura -> ofício especializado
	# -> excedente pra trocar). Libera CONSTRUIR o Mercado (unlocks_
	# building, mesmo mecanismo das outras), que por sua vez libera
	# COMPRAR o resto da producao do item atual com ouro (rush-buy, ver
	# City.can_rush_buy()/rush_buy_cost()/rush_buy()) — pedido do usuario:
	# "o mercado pode servir pra [dar um uso real pro ouro]"/"é uma boa,
	# faça isso".
	var mercado_tech := TechData.new()
	mercado_tech.id = "mercado"
	mercado_tech.display_name = "Mercado"
	mercado_tech.cost = 25.0
	mercado_tech.prerequisites = ["oficina"]
	mercado_tech.unlocks_building = "market"
	mercado_tech.school = "Doutrina"
	mercado_tech.description = "Com as oficinas produzindo mais do que a vila consome sozinha, um conselho de mercadores padroniza pesos, câmbio e cadernos de crédito — o excedente das bancadas finalmente encontra pra onde escoar, e ouro sonante passa a apressar obras, não só pagar por elas depois de prontas."
	techs[mercado_tech.id] = mercado_tech

	var quartel := TechData.new()
	quartel.id = "quartel"
	quartel.display_name = "Quartel"
	quartel.cost = 15.0
	quartel.unlocks_unit = "men_at_arms"
	quartel.school = "Doutrina"
	quartel.description = "Nem todo poder vem da Trama: um conselho de veteranos formaliza turnos de guarda, manobras e a forja de armaduras em uma doutrina permanente — o alicerce de um exército de verdade, sem feitiço nenhum envolvido."
	techs[quartel.id] = quartel

	# unlocks_unit = "cavalry" (nao "human_knight") de proposito: o Estabulo
	# treina AS DUAS (Cavaleiro comum via trains_unit, Cavaleiro Real via
	# fallback especial em BuildingDatabase.building_that_trains — ver
	# comentario la) — travar a CONSTRUCAO do predio automaticamente atrasa
	# as duas tropas juntas, sem precisar duplicar o gate. prerequisites =
	# ["quartel"] — pedido explicito do usuario com diagrama da arvore:
	# "quartel -> estabulo -> batedor montado, \/ arquearia... o quartel
	# libera a pesquisa de estabulo e arquearia". Isso e um gate SEPARADO
	# do requires_building (BuildingData.requires_building == "barracks",
	# pedido anterior: "faca o estabulo ser uma coisa que so pode ser feita
	# depois do quartel") — um trava a PESQUISA (nao da nem pra escolher
	# Estabulo antes de pesquisar Quartel), o outro trava a CONSTRUCAO
	# fisica do predio mesmo com a tech ja pronta; os dois combinados.
	var estabulo := TechData.new()
	estabulo.id = "estabulo"
	estabulo.display_name = "Estábulo"
	estabulo.cost = 15.0
	estabulo.prerequisites = ["quartel"]
	estabulo.unlocks_unit = "cavalry"
	estabulo.school = "Doutrina"
	estabulo.description = "Um mestre-cavalariço codifica as técnicas de doma, ferração e equipagem de guerra — o alicerce necessário antes de qualquer estábulo abrigar cavalos de batalha de verdade."
	techs[estabulo.id] = estabulo

	# Prerequisito ["estabulo"], NAO Tier 0 — pedido do usuario: "uma
	# pesquisa seguinte ao estabulo... o batedor montado, que libera a
	# construcao do batedor". "Construcao" aqui e treinar a tropa, nao um
	# predio novo: Batedor cai no MESMO Estabulo que ja treina Cavaleiro/
	# Cavaleiro Real (fallback especial em BuildingDatabase.
	# building_that_trains, mesmo principio do Cavaleiro Real) — faz
	# sentido tematico (um batedor MONTADO tambem sai do estabulo) e evita
	# inventar um predio novo so pra uma tropa de baixo dano. unlocks_unit
	# = "scout" (nao "cavalry" de novo) e o que da a Batedor seu PROPRIO
	# gate de desbloqueio, alem do gate de predio que "estabulo" ja cobre —
	# assim o jogador precisa pesquisar as DUAS (Estabulo primeiro, depois
	# Batedor Montado) antes de treinar Batedor, mesmo com o Estabulo ja
	# construido.
	var batedor_montado := TechData.new()
	batedor_montado.id = "batedor_montado"
	batedor_montado.display_name = "Batedor Montado"
	batedor_montado.cost = 25.0
	batedor_montado.prerequisites = ["estabulo"]
	batedor_montado.unlocks_unit = "scout"
	batedor_montado.school = "Doutrina"
	batedor_montado.description = "Um cavaleiro leve, sem armadura pesada nem lança de choque, aprende a cavalgar longe e rápido — sua função não é vencer batalhas, é ver o que está além da próxima colina antes de qualquer outra pessoa."
	techs[batedor_montado.id] = batedor_montado

	# prerequisites = ["quartel"] — CORRECAO do usuario sobre a primeira
	# versao desta tech (que tinha ido pra Tier 0 sem pre-requisito
	# nenhum): "nao e correlacionada com nenhuma outra" se referia a nao
	# se correlacionar com o ramo Estabulo/Batedor Montado (arquearia e um
	# ramo PROPRIO, separado), NAO "sem pre-requisito nenhum" — o diagrama
	# do usuario deixa claro que Quartel e raiz das DUAS ramificacoes:
	# "quartel -> estabulo -> batedor montado, \/ arquearia... o quartel
	# libera a pesquisa de estabulo e arquearia". Mesmo mecanismo de
	# Quartel/Estabulo: unlocks_unit = "archer" trava a CONSTRUCAO do Campo
	# de Tiro (tech_that_unlocks deixa de devolver null pro Campo de Tiro),
	# o que atrasa treinar Arqueiro ate pesquisar isso — Arqueiro deixa de
	# ser tropa mundana "sempre liberada" (ver comentario de
	# is_unit_unlocked).
	var arquearia := TechData.new()
	arquearia.id = "arquearia"
	arquearia.display_name = "Arquearia"
	arquearia.cost = 15.0
	arquearia.prerequisites = ["quartel"]
	arquearia.unlocks_unit = "archer"
	arquearia.school = "Doutrina"
	arquearia.description = "Puxar a corda, mirar e soltar parece simples até a centésima flecha perdida — um mestre-arqueiro formaliza a postura, a respiração e a manutenção do próprio arco em algo que se ensina de verdade, não só se aprende sozinho."
	techs[arquearia.id] = arquearia

	# Tier 0, SEM prerequisito — irma solta de Quartel, nao filha dele
	# (fortificar uma cidade nao depende de disciplina militar nenhuma, so
	# de mao de obra e pedra), e TAMBEM fora da cadeia economica Celeiro->
	# Oficina->Mercado por proposito (mesmo motivo: mao de obra e pedra, nao
	# comida armazenada nem ofício especializado) — pedido do usuario ao
	# reorganizar a arvore em familias: "não precisa interligar tudo se não
	# fizer sentido". Fica como seu proprio componente isolado (ver
	# TechTree._compute_components), nem militar nem economico. Pedido do
	# usuario: "eu acho que a muralha
	# [predio] nao faz tanto sentido, vamos remover ela, e adicionar como
	# pesquisa... essa pesquisa libera a construção da muralha, mas essa
	# muralha no caso simplesmente adiciona esteticamente uma muralha ao
	# redor do tile da cidade... dando um shield a ela". Reaproveita o anel
	# de muralha que City._add_walls ja desenhava (antes so por populacao,
	# sem bonus nenhum) em vez de duplicar visual: unlocks_building = "walls"
	# trava a CONSTRUCAO do predio (ver TechDatabase.tech_that_unlocks_
	# building/City._tech_unlocked_for_building), e BuildingData.walls.
	# self_placed = true faz esse predio, uma vez construido, acender o
	# anel de muralha da PROPRIA cidade (ver City._build_visual_procedural)
	# em vez de virar um modelo separado num tile vizinho escolhido — nao
	# faz sentido "escolher onde" cercar uma cidade que so tem um tile.
	var muralhas := TechData.new()
	muralhas.id = "muralhas"
	muralhas.display_name = "Muralhas"
	muralhas.cost = 15.0
	muralhas.unlocks_building = "walls"
	muralhas.school = "Doutrina"
	muralhas.description = "Um mestre-pedreiro aprende a erguer um anel de pedra alto o bastante pra deter um aríete e reto o bastante pra não desabar sob o próprio peso — o alicerce de qualquer cidade que pretenda sobreviver a um cerco de verdade."
	techs[muralhas.id] = muralhas

	# Roadmap 2.0 Parte 1 (C1) — standalone, sem pre-requisito, mesmo padrao
	# de Muralhas acima (nem militar nem economica, componente conexo
	# proprio). Libera o modo "Embarcar" (ver Unit.embarked/SelectionManager.
	# toggle_embark_selected) — unica forma de uma unidade terrestre
	# atravessar agua e alcancar os continentes Vulcanico/de Cristal.
	var navegacao := TechData.new()
	navegacao.id = "navegacao"
	navegacao.display_name = "Navegação"
	navegacao.cost = 20.0
	navegacao.school = "Doutrina"
	navegacao.description = "Cascos calafetados e a leitura das correntes permitem que um exército inteiro se arrisque mar adentro — não como marujos de guerra, só gente disposta a confiar a própria vida a uma prancha de madeira até avistar terra de novo."
	techs[navegacao.id] = navegacao

	var invocacao_espiritos := TechData.new()
	invocacao_espiritos.id = "invocacao_espiritos"
	invocacao_espiritos.display_name = "Invocação de Espíritos"
	invocacao_espiritos.cost = 40.0
	invocacao_espiritos.prerequisites = ["canalizacao_base"]
	invocacao_espiritos.unlocks_unit = "mage"
	invocacao_espiritos.unlocks_spell = "Lança de Arcana"
	invocacao_espiritos.school = "Arcanismo"
	invocacao_espiritos.description = "Rasgar um véu fino entre planos e vincular um espírito à vontade do invocador — a base de todo combate arcano, e o primeiro passo rumo aos rituais mais sombrios."
	techs[invocacao_espiritos.id] = invocacao_espiritos

	var pacto_florestal := TechData.new()
	pacto_florestal.id = "pacto_florestal"
	pacto_florestal.display_name = "Pacto Florestal"
	pacto_florestal.cost = 35.0
	pacto_florestal.prerequisites = ["alquimia_botanica"]
	pacto_florestal.unlocks_unit = "treant"
	pacto_florestal.bonus_terrain_types = [HexTileData.TerrainType.FOREST]
	pacto_florestal.bonus_food = 1
	pacto_florestal.bonus_production = 1
	pacto_florestal.school = "Naturalismo"
	pacto_florestal.description = "Um juramento antigo entre os druidas e o coração da floresta desperta os Ents guardiões — e faz cada árvore do território render mais madeira e fruto."
	techs[pacto_florestal.id] = pacto_florestal

	var forja_runica := TechData.new()
	forja_runica.id = "forja_runica"
	forja_runica.display_name = "Forja Rúnica"
	forja_runica.cost = 40.0
	forja_runica.prerequisites = ["transmutacao_rocha"]
	forja_runica.unlocks_unit = "stone_golem"
	forja_runica.bonus_terrain_types = [HexTileData.TerrainType.HILLS]
	forja_runica.bonus_production = 1
	forja_runica.school = "Transmutação"
	forja_runica.description = "Runas de poder gravadas a fogo na bigorna dão vida à pedra e ao metal — o nascimento do Golem de Pedra, guardião incansável que nunca sente o próprio peso."
	techs[forja_runica.id] = forja_runica

	var geomancia := TechData.new()
	geomancia.id = "geomancia"
	geomancia.display_name = "Geomancia"
	geomancia.cost = 35.0
	geomancia.prerequisites = ["transmutacao_rocha"]
	geomancia.bonus_terrain_types = [HexTileData.TerrainType.DESERT, HexTileData.TerrainType.SAVANNA]
	geomancia.bonus_food = 1
	geomancia.school = "Geomancia"
	geomancia.description = "Ouvir o pulso lento da terra e persuadi-la a liberar água presa nas profundezas — o solo árido do deserto e da savana aprende a nutrir novamente."
	techs[geomancia.id] = geomancia

	var lordes_dos_ventos := TechData.new()
	lordes_dos_ventos.id = "lordes_dos_ventos"
	lordes_dos_ventos.display_name = "Lordes dos Ventos"
	lordes_dos_ventos.cost = 55.0
	lordes_dos_ventos.prerequisites = ["invocacao_espiritos"]
	lordes_dos_ventos.unlocks_unit = "griffin"
	lordes_dos_ventos.school = "Elementalismo"
	lordes_dos_ventos.description = "Um pacto sussurrado ao vento convoca os grandes grifos das alturas, que aceitam carregar um cavaleiro digno em troca de um ninho seguro no topo da torre mais alta."
	techs[lordes_dos_ventos.id] = lordes_dos_ventos

	var necromancia_pratica := TechData.new()
	necromancia_pratica.id = "necromancia_pratica"
	necromancia_pratica.display_name = "Necromancia Prática"
	necromancia_pratica.cost = 55.0
	necromancia_pratica.prerequisites = ["invocacao_espiritos"]
	necromancia_pratica.unlocks_unit = "shadow_summoner"
	necromancia_pratica.unlocks_spell = "Reanimar"
	necromancia_pratica.school = "Necromancia"
	necromancia_pratica.description = "A fronteira entre a vida e a sombra se mostra mais fina do que qualquer sábio ortodoxo admitiria — o Convocador de Sombras aprende a puxar ecos do outro lado para lutar por ele."
	techs[necromancia_pratica.id] = necromancia_pratica

	var constructos_de_guerra := TechData.new()
	constructos_de_guerra.id = "constructos_de_guerra"
	constructos_de_guerra.display_name = "Constructos de Guerra"
	constructos_de_guerra.cost = 55.0
	constructos_de_guerra.prerequisites = ["forja_runica"]
	constructos_de_guerra.unlocks_unit = "catapult"
	constructos_de_guerra.school = "Transmutação"
	constructos_de_guerra.description = "A mesma runa que dá vida ao Golem de Pedra, gravada num braço de arremesso em vez de um corpo, nasce a Catapulta Cadenciada — cada disparo cronometrado por um pulso arcano constante."
	techs[constructos_de_guerra.id] = constructos_de_guerra

	var cataclismo_elemental := TechData.new()
	cataclismo_elemental.id = "cataclismo_elemental"
	cataclismo_elemental.display_name = "Cataclismo Elemental"
	cataclismo_elemental.cost = 75.0
	cataclismo_elemental.prerequisites = ["constructos_de_guerra"]
	cataclismo_elemental.unlocks_spell = "Ruína Ígnea"
	cataclismo_elemental.school = "Elementalismo"
	cataclismo_elemental.description = "O ritual supremo da escola elemental: convocar fogo, pedra e tempestade ao mesmo tempo sobre um único ponto do mapa, o bastante para reduzir uma fortificação inteira a cinzas."
	techs[cataclismo_elemental.id] = cataclismo_elemental

	var transcendencia_florestal := TechData.new()
	transcendencia_florestal.id = "transcendencia_florestal"
	transcendencia_florestal.display_name = "Transcendência Florestal"
	transcendencia_florestal.cost = 70.0
	transcendencia_florestal.prerequisites = ["pacto_florestal"]
	transcendencia_florestal.unlocks_spell = "Metamorfose de Gaia"
	transcendencia_florestal.terrain_transform = {
		"from": [HexTileData.TerrainType.TUNDRA, HexTileData.TerrainType.DESERT],
		"to": HexTileData.TerrainType.GRASSLAND,
	}
	transcendencia_florestal.school = "Naturalismo"
	transcendencia_florestal.description = "O ápice do Pacto Florestal: em vez de apenas pedir à terra que floresça, o ritual reescreve o próprio bioma — tundra e deserto cedem lugar a pradarias férteis sob o toque dos druidas mais experientes."
	techs[transcendencia_florestal.id] = transcendencia_florestal

	return techs

static func _all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build_all()
	return _cache

static func get_tech(id: String) -> TechData:
	return _all().get(id, null)

static func all_techs() -> Array:
	return _all().values()

## Tecnologias ainda nao pesquisadas cujos pre-requisitos ja foram TODOS
## cumpridos — e o que aparece pra escolher como proxima pesquisa.
static func available_techs(researched: Dictionary) -> Array:
	var result := []
	for tech in all_techs():
		if researched.has(tech.id):
			continue
		var ok := true
		for prereq in tech.prerequisites:
			if not researched.has(prereq):
				ok = false
				break
		if ok:
			result.append(tech)
	return result

## Colonizador e Guarda sao os UNICOS kinds sempre liberados aqui — Guarda
## via fail-open natural (nenhuma tech mira "warrior", ver comentario de
## _build_all), Colonizador via hardcode explicito (nunca teve tech
## nenhuma associada, nem faria sentido ter). Cavaleiro (comum), Arqueiro e
## Batedor TODOS passam pelo loop normal agora: "Estabulo" tem unlocks_unit
## == "cavalry", "Arquearia" == "archer", "Batedor Montado" == "scout" —
## os tres ficam de verdade bloqueados ATE pesquisar (pedido do usuario:
## "introduza a pesquisa em arqueria... nela voce libera a construcao que
## atualmente temos pra treinar arqueiros"). Resto do kind sem tecnologia
## associada fica liberado por padrao (fail-open — nao trava um tipo de
## unidade novo que ainda nao ganhou tech propria).
## Roadmap 2.0 Parte 1 (C1) — unica checagem que o modo "Embarcar" precisa
## (ver SelectionManager.toggle_embark_selected).
const NAVEGACAO_TECH_ID := "navegacao"
static func is_navigation_researched(researched: Dictionary) -> bool:
	return researched.has(NAVEGACAO_TECH_ID)

static func is_unit_unlocked(kind: String, researched: Dictionary) -> bool:
	if kind == "settler":
		return true
	for tech in all_techs():
		if tech.unlocks_unit == kind:
			return researched.has(tech.id)
	return true

## Tecnologia cujo unlocks_unit bate com `kind`, ou null se nenhuma
## tecnologia trava esse kind (so Colonizador e Guarda — ver comentario de
## is_unit_unlocked; "men_at_arms"/"cavalry"/"archer"/"scout" SIM caem
## aqui, ver techs "Quartel"/"Estabulo"/"Arquearia"/"Batedor Montado" em
## _build_all) — usado por
## City._tech_unlocked_for_building() pra saber se um predio de treino ja
## pode ser construido (e por tabela, HUD._building_lock_reason mostra
## qual pesquisa falta no tooltip de CONSTRUCAO — nao mais no de treino de
## tropa, que agora so aparece ja liberado). kind == "" tem que devolver null
## explicitamente ANTES do loop: `TechData.unlocks_unit` tambem default
## pra "" nas tecnologias que nao desbloqueiam unidade nenhuma
## (Alquimia Botanica, Geomancia...), entao sem essa guarda
## `tech_that_unlocks("")` "encontraria" a primeira tech de bioma da
## lista por acidente (ex: exigiria Alquimia Botanica pra construir o
## Celeiro, que nao trava tropa nenhuma — BuildingData.trains_unit == "").
static func tech_that_unlocks(kind: String) -> TechData:
	if kind == "":
		return null
	for tech in all_techs():
		if tech.unlocks_unit == kind:
			return tech
	return null

## Mesma ideia de tech_that_unlocks, so que pra um predio SEM trains_unit
## (ex: Muralhas, ver TechData.unlocks_building) — City._tech_unlocked_for_
## building() consulta essa aqui quando tech_that_unlocks(building.
## trains_unit) nao acha nada (trains_unit == "" pra esses predios).
static func tech_that_unlocks_building(building_id: String) -> TechData:
	if building_id == "":
		return null
	for tech in all_techs():
		if tech.unlocks_building == building_id:
			return tech
	return null

## Mesma ideia de tech_that_unlocks/tech_that_unlocks_building, pro NOME
## de feitico (TechData.unlocks_spell) — usado por SpellManager pra achar
## de volta o TechData.terrain_transform de uma tech so tendo o nome do
## feitico em maos (ver _apply_terrain_transform, roadmap Fase 5).
static func tech_that_unlocks_spell(spell_name: String) -> TechData:
	if spell_name == "":
		return null
	for tech in all_techs():
		if tech.unlocks_spell == spell_name:
			return tech
	return null

## Soma os bonus de TODAS as tecnologias pesquisadas que afetam este bioma
## — varias tecnologias podem mirar o mesmo terreno.
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

## Nomes de todos os feiticos/rituais (TechData.unlocks_spell) concedidos
## pelas tecnologias ja pesquisadas — usado pra um futuro painel "meus
## feiticos" ou tooltip, sem precisar varrer a arvore inteira toda vez.
## Ignora tecnologias sem feitico (unlocks_spell == "").
static func unlocked_spells_for(researched: Dictionary) -> Array[String]:
	var spells: Array[String] = []
	for tech in all_techs():
		if tech.unlocks_spell != "" and researched.has(tech.id):
			spells.append(tech.unlocks_spell)
	return spells

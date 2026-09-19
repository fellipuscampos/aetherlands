class_name TechData
extends Resource

## Um no da arvore de tecnologia. Recurso puro de dados (igual UnitData/
## CivilizationData) — quem interpreta isto e TechDatabase (consultas) e
## City.collect_yields/GameManager (aplicacao dos efeitos).
##
## Pivot pedido pelo usuario: a arvore deixou de ser generica/historica
## (Agricultura, Mineracao...) e virou um sistema de MAGIA/manipulacao do
## mundo — ver TechDatabase.gd pra tabela nova. Os 4 campos abaixo (school/
## unlocks_spell/terrain_transform/description) foram adicionados pra
## sustentar esse tema; os originais (id/display_name/cost/prerequisites/
## unlocks_unit/bonus_*) continuam significando exatamente o mesmo de
## antes.

@export var id: String = ""
@export var display_name: String = ""
@export var cost: float = 30.0

## Nivel da arvore de Tecnologia mundana (1..10, ver TechDatabase.gd) — pedido
## do usuario: "pesquisar 2 tecnologias do nivel atual" libera o nivel
## seguinte INTEIRO, ao inves da cadeia de pre-requisito especifico de
## antes. Campo NOVO, usado so por TechDatabase (MagicDatabase nunca seta
## isto, fica no default 1 sem efeito — a arvore de Magia continua no
## modelo antigo de pre-requisito em cadeia, ver TechDatabase.
## available_techs/MagicDatabase.available_techs). Ver TechTree.
## _compute_tiers() pra como isto vira coluna na visualizacao.
@export var tier: int = 1

## Desde o portao "2 de N" (ver campo tier acima), prerequisites DEIXOU de
## decidir se a tech esta disponivel — isso agora e so tier + contagem
## (TechDatabase.available_techs). Mas o campo continua tendo DOIS usos
## reais, nao e decorativo morto:
## 1) Ancora de layout — TechTree._compute_components/_compute_rows/
##    _align_rows_within_group/_draw continuam agrupando/alinhando/ligando
##    cards por conectividade deste campo (mesmo algoritmo de sempre, ver
##    TechTree.gd). Pra Doutrina, cada tech aponta (quando fizer sentido)
##    pra sua antecessora de mesma familia (ex: "quartel_2" aponta pra
##    "quartel") so pra o desenho continuar coeso.
## 2) Preferencia suave da IA — RivalAI._score_research_candidate's
##    continues_chain ainda le isto pra dar bonus de pontuacao a quem
##    continua uma familia ja comecada (nao e mais um bloqueio, so uma
##    preferencia).
## Pra Magia, este campo continua sendo o mecanismo de LIBERACAO de
## verdade (nada mudou la).
@export var prerequisites: Array[String] = []

## "" = nao desbloqueia unidade nenhuma. Guarda e Colonizador nao dependem
## de tecnologia NEM de predio pra treinar (pedido do usuario: "o guarda
## comum nao precisa de quartel pra ser feito") — os dois ficam sempre
## disponiveis desde o primeiro turno. Homem de Armas ainda depende do
## Quartel estar CONSTRUIDO pra treinar de verdade, e o Quartel em si exige
## a tech "Quartel" pra poder ser construido (ver BuildingDatabase.
## building_that_trains / City._tech_unlocked_for_building) — os dois gates
## sao independentes.
@export var unlocks_unit: String = ""

## "" = nao desbloqueia predio nenhum. Mesma ideia de unlocks_unit, so que
## pra um predio SEM trains_unit (ex: Muralhas) — esses nao aparecem no
## mecanismo de tech_that_unlocks(kind) normal (kind == building.trains_unit
## seria "", e tech_that_unlocks("") sempre devolve null de proposito, ver
## TechDatabase.gd) entao precisam do proprio campo pra travar a
## CONSTRUCAO do predio (ver TechDatabase.tech_that_unlocks_building/City.
## _tech_unlocked_for_building).
@export var unlocks_building: String = ""

## Bonus de rendimento aplicado a QUALQUER tile destes biomas que a
## civilizacao estiver trabalhando, uma vez pesquisada — ver
## City.collect_yields() e TechDatabase.yield_bonus_for().
@export var bonus_terrain_types: Array[int] = []
@export var bonus_food: int = 0
@export var bonus_production: int = 0
@export var bonus_gold: int = 0

## Mesma logica de bonus_food/production/gold, so que pro rendimento de
## Mana (ver TechDatabase.yield_bonus_for/City.effective_tile_yield).
## Nenhuma tecnologia usa isto ainda — campo adicionado pra manter os 4
## tipos de rendimento simetricos no sistema (ver Ponto 3, "Economia
## Arcana"), pronto pra uma tech futura de bioma+mana sem exigir outro
## passe de refatoracao.
@export var bonus_mana: int = 0

## Escola/afinidade magica desta pesquisa (ex: "Arcanismo", "Geomancia",
## "Necromancia", "Transmutacao", "Alquimia", "Naturalismo",
## "Elementalismo") — puramente descritivo, usado pra colorir o card na
## TechTree (ver TechTree._school_color) e agrupar visualmente a arvore
## por tema. "" pra qualquer tech sem escola definida (nao deveria
## acontecer na tabela atual, mas nao e obrigatorio pro resto do sistema
## funcionar).
@export var school: String = ""

## Nome de um ritual/feitico que esta pesquisa concede ao jogador, alem
## de qualquer unidade/bonus de bioma — ver TechDatabase.unlocked_spells_
## for(). "" = nao concede feitico nenhum. Puramente informativo por
## enquanto (mostrado como badge na TechTree/tooltip da HUD); nenhum
## sistema de conjuracao/efeito de feitico em jogo consome isto ainda —
## fica registrado aqui pra um passe futuro poder ler "quais feiticos o
## jogador ja tem" sem precisar duplicar essa lista em outro lugar.
@export var unlocks_spell: String = ""

## Escopo futuro: capacidade de transformar um bioma em outro (ex:
## Transcendencia Florestal transformando Tundra/Deserto em terra
## fertil). Formato sugerido: {"from": Array[TerrainType], "to":
## TerrainType}. Dictionary crua (nao um Resource tipado) de proposito —
## e so um registro de DADOS por enquanto, nenhuma logica de HexGrid/
## City le isto ainda (implementar a transformacao de fato — mudar o
## TerrainType de um tile em jogo — fica fora do escopo desta rodada,
## que e so a arvore de tecnologia). default {} = pesquisa nao transforma
## bioma nenhum.
@export var terrain_transform: Dictionary = {}

## Texto de lore/sabor exibido no card da TechTree, embaixo do resumo de
## efeito — puramente narrativo, nunca lido por nenhuma logica de
## gameplay.
@export var description: String = ""

## Roadmap "polimento definitivo V1": familia de apresentacao da Arvore de
## Tecnologia MUNDANA — um dos 4 consts FAMILY_* abaixo, ou "" (default,
## usado por TODA tech de MagicDatabase, que nunca seta isto — a Magia
## continua sem familia visual nenhuma). Substitui o dict FAMILY_OF que
## TechTierBoard.gd hardcodeava antes (inferencia por id, sem dado real) —
## agora e um campo de verdade em TechData, unica fonte. Puramente
## apresentacao: TechTierBoard.gd agrupa cards nesta familia dentro de cada
## nivel, TechTierBoard's filtro de familia le isto direto — NAO afeta
## disponibilidade/bloqueio (isso continua so tier + contagem, ver
## TechDatabase.available_techs), nem prerequisites (que continua sendo a
## ancora cosmetica/preferencia de IA separada, ver comentario acima).
@export var display_family: String = ""

const FAMILY_MILITAR := "militar"
const FAMILY_ECONOMIA := "economia"
const FAMILY_DEFESA := "defesa"
const FAMILY_EXPLORACAO_UTILIDADE := "exploracao_utilidade"

## Frase curta e HONESTA de "o que eu ganho pesquisando isso" — mostrada no
## card no lugar do antigo "Desbloqueia: <nome interno>". Pedido explicito
## do usuario: NUNCA prometer um efeito que ainda nao existe no jogo (ex:
## aura do General, reparo do Engenheiro de Cerco) — pra mecanica ainda nao
## implementada, o texto descreve a unidade/estrutura de forma honesta e diz
## que o efeito especifico ainda esta por vir, em vez de inventar um verbo
## de gameplay que nao roda. "" so pra tech de MagicDatabase (que nunca seta
## isto ainda — fora de escopo desta rodada, so Tecnologia usa por enquanto).
@export var effect_text: String = ""

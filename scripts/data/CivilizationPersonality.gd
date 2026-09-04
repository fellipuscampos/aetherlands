class_name CivilizationPersonality
extends RefCounted

## Roadmap "Parte B", fatia B4 (fecha a Parte B) — personalidade
## civilizacional PROSPECTIVA/intencional, sorteada uma vez por partida e
## estavel dali pra frente. Explicitamente DIFERENTE de CityIdentity.
## civilization_axis_strength() (B3): aquela e RETROSPECTIVA, recalculada
## toda chamada a partir de City.buildings, zero estado guardado. Esta aqui
## e o oposto — uma INTENCAO fixa, sorteada uma vez, que nao muda com o que
## as cidades constroem depois. "Personalidade e uma intencao persistente;
## identidade e evidencia historica" (pedido do usuario) — as duas
## convivem, nenhuma substitui a outra (ver RivalAI._score_research_
## candidate, que soma os dois termos). INVARIANTE PROTEGIDA pra qualquer
## fatia futura: personalidade NUNCA deve ser alterada pela identidade
## (nunca "personality += civilization_axis_strength" nem nenhuma forma de
## aprendizado/deriva) — as duas sao entradas INDEPENDENTES numa decisao,
## nunca uma alimentando a outra.
##
## Reusa os 5 eixos de CityIdentity.AXES como vocabulario (pedido explicito
## do usuario: "os cinco eixos ja existentes sao uma linguagem
## suficientemente boa... evitam criar uma segunda taxonomia") — nada de
## enum AGGRESSIVE/EXPANSIONIST/etc novo.
##
## ACHADO QUE FUNDAMENTA O ARMAZENAMENTO (o mais importante deste arquivo):
## personalidade PARECE estado (sorteada uma vez, estavel a partida
## inteira) mas NUNCA e serializada em SaveManager.gd. Em vez disso e
## DERIVADA deterministicamente de HexGrid.map_seed, exatamente como
## terreno/recursos/covis ja sao (ver HexGrid.generate_map(), offsets
## fixos map_seed+500/1000/2000/3000/4000/5000/6000/7000, comentario la:
## "Offsets fixos (nao randi() de novo) pra continuar 100% deterministico
## a partir da mesma map_seed — Salvar/Carregar depende disso"). Um save
## sempre chama generate_map(map_seed) ANTES de GameManager.setup_players()
## (ver SaveManager.gd:90,110) — entao carregar um save sempre regenera a
## mesma personalidade que existia quando o jogo foi salvo, SEM precisar
## guardar um campo novo, SEM bump de SAVE_VERSION. Quarta vez que este
## projeto usa "derive, nao duplique estado" (covil/identidade de cidade/
## afinidade de tecnologia, agora personalidade) — desta vez a fonte da
## verdade e map_seed em vez de City.buildings.
##
## Estrategia de geracao ("opcao 3" escolhida pelo usuario): lean BASE por
## raca (fundamentado na mesma lore ja usada por RaceEconomy.gd/
## GameSetupScreen.RACE_INFO — nao inventa flavor novo) + jitter pequeno
## seedado (mesma fonte de determinismo de HexGrid acima). Mantem a raca
## reconhecivel entre partidas (Orc sempre tende a militar) sem tornar
## toda partida da mesma raca IDENTICA no detalhe.

## Magnitude do lean-base (0.0-1.0) — deixa headroom acima pro jitter nunca
## estourar 1.0 sozinho (0.6 base + 0.15 jitter = 0.75 no pior caso de alta,
## bem abaixo do teto 1.0) e headroom abaixo pra um eixo SEM lean (base 0.0)
## nunca ficar deterministicamente negativo (clamp cuida disso de qualquer
## forma). Harness-validate-later, mesma disciplina de AGRICOLA_FOOD_BONUS_
## MAX etc (CityIdentity.gd) — "variavel sistemica pequena -> decisao
## existente -> formula aditiva -> teste comportamental -> harness antes de
## calibrar".
const BASELINE_LEAN_MAGNITUDE := 0.6

## Jitter simetrico somado por cima do lean-base, POR EIXO — pequeno de
## proposito (bem menor que BASELINE_LEAN_MAGNITUDE), so pra "evitar
## comportamento totalmente deterministico entre partidas diferentes"
## (pedido do usuario) sem afogar o lean racial reconhecivel. Garantia
## MATEMATICA (nao so "tendencia" estatistica): uma raca com lean 1.0 num
## eixo nunca cai abaixo de BASELINE_LEAN_MAGNITUDE - JITTER_RANGE nesse
## eixo, e uma raca SEM lean nenhum (ou raca desconhecida) nunca passa de
## JITTER_RANGE em eixo nenhum.
const JITTER_RANGE := 0.15

## Lean base por raca, eixo -> peso 0.0-1.0 (multiplicado por
## BASELINE_LEAN_MAGNITUDE em generate() abaixo). Raca ausente da tabela
## (inclusive "human" e "" ou qualquer raca desconhecida) = SEM lean
## nenhum, todo eixo cai so no jitter — e a leitura mecanica de "equilibrio"
## pedida pelo usuario pro humano, mesmo espirito do "generalista" que
## CityIdentity.dominant_axis() ja usa pra cidade sem predio de eixo nenhum
## (retorna "").
## - Orc -> AXIS_MILITAR: match VERBATIM com o texto original do usuario
##   ("Orc -> militar agressivo") e com RaceEconomy.ORC_PRODUCTION_BONUS/
##   GameSetupScreen.RACE_INFO.orc ("A Ameaca Implacavel, Senhores da
##   Guerra").
## - Elfo -> AXIS_ARCANA: RaceEconomy.ELF_MANA_BONUS/RACE_INFO.elf ("...
##   maestria inigualavel na Magia... luz arcana").
## - Anao -> AXIS_COMERCIAL (peso cheio) + AXIS_INDUSTRIAL (peso reduzido):
##   RaceEconomy.DWARF_GOLD_PRODUCTION_BONUS bonifica OURO e PRODUCAO ao
##   mesmo tempo (Colina/Ferro) — o mesmo par de eixos aqui, comercial
##   dominante (ouro/riqueza e o tema mais forte de RACE_INFO.dwarf:
##   "Guardioes da Riqueza"), industrial secundario (peso 0.6, nao 1.0)
##   porque e o tema mais fraco dos dois na lore, nao ausente.
const BASELINE_LEAN := {
	"orc": {CityIdentity.AXIS_MILITAR: 1.0},
	"elf": {CityIdentity.AXIS_ARCANA: 1.0},
	"dwarf": {CityIdentity.AXIS_COMERCIAL: 1.0, CityIdentity.AXIS_INDUSTRIAL: 0.6},
	# "human" ausente de proposito -- ver comentario acima.
}

## Offset de canal FIXO — mesmo CONTRATO de namespace de RNG que HexGrid.
## generate_map() ja usa (+500 a +7000) e o RNG de recompensa de covil
## (+4000): cada canal reserva sua faixa e nunca reusa a de outro, pra
## nenhum gerador colidir com outro mesmo compartilhando o mesmo map_seed
## como raiz. +9000 confirmado livre (nenhum canal existente usa essa
## faixa) — GameManager.setup_players() soma um SLOT por jogador em cima
## disto (humano = +0, rival no indice i do loop = +i+1), documentado ali
## como parte do MESMO contrato.
const PERSONALITY_SEED_OFFSET := 9000

## Gera a personalidade (eixo -> forca 0.0-1.0) de uma civilizacao, PURA e
## deterministica: mesma `race` + mesma `rng_seed` -> mesmo resultado
## sempre (ver comentario de topo sobre por que isso dispensa SaveManager).
## Itera CityIdentity.AXES NA ORDEM FIXA declarada la (nao lean.keys()) de
## proposito -- consumo do RNG precisa ser deterministico independente de
## quais eixos a raca tem lean ou nao, senao duas racas com tabelas
## diferentes consumiriam o RNG em ordens diferentes e o resultado deixaria
## de ser reproduzivel so pela dupla (race, rng_seed).
static func generate(race: String, rng_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var lean: Dictionary = BASELINE_LEAN.get(race, {})
	var personality := {}
	for axis in CityIdentity.AXES:
		var base: float = float(lean.get(axis, 0.0)) * BASELINE_LEAN_MAGNITUDE
		var jitter := rng.randf_range(-JITTER_RANGE, JITTER_RANGE)
		personality[axis] = clamp(base + jitter, 0.0, 1.0)
	return personality

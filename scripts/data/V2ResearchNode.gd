class_name V2ResearchNode
extends Resource

## Um nó de pesquisa do Aetherlands V2 (ver docs/AETHERLANDS_V2_IMPLEMENTATION.md
## e V2ResearchDatabase.gd). Recurso puro de dados. (Fase 25: o TechData/TechDatabase
## V1 foi removido; este é o único tipo de nó de pesquisa.)
##
## FASE 0 (scaffold): estes dados descrevem a estrutura das três árvores V2.
## Nenhum campo abaixo altera gameplay — `unlock_type`/`unlock_id` dizem o que
## um nó DESBLOQUEARÁ numa fase futura, e `is_placeholder` continua true até
## essa fase existir.

## As três árvores visuais. São categorias do MESMO sistema de pesquisa V2:
## no futuro a civilização terá um único projeto ativo, pago em Conhecimento,
## qualquer que seja a árvore do nó.
enum TreeType { MILITARY_DOCTRINE, MAGIC_SCHOOL, INFRASTRUCTURE }

## Branch dos nós universais (Exército Supremo, Transcendência): não pertencem
## a nenhuma linha, mas pertencem à árvore do seu tipo.
const UNIVERSAL_BRANCH := "universal"

## Id estável (prefixo v2_, ver V2ResearchDatabase.ID_PREFIX). O conteúdo do nó
## pode mudar entre fases; o id, preferencialmente, não.
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export var tree_type: TreeType = TreeType.MILITARY_DOCTRINE
## Linha dentro da árvore (ex.: "guardian", "sacred", "economy") ou
## UNIVERSAL_BRANCH.
@export var branch: String = ""
## 1..9 nas Doutrinas/Escolas, 1..3 na Infraestrutura, 10 nos nós universais.
@export var tier: int = 1
## Papel estrutural do tier (ex.: "base_unit", "grand_manifestation"). Faz
## parte do design oficial da V2, NÃO é placeholder — ver as tabelas
## *_TIER_ROLES em V2ResearchDatabase.
@export var tier_role: String = ""

## BALANCE PLACEHOLDER: valores provisórios de progressão, nunca balanceados.
@export var cost: float = 0.0

## Pré-requisitos lineares (o tier anterior da mesma linha). Vazio no N1 e nos
## nós universais — estes usam `requirement`.
@export var prerequisites: Array[String] = []

## O que este nó desbloqueará no futuro ("unit", "spell", "building", ...).
## NADA disto é aplicado nesta fase.
@export var unlock_type: String = ""
@export var unlock_id: String = "placeholder"
## true = conteúdo (nome/descrição/unlock_id) ainda é placeholder estrutural.
## Falso nos nós com conteúdo canônico (Doutrinas Militares, Fase 2) — mas isso
## NÃO significa gameplay: veja `gameplay_connected`.
@export var is_placeholder: bool = true
## Sempre false até uma fase conectar o unlock ao jogo. Concluir um nó V2 não
## altera nada no gameplay enquanto isto for false.
@export var gameplay_connected: bool = false

## Função pretendida do nó, em uma frase (design, não números). Fase 2: só as
## Doutrinas Militares; "" nos demais.
@export var intent: String = ""

## Linha de evolução das unidades convencionais (Fase 2, só metadata — nenhum
## upgrade existe no jogo): ids de UNLOCK (não de pesquisa) da forma anterior/
## seguinte. "" fora dos três nós de unidade da linha (unidade-base -> evolução
## -> Elite). Ex.: Escudeiro upgrade_to = v2_unit_guardian.
@export var upgrade_from: String = ""
@export var upgrade_to: String = ""

## Identidade semântica da linha, replicada em cada nó para consulta direta:
## Escolas ("sustain", "magical_damage", ...), Doutrinas ("tank_frontline", ...)
## e Infraestrutura ("gold", "supplies", ...).
@export var branch_role: String = ""

## true nos nós universais (capstones).
@export var is_universal: bool = false
## Regra estrutural dos capstones, ex.: {"type": "complete_branches",
## "tree_type": MAGIC_SCHOOL, "branch_count": 2, "at_tier": 9}. {} nos demais.
## Só representa a regra (V2ResearchDatabase.capstone_requirement_met) — não
## executa vitória nenhuma.
@export var requirement: Dictionary = {}

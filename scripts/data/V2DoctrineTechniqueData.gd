class_name V2DoctrineTechniqueData
extends Resource

## Uma Técnica Militar de Doutrina do Aetherlands V2 (Fase 4). Recurso puro de dados,
## como UnitData/BuildingData — quem interpreta é V2TechniqueRuntime. Vem de um
## registro (V2DoctrineTechniqueDatabase), nunca de `if id == "..."` espalhado.
##
## Técnica Militar NÃO é magia: não custa Mana, não depende de conjurador, não entra
## no Grimório e não usa Escola Mágica. Custa a AÇÃO da unidade (e o movimento que
## restava) e entra em recarga. A unidade continua com o ataque básico quando a
## Técnica está indisponível.
##
## BALANCE PLACEHOLDER: todos os números abaixo são provisórios, nunca balanceados.

## Como a técnica entra em jogo (Fase 5). ACTIVE: o jogador a ativa (botão), ela gasta a ação, tem
## recarga e um efeito com duração (Muralha de Escudos). PASSIVE: vale sozinha enquanto a
## civilização tem o nó pesquisado e a unidade é da linha — sem botão, sem recarga, sem duração,
## sem ação consumida e SEM estado guardado (Preparar Lanças). O modo vem do dado; nenhum código
## decide "tem botão?" por id.
enum ActivationMode { ACTIVE, PASSIVE }
@export var activation_mode: ActivationMode = ActivationMode.ACTIVE

## Duração: até o início do próximo turno do DONO da unidade. É a única política
## que a Fase 4 precisa; a constante existe pra a próxima técnica declarar a sua.
const DURATION_UNTIL_OWNER_NEXT_TURN := "until_owner_next_turn"

## unlock_id do nó de pesquisa que a libera (ex.: v2_technique_shield_wall) — é
## também o id da técnica e a chave usada em Unit.magic_cooldowns/magic_status.
@export var id: String = ""
## Nome e descrição curta (o nome vem do nó de pesquisa, fonte única).
@export var display_name: String = ""
@export var description: String = ""
## Linha da Doutrina (V2ResearchNode.branch, ex.: "guardian"). A elegibilidade é
## POR LINHA: toda unidade da linha (Escudeiro, Guardião, Sentinela...) pode usar.
@export var doctrine_branch: String = ""

@export var duration: String = DURATION_UNTIL_OWNER_NEXT_TURN
## Turnos até poder usar de novo (contando o turno do uso: usou no turno T, volta no T+N).
@export var cooldown_turns: int = 3
## Gasta a ação da unidade: exige movimento restante e o zera (ver V2TechniqueRuntime.activate).
@export var consumes_action: bool = true

## Bônus de Defesa da própria unidade enquanto ativa (0.35 = +35%).
@export var self_defense_bonus: float = 0.0
## Bônus de Defesa dos ALIADOS adjacentes enquanto a unidade estiver ativa. É por
## formação: consultado no cálculo de defesa, nunca aplicado como buff permanente.
@export var adjacent_ally_defense_bonus: float = 0.0
@export var adjacent_radius: int = 1

## PASSIVA: bônus no ATAQUE BÁSICO da unidade contra alvos com QUALQUER um dos traços de `basic_attack_target_traits` (UnitData.traits; Fase 5:
## ["mounted"]; Fase 10, Desmantelar: ["caster", "siege"] — a LISTA aceita várias categorias sem refatorar). 0.5 = +50%, contado UMA vez mesmo se o
## alvo tiver mais de um traço da lista. Não vale pra dano de cidade, feitiço nem efeito de mapa (só entra em UnitAbilities.attack_multiplier).
@export var basic_attack_bonus: float = 0.0
@export var basic_attack_target_traits: Array[String] = []

## ATAQUE ATIVO (Fase 7 — Golpe Poderoso, Ataque em Arco): em vez de um efeito com duração (postura), a
## técnica é uma AÇÃO OFENSIVA resolvida na hora pelo combate normal (CombatResolver.resolve), só com o
## Ataque multiplicado por `strike_multiplier` (> 0 = é uma técnica de ataque). Sem `magic_status`: o único
## estado é a recarga (`magic_cooldowns`), então save/load e a evolução de forma já a preservam.
## SINGLE_TARGET: o jogador escolhe UM inimigo ao alcance (modo de mira). ADJACENT_ENEMIES: sem mira, atinge até
## `strike_max_targets` inimigos adjacentes (escolha determinística, ver V2TechniqueRuntime.strike_targets).
## TARGET_AND_NEIGHBORS (Fase 8, Saraivada): o jogador escolhe um alvo PRIMÁRIO ao alcance; ele sempre entra e o golpe
## atinge também os inimigos a até `strike_splash_radius` tiles dele, até `strike_max_targets` no total (primário incluso).
enum StrikeTargeting { SINGLE_TARGET, ADJACENT_ENEMIES, TARGET_AND_NEIGHBORS }
@export var strike_multiplier: float = 0.0
@export var strike_targeting: StrikeTargeting = StrikeTargeting.SINGLE_TARGET
@export var strike_max_targets: int = 1
## Alcance do golpe (Fase 8: por DADO). FIXED: `strike_range` tiles absolutos (1 = adjacente, o melee do Golpe Poderoso).
## ATTACK_RANGE_PLUS: o alcance BÁSICO da unidade (`UnitData.attack_range`) + `strike_range` de bônus — o mesmo dado serve
## Arqueiro (2), Atirador de Elite (3)… sem lista de unidades. Só unidades hostis; nunca cidade nem covil.
enum StrikeRangeMode { FIXED, ATTACK_RANGE_PLUS }
@export var strike_range_mode: StrikeRangeMode = StrikeRangeMode.FIXED
@export var strike_range: int = 1
## Raio ao redor do alvo primário (só TARGET_AND_NEIGHBORS).
@export var strike_splash_radius: int = 1
## Distância INICIAL mínima do alvo (em tiles): 1 = qualquer (o padrão de todos os golpes); 2 = o alvo não pode estar colado (a Carga precisa de espaço).
@export var strike_min_range: int = 1
## PENETRAÇÃO DE DEFESA (Fase 10, Ataque Furtivo): fração [0, 1] da Defesa do alvo IGNORADA durante a resolução DESTE golpe (0.4 = só 60% da Defesa
## conta). Aplicada dentro da MESMA fórmula de sempre (CombatResolver.predict/resolve reduzem a contribuição da Defesa antes da mitigação) — nunca uma
## correção pós-cálculo, nunca um `if id`. 0.0 (padrão) = comportamento idêntico a antes de existir este campo.
@export var strike_defense_penetration: float = 0.0
## SEM REVIDE (Fase 10, Ataque Furtivo): o alvo não contra-ataca NESTA resolução específica, mesmo em alcance corpo a corpo — o efeito dura só o golpe;
## se o alvo sobreviver, continua sem nenhum status (pode agir normalmente no turno dele). false (padrão) = revide normal.
@export var strike_prevents_counterattack: bool = false
## MOVER-E-ATACAR (Fase 9, Carga): NONE = o golpe sai de onde a unidade está. MOVE_ADJACENT_TO_TARGET = antes de atacar a unidade percorre, pelo seu perfil de
## movimento (terreno, bloqueios e ocupação normais; o voo pelo voo), uma rota real até um tile LIVRE adjacente ao alvo — o melhor por custo real, depois menos
## passos, depois coordenada — e ataca dali. Sem tile alcançável o alvo é inválido e nada é gasto.
enum StrikeReposition { NONE, MOVE_ADJACENT_TO_TARGET }
@export var strike_reposition: StrikeReposition = StrikeReposition.NONE

## O que a mira escolhe (Fase 9): UNIT = uma unidade (Golpe, Disparo, Carga...); TILE = um tile vazio (Retirada Tática);
## CITY (Fase 11, Bombardeio Preparado) = uma cidade/fortificação hostil ao alcance — nunca unidade nem tile vazio.
enum TargetMode { UNIT, TILE, CITY }
@export var target_mode: TargetMode = TargetMode.UNIT

## PASSIVA contra CIDADE/FORTIFICAÇÃO (Fase 11, Munição Demolidora): bônus multiplicativo no ataque de CERCO contra cidade —
## ataque básico de Cerco (UnitAbilities.city_attack_multiplier) e Bombardeio Preparado (V2TechniqueRuntime.perform_city_strike),
## ambos dentro da MESMA fórmula de sempre (CombatResolver.resolve_city_attack). NUNCA unidade, monstro, covil, feitiço nem dano
## ambiental. 0.4 = +40%. Por LINHA + pesquisa, mesmo princípio de basic_attack_bonus: sem estado guardado, nunca duplicado.
@export var city_attack_bonus: float = 0.0

## REQUISITO DE PREPARAÇÃO (Fase 11, Bombardeio Preparado): a unidade só pode usar esta Técnica se ainda NÃO tiver se movido
## neste turno (movement_left == movement_points do dado — nada é salvo, é derivado do próprio estado de movimento). Uma
## unidade com `UnitData.ignores_technique_stationary_requirement` (Colosso de Cerco — Artilharia Andante) ignora ESTE
## requisito específico; a Técnica continua consumindo a ação e o movimento normalmente. false (padrão) = sem este requisito.
@export var strike_requires_undisturbed: bool = false
## REPOSICIONAMENTO (Fase 9, Retirada Tática): com target_mode TILE, a unidade vai a um tile livre alcançável em até `relocate_range` passos. `relocate_flat_cost`
## = cada passo conta 1 (o custo do terreno não reduz o alcance); o terreno realmente impassável e a ocupação continuam valendo. Ao chegar aplica o efeito de
## postura do dado (`self_defense_bonus`, por `duration`) — o MESMO estado temporário da Muralha de Escudos, sem campo novo.
@export var relocate_range: int = 0
@export var relocate_flat_cost: bool = true

func is_passive() -> bool:
	return activation_mode == ActivationMode.PASSIVE

func is_strike() -> bool:
	return strike_multiplier > 0.0

## Ataque de CERCO contra CIDADE/FORTIFICAÇÃO (Fase 11, Bombardeio Preparado) — nunca unidade. Um alvo por golpe, sempre com mira.
func is_city_strike() -> bool:
	return is_strike() and target_mode == TargetMode.CITY

## Reposiciona a unidade a um tile escolhido (Retirada Tática)?
func is_relocation() -> bool:
	return target_mode == TargetMode.TILE and relocate_range > 0

## O golpe move a unidade até o alvo antes de atacar (Carga)?
func repositions() -> bool:
	return is_strike() and strike_reposition != StrikeReposition.NONE

## O jogador escolhe um alvo (unidade ou tile) no modo de mira? Só as técnicas de ataque sem mira (ADJACENT_ENEMIES) e as posturas resolvem na hora.
func needs_target() -> bool:
	return is_relocation() or (is_strike() and strike_targeting != StrikeTargeting.ADJACENT_ENEMIES)

## Alcance efetivo (em tiles) do golpe para uma unidade com este dado: fixo, ou alcance básico + bônus.
func resolved_range(data: UnitData) -> int:
	if strike_range_mode == StrikeRangeMode.ATTACK_RANGE_PLUS and data != null:
		return maxi(1, data.attack_range) + strike_range
	return strike_range

func has_defense_effect() -> bool:
	return self_defense_bonus > 0.0 or adjacent_ally_defense_bonus > 0.0

func has_attack_effect() -> bool:
	return basic_attack_bonus > 0.0 and not basic_attack_target_traits.is_empty()

func has_city_attack_effect() -> bool:
	return city_attack_bonus > 0.0

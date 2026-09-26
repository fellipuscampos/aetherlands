class_name UnitData
extends Resource

## Escola de Magia da unidade (conjurador / Grande Manifestação); "" = não conjura. V2MagicRuntime e
## V2ManifestationSystem só leem este campo. Fase 25: o antigo `magic_school` das Escolas V1 foi
## removido junto com a magia V1 (o nome com prefixo "v2_" continua para não mexer em todo consumidor).
@export var v2_magic_school: String = ""
## Multiplicador da potência de DANO dos feitiços V2. Não afeta cura, buffs,
## ataque básico, Técnicas ou Ataque da Cidade.
@export var spell_damage_multiplier: float = 1.0
## Fase 20 — alcance EXTRA do alvo primário de TODO feitiço V2 que esta unidade conjura (efetivo = cast_range + bônus).
## Nunca muda área, Mana, recarga nem visão. 0 (padrão) = comportamento idêntico ao de antes para toda Escola.
@export var spell_range_bonus: int = 0
## Nome público opcional da passiva do bônus acima (Avatar da Natureza: "Domínio Natural"). Só UI.
@export var spell_range_bonus_name: String = ""
## Fase 21 — reduz a recarga GRAVADA por um cast V2 (mínimo 0). Default inerte; não altera
## recargas já em curso, Mana, alcance ou potência.
@export var spell_cooldown_reduction: int = 0
@export var spell_cooldown_reduction_name: String = ""
## Fase 22 — bônus materializado na criação de uma zona ambiental; não depende
## do caster depois disso. Default inerte para todas as unidades preexistentes.
@export var environmental_zone_duration_bonus: int = 0
@export var environmental_zone_duration_bonus_name: String = ""
## Nome público opcional da passiva que concede o multiplicador acima. O runtime
## continua usando apenas o número; UI/inspector exibem este dado sem conhecer Escola/kind.
@export var spell_damage_multiplier_name: String = ""

@export var unit_name: String = "Unidade"
@export var movement_points: float = 2.0
@export var attack: float = 1.0
@export var defense: float = 1.0
@export var attack_range: int = 1 # 1 = corpo-a-corpo, 2+ = a distancia (sem contra-ataque)
@export var max_hp: float = 10.0
@export var vision_range: int = 3
@export var can_found_city: bool = false
@export var visual_kind: String = "warrior"
@export var production_cost: float = 15.0
## Mago: ataque magico ignora o bonus de defesa de terreno E de predio
## (colinas/floresta/montanha, Muralhas) do defensor — nao protegem
## contra magia. Ver CombatResolver.predict().
@export var ignores_terrain_defense: bool = false

## So > 0 pra monstros neutros (MonsterDatabase) que guardam Covis de
## Monstro espalhados pelo mapa — quem derrotar o guardiao (Unit com
## owner_player == null) recebe esse ouro. Zero pra qualquer unidade de
## jogador. Ver CombatResolver.resolve().
@export var gold_reward: float = 0.0

## Grifo: ignora custo de terreno E atravessa oceano livremente (o resto do
## exercito precisa de estrada/costa) — ver HexGrid.compute_reachable().
@export var flies: bool = false

## Ent: cura essa fracao do HP maximo TODO turno, em qualquer lugar — nao
## precisa estar guarnicionado na propria cidade como o resto do exercito
## (GameManager._heal_if_garrisoned). Zero pra qualquer outra unidade. Ver
## GameManager._apply_regen().
@export var regen_fraction: float = 0.0

## Caminho de uma cena externa (.glb/.gltf, ex: KayKit) pra usar como corpo
## desta unidade EM VEZ da geometria procedural de Unit.gd — mesmo motivo/
## historico de BuildingData.model_scene_path (ver comentario la). ""
## (padrao) mantem o corpo procedural de sempre. Ver Unit._build_procedural_
## body().
@export var model_scene_path: String = ""

## Caminho de uma cena externa (.glb) contendo clipes de animacao pro MESMO
## esqueleto de model_scene_path (KayKit Character Animations — nomes de
## osso identicos entre o pacote de personagens e o de animacoes, mesmo
## rig compartilhado) — "" (padrao) deixa a unidade em bind pose (sem
## animar). Ver Unit._build_model_body()/_play_default_animation().
@export var animation_scene_path: String = ""

## Multiplica a escala calculada em cima de MODEL_TARGET_HEIGHT (Unit.gd) —
## 1.0 (padrao) mantem o comportamento de sempre pra qualquer unidade
## baseada em model_scene_path. So existe pra dar um ajuste POR UNIDADE
## sem mexer na constante compartilhada (que afetaria todo mundo, incluindo
## o Homem de Armas do KayKit, ja calibrado). Ver Unit._build_model_body().
@export var model_scale_multiplier: float = 1.0

## Fase 19 — quantos CORPOS de model_scene_path compõem o visual desta unidade (Hostes = um grupo num único
## token). PURAMENTE visual: as cópias extras são só malha filha da mesma Unit (sem HP, seleção ou caminho).
## 1 (padrão) = o comportamento de sempre. Ver Unit._build_model_body().
@export var model_formation_count: int = 1

## Rotacao extra (graus, eixo Y) aplicada ao modelo depois de carregado —
## alguns pipelines de exportacao (ex: a 3D Asset Factory procedural em
## tools/asset_factory) exportam a "frente" do personagem virada pro lado
## errado em relacao a convencao que slide_to() usa pra girar a unidade na
## direcao do movimento (-Z local = frente). 0.0 (padrao) nao muda nada.
## Ver Unit._build_model_body().
@export var model_yaw_offset_degrees: float = 0.0

## Overrides de nome de clipe pra unidades cujo animation_scene_path NAO
## segue a convencao KayKit ("Idle_A"/"Walking_A") — ex: a 3D Asset
## Factory procedural (tools/asset_factory) exporta clipes literalmente
## chamados "Idle"/"Walk"/"Attack"/"Death". "" (padrao) mantem as
## constantes de sempre (Unit.DEFAULT_ANIMATION/WALK_ANIMATION), ZERO
## mudanca pra qualquer unidade KayKit existente. Ver Unit._build_model_
## body().
@export var idle_animation_override: String = ""
@export var walk_animation_override: String = ""
@export var attack_animation_override: String = ""

## Todo pacote KayKit reaproveitado ate hoje separa Idle (vem do proprio
## personagem, model_scene_path) de Andar (sempre este segundo arquivo
## compartilhado, Unit.WALK_ANIMATION_SCENE) — precisa desse merge pra
## fechar os dois clipes. Uma unidade cujo animation_scene_path JA contem
## os proprios clipes de Idle E Andar (ex: a 3D Asset Factory, que exporta
## os 4 clipes prontos no mesmo arquivo do modelo) nao precisa — e nao
## deve, o rig dela nao bate com o esqueleto KayKit desse arquivo
## compartilhado. true (padrao) mantem o comportamento de sempre.
@export var merge_shared_walk_animation: bool = true

## Traços semânticos da unidade (Aetherlands V2, Fase 5): classificações de combate
## dirigidas por DADO, pra a lógica nunca decidir por nome/id. Hoje só "mounted".
## Bônus "contra montados" (Lanceiro V1, Preparar Lanças V2...) consultam has_trait em
## vez de listar ids; uma unidade nova entra na classificação declarando o traço.
const TRAIT_MOUNTED := "mounted"
## Fase 6: traço das Unidades Lendárias (V2LegendarySystem). Semeado por UnitDatabase.create_unit
## pra todo unlock `legendary_candidate`; uma unidade de teste pode declará-lo com qualquer id.
const TRAIT_LEGENDARY := "legendary"
## Voo (Fase 9): traço SEMÂNTICO de "esta unidade voa" — semeado a partir do perfil de movimento (`is_flying()`), consultável por qualquer regra
## futura (clima, anti-aéreo...) sem lista de ids. Não muda o movimento sozinho: quem move é `movement_profile`/`flies`.
const TRAIT_FLYING := "flying"
## Conjurador (Fase 10/18, Desmantelar): traço SEMÂNTICO unificado de "esta unidade lança
## feitiços". A geração da Escola continua separada nos campos acima.
const TRAIT_CASTER := "caster"
## Cerco (Fase 10, Desmantelar): traço SEMÂNTICO de "esta unidade é uma máquina de Cerco" — semeado a partir da ÚNICA lista que já existe
## (`UnitAbilities.SIEGE`, a mesma do bônus de dano contra cidade). Uma máquina de Cerco V2 futura só precisa declarar o traço.
const TRAIT_SIEGE := "siege"
## Grande Manifestação (Aetherlands V2, Fase 17): traço SEMÂNTICO da entidade mágica N9 de uma Escola
## (Serafim). Semeado da metadata de pesquisa (nó `grand_manifestation`), nunca de uma lista de ids.
## NÃO é `legendary`: o slot Lendário Militar e o de Manifestação são conceitos diferentes
## (V2LegendarySystem x V2ManifestationSystem) — a Caçada Lendária não vale contra uma Manifestação.
const TRAIT_GRAND_MANIFESTATION := "grand_manifestation"
## Morto-vivo (Fase 19): classificação SEMÂNTICA declarada no dado (Hostes, Lich). Serve a identificação e a
## filtros de alvo (`V2SpellData.required_target_trait`); não concede resistência/imunidade nenhuma.
const TRAIT_UNDEAD := "undead"
## Retinue/Hoste (Fase 19): unidade que OCUPA capacidade de comando mágico. Semeado do dado
## (`is_retinue()`: `retinue_school` + `retinue_command_cost` > 0), nunca de uma lista de ids.
const TRAIT_RETINUE := "retinue"
@export var traits: Array[String] = []

## Fase 19 — frases de UI para filtros de alvo por traço (V2SpellData.required_target_trait). Só texto.
const OWN_TARGET_PHRASES := {"": "uma unidade própria", TRAIT_UNDEAD: "uma unidade própria morta-viva", TRAIT_RETINUE: "uma Hoste própria"}
const OWN_TARGET_PLURALS := {"": "unidades próprias", TRAIT_UNDEAD: "unidades próprias mortas-vivas", TRAIT_RETINUE: "Hostes próprias"}

static func own_target_phrase(trait_id: String) -> String:
	return OWN_TARGET_PHRASES.get(trait_id, "uma unidade própria (%s)" % trait_id)

static func own_target_plural(trait_id: String) -> String:
	return OWN_TARGET_PLURALS.get(trait_id, "unidades próprias (%s)" % trait_id)

## RETINUES (Aetherlands V2, Fase 19 — V2RetinueSystem). Três campos de dado puro, defaults inertes:
## * `retinue_school` + `retinue_command_cost` > 0: esta unidade é uma retinue daquela Escola e ocupa
##   esse custo de comando (Hoste Esquelética 1, Hoste Macabra 2).
## * `retinue_command_capacity` > 0 num conjurador V2 (`v2_magic_school`): CONTRIBUI essa capacidade para
##   a Escola dele (Necromante 2, Lich 4). Capacidades somam por civilização e Escola; nada é salvo.
@export var retinue_school: String = ""
@export var retinue_command_cost: int = 0
@export var retinue_command_capacity: int = 0
## Nome público opcional da passiva que concede a capacidade acima (Lich: "Soberania dos Mortos"). Só UI.
@export var retinue_command_capacity_name: String = ""

## Aura INTRÍNSECA da unidade (Fase 6, V2UnitAuras): habilidade da própria unidade, não de pesquisa.
## Aliados do mesmo dono a até `aura_radius` tiles recebem `aura_defense_bonus` (0.2 = +20%) de
## Defesa, por posição real; nunca no emissor. `aura_id` agrupa: a mesma aura não acumula.
@export var aura_id: String = ""
@export var aura_name: String = ""
@export var aura_radius: int = 0
@export var aura_defense_bonus: float = 0.0

## PERFIL DE MOVIMENTO (Fase 9-10). GROUND = o pathfinding de sempre (custo de terreno, terreno impassável, unidades bloqueiam). FLYING = voo TÁTICO: até
## `movement_points` passos por distância geométrica, sobre qualquer terreno e qualquer unidade, terminando só em tile de terra livre (HexGrid.flight_reachable).
## INFILTRATOR (Fase 10, Passo Sombrio): conectividade TERRESTRE normal (nunca atravessa água/montanha/terreno impassável), mas unidades no meio do
## caminho (aliadas OU inimigas) não bloqueiam a passagem — só o TILE FINAL precisa estar livre; cada passo atravessável custa 1, ignorando o custo do
## terreno (HexGrid.infiltrate_reachable). Diferente de FLYING: nunca cruza água/montanha, então nunca precisa da regra de "pouso legal".
## `flies` (V1: monstros/Grifo V1) segue sendo o voo "livre" do pathfinding antigo e NÃO muda; FLYING/INFILTRATOR são só do V2 — para o resto do jogo
## (IA, ordens de mover de vários turnos) essas unidades andam como terrestres, sem risco de terminar num tile ilegal.
enum MovementProfile { GROUND, FLYING, INFILTRATOR }
@export var movement_profile: MovementProfile = MovementProfile.GROUND
## Modelo visual PROVISÓRIO reaproveitado: nome de um visual_kind V1 com corpo procedural (ex.: "cavalry", "griffin") usado no lugar do próprio
## `visual_kind` ao montar o corpo — assim uma unidade V2 herda um visual existente sem arte nova. "" = o próprio visual_kind / model_scene_path.
@export var visual_template: String = ""
## Vulnerabilidade a ataques FÍSICOS À DISTÂNCIA (Fase 9): o dano que esta unidade recebe de um atacante cujo alcance de ataque é maior que 1 é
## multiplicado por (1 + bônus). 0.25 = +25%. Não vale contra melee, feitiço, cidade nem dano ambiental. Por DADO (UnitAbilities.ranged_vulnerability_multiplier).
@export var ranged_damage_taken_bonus: float = 0.0

## EXCEÇÃO por dado ao requisito "não se moveu neste turno" de uma Técnica (Fase 11, Colosso de Cerco — Artilharia Andante):
## quando true, `V2TechniqueRuntime.unavailable_reason` ignora `V2DoctrineTechniqueData.strike_requires_undisturbed` para esta
## unidade. Só remove ESSE requisito específico — a Técnica continua consumindo a ação, zerando o movimento e entrando em
## recarga normalmente; nenhuma ação extra é concedida. false (padrão) = comportamento idêntico a antes de existir este campo.
@export var ignores_technique_stationary_requirement: bool = false

## Aetherlands V2, Fase 15 — quantos Suprimentos esta unidade consome enquanto viva OU reservada em
## produção (V2LogisticsRuntime.player_supply_used). 0 (padrão) = toda unidade V1, o Colonizador e o
## Construtor — nenhuma delas participa da conta de Suprimentos. Só as 24 formas militares V2
## (N3/N5/N7/N9 das seis Doutrinas) declaram um valor > 0. Nunca identificado por nome/id em
## runtime — é dado puro.
@export var supply_cost: int = 0

## Aetherlands V2, Fase 15 — redireciona o GATE de pesquisa desta unidade pra outro unlock_id, em
## vez do próprio `visual_kind`/kind de produção (V2UnlockSystem.is_unit_unlocked). "" (padrão) =
## usa o próprio kind, comportamento idêntico a antes deste campo existir, pra toda unidade V2
## já conectada. Existe pro Construtor: `required_v2_unlock_id = "v2_building_workshop"` faz
## "pesquisar Oficinas" liberar o Construtor, sem um segundo unlock artificial no mesmo nó de
## pesquisa (§53 do pedido).
@export var required_v2_unlock_id: String = ""

## Aetherlands V2, Fase 17 — a unidade pode fazer ATAQUE BÁSICO (iniciar um ataque comum e revidar)?
## false = conjurador sem ataque (Clérigo, Serafim): nunca inicia ataque, nunca revida, nunca aparece
## como "podendo atacar" — mas continua podendo ser atacada, mover e conjurar. Semântica EXPLÍCITA de
## propósito: Ataque 0 sozinho não basta (o motor tem piso de dano de 1). true (padrão) = toda unidade
## existente, comportamento idêntico a antes deste campo.
@export var can_basic_attack: bool = true

## Aetherlands V2, Fase 17 — Mana cobrada na CONCLUSÃO da produção desta unidade (Serafim: 60). Exigida
## para INICIAR (sem reservar nem descontar); descontada UMA vez quando os PP completam; se faltar Mana
## na conclusão, a produção espera completa, sem perder PP (City.process_turn). 0 (padrão) = nenhum efeito.
@export var production_mana_cost: float = 0.0

## Voa? O voo V1 (`flies`) OU o perfil de voo tático do V2.
func is_flying() -> bool:
	return flies or movement_profile == MovementProfile.FLYING

func is_v2_caster() -> bool:
	return v2_magic_school != ""

func is_caster() -> bool:
	return is_v2_caster()

## Retinue que ocupa comando (Fase 19). O caminho rápido de V2RetinueSystem.is_commanded lê só isto.
func is_retinue() -> bool:
	return retinue_school != "" and retinue_command_cost > 0

## Contribui capacidade de comando para a própria Escola V2 (Fase 19).
func is_retinue_commander() -> bool:
	return retinue_command_capacity > 0 and v2_magic_school != ""

func has_aura() -> bool:
	return aura_radius > 0 and aura_defense_bonus > 0.0

## Passiva intrínseca "ataque contra alvo ferido" (Fase 7 — Execução do Herói da Lâmina), por dado: quando esta
## unidade ATACA outra unidade cujo HP está em `low_hp_attack_threshold` (fração do HP máximo, 0.5 = 50%) ou menos,
## o Ataque recebe `low_hp_attack_bonus` (0.3 = +30%). Condição por ALVO/ataque, avaliada em
## UnitAbilities.attack_multiplier — vale para o ataque básico e para técnicas de ataque; não afeta cidades,
## estruturas, feitiços nem dano de terceiros. Nenhum id de unidade na lógica de combate.
@export var low_hp_attack_name: String = ""
@export var low_hp_attack_threshold: float = 0.0
@export var low_hp_attack_bonus: float = 0.0

func has_low_hp_attack_bonus() -> bool:
	return low_hp_attack_threshold > 0.0 and low_hp_attack_bonus > 0.0

## Passiva intrínseca "ataque contra alvo de um TIPO" (Fase 8 — Caçada Lendária do Caçador de Lendas), por dado: ao ATACAR uma
## unidade cujo dado tem QUALQUER um dos traços de `trait_attack_target_traits` (`UnitData.traits`, ex.: "legendary"), o Ataque
## recebe `trait_attack_bonus` (0.4 = +40%), uma vez. A LISTA aceita vários traços (futuras categorias) sem refatorar. Mesmo
## princípio da Execução: avaliada por ALVO em UnitAbilities.attack_multiplier (ataque básico e técnicas de ataque, cada vítima
## por si); não vale contra cidade/estrutura/feitiço nem para dano de terceiros; nenhum id de unidade na lógica de combate.
@export var trait_attack_name: String = ""
@export var trait_attack_target_traits: Array[String] = []
@export var trait_attack_bonus: float = 0.0

func has_trait_attack_bonus() -> bool:
	return trait_attack_bonus > 0.0 and not trait_attack_target_traits.is_empty()

func has_trait(trait_id: String) -> bool:
	return trait_id in traits

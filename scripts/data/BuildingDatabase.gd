class_name BuildingDatabase
extends RefCounted

## Prédios de cidade da Aetherlands (todos V2 desde a Fase 25): entram na MESMA fila de produção das
## unidades — City.production_item aceita tanto um kind de UnitDatabase quanto um id daqui (ver
## City.production_cost()/process_turn(), que checam este banco primeiro).
##
## Famílias: prédios de treino das Doutrinas (Salão/Maestria), prédios de Escola de Magia
## (Escola/Estrutura Ritual) e os cinco prédios econômicos repetíveis (Mercado, Fazenda, Oficina,
## Academia, Santuário Arcano — yield derivado por V2EconomyRuntime, nunca somado aqui). Todo prédio é
## liberado pela pesquisa V2 da civilização (City._research_unlocked_for_building -> V2UnlockSystem).
##
## Fase 25: os ~40 prédios V1 (Celeiro, Oficina/Mercado V1, Muralhas, Quartel, Estábulo, Torres...)
## saíram do banco. Um save antigo que ainda os contenha é sanitizado em
## SaveManager._sanitize_legacy_city (as muralhas antes migram para City.fortification_level).

static var _cache: Dictionary = {} # id -> BuildingData, montada uma vez por sessao

static func _build_all() -> Dictionary:
	var buildings: Dictionary = {}
	# AETHERLANDS V2, Fase 3 — Salão dos Guardiões (nó v2_doctrine_guardian_2).
	# Prédio de treino da linha do Guardião: só é construível por quem pesquisou
	# o nó (City._tech_unlocked_for_building -> V2UnlockSystem) e é ELE, via
	# trains_unit, que faz City.can_train("v2_unit_shieldbearer") exigir o Salão
	# na cidade. NÃO depende do Quartel V1 (requires_building fica vazio).
	# BALANCE PLACEHOLDER: custo provisório (entre o Quartel, 20, e o Campo de
	# Tiro, 22). Ocupa um slot de prédio como qualquer outro (sem exceção).
	# Modelo PROVISÓRIO: o mesmo prédio do Quartel (KayKit) — ainda sem arte
	# própria da V2.
	var guardian_hall := BuildingData.new()
	guardian_hall.id = "v2_building_guardian_hall"
	guardian_hall.display_name = "Salão dos Guardiões"
	guardian_hall.production_cost = 22.0
	guardian_hall.trains_unit = "v2_unit_shieldbearer"
	guardian_hall.model_scene_path = "res://assets/models/kaykit/buildings/building_barracks_blue.gltf"
	guardian_hall.gold_upkeep = 1.0
	buildings[guardian_hall.id] = guardian_hall

	# AETHERLANDS V2, Fase 6 — Bastião de Maestria (nó v2_doctrine_guardian_8, `mastery_building`).
	# Única função: HABILITAR o treino do candidato Lendário da linha (trains_unit = Campeão
	# Guardião, pelo mecanismo normal trains_unit -> building_that_trains -> City.can_train). Sem
	# rendimento, defesa, aura, upkeep nem redução de recarga. Exige o Salão dos Guardiões na cidade
	# (requires_building, gate normal de City.can_build) — o Bastião NÃO o substitui — e o nó N8.
	# BALANCE PLACEHOLDER: 55 PP (bem acima do Salão, 22). Modelo PROVISÓRIO: a torre B do KayKit (o
	# pack não tem fortaleza), a mesma da Torre Arcana.
	var guardian_mastery := BuildingData.new()
	guardian_mastery.id = "v2_building_guardian_mastery"
	guardian_mastery.display_name = "Bastião de Maestria"
	guardian_mastery.production_cost = 55.0
	guardian_mastery.trains_unit = "v2_legendary_guardian_champion"
	guardian_mastery.requires_building = "v2_building_guardian_hall"
	guardian_mastery.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf"
	guardian_mastery.gold_upkeep = 2.0
	buildings[guardian_mastery.id] = guardian_mastery

	# AETHERLANDS V2, Fase 7 — Salão de Armas (nó v2_doctrine_warrior_2): prédio de treino da linha do Guerreiro,
	# IRMÃO do Salão dos Guardiões (mesmo mecanismo: gate de pesquisa V2 + trains_unit). Treina o Guerreiro e,
	# depois do N5/N7, a forma mais avançada (V2UnitLine.resolve_trainable_form). Não exige Quartel V1, Salão dos
	# Guardiões nem outra Doutrina. BALANCE PLACEHOLDER: 22 PP, igual ao Salão dos Guardiões (comparação em playtest).
	# Modelo PROVISÓRIO: a ferraria do KayKit (tema de armas), sem arte V2. Sem upkeep.
	var warrior_hall := BuildingData.new()
	warrior_hall.id = "v2_building_warrior_hall"
	warrior_hall.display_name = "Salão de Armas"
	warrior_hall.production_cost = 22.0
	warrior_hall.trains_unit = "v2_unit_warrior"
	warrior_hall.model_scene_path = "res://assets/models/kaykit/buildings/building_blacksmith_blue.gltf"
	warrior_hall.gold_upkeep = 1.0
	buildings[warrior_hall.id] = warrior_hall

	# Fase 7 — Arena dos Campeões (nó v2_doctrine_warrior_8, `mastery_building`): irmã do Bastião de Maestria —
	# única função é HABILITAR o treino do candidato Lendário da linha (trains_unit = Herói da Lâmina). Exige o
	# Salão de Armas na cidade (requires_building) e o N8. BALANCE PLACEHOLDER: 55 PP (mesma escala do Bastião).
	# Modelo PROVISÓRIO: o campo de tiro do KayKit (pátio aberto), sem arte V2.
	var warrior_mastery := BuildingData.new()
	warrior_mastery.id = "v2_building_warrior_mastery"
	warrior_mastery.display_name = "Arena dos Campeões"
	warrior_mastery.production_cost = 55.0
	warrior_mastery.trains_unit = "v2_legendary_blade_hero"
	warrior_mastery.requires_building = "v2_building_warrior_hall"
	warrior_mastery.model_scene_path = "res://assets/models/kaykit/buildings/building_archeryrange_blue.gltf"
	warrior_mastery.gold_upkeep = 2.0
	buildings[warrior_mastery.id] = warrior_mastery

	# AETHERLANDS V2, Fase 8 — Campo dos Patrulheiros (nó v2_doctrine_ranger_2): prédio de treino da linha do Patrulheiro, IRMÃO do Salão dos
	# Guardiões e do Salão de Armas (mesmo mecanismo: gate de pesquisa V2 + trains_unit). Treina o Arqueiro e, depois do N5/N7, a forma mais avançada
	# (V2UnitLine.resolve_trainable_form). Não exige Campo de Tiro/Quartel V1 nem outra Doutrina. BALANCE PLACEHOLDER: 22 PP, igual aos outros Salões.
	# Modelo PROVISÓRIO: o campo de tiro do KayKit (o mesmo do prédio V1 e da Arena dos Campeões). Sem upkeep.
	var ranger_camp := BuildingData.new()
	ranger_camp.id = "v2_building_ranger_camp"
	ranger_camp.display_name = "Campo dos Patrulheiros"
	ranger_camp.production_cost = 22.0
	ranger_camp.trains_unit = "v2_unit_archer"
	ranger_camp.model_scene_path = "res://assets/models/kaykit/buildings/building_archeryrange_blue.gltf"
	ranger_camp.gold_upkeep = 1.0
	buildings[ranger_camp.id] = ranger_camp

	# Fase 8 — Torre dos Patrulheiros (nó v2_doctrine_ranger_8, `mastery_building`): irmã do Bastião e da Arena — única função é HABILITAR o treino do
	# candidato Lendário da linha (trains_unit = Caçador de Lendas). Exige o Campo dos Patrulheiros na cidade (requires_building) e o N8.
	# BALANCE PLACEHOLDER: 55 PP (mesma escala). Modelo PROVISÓRIO: a torre A do KayKit.
	var ranger_mastery := BuildingData.new()
	ranger_mastery.id = "v2_building_ranger_mastery"
	ranger_mastery.display_name = "Torre dos Patrulheiros"
	ranger_mastery.production_cost = 55.0
	ranger_mastery.trains_unit = "v2_legendary_legend_hunter"
	ranger_mastery.requires_building = "v2_building_ranger_camp"
	ranger_mastery.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	ranger_mastery.gold_upkeep = 2.0
	buildings[ranger_mastery.id] = ranger_mastery

	# AETHERLANDS V2, Fase 9 — Estábulo de Guerra (nó v2_doctrine_cavalry_2): prédio de treino da linha da Cavalaria, IRMÃO dos outros Salões (mesmo mecanismo:
	# gate de pesquisa V2 + trains_unit). Treina o Cavaleiro e, depois do N5/N7, a forma mais avançada (V2UnitLine.resolve_trainable_form). NÃO depende do Estábulo
	# V1, do Quartel, do Salão de Armas nem de outra Doutrina. BALANCE PLACEHOLDER: 22 PP. Modelo PROVISÓRIO: o mercado do KayKit (galpão aberto). Sem upkeep.
	var war_stable := BuildingData.new()
	war_stable.id = "v2_building_war_stable"
	war_stable.display_name = "Estábulo de Guerra"
	war_stable.production_cost = 22.0
	war_stable.trains_unit = "v2_unit_cavalier"
	war_stable.model_scene_path = "res://assets/models/kaykit/buildings/building_market_blue.gltf"
	war_stable.gold_upkeep = 1.0
	buildings[war_stable.id] = war_stable

	# Fase 9 — Ordem da Cavalaria (nó v2_doctrine_cavalry_8, `mastery_building`): irmã do Bastião, da Arena e da Torre — única função é HABILITAR o treino do candidato
	# Lendário da linha (trains_unit = Cavaleiro de Grifo). Exige o Estábulo de Guerra na cidade (requires_building) e o N8. BALANCE PLACEHOLDER: 55 PP.
	# Modelo PROVISÓRIO: a torre de catapulta do KayKit.
	var cavalry_mastery := BuildingData.new()
	cavalry_mastery.id = "v2_building_cavalry_mastery"
	cavalry_mastery.display_name = "Ordem da Cavalaria"
	cavalry_mastery.production_cost = 55.0
	cavalry_mastery.trains_unit = "v2_legendary_griffon_rider"
	cavalry_mastery.requires_building = "v2_building_war_stable"
	cavalry_mastery.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_catapult_blue.gltf"
	cavalry_mastery.gold_upkeep = 2.0
	buildings[cavalry_mastery.id] = cavalry_mastery

	# AETHERLANDS V2, Fase 10 — Guilda dos Ladinos (nó v2_doctrine_rogue_2): prédio de treino da linha do Ladino, IRMÃ dos outros Salões (mesmo
	# mecanismo: gate de pesquisa V2 + trains_unit). Treina o Ladino e, depois do N5/N7, a forma mais avançada (V2UnitLine.resolve_trainable_form).
	# NÃO depende de outra Doutrina. BALANCE PLACEHOLDER: 22 PP (mesma escala dos outros Salões). Modelo PROVISÓRIO: o moinho do KayKit (sem prédio
	# temático de "guilda" no pacote gratuito — mesma limitação já documentada em outros Salões). Sem upkeep.
	var rogue_guild := BuildingData.new()
	rogue_guild.id = "v2_building_rogue_guild"
	rogue_guild.display_name = "Guilda dos Ladinos"
	rogue_guild.production_cost = 22.0
	rogue_guild.trains_unit = "v2_unit_rogue"
	rogue_guild.model_scene_path = "res://assets/models/kaykit/buildings/building_windmill_blue.gltf"
	rogue_guild.gold_upkeep = 1.0
	buildings[rogue_guild.id] = rogue_guild

	# Fase 10 — Refúgio das Sombras (nó v2_doctrine_rogue_8, `mastery_building`): irmã do Bastião, da Arena, da Torre e da Ordem — única função é
	# HABILITAR o treino do candidato Lendário da linha (trains_unit = Mestre das Sombras). Exige a Guilda dos Ladinos na cidade (requires_building)
	# e o N8. BALANCE PLACEHOLDER: 55 PP (mesma escala). Modelo PROVISÓRIO: a torre A do KayKit (a mesma da Torre dos Patrulheiros).
	var rogue_mastery := BuildingData.new()
	rogue_mastery.id = "v2_building_rogue_mastery"
	rogue_mastery.display_name = "Refúgio das Sombras"
	rogue_mastery.production_cost = 55.0
	rogue_mastery.trains_unit = "v2_legendary_shadow_master"
	rogue_mastery.requires_building = "v2_building_rogue_guild"
	rogue_mastery.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	rogue_mastery.gold_upkeep = 2.0
	buildings[rogue_mastery.id] = rogue_mastery

	# AETHERLANDS V2, Fase 11 — Arsenal de Cerco (nó v2_doctrine_siege_2): prédio de treino da linha de Cerco, IRMÃO dos
	# outros Salões (mesmo mecanismo: gate de pesquisa V2 + trains_unit). Treina a Catapulta e, depois do N5/N7, a
	# forma mais avançada (V2UnitLine.resolve_trainable_form). NÃO depende de outra Doutrina nem do Arsenal de Cerco
	# V1 (`siege_workshop`, id DIFERENTE — mesmo NOME de exibição; a mesma limitação de nomes repetidos V1/V2 já
	# documentada nas Fases 7-8 pro Espadachim/Arqueiro). BALANCE PLACEHOLDER: 22 PP (mesma escala dos outros Salões).
	# Modelo PROVISÓRIO: a torre de catapulta do KayKit (já reaproveitada pela Ordem da Cavalaria — a mais próxima de
	# "arsenal de Cerco" no pacote gratuito). Sem upkeep.
	var siege_arsenal := BuildingData.new()
	siege_arsenal.id = "v2_building_siege_arsenal"
	siege_arsenal.display_name = "Arsenal de Cerco"
	siege_arsenal.production_cost = 22.0
	siege_arsenal.trains_unit = "v2_unit_catapult"
	siege_arsenal.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_catapult_blue.gltf"
	siege_arsenal.gold_upkeep = 1.0
	buildings[siege_arsenal.id] = siege_arsenal

	# Fase 11 — Grande Arsenal (nó v2_doctrine_siege_8, `mastery_building`): irmão do Bastião, da Arena, da Torre, da
	# Ordem e do Refúgio — única função é HABILITAR o treino do candidato Lendário da linha (trains_unit = Colosso de
	# Cerco). Exige o Arsenal de Cerco na cidade (requires_building) e o N8. NÃO é o mesmo prédio do "Grande Arsenal"
	# V1 (`grand_arsenal`, id DIFERENTE — mesma limitação de nome repetido acima). BALANCE PLACEHOLDER: 55 PP (mesma
	# escala). Modelo PROVISÓRIO: a torre B do KayKit (já reaproveitada pelo Bastião de Maestria).
	var grand_arsenal_v2 := BuildingData.new()
	grand_arsenal_v2.id = "v2_building_grand_arsenal"
	grand_arsenal_v2.display_name = "Grande Arsenal"
	grand_arsenal_v2.production_cost = 55.0
	grand_arsenal_v2.trains_unit = "v2_legendary_siege_colossus"
	grand_arsenal_v2.requires_building = "v2_building_siege_arsenal"
	grand_arsenal_v2.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf"
	grand_arsenal_v2.gold_upkeep = 2.0
	buildings[grand_arsenal_v2.id] = grand_arsenal_v2

	# AETHERLANDS V2, Fase 14 — os cinco prédios econômicos (Economia/Logística/Indústria/Academia/
	# Arcano). Todos CopyLimitMode.CITY_LEVEL (§8 do pedido: Cidade I comporta 1 cópia, II comporta
	# 2, III comporta 3, IV comporta 4 — ver V2CityLevelData.repeatable_building_limit), sem
	# requires_building (cada um é infraestrutura básica independente, §59) e sem trains_unit (não
	# treinam tropa nenhuma). O yield real de cada cópia vem inteiro de V2InfrastructureEconomyData,
	# consultado por V2EconomyRuntime a cada turno/UI, nunca somado aqui (Fase 25: os campos bonus_* e
	# a pipeline de rendimento V1 foram removidos). BALANCE PLACEHOLDER: custos e yields em V2InfrastructureEconomyData.
	var econ_market := BuildingData.new()
	econ_market.id = "v2_building_market"
	econ_market.display_name = "Mercado"
	econ_market.production_cost = V2InfrastructureEconomyData.production_cost_for_branch("economy")
	econ_market.copy_limit_mode = BuildingData.CopyLimitMode.CITY_LEVEL
	# Fase 15 (§26 do pedido): Mercado fica SEM upkeep de propósito — é a rota de recuperação de
	# um Déficit de Ouro, mesmo num império quebrado o jogador precisa conseguir construir um e
	# se recuperar.
	econ_market.gold_upkeep = 0.0
	econ_market.model_scene_path = "res://assets/models/kaykit/buildings/building_market_blue.gltf"
	buildings[econ_market.id] = econ_market

	var econ_farm := BuildingData.new()
	econ_farm.id = "v2_building_farm"
	econ_farm.display_name = "Fazenda"
	econ_farm.production_cost = V2InfrastructureEconomyData.production_cost_for_branch("logistics")
	econ_farm.copy_limit_mode = BuildingData.CopyLimitMode.CITY_LEVEL
	econ_farm.gold_upkeep = 1.0
	econ_farm.model_scene_path = "res://assets/models/kaykit/buildings/building_windmill_blue.gltf"
	buildings[econ_farm.id] = econ_farm

	var econ_workshop := BuildingData.new()
	econ_workshop.id = "v2_building_workshop"
	econ_workshop.display_name = "Oficina"
	econ_workshop.production_cost = V2InfrastructureEconomyData.production_cost_for_branch("industry")
	econ_workshop.copy_limit_mode = BuildingData.CopyLimitMode.CITY_LEVEL
	econ_workshop.gold_upkeep = 1.0
	# Fase 15 (§52 do pedido): a Oficina passa a treinar o Construtor -- nenhum prédio novo,
	# nenhuma segunda fila (o gate de pesquisa do Construtor é UnitData.required_v2_unlock_id,
	# não um trains_unit especial aqui).
	econ_workshop.trains_unit = "v2_unit_builder"
	econ_workshop.model_scene_path = "res://assets/models/kaykit/buildings/building_blacksmith_blue.gltf"
	buildings[econ_workshop.id] = econ_workshop

	# AETHERLANDS V2, Fase 17 — Templo Sagrado (nó v2_magic_sacred_2, `school_building`): estrutura de treinamento da
	# Escola Sagrada. Treina o Clérigo depois do N3 (gate normal trains_unit -> City.can_train). NÃO produz Mana (a Mana
	# é da infraestrutura Arcana). UNIQUE, sem prédio exigido. BALANCE PLACEHOLDER: 24 PP, 1 Ouro/turno. Modelo PROVISÓRIO:
	# a torre A do KayKit (a mesma da Academia/Torre dos Patrulheiros).
	var sacred_temple := BuildingData.new()
	sacred_temple.id = "v2_building_sacred_temple"
	sacred_temple.display_name = "Templo Sagrado"
	sacred_temple.production_cost = 24.0
	sacred_temple.gold_upkeep = 1.0
	sacred_temple.trains_unit = "v2_unit_sacred_cleric"
	sacred_temple.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	buildings[sacred_temple.id] = sacred_temple

	# AETHERLANDS V2, Fase 17 — Catedral Sagrada (nó v2_magic_sacred_8, `ritual_building`): estrutura ritual da Escola.
	# Única função: habilitar a produção do Serafim depois do N9 (trains_unit). Exige o Templo na MESMA cidade (não o
	# substitui). Prédio normal: ocupa slot, fila normal, Déficit bloqueia iniciar (upkeep > 0). BALANCE PLACEHOLDER: 60 PP,
	# 2 Ouro/turno. Modelo PROVISÓRIO: a torre B do KayKit.
	var sacred_ritual := BuildingData.new()
	sacred_ritual.id = "v2_building_sacred_ritual"
	sacred_ritual.display_name = "Catedral Sagrada"
	sacred_ritual.production_cost = 60.0
	sacred_ritual.gold_upkeep = 2.0
	sacred_ritual.requires_building = "v2_building_sacred_temple"
	sacred_ritual.trains_unit = "v2_manifestation_seraph"
	sacred_ritual.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf"
	buildings[sacred_ritual.id] = sacred_ritual

	# AETHERLANDS V2, Fase 18 — estruturas da Escola Infernal. Seguem exatamente o molde mágico
	# genérico: prédio de Escola treina o caster; estrutura ritual exige o primeiro e habilita a
	# Grande Manifestação. Nenhuma produz Mana (a fonte especializada continua sendo o Santuário Arcano).
	var infernal_sanctum := BuildingData.new()
	infernal_sanctum.id = "v2_building_infernal_sanctum"
	infernal_sanctum.display_name = "Santuário Infernal"
	infernal_sanctum.production_cost = 24.0
	infernal_sanctum.gold_upkeep = 1.0
	infernal_sanctum.trains_unit = "v2_unit_infernal_warlock"
	infernal_sanctum.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	buildings[infernal_sanctum.id] = infernal_sanctum

	var infernal_ritual := BuildingData.new()
	infernal_ritual.id = "v2_building_infernal_ritual"
	infernal_ritual.display_name = "Círculo Profano"
	infernal_ritual.production_cost = 60.0
	infernal_ritual.gold_upkeep = 2.0
	infernal_ritual.requires_building = "v2_building_infernal_sanctum"
	infernal_ritual.trains_unit = "v2_manifestation_archdemon"
	infernal_ritual.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf"
	buildings[infernal_ritual.id] = infernal_ritual

	# AETHERLANDS V2, Fase 19 — Ossuário (N2) e Mausoléu Negro (N8) da Necromancia: o MESMO molde dos prédios das
	# outras Escolas (UNIQUE por padrão, slot, fila, Déficit bloqueia iniciar, nenhuma Mana). O Ossuário treina o
	# Necromante — nunca Hostes (essas só nascem por feitiço). BALANCE PLACEHOLDER. Modelos PROVISÓRIOS (torres KayKit).
	var necromancy_ossuary := BuildingData.new()
	necromancy_ossuary.id = "v2_building_necromancy_ossuary"
	necromancy_ossuary.display_name = "Ossuário"
	necromancy_ossuary.production_cost = 24.0
	necromancy_ossuary.gold_upkeep = 1.0
	necromancy_ossuary.trains_unit = "v2_unit_necromancer"
	necromancy_ossuary.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	buildings[necromancy_ossuary.id] = necromancy_ossuary

	var necromancy_ritual := BuildingData.new()
	necromancy_ritual.id = "v2_building_necromancy_ritual"
	necromancy_ritual.display_name = "Mausoléu Negro"
	necromancy_ritual.production_cost = 60.0
	necromancy_ritual.gold_upkeep = 2.0
	necromancy_ritual.requires_building = "v2_building_necromancy_ossuary"
	necromancy_ritual.trains_unit = "v2_manifestation_lich_sovereign"
	necromancy_ritual.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf"
	buildings[necromancy_ritual.id] = necromancy_ritual

	# AETHERLANDS V2, Fase 20 — Círculo Druídico (N2) e Bosque Ancestral (N8): o mesmo molde das outras Escolas (UNIQUE por
	# padrão, slot, fila, Déficit bloqueia iniciar, nenhuma Mana). BALANCE PLACEHOLDER. Modelos PROVISÓRIOS (moinho e torre
	# A do KayKit — os mais "rurais" dos pacotes; não há estrutura natural).
	var druidic_circle := BuildingData.new()
	druidic_circle.id = "v2_building_druidic_circle"
	druidic_circle.display_name = "Círculo Druídico"
	druidic_circle.production_cost = 24.0
	druidic_circle.gold_upkeep = 1.0
	druidic_circle.trains_unit = "v2_unit_druid"
	druidic_circle.model_scene_path = "res://assets/models/kaykit/buildings/building_windmill_blue.gltf"
	buildings[druidic_circle.id] = druidic_circle

	var druidic_ritual := BuildingData.new()
	druidic_ritual.id = "v2_building_druidic_ritual"
	druidic_ritual.display_name = "Bosque Ancestral"
	druidic_ritual.production_cost = 60.0
	druidic_ritual.gold_upkeep = 2.0
	druidic_ritual.requires_building = "v2_building_druidic_circle"
	druidic_ritual.trains_unit = "v2_manifestation_nature_avatar"
	druidic_ritual.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	buildings[druidic_ritual.id] = druidic_ritual

	# AETHERLANDS V2, Fase 21 — Conclave Arcano (N2) e Torre do Véu (N8): prédios normais do
	# mesmo molde mágico. Nenhum produz Mana; o Santuário Arcano da Infraestrutura mantém essa função.
	var arcane_conclave := BuildingData.new()
	arcane_conclave.id = "v2_building_arcane_conclave"
	arcane_conclave.display_name = "Conclave Arcano"
	arcane_conclave.production_cost = 24.0
	arcane_conclave.gold_upkeep = 1.0
	arcane_conclave.trains_unit = "v2_unit_arcanist"
	arcane_conclave.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	buildings[arcane_conclave.id] = arcane_conclave

	var arcane_ritual := BuildingData.new()
	arcane_ritual.id = "v2_building_arcane_ritual"
	arcane_ritual.display_name = "Torre do Véu"
	arcane_ritual.production_cost = 60.0
	arcane_ritual.gold_upkeep = 2.0
	arcane_ritual.requires_building = "v2_building_arcane_conclave"
	arcane_ritual.trains_unit = "v2_manifestation_veil_archon"
	arcane_ritual.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf"
	buildings[arcane_ritual.id] = arcane_ritual

	# AETHERLANDS V2, Fase 22 — Observatório/Nexo do Elementalismo: o mesmo
	# molde mágico UNIQUE, sem renda de Mana e sem sistema de produção paralelo.
	var elemental_observatory := BuildingData.new()
	elemental_observatory.id = "v2_building_elemental_observatory"
	elemental_observatory.display_name = "Observatório Elemental"
	elemental_observatory.production_cost = 24.0
	elemental_observatory.gold_upkeep = 1.0
	elemental_observatory.trains_unit = "v2_unit_elementalist"
	elemental_observatory.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	buildings[elemental_observatory.id] = elemental_observatory

	var elemental_ritual := BuildingData.new()
	elemental_ritual.id = "v2_building_elemental_ritual"
	elemental_ritual.display_name = "Nexo dos Elementos"
	elemental_ritual.production_cost = 60.0
	elemental_ritual.gold_upkeep = 2.0
	elemental_ritual.requires_building = "v2_building_elemental_observatory"
	elemental_ritual.trains_unit = "v2_manifestation_elemental_primordial"
	elemental_ritual.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf"
	buildings[elemental_ritual.id] = elemental_ritual

	var econ_academy := BuildingData.new()
	econ_academy.id = "v2_building_academy"
	econ_academy.display_name = "Academia"
	econ_academy.production_cost = V2InfrastructureEconomyData.production_cost_for_branch("academy")
	econ_academy.copy_limit_mode = BuildingData.CopyLimitMode.CITY_LEVEL
	econ_academy.gold_upkeep = 1.0
	econ_academy.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	buildings[econ_academy.id] = econ_academy

	var econ_arcane_shrine := BuildingData.new()
	econ_arcane_shrine.id = "v2_building_arcane_shrine"
	econ_arcane_shrine.display_name = "Santuário Arcano"
	econ_arcane_shrine.production_cost = V2InfrastructureEconomyData.production_cost_for_branch("arcane")
	econ_arcane_shrine.copy_limit_mode = BuildingData.CopyLimitMode.CITY_LEVEL
	econ_arcane_shrine.gold_upkeep = 1.0
	econ_arcane_shrine.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf"
	buildings[econ_arcane_shrine.id] = econ_arcane_shrine
	return buildings

static func _all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build_all()
	return _cache

static func get_building(id: String) -> BuildingData:
	return _all().get(id, null)

static func all_buildings() -> Array:
	return _all().values()

## Fallback de treino pra kind sem `trains_unit` proprio em NENHUM BuildingData — cada prédio só tem
## UM `trains_unit`, então as evoluções de uma linha de Doutrina treinam no MESMO prédio da forma-base.
const UNIT_TRAINER_FALLBACK: Dictionary = {
	# V2 (Fase 4): a evolução da linha do Guardião treina no MESMO Salão da unidade-base
	"v2_unit_guardian": "v2_building_guardian_hall",
	"v2_unit_sentinel": "v2_building_guardian_hall",
	# Fase 7: a linha do Guerreiro treina no MESMO Salão de Armas (trains_unit dele é só o Guerreiro).
	"v2_unit_swordsman": "v2_building_warrior_hall",
	"v2_unit_weapon_master": "v2_building_warrior_hall",
	# Fase 8: a linha do Patrulheiro treina no MESMO Campo (trains_unit dele é só o Arqueiro).
	"v2_unit_hunter": "v2_building_ranger_camp",
	"v2_unit_elite_marksman": "v2_building_ranger_camp",
	# Fase 9: a linha da Cavalaria treina no MESMO Estábulo de Guerra (trains_unit dele é só o Cavaleiro).
	"v2_unit_shock_cavalier": "v2_building_war_stable",
	"v2_unit_armored_cavalier": "v2_building_war_stable",
	# Fase 10: a linha do Ladino treina na MESMA Guilda dos Ladinos (trains_unit dela é só o Ladino).
	"v2_unit_saboteur": "v2_building_rogue_guild",
	"v2_unit_assassin": "v2_building_rogue_guild",
	# Fase 11: a linha de Cerco treina no MESMO Arsenal de Cerco (trains_unit dele é só a Catapulta).
	"v2_unit_trebuchet": "v2_building_siege_arsenal",
	"v2_unit_bombard": "v2_building_siege_arsenal",
}

## Prédio de treino cujo trains_unit bate com `kind`, ou o fallback acima; null se `kind` não exige
## prédio nenhum (ex.: "settler").
static func building_that_trains(kind: String) -> BuildingData:
	for b in all_buildings():
		if b.trains_unit == kind:
			return b
	if UNIT_TRAINER_FALLBACK.has(kind):
		return get_building(UNIT_TRAINER_FALLBACK[kind])
	return null

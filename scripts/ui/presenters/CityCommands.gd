class_name CityCommands
extends RefCounted

## Caminho ÚNICO das ações de cidade disparadas pela UI (painel novo, resumo de
## produção e o HUD legado ainda existente). Cada função só repete o gate do
## runtime como proteção de clique e chama a mesma API de sempre (City,
## SelectionManager, V2TranscendenceSystem) — nenhuma regra nova.

## Produção de unidade/prédio/projeto. Prédio entra no posicionamento de tile
## (SelectionManager); unidade e projetos vão direto para a fila da cidade.
static func produce(city: City, item_id: String) -> bool:
	if city == null or not is_instance_valid(city) or GameManager.is_turn_processing:
		return false
	if V2CityLevelData.is_city_project(item_id):
		return start_city_upgrade(city, V2CityLevelData.target_level_for_project(item_id))
	if V2FortificationData.is_fortification_project(item_id):
		return start_fortification(city, V2FortificationData.target_level_for_project(item_id))
	if not city.owner_player.has_unlocked(item_id):
		return false
	var building := BuildingDatabase.get_building(item_id)
	if building != null:
		if not city.can_build(item_id):
			return false
		SelectionManager.start_building_placement(city, item_id)
		return true
	if not city.can_train(item_id):
		return false
	city.set_production(item_id)
	if GameManager.hex_grid != null:
		GameManager.hex_grid.refresh_construction_markers()
	return true

static func start_city_upgrade(city: City, target_level: int) -> bool:
	if city == null or not is_instance_valid(city) or V2CityLevelData.next_level(city.city_level) != target_level:
		return false
	if not city.can_start_city_upgrade():
		return false
	city.set_production(V2CityLevelData.project_id_for_level(target_level))
	if GameManager.hex_grid != null:
		GameManager.hex_grid.refresh_construction_markers()
	return true

static func start_fortification(city: City, target_level: int) -> bool:
	if city == null or not is_instance_valid(city) or V2FortificationData.next_level(city.fortification_level) != target_level:
		return false
	if not city.can_start_fortification():
		return false
	city.set_production(V2FortificationData.project_id(target_level))
	return true

static func start_city_attack(city: City) -> void:
	if city == null or not is_instance_valid(city):
		return
	SelectionManager.start_city_attack_targeting(city)

static func start_annexation(city: City) -> void:
	if city == null or not is_instance_valid(city):
		return
	SelectionManager.start_city_annexation(city)

static func start_ritual(player: PlayerData, city: City) -> bool:
	return V2TranscendenceSystem.start_ritual(player, city)

static func cancel_ritual(player: PlayerData) -> bool:
	return V2TranscendenceSystem.cancel_ritual(player)

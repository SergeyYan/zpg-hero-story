#SaveSystem.gd

extends Node
class_name SaveSystem

var SAVE_PATH: String = ""
var SAVE_DIR: String = "ZPG Hero story"

func _init():
	# Определяем путь к папке документов пользователя
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	SAVE_PATH = documents_path.path_join(SAVE_DIR).path_join("savegame.save")
	
	# Создаем папку если она не существует
	_create_save_directory()

func _create_save_directory():
	var dir = DirAccess.open(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS))
	if dir:
		if !dir.dir_exists(SAVE_DIR):
			var error = dir.make_dir(SAVE_DIR)
			

func save_game():
	var save_data = {
		"player_stats": _get_player_stats_data(),
		"player_position": _get_player_position(),
		"achievements": _get_achievements_data(),
		"game_time": Time.get_ticks_msec(),
		"version": "1.0"
	}
	# Создаем папку на всякий случай (если вдруг удалили)
	_create_save_directory()
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json = JSON.stringify(save_data)
		file.store_string(json)
		file.close()


func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = file.get_as_text()
		file.close()
		
		var json_object = JSON.new()
		var error = json_object.parse(json)
		if error == OK:
			var save_data = json_object.data
			_apply_save_data(save_data)
			return true
		else:
			push_error("Ошибка парсинга сохранения")
	return false

func _get_player_stats_data() -> Dictionary:
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats:
		return {
			"level": player_stats.level,
			"current_exp": player_stats.current_exp,
			"exp_to_level": player_stats.exp_to_level,
			"current_health": player_stats.current_health,
			"available_points": player_stats.available_points,
			"strength": player_stats.stats_system.strength,
			"fortitude": player_stats.stats_system.fortitude,
			"endurance": player_stats.stats_system.endurance,
			"luck": player_stats.stats_system.luck,
			"monsters_killed": player_stats.monsters_killed,
			"active_statuses": player_stats._get_active_statuses_data()
		}
	return {}

func _get_achievements_data() -> Dictionary:
	var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
	if achievement_manager:
		var achievements_data = {}
		for achievement_id in achievement_manager.achievements:
			achievements_data[achievement_id] = achievement_manager.achievements[achievement_id].unlocked
		return achievements_data
	return {}

func _get_player_position() -> Dictionary:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return {
			"x": player.global_position.x,
			"y": player.global_position.y
		}
	return {"x": 0, "y": 0}

func _apply_save_data(save_data: Dictionary):
	# Загружаем статистику игрока
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats and save_data.has("player_stats"):
		var stats = save_data["player_stats"]
		player_stats.level = stats.get("level", 1)
		player_stats.current_exp = stats.get("current_exp", 0)
		player_stats.exp_to_level = stats.get("exp_to_level", 100)
		player_stats.current_health = stats.get("current_health", 100)
		player_stats.available_points = stats.get("available_points", 0)
		player_stats.stats_system.strength = stats.get("strength", 1)
		player_stats.stats_system.fortitude = stats.get("fortitude", 1)
		player_stats.stats_system.endurance = stats.get("endurance", 1)
		player_stats.stats_system.luck = stats.get("luck", 1)
		player_stats.monsters_killed = stats.get("monsters_killed", 0)
		
		# ЗАГРУЗКА АКТИВНЫХ СТАТУСОВ
		if stats.has("active_statuses"):
			player_stats._load_active_statuses(stats["active_statuses"])
			
		# Только обновляем здоровье, НЕ вызываем level_up
		player_stats.health_changed.emit(player_stats.current_health)
		
	# Загружаем достижения
	if save_data.has("achievements"):
		_apply_achievements_data(save_data["achievements"])
		
	# Загружаем позицию игрока
	var player = get_tree().get_first_node_in_group("player")
	if player and save_data.has("player_position"):
		var pos = save_data["player_position"]
		player.global_position = Vector2(pos.get("x", 0), pos.get("y", 0))

func _apply_achievements_data(achievements_data: Dictionary):
	var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
	if achievement_manager:
		for achievement_id in achievements_data:
			if achievement_id in achievement_manager.achievements:
				achievement_manager.achievements[achievement_id].unlocked = achievements_data[achievement_id]
		print("Достижения загружены")


func clear_save():
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join(SAVE_DIR))
		if dir:
			var error = dir.remove("savegame.save")
			

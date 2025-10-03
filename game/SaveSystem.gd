#SaveSystem.gd
extends Node
class_name SaveSystem

var SAVE_PATH: String = ""
var SAVE_DIR: String = "ZPG Hero story"

func _init():
	# Определяем путь для сохранения в зависимости от платформы
	_setup_save_paths()
	
	# Создаем папку если она не существует
	_create_save_directory()

func _setup_save_paths():
	match OS.get_name():
		"Android":
			# На Android используем user:// директорию (внутреннее хранилище приложения)
			SAVE_PATH = "user://savegame.save"
		"iOS":
			# На iOS также используем user://
			SAVE_PATH = "user://savegame.save"
		"HTML5":
			# В браузере используем локальное хранилище
			SAVE_PATH = "user://savegame.save"
		_:
			# На десктопных платформах (Windows, Linux, macOS) используем Documents
			var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			SAVE_PATH = documents_path.path_join(SAVE_DIR).path_join("savegame.save")

func _create_save_directory():
	match OS.get_name():
		"Android", "iOS", "HTML5":
			# На мобильных платформах и в браузере папка создается автоматически
			pass
		_:
			# На десктопах создаем папку вручную
			var dir = DirAccess.open(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS))
			if dir:
				if !dir.dir_exists(SAVE_DIR):
					var error = dir.make_dir(SAVE_DIR)
					if error != OK:
						push_error("Не удалось создать папку для сохранений: " + str(error))

func save_game():
	var save_data = {
		"player_stats": _get_player_stats_data(),
		"player_position": _get_player_position(),
		"achievements": _get_achievements_data(),
		"game_time": Time.get_ticks_msec(),
		"version": "1.0",
		"platform": OS.get_name()  # Добавляем информацию о платформе для отладки
	}
	
	# Создаем папку на десктопах на всякий случай
	if OS.get_name() not in ["Android", "iOS", "HTML5"]:
		_create_save_directory()
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json = JSON.stringify(save_data)
		file.store_string(json)
		file.close()
		print("Игра сохранена: " + SAVE_PATH)
	else:
		push_error("Ошибка сохранения игры: " + SAVE_PATH)
		# На Android попробуем альтернативный путь если основной не работает
		if OS.get_name() == "Android":
			_try_alternative_android_save()

func _try_alternative_android_save():
	# Альтернативный путь для Android если основной не работает
	var alt_path = "user://zpg_savegame.save"
	var file = FileAccess.open(alt_path, FileAccess.WRITE)
	if file:
		var save_data = {
			"player_stats": _get_player_stats_data(),
			"player_position": _get_player_position(),
			"achievements": _get_achievements_data(),
			"game_time": Time.get_ticks_msec(),
			"version": "1.0",
			"platform": OS.get_name()
		}
		var json = JSON.stringify(save_data)
		file.store_string(json)
		file.close()
		print("Игра сохранена в альтернативный путь: " + alt_path)
		SAVE_PATH = alt_path  # Обновляем путь для будущих операций

func load_game():
	# Сначала пробуем основной путь
	if FileAccess.file_exists(SAVE_PATH):
		return _load_from_path(SAVE_PATH)
	
	# Если на Android и основной путь не найден, пробуем альтернативный
	if OS.get_name() == "Android":
		var alt_path = "user://zpg_savegame.save"
		if FileAccess.file_exists(alt_path):
			SAVE_PATH = alt_path
			return _load_from_path(alt_path)
	
	print("Файл сохранения не найден: " + SAVE_PATH)
	return false

func _load_from_path(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = file.get_as_text()
		file.close()
		
		var json_object = JSON.new()
		var error = json_object.parse(json)
		if error == OK:
			var save_data = json_object.data
			_apply_save_data(save_data)
			print("Игра загружена: " + path)
			return true
		else:
			push_error("Ошибка парсинга сохранения: " + path)
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
		var dir = DirAccess.open(SAVE_PATH.get_base_dir())
		if dir:
			var error = dir.remove(SAVE_PATH.get_file())
			if error == OK:
				print("Сохранение удалено: " + SAVE_PATH)
			else:
				push_error("Ошибка удаления сохранения: " + str(error))
	
	# Также удаляем альтернативный путь на Android
	if OS.get_name() == "Android":
		var alt_path = "user://zpg_savegame.save"
		if FileAccess.file_exists(alt_path):
			var dir = DirAccess.open(alt_path.get_base_dir())
			if dir:
				dir.remove(alt_path.get_file())

# Функция для отладки - показывает информацию о путях сохранения
func debug_save_info():
	print("=== Save System Debug Info ===")
	print("Platform: " + OS.get_name())
	print("Save Path: " + SAVE_PATH)
	print("User Data Dir: " + OS.get_user_data_dir())
	print("Documents Dir: " + OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS))
	print("Save File Exists: " + str(FileAccess.file_exists(SAVE_PATH)))
	print("==============================")

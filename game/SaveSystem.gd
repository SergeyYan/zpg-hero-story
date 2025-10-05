#SaveSystem.gd
extends Node
class_name SaveSystem

var SAVE_PATH: String = ""
var SAVE_FILENAME: String = "zpg_savegame.save"
var SAVE_DIR: String = "ZPG Hero Story"
var has_valid_save: bool = false

# Сигнал для уведомления об успешном сохранении
signal save_completed

func _init():
	# Определяем путь для сохранения в зависимости от платформы
	_setup_save_paths()
	# Создаем папку если она не существует
	_create_save_directory()
	# Проверяем наличие сохранения при инициализации
	_check_save_exists()

func _setup_save_paths():
	match OS.get_name():
		"Windows":
			# На Windows используем папку Documents
			var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			SAVE_PATH = documents_path.path_join(SAVE_DIR).path_join(SAVE_FILENAME)
			print("Windows save path: " + SAVE_PATH)
		"macOS":
			# На macOS используем папку Documents
			var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			SAVE_PATH = documents_path.path_join(SAVE_DIR).path_join(SAVE_FILENAME)
		"X11":  # ← Linux использует X11
			# На Linux используем домашнюю директорию в .local/share
			var home_path = OS.get_environment("HOME")
			if home_path.is_empty():
				home_path = "user://"
			SAVE_PATH = home_path.path_join(".local/share/" + SAVE_DIR.to_lower().replace(" ", "_")).path_join(SAVE_FILENAME)
		"Android":
			# На Android используем user:// директорию
			SAVE_PATH = "user://" + SAVE_FILENAME
			print("Android save path: " + SAVE_PATH)
		"iOS":
			SAVE_PATH = "user://" + SAVE_FILENAME
		"HTML5":
			SAVE_PATH = "user://" + SAVE_FILENAME
		_:
			# Для неизвестных платформ используем user://
			SAVE_PATH = "user://" + SAVE_FILENAME
			print("Unknown platform, using user://: " + OS.get_name())

func _create_save_directory():
	match OS.get_name():
		"Windows", "macOS":
			# Для Windows и macOS создаем папку вручную
			var save_dir = SAVE_PATH.get_base_dir()
			var dir = DirAccess.open(save_dir.get_base_dir())  # Открываем родительскую директорию
			if dir:
				var folder_name = save_dir.get_file()
				if !dir.dir_exists(folder_name):
					var error = dir.make_dir(folder_name)
					if error == OK:
						print("Создана папка для сохранений: " + save_dir)
					else:
						push_error("Не удалось создать папку для сохранений: " + str(error))
				else:
					print("Папка для сохранений уже существует: " + save_dir)
		"X11":  # Linux
			# Для Linux создаем папку в ~/.local/share
			var save_dir = SAVE_PATH.get_base_dir()
			var dir = DirAccess.open(save_dir.get_base_dir())
			if dir:
				var folder_name = save_dir.get_file()
				if !dir.dir_exists(folder_name):
					var error = dir.make_dir(folder_name)
					if error == OK:
						print("Создана папка для сохранений: " + save_dir)
					else:
						push_error("Не удалось создать папку для сохранений: " + str(error))
				else:
					print("Папка для сохранений уже существует: " + save_dir)
		_:
			# Для мобильных платформ папка создается автоматически
			pass

func _check_save_exists():
	# Проверяем наличие сохранения и обновляем флаг
	has_valid_save = FileAccess.file_exists(SAVE_PATH)
	print("Save exists: " + str(has_valid_save) + " at path: " + SAVE_PATH)

func save_game():
	var save_data = {
		"player_stats": _get_player_stats_data(),
		"player_position": _get_player_position(),
		"achievements": _get_achievements_data(),
		"game_time": Time.get_ticks_msec(),
		"version": "1.0",
		"platform": OS.get_name(),
		"save_timestamp": Time.get_unix_time_from_system(),
		"save_path": SAVE_PATH  # ← Добавляем путь для отладки
	}
	
	# Для отладки
	debug_save_info()
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json = JSON.stringify(save_data, "\t")  # ← Красивый формат с отступами
		var bytes_written = file.store_string(json)
		file.close()
		
		print("✅ Игра сохранена: " + SAVE_PATH)
		print("📊 Записано байт: " + str(bytes_written))
		
		# Обновляем флаг наличия сохранения
		has_valid_save = true
		
		# Сигнализируем об успешном сохранении
		save_completed.emit()  # ← ПРАВИЛЬНЫЙ ВЫЗОВ СИГНАЛА
		
		# Дополнительная проверка для Windows
		if OS.get_name() == "Windows":
			_verify_windows_save()
	else:
		push_error("❌ Ошибка сохранения игры: " + SAVE_PATH)
		# Пробуем альтернативный путь
		_try_alternative_save()

func _verify_windows_save():
	# Дополнительная проверка для Windows
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			print("✅ Файл подтвержден, размер: " + str(content.length()) + " символов")
			
			# Показываем полный путь для удобства
			var absolute_path = ProjectSettings.globalize_path(SAVE_PATH)
			print("📍 Полный путь к файлу: " + absolute_path)
	else:
		print("❌ Файл не найден после сохранения!")

func _try_alternative_save():
	# Альтернативные пути для разных платформ
	var alt_paths = []
	
	match OS.get_name():
		"Windows", "macOS", "X11":
			# Для десктопов пробуем user:// как запасной вариант
			alt_paths.append("user://" + SAVE_FILENAME)
			alt_paths.append("user://backup_" + SAVE_FILENAME)
		_:
			# Для мобильных пробуем backup
			alt_paths.append("user://backup_" + SAVE_FILENAME)
	
	for alt_path in alt_paths:
		var file = FileAccess.open(alt_path, FileAccess.WRITE)
		if file:
			var save_data = {
				"player_stats": _get_player_stats_data(),
				"player_position": _get_player_position(),
				"achievements": _get_achievements_data(),
				"game_time": Time.get_ticks_msec(),
				"version": "1.0",
				"platform": OS.get_name(),
				"is_backup": true,
				"original_path": SAVE_PATH
			}
			var json = JSON.stringify(save_data, "\t")
			file.store_string(json)
			file.close()
			print("🔄 Игра сохранена в альтернативный путь: " + alt_path)
			has_valid_save = true
			break

func load_game() -> bool:
	debug_save_info()
	
	# Сначала пробуем основной путь
	if FileAccess.file_exists(SAVE_PATH):
		print("Найден основной файл сохранения")
		var success = _load_from_path(SAVE_PATH)
		if success:
			has_valid_save = true
		return success
	
	# Пробуем альтернативные пути
	var alt_paths = [
		"user://backup_zpg_savegame.save",
		"user://zpg_savegame.save",
		"user://savegame.save"
	]
	
	for alt_path in alt_paths:
		if FileAccess.file_exists(alt_path):
			print("Найден альтернативный файл сохранения: " + alt_path)
			SAVE_PATH = alt_path
			var success = _load_from_path(alt_path)
			if success:
				has_valid_save = true
			return success
	
	print("Файл сохранения не найден: " + SAVE_PATH)
	has_valid_save = false
	return false

func can_load_game() -> bool:
	# Проверяем можно ли загрузить игру
	return has_valid_save

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

# Остальные методы без изменений...
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
			"agility": player_stats.stats_system.agility,
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
		player_stats.stats_system.agility = stats.get("agility", 1)
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

func debug_save_info():
	print("=== Save System Debug Info ===")
	print("Platform: " + OS.get_name())
	print("Save Path: " + SAVE_PATH)
	print("User Data Dir: " + OS.get_user_data_dir())
	
	# Показываем абсолютный путь для Windows
	if OS.get_name() == "Windows":
		var absolute_path = ProjectSettings.globalize_path(SAVE_PATH)
		print("Absolute Save Path: " + absolute_path)
	
	print("Save File Exists: " + str(FileAccess.file_exists(SAVE_PATH)))
	print("Has Valid Save: " + str(has_valid_save))
	
	# Показываем файлы в соответствующих директориях
	var debug_dirs = []
	match OS.get_name():
		"Windows", "macOS":
			var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			debug_dirs.append(documents_path)
		"X11":  # Linux
			var home_path = OS.get_environment("HOME")
			if not home_path.is_empty():
				debug_dirs.append(home_path)
		_:
			debug_dirs.append(OS.get_user_data_dir())
	
	for debug_dir in debug_dirs:
		var dir = DirAccess.open(debug_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			var files = []
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".save"):
					files.append(file_name)
				file_name = dir.get_next()
			if files.size() > 0:
				print("Save files in " + debug_dir + ": " + str(files))
	print("==============================")

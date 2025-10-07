extends Node
class_name SaveSystem

var SAVE_PATH: String = ""
var SAVE_FILENAME: String = "zpg_savegame.save"
var SAVE_DIR: String = "ZPG Hero Story"
var has_valid_save: bool = false

signal save_completed

func _init():
	_setup_save_paths()
	_create_save_directory()
	_check_save_exists()
	_debug_android_storage()

func _setup_save_paths():
	match OS.get_name():
		"Windows":
			var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			SAVE_PATH = documents_path.path_join(SAVE_DIR).path_join(SAVE_FILENAME)
			print("Windows save path: " + SAVE_PATH)
		"macOS":
			var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			SAVE_PATH = documents_path.path_join(SAVE_DIR).path_join(SAVE_FILENAME)
		"X11":
			var home_path = OS.get_environment("HOME")
			if home_path.is_empty():
				home_path = "user://"
			SAVE_PATH = home_path.path_join(".local/share/" + SAVE_DIR.to_lower().replace(" ", "_")).path_join(SAVE_FILENAME)
		"Android":
			var user_data_dir = OS.get_user_data_dir()
			SAVE_PATH = user_data_dir.path_join(SAVE_FILENAME)
			print("🎯 Android FULL path: " + SAVE_PATH)
			print("📍 User data dir: " + user_data_dir)
		"iOS", "HTML5", "_":
			SAVE_PATH = "user://" + SAVE_FILENAME
			print("Using user:// path: " + SAVE_PATH)

func _create_save_directory():
	match OS.get_name():
		"Windows", "macOS":
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
		"X11":
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
		"Android":
			var save_dir = SAVE_PATH.get_base_dir()
			print("🔧 Android save directory: " + save_dir)
			
			var dir = DirAccess.open("user://")
			if dir:
				print("✅ user:// directory accessible")
			else:
				print("❌ Cannot open user:// directory")
		_:
			pass

func _check_save_exists():
	has_valid_save = FileAccess.file_exists(SAVE_PATH)
	print("Save exists: " + str(has_valid_save) + " at path: " + SAVE_PATH)

func save_game():
	print("💾 Starting save process...")
	
	# ДОБАВЛЕНО: Вызов диагностики перед сохранением
	_pre_save_diagnostic()
	
	var save_data = {
		"player_stats": _get_player_stats_data(),
		"player_position": _get_player_position(),
		"achievements": _get_achievements_data(),
		"game_time": Time.get_ticks_msec(),
		"version": "1.0",
		"platform": OS.get_name(),
		"save_timestamp": Time.get_unix_time_from_system(),
		"save_path": SAVE_PATH
	}
	
	debug_save_info()
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json = JSON.stringify(save_data, "\t")
		var bytes_written = file.store_string(json)
		file.close()
		
		print("✅ File write completed, bytes: " + str(bytes_written))
		_post_save_verification()
		
		# ДОБАВЛЕНО: Проверка для Windows
		if OS.get_name() == "Windows":
			_verify_windows_save()
	else:
		var error = FileAccess.get_open_error()
		print("❌ FileAccess.open FAILED with error: " + str(error))
		_try_alternative_save()

func _debug_android_storage():
	if OS.get_name() == "Android":
		print("=== ANDROID STORAGE DEBUG ===")
		print("📱 Device: " + OS.get_model_name())
		print("🔧 Android: " + OS.get_version())
		print("💾 User data dir: " + OS.get_user_data_dir())
		print("💾 Data dir: " + OS.get_data_dir())
		print("💾 Cache dir: " + OS.get_cache_dir())
		print("🎯 Save path: " + SAVE_PATH)
		
		var test_path = "user://android_test.tmp"
		print("🧪 Testing write to: " + test_path)
		
		var file = FileAccess.open(test_path, FileAccess.WRITE)
		if file:
			file.store_string("Android user:// test")
			file.close()
			
			if FileAccess.file_exists(test_path):
				print("✅ user:// WRITE TEST PASSED")
				var read_file = FileAccess.open(test_path, FileAccess.READ)
				if read_file:
					var content = read_file.get_as_text()
					read_file.close()
					print("✅ user:// READ TEST PASSED, content: " + content)
				DirAccess.remove_absolute(test_path)
			else:
				print("❌ user:// WRITE TEST FAILED - file not created")
		else:
			print("❌ user:// WRITE TEST FAILED - cannot open file")
		
		var target_test_path = SAVE_PATH.get_base_dir().path_join("target_test.tmp")
		print("🧪 Testing write to target: " + target_test_path)
		
		var target_file = FileAccess.open(target_test_path, FileAccess.WRITE)
		if target_file:
			target_file.store_string("Android target test")
			target_file.close()
			
			if FileAccess.file_exists(target_test_path):
				print("✅ TARGET WRITE TEST PASSED")
				DirAccess.remove_absolute(target_test_path)
			else:
				print("❌ TARGET WRITE TEST FAILED")
		else:
			print("❌ TARGET WRITE TEST FAILED")
		
		print("==============================")

func _verify_windows_save():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			print("✅ Файл подтвержден, размер: " + str(content.length()) + " символов")
			
			var absolute_path = ProjectSettings.globalize_path(SAVE_PATH)
			print("📍 Полный путь к файлу: " + absolute_path)
	else:
		print("❌ Файл не найден после сохранения!")

func _pre_save_diagnostic():
	print("=== PRE-SAVE DIAGNOSTIC ===")
	print("📁 Target: " + SAVE_PATH)
	
	var dir_path = SAVE_PATH.get_base_dir()
	var dir = DirAccess.open(dir_path)
	if dir:
		print("✅ Directory accessible: " + dir_path)
	else:
		print("❌ Directory NOT accessible: " + dir_path)
	print("===========================")

func _post_save_verification():
	print("=== POST-SAVE VERIFICATION ===")
	
	if FileAccess.file_exists(SAVE_PATH):
		print("✅ Save file EXISTS: " + SAVE_PATH)
		
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			print("✅ Save file READABLE, size: " + str(content.length()) + " chars")
			
			if content.length() > 50:
				print("✅ Save file CONTENT VALID")
				has_valid_save = true
				save_completed.emit()
			else:
				print("❌ Save file TOO SMALL")
		else:
			print("❌ Save file NOT READABLE")
	else:
		print("❌ Save file DOES NOT EXIST")
	
	print("=============================")

func _try_alternative_save():
	print("🔄 Trying alternative save paths...")
	
	var alt_paths = [
		"user://" + SAVE_FILENAME,
		"user://backup_" + SAVE_FILENAME
	]
	
	for alt_path in alt_paths:
		print("🔄 Trying: " + alt_path)
		var file = FileAccess.open(alt_path, FileAccess.WRITE)
		if file:
			var save_data = {
				"player_stats": _get_player_stats_data(),
				"player_position": _get_player_position(),
				"achievements": _get_achievements_data(),
				"game_time": Time.get_ticks_msec(),
				"version": "1.0",
				"platform": OS.get_name(),
				"is_backup": true
			}
			var json = JSON.stringify(save_data, "\t")
			file.store_string(json)
			file.close()
			print("✅ Saved to backup: " + alt_path)
			has_valid_save = true
			break

func load_game() -> bool:
	debug_save_info()
	
	if FileAccess.file_exists(SAVE_PATH):
		print("✅ Save file found")
		var success = _load_from_path(SAVE_PATH)
		if success:
			has_valid_save = true
		return success
	
	print("❌ Save file not found, checking alternatives...")
	
	var alt_paths = [
		"user://" + SAVE_FILENAME,
		"user://backup_" + SAVE_FILENAME
	]
	
	for alt_path in alt_paths:
		if FileAccess.file_exists(alt_path):
			print("✅ Found alternative: " + alt_path)
			var success = _load_from_path(alt_path)
			if success:
				has_valid_save = true
			return success
	
	has_valid_save = false
	return false

func can_load_game() -> bool:
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
		
		if stats.has("active_statuses"):
			player_stats._load_active_statuses(stats["active_statuses"])
			
		player_stats.health_changed.emit(player_stats.current_health)
		
	if save_data.has("achievements"):
		_apply_achievements_data(save_data["achievements"])
		
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
	
	if OS.get_name() == "Windows":
		var absolute_path = ProjectSettings.globalize_path(SAVE_PATH)
		print("Absolute Save Path: " + absolute_path)
	
	print("Save File Exists: " + str(FileAccess.file_exists(SAVE_PATH)))
	print("Has Valid Save: " + str(has_valid_save))
	
	var debug_dirs = []
	match OS.get_name():
		"Windows", "macOS":
			var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			debug_dirs.append(documents_path)
		"X11":
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

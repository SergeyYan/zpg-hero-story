#GameOverMenu.gd
extends CanvasLayer

@onready var restart_button: Button = $Panel/RestartButton
@onready var load_button: Button = $Panel/LoadButton  # ← ДОБАВЛЯЕМ КНОПКУ ЗАГРУЗКИ
@onready var quit_button: Button = $Panel/QuitButton

var save_system: SaveSystem  # ← ДОБАВЛЯЕМ СИСТЕМУ СОХРАНЕНИЙ

func _ready():
	hide()
	
	# Создаем систему сохранений
	save_system = SaveSystem.new()
	add_child(save_system)
	
	# Подключаем кнопки СРАЗУ
	if restart_button:
		if restart_button.pressed.is_connected(_on_restart_button_pressed):
			restart_button.pressed.disconnect(_on_restart_button_pressed)
		# Подключаем заново
		restart_button.pressed.connect(_on_restart_button_pressed)
		
	if load_button:  # ← ПОДКЛЮЧАЕМ КНОПКУ ЗАГРУЗКИ
		if load_button.pressed.is_connected(_on_load_button_pressed):
			load_button.pressed.disconnect(_on_load_button_pressed)
		# Подключаем заново
		load_button.pressed.connect(_on_load_button_pressed)
		
	if quit_button:
		if quit_button.pressed.is_connected(_on_quit_button_pressed):
			quit_button.pressed.disconnect(_on_quit_button_pressed)
		# Подключаем заново
		quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Проверяем наличие сохранений
	_check_save_file()
	
	# Подключаемся к сигналу смерти игрока
	await get_tree().process_frame
	_connect_to_player_stats()

func _check_save_file():
	print("=== GAME OVER MENU SAVE CHECK ===")
	
	# Используем SaveSystem для проверки
	if save_system:
		print("SaveSystem found in game over menu")
		print("Can load game: ", save_system.can_load_game())
		print("Has valid save: ", save_system.has_valid_save)
		print("Save path: ", save_system.SAVE_PATH)
		print("File exists: ", FileAccess.file_exists(save_system.SAVE_PATH))
		
		# ВКЛЮЧАЕМ/ВЫКЛЮЧАЕМ кнопку загрузки на основе SaveSystem
		if load_button:
			if save_system.can_load_game():
				load_button.disabled = false
				print("✅ Load button ENABLED in game over menu")
			else:
				load_button.disabled = true
				print("❌ Load button DISABLED in game over menu")
	else:
		print("❌ SaveSystem NOT found in game over menu!")
		if load_button:
			load_button.disabled = true
	
	print("================================")


func _connect_to_player_stats():
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats:
		if player_stats.player_died.is_connected(show_game_over):
			player_stats.player_died.disconnect(show_game_over)
		# Подключаем заново
		player_stats.player_died.connect(show_game_over)


func show_game_over():
	# ← РАЗБЛОКИРОВКА ДОСТИЖЕНИЯ ПРИ СМЕРТИ
	var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
	if achievement_manager:
		achievement_manager.unlock_achievement("first_death")
	# УБИРАЕМ ВСЮ ПАУЗУ - она мешает работе кнопок!
	get_tree().paused = false  
	show()
	# ВКЛЮЧАЕМ обработку ввода UI
	set_process_input(true)
	set_process_unhandled_input(true)
	# ПЕРЕПРОВЕРЯЕМ СОХРАНЕНИЯ ПРИ ПОКАЗЕ МЕНЮ
	_check_save_file()
	# Фокусируемся на кнопке рестарта
	if restart_button:
		restart_button.grab_focus()
	# Останавливаем только игровые процессы, но не UI
	_stop_game_processes()

func _stop_game_processes():
	# Останавливаем всех монстров
	for monster in get_tree().get_nodes_in_group("monsters"):
		monster.set_physics_process(false)
		monster.set_process(false)
	
	# Останавливаем спавнер монстров
	var spawner = get_tree().get_first_node_in_group("monster_spawner")
	if spawner:
		spawner.set_process(false)
	
	# Останавливаем генератор карты
	var map_generator = get_tree().get_first_node_in_group("map_generator")
	if map_generator:
		map_generator.set_process(false)
	
	# Останавливаем игрока
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		player.set_process(false)

func _input(event):
	# Обрабатываем ввод только когда меню видно
	if visible and event is InputEventKey:
		if event.is_action_pressed("ui_accept"):
			if restart_button and restart_button.has_focus():
				_on_restart_button_pressed()
				get_viewport().set_input_as_handled()
			elif load_button and load_button.has_focus():  # ← ОБРАБОТКА ЗАГРУЗКИ
				_on_load_button_pressed()
				get_viewport().set_input_as_handled()

func _on_restart_button_pressed():
	# Перезагружаем сцену (новая игра)
	GameState.is_loading = false
	get_tree().call_group("new_game_listener", "reset_all_achievements")
	get_tree().reload_current_scene()

# ← НОВАЯ ФУНКЦИЯ ДЛЯ КНОПКИ ЗАГРУЗКИ
func _on_load_button_pressed():
	print("=== LOAD FROM GAME OVER ===")
	
	# Устанавливаем флаг загрузки и перезагружаем сцену
	if save_system and save_system.can_load_game():
		print("✅ Loading game from game over menu...")
		GameState.is_loading = true
		get_tree().reload_current_scene()
	else:
		print("❌ Cannot load - no valid save found")

func _on_quit_button_pressed():
	get_tree().quit()

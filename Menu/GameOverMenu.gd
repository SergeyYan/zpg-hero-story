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
		print("RestartButton найден, подключаем...")
		# Отключаем старые соединения если есть
		if restart_button.pressed.is_connected(_on_restart_button_pressed):
			restart_button.pressed.disconnect(_on_restart_button_pressed)
		# Подключаем заново
		restart_button.pressed.connect(_on_restart_button_pressed)
		
	if load_button:  # ← ПОДКЛЮЧАЕМ КНОПКУ ЗАГРУЗКИ
		print("LoadButton найден, подключаем...")
		if load_button.pressed.is_connected(_on_load_button_pressed):
			load_button.pressed.disconnect(_on_load_button_pressed)
		load_button.pressed.connect(_on_load_button_pressed)
		
	if quit_button:
		print("QuitButton найден, подключаем...")
		if quit_button.pressed.is_connected(_on_quit_button_pressed):
			quit_button.pressed.disconnect(_on_quit_button_pressed)
		quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Проверяем наличие сохранений
	_check_save_file()
	
	# Подключаемся к сигналу смерти игрока
	await get_tree().process_frame
	_connect_to_player_stats()

func _check_save_file():
	# Проверяем есть ли файл сохранения
	var save_path = "user://savegame.save"
	if FileAccess.file_exists(save_path):
		if load_button:
			load_button.disabled = false
		print("Сохранение найдено, кнопка загрузки активна")
	else:
		if load_button:
			load_button.disabled = true
		print("Сохранение не найдено, кнопка загрузки отключена")



func _connect_to_player_stats():
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats:
		print("GameOverMenu: подключен к PlayerStats")
		if player_stats.player_died.is_connected(show_game_over):
			player_stats.player_died.disconnect(show_game_over)
		player_stats.player_died.connect(show_game_over)
	else:
		print("GameOverMenu: PlayerStats не найден")

func show_game_over():
#	print("GameOverMenu: получен сигнал player_died")
	
	# УБИРАЕМ ВСЮ ПАУЗУ - она мешает работе кнопок!
	get_tree().paused = false  
	
	show()
	
	# ВКЛЮЧАЕМ обработку ввода UI
	set_process_input(true)
	set_process_unhandled_input(true)
	
	# Фокусируемся на кнопке рестарта
	if restart_button:
		restart_button.grab_focus()
#		print("Фокус на кнопке рестарта")

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
		print("Input event: ", event)
		if event.is_action_pressed("ui_accept"):
			if restart_button and restart_button.has_focus():
				_on_restart_button_pressed()
				get_viewport().set_input_as_handled()
			elif load_button and load_button.has_focus():  # ← ОБРАБОТКА ЗАГРУЗКИ
				_on_load_button_pressed()
				get_viewport().set_input_as_handled()

func _on_restart_button_pressed():
	print("!!! НАЖАТИЕ: RestartButton !!!")
	# Перезагружаем сцену
	get_tree().reload_current_scene()

# ← НОВАЯ ФУНКЦИЯ ДЛЯ КНОПКИ ЗАГРУЗКИ
func _on_load_button_pressed():
	print("!!! НАЖАТИЕ: LoadButton !!!")
	if save_system and save_system.load_game():
		# Успешная загрузка - перезагружаем сцену
		get_tree().reload_current_scene()
	else:
		print("Не удалось загрузить сохранение")

func _on_quit_button_pressed():
	print("!!! НАЖАТИЕ: QuitButton !!!")
	get_tree().quit()

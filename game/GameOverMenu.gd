#GameOverMenu.gd
extends CanvasLayer

@onready var restart_button: Button = $Panel/RestartButton
@onready var quit_button: Button = $Panel/QuitButton

func _ready():
	hide()
	
	# Подключаем кнопки СРАЗУ
	if restart_button:
		print("RestartButton найден, подключаем...")
		# Отключаем старые соединения если есть
		if restart_button.pressed.is_connected(_on_restart_button_pressed):
			restart_button.pressed.disconnect(_on_restart_button_pressed)
		# Подключаем заново
		restart_button.pressed.connect(_on_restart_button_pressed)
		
	if quit_button:
		print("QuitButton найден, подключаем...")
		if quit_button.pressed.is_connected(_on_quit_button_pressed):
			quit_button.pressed.disconnect(_on_quit_button_pressed)
		quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Подключаемся к сигналу смерти игрока
	await get_tree().process_frame
	_connect_to_player_stats()

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
	print("GameOverMenu: получен сигнал player_died")
	
	# УБИРАЕМ ВСЮ ПАУЗУ - она мешает работе кнопок!
	# get_tree().paused = true  ← ЗАКОММЕНТИРОВАТЬ или УДАЛИТЬ
	
	show()
	
	# ВКЛЮЧАЕМ обработку ввода UI
	set_process_input(true)
	set_process_unhandled_input(true)
	
	# Фокусируемся на кнопке рестарта
	if restart_button:
		restart_button.grab_focus()
		print("Фокус на кнопке рестарта")

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

func _on_restart_button_pressed():
	print("!!! НАЖАТИЕ: RestartButton !!!")
	# Перезагружаем сцену
	get_tree().reload_current_scene()

func _on_quit_button_pressed():
	print("!!! НАЖАТИЕ: QuitButton !!!")
	get_tree().quit()

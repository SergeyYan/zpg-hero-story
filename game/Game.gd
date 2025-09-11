#Game.gd
extends Node2D

var pause_menu: CanvasLayer
@onready var level_up_menu: LevelUpMenu = $LevelUpMenu

func _ready():
	# Проверяем, нет ли уже меню в дереве
	if has_node("Menu"):
		pause_menu = get_node("Menu")
		print("Меню уже существует в сцене")
	else:
		var pause_menu_scene = load("res://game/Menu.tscn")
		if pause_menu_scene:
			pause_menu = pause_menu_scene.instantiate()
			pause_menu.name = "Menu"  # Даем имя для последующего поиска
			add_child(pause_menu)
			print("Меню загружено и добавлено")
		else:
			push_error("Не удалось загрузить сцену меню")
			return
	
	# Подключаем сигналы только если меню существует
	if pause_menu:
		print("Подключаем сигналы меню")
		var connect_result1 = pause_menu.resume_game.connect(_on_resume_game)
		var connect_result2 = pause_menu.restart_game.connect(_on_restart_game)
		var connect_result3 = pause_menu.quit_game.connect(_on_quit_game)
		
		print("Результаты подключения: ", connect_result1, ", ", connect_result2, ", ", connect_result3)
	else:
		push_error("Меню не найдено для подключения сигналов")
	
	# ПОДКЛЮЧАЕМ СИГНАЛ LEVEL UP
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats:
		player_stats.level_up.connect(_on_player_level_up)
		print("Сигнал level_up подключен")
	else:
		print("PlayerStats не найден для подключения level_up")

# ← ДОБАВЛЯЕМ ЭТУ ФУНКЦИЮ В Game.gd!
func _on_player_level_up(level: int, available_points: int):
	print("Игрок получил уровень! Доступно очков: ", available_points)
	
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if not player_stats:
		push_error("PlayerStats не найден!")
		return
	
	if level_up_menu and level_up_menu.has_method("show_menu"):
		level_up_menu.show_menu(player_stats, available_points)
	else:
		push_error("LevelUpMenu не найден или не имеет метода show_menu!")
	
	# Улучшаем монстров - передаем ТЕКУЩИЙ уровень (не +1)
	_upgrade_monsters(level)  # ← level, а не level + 1

func _upgrade_monsters(player_level: int):
	# Увеличиваем силу монстров в зависимости от уровня игрока
	var monsters = get_tree().get_nodes_in_group("monsters")
	print("Найдено монстров для улучшения: ", monsters.size())
	
	for monster in monsters:
		if monster.has_method("apply_level_scaling"):
			print("Улучшаем монстра: ", monster.name)
			monster.apply_level_scaling(player_level)
		else:
			print("Монстр ", monster.name, " не имеет метода apply_level_scaling")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("=== ОБРАБОТКА ESC ===")
		
		# ЕСЛИ открыто меню прокачки - не обрабатываем ESC
		if level_up_menu and level_up_menu.visible:
			return
		
		if get_tree().paused:
			print("Возобновляем игру")
			get_tree().paused = false
			if pause_menu and pause_menu.has_method("hide_menu"):
				pause_menu.hide_menu()
		else:
			print("Ставим игру на паузу")
			get_tree().paused = true
			if pause_menu and pause_menu.has_method("show_menu"):
				pause_menu.show_menu()

func _on_resume_game():
	print("Game: получен сигнал resume_game")
	get_tree().paused = false

func _on_restart_game():
	print("Game: получен сигнал restart_game")
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_game():
	print("Game: получен сигнал quit_game")
	get_tree().quit()

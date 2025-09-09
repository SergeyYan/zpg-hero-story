#Game.gd
extends Node2D

var pause_menu: CanvasLayer

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


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("=== ОБРАБОТКА ESC ===")
		
		if get_tree().paused:
			# Если игра на паузе - возобновляем
			print("Возобновляем игру")
			get_tree().paused = false
			if pause_menu and pause_menu.has_method("hide_menu"):
				pause_menu.hide_menu()
		else:
			# Если игра не на паузе - ставим на паузу
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

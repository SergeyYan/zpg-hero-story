#Game.gd
extends Node2D

var main_menu: CanvasLayer  # ← ДОБАВЛЯЕМ
var pause_menu: CanvasLayer
@onready var level_up_menu: LevelUpMenu = $LevelUpMenu

func _ready():

	get_tree().paused = true  # ← Пауза при запуске
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

	var battle_system = get_tree().get_first_node_in_group("battle_system")
	if battle_system:
		battle_system.battle_ended.connect(_on_battle_ended)


func _on_battle_ended(victory: bool):
	print("Бой завершен, результат: ", victory)
	
	# ← ДАЕМ ВРЕМЯ LevelUpMenu ОТКРЫТЬСЯ через сигнал level_up
	await get_tree().create_timer(0.1).timeout  # ← Маленькая задержка
	
	# ← ТЕПЕРЬ проверяем очки после того как level_up отработал
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats and player_stats.available_points <= 0:
		get_tree().paused = false
		print("Пауза снята - нет очков для прокачки")
	else:
		print("Пауза остается - есть очки для прокачки")


func _on_new_game_pressed():
	print("Начинаем новую игру...")
	get_tree().paused = false  # ← Снимаем паузу
	
	if main_menu:
		main_menu.hide()  # ← Скрываем меню, НЕ удаляем!
	
	# Сброс прогресса (если нужно)
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats:
		player_stats.current_health = player_stats.get_max_health()
		player_stats.current_exp = 0
		player_stats.level = 1
		player_stats.available_points = 3
		print("Новая игра начата")

func _on_load_game_pressed():
	print("Загрузка игры...")
	get_tree().paused = false
	if main_menu:
		main_menu.hide()

func _on_quit_game_pressed():
	print("Выход из игры...")
	get_tree().quit()

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
	
	# Улучшаем монстров - передаем ТЕКУЩИЙ уровень
	_upgrade_monsters(level)  # ← level, а не level + 1
	
	# ТЕПЕРЬ ТАКЖЕ ОБНОВЛЯЕМ СПАВНЕР
	var spawner = get_tree().get_first_node_in_group("monster_spawner")
	if spawner:
		spawner.set("player_level", level)  # Обновляем уровень в спавнере
		print("Спавнер обновлен до уровня: ", level)

func _upgrade_monsters(player_level: int):
	# Увеличиваем силу монстров в зависимости от уровня игрока
	var monsters = get_tree().get_nodes_in_group("monsters")
	print("Улучшаем монстров до уровня игрока: ", player_level)
	
	for monster in monsters:
		if monster.has_method("apply_level_scaling"):
			monster.apply_level_scaling(player_level)  # ← Тот же уровень

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Если открыто главное меню - не обрабатываем ESC
		if main_menu and main_menu.visible:
			return
		
		# ЕСЛИ открыто меню прокачки - не обрабатываем ESC
		var level_up_menu_node = get_tree().get_first_node_in_group("level_up_menu")
		if level_up_menu_node and level_up_menu_node.visible:
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

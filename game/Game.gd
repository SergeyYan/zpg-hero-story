#Game.gd
extends Node2D

var main_menu: CanvasLayer
var pause_menu: CanvasLayer
@onready var level_up_menu: LevelUpMenu = $LevelUpMenu

func _ready():
	# Проверяем, идет ли загрузка сохранения
	var is_loading = GameState.is_loading
	
	if is_loading:
		get_tree().paused = false
		
		# Загружаем сохранение ПОСЛЕ создания сцены
		var save_system = SaveSystem.new()
		add_child(save_system)
		if save_system.load_game():
			
			# ← Ждем инициализации
			await get_tree().process_frame
			
			# Обновляем спавнер
			var player_stats = get_tree().get_first_node_in_group("player_stats")
			var spawner = get_tree().get_first_node_in_group("monster_spawner")
			
			if player_stats and spawner:
				if spawner.has_method("set_player_level_after_load"):
					spawner.set_player_level_after_load(player_stats.level)
				elif spawner.has_method("update_player_level"):
					spawner.update_player_level(player_stats.level)
				else:
					spawner.player_level = player_stats.level
			# ← МАСШТАБИРУЕМ СТАТИЧЕСКИХ МОНСТРОВ ПОСЛЕ загрузки!
			_scale_static_monsters(player_stats.level)
			
	else:
		get_tree().paused = true
	
	
	# Проверяем, нет ли уже меню в дереве
	if has_node("Menu"):
		pause_menu = get_node("Menu")
	else:
		var pause_menu_scene = load("res://game/Menu.tscn")
		if pause_menu_scene:
			pause_menu = pause_menu_scene.instantiate()
			pause_menu.name = "Menu"
			add_child(pause_menu)
		else:
			return
	
	# Подключаем сигналы паузы
	if pause_menu:
		pause_menu.resume_game.connect(_on_resume_game)
		pause_menu.restart_game.connect(_on_restart_game)
		pause_menu.quit_game.connect(_on_quit_game)
		pause_menu.save_game.connect(_on_save_game)
		pause_menu.load_game.connect(_on_load_game)
	else:
		push_error("Меню не найдено для подключения сигналов")
	
	# ПОДКЛЮЧАЕМ СИГНАЛ LEVEL UP
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats:
		player_stats.level_up.connect(_on_player_level_up)
	else:
		push_error("PlayerStats не найден для подключения level_up")
	
	# Подключаем battle system
	var battle_system = get_tree().get_first_node_in_group("battle_system")
	if battle_system:
		battle_system.battle_ended.connect(_on_battle_ended)

	# Сбрасываем флаг после использования
	GameState.is_loading = false

func _on_battle_ended(victory: bool):
	
	# Даем время LevelUpMenu открыться через сигнал level_up
	await get_tree().create_timer(0.1).timeout
	
	# Проверяем очки после того как level_up отработал
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats and player_stats.available_points <= 0:
		get_tree().paused = false


func _on_new_game_pressed():
	get_tree().paused = false
	
	if main_menu:
		main_menu.hide()
	
	# Сброс прогресса
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats:
		player_stats.current_health = player_stats.get_max_health()
		player_stats.current_exp = 0
		player_stats.level = 1
		player_stats.available_points = 3


func _on_save_game():
	print("Сохранение игры из меню паузы...")

func _on_load_game():

	# Устанавливаем флаг загрузки
	GameState.is_loading = true
	# Перезагружаем сцену - теперь Game.gd обработает флаг корректно
	get_tree().reload_current_scene()

func _on_player_level_up(level: int, available_points: int):
	# ЕСЛИ это загрузка сохранения ИЛИ нет очков - НЕ открываем меню
	if GameState.is_loading or available_points <= 0:

		# Но все равно улучшаем монстров и обновляем спавнер!
		_upgrade_monsters(level)
		var spawner = get_tree().get_first_node_in_group("monster_spawner")
		if spawner:
			spawner.set("player_level", level)
		return
	

	
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if not player_stats:
		push_error("PlayerStats не найден!")
		return
	
	if level_up_menu and level_up_menu.has_method("show_menu"):
		level_up_menu.show_menu(player_stats, available_points)
	else:
		push_error("LevelUpMenu не найден или не имеет метода show_menu!")
	
	_upgrade_monsters(level)
	
	# Обновляем спавнер
	var spawner = get_tree().get_first_node_in_group("monster_spawner")
	if spawner:
		spawner.set("player_level", level)


func _upgrade_monsters(player_level: int):

	
	var monsters = get_tree().get_nodes_in_group("monsters")

	
	for monster in monsters:
		if monster and monster.has_method("apply_level_scaling"):
			monster.apply_level_scaling(player_level)


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Если открыто главное меню - не обрабатываем ESC
		if main_menu and main_menu.visible:
			return
		
		# Если открыто меню прокачки - не обрабатываем ESC
		var level_up_menu_node = get_tree().get_first_node_in_group("level_up_menu")
		if level_up_menu_node and level_up_menu_node.visible:
			return
		
		if get_tree().paused:
			get_tree().paused = false
			if pause_menu and pause_menu.has_method("hide_menu"):
				pause_menu.hide_menu()
		else:
			get_tree().paused = true
			if pause_menu and pause_menu.has_method("show_menu"):
				pause_menu.show_menu()

func _on_resume_game():
	get_tree().paused = false

func _on_restart_game():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_game():
	get_tree().quit()


func _scale_static_monsters(player_level: int):
	
	var all_monsters = get_tree().get_nodes_in_group("monsters")
	
	for monster in all_monsters:
		if monster and monster.has_node("MonsterStats"):
			var stats = monster.get_node("MonsterStats")
			
			# Если монстр имеет уровень 1 но должен быть выше
			if stats.monster_level == 1 and player_level > 1:
				stats.monster_level = player_level  # ← Вручную устанавливаем уровень
				stats.apply_level_scaling(player_level)  # ← Применяем масштабирование

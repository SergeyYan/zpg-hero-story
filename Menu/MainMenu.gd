# MainMenu.gd
extends CanvasLayer

signal new_game_pressed
signal load_game_pressed  
signal quit_game_pressed

@onready var new_game_button: Button = $CenterContainer/Panel/VBoxContainer/NewGameButton 
@onready var load_game_button: Button = $CenterContainer/Panel/VBoxContainer/LoadGameButton
@onready var quit_button: Button = $CenterContainer/Panel/VBoxContainer/QuitButton
@onready var center_container: CenterContainer = $CenterContainer
@onready var main_panel: Panel = $CenterContainer/Panel
@onready var vbox_container: VBoxContainer = $CenterContainer/Panel/VBoxContainer
@onready var menu_player: CharacterBody2D = $MenuPlayer
@onready var dance_menu: AnimatedSprite2D = $MenuPlayer/DanceMenu
@onready var animated_sprite_left: AnimatedSprite2D = $MenuPlayer/AnimatedSprite2D
@onready var animated_sprite_right: AnimatedSprite2D = $MenuPlayer/AnimatedSprite2D2

var save_system
var is_mobile: bool = false
var screen_size: Vector2
var base_font_size: int = 16

func _ready():
	add_to_group("main_menu")
	
	# Ждем пока сцена полностью загрузится
	await get_tree().process_frame
	
	# Определяем тип устройства
	_detect_device_type()
	
	# Настраиваем стиль меню
	_setup_menu_style()
	
	# Создаем систему сохранений
	save_system = SaveSystem.new()
	add_child(save_system)
	
	# Подключаем кнопки
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Настраиваем адаптивный интерфейс
	_setup_responsive_ui()
	
	# Настраиваем позиции персонажей
	_setup_characters_position()
	
	# Проверяем сохранения при запуске
	_check_save_file()

func _detect_device_type():
	screen_size = get_viewport().get_visible_rect().size
	print("Размер экрана главного меню: ", screen_size)
	
	# Для 800x600 считаем десктопом
	is_mobile = screen_size.x < 600
	
	if is_mobile:
		print("Главное меню: обнаружено мобильное устройство")
		base_font_size = 18
	else:
		print("Главное меню: обнаружено десктоп/планшет устройство")
		base_font_size = 16

func _setup_characters_position():
	if not menu_player:
		print("Персонаж меню не найден!")
		return
	
	print("Настройка позиций персонажей для экрана: ", screen_size)
	
	# Основной танцующий персонаж под кнопками
	dance_menu.position = Vector2(
		screen_size.x * 0.5,  # Центр по X
		screen_size.y * 0.8   # Под кнопками (70% высоты)
	)
	
	# Персонаж слева (торчит наполовину)
	animated_sprite_right.position = Vector2(
		-16,  # Торчит слева
		screen_size.y * 0.8   # На уровне кнопок
	)
	
	# Персонаж справа (торчит наполовину)
	animated_sprite_left.position = Vector2(
		screen_size.x + 16,  # Торчит справа
		screen_size.y * 0.8   # На уровне кнопок
	)
	
	print("Позиция танцора: ", dance_menu.position)
	print("Позиция левого персонажа: ", animated_sprite_left.position)
	print("Позиция правого персонажа: ", animated_sprite_right.position)

func _setup_responsive_ui():
	print("Настройка адаптивного интерфейса")
	
	# Устанавливаем фиксированные размеры для панели
	if is_mobile:
		main_panel.size = Vector2(screen_size.x * 0.8, screen_size.y * 0.4)
	else:
		main_panel.size = Vector2(400, 280)  # Фиксированный размер для десктопа
	
	# ВРУЧНУЮ центрируем панель, так как CenterContainer может не работать как ожидается
	main_panel.position = Vector2(
		(screen_size.x - main_panel.size.x) / 2,  # Центр по X
		(screen_size.y - main_panel.size.y) / 3   # Центр по Y
	)
	
	print("Размер панели после установки: ", main_panel.size)
	print("Позиция панели после центрирования: ", main_panel.position)
	
	# Настраиваем VBoxContainer - заполняет всю панель
	vbox_container.size = main_panel.size
	vbox_container.position = Vector2(0, 0)  # Заполняет всю панель
	vbox_container.add_theme_constant_override("separation", 20)
	
	# Центрируем содержимое VBoxContainer
	#vbox_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Настраиваем кнопки
	var button_width = main_panel.size.x * 0.6  # 80% ширины панели
	var button_height = main_panel.size.y * 0.18
	
	for button in [new_game_button, load_game_button, quit_button]:
		button.custom_minimum_size = Vector2(button_width, button_height)
		# Убираем растягивающие флаги
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", base_font_size)
	
	# Центрируем VBoxContainer содержимое вручную
	vbox_container.position.x = (main_panel.size.x - vbox_container.size.x) / 2

func _setup_menu_style():
	# Создаем стиль для основной панели
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	panel_style.border_color = Color(0.6, 0.6, 0.8, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.shadow_color = Color(0, 0, 0, 0.7)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(4, 4)
	
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Настраиваем стиль для кнопок
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.3, 1.0)
	button_style.border_color = Color(0.4, 0.4, 0.6, 1.0)
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_right = 8
	button_style.corner_radius_bottom_left = 8
	
	var button_hover_style = button_style.duplicate()
	button_hover_style.bg_color = Color(0.3, 0.3, 0.4, 1.0)
	button_hover_style.border_color = Color(0.6, 0.6, 0.8, 1.0)
	
	var button_pressed_style = button_style.duplicate()
	button_pressed_style.bg_color = Color(0.4, 0.4, 0.5, 1.0)
	button_pressed_style.border_color = Color(0.8, 0.8, 1.0, 1.0)
	
	for button in [new_game_button, load_game_button, quit_button]:
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("hover", button_hover_style)
		button.add_theme_stylebox_override("pressed", button_pressed_style)
		
		button.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 1.0, 1.0))
		
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_viewport_size_changed():
	_detect_device_type()
	_setup_responsive_ui()
	_setup_characters_position()

func _check_save_file():
	var save_path = ""
	var SAVE_DIR: String = "ZPG Hero story"
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	save_path = documents_path.path_join(SAVE_DIR).path_join("savegame.save")
	if FileAccess.file_exists(save_path):
		load_game_button.disabled = false
		load_game_button.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 1.0))
	else:
		load_game_button.disabled = true
		load_game_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.7))

func _on_new_game_pressed():
	GameState.is_loading = false
	get_tree().call_group("new_game_listener", "reset_all_achievements")
	get_tree().change_scene_to_file("res://game/game.tscn")
	hide()

func _on_load_game_pressed():
	GameState.is_loading = true
	get_tree().change_scene_to_file("res://game/game.tscn")
	hide()

func _on_quit_pressed():
	get_tree().quit()

func show_menu():
	show()
	_check_save_file()
	new_game_button.grab_focus()
	_detect_device_type()
	_setup_responsive_ui()
	_setup_characters_position()

func hide_menu():
	hide()

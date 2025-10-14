#Menu.gd
extends CanvasLayer

signal resume_game
signal restart_game  
signal save_game
signal load_game
signal quit_game
signal menu_closed

@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var fullscreen_button: Button = %FullscreenButton
@onready var menu_container: VBoxContainer = $VBoxContainer

var save_system: SaveSystem
var is_mobile: bool = false

func _ready():
	add_to_group("pause_menu")
	hide()
	set_process_unhandled_input(false)
	# Определяем тип устройства
	_detect_device_type()
	# Создаем систему сохранений
	save_system = SaveSystem.new()
	add_child(save_system)
	# Подключаем кнопки
	_connect_buttons()
	# Проверяем наличие сохранений
	_check_save_file()

func _unhandled_input(event):
	if not visible:
		return

	if event is InputEventMouseButton and event.pressed:
		var clicked_inside = false

		if menu_container and menu_container.visible:
			# Получаем глобальный прямоугольник контейнера меню
			var menu_rect = menu_container.get_global_rect()
			# Добавляем небольшой отступ для удобства (опционально)
			var padded_rect = Rect2(
				menu_rect.position - Vector2(10, 10),
				menu_rect.size + Vector2(20, 20)
			)
			clicked_inside = padded_rect.has_point(event.global_position)
		else:
			# Если нет menu_container, проверяем все видимые кнопки и панели
			var menu_nodes = [continue_button, restart_button, quit_button, save_button, load_button, fullscreen_button]
			for node in menu_nodes:
				if node and node.visible and node.get_global_rect().has_point(event.global_position):
					clicked_inside = true
					break

		if not clicked_inside:
			resume_game.emit()
			hide_menu()
			get_viewport().set_input_as_handled()
			
	# Также закрываем меню при нажатии Escape
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		resume_game.emit()
		hide_menu()
		get_viewport().set_input_as_handled()

func _detect_device_type():
	var screen_size = get_viewport().get_visible_rect().size
	is_mobile = screen_size.x < 790 or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	if is_mobile:
		print("Меню паузы: обнаружено мобильное устройство")
	else:
		print("Меню паузы: обнаружено десктоп устройство")

func _connect_buttons():
	# Сначала отключаем все сигналы
	continue_button.pressed.disconnect(_on_continue_button_pressed)
	restart_button.pressed.disconnect(_on_restart_button_pressed)
	quit_button.pressed.disconnect(_on_quit_button_pressed)
	save_button.pressed.disconnect(_on_save_button_pressed)
	load_button.pressed.disconnect(_on_load_button_pressed)
	
	# Затем подключаем заново
	continue_button.pressed.connect(_on_continue_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	
	# Настраиваем полноэкранную кнопку (только для десктопа)
	_setup_fullscreen_button()

func _setup_fullscreen_button():
	# Скрываем кнопку на мобильных устройствах
	if is_mobile:
		if fullscreen_button:
			fullscreen_button.visible = false
		return
	
	# Настраиваем только для десктопа
	if fullscreen_button:
		fullscreen_button.visible = true
		
		# Подключаем сигнал pressed (только если еще не подключен)
		if not fullscreen_button.pressed.is_connected(_on_fullscreen_button_pressed):
			fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
		
		# Обновляем текст кнопки в зависимости от текущего режима
		_update_fullscreen_button_text()

func _on_fullscreen_button_pressed():
	# Переключаем режим
	var current_mode = DisplayServer.window_get_mode()
	
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		print("Включен полноэкранный режим")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("Включен оконный режим")
	
	# Ждем немного пока система обработает изменение режима
	await get_tree().create_timer(0.1).timeout
	
	# Обновляем текст кнопки
	_update_fullscreen_button_text()

func _update_fullscreen_button_text():
	if fullscreen_button and fullscreen_button.visible:
		var current_mode = DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
			fullscreen_button.text = "Полноэкранный режим: ВЫКЛ"
		else:
			fullscreen_button.text = "Полноэкранный режим: ВКЛ"

func _check_save_file():
	print("=== PAUSE MENU SAVE CHECK ===")
	
	# Используем SaveSystem для проверки
	if save_system:
		print("SaveSystem found in pause menu")
		print("Can load game: ", save_system.can_load_game())
		print("Has valid save: ", save_system.has_valid_save)
		print("Save path: ", save_system.SAVE_PATH)
		print("File exists: ", FileAccess.file_exists(save_system.SAVE_PATH))
		
		# ВКЛЮЧАЕМ/ВЫКЛЮЧАЕМ кнопку загрузки на основе SaveSystem
		if save_system.can_load_game():
			load_button.disabled = false
			print("✅ Load button ENABLED in pause menu")
		else:
			load_button.disabled = true
			print("❌ Load button DISABLED in pause menu")
	else:
		print("❌ SaveSystem NOT found in pause menu!")
		load_button.disabled = true
	
	print("=============================")

func _input(event):
	if visible and event is InputEventKey:
		if event.is_action_pressed("ui_cancel"):
			resume_game.emit()
			hide_menu()
			get_viewport().set_input_as_handled()

func show_menu():
	show()
	set_process_input(true)
	set_process_unhandled_input(true)
	# Проверяем сохранения при каждом открытии меню
	_check_save_file()
	# Обновляем настройки кнопок
	_update_button_sizes()
	# Обновляем текст полноэкранной кнопки
	_update_fullscreen_button_text()
	if continue_button:
		continue_button.grab_focus()

func _update_button_sizes():
	# Устанавливаем одинаковые размеры для всех кнопок
	var button_size = Vector2(250, 45)
	
	for button in [continue_button, restart_button, save_button, load_button, quit_button, fullscreen_button]:
		if button and button.visible:
			button.custom_minimum_size = button_size

func hide_menu():
	hide()
	set_process_input(false)
	set_process_unhandled_input(false)
	menu_closed.emit()

# Обработчики кнопок
func _on_continue_button_pressed():
	resume_game.emit()
	hide_menu()

func _on_restart_button_pressed():
	get_tree().call_group("new_game_listener", "reset_all_achievements")
	restart_game.emit()
	hide_menu()

func _on_quit_button_pressed():
	quit_game.emit()

func _on_save_button_pressed():
	print("=== SAVE FROM PAUSE MENU ===")
	
	var save_system = get_tree().get_first_node_in_group("save_system")
	if save_system:
		save_system.save_game()
		# После сохранения активируем кнопку загрузки
		await get_tree().create_timer(0.5).timeout  # Ждем завершения сохранения
		_check_save_file()  # Обновляем состояние кнопки
		_show_save_confirmation()
	else:
		print("❌ SaveSystem not found for saving!")

func _on_load_button_pressed():
	print("=== LOAD FROM PAUSE MENU ===")
	
	var save_system = get_tree().get_first_node_in_group("save_system")
	if save_system and save_system.can_load_game():
		print("✅ Loading game from pause menu...")
		GameState.is_loading = true
		# Закрываем меню
		hide_menu()
		# Перезагружаем сцену
		get_tree().reload_current_scene()
	else:
		print("❌ No saves available or SaveSystem not found")
		print("Can load: ", save_system.can_load_game() if save_system else "No SaveSystem")

func _show_save_confirmation():
	var original_text = save_button.text
	save_button.text = "Сохранено!"
	await get_tree().create_timer(1.0).timeout
	save_button.text = original_text

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
	# Проверяем есть ли файл сохранения
	var save_path = ""
	var SAVE_DIR: String = "ZPG Hero story"
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	save_path = documents_path.path_join(SAVE_DIR).path_join("savegame.save")
	if FileAccess.file_exists(save_path):
		load_button.disabled = false
	else:
		load_button.disabled = true

func _input(event):
	if visible and event is InputEventKey:
		if event.is_action_pressed("ui_cancel"):
			resume_game.emit()
			hide_menu()
			get_viewport().set_input_as_handled()

func show_menu():
	show()
	set_process_input(true)
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
	if save_system:
		save_system.save_game()
		# После сохранения активируем кнопку загрузки
		load_button.disabled = false
		_show_save_confirmation()

func _on_load_button_pressed():
	if save_system:
		GameState.is_loading = true
		if save_system.load_game():
			get_tree().reload_current_scene()
		else:
			GameState.is_loading = false

func _show_save_confirmation():
	var original_text = save_button.text
	save_button.text = "Сохранено!"
	await get_tree().create_timer(1.0).timeout
	save_button.text = original_text

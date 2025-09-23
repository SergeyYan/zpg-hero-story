#Menu.gd
extends CanvasLayer

signal resume_game
signal restart_game  
signal save_game
signal load_game
signal quit_game

@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton

var save_system: SaveSystem

func _ready():
	add_to_group("pause_menu")
	hide()
	set_process_unhandled_input(false)
	
	# Создаем систему сохранений
	save_system = SaveSystem.new()
	add_child(save_system)
	
	# Подключаем кнопки
	_connect_buttons()
	
	# Проверяем наличие сохранений
	_check_save_file()
	
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
	
	if continue_button:
		continue_button.grab_focus()
	
	
func hide_menu():
	hide()
	set_process_input(false)  # Выключаем обработку ввода


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
		# Можно добавить визуальное подтверждение сохранения
		_show_save_confirmation()


func _on_load_button_pressed():
	if save_system:
		# Устанавливаем флаг загрузки
		GameState.is_loading = true
		
		if save_system.load_game():
			# Успешная загрузка - перезагружаем сцену
			get_tree().reload_current_scene()
		else:
			GameState.is_loading = false


# Визуальное подтверждение сохранения
func _show_save_confirmation():
	# Можно добавить анимацию или текст подтверждения
	var original_text = save_button.text
	save_button.text = "Сохранено!"
	# Через 1 секунду возвращаем оригинальный текст
	await get_tree().create_timer(1.0).timeout
	save_button.text = original_text

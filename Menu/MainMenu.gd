# MainMenu.gd
extends CanvasLayer

signal new_game_pressed
signal load_game_pressed  
signal quit_game_pressed

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton 
@onready var load_game_button: Button = $CenterContainer/VBoxContainer/LoadGameButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

var save_system

func _ready():
	# Создаем систему сохранений
	save_system = SaveSystem.new()
	add_child(save_system)
	
	# Подключаем кнопки
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Проверяем сохранения при запуске
	_check_save_file()

func _check_save_file():
	var save_path = ""
	var SAVE_DIR: String = "ZPG Hero story"
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	save_path = documents_path.path_join(SAVE_DIR).path_join("savegame.save")
	if FileAccess.file_exists(save_path):  # ← Используем SAVE_PATH из SaveSystem
		load_game_button.disabled = false
	else:
		load_game_button.disabled = true

func _on_new_game_pressed():
	GameState.is_loading = false
	get_tree().change_scene_to_file("res://game/game.tscn")
	hide()

func _on_load_game_pressed():
	GameState.is_loading = true
	
	# Переходим в игру БЕЗ предварительной загрузки
	get_tree().change_scene_to_file("res://game/game.tscn")
	hide()

func _on_quit_pressed():
	get_tree().quit()

func show_menu():
	show()
	_check_save_file()
	new_game_button.grab_focus()

func hide_menu():
	hide()

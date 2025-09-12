# MainMenu.gd
extends CanvasLayer

signal new_game_pressed
signal load_game_pressed
signal quit_game_pressed

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton 
@onready var load_game_button: Button = $CenterContainer/VBoxContainer/LoadGameButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
	# Подключаем кнопки
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed) 
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Делаем кнопку загрузки неактивной пока нет сохранений
	load_game_button.disabled = true
	print("Главное меню загружено")

func _on_new_game_pressed():
	print("Нажата кнопка 'Новая игра'")
	get_tree().change_scene_to_file("res://game/game.tscn")
	hide()

func _on_load_game_pressed():
	print("Нажата кнопка 'Загрузить игру'")
	load_game_pressed.emit()
	hide()

func _on_quit_pressed():
	print("Нажата кнопка 'Выход'")
	quit_game_pressed.emit()  # ← Должно совпадать с сигналом в Game.gd
	get_tree().quit()  # ← ДОБАВЛЯЕМ немедленный выход

# Показываем меню при запуске
func show_menu():
	show()
	new_game_button.grab_focus()

# Прячем меню когда игра начинается
func hide_menu():
	hide()


func _on_new_game_button_pressed() -> void:
	pass # Replace with function body.


func _on_load_game_button_pressed() -> void:
	pass # Replace with function body.


func _on_quit_button_pressed() -> void:
	pass # Replace with function body.

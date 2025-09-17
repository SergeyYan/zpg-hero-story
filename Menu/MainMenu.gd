# MainMenu.gd
extends CanvasLayer

signal new_game_pressed
signal load_game_pressed
signal quit_game_pressed

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton 
@onready var load_game_button: Button = $CenterContainer/VBoxContainer/LoadGameButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

# ← ДОБАВЛЯЕМ ССЫЛКУ НА СИСТЕМУ СОХРАНЕНИЙ
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
	print("Главное меню загружено")

func _check_save_file():
	# ← ПРОВЕРЯЕМ ЕСТЬ ЛИ ФАЙЛ СОХРАНЕНИЯ
	var save_path = "user://savegame.save"
	if FileAccess.file_exists(save_path):
		load_game_button.disabled = false
		print("Сохранение найдено, кнопка загрузки активна")
	else:
		load_game_button.disabled = true
		print("Сохранение не найдено, кнопка загрузки отключена")


func _on_new_game_pressed():
	print("Нажата кнопка 'Новая игра'")
	# ← ОЧИЩАЕМ СТАРОЕ СОХРАНЕНИЕ ПЕРЕД НОВОЙ ИГРОЙ
	if save_system:
		save_system.clear_save()
	get_tree().change_scene_to_file("res://game/game.tscn")
	hide()

func _on_load_game_pressed():
	print("Нажата кнопка 'Загрузить игру'")
	
	if save_system.load_game():
		# Успешная загрузка - переходим в игру
		get_tree().change_scene_to_file("res://game/game.tscn")
	else:
		print("Ошибка загрузки сохранения")
		# Можно показать сообщение об ошибке

func _on_quit_pressed():
	print("Нажата кнопка 'Выход'")
	quit_game_pressed.emit()  # ← Должно совпадать с сигналом в Game.gd
	get_tree().quit()  # ← ДОБАВЛЯЕМ немедленный выход

# Показываем меню при запуске
func show_menu():
	show()
	# ← ПЕРЕПРОВЕРЯЕМ СОХРАНЕНИЯ ПРИ ПОКАЗЕ МЕНЮ
	_check_save_file()
	new_game_button.grab_focus()

# Прячем меню когда игра начинается
func hide_menu():
	hide()

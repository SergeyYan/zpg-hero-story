# Menu.gd
extends CanvasLayer

signal resume_game
signal restart_game  
signal quit_game

@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton

func _ready():
	print("Меню: _ready() вызван для: ", self.name)
	hide()
	set_process_unhandled_input(false)
	
	print("=== ИНИЦИАЛИЗАЦИЯ МЕНЮ ===")
	
	# Проверяем, существуют ли кнопки
	print("ContinueButton exists: ", continue_button != null)
	print("RestartButton exists: ", restart_button != null) 
	print("QuitButton exists: ", quit_button != null)
	
	if continue_button:
		_connect_button(continue_button, _on_continue_button_pressed)
	if restart_button:
		_connect_button(restart_button, _on_restart_button_pressed)
	if quit_button:
		_connect_button(quit_button, _on_quit_button_pressed)

func _connect_button(button: Button, callback: Callable):
	if button:
		if button.pressed.is_connected(callback):
			button.pressed.disconnect(callback)
		var result = button.pressed.connect(callback)
		if result == OK:
			print("Успешно подключен: ", button.name)
		else:
			print("Ошибка подключения: ", button.name, " код: ", result)

func _input(event):
	if visible and event is InputEventKey:
		print("Меню: получено событие ввода: ", event.as_text())
		
		if event.is_action_pressed("ui_cancel"):
			print("ESC в меню: закрытие")
			resume()
			get_viewport().set_input_as_handled()  # ПРАВИЛЬНО!


func show_menu():
	show()
	set_process_input(true)  # Включаем обработку ввода
	print("Меню показано")
	
	if continue_button:
		continue_button.grab_focus()
	
func hide_menu():
	hide()
	set_process_input(false)  # Выключаем обработку ввода
	print("Меню скрыто")

func resume():
	hide_menu()
	resume_game.emit()
	print("Меню: испущен сигнал resume_game")

func restart():
	hide_menu()
	restart_game.emit()
	print("Меню: испущен сигнал restart_game")

func quit():
	quit_game.emit()
	print("Меню: испущен сигнал quit_game")

# Обработчики кнопок
func _on_continue_button_pressed():
	print("!!! НАЖАТИЕ: ContinueButton !!!")
	resume()

func _on_restart_button_pressed():
	print("!!! НАЖАТИЕ: RestartButton !!!")
	restart()

func _on_quit_button_pressed():
	print("!!! НАЖАТИЕ: QuitButton !!!")
	quit()

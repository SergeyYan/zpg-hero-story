#LevelUpMenu.gd
extends CanvasLayer
class_name LevelUpMenu  # ← ВАЖНО: добавляем class_name

signal points_distributed

@onready var strength_label: Label = $Panel/VBoxContainer/HBOXstr/StrengthLabel
@onready var fortitude_label: Label = $Panel/VBoxContainer/HBOXfort/FortitudeLabel
@onready var endurance_label: Label = $Panel/VBoxContainer/HBOXend/EnduranceLabel
@onready var points_label: Label = $Panel/VBoxContainer/PointsLabel
@onready var strength_button: Button = $Panel/VBoxContainer/HBOXstr/StrengthButton
@onready var fortitude_button: Button = $Panel/VBoxContainer/HBOXfort/FortitudeButton
@onready var endurance_button: Button = $Panel/VBoxContainer/HBOXend/EnduranceButton
@onready var confirm_button: Button = $Panel/VBoxContainer/ConfirmButton

var player_stats: PlayerStats
var available_points: int = 0

func _ready():
	hide()
	add_to_group("level_up_menu")

func show_menu(player_stats_ref: PlayerStats, points: int):  # ← ДОЛЖНО БЫТЬ ТАК
	print("=== MENU SHOW ===")
	print("До паузы: ", get_tree().paused)
	
	player_stats = player_stats_ref
	available_points = points
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	update_display()
	show()
	
	get_tree().paused = true  # ← Важно: пауза ПОСЛЕ показа меню!
	print("После паузы: ", get_tree().paused)


func update_display():
	if player_stats:
		strength_label.text = "Сила: %d" % player_stats.stats_system.strength
		fortitude_label.text = "Крепость: %d" % player_stats.stats_system.fortitude
		endurance_label.text = "Выносливость: %d" % player_stats.stats_system.endurance
	points_label.text = "Очков: %d" % available_points
	
	# Кнопки активны только если есть очки
	strength_button.disabled = available_points <= 0
	fortitude_button.disabled = available_points <= 0  
	endurance_button.disabled = available_points <= 0
	confirm_button.disabled = available_points > 0

func _on_strength_button_pressed():
	if available_points > 0:
		player_stats.increase_strength()  # ← Используем метод PlayerStats!
		available_points = player_stats.available_points  # ← Обновляем локальную переменную
		update_display()

func _on_fortitude_button_pressed():
	if available_points > 0:
		player_stats.increase_fortitude()  # ← Используем метод PlayerStats!
		available_points = player_stats.available_points
		update_display()

func _on_endurance_button_pressed():
	if available_points > 0:
		player_stats.increase_endurance()  # ← Используем метод PlayerStats!
		available_points = player_stats.available_points  
		update_display()

func _on_confirm_button_pressed():
	print("=== MENU HIDE ===")
	print("До снятия паузы: ", get_tree().paused)
	
	player_stats.available_points = available_points
	hide()
	process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	
	print("После снятия паузы: ", get_tree().paused)
	points_distributed.emit()

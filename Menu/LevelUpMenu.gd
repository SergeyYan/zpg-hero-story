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
@onready var luck_label: Label = $Panel/VBoxContainer/HBOXluck/LuckLable
@onready var luck_button: Button = $Panel/VBoxContainer/HBOXluck/LuckButton
@onready var timer_label: Label = $Panel/VBoxTimer/TimerLabel  # ← Новый лейбл для таймера
@onready var auto_timer: Timer = $Panel/VBoxTimer/AutoDistributeTimer  # ← Новый таймер

var player_stats: PlayerStats
var available_points: int = 0
var time_remaining: int = 30  # ← 30 секунд на выбор

func _ready():
	hide()
	add_to_group("level_up_menu")
	
	if auto_timer:
		auto_timer.timeout.connect(_on_auto_timer_timeout)
	else:
		push_warning("AutoDistributeTimer not found!")

func show_menu(player_stats_ref: PlayerStats, points: int):  # ← ДОЛЖНО БЫТЬ ТАК
	print("=== MENU SHOW ===")
	print("До паузы: ", get_tree().paused)
	
	
	player_stats = player_stats_ref
	available_points = points
	time_remaining = 30  # ← СБРАСЫВАЕМ ТАЙМЕР
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# ← ЗАПУСКАЕМ ТАЙМЕР АВТОРАСПРЕДЕЛЕНИЯ
	if auto_timer:
		auto_timer.start(1.0)
		update_timer_display()
		if timer_label:
			timer_label.visible = true
	
	update_display()
	show()
	
	get_tree().paused = true  # ← Важно: пауза ПОСЛЕ показа меню!
	print("После паузы: ", get_tree().paused)


func update_display():
	if player_stats:
		strength_label.text = "Сила: %d" % player_stats.stats_system.strength
		fortitude_label.text = "Крепость: %d" % player_stats.stats_system.fortitude
		endurance_label.text = "Выносливость: %d" % player_stats.stats_system.endurance
		luck_label.text = "Удача: %d (%.1f%%)" % [player_stats.stats_system.luck, player_stats.stats_system.get_crit_chance() * 100]
	points_label.text = "Очков: %d" % available_points
	
	# ← ОБНОВЛЯЕМ ОТОБРАЖЕНИЕ ТАЙМЕРА
	update_timer_display()
	
	# Кнопки активны только если есть очки
	strength_button.disabled = available_points <= 0
	fortitude_button.disabled = available_points <= 0  
	endurance_button.disabled = available_points <= 0
	luck_button.disabled = available_points <= 0  # ← Новая кнопка
	confirm_button.disabled = available_points > 0


# ← НОВАЯ ФУНКЦИЯ: ОБНОВЛЕНИЕ ТАЙМЕРА
func update_timer_display():
	if timer_label:
		timer_label.text = "Автораспределение через: %d сек" % time_remaining
		if time_remaining <= 10:
			timer_label.modulate = Color(1, 0.5, 0.5)  # ← Краснеет при малом времени
		else:
			timer_label.modulate = Color(1, 1, 1)

# ← НОВАЯ ФУНКЦИЯ: ТАЙМЕР АВТОРАСПРЕДЕЛЕНИЯ
func _on_auto_timer_timeout():
	time_remaining -= 1
	update_timer_display()
	
	if time_remaining <= 0:
		print("Время вышло! Автораспределение характеристик...")
		auto_distribute_points()
		_on_confirm_button_pressed()  # ← Автоподтверждение

# ← НОВАЯ ФУНКЦИЯ: АВТОМАТИЧЕСКОЕ РАСПРЕДЕЛЕНИЕ
func auto_distribute_points():
	if available_points <= 0:
		return
	
	print("Автоматическое случайное распределение ", available_points, " очков...")
	
	# СТРАТЕГИЯ: Выносливость → Сила → Крепость → Удача (по кругу)
	var stats_to_upgrade = ["endurance", "strength", "fortitude", "luck"]
	var current_stat_index = 0
	
	# ← ПОЛНОСТЬЮ СЛУЧАЙНОЕ РАСПРЕДЕЛЕНИЕ
	while available_points > 0:
		var random_stat = randi() % 3  # 0-3
		
		match random_stat:
			0:
				player_stats.increase_strength()
				print("Авто: +1 к Силе (случайно)")
			1:
				player_stats.increase_fortitude()
				print("Авто: +1 к Крепости (случайно)")
			2:
				player_stats.increase_endurance()
				print("Авто: +1 к Выносливости (случайно)")
			#3:
			#	player_stats.increase_luck()
			#	print("Авто: +1 к Удаче (случайно)")
		
		available_points = player_stats.available_points
		update_display()
		
		# ← МАЛЕНЬКАЯ ПАУЗА ДЛЯ ВИЗУАЛЬНОГО ЭФФЕКТА
		await get_tree().create_timer(0.1).timeout



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

func _on_luck_button_pressed():
	if available_points > 0:
		player_stats.increase_luck()
		available_points = player_stats.available_points
		update_display()

func _on_confirm_button_pressed():
	print("=== MENU HIDE ===")
	print("До снятия паузы: ", get_tree().paused)
	
	# ← ОСТАНАВЛИВАЕМ ТАЙМЕР
	if auto_timer:
		auto_timer.stop()
	
	player_stats.available_points = available_points
	hide()
	process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	
	print("После снятия паузы: ", get_tree().paused)
	points_distributed.emit()

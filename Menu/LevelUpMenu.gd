# LevelUpMenu.gd
extends CanvasLayer
class_name LevelUpMenu

signal points_distributed

@onready var strength_label: Label = $Panel/VBoxContainer/HBOXstr/StrengthLabel
@onready var fortitude_label: Label = $Panel/VBoxContainer/HBOXfort/FortitudeLabel
@onready var agility_label: Label = $Panel/VBoxContainer/HBOXagil/AgilityLabel
@onready var endurance_label: Label = $Panel/VBoxContainer/HBOXend/EnduranceLabel
@onready var points_label: Label = $Panel/VBoxContainer/PointsLabel
@onready var strength_button: Button = $Panel/VBoxContainer/HBOXstr/StrengthButton
@onready var fortitude_button: Button = $Panel/VBoxContainer/HBOXfort/FortitudeButton
@onready var agility_button: Button = $Panel/VBoxContainer/HBOXagil/AgilityButton
@onready var endurance_button: Button = $Panel/VBoxContainer/HBOXend/EnduranceButton
@onready var confirm_button: Button = $Panel/VBoxContainer/ConfirmButton
@onready var luck_label: Label = $Panel/VBoxContainer/HBOXluck/LuckLable
@onready var luck_button: Button = $Panel/VBoxContainer/HBOXluck/LuckButton
@onready var timer_label: Label = $Panel/VBoxTimer/TimerLabel
@onready var auto_timer: Timer = $Panel/VBoxTimer/AutoDistributeTimer
@onready var panel: Panel = $Panel
@onready var vbox_container: VBoxContainer = $Panel/VBoxContainer

var is_mobile: bool = false
var screen_size: Vector2

var player_stats: PlayerStats
var available_points: int = 0
var time_remaining: int = 30

func _ready():
	hide()
	add_to_group("level_up_menu")
	
	# Определяем тип устройства
	screen_size = get_viewport().get_visible_rect().size
	is_mobile = screen_size.x < 790
	
	# Делаем панель исключением из паузы
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_set_children_process_mode(panel, Node.PROCESS_MODE_WHEN_PAUSED)
	
	if auto_timer:
		auto_timer.timeout.connect(_on_auto_timer_timeout)
	else:
		push_warning("AutoDistributeTimer not found!")


func _center_panel_left():
	# Размер панели
	var panel_size = Vector2(400, 350) if is_mobile else Vector2(450, 400)
	panel.size = panel_size
	
	# Центрируем с небольшим смещением влево (40% от центра вместо 50%)
	panel.position = Vector2(
		(screen_size.x - panel_size.x) / 2,  # 30% от центра - левее
		(screen_size.y - panel_size.y) / 2   # 40% сверху - немного выше
	)
	
	if vbox_container:
		# Увеличиваем отступ слева, уменьшаем справа
		vbox_container.add_theme_constant_override("margin_left", 40)  # ← БОЛЬШЕ СЛЕВА
		vbox_container.add_theme_constant_override("margin_right", 10) # ← МЕНЬШЕ СПРАВА
	
	print("LevelUpMenu: Позиция панели - ", panel.position)  # ← ДЛЯ ДЕБАГА
	
	# Стиль панели
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.6, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	
	panel.add_theme_stylebox_override("panel", panel_style)

func _set_children_process_mode(node: Node, mode: int):
	for child in node.get_children():
		if child is Control:
			child.process_mode = mode
		_set_children_process_mode(child, mode)

func _disable_menu_button(disabled: bool):
	var menu_button = get_tree().get_first_node_in_group("menu_button")
	if menu_button:
		menu_button.disabled = disabled
		if disabled:
			menu_button.modulate = Color(1, 1, 1, 0.5)
		else:
			menu_button.modulate = Color(1, 1, 1, 1)

func show_menu(player_stats_ref: PlayerStats, points: int):
	if GameState.is_loading or points <= 0:
		return
	
	# Обновляем размеры перед показом
	screen_size = get_viewport().get_visible_rect().size
	is_mobile = screen_size.x < 790
	
	# ← ЦЕНТРИРУЕМ ЗДЕСЬ ПРИ КАЖДОМ ПОКАЗЕ
	_center_panel_left()
	
	# Уведомляем devpanel что levelupmenu открыт
	var dev_panels = get_tree().get_nodes_in_group("dev_panel")
	for dev_panel in dev_panels:
		if dev_panel.has_method("on_level_up_menu_opened"):
			dev_panel.on_level_up_menu_opened()
	
	player_stats = player_stats_ref
	available_points = points
	time_remaining = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Отключаем кнопку меню
	_disable_menu_button(true)
	
	if auto_timer:
		auto_timer.start(1.0)
		update_timer_display()
		if timer_label:
			timer_label.visible = true
	
	update_display()
	show()
	
	get_tree().paused = true

func update_display():
	if player_stats:
		# Полные названия характеристик
		strength_label.text = "Сила: %d" % player_stats.stats_system.strength
		fortitude_label.text = "Крепость: %d" % player_stats.stats_system.fortitude
		agility_label.text = "Ловкость: %d" % player_stats.stats_system.agility
		endurance_label.text = "Выносливость: %d" % player_stats.stats_system.endurance
		luck_label.text = "Удача: %d" % player_stats.stats_system.luck
	
	points_label.text = "Очков: %d" % available_points
	
	update_timer_display()
	
	strength_button.disabled = available_points <= 0
	fortitude_button.disabled = available_points <= 0
	agility_button.disabled = available_points <= 0  
	endurance_button.disabled = available_points <= 0
	luck_button.disabled = available_points <= 0
	confirm_button.disabled = available_points > 0

func update_timer_display():
	if timer_label:
		timer_label.text = "Автораспределение через: %d сек" % time_remaining
		if time_remaining <= 10:
			timer_label.modulate = Color(1, 0.5, 0.5)
		else:
			timer_label.modulate = Color(1, 1, 1)

func _on_auto_timer_timeout():
	time_remaining -= 1
	update_timer_display()
	
	if time_remaining <= 0:
		auto_distribute_points()
		_on_confirm_button_pressed()

func auto_distribute_points():
	if available_points <= 0:
		return

	var stats_to_upgrade = ["endurance", "strength", "fortitude","agility" ,"luck"]
	var current_stat_index = 0
	
	while available_points > 0:
		var random_stat = randi() % 4
		
		match random_stat:
			0:
				player_stats.increase_strength()
			1:
				player_stats.increase_fortitude()
			2: 
				player_stats.increase_agility()
			3:
				player_stats.increase_endurance()
		
		available_points = player_stats.available_points
		update_display()
		
		await get_tree().create_timer(0.1).timeout

func _on_strength_button_pressed():
	if available_points > 0:
		player_stats.increase_strength()
		available_points = player_stats.available_points
		update_display()

func _on_fortitude_button_pressed():
	if available_points > 0:
		player_stats.increase_fortitude()
		available_points = player_stats.available_points
		update_display()

func _on_endurance_button_pressed():
	if available_points > 0:
		player_stats.increase_endurance()
		available_points = player_stats.available_points
		update_display()

func _on_agility_button_pressed() -> void:
	if available_points > 0:
		player_stats.increase_agility()
		available_points = player_stats.available_points
		update_display()

func _on_luck_button_pressed():
	if available_points > 0:
		player_stats.increase_luck()
		available_points = player_stats.available_points
		update_display()

func _on_confirm_button_pressed():
	if auto_timer:
		auto_timer.stop()
	
	var dev_panels = get_tree().get_nodes_in_group("dev_panel")
	for dev_panel in dev_panels:
		if dev_panel.has_method("on_level_up_menu_closed"):
			dev_panel.on_level_up_menu_closed()
	
	# Включаем кнопку меню
	_disable_menu_button(false)
	
	player_stats.available_points = available_points
	hide()
	process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	
	points_distributed.emit()

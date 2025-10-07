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
# ← НОВЫЕ НОДЫ ДЛЯ ВЫБОРА СТРАТЕГИИ
@onready var strategy_container: HBoxContainer = $Panel/StrategyContainer
@onready var warrior_button: Button = $Panel/StrategyContainer/WarriorButton
@onready var assassin_button: Button = $Panel/StrategyContainer/AssassinButton
@onready var tank_button: Button = $Panel/StrategyContainer/TankButton
@onready var strategy_timer_label: Label = $Panel/StrategyTimerLabel

var is_mobile: bool = false
var screen_size: Vector2

var player_stats: PlayerStats
var available_points: int = 0
var time_remaining: int = 30

# ← НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ СТРАТЕГИИ
var selected_strategy: String = ""  # "warrior", "assassin", "tank", ""
var is_first_time: bool = true
var distribution_count: int = 0  # Счётчик распределений
var strategy_time_remaining: int = 30  # Таймер выбора стратегии
var strategy_timer: Timer  # ← ОТДЕЛЬНЫЙ ТАЙМЕР ДЛЯ СТРАТЕГИИ
var signals_connected: bool = false  # ← ФЛАГ ПОДКЛЮЧЕНИЯ СИГНАЛОВ

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
	
	# ← ПОДКЛЮЧАЕМ СИГНАЛЫ КНОПОК СТРАТЕГИИ (ОДИН РАЗ)
	_connect_strategy_signals()

func _connect_strategy_signals():
	if signals_connected:
		return  # ← УЖЕ ПОДКЛЮЧЕНЫ
	
	if warrior_button and not warrior_button.pressed.is_connected(_on_warrior_button_pressed):
		warrior_button.pressed.connect(_on_warrior_button_pressed)
	if assassin_button and not assassin_button.pressed.is_connected(_on_assassin_button_pressed):
		assassin_button.pressed.connect(_on_assassin_button_pressed)
	if tank_button and not tank_button.pressed.is_connected(_on_tank_button_pressed):
		tank_button.pressed.connect(_on_tank_button_pressed)
	
	signals_connected = true

func _center_panel_left():
	# Увеличиваем высоту панели для кнопок стратегии
	var panel_size = Vector2(400, 450) if is_mobile else Vector2(450, 500)
	panel.size = panel_size
	
	# Центрируем с небольшим смещением влево
	panel.position = Vector2(
		(screen_size.x - panel_size.x) / 2,
		(screen_size.y - panel_size.y) / 2
	)
	
	if vbox_container:
		# Увеличиваем отступ слева, уменьшаем справа
		vbox_container.add_theme_constant_override("margin_left", 40)
		vbox_container.add_theme_constant_override("margin_right", 10)
	
	# ← НАСТРАИВАЕМ КОНТЕЙНЕР СТРАТЕГИИ
	if strategy_container:
		if is_mobile:
			strategy_container.add_theme_constant_override("separation", 5)
		else:
			strategy_container.add_theme_constant_override("separation", 10)
	
	print("LevelUpMenu: Позиция панели - ", panel.position)
	
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
	
	# Центрируем при каждом показе
	_center_panel_left()
	
	# Уведомляем devpanel что levelupmenu открыт
	var dev_panels = get_tree().get_nodes_in_group("dev_panel")
	for dev_panel in dev_panels:
		if dev_panel.has_method("on_level_up_menu_opened"):
			dev_panel.on_level_up_menu_opened()
	
	player_stats = player_stats_ref
	available_points = points
	time_remaining = 30
	strategy_time_remaining = 30  # ← СБРАСЫВАЕМ ТАЙМЕР СТРАТЕГИИ
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Отключаем кнопку меню
	_disable_menu_button(true)
	
	# ← УПРАВЛЕНИЕ ВИДИМОСТЬЮ КНОПОК СТРАТЕГИИ И ХАРАКТЕРИСТИК
	if strategy_container:
		if is_first_time:
			# Первый показ - показываем выбор стратегии
			strategy_container.visible = true
			if strategy_timer_label:
				strategy_timer_label.visible = true
				strategy_timer_label.text = "Выбор стратегии: %d сек" % strategy_time_remaining
				strategy_timer_label.modulate = Color(1, 1, 1)
			
			# ← СКРЫВАЕМ ВСЕ ЭЛЕМЕНТЫ РАСПРЕДЕЛЕНИЯ ХАРАКТЕРИСТИК
			_set_distribution_elements_visible(false)
			
			# Останавливаем основной таймер распределения
			if auto_timer:
				auto_timer.stop()
			# Запускаем таймер выбора стратегии
			_start_strategy_timer()
		else:
			# Не первый показ - скрываем выбор стратегии
			strategy_container.visible = false
			if strategy_timer_label:
				strategy_timer_label.visible = false
			
			# ← ПОКАЗЫВАЕМ ЭЛЕМЕНТЫ РАСПРЕДЕЛЕНИЯ ХАРАКТЕРИСТИК
			_set_distribution_elements_visible(true)
			
			# Запускаем основной таймер распределения
			if auto_timer:
				auto_timer.start(1.0)
	
	update_display()
	show()
	
	get_tree().paused = true

# ← НОВАЯ ФУНКЦИЯ: УПРАВЛЕНИЕ ВИДИМОСТЬЮ ВСЕХ ЭЛЕМЕНТОВ РАСПРЕДЕЛЕНИЯ
func _set_distribution_elements_visible(visible: bool):
	# Скрываем/показываем все элементы VBoxContainer (характеристики)
	if vbox_container:
		vbox_container.visible = visible
	
	# Скрываем/показываем таймер распределения
	if timer_label:
		timer_label.visible = visible

# ← НОВАЯ ФУНКЦИЯ: ЗАПУСК ТАЙМЕРА ВЫБОРА СТРАТЕГИИ
func _start_strategy_timer():
	# Останавливаем старый таймер если есть
	if strategy_timer and strategy_timer.timeout.is_connected(_on_strategy_timer_timeout):
		strategy_timer.stop()
		strategy_timer.timeout.disconnect(_on_strategy_timer_timeout)
		strategy_timer.queue_free()
	
	# Создаем новый таймер для выбора стратегии
	strategy_timer = Timer.new()
	add_child(strategy_timer)
	strategy_timer.one_shot = false
	strategy_timer.timeout.connect(_on_strategy_timer_timeout)
	strategy_timer.start(1.0)

# ← НОВАЯ ФУНКЦИЯ: ОБРАБОТКА ТАЙМЕРА СТРАТЕГИИ
func _on_strategy_timer_timeout():
	if not is_first_time or selected_strategy != "":
		return  # Уже выбрана стратегия или не первый раз
	
	strategy_time_remaining -= 1
	
	if strategy_timer_label:
		strategy_timer_label.text = "Выбор стратегии: %d сек" % strategy_time_remaining
		if strategy_time_remaining <= 10:
			strategy_timer_label.modulate = Color(1, 0.5, 0.5)
		else:
			strategy_timer_label.modulate = Color(1, 1, 1)
	
	if strategy_time_remaining <= 0:
		# Время вышло - автоматически закрываем выбор стратегии
		print("Время выбора стратегии истекло - будет случайное распределение")
		_finalize_strategy_selection()

# ← СТАРАЯ ФУНКЦИЯ (ОСТАВЛЯЕМ ДЛЯ СОВМЕСТИМОСТИ)
func _set_distribution_buttons_visible(visible: bool):
	strength_button.visible = visible
	fortitude_button.visible = visible
	agility_button.visible = visible
	endurance_button.visible = visible
	luck_button.visible = visible
	confirm_button.visible = visible
	points_label.visible = visible
	timer_label.visible = visible

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
	if timer_label and timer_label.visible:
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
	
	distribution_count += 1
	
	# ← ЛОГИКА АВТОРАСПРЕДЕЛЕНИЯ ПО СТРАТЕГИИ
	if selected_strategy == "":
		# Случайное распределение по всем 5 характеристикам
		_random_distribute_all()
	elif distribution_count % 2 == 1:
		# Каждое первое распределение - случайное
		_random_distribute_all()
	else:
		# Каждое второе распределение - по стратегии
		_strategy_distribute()

# ← НОВАЯ ФУНКЦИЯ: СЛУЧАЙНОЕ РАСПРЕДЕЛЕНИЕ ПО ВСЕМ ХАРАКТЕРИСТИКАМ
func _random_distribute_all():
	while available_points > 0:
		var random_stat = randi() % 5  # 0-4 для всех 5 характеристик
		
		match random_stat:
			0:
				player_stats.increase_strength()
			1:
				player_stats.increase_fortitude()
			2: 
				player_stats.increase_agility()
			3:
				player_stats.increase_endurance()
			4:
				player_stats.increase_luck()
		
		available_points = player_stats.available_points
		update_display()
		
		await get_tree().create_timer(0.1).timeout

# ← НОВАЯ ФУНКЦИЯ: РАСПРЕДЕЛЕНИЕ ПО СТРАТЕГИИ
func _strategy_distribute():
	while available_points > 0:
		var random_stat: int
		
		match selected_strategy:
			"warrior":
				# Воин: сила, выносливость, удача
				random_stat = randi() % 3
				match random_stat:
					0: player_stats.increase_strength()
					1: player_stats.increase_endurance()
					2: player_stats.increase_luck()
			
			"assassin":
				# Ассасин: ловкость, выносливость, удача
				random_stat = randi() % 3
				match random_stat:
					0: player_stats.increase_agility()
					1: player_stats.increase_endurance()
					2: player_stats.increase_luck()
			
			"tank":
				# Танк: сила, выносливость, крепость
				random_stat = randi() % 3
				match random_stat:
					0: player_stats.increase_strength()
					1: player_stats.increase_endurance()
					2: player_stats.increase_fortitude()
		
		available_points = player_stats.available_points
		update_display()
		
		await get_tree().create_timer(0.1).timeout

# ← НОВЫЕ ФУНКЦИИ ДЛЯ КНОПОК СТРАТЕГИИ
func _on_warrior_button_pressed():
	selected_strategy = "warrior"
	_finalize_strategy_selection()
	print("Выбрана стратегия: Воин")

func _on_assassin_button_pressed():
	selected_strategy = "assassin"
	_finalize_strategy_selection()
	print("Выбрана стратегия: Ассасин")

func _on_tank_button_pressed():
	selected_strategy = "tank"
	_finalize_strategy_selection()
	print("Выбрана стратегия: Танк")

# ← ОБНОВЛЕННАЯ ФУНКЦИЯ: ЗАВЕРШЕНИЕ ВЫБОРА СТРАТЕГИИ
func _finalize_strategy_selection():
	is_first_time = false
	strategy_container.visible = false
	if strategy_timer_label:
		strategy_timer_label.visible = false
	
	# ← ПОКАЗЫВАЕМ ВСЕ ЭЛЕМЕНТЫ РАСПРЕДЕЛЕНИЯ ХАРАКТЕРИСТИК
	_set_distribution_elements_visible(true)
	
	# Останавливаем таймер стратегии
	if strategy_timer and strategy_timer.timeout.is_connected(_on_strategy_timer_timeout):
		strategy_timer.stop()
		strategy_timer.timeout.disconnect(_on_strategy_timer_timeout)
		strategy_timer.queue_free()
	
	# Запускаем основной таймер распределения
	if auto_timer:
		auto_timer.start(1.0)

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
	# Останавливаем оба таймера
	if auto_timer:
		auto_timer.stop()
	if strategy_timer and strategy_timer.timeout.is_connected(_on_strategy_timer_timeout):
		strategy_timer.stop()
		strategy_timer.timeout.disconnect(_on_strategy_timer_timeout)
		strategy_timer.queue_free()
	
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

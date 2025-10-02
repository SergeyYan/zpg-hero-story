# LevelUpMenu.gd
extends CanvasLayer
class_name LevelUpMenu

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
@onready var timer_label: Label = $Panel/VBoxTimer/TimerLabel
@onready var auto_timer: Timer = $Panel/VBoxTimer/AutoDistributeTimer
@onready var panel: Panel = $Panel
@onready var vbox_container: VBoxContainer = $Panel/VBoxContainer

# ← НАСТРОЙКИ ВЫРАВНИВАНИЯ
var is_mobile: bool = false
var is_small_mobile: bool = false
var screen_size: Vector2
var base_font_size: int = 14

var player_stats: PlayerStats
var available_points: int = 0
var time_remaining: int = 30

func _ready():
	hide()
	add_to_group("level_up_menu")
	
	# ← ЦЕНТРИРОВАНИЕ ПАНЕЛИ
	_setup_panel_alignment()
	
	# ← ОПРЕДЕЛЯЕМ ТИП УСТРОЙСТВА
	_detect_device_type()
	
	# ← НАСТРАИВАЕМ АДАПТИВНЫЙ ИНТЕРФЕЙС
	_setup_responsive_ui()
	
	# ← ДЕЛАЕМ ПАНЕЛЬ ИСКЛЮЧЕНИЕМ ИЗ ПАУЗЫ
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_set_children_process_mode(panel, Node.PROCESS_MODE_WHEN_PAUSED)
	
	if auto_timer:
		auto_timer.timeout.connect(_on_auto_timer_timeout)
	else:
		push_warning("AutoDistributeTimer not found!")
	
	# ← ПОДПИСЫВАЕМСЯ НА ИЗМЕНЕНИЕ РАЗМЕРА ЭКРАНА
	get_viewport().size_changed.connect(_on_viewport_size_changed)

# ← НОВАЯ ФУНКЦИЯ: НАСТРОЙКА ВЫРАВНИВАНИЯ ПАНЕЛИ
func _setup_panel_alignment():
	# Устанавливаем якоря для центрирования
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	# Смещаем pivot в центр для правильного центрирования
	panel.pivot_offset = Vector2(panel.size.x / 2, panel.size.y / 2)

func _detect_device_type():
	screen_size = get_viewport().get_visible_rect().size
	print("LevelUpMenu: Размер экрана: ", screen_size)
	
	var aspect_ratio = screen_size.x / screen_size.y
	is_mobile = screen_size.x < 600 or aspect_ratio < 1.2
	is_small_mobile = screen_size.x < 400
	
	if is_small_mobile:
		print("LevelUpMenu: обнаружено очень маленькое мобильное устройство")
		base_font_size = 12
	elif is_mobile:
		print("LevelUpMenu: обнаружено мобильное устройство")
		base_font_size = 14
	else:
		print("LevelUpMenu: обнаружено десктоп/планшет устройство")
		base_font_size = 16

func _setup_responsive_ui():
	print("LevelUpMenu: Настройка адаптивного интерфейса")
	
	# Настраиваем размеры панели в зависимости от устройства
	if is_small_mobile:
		_setup_small_mobile_layout()
	elif is_mobile:
		_setup_mobile_layout()
	else:
		_setup_desktop_layout()
	
	# Обновляем шрифты
	_update_font_sizes()
	
	# ← НАСТРАИВАЕМ КНОПКИ ДЛЯ МОБИЛЬНЫХ УСТРОЙСТВ
	_setup_mobile_buttons()
	
	# ← ВЫРАВНИВАЕМ ЭЛЕМЕНТЫ ПО ЦЕНТРУ
	_center_elements()

# ← НОВАЯ ФУНКЦИЯ: ВЫРАВНИВАНИЕ ЭЛЕМЕНТОВ ПО ЦЕНТРУ
func _center_elements():
	# Центрируем VBoxContainer внутри панели
	if vbox_container:
		vbox_container.anchor_left = 0.5
		vbox_container.anchor_right = 0.5
		vbox_container.anchor_top = 0.5
		vbox_container.anchor_bottom = 0.5
		vbox_container.pivot_offset = Vector2(vbox_container.size.x / 2, vbox_container.size.y / 2)
		
		# Устанавливаем выравнивание для всех элементов
		vbox_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Центрируем текст в лейблах
	var labels = [strength_label, fortitude_label, endurance_label, points_label, luck_label, timer_label]
	for label in labels:
		if label:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# ← ИСПРАВЛЕНИЕ: Для кнопок используем theme_override вместо прямого доступа
	_setup_buttons_alignment()

# ← НОВАЯ ФУНКЦИЯ: ВЫРАВНИВАНИЕ ТЕКСТА В КНОПКАХ
func _setup_buttons_alignment():
	var buttons = [strength_button, fortitude_button, endurance_button, luck_button, confirm_button]
	
	for button in buttons:
		if button:
			# Для кнопок используем theme_override для выравнивания текста
			button.add_theme_constant_override("h_separation", 0)
			
			# Центрируем саму кнопку в контейнере
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			
			# Создаем стиль для центрирования текста в кнопках
			var button_style = StyleBoxFlat.new()
			button_style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
			button_style.border_color = Color(0.4, 0.4, 0.6, 1.0)
			button_style.border_width_left = 2
			button_style.border_width_top = 2
			button_style.border_width_right = 2
			button_style.border_width_bottom = 2
			button_style.corner_radius_top_left = 6
			button_style.corner_radius_top_right = 6
			button_style.corner_radius_bottom_left = 6
			button_style.corner_radius_bottom_right = 6
			
			button.add_theme_stylebox_override("normal", button_style)
			
			# Стиль для нажатой кнопки
			var pressed_style = button_style.duplicate()
			pressed_style.bg_color = Color(0.3, 0.3, 0.4, 0.9)
			button.add_theme_stylebox_override("pressed", pressed_style)
			
			# Стиль для отключенной кнопки
			var disabled_style = button_style.duplicate()
			disabled_style.bg_color = Color(0.1, 0.1, 0.2, 0.5)
			disabled_style.border_color = Color(0.2, 0.2, 0.3, 0.7)
			button.add_theme_stylebox_override("disabled", disabled_style)

func _setup_mobile_buttons():
	if not is_mobile:
		return
	
	# Получаем все HBox контейнеры с кнопками
	var hbox_str = $Panel/VBoxContainer/HBOXstr
	var hbox_fort = $Panel/VBoxContainer/HBOXfort
	var hbox_end = $Panel/VBoxContainer/HBOXend
	var hbox_luck = $Panel/VBoxContainer/HBOXluck
	
	var hboxes = [hbox_str, hbox_fort, hbox_end, hbox_luck]
	
	# Настраиваем компактные размеры кнопок для мобильных
	var button_width = 70 if is_small_mobile else 80
	var button_height = 30 if is_small_mobile else 35
	
	# Настраиваем размеры лейблов
	var label_font_size = base_font_size - 2 if is_small_mobile else base_font_size - 1
	
	for hbox in hboxes:
		if hbox:
			# Находим лейбл и кнопку в HBox
			var label = null
			var button = null
			for child in hbox.get_children():
				if child is Label:
					label = child
				elif child is Button:
					button = child
			
			if label:
				label.add_theme_font_size_override("font_size", label_font_size)
				# Устанавливаем фиксированную ширину для лейбла и центрируем
				label.custom_minimum_size = Vector2(120 if is_small_mobile else 140, 0)
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			# Настраиваем кнопку
			if button:
				button.custom_minimum_size = Vector2(button_width, button_height)
				button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			
			# Центрируем HBox
			hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			hbox.add_theme_constant_override("separation", 8)

func _setup_small_mobile_layout():
	print("LevelUpMenu: Установка компактной мобильной компоновки")
	
	# Панель компактнее и центрирована
	panel.size = Vector2(screen_size.x * 0.95, screen_size.y * 0.8)
	panel.position = Vector2(
		(screen_size.x - panel.size.x) / 2,  # ← ЦЕНТРИРУЕМ ПО ГОРИЗОНТАЛИ
		screen_size.y * 0.1                  # ← СДВИГ ВВЕРХ (10% от верхнего края)
	)
	
	_setup_panel_style()
	_adjust_vbox_layout()

func _setup_mobile_layout():
	print("LevelUpMenu: Установка мобильной компоновки")
	
	# Панель компактнее и центрирована
	panel.size = Vector2(screen_size.x * 0.92, screen_size.y * 0.75)
	panel.position = Vector2(
		(screen_size.x - panel.size.x) / 2,  # ← ЦЕНТРИРУЕМ ПО ГОРИЗОНТАЛИ
		screen_size.y * 0.12                 # ← СДВИГ ВВЕРХ (12% от верхнего края)
	)
	
	_setup_panel_style()
	_adjust_vbox_layout()

func _setup_desktop_layout():
	print("LevelUpMenu: Установка десктопной компоновки")
	
	# Фиксированный размер для десктопа
	panel.size = Vector2(500, 400)
	panel.position = Vector2(
		(screen_size.x - 500) / 2,  # ← ЦЕНТРИРУЕМ
		(screen_size.y - 400) / 2   # ← ЦЕНТРИРУЕМ
	)
	
	_setup_panel_style()

func _adjust_vbox_layout():
	if not is_mobile or not vbox_container:
		return
	
	# Уменьшаем отступы в VBox для мобильных
	var vbox_separation = 8 if is_small_mobile else 10
	vbox_container.add_theme_constant_override("separation", vbox_separation)
	
	# ← РАВНОМЕРНЫЕ ОТСТУПЫ ПО БОКАМ ДЛЯ ЦЕНТРИРОВАНИЯ
	var margin_horizontal = 15 if is_small_mobile else 20
	vbox_container.add_theme_constant_override("margin_left", margin_horizontal)
	vbox_container.add_theme_constant_override("margin_right", margin_horizontal)
	
	# Добавляем отступ сверху для сдвига вверх
	var margin_top = 10 if is_small_mobile else 15
	vbox_container.add_theme_constant_override("margin_top", margin_top)

func _setup_panel_style():
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 0.98)
	panel_style.border_color = Color(0.4, 0.4, 0.6, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 16
	panel_style.shadow_offset = Vector2(6, 6)
	
	panel.add_theme_stylebox_override("panel", panel_style)

func _update_font_sizes():
	var labels = [
		strength_label, fortitude_label, endurance_label, 
		points_label, luck_label, timer_label
	]
	
	for label in labels:
		if label:
			label.add_theme_font_size_override("font_size", base_font_size)
	
	# Кнопки с немного меньшим шрифтом
	var buttons = [
		strength_button, fortitude_button, endurance_button,
		luck_button, confirm_button
	]
	
	var button_font_size = base_font_size - 2 if is_mobile else base_font_size - 1
	for button in buttons:
		if button:
			button.add_theme_font_size_override("font_size", button_font_size)
			
	# Настраиваем размеры кнопок для десктопа
	if not is_mobile:
		var button_width = 140
		var button_height = 45
		
		for button in buttons:
			if button:
				button.custom_minimum_size = Vector2(button_width, button_height)
				button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

# ... остальные функции остаются без изменений ...

func _on_viewport_size_changed():
	print("LevelUpMenu: Размер экрана изменился")
	_detect_device_type()
	_setup_responsive_ui()

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
	
	# ← ОБНОВЛЯЕМ РАЗМЕРЫ ПЕРЕД ПОКАЗОМ
	_detect_device_type()
	_setup_responsive_ui()
	
	# ← УВЕДОМЛЯЕМ DEVPANEL ЧТО LEVELUPMENU ОТКРЫТ
	var dev_panels = get_tree().get_nodes_in_group("dev_panel")
	for dev_panel in dev_panels:
		if dev_panel.has_method("on_level_up_menu_opened"):
			dev_panel.on_level_up_menu_opened()
	
	player_stats = player_stats_ref
	available_points = points
	time_remaining = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# ← ОТКЛЮЧАЕМ КНОПКУ МЕНЮ
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
		if is_mobile:
			strength_label.text = "Сила: %d" % player_stats.stats_system.strength
			fortitude_label.text = "Крепость: %d" % player_stats.stats_system.fortitude
			endurance_label.text = "Выносливость: %d" % player_stats.stats_system.endurance
			luck_label.text = "Удача: %d" % player_stats.stats_system.luck
		else:
			strength_label.text = "Сила: %d" % player_stats.stats_system.strength
			fortitude_label.text = "Крепость: %d" % player_stats.stats_system.fortitude
			endurance_label.text = "Выносливость: %d" % player_stats.stats_system.endurance
			luck_label.text = "Удача: %d (%.1f%%)" % [player_stats.stats_system.luck, player_stats.stats_system.get_crit_chance() * 100]
	
	points_label.text = "Очков: %d" % available_points
	
	update_timer_display()
	
	strength_button.disabled = available_points <= 0
	fortitude_button.disabled = available_points <= 0  
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

	var stats_to_upgrade = ["endurance", "strength", "fortitude", "luck"]
	var current_stat_index = 0
	
	while available_points > 0:
		var random_stat = randi() % 3
		
		match random_stat:
			0:
				player_stats.increase_strength()
			1:
				player_stats.increase_fortitude()
			2:
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
	
	# ← ВКЛЮЧАЕМ КНОПКУ МЕНЮ
	_disable_menu_button(false)
	
	player_stats.available_points = available_points
	hide()
	process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	
	points_distributed.emit()

# DevPanel.gd
extends CanvasLayer

@onready var dev_panel: Panel = $DevPanel
@onready var status_grid: GridContainer = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/StatusSection/StatusGrid
@onready var strength_spin: SpinBox = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/StatsContainer/StrengthSpin
@onready var fortitude_spin: SpinBox = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/StatsContainer/FortitudeSpin
@onready var agility_spin: SpinBox = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/StatsContainer/AgilitySpin
@onready var endurance_spin: SpinBox = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/StatsContainer/EnduranceSpin
@onready var luck_spin: SpinBox = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/StatsContainer/LuckSpin
@onready var apply_stats_button: Button = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/StatsContainer/ApplyStatsButton
@onready var heal_button: Button = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/ActionsContainer/HealButton
@onready var level_up_button: Button = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/ActionsContainer/LevelUpButton
@onready var add_exp_button: Button = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/ActionsContainer/AddExpButton
@onready var close_button: Button = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/CloseButton
@onready var scroll_container: ScrollContainer = $DevPanel/MarginContainer/ScrollContainer
@onready var main_vbox: VBoxContainer = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer

# ← НОВЫЕ ССЫЛКИ
@onready var stats_container: GridContainer = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/StatsContainer
@onready var actions_container: HBoxContainer = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/ActionsContainer
@onready var status_section: VBoxContainer = $DevPanel/MarginContainer/ScrollContainer/VBoxContainer/StatusSection

var player_stats: PlayerStats
var secret_code: Array[String] = ["K", "O", "D"]
var current_input: Array[String] = []
var all_status_ids: Array[String] = []
var signals_connected: bool = false
var level_up_menu_open: bool = false

# ← НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ АДАПТИВНОСТИ
var is_mobile: bool = false
var screen_size: Vector2
var base_font_size: int = 12
var status_buttons: Dictionary = {}  # ← Храним ссылки на кнопки статусов

func _ready():
	# ← НАСТРАИВАЕМ ВНЕШНИЙ ВИД ПАНЕЛИ
	_setup_panel_style()
	
	# ← ОПРЕДЕЛЯЕМ ТИП УСТРОЙСТВА
	_detect_device_type()
	
	# ← УСТАНАВЛИВАЕМ ПРАВИЛЬНЫЙ Z_INDEX ДЛЯ ПАНЕЛИ
	dev_panel.z_index = 1000
	self.layer = 1000
	
	dev_panel.visible = false
	
	# ← ДЕЛАЕМ ВСЕ ЭЛЕМЕНТЫ ИСКЛЮЧЕНИЯМИ ИЗ ПАУЗЫ
	dev_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_set_children_process_mode(dev_panel, Node.PROCESS_MODE_WHEN_PAUSED)
	
	# ← ПОДПИСЫВАЕМСЯ НА ИЗМЕНЕНИЕ РАЗМЕРА ЭКРАНА
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# ← НАСТРАИВАЕМ РАЗМЕРЫ ПАНЕЛИ В ЗАВИСИМОСТИ ОТ УСТРОЙСТВА
	_setup_panel_size()
	
	# ← СОЗДАЕМ СПИСОК СТАТУСОВ
	_create_status_grid()
	
	# ← НАСТРАИВАЕМ АДАПТИВНЫЙ ИНТЕРФЕЙС
	_setup_responsive_ui()
	
	if not signals_connected:
		_connect_signals()
		signals_connected = true
	
	add_to_group("dev_panel")

# ← НОВАЯ ФУНКЦИЯ: НАСТРОЙКА СТИЛЯ ПАНЕЛИ
func _setup_panel_style():
	# Создаем стиль для панели с темным фоном
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.98)  # Темный фон с минимальной прозрачностью
	panel_style.border_color = Color(0.4, 0.4, 0.4, 1.0)  # Светлая граница
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.shadow_color = Color(0, 0, 0, 0.6)  # Тень
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(4, 4)
	
	# Применяем стиль к панели
	dev_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Настраиваем стиль для кнопок
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	button_style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	button_style.border_width_left = 1
	button_style.border_width_top = 1
	button_style.border_width_right = 1
	button_style.border_width_bottom = 1
	button_style.corner_radius_top_left = 6
	button_style.corner_radius_top_right = 6
	button_style.corner_radius_bottom_right = 6
	button_style.corner_radius_bottom_left = 6
	
	# Применяем стиль к кнопкам
	apply_stats_button.add_theme_stylebox_override("normal", button_style)
	heal_button.add_theme_stylebox_override("normal", button_style)
	level_up_button.add_theme_stylebox_override("normal", button_style)
	add_exp_button.add_theme_stylebox_override("normal", button_style)
	close_button.add_theme_stylebox_override("normal", button_style)
	
	# Стиль для наведенной кнопки
	var button_hover_style = button_style.duplicate()
	button_hover_style.bg_color = Color(0.3, 0.3, 0.3, 1.0)
	button_hover_style.border_color = Color(0.6, 0.6, 0.6, 1.0)
	
	apply_stats_button.add_theme_stylebox_override("hover", button_hover_style)
	heal_button.add_theme_stylebox_override("hover", button_hover_style)
	level_up_button.add_theme_stylebox_override("hover", button_hover_style)
	add_exp_button.add_theme_stylebox_override("hover", button_hover_style)
	close_button.add_theme_stylebox_override("hover", button_hover_style)
	
	# Стиль для нажатой кнопки
	var button_pressed_style = button_style.duplicate()
	button_pressed_style.bg_color = Color(0.4, 0.4, 0.4, 1.0)
	button_pressed_style.border_color = Color(0.7, 0.7, 0.7, 1.0)
	
	apply_stats_button.add_theme_stylebox_override("pressed", button_pressed_style)
	heal_button.add_theme_stylebox_override("pressed", button_pressed_style)
	level_up_button.add_theme_stylebox_override("pressed", button_pressed_style)
	add_exp_button.add_theme_stylebox_override("pressed", button_pressed_style)
	close_button.add_theme_stylebox_override("pressed", button_pressed_style)
	
	# Настраиваем цвет текста для лучшей читаемости
	var font_color = Color(0.9, 0.9, 0.9, 1.0)  # Светлый текст
	apply_stats_button.add_theme_color_override("font_color", font_color)
	heal_button.add_theme_color_override("font_color", font_color)
	level_up_button.add_theme_color_override("font_color", font_color)
	add_exp_button.add_theme_color_override("font_color", font_color)
	close_button.add_theme_color_override("font_color", font_color)
	
	# Настраиваем стиль для SpinBox
	var spinbox_style = StyleBoxFlat.new()
	spinbox_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	spinbox_style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	spinbox_style.border_width_left = 1
	spinbox_style.border_width_top = 1
	spinbox_style.border_width_right = 1
	spinbox_style.border_width_bottom = 1
	spinbox_style.corner_radius_top_left = 4
	spinbox_style.corner_radius_top_right = 4
	spinbox_style.corner_radius_bottom_right = 4
	spinbox_style.corner_radius_bottom_left = 4
	
	strength_spin.get_line_edit().add_theme_stylebox_override("normal", spinbox_style)
	fortitude_spin.get_line_edit().add_theme_stylebox_override("normal", spinbox_style)
	agility_spin.get_line_edit().add_theme_stylebox_override("normal", spinbox_style)
	endurance_spin.get_line_edit().add_theme_stylebox_override("normal", spinbox_style)
	luck_spin.get_line_edit().add_theme_stylebox_override("normal", spinbox_style)
	
	# Цвет текста в SpinBox
	var spinbox_font_color = Color(1.0, 1.0, 1.0, 1.0)
	strength_spin.get_line_edit().add_theme_color_override("font_color", spinbox_font_color)
	fortitude_spin.get_line_edit().add_theme_color_override("font_color", spinbox_font_color)
	agility_spin.get_line_edit().add_theme_color_override("font_color", spinbox_font_color)
	endurance_spin.get_line_edit().add_theme_color_override("font_color", spinbox_font_color)
	luck_spin.get_line_edit().add_theme_color_override("font_color", spinbox_font_color)
	
	# Настраиваем стиль для CheckBox (статусы)
	var checkbox_style = StyleBoxFlat.new()
	checkbox_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	checkbox_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	checkbox_style.border_width_left = 1
	checkbox_style.border_width_top = 1
	checkbox_style.border_width_right = 1
	checkbox_style.border_width_bottom = 1
	checkbox_style.corner_radius_top_left = 4
	checkbox_style.corner_radius_top_right = 4
	checkbox_style.corner_radius_bottom_right = 4
	checkbox_style.corner_radius_bottom_left = 4

# ← ФУНКЦИЯ СОЗДАНИЯ СЕТКИ СТАТУСОВ
func _create_status_grid():
	# Очищаем сетку
	for child in status_grid.get_children():
		child.queue_free()
	status_buttons.clear()
	
	# Словарь emoji для статусов
	var status_emojis = {
		"well_fed": "🍖", "good_shoes": "👟", "inspired": "💡",
		"adrenaline": "⚡", "lucky_day": "🍀", "potion_splash": "🧴",
		"strange_mushroom": "🍄", "cloak_tent": "👻", "mage_potion": "⚗️",
		"phoenix_feather": "🔥", "thinker": "🤔", "sore_knees": "🦵",
		"crying": "😢", "exhausted": "😴", "bad_luck": "☂️", 
		"minor_injury": "🩹", "swamp_bog": "🟤", "snake_bite": "🐍",
		"stunned": "💫", "sleepy": "😪"
	}
	
	# Группируем статусы по твоей структуре
	var status_categories = {
		"## ПОЛОЖИТЕЛЬНЫЕ": [
			"good_shoes", "adrenaline", "potion_splash", "cloak_tent", 
			"phoenix_feather", "well_fed", "inspired", "strange_mushroom", "mage_potion"
		],
		"## СУПЕР ПОЛОЖИТЕЛЬНЫЕ": [
			"lucky_day", "thinker"
		],
		"## НЕГАТИВНЫЕ": [
			"crying", "swamp_bog", "stunned", 
			"sore_knees", "exhausted", "minor_injury", "sleepy"
		],
		"## СУПЕР ОТРИЦАТЕЛЬНЫЕ": [
			"bad_luck", "snake_bite"
		]
	}
	
	# Создаем контейнеры для левой и правой колонок
	var left_column = VBoxContainer.new()
	var right_column = VBoxContainer.new()
	
	left_column.name = "LeftColumn"
	right_column.name = "RightColumn"
	
	# Настраиваем выравнивание
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Добавляем колонки в сетку
	status_grid.add_child(left_column)
	status_grid.add_child(right_column)
	
	# Распределяем категории по колонкам
	var left_categories = ["## ПОЛОЖИТЕЛЬНЫЕ", "## СУПЕР ПОЛОЖИТЕЛЬНЫЕ"]
	var right_categories = ["## НЕГАТИВНЫЕ", "## СУПЕР ОТРИЦАТЕЛЬНЫЕ"]
	
	# Создаем левую колонку (положительные статусы)
	for category in left_categories:
		if status_categories.has(category):
			_create_category_section(category, status_categories[category], left_column, status_emojis)
	
	# Создаем правую колонку (отрицательные статусы)
	for category in right_categories:
		if status_categories.has(category):
			_create_category_section(category, status_categories[category], right_column, status_emojis)

# ← ФУНКЦИЯ СОЗДАНИЯ КАТЕГОРИИ
func _create_category_section(category_name: String, status_list: Array, parent_container: VBoxContainer, status_emojis: Dictionary):
	# Добавляем заголовок категории
	var category_label = Label.new()
	category_label.text = category_name.replace("## ", "")
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category_label.add_theme_font_size_override("font_size", base_font_size + 2)
	category_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Цвета категорий
	if "ПОЛОЖИТЕЛЬНЫЕ" in category_name:
		category_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))  # Зеленый
	elif "СУПЕР ПОЛОЖИТЕЛЬНЫЕ" in category_name:
		category_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2, 1.0))  # Ярко-зеленый
	elif "НЕГАТИВНЫЕ" in category_name:
		category_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4, 1.0))  # Красный
	else:  # СУПЕР ОТРИЦАТЕЛЬНЫЕ
		category_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))  # Ярко-красный
	
	parent_container.add_child(category_label)
	
	# Добавляем статусы этой категории
	for status_id in status_list:
		var emoji = status_emojis.get(status_id, "❓")
		var status_button = CheckBox.new()
		status_button.text = " " + emoji + " " + status_id
		status_button.add_theme_font_size_override("font_size", base_font_size)
		status_button.toggled.connect(_on_status_button_toggled.bind(status_id))
		status_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Настраиваем стиль для CheckBox
		var checkbox_style = StyleBoxFlat.new()
		checkbox_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
		checkbox_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
		checkbox_style.border_width_left = 1
		checkbox_style.border_width_top = 1
		checkbox_style.border_width_right = 1
		checkbox_style.border_width_bottom = 1
		checkbox_style.corner_radius_top_left = 8
		checkbox_style.corner_radius_top_right = 8
		checkbox_style.corner_radius_bottom_right = 8
		checkbox_style.corner_radius_bottom_left = 8
		
		status_button.add_theme_stylebox_override("normal", checkbox_style)
		
		var checkbox_hover_style = checkbox_style.duplicate()
		checkbox_hover_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
		checkbox_hover_style.border_color = Color(0.6, 0.6, 0.6, 1.0)
		status_button.add_theme_stylebox_override("hover", checkbox_hover_style)
		
		var checkbox_pressed_style = checkbox_style.duplicate()
		# Цвета активации по категориям
		if "ПОЛОЖИТЕЛЬНЫЕ" in category_name:
			checkbox_pressed_style.bg_color = Color(0.1, 0.4, 0.1, 1.0)  # Зеленый
		elif "СУПЕР ПОЛОЖИТЕЛЬНЫЕ" in category_name:
			checkbox_pressed_style.bg_color = Color(0.1, 0.5, 0.1, 1.0)  # Ярко-зеленый
		elif "НЕГАТИВНЫЕ" in category_name:
			checkbox_pressed_style.bg_color = Color(0.4, 0.1, 0.1, 1.0)  # Красный
		else:  # СУПЕР ОТРИЦАТЕЛЬНЫЕ
			checkbox_pressed_style.bg_color = Color(0.5, 0.1, 0.1, 1.0)  # Ярко-красный
		
		status_button.add_theme_stylebox_override("pressed", checkbox_pressed_style)
		
		# Цвет текста
		status_button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
		status_button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
		status_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		
		parent_container.add_child(status_button)
		status_buttons[status_id] = status_button
	
	# Добавляем отступ между категориями
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	parent_container.add_child(spacer)

# ← ФУНКЦИЯ ОБРАБОТКИ ПЕРЕКЛЮЧЕНИЯ СТАТУСОВ
func _on_status_button_toggled(toggled_on: bool, status_id: String):
	if toggled_on:
		print("Добавляем статус: ", status_id)
		player_stats.add_status(status_id)
	else:
		print("Удаляем статус: ", status_id)
		player_stats.remove_status(status_id)
	update_display()

# ← НОВАЯ ФУНКЦИЯ: ОПРЕДЕЛЕНИЕ ТИПА УСТРОЙСТВА
func _detect_device_type():
	screen_size = get_viewport().get_visible_rect().size
	print("Размер экрана: ", screen_size)
	
	# Определяем мобильное устройство по соотношению сторон и размеру
	var aspect_ratio = screen_size.x / screen_size.y
	is_mobile = screen_size.x < 790
	
	if is_mobile:
		print("Обнаружено мобильное устройство")
		base_font_size = 14  # Увеличиваем шрифт для мобильных
	else:
		print("Обнаружено десктоп/планшет устройство")
		base_font_size = 12

# ← НОВАЯ ФУНКЦИЯ: НАСТРОЙКА РАЗМЕРОВ ПАНЕЛИ
func _setup_panel_size():
	if is_mobile:
		# На мобильных - почти на весь экран
		dev_panel.size = Vector2(screen_size.x * 0.95, screen_size.y * 0.9)
		dev_panel.position = Vector2(
			(screen_size.x - dev_panel.size.x) / 2,
			(screen_size.y - dev_panel.size.y) / 2
		)
	else:
		# На десктоп/планшете - фиксированный размер
		dev_panel.size = Vector2(800, 600)
		dev_panel.position = Vector2(
			(screen_size.x - 800) / 2,
			(screen_size.y - 600) / 2
		)

# ← НОВАЯ ФУНКЦИЯ: НАСТРОЙКА АДАПТИВНОГО ИНТЕРФЕЙСА
func _setup_responsive_ui():
	# Настраиваем ScrollContainer
	scroll_container.custom_minimum_size = dev_panel.size - Vector2(40, 40)
	scroll_container.size = scroll_container.custom_minimum_size
	
	# Настраиваем основной VBox
	if is_mobile:
		main_vbox.custom_minimum_size = Vector2(scroll_container.size.x - 20, scroll_container.size.y * 1.5)
	else:
		main_vbox.custom_minimum_size = Vector2(scroll_container.size.x - 20, 800)
	
	# Настраиваем расстояния
	var separation = 15 if is_mobile else 10
	main_vbox.add_theme_constant_override("separation", separation)
	
	# ← НАСТРОЙКА СЕТКИ СТАТУСОВ
	if is_mobile:
		# На мобильных - 1 колонка (вертикальный скролл)
		status_grid.columns = 1
		status_grid.custom_minimum_size = Vector2(scroll_container.size.x - 40, 500)
	else:
		# На десктопе - 2 колонки (левая-правая)
		status_grid.columns = 2
		status_grid.custom_minimum_size = Vector2(scroll_container.size.x - 40, 400)
	
	status_grid.add_theme_constant_override("v_separation", 8)
	status_grid.add_theme_constant_override("h_separation", 20)  # Больше расстояния между колонками
	
	# Настраиваем внутренние колонки
	var left_column = status_grid.get_node_or_null("LeftColumn")
	var right_column = status_grid.get_node_or_null("RightColumn")
	
	if left_column and right_column:
		left_column.add_theme_constant_override("separation", 6)
		right_column.add_theme_constant_override("separation", 6)
	
	# Настраиваем секцию статусов
	status_section.add_theme_constant_override("separation", 8)
		
	# Настраиваем контейнер характеристик
	if stats_container is GridContainer:
		if is_mobile:
			stats_container.columns = 1
			stats_container.add_theme_constant_override("v_separation", 10)
			stats_container.add_theme_constant_override("h_separation", 5)
		else:
			stats_container.columns = 2
			stats_container.add_theme_constant_override("v_separation", 8)
			stats_container.add_theme_constant_override("h_separation", 15)
	
	# Настраиваем контейнер действий
	if actions_container is HBoxContainer:
		if is_mobile:
			actions_container.add_theme_constant_override("separation", 5)
		else:
			actions_container.add_theme_constant_override("separation", 10)
		actions_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Настраиваем SpinBoxes
	var spin_size = Vector2(80, 30) if is_mobile else Vector2(70, 25)
	strength_spin.custom_minimum_size = spin_size
	fortitude_spin.custom_minimum_size = spin_size
	agility_spin.custom_minimum_size = spin_size
	endurance_spin.custom_minimum_size = spin_size
	luck_spin.custom_minimum_size = spin_size
	
	# Настраиваем кнопки
	var button_width = 120 if is_mobile else 110
	var button_height = 35 if is_mobile else 30
	apply_stats_button.custom_minimum_size = Vector2(button_width, button_height)
	heal_button.custom_minimum_size = Vector2(button_width, button_height)
	level_up_button.custom_minimum_size = Vector2(button_width, button_height)
	add_exp_button.custom_minimum_size = Vector2(button_width, button_height)
	close_button.custom_minimum_size = Vector2(button_width, 40 if is_mobile else 35)
	
	# Увеличиваем шрифты для мобильных
	if is_mobile:
		apply_stats_button.add_theme_font_size_override("font_size", base_font_size)
		heal_button.add_theme_font_size_override("font_size", base_font_size)
		level_up_button.add_theme_font_size_override("font_size", base_font_size)
		add_exp_button.add_theme_font_size_override("font_size", base_font_size)
		close_button.add_theme_font_size_override("font_size", base_font_size)

# ← НОВАЯ ФУНКЦИЯ: ОБРАБОТКА ИЗМЕНЕНИЯ РАЗМЕРА ЭКРАНА
func _on_viewport_size_changed():
	print("Размер экрана изменился: ", get_viewport().get_visible_rect().size)
	_detect_device_type()
	_setup_panel_size()
	_setup_responsive_ui()
	
	# Обновляем отображение если панель открыта
	if dev_panel.visible:
		update_display()

func _set_children_process_mode(node: Node, mode: int):
	for child in node.get_children():
		if child is Control:
			child.process_mode = mode
		_set_children_process_mode(child, mode)

func _connect_signals():
	_disconnect_signals()
	
	apply_stats_button.pressed.connect(_on_apply_stats_button_pressed)
	heal_button.pressed.connect(_on_heal_button_pressed)
	level_up_button.pressed.connect(_on_level_up_button_pressed)
	add_exp_button.pressed.connect(_on_add_exp_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)

func _disconnect_signals():
	if apply_stats_button.pressed.is_connected(_on_apply_stats_button_pressed):
		apply_stats_button.pressed.disconnect(_on_apply_stats_button_pressed)
	if heal_button.pressed.is_connected(_on_heal_button_pressed):
		heal_button.pressed.disconnect(_on_heal_button_pressed)
	if level_up_button.pressed.is_connected(_on_level_up_button_pressed):
		level_up_button.pressed.disconnect(_on_level_up_button_pressed)
	if add_exp_button.pressed.is_connected(_on_add_exp_button_pressed):
		add_exp_button.pressed.disconnect(_on_add_exp_button_pressed)
	if close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.disconnect(_on_close_button_pressed)

func _input(event):
	if event is InputEventKey and event.pressed:
		var key = OS.get_keycode_string(event.keycode)
		current_input.append(key)
		
		if current_input.size() > secret_code.size():
			current_input.remove_at(0)
		
		if current_input == secret_code:
			toggle_dev_panel()
			current_input.clear()

func toggle_dev_panel():
	if not player_stats:
		player_stats = get_tree().get_first_node_in_group("player_stats")
		if not player_stats:
			push_error("PlayerStats not found!")
			return
	
	dev_panel.visible = not dev_panel.visible
	
	if dev_panel.visible and not level_up_menu_open:
		get_tree().paused = true
		_disable_menu_button(true)
	
	if not dev_panel.visible and not level_up_menu_open:
		get_tree().paused = false
		_disable_menu_button(false)
		
	if dev_panel.visible:
		update_display()
		dev_panel.grab_focus()

func on_level_up_menu_opened():
	level_up_menu_open = true

func on_level_up_menu_closed():
	level_up_menu_open = false
	
	if dev_panel.visible:
		get_tree().paused = true
	else:
		get_tree().paused = false

func update_display():
	if not player_stats:
		return
	
	strength_spin.value = player_stats.stats_system.strength
	fortitude_spin.value = player_stats.stats_system.fortitude
	agility_spin.value = player_stats.stats_system.agility
	endurance_spin.value = player_stats.stats_system.endurance
	luck_spin.value = player_stats.stats_system.luck
	
	# Обновляем состояние кнопок статусов
	for status_id in status_buttons:
		var status_button = status_buttons[status_id]
		var is_active = false
		
		for active_status in player_stats.active_statuses:
			if active_status.id == status_id:
				is_active = true
				break
		
		status_button.set_pressed_no_signal(is_active)

func _on_apply_stats_button_pressed():
	print("Применить характеристики нажата")
	if player_stats:
		player_stats.stats_system.strength = int(strength_spin.value)
		player_stats.stats_system.fortitude = int(fortitude_spin.value)
		player_stats.stats_system.agility = int(agility_spin.value)
		player_stats.stats_system.endurance = int(endurance_spin.value)
		player_stats.stats_system.luck = int(luck_spin.value)
		player_stats.stats_changed.emit()
		
		_force_achievement_check()

# ← НОВАЯ ФУНКЦИЯ: Принудительная проверка ачивок
func _force_achievement_check():
	var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
	if not achievement_manager:
		print("❌ AchievementManager не найден!")
		return
	
	if achievement_manager.has_method("check_stats_achievements"):
		print("🎯 ВЫЗЫВАЕМ ПРИНУДИТЕЛЬНУЮ ПРОВЕРКУ АЧИВОК")
		achievement_manager.check_stats_achievements(player_stats)
		
		# Дополнительно: выводим отладочную информацию
		print("📊 Текущие характеристики для проверки ачивок:")
		print("   Сила:", player_stats.stats_system.strength)
		print("   Крепость:", player_stats.stats_system.fortitude)
		print("   Ловкость:", player_stats.stats_system.agility)
		print("   Выносливость:", player_stats.stats_system.endurance)
		print("   Удача:", player_stats.stats_system.luck)
	else:
		print("❌ Метод check_stats_achievements не найден")

func _on_heal_button_pressed():
	print("Лечение нажато")
	if player_stats:
		player_stats.current_health = player_stats.get_max_health()
		player_stats.health_changed.emit(player_stats.current_health)

func _on_level_up_button_pressed():
	print("Уровень UP нажато")
	if player_stats:
		player_stats._level_up()

func _on_add_exp_button_pressed():
	print("+1000 опыта нажато")
	if player_stats:
		player_stats.add_exp(1000)

func _on_close_button_pressed():
	print("Закрыть нажато")
	toggle_dev_panel()

func _disable_menu_button(disabled: bool):
	var menu_button = get_tree().get_first_node_in_group("menu_button")
	if menu_button:
		menu_button.disabled = disabled
		# Визуальная обратная связь
		if disabled:
			menu_button.modulate = Color(1, 1, 1, 0.5)
		else:
			menu_button.modulate = Color(1, 1, 1, 1)

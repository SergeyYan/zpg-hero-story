# PlayerHUD.gd
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var level_label: Label = $LevelLabel
@onready var exp_bar: ProgressBar = $ExpBar

@onready var strength_label: Label = $StatsContainer/StrengthLabel
@onready var fortitude_label: Label = $StatsContainer/FortitudeLabel  
@onready var endurance_label: Label = $StatsContainer/EnduranceLabel
@onready var luck_label: Label = $StatsContainer/LuckLabel
@onready var regen_label: Label = $StatsContainer/RegenLabel
@onready var kills_label: Label = $KillBox/KillsLabel
@onready var status_container: HBoxContainer = $StatusContainer

@onready var stats_container: VBoxContainer = $StatsContainer
@onready var kill_box: VBoxContainer = $KillBox

@onready var menu_button: Button = $MenuButton

var player_stats_instance: PlayerStats

# Кастомные тултипы
var custom_tooltip: Control
var current_tooltip_status: StatusEffect = null
var tooltip_timer: Timer
var hovered_status_item: Control = null
var tooltip_background: Panel
var tooltip_label: RichTextLabel

# ← НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ АДАПТИВНОСТИ
var is_mobile: bool = false
var is_small_mobile: bool = false  # ← НОВОЕ: для очень маленьких экранов
var screen_size: Vector2
var base_font_size: int = 14

var is_menu_open: bool = false

func _ready():
	add_to_group("hud")
	menu_button.add_to_group("menu_button")
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Определяем тип устройства
	_detect_device_type()
	# Настраиваем адаптивный интерфейс
	_setup_responsive_ui()
	# Находим экземпляр PlayerStats
	player_stats_instance = get_tree().get_first_node_in_group("player_stats")
	if not player_stats_instance:
		push_error("PlayerStats not found!")
		return
	
	# Подключаемся к сигналам
	player_stats_instance.health_changed.connect(update_health)
	player_stats_instance.level_up.connect(update_level)
	player_stats_instance.exp_gained.connect(_on_exp_gained)
	player_stats_instance.stats_changed.connect(update_stats_display)
	player_stats_instance.monsters_killed_changed.connect(update_kills_display)
	player_stats_instance.statuses_changed.connect(update_status_display)
	
	# Инициализируем бары
	health_bar.max_value = player_stats_instance.get_max_health()
	exp_bar.max_value = player_stats_instance.exp_to_level
	
	# Создаем кастомную систему тултипов
	_create_custom_tooltip_system()
	
	# Инициализируем кнопку меню для мобильных устройств
	_setup_menu_button()
	
	# Подписываемся на изменение размера экрана
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Ждем один кадр, чтобы данные загрузились
	await get_tree().process_frame
	
	update_display()
	update_kills_display(player_stats_instance.monsters_killed)

# ← ОБНОВЛЕННАЯ ФУНКЦИЯ: ОПРЕДЕЛЕНИЕ ТИПА УСТРОЙСТВА
func _detect_device_type():
	screen_size = get_viewport().get_visible_rect().size
	print("Размер экрана HUD: ", screen_size)
	
	# Определяем мобильное устройство по соотношению сторон и размеру
	var aspect_ratio = screen_size.x / screen_size.y
	is_mobile = screen_size.x < 790
	
	# ← НОВОЕ: определяем очень маленькие экраны
	is_small_mobile = screen_size.x < 400
	
	if is_small_mobile:
		print("HUD: обнаружено очень маленькое мобильное устройство")
		base_font_size = 14
	elif is_mobile:
		print("HUD: обнаружено мобильное устройство")
		base_font_size = 14
	else:
		print("HUD: обнаружено десктоп/планшет устройство")
		base_font_size = 17

# ← ОБНОВЛЕННАЯ ФУНКЦИЯ: НАСТРОЙКА АДАПТИВНОГО ИНТЕРФЕЙСА
func _setup_responsive_ui():
	print("Настройка адаптивного HUD")
	
	# Настраиваем размеры и позиции в зависимости от устройства
	if is_small_mobile:
		_setup_small_mobile_layout()  # ← НОВАЯ ФУНКЦИЯ для очень маленьких экранов
	elif is_mobile:
		_setup_mobile_layout()
	else:
		_setup_desktop_layout()
	
	# Показываем кнопку меню только на мобильных устройствах
	if menu_button:
		menu_button.visible = is_mobile or is_small_mobile or !is_small_mobile or !is_mobile
		print("Menu button visibility: ", menu_button.visible)
	
	# Обновляем шрифты для всех элементов
	_update_font_sizes()

# ← НОВАЯ ФУНКЦИЯ: КОМПОНОВКА ДЛЯ ОЧЕНЬ МАЛЕНЬКИХ ЭКРАНОВ (320px)
func _setup_small_mobile_layout():
	print("Установка компактной мобильной компоновки для маленького экрана")
	
	# ХАРАКТЕРИСТИКИ - вверху слева (как на скриншоте)
	if stats_container:
		stats_container.position = Vector2(10, 10)
		stats_container.size = Vector2(180, 120)
		stats_container.add_theme_constant_override("separation", 3)
	
	# ЗДОРОВЬЕ И ОПЫТ - вверху справа компактно
	if health_label:
		health_label.position = Vector2(screen_size.x - 150, 10)
		health_bar.add_theme_constant_override("font_size", 10)
	
	if health_bar:
		health_bar.position = Vector2(screen_size.x -150, 30)
		health_bar.custom_minimum_size = Vector2(140, 10)  # Ширина, высота
		health_bar.size = Vector2(140, 10)
	
	if level_label:
		level_label.position = Vector2(screen_size.x - 150, 60)
		level_label.add_theme_constant_override("font_size", 10)
	
	if exp_bar:
		exp_bar.position = Vector2(screen_size.x - 150, 80)
		exp_bar.custom_minimum_size = Vector2(140, 10)  # Ширина, высота
		exp_bar.size = Vector2(140, 10)

	# СТАТУСЫ - внизу над killbox (центрировано)
	if status_container:
		var status_y_pos = screen_size.y - 80  # Над killbox
		status_container.position = Vector2(
			max(10, (screen_size.x - status_container.size.x) / 2),
			status_y_pos
		)
		status_container.add_theme_constant_override("separation", 3)
	
	# СЧЕТЧИК УБИЙСТВ - внизу по центру
	if kill_box:
		kill_box.position = Vector2(
			(screen_size.x - kill_box.size.x) / 2.1,
			screen_size.y - 40
		)
		kill_box.size = Vector2(150, 30)
		
	# КНОПКА МЕНЮ - внизу справа (для маленьких экранов)
	if menu_button:
		menu_button.position = Vector2(screen_size.x - 60, screen_size.y - 60)
		menu_button.custom_minimum_size = Vector2(50, 50)
		menu_button.add_theme_font_size_override("font_size", 16)
	
	_position_menu_button()


# ← ОБНОВЛЕННАЯ ФУНКЦИЯ: МОБИЛЬНАЯ КОМПОНОВКА
func _setup_mobile_layout():
	print("Установка мобильной компоновки")
	
	# ХАРАКТЕРИСТИКИ - вверху слева (как на скриншоте)
	if stats_container:
		stats_container.position = Vector2(10, 10)
		stats_container.size = Vector2(200, 140)
		stats_container.add_theme_constant_override("separation", 4)
	
	# ЗДОРОВЬЕ И ОПЫТ - вверху справа
	if health_label:
		health_label.position = Vector2(screen_size.x - 210, 10)
	
	if health_bar:
		health_bar.position = Vector2(screen_size.x - 210, 30)
		health_bar.custom_minimum_size = Vector2(200, 15)
		health_bar.size = Vector2(200, 16)
	
	if level_label:
		level_label.position = Vector2(screen_size.x - 210, 60)
	
	if exp_bar:
		exp_bar.position = Vector2(screen_size.x - 210, 80)
		exp_bar.custom_minimum_size = Vector2(200, 15)
		exp_bar.size = Vector2(200, 16)
	
	# СТАТУСЫ - внизу над killbox (центрировано)
	if status_container:
		var status_y_pos = screen_size.y - 100  # Над killbox
		status_container.position = Vector2(
			max(10, (screen_size.x - status_container.size.x) / 2),
			status_y_pos
		)
		status_container.add_theme_constant_override("separation", 5)
	
	# СЧЕТЧИК УБИЙСТВ - внизу по центру
	if kill_box:
		kill_box.position = Vector2(
			(screen_size.x - kill_box.size.x) / 2.2,
			screen_size.y - 50
		)
		kill_box.size = Vector2(200, 40)
		
	# КНОПКА МЕНЮ - внизу справа
	if menu_button:
		menu_button.position = Vector2(screen_size.x - 70, screen_size.y - 70)
		menu_button.custom_minimum_size = Vector2(60, 60)
		menu_button.add_theme_font_size_override("font_size", 24)
	
	_position_menu_button()

# ← ОБНОВЛЕННАЯ ФУНКЦИЯ: ДЕСКТОПНАЯ КОМПОНОВКА
func _setup_desktop_layout():
	print("Установка десктопной компоновки")
	
	# ХАРАКТЕРИСТИКИ - вверху слева (как на скриншоте)
	if stats_container:
		stats_container.position = Vector2(10, 10)
		stats_container.size = Vector2(220, 150)
		stats_container.add_theme_constant_override("separation", 5)
	
	# ЗДОРОВЬЕ И ОПЫТ - вверху справа
	if health_label:
		health_label.position = Vector2(screen_size.x - 250, 10)
	
	if health_bar:
		health_bar.position = Vector2(screen_size.x - 250, 40)
		health_bar.custom_minimum_size = Vector2(220, 25)
	
	if level_label:
		level_label.position = Vector2(screen_size.x - 250, 70)
	
	if exp_bar:
		exp_bar.position = Vector2(screen_size.x - 250, 100)
		exp_bar.custom_minimum_size = Vector2(220, 20)
	
	# СТАТУСЫ - по центру вверху (над характеристиками/здоровьем)
	if status_container:
		status_container.position = Vector2(
			(screen_size.x - status_container.size.x) / 2,
			10
		)
		status_container.add_theme_constant_override("separation", 8)
	
	# СЧЕТЧИК УБИЙСТВ - по центру внизу
	if kill_box:
		kill_box.position = Vector2(
			(screen_size.x - kill_box.size.x) / 2.3,
			screen_size.y - 50
		)
		kill_box.size = Vector2(250, 40)
		
	# На десктопе скрываем кнопку меню (управление через клавиатуру)
	if menu_button:
		menu_button.visible = false


# ← ОБНОВЛЕННАЯ ФУНКЦИЯ: ОБНОВЛЕНИЕ РАЗМЕРОВ ШРИФТОВ
func _update_font_sizes():
	# Обновляем шрифты для всех текстовых элементов
	var labels = [
		health_label, level_label, strength_label, fortitude_label,
		endurance_label, luck_label, regen_label, kills_label
	]
	
	for label in labels:
		if label:
			label.add_theme_font_size_override("font_size", base_font_size)
	
	# Уменьшаем шрифты для мобильных в статусах
	var status_font_size = base_font_size - 2 if is_mobile else base_font_size
	if is_small_mobile:
		status_font_size = 8  # Еще меньше для очень маленьких экранов
	
	# Обновляем размеры иконок статусов
	if status_container:
		for status_item in status_container.get_children():
			var emoji_label = status_item.get_node_or_null("StatusEmoji")
			var timer_label = status_item.get_node_or_null("TimerLabel")
			
			if emoji_label:
				var emoji_size = 12 if is_small_mobile else (16 if is_mobile else 18)
				emoji_label.add_theme_font_size_override("font_size", emoji_size)
			if timer_label:
				var timer_size = 7 if is_small_mobile else (9 if is_mobile else 11)
				timer_label.add_theme_font_size_override("font_size", timer_size)

# ← ФУНКЦИЯ: ОБРАБОТКА ИЗМЕНЕНИЯ РАЗМЕРА ЭКРАНА
func _on_viewport_size_changed():
	print("Размер экрана HUD изменился: ", get_viewport().get_visible_rect().size)
	_detect_device_type()
	_setup_responsive_ui()

# ← ОБНОВЛЕННАЯ ФУНКЦИЯ: ОБНОВЛЕНИЕ ОТОБРАЖЕНИЯ ХАРАКТЕРИСТИК
func update_stats_display():
	var effective_stats = player_stats_instance.get_effective_stats()
		
	if strength_label:
		strength_label.text = "Сила: %d" % effective_stats["strength"]
	if fortitude_label:
		fortitude_label.text = "Крепость: %d" % effective_stats["fortitude"]
	if endurance_label:
		endurance_label.text = "Выносливость: %d" % effective_stats["endurance"]
	if luck_label:
		luck_label.text = "Удача: %d" % effective_stats["luck"]
	if regen_label:
		regen_label.text = "Восстановление: %.1f/s" % effective_stats["health_regen"]

# ← ОБНОВЛЕННАЯ ФУНКЦИЯ: ОБНОВЛЕНИЕ ЗДОРОВЬЯ
func update_health(health: int):
	if health_bar:
		health_bar.max_value = player_stats_instance.get_max_health()
		health_bar.value = health
	if health_label:
		health_label.text = "HP: %d/%d" % [health, player_stats_instance.get_max_health()]

func update_level(new_level: int, available_points: int):
	if level_label:
		level_label.text = "Level: %d" % new_level
	update_exp_display()
	update_stats_display()

func _on_exp_gained():
	_create_exp_gain_effect()

func update_exp_display():
	if exp_bar:
		exp_bar.max_value = player_stats_instance.exp_to_level
		exp_bar.value = player_stats_instance.current_exp
		_create_exp_gain_effect()

func _create_exp_gain_effect():
	if exp_bar:
		var tween = create_tween()
		tween.tween_property(exp_bar, "value", player_stats_instance.current_exp, 0.3)

func update_kills_display(kills: int):
	if kills_label:
		kills_label.text = "Убито монстров: %d" % kills

func update_display():
	update_health(player_stats_instance.current_health)
	update_level(player_stats_instance.level, player_stats_instance.available_points)
	update_exp_display()
	update_stats_display()

# ← ФУНКЦИИ ДЛЯ КАСТОМНЫХ ТУЛТИПОВ (без изменений)
func _create_custom_tooltip_system():
	# Создаем кастомный тултип
	custom_tooltip = Control.new()
	custom_tooltip.visible = false
	custom_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_tooltip.z_index = 1000
	
	# АДАПТИВНЫЙ РАЗМЕР ТУЛТИПА
	var tooltip_width = 250 if is_mobile else 280
	var tooltip_height = 80 if is_mobile else 100
	
	tooltip_background = Panel.new()
	tooltip_background.size = Vector2(tooltip_width, tooltip_height)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.05, 0.98)
	bg_style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	
	tooltip_background.add_theme_stylebox_override("panel", bg_style)
	
	# Текст тултипа
	tooltip_label = RichTextLabel.new()
	tooltip_label.size = Vector2(tooltip_width - 10, tooltip_height - 10)
	tooltip_label.position = Vector2(5, 5)
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = false
	tooltip_label.scroll_active = false
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.name = "TooltipLabel"
	
	custom_tooltip.add_child(tooltip_background)
	custom_tooltip.add_child(tooltip_label)
	add_child(custom_tooltip)
	
	# Таймер для показа/скрытия тултипа
	tooltip_timer = Timer.new()
	tooltip_timer.wait_time = 0.3
	tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	tooltip_timer.one_shot = true
	add_child(tooltip_timer)

func _on_status_mouse_entered(status: StatusEffect, status_item: Control):
	hovered_status_item = status_item
	current_tooltip_status = status
	tooltip_timer.start()

func _on_status_mouse_exited():
	if tooltip_timer:
		tooltip_timer.stop()
	custom_tooltip.visible = false
	hovered_status_item = null
	current_tooltip_status = null

func _on_tooltip_timer_timeout():
	if current_tooltip_status and hovered_status_item:
		_show_custom_tooltip()

func _show_custom_tooltip():
	if not current_tooltip_status or not hovered_status_item:
		return
	_update_tooltip_content()

func _update_tooltip_content():
	if not current_tooltip_status or not hovered_status_item or not is_instance_valid(hovered_status_item):
		custom_tooltip.visible = false
		return
	
	var status = current_tooltip_status
	
	# ФОРМАТИРОВАННЫЙ ТЕКСТ
	var tooltip_text = "[b][color=%s]%s[/color][/b]\n" % [
		"#00ff00" if status.type == 0 else "#ff4444",
		status.name
	]
	tooltip_text += "[color=#dddddd]%s[/color]\n\n" % status.description
	tooltip_text += "[color=#aaaaaa]Осталось: %s[/color]" % _format_time_full(status.duration)
	
	tooltip_label.text = tooltip_text
	
	await get_tree().process_frame
	
	if not current_tooltip_status or not hovered_status_item or not is_instance_valid(hovered_status_item):
		custom_tooltip.visible = false
		return
	
	# АДАПТИВНАЯ ВЫСОТА ТУЛТИПА
	var text_height = tooltip_label.get_content_height()
	var min_height = 60 if is_mobile else 80
	var max_height = 150 if is_mobile else 200
	var target_height = clamp(text_height + 20, min_height, max_height)
	
	tooltip_label.size.y = target_height - 10
	tooltip_background.size.y = target_height
	custom_tooltip.size = tooltip_background.size
	
	if hovered_status_item and is_instance_valid(hovered_status_item):
		var status_pos = hovered_status_item.get_global_position()
		custom_tooltip.position = status_pos + Vector2(40 if is_mobile else 50, 0)
		
		var viewport_size = get_viewport().get_visible_rect().size
		if custom_tooltip.position.x + custom_tooltip.size.x > viewport_size.x:
			custom_tooltip.position.x = status_pos.x - custom_tooltip.size.x - 10
		if custom_tooltip.position.y + custom_tooltip.size.y > viewport_size.y:
			custom_tooltip.position.y = viewport_size.y - custom_tooltip.size.y - 10
		
		custom_tooltip.visible = true
	else:
		custom_tooltip.visible = false

func _process(delta):
	if custom_tooltip.visible and hovered_status_item and is_instance_valid(hovered_status_item) and current_tooltip_status:
		var status_pos = hovered_status_item.get_global_position()
		custom_tooltip.position = status_pos + Vector2(40 if is_mobile else 50, 0)
		
		var viewport_size = get_viewport().get_visible_rect().size
		if custom_tooltip.position.x + custom_tooltip.size.x > viewport_size.x:
			custom_tooltip.position.x = status_pos.x - custom_tooltip.size.x - 10
		if custom_tooltip.position.y + custom_tooltip.size.y > viewport_size.y:
			custom_tooltip.position.y = viewport_size.y - custom_tooltip.size.y - 10

# ← ФУНКЦИИ ДЛЯ СТАТУСОВ (без изменений)
func _start_status_animation(status_item: Control):
	status_item.set_meta("animation_started", true)
	
	var status_label = status_item.get_node("StatusEmoji")
	var tween = create_tween()
	
	status_item.set_meta("status_tween", tween)
	
	tween.tween_property(status_label, "scale", Vector2(1.3, 1.3), 0.6)
	tween.tween_property(status_label, "scale", Vector2(1.0, 1.0), 0.6)
	tween.set_loops(100)

func _start_timer_updates():
	if has_node("StatusTimer"):
		get_node("StatusTimer").queue_free()
	
	var timer = Timer.new()
	timer.name = "StatusTimer"
	timer.wait_time = 1.0
	timer.timeout.connect(_update_status_timers)
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.start()

func _update_status_timers():
	if not is_instance_valid(status_container):
		return
	
	for i in range(status_container.get_child_count()):
		var status_item = status_container.get_child(i)
		
		if not is_instance_valid(status_item):
			continue
		
		var timer_label = status_item.get_node_or_null("TimerLabel")
		if not timer_label:
			continue
		
		if i < player_stats_instance.active_statuses.size():
			var status = player_stats_instance.active_statuses[i]
			timer_label.text = _format_time(status.duration)
	
	if (custom_tooltip.visible and 
		current_tooltip_status and 
		hovered_status_item and 
		is_instance_valid(hovered_status_item)):
		
		var tooltip_label = custom_tooltip.get_node("TooltipLabel")
		var status = current_tooltip_status
		
		var current_text = tooltip_label.text
		var time_index = current_text.rfind("Осталось:")
		if time_index != -1:
			var new_text = current_text.substr(0, time_index) + "[color=#aaaaaa]Осталось: %s[/color]" % _format_time_full(status.duration)
			tooltip_label.text = new_text

func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func _format_time_full(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	
	if mins > 0 and secs > 0:
		return "%d мин %d сек" % [mins, secs]
	elif mins > 0:
		return "%d минут" % mins
	else:
		return "%d секунд" % secs

func _get_status_emoji(status_id: String) -> String:
	var emoji_dict = {
		"well_fed": "🍖", "good_shoes": "👟", "inspired": "💡",
		"adrenaline": "⚡", "lucky_day": "🍀", "potion_splash": "🧴",
		"strange_mushroom": "🍄", "cloak_tent": "👻", "mage_potion": "⚗️",
		"phoenix_feather": "🔥", "thinker": "🤔", "sore_knees": "🦵",
		"crying": "😢", "exhausted": "😴", "bad_luck": "☂️", 
		"minor_injury": "🩹", "swamp_bog": "🟤", "snake_bite": "🐍",
		"stunned": "💫", "sleepy": "😪", "deja_vu": "🌀", "confused": "😵",
		"blessed": "🙏", "cursed": "👺", "poisoned": "☠️", "burning": "🔥",
		"frozen": "❄️", "regenerating": "💚", "bleeding": "💉"
	}
	return emoji_dict.get(status_id, "❓")

# ← ОБНОВЛЕННАЯ ФУНКЦИЯ: ОБНОВЛЕНИЕ СТАТУСОВ С КОМПАКТНЫМИ РАЗМЕРАМИ
func update_status_display():
	if not status_container:
		return
	
	# Очищаем контейнер
	for child in status_container.get_children():
		if child.has_meta("status_tween"):
			var tween = child.get_meta("status_tween")
			if tween and tween.is_valid():
				tween.kill()
		child.queue_free()
	
	status_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# АДАПТИВНЫЕ РАЗМЕРЫ ДЛЯ СТАТУСОВ
	var status_size = 28 if is_small_mobile else (32 if is_mobile else 40)
	var emoji_size = 12 if is_small_mobile else (16 if is_mobile else 18)
	var timer_font_size = 7 if is_small_mobile else (9 if is_mobile else 11)
	
	# Добавляем иконки статусов
	for status in player_stats_instance.active_statuses:
		var status_container_item = Control.new()
		status_container_item.custom_minimum_size = Vector2(status_size, status_size)
		status_container_item.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# ЦВЕТА
		var background_color = Color(0.1, 0.8, 0.1, 0.8) if status.type == 0 else Color(0.9, 0.1, 0.1, 0.8)
		var border_color = Color(0.3, 1.0, 0.3, 1.0) if status.type == 0 else Color(1.0, 0.3, 0.3, 1.0)
		
		# РАМКА
		var border_panel = Panel.new()
		border_panel.size = Vector2(status_size, status_size)
		border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var border_style = StyleBoxFlat.new()
		border_style.bg_color = Color.TRANSPARENT
		border_style.border_color = border_color
		border_style.border_width_left = 1 if is_small_mobile else 2  # Тоньше для маленьких
		border_style.border_width_top = 1 if is_small_mobile else 2
		border_style.border_width_right = 1 if is_small_mobile else 2
		border_style.border_width_bottom = 1 if is_small_mobile else 2
		border_style.corner_radius_top_left = 3 if is_small_mobile else 4
		border_style.corner_radius_top_right = 3 if is_small_mobile else 4
		border_style.corner_radius_bottom_left = 3 if is_small_mobile else 4
		border_style.corner_radius_bottom_right = 3 if is_small_mobile else 4
		
		border_panel.add_theme_stylebox_override("panel", border_style)
		
		# ФОН
		var background = ColorRect.new()
		background.size = Vector2(status_size - 2, status_size - 2) if is_small_mobile else Vector2(status_size - 4, status_size - 4)
		background.position = Vector2(1, 1) if is_small_mobile else Vector2(2, 2)
		background.color = background_color
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# ЭМОДЗИ СТАТУСА
		var status_label = Label.new()
		status_label.name = "StatusEmoji"
		status_label.size = Vector2(status_size - 4, status_size - 4) if is_small_mobile else Vector2(status_size - 8, status_size - 8)
		status_label.position = Vector2(2, 2) if is_small_mobile else Vector2(4, 4)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.text = _get_status_emoji(status.id)
		status_label.add_theme_font_size_override("font_size", emoji_size)
		status_label.add_theme_color_override("font_color", Color.WHITE)
		
		# ТАЙМЕР
		var timer_label = Label.new()
		timer_label.name = "TimerLabel"
		timer_label.size = Vector2(status_size - 8, 10) if is_small_mobile else Vector2(status_size - 12, 14)
		timer_label.position = Vector2(4, status_size - 14) if is_small_mobile else Vector2(6, status_size - 18)
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", timer_font_size)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		
		# ФОН ДЛЯ ТАЙМЕРА
		var timer_bg = ColorRect.new()
		timer_bg.size = Vector2(status_size - 4, 8) if is_small_mobile else Vector2(status_size - 8, 12)
		timer_bg.position = Vector2(2, status_size - 10) if is_small_mobile else Vector2(4, status_size - 16)
		timer_bg.color = Color(0, 0, 0, 0.8)
		timer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# ОБРАБОТЧИКИ МЫШИ ДЛЯ КАСТОМНЫХ ТУЛТИПОВ
		status_container_item.mouse_entered.connect(_on_status_mouse_entered.bind(status, status_container_item))
		status_container_item.mouse_exited.connect(_on_status_mouse_exited)
		
		# СОБИРАЕМ ВСЕ ВМЕСТЕ
		status_container_item.add_child(border_panel)
		status_container_item.add_child(background)
		status_container_item.add_child(timer_bg)
		status_container_item.add_child(status_label)
		status_container_item.add_child(timer_label)
		
		# АНИМАЦИЯ ДЛЯ ВАЖНЫХ СТАТУСОВ
		if (status.id == "lucky_day" or status.id == "adrenaline") and not status_container_item.has_meta("animation_started"):
			_start_status_animation(status_container_item)
		
		status_container.add_child(status_container_item)
	
	_start_timer_updates()


# НОВАЯ ФУНКЦИЯ: Настройка кнопки меню
func _setup_menu_button():
	if not menu_button:
		print("MenuButton not found!")
		return
	
	# Настраиваем кнопку меню
	menu_button.text = "☰"  # Символ меню
	menu_button.custom_minimum_size = Vector2(50, 50)
	
	# Стили для кнопки
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	button_style.border_color = Color(0.5, 0.5, 0.7)
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	
	menu_button.add_theme_stylebox_override("normal", button_style)
	
	# Стиль при наведении
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.3, 0.4, 0.9)
	menu_button.add_theme_stylebox_override("hover", hover_style)
	
	# Стиль при нажатии
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(0.4, 0.4, 0.5, 1.0)
	menu_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Настраиваем шрифт
	menu_button.add_theme_font_size_override("font_size", 20)
	menu_button.add_theme_color_override("font_color", Color.WHITE)
	
	# Подключаем сигнал
	if not menu_button.pressed.is_connected(_on_menu_button_pressed):
		menu_button.pressed.connect(_on_menu_button_pressed)
	

# НОВАЯ ФУНКЦИЯ: Обработчик нажатия кнопки меню
func _on_menu_button_pressed():
	print("Menu button pressed - opening game menu")
	
	# Ищем меню в сцене
	var menu = get_tree().get_first_node_in_group("pause_menu")
	if menu:
		if not menu.menu_closed.is_connected(_on_menu_closed):
			menu.menu_closed.connect(_on_menu_closed)
		if is_menu_open:
			# Меню открыто - закрываем его
			menu.hide_menu()
			get_tree().paused = false
			is_menu_open = false
			# Можно поменять внешний вид кнопки
			menu_button.text = "☰"
		else:
			# Меню закрыто - открываем его
			menu.show_menu()
			get_tree().paused = true
			is_menu_open = true
			# Можно поменять внешний вид кнопки
			menu_button.text = "✕"
	else:
		print("Menu not found in scene")

func _position_menu_button():
	if not menu_button:
		return
	
	# Устанавливаем позицию вручную
	if is_small_mobile:
		menu_button.position = Vector2(screen_size.x - 55, screen_size.y - 55)
		menu_button.size = Vector2(45, 45)
	elif is_mobile:
		menu_button.position = Vector2(screen_size.x - 65, screen_size.y - 65)
		menu_button.size = Vector2(55, 55)
	
	# Делаем кнопку видимой только на мобильных
	menu_button.visible = is_mobile or is_small_mobile

# ДОБАВЬТЕ ЭТУ ФУНКЦИЮ ДЛЯ ОБРАБОТКИ ЗАКРЫТИЯ МЕНЮ ЧЕРЕЗ ДРУГИЕ СПОСОБЫ
func _on_menu_closed():
	is_menu_open = false
	menu_button.text = "☰"
	get_tree().paused = false

func _animate_menu_button():
	var tween = create_tween()
	tween.tween_property(menu_button, "scale", Vector2(0.9, 0.9), 0.1)
	tween.tween_property(menu_button, "scale", Vector2(1.0, 1.0), 0.1)

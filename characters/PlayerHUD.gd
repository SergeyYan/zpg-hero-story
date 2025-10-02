#PlayerHUD.gd
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var level_label: Label = $LevelLabel
@onready var exp_bar: ProgressBar = $ExpBar

# ОСТАВЛЯЕМ только labels характеристик
@onready var strength_label: Label = $StatsContainer/StrengthLabel
@onready var fortitude_label: Label = $StatsContainer/FortitudeLabel  
@onready var endurance_label: Label = $StatsContainer/EnduranceLabel
@onready var luck_label: Label = $StatsContainer/LuckLabel
@onready var regen_label: Label = $StatsContainer/RegenLabel
@onready var kills_label: Label = $KillBox/KillsLabel  # ← НОВЫЙ ЛЕЙБЛ
@onready var status_container: HBoxContainer = $StatusContainer  # ← Новый контейнер

var player_stats_instance: PlayerStats

# Кастомные тултипы
var custom_tooltip: Control
var current_tooltip_status: StatusEffect = null
var tooltip_timer: Timer
var hovered_status_item: Control = null
var tooltip_background: Panel
var tooltip_label: RichTextLabel

func _ready():
	add_to_group("hud")
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
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
	
	# Ждем один кадр, чтобы данные загрузились
	await get_tree().process_frame
	
	update_display()
	update_kills_display(player_stats_instance.monsters_killed)

func _create_custom_tooltip_system():
	# Создаем кастомный тултип
	custom_tooltip = Control.new()
	custom_tooltip.visible = false
	custom_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_tooltip.z_index = 1000
	
	# ФОН - БАЗОВЫЙ РАЗМЕР, БУДЕМ МЕНЯТЬ ДИНАМИЧЕСКИ
	tooltip_background = Panel.new()
	tooltip_background.size = Vector2(280, 100)  # ← Базовый размер
	
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
	
	# Текст тултипа - ДИНАМИЧЕСКИЙ РАЗМЕР
	tooltip_label = RichTextLabel.new()
	tooltip_label.size = Vector2(270, 90)  # ← Базовый размер
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

# ОСТАЛЬНЫЕ ФУНКЦИИ БЕЗ ИЗМЕНЕНИЙ (update_health, update_level, и т.д.)
func update_health(health: int):
	health_bar.max_value = player_stats_instance.get_max_health()
	health_bar.value = health
	health_label.text = "HP: %d/%d" % [health, player_stats_instance.get_max_health()]

func update_level(new_level: int, available_points: int):
	level_label.text = "Level: %d" % new_level
	update_exp_display()
	update_stats_display()

func update_exp_display():
	exp_bar.max_value = player_stats_instance.exp_to_level
	exp_bar.value = player_stats_instance.current_exp
	_create_exp_gain_effect()

func _create_exp_gain_effect():
	var tween = create_tween()
	tween.tween_property(exp_bar, "value", player_stats_instance.current_exp, 0.3)

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

func update_kills_display(kills: int):
	if kills_label:
		kills_label.text = "Убито монстров: %d" % kills

func update_status_display():
	# Очищаем контейнер
	for child in status_container.get_children():
		if child.has_meta("status_tween"):
			var tween = child.get_meta("status_tween")
			if tween and tween.is_valid():
				tween.kill()
		child.queue_free()
	
	status_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Добавляем иконки статусов
	for status in player_stats_instance.active_statuses:
		var status_container_item = Control.new()
		status_container_item.custom_minimum_size = Vector2(40, 40)
		status_container_item.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# ЦВЕТА
		var background_color = Color(0.1, 0.8, 0.1, 0.8) if status.type == 0 else Color(0.9, 0.1, 0.1, 0.8)
		var border_color = Color(0.3, 1.0, 0.3, 1.0) if status.type == 0 else Color(1.0, 0.3, 0.3, 1.0)
		
		# РАМКА
		var border_panel = Panel.new()
		border_panel.size = Vector2(40, 40)
		border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var border_style = StyleBoxFlat.new()
		border_style.bg_color = Color.TRANSPARENT
		border_style.border_color = border_color
		border_style.border_width_left = 2
		border_style.border_width_top = 2
		border_style.border_width_right = 2
		border_style.border_width_bottom = 2
		border_style.corner_radius_top_left = 4
		border_style.corner_radius_top_right = 4
		border_style.corner_radius_bottom_left = 4
		border_style.corner_radius_bottom_right = 4
		
		border_panel.add_theme_stylebox_override("panel", border_style)
		
		# ФОН
		var background = ColorRect.new()
		background.size = Vector2(36, 36)
		background.position = Vector2(2, 2)
		background.color = background_color
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# ЭМОДЗИ СТАТУСА
		var status_label = Label.new()
		status_label.name = "StatusEmoji"
		status_label.size = Vector2(32, 32)
		status_label.position = Vector2(4, 4)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.text = _get_status_emoji(status.id)
		status_label.add_theme_font_size_override("font_size", 18)
		status_label.add_theme_color_override("font_color", Color.WHITE)
		
		# ТАЙМЕР
		var timer_label = Label.new()
		timer_label.name = "TimerLabel"
		timer_label.size = Vector2(20, 16)
		timer_label.position = Vector2(16, 22)
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 11)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		
		# ФОН ДЛЯ ТАЙМЕРА
		var timer_bg = ColorRect.new()
		timer_bg.size = Vector2(26, 14)
		timer_bg.position = Vector2(14, 26)
		timer_bg.color = Color(0, 0, 0, 1.0)
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

# ОБРАБОТЧИКИ МЫШИ ДЛЯ ТУЛТИПОВ
func _on_status_mouse_entered(status: StatusEffect, status_item: Control):
	hovered_status_item = status_item
	current_tooltip_status = status
	tooltip_timer.start()

func _on_status_mouse_exited():
	# ПРЕКРАЩАЕМ ОБНОВЛЕНИЕ ПЕРЕД ОЧИСТКОЙ
	if tooltip_timer:
		tooltip_timer.stop()
	# СКРЫВАЕМ ТУЛТИП ПЕРВЫМ ДЕЛОМ
	custom_tooltip.visible = false
	# ПОТОМ ОЧИЩАЕМ ПЕРЕМЕННЫЕ
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
	# ПРОВЕРКА В НАЧАЛЕ ФУНКЦИИ
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
	
	# ДИНАМИЧЕСКИ РАССЧИТЫВАЕМ ВЫСОТУ ТЕКСТА
	await get_tree().process_frame  # Ждем обновления текста
	
	# ПОВТОРНАЯ ПРОВЕРКА ПОСЛЕ ОЖИДАНИЯ - ВАЖНО!
	if not current_tooltip_status or not hovered_status_item or not is_instance_valid(hovered_status_item):
		custom_tooltip.visible = false
		return
	
	# Получаем высоту текста
	var text_height = tooltip_label.get_content_height()
	var min_height = 80
	var max_height = 200
	var target_height = clamp(text_height + 20, min_height, max_height)
	
	# ОБНОВЛЯЕМ РАЗМЕРЫ ТУЛТИПА
	tooltip_label.size.y = target_height - 10
	tooltip_background.size.y = target_height
	custom_tooltip.size = tooltip_background.size
	
	# ПОЗИЦИОНИРУЕМ ТУЛТИП ВОЗЛЕ СТАТУСА (С ЕЩЕ ОДНОЙ ПРОВЕРКОЙ)
	if hovered_status_item and is_instance_valid(hovered_status_item):
		var status_pos = hovered_status_item.get_global_position()
		custom_tooltip.position = status_pos + Vector2(50, 0)
		
		# ЕСЛИ ТУЛТИП ВЫХОДИТ ЗА ЭКРАН - СДВИГАЕМ
		var viewport_size = get_viewport().get_visible_rect().size
		if custom_tooltip.position.x + custom_tooltip.size.x > viewport_size.x:
			custom_tooltip.position.x = status_pos.x - custom_tooltip.size.x - 10
		if custom_tooltip.position.y + custom_tooltip.size.y > viewport_size.y:
			custom_tooltip.position.y = viewport_size.y - custom_tooltip.size.y - 10
		
		custom_tooltip.visible = true
	else:
		custom_tooltip.visible = false


func _process(delta):
	# УБИРАЕМ ВЫЗОВ _update_tooltip_content() ОТСЮДА - он вызывает проблемы
	# Вместо этого просто обновляем позицию
	if custom_tooltip.visible and hovered_status_item and is_instance_valid(hovered_status_item) and current_tooltip_status:
		var status_pos = hovered_status_item.get_global_position()
		custom_tooltip.position = status_pos + Vector2(50, 0)
		
		# Проверяем границы экрана
		var viewport_size = get_viewport().get_visible_rect().size
		if custom_tooltip.position.x + custom_tooltip.size.x > viewport_size.x:
			custom_tooltip.position.x = status_pos.x - custom_tooltip.size.x - 10
		if custom_tooltip.position.y + custom_tooltip.size.y > viewport_size.y:
			custom_tooltip.position.y = viewport_size.y - custom_tooltip.size.y - 10

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
	
	# ОБНОВЛЯЕМ ТАЙМЕРЫ СТАТУСОВ
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
	
	# ОБНОВЛЯЕМ ТУЛТИП ТОЛЬКО ЕСЛИ ВСЕ ВАЛИДНО
	if (custom_tooltip.visible and 
		current_tooltip_status and 
		hovered_status_item and 
		is_instance_valid(hovered_status_item)):
		
		# ОБНОВЛЯЕМ ТОЛЬКО ТЕКСТ ВРЕМЕНИ, БЕЗ ПЕРЕСЧЕТА РАЗМЕРОВ
		var tooltip_label = custom_tooltip.get_node("TooltipLabel")
		var status = current_tooltip_status
		
		# ОБНОВЛЯЕМ ТОЛЬКО СТРОКУ С ВРЕМЕНЕМ
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

func update_display():
	update_health(player_stats_instance.current_health)
	update_level(player_stats_instance.level, player_stats_instance.available_points)
	update_exp_display()
	update_stats_display()

func _on_exp_gained():
	_create_exp_gain_effect()

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

func _ready():
	add_to_group("hud")
	# Находим экземпляр PlayerStats
	player_stats_instance = get_tree().get_first_node_in_group("player_stats")
	if not player_stats_instance:
		push_error("PlayerStats not found!")
		return
	
	# Подключаемся к сигналам
	player_stats_instance.health_changed.connect(update_health)
	player_stats_instance.level_up.connect(update_level)
	player_stats_instance.exp_gained.connect(_on_exp_gained)
	player_stats_instance.stats_changed.connect(update_stats_display)  # ← НОВОЕ ПОДКЛЮЧЕНИЕ!
	player_stats_instance.monsters_killed_changed.connect(update_kills_display)  # ← НОВЫЙ СИГНАЛ
	player_stats_instance.statuses_changed.connect(update_status_display)
	
	# Инициализируем бары
	health_bar.max_value = player_stats_instance.get_max_health()
	exp_bar.max_value = player_stats_instance.exp_to_level
	
	# Ждем один кадр, чтобы данные загрузились
	await get_tree().process_frame
	
	update_display()
	update_kills_display(player_stats_instance.monsters_killed)  # ← ИНИЦИАЛИЗИРУЕМ СЧЕТЧИК


func update_health(health: int):
	# ОБНОВЛЯЕМ максимальное значение здоровья при изменении
	health_bar.max_value = player_stats_instance.get_max_health()
	health_bar.value = health
	health_label.text = "HP: %d/%d" % [health, player_stats_instance.get_max_health()]

func update_level(new_level: int, available_points: int):  # ← Добавляем второй параметр
	level_label.text = "Level: %d" % new_level
	update_exp_display()
	update_stats_display()  # ← Обновляем характеристики и очки!
	# available_points можно не использовать, т.к. берем из player_stats_instance

func update_exp_display():
	# ОБНОВЛЯЕМ максимальное значение опыта
	exp_bar.max_value = player_stats_instance.exp_to_level
	exp_bar.value = player_stats_instance.current_exp
	# Можно добавить визуальный эффект при получении опыта
	_create_exp_gain_effect()

func _create_exp_gain_effect():
	# Визуальный эффект для получения опыта
	var tween = create_tween()
	tween.tween_property(exp_bar, "value", player_stats_instance.current_exp, 0.3)
#	tween.tween_callback(_check_level_up)

func update_stats_display():
	var effective_stats = player_stats_instance.get_effective_stats()
	# Обновляем ТОЛЬКО характеристики
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
	
	# Добавляем иконки статусов
	for status in player_stats_instance.active_statuses:
		# ОСНОВНОЙ КОНТЕЙНЕР ДЛЯ СТАТУСА
		var status_container_item = Control.new()
		status_container_item.custom_minimum_size = Vector2(40, 40)
		status_container_item.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# ФОН
		var background = ColorRect.new()
		background.size = Vector2(36, 36)
		background.position = Vector2(2, 2)
		background.color = Color(0, 0, 0, 0.6)
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
		
		# ЦВЕТ В ЗАВИСИМОСТИ ОТ ТИПА СТАТУСА
		var text_color = Color.SKY_BLUE if status.type == 0 else Color.INDIAN_RED
		status_label.add_theme_color_override("font_color", text_color)
		
		# ТАЙМЕР В ПРАВОМ НИЖНЕМ УГЛУ (ОБНОВЛЯЕМЫЙ)
		var timer_label = Label.new()
		timer_label.name = "TimerLabel"  # ← ДОБАВЛЯЕМ ИМЯ ДЛЯ ПОИСКА
		timer_label.size = Vector2(20, 12)
		timer_label.position = Vector2(18, 26)
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		timer_label.add_theme_font_size_override("font_size", 10)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		
		# ФОН ДЛЯ ТАЙМЕРА
		var timer_bg = ColorRect.new()
		timer_bg.size = Vector2(20, 12)
		timer_bg.position = Vector2(18, 26)
		timer_bg.color = Color(0, 0, 0, 0.8)
		timer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# ПОДСКАЗКИ!
		var tooltip_text = "%s\n%s\n\nОсталось: %s" % [
			status.name, 
			status.description, 
			_format_time_full(status.duration)
		]
		status_container_item.tooltip_text = tooltip_text
		
		# СОБИРАЕМ ВСЕ ВМЕСТЕ
		status_container_item.add_child(background)
		status_container_item.add_child(timer_bg)
		status_container_item.add_child(status_label)
		status_container_item.add_child(timer_label)
		
		# АНИМАЦИЯ ДЛЯ ВАЖНЫХ СТАТУСОВ
		if (status.id == "lucky_day" or status.id == "adrenaline") and not status_container_item.has_meta("animation_started"):
			_start_status_animation(status_container_item)
		
		status_container.add_child(status_container_item)

	# ← ЗАПУСКАЕМ ТАЙМЕР ОБНОВЛЕНИЯ ВРЕМЕНИ
	_start_timer_updates()

func _start_status_animation(status_item: Control):
	# Помечаем, что анимация запущена
	status_item.set_meta("animation_started", true)
	
	var status_label = status_item.get_node("StatusEmoji")
	var tween = create_tween()
	
	# Сохраняем твин в метаданные для возможности остановки
	status_item.set_meta("status_tween", tween)
	
	# БЕЗОПАСНАЯ АНИМАЦИЯ с конечным числом повторов
	tween.tween_property(status_label, "scale", Vector2(1.3, 1.3), 0.6)
	tween.tween_property(status_label, "scale", Vector2(1.0, 1.0), 0.6)
	tween.set_loops(100)  # ← ОГРАНИЧИВАЕМ КОЛИЧЕСТВО ПОВТОРОВ!

func _start_timer_updates():
	# Удаляем старый таймер если есть
	if has_node("StatusTimer"):
		get_node("StatusTimer").queue_free()
	
	# СОЗДАЕМ НОВЫЙ ТАЙМЕР
	var timer = Timer.new()
	timer.name = "StatusTimer"
	timer.wait_time = 1.0
	timer.timeout.connect(_update_status_timers)
	add_child(timer)
	timer.start()


func _update_status_timers():
	# ПРОВЕРЯЕМ, ЧТО КОНТЕЙНЕР СУЩЕСТВУЕТ
	if not is_instance_valid(status_container):
		return
	
	# ОБНОВЛЯЕМ ТАЙМЕРЫ ВСЕХ АКТИВНЫХ СТАТУСОВ
	for i in range(status_container.get_child_count()):
		var status_item = status_container.get_child(i)
		
		# ПРОВЕРКА ВАЛИДНОСТИ
		if not is_instance_valid(status_item):
			continue
		
		var timer_label = status_item.get_node_or_null("TimerLabel")
		if not timer_label:
			continue
		
		if i < player_stats_instance.active_statuses.size():
			var status = player_stats_instance.active_statuses[i]
			
			# ОБНОВЛЯЕМ ТАЙМЕР
			timer_label.text = _format_time(status.duration)
			
			# ОБНОВЛЯЕМ ПОДСКАЗКУ
			var tooltip_text = "%s\n%s\n\nОсталось: %s" % [
				status.name, 
				status.description, 
				_format_time_full(status.duration)
			]
			status_item.tooltip_text = tooltip_text

func _format_time(seconds: float) -> String:
	# КОРОТКИЙ ФОРМАТ ДЛЯ ТАЙМЕРА: "1:30", "0:45"
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func _format_time_full(seconds: float) -> String:
	# ПОЛНЫЙ ФОРМАТ ДЛЯ ПОДСКАЗКИ: "1 минута 30 секунд"
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
		"adrenaline": "⚡", "lucky_day": "🍀", "sore_knees": "🦵",
		"crying": "😢", "exhausted": "😴", "bad_luck": "☂️", "minor_injury": "🩹"
	}
	return emoji_dict.get(status_id, "❓")


func update_display():
	update_health(player_stats_instance.current_health)
	update_level(player_stats_instance.level, player_stats_instance.available_points)  # player_stats_instance.available_points ← Добавляем второй аргумент!
	update_exp_display()
	update_stats_display()

# ДОБАВЛЯЕМ обработку получения опыта
func _on_exp_gained():
	# Создаем эффект получения опыта
	_create_exp_gain_effect()

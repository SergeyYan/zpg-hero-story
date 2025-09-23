#PlayerStat.gd
extends Node
class_name PlayerStats

signal health_changed(new_health)
signal level_up(new_level, available_points)  # ← Добавляем available_points
signal player_died
signal exp_gained()
signal stats_changed()  # ← НОВЫЙ СИГНАЛ при изменении характеристик!
signal monsters_killed_changed(count: int)  # ← НОВЫЙ СИГНАЛ
signal statuses_changed()  # ← Новый сигнал

@export var stats_system: StatsSystem = StatsSystem.new()
# Заменяем статические значения на систему характеристик
#var stats_system: StatsSystem = StatsSystem.new()
var current_health: int
var current_exp: int = 0
var exp_to_level: int = 100
var level: int = 1
var available_points: int = 0  # ← Очки для распределения
var monsters_killed: int = 0  # ← НОВАЯ ПЕРЕМЕННАЯ
var active_statuses: Array[StatusEffect] = []
var max_concurrent_statuses: int = 3
var accumulated_regen: float = 0.0

var status_library: Dictionary = {}

# Геттеры для удобства
func get_max_health() -> int: return stats_system.get_max_health()
func get_damage() -> int: return stats_system.get_damage() 
func get_defense() -> int: return stats_system.get_defense()
func get_health_regen() -> float: return stats_system.get_health_regen()
func get_level() -> int: return level


func _ready():
	add_to_group("player_stats")
	
	print("PlayerStats _ready() вызван")
	process_mode = Node.PROCESS_MODE_ALWAYS  
	# Сначала инициализируем статусы
	_init_status_library()
	
	# Начальные характеристики
	stats_system.strength = 1
	stats_system.fortitude = 0
	stats_system.endurance = 0
	stats_system.luck = 0
	stats_system.base_health = 5  # ↓ Базовое здоровье
	
	current_health = get_max_health()
	
	# Таймер для обновления статусов
	_create_status_timer()
	
	
	# Начинаем с 1 уровня и даем очки для распределения
	level = 1
	available_points = 3  # ← Очки для распределения при старте
		
	# Немедленно показываем меню распределения
	await get_tree().process_frame
	level_up.emit(level, available_points)  # ← Сигнал при старте


func _init_status_library():
	# ПОЛОЖИТЕЛЬНЫЕ СТАТУСЫ (голубой/золотой)
	status_library["well_fed"] = StatusEffect.new(
		"well_fed", "Хорошо покушал", "+2 ко всем характеристикам",  
		StatusEffect.StatusType.POSITIVE, randf_range(300, 720)  # 5-10 минут
	)
	status_library["well_fed"].strength_modifier = 2
	status_library["well_fed"].fortitude_modifier = 2
	status_library["well_fed"].endurance_modifier = 2
	status_library["well_fed"].luck_modifier = 2
	
	status_library["good_shoes"] = StatusEffect.new(
		"good_shoes", "Удобная обувь", "+15% скорости передвижения", 
		StatusEffect.StatusType.POSITIVE, randf_range(300, 600)
	)
	status_library["good_shoes"].speed_modifier = 1.15
	
	status_library["inspired"] = StatusEffect.new(
		"inspired", "Вдохновение", "+3 к удаче, +50% регенерации", 
		StatusEffect.StatusType.POSITIVE, randf_range(240, 720)  # 4-8 минут
	)
	status_library["inspired"].luck_modifier = 3
	status_library["inspired"].health_regen_modifier = 0.5
	
	status_library["adrenaline"] = StatusEffect.new(
		"adrenaline", "Выброс адреналина", "+25% скорости, +3 к силе", 
		StatusEffect.StatusType.POSITIVE, randf_range(180, 540)  # 3-5 минут
	)
	status_library["adrenaline"].speed_modifier = 1.25
	status_library["adrenaline"].strength_modifier = 3
	
	status_library["lucky_day"] = StatusEffect.new(
		"lucky_day", "Счастливый день", "Удвоенный шанс крита", 
		StatusEffect.StatusType.POSITIVE, randf_range(300, 900)  # 10-15 минут
	)
	# Особый статус - обрабатывается отдельно
	
	# НЕГАТИВНЫЕ СТАТУСЫ (красный)
	status_library["sore_knees"] = StatusEffect.new(
		"sore_knees", "Боль в коленях", "-15% скорости передвижения", 
		StatusEffect.StatusType.NEGATIVE, randf_range(180, 600)
	)
	status_library["sore_knees"].speed_modifier = 0.85
	
	status_library["crying"] = StatusEffect.new(
		"crying", "Плакал", "-1 ко всем характеристикам", 
		StatusEffect.StatusType.NEGATIVE, randf_range(180, 360)  # 3-6 минут
	)
	status_library["crying"].strength_modifier = -1
	status_library["crying"].fortitude_modifier = -1
	status_library["crying"].endurance_modifier = -1
	status_library["crying"].luck_modifier = -1
	
	status_library["exhausted"] = StatusEffect.new(
		"exhausted", "Истощение", "-10% регенерации, -25% скорости", 
		StatusEffect.StatusType.NEGATIVE, randf_range(180, 540)  # 7-12 минут
	)
	status_library["exhausted"].speed_modifier = 0.75
	status_library["exhausted"].health_regen_modifier = -0.1
	
	status_library["bad_luck"] = StatusEffect.new(
		"bad_luck", "Неудачный день", "-5 к удаче", 
		StatusEffect.StatusType.NEGATIVE, randf_range(120, 660)  # 2-7 минут
	)
	status_library["bad_luck"].luck_modifier = -5
	
	status_library["minor_injury"] = StatusEffect.new(
		"minor_injury", "Легкое ранение", "-1 к выносливости и крепости", 
		StatusEffect.StatusType.NEGATIVE, randf_range(240, 480)  # 4-8 минут
	)
	status_library["minor_injury"].endurance_modifier = -1
	status_library["minor_injury"].fortitude_modifier = -1

func _create_status_timer():
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_statuses)
	timer.process_mode = Node.PROCESS_MODE_ALWAYS  # ← ТАЙМЕР ТОЖЕ ВСЕГДА
	add_child(timer)
	timer.start()

func _update_statuses():
		
	var statuses_to_remove = []
	
	for status in active_statuses:
		status.duration -= 1.0
		if status.duration <= 0:
			statuses_to_remove.append(status)

	
	for status in statuses_to_remove:
		active_statuses.erase(status)

	
	if statuses_to_remove.size() > 0:
		statuses_changed.emit()
		stats_changed.emit()


func add_status(status_id: String):
	# ПРОВЕРКА НА ДУБЛИКАТЫ
	for existing_status in active_statuses:
		if existing_status.id == status_id:
			return
			
	# ← ИСПРАВЛЕНИЕ: ПРОВЕРЯЕМ ЕСТЬ ЛИ СВОБОДНЫЕ СЛОТЫ
	if active_statuses.size() >= max_concurrent_statuses:
		print("Все слоты статусов заняты. Нельзя добавить: ", status_id)
		return  # ← ВЫХОДИМ, НЕ ДОБАВЛЯЕМ НОВЫЙ СТАТУС
	
	if status_library.has(status_id):
		var template = status_library[status_id]
		var new_status = StatusEffect.new(
			template.id, template.name, template.description,
			template.type, randf_range(60, 600)
		)
		
		# КОПИРУЕМ МОДИФИКАТОРЫ из шаблона
		new_status.speed_modifier = template.speed_modifier
		new_status.strength_modifier = template.strength_modifier
		new_status.fortitude_modifier = template.fortitude_modifier
		new_status.endurance_modifier = template.endurance_modifier
		new_status.luck_modifier = template.luck_modifier
		new_status.health_regen_modifier = template.health_regen_modifier
		
		active_statuses.append(new_status)
		statuses_changed.emit()
		stats_changed.emit()


func remove_status(status_id: String):
	for i in range(active_statuses.size() - 1, -1, -1):
		if active_statuses[i].id == status_id:
			active_statuses.remove_at(i)
			statuses_changed.emit()
			stats_changed.emit()
			break

func get_effective_stats() -> Dictionary:
	var effective = {
		"speed": 1.0,
		"strength": stats_system.strength,
		"fortitude": stats_system.fortitude, 
		"endurance": stats_system.endurance,
		"luck": stats_system.luck,
		"health_regen": stats_system.get_health_regen()
	}
	
	for status in active_statuses:
		effective.speed *= status.speed_modifier
		effective.strength += status.strength_modifier
		effective.fortitude += status.fortitude_modifier
		effective.endurance += status.endurance_modifier
		effective.luck += status.luck_modifier
		effective.health_regen += status.health_regen_modifier
	
	return effective

func get_crit_chance_with_modifiers() -> float:
	var base_chance = stats_system.get_crit_chance()
	for status in active_statuses:
		if status.id == "lucky_day":
			base_chance *= 2.0
	return base_chance


# Методы для получения статусов в разных ситуациях
func apply_post_battle_effects():
	if randf() < 0.3:  # 30% шанс получить негативный статус после боя
		var negative_statuses = ["sore_knees", "minor_injury", "exhausted"]
		add_status(negative_statuses[randi() % negative_statuses.size()])
	
	if randf() < 0.4:  # 40% шанс получить позитивный статус
		var positive_statuses = ["well_fed", "adrenaline", "inspired"] 
		add_status(positive_statuses[randi() % positive_statuses.size()])


func apply_movement_effects():
	if randf() < 0.2:  # 10% шанс при движении
		if randf() < 0.6:  # 60% из них - положительные
			var positive_statuses = ["good_shoes", "adrenaline"]
			add_status(positive_statuses[randi() % positive_statuses.size()])
		else:
			add_status("sore_knees")

func apply_level_up_effects():
	# При получении уровня всегда даем позитивный статус
	var positive_statuses = ["well_fed", "inspired", "lucky_day"]
	add_status(positive_statuses[randi() % positive_statuses.size()])


func take_damage(amount: int):
	var actual_damage = max(1, amount)
	current_health -= actual_damage
	health_changed.emit(current_health)
	
	if current_health <= 0:
		current_health = 0
		player_died.emit()  # ← Сигнал должен отправляться

func heal(amount: int):
	current_health = min(current_health + amount, get_max_health())
	health_changed.emit(current_health)

# Регенерация здоровья вне боя
func regenerate_health(delta: float):
	if current_health < get_max_health():
		var regen_per_second = get_health_regen()
		accumulated_regen += regen_per_second * delta
		
		# Добавляем только когда накопился целый HP
		if accumulated_regen >= 1.0:
			var hp_to_add = floor(accumulated_regen)
			current_health = min(current_health + hp_to_add, get_max_health())
			accumulated_regen -= hp_to_add
			
			var display_health = int(current_health)
			health_changed.emit(display_health)

func add_exp(amount: int):
	# ← ПРОСТО ДОБАВЛЯЕМ ФИКСИРОВАННЫЙ ОПЫТ
	current_exp += amount
	exp_gained.emit()

func add_monster_kill():  # ← НОВАЯ ФУНКЦИЯ
	monsters_killed += 1
	monsters_killed_changed.emit(monsters_killed)
	# ← ПРОВЕРКА ДОСТИЖЕНИЙ
	var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
	if achievement_manager:
		achievement_manager.check_kill_achievements(monsters_killed)

func complete_level_up_after_battle():  # ← НОВАЯ ФУНКЦИЯ
	if current_exp >= exp_to_level:
		_level_up()


func _level_up():
	level += 1
	# ← ОБНОВЛЯЕМ ПОРГ ОПЫТА ДЛЯ СЛЕДУЮЩЕГО УРОВНЯ
	exp_to_level = get_exp_for_next_level(level)
	current_exp = 0  # Сбрасываем опыт
	# Даем 3 очка за уровень
	available_points += 3
	# Восстанавливаем здоровье
	current_health = get_max_health()
	level_up.emit(level, available_points)
	# ← ПРОВЕРКА ДОСТИЖЕНИЙ УРОВНЯ
	apply_level_up_effects()
	var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
	if achievement_manager:
		achievement_manager.check_level_achievements(level)


func increase_strength():
	if available_points > 0:
		stats_system.strength += 1
		available_points -= 1
		stats_changed.emit()
		# ← ПРОВЕРКА ДОСТИЖЕНИЙ ХАРАКТЕРИСТИК
		var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
		if achievement_manager:
			achievement_manager.check_stats_achievements(stats_system)

func increase_fortitude():
	if available_points > 0:
		stats_system.fortitude += 1  
		available_points -= 1
		stats_changed.emit()
		# ← ПРОВЕРКА ДОСТИЖЕНИЙ ХАРАКТЕРИСТИК
		var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
		if achievement_manager:
			achievement_manager.check_stats_achievements(stats_system)

func increase_endurance():
	if available_points > 0:
		stats_system.endurance += 1
		available_points -= 1
		stats_changed.emit()
		# ← ПРОВЕРКА ДОСТИЖЕНИЙ ХАРАКТЕРИСТИК
		var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
		if achievement_manager:
			achievement_manager.check_stats_achievements(stats_system)

func increase_luck():
	if available_points > 0:
		stats_system.luck += 1
		available_points -= 1
		stats_changed.emit()
		# ← ПРОВЕРКА ДОСТИЖЕНИЙ ХАРАКТЕРИСТИК
		var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
		if achievement_manager:
			achievement_manager.check_stats_achievements(stats_system)


func get_exp_for_next_level(current_level: int) -> int:
	# ← ФИКСИРОВАННОЕ КОЛИЧЕСТВО ПОБЕД ДЛЯ КАЖДОГО УРОВНЯ
	if current_level <= 15:
		# Уровни 1-15: прогрессия как раньше
		match current_level:
			1: return 100    # 5 побед
			2: return 150    # 7-8 побед
			3: return 200    # 10 побед
			4: return 250    # 12-13 побед
			5: return 300    # 15 победы
			6: return 350    # 17-18 побед
			7: return 400    # 20 побед
			8: return 450   # 22-23 побед
			9: return 500   # 25 побед
			10: return 1000  # 50 побед
			11: return 1200  # 60 побед
			12: return 1400  # 70 побед
			13: return 1600  # 80 побед
			14: return 1800  # 90 побед
			15: return 2000  # 100 побед
	elif current_level <= 39:
		# ← УРОВНИ 16-39: плавный рост до 250 побед
		# ← УРОВНИ 16-39: точный расчет до 5000
		if current_level == 39:
			return 5000  # ← exactly 5000 for 39→40
		else:
			var victories_needed = 100 + (current_level - 15) * 6
			return victories_needed * 20
	else:
	# ← УРОВНИ 40+: ФИКСИРОВАННЫЕ 300 ПОБЕД
	# Для 40+ уровня: 300 побед × 20 exp = 6000 exp
		return 6000
	return 6000


func get_exp_reward_multiplier(player_level: int) -> float:
	# ← ФИКСИРОВАННАЯ НАГРАДА: ВСЕГДА 20 exp за победу
	# Множитель всегда 1.0, так как монстры дают фиксированный опыт
	return 1.0

func load_from_data(data: Dictionary):
	level = data.get("level", 1)
	current_exp = data.get("current_exp", 0)
	exp_to_level = data.get("exp_to_level", 100)
	current_health = data.get("current_health", 100)
	available_points = data.get("available_points", 0)
	stats_system.strength = data.get("strength", 1)
	stats_system.fortitude = data.get("fortitude", 1) 
	stats_system.endurance = data.get("endurance", 1)
	stats_system.luck = data.get("luck", 1)
	monsters_killed = data.get("monsters_killed", 0)  # ← ЗАГРУЗКА СЧЕТЧИКА
	# НЕ вызываем сигнал level_up при загрузке!
	# level_up.emit(level, available_points)  # ← ЗАКОММЕНТИРУЙ эту строку!
	
	health_changed.emit(current_health)  # ← Только здоровье обновляем
	monsters_killed_changed.emit(monsters_killed)  # ← ОБНОВЛЯЕМ ИНТЕРФЕЙС
	stats_changed.emit()  # ← Добавьте это для обновления характеристик

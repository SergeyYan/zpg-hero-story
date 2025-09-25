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
var is_invisible: bool = false
var status_library: Dictionary = {}

# Геттеры для удобства
func get_max_health() -> int: return stats_system.get_max_health()
func get_damage() -> int: return stats_system.get_damage() 
func get_defense() -> int: return stats_system.get_defense()
func get_health_regen() -> float: return stats_system.get_health_regen()
func get_level() -> int: return level


func _ready():
	add_to_group("player_stats")
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
	calculate_current_level()
	
func calculate_current_level() -> int:
	# Комбинируем реальный уровень и характеристики
	var calculated_level = level
	return calculated_level

func _init_status_library():
	var now_level = calculate_current_level()  # ← Используем функцию
	print("🎯 Расчет уровня для статусов: ", calculate_current_level())
	# ПОЛОЖИТЕЛЬНЫЕ СТАТУСЫ (голубой/золотой)
	status_library["well_fed"] = StatusEffect.new(
		"well_fed", "Хорошо покушал", "Бонус к характеристикам",  
		StatusEffect.StatusType.POSITIVE, randf_range(300, 720)  # 5-10 минут
	)
	status_library["well_fed"].strength_modifier = max(1, level - 5)
	status_library["well_fed"].fortitude_modifier = max(1, now_level - 5)
	status_library["well_fed"].endurance_modifier = max(1, now_level - 5)
	status_library["well_fed"].luck_modifier = max(1, now_level - 5)
	
	status_library["good_shoes"] = StatusEffect.new(
		"good_shoes", "Удобная обувь", "Увеличение скорости передвижения", 
		StatusEffect.StatusType.POSITIVE, randf_range(300, 600)
	)
	status_library["good_shoes"].speed_modifier = 1.25
	
	status_library["inspired"] = StatusEffect.new(
		"inspired", "Вдохновение", "Вы в ударе, бонус удачи и регенерации", 
		StatusEffect.StatusType.POSITIVE, randf_range(240, 720)  # 4-8 минут
	)
	status_library["inspired"].luck_modifier = max(2, now_level - 8)
	status_library["inspired"].health_regen_modifier = 0.5
	
	status_library["adrenaline"] = StatusEffect.new(
		"adrenaline", "Выброс адреналина", "увеличение скорости, силы, уменьшение выносливости",
		StatusEffect.StatusType.POSITIVE, randf_range(180, 540)  # 3-5 минут
	)
	status_library["adrenaline"].speed_modifier = 1.25
	status_library["adrenaline"].strength_modifier = max(3, now_level - 5)
	status_library["adrenaline"].fortitude_modifier = min(-3, 10 - now_level)
	
	status_library["lucky_day"] = StatusEffect.new(
		"lucky_day", "Счастливый день", "Удвоенный шанс крита", 
		StatusEffect.StatusType.POSITIVE, randf_range(300, 900)  # 10-15 минут
	)
	status_library["lucky_day"].luck_modifier = max(10, now_level - 5)
	
	status_library["potion_splash"] = StatusEffect.new(
		"potion_splash", "Облился зельем", "У вас ростут новые конечности",  
		StatusEffect.StatusType.POSITIVE, randf_range(90, 240)  # 10-15 секунд
	)
	status_library["potion_splash"].health_regen_modifier = 5.0
	
	# 2. "Съел непонятный гриб" - увеличение скорости
	status_library["strange_mushroom"] = StatusEffect.new(
		"strange_mushroom", "Съел непонятный гриб", "Суперскорость", 
		StatusEffect.StatusType.POSITIVE, randf_range(60, 300)  # 20-30 секунд
	)
	status_library["strange_mushroom"].speed_modifier = 2.0  # ×2 скорости
	
	# 3. "Надел плащ-палатку" - невидимость (специальная логика)
	status_library["cloak_tent"] = StatusEffect.new(
		"cloak_tent", "Надел плащ-палатку", "Невидимость", 
		StatusEffect.StatusType.POSITIVE, randf_range(30, 90)  # 30-90 секунд
	)
	# Невидимость будет обрабатываться отдельно в коде игрока
	
	# 4. "Выпил напиток мага" - увеличение урона
	status_library["mage_potion"] = StatusEffect.new(
		"mage_potion", "Выпил напиток берсерка", "Больше силы, меньше крепости", 
		StatusEffect.StatusType.POSITIVE, randf_range(90, 600)  # 20-25 секунд
	)
	status_library["mage_potion"].strength_modifier = max(5, now_level)  # +5 к силе
	status_library["mage_potion"].fortitude_modifier = min(-5, -now_level) 
	
	# 5. "Нашел перо феникса" - защита
	status_library["phoenix_feather"] = StatusEffect.new(
		"phoenix_feather", "Нашел перо феникса", "Повышение защиты", 
		StatusEffect.StatusType.POSITIVE, randf_range(90, 720)  # 35-40 секунд
	)
	status_library["phoenix_feather"].fortitude_modifier = max(10, now_level + 2)  # +10 к защите
	
	# Особый статус - обрабатывается отдельно
	
	# 6. "Мыслитель" - опыт
	status_library["thinker"] = StatusEffect.new(
		"thinker", "Звездой по голове", "Опыт вливается ручьем и головная боль", 
		StatusEffect.StatusType.POSITIVE, randf_range(10, 30)  # 10-30 секунд
	)
	status_library["thinker"].fortitude_modifier = min(-1, 9 - now_level)
		# Особый статус - обрабатывается отдельно
	
	# НЕГАТИВНЫЕ СТАТУСЫ (красный)
	status_library["sore_knees"] = StatusEffect.new(
		"sore_knees", "Боль в коленях", "Вы хромаете", 
		StatusEffect.StatusType.NEGATIVE, randf_range(180, 600)
	)
	status_library["sore_knees"].speed_modifier = 0.85
	
	status_library["crying"] = StatusEffect.new(
		"crying", "Плакал", "Характеристики утекают со слезами", 
		StatusEffect.StatusType.NEGATIVE, randf_range(180, 360)  # 3-6 минут
	)
	status_library["crying"].strength_modifier = min(-1, 10 - now_level)
	status_library["crying"].fortitude_modifier = min(-1, 10 - now_level)
	status_library["crying"].endurance_modifier = min(-1, 10 - now_level)
	status_library["crying"].luck_modifier = min(-1, 10 - now_level)
	
	status_library["exhausted"] = StatusEffect.new(
		"exhausted", "Истощение", "Меньше регенерации и скорости", 
		StatusEffect.StatusType.NEGATIVE, randf_range(180, 540)  # 7-12 минут
	)
	status_library["exhausted"].speed_modifier = 0.75
	status_library["exhausted"].health_regen_modifier = -0.5
	
	status_library["bad_luck"] = StatusEffect.new(
		"bad_luck", "Неудачный день", "Прощай удача", 
		StatusEffect.StatusType.NEGATIVE, randf_range(120, 660)  # 2-7 минут
	)
	status_library["bad_luck"].luck_modifier = min(-5, 5 - now_level)
	
	status_library["minor_injury"] = StatusEffect.new(
		"minor_injury", "Легкое ранение", "А где выносливость и крепость?", 
		StatusEffect.StatusType.NEGATIVE, randf_range(240, 480)  # 4-8 минут
	)
	status_library["minor_injury"].endurance_modifier = min(-1, 9 - now_level)
	status_library["minor_injury"].fortitude_modifier = min(-1, 9 - now_level)

	# 6. "Увяз в болоте" - замедление
	status_library["swamp_bog"] = StatusEffect.new(
		"swamp_bog", "Увяз в болоте", "Замедление", 
		StatusEffect.StatusType.NEGATIVE, randf_range(30, 240)  # 12-15 секунд
	)
	status_library["swamp_bog"].speed_modifier = 0.4  # ×0.4 скорости
	
	# 7. "Укус ядовитой змеи" - периодический урон
	status_library["snake_bite"] = StatusEffect.new(
		"snake_bite", "Укус опытной змеи", "Потеря опыта, а где реген?", 
		StatusEffect.StatusType.NEGATIVE, randf_range(10, 30)  # 10-12 секунд
	)
	status_library["snake_bite"].health_regen_modifier = -2
	# Урон будет обрабатываться отдельно
	
	# 8. "Ошеломлен ударом" - оглушение
	status_library["stunned"] = StatusEffect.new(
		"stunned", "Ошеломлен ударом", "Не может двигаться", 
		StatusEffect.StatusType.NEGATIVE, randf_range(10, 60)  # 3-5 секунд
	)
	status_library["stunned"].speed_modifier = -10.0
	# Оглушение будет обрабатываться отдельно

func _create_status_timer():
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_statuses)
	timer.process_mode = Node.PROCESS_MODE_ALWAYS  # ← ТАЙМЕР ТОЖЕ ВСЕГДА
	add_child(timer)
	timer.start()

func _update_statuses():
	
	# ПРОВЕРЯЕМ ГЛОБАЛЬНУЮ ПАУЗУ (меню, распределение характеристик)
	if get_tree().paused:
		# Проверяем, это пауза в бою или глобальная пауза?
		var battle_system = get_tree().get_first_node_in_group("battle_system")
		if not battle_system or not battle_system.visible:
			return  # ГЛОБАЛЬНАЯ ПАУЗА - не обновляем статусы
	
	var statuses_to_remove = []
	var was_invisible = is_invisible
	is_invisible = false
	
	for status in active_statuses:
		status.duration -= 1.0
		
		# ОБРАБОТКА СПЕЦИАЛЬНЫХ ЭФФЕКТОВ
		match status.id:
			"snake_bite":
				# Уменьшение опыта каждую секунду вместо урона
				if current_exp > 0:
					current_exp = max(0, current_exp - 1)  # -1 exp в секунду
					exp_gained.emit()  # Обновляем UI опыта
			"cloak_tent":
				is_invisible = true
			"thinker":
				if current_exp >= 0:
					current_exp = current_exp + 2  # +2 exp в секунду
					exp_gained.emit()  # Обновляем UI опыта
			
		if status.duration <= 0:
			statuses_to_remove.append(status)
			
	if was_invisible != is_invisible:
		statuses_changed.emit()  # Обновим UI
	
	for status in statuses_to_remove:
		active_statuses.erase(status)
	
	if statuses_to_remove.size() > 0:
		statuses_changed.emit()
		stats_changed.emit()

func is_player_invisible() -> bool:
	for status in active_statuses:
		if status.id == "cloak_tent":
			return true
	return false

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
			template.id, 
			template.name, 
			template.description,
			template.type, 
			template.duration  # случайная длительность
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
	# БАЗОВЫЕ значения (копируем)
	var base_stats = {
		"speed": 1.0,
		"strength": stats_system.strength,
		"fortitude": stats_system.fortitude, 
		"endurance": stats_system.endurance,
		"luck": stats_system.luck,
		#"health_regen": stats_system.get_health_regen()
	}
	
	# НАКАПЛИВАЕМ бонусы ОТДЕЛЬНО
	var total_speed_bonus = 0.0
	var total_strength_bonus = 0
	var total_fortitude_bonus = 0
	var total_endurance_bonus = 0
	var total_luck_bonus = 0
	var total_health_regen_bonus = 0.0
	
	for i in range(active_statuses.size()):
		var status = active_statuses[i]
		
		total_speed_bonus += (status.speed_modifier - 1.0)
		total_strength_bonus += status.strength_modifier
		total_fortitude_bonus += status.fortitude_modifier
		total_endurance_bonus += status.endurance_modifier
		total_luck_bonus += status.luck_modifier
		total_health_regen_bonus += status.health_regen_modifier
		
	# ПРИМЕНЯЕМ бонусы ОДИН РАЗ
	var result = {
		"speed": max(0.0, base_stats.speed + total_speed_bonus),
		"strength": max(0, base_stats.strength + total_strength_bonus),
		"fortitude": max(0, base_stats.fortitude + total_fortitude_bonus),
		"endurance": max(0, base_stats.endurance + total_endurance_bonus),
		"luck": max(0, base_stats.luck + total_luck_bonus),
		"health_regen": max(0.0, (base_stats.endurance + total_endurance_bonus) * 0.5 + total_health_regen_bonus)
	}
		
	return result

func _get_active_statuses_data() -> Array:
	var statuses_data = []
	for status in active_statuses:
		statuses_data.append({
			"id": status.id,
			"duration": status.duration
		})
	return statuses_data

func get_crit_chance_with_modifiers() -> float:
	var base_chance = stats_system.get_crit_chance()
	for status in active_statuses:
		if status.id == "lucky_day":
			base_chance *= 2.0
	return base_chance


# Методы для получения статусов в разных ситуациях
func apply_post_battle_effects():
	if randf() < 0.3:  # 30% шанс получить негативный статус после боя
		var negative_statuses = ["sore_knees", "minor_injury", "exhausted", "swamp_bog", "snake_bite", "stunned"]
		add_status(negative_statuses[randi() % negative_statuses.size()])
	
	if randf() < 0.4:  # 40% шанс получить позитивный статус
		var positive_statuses = ["thinker", "well_fed", "adrenaline", "inspired", "potion_splash", "strange_mushroom", "mage_potion", "phoenix_feather"] 
		add_status(positive_statuses[randi() % positive_statuses.size()])


func apply_movement_effects():
	if randf() < 0.2:  # 10% шанс при движении
		if randf() < 0.6:  # 60% из них - положительные
			var positive_statuses = ["thinker", "good_shoes", "adrenaline", "cloak_tent"]
			add_status(positive_statuses[randi() % positive_statuses.size()])
		else:
			var negative_statuses = ["sore_knees", "swamp_bog"]
			add_status(negative_statuses[randi() % negative_statuses.size()])

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
		# ИСПОЛЬЗУЕМ ЭФФЕКТИВНУЮ регенерацию с учетом статусов
		var effective_stats = get_effective_stats()
		var regen_per_second = effective_stats["health_regen"]
		accumulated_regen += regen_per_second * delta
		
		# Добавляем только когда накопился целый HP
		if accumulated_regen >= 1.0:
			var hp_to_add = floor(accumulated_regen)
			current_health = clamp(current_health + hp_to_add, 0, get_max_health())
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
	_load_active_statuses(data.get("active_statuses", []))
	
	health_changed.emit(current_health)  # ← Только здоровье обновляем
	monsters_killed_changed.emit(monsters_killed)  # ← ОБНОВЛЯЕМ ИНТЕРФЕЙС
	stats_changed.emit()  # ← Добавьте это для обновления характеристик


func _load_active_statuses(statuses_data: Array):
	# Очищаем текущие статусы
	active_statuses.clear()
	
	for status_data in statuses_data:
		var status_id = status_data["id"]
		var duration = status_data["duration"]
		
		if status_library.has(status_id):
			var template = status_library[status_id]
			var new_status = StatusEffect.new(
				template.id, 
				template.name, 
				template.description,
				template.type, 
				duration  # Восстанавливаем сохраненную длительность
			)
			
			# Копируем модификаторы
			new_status.speed_modifier = template.speed_modifier
			new_status.strength_modifier = template.strength_modifier
			new_status.fortitude_modifier = template.fortitude_modifier
			new_status.endurance_modifier = template.endurance_modifier
			new_status.luck_modifier = template.luck_modifier
			new_status.health_regen_modifier = template.health_regen_modifier
			
			active_statuses.append(new_status)
	
	# Обновляем UI
	statuses_changed.emit()
	stats_changed.emit()

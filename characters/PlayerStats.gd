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
signal bad_luck_changed(active: bool)

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


func get_crit_chance_against(defender_endurance: int) -> float:
	var effective_stats = get_effective_stats()
	return stats_system.get_crit_chance(effective_stats["luck"], defender_endurance)

func get_crit_defense_chance_against(attacker_luck: int) -> float:
	var effective_stats = get_effective_stats()
	return stats_system.get_crit_defense_chance(attacker_luck, effective_stats["endurance"])

func get_dodge_chance_against(attacker_luck: int) -> float:
	var effective_stats = get_effective_stats()
	return stats_system.get_dodge_chance(effective_stats["agility"], attacker_luck)

func get_hit_chance_against(defender_agility: int) -> float:
	var effective_stats = get_effective_stats()
	var base_chance = stats_system.get_hit_chance(effective_stats["luck"], defender_agility)
	
	# Добавляем бонус баланса
	var balanced_bonus = get_balanced_hit_chance_bonus()
	var final_chance = base_chance + balanced_bonus
	
	return clamp(final_chance, 0.01, 0.99)
	
# Геттеры для удобства
func get_max_health() -> int:
	# Используем ЭФФЕКТИВНУЮ выносливость (с учетом статусов)
	var effective_stats = get_effective_stats()
	return stats_system.base_health + (effective_stats["endurance"] * 5)
func get_damage() -> int: return stats_system.get_damage() 
func get_defense() -> int: return stats_system.get_defense()
func get_health_regen() -> float: return stats_system.get_health_regen()
func get_level() -> int: return level
func get_effective_defense() -> int:
	var effective_stats = get_effective_stats()
	var base_def = stats_system.base_defense + effective_stats["fortitude"]
	var min_defense = max(1, base_def)
	var max_defense = base_def + 3
	
	# Добавляем бонус баланса
	var balanced_bonus = get_balanced_defense_bonus()
	return randi_range(min_defense + balanced_bonus, max_defense + balanced_bonus)

func get_effective_damage() -> int:
	var effective_stats = get_effective_stats()
	var base_dmg = stats_system.base_damage + effective_stats["strength"]
	var min_damage = max(1, base_dmg)
	var max_damage = base_dmg + 3
	
	# Добавляем бонус баланса
	var balanced_bonus = get_balanced_damage_bonus()
	return randi_range(min_damage + balanced_bonus, max_damage + balanced_bonus)


func _ready():
	add_to_group("player_stats")
	process_mode = Node.PROCESS_MODE_ALWAYS  
	
	# 1. Сначала базовая инициализация характеристик
	stats_system.strength = 1
	stats_system.fortitude = 0
	stats_system.agility = 0
	stats_system.endurance = 0
	stats_system.luck = 0
	stats_system.base_health = 5  # ↓ Базовое здоровье
	
	level = 1
	available_points = 3  # ← Очки для распределения при старте
	current_health = get_max_health()
	
	# 2. Ждем загрузки сохранения (если есть)
	await get_tree().process_frame
	
	# 3. ТЕПЕРЬ инициализируем статусы с ПРАВИЛЬНЫМ уровнем
	if status_library.is_empty():
		_init_status_library()
	
	# 4. Таймер для обновления статусов
	_create_status_timer()
		
	# 5. Немедленно показываем меню распределения
	level_up.emit(level, available_points)  # ← Сигнал при старте
	

func _init_status_library():
	var now_level = level  # ← Используем ПРЯМО переменную level
	#print("🎯 Расчет уровня для статусов: ", now_level)
	
	# ПОЛОЖИТЕЛЬНЫЕ СТАТУСЫ (голубой/золотой)
	status_library["well_fed"] = StatusEffect.new(
		"well_fed", "Объелся как удав", "Живот трещит, но зато как вырос!",  
		StatusEffect.StatusType.POSITIVE, randf_range(240, 720)  # 5-10 минут
	)
	status_library["well_fed"].strength_modifier = max(1, now_level/1.5)
	status_library["well_fed"].fortitude_modifier = max(1, now_level/1.5)
	status_library["well_fed"].agility_modifier = max(1, now_level/1.5)
	status_library["well_fed"].endurance_modifier = max(1, now_level/1.5)
	status_library["well_fed"].luck_modifier = max(1, now_level/1.5)
	
	status_library["good_shoes"] = StatusEffect.new(
		"good_shoes", "Нашел кроссовки Nuke", "Чувствуешь себя Форрестом Гампом!", 
		StatusEffect.StatusType.POSITIVE, randf_range(120, 600)
	)
	status_library["good_shoes"].speed_modifier = 1.25
	status_library["good_shoes"].agility_modifier = max(1, now_level/2.5)
	
	status_library["inspired"] = StatusEffect.new(
		"inspired", "Вдохновился игрой", "Тебе кажется, что ты можешь всё!", 
		StatusEffect.StatusType.POSITIVE, randf_range(240, 720)  # 4-8 минут
	)
	status_library["inspired"].luck_modifier = max(2, now_level/1.3)
	status_library["inspired"].health_regen_modifier = 0.5
	
	status_library["adrenaline"] = StatusEffect.new(
		"adrenaline", "Выпил 7 чашек кофе", "Руки трясутся и хочется в туалет, зато удары быстры и болезнены!",
		StatusEffect.StatusType.POSITIVE, randf_range(180, 540)  # 3-5 минут
	)
	status_library["adrenaline"].speed_modifier = 1.25
	status_library["adrenaline"].strength_modifier = max(3, now_level - 5)
	status_library["adrenaline"].fortitude_modifier = min(-3, 10 - now_level)
	status_library["adrenaline"].health_regen_modifier = min(-0.5, 10 - now_level/2.0)
	
	status_library["lucky_day"] = StatusEffect.new(
		"lucky_day", "Счастливый день", "Даже монеты падают ребром!", 
		StatusEffect.StatusType.POSITIVE, randf_range(300, 900)  # 10-15 минут
	)
	status_library["lucky_day"].luck_modifier = max(10, now_level - 5)
	status_library["lucky_day"].agility_modifier = min(-10, -now_level/2.0)
	status_library["lucky_day"].health_regen_modifier = 10
	
	status_library["potion_splash"] = StatusEffect.new(
		"potion_splash", "Облился зельем", "У вас ростут новые конечности",  
		StatusEffect.StatusType.POSITIVE, randf_range(90, 300)  # 10-15 секунд
	)
	status_library["potion_splash"].health_regen_modifier = max(5, now_level - 4)
	
	# 2. "Съел непонятный гриб" - увеличение скорости
	status_library["strange_mushroom"] = StatusEffect.new(
		"strange_mushroom", "Съел непонятный гриб", "Мир стал ярче, а ноги быстрее!", 
		StatusEffect.StatusType.POSITIVE, randf_range(60, 300)  # 20-30 секунд
	)
	status_library["strange_mushroom"].speed_modifier = 2.0  # ×2 скорости
	status_library["strange_mushroom"].agility_modifier = max(1, now_level/2.0)
	status_library["strange_mushroom"].luck_modifier = min(-1, -now_level/2.0) 
	
	# 3. "Надел плащ-палатку" - невидимость (специальная логика)
	status_library["cloak_tent"] = StatusEffect.new(
		"cloak_tent", "Надел плащ-палатку", "Тебя не видно, но ты все еще здесь!", 
		StatusEffect.StatusType.POSITIVE, randf_range(30, 90)  # 30-90 секунд
	)
	# Невидимость будет обрабатываться отдельно в коде игрока
	
	# 4. "Выпил напиток мага" - увеличение урона
	status_library["mage_potion"] = StatusEffect.new(
		"mage_potion", "Выпил напиток берсерка", "Сила варвара, но хрупкость балерины", 
		StatusEffect.StatusType.POSITIVE, randf_range(90, 600)  # 20-25 секунд
	)
	status_library["mage_potion"].strength_modifier = max(5, now_level)  # +5 к силе
	status_library["mage_potion"].fortitude_modifier = min(-5, -now_level) 
	
	# 5. "Нашел перо феникса" - защита
	status_library["phoenix_feather"] = StatusEffect.new(
		"phoenix_feather", "Нашел перо жар-дракона", "Кожа как с ... дракона, а огня нет!", 
		StatusEffect.StatusType.POSITIVE, randf_range(90, 720)  # 35-40 секунд
	)
	status_library["phoenix_feather"].fortitude_modifier = max(10, now_level + 2)  # +10 к защите
	
	# Особый статус - обрабатывается отдельно
	
	# 6. "Мыслитель" - опыт
	status_library["thinker"] = StatusEffect.new(
		"thinker", "Звездой по голове", "Опыт течет рекой, а голова болит как после экзамена!", 
		StatusEffect.StatusType.POSITIVE, randf_range(10, 30)  # 10-30 секунд
	)
	status_library["thinker"].endurance_modifier = min(-1, 5 - now_level/2.0)
		# Особый статус - обрабатывается отдельно
	
	# НЕГАТИВНЫЕ СТАТУСЫ (красный)
	status_library["sore_knees"] = StatusEffect.new(
		"sore_knees", "Вспомнил, что тебе не 18", "Колени хрустят как осенняя листва!", 
		StatusEffect.StatusType.NEGATIVE, randf_range(180, 600)
	)
	status_library["sore_knees"].speed_modifier = 0.85
	status_library["sore_knees"].agility_modifier = min(-1, 10 - now_level/3.0)
	
	status_library["crying"] = StatusEffect.new(
		"crying", "Плакал", "Слезы мешают видеть врагов... и вообще все!", 
		StatusEffect.StatusType.NEGATIVE, randf_range(180, 360)  # 3-6 минут
	)
	status_library["crying"].strength_modifier = min(-1, 10 - now_level)
	status_library["crying"].fortitude_modifier = min(-1, 10 - now_level)
	status_library["crying"].agility_modifier = min(-1, 10 - now_level)
	status_library["crying"].endurance_modifier = min(-1, 10 - now_level)
	status_library["crying"].luck_modifier = min(-1, 10 - now_level)
	
	status_library["exhausted"] = StatusEffect.new(
		"exhausted", "Бегал от монстров до утра", "Глаза слипаются, а ноги ватные!", 
		StatusEffect.StatusType.NEGATIVE, randf_range(180, 540)  # 7-12 минут
	)
	status_library["exhausted"].speed_modifier = 0.75
	status_library["exhausted"].agility_modifier = min(-1, 3 - now_level/3.0)
	status_library["exhausted"].health_regen_modifier = min(-0.5, 3 - now_level/3.0)
	
	status_library["bad_luck"] = StatusEffect.new(
		"bad_luck", "Неудачный день", "Теперь даже стул подставляет подножку!", 
		StatusEffect.StatusType.NEGATIVE, randf_range(120, 660)  # 2-7 минут
	)
	status_library["bad_luck"].luck_modifier = min(-5, - now_level + 5)
	status_library["bad_luck"].agility_modifier = max(5, now_level - 5)
	status_library["bad_luck"].health_regen_modifier = 10
	
	status_library["minor_injury"] = StatusEffect.new(
		"minor_injury", "Наступил на детальку LEGO", "Больно, но не смертельно...", 
		StatusEffect.StatusType.NEGATIVE, randf_range(120, 480)  # 4-8 минут
	)
	status_library["minor_injury"].strength_modifier = max(3, now_level - 8)
	status_library["minor_injury"].endurance_modifier = min(-1, 5 - now_level/2.0)
	status_library["minor_injury"].fortitude_modifier = min(-1, 5 - now_level/2.0)
	status_library["minor_injury"].speed_modifier = 0.6  # ×0.4 скорости

	# 6. "Увяз в болоте" - замедление
	status_library["swamp_bog"] = StatusEffect.new(
		"swamp_bog", "Увяз в болоте", "Двигаешься как в клейстере!", 
		StatusEffect.StatusType.NEGATIVE, randf_range(30, 240)  # 12-15 секунд
	)
	status_library["swamp_bog"].speed_modifier = 0.4  # ×0.4 скорости
	status_library["swamp_bog"].agility_modifier = min(-1, 5 - now_level/3.0)
	
	# 7. "Укус ядовитой змеи" - периодический урон
	status_library["snake_bite"] = StatusEffect.new(
		"snake_bite", "Укус опытной змеи", "Опыт утекает,а вместе с ним и реген?", 
		StatusEffect.StatusType.NEGATIVE, randf_range(10, 30)  # 10-12 секунд
	)
	status_library["snake_bite"].health_regen_modifier = -100
	# Урон будет обрабатываться отдельно
	
	# 8. "Ошеломлен ударом" - оглушение
	status_library["stunned"] = StatusEffect.new(
		"stunned", "Получил по шапке", "В голове звенит, а в глазах соловушки!", 
		StatusEffect.StatusType.NEGATIVE, randf_range(10, 60)  # 3-5 секунд
	)
	status_library["stunned"].speed_modifier = -10.0
	# Оглушение будет обрабатываться отдельно

	status_library["sleepy"] = StatusEffect.new(
	"sleepy", "Не выспался", "Зевнул так, что челюсть хрустнула!", 
	StatusEffect.StatusType.NEGATIVE, randf_range(120, 360)
)
	status_library["sleepy"].strength_modifier = max(5, now_level + 5)
	status_library["sleepy"].fortitude_modifier = min(-5, 5 - now_level/2.0)
	status_library["sleepy"].agility_modifier = min(-1, 3 - now_level/3.0)
	status_library["sleepy"].endurance_modifier = min(-1, 5 - now_level/2.5)
	status_library["sleepy"].luck_modifier = max(5, now_level + 2)
	status_library["sleepy"].speed_modifier = 0.5
	
	
	
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
					current_exp = max(0, current_exp - max(1, level))  # -1 exp в секунду
					exp_gained.emit()  # Обновляем UI опыта
			"cloak_tent":
				is_invisible = true
			"thinker":
				if current_exp >= 0:
					current_exp = current_exp + max(2, level + level/4.0)   # от 2 exp в секунду
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
		_update_max_health()

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
		new_status.agility_modifier = template.agility_modifier
		new_status.endurance_modifier = template.endurance_modifier
		new_status.luck_modifier = template.luck_modifier
		new_status.health_regen_modifier = template.health_regen_modifier
		
		
		active_statuses.append(new_status)
		statuses_changed.emit()
		stats_changed.emit()
		_update_max_health()
	
	# ← ВЫЗЫВАЕМ СИГНАЛ ДЛЯ BAD_LUCK
		if status_id == "bad_luck":
			bad_luck_changed.emit(true)

func remove_status(status_id: String):
	for i in range(active_statuses.size() - 1, -1, -1):
		if active_statuses[i].id == status_id:
			active_statuses.remove_at(i)
			statuses_changed.emit()
			stats_changed.emit()
			_update_max_health()
			
			# ← ВЫЗЫВАЕМ СИГНАЛ ДЛЯ BAD_LUCK
			if status_id == "bad_luck":
				bad_luck_changed.emit(false)
			break

func get_effective_stats() -> Dictionary:
	# БАЗОВЫЕ значения (копируем)
	var base_stats = {
		"speed": 1.0,
		"strength": stats_system.strength,
		"fortitude": stats_system.fortitude, 
		"agility": stats_system.agility,
		"endurance": stats_system.endurance,
		"luck": stats_system.luck
		#"health_regen": stats_system.get_health_regen()
	}
	
	# НАКАПЛИВАЕМ бонусы ОТДЕЛЬНО
	var total_speed_bonus = 0.0
	var total_strength_bonus = 0
	var total_fortitude_bonus = 0
	var total_agility_bonus = 0
	var total_endurance_bonus = 0
	var total_luck_bonus = 0
	var total_health_regen_bonus = 0.0
	
	for i in range(active_statuses.size()):
		var status = active_statuses[i]
		
		total_speed_bonus += (status.speed_modifier - 1.0)
		total_strength_bonus += status.strength_modifier
		total_fortitude_bonus += status.fortitude_modifier
		total_agility_bonus += status.agility_modifier
		total_endurance_bonus += status.endurance_modifier
		total_luck_bonus += status.luck_modifier
		total_health_regen_bonus += status.health_regen_modifier
		
	# ПРИМЕНЯЕМ бонусы ОДИН РАЗ
	var result = {
		"speed": max(0.0, base_stats.speed + total_speed_bonus),
		"strength": max(0, base_stats.strength + total_strength_bonus),
		"fortitude": max(0, base_stats.fortitude + total_fortitude_bonus),
		"agility": max(0, base_stats.agility + total_agility_bonus),
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

func get_crit_chance_with_modifiers(defender_endurance: int) -> float:
	# Получаем базовый шанс крита по новой механике
	var effective_stats = get_effective_stats()
	var base_chance = stats_system.get_crit_chance(effective_stats["luck"], defender_endurance)
	
	# Применяем модификаторы статусов
	for status in active_statuses:
		if status.id == "lucky_day":
			base_chance *= 10.0  # Удваиваем шанс, но не более 95%
		elif status.id == "bad_luck":
			base_chance *= 0.01  # Уменьшаем до 10%, но не менее 1%
		elif status.id == "inspired":
			base_chance = min(base_chance + 0.15, 0.95)  # +15% к шансу крита
		elif status.id == "adrenaline":
			base_chance = min(base_chance + 0.10, 0.95)  # +10% к шансу крита
		elif status.id == "crying":
			base_chance = max(base_chance - 0.10, 0.01)  # -10% к шансу крита
		elif status.id == "exhausted":
			base_chance = max(base_chance - 0.15, 0.01)  # -15% к шансу крита

	var balanced_bonus = get_balanced_crit_chance_bonus()
	var final_chance = base_chance + balanced_bonus
	
	return clamp(final_chance, 0.01, 1.0)  # Ограничиваем от 1% до 95%

func get_balanced_dodge_chance_against(attacker_luck: int) -> float:
	var effective_stats = get_effective_stats()
	var base_chance = stats_system.get_dodge_chance(effective_stats["agility"], attacker_luck)
	var compensation_bonus = _get_defense_compensation_bonus(effective_stats)
	var final_chance = base_chance + compensation_bonus
	
	return clamp(final_chance, 0.01, 0.99)

func _get_defense_compensation_bonus(stats: Dictionary) -> float:
	var agility_fortitude_diff = stats["agility"] - stats["fortitude"]
	
	# Прогрессивный бонус за разницу Ловкость > Крепость
	if agility_fortitude_diff >= 80:
		return 0.3  # +30% за разницу 80+
	elif agility_fortitude_diff >= 50:
		return 0.2  # +20% за разницу 50-79
	elif agility_fortitude_diff >= 30:
		return 0.10  # +10% за разницу 30-49
	elif agility_fortitude_diff >= 15:
		return 0.05  # +5% за разницу 15-29
	else:
		return 0.0   # Нет бонуса

func get_balanced_damage_against(defender_fortitude: int) -> Dictionary:
	var base_damage = get_effective_damage()
	var compensation_bonus = _get_strength_compensation_bonus()
	
	var base_after_defense = max(1, base_damage - defender_fortitude)
	var piercing_damage = int(base_damage * compensation_bonus)
	
	return {
		"base_damage": base_after_defense,
		"piercing_damage": piercing_damage,
		"total_damage": base_after_defense + piercing_damage,
		"compensation_bonus": compensation_bonus
	}

func _get_strength_compensation_bonus() -> float:
	var effective_stats = get_effective_stats()
	var strength_endurance_diff = effective_stats["endurance"] - effective_stats["strength"]  # ← СВОИ характеристики
	
	if strength_endurance_diff >= 90:
		return 2.0  # +20% пробивающего урона
	elif strength_endurance_diff >= 70:
		return 1.6  # +15% пробивающего урона
	elif strength_endurance_diff >= 50:
		return 1.3  # +10% пробивающего урона
	elif strength_endurance_diff >= 30:
		return 1.0  # +5% пробивающего урона
	else:
		return 0.0   # Нет бонуса

# Методы для получения статусов в разных ситуациях
func apply_post_battle_effects():
	if randf() < 0.2:  # 20% шанс получить негативный статус после боя
		var negative_statuses = ["sore_knees", "minor_injury", "exhausted", "swamp_bog", "snake_bite", "stunned", "sleepy", "bad_luck"]
		add_status(negative_statuses[randi() % negative_statuses.size()])
	
	if randf() < 0.3:  # 30% шанс получить позитивный статус
		var positive_statuses = ["thinker", "well_fed", "adrenaline", "inspired", "potion_splash", "strange_mushroom", "mage_potion", "phoenix_feather", "lucky_day"] 
		add_status(positive_statuses[randi() % positive_statuses.size()])


func apply_movement_effects():
	if randf() < 0.2:  # 10% шанс при движении
		if randf() < 0.5:  # 50% из них - положительные
			var positive_statuses = ["well_fed", "thinker", "inspired", "good_shoes", "adrenaline", "cloak_tent", "lucky_day", "potion_splash", "strange_mushroom", "mage_potion", "phoenix_feather"]
			add_status(positive_statuses[randi() % positive_statuses.size()])
		else:
			var negative_statuses = ["sore_knees", "swamp_bog", "sleepy", "crying", "exhausted", "bad_luck", "minor_injury", "snake_bite"]
			add_status(negative_statuses[randi() % negative_statuses.size()])

func apply_level_up_effects():
	if randf() < 1:
		if randf() < 0.5:
			var positive_statuses = ["thinker", "lucky_day"]
			add_status(positive_statuses[randi() % positive_statuses.size()])
		else:
			var negative_statuses = ["bad_luck"]
			add_status(negative_statuses[randi() % negative_statuses.size()])

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

func _update_max_health():
	var old_max_health = get_max_health()
	var new_max_health = stats_system.base_health + (get_effective_stats()["endurance"] * 5)
	
	# Если максимальное здоровье уменьшилось - ограничиваем текущее
	if new_max_health < old_max_health and current_health > new_max_health:
		current_health = new_max_health
		health_changed.emit(current_health)

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
			achievement_manager.check_stats_achievements(self)  # Передаем сам PlayerStats

func increase_fortitude():
	if available_points > 0:
		stats_system.fortitude += 1  
		available_points -= 1
		stats_changed.emit()
		# ← ПРОВЕРКА ДОСТИЖЕНИЙ ХАРАКТЕРИСТИК
		var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
		if achievement_manager:
			achievement_manager.check_stats_achievements(self)  # Передаем сам PlayerStats

func increase_agility():
	if available_points > 0:
		stats_system.agility += 1
		available_points -= 1
		stats_changed.emit()
		# ← ПРОВЕРКА ДОСТИЖЕНИЙ ХАРАКТЕРИСТИК
		var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
		if achievement_manager:
			achievement_manager.check_stats_achievements(self)  # Передаем сам PlayerStats

func increase_endurance():
	if available_points > 0:
		stats_system.endurance += 1
		available_points -= 1
		stats_changed.emit()
		# ← ПРОВЕРКА ДОСТИЖЕНИЙ ХАРАКТЕРИСТИК
		var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
		if achievement_manager:
			achievement_manager.check_stats_achievements(self)  # Передаем сам PlayerStats

func increase_luck():
	if available_points > 0:
		stats_system.luck += 1
		available_points -= 1
		stats_changed.emit()
		# ← ПРОВЕРКА ДОСТИЖЕНИЙ ХАРАКТЕРИСТИК
		var achievement_manager = get_tree().get_first_node_in_group("achievement_manager")
		if achievement_manager:
			achievement_manager.check_stats_achievements(self)  # Передаем сам PlayerStats


func get_exp_for_next_level(current_level: int) -> int:
	# ← ФИКСИРОВАННОЕ КОЛИЧЕСТВО ПОБЕД ДЛЯ КАЖДОГО УРОВНЯ
	if current_level <= 0:
		return 100
	elif current_level <= 40:
		return current_level * 100
	else:
		return 4000


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
	
	_init_status_library()
	# НЕ вызываем сигнал level_up при загрузке!
	_load_active_statuses(data.get("active_statuses", []))
	
	health_changed.emit(current_health)  # ← Только здоровье обновляем
	monsters_killed_changed.emit(monsters_killed)  # ← ОБНОВЛЯЕМ ИНТЕРФЕЙС
	stats_changed.emit()  # ← Добавьте это для обновления характеристик

func _load_active_statuses(statuses_data: Array):
	# Очищаем текущие статусы
	active_statuses.clear()
	
	if status_library.is_empty():
		_init_status_library()
	
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

func is_balanced_build() -> bool:
	var effective_stats = get_effective_stats()
	var stats = [
		effective_stats["strength"],
		effective_stats["fortitude"], 
		effective_stats["agility"],
		effective_stats["endurance"],
		effective_stats["luck"]
	]
	
	# Находим минимальную и максимальную характеристику
	var min_stat = stats[0]
	var max_stat = stats[0]
	for stat in stats:
		min_stat = min(min_stat, stat)
		max_stat = max(max_stat, stat)
	
	# Проверяем, что разница между самой большой и самой маленькой характеристикой ≤ 5
	return (max_stat - min_stat) <= 5 and min_stat >= 10

# Бонус урона за баланс (зависит от уровня)
func get_balanced_damage_bonus() -> int:
	if not is_balanced_build():
		return 0
	
	# +1 урон за уровень, минимум +10, максимум +50
	return clamp(level, 1, 500000)

# Бонус шанса попадания за баланс
func get_balanced_hit_chance_bonus() -> float:
	if not is_balanced_build():
		return 0.0
	
	var effective_stats = get_effective_stats()
	var stats = [
		effective_stats["strength"],
		effective_stats["fortitude"],
		effective_stats["agility"], 
		effective_stats["endurance"],
		effective_stats["luck"]
	]
	
	# Рассчитываем насколько равномерно распределены характеристики
	var min_stat = stats[0]
	var max_stat = stats[0]
	for stat in stats:
		min_stat = min(min_stat, stat)
		max_stat = max(max_stat, stat)
	
	# Чем меньше разница между min и max, тем выше бонус (максимум 30%)
	var diff = max_stat - min_stat
	if diff <= 1:
		return 0.30  # Почти идеальный баланс
	elif diff <= 3:
		return 0.20  # Хороший баланс
	elif diff <= 5:
		return 0.10  # Базовый баланс
	else:
		return 0.0

# Бонус шанса крита за баланс  
func get_balanced_crit_chance_bonus() -> float:
	if not is_balanced_build():
		return 0.0
	
	var effective_stats = get_effective_stats()
	var stats = [
		effective_stats["strength"],
		effective_stats["fortitude"],
		effective_stats["agility"],
		effective_stats["endurance"],
		effective_stats["luck"]
	]
	
	# Рассчитываем "гармонию" характеристик
	var total = 0.0
	for stat in stats:
		total += stat
	var average = total / stats.size()
	
	# Считаем среднее отклонение от среднего
	var total_deviation = 0.0
	for stat in stats:
		total_deviation += abs(stat - average)
	var avg_deviation = total_deviation / stats.size()
	
	# Чем меньше отклонение, тем выше бонус (максимум 25%)
	if avg_deviation <= 0.0:
		return 0.25  # Идеальный баланс
	elif avg_deviation <= 1.0:
		return 0.20  # Отличный баланс
	elif avg_deviation <= 3.0:
		return 0.15  # Хороший баланс
	elif avg_deviation <= 5.0:
		return 0.10  # Умеренный баланс
	else:
		return 0.00  # Минимальный баланс

# Бонус защиты за баланс (подавление урона)
func get_balanced_defense_bonus() -> int:
	if not is_balanced_build():
		return 0
	
	# +1 защита за уровень, минимум +10, максимум +50
	return clamp(level, 1, 500000)

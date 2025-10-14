#MonsterStats.gd
extends Node
class_name MonsterStats

signal health_changed(new_health)
signal monster_died

# Система характеристик для монстров
var stats_system: StatsSystem = StatsSystem.new()

@export var enemy_name: String = "Монстр"
@export var strength: int = 0
@export var fortitude: int = 0
@export var agility: int = 0
@export var endurance: int = 0
@export var luck: int = 0
@export var exp_reward: int = get_exp_reward()

var current_health: int
var monster_level: int = 1
var _stats_initialized: bool = false  # ← Флаг инициализации
var _base_strength: int = 0  # ← Сохраняем базу отдельно
var _base_fortitude: int = 0
var _base_agility: int = 0
var _base_endurance: int = 0
var _base_luck: int = 0

func _ready():
	add_to_group("monster_stats")
	_generate_random_stats()
	_stats_initialized = true
		
	# ← ОТЛАДОЧНАЯ ИНФОРМАЦИЯ
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats and player_stats.level > 1 and monster_level == 1:
		apply_level_scaling(player_stats.level)
	

func apply_level_scaling(player_level: int):
	# ← ИСПРАВЛЯЕМ УСЛОВИЕ: масштабируем если уровень ИГРОКА выше ИЛИ характеристики не соответствуют
	if player_level <= monster_level and _stats_initialized:
		# ← ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: если характеристики как у 1 уровня - все равно масштабируем
		var total_stats = strength + fortitude + agility + endurance + luck
		if total_stats > 4 and _stats_initialized:  # Если характеристики уже правильные
			return
		
	monster_level = player_level
	_scale_stats_by_level()
	

func _scale_stats_by_level():
	# ← ВОССТАНАВЛИВАЕМ ИСХОДНУЮ БАЗУ (без случайных очков!)
	strength = 1  # ← ФИКСИРОВАННАЯ база: 1 сила
	fortitude = 0  # ← остальные 0
	agility = 0
	endurance = 0
	luck = 0
	
	var target_points: int
	
# ← НОВАЯ ФОРМУЛА: умное масштабирование относительно игрока
	if is_inside_tree():
		var player_stats = get_tree().get_first_node_in_group("player_stats")
		if player_stats:
			var player_level = player_stats.level
			var player_points = 4 + (player_level - 1) * 3
			
			var points_difference = clamp(5 - (player_level * 0.25), 1.5, 5.0)
			target_points = int(player_points - points_difference)
			target_points = max(3, target_points)
	else:
		target_points = (4 + (monster_level - 1) * 3) - 1
	# ← ТЕПЕРЬ добавляем ВСЕ очки (база + дополнительные)
	var current_points = 1  # ← Только базовая сила
	var points_to_add = target_points - current_points


	if points_to_add > 0:
		for i in range(points_to_add):
			var random_stat = randi() % 5
			match random_stat:
				0: strength += 1
				1: fortitude += 1  
				2: agility += 1
				3: endurance += 1
				4: luck += 1
	
	# Обновляем систему
	stats_system.strength = strength
	stats_system.fortitude = fortitude
	stats_system.agility = agility
	stats_system.endurance = endurance
	stats_system.luck = luck
	
	current_health = get_max_health()


func _generate_random_stats():
	# Монстр 1 уровня: 3 очка (1 сила + 2 случайных)
	strength = 1
	fortitude = 0
	agility = 0
	endurance = 0
	luck = 0
	
	# Сохраняем базу
	_base_strength = strength
	_base_fortitude = fortitude
	_base_agility = agility
	_base_endurance = endurance
	_base_luck = luck
	
	# Добавляем 2 случайных очка
	for i in range(2):
		var random_stat = randi() % 5
		match random_stat:
			0: strength += 1
			1: fortitude += 1
			2: agility += 1
			3: endurance += 1
			4: luck += 1
	
	# Обновляем систему
	stats_system.strength = strength
	stats_system.fortitude = fortitude
	stats_system.agility = agility
	stats_system.endurance = endurance
	stats_system.luck = luck
	#exp_reward = 10 * (strength + fortitude + endurance + luck) + (endurance * 5)
	current_health = get_max_health()

func get_max_health() -> int: return stats_system.get_max_health()
func get_damage() -> int:
	# Сила: 1 = 1-3 урона, 5 = 5-15, 10 = 10-30
	var base_dmg = stats_system.base_damage + stats_system.strength
	var min_damage = max(1, base_dmg)  # Минимальный урон
	var max_damage = base_dmg + 3      # Максимальный урон (×3)
	
	# Добавляем бонус баланса
	var balanced_bonus = get_balanced_damage_bonus()
	return randi_range(min_damage + balanced_bonus, max_damage + balanced_bonus)

func get_defense() -> int:
	# Крепость: 1 = 1-3 защиты, 5 = 5-15, 10 = 10-30  
	var base_def = stats_system.base_defense + stats_system.fortitude
	var min_defense = max(1, base_def)  # Минимальная защита
	var max_defense = base_def + 3      # Максимальная защита (×3)
	
	# Добавляем бонус баланса
	var balanced_bonus = get_balanced_defense_bonus()
	return randi_range(min_defense + balanced_bonus, max_defense + balanced_bonus)

func get_crit_chance_against(defender_endurance: int) -> float:
	var base_chance = stats_system.get_crit_chance(stats_system.luck, defender_endurance)
	
	# Добавляем бонус баланса
	var balanced_bonus = get_balanced_crit_chance_bonus()
	var final_chance = base_chance + balanced_bonus
	
	return clamp(final_chance, 0.01, 0.95)

func get_crit_defense_chance_against(attacker_luck: int) -> float:
	return stats_system.get_crit_defense_chance(attacker_luck, endurance)

func get_dodge_chance_against(attacker_luck: int) -> float:
	return stats_system.get_dodge_chance(agility, attacker_luck)

func get_hit_chance_against(defender_agility: int) -> float:
	var base_chance = stats_system.get_hit_chance(stats_system.luck, defender_agility)
	
	# Добавляем бонус баланса
	var balanced_bonus = get_balanced_hit_chance_bonus()
	var final_chance = base_chance + balanced_bonus
	
	return clamp(final_chance, 0.01, 0.99)

func get_balanced_dodge_chance_against(attacker_luck: int) -> float:
	var base_chance = get_dodge_chance_against(attacker_luck)
	var compensation_bonus = _get_defense_compensation_bonus()
	var final_chance = base_chance + compensation_bonus
	
	# Ограничиваем максимальный уворот (например, 75%)
	return clamp(final_chance, 0.01, 0.99)

func _get_defense_compensation_bonus() -> float:
	var agility_fortitude_diff = agility - fortitude
	
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

func get_balanced_damage_against(defender_endurance: int) -> Dictionary:
	var base_damage = get_damage()
	var compensation_bonus = _get_strength_compensation_bonus()
	
	# Базовый урон (учитывает защиту)
	var base_after_defense = max(1, base_damage - defender_endurance)
	
	# Пробивающий урон (игнорирует защиту)
	var piercing_damage = int(base_damage * compensation_bonus)
	
	return {
		"base_damage": base_after_defense,
		"piercing_damage": piercing_damage,
		"total_damage": base_after_defense + piercing_damage,
		"compensation_bonus": compensation_bonus
	}

func _get_strength_compensation_bonus() -> float:
	var strength_endurance_diff = endurance - strength  # ← Сравниваем СВОИ характеристики
	
	# Прогрессивный бонус за разницу Выносливость > Силы
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

func take_damage(amount: int):
	var actual_damage = max(1, amount)
	current_health -= actual_damage
	health_changed.emit(current_health)
	
	if current_health <= 0:
		monster_died.emit()
		current_health = 0

func heal(amount: int):
	current_health = min(current_health + amount, get_max_health())
	health_changed.emit(current_health)

func get_exp_reward() -> int:
	var base_exp = 20
	var final_exp = base_exp
	
	# ← ПРОВЕРЯЕМ, ЧТО МЫ В ДЕРЕВЕ СЦЕНЫ
	if not is_inside_tree():
		return 20 + (randi() % 10)
	
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	var has_bad_luck = false
	var has_lucky_day = false
	
	if player_stats:
		for status in player_stats.active_statuses:
			if status.id == "bad_luck":
				has_bad_luck = true
			if status.id == "lucky_day":
				has_lucky_day = true
	
	# ← ПРИМЕНЯЕМ МОДИФИКАТОРЫ
	if has_bad_luck and has_lucky_day:
		final_exp = base_exp  # Баланс
	elif has_bad_luck:
		final_exp = int(base_exp / 2)  # ← 50% при bad_luck
	elif has_lucky_day:
		final_exp = int(base_exp * 2)  # ← 150% при lucky_day

	# Добавляем небольшую случайность
	final_exp += randi() % 10
	return final_exp

func is_balanced_build() -> bool:
	var stats = [
		stats_system.strength,
		stats_system.fortitude, 
		stats_system.agility,
		stats_system.endurance,
		stats_system.luck
	]
	
	# Находим минимальную и максимальную характеристику
	var min_stat = stats[0]
	var max_stat = stats[0]
	for stat in stats:
		min_stat = min(min_stat, stat)
		max_stat = max(max_stat, stat)
	
	# Проверяем, что разница между самой большой и самой маленькой характеристикой ≤ 5
	return (max_stat - min_stat) <= 5 and min_stat >= 10

# Бонус урона за баланс (зависит от уровня монстра)
func get_balanced_damage_bonus() -> int:
	if not is_balanced_build():
		return 0
	# +1 урон за уровень, минимум +5, максимум +30 (монстры слабее игроков)
	return clamp(monster_level, 1, 300000)

# Бонус шанса попадания за баланс
func get_balanced_hit_chance_bonus() -> float:
	if not is_balanced_build():
		return 0.0
	
	var stats = [
		stats_system.strength,
		stats_system.fortitude,
		stats_system.agility, 
		stats_system.endurance,
		stats_system.luck
	]
	
	# Рассчитываем насколько равномерно распределены характеристики
	var min_stat = stats[0]
	var max_stat = stats[0]
	for stat in stats:
		min_stat = min(min_stat, stat)
		max_stat = max(max_stat, stat)
	
	# Чем меньше разница между min и max, тем выше бонус (максимум 20%)
	var diff = max_stat - min_stat
	if diff <= 1:
		return 0.20  # Почти идеальный баланс
	elif diff <= 3:
		return 0.15  # Хороший баланс
	elif diff <= 5:
		return 0.10  # Базовый баланс
	else:
		return 0.0

# Бонус шанса крита за баланс  
func get_balanced_crit_chance_bonus() -> float:
	if not is_balanced_build():
		return 0.0
	
	var stats = [
		stats_system.strength,
		stats_system.fortitude,
		stats_system.agility,
		stats_system.endurance,
		stats_system.luck
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
	
	# Чем меньше отклонение, тем выше бонус (максимум 20%)
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
	
	# +1 защита за уровень, минимум +5, максимум +30 (монстры слабее игроков)
	return clamp(monster_level, 1, 300000)

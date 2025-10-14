#StatsSystem.gd
extends Resource
class_name StatsSystem

# Основные характеристики
var strength: int = 1        # Сила - увеличивает урон
var fortitude: int = 1       # Крепость - увеличивает броню  
var endurance: int = 1       # Выносливость - увеличивает здоровье и регенерацию
var luck: int = 1            # Удача - увеличивает шанс крита и попадания
var agility: int = 1         # ← НОВАЯ: Ловкость - увеличивает шанс уворота

# Производные характеристики
var base_health: int = 1     # Базовое здоровье
var base_damage: int = 1     # Базовый урон
var base_defense: int = 1    # Базовая защита
var base_crit_chance: float = 0.01  # Базовый шанс крита 1%
var base_hit_chance: float = 1.0    # ← НОВАЯ: Базовый шанс попадания

# Расчетные значения
func get_max_health() -> int:
	return base_health + (endurance * 5)

#Механика атака
func get_damage() -> int:
	# Сила: 1 = 1-3 урона, 5 = 5-15, 10 = 10-30
	var base_dmg = base_damage + strength
	var min_damage = max(1, base_dmg)  # Минимальный урон
	var max_damage = base_dmg + 3      # Максимальный урон (×3)
	return randi_range(min_damage, max_damage)

#Механика защита
func get_defense() -> int:
	# Крепость: 1 = 1-3 защиты, 5 = 5-15, 10 = 10-30  
	var base_def = base_defense + fortitude
	var min_defense = max(1, base_def)  # Минимальная защита
	var max_defense = base_def + 3      # Максимальная защита (×3)
	return randi_range(min_defense, max_defense)

#Механика регенерации
func get_health_regen() -> float:
	return endurance * 0.5  # 0.5 здоровья в секунду за 1 выносливости

#Механика критического удара
func get_crit_chance(attacker_luck: int, defender_endurance: int) -> float:
	# Вычисляем разницу характеристик
	var stat_difference = attacker_luck - defender_endurance
	
	# Прогрессия на основе разницы
	if stat_difference <= 0:
		return 0.01  # Минимум 1% если выносливость больше удачи
	elif stat_difference <= 20:
		return stat_difference * 0.01  # 1-20%
	elif stat_difference <= 50:
		return 0.20 + (stat_difference - 20) * 0.005  # 20-35%
	elif stat_difference <= 100:
		return 0.35 + (stat_difference - 50) * 0.005  # 35-60%
	elif stat_difference <= 200:
		return 0.6 + (stat_difference - 100) * 0.003  # 70-90%
	else:
		return 0.90  # Максимум 90%

func get_crit_defense_chance(attacker_luck: int, defender_endurance: int) -> float:
	var crit_chance = get_crit_chance(attacker_luck, defender_endurance)
	var crit_defense_chance = 1.0 - crit_chance
	
	# Ограничиваем от 1% до 99%
	return clamp(crit_defense_chance, 0.01, 0.99)

#Расчет шанса уворота
func get_dodge_chance(defender_agility: int, attacker_luck: int) -> float:
	# Вычисляем разницу характеристик
	var stat_difference = defender_agility - attacker_luck
	
	# Прогрессия на основе разницы
	if stat_difference <= 0:
		return 0.01  # Минимум 1% если удача больше ловкости
	elif stat_difference <= 20:
		return stat_difference * 0.01  # 1-20%
	elif stat_difference <= 50:
		return 0.20 + (stat_difference - 20) * 0.005  # 20-35%
	elif stat_difference <= 100:
		return 0.35 + (stat_difference - 50) * 0.003  # 35-50%
	elif stat_difference <= 200:
		return 0.50 + (stat_difference - 100) * 0.002  # 50-70%
	else:
		return 0.70  # Максимум 70%

#Расчет шанса попадания (против уворота)
func get_hit_chance(attacker_luck: int, defender_agility: int) -> float:
	# Шанс попасть = 100% - шанс уворота
	var dodge_chance = get_dodge_chance(defender_agility, attacker_luck)
	var hit_chance = 1.0 - dodge_chance
	
	# Ограничиваем от 10% до 99%
	return clamp(hit_chance, 0.01, 0.99)

func get_balanced_damage_against(defender_fortitude: int) -> Dictionary:
	var base_damage = get_damage()
	var compensation_bonus = _get_strength_compensation_bonus()  # ← Без параметра!
	
	# Базовый урон (учитывает защиту)
	var base_after_defense = max(1, base_damage - defender_fortitude)
	
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
		return 0.30  # +20% пробивающего урона
	elif strength_endurance_diff >= 70:
		return 0.20  # +15% пробивающего урона
	elif strength_endurance_diff >= 50:
		return 0.15  # +10% пробивающего урона
	elif strength_endurance_diff >= 30:
		return 0.10  # +5% пробивающего урона
	else:
		return 0.0   # Нет бонуса

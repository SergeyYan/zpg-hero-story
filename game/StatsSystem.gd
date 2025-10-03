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
func get_crit_chance() -> float:
	return base_crit_chance + (luck * 0.01)  # 1% за каждую удачу

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
		return 0.50 + (stat_difference - 100) * 0.001  # 50-60%
	else:
		return 0.60  # Максимум 60%

#Расчет шанса попадания (против уворота)
func get_hit_chance(attacker_luck: int, defender_agility: int) -> float:
	# Шанс попасть = 100% - шанс уворота
	var dodge_chance = get_dodge_chance(defender_agility, attacker_luck)
	var hit_chance = 1.0 - dodge_chance
	
	# Ограничиваем от 10% до 99%
	return clamp(hit_chance, 0.1, 0.99)

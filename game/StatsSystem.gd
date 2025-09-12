#StatsSystem.gd
extends Resource
class_name StatsSystem

# Основные характеристики
var strength: int = 1        # Сила - увеличивает урон
var fortitude: int = 1       # Крепость - увеличивает броню  
var endurance: int = 1       # Выносливость - увеличивает здоровье и регенерацию

# Производные характеристики
var base_health: int = 1   # Базовое здоровье
var base_damage: int = 1    # Базовый урон
var base_defense: int = 1    # Базовая защита

# Расчетные значения
func get_max_health() -> int:
	return base_health + (endurance * 5)

func get_damage() -> int:
	# Сила: 1 = 1-3 урона, 5 = 5-15, 10 = 10-30
	var base_dmg = base_damage + strength
	var min_damage = max(1, base_dmg)  # Минимальный урон
	var max_damage = base_dmg * 3      # Максимальный урон (×3)
	return randi_range(min_damage, max_damage)

func get_defense() -> int:
	# Крепость: 1 = 1-3 защиты, 5 = 5-15, 10 = 10-30  
	var base_def = base_defense + fortitude
	var min_defense = max(1, base_def)  # Минимальная защита
	var max_defense = base_def * 3      # Максимальная защита (×3)
	return randi_range(min_defense, max_defense)

func get_health_regen() -> float:
	return endurance * 0.5  # 0.5 здоровья в секунду за 1 выносливости

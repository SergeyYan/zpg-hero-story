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
	return base_damage + int(strength * 0.5)

func get_defense() -> int:
	return base_defense + int(fortitude * 0.5)

func get_health_regen() -> float:
	return endurance * 0.5  # 0.5 здоровья в секунду за 1 выносливости

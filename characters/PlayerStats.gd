extends Node
class_name PlayerStats

signal health_changed(new_health)
signal level_up(new_level)
signal player_died
signal exp_gained()

# Заменяем статические значения на систему характеристик
var stats_system: StatsSystem = StatsSystem.new()

var current_health: int
var current_exp: int = 0
var exp_to_level: int = 100
var level: int = 1

var accumulated_regen: float = 0.0

# Геттеры для удобства
func get_max_health() -> int: return stats_system.get_max_health()
func get_damage() -> int: return stats_system.get_damage() 
func get_defense() -> int: return stats_system.get_defense()
func get_health_regen() -> float: return stats_system.get_health_regen()

func _ready():
	add_to_group("player_stats")
	current_health = get_max_health()  # Используем расчетное здоровье

func take_damage(amount: int):
	var actual_damage = max(1, amount - get_defense())  # Используем расчетную защиту
	current_health -= actual_damage
	health_changed.emit(current_health)
	
	if current_health <= 0:
		player_died.emit()
		current_health = 0

func heal(amount: int):
	current_health = min(current_health + amount, get_max_health())
	health_changed.emit(current_health)

# Регенерация здоровья вне боя
func regenerate_health(delta_time: float):
	if current_health < get_max_health():
		var regen_per_second = stats_system.endurance * 0.5
		accumulated_regen += regen_per_second * delta_time
		
		# Добавляем только когда накопился целый HP
		if accumulated_regen >= 1.0:
			var hp_to_add = floor(accumulated_regen)
			current_health = min(current_health + hp_to_add, get_max_health())
			accumulated_regen -= hp_to_add
			
			var display_health = int(current_health)
			health_changed.emit(display_health)
			print("Регенерация +", hp_to_add, " HP: ", display_health)

func add_exp(amount: int):
	current_exp += amount
	exp_gained.emit()  # ← Испускаем сигнал при получении опыта!
	if current_exp >= exp_to_level:
		_level_up()

func _level_up():
	level += 1
	current_exp -= exp_to_level
	exp_to_level = int(exp_to_level * 1.5)
	
	# Увеличиваем характеристики при уровне
	stats_system.strength += 1
	stats_system.fortitude += 1 
	stats_system.endurance += 2
	
	# Восстанавливаем здоровье до нового максимума
	current_health = get_max_health()
	level_up.emit(level)

#PlayerStat.gd
extends Node
class_name PlayerStats

signal health_changed(new_health)
signal level_up(new_level, available_points)  # ← Добавляем available_points
signal player_died
signal exp_gained()
signal stats_changed()  # ← НОВЫЙ СИГНАЛ при изменении характеристик!


# Заменяем статические значения на систему характеристик
var stats_system: StatsSystem = StatsSystem.new()
var current_health: int
var current_exp: int = 0
var exp_to_level: int = 100
var level: int = 1
var available_points: int = 0  # ← Очки для распределения

var accumulated_regen: float = 0.0

# Геттеры для удобства
func get_max_health() -> int: return stats_system.get_max_health()
func get_damage() -> int: return stats_system.get_damage() 
func get_defense() -> int: return stats_system.get_defense()
func get_health_regen() -> float: return stats_system.get_health_regen()
func get_level() -> int: return level


func _ready():
	add_to_group("player_stats")
	
	# Начальные характеристики
	stats_system.strength = 1
	stats_system.fortitude = 0
	stats_system.endurance = 0
	stats_system.luck = 0
	stats_system.base_health = 5  # ↓ Базовое здоровье
	
	current_health = get_max_health()
	
	# Начинаем с 1 уровня и даем очки для распределения
	level = 1
	available_points = 3  # ← Очки для распределения при старте
	
	# Немедленно показываем меню распределения
	await get_tree().process_frame
	level_up.emit(level, available_points)  # ← Сигнал при старте

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
			print("Регенерация +", hp_to_add, " HP: ", display_health, "/", get_max_health())

func add_exp(amount: int):
	# ← ПРОСТО ДОБАВЛЯЕМ ФИКСИРОВАННЫЙ ОПЫТ
	current_exp += amount
	exp_gained.emit()
	
	print("Получено опыта: ", amount, " (фиксированно)")
	

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
	print("🎉 Уровень ", level, "! Нужно опыта для след. уровня: ", exp_to_level)
	
	
func increase_strength():
	if available_points > 0:
		stats_system.strength += 1
		available_points -= 1
		stats_changed.emit()

func increase_fortitude():
	if available_points > 0:
		stats_system.fortitude += 1  
		available_points -= 1
		stats_changed.emit()

func increase_endurance():
	if available_points > 0:
		stats_system.endurance += 1
		available_points -= 1
		stats_changed.emit()

func increase_luck():
	if available_points > 0:
		stats_system.luck += 1
		available_points -= 1
		stats_changed.emit()

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

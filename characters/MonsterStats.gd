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
@export var endurance: int = 0
@export var exp_reward: int = 5

var current_health: int
var monster_level: int = 1
var _stats_initialized: bool = false  # ← Флаг инициализации
var _base_strength: int = 0  # ← Сохраняем базу отдельно
var _base_fortitude: int = 0
var _base_endurance: int = 0

func _ready():
	add_to_group("monster_stats")
	_generate_random_stats()
	_stats_initialized = true
	
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats and player_stats.level > 1:
		set_monster_level(player_stats.level)
	else:
		print("Монстр: ", enemy_name, " Ур.", monster_level, " С:", strength, " К:", fortitude, " В:", endurance)

func set_monster_level(level: int):
	if level <= monster_level and _stats_initialized:
		return
	
	monster_level = level
	_scale_stats_by_level()
	print("Монстр улучшен до ур.", monster_level, ": С", strength, " К", fortitude, " В", endurance, " (", strength + fortitude + endurance, " очков)")

func _scale_stats_by_level():
	# ВОССТАНАВЛИВАЕМ БАЗУ 1 УРОВНЯ
	strength = _base_strength
	fortitude = _base_fortitude
	endurance = _base_endurance
	
	# РАСЧЕТ: игрок имеет (4 + (level-1)*3) очков, монстр на 1 меньше
	var target_points = (4 + (monster_level - 1) * 3) - 1
	
	# Добавляем очки до нужного количества
	var current_points = strength + fortitude + endurance
	var points_to_add = target_points - current_points
	
	for i in range(points_to_add):
		var random_stat = randi() % 3
		match random_stat:
			0: strength += 1
			1: fortitude += 1  
			2: endurance += 1
	
	# Обновляем систему
	stats_system.strength = strength
	stats_system.fortitude = fortitude
	stats_system.endurance = endurance
	exp_reward = 5 * (strength + fortitude + endurance)
	current_health = get_max_health()

func _generate_random_stats():
	# Монстр 1 уровня: 3 очка (1 сила + 2 случайных)
	strength = 1
	fortitude = 0
	endurance = 0
	
	# Сохраняем базу
	_base_strength = strength
	_base_fortitude = fortitude
	_base_endurance = endurance
	
	# Добавляем 2 случайных очка
	for i in range(2):
		var random_stat = randi() % 3
		match random_stat:
			0: strength += 1
			1: fortitude += 1
			2: endurance += 1
	
	# Обновляем систему
	stats_system.strength = strength
	stats_system.fortitude = fortitude
	stats_system.endurance = endurance
	exp_reward = 10 * (strength + fortitude + endurance)
	current_health = get_max_health()

func get_max_health() -> int: return stats_system.get_max_health()
func get_damage() -> int: return stats_system.get_damage()
func get_defense() -> int: return stats_system.get_defense()

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

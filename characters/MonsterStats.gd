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
@export var luck: int = 0
@export var exp_reward: int = 5

var current_health: int
var monster_level: int = 1
var _stats_initialized: bool = false  # ← Флаг инициализации
var _base_strength: int = 0  # ← Сохраняем базу отдельно
var _base_fortitude: int = 0
var _base_endurance: int = 0
var _base_luck: int = 0

func _ready():
	add_to_group("monster_stats")
	_generate_random_stats()
	_stats_initialized = true
	
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats and player_stats.level > 1:
		set_monster_level(player_stats.level)
	else:
		print("Монстр: ", enemy_name, " Ур.", monster_level, " С:", strength, " К:", fortitude, " В:", endurance, " У:", luck)

func set_monster_level(level: int):
	if level <= monster_level and _stats_initialized:
		return
	
	monster_level = level
	_scale_stats_by_level()
	print("Монстр улучшен до ур.", monster_level, ": С", strength, " К", fortitude, " В", endurance, " У", luck)

func _scale_stats_by_level():
	# ВОССТАНАВЛИВАЕМ БАЗУ 1 УРОВНЯ
	strength = _base_strength
	fortitude = _base_fortitude
	endurance = _base_endurance
	luck = _base_luck
	
	var target_points: int
	
# ← НОВАЯ ФОРМУЛА: умное масштабирование относительно игрока
	if is_inside_tree():
		# НОВАЯ ФОРМУЛА: умное масштабирование относительно игрока
		var player_stats = get_tree().get_first_node_in_group("player_stats")
		if player_stats:
			var player_level = player_stats.level
			var player_points = 4 + (player_level - 1) * 3
			
			# Динамическая разница: уменьшается с уровнем
			var points_difference = clamp(5 - (player_level * 0.25), 1.5, 5.0)
			target_points = int(player_points - points_difference)
			target_points = max(3, target_points)
			
			print("Игрок Ур.", player_level, ": ", player_points, " очков | Монстр: ", target_points, " очков")
	else:
		# ← ЕСЛИ МОНСТР ЕЩЕ НЕ В ДЕРЕВЕ - используем старую формулу
		target_points = (4 + (monster_level - 1) * 3) - 1
		print("Монстр еще не в дереве, используем базовые очки: ", target_points)
	
	# Добавляем очки до нужного количества
	var current_points = strength + fortitude + endurance + luck
	var points_to_add = target_points - current_points
	
	if points_to_add > 0:
		for i in range(points_to_add):
			var random_stat = randi() % 4
			match random_stat:
				0: strength += 1
				1: fortitude += 1  
				2: endurance += 1
				3: luck += 1
	
	# Обновляем систему
	stats_system.strength = strength
	stats_system.fortitude = fortitude
	stats_system.endurance = endurance
	stats_system.luck = luck
	
	exp_reward = 5 * (strength + fortitude + endurance + luck) + (endurance * 5)
	current_health = get_max_health()

func _generate_random_stats():
	# Монстр 1 уровня: 3 очка (1 сила + 2 случайных)
	strength = 1
	fortitude = 0
	endurance = 0
	luck = 0
	
	# Сохраняем базу
	_base_strength = strength
	_base_fortitude = fortitude
	_base_endurance = endurance
	_base_luck = luck
	
	# Добавляем 2 случайных очка
	for i in range(2):
		var random_stat = randi() % 4
		match random_stat:
			0: strength += 1
			1: fortitude += 1
			2: endurance += 1
			3: luck += 1
	
	# Обновляем систему
	stats_system.strength = strength
	stats_system.fortitude = fortitude
	stats_system.endurance = endurance
	stats_system.luck = luck
	exp_reward = 10 * (strength + fortitude + endurance + luck) + (endurance * 5)
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

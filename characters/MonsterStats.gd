#MonsterStats.gd
extends Node
class_name MonsterStats

signal health_changed(new_health)
signal monster_died

# Система характеристик для монстров
var stats_system: StatsSystem = StatsSystem.new()

@export var enemy_name: String = "Монстр"
@export var strength: int = 1
@export var fortitude: int = 1
@export var endurance: int = 2
@export var exp_reward: int = 25

var current_health: int

func _ready():
	add_to_group("monster_stats")
	# Устанавливаем характеристики
	stats_system.strength = strength
	stats_system.fortitude = fortitude  
	stats_system.endurance = endurance
	
	current_health = get_max_health()  # ← Уже правильно - полное здоровье!

func get_max_health() -> int: return stats_system.get_max_health()
func get_damage() -> int: return stats_system.get_damage()
func get_defense() -> int: return stats_system.get_defense()

func take_damage(amount: int):
	var actual_damage = max(1, amount - get_defense())
	current_health -= actual_damage
	health_changed.emit(current_health)
	
	if current_health <= 0:
		monster_died.emit()
		current_health = 0

func heal(amount: int):
	current_health = min(current_health + amount, get_max_health())
	health_changed.emit(current_health)

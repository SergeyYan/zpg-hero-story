extends Node
class_name MonsterStats

signal health_changed(new_health)
signal monster_died

@export var enemy_name: String = "Монстр"
@export var max_health: int = 50
@export var damage: int = 20  
@export var defense: int = 2
@export var exp_reward: int = 25

var current_health: int

func _ready():
	add_to_group("monster_stats")  # ← ДОБАВЛЯЕМ В ГРУППУ!
	current_health = max_health

func take_damage(amount: int):
	var actual_damage = max(1, amount - defense)
	current_health -= actual_damage
	health_changed.emit(current_health)
	
	if current_health <= 0:
		monster_died.emit()
		current_health = 0

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health)

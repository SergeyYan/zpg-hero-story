#PlayerStats.gd
extends Node
class_name PlayerStats

signal health_changed(new_health)
signal level_up(new_level)
signal player_died

var max_health: int = 100
var current_health: int = 100
var damage: int = 15
var defense: int = 5
var current_exp: int = 0
var exp_to_level: int = 100
var level: int = 1



func _ready():
	add_to_group("player_stats")

func take_damage(amount: int):
	var actual_damage = max(1, amount - defense)  # ← Защита снижает урон
	current_health -= actual_damage
	health_changed.emit(current_health)
	
	if current_health <= 0:
		player_died.emit()
		current_health = 0

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health)

func add_exp(amount: int):
	current_exp += amount
	if current_exp >= exp_to_level:
		_level_up()

func _level_up():
	level += 1
	current_exp -= exp_to_level
	exp_to_level = int(exp_to_level * 1.5)
	max_health += 20
	current_health = max_health
	damage += 5
	defense += 2
	level_up.emit(level)

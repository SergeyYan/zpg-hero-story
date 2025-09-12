# WaterCollision.gd
extends Area2D

@export var water_type := "deep"
@export var slow_factor := 0.5

func _ready():
	if water_type == "deep":
		slow_factor = 0.5
	elif water_type != "deep" && water_type == "shallow":
		slow_factor = 0.7

	# Проверяем, не подключены ли уже сигналы
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)
	if not is_connected("body_exited", _on_body_exited):
		connect("body_exited", _on_body_exited)
	add_to_group("water_collisions")  # Добавьте эту строку

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
#		print("Игрок вошел в воду: ", water_type)
		if body.has_method("set_water_slowdown"):
			body.set_water_slowdown(slow_factor)

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
#		print("Игрок вышел из воды")
		if body.has_method("set_water_slowdown"):
			body.set_water_slowdown(1.0)

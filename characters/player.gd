#player.gd
extends CharacterBody2D

@export var SPEED := 100.0

var _water_slowdown := 1.0
var speed: float = SPEED  # Базовая скорость

var target_distance: float = 0.0
var moved_distance: float = 0.0
var move_direction: Vector2 = Vector2.ZERO

var is_paused: bool = false
var pause_time: float = 0.0
var pause_timer: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var push_force := 500.0  # Сила толчка
@export var push_radius := 550.0  # Радиус толчка


func _ready() -> void:
	add_to_group("player")  # Добавляем в группу игрока
	randomize()
	_choose_new_direction()

func _choose_new_direction() -> void:
	var directions = [
		Vector2(0, -1),    # вверх
		Vector2(1, -1).normalized(),  # вверх-направо
		Vector2(-1, -1).normalized(), # вверх-налево
		Vector2(0, 1),     # вниз
		Vector2(1, 1).normalized(),   # вниз-направо
		Vector2(-1, 1).normalized(),  # вниз-налево
		Vector2(1, 0),     # вправо
		Vector2(-1, 0)     # влево
	]
	move_direction = directions[randi() % directions.size()]
	target_distance = randf_range(100, 1000)
	moved_distance = 0.0
	is_paused = false
	pause_timer = 0.0
	_update_animation()

func _start_pause() -> void:
	is_paused = true
	pause_time = randf_range(0.0, 3.0)
	pause_timer = 0.0
	velocity = Vector2.ZERO
	anim_sprite.play("idle")

func _update_animation() -> void:
	if is_paused or move_direction == Vector2.ZERO:
		anim_sprite.play("idle")
		return

	# Определяем направление для анимации с приоритетом по осям
	var dir = move_direction.normalized()
	var anim_name = ""

	if dir.y < -0.5:
		if dir.x > 0.5:
			anim_name = "walk_up_right"
		elif dir.x < -0.5:
			anim_name = "walk_up_left"
		else:
			anim_name = "walk_up"
	elif dir.y > 0.5:
		if dir.x > 0.5:
			anim_name = "walk_down_right"
		elif dir.x < -0.5:
			anim_name = "walk_down_left"
		else:
			anim_name = "walk_down"
	else:
		# y около 0, значит горизонталь
		if dir.x > 0:
			anim_name = "walk_right"
		else:
			anim_name = "walk_left"

	_play_animation(anim_name)

func _play_animation(anim_name: String) -> void:
	var frames = anim_sprite.sprite_frames
	if frames and frames.has_animation(anim_name):
		anim_sprite.animation = anim_name
		anim_sprite.play()
	else:
		# fallback если анимация отсутствует
		if frames and frames.has_animation("walk_down"):
			anim_sprite.animation = "walk_down"
			anim_sprite.play()
		else:
			anim_sprite.stop()

func _physics_process(delta: float) -> void:
	var current_speed = speed * _water_slowdown  # Учитываем замедление воды
	
	# Оптимизированная проверка воды
	if _water_slowdown < 1.0:
		var in_water = false
		modulate = Color(0.8, 0.9, 1.0, 0.9)
		# Добавьте частицы или другие эффекты
	else:
		var in_water = false
		modulate = Color(1, 1, 1, 1)
		# Быстрая проверка только если нужно
		for water in get_tree().get_nodes_in_group("water_collisions"):
			if global_position.distance_squared_to(water.global_position) < 100:  # 10^2
				in_water = true
				break
		
		if not in_water:
			_water_slowdown = 1.0
			modulate = Color(1, 1, 1, 1)
	
	if is_paused:
		pause_timer += delta
		velocity = Vector2.ZERO
		move_and_slide()
		if pause_timer >= pause_time:
			_choose_new_direction()
		return

	if move_direction == Vector2.ZERO:
		_choose_new_direction()

	var distance_to_move = current_speed * delta
	velocity = move_direction * current_speed
	move_and_slide()
	
	_push_monsters()
	
	moved_distance += distance_to_move
	if moved_distance >= target_distance:
		_start_pause()


func _push_monsters() -> void:
	# Ищем всех монстров в радиусе
	var monsters = get_tree().get_nodes_in_group("monsters")
	for monster in monsters:
		if not is_instance_valid(monster):
			continue
		
		var distance = global_position.distance_to(monster.global_position)
		if distance < push_radius:
			var direction = (monster.global_position - global_position).normalized()
			if monster.has_method("push"):
				monster.push(direction, push_force * (1.0 - distance/push_radius))


func set_water_slowdown(factor: float) -> void:
	# Ограничиваем фактор между 0.1 и 1.0
	factor = clamp(factor, 0.1, 1.0)
	
	if abs(_water_slowdown - factor) > 0.01:  # Изменяем только при значимой разнице
		_water_slowdown = factor
		print("Скорость изменена: ", factor)


func is_in_water() -> bool:
	return _water_slowdown < 1.0

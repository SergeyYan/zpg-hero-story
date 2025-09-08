extends CharacterBody2D

const SPEED: float = 100.0

var target_distance: float = 0.0
var moved_distance: float = 0.0
var move_direction: Vector2 = Vector2.ZERO

var is_paused: bool = false
var pause_time: float = 0.0
var pause_timer: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
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
	pause_time = randf_range(1.0, 3.0)
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
	if is_paused:
		pause_timer += delta
		velocity = Vector2.ZERO
		move_and_slide()
		if pause_timer >= pause_time:
			_choose_new_direction()
		return

	if move_direction == Vector2.ZERO:
		_choose_new_direction()

	var distance_to_move = SPEED * delta
	velocity = move_direction * SPEED
	move_and_slide()

	moved_distance += distance_to_move
	if moved_distance >= target_distance:
		_start_pause()

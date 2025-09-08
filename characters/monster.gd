extends CharacterBody2D

@export var speed := 60.0
@export var change_dir_time := 3.5

var _rng := RandomNumberGenerator.new()
var _velocity := Vector2.ZERO
var _timer := 0.0

func _ready() -> void:
	_rng.randomize()
	_pick_new_direction()

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= change_dir_time:
		_pick_new_direction()
		_timer = 0.0

	velocity = _velocity          # передаём желаемую скорость
	move_and_slide()              # двигаемся

func _pick_new_direction() -> void:
	_velocity = Vector2.from_angle(_rng.randf_range(0, 2 * PI)) * speed

extends CharacterBody2D

@export var speed := 50.0
@export var change_dir_time := 3.5
@export var aggro_range := 100.0 # радиус зоны агрессии в пикселях
@export var show_aggro_radius := true # включить/выключить отрисовку радиуса
@export var mass := 50.0  # Масса монстра
@export var friction := 0.9  # Трение
@export_category("Push Settings")
@export var can_be_pushed: bool = true
@export var push_resistance: float = 1.0  # 1 = нормально, >1 = устойчивее

var push_sound: AudioStreamPlayer2D

var _rng := RandomNumberGenerator.new()
var _velocity := Vector2.ZERO
var _timer := 0.0
var player : Node = null   # ссылка на игрока
var chasing := false # флаг преследования
const PLAYER_GROUP := "player"
var _push_velocity := Vector2.ZERO


func _ready() -> void:
	add_to_group("monsters")  # ← Добавьте эту строку!
	_rng.randomize()
	_pick_new_direction()
	
	player = get_tree().get_first_node_in_group(PLAYER_GROUP)
	if not is_instance_valid(player):
		push_warning("Игрок не найден! Добавьте его в группу '%s'." % PLAYER_GROUP)

func _physics_process(delta: float) -> void:
	# Проверяем, находится ли игрок в зоне агрессии
	if player && is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance <= aggro_range:
			chasing = true
		else:
			chasing = false
	
	# Применяем толчок с учетом дельты времени
	if _push_velocity.length() > 5.0:
		velocity += _push_velocity * delta
		_push_velocity *= friction
	else:
		_push_velocity = Vector2.ZERO
	
	
	if chasing:
		# Режим преследования
		var direction = (player.global_position - global_position).normalized()
		_velocity = direction * speed
	else:
		# Случайное движение
		_timer += delta
		if _timer >= change_dir_time:
			_pick_new_direction()
			_timer = 0.0

	velocity = _velocity          # передаём желаемую скорость
	move_and_slide()              # двигаемся
	
	# Обновляем отрисовку при изменении позиции
	if show_aggro_radius:
		queue_redraw()


func push(direction: Vector2, force: float) -> void:
	_push_velocity += direction * force / mass
	
	# Визуальный эффект толчка
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
		
	# Создаем звук программно если нет в сцене
	if not has_node("PushSound"):
		push_sound = AudioStreamPlayer2D.new()
		add_child(push_sound)
	else:
		push_sound = $PushSound
		
	if not can_be_pushed:
		return
	
	_push_velocity += direction * (force / mass) / push_resistance


func _pick_new_direction() -> void:
	_velocity = Vector2.from_angle(_rng.randf_range(0, 2 * PI)) * speed

# Дополнительно можно добавить визуальную индикацию зоны агрессии
func _draw() -> void:
	if show_aggro_radius and is_inside_tree():
		# Создаем полупрозрачный цвет (серый с альфа-каналом)
		var aggro_color := Color(0.5, 0.5, 0.5, 0.2) # Более прозрачный
		# Рисуем круг радиуса агрессии с центром в (0,0) относительно ноды
		draw_circle(Vector2.ZERO, aggro_range, aggro_color)
		
		# Дополнительно: рисуем границу круга для лучшей видимости
		var border_color := Color(0.7, 0.7, 0.7, 0.4)
		draw_arc(Vector2.ZERO, aggro_range, 0, 2 * PI, 32, border_color, 2.0)

# Функция для включения/выключения отображения радиуса
func toggle_aggro_visibility() -> void:
	show_aggro_radius = not show_aggro_radius
	queue_redraw()

# Функция для установки видимости радиуса
func set_aggro_visibility(visible: bool) -> void:
	show_aggro_radius = visible
	queue_redraw()

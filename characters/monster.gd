extends CharacterBody2D

@export var speed := 50.0
@export var change_dir_time := 3.5
@export var aggro_range := 100.0
@export var show_aggro_radius := true

# Используем общий MonsterStats из Game.tscn
var monster_stats: MonsterStats

var _rng := RandomNumberGenerator.new()
var _velocity := Vector2.ZERO
var _timer := 0.0
var player : Node = null
var chasing := false
const PLAYER_GROUP := "player"
var _push_velocity := Vector2.ZERO
var _aggro_tween: Tween
var _is_aggro := false

func _ready() -> void:
	add_to_group("monsters")
	_rng.randomize()
	_pick_new_direction()
	
	# НАХОДИМ ОБЩИЙ MonsterStats ИЗ ГРУППЫ
	monster_stats = get_tree().get_first_node_in_group("monster_stats")
	if not monster_stats:
		push_error("MonsterStats not found in group 'monster_stats'!")
		return
	
	print("MonsterStats загружен: ", monster_stats.enemy_name)
	
	player = get_tree().get_first_node_in_group(PLAYER_GROUP)
	if not is_instance_valid(player):
		push_warning("Игрок не найден! Добавьте его в группу '%s'." % PLAYER_GROUP)

func _physics_process(delta: float) -> void:
	# Проверяем, находится ли игрок в зоне агрессии
	if player && is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		var was_chasing = chasing
		
		if distance <= aggro_range:
			chasing = true
			if not _is_aggro:  # Только если агро только началось
				_start_aggro_effect()
				_is_aggro = true
		else:
			chasing = false
			if _is_aggro:  # Только если агро закончилось
				_stop_aggro_effect()
				_is_aggro = false
	
	# Применяем толчок с учетом дельты времени
	if _push_velocity.length() > 5.0:
		velocity += _push_velocity * delta
		_push_velocity *= 0.9
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

	velocity = _velocity
	move_and_slide()
	
	# Проверяем столкновения с игроком после движения
	_check_collisions()
	
	# Обновляем отрисовку при изменении позиции
	if show_aggro_radius:
		queue_redraw()

# Начало эффекта агро - постоянный красный цвет
func _start_aggro_effect():
	if _aggro_tween:
		_aggro_tween.kill()
	
	_aggro_tween = create_tween()
	_aggro_tween.tween_property(self, "modulate", Color.RED, 0.2)
	_aggro_tween.tween_callback(_keep_aggro_effect)

# Поддержание красного цвета пока агро активно
func _keep_aggro_effect():
	if _is_aggro and modulate != Color.RED:
		modulate = Color.RED

# Окончание эффекта агро - возврат к нормальному цвету
func _stop_aggro_effect():
	if _aggro_tween:
		_aggro_tween.kill()
	
	_aggro_tween = create_tween()
	_aggro_tween.tween_property(self, "modulate", Color.WHITE, 0.3)

# Проверка столкновений
func _check_collisions():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		
		if body and body.is_in_group("player"):
			var battle_system = get_tree().get_first_node_in_group("battle_system")
			if battle_system and not battle_system.visible:
				battle_system.start_battle(self)
			return

func take_damage(amount: int):
	if monster_stats:
		monster_stats.take_damage(amount)

func die():
	# ПРОВЕРЯЕМ, не в бою ли мы
	var battle_system = get_tree().get_first_node_in_group("battle_system")
	if battle_system and battle_system.visible:
		print("⚔️ Монстр убит в бою - отключаем коллизии")
		# ОТКЛЮЧАЕМ КОЛЛИЗИИ чтобы не запускать новые бои
		collision_layer = 0  # Отключаем все слои
		collision_mask = 0   # Отключаем все маски
		hide()  # Скрываем, но не удаляем
	else:
		queue_free()  # Удаляем только если не в бою

func _pick_new_direction() -> void:
	_velocity = Vector2.from_angle(_rng.randf_range(0, 2 * PI)) * speed

# Визуализация зоны агрессии
func _draw() -> void:
	if show_aggro_radius and is_inside_tree():
		var aggro_color := Color(0.5, 0.5, 0.5, 0.2)
		draw_circle(Vector2.ZERO, aggro_range, aggro_color)
		
		var border_color := Color(0.7, 0.7, 0.7, 0.4)
		draw_arc(Vector2.ZERO, aggro_range, 0, 2 * PI, 32, border_color, 2.0)

func toggle_aggro_visibility() -> void:
	show_aggro_radius = not show_aggro_radius
	queue_redraw()

func set_aggro_visibility(visible: bool) -> void:
	show_aggro_radius = visible
	queue_redraw()

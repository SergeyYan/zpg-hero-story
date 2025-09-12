#monster.gd
extends CharacterBody2D

@export var speed := 85.0
@export var change_dir_time := 3.5
@export var aggro_range := 100.0
@export var show_aggro_radius := true

# Ссылка на дочерний MonsterStats
@onready var monster_stats: MonsterStats = $MonsterStats

var _rng := RandomNumberGenerator.new()
var _velocity := Vector2.ZERO
var _timer := 0.0
var player : Node = null
var chasing := false
const PLAYER_GROUP := "player"
var _push_velocity := Vector2.ZERO
var _aggro_tween: Tween
var _is_aggro := false

# Защита от повторных вызовов боя
var is_in_battle: bool = false
var battle_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("monsters")
	_rng.randomize()
	_pick_new_direction()
	
	# ПРОВЕРКА MonsterStats
	if not monster_stats:
		# Пытаемся найти в дочерних нодах
		monster_stats = get_node_or_null("MonsterStats")
		if not monster_stats:
			push_error("MonsterStats not found as child node!")
			set_physics_process(false)
			return
	
#	print("MonsterStats загружен: ", monster_stats.enemy_name)
	
	player = get_tree().get_first_node_in_group(PLAYER_GROUP)
	if not is_instance_valid(player):
		push_warning("Игрок не найден! Добавьте его в группу '%s'." % PLAYER_GROUP)

func _physics_process(delta: float) -> void:
	# ПРОВЕРКА: если нет статистики - не обрабатываем
	if not monster_stats:
		return
	
	# Обновляем кулдаун боя
	if battle_cooldown > 0.0:
		battle_cooldown -= delta
		if battle_cooldown <= 0.0:
			is_in_battle = false
	
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

# Проверка столкновений с защитой от повторных вызовов
func _check_collisions():
	# Более строгая проверка
	if is_in_battle or battle_cooldown > 0.0 or not monster_stats:
		return
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		
		if body and body.is_in_group("player") and is_instance_valid(body):
			var battle_system = get_tree().get_first_node_in_group("battle_system")
			if battle_system and is_instance_valid(battle_system) and not battle_system.visible:
				is_in_battle = true
				battle_cooldown = 2.0
				battle_system.start_battle(self, monster_stats)
				return  # Выходим после первого найденного столкновения

func take_damage(amount: int):
	if monster_stats:
		monster_stats.take_damage(amount)

func die():
	# ПРОВЕРЯЕМ, не в бою ли мы
	var battle_system = get_tree().get_first_node_in_group("battle_system")
	if battle_system and battle_system.visible:
#		print("⚔️ Монстр убит в бою - отключаем коллизии")
		# ОТКЛЮЧАЕМ КОЛЛИЗИИ чтобы не запускать новые бои
		collision_layer = 0  # Отключаем все слои
		collision_mask = 0   # Отключаем все маски
		hide()  # Скрываем, но не удаляем
	else:
		queue_free()  # Удаляем только если не в бою

# Метод для завершения боя (вызывается из BattleSystem)
func end_battle():
	is_in_battle = false
	battle_cooldown = 5.0  # Больший кулдаун после боя

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


func apply_level_scaling(player_level: int):
	if not monster_stats:
		return
	
	# ПРОСТО УСТАНАВЛИВАЕМ УРОВЕНЬ - MonsterStats сам все пересчитает
	monster_stats.set_monster_level(player_level)
	
	print("Монстр Ур.", player_level, ": С", monster_stats.strength, 
		  " К", monster_stats.fortitude, " В", monster_stats.endurance,
		  " HP: ", monster_stats.current_health, "/", monster_stats.get_max_health(),
		  " EXP: ", monster_stats.exp_reward)

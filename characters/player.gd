#player.gd
extends CharacterBody2D

@export var SPEED := 100.0

var _water_slowdown := 1.0
var speed: float = SPEED  # Базовая скорость
var _is_in_water: bool = false  # ← НОВАЯ ПЕРЕМЕННАЯ: находимся ли в воде
var _drying_timer: float = 0.0  # ← Таймер высыхания
var _drying_delay: float = 0.5  # ← Время до высыхания после выхода (0.5 секунды)
var _water_tile_count: int = 0  # ← СЧЕТЧИК водных тайлов

var target_distance: float = 0.0
var moved_distance: float = 0.0
var move_direction: Vector2 = Vector2.ZERO

var is_paused: bool = false
var pause_time: float = 0.0
var pause_timer: float = 0.0

var regen_timer: float = 0.0
var regen_interval: float = 1.0  # Раз в секунду

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

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
	pause_time = randf_range(0.0, 2.0)
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
	# ЛОГИКА ВЫСЫХАНИЯ (5 секунд)
	# ЛОГИКА ВЫСЫХАНИЯ
	if _water_tile_count <= 0 and _drying_timer >= 0:
		_drying_timer += delta
		#print("Таймер высыхания: ", _drying_timer, "/", _drying_delay, " (замедление: ", _water_slowdown, ")")
		
		if _drying_timer >= _drying_delay:
			_water_slowdown = 1.0
			_drying_timer = -0.5
			#print("Игрок полностью высох")
	
	# ОТДЕЛЬНО управляем цветом
	if _water_slowdown < 1.0:
		modulate = Color(0.8, 0.9, 1.0, 0.9)  # Синий оттенок
	else:
		modulate = Color.WHITE  # Нормальный цвет
	
	# ПРОВЕРКА: если игра на паузе - не двигаемся
	if get_tree().paused:
		velocity = Vector2.ZERO
		return
	
	var current_speed = speed * _water_slowdown  # Учитываем замедление воды
		
	
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
	
	moved_distance += distance_to_move
	if moved_distance >= target_distance:
		_start_pause()
	
	
func _process(delta: float) -> void:
	# Регенерация здоровья вне боя - работает ВСЕГДА!
	# Убираем проверку на is_paused - она только для движения!
	if not is_in_battle():  # ← Только проверка на бой!
		var player_stats = get_tree().get_first_node_in_group("player_stats")
		if player_stats and player_stats.current_health < player_stats.get_max_health():
#			print("Регенерация активна (стояние)")
			player_stats.regenerate_health(delta)


func is_in_battle() -> bool:
	# Проверяем, находится ли игрок в бою
	var battle_system = get_tree().get_first_node_in_group("battle_system")
	return battle_system and battle_system.visible

func set_water_slowdown(factor: float) -> void:
	# Ограничиваем фактор между 0.1 и 1.0
	factor = clamp(factor, 0.1, 1.0)
	
	# ОБНОВЛЯЕМ СЧЕТЧИК
	if factor < 1.0:
		_water_tile_count += 1  # Вошли в воду
	else:
		_water_tile_count -= 1  # Вышли из воды
	
	# ЕСЛИ все еще в воде - не запускаем высыхание
	if _water_tile_count > 0 and factor == 1.0:
		#print("Игнорируем выход из воды - все еще в другом тайле воды")
		return
	
	# ОСНОВНАЯ ЛОГИКА
	if abs(_water_slowdown - factor) > 0.01:
		if factor < 1.0:
			# ВОШЛИ В ВОДУ - применяем замедление сразу
			_water_slowdown = factor
			_drying_timer = -1.0
			#print("Вошел в воду, таймер высыхания остановлен")
		elif _water_tile_count <= 0 and _drying_timer < 0:
			# ВЫШЛИ ИЗ ВОДЫ (и нет других водных тайлов) - запускаем таймер
			_drying_timer = 0.0
			#print("Начало высыхания, таймер запущен (замедление: ", _water_slowdown, ")")
		else:
			# Другие случаи
			_water_slowdown = factor
		
		#print("Водных тайлов: ", _water_tile_count, ", замедление: ", _water_slowdown)

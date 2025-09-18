# MonsterSpawner.gd
extends Node

## Радиус в чанках вокруг игрока, в котором могут появляться монстры
@export var SPAWN_RADIUS := 18
## Радиус в чанках, за пределами которого монстры удаляются
@export var DESPAWN_RADIUS := 20
## Максимальное количество монстров на карте одновременно
@export var MAX_MONSTERS := 4
## Шанс спавна монстра в подходящем чанке (0.0 - 1.0)
@export var SPAWN_CHANCE := 0.1
## Интервал обновления системы спавна в секундах
@export var UPDATE_INTERVAL := 0.2

## Размер тайла карты в пикселях (должен совпадать с MapGenerator)
const TILE_SIZE := 32
## Путь к сцене монстра для инстансинга
const MONSTER_SCENE := "res://characters/monster.tscn"

var _player: CharacterBody2D
## Словарь для хранения монстров по чанкам: {Vector2i: Array[Node]}
var _monsters: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _update_cooldown := 0.0
## Очередь чанков для отложенного спавна монстров
var _spawn_queue: Array = []
# Добавляем свойство для хранения уровня игрока
var player_level: int = 1


## Инициализация спавнера
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_rng.randomize()
	_find_player()
	_cleanup_existing_monsters()
	
	_update_monsters.call_deferred()


## Удаляет монстров, уже находящихся на сцене при запуске
func _cleanup_existing_monsters() -> void:
	var existing_monsters = get_tree().get_nodes_in_group("monsters")
	for monster in existing_monsters:
		monster.queue_free()


## Основной процесс обновления системы спавна
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _player:
		return

	_update_cooldown += delta
	# Добавляем небольшую случайность к интервалу для разнообразия
	if _update_cooldown < UPDATE_INTERVAL + _rng.randf_range(-0.05, 0.05):
		return
	
	_update_cooldown = 0.0
	_update_monsters()


## Поиск игрока в сцене по группе "player"
func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		set_process(false)


## Основная функция обновления монстров
func _update_monsters() -> void:
	_despawn_monsters()
	_spawn_monsters()
	_process_spawn_queue()


## Удаляет монстров, которые вышли за радиус деспавна
func _despawn_monsters() -> void:
	for chunk_key in _monsters.keys().duplicate():
		var monsters_in_chunk = _monsters[chunk_key]
		
		# Обратный цикл для безопасного удаления элементов
		for i in range(monsters_in_chunk.size() - 1, -1, -1):
			var monster = monsters_in_chunk[i]
			
			if not is_instance_valid(monster):
				monsters_in_chunk.remove_at(i)
			elif monster.global_position.distance_to(_player.global_position) > (DESPAWN_RADIUS * TILE_SIZE):
				monster.queue_free()
				monsters_in_chunk.remove_at(i)
		
		if monsters_in_chunk.is_empty():
			_monsters.erase(chunk_key)


## Проверяет подходящие чанки для спавна новых монстров
func _spawn_monsters() -> void:
	var current_count = _count_monsters()
	if current_count >= randi_range(0, MAX_MONSTERS):
		return
	
	var player_chunk = _world_to_chunk(_player.global_position)
	var monsters_to_spawn = randi_range(0, MAX_MONSTERS) - current_count
	
	# Проверяем все чанки в радиусе спавна
	for x in range(player_chunk.x - SPAWN_RADIUS, player_chunk.x + SPAWN_RADIUS + 1):
		for y in range(player_chunk.y - SPAWN_RADIUS, player_chunk.y + SPAWN_RADIUS + 1):
			var chunk = Vector2i(x, y)
			
			# Условия спавна: чанк свободен + выпал шанс + есть место
			if not _monsters.has(chunk) and _rng.randf() < SPAWN_CHANCE:
				_spawn_queue.append(chunk)
				monsters_to_spawn -= 1
				
				if monsters_to_spawn <= 0:
					return


## Обрабатывает очередь чанков для спавна
func _process_spawn_queue() -> void:
	if _spawn_queue.is_empty():
		return
	
	for chunk in _spawn_queue:
		_spawn_monster(chunk)
	
	_spawn_queue.clear()


## Создает монстра в указанном чанке
func _spawn_monster(chunk: Vector2i) -> void:
	var monster_scene = load(MONSTER_SCENE)
	var monster = monster_scene.instantiate()
	
	# ← ТОЛЬКО ОДИН РАЗ устанавливаем уровень!
	var monster_stats = monster.get_node("MonsterStats")
	if monster_stats and monster_stats.has_method("apply_level_scaling"):  # ← Используем apply_level_scaling
		monster_stats.apply_level_scaling(player_level)

	
	# УВЕЛИЧИВАЕМ радиус спавна чтобы монстры не появлялись внутри игрока
	var spawn_radius = (DESPAWN_RADIUS - 5) * TILE_SIZE
	var angle = _rng.randf_range(0, TAU)
	var pos = _player.global_position + Vector2.from_angle(angle) * spawn_radius
	
	# ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: не спавнить слишком близко к игроку
	var min_distance = 200.0  # Минимальная дистанция от игрока
	if pos.distance_to(_player.global_position) < min_distance:
		# Если слишком близко - выбираем новую позицию
		angle = _rng.randf_range(0, TAU)
		pos = _player.global_position + Vector2.from_angle(angle) * min_distance
	
	monster.position = pos
	call_deferred("_add_monster_to_scene", monster, chunk)


## Добавляет созданного монстра на сцену и регистрирует его
func _add_monster_to_scene(monster: Node, chunk: Vector2i) -> void:
	get_parent().add_child(monster)
	# ← ОТЛАДОЧНАЯ ИНФОРМАЦИЯ
		
	if not _monsters.has(chunk):
		_monsters[chunk] = []
	_monsters[chunk].append(monster)


## Возвращает общее количество активных монстров
func _count_monsters() -> int:
	var total = 0
	for monsters_in_chunk in _monsters.values():
		total += monsters_in_chunk.size()
	return total


## Конвертирует мировые координаты в координаты чанка
func _world_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(pos / TILE_SIZE)


## ← НОВЫЙ МЕТОД: обновление уровня спавнера
func update_player_level(new_level: int):
	if new_level > player_level:
		player_level = new_level


func set_player_level_after_load(level: int):
	player_level = level
	
	# ← ПЕРЕМАСШТАБИРУЕМ уже созданных монстров
	for chunk in _monsters:
		for monster in _monsters[chunk]:
			if is_instance_valid(monster) and monster.has_node("MonsterStats"):
				var stats = monster.get_node("MonsterStats")
				if stats.has_method("apply_level_scaling"):
					stats.apply_level_scaling(player_level)

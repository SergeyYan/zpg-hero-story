# res://Map/MapGenerator.gd
extends Node2D

## Размер одного тайла в пикселях (должен совпадать с MonsterSpawner)
@export var TILE_SIZE := 32
## Радиус в чанках вокруг игрока для генерации тайлов
@export var SPAWN_RADIUS := 13
## Радиус в чанках для удаления тайлов (должен быть > SPAWN_RADIUS)
@export var DESPAWN_RADIUS := 15
## Интервал обновления генерации в секундах
@export var UPDATE_INTERVAL := 0.2
## Включить визуализацию карты высот для отладки
@export var debug_draw_heightmap := false

## Настройки шума для генерации высот
@export_group("Noise Settings")
## Масштаб шума высот (меньше = более плавный рельеф)
@export var NOISE_FREQUENCY := 0.01
## Масштаб шума влажности (меньше = более плавные биомы) 
@export var MOISTURE_FREQUENCY := 0.15

var _update_cooldown := 0.0
var _noise: FastNoiseLite
var _moisture_noise: FastNoiseLite
var _generated_biomes: Dictionary = {}  # Хэш сгенерированных биомов: {Vector2i: biome_type}
var _active_biomes: Dictionary = {}     # Активные биомы в радиусе видимости

var _water_collisions: Dictionary = {}  # {Vector2i: Area2D}

## Словарь путей к текстурам биомов
const TEXTURES := {
	"snow": "res://assets/map/snow.png",
	"sand": "res://assets/map/sand.png", 
	"grass": "res://assets/map/grass.png",
	"earth": "res://assets/map/earth.png",
	"water_deep": "res://assets/map/water_deep.png",
	"water_shallow": "res://assets/map/water_shallow.png",
	"grass_lush": "res://assets/map/grass_lush.png"
}

var _player: CharacterBody2D
## Словарь загруженных тайлов: {Vector2i: Sprite2D}
var _loaded_tiles: Dictionary = {}
var _textures: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## Инициализация генератора карты
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	print("Загрузка текстур карты...")
	_load_textures()
	_init_noise()
	_find_player()
	_update_chunks()


## Основной процесс обновления генерации
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_update_cooldown += delta
	if _update_cooldown < UPDATE_INTERVAL:
		return
	
	_update_cooldown = 0.0
	_update_chunks()


## Загружает текстуры биомов из файлов
## Использует заглушку (траву) для отсутствующих текстур
func _load_textures() -> void:
	for key in TEXTURES.keys():
		var tex := load(TEXTURES[key])
		if tex == null:
			push_warning("Не удалось загрузить текстуру: " + TEXTURES[key])
			_textures[key] = load("res://assets/map/grass.png")
			print("   ", key, ": НЕ ЗАГРУЖЕНА (используем заглушку)")
		else:
			_textures[key] = tex
			print("   ", key, ": OK")


## Инициализирует генераторы шума для высот и влажности
func _init_noise() -> void:
	_rng.randomize()
	
	# Шум для высот (рельеф)
	_noise = FastNoiseLite.new()
	_noise.seed = _rng.randi()
	_noise.frequency = NOISE_FREQUENCY
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.5
	_noise.fractal_lacunarity = 2.0
	
	# Шум для влажности (биомы)
	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.seed = _rng.randi() + 1
	_moisture_noise.frequency = MOISTURE_FREQUENCY
	_moisture_noise.fractal_octaves = 3
	_moisture_noise.fractal_gain = 0.4


## Находит игрока в сцене по группе "player"
func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_error("MapGenerator: игрок не найден!")
		set_process(false)


## Основная функция обновления чанков вокруг игрока
func _update_chunks() -> void:
	if not _player:
		return
	
	var player_chunk := world_to_chunk(_player.global_position)
	
	# Генерация новых тайлов в радиусе вокруг игрока
	_generate_chunks_around_player(player_chunk)
	
	# Удаление тайлов вне радиуса видимости
	_remove_distant_chunks(player_chunk)


## Генерирует тайлы в радиусе вокруг позиции игрока
## @param player_chunk: Текущий чанк игрока (Vector2i)
func _generate_chunks_around_player(player_chunk: Vector2i) -> void:
	for x in range(player_chunk.x - SPAWN_RADIUS, player_chunk.x + SPAWN_RADIUS + 1):
		for y in range(player_chunk.y - SPAWN_RADIUS, player_chunk.y + SPAWN_RADIUS + 1):
			var chunk := Vector2i(x, y)
			if not _loaded_tiles.has(chunk):
				_spawn_tile(chunk)


## Обновляем удаление чанков
func _remove_distant_chunks(player_chunk: Vector2i) -> void:
	# Удаляем тайлы
	for chunk in _loaded_tiles.keys():
		if chunk.distance_to(player_chunk) > DESPAWN_RADIUS:
			_loaded_tiles[chunk].queue_free()
			_loaded_tiles.erase(chunk)
			
			# Удаляем водные коллизии
			if _water_collisions.has(chunk):
				_water_collisions[chunk].queue_free()
				_water_collisions.erase(chunk)
	
	# Очищаем активные биомы
	for chunk in _active_biomes.keys().duplicate():
		if chunk.distance_to(player_chunk) > DESPAWN_RADIUS + 10:
			_active_biomes.erase(chunk)


## Создает и добавляет тайл в указанном чанке
## @param chunk: Координаты чанка (Vector2i)
func _spawn_tile(chunk: Vector2i) -> void:
	var tile := Sprite2D.new()
	var texture = _pick_texture(chunk)
	tile.texture = texture
	tile.centered = false
	tile.position = chunk_to_world(chunk)
	add_child(tile)
	_loaded_tiles[chunk] = tile
	
	# Создаем коллизию только для водных тайлов
	if texture == _textures["water_deep"] or texture == _textures["water_shallow"]:
		_create_water_collision(chunk, texture)


func _create_water_collision(chunk: Vector2i, texture: Texture2D) -> void:
	if _water_collisions.has(chunk):
		return  # Уже существует
	
	var water_collision = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	
	rectangle.size = Vector2(TILE_SIZE, TILE_SIZE)
	collision_shape.shape = rectangle
	water_collision.add_child(collision_shape)
	
	water_collision.position = chunk_to_world(chunk) + Vector2(TILE_SIZE/2, TILE_SIZE/2)
	
	# Настраиваем слои коллизии
	water_collision.collision_layer = 2
	water_collision.collision_mask = 1
	
	# Добавляем скрипт
	var script = load("res://Map/WaterCollision.gd")
	water_collision.set_script(script)
	
	# Устанавливаем тип воды
	water_collision.water_type = "deep" if texture == _textures["water_deep"] else "shallow"
	
	add_child(water_collision)
	_water_collisions[chunk] = water_collision


## Выбирает текстуру для тайла на основе высоты и влажности
## @param chunk: Координаты чанка (Vector2i)
## @return: Texture2D для отображения
## Выбирает текстуру для тайла на основе высоты и влажности
func _pick_texture(chunk: Vector2i) -> Texture2D:
	if Engine.is_editor_hint():
		return load("res://assets/map/grass.png")
	
	var world_pos := chunk_to_world(chunk)
	var height_value := _noise.get_noise_2d(world_pos.x, world_pos.y)
	var moisture_value := _moisture_noise.get_noise_2d(world_pos.x, world_pos.y)
	var elevation := (height_value + 1.0) / 2.0
	
	# Используем упрощенную логику если нет специальных текстур
	if not _textures.has("water_deep") or not _textures.has("water_shallow"):
		return _fallback_texture(elevation, moisture_value)
	
	# Проверяем, не находится ли этот чанк уже в сгенерированном биоме
	if _generated_biomes.has(chunk):
		return _textures[_generated_biomes[chunk]]
	
	# Проверяем условия для создания нового биома (только для "свежих" чанков)
	if not _is_chunk_explored(chunk):
		var biome_texture = _try_create_biome(chunk, elevation, moisture_value)
		if biome_texture:
			return biome_texture
	
	# Стандартная логика выбора биома
	if elevation < 0.35 and moisture_value > 0.1:
		return _textures["water_deep"] if _rng.randf() < 0.7 else _textures["water_shallow"]
	elif elevation < 0.35:
		return _textures["sand"]  # Пляжи у воды
	elif elevation < 0.45:
		# Пустыни и сухие земли
		if moisture_value < 0.2:
			return _textures["sand"]  # Пустыня
		elif moisture_value > 0.3:
			return _textures["sand"]  # Пляж
		else:
			return _textures["earth"]
	elif elevation < 0.65:
		if moisture_value > 0.4:
			return _textures["grass_lush"] if _textures.has("grass_lush") else _textures["grass"]
		elif moisture_value > 0.2:
			return _textures["grass"]
		else:
			return _textures["earth"]
	elif elevation < 0.75:
		return _textures["earth"] if moisture_value < 0.3 else _textures["grass"]
	else:
		if elevation > 0.85:
			return _textures["snow"]
		return _textures["snow"] if _rng.randf() < (elevation - 0.75) * 3 else _textures["earth"]


## Проверяет, был ли чанк уже исследован (имеет соседей)
func _is_chunk_explored(chunk: Vector2i) -> bool:
	# Если этот чанк уже имеет тайл - он точно исследован
	if _loaded_tiles.has(chunk):
		return true
	
	# Проверяем только непосредственных соседей (не диагонали)
	var neighbors = [
		Vector2i(chunk.x + 1, chunk.y),    # право
		Vector2i(chunk.x - 1, chunk.y),    # лево
		Vector2i(chunk.x, chunk.y + 1),    # низ
		Vector2i(chunk.x, chunk.y - 1)     # верх
	]
	
	# Чанк считается исследованным, если ВСЕ соседи загружены
	for neighbor in neighbors:
		if not _loaded_tiles.has(neighbor):
			return false  # Если хоть один сосед отсутствует - чанк свежий
	
	return true  # Все соседи есть - чанк исследован


## Пытается создать биом в указанном чанке
func _try_create_biome(chunk: Vector2i, elevation: float, moisture: float) -> Texture2D:
	# Добавляем случайность - не каждый подходящий чанк создает биом
	var should_create_biome = _rng.randf() < 0.9  # 10% шанс попытки создания
	
	if not should_create_biome:
		return null
	
	# Водные биомы
	if elevation < 0.35 and moisture > 0.1:
		if _rng.randf() < 0.4:  # 30% шанс создать озеро
			return _create_water_biome(chunk)
	
	# Песчаные биомы (пустыни)
	elif elevation < 0.45 and moisture < 0.2:  # Низкая влажность для пустынь
		if _rng.randf() < 0.1:  # 40% шанс создать пустыню
			return _create_sand_biome(chunk, moisture)
	
	# Травяные биомы
	elif elevation < 0.65 and moisture > 0.3:
		if _rng.randf() < 0.5:  # 40% шанс создать поле
			return _create_grass_biome(chunk, moisture)
	
	# Снежные биомы (горные плато)
	elif elevation > 0.8 and moisture < 0.4:
		if _rng.randf() < 0.4:  # 25% шанс создать снежное плато
			return _create_snow_biome(chunk, moisture)
	
	return null


## Создает водный биом
func _create_water_biome(center_chunk: Vector2i) -> Texture2D:
	var biome_width = _rng.randi_range(9, 15)
	var biome_height = _rng.randi_range(6, 15)
	var biome_type = "water_deep" if _rng.randf() < 0.65 else "water_shallow"
	
	# Добавляем случайное смещение от центрального чанка
	var offset_x = _rng.randi_range(-biome_width/2, biome_width/2)
	var offset_y = _rng.randi_range(-biome_height/2, biome_height/2)
	var actual_center = Vector2i(center_chunk.x + offset_x, center_chunk.y + offset_y)
	
	_generate_biome(actual_center, biome_width, biome_height, biome_type)
	return _textures[biome_type]


## Создает песчаный биом (пустыню или пляж)
func _create_sand_biome(center_chunk: Vector2i, moisture: float) -> Texture2D:
	var biome_width = _rng.randi_range(6, 15)  # Пустыни могут быть большими
	var biome_height = _rng.randi_range(9, 15)
	var biome_type = "sand"
	
	# Случайное смещение для естественного вида
	var offset_x = _rng.randi_range(-biome_width/3, biome_width/3)
	var offset_y = _rng.randi_range(-biome_height/3, biome_height/3)
	var actual_center = Vector2i(center_chunk.x + offset_x, center_chunk.y + offset_y)
	
	_generate_biome(actual_center, biome_width, biome_height, biome_type)
	return _textures[biome_type]


## Создает травяной биом
func _create_grass_biome(center_chunk: Vector2i, moisture: float) -> Texture2D:
	var biome_width = _rng.randi_range(8, 12)
	var biome_height = _rng.randi_range(6, 12)
	var biome_type = "grass_lush" if moisture > 0.4 and _textures.has("grass_lush") else "grass"
	
	# Случайное смещение
	var offset_x = _rng.randi_range(-biome_width/3, biome_width/3)
	var offset_y = _rng.randi_range(-biome_height/3, biome_height/3)
	var actual_center = Vector2i(center_chunk.x + offset_x, center_chunk.y + offset_y)
	
	_generate_biome(actual_center, biome_width, biome_height, biome_type)
	return _textures[biome_type]


## Создает снежный  биом
func _create_snow_biome(center_chunk: Vector2i, moisture: float) -> Texture2D:
	var biome_width = _rng.randi_range(12, 20)
	var biome_height = _rng.randi_range(12, 25)
	var biome_type = "snow" #if moisture > 0.4 and _textures.has("snow") else "snow"
	
	# Случайное смещение для горных плато
	var offset_x = _rng.randi_range(-biome_width/4, biome_width/4)
	var offset_y = _rng.randi_range(-biome_height/4, biome_height/4)
	var actual_center = Vector2i(center_chunk.x + offset_x, center_chunk.y + offset_y)
	
	_generate_biome(actual_center, biome_width, biome_height, biome_type)
	return _textures[biome_type]


## Генерирует зону биома
func _generate_biome(center_chunk: Vector2i, width: int, height: int, biome_type: String) -> void:
	var start_x = center_chunk.x - width / 2
	var start_y = center_chunk.y - height / 2
	
	for x in range(start_x, start_x + width):
		for y in range(start_y, start_y + height):
			var chunk_pos = Vector2i(x, y)
			_generated_biomes[chunk_pos] = biome_type
			_active_biomes[chunk_pos] = true


## Упрощенная логика выбора текстуры (fallback)
## Упрощенная логика выбора текстуры (fallback)
func _fallback_texture(elevation: float, moisture: float) -> Texture2D:
	if Engine.is_editor_hint():
		return load("res://assets/map/grass.png")
	
	# Упрощенная версия без больших биомов
	if elevation < 0.25 and moisture > 0.3:
		return _textures["sand"]  # Временная замена воды
	elif elevation < 0.4:
		if moisture < 0.2:
			return _textures["sand"]  # Пустыня
		elif moisture > 0.4:
			return _textures["sand"]  # Пляж
		else:
			return _textures["earth"]
	elif elevation < 0.65:
		return _textures["grass"]
	elif elevation < 0.8:
		return _textures["earth"] if moisture < 0.4 else _textures["grass"]
	else:
		return _textures["snow"] if elevation > 0.9 else _textures["earth"]


## Конвертирует мировые координаты в координаты чанка
## @param pos: Мировые координаты (Vector2)
## @return: Координаты чанка (Vector2i)
func world_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / TILE_SIZE), int(pos.y / TILE_SIZE))


## Конвертирует координаты чанка в мировые координаты
## @param chunk: Координаты чанка (Vector2i)
## @return: Мировые координаты (Vector2)
func chunk_to_world(chunk: Vector2i) -> Vector2:
	return Vector2(chunk.x, chunk.y) * TILE_SIZE


## Отладочная отрисовка карты высот (только в редакторе)
func _draw() -> void:
	if not debug_draw_heightmap or not _noise or not Engine.is_editor_hint():
		return
	
	for chunk in _loaded_tiles:
		var height_value := _noise.get_noise_2d(chunk.x * TILE_SIZE, chunk.y * TILE_SIZE)
		var color := Color(0, (height_value + 1) / 2, 0)
		draw_rect(Rect2(chunk_to_world(chunk), Vector2.ONE * TILE_SIZE), color, false, 1.0)

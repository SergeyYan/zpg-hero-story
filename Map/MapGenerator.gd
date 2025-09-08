# res://Map/MapGenerator.gd
extends Node2D

@export var TILE_SIZE := 32                # размер одного спрайта
@export var SPAWN_RADIUS := 13             # сколько квадратов в сторону спавнить (1 = 3×3)
@export var DESPAWN_RADIUS := 13           # на каком расстоянии удалять

# пути к текстурам
const TEXTURES := {
	"snow": "res://assets/map/snow.png",
	"sand": "res://assets/map/sand.png",
	"grass": "res://assets/map/grass.png",
	"earth": "res://assets/map/earth.png"
}
const MONSTER_SCENE := "res://characters/monster.tscn"


var _player: CharacterBody2D                 # ссылка на игрока
var _loaded_tiles: Dictionary = {}         # Vector2i(chunk) -> Sprite2D
var _textures: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _monsters: Dictionary = {}      # Vector2i(chunk) -> Array[Node]

func _ready() -> void:
	print("=== MapGenerator _ready() ===")
	# --- предзагрузка текстур ---
	for key in TEXTURES.keys():
		var tex := load(TEXTURES[key])
		if tex == null:
			push_error("Не удалось загрузить текстуру: " + TEXTURES[key])
		_textures[key] = tex
	
	_rng.randomize()
	# ищем Player в дереве (можно присвоить через @export, если удобнее)
	_player = get_tree().get_first_node_in_group("player")
	print("player = ", _player)
	if _player == null:
		push_error("MapGenerator: не найден узел в группе 'player'!")
		set_process(false)
		return
	# первичная генерация под игроком
	_update_chunks()

func _process(_delta) -> void:
	# обновляем карту каждый кадр (можно реже, если производительность важна)
	_update_chunks()

# основная логика
func _update_chunks() -> void:
	
	var player_chunk := world_to_chunk(_player.global_position)
	# 1. спавним недостающие
	for x in range(player_chunk.x - SPAWN_RADIUS, player_chunk.x + SPAWN_RADIUS + 1):
		for y in range(player_chunk.y - SPAWN_RADIUS, player_chunk.y + SPAWN_RADIUS + 1):
			var c := Vector2i(x, y)
			
			# тайлы
			if not _loaded_tiles.has(c):
				_spawn_tile(c)
				
			# монстры
			if not _monsters.has(c):
				_spawn_monsters(c)


	# 2. удаление дальних тайлов
	for c in _loaded_tiles.keys():
		if c.distance_to(player_chunk) > DESPAWN_RADIUS:
			_loaded_tiles[c].queue_free()
			_loaded_tiles.erase(c)
	# 3. удаление дальних монстров
	for c in _monsters.keys():
		if c.distance_to(player_chunk) > DESPAWN_RADIUS:
			for m in _monsters[c]:
				m.queue_free()
			_monsters.erase(c)

# создаём спрайт в нужном чанке
func _spawn_tile(chunk: Vector2i) -> void:
	var s := Sprite2D.new()
	s.texture = _pick_texture(chunk)
	s.centered = false
	s.position = chunk_to_world(chunk)
	add_child(s)
	_loaded_tiles[chunk] = s


# создаём монстра в нужном чанке
func _spawn_monsters(chunk: Vector2i) -> void:
	var spawn_chance := 0.01  # настраивайте это значение
	var list: Array = []
	
	if _rng.randf() < spawn_chance:
		var monster: Node = load(MONSTER_SCENE).instantiate()
		var pos := chunk_to_world(chunk) + Vector2(
			_rng.randf_range(0, TILE_SIZE),
			_rng.randf_range(0, TILE_SIZE)
		)
		monster.position = pos
		add_child(monster)
		list.append(monster)
		
	_monsters[chunk] = list


# выбираем текстуру в зависимости от глобальной Y
func _pick_texture(chunk: Vector2i) -> Texture2D:
	var world_y := chunk_to_world(chunk).y

	# 1. Базовая «температурная» шкала
	#  -200..-50  → почти всегда снег
	#  -50 .. 50   → много травы, немного снега/песка
	#   50 .. 200  → много травы, немного песка
	#  200 .. 350  → почти всегда песок
	var t := inverse_lerp(-700.0, 750.0, world_y)   # 50..150 → 0..1
	t = clamp(t, 0.0, 1.0) #+ _rng.randf()

	# 2. Два независимых шума: высота и «влажность/почва»
	var temp_noise := _rng.randf()          # 0..1
	var soil_noise := _rng.randf()   

	# 3. Вероятности по высоте
	var snow_prob := 1.0 - smoothstep(0.0, 0.1, t)
	var sand_prob  := smoothstep(0.9, 1, t)
	var grass_prob := 1.0 - sand_prob - snow_prob

	print("world_y:", world_y)
	print("t:", t)
	print("Вероятности: снег =", snow_prob , 
	  " трава =", grass_prob , 
	  " песок =", sand_prob)
	
	# 4. «Пересечение» земли: 20 % случаев земля «прорывает» любой биом
	if soil_noise < 0.10:  # Уменьшайте/увеличивайте `0.20`, чтобы сделать землю реже или чаще.
		return _textures["earth"]

	# 5. Иначе выбираем по температуре
	var r := temp_noise
	if r < snow_prob:
		return _textures["snow"]
	elif r < snow_prob + grass_prob:
		return _textures["grass"]
	else:
		return _textures["sand"]

# вспомогательные функции
func world_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(pos.x / TILE_SIZE),
		int(pos.y / TILE_SIZE)
	)

func chunk_to_world(chunk: Vector2i) -> Vector2:
	return Vector2(chunk.x, chunk.y) * TILE_SIZE

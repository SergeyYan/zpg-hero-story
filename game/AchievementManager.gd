# AchievementManager.gd
extends Node

signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)

@export_category("Physics Settings")
@export var popup_mass: float = 2.0
@export var popup_bounce_force: float = 300.0
@export var popup_damping: float = 2.0
var is_showing_popup: bool = false
var achievement_queue: Array[Dictionary] = []
var is_processing_queue: bool = false

var achievements: Dictionary = {
	"level_10": {
		"name": "Опытный воин", 
		"desc": "Достигните 10 уровня",
		"unlocked": false,
		"icon": "res://assets/achievements/level_10.png"
	},
	"level_20": {
		"name": "Мастер", 
		"desc": "Достигните 20 уровня",
		"unlocked": false,
		"icon": "res://assets/achievements/level_20.png"
	},
	"level_50": {
		"name": "Мастер", 
		"desc": "Достигните 50 уровня",
		"unlocked": false,
		"icon": "res://assets/achievements/level_50.png"
	},
	"level_100": {
		"name": "Мастер", 
		"desc": "Достигните 100 уровня",
		"unlocked": false,
		"icon": "res://assets/achievements/level_100.png"
	},
	"first_blood": {
		"name": "Первая кровь", 
		"desc": "Убейте первого монстра",
		"unlocked": false,
		"icon": "res://assets/achievements/first_blood.png"
	},
	"100_kills": {
		"name": "Охотник", 
		"desc": "Убейте 100 монстров",
		"unlocked": false,
		"icon": "res://assets/achievements/100_kills.png"
	},
	"500_kills": {
		"name": "Легендарный охотник", 
		"desc": "Убейте 500 монстров",
		"unlocked": false,
		"icon": "res://assets/achievements/500_kills.png"
	},
	"1000_kills": {
		"name": "Легендарный охотник", 
		"desc": "Убейте 1000 монстров",
		"unlocked": false,
		"icon": "res://assets/achievements/1000_kills.png"
	},
	"max_luck": {
		"name": "Везунчик", 
		"desc": "Максимальная удача",
		"unlocked": false,
		"icon": "res://assets/achievements/max_luck.png"
	},
	"max_agility": {
		"name": "Тень в ночи", 
		"desc": "Максимальная ловкость",
		"unlocked": false,
		"icon": "res://assets/achievements/max_agility.png"
	},
	"max_fortitude": {
		"name": "Несокрушимый", 
		"desc": "Максимальная крепость",
		"unlocked": false,
		"icon": "res://assets/achievements/max_fortitude.png"
	},
	"max_strength": {
		"name": "Силач", 
		"desc": "Максимальная сила",
		"unlocked": false,
		"icon": "res://assets/achievements/max_strength.png"
	},
	"max_endurance": {
		"name": "Живучий", 
		"desc": "Максимальная выносливость",
		"unlocked": false,
		"icon": "res://assets/achievements/max_endurance.png"
	},
	"equals_all_stats": {
		"name": "Совершенство", 
		"desc": "Прокачайте все поровну",
		"unlocked": false,
		"icon": "res://assets/achievements/equals_all_stats.png"
	},
	"perfect_balance": {
		"name": "Идеальный баланс", 
		"desc": "Прокачайте все до 20",
		"unlocked": false,
		"icon": "res://assets/achievements/perfect_balance.png"
	},
	"ultimate_balance": {
		"name": "Абсолютный баланс", 
		"desc": "Прокачайте все до 50",
		"unlocked": false,
		"icon": "res://assets/achievements/ultimate_balance.png"
	},
	"jack_of_all_trades": {
		"name": "Мастер на все руки", 
		"desc": "Прокачайте все хотя бы до 5",
		"unlocked": false,
		"icon": "res://assets/achievements/jack_of_all_trades.png"
	},
	"first_death": {
		"name": "Первая смерть", 
		"desc": "Впервые погибните в бою",
		"unlocked": false,
		"icon": "res://assets/achievements/first_death.png"
	}
}

func _ready():
	add_to_group("achievement_manager")
	# Подписываемся на сигнал новой игры
	connect_to_new_game_signal()


# Функция для подключения к сигналу новой игры
func connect_to_new_game_signal():
	# Ждем пока дерево сцены будет готово
	await get_tree().process_frame
	
	# Ищем кнопку "Новая игра" или меню, которое отвечает за новую игру
	var new_game_button = find_new_game_button()
	if new_game_button:
		new_game_button.connect("pressed", reset_all_achievements)
		print("Подключились к кнопке Новая игра")
	else:
		print("Кнопка Новая игра не найдена, используем группу")
		# Альтернативный способ: используем группу
		add_to_group("new_game_listener")

# Функция для поиска кнопки Новая игра
func find_new_game_button() -> Button:
	# Попробуем найти кнопку по разным путям
	var possible_paths = [
		"MainMenu/NewGameButton",
		"GameOverMenu/RestartButton", 
		"Menu/RestartButton"
	]
	
	for path in possible_paths:
		var node = get_tree().current_scene.get_node_or_null(path)
		if node and node is Button:
			return node
	
	# Ищем по группе
	var buttons = get_tree().get_nodes_in_group("new_game_button")
	if buttons.size() > 0:
		return buttons[0]
	
	return null

# Основная функция сброса всех достижений
func reset_all_achievements():
	print("Сбрасываем все достижения...")
	
	for achievement_id in achievements:
		achievements[achievement_id]["unlocked"] = false
	
	print("Все достижения сброшены!")
	
	# Можно также добавить визуальное подтверждение
	show_reset_notification()

# Функция для показа уведомления о сбросе (опционально)
func show_reset_notification():
	print("Достижения сброшены для новой игры!")


func unlock_achievement(achievement_id: String):
	if achievement_id in achievements and not achievements[achievement_id].unlocked:
		achievements[achievement_id].unlocked = true
		achievement_unlocked.emit(achievement_id, achievements[achievement_id])
		
		# Добавляем в очередь вместо немедленного показа
		achievement_queue.append(achievements[achievement_id])
		
		# Запускаем обработку очереди, если еще не запущена
		if not is_processing_queue:
			_process_achievement_queue()
		
		return true
	return false

func _process_achievement_queue():
	is_processing_queue = true
	
	while achievement_queue.size() > 0:
		var achievement_data = achievement_queue[0]
		achievement_queue.remove_at(0)
		
		# Показываем попап и ждем его завершения
		await show_achievement_popup(achievement_data)
		
		# Небольшая пауза между ачивками
		if achievement_queue.size() > 0:
			await get_tree().create_timer(1.0).timeout
	
	is_processing_queue = false

func check_kill_achievements(kills_count: int):
	if kills_count >= 1:
		await unlock_achievement("first_blood")
	if kills_count >= 100:
		await unlock_achievement("100_kills")
	if kills_count >= 500:
		await unlock_achievement("500_kills")
	if kills_count >= 1000:
		await unlock_achievement("1000_kills")

func check_level_achievements(level: int):
	if level >= 10:
		await unlock_achievement("level_10")
	if level >= 20:
		await unlock_achievement("level_20")
	if level >= 50:
		await unlock_achievement("level_50")
	if level >= 100:
		await unlock_achievement("level_100")

func check_stats_achievements(player_stats: Node):
	var base_stats = _get_base_stats_from_player_stats(player_stats)
	
	# Проверяем максимальные характеристики (базовые, без бонусов статусов)
	if base_stats["luck"] >= 100:
		await unlock_achievement("max_luck")
	if base_stats["agility"] >= 100:
		await unlock_achievement("max_agility")
	if base_stats["fortitude"] >= 100:
		await unlock_achievement("max_fortitude")
	if base_stats["strength"] >= 100:
		await unlock_achievement("max_strength")
	if base_stats["endurance"] >= 100:
		await unlock_achievement("max_endurance")
	
	# Проверяем условие для equals_all_stats
	var all_equal = (
		base_stats["strength"] == base_stats["fortitude"] and 
		base_stats["fortitude"] == base_stats["endurance"] and 
		base_stats["endurance"] == base_stats["agility"] and 
		base_stats["agility"] == base_stats["luck"] and
		base_stats["strength"] > 1
	)
	
	# Проверяем равные характеристики (базовые)
	if all_equal:
		print("🎯 РАЗБЛОКИРУЕМ 'equals_all_stats'!")
		await unlock_achievement("equals_all_stats")
	
	# Мастер на все руки (все базовые >= 5)
	if (base_stats["strength"] >= 5 and 
		base_stats["fortitude"] >= 5 and 
		base_stats["agility"] >= 5 and 
		base_stats["endurance"] >= 5 and 
		base_stats["luck"] >= 5):
		await unlock_achievement("jack_of_all_trades")
	
	# Идеальный баланс - все базовые характеристики равны 20
	if (base_stats["strength"] == 20 and 
		base_stats["fortitude"] == 20 and 
		base_stats["agility"] == 20 and 
		base_stats["endurance"] == 20 and 
		base_stats["luck"] == 20):
		await unlock_achievement("perfect_balance")
	
	# Абсолютный баланс - все базовые характеристики равны 50
	if (base_stats["strength"] == 50 and 
		base_stats["fortitude"] == 50 and 
		base_stats["agility"] == 50 and 
		base_stats["endurance"] == 50 and 
		base_stats["luck"] == 50):
		await unlock_achievement("ultimate_balance")

func get_unlocked_achievements() -> Array:
	var unlocked = []
	for achievement_id in achievements:
		if achievements[achievement_id].unlocked:
			unlocked.append(achievements[achievement_id])
	return unlocked

func get_locked_achievements() -> Array:
	var locked = []
	for achievement_id in achievements:
		if not achievements[achievement_id].unlocked:
			locked.append(achievements[achievement_id])
	return locked

func show_achievement_popup(achievement_data: Dictionary) -> void:
	if is_showing_popup:
		await get_tree().create_timer(0.5).timeout
		return
	
	is_showing_popup = true
	
	print("🪟 Показываем попап для:", achievement_data["name"])
	
	var center_pos: Vector2
	var camera = get_viewport().get_camera_2d()
	if not camera:
		var screen_size = get_viewport().get_visible_rect().size
		center_pos = screen_size / 2
	else:
		var camera_center = camera.get_screen_center_position()
		center_pos = camera_center
	
	var title_text = achievement_data["name"]
	var desc_text = achievement_data["desc"]
	
	var base_width = 400
	var min_width = 350
	var max_width = 600
	
	var title_length = title_text.length()
	var desc_length = desc_text.length()
	
	var calculated_width = base_width
	if title_length > 20 or desc_length > 40:
		calculated_width = base_width + (max(title_length - 20, desc_length - 40) * 8)
	calculated_width = clamp(calculated_width, min_width, max_width)
	
	var base_height = 120
	var extra_height = 0
	
	if desc_length > 50:
		extra_height = 20
	if desc_length > 80:
		extra_height = 40
	
	var panel_height = base_height + extra_height
	
	# Создаем попап как RigidBody2D для физики
	var panel = RigidBody2D.new()
	panel.gravity_scale = 0.0  # Отключаем гравитацию
	panel.linear_damp = 2.0    # Сопротивление движению
	panel.angular_damp = 5.0   # Сопротивление вращению
	panel.mass = 2.0           # Масса попапа
	panel.lock_rotation = true # Запрещаем вращение
	
	# Создаем CollisionShape2D для физического тела
	var collision_shape = CollisionShape2D.new()
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = Vector2(calculated_width, panel_height)
	collision_shape.shape = rectangle_shape
	
	# Создаем основную панель как дочерний нод
	var panel_visual = Panel.new()
	panel_visual.size = Vector2(calculated_width, panel_height)
	panel_visual.position = -panel_visual.size / 2  # Центрируем визуал относительно физического тела
	
	# Стилизуем панель
	panel_visual.add_theme_stylebox_override("panel", create_panel_style())
	
	# Создаем главный контейнер
	var main_container = MarginContainer.new()
	main_container.size = panel_visual.size
	main_container.add_theme_constant_override("margin_left", 15)
	main_container.add_theme_constant_override("margin_right", 15)
	main_container.add_theme_constant_override("margin_top", 10)
	main_container.add_theme_constant_override("margin_bottom", 10)
	
	# Создаем главный контейнер для содержимого
	var content_container = Control.new()
	content_container.size = Vector2(calculated_width - 30, panel_height - 20)
	
	# Контейнер для иконки (сдвигаем влево и вверх)
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(220, 220)
	icon_container.size = Vector2(220, 220)
	icon_container.position = Vector2(-80, -80)
	
	# Загружаем иконку
	var icon_texture = TextureRect.new()
	var texture_path = achievement_data.get("icon", "")
	
	if texture_path and ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		if texture:
			icon_texture.texture = texture
		else:
			icon_texture.texture = create_color_texture(Color.RED)
	else:
		icon_texture.texture = create_color_texture(Color.BLUE)
	
	icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_texture.custom_minimum_size = Vector2(200, 200)
	icon_texture.size = Vector2(200, 200)
	
	# Фон для иконки
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.2, 0.2, 0.2)
	icon_style.border_color = Color.GOLDENROD
	icon_style.border_width_left = 4
	icon_style.border_width_right = 4
	icon_style.border_width_top = 4
	icon_style.border_width_bottom = 4
	icon_style.corner_radius_top_left = 15
	icon_style.corner_radius_top_right = 15
	icon_style.corner_radius_bottom_right = 15
	icon_style.corner_radius_bottom_left = 15
	icon_style.shadow_color = Color(0, 0, 0, 0.8)
	icon_style.shadow_size = 15
	icon_style.shadow_offset = Vector2(5, 5)
	
	var icon_background = Panel.new()
	icon_background.add_theme_stylebox_override("panel", icon_style)
	icon_background.custom_minimum_size = Vector2(210, 210)
	icon_background.size = Vector2(210, 210)
	
	# Центрируем иконку и фон внутри icon_container
	var icon_center_container = CenterContainer.new()
	icon_center_container.custom_minimum_size = Vector2(220, 220)
	icon_center_container.size = Vector2(220, 220)
	
	icon_background.position = Vector2(5, 5)
	icon_texture.position = Vector2(5, 5)
	
	icon_center_container.add_child(icon_background)
	icon_center_container.add_child(icon_texture)
	icon_container.add_child(icon_center_container)
	
	# Контейнер для текста (позиционируем справа от иконки)
	var text_container = VBoxContainer.new()
	text_container.size = Vector2(calculated_width - 30 - 140, panel_height - 20)
	text_container.position = Vector2(140, 0)
	text_container.add_theme_constant_override("separation", 10)
	
	# Заголовок
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Описание
	var desc = Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 18)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color.WHITE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	text_container.add_child(title)
	text_container.add_child(desc)
	
	# Добавляем иконку и текст в главный контейнер
	content_container.add_child(icon_container)
	content_container.add_child(text_container)
	
	# Отключаем обрезку
	panel_visual.clip_contents = false
	main_container.clip_contents = false
	content_container.clip_contents = false
	
	# Добавляем все в главный контейнер
	main_container.add_child(content_container)
	panel_visual.add_child(main_container)
	
	# Добавляем все компоненты в физическое тело
	panel.add_child(collision_shape)
	panel.add_child(panel_visual)
	
	# Устанавливаем начальную позицию
	panel.position = center_pos
	
	# Добавляем на сцену
	get_tree().current_scene.add_child(panel)
	
	# Функция для проверки столкновений с игроком и монстрами
	panel.body_entered.connect(_on_popup_collision.bind(panel))
	
	# Анимация появления
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Анимация прозрачности
	tween.tween_property(panel_visual, "modulate:a", 1.0, 0.6).from(0.0)
	
	# Анимация масштаба иконки
	icon_center_container.scale = Vector2(0.3, 0.3)
	tween.tween_property(icon_center_container, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Небольшой импульс для "оживления" попапа
	await get_tree().create_timer(0.1).timeout
	panel.apply_impulse(Vector2(randf_range(-50, 50), randf_range(-30, 30)))
	
	await tween.finished
	await get_tree().create_timer(3.0).timeout
	
	# Анимация исчезновения
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel_visual, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	
	# Удаляем попап
	panel.queue_free()
	is_showing_popup = false
	
	print("ДОСТИЖЕНИЕ РАЗБЛОКИРОВАНО: ", achievement_data["name"])

# Функция обработки столкновений
func _on_popup_collision(body: Node, popup: RigidBody2D):
	# Проверяем, что столкнулись с игроком или монстром
	if body.is_in_group("player") or body.is_in_group("enemy"):
		# Применяем отталкивающую силу
		var direction = (popup.position - body.position).normalized()
		var force = 300.0  # Сила отталкивания
		
		popup.apply_impulse(direction * force)
		
		# Небольшой визуальный эффект при столкновении
		var tween = create_tween()
		tween.tween_property(popup, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.1)

# НОВАЯ ФУНКЦИЯ: Получает базовые характеристики из PlayerStats
func _get_base_stats_from_player_stats(player_stats: Node) -> Dictionary:
	var base_stats = {
		"strength": 1,
		"fortitude": 1,
		"agility": 1,
		"endurance": 1,
		"luck": 1
	}
	# Получаем характеристики напрямую из stats_system PlayerStats
	if player_stats and player_stats.stats_system:
		base_stats["strength"] = player_stats.stats_system.strength
		base_stats["fortitude"] = player_stats.stats_system.fortitude
		base_stats["agility"] = player_stats.stats_system.agility
		base_stats["endurance"] = player_stats.stats_system.endurance
		base_stats["luck"] = player_stats.stats_system.luck
	
	return base_stats

# Вспомогательная функция для создания цветной текстуры
func create_color_texture(color: Color) -> Texture2D:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_color = Color.GOLDENROD
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color.BLACK
	style.shadow_size = 10
	return style

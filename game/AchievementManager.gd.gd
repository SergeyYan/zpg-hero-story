# AchievementManager.gd
extends Node

signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)

var is_showing_popup: bool = false

var achievements: Dictionary = {
	"first_blood": {
		"name": "Первая кровь", 
		"desc": "Убейте первого монстра",
		"unlocked": false,
		"icon": "res://assets/achievements/first_blood.png"
	},
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
	"max_luck": {
		"name": "Везунчик", 
		"desc": "Максимально прокачайте удачу",
		"unlocked": false,
		"icon": "res://assets/achievements/max_luck.png"
	},
	"equals_all_stats": {
		"name": "Совершенство", 
		"desc": "прокачайте все характеристики поровну",
		"unlocked": false,
		"icon": "res://assets/achievements/equals_all_stats.png"
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


func unlock_achievement(achievement_id: String):
	if achievement_id in achievements and not achievements[achievement_id].unlocked:
		achievements[achievement_id].unlocked = true
		achievement_unlocked.emit(achievement_id, achievements[achievement_id])
		
		# Показываем уведомление
		show_achievement_popup(achievements[achievement_id])
		return true
	return false


func check_kill_achievements(kills_count: int):
	if kills_count >= 1:
		await unlock_achievement("first_blood")
	if kills_count >= 100:
		await unlock_achievement("100_kills")
	if kills_count >= 500:
		await unlock_achievement("500_kills")

func check_level_achievements(level: int):
	if level >= 10:
		await unlock_achievement("level_10")
	if level >= 20:
		await unlock_achievement("level_20")

func check_stats_achievements(stats_system: StatsSystem):
	if stats_system.luck >= 100:
		await unlock_achievement("max_luck")
	
	# Проверяем все характеристики на максимум (например, 20)
	if (stats_system.strength == stats_system.fortitude and 
		stats_system.fortitude == stats_system.endurance and 
		stats_system.endurance == stats_system.luck and 
		stats_system.luck == stats_system.strength and
		stats_system.strength > 1):
		await unlock_achievement("equals_all_stats")


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
		await get_tree().create_timer(2.5).timeout
	
	var battle_system = get_tree().get_first_node_in_group("battle_system")
	if battle_system:
		print("Ждем завершения боя...")
		await battle_system.battle_ended
		await get_tree().create_timer(0.5).timeout
		
	is_showing_popup = true
	
	var center_pos: Vector2
	var camera = get_viewport().get_camera_2d()
	if not camera:
		var screen_size = get_viewport().get_visible_rect().size
		center_pos = screen_size / 2
	else:
		var camera_center = camera.get_screen_center_position()
		center_pos = camera_center
	
	# Создаем попап
	var panel = Panel.new()
	panel.size = Vector2(400, 120)
	panel.position = center_pos - panel.size / 2
	
	# Стилизуем панель
	panel.add_theme_stylebox_override("panel", create_panel_style())
	
	# Создаем главный контейнер
	var main_container = MarginContainer.new()
	main_container.size = panel.size
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_top", 10)
	main_container.add_theme_constant_override("margin_bottom", 10)
	
	# Создаем горизонтальный контейнер
	var hbox = HBoxContainer.new()
	hbox.size = Vector2(380, 100)
	hbox.add_theme_constant_override("separation", 15)
	
	# Создаем контейнер для иконки
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(80, 80)
	
	# Загружаем иконку
	var icon_texture = TextureRect.new()
	var texture_path = achievement_data.get("icon", "")
	
	if texture_path and ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		if texture:
			icon_texture.texture = texture
		else:
			# Запасной вариант
			icon_texture.texture = create_color_texture(Color.RED)
	else:
		icon_texture.texture = create_color_texture(Color.BLUE)
	
	icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_texture.custom_minimum_size = Vector2(64, 64)
	icon_texture.size = Vector2(64, 64)
	
	# ВАРИАНТ 3: Добавляем красивый фон с обводкой для иконки
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.2, 0.2, 0.2)  # Темно-серый фон
	icon_style.border_color = Color.GOLDENROD    # Золотая обводка
	icon_style.border_width_left = 2
	icon_style.border_width_right = 2
	icon_style.border_width_top = 2
	icon_style.border_width_bottom = 2
	icon_style.corner_radius_top_left = 8
	icon_style.corner_radius_top_right = 8
	icon_style.corner_radius_bottom_right = 8
	icon_style.corner_radius_bottom_left = 8
	
	var icon_background = Panel.new()
	icon_background.add_theme_stylebox_override("panel", icon_style)
	icon_background.custom_minimum_size = Vector2(70, 70)
	icon_background.size = Vector2(70, 70)
	
	# Сначала добавляем фон, потом иконку
	icon_container.add_child(icon_background)
	icon_container.add_child(icon_texture)
	
	# Создаем вертикальный контейнер для текста
	var vbox = VBoxContainer.new()
	vbox.size = Vector2(280, 100)
	vbox.add_theme_constant_override("separation", 8)
	
	var title = Label.new()
	title.text = achievement_data["name"]
	title.add_theme_font_size_override("font_size", 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.GOLD)
	title.size = Vector2(280, 30)
	
	var desc = Label.new()
	desc.text = achievement_data["desc"]
	desc.add_theme_font_size_override("font_size", 20)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color.WHITE)
	desc.size = Vector2(280, 40)
	
	vbox.add_child(title)
	vbox.add_child(desc)
	
	# Добавляем иконку и текст в горизонтальный контейнер
	hbox.add_child(icon_container)
	hbox.add_child(vbox)
	
	# Добавляем все в главный контейнер
	main_container.add_child(hbox)
	panel.add_child(main_container)
	
	# Добавляем на сцену
	get_tree().current_scene.add_child(panel)
	
	# Анимация появления
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_property(panel, "position:y", panel.position.y, 0.5).from(panel.position.y - 100)
	
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	
	# Анимация исчезновения
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_property(panel, "position:y", panel.position.y - 100, 0.5)
	
	await tween.finished
	
	if not (battle_system and battle_system.visible):
		get_tree().paused = false
	
	panel.queue_free()
	is_showing_popup = false
	
	print("ДОСТИЖЕНИЕ РАЗБЛОКИРОВАНО: ", achievement_data["name"])

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

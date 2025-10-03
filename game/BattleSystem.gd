#BattleSystem.gd
extends CanvasLayer

signal battle_ended(victory: bool)

const PLAYER_CRITICAL_MULTIPLIER := 2.0
const ENEMY_CRITICAL_MULTIPLIER := 1.5

@onready var player_stats_container: VBoxContainer = $StatsPlayer/PlayerStats
@onready var enemy_stats: VBoxContainer = $StatsMonster/EnemyStats
@onready var battle_log: RichTextLabel = $BattleUI/BattleLog
@onready var timer: Timer = $Timer
@onready var stats_player: Control = $StatsPlayer
@onready var stats_monster: Control = $StatsMonster
@onready var battle_ui: Control = $BattleUI

# ← НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ АДАПТИВНОСТИ
var screen_size: Vector2
var is_mobile: bool = false
var base_font_size: int = 14

# ← НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ ФИКСИРОВАННОЙ ШИРИНЫ
var stats_container_width: int = 200
var label_min_width: int = 180

var player_stats_instance: PlayerStats
var current_enemy: Node = null
var current_enemy_stats: MonsterStats = null
var is_player_turn: bool = true

var player_attack_messages = [
	"[color=#ff6b6b]Герой нанес ⚔️ %d урона![/color]",
	"[color=#ff6b6b]Герой с разбегу ударил на ⚔️ %d урона![/color]",
	"[color=#ff6b6b]Герой на отмашь ударил на ⚔️ %d урона![/color]", 
	"[color=#ff6b6b]Герой нанес мощный удар на ⚔️ %d урона![/color]",
	"[color=#ff6b6b]Герой бросил камень в голову на ⚔️ %d урона![/color]",
	"[color=#ff6b6b]Герой упал на коленку врага и нанесли ⚔️ %d урона![/color]",
	"[color=#ff6b6b]Герой плюнул прямо в бубен на ⚔️ %d урона![/color]",
	"[color=#ff6b6b]Разящий удар героя в пах на ⚔️ %d урона![/color]",
	"[color=#ff6b6b]Сокрушительный удар по самолюбию врага на ⚔️ %d урона![/color]",
	"[color=#ff6b6b]Враг спотыкнулся и получил ⚔️ %d урона![/color]"
]

var enemy_attack_messages = [
	"[color=#ffd93d]%s нанес вам ⚔️ %d урона![/color]",
	"[color=#ffd93d]%s атакует и наносит ⚔️ %d урона![/color]",
	"[color=#ffd93d]%s бьет вас на ⚔️ %d урона![/color]",
	"[color=#ffd93d]Атака %sа в голову наносит ⚔️ %d урона![/color]",
	"[color=#ffd93d]%s царапает вас на ⚔️ %d урона![/color]",
	"[color=#ffd93d]%s кусает вас на ⚔️ %d урона![/color]",
	"[color=#ffd93d]Щелчок %sа наносит ⚔️ %d урона![/color]",
	"[color=#ffd93d]%s толкает вас на ⚔️ %d урона![/color]",
	"[color=#ffd93d]Бросок пыли %sа наносит ⚔️ %d урона![/color]",
	"[color=#ffd93d]%s прыгает вам на шею, нанесен ⚔️ %d урона пояснице![/color]"
]

var player_critical_messages = [
	"[color=#ff0000][b]🔥 ГЕРОЙ НАНОСИТ КРИТИЧЕСКИЙ УДАР! %d урона! 🔥[/b][/color]",
	"[color=#ff0000][b]💥 ГЕРОЙ НАНОСИТ СМЕРТЕЛЬНЫЙ УДАР! %d урона! 💥[/b][/color]",
	"[color=#ff0000][b]⭐ ГЕРОЙ ДЕЛАЕТ ИДЕАЛЬНЫЙ УДАР! %d урона! ⭐[/b][/color]"
]

var enemy_critical_messages = [
	"[color=#ffcc00][b]🔥 %s НАНОСИТ КРИТИЧЕСКИЙ УДАР! %d урона! 🔥[/b][/color]",
	"[color=#ffcc00][b]💥 %s НАНОСИТ СМЕРТЕЛЬНЫЙ УДАР! %d урона! 💥[/b][/color]",
	"[color=#ffcc00][b]⭐ %s ДЕЛАЕТ ИДЕАЛЬНЫЙ УДАР! %d урона! ⭐[/b][/color]"
]

func _ready():
	add_to_group("battle_system")
	
	# ← ОПРЕДЕЛЯЕМ ТИП УСТРОЙСТВА
	_detect_device_type()
	# ← НАСТРАИВАЕМ АДАПТИВНЫЙ ИНТЕРФЕЙС
	_setup_responsive_ui()
	
	player_stats_instance = get_tree().get_first_node_in_group("player_stats")
	if not player_stats_instance:
		push_error("PlayerStats not found!")
	
	hide()

# ← НОВАЯ ФУНКЦИЯ: ОПРЕДЕЛЕНИЕ ТИПА УСТРОЙСТВА
func _detect_device_type():
	screen_size = get_viewport().get_visible_rect().size
	is_mobile = screen_size.x < 790
	
	if is_mobile:
		print("BattleSystem: обнаружено мобильное устройство")
		base_font_size = 12
		stats_container_width = 180
		label_min_width = 140
	else:
		print("BattleSystem: обнаружено десктоп устройство")
		base_font_size = 14
		stats_container_width = 220
		label_min_width = 180

# ← НОВАЯ ФУНКЦИЯ: НАСТРОЙКА АДАПТИВНОГО ИНТЕРФЕЙСА
func _setup_responsive_ui():
	if is_mobile:
		_setup_mobile_layout()
	else:
		_setup_desktop_layout()
	
	_update_font_sizes()

# ← НОВАЯ ФУНКЦИЯ: МОБИЛЬНАЯ КОМПОНОВКА
func _setup_mobile_layout():
	print("BattleSystem: Установка мобильной компоновки")
	
	# Скрываем статистику игрока на мобильных
	if stats_player:
		stats_player.visible = false
	
	# Настраиваем BattleLog - растягиваем по ширине и ограничиваем высоту
	if battle_ui and battle_log:
		battle_ui.size = Vector2(screen_size.x * 0.95, screen_size.y * 0.3)
		battle_ui.position = Vector2(
			(screen_size.x - battle_ui.size.x) / 2,
			screen_size.y * 0.25
		)
		
		# BattleLog занимает всю доступную площадь
		battle_log.size = battle_ui.size
		battle_log.position = Vector2.ZERO
		
		# Ограничиваем количество видимых строк (4-5 строк)
		battle_log.scroll_following = false
		battle_log.fit_content = false
	
	# Настраиваем EnemyStats - по центру ниже BattleLog
	if stats_monster:
		stats_monster.visible = true
		stats_monster.size = Vector2(stats_container_width, screen_size.y * 0.28)
		stats_monster.position = Vector2(
			(screen_size.x - stats_monster.size.x) / 2,
			screen_size.y * 0.55  # Ниже BattleLog
		)

# ← НОВАЯ ФУНКЦИЯ: ДЕСКТОПНАЯ КОМПОНОВКА
func _setup_desktop_layout():
	print("BattleSystem: Установка десктопной компоновки")
	
	# Показываем все элементы на десктопе
	if stats_player:
		stats_player.visible = true
		stats_player.size = Vector2(stats_container_width, 150)
		stats_player.position = Vector2(
			(screen_size.x - stats_monster.size.x) * 0.29,  # Левая часть экрана
			(screen_size.y - stats_player.size.y) / 2.15
		)
	
	if stats_monster:
		stats_monster.visible = true
		stats_monster.size = Vector2(stats_container_width, 150)
		stats_monster.position = Vector2(
			(screen_size.x - stats_monster.size.x) * 0.71,  # Правая часть экрана
			(screen_size.y - stats_monster.size.y) / 2.15
		)
		
	# Стандартные размеры для десктопа
	if battle_ui:
		battle_ui.size = Vector2(600, 200)
		battle_ui.position = Vector2(
			(screen_size.x - battle_ui.size.x) / 2,
			screen_size.y / 1.7  # Верхняя часть экрана
		)
		
		if battle_log:
			battle_log.size = battle_ui.size
			battle_log.position = Vector2.ZERO

# ← НОВАЯ ФУНКЦИЯ: ОБНОВЛЕНИЕ РАЗМЕРОВ ШРИФТОВ
func _update_font_sizes():
	if battle_log:
		battle_log.add_theme_font_size_override("normal_font_size", base_font_size)
	
	# Обновляем шрифты в контейнерах статистики
	_update_stats_font_sizes(player_stats_container)
	_update_stats_font_sizes(enemy_stats)

# ← НОВАЯ ФУНКЦИЯ: ОБНОВЛЕНИЕ ШРИФТОВ СТАТИСТИКИ
func _update_stats_font_sizes(container: VBoxContainer):
	if not container:
		return
	
	for child in container.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", base_font_size)
			# Устанавливаем минимальную ширину для выравнивания
			child.custom_minimum_size.x = label_min_width
			# Выравнивание текста по левому краю
			child.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func start_battle(enemy: Node, enemy_stats_ref: MonsterStats):
	if player_stats_instance.current_health <= 0:
		return
	
	# Добавить проверку на валидность enemy
	if not is_instance_valid(enemy) or not is_instance_valid(enemy_stats_ref):
		return
	
	# ЗАЩИТА: не начинаем бой в первые секунды игры
	if get_tree().get_frame() < 60:
		return
	
	# ← ОБНОВЛЯЕМ РАЗМЕРЫ ПЕРЕД ПОКАЗОМ
	_detect_device_type()
	_setup_responsive_ui()
	
	current_enemy = enemy
	current_enemy_stats = enemy_stats_ref
	show()
	get_tree().paused = true
	_disable_menu_button(true)
	update_stats()
	battle_log.text = "Бой начался против %s!\n" % current_enemy_stats.enemy_name
	timer.start(1.0)

func update_stats():
	# ПРОВЕРКА НА ВАЛИДНОСТЬ ВРАГА И ЕГО СТАТИСТИК
	if not is_instance_valid(current_enemy) or not current_enemy_stats:
		end_battle(false)
		return
		
	var effective_stats = player_stats_instance.get_effective_stats()
	
	# Обновляем статистику игрока только если она видима
	if stats_player and stats_player.visible:
		_update_stat_display(player_stats_container, "Игрок", 
			player_stats_instance.current_health, player_stats_instance.get_max_health(),
			effective_stats["strength"],
			effective_stats["fortitude"],
			effective_stats["endurance"],
			effective_stats["luck"]
		)
	
	# Обновляем статистику врага
	_update_stat_display(enemy_stats, current_enemy_stats.enemy_name, 
		current_enemy_stats.current_health, current_enemy_stats.get_max_health(),
		current_enemy_stats.stats_system.strength,
		current_enemy_stats.stats_system.fortitude,
		current_enemy_stats.stats_system.endurance,
		current_enemy_stats.stats_system.luck
	)

func _update_stat_display(container: VBoxContainer, name: String, 
						 health: int, max_health: int, 
						 strength: int, fortitude: int, endurance: int, luck: int):
	for child in container.get_children():
		child.queue_free()
	
	# Устанавливаем фиксированную ширину контейнера
	container.custom_minimum_size.x = stats_container_width
	container.size.x = stats_container_width
	
	var name_label = Label.new()
	name_label.text = name
	name_label.add_theme_font_size_override("font_size", base_font_size)
	name_label.custom_minimum_size.x = label_min_width
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(name_label)
	
	var health_label = Label.new()
	health_label.text = "HP: %d/%d ❤️" % [health, max_health]
	health_label.add_theme_font_size_override("font_size", base_font_size)
	health_label.custom_minimum_size.x = label_min_width
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(health_label)
	
	# ПОКАЗЫВАЕМ РЕАЛЬНЫЕ ХАРАКТЕРИСТИКИ
	var strength_label = Label.new()
	strength_label.text = "Сила: %d ⚔️" % strength
	strength_label.add_theme_font_size_override("font_size", base_font_size)
	strength_label.custom_minimum_size.x = label_min_width
	strength_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(strength_label)
	
	var fortitude_label = Label.new()
	fortitude_label.text = "Крепость: %d 🛡️" % fortitude
	fortitude_label.add_theme_font_size_override("font_size", base_font_size)
	fortitude_label.custom_minimum_size.x = label_min_width
	fortitude_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(fortitude_label)
	
	var endurance_label = Label.new()
	endurance_label.text = "Выносливость: %d 💪" % endurance
	endurance_label.add_theme_font_size_override("font_size", base_font_size)
	endurance_label.custom_minimum_size.x = label_min_width
	endurance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(endurance_label)

	var luck_label = Label.new()
	luck_label.text = "Удача: %d 🎲" % luck
	luck_label.add_theme_font_size_override("font_size", base_font_size)
	luck_label.custom_minimum_size.x = label_min_width
	luck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(luck_label)

func _on_timer_timeout():
	# ПРОВЕРКА: если игрок умер - немедленно заканчиваем бой
	if player_stats_instance.current_health <= 0:
		end_battle(false)
		return
	
	if is_player_turn:
		player_attack()
	else:
		enemy_attack()
	
	update_stats()
	
	# ПРОВЕРКА после атаки
	if not is_instance_valid(current_enemy) or not current_enemy_stats:
		end_battle(false)
		return
	
	# ПРОВЕРКА здоровья через MonsterStats
	if current_enemy_stats.current_health <= 0:
		end_battle(true)
	elif player_stats_instance.current_health <= 0:
		end_battle(false)
	else:
		is_player_turn = !is_player_turn
		timer.start(1.0)

func get_random_attack_message(messages_array: Array) -> String:
	return messages_array[randi() % messages_array.size()]

func player_attack():
	if not is_instance_valid(current_enemy) or not current_enemy_stats:
		end_battle(false)
		return
	
	# РАСЧЕТ УРОНА
	var base_damage = player_stats_instance.get_effective_damage()
	var enemy_defense = current_enemy_stats.get_defense()
	var actual_damage = max(1, base_damage - enemy_defense)
	var crit_chance = player_stats_instance.get_crit_chance_with_modifiers()
	
	if randf() < crit_chance:
		var critical_damage = int((base_damage * PLAYER_CRITICAL_MULTIPLIER) - enemy_defense)
		critical_damage = max(1, critical_damage)
		var message = get_random_attack_message(player_critical_messages) % critical_damage
		battle_log.text += message + "\n"
		current_enemy_stats.take_damage(critical_damage)
	else:
		var message = get_random_attack_message(player_attack_messages) % actual_damage
		battle_log.text += message + "\n"
		current_enemy_stats.take_damage(actual_damage)

func enemy_attack():
	if not is_instance_valid(current_enemy) or not current_enemy_stats:
		end_battle(false)
		return
	
	# РАСЧЕТ УРОНА
	var base_damage = current_enemy_stats.get_damage()
	var player_defense = player_stats_instance.get_effective_defense()
	var actual_damage = max(1, base_damage - player_defense)
	var crit_chance = current_enemy_stats.stats_system.get_crit_chance()
	
	if randf() < crit_chance:
		var critical_damage = int((base_damage * ENEMY_CRITICAL_MULTIPLIER) - player_defense)
		critical_damage = max(1, critical_damage)
		var message = get_random_attack_message(enemy_critical_messages) % [current_enemy_stats.enemy_name, critical_damage]
		battle_log.text += message + "\n"
		player_stats_instance.take_damage(critical_damage)
	else:
		var message = get_random_attack_message(enemy_attack_messages) % [current_enemy_stats.enemy_name, actual_damage]
		battle_log.text += message + "\n"
		player_stats_instance.take_damage(actual_damage)

func end_battle(victory: bool):
	if victory and current_enemy_stats:
		var exp_gained = current_enemy_stats.exp_reward
		player_stats_instance.add_exp(exp_gained)
		player_stats_instance.apply_post_battle_effects()
		player_stats_instance.add_monster_kill()
		
		var has_bad_luck = false
		var has_lucky_day = false
		for status in player_stats_instance.active_statuses:
			if status.id == "bad_luck":
				has_bad_luck = true
			if status.id == "lucky_day":
				has_lucky_day = true
		
		if has_bad_luck and has_lucky_day:
			battle_log.text += "[color=#ffaa00]Победа! Получено %d опыта (День противоречий!).[/color]\n" % exp_gained
		elif has_bad_luck:
			battle_log.text += "[color=#ffcc00]Победа! Получено %d опыта (Ужасный день).[/color]\n" % exp_gained
		elif has_lucky_day:
			battle_log.text += "[color=#00ff00]Победа! Получено %d опыта (Удачный день).[/color]\n" % exp_gained
		else:
			battle_log.text += "[color=#00ff00]Победа! Получено %d опыта.[/color]\n" % exp_gained
		
		if is_instance_valid(current_enemy):
			current_enemy.queue_free()
	else:
		battle_log.text += "[color=#ff0000]Вы проиграли...[/color]\n"
		
	timer.stop()
	await get_tree().create_timer(2.5).timeout
	
	if victory and player_stats_instance:
		player_stats_instance.complete_level_up_after_battle()
	
	hide()
	_disable_menu_button(false)
	battle_ended.emit(victory)
	current_enemy = null
	current_enemy_stats = null

func _disable_menu_button(disabled: bool):
	var menu_button = get_tree().get_first_node_in_group("menu_button")
	if menu_button:
		menu_button.disabled = disabled
		if disabled:
			menu_button.modulate = Color(1, 1, 1, 0.5)
		else:
			menu_button.modulate = Color(1, 1, 1, 1)

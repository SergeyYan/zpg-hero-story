#BattleSystem.gd
extends CanvasLayer

signal battle_ended(victory: bool)

const PLAYER_CRITICAL_MULTIPLIER := 2.0
const ENEMY_CRITICAL_MULTIPLIER := 1.5

@onready var player_stats_container: VBoxContainer = $StatsPlayer/PlayerStats
@onready var enemy_stats: VBoxContainer = $StatsMonster/EnemyStats
@onready var battle_log: RichTextLabel = $BattleUI/BattleLog
@onready var timer: Timer = $Timer

var player_stats_instance: PlayerStats
var current_enemy: Node = null
var current_enemy_stats: MonsterStats = null  # ← ДОБАВИЛИ!
var is_player_turn: bool = true

var player_attack_messages = [
	"[color=#ff6b6b]Герой нанес ⚔️ %d урона![/color]",  # ← Красный
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
	"[color=#ffd93d]%s нанес вам ⚔️ %d урона![/color]",  # ← Желтый
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
	"[color=#ff0000][b]🔥 ГЕРОЙ НАНОСИТ КРИТИЧЕСКИЙ УДАР! %d урона! 🔥[/b][/color]",  # ← Красный + жирный
	"[color=#ff0000][b]💥 ГЕРОЙ НАНОСИТ СМЕРТЕЛЬНЫЙ УДАР! %d урона! 💥[/b][/color]",
	"[color=#ff0000][b]⭐ ГЕРОЙ ДЕЛАЕТ ИДЕАЛЬНЫЙ УДАР! %d урона! ⭐[/b][/color]"
]

var enemy_critical_messages = [
	"[color=#ffcc00][b]🔥 %s НАНОСИТ КРИТИЧЕСКИЙ УДАР! %d урона! 🔥[/b][/color]",  # ← Желтый + жирный
	"[color=#ffcc00][b]💥 %s НАНОСИТ СМЕРТЕЛЬНЫЙ УДАР! %d урона! 💥[/b][/color]",
	"[color=#ffcc00][b]⭐ %s ДЕЛАЕТ ИДЕАЛЬНЫЙ УДАР! %d урона! ⭐[/b][/color]"
]


func _ready():
	add_to_group("battle_system")
	player_stats_instance = get_tree().get_first_node_in_group("player_stats")
	if not player_stats_instance:
		push_error("PlayerStats not found!")
	
	hide()  # ← ДОБАВИТЬ ЭТУ СТРОКУ!

func start_battle(enemy: Node, enemy_stats_ref: MonsterStats):
	if player_stats_instance.current_health <= 0:
		#print("Игрок мёртв, бой не начинается")
		return
	# Добавить проверку на валидность enemy
	if not is_instance_valid(enemy) or not is_instance_valid(enemy_stats_ref):
		#print("Враг невалиден, бой не начинается")
		return
	# ЗАЩИТА: не начинаем бой в первые секунды игры
	if get_tree().get_frame() < 60:  # Первые 60 кадров (≈1 секунда)
		#print("Слишком рано для боя, пропускаем")
		return
	
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
	
	_update_stat_display(player_stats_container, "Игрок", 
		player_stats_instance.current_health, player_stats_instance.get_max_health(),
		effective_stats["strength"],      # ← Эффективная сила
		effective_stats["fortitude"],     # ← Эффективная крепость
		effective_stats["endurance"],     # ← Эффективная выносливость
		effective_stats["luck"]           # ← Эффективная удача
	)
	
	# ПЕРЕДАЕМ РЕАЛЬНЫЕ ХАРАКТЕРИСТИКИ монстра
	_update_stat_display(enemy_stats, current_enemy_stats.enemy_name, 
		current_enemy_stats.current_health, current_enemy_stats.get_max_health(),
		current_enemy_stats.stats_system.strength,        # ← Реальная сила
		current_enemy_stats.stats_system.fortitude,       # ← Реальная крепость  
		current_enemy_stats.stats_system.endurance,        # ← Реальная выносливость
		current_enemy_stats.stats_system.luck             # ← ДОБАВЛЯЕМ УДАЧУ
	)

func _update_stat_display(container: VBoxContainer, name: String, 
						 health: int, max_health: int, 
						 strength: int, fortitude: int, endurance: int, luck: int):  # ← Новые параметры!
	for child in container.get_children():
		child.queue_free()
	
	var name_label = Label.new()
	name_label.text = name
	container.add_child(name_label)
	
	var health_label = Label.new()
	health_label.text = "HP: %d/%d ❤️" % [health, max_health]
	container.add_child(health_label)
	
	# ПОКАЗЫВАЕМ РЕАЛЬНЫЕ ХАРАКТЕРИСТИКИ
	var strength_label = Label.new()
	strength_label.text = "Сила: %d ⚔️" % strength
	container.add_child(strength_label)
	
	var fortitude_label = Label.new()
	fortitude_label.text = "Крепость: %d 🛡️" % fortitude
	container.add_child(fortitude_label)
	
	var endurance_label = Label.new()
	endurance_label.text = "Выносливость: %d 💪" % endurance
	container.add_child(endurance_label)

	var luck_label = Label.new()
	luck_label.text = "Удача: %d 🎲" % luck
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
	var base_damage = player_stats_instance.get_effective_damage()  # Эта функция ДОЛЖНА учитывать effective_stats
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
		# ПОКАЗЫВАЕМ ФАКТИЧЕСКИЙ урон (после защиты)
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
		# ПЕРЕМЕЩАЕМ вызов статусов ВНУТРЬ условия victory
		player_stats_instance.apply_post_battle_effects()
		# ← ДОБАВЛЯЕМ ПОДСЧЕТ УБИЙСТВ
		player_stats_instance.add_monster_kill()
		
		# ← ПРОВЕРЯЕМ BAD_LUCK ДЛЯ СООБЩЕНИЯ
		var has_bad_luck = false
		var has_lucky_day = false
		for status in player_stats_instance.active_statuses:
			if status.id == "bad_luck":
				has_bad_luck = true
			if status.id == "lucky_day":
				has_lucky_day = true
		
		if has_bad_luck and has_lucky_day:
			battle_log.text += "[color=#ffaa00]Победа! Получено %d опыта (День противоречий!).[/color]\n" % exp_gained
		elif  has_bad_luck:
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
	# ← ДОБАВЛЯЕМ ТАЙМЕР ПАУЗЫ ДЛЯ ЧТЕНИЯ
	await get_tree().create_timer(2.5).timeout
	
	# ← ВЫЗЫВАЕМ ПРОКАЧКУ ПОСЛЕ БОЯ
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
		# Можно также изменить прозрачность для визуального обозначения
		if disabled:
			menu_button.modulate = Color(1, 1, 1, 0.5)
		else:
			menu_button.modulate = Color(1, 1, 1, 1)

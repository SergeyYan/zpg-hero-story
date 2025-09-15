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
	"Герой нанес %d урона!",
	"Герой с разбегу ударил на %d урона!",
	"Герой на отмашь ударил на %d урона!",
	"Герой нанес мощный удар на %d урона!",
	"Герой бросил камень в голову на %d урона!",
	"Герой упал на коленку врага и нанесли %d урона!",
	"Герой плюнул прямо в бубен на %d урона!",
	"Разящий удар героя в пах на %d урона!",
	"Сокрушительный удар по самолюбию врага на %d урона!",
	"Враг спотыкнулся и получил %d урона!"
]

var enemy_attack_messages = [
	"%s нанес вам %d урона!",
	"%s атакует и наносит %d урона!",
	"%s бьет вас на %d урона!",
	"Атака %sа в голову наносит %d урона!",
	"%s царапает вас на %d урона!",
	"%s кусает вас на %d урона!",
	"Щелчок %sа наносит %d урона!",
	"%s толкает вас на %d урона!",
	"Бросок пыли %sа наносит %d урона!",
	"%s прыгает вам на шею, нанесен %d урона пояснице!"
]

var player_critical_messages = [
	"🔥 ГЕРОЙ НАНОСИТ КРИТИЧЕСКИЙ УДАР! %d урона! 🔥",
	"💥 ГЕРОЙ НАНОСИТ СМЕРТЕЛЬНЫЙ УДАР! %d урона! 💥",
	"⭐ ГЕРОЙ ДЕЛАЕТ ИДЕАЛЬНЫЙ УДАР! %d урона! ⭐"
]

var enemy_critical_messages = [
	"🔥 %s НАНОСИТ КРИТИЧЕСКИЙ УДАР! %d урона! 🔥",
	"💥 %s НАНОСИТ СМЕРТЕЛЬНЫЙ УДАР! %d урона! 💥",
	"⭐ %s ДЕЛАЕТ ИДЕАЛЬНЫЙ УДАР! %d урона! ⭐"
]


func _ready():
	add_to_group("battle_system")
	player_stats_instance = get_tree().get_first_node_in_group("player_stats")
	if not player_stats_instance:
		push_error("PlayerStats not found! Make sure PlayerStats node is in 'player_stats' group")
	
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
	update_stats()
	battle_log.text = "Бой начался против %s!\n" % current_enemy_stats.enemy_name
	timer.start(1.0)
	

func update_stats():
	# ПРОВЕРКА НА ВАЛИДНОСТЬ ВРАГА И ЕГО СТАТИСТИК
	if not is_instance_valid(current_enemy) or not current_enemy_stats:
		end_battle(false)
		return
	
	_update_stat_display(player_stats_container, "Игрок", 
		player_stats_instance.current_health, player_stats_instance.get_max_health(),
		player_stats_instance.stats_system.strength,      # ← Реальная сила
		player_stats_instance.stats_system.fortitude,     # ← Реальная крепость
		player_stats_instance.stats_system.endurance,      # ← Реальная выносливость
		player_stats_instance.stats_system.luck           # ← ДОБАВЛЯЕМ УДАЧУ
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
	health_label.text = "HP: %d/%d" % [health, max_health]
	container.add_child(health_label)
	
	# ПОКАЗЫВАЕМ РЕАЛЬНЫЕ ХАРАКТЕРИСТИКИ
	var strength_label = Label.new()
	strength_label.text = "Сила: %d" % strength
	container.add_child(strength_label)
	
	var fortitude_label = Label.new()
	fortitude_label.text = "Крепость: %d" % fortitude
	container.add_child(fortitude_label)
	
	var endurance_label = Label.new()
	endurance_label.text = "Выносливость: %d" % endurance
	container.add_child(endurance_label)

	var luck_label = Label.new()
	luck_label.text = "Удача: %d" % luck
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
		print("❌ Враг удален после атаки")
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
	var base_damage = player_stats_instance.get_damage()
	var enemy_defense = current_enemy_stats.get_defense()
	var actual_damage = max(1, base_damage - enemy_defense)
	var crit_chance = player_stats_instance.stats_system.get_crit_chance()
	
	if randf() < crit_chance:
		var critical_damage = int((base_damage * PLAYER_CRITICAL_MULTIPLIER) - enemy_defense)
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
	var player_defense = player_stats_instance.get_defense()
	var actual_damage = max(1, base_damage - player_defense)
	var crit_chance = current_enemy_stats.stats_system.get_crit_chance()
	
	if randf() < crit_chance:
		var critical_damage = int((base_damage * ENEMY_CRITICAL_MULTIPLIER) - player_defense)
		var message = get_random_attack_message(enemy_critical_messages) % [current_enemy_stats.enemy_name, critical_damage]
		battle_log.text += message + "\n"
		player_stats_instance.take_damage(critical_damage)
	else:
		# ПОКАЗЫВАЕМ ФАКТИЧЕСКИЙ урон (после защиты)
		var message = get_random_attack_message(enemy_attack_messages) % [current_enemy_stats.enemy_name, actual_damage]
		battle_log.text += message + "\n"
		player_stats_instance.take_damage(actual_damage)

func end_battle(victory: bool):
	if victory and current_enemy_stats:
		var exp_gained = current_enemy_stats.exp_reward
		player_stats_instance.add_exp(exp_gained)
		battle_log.text += "Победа! Получено %d опыта.\n" % exp_gained
		
		if is_instance_valid(current_enemy):
			current_enemy.queue_free()
	else:
		battle_log.text += "Вы проиграли...\n"
	
	timer.stop()
	battle_ended.emit(victory)
	
	# ВАЖНО: НЕ снимаем паузу если началась прокачка уровня!
	# Паузу будет управлять LevelUpMenu
	if not player_stats_instance.current_health <= 0:
		# Только если игрок не умер И не началась прокачка
		var player_stats = get_tree().get_first_node_in_group("player_stats")
		if player_stats and player_stats.available_points <= 0:  # ← Проверяем что нет очков для прокачки
			get_tree().paused = false
			print("Бой завершен, пауза снята")
		else:
			print("Бой завершен, пауза остается для прокачки")
	
	hide()
	
	current_enemy = null
	current_enemy_stats = null

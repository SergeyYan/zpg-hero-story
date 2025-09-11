#BattleSystem.gd
extends CanvasLayer

signal battle_ended(victory: bool)

@onready var player_stats_container: VBoxContainer = $BattleUI/PlayerStats
@onready var enemy_stats: VBoxContainer = $BattleUI/EnemyStats
@onready var battle_log: RichTextLabel = $BattleUI/BattleLog
@onready var timer: Timer = $Timer

var player_stats_instance: PlayerStats
var current_enemy: Node = null
var current_enemy_stats: MonsterStats = null  # ← ДОБАВИЛИ!
var is_player_turn: bool = true

func _ready():
	add_to_group("battle_system")
	player_stats_instance = get_tree().get_first_node_in_group("player_stats")
	if not player_stats_instance:
		push_error("PlayerStats not found! Make sure PlayerStats node is in 'player_stats' group")
	
	hide()  # ← ДОБАВИТЬ ЭТУ СТРОКУ!

func start_battle(enemy: Node, enemy_stats_ref: MonsterStats):
	if player_stats_instance.current_health <= 0:
		print("Игрок мёртв, бой не начинается")
		return
	# Добавить проверку на валидность enemy
	if not is_instance_valid(enemy) or not is_instance_valid(enemy_stats_ref):
		print("Враг невалиден, бой не начинается")
		return
	# ЗАЩИТА: не начинаем бой в первые секунды игры
	if get_tree().get_frame() < 60:  # Первые 60 кадров (≈1 секунда)
		print("Слишком рано для боя, пропускаем")
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
		player_stats_instance.current_health, player_stats_instance.get_max_health(),  # ← get_max_health()
		player_stats_instance.get_damage(), player_stats_instance.get_defense())       # ← get_damage() и get_defense()
	
	# Обновляем статистику врага - ИСПОЛЬЗУЕМ ГЕТТЕРЫ!
	_update_stat_display(enemy_stats, current_enemy_stats.enemy_name, 
		current_enemy_stats.current_health, current_enemy_stats.get_max_health(),      # ← get_max_health()
		current_enemy_stats.get_damage(), current_enemy_stats.get_defense())           # ← get_damage() и get_defense()

func _update_stat_display(container: VBoxContainer, name: String, 
						 health: int, max_health: int, damage: int, defense: int):
	for child in container.get_children():
		child.queue_free()
	
	var name_label = Label.new()
	name_label.text = name
	container.add_child(name_label)
	
	var health_label = Label.new()
	health_label.text = "HP: %d/%d" % [health, max_health]
	container.add_child(health_label)
	
	var damage_label = Label.new()
	damage_label.text = "Урон: %d" % damage
	container.add_child(damage_label)
	
	var defense_label = Label.new()
	defense_label.text = "Защита: %d" % defense
	container.add_child(defense_label)

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

func player_attack():
	if not is_instance_valid(current_enemy) or not current_enemy_stats:
		end_battle(false)
		return
	
	var damage = max(1, player_stats_instance.get_damage() - current_enemy_stats.get_defense())
	current_enemy_stats.take_damage(damage)  # ← Вызываем у MonsterStats!
	battle_log.text += "Вы нанесли %d урона!\n" % damage

func enemy_attack():
	if not is_instance_valid(current_enemy) or not current_enemy_stats:
		end_battle(false)
		return
	
	var damage = max(1, current_enemy_stats.get_damage() - player_stats_instance.get_defense())
	player_stats_instance.take_damage(damage)
	battle_log.text += "%s нанес вам %d урона!\n" % [current_enemy_stats.enemy_name, damage]

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
	
	# ВАЖНО: снимаем паузу в ЛЮБОМ случае после боя!
	get_tree().paused = false  # ← СНИМАЕМ ПАУЗУ всегда после завершения боя
	print("Бой завершен, пауза снята")
	
	hide()
	
	current_enemy = null
	current_enemy_stats = null

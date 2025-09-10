#PlayerHUD.gd
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var level_label: Label = $LevelLabel
@onready var exp_bar: ProgressBar = $ExpBar
@onready var damage_label: Label = $StatsContainer/DamageLabel
@onready var defense_label: Label = $StatsContainer/DefenseLabel
@onready var exp_label: Label = $StatsContainer/ExpLabel
@onready var stats_container: VBoxContainer = $StatsContainer  # ← Добавили!

var player_stats_instance: PlayerStats  # Экземпляр PlayerStats

func _ready():
	# Находим экземпляр PlayerStats
	player_stats_instance = get_tree().get_first_node_in_group("player_stats")
	if not player_stats_instance:
		push_error("PlayerStats not found!")
		return
	
	# Подключаемся к сигналам
	player_stats_instance.health_changed.connect(update_health)
	player_stats_instance.level_up.connect(update_level)
	
	update_display()

func update_health(health: int):
	health_bar.value = health
	health_label.text = "HP: %d/%d" % [health, player_stats_instance.max_health]

func update_level(new_level: int):
	level_label.text = "Level: %d" % new_level
	update_exp_display()

func update_exp_display():
	exp_bar.value = player_stats_instance.current_exp
	exp_bar.max_value = player_stats_instance.exp_to_level
	exp_label.text = "Exp: %d/%d" % [player_stats_instance.current_exp, player_stats_instance.exp_to_level]

func update_display():
	update_health(player_stats_instance.current_health)
	update_level(player_stats_instance.level)
	update_exp_display()
	
	# Просто обновляем существующие лейблы без создания новых
	damage_label.text = "Damage: %d" % player_stats_instance.damage
	defense_label.text = "Defense: %d" % player_stats_instance.defense
	exp_label.text = "Exp: %d/%d" % [player_stats_instance.current_exp, player_stats_instance.exp_to_level]

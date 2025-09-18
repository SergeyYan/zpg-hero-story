#PlayerHUD.gd
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var level_label: Label = $LevelLabel
@onready var exp_bar: ProgressBar = $ExpBar

# ОСТАВЛЯЕМ только labels характеристик
@onready var strength_label: Label = $StatsContainer/StrengthLabel
@onready var fortitude_label: Label = $StatsContainer/FortitudeLabel  
@onready var endurance_label: Label = $StatsContainer/EnduranceLabel
@onready var luck_label: Label = $StatsContainer/LuckLabel
@onready var regen_label: Label = $StatsContainer/RegenLabel
@onready var kills_label: Label = $KillBox/KillsLabel  # ← НОВЫЙ ЛЕЙБЛ

var player_stats_instance: PlayerStats

func _ready():
	# Находим экземпляр PlayerStats
	player_stats_instance = get_tree().get_first_node_in_group("player_stats")
	if not player_stats_instance:
		push_error("PlayerStats not found!")
		return
	
	# Подключаемся к сигналам
	player_stats_instance.health_changed.connect(update_health)
	player_stats_instance.level_up.connect(update_level)
	player_stats_instance.exp_gained.connect(_on_exp_gained)
	player_stats_instance.stats_changed.connect(update_stats_display)  # ← НОВОЕ ПОДКЛЮЧЕНИЕ!
	player_stats_instance.monsters_killed_changed.connect(update_kills_display)  # ← НОВЫЙ СИГНАЛ
	
	# Инициализируем бары
	health_bar.max_value = player_stats_instance.get_max_health()
	exp_bar.max_value = player_stats_instance.exp_to_level
	
	update_display()
	update_kills_display(player_stats_instance.monsters_killed)  # ← ИНИЦИАЛИЗИРУЕМ СЧЕТЧИК


func update_health(health: int):
	# ОБНОВЛЯЕМ максимальное значение здоровья при изменении
	health_bar.max_value = player_stats_instance.get_max_health()
	health_bar.value = health
	health_label.text = "HP: %d/%d" % [health, player_stats_instance.get_max_health()]

func update_level(new_level: int, available_points: int):  # ← Добавляем второй параметр
	level_label.text = "Level: %d" % new_level
	update_exp_display()
	update_stats_display()  # ← Обновляем характеристики и очки!
	# available_points можно не использовать, т.к. берем из player_stats_instance

func update_exp_display():
	# ОБНОВЛЯЕМ максимальное значение опыта
	exp_bar.max_value = player_stats_instance.exp_to_level
	exp_bar.value = player_stats_instance.current_exp
	# Можно добавить визуальный эффект при получении опыта
	_create_exp_gain_effect()

func _create_exp_gain_effect():
	# Визуальный эффект для получения опыта
	var tween = create_tween()
	tween.tween_property(exp_bar, "value", player_stats_instance.current_exp, 0.3)
#	tween.tween_callback(_check_level_up)

func update_stats_display():
	# Обновляем ТОЛЬКО характеристики
	if strength_label:
		strength_label.text = "Сила: %d" % player_stats_instance.stats_system.strength
	if fortitude_label:
		fortitude_label.text = "Крепость: %d" % player_stats_instance.stats_system.fortitude
	if endurance_label:
		endurance_label.text = "Выносливость: %d" % player_stats_instance.stats_system.endurance
	if luck_label:
		luck_label.text = "Удача: %d" % player_stats_instance.stats_system.luck
	if regen_label:
		regen_label.text = "Восстановление: %.1f/s" % player_stats_instance.get_health_regen()

func update_kills_display(kills: int):
	if kills_label:
		kills_label.text = "Убито монстров: %d" % kills

func update_display():
	update_health(player_stats_instance.current_health)
	update_level(player_stats_instance.level, player_stats_instance.available_points)  # player_stats_instance.available_points ← Добавляем второй аргумент!
	update_exp_display()
	update_stats_display()

# ДОБАВЛЯЕМ обработку получения опыта
func _on_exp_gained():
	# Создаем эффект получения опыта
	_create_exp_gain_effect()

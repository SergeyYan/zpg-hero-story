# DevPanel.gd
extends CanvasLayer

@onready var dev_panel: Panel = $DevPanel
@onready var status_list: ItemList = $DevPanel/MarginContainer/VBoxContainer/HSplitContainer/StatusList
@onready var add_status_button: Button = $DevPanel/MarginContainer/VBoxContainer/HSplitContainer/VBoxContainer/AddStatusButton
@onready var remove_status_button: Button = $DevPanel/MarginContainer/VBoxContainer/HSplitContainer/VBoxContainer/RemoveStatusButton
@onready var strength_spin: SpinBox = $DevPanel/MarginContainer/VBoxContainer/StatsContainer/StrengthSpin
@onready var fortitude_spin: SpinBox = $DevPanel/MarginContainer/VBoxContainer/StatsContainer/FortitudeSpin
@onready var endurance_spin: SpinBox = $DevPanel/MarginContainer/VBoxContainer/StatsContainer/EnduranceSpin
@onready var luck_spin: SpinBox = $DevPanel/MarginContainer/VBoxContainer/StatsContainer/LuckSpin
@onready var apply_stats_button: Button = $DevPanel/MarginContainer/VBoxContainer/StatsContainer/ApplyStatsButton
@onready var heal_button: Button = $DevPanel/MarginContainer/VBoxContainer/ActionsContainer/HealButton
@onready var level_up_button: Button = $DevPanel/MarginContainer/VBoxContainer/ActionsContainer/LevelUpButton
@onready var add_exp_button: Button = $DevPanel/MarginContainer/VBoxContainer/ActionsContainer/AddExpButton
@onready var close_button: Button = $DevPanel/MarginContainer/VBoxContainer/CloseButton

var player_stats: PlayerStats
var secret_code: Array[String] = ["K", "O", "D"]
var current_input: Array[String] = []
var all_status_ids: Array[String] = []
var signals_connected: bool = false

func _ready():
	# ← УСТАНАВЛИВАЕМ ПРАВИЛЬНЫЙ Z_INDEX ДЛЯ ПАНЕЛИ
	dev_panel.z_index = 1000
	self.layer = 1000
	
	dev_panel.visible = false
	
	# ← НАСТРАИВАЕМ РАЗМЕРЫ ПАНЕЛИ
	dev_panel.size = Vector2(800, 600)
	dev_panel.position = Vector2(0, 0)
	
	# ← НАСТРАИВАЕМ РАЗМЕРЫ И РАССТОЯНИЯ
	var vbox = $DevPanel/MarginContainer/VBoxContainer
	vbox.add_theme_constant_override("separation", 5)
	
	var hsplit = $DevPanel/MarginContainer/VBoxContainer/HSplitContainer
	hsplit.add_theme_constant_override("separation", 5)
	
	var stats_container = $DevPanel/MarginContainer/VBoxContainer/StatsContainer
	if stats_container is GridContainer:
		stats_container.add_theme_constant_override("v_separation", 5)
		stats_container.add_theme_constant_override("h_separation", 5)
	
	var actions_container = $DevPanel/MarginContainer/VBoxContainer/ActionsContainer
	actions_container.add_theme_constant_override("separation", 5)
	
	# ← НАСТРАИВАЕМ СПИСОК СТАТУСОВ
	status_list.add_theme_font_size_override("font_size", 12)
	status_list.custom_minimum_size = Vector2(200, 150)
	
	# ГРУППИРУЕМ СТАТУСЫ ПО КАТЕГОРИЯМ (ОДИН РАЗ!)
	var status_categories = {
		"ПОЛОЖИТЕЛЬНЫЕ": [
			"well_fed", "good_shoes", "inspired", "adrenaline", "lucky_day",
			"potion_splash", "strange_mushroom", "cloak_tent", "mage_potion",
			"phoenix_feather", "thinker"
		],
		"НЕГАТИВНЫЕ": [
			"sore_knees", "crying", "exhausted", "bad_luck", "minor_injury",
			"swamp_bog", "snake_bite", "stunned", "sleepy"
		]
	}
	
	# Очищаем список перед добавлением
	status_list.clear()
	
	for category in status_categories:
		status_list.add_item("--- " + category + " ---")
		for status_id in status_categories[category]:
			status_list.add_item(status_id)
	
	if not signals_connected:
		_connect_signals()
		signals_connected = true

func _connect_signals():
	_disconnect_signals()
	
	add_status_button.pressed.connect(_on_add_status_button_pressed)
	remove_status_button.pressed.connect(_on_remove_status_button_pressed)
	apply_stats_button.pressed.connect(_on_apply_stats_button_pressed)
	heal_button.pressed.connect(_on_heal_button_pressed)
	level_up_button.pressed.connect(_on_level_up_button_pressed)
	add_exp_button.pressed.connect(_on_add_exp_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)

func _disconnect_signals():
	if add_status_button.pressed.is_connected(_on_add_status_button_pressed):
		add_status_button.pressed.disconnect(_on_add_status_button_pressed)
	if remove_status_button.pressed.is_connected(_on_remove_status_button_pressed):
		remove_status_button.pressed.disconnect(_on_remove_status_button_pressed)
	if apply_stats_button.pressed.is_connected(_on_apply_stats_button_pressed):
		apply_stats_button.pressed.disconnect(_on_apply_stats_button_pressed)
	if heal_button.pressed.is_connected(_on_heal_button_pressed):
		heal_button.pressed.disconnect(_on_heal_button_pressed)
	if level_up_button.pressed.is_connected(_on_level_up_button_pressed):
		level_up_button.pressed.disconnect(_on_level_up_button_pressed)
	if add_exp_button.pressed.is_connected(_on_add_exp_button_pressed):
		add_exp_button.pressed.disconnect(_on_add_exp_button_pressed)
	if close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.disconnect(_on_close_button_pressed)

func _input(event):
	if event is InputEventKey and event.pressed:
		var key = OS.get_keycode_string(event.keycode)
		print("Нажата клавиша: ", key)
		
		current_input.append(key)
		print("Текущий ввод: ", current_input)
		
		if current_input.size() > secret_code.size():
			current_input.remove_at(0)
		
		if current_input == secret_code:
			print("Код распознан! Открываю панель...")
			toggle_dev_panel()
			current_input.clear()

func toggle_dev_panel():
	if not player_stats:
		player_stats = get_tree().get_first_node_in_group("player_stats")
		if not player_stats:
			push_error("PlayerStats not found!")
			return
	
	dev_panel.visible = not dev_panel.visible
	get_tree().paused = dev_panel.visible
	
	if dev_panel.visible:
		update_display()

func update_display():
	if not player_stats:
		return
	
	strength_spin.value = player_stats.stats_system.strength
	fortitude_spin.value = player_stats.stats_system.fortitude
	endurance_spin.value = player_stats.stats_system.endurance
	luck_spin.value = player_stats.stats_system.luck
	
	status_list.deselect_all()
	for i in range(status_list.get_item_count()):
		var item_text = status_list.get_item_text(i)
		# Пропускаем заголовки категорий
		if item_text.begins_with("---"):
			continue
			
		for active_status in player_stats.active_statuses:
			if active_status.id == item_text:
				status_list.select(i)
				break

func _on_add_status_button_pressed():
	print("Добавить статус нажата")
	var selected = status_list.get_selected_items()
	if selected.size() > 0:
		var status_id = status_list.get_item_text(selected[0])
		# Проверяем, что это не заголовок категории
		if not status_id.begins_with("---"):
			print("Добавляем статус: ", status_id)
			player_stats.add_status(status_id)
			update_display()

func _on_remove_status_button_pressed():
	print("Удалить статус нажата")
	var selected = status_list.get_selected_items()
	if selected.size() > 0:
		var status_id = status_list.get_item_text(selected[0])
		# Проверяем, что это не заголовок категории
		if not status_id.begins_with("---"):
			print("Удаляем статус: ", status_id)
			player_stats.remove_status(status_id)
			update_display()

func _on_apply_stats_button_pressed():
	print("Применить характеристики нажата")
	if player_stats:
		player_stats.stats_system.strength = int(strength_spin.value)
		player_stats.stats_system.fortitude = int(fortitude_spin.value)
		player_stats.stats_system.endurance = int(endurance_spin.value)
		player_stats.stats_system.luck = int(luck_spin.value)
		player_stats.stats_changed.emit()

func _on_heal_button_pressed():
	print("Лечение нажато")
	if player_stats:
		player_stats.current_health = player_stats.get_max_health()
		player_stats.health_changed.emit(player_stats.current_health)

func _on_level_up_button_pressed():
	print("Уровень UP нажато")
	if player_stats:
		player_stats._level_up()

func _on_add_exp_button_pressed():
	print("+1000 опыта нажато")
	if player_stats:
		player_stats.add_exp(1000)

func _on_close_button_pressed():
	print("Закрыть нажато")
	toggle_dev_panel()

#GameOverMenu.gd
extends CanvasLayer


@onready var restart_button: Button = $Panel/RestartButton
@onready var quit_button: Button = $Panel/QuitButton

func _ready():
	hide()
	# Подключаемся к сигналу смерти игрока
	var player_stats = get_tree().get_first_node_in_group("player_stats")
	if player_stats:
		player_stats.player_died.connect(show_game_over)

func show_game_over():
	show()
	get_tree().paused = true

func _on_restart_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()  # ← Прямой перезапуск!

func _on_quit_button_pressed():
	get_tree().quit()  # ← Прямой выход!

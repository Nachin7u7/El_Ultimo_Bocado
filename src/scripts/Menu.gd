extends CanvasLayer

signal mode_selected(mode)

const PLAYER_VS_PLAYER = 0
const PLAYER_VS_BOT = 1

func _ready():
	var panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -150
	panel.offset_top = -90
	panel.offset_right = 150
	panel.offset_bottom = 90
	add_child(panel)

	var label = Label.new()
	label.text = "Selecciona modo de juego:"
	label.position = Vector2(50, 20)
	panel.add_child(label)

	var btn_friend = Button.new()
	btn_friend.text = "Jugar con un amigo"
	btn_friend.position = Vector2(50, 60)
	btn_friend.size = Vector2(200, 40)
	btn_friend.connect("pressed", Callable(self, "_on_friend_pressed"))
	panel.add_child(btn_friend)

	var btn_bot = Button.new()
	btn_bot.text = "Jugar contra un bot"
	btn_bot.position = Vector2(50, 110)
	btn_bot.size = Vector2(200, 40)
	btn_bot.connect("pressed", Callable(self, "_on_bot_pressed"))
	panel.add_child(btn_bot)

func _on_friend_pressed():
	emit_signal("mode_selected", PLAYER_VS_PLAYER)
	queue_free()

func _on_bot_pressed():
	emit_signal("mode_selected", PLAYER_VS_BOT)
	queue_free()

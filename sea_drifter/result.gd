extends CanvasLayer
var label: Label
func _ready():
	label = Label.new()
	label.position = Vector2(170, 130)
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
func show_result(won: bool, kills: int):
	label.text = ("抵达灯塔 · 生存成功" if won else "木筏沉没 · 漂流结束") + "\n击杀：%d\nEnter 再来一次" % kills

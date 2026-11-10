extends CanvasLayer
var game: Node
var title: Label
var stats: Label
var notice: Label
var alerts: Label
var health: ColorRect
var panel: ColorRect
var menu: Label
var slots: Array[Label] = []
var preview = false

func text_at(pos: Vector2, size: int, color: Color) -> Label:
	var label = Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("101725"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label

func box(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	add_child(rect)
	return rect

func _ready():
	game = get_parent()
	var gold = Color("d4b78a")
	box(Vector2(12, 10), Vector2(210, 43), Color(0.05, 0.08, 0.12, 0.65))
	box(Vector2(12, 10), Vector2(2, 43), gold)
	title = text_at(Vector2(22, 14), 12, Color("f0dfbb"))
	stats = text_at(Vector2(22, 32), 9, Color("b7c1bd"))
	box(Vector2(469, 14), Vector2(155, 5), Color("293944"))
	health = box(Vector2(469, 14), Vector2(155, 5), Color("b4c399"))
	var controls = text_at(Vector2(14, 340), 9, Color("b4c1bd"))
	controls.text = "A/D 划船   J 弓   K 小刀   Tab 背包   Esc 暂停"
	notice = text_at(Vector2(20, 303), 11, Color("e4c993"))
	alerts = text_at(Vector2(12, 179), 12, gold)
	panel = box(Vector2(148, 100), Vector2(344, 170), Color(0.04, 0.07, 0.11, 0.94))
	menu = text_at(Vector2(168, 118), 14, Color("eddfbd"))
	var inventory_view = Control.new()
	inventory_view.set_script(preload("res://inventory_view.gd"))
	add_child(inventory_view)

func _process(_dt):
	var state = GameState
	var names = {"DAY":"白昼", "DUSK":"暮色", "NIGHT":"长夜", "DAWN":"破晓", "SAIL":"驶向灯塔", "RESULT":"旅程结束"}
	var duration = float(state.config.phases.get(game.phase.to_lower(), 0))
	title.text = "海上流浪者   /   第 %d 天 · %s" % [state.day, names[game.phase]]
	stats.text = "余时 %ds   护甲 %d   弓 %d   小刀 %s" % [maxi(0, int(ceil(duration - game.elapsed))), state.armor, state.config.weapons.bow.damage + state.bonus, str(state.config.weapons.knife.damage + state.bonus) if state.knife else "—"]
	health.size.x = 155 * clampf(state.hp / state.max_hp, 0, 1)
	notice.text = game.message if game.message_time > 0 else ""
	var center = clampf(game.boat.position.x, 320, state.config.world.width - 320)
	var left = false
	var right = false
	for enemy in game.enemies.get_children():
		if enemy.hp <= 0: continue
		var relative = enemy.position.x - center
		left = left or (relative < -320 and relative >= -320 - state.config.world.alert_distance)
		right = right or (relative > 320 and relative <= 320 + state.config.world.alert_distance)
	if game.phase == "DUSK":
		left = true
		right = true
	alerts.text = ("◀ 来袭" if left else "") + ("                                            来袭 ▶" if right else "")
	alerts.modulate.a = 0.5 + sin(game.clock * 6) * 0.4
	panel.visible = game.paused and not preview
	menu.visible = panel.visible
	if game.inventory: menu.text = "行囊与工坊\n\n1—6  使用物资\nB  三木头 → 加固板\nN  三木头 → 小刀图纸\nTab 返回"
	elif game.paused: menu.text = "潮汐稍歇\n\nEsc 继续旅程\nR  重新开始"

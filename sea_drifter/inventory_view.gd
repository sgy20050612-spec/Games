extends Control
var game: Node
var font: Font
var gold = Color("d6bd8c")
var muted = Color("97a8ac")
func _ready():
	game = get_parent().get_parent()
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_dt): queue_redraw()
func text(pos: Vector2, value: String, size: int = 11, color: Color = Color("e9dfc6")):
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
func frame(rect: Rect2, color: Color = Color("887d65")):
	draw_rect(rect, Color(0.045, 0.075, 0.105, 0.96))
	draw_rect(rect, color, false, 1)
func icon(kind: String, pos: Vector2, scale_value: float = 1.0):
	draw_set_transform(pos, 0, Vector2.ONE * scale_value)
	match kind:
		"wood":
			for i in range(3):
				draw_rect(Rect2(-9, -7 + i * 5, 18, 4), Color("9c704a"))
				draw_rect(Rect2(-8, -7 + i * 5, 15, 1), Color("d5b37c"))
			draw_rect(Rect2(-4, -8, 2, 17), Color("ead3a2"))
		"plastic":
			draw_rect(Rect2(-3, -12, 6, 3), gold)
			draw_rect(Rect2(-6, -9, 12, 18), Color("519eaa"))
			draw_rect(Rect2(-4, -7, 2, 12), Color("c2e4d3"))
			draw_rect(Rect2(-6, 1, 12, 4), Color("b9cab2"))
		"stone":
			draw_colored_polygon(PackedVector2Array([Vector2(-10, 6), Vector2(-6, -8), Vector2(3, -11), Vector2(10, -2), Vector2(7, 9)]), Color("82949e"))
			draw_line(Vector2(-6, -8), Vector2(3, -11), Color("cfcec0"), 2)
		"blueprint":
			draw_rect(Rect2(-9, -12, 18, 23), gold)
			draw_rect(Rect2(-7, -10, 14, 19), Color("537d92"))
			draw_line(Vector2(-4, 5), Vector2(5, -6), Color("ece3b9"), 2)
			draw_line(Vector2(-4, -6), Vector2(4, -6), Color("9fbbc3"), 1)
		"knife":
			draw_line(Vector2(-7, 8), Vector2(-2, 2), Color("b38d5f"), 4)
			draw_line(Vector2(-1, 1), Vector2(9, -11), Color("d6e1d2"), 4)
		"board":
			draw_rect(Rect2(-10, -12, 20, 24), Color("996b48"))
			for y in [-7, 5]: draw_rect(Rect2(-12, y, 24, 3), Color("a3adb0"))
	draw_set_transform(Vector2.ZERO)
func slot(index: int, pos: Vector2, large: bool):
	var s = GameState
	var size = Vector2(70, 60) if large else Vector2(30, 31)
	frame(Rect2(pos, size), gold if large and index == s.selected_slot else Color("685e51"))
	var entry = s.bag[index]
	text(pos + Vector2(4, 11), str(index + 1), 9, muted)
	if not entry.is_empty():
		icon(entry.kind, pos + size * Vector2(0.5, 0.48), 1.1 if large else 0.65)
		text(pos + Vector2(size.x - 18, size.y - 4), str(entry.count), 10, gold)
		if large:
			var names = {"wood":"木头", "plastic":"塑料", "stone":"石头", "blueprint":"小刀图纸"}
			text(pos + Vector2(7, 49), names.get(entry.kind, "物品"), 10)
func _draw():
	if not is_instance_valid(game): return
	for i in range(GameState.bag.size()): slot(i, Vector2(438 + i * 32, 320), false)
	if not game.inventory or game.paused: return
	draw_rect(Rect2(0, 60, 640, 250), Color(0.015, 0.025, 0.05, 0.67))
	frame(Rect2(36, 76, 264, 211))
	frame(Rect2(316, 76, 288, 211))
	text(Vector2(52, 98), "工坊  /  手动合成", 15, gold)
	text(Vector2(332, 98), "行囊  /  2 × 3", 15, gold)
	text(Vector2(332, 114), "每格上限 %d  ·  已用 %d/6 格" % [GameState.config.player.stack_limit, GameState.used_slots()], 10, muted)
	for i in range(GameState.bag.size()): slot(i, Vector2(344 + i % 3 * 78, 125 + int(i / 3) * 67), true)
	var wood = GameState.count_item("wood")
	var plans = GameState.count_item("blueprint")
	var cost = int(GameState.config.resources.craft_cost)
	var board_ok = wood >= cost and GameState.armor < GameState.config.player.armor_cap
	var knife_ok = wood >= cost and plans >= GameState.config.resources.knife_blueprints and not GameState.knife
	frame(Rect2(50, 115, 236, 62), Color("92b593") if board_ok else Color("555c63"))
	icon("board", Vector2(72, 143))
	text(Vector2(94, 133), "[B] 制作加固板", 12, gold if board_ok else muted)
	text(Vector2(94, 151), "木头 %d/%d  → 生命上限 +%d" % [wood, cost, GameState.config.resources.board_hp], 10)
	text(Vector2(94, 166), "护甲 +1（黎明清空）", 10, muted)
	frame(Rect2(50, 186, 236, 72), Color("92b593") if knife_ok else Color("555c63"))
	icon("knife", Vector2(72, 214))
	text(Vector2(94, 205), "[N] 制作小刀" if not GameState.knife else "小刀已制作", 12, gold if knife_ok else muted)
	text(Vector2(94, 224), "木头 %d/%d  +  图纸 %d/%d" % [wood, cost, plans, GameState.config.resources.knife_blueprints], 10)
	text(Vector2(94, 243), "图纸不会自动解锁武器", 10, muted)
	text(Vector2(52, 276), "B / N 合成 · 材料不足不消耗", 10, muted)
	text(Vector2(332, 276), "方向键选格 · E 使用 · 1—6 快捷使用", 10, muted)
	text(Vector2(239, 303), "Tab / Esc 关闭背包", 11, gold)

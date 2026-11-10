extends Area2D
var kind = "wood"
var age = 0.0
var game: Node
func _ready(): game = get_parent().get_parent()
func _physics_process(dt):
	if not game.active(): return
	age += dt
	if age >= GameState.config.world.drop_lifetime:
		if kind == "blueprint": GameState.defer_blueprint()
		queue_free()
		return
	if absf(position.x - game.boat.position.x) < GameState.config.world.pickup_radius:
		if kind == "blueprint" and GameState.blueprint_claimed:
			queue_free()
			return
		if GameState.add_item(kind) > 0:
			game.note("背包已满：Tab 使用或合成后再拾取")
			return
		game.note("获得小刀图纸：Tab → 左侧工坊按 N 合成" if kind == "blueprint" else "拾取物资：Tab 查看背包")
		queue_free()
	queue_redraw()
func _draw():
	var bob = round(sin(age * 3) * 2)
	draw_set_transform(Vector2(0, bob))
	match kind:
		"wood":
			for i in range(3):
				draw_rect(Rect2(-9, -7 + i * 4, 18, 3), Color("946d4b"))
				draw_line(Vector2(-7, -7 + i * 4), Vector2(7, -7 + i * 4), Color("c2a16d"), 1)
			draw_rect(Rect2(-4, -8, 2, 13), Color("d2bd88"))
		"plastic":
			draw_rect(Rect2(-3, -12, 6, 3), Color("cbbd8a"))
			draw_rect(Rect2(-5, -9, 10, 14), Color("5e9a99"))
			draw_rect(Rect2(-3, -7, 2, 9), Color("b2d2bd"))
			draw_rect(Rect2(-5, -2, 10, 3), Color("c8c7a4"))
		"stone":
			draw_colored_polygon(PackedVector2Array([Vector2(-8, 3), Vector2(-6, -7), Vector2(2, -11), Vector2(8, -4), Vector2(6, 5)]), Color("74818a"))
			draw_line(Vector2(-6, -7), Vector2(2, -11), Color("b4b4a2"), 2)
		"blueprint":
			draw_rect(Rect2(-7, -12, 14, 17), Color("d4bd86"))
			draw_rect(Rect2(-5, -10, 10, 13), Color("6c9392"))
			draw_line(Vector2(-3, 0), Vector2(3, -7), Color("e2d2a6"), 2)
			for i in range(3):
				var p = Vector2(cos(age * 2 + i * 2), sin(age * 2 + i * 2)) * 13
				draw_rect(Rect2(p.round(), Vector2(2, 2)), Color("ffe6a1"))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-12, 8), Vector2(12, 8), Color(0.6, 0.77, 0.78, 0.35), 1)

extends CharacterBody2D
var facing = 1
var invincible = 0.0
var cooldown = 0.0
var windup = 0.0
var turn = 0.0
var attack = ""
var shake = 0.0
var game: Node
var animation_time = 0.0
var rowing = false
var slash_time = 0.0

func _ready():
	game = get_parent()
	var camera = $Camera2D
	camera.limit_left = 0
	camera.limit_right = int(GameState.config.world.width)
	camera.limit_top = 0
	camera.limit_bottom = int(GameState.config.world.height)
	camera.position.y = -60

func _physics_process(dt):
	if not game.active(): return
	animation_time += dt
	slash_time = maxf(0, slash_time - dt)
	var c = GameState.config
	invincible = maxf(0, invincible - dt)
	cooldown = maxf(0, cooldown - dt)
	turn = maxf(0, turn - dt)
	shake = maxf(0, shake - dt)
	var dir = int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	rowing = dir != 0
	if dir != 0 and dir != facing:
		facing = dir
		turn = c.player.turn_lock
	if windup > 0:
		windup -= dt
		if windup <= 0:
			game.strike(attack)
			slash_time = 0.22
	if cooldown <= 0 and windup <= 0:
		if Input.is_physical_key_pressed(KEY_J): begin_attack("bow")
		elif Input.is_physical_key_pressed(KEY_K) and GameState.knife: begin_attack("knife")
	var speed = c.player.speed * (c.player.attack_move if cooldown > 0 else 1.0)
	if turn <= 0: position.x += dir * speed * dt
	var clamped = clampf(position.x, c.world.reef, c.world.width - c.world.reef)
	if clamped != position.x: shake = 0.12
	position.x = clamped
	$Camera2D.offset = Vector2(randf_range(-2, 2), randf_range(-1, 1)) if shake > 0 else Vector2.ZERO
	queue_redraw()

func begin_attack(kind: String):
	attack = kind
	windup = GameState.config.weapons[kind].windup
	cooldown = GameState.config.weapons[kind].cooldown

func hurt(damage: float, direction: int):
	var c = GameState.config
	position.x = clampf(position.x + direction * c.player.knockback, c.world.reef, c.world.width - c.world.reef)
	shake = 0.18
	if invincible > 0: return
	GameState.hp -= damage * (1 - GameState.armor * c.player.armor_reduction)
	invincible = c.player.invincible
	GameState.changed.emit()
	if GameState.hp <= 0: game.die()

func _draw():
	var v = GameState.config.visuals
	var t = floor(animation_time * 10) / 10.0
	var bob = round(sin(t * TAU * v.idle_rate) * v.boat_bob)
	var rock = sin(t * 2.3) * v.boat_roll
	var jitter = round(randf_range(-2, 2)) if shake > 0 else 0.0
	# Mirrored silhouette is broken up by wave highlights below the hull.
	draw_set_transform(Vector2(jitter + sin(t * 2) * 2, 24 - bob * 0.4), -rock, Vector2(1, -0.42))
	paint_boat(t, Color(0.42, 0.57, 0.69, 0.25))
	draw_set_transform(Vector2(jitter, bob), rock)
	paint_boat(t, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	for i in range(7):
		var x = fposmod(i * 13 - t * (28 if rowing else 8), 82) - 41
		draw_rect(Rect2(round(x), 14 + i % 3 * 3, 5 + i % 2 * 5, 1), Color(0.72, 0.87, 0.81, 0.3))
	if rowing and sin(t * TAU * v.row_rate) > 0.55:
		for i in range(4):
			draw_rect(Rect2(-facing * (20 + i * 3), 8 - i % 2 * 3, 2, 2), Color("c7e1d5"))

func paint_boat(t: float, tint: Color):
	var flash = invincible > 0 and int(invincible * 20) % 2 == 0
	var dark = Color("322a32") * tint
	var wood = (Color.WHITE if flash else Color("936548")) * tint
	# Curved plank silhouette, end caps, lashings and individual grain pixels.
	draw_colored_polygon(PackedVector2Array([Vector2(-33, -1), Vector2(-25, 10), Vector2(23, 10), Vector2(34, -1), Vector2(24, 4), Vector2(-24, 4)]), dark)
	for i in range(5):
		var x = -25 + i * 11
		draw_rect(Rect2(x, -2, 10, 7), wood)
		draw_rect(Rect2(x + 1, -2, 8, 1), Color("c39360") * tint)
		draw_line(Vector2(x + 2, 2), Vector2(x + 7, 2), Color("614737") * tint)
	for x in [-19, 17]:
		draw_rect(Rect2(x, -3, 2, 9), Color("c4ac7c") * tint)
	# Supply roll and a small warm lantern distinguish this traveller.
	draw_rect(Rect2(-22, -10, 11, 8), Color("5b7271") * tint)
	draw_rect(Rect2(-20, -10, 2, 8), Color("baa579") * tint)
	var flame = int(t * 9) % 3
	draw_rect(Rect2(23, -13, 1, 12), dark)
	draw_rect(Rect2(20, -10, 6, 7), Color("b28852") * tint)
	draw_rect(Rect2(22, -9, 2, 4 + flame % 2), Color("ffe1a1") * tint)
	# Rowing shoulders lean with the oar's power stroke; cloak flutters independently.
	var stroke = sin(t * TAU * GameState.config.visuals.row_rate) if rowing else sin(t * 2) * 0.12
	var lean = round(stroke * 2) * facing
	var basis = Transform2D(0, Vector2(facing, 1), 0, Vector2(lean, 0))
	var current_bob = round(sin(t * TAU * GameState.config.visuals.idle_rate) * GameState.config.visuals.boat_bob)
	var current_rock = sin(t * 2.3) * GameState.config.visuals.boat_roll
	var base = Transform2D(current_rock, Vector2(0, current_bob))
	if tint.a < 1: base = Transform2D(-current_rock, Vector2(1, -0.42), 0, Vector2(sin(t * 2) * 2, 24 - current_bob * 0.4))
	draw_set_transform_matrix(base * basis)
	var cape = round(sin(t * 5) * (3 if rowing else 1))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -31), Vector2(4, -30), Vector2(5, -12), Vector2(-12 + cape, -8), Vector2(-9, -22)]), Color("283a52") * tint)
	draw_rect(Rect2(-5, -27, 9, 15), (Color.WHITE if flash else Color("647879")) * tint)
	draw_rect(Rect2(-5, -14, 10, 3), Color("bd9a64") * tint)
	draw_rect(Rect2(-4, -11, 3, 8), dark)
	draw_rect(Rect2(2, -11, 3, 8), dark)
	draw_rect(Rect2(-4, -5, 5, 2), Color("725245") * tint)
	draw_rect(Rect2(2, -5, 6, 2), Color("725245") * tint)
	draw_rect(Rect2(-5, -40, 10, 12), Color("3b3944") * tint)
	draw_rect(Rect2(0, -37, 6, 8), Color("d6b287") * tint)
	draw_rect(Rect2(4, -35, 2, 2), dark)
	draw_rect(Rect2(-7, -42, 12, 5), Color("4e6170") * tint)
	draw_rect(Rect2(-3, -43, 9, 2), Color("82918b") * tint)
	var hand = Vector2(8 + round(stroke * 5), -19 + round(stroke * 3))
	if windup > 0 or slash_time > 0:
		if attack == "bow":
			var pull = windup / GameState.config.weapons.bow.windup
			hand = Vector2(13, -25)
			draw_arc(Vector2(16, -25), 10, -1.25, 1.25, 7, Color("ba9767") * tint, 2)
			draw_polyline(PackedVector2Array([Vector2(19, -34), Vector2(11 - pull * 7, -25), Vector2(19, -16)]), Color("e0cda0") * tint, 1)
			draw_line(Vector2(2, -25), Vector2(25, -25), Color("cfb880") * tint, 1)
		else:
			var angle = -1.5 + (1 - slash_time / 0.22) * 2.5
			hand = Vector2(9, -23)
			var tip = hand + Vector2(cos(angle), sin(angle)) * 22
			draw_line(hand, tip, Color("e0e6cb") * tint, 3)
			if slash_time > 0: draw_arc(Vector2(4, -20), 27, -1.2, angle, 9, Color(0.94, 0.95, 0.72, slash_time / 0.22) * tint, 2)
	else:
		var blade = Vector2(-17 + round(stroke * 15), 12 + round(cos(t * TAU * GameState.config.visuals.row_rate) * 3))
		draw_line(hand, blade, Color("ae8d60") * tint, 2)
		draw_line(blade - Vector2(2, 2), blade + Vector2(3, 6), Color("694e3d") * tint, 4)
	draw_line(Vector2(2, -26), hand, Color("536c70") * tint, 4)
	draw_rect(Rect2(hand - Vector2(1, 1), Vector2(3, 3)), Color("d6b287") * tint)
	draw_set_transform(Vector2.ZERO)

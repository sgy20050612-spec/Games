extends CharacterBody2D
var kind = "small"
var hp: float
var special = false
var flash = 0.0
var cooldown = 0.0
var game: Node
var animation_time = 0.0
var attack_time = -1.0
var struck = false
var direction = 1
var dying = 0.0

func _ready():
	game = get_parent().get_parent()
	hp = GameState.config.enemies[kind].hp

func _physics_process(dt):
	if not game.active(): return
	animation_time += dt
	if hp <= 0:
		dying += dt
		if dying >= 0.4: queue_free()
		queue_redraw()
		return
	var c = GameState.config.enemies[kind]
	var v = GameState.config.visuals
	var dir = signf(game.boat.position.x - position.x)
	if dir != 0: direction = int(dir)
	cooldown -= dt
	flash = maxf(0, flash - dt)
	if attack_time >= 0:
		attack_time += dt
		if not struck and attack_time >= v.enemy_anticipation:
			struck = true
			if absf(game.boat.position.x - position.x) < GameState.config.world.contact_radius:
				game.boat.hurt(c.damage, direction)
		if attack_time >= v.enemy_anticipation + v.enemy_strike + v.enemy_recover: attack_time = -1
	else:
		position.x += dir * c.speed * dt
		if absf(game.boat.position.x - position.x) < GameState.config.world.contact_radius and cooldown <= 0:
			attack_time = 0
			struck = false
			cooldown = c.cooldown
	queue_redraw()

func hit(damage: float, dir: int):
	if hp <= 0: return
	hp -= damage
	position.x += dir * GameState.config.world.enemy_knockback
	flash = 0.12
	game.spark(position)
	if hp <= 0:
		game.enemy_died(self)
		dying = 0

func _draw():
	var t = floor(animation_time * 10) / 10.0
	var big = kind == "large"
	var size = 1.45 if big else 1.0
	var bob = round(sin(t * TAU * GameState.config.visuals.enemy_swim_rate) * 1.6)
	var lunge = 0.0
	var arm = -1.0
	if attack_time >= 0:
		var v = GameState.config.visuals
		if attack_time < v.enemy_anticipation:
			var amount = attack_time / v.enemy_anticipation
			lunge = -amount * 5
			arm = -1 - amount * 1.6
		else:
			var amount = clampf((attack_time - v.enemy_anticipation) / v.enemy_strike, 0, 1)
			lunge = sin(amount * PI) * 12
			arm = -2.6 + amount * 3.5
	var fade = clampf(1 - dying / 0.4, 0, 1)
	var tint = Color(1, 1, 1, fade)
	draw_set_transform(Vector2(direction * lunge, bob + dying * 16), 0, Vector2(direction * size, size))
	paint_creature(t, arm, tint)
	draw_set_transform(Vector2(direction * lunge + sin(t * 2) * 2, 17 - bob * 0.4), 0, Vector2(direction * size, -size * 0.4))
	paint_creature(t, arm, Color(0.44, 0.54, 0.7, fade * 0.24))
	draw_set_transform(Vector2.ZERO)
	for i in range(4):
		var x = fposmod(i * 11 - t * 20, 44) - 22
		draw_rect(Rect2(round(x), 5 + i % 2 * 2, 7, 1), Color(0.63, 0.77, 0.8, 0.4 * fade))

func paint_creature(t: float, arm: float, tint: Color):
	var dark = Color("202339") * tint
	var body = (Color.WHITE if flash > 0 else Color("62576e") if kind == "large" else Color("476878")) * tint
	var highlight = (Color.WHITE if flash > 0 else Color("9a8292") if kind == "large" else Color("789690")) * tint
	var stride = round(sin(t * 8) * 3)
	# Hunched amphibious silhouettes with articulated legs, webbed claws and tail.
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -13), Vector2(-20, -5 + stride), Vector2(-27, -8), Vector2(-20, 0), Vector2(-7, -3)]), dark)
	for offset in [-4, 4]:
		draw_line(Vector2(offset, -9), Vector2(offset + stride, -2), dark, 5)
		draw_line(Vector2(offset + stride, -2), Vector2(offset + stride + 7, 0), body, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -10), Vector2(-12, -23), Vector2(-5, -29), Vector2(6, -25), Vector2(10, -12), Vector2(5, -5), Vector2(-9, -5)]), dark)
	draw_rect(Rect2(-10, -22, 15, 15), body)
	draw_rect(Rect2(-8, -22, 4, 10), highlight)
	draw_rect(Rect2(-4, -31, 15, 13), body)
	draw_rect(Rect2(3, -25, 11, 6), dark)
	draw_rect(Rect2(6, -24, 7, 2), Color("b3b4a0") * tint)
	draw_rect(Rect2(4, -29, 4, 2), Color("ffc77b") * tint)
	for i in range(3):
		draw_colored_polygon(PackedVector2Array([Vector2(-11 + i * 4, -21 - i * 2), Vector2(-16 + i * 4, -28 - i * 2), Vector2(-6 + i * 4, -23 - i * 2)]), highlight)
	var elbow = Vector2(2, -21) + Vector2(cos(arm), sin(arm)) * 11
	var claw = elbow + Vector2(cos(arm + 0.8), sin(arm + 0.8)) * 11
	draw_line(Vector2(2, -21), elbow.round(), body, 5)
	draw_line(elbow.round(), claw.round(), highlight, 3)
	for i in range(3): draw_line(claw.round() + Vector2(0, i * 2), claw.round() + Vector2(5, i * 2 - 2), Color("d8c6a2") * tint, 1)
	if special:
		draw_arc(Vector2(1, -25), 14, PI, TAU, 7, Color("f6cb70") * tint, 1)
		for i in range(3):
			var glint = Vector2(cos(t * 2 + i * 2.1), sin(t * 2 + i * 2.1)) * 18 + Vector2(0, -22)
			draw_rect(Rect2(glint.round(), Vector2(2, 2)), Color("ffe5a6") * tint)

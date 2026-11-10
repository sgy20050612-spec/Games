extends Area2D
var direction = 1
var travelled = 0.0
var game: Node
func _ready(): game = get_parent().get_parent()
func _physics_process(dt):
	if not game.active(): return
	var c = GameState.config.weapons.bow
	var step = c.speed * dt
	var before = position.x
	position.x += direction * step
	travelled += step
	for enemy in game.enemies.get_children():
		if enemy.hp > 0 and enemy.position.x >= minf(before, position.x) - 12 and enemy.position.x <= maxf(before, position.x) + 12:
			enemy.hit(c.damage + GameState.bonus, direction)
			queue_free()
			return
	if travelled >= c.range: queue_free()
	queue_redraw()
func _draw():
	draw_line(Vector2(-8 * direction, -14), Vector2(8 * direction, -14), Color("ffe7a0"), 2)

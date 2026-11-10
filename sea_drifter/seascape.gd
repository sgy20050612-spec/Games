extends Node2D
## Original procedural pixel scenery: stepped silhouettes, parallax and broken reflections.
var game: Node
var colors: Array[Color] = []
var sunlight = 0.25
var sun_progress = 0.0
var time = 0.0
var tint = Color.WHITE

func _ready():
	game = get_parent()
	for value in GameState.config.visuals.palettes.dawn: colors.append(Color(value))

func palette(name: String) -> Array[Color]:
	var output: Array[Color] = []
	for value in GameState.config.visuals.palettes[name]: output.append(Color(value))
	return output

func blend(a: String, b: String, amount: float) -> Array[Color]:
	var left = palette(a)
	var right = palette(b)
	for i in range(left.size()): left[i] = left[i].lerp(right[i], smoothstep(0, 1, amount))
	return left

func _process(dt):
	if not is_instance_valid(game.boat): return
	if game.active(): time += dt
	var target = palette("dawn")
	var light = 0.35
	var progress = 0.03
	match game.phase:
		"DAY":
			var fraction = clampf(game.elapsed / GameState.config.phases.day, 0, 1)
			target = blend("dawn", "noon", fraction / 0.45) if fraction < 0.45 else blend("noon", "sunset", (fraction - 0.45) / 0.55)
			light = lerpf(0.35, 1.0, sin(fraction * PI))
			progress = lerpf(0.03, 0.97, fraction)
		"DUSK":
			var fraction = clampf(game.elapsed / GameState.config.phases.dusk, 0, 1)
			target = blend("sunset", "night", fraction)
			light = lerpf(0.35, 0, fraction)
			progress = 1.0
		"NIGHT":
			target = palette("night")
			light = 0
			progress = 1.08
		"DAWN":
			var fraction = clampf(game.elapsed / GameState.config.phases.dawn, 0, 1)
			target = blend("night", "dawn", fraction)
			light = fraction * 0.35
			progress = 0.03
		"SAIL":
			target = palette("dawn")
			light = 0.4
			progress = 0.12
		"RESULT": return
	# A short lighting easing bridges early-cleared nights and short dawn stages.
	var ease = 1.0 - exp(-GameState.config.visuals.palette_smoothing * dt)
	for i in range(colors.size()): colors[i] = colors[i].lerp(target[i], ease)
	sunlight = lerpf(sunlight, light, ease)
	sun_progress = lerpf(sun_progress, progress, ease)
	tint = Color("8794b5").lerp(Color.WHITE, sunlight)
	game.boat.modulate = tint
	for enemy in game.enemies.get_children(): enemy.modulate = tint
	queue_redraw()

func ridge(x: float, layer: int) -> float:
	return floor((sin(x * 0.007 + layer * 2.0) * 24 + sin(x * 0.019 + layer) * 12 + sin(x * 0.037) * 5) / 3) * 3

func tree(x: float, y: float, height: float, color: Color, reflection: bool = false):
	var side = -1.0 if reflection else 1.0
	draw_rect(Rect2(x - 1, minf(y, y - height * side), 3, height), color)
	for i in range(5):
		var width = (i + 1) * height * 0.115
		var top = y - (height - i * height * 0.16) * side
		var bottom = top + height * 0.35 * side
		draw_colored_polygon(PackedVector2Array([Vector2(x, top).round(), Vector2(x - width, bottom).round(), Vector2(x + width, bottom).round()]), color)

func _draw():
	if colors.is_empty() or not is_instance_valid(game.boat): return
	var w = float(GameState.config.world.width)
	var water = float(GameState.config.world.water_y)
	var center = clampf(game.boat.position.x, 320, w - 320)
	var left = floor(center - 320)
	# Render only the visible width in world coordinates; distant layers move slower.
	for y in range(0, int(water), 3):
		var ratio = float(y) / water
		var col = colors[0].lerp(colors[1], minf(ratio * 1.6, 1.0)).lerp(colors[2], pow(ratio, 4))
		draw_rect(Rect2(left - 4, y, 648, 3), col)
	var night = 1 - sunlight
	for i in range(48):
		var sx = left + fposmod(i * 83.7 - center * 0.06, 640)
		var sy = 18 + fmod(i * 31.7, 115)
		var alpha = clampf((night - 0.45) * 2, 0, 1) * (0.65 + sin(time + i) * 0.25)
		draw_rect(Rect2(floor(sx), floor(sy), 1 if i % 3 else 2, 1), Color(0.9, 0.88, 0.76, alpha))
	var sun_x = left + lerpf(80, 560, sun_progress)
	var sun_y = water - 91 - sin(clampf(sun_progress, 0, 1) * PI) * 112
	if sunlight > 0.04 and sun_progress <= 1.03:
		for y in range(-16, 17, 2):
			var span = floor(sqrt(maxf(0, 256 - y * y)))
			draw_rect(Rect2(floor(sun_x - span), floor(sun_y + y), span * 2, 2), colors[7])
	if night > 0.85:
		var moon = Vector2(left + 470, 60)
		draw_circle(moon, 11, Color(colors[7], (night - 0.85) * 6))
		draw_circle(moon + Vector2(5, -3), 9, colors[0])
	# Clouds use stepped rectangles, with no smooth bitmap filtering.
	for i in range(7):
		var cx = left + fposmod(i * 137 - center * 0.10 + time * 1.3, 820) - 90
		var cy = 48 + fmod(i * 29, 80)
		var cloud = Color(colors[2].lerp(colors[1], 0.4), 0.27)
		draw_rect(Rect2(floor(cx), cy, 74, 5), cloud)
		draw_rect(Rect2(floor(cx + 15), cy - 4, 36, 4), cloud)
	for layer in range(3):
		var parallax = [0.12, 0.24, 0.42][layer]
		var col = colors[3].lerp(colors[4], layer / 2.0)
		var points = PackedVector2Array([Vector2(left - 8, water)])
		for sx in range(-8, 649, 8):
			var world_x = sx + center * parallax
			points.append(Vector2(left + sx, minf(water - 3, 180 + layer * 16 + ridge(world_x, layer))))
		points.append(Vector2(left + 648, water))
		draw_colored_polygon(points, col)
		if layer > 0:
			for i in range(-2, 26):
				var tx = i * 32 - fposmod(center * parallax, 32)
				var wx = tx + center * parallax
				var ty = minf(water - 3, 180 + layer * 16 + ridge(wx, layer))
				tree(left + tx, ty, 19 + fposmod(wx * 0.31, 37), col)
	# Water base, reflected skyline and trees.
	draw_rect(Rect2(left - 4, water, 648, 360 - water), colors[5])
	for band in range(0, 120, 3):
		var depth = band / 120.0
		var col = colors[1].lerp(colors[5], depth * 0.75)
		draw_rect(Rect2(left - 4, water + band, 648, 3), Color(col, 0.35 * (1 - depth)))
	for i in range(-2, 26):
		var tx = i * 32 - fposmod(center * 0.42, 32)
		var wx = tx + center * 0.42
		var reflected = colors[4].lerp(colors[5], 0.35)
		tree(left + tx + sin(time * 1.1 + i) * 2, water + 2, 12 + fposmod(wx * 0.31, 33), reflected, true)
	for i in range(int(GameState.config.visuals.water_bands)):
		var depth = float(i) / GameState.config.visuals.water_bands
		var y = water + 2 + depth * depth * 115
		var drift = time * GameState.config.visuals.water_speed * (0.3 + depth)
		for j in range(8):
			var x = left + fposmod(j * 91 + i * 37 + drift * (-1 if i % 2 else 1), 700) - 30
			var width = 6 + fmod(i * 7 + j * 11, 38)
			draw_rect(Rect2(floor(x), floor(y), width, 1 if i % 3 else 2), Color(colors[6], 0.12 + fmod(i * 0.07, 0.22)))
	if sunlight > 0.1:
		for i in range(21):
			var spread = 7 + i * 2.8
			var x = sun_x + sin(time * 1.6 + i * 1.7) * spread * 0.3
			draw_rect(Rect2(floor(x - spread / 2), water + i * 5, spread, 2), Color(colors[7], 0.08 + sunlight * 0.11))
	for edge in [0.0, w - GameState.config.world.reef]:
		for i in range(5):
			var x = edge + i * 17
			draw_colored_polygon(PackedVector2Array([Vector2(x, water + 16), Vector2(x + 6, water - 8 - i % 3 * 9), Vector2(x + 17, water - 3), Vector2(x + 24, water + 17)]), colors[4].darkened(0.35))
	# Lamp-bearing lighthouse remains world anchored at the destination.
	if game.phase in ["SAIL", "RESULT"]:
		var x = float(GameState.config.world.lighthouse_x)
		draw_rect(Rect2(x - 4, water - 94, 29, 94), Color("b5b09a") * tint)
		for y in range(0, 5): draw_rect(Rect2(x - 4, water - y * 18, 29, 3), Color("666d70") * tint)
		draw_rect(Rect2(x - 7, water - 100, 35, 10), Color("e8c274"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 10, water - 100), Vector2(x + 10, water - 117), Vector2(x + 31, water - 100)]), Color("453746"))

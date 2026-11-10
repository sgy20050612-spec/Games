extends Node2D
signal population_changed(count: int)
var boat: CharacterBody2D
var enemies: Node2D
var loot: Node2D
var projectiles: Node2D
var phase = "DAY"
var elapsed = 0.0
var clock = 0.0
var wave_index = 0
var alive = 0
var next_wave = 0.0
var wood_count = 0
var plastic_count = 0
var next_wood: float
var next_plastic: float
var blueprint_index = 0
var spawned = 0
var inventory = false
var paused = false
var message = "向灯塔前进。A/D 移动，J 射箭"
var message_time = 5.0
var death_time = -1.0
var kills = 0
var particles: Array = []
var result_layer: CanvasLayer

func _ready():
	randomize()
	GameState.reset()
	var scenery = Node2D.new()
	scenery.set_script(preload("res://seascape.gd"))
	scenery.name = "Seascape"
	scenery.z_index = -10
	add_child(scenery)
	for container in ["Enemies", "Loot", "Projectiles"]:
		var node = Node2D.new()
		node.name = container
		add_child(node)
	enemies = $Enemies
	loot = $Loot
	projectiles = $Projectiles
	boat = preload("res://boat.tscn").instantiate()
	boat.position = Vector2(GameState.config.world.start_x, GameState.config.world.water_y)
	add_child(boat)
	add_child(preload("res://hud.tscn").instantiate())
	result_layer = preload("res://result.tscn").instantiate()
	add_child(result_layer)
	for sound in ["BowSound", "HitSound", "BlueprintSound", "WaterSound"]:
		var player = AudioStreamPlayer.new()
		player.name = sound
		add_child(player)
	population_changed.connect(check_clear)
	start_day()

func active() -> bool:
	return not paused and not inventory and phase != "RESULT" and death_time < 0

func note(text: String):
	message = text
	message_time = 2.0

func start_day():
	phase = "DAY"
	elapsed = 0
	wood_count = 0
	plastic_count = 0
	next_wood = GameState.config.resources.wood_interval
	next_plastic = GameState.config.resources.plastic_interval - GameState.config.resources.plastic_offset

func _unhandled_key_input(event):
	if not event.pressed or event.echo: return
	if phase == "RESULT":
		if event.physical_keycode == KEY_ENTER: get_tree().reload_current_scene()
		return
	if event.physical_keycode == KEY_ESCAPE:
		if inventory: inventory = false
		else: paused = not paused
	if event.physical_keycode == KEY_TAB and not paused: inventory = not inventory
	if paused and event.physical_keycode == KEY_R: get_tree().reload_current_scene()
	if inventory and not paused:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
			note(GameState.consume(event.physical_keycode - KEY_1))
		var selected = GameState.selected_slot
		match event.physical_keycode:
			KEY_LEFT, KEY_A: selected = selected / 3 * 3 + (selected % 3 + 2) % 3
			KEY_RIGHT, KEY_D: selected = selected / 3 * 3 + (selected % 3 + 1) % 3
			KEY_UP, KEY_W, KEY_DOWN, KEY_S: selected = (selected + 3) % int(GameState.config.player.slots)
			KEY_E, KEY_ENTER: note(GameState.consume(selected))
		GameState.selected_slot = selected
		if event.physical_keycode == KEY_B: note(GameState.craft(true))
		if event.physical_keycode == KEY_N: note(GameState.craft(false))

func _process(dt):
	if active(): clock += dt
	message_time = maxf(0, message_time - dt)
	if death_time >= 0:
		death_time -= dt
		if death_time <= 0: finish(false)
	if active():
		GameState.fulfill_reward()
		elapsed += dt
		match phase:
			"DAY":
				if elapsed >= next_wood and wood_count < GameState.config.resources.wood_count:
					spawn_resource("wood")
					wood_count += 1
					next_wood += GameState.config.resources.wood_interval
				if elapsed >= next_plastic and plastic_count < GameState.config.resources.plastic_count:
					spawn_resource("plastic")
					plastic_count += 1
					next_plastic += GameState.config.resources.plastic_interval
				if elapsed >= GameState.config.phases.day:
					phase = "DUSK"
					elapsed = 0
					note("今晚从两侧来  ◀    ▶")
			"DUSK":
				if elapsed >= GameState.config.phases.dusk: start_night()
			"NIGHT":
				if wave_index < GameState.config.waves[GameState.day - 1].size() and elapsed >= next_wave: spawn_wave()
				if elapsed >= GameState.config.phases.night:
					for enemy in enemies.get_children(): enemy.queue_free()
					alive = 0
					wave_index = GameState.config.waves[GameState.day - 1].size()
					population_changed.emit(alive)
			"DAWN":
				if elapsed >= GameState.config.phases.dawn:
					if GameState.day == GameState.config.waves.size():
						phase = "SAIL"
						note("灯塔在右侧！驶向灯光")
					else:
						GameState.day += 1
						start_day()
			"SAIL":
				if boat.position.x >= GameState.config.world.lighthouse_x: finish(true)
		for particle in particles: particle.life -= dt
		particles = particles.filter(func(p): return p.life > 0)
	queue_redraw()

func start_night():
	phase = "NIGHT"
	elapsed = 0
	wave_index = 0
	spawned = 0
	next_wave = 0
	var total = 0
	for wave in GameState.config.waves[0]: total += int(wave.get("small", 0))
	blueprint_index = randi_range(0, total - 1) if GameState.day == 1 else -1
	spawn_wave()

func spawn_wave():
	var wave = GameState.config.waves[GameState.day - 1][wave_index]
	var left = wave_index % 2 == 0
	var offset = 0
	for kind in ["small", "large"]:
		for index in range(int(wave.get(kind, 0))):
			var enemy = preload("res://enemy.tscn").instantiate()
			enemy.kind = kind
			enemy.special = spawned == blueprint_index
			enemy.position = Vector2(-offset if left else GameState.config.world.width + offset, GameState.config.world.water_y)
			enemies.add_child(enemy)
			offset += GameState.config.world.wave_spacing
			spawned += 1
			alive += 1
	wave_index += 1
	next_wave += GameState.config.world.wave_gap
	population_changed.emit(alive)

func check_clear(count: int):
	# Only resolve after the final scheduled wave, so zero between waves does not skip them.
	if phase == "NIGHT" and count == 0 and wave_index >= GameState.config.waves[GameState.day - 1].size():
		if GameState.day == 1 and not GameState.blueprint_claimed:
			var on_water = false
			for item in loot.get_children():
				if item.kind == "blueprint": on_water = true
			if not on_water: GameState.defer_blueprint()
		GameState.armor = 0
		phase = "DAWN"
		elapsed = 0
		note("黎明：护甲清空，今晚击退 %d 只" % kills)

func spawn_resource(kind: String):
	if kind == "wood" and GameState.max_hp >= GameState.config.player.hp_cap: kind = "plastic"
	elif kind == "plastic" and GameState.bonus >= GameState.config.player.attack_cap: kind = "wood"
	if GameState.max_hp >= GameState.config.player.hp_cap and GameState.bonus >= GameState.config.player.attack_cap: return
	drop(kind, randf_range(GameState.config.world.reef, GameState.config.world.width - GameState.config.world.reef))

func drop(kind: String, x: float):
	var item = preload("res://loot.tscn").instantiate()
	item.kind = kind
	item.position = Vector2(x, GameState.config.world.water_y)
	loot.add_child(item)

func enemy_died(enemy):
	kills += 1
	if enemy.special: drop("blueprint", enemy.position.x)
	else: drop("wood" if randf() < GameState.config.resources.wood_drop_chance else "stone", enemy.position.x)
	alive -= 1
	population_changed.emit(alive)

func strike(kind: String):
	if kind == "bow":
		var arrow = preload("res://arrow.tscn").instantiate()
		arrow.position = boat.position
		arrow.direction = boat.facing
		projectiles.add_child(arrow)
	else:
		for enemy in enemies.get_children():
			var delta = enemy.position.x - boat.position.x
			if delta * boat.facing >= 0 and absf(delta) <= GameState.config.weapons.knife.range:
				enemy.hit(GameState.config.weapons.knife.damage + GameState.bonus, boat.facing)

func spark(pos: Vector2): particles.append({"pos": pos + Vector2(0, -16), "life": 0.2})
func die(): death_time = GameState.config.world.death_freeze
func finish(won: bool):
	phase = "RESULT"
	death_time = -1
	result_layer.show_result(won, kills)

func _draw():
	for particle in particles:
		var t = particle.life / 0.2
		for i in range(4):
			var delta = Vector2(cos(i * 1.6), sin(i * 1.6)) * (1 - t) * 12
			draw_rect(Rect2((particle.pos + delta).round(), Vector2(2, 2)), Color(1, 0.88, 0.6, t))

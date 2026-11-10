extends SceneTree
func _initialize(): call_deferred("run")

func grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.boat.set_physics_process(false)
	game.get_node("Hud").preview = true
	game.message_time = 0
	game.paused = true
	var scenery = game.get_node("Seascape")
	scenery.set_process(false)
	game.phase = "DAY"
	game.elapsed = 59
	for i in range(30): scenery._process(0.1)
	var previous = scenery.colors[0]
	game.phase = "DUSK"
	for i in range(180):
		game.elapsed = i / 60.0
		scenery._process(1.0 / 60)
		assert(absf(scenery.colors[0].r - previous.r) < 0.03)
		previous = scenery.colors[0]
	game.boat.rowing = true
	game.boat.animation_time = 0.0
	game.boat.queue_redraw()
	var rowing_a = await grab()
	game.boat.animation_time = 0.3
	game.boat.queue_redraw()
	var rowing_b = await grab()
	assert(rowing_a.get_data() != rowing_b.get_data())
	game.start_night()
	var enemy = game.enemies.get_child(0)
	enemy.set_physics_process(false)
	enemy.position.x = game.boat.position.x + 10
	game.paused = false
	enemy._physics_process(0.01)
	assert(enemy.attack_time >= 0)
	var state = root.get_node("GameState")
	var before = state.hp
	enemy._physics_process(0.12)
	assert(state.hp == before)
	var anticipation = await grab()
	enemy._physics_process(0.13)
	assert(state.hp < before)
	var after = state.hp
	enemy._physics_process(0.1)
	assert(state.hp == after)
	var strike = await grab()
	assert(anticipation.get_data() != strike.get_data())
	game.paused = true
	scenery.time = 0
	scenery.queue_redraw()
	var water_a = await grab()
	scenery.time = 1.0
	scenery.queue_redraw()
	var water_b = await grab()
	assert(water_a.get_data() != water_b.get_data())
	print("PASS: real rowing frames, water frames, monster anticipation/strike frames, damage once after anticipation, continuous dusk lighting")
	quit()

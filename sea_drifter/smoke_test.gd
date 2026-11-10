extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var state = root.get_node("GameState")
	state.add_item("wood", 3)
	state.craft(true)
	assert(state.armor == 1 and state.used_slots() == 0)
	state.add_item("wood", 3)
	state.add_item("blueprint")
	assert(not state.knife)
	state.craft(false)
	assert(state.knife)
	for day in [1, 2]:
		state.day = day
		game.start_night()
		var count = 0
		for wave in range(state.config.waves[day - 1].size()):
			if wave > 0: game.spawn_wave()
			for enemy in game.enemies.get_children():
				if enemy.hp > 0:
					count += 1
					enemy.hit(1000, 1)
			await process_frame
		assert(count == (8 if day == 1 else 12))
		assert(game.phase == "DAWN" and game.alive == 0)
		assert(state.armor == 0)
	game._process(state.config.phases.dawn + 0.01)
	assert(game.phase == "SAIL")
	game.boat.position.x = state.config.world.lighthouse_x
	game._process(0.01)
	assert(game.phase == "RESULT")
	game.phase = "DAY"
	game.boat.invincible = 0
	game.boat.hurt(1000, 1)
	game._process(state.config.world.death_freeze + 0.01)
	assert(game.phase == "RESULT" and state.hp <= 0)
	print("PASS: crafting, both wave totals, immediate clear, dawn armor reset, lighthouse victory and death result")
	quit()

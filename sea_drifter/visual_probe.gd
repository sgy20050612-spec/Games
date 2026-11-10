extends SceneTree
## Render our own scene to PNGs; no third-party artwork or screen scraping.
func _initialize(): call_deferred("capture")
func capture():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.paused = true
	game.get_node("Hud").preview = true
	var directory = OS.get_environment("SEA_CAPTURE_DIR")
	if directory.is_empty(): directory = "user://visual_previews"
	DirAccess.make_dir_recursive_absolute(directory)
	var scenery = game.get_node("Seascape")
	var cases = [["sunrise", "DAY", 1.0], ["noon", "DAY", 27.0], ["sunset", "DAY", 59.0], ["night_attack", "NIGHT", 10.0]]
	for sample in cases:
		game.phase = sample[1]
		game.elapsed = sample[2]
		game.boat.animation_time = 1.15
		game.boat.rowing = true
		game.boat.queue_redraw()
		if sample[0] == "night_attack":
			game.spawn_wave()
			var index = 0
			for enemy in game.enemies.get_children():
				enemy.position.x = game.boat.position.x + 50 + index * 50
				enemy.attack_time = 0.31
				enemy.direction = -1
				enemy.queue_redraw()
				index += 1
		for i in range(15): scenery._process(0.2)
		scenery.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join(sample[0] + ".png"))
	print("PASS: rendered sunrise, noon, sunset and enemy attack to ", directory)
	quit()

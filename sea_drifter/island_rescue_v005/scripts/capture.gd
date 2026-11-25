extends SceneTree
var game

func _initialize():call_deferred("capture")

func shot(name):
	for k in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/"+name+".png")

func capture():
	root.size=Vector2i(1152,648)
	DirAccess.make_dir_recursive_absolute("res://previews")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await shot("01-main")
	game.g.start()
	game.menu=""
	await shot("02-world")
	game.g.day=3
	game.g.story.artisan=true
	game.g.story.settlers=true
	game.g.research=12
	game.g.tech=2
	game.g.resident_tree=3
	for w in game.g.worlds:w.s.status="OWNED"
	for i in range(3):
		game.g.worlds[i].add_building("house",Vector2i(4,6),true)
		for role in ["BUILD","GATHER","MELEE","RANGED"]:game.g.add_resident(role,i)
	for k in range(5):game.g.add_resident("UNEMPLOYED")
	game.menu="dispatch"
	await shot("03-dispatch")
	game.detail={"island":0,"column":1}
	await shot("04-facilities")
	game.detail=null
	game.menu="tree"
	await shot("05-tree")
	game.menu="map"
	await shot("06-map")
	game.menu=""
	game.g.phase="NIGHT"
	game.g.remaining=80
	game.g.current().begin_night(5,0)
	await shot("07-night")
	game.queue_free()
	await process_frame
	quit()

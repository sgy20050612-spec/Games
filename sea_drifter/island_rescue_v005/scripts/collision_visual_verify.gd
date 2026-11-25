extends SceneTree
func _initialize():OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func capture(game,path):
	game.queue_redraw()
	for k in range(3):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	root.size=Vector2i(1152,648)
	var game=load("res://scripts/game.gd").new();root.add_child(game);game.set_process(false);game.g.start();game.menu="";game.clock=.15
	var g=game.g;var w=g.current();g.resources=[100.0,100.0,0.0,20.0]
	var a=w.add_building("wall",Vector2i(17,18),false);a.batch=true
	var b=w.add_building("wall",Vector2i(17,19),false);b.batch=true
	var worker=g.add_resident("BUILD",0);worker.pos=Vector2(500,600);w.assign_builder(a,worker)
	g.player.pos=Vector2(590,650)
	for i in range(300):
		g.tick(.05)
		if worker.working and a.progress>a.duration*.3:break
	await capture(game,"res://previews/collision-builder-working.png")
	for i in range(600):g.tick(.05)
	await capture(game,"res://previews/collision-builder-finished.png")
	var okay=a.progress>=a.duration and b.progress>=b.duration and not w.worker_blocked(worker.pos)
	print(JSON.stringify({"visual_construction_finished":okay,"worker":str(worker.pos),"first_progress":a.progress,"second_progress":b.progress}))
	game.queue_free();await process_frame;await process_frame;await create_timer(.15).timeout;quit(0 if okay else 1)

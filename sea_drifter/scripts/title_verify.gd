extends SceneTree
var game
var failures=[]
var checks=0
func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func check(value,name):
	checks+=1
	if not value:failures.append(name);push_error(name)
func render():
	game.queue_redraw()
	for k in range(3):await process_frame
	await RenderingServer.frame_post_draw
func action(tag):
	var found=game.ui_buttons.filter(func(b):return b.get("tag","")==tag)
	check(found.size()==1,"title action exists "+tag)
	if not found.is_empty():found[0].action.call()
func run():
	root.size=Vector2i(1152,648)
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false)
	game.title_screen.time=.15;await render()
	var first=root.get_texture().get_image()
	game.title_screen.time=2;await render()
	var settled=root.get_texture().get_image()
	settled.save_png("res://previews/24-animated-title.png")
	var changed=0
	for x in range(0,1152,12):
		for y in range(0,648,12):
			if first.get_pixel(x,y)!=settled.get_pixel(x,y):changed+=1
	check(changed>200,"intro animates title and descending signs")
	check(game.g.elapsed==0 and game.g.phase=="MENU","title animation never advances game clock")
	check(game.ui_buttons.size()==4,"four separate menu actions")
	action("title_load");await render()
	check(game.menu=="title_load","load opens save selection")
	var available_slots=0
	for i in range(10):
		if FileAccess.file_exists("user://island_slot_%d.json"%i):available_slots+=1
	check(game.ui_buttons.size()==available_slots+1,"only existing saves and return are clickable")
	game.menu="main";await render();action("title_settings");await render()
	check(game.menu=="title_settings" and game.ui_buttons.any(func(b):return b.get("tag","")=="zoom_up"),"settings opens independent controls")
	game.menu="main";await render();action("title_exit");await render()
	check(game.menu=="title_exit","exit opens confirmation without quitting immediately")
	game.menu="main";await render()
	DirAccess.make_dir_recursive_absolute("res://previews/title-animation-frames")
	for i in range(20):
		game.title_screen.time=i*.12
		await render()
		var frame=root.get_texture().get_image();frame.resize(576,324)
		frame.save_png("res://previews/title-animation-frames/%02d.png"%i)
	game.title_screen.time=3;await render();action("title_start")
	check(game.g.phase=="DAY" and game.menu=="" and game.g.resources[0]==0,"start enters real zero-material new game")
	var report={"checks":checks,"failures":failures,"animated_samples":changed}
	var file=FileAccess.open("res://title-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)

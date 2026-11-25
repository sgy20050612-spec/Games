extends SceneTree
var game
var errors=[]
func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func check(value,name):
	if not value:errors.append(name);push_error(name)
func render():
	game.queue_redraw()
	for k in range(3):await process_frame
	await RenderingServer.frame_post_draw
func run():
	root.size=Vector2i(1152,648)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.menu="";game.g.start()
	var g=game.g;var w=g.current()
	g.player.pos=w.camp_position();g.interact()
	check(w.s.residents[0].profession=="UNEMPLOYED","camp resident starts unassigned")
	game.menu="dispatch";await render()
	check(game.avatars.size()==1,"day1 resident dispatch is immediately available")
	var target=game.drops.filter(func(d):return d.has("column") and d.column==0 and d.island==0)[0]
	game.dragging=w.s.residents[0];game.cursor=target.rect.get_center();game.finish_drag()
	check(w.builders().size()==1,"UI drag chooses first builder profession")
	game.menu="";g.resources=[100.0,100.0,0.0,20.0];g.remaining=70
	g.player.pos=w.pos(w.core())+Vector2(0,70)
	var first=null
	for y in range(17,21):
		for x in range(8,19):
			if w.can_place("wall",Vector2i(x,y))=="" and w.can_place("wall",Vector2i(x+1,y))=="" and w.can_place("wall",Vector2i(x+2,y))=="":first=Vector2i(x,y);break
		if first!=null:break
	game.placement="wall";game.placement_click(first)
	check(w.s.buildings.size()==2 and game.wall_start==first,"first click only anchors wall preview")
	await render()
	game.cursor=Vector2(first+Vector2i(2,0))*32+game.offset+Vector2(16,16)
	await render()
	root.get_texture().get_image().save_png("res://previews/21-camp-wall-preview.png")
	game.placement_click(first+Vector2i(2,0))
	check(w.s.buildings.size()==5 and game.wall_start==null,"second click commits complete wall line")
	game.placement=""
	g.player.pos=Vector2(first)*32+Vector2(40,65)
	for k in range(250):
		g.tick(.05);game.clock+=.05
		if w.builders()[0].get("working",false):break
	await render()
	root.get_texture().get_image().save_png("res://previews/22-builder-hammer.png")
	check(w.builders()[0].get("working",false),"arrived builder enters animated hammer state")
	DirAccess.make_dir_recursive_absolute("res://previews/builder-animation-frames")
	for frame in range(16):
		game.clock+=.09
		await render()
		var image=root.get_texture().get_image()
		var p=w.builders()[0].pos+game.offset
		image.get_region(Rect2i(Vector2i(p)-Vector2i(75,100),Vector2i(150,145))).save_png("res://previews/builder-animation-frames/%02d.png"%frame)
	game.placement="wall";game.placement_click(first)
	var cancel=InputEventMouseButton.new();cancel.button_index=MOUSE_BUTTON_RIGHT;cancel.pressed=true;game._input(cancel)
	check(game.wall_start==null and game.placement=="","right click cancels wall anchor")
	print(JSON.stringify({"checks":7,"failures":errors}))
	game.queue_free();await process_frame;await process_frame
	quit(0 if errors.is_empty() else 1)

extends SceneTree
class Sheet:
	extends "res://scripts/game.gd"
	func _draw():
		if art==null:return
		box(Rect2(0,0,1152,648),Color("f6d99b"))
		label_at("原创居民 · 四方向移动动作",Vector2(34,40),26)
		var names=["正面","背面","向左","向右"]
		var directions=[Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]
		for c in range(4):label_at(names[c],Vector2(280+c*200,77),20)
		var roles=["UNEMPLOYED","BUILD","GATHER","MELEE","RANGED","HERO_MELEE","HERO_RANGED"]
		for r in range(7):
			label_at(ROLE_NAMES[roles[r]],Vector2(35,125+r*73),19)
			for c in range(4):art.person(Vector2(310+c*200,141+r*73),roles[r],true,1,1.55,directions[c])
var checks=0
var failures=[]
func check(value,name):
	checks+=1
	if not value:failures.append(name);push_error(name)
func _initialize():OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func run():
	root.size=Vector2i(1152,648)
	var game=Sheet.new();root.add_child(game);game.set_process(false);game.menu="directions";game.water_layer.visible=false
	var roles=["UNEMPLOYED","BUILD","GATHER","MELEE","RANGED","HERO_MELEE","HERO_RANGED"]
	for role in roles:
		game.clock=0
		var front=game.art.person_frame(role,true,Vector2.DOWN)
		var back=game.art.person_frame(role,true,Vector2.UP)
		check(front.texture==game.art.SOUTH and back.texture==game.art.VERTICAL and front.columns==4 and back.columns==8,"front and back have independent frames "+role)
		check(game.art.person_frame(role,true,Vector2.LEFT).flip and not game.art.person_frame(role,true,Vector2.RIGHT).flip,"left and right face opposite directions "+role)
		game.clock=.15
		check(game.art.person_frame(role,true,Vector2.DOWN).index!=front.index,"walking advances animation "+role)
	for role in roles:
		for direction in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
			for frame in range(4):
				game.clock=float(frame)/8.0
				var state=game.art.person_frame(role,true,direction)
				var layout=game.art.person_layout(Vector2(400,400),state,1.0)
				var rect=Rect2(layout.target.position,layout.target.size.abs())
				check(layout.anchor==Vector2(400,400) and abs(rect.end.y-400)<.01,"stable foot anchor %s %s frame%d"%[role,str(direction),frame])
	var g=game.g;g.start();g.player.pos=Vector2(100,100)
	for direction in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
		g.move(direction,.05);check(g.player.moving and g.player.facing==direction,"player faces actual input "+str(direction))
		g.move(Vector2.ZERO,.05);check(not g.player.moving and g.player.facing==direction,"idle keeps last direction "+str(direction))
	var turn_origin=g.player.pos
	for direction in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
		g.player.facing=direction
		for frame in range(4):
			game.clock=float(frame)/8.0
			game.art.person_layout(turn_origin,game.art.person_frame("HERO_MELEE",true,direction),1.5)
			g.move(Vector2.ZERO,.05)
			check(g.player.pos==turn_origin,"turning/rendering never mutates world position")
	var worker=g.add_resident("GATHER",0);worker.job="wood";worker.pos=Vector2(450,450)
	var before=worker.pos;g.tick(.05)
	check(worker.moving and worker.facing.dot((worker.pos-before).normalized())>.99,"NPC direction follows actual displacement")
	DirAccess.make_dir_recursive_absolute("res://previews/direction-frames")
	for i in range(16):
		game.clock=i*.10;game.queue_redraw()
		for k in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		if i==0:image.save_png("res://previews/28-four-direction-sheet.png")
		image.resize(768,432);image.save_png("res://previews/direction-frames/%02d.png"%i)
	var f=FileAccess.open("res://directions-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print(JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)

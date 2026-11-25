extends SceneTree
class Probe:
	extends "res://scripts/game.gd"
	var selected_kind="camp"
	var selected_data=null
	var mode="both"
	func _draw():
		if art==null:return
		box(Rect2(0,0,1152,648),Color("203040"))
		if mode in ["expected_front","expected_back"]:
			var object_entry=null;var player_entry=null
			for e in art.scene_entries(g.current()):
				if e.kind=="player":player_entry=e
				elif e.kind==selected_kind and e.data==selected_data:object_entry=e
			if mode=="expected_front":
				art.draw_entry(g.current(),object_entry);art.draw_entry(g.current(),player_entry)
			else:
				art.draw_entry(g.current(),player_entry);art.draw_entry(g.current(),object_entry)
			return
		for entry in art.scene_entries(g.current()):
			if entry.kind=="player":
				if mode!="object":art.draw_entry(g.current(),entry)
			elif entry.kind==selected_kind and entry.data==selected_data and mode!="player":art.draw_entry(g.current(),entry)
var checks=0
var failures=[]
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func difference(a,b):
	return abs(a.r-b.r)+abs(a.g-b.g)+abs(a.b-b.b)
func capture(game,mode):
	game.mode=mode;game.queue_redraw()
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func _initialize():OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func run():
	root.size=Vector2i(1152,648)
	var game=Probe.new();root.add_child(game);game.set_process(false);game.menu="probe";game.water_layer.visible=false;game.clock=0
	game.g.start();game.g.day=2;game.g.current().s.dock=true
	var w=game.g.current()
	var node={"kind":0,"cell":Vector2i(4,5),"amount":10,"form":"natural"}
	w.s.nodes=[node]
	var worker=game.g.add_resident("BUILD",0);worker.pos=Vector2(400,400)
	w.s.enemies=[{"pos":Vector2(450,450),"kind":0,"cooldown":0,"hp":10}]
	var all=game.art.scene_entries(w)
	var kinds=[]
	for e in all:kinds.append(e.kind)
	for kind in ["camp","boat","settlement","refugee","resident","enemy","beach","resource","building","player"]:check(kind in kinds,"world queue includes "+kind)
	for i in range(1,all.size()):check(all[i-1].y<=all[i].y,"world queue sorted from back to front")
	var fixtures=[]
	for kind in ["camp","building","resource","boat","settlement","resident","enemy"]:
		for entry in all:
			if entry.kind==kind:fixtures.append(entry);break
	# Additional pile and log use the same production resource draw path.
	for fixture in fixtures:
		game.selected_kind=fixture.kind;game.selected_data=fixture.data
		var anchor=Vector2.ZERO
		if fixture.kind=="camp":anchor=w.camp_position()+Vector2(0,32)
		elif fixture.kind=="building":anchor=Vector2(fixture.data.cell)*32+Vector2(game.g.rules.buildings[fixture.data.kind].w*16,game.g.rules.buildings[fixture.data.kind].h*32)
		elif fixture.kind=="resource":anchor=Vector2(fixture.data.cell)*32+Vector2(16,30)
		elif fixture.kind in ["boat","settlement"]:anchor=fixture.data;anchor.y=fixture.y
		else:anchor=fixture.data.pos
		game.offset=Vector2(576,355)-anchor
		for front in [false,true]:
			game.g.player.pos=anchor+Vector2(0,8 if front else -8)
			game.g.player.facing=Vector2.DOWN
			var object_image=await capture(game,"object")
			var player_image=await capture(game,"player")
			var combined=await capture(game,"both")
			var expected_image=await capture(game,"expected_front" if front else "expected_back")
			var bg=combined.get_pixel(500,250);var overlap=0;var wrong=0
			for y in range(275,375):
				for x in range(530,625):
					var a=object_image.get_pixel(x,y);var b=player_image.get_pixel(x,y)
					if difference(a,bg)<.08 or difference(b,bg)<.08 or difference(a,b)<.08:continue
					overlap+=1
					var expected=expected_image.get_pixel(x,y)
					if difference(combined.get_pixel(x,y),expected)>.05:wrong+=1
			check(overlap>10,"rendered overlap exists "+fixture.kind+str(front))
			check(wrong==0,"correct actual visible pixels "+fixture.kind+str(front)+" wrong=%d/%d"%[wrong,overlap])
			if fixture.kind=="camp":combined.save_png("res://previews/depth-camp-%s.png"%("front" if front else "behind"))
	var f=FileAccess.open("res://depth-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print(JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame;await process_frame;await create_timer(.15).timeout;quit(0 if failures.is_empty() else 1)

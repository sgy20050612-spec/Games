extends SceneTree
var errors=[]
var checks=0
var game

func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1")
	call_deferred("run")

func check(value,name):
	checks+=1
	if not value:errors.append(name);push_error(name)

func refresh():
	for k in range(3):await process_frame

func run():
	root.size=Vector2i(1152,648)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.title_screen.time=2
	await refresh()
	var start=game.ui_buttons.filter(func(b):return b.get("tag","")=="title_start")
	check(start.size()==1,"main menu start button rendered")
	start[0].action.call()
	check(game.g.phase=="DAY" and game.menu=="","main menu starts actual simulation")
	var before_time=game.g.remaining
	for key in [KEY_1,KEY_2,KEY_3]:
		var event=InputEventKey.new();event.keycode=key;event.pressed=true
		game._input(event)
	check(game.g.phase=="DAY" and game.g.remaining==before_time,"number keys cannot change day or time")
	game.menu="tree"
	game.g.research=3
	await refresh()
	var tech=game.ui_buttons.filter(func(b):return b.rect.position==Vector2(62,257))
	check(tech.size()==1,"next technology is clickable")
	tech[0].action.call()
	check(game.g.tech==2 and game.g.resident_tree==1,"technology callback buys correct tree")
	game.g.day=2
	game.g.story.settlers=true
	var r=game.g.add_resident("UNEMPLOYED")
	game.menu="dispatch"
	await refresh()
	check(game.avatars.any(func(a):return a.r.id==r.id),"pool avatar rendered")
	var target=game.drops.filter(func(d):return d.island==0 and d.column==0)[0]
	game.dragging=r
	game.cursor=target.rect.get_center()
	game.finish_drag()
	check(r.profession=="BUILD" and r.island==0,"drag handler assigns resident")
	check(game.g.resident_count()==1,"drag creates no duplicate resident")
	await refresh()
	var enter=game.ui_buttons.filter(func(b):return b.rect.position==Vector2(205,224))[0]
	enter.action.call()
	check(game.detail.island==0 and game.detail.column==0,"occupation cell opens correct facility page")
	await refresh()
	var facility=game.drops.filter(func(d):return d.facility.has("workplace"))[0]
	game.dragging=r
	game.cursor=facility.rect.get_center()
	game.finish_drag()
	check(r.job=="build","facility drop updates actual job")
	game.menu="map";game.detail=null
	await refresh()
	check(game.ui_buttons.size()>=8,"map includes navigation controls")
	game.menu="saves"
	await refresh()
	check(game.ui_buttons.size()>=18,"settings renders ten save slots and controls")
	game.g.dispose();game.g=load("res://scripts/simulation.gd").new()
	game.g.resident_tree=6;game.g.day=2;game.g.phase="DAY";game.g.story.settlers=true
	for k in range(40):game.g.add_resident("UNEMPLOYED")
	game.menu="dispatch";game.detail=null;game.dispatch_scroll={}
	await refresh()
	check(game.avatars.size()==15,"40-resident pool renders only15 visible avatars")
	game.dispatch_scroll.pool=9
	await refresh()
	check(game.avatars.any(func(a):return a.r.id==game.g.pool[-1].id),"last of40 residents reachable on final page")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/18-dispatch-40-residents.png")
	var report={"checks":checks,"failures":errors,"scope":"rendered UI callbacks and drag/drop handlers; not OS mouse/keyboard acceptance"}
	var f=FileAccess.open("res://ui-verification.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.15).timeout
	quit(0 if errors.is_empty() else 1)

extends SceneTree
var game
var failures=[]
var checks=0
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func capture(path):
	game.queue_redraw()
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func _initialize():OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func run():
	root.size=Vector2i(1152,648)
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.g.start()
	var g=game.g;g.tech=6;g.resident_tree=6;g.resources=[100.0,80.0,40.0,20.0]
	var w=g.current();var warehouse=w.add_building("warehouse",Vector2i(4,4),true);warehouse.level=3
	var smith=g.add_resident("BUILD",0);smith.pos=Vector2(600,600);g.player.pos=Vector2(620,620)
	g.craft("shortbow");g.craft("leather");g.items.sync()
	game.menu="character";await capture("res://previews/34-inventory-information.png")
	check(game.inventory_cells.size()==36,"UI exposes all36 slots")
	# Actual game input: select bag item, then swap slots by press/release.
	var target=game.inventory_cells[0].rect.get_center()
	Input.warp_mouse(target);await process_frame
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=target;game._input(e)
	e.pressed=false;game._input(e);check(g.selected_slot==0,"click selects inventory item through input handler")
	var bow=g.gear.filter(func(item):return item.kind=="shortbow")[0]
	for i in range(36):
		if g.inventory[i].get("id","")==bow.id:g.items.equip(i);break
	game.menu=""
	var handoff=InputEventMouseButton.new();handoff.button_index=MOUSE_BUTTON_RIGHT;handoff.pressed=true;handoff.position=Vector2(576,355)+(smith.pos-g.player.pos)
	game._input(handoff)
	check(bow.owner==smith.id,"real right-click handler equips nearby resident with held gear")
	game.menu="workshop";await capture("res://previews/35-artisan-workshop.png")
	check(game.ui_buttons.any(func(b):return b.rect.has_point(Vector2(500,265))),"workshop craft actions rendered")
	var gatherer=g.add_resident("GATHER",0)
	game.menu="dispatch";game.detail=null;await capture("res://previews/36-building-job-capacity.png")
	game.detail={"island":0,"column":1};await capture("res://previews/37-per-building-allocation.png")
	check(game.drops.any(func(d):return d.has("facility") and d.facility.has("workplace")),"facility drops target actual buildings")
	game.menu="";game.detail=null;await capture("res://previews/38-header-removed.png")
	var f=FileAccess.open("res://inventory-ui-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print(JSON.stringify({"checks":checks,"failures":failures}));game.queue_free();await process_frame;await process_frame;await create_timer(.15).timeout;quit(0 if failures.is_empty() else 1)

extends SceneTree
var game
var checks=0
var failures=[]
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func render():
	game.queue_redraw()
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
func click(tag):
	for b in game.ui_buttons:
		if b.get("tag","")==tag:b.action.call();return true
	return false
func _initialize():OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func run():
	root.size=Vector2i(1152,648)
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.title_screen.time=2;game.menu="title_settings"
	var p=game.preferences
	await render()
	check(click("background_dropdown"),"background dropdown opens");await render()
	check(click("background_2") and p.values.background=="夜色","background choice applies");await render()
	p.popup="";p.set_option("background","标准")
	for scale_value in p.UI_SCALES:
		p.set_option("ui_scale",scale_value);await render()
		for b in game.ui_buttons:check(Rect2(0,0,1152,648).encloses(b.rect),"settings control remains on screen at "+str(scale_value))
		var start=Vector2(727,179);var end=Vector2(917,179)
		var offset=Vector2(576,324)*(1-scale_value)
		var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=start*scale_value+offset
		check(p.handle_input(down),"slider starts dragging at scaled position")
		var motion=InputEventMouseMotion.new();motion.position=end*scale_value+offset;p.handle_input(motion)
		var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=motion.position;p.handle_input(up)
		check(p.values.music==10 and p.dragging_slider=="","drag reaches endpoint and releases")
		p.set_option("music",4);p.set_option("effects",7)
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=start*scale_value+offset;p.handle_input(e);e.pressed=false;p.handle_input(e)
		check(p.values.music==0 and p.values.effects==7,"music slider does not modify effects")
	p.reset();game.g.start();game.menu="";await render()
	check(game.clock_minutes()==360,"day starts at06:00")
	game.g.tick(2.0);check(game.clock_minutes()>360,"clock advances with simulation automatically")
	game.g.remaining=50;check(game.clock_minutes()==720,"midday reads12:00")
	game.g.phase="TRANSITION";game.g.remaining=1;check(game.clock_minutes()==1110,"sunset reads18:30")
	game.g.phase="NIGHT";game.g.remaining=40;check(game.clock_minutes()==30,"night clock crosses midnight")
	game.g.remaining=0;check(game.clock_minutes()==360,"night ends at06:00")
	game.g.phase="DAY";game.g.remaining=100
	await render();root.get_texture().get_image().save_png("res://previews/32-day-clock-ui.png")
	game.menu="settings";await render();root.get_texture().get_image().save_png("res://previews/31-settings-reference-ui.png")
	p.set_option("ui_scale",1.1);await render();root.get_texture().get_image().save_png("res://previews/33-settings-scale110.png")
	p.reset()
	var f=FileAccess.open("res://settings-layout-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print(JSON.stringify({"checks":checks,"failures":failures}));game.queue_free();await process_frame;await process_frame;await create_timer(.15).timeout;quit(0 if failures.is_empty() else 1)

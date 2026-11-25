extends SceneTree
const COAST=preload("res://scripts/coast.gd")
var failures=[]
var checks=0

func check(value,name):
	checks+=1
	if not value:failures.append(name);push_error(name)

func luminance(image):
	var total=0.0
	var count=0
	for x in range(180,980,11):
		for y in range(485,560,9):
			var c=image.get_pixel(x,y)
			total+=c.r*.2126+c.g*.7152+c.b*.0722
			count+=1
	return total/count

func _initialize():call_deferred("run")

func run():
	root.size=Vector2i(1152,648)
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.menu=""
	game.g.phase="DAY";game.g.remaining=55
	game.g.player.pos=Vector2(464,860)
	var w=game.g.current()
	w.s.dock=true
	w.add_building("house",Vector2i(6,24),true)
	for k in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var first=root.get_texture().get_image()
	await create_timer(.9).timeout
	await RenderingServer.frame_post_draw
	var second=root.get_texture().get_image()
	var changed=0
	for x in range(180,980,7):
		for y in range(485,560,7):
			if first.get_pixel(x,y)!=second.get_pixel(x,y):changed+=1
	check(changed>50,"water pixels animate while simulation is paused")
	var reflection=game.water_layer.reflection_viewport.get_texture().get_image()
	var alpha_pixels=0
	for x in range(0,1152,4):
		for y in range(75,570,4):
			if reflection.get_pixel(x,y).a>.02:alpha_pixels+=1
	check(alpha_pixels>50,"reflection viewport contains actual scene sprites")
	game.g.phase="NIGHT";game.g.remaining=65
	game.queue_redraw()
	for k in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var dark=root.get_texture().get_image()
	check(luminance(dark)<luminance(second)*.7,"night water has a darker cool palette")
	for size_value in [704,896]:
		for corner in [Vector2.ZERO,Vector2(size_value,0),Vector2(0,size_value),Vector2(size_value,size_value)]:
			check(COAST.distance_at(corner,size_value)<0,"entire build rectangle remains on land")
		var depth=COAST.depth(size_value*.5,3,size_value)
		check(abs(COAST.distance_at(Vector2(size_value*.5,size_value+depth),size_value))<3,"reflection coast aligns with terrain shape")
	game.g.player.pos=Vector2(464,896)
	game.g.phase="DAY"
	game.g.move(Vector2.DOWN,.2)
	check(game.g.player.pos.y>896,"player can walk onto the visible beach")
	for i in range(80):game.g.move(Vector2.DOWN,.05)
	check(COAST.distance_at(game.g.player.pos,896)<=-8,"player stops at the visible shoreline")
	var report={"checks":checks,"failures":failures,"animated_water_samples":changed,"reflection_alpha_samples":alpha_pixels,"day_luminance":luminance(second),"night_luminance":luminance(dark)}
	var f=FileAccess.open("res://water-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

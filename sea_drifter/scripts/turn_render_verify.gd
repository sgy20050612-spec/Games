extends SceneTree
class Probe:
	extends "res://scripts/game.gd"
	var facing=Vector2.RIGHT
	func _draw():
		if art==null:return
		box(Rect2(0,0,1152,648),Color("ff00ff"))
		art.person(Vector2(576,355),"HERO_MELEE",false,1,1.5,facing)
var checks=0
var failures=[]
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func visible_bounds(image):
	var left=10000;var right=-1;var top=10000;var bottom=-1
	for y in range(280,380):
		for x in range(500,680):
			if image.get_pixel(x,y).g>.05:
				left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)
	return Rect2i(left,top,right-left+1,bottom-top+1)
func _initialize():OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func run():
	root.size=Vector2i(1152,648)
	var game=Probe.new();root.add_child(game);game.set_process(false);game.menu="probe";game.water_layer.visible=false
	var origin=game.g.player.pos
	var boxes={}
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]:
		game.facing=direction;game.queue_redraw()
		for i in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		image.save_png("res://previews/turn-probe-%d-%d.png"%[direction.x,direction.y])
		var bounds=visible_bounds(image);boxes[direction]=bounds
		check(abs(bounds.get_center().x-576)<=2,"rendered body remains at original X on turn "+str(direction))
		check(abs(bounds.end.y-355)<=1,"rendered feet remain at original Y on turn "+str(direction))
		check(game.g.player.pos==origin,"rendering turn preserves world coordinates")
	check(boxes[Vector2.LEFT]==boxes[Vector2.RIGHT],"left/right actual rendered bounds coincide (regression: 38px jump)")
	var f=FileAccess.open("res://turn-render-verification.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print(JSON.stringify({"checks":checks,"failures":failures,"rendered_bounds":str(boxes)}))
	game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)

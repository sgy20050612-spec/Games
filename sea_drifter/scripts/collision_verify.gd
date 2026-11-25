extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func fresh():
	var g=Sim.new();g.start();g.resources=[999.0,999.0,999.0,99.0];return g
func _initialize():OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func run():
	# Every production building has a footprint, including unfinished sites.
	var g=fresh();var w=g.current()
	for kind in g.rules.buildings:
		var b=w.add_building(kind,Vector2i(4,4),false)
		var body=w.building_body(b)
		check(w.worker_blocked(body.get_center()),"solid building/site "+kind)
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var start=body.get_center()+direction*(max(body.size.x,body.size.y)+50)
			start=w.safe_worker_position(start)
			var result=w.move_actor(start,body.get_center()-direction*100)
			check(not w.worker_blocked(result),"swept movement cannot tunnel through "+kind+str(direction))
		var recovered=w.safe_worker_position(body.get_center())
		check(not w.worker_blocked(recovered),"legacy embedded actor escapes "+kind)
		w.remove_building(b)
	# Real player movement uses the same blocker, and slides beside walls.
	var wall=w.add_building("wall",Vector2i(5,5),true)
	g.player.pos=Vector2(130,176);g.move(Vector2.RIGHT,1)
	check(g.player.pos.x<153 and not w.worker_blocked(g.player.pos),"player cannot cross wall at large delta")
	var before=g.player.pos;g.move(Vector2(1,1),.05)
	check(g.player.pos.y>before.y and not w.worker_blocked(g.player.pos),"player slides along wall")
	# The user's two adjacent-wall case: two workers, a stale finished path and new obstacles.
	var a=w.add_building("wall",Vector2i(9,8),false);a.batch=true
	var b=w.add_building("wall",Vector2i(9,9),false);b.batch=true
	var r=g.add_resident("BUILD",0);r.pos=Vector2(240,270)
	var r2=g.add_resident("BUILD",0);r2.pos=Vector2(230,275)
	w.assign_builder(a,r);w.assign_builder(a,r2)
	w.navigation();r.path_site=a.id;r.path_version=w.navigation_key;r.work_path=[r.pos];r.path_cursor=1;r.path_retry=0
	var animations=false;var embedded=false
	for i in range(700):
		g.tick(.05)
		animations=animations or r.working or r2.working
		embedded=embedded or w.worker_blocked(r.pos) or w.worker_blocked(r2.pos)
	check(a.progress>=a.duration and b.progress>=b.duration,"adjacent walls finish and continue queue with stale cached path")
	check(animations,"builders play construction state while progress advances")
	check(not embedded,"builders remain outside all footprints throughout construction")
	# Large buildings need perimeter access, not a hard distance to their centre.
	var house=w.add_building("house",Vector2i(16,8),false);w.assign_builder(house,r)
	for i in range(650):g.tick(.05)
	check(house.progress>=house.duration,"large building finishes from a reachable exterior work point")
	# Same-count replacement invalidates path caches; save recovery keeps progress.
	w.navigation();var old_key=w.navigation_key;w.remove_building(wall);w.add_building("wall",Vector2i(6,5),true);w.navigation()
	check(w.navigation_key!=old_key,"same building count does not preserve stale navigation")
	var saved=g.snapshot();var restored=Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))),"collision/navigation fields survive save restore")
	restored.dispose();g.dispose()
	var f=FileAccess.open("res://collision-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)

extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func check(value,name):
	checks+=1
	if not value:failures.append(name);push_error(name)
func volley(form,level,count):
	var g=Sim.new();g.phase="DAY";g.tech=4;g.resident_tree=4
	g.player.pos=Vector2(-80,-80)
	var w=g.current()
	for j in range(4):w.add_building("house",Vector2i(j*2,24),true)
	var b=w.add_building("htower",Vector2i(4,4),true);b.level=level
	for j in range(count):
		var r=g.add_resident("BUILD",0)
		g.set_station(r,form if form in ["signal","cannon","mortar"] else "")
		if form=="elite":r.profession="RANGED"
		w.station(r.id,b)
	check(w.tower_form(b)==form,"tower form %s level%d crew%d"%[form,level,count])
	w.spawn(0,0,w.pos(b)+Vector2(60,0))
	var e=w.s.enemies[0];e.hp=10000
	w.tick(.05)
	var damage=10000-e.hp
	g.dispose();return damage
func run():
	for level in range(1,4):
		for form in ["archer","elite","signal","cannon","mortar"]:
			var one=volley(form,level,1)
			var three=volley(form,level,3)
			check(is_equal_approx(three,one*3),"three independent shots %s level%d"%[form,level])
			check(one==0 if form=="signal" else one>0,"signal noncombat / weapon fires %s level%d"%[form,level])
	var g=Sim.new();g.phase="DAY";g.resources=[1000.0,1000.0,1000.0,1000.0]
	var w=g.current();g.add_resident("BUILD",0)
	var tower=w.add_building("htower",Vector2i(4,4),true)
	check(not tower.wall_link,"isolated empty tower is not linked")
	var wall=w.add_building("wall",Vector2i(3,4),true)
	check(tower.wall_link,"wall links adjacent empty tower")
	w.remove_building(wall,true)
	check(not tower.wall_link,"removing wall immediately unlinks empty tower")
	var r=g.add_resident("BUILD",0);w.station(r.id,tower)
	check(tower.wall_link,"occupied isolated tower remains wall")
	w.unstation(r)
	var rng=RandomNumberGenerator.new();rng.seed=7124
	for k in range(200):
		var cell=Vector2i(rng.randi_range(0,27),rng.randi_range(0,27))
		if w.can_place("wall",cell)=="":
			w.place("wall",cell)
			var b=w.s.buildings[-1]
			check(w.s.occupancy.get(cell)==b.id,"random placement footprint%d"%k)
			w.remove_building(b,true)
			check(not w.s.occupancy.has(cell),"random demolition releases footprint%d"%k)
	g.dispose()
	var a=Sim.new();a.phase="NIGHT";a.remaining=80;a.active=1
	for world in a.worlds:
		world.s.status="OWNED";world.begin_night(4,a.worlds.find(world))
	a.player.pos=Vector2(-80,-80)
	var b=Sim.new();b.restore(JSON.parse_string(JSON.stringify(a.snapshot())))
	b.phase="NIGHT";b.active=2
	for k in range(600):a.tick(.05);b.tick(.05)
	check(JSON.parse_string(JSON.stringify(a.pack_value(a.worlds[0].s)))==JSON.parse_string(JSON.stringify(b.pack_value(b.worlds[0].s))),"switching rendered island preserves remote battle")
	a.dispose();b.dispose()
	g=Sim.new();g.phase="DAY";g.resources=[200.0,200.0,0.0,20.0]
	g.active=1;w=g.current();w.s.status="TO_RECLAIM";w.core().hp=100
	g.player.pos=w.pos(w.core())+Vector2(0,80)
	for k in range(5):w.spawn(0,0,g.player.pos+Vector2(0,-35))
	var duration=5.0
	for k in range(500):
		if w.s.enemies.is_empty():break
		var e=w.s.enemies[0]
		g.move((e.pos-g.player.pos).normalized(),.05)
		g.attack(e.pos-g.player.pos)
		if g.player.hp<100:g.heal()
		g.tick(.05);duration+=.05
	w.repair(w.core());g.tick(.05);duration+=1.05
	check(w.s.status=="OWNED" and duration<=30,"five-residual-enemy reclamation within30seconds including travel and return")
	g.dispose()
	g=Sim.new();g.phase="DAY";w=g.current()
	var armed=w.add_building("htower",Vector2i(4,4),true)
	var operator=g.add_resident("BUILD",0);w.station(operator.id,armed)
	var blocker=w.add_building("wall",Vector2i(7,7),true)
	w.spawn(1,0,w.pos(armed)+Vector2(70,0))
	check(w.target_for(w.s.enemies[0])==armed.id,"ranged enemy prioritizes armed tower within range")
	w.unstation(operator)
	w.s.enemies[0].pos=w.pos(blocker)
	check(w.target_for(w.s.enemies[0])==blocker.id,"contact wall blocks ranged enemy targeting")
	g.dispose()
	var report={"checks":checks,"failures":failures,"scope":"GDD13.1 tower forms, wall links,200 random placements and remote battle conservation fixtures"}
	var f=FileAccess.open("res://acceptance-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

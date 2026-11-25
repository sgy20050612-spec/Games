extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=[]
var checks=0
func check(value,name):
	checks+=1
	if not value:failures.append(name);push_error(name)
func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1")
	call_deferred("run")
func run():
	var g=Sim.new()
	g.research=30
	for i in range(3):g.unlock("resident")
	for r in g.pool:
		if r.profession=="UNEMPLOYED":check(is_equal_approx(r.max_hp,65.0),"tier4 new residents receive health bonus once")
	g.dispose()
	g=Sim.new()
	var saved=g.snapshot()
	for invalid in [[],{"version":9},"bad",null]:
		check(not g.restore(invalid),"malformed save rejected before state mutation")
		check(g.snapshot()==saved,"invalid save preserves current game")
	var broken=saved.duplicate(true);broken.worlds=[]
	check(not g.restore(broken),"missing island data rejected")
	broken=saved.duplicate(true);broken.player.pos={"_v2":[]}
	check(not g.restore(broken),"corrupt encoded player position rejected")
	g.dispose()
	g=Sim.new();g.resident_tree=3;g.research=7
	g.pending_residents=[{"profession":"UNEMPLOYED","island":-1}]
	g.unlock("resident")
	check(g.pool.all(func(r):return is_equal_approx(r.max_hp,65.0)),"tier4 pending residents receive health bonus once")
	g.dispose()
	# Ending fixtures isolate rules; these are not normal-resource playthroughs.
	for outcome in ["HE","NE","BE"]:
		g=Sim.new()
		g.day=10
		g.phase="NIGHT"
		for w in g.worlds:w.s.status="OWNED"
		if outcome=="NE":g.worlds[1].core().hp=1
		if outcome=="BE":g.worlds[1].s.status="TO_RECLAIM"
		g.finish_night()
		check(g.phase==outcome,"ending "+outcome)
		g.dispose()
	# Real per-island enemies attack all three cores in the same simulation ticks.
	g=Sim.new()
	g.phase="NIGHT";g.remaining=80
	g.player.pos=Vector2(-80,-80)
	var before=[]
	for w in g.worlds:
		w.s.status="OWNED"
		before.append(w.core().hp)
		w.spawn(0,0,w.pos(w.core())+Vector2(40,0))
	for k in range(25):g.tick(.05)
	for i in range(3):check(g.worlds[i].core().hp<before[i],"simultaneous core damage island%d"%i)
	g.dispose()
	# Continuing a daytime save preserves all three worlds' future simulation.
	g=Sim.new();g.phase="DAY";g.day=6;g.remaining=20
	g.tech=6;g.resident_tree=6
	for w in g.worlds:
		w.s.status="OWNED"
		w.core().hp=100000;w.core().max_hp=100000
		var tower=w.add_building("htower",Vector2i(4,4),true)
		var r=g.add_resident("RANGED",g.worlds.find(w))
		w.station(r.id,tower)
		w.spawn(0,0,w.pos(tower)+Vector2(60,0))
	var clone=Sim.new()
	clone.restore(JSON.parse_string(JSON.stringify(g.snapshot())))
	for k in range(600):g.tick(.05);clone.tick(.05)
	var left=JSON.parse_string(JSON.stringify(g.snapshot()))
	var right=JSON.parse_string(JSON.stringify(clone.snapshot()))
	check(left==right,"late save continues identically across night transition")
	if left!=right:
		for key in left:
			if left[key]!=right.get(key):print("DIFFERENT ",key," ",JSON.stringify(left[key]).left(300)," / ",JSON.stringify(right.get(key)).left(300))
	check(g.research==clone.research,"replay research rewards unchanged")
	g.dispose();clone.dispose()
	g=Sim.new();g.phase="DAY";g.tech=6
	var w=g.current()
	var collector=w.add_building("collector",Vector2i(4,4),true)
	check(not collector.powered,"unpowered collector stops without generator")
	var generator=w.add_building("generator",Vector2i(7,4),true)
	w.recompute()
	check(collector.powered,"generator restores collector power")
	w.remove_building(generator,false)
	check(not collector.powered,"destroying generator cuts consumer power")
	var worker=g.add_resident("BUILD",0)
	var site=w.add_building("wall",Vector2i(11,14),false)
	worker.pos=w.pos(site)+Vector2(0,34)
	g.active=1
	for k in range(100):w.tick(.05)
	check(site.progress>=site.duration,"tier6 queued construction completes while player on other island")
	check(worker.job=="build","automated completion releases worker")
	g.dispose()
	var report={"checks":checks,"failures":failures,"scope":"isolated late systems, three-island combat and ending fixtures; not full ten-day balance"}
	var f=FileAccess.open("res://late-verification.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

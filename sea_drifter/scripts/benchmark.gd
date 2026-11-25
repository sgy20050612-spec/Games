extends SceneTree
const Sim = preload("res://scripts/simulation.gd")

func _initialize():call_deferred("run")

func run():
	var g=Sim.new()
	g.phase="NIGHT"
	g.remaining=80
	g.tech=6
	g.resident_tree=6
	g.player.pos=Vector2(880,880)
	for i in range(3):
		var w=g.worlds[i]
		w.s.status="OWNED"
		w.core().hp=100000
		w.core().max_hp=100000
		for j in range(43):w.add_building("wall" if j%3==0 else "house",Vector2i(2+(j%7)*2,2+(j/7)*2),true)
		for j in range(13 if i<2 else 14):g.add_resident("GATHER",i)
		for j in range(40):w.spawn(j%3,j%4)
	var costs=[]
	for k in range(200):
		var started=Time.get_ticks_usec()
		g.tick(.05)
		costs.append((Time.get_ticks_usec()-started)/1000.0)
	costs.sort()
	var total=0.0
	for value in costs:total+=value
	var report={"mean_ms":total/costs.size(),"p95_ms":costs[189],"max_ms":costs[-1],"target_ms":3,"initial_enemies":120,"initial_residents":40,"buildings_per_island":45,"fixture":"stress data, not legal placement or route progression"}
	var f=FileAccess.open("res://benchmark.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	g.dispose()
	quit()

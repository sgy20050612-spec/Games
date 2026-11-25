extends SceneTree
## Real initial stats/resources and real input commands. No invulnerability,
## resource grants, technology grants, timer skips, or snapshot phase overrides.
const Sim=preload("res://scripts/simulation.gd")
var g
var errors=[]
var steps=0
var events=[]

func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1")
	call_deferred("run")

func check(value,name):
	if not value:errors.append(name);push_error(name)
	events.append({"at":g.elapsed,"day":g.day,"phase":g.phase,"event":name,"passed":value})
	return value

func step():
	g.tick(.05)
	steps+=1

func go(target,limit=600):
	var w=g.current()
	target=w.safe_worker_position(target)
	var nav=w.navigation()
	var path=nav.get_point_path(w.nav_cell(g.player.pos,nav),w.nav_cell(target,nav))
	var cursor=0
	for i in range(limit):
		if g.player.pos.distance_to(target)<9:return true
		if g.phase not in ["DAY","TRANSITION","NIGHT"]:return false
		while cursor<path.size() and g.player.pos.distance_to(path[cursor])<5:cursor+=1
		var destination=path[cursor] if cursor<path.size() else target
		g.move((destination-g.player.pos).normalized(),.05)
		step()
	return false

func harvest(kind,goal):
	while g.resources[kind]+.00001<goal and g.phase=="DAY" and g.remaining>8:
		var target=null
		var distance=INF
		for node in g.current().s.nodes:
			var p=Vector2(node.cell)*32+Vector2(16,16)
			if node.kind==kind and node.amount>.00001 and g.player.pos.distance_to(p)<distance:
				target=node;distance=g.player.pos.distance_to(p)
		if target==null:return false
		if not go(Vector2(target.cell)*32+Vector2(16,16)):return false
		while target.amount>.00001 and g.resources[kind]+.00001<goal and g.phase=="DAY":
			g.gather(.05)
			step()
	return g.resources[kind]+.00001>=goal

func combat_tick():
	var target=null
	var distance=INF
	for e in g.current().s.enemies:
		if e.hp>0 and g.player.pos.distance_to(e.pos)<distance:
			target=e;distance=g.player.pos.distance_to(e.pos)
	if target!=null:
		if distance>48:g.move((target.pos-g.player.pos).normalized(),.05)
		if distance<=55:g.attack(target.pos-g.player.pos)
	if g.player.hp<100:g.heal()
	step()

func run():
	g=Sim.new()
	g.start()
	check(g.resources==[0.0,0.0,0.0,20.0] and g.tech==1 and g.resident_tree==1 and g.resident_count()==0,"real initial state")
	var w=g.current()
	go(w.camp_position())
	g.interact()
	check(g.story.artisan and w.s.residents[0].profession=="UNEMPLOYED","rescue unassigned resident through proximity interaction")
	g.assign(w.s.residents[0],0,"BUILD")
	if check(w.builders().size()==1,"manually assign first builder on day1"):
		check(harvest(0,90),"gather wood using actual nodes and gathering rate")
		check(harvest(1,40),"gather stone using actual nodes and gathering rate")
		go(w.builders()[0].pos)
		var cell=Vector2i(11,14)
		var reason=w.can_place("wall",cell)
		if check(reason=="","legal defensive wall placement"):
			w.place("wall",cell)
			var wall=w.s.buildings[-1]
			go(w.pos(wall)+Vector2(45,0))
			for i in range(200):
				if wall.progress>=wall.duration:break
				step()
			check(wall.progress>=wall.duration,"resident completes construction on site")
		go(w.pos(w.core())+Vector2(0,64))
		g.upgrade_core()
		for i in range(80):
			if g.base_upgrade.time<=0:break
			step()
		check(w.s.level==2 and g.earned_research>=3,"upgrade core with earned resources")
		g.unlock("tech")
		check(g.tech==2 and g.research==0,"buy tower technology with actual core research reward")
	while g.phase in ["DAY","TRANSITION"]:step()
	while g.phase=="NIGHT":combat_tick()
	check(g.phase=="RESULT" and g.player.hp>0 and w.core().hp>0,"survive first night without modified health")
	if g.phase=="RESULT":
		g.next_day()
		check(g.day==2 and g.phase=="DAY" and g.remaining==100,"advance to day2 through normal result continuation")
		go(w.pos(w.core())+Vector2(150,100))
		g.interact()
		check(g.story.settlers and g.resident_count()>=4,"rescue second-day residents")
		check(w.assigned_count()<=w.capacity(),"unassigned story residents do not occupy jobs")
		for resident in w.s.residents:
			if resident.profession=="UNEMPLOYED":g.assign(resident,0,"BUILD");break
		check(harvest(0,70) and harvest(1,20),"gather day2 dock materials from regenerated nodes")
		go(w.pos(w.s.buildings[1])-Vector2(0,55))
		g.interact()
		check(w.s.dock,"repair main dock with actual materials")
		g.begin_travel(1)
		for i in range(145):
			if g.travel.time<=0:break
			step()
		check(g.active==1 and g.current().builders().size()==1,"first landing brings a builder to side island")
		var side=g.current()
		go(side.pos(side.s.buildings[1])-Vector2(0,55))
		g.interact()
		for i in range(350):
			if side.s.dock:break
			step()
		check(side.s.dock,"build side dock through resident construction")
		g.begin_travel(0)
		for i in range(145):
			if g.travel.time<=0:break
			step()
		check(g.active==0 and g.phase=="DAY","return to main island before second sunset")
	var report={"state":"passed" if errors.is_empty() else "failed","errors":errors,"events":events,"ticks":steps,"elapsed_simulated_seconds":g.elapsed,"player_hp":g.player.hp,"core_hp":w.core().hp,"resources":g.resources,"scope":"automated real-input first-day and day2 rescue integration; not human acceptance or ten-day balance"}
	var f=FileAccess.open("res://playthrough-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	g.dispose();g=null
	quit(0 if errors.is_empty() else 1)

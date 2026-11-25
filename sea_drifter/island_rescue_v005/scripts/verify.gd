extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var failures = []
var checks = 0

func check(condition, name):
	checks += 1
	if not condition:
		failures.append(name)
		push_error(name)

func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1")
	call_deferred("run")

func run():
	var g = Sim.new()
	g.phase = "DAY"
	check(g.resident_count()==0,"no builder before rescue")
	check(g.current().can_place("wall",Vector2i(3,3))!="","construction requires builder")
	var builder=g.add_resident("BUILD",0)
	g.resources=[1000.0,1000.0,1000.0,1000.0]
	check(g.current().can_place("wall",g.current().core().cell-Vector2i.ONE)!="","core exclusion zone")
	check(g.current().can_place("warehouse",Vector2i(27,27))!="","whole footprint must be in bounds")
	check(g.current().can_place("wall",Vector2i(0,14))!="","waypoint protection")
	var location=null
	for x in range(2,24):
		for y in range(2,24):
			if g.current().can_place("wall",Vector2i(x,y))=="":location=Vector2i(x,y);break
		if location!=null:break
	check(location!=null,"find legal placement")
	var wall=g.current().add_building("wall",location,true)
	check(g.current().can_place("wall",location)!="","occupancy prevents overlapping")
	g.current().remove_building(wall,true)
	check(g.current().can_place("wall",location)=="","demolition releases occupancy")
	var tower=g.current().add_building("htower",Vector2i(4,4),true)
	check(g.current().tower_form(tower)=="none","empty tower has no attack form")
	for k in range(6):g.current().add_building("house",Vector2i(2+k*2,22),true)
	var melee=g.add_resident("RANGED",0)
	var ranged=g.add_resident("MELEE",0)
	var hero=g.add_resident("HERO_MELEE",0)
	check(g.current().station(hero.id,tower)!="已驻守高塔","heroes cannot enter towers")
	g.current().station(melee.id,tower)
	check(tower.occupants.size()==1,"tower accepts resident")
	g.current().station(ranged.id,tower)
	check(tower.occupants.size()==1,"mixed professions rejected")
	for k in range(4):
		var r=g.add_resident("RANGED",0)
		g.current().station(r.id,tower)
	check(tower.occupants.size()==3,"tower occupancy hard limit three")
	check(g.rules.tower.elite[2][0]*3/g.rules.tower.elite[2][1]==80,"three individual elite volleys equal80DPS")
	check(g.rules.tower.mortar[2][0]*3/g.rules.tower.mortar[2][1]==150,"three individual mortar volleys equal150DPS")
	check(g.rules.buildings.htower.power==0,"all tower forms unpowered")
	# Capacity enforcement and fixed professions.
	g.day=2
	var unemployed=g.add_resident("UNEMPLOYED")
	check(g.current().assigned_count()<g.current().capacity() and g.assign(unemployed,0,"GATHER").begins_with("调度已提交"),"combat does not consume civilian capacity")
	for k in range(10):g.current().add_building("house",Vector2i(2+k*2,20),true)
	g.assign(unemployed,0,"GATHER")
	check(unemployed.profession=="GATHER","unemployed takes first profession")
	g.assign(unemployed,0,"BUILD")
	check(unemployed.profession=="GATHER","early fixed profession")
	var before=g.resident_count()
	g.worlds[1].s.status="OWNED"
	g.worlds[1].s.dock=true
	g.current().s.dock=true
	g.worlds[1].add_building("house",Vector2i(3,3),true)
	g.assign(unemployed,1,"GATHER")
	check(unemployed.island==1 and unemployed.travel==5,"real cross island travel timer")
	check(g.resident_count()==before,"resident transfer conserves population")
	# Repair is instant and capped independently from defense.
	var core=g.current().core()
	core.hp=20
	g.current().s.repaired=0
	g.current().repair(core)
	check(g.current().s.repaired<=g.current().non_def_max()*.25+.001,"daily nondefense repair cap")
	var damaged_hp=core.hp
	g.current().s.repaired=g.current().non_def_max()*.25
	g.current().repair(core)
	check(core.hp==damaged_hp,"repair stops at cap")
	# Research budgets are exhaustive and do not use kills/perfect defense.
	var island_points=0
	for cfg in g.rules.islands:
		for n in cfg.points:island_points+=n
	island_points+=2
	var player_points=0
	for n in g.rules.xp_rewards:player_points+=n
	check(island_points==15 and player_points==15,"exactly30 research obtainable")
	var cost=0
	for n in g.rules.tree_cost:cost+=n
	check(cost==30,"each tree costs30")
	var full=Sim.new()
	for k in range(12):full.add_resident("UNEMPLOYED")
	full.research=8
	full.unlock("resident")
	check(full.pending_residents.size()==2 and full.resident_count()==12,"fixed resident rewards wait at global cap")
	full.unlock("resident")
	check(full.pending_residents.is_empty() and full.resident_count()==17,"fixed rewards delivered when capacity rises")
	full.dispose()
	for route in ["tech","resident","mixed"]:
		var route_game=Sim.new()
		route_game.research=30
		if route=="mixed":
			for k in range(3):route_game.unlock("tech");route_game.unlock("resident")
			check(route_game.tech==4 and route_game.resident_tree==4 and route_game.synergy()==3 and route_game.research==0,"mixed budget")
		else:
			for k in range(5):route_game.unlock(route)
			check(route_game.research==0 and route_game.synergy()==0,"pure route independence "+route)
			check(route_game.tech==6 if route=="tech" else route_game.resident_tree==6,"pure route reaches six "+route)
		route_game.dispose()
	# Save round trip includes cooldowns, vectors, residents, footprints, remaining time.
	g.remaining=37.25
	var snapshot=g.snapshot()
	var clone=Sim.new()
	clone.restore(JSON.parse_string(JSON.stringify(snapshot)))
	check(JSON.parse_string(JSON.stringify(clone.snapshot()))==JSON.parse_string(JSON.stringify(snapshot)),"snapshot exact roundtrip")
	check(clone.remaining==37.25,"save does not reset daytime timer")
	g.phase="NIGHT"
	check(g.save(9).contains("仅"),"night writes rejected")
	# Replays run the same full model, not an offscreen score approximation.
	g.dispose();clone.dispose()
	var a=Sim.new()
	a.phase="DAY"
	a.worlds[1].s.status="OWNED"
	a.worlds[2].s.status="OWNED"
	a.player.pos=Vector2(840,840)
	a.day=1
	a.remaining=.05
	var b=Sim.new()
	b.restore(JSON.parse_string(JSON.stringify(a.snapshot())))
	for k in range(1200):a.tick(.05);b.tick(.05)
	check(JSON.parse_string(JSON.stringify(a.snapshot()))==JSON.parse_string(JSON.stringify(b.snapshot())),"deterministic1200tick replay")
	a.dispose();b.dispose()
	# Fixed-time phase transitions: no shortcut input or premature clearing.
	var timed=Sim.new()
	timed.phase="DAY";timed.remaining=100
	timed.current().core().hp=100000;timed.current().core().max_hp=100000
	timed.player.pos=Vector2(850,850)
	for k in range(1999):timed.tick(.05)
	check(timed.phase=="DAY","day lasts100seconds")
	timed.tick(.05)
	check(timed.phase=="TRANSITION" and timed.remaining==2,"night transition starts after100seconds")
	for k in range(39):timed.tick(.05)
	check(timed.phase=="TRANSITION","transition lasts2seconds")
	timed.tick(.05)
	check(timed.phase=="NIGHT" and timed.remaining==80,"night starts after full transition")
	for k in range(1599):timed.tick(.05)
	check(timed.phase=="NIGHT","night lasts80seconds")
	timed.tick(.05)
	check(timed.phase=="RESULT","night ends only at fixed timer")
	timed.dispose()
	# A fallen island retains at most five real enemies, suspends residents,
	# and requires both clearance and a fully repaired core to be reclaimed.
	var reclamation=Sim.new()
	reclamation.phase="NIGHT"
	reclamation.day=3
	reclamation.resources=[1000.0,1000.0,1000.0,1000.0]
	var fallen=reclamation.worlds[1]
	fallen.s.status="OWNED"
	fallen.core().hp=50
	var civilian=reclamation.add_resident("GATHER",1)
	civilian.job="food"
	for k in range(8):fallen.spawn(0,k%4)
	reclamation.finish_night()
	check(fallen.s.status=="TO_RECLAIM","undefended island can fall")
	check(fallen.s.enemies.size()==5,"residual enemies capped at five")
	var food_before=reclamation.resources[3]
	fallen.dawn()
	check(reclamation.resources[3]==food_before,"sheltered residents consume no food")
	reclamation.phase="DAY"
	fallen.tick(.05)
	check(reclamation.resources[3]==food_before,"fallen island suspends production")
	reclamation.active=1
	fallen.s.enemies.clear()
	fallen.tick(.05)
	check(fallen.s.status=="TO_RECLAIM","enemy clearance alone does not reclaim")
	fallen.s.repaired=9999.0
	fallen.repair(fallen.core())
	check(fallen.core().hp==fallen.core().max_hp,"reclamation repair bypasses daily cap")
	fallen.tick(.05)
	check(fallen.s.status=="OWNED" and civilian.travel==1.0,"reclaimed residents return after one second")
	reclamation.dispose()
	# Ten nights: verify every wave schedule using normal ticks, with a documented
	# durable-core fixture. This is scheduling coverage, NOT a balanced playthrough.
	var fixture=Sim.new()
	fixture.player.pos=Vector2(840,840)
	for w in fixture.worlds:
		w.s.status="OWNED"
		w.core().hp=100000
		w.core().max_hp=100000
	var wave_total=0
	for day in range(1,11):
		fixture.day=day
		fixture.phase="NIGHT"
		fixture.remaining=80
		for i in range(3):fixture.worlds[i].begin_night(day,i)
		for k in range(1599):fixture.tick(.05)
		for w in fixture.worlds:
			check(w.s.cursor==w.s.wave.size(),"all batches spawned day%d %s"%[day,w.cfg.id])
			wave_total+=w.s.cursor
			w.s.enemies=[]
		fixture.tick(.05)
		check(fixture.phase not in ["DAY","TRANSITION"],"no early night skip")
	fixture.dispose()
	var team=Sim.new()
	team.phase="DAY"
	team.tech=6
	var site=team.current().add_building("wall",Vector2i(11,14),false)
	site.level=2
	var crew_a=team.add_resident("BUILD",0)
	var crew_b=team.add_resident("BUILD",0)
	var crew_c=team.add_resident("BUILD",0)
	var standby=team.current().add_building("house",Vector2i(3,3),true)
	team.current().assign_workplace(crew_c,standby)
	team.current().assign_builder(site,crew_a)
	team.current().assign_builder(site,crew_b)
	check(team.current().site_builders(site).size()==2,"two builders share one site")
	team.current().assign_builder(site,crew_c)
	check(crew_c.job!=site.id,"third builder rejected without changing assignment")
	crew_a.pos=team.current().pos(site)+Vector2(0,34)
	crew_b.pos=crew_a.pos
	team.current().tick(.05)
	for k in range(20):
		if crew_a.get("working",false) and crew_b.get("working",false):break
		team.current().tick(.05)
	var progress_before=site.progress
	team.current().tick(.05)
	check(is_equal_approx(site.progress-progress_before,.24),"two arrived builders contribute construction speed")
	team.current().unstation(crew_a)
	check(team.current().site_builders(site).size()==1,"dragging worker away releases site slot")
	team.travel.time=3.0
	var hp_before=team.player.hp
	team.current().hurt_target("player",20)
	check(team.player.hp==hp_before,"cached enemy target cannot hurt sailing player")
	team.travel.time=0.0
	team.worlds[1].hurt_target("player",20)
	check(team.player.hp==hp_before,"offscreen island cannot hurt player on another island")
	team.phase="RESULT"
	team.begin_travel(1)
	check(team.travel.time==0.0,"result screen cannot start sailing")
	team.phase="DAY"
	team.begin_travel(9)
	check(team.travel.time==0.0,"invalid destination rejected")
	team.current().remove_building(site,true)
	check(crew_b.job=="build","removed construction site releases its builders")
	team.dispose()
	var report={"checks":checks,"failures":failures,"wave_entries":wave_total,"scope":"simulation unit/integration; durable-core ten-night scheduling fixture; not human acceptance or route balance"}
	var file=FileAccess.open("res://verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=[]
var checks=0
func check(value,name):
	checks+=1
	if not value:failures.append(name);push_error(name)
func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func run():
	var g=Sim.new();g.start();var w=g.current()
	check(g.resources[0]==0 and g.resources[1]==0,"initial building materials must be gathered")
	check(w.s.nodes.any(func(n):return n.get("form","")=="log"),"loose wood nodes exist")
	check(w.s.nodes.any(func(n):return n.kind==1),"stone piles exist")
	g.player.pos=w.camp_position();g.interact()
	w.s.camp_waiting=2 # independent camp-capacity fixture after the initial recruit
	var worker=w.s.residents[0]
	check(worker.profession=="UNEMPLOYED" and w.builders().is_empty(),"rescue grants no automatic profession")
	g.assign(worker,0,"BUILD")
	check(worker.profession=="BUILD" and worker.max_hp==60,"day1 manual profession assignment updates health")
	g.player.pos=w.camp_position();g.interact()
	check(g.resident_count()==2 and w.s.camp_waiting==1,"camp rescue consumes one waiting resident")
	g.interact()
	check(g.resident_count()==3 and w.s.camp_waiting==0,"camp rescue remains unemployed")
	check(g.pool.all(func(r):return r.profession=="UNEMPLOYED"),"overflow camp residents wait in common pool")
	var wood=w.s.nodes.filter(func(n):return n.kind==0)[0]
	g.player.pos=Vector2(wood.cell)*32+Vector2(16,16)
	g.gather(1.0)
	check(g.resources[0]==4,"collect natural wood before construction")
	for node in w.s.nodes:node.amount=0
	w.dawn()
	check(w.s.nodes.all(func(n):return n.amount==n.max),"daily nodes fully refill")
	check(w.s.camp_waiting==2,"camp receives daily arrivals")
	var first=null
	for y in range(2,24):
		for x in range(2,23):
			if w.can_place("wall",Vector2i(x,y))=="" and w.can_place("wall",Vector2i(x+1,y))=="" and w.can_place("wall",Vector2i(x+2,y))=="":first=Vector2i(x,y);break
		if first!=null:break
	check(first!=null,"find legal three-segment wall")
	var count=w.s.buildings.size();var before=g.resources.duplicate()
	w.place_wall_line(first,first+Vector2i(2,0))
	check(w.s.buildings.size()==count and g.resources==before,"insufficient batch materials leave world unchanged")
	g.resources=[100.0,100.0,0.0,20.0]
	var cost=g.rules.buildings.wall.cost
	var result=w.place_wall_line(first,first+Vector2i(2,0))
	print("BATCH ",first," ",result)
	check(result.begins_with("已创建") and w.s.buildings.size()==count+3,"batch confirms all three paid sites")
	check(g.resources[0]==100-cost[0]*3 and g.resources[1]==100-cost[1]*3,"batch charges exact whole-line cost")
	g.player.pos=Vector2(first)*32+Vector2(40,65)
	for k in range(650):g.tick(.05)
	var walls=w.s.buildings.filter(func(b):return b.kind=="wall")
	if walls.is_empty():g.dispose();quit(1);return
	check(walls.all(func(b):return b.progress>=b.duration),"one builder completes whole wall queue before automation technology")
	check(not w.worker_blocked(worker.pos),"builder ends outside completed wall collision")
	var remote_site=w.add_building("wall",Vector2i(11,14),false)
	w.assign_builder(remote_site,worker)
	worker.work_path=[];worker.path_site=remote_site.id;worker.path_version=w.s.buildings.size();worker.path_retry=0
	g.player.pos=Vector2(850,850)
	for k in range(500):g.tick(.05)
	check(remote_site.progress>=remote_site.duration,"builder recovers empty cached route and completes while player is far away")
	worker.pos=w.pos(walls[-1]);g.tick(.05)
	check(not w.worker_blocked(worker.pos),"legacy trapped builder can be relocated safely")
	walls[-1].hp-=10
	worker.pos=w.pos(walls[-1])+Vector2(0,45)
	w.repair(walls[-1])
	check(walls[-1].hp==walls[-1].max_hp and w.fx.any(func(f):return f.kind=="repair"),"wall repair is instant with animated feedback")
	check(worker.get("repair_time",0)>0,"nearby builder plays repair animation")
	before=g.resources.duplicate();count=w.s.buildings.size()
	w.place_wall_line(w.core().cell,w.core().cell+Vector2i(2,0))
	check(before==g.resources and count==w.s.buildings.size(),"blocked wall line never partially spends resources")
	while g.resident_count()<g.resident_limit():g.add_resident("UNEMPLOYED")
	g.player.pos=w.camp_position();var waiting=w.s.camp_waiting
	g.interact()
	check(w.s.camp_waiting==waiting and g.pending_residents.is_empty(),"full population does not consume camp residents or create hidden grants")
	var clone=Sim.new()
	check(clone.restore(JSON.parse_string(JSON.stringify(g.snapshot()))),"new camp and worker paths survive save roundtrip")
	clone.dispose();g.dispose()
	var report={"checks":checks,"failures":failures,"scope":"new material, unemployed, camp, builder path, animation and atomic wall-line rules"}
	var f=FileAccess.open("res://settlement-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)

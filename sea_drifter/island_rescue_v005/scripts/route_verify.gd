extends SceneTree
## A reproducible controller using normal movement, gathering, paid building,
## upgrades and combat. Failure is a controller result, never proof of impossibility.
const Sim=preload("res://scripts/simulation.gd")
var g
var route=""
var records=[]
var route_runs=[]
var ticks=0
var combat_path=PackedVector2Array()
var combat_cursor=0
func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1")
	call_deferred("run")
func step():
	g.tick(.05);ticks+=1
func navigation_path(p):
	var nav=AStarGrid2D.new()
	var size=int(g.current().cfg.size)
	nav.region=Rect2i(-2,-2,size+4,size+4);nav.cell_size=Vector2(16,16)
	nav.region=Rect2i(-4,-4,size*2+8,size*2+8)
	nav.offset=Vector2(8,8);nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for building in g.current().s.buildings:
		if building.kind not in ["wall","htower"]:continue
		var rect=Rect2(Vector2(building.cell)*32,Vector2(g.rules.buildings[building.kind].w,g.rules.buildings[building.kind].h)*32).grow(7)
		for x in range(size*2):
			for y in range(size*2):
				if rect.has_point(Vector2(x*16+8,y*16+8)):nav.set_point_solid(Vector2i(x,y))
	return nav.get_point_path(Vector2i((g.player.pos/16).floor()),Vector2i((p/16).floor()))
func go(p,limit=500):
	var path=navigation_path(p)
	var cursor=1
	for k in range(limit):
		if g.player.pos.distance_to(p)<10:return true
		if g.phase!="DAY" or g.remaining<3:return false
		while cursor<path.size() and g.player.pos.distance_to(path[cursor])<7:cursor+=1
		var destination=path[cursor] if cursor<path.size() else p
		g.move((destination-g.player.pos).normalized(),.05);step()
	return false
func affordable(cost):
	for k in range(cost.size()):
		if g.resources[k]+.0001<cost[k]:return false
	return true
func research():
	for k in range(10):
		var tree=route if route!="mixed" else ("tech" if g.tech<=g.resident_tree else "resident")
		var level=g.tech if tree=="tech" else g.resident_tree
		if level>=6 or (route=="mixed" and level>=4):break
		if g.research<g.rules.tree_cost[level]:break
		g.unlock(tree)
func build(kind):
	var w=g.current()
	if w.builders().is_empty() or not affordable(g.rules.buildings[kind].cost):return false
	var candidates=[]
	for x in range(2,int(w.cfg.size)-3):
		for y in range(2,int(w.cfg.size)-3):
			var cell=Vector2i(x,y)
			if Vector2(cell*32).distance_to(w.pos(w.core()))<210:candidates.append(cell)
	candidates.sort_custom(func(a,b):return Vector2(a*32).distance_to(w.pos(w.core()))<Vector2(b*32).distance_to(w.pos(w.core())))
	for cell in candidates:
		if w.can_place(kind,cell)!="":continue
		w.place(kind,cell)
		var b=w.s.buildings[-1]
		go(w.pos(b)+Vector2(-26,52))
		for k in range(300):
			if b.progress>=b.duration or g.phase!="DAY":break
			step()
		return b.progress>=b.duration
	return false
func staffing():
	var w=g.current()
	for r in w.s.residents.duplicate():
		if r.profession=="UNEMPLOYED":g.assign(r,g.active,"BUILD" if w.builders().is_empty() else "RANGED")
	for r in g.pool.duplicate():
		if w.s.residents.size()>=w.capacity():break
		g.assign(r,g.active,("BUILD" if w.builders().is_empty() else "RANGED") if r.profession=="UNEMPLOYED" else r.profession)
	for b in w.s.buildings:
		if b.kind!="htower" or b.progress<b.duration:continue
		for r in w.active_residents():
			if r.tower!="" or r.profession=="BUILD":continue
			if g.synergy()>0:g.set_station(r,"mortar" if g.synergy()>=3 else "cannon" if g.synergy()>=2 else "")
			w.station(r.id,b)
func harvest_one():
	var w=g.current()
	var best=null
	var score=INF
	for node in w.s.nodes:
		if node.amount<.001 or g.resources[node.kind]>=g.stock_limit()-.1:continue
		var demand=[180,110,20,30][node.kind]
		var weight=max(.1,1-g.resources[node.kind]/demand)
		if node.kind==0 and g.resources[0]<150:weight*=5
		if node.kind==3 and g.resources[3]>20:weight*=.1
		var s=(g.player.pos.distance_to(Vector2(node.cell)*32+Vector2(16,16))+35)/weight
		if s<score:best=node;score=s
	if best==null:return false
	if not go(Vector2(best.cell)*32+Vector2(16,16)):return false
	for k in range(170):
		if best.amount<.001 or g.phase!="DAY" or g.remaining<4:break
		g.gather(.05);step()
	return true
func dock():
	var w=g.current()
	go(w.pos(w.s.buildings[1])-Vector2(0,55))
	g.interact()
	for k in range(300):
		if w.s.dock or w.s.buildings[1].progress>=w.s.buildings[1].duration or g.phase!="DAY":break
		step()
func sail(target):
	g.begin_travel(target)
	for k in range(150):
		if g.travel.time<=0:break
		step()
func daytime():
	var w=g.current()
	if g.active==0:
		if not g.story.artisan:go(w.camp_position());g.interact()
		if g.day>=2 and not g.story.settlers:go(w.pos(w.core())+Vector2(150,100));g.interact()
		staffing()
		if g.day>1:
			go(w.pos(w.core())+Vector2(0,65));w.repair(w.core())
	# Recover an occupied island using the same damage and repair commands.
	for i in range(1,3):
		if g.worlds[i].s.status!="TO_RECLAIM" or not g.worlds[i].s.dock or g.remaining<45:continue
		for k in range(10):
			if affordable([60,30,0]) or g.remaining<60:break
			if not harvest_one():break
		sail(i);w=g.current()
		for k in range(1000):
			if g.phase!="DAY" or g.remaining<20 or w.s.enemies.is_empty():break
			fight()
		go(w.pos(w.core())+Vector2(0,65))
		w.repair(w.core());step()
		if w.s.status=="OWNED":
			if w.capacity()<3:build("house")
			staffing()
			if g.tech>=2 and not w.s.buildings.any(func(b):return b.kind=="htower"):build("htower");staffing()
		if g.worlds[0].s.dock:sail(0)
	var attempts=0
	while g.phase=="DAY" and g.remaining>5 and attempts<150:
		attempts+=1;research();w=g.current()
		if w.s.status=="TO_RECLAIM":break
		if g.day>=4 and g.player.blade<4:
			var weapon_cost=[[0,10,5],[0,20,10],[0,35,18]][int(g.player.blade)-1]
			if affordable(weapon_cost):g.craft("blade")
		if g.day>=2 and not w.s.dock and affordable([30,10,0]):dock();continue
		if g.active==0 and w.s.level<4 and affordable(w.cfg.costs[int(w.s.level)-1]):
			go(w.pos(w.core())+Vector2(0,65));g.upgrade_core()
			for k in range(61):
				if g.base_upgrade.time<=0 or g.phase!="DAY":break
				step()
			if g.base_upgrade.time>0:break
			if g.message.begins_with("累计"):harvest_one()
			else:research()
		if g.day>=2 and g.active==0 and g.worlds[1].s.status=="LOCKED" and w.s.dock and g.resources[0]>=30 and g.resources[1]>=10:
			sail(1);dock();build("house");staffing();continue
		if g.day>=3 and g.worlds[2].s.status=="LOCKED" and w.s.dock and g.resources[0]>=30 and g.resources[1]>=10:
			sail(2);dock();build("house");staffing();continue
		staffing()
		if g.pool.size()>0 and w.capacity()<6 and affordable([25 if g.active>0 else 75,0,0]):
			if build("house"):staffing();continue
		var towers=w.s.buildings.filter(func(b):return b.kind=="htower")
		if g.tech>=2 and towers.size()<min(2,w.cfg.towers[int(w.s.level)-1]) and affordable(g.rules.buildings.htower.cost):
			if build("htower"):staffing();continue
		for tower in towers:
			if tower.level<min(3,g.tech-1) and affordable([0,15 if tower.level==1 else 25,8 if tower.level==1 else 15]):
				g.upgrade_building(tower);go(w.pos(tower)+Vector2(-26,52))
				for k in range(180):
					if tower.progress>=tower.duration or g.phase!="DAY":break
					step()
		if g.stock_limit()<300 and g.resources[0]>100 and g.resources[1]>60:
			if build("warehouse"):continue
		if not harvest_one():break
	if g.active!=0 and g.current().s.dock and g.worlds[0].s.dock:sail(0)
	while g.phase in ["DAY","TRANSITION"]:step()
func fight():
	var w=g.current()
	var target=null
	var distance=INF
	for e in w.s.enemies:
		if e.hp>0 and e.pos.distance_to(w.pos(w.core()))<distance:target=e;distance=e.pos.distance_to(w.pos(w.core()))
	if target!=null:
		distance=g.player.pos.distance_to(target.pos)
		if distance>45:
			if ticks%20==0 or combat_path.is_empty():combat_path=navigation_path(target.pos);combat_cursor=1
			while combat_cursor<combat_path.size() and g.player.pos.distance_to(combat_path[combat_cursor])<7:combat_cursor+=1
			var p=combat_path[combat_cursor] if combat_cursor<combat_path.size() else target.pos
			g.move((p-g.player.pos).normalized(),.05)
		if distance<60:g.attack(target.pos-g.player.pos)
	if g.player.hp<g.player.max_hp-20:g.heal()
	step()
func run():
	for selected in ["tech","resident","mixed"]:
		route=selected;g=Sim.new();g.start();records=[];ticks=0;combat_path=PackedVector2Array()
		for d in range(10):
			if g.phase!="DAY":break
			daytime()
			while g.phase=="NIGHT":fight()
			records.append({"day":g.day,"phase":g.phase,"stock":g.resources.duplicate(),"hp":g.player.hp,"core":g.worlds[0].core().hp,"tech":g.tech,"resident_tree":g.resident_tree,"earned_research":g.earned_research,"islands":g.worlds.map(func(w):return {"status":w.s.status,"level":w.s.level,"hp":w.core().hp})})
			if g.phase=="RESULT":g.next_day()
		route_runs.append({"route":route,"ending":g.phase,"ticks":ticks,"days":records.duplicate(true)})
		g.dispose()
	var report={"scope":"unmodified initial resources and paid player commands; controller failure does not prove route impossible; tree spending follows a route but full30point progression is not guaranteed","runs":route_runs}
	var f=FileAccess.open("res://route-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit()

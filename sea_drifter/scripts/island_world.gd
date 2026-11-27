extends RefCounted
## All islands use this exact model, irrespective of rendering or input.
var g
var cfg = {}
var s = {}
var fx = []
var enemy_grid = {}
var building_index = {}
var building_grid = {}
var navigation_cache=null
var navigation_key=""
var topology_revision=0
var body_revision=Vector3i(-1,-1,-1)
var body_cache=[]
var collision_grid={}
var body_layout_key=""

func _init(game, definition):
	g = game
	cfg = definition
	var n = int(cfg.size)
	s = {"id":cfg.id,"status":"LOCKED","level":1,"buildings":[],"residents":[],"enemies":[],"nodes":[],"wave":[],"cursor":0,"night_elapsed":0.0,"first_attack":true,"power":0,"used":0,"repaired":0.0,"hurt":false,"bonus":0.0,"dock":false,"occupancy":{},"waypoints":[],"edges":[],"repair_queue":[]}
	var center = Vector2i(n / 2 - 1, n / 2 - 1)
	add_building("core", center, true)
	s.buildings[0].hp = cfg.hps[0]
	s.buildings[0].max_hp = cfg.hps[0]
	add_building("dock", Vector2i(n / 2 - 1,n - 2), true)
	s.buildings[1].hp = 35.0
	s.camp_waiting=2
	s.camp_day=1
	# Four coast entries, two waypoints per arm, then the central junction.
	var mid = int(n / 2)
	s.waypoints = [Vector2i(0,mid),Vector2i(mid,0),Vector2i(n-1,mid),Vector2i(mid,n-1),Vector2i(3,mid),Vector2i(mid,3),Vector2i(n-4,mid),Vector2i(mid,n-4),Vector2i(mid-4,mid),Vector2i(mid,mid-4),Vector2i(mid+4,mid),Vector2i(mid,mid+4),Vector2i(mid,mid)]
	s.edges = [[0,4],[4,8],[8,12],[1,5],[5,9],[9,12],[2,6],[6,10],[10,12],[3,7],[7,11],[11,12],[8,9],[9,10],[10,11],[11,8]]
	var index = 0
	for kind in range(4):
		for j in range(int(cfg.nodes[kind])):
			var cell = Vector2i(2 + (index * 5) % (n-5), 2 + (index * 7) % (n-5))
			while reserved(cell) or node_at(cell) != null:
				cell.x = (cell.x + 1) % (n-3) + 1
				if cell.x % 3 == 0: cell.y = (cell.y + 2) % (n-3) + 1
			var amount = [15,10,8,12][kind]
			if cfg.nodes[kind] == 1 and kind == 2: amount = 60
			s.nodes.append({"kind":kind,"cell":cell,"amount":float(amount),"max":float(amount),"form":"log" if kind==0 and j%2==0 else "natural"})
			index += 1

func core():
	return s.buildings[0]

func camp_position():
	return pos(core())+Vector2(-170,-140)

func pos(b):
	var d = g.rules.buildings[b.kind]
	return (Vector2(b.cell) + Vector2(d.w,d.h)*0.5)*32

func node_at(cell):
	for node in s.nodes:
		if node.cell == cell and node.amount > 0: return node
	return null

func reserved(cell):
	return Rect2i(core().cell-Vector2i.ONE,Vector2i(5,5)).has_point(cell) or Rect2i(s.buildings[1].cell-Vector2i(2,2),Vector2i(7,6)).has_point(cell) or Rect2(camp_position()-Vector2(64,48),Vector2(128,96)).has_point(Vector2(cell)*32+Vector2(16,16)) or cell in s.waypoints

func cells(kind, origin):
	var result = []
	var d = g.rules.buildings[kind]
	for x in range(d.w):
		for y in range(d.h): result.append(origin + Vector2i(x,y))
	return result

func add_building(kind, origin, complete=false):
	var d = g.rules.buildings[kind]
	var b = {"id":g.uid(),"kind":kind,"cell":origin,"level":1,"hp":float(d.hp),"max_hp":float(d.hp),"progress":float(d.time) if complete else 0.0,"duration":float(d.time),"occupants":[],"timers":{},"cooldown":0.0,"powered":true,"wall_link":false,"cost":d.cost.duplicate(),"upgrade":0,"worker":-1}
	s.buildings.append(b)
	occupy(b)
	recompute()
	return b

func occupy(b):
	topology_revision+=1
	for cell in cells(b.kind,b.cell): s.occupancy[cell] = b.id
	building_index[b.id] = b
	var grid = Vector2i((pos(b)/96).floor())
	if not building_grid.has(grid): building_grid[grid] = []
	building_grid[grid].append(b)

func release(b):
	topology_revision+=1
	for cell in cells(b.kind,b.cell): s.occupancy.erase(cell)
	building_index.erase(b.id)
	var grid = Vector2i((pos(b)/96).floor())
	if building_grid.has(grid): building_grid[grid].erase(b)

func active_residents():
	if s.status == "TO_RECLAIM": return []
	return s.residents.filter(func(r): return not r.retreated and r.travel <= 0)

func builders():
	return active_residents().filter(func(r): return r.profession == "BUILD" and r.tower == "")

func site_builders(b):
	return builders().filter(func(r):return r.job==b.id)

func building_body(b):
	var d=g.rules.buildings[b.kind]
	return Rect2(Vector2(b.cell)*32,Vector2(d.w,d.h)*32)

func collision_signature():
	return Vector3i(topology_revision,int(g.day>=2),int(g.story.settlers))

func collision_rects():
	var revision=collision_signature()
	if revision==body_revision:return body_cache
	var result=[]
	body_layout_key=str(g.day>=2)+str(g.story.settlers)
	for b in s.buildings:
		result.append(building_body(b).grow(7))
		body_layout_key+=str(b.id)+str(b.cell)+b.kind+";"
	# Only the ground footprint is solid, not roofs, foliage or interface labels.
	result.append(Rect2(camp_position()+Vector2(-60,-18),Vector2(120,43)).grow(7))
	if g.day>=2 and not g.story.settlers and g.worlds.find(self)==0:
		result.append(Rect2(pos(core())+Vector2(118,74),Vector2(64,37)).grow(7))
	collision_grid.clear()
	for rect in result:
		var low=Vector2i((rect.position/64).floor());var high=Vector2i((rect.end/64).floor())
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1):
				var key=Vector2i(x,y)
				if not collision_grid.has(key):collision_grid[key]=[]
				collision_grid[key].append(rect)
	body_cache=result;body_revision=revision
	return result

func worker_blocked(p):
	collision_rects()
	for rect in collision_grid.get(Vector2i((p/64).floor()),[]):
		if rect.has_point(p):return true
	return false

func safe_worker_position(p):
	if not worker_blocked(p):return p
	var best=p;var distance=INF
	# Recover old saves/spawns or new building footprints at the nearest free edge.
	for rect in collision_rects():
		for candidate in [Vector2(rect.position.x-.1,clamp(p.y,rect.position.y,rect.end.y)),Vector2(rect.end.x+.1,clamp(p.y,rect.position.y,rect.end.y)),Vector2(clamp(p.x,rect.position.x,rect.end.x),rect.position.y-.1),Vector2(clamp(p.x,rect.position.x,rect.end.x),rect.end.y+.1)]:
			if not worker_blocked(candidate) and p.distance_squared_to(candidate)<distance:best=candidate;distance=p.distance_squared_to(candidate)
	return best

func move_actor(origin,destination):
	var point=safe_worker_position(origin)
	var delta=destination-origin
	var steps=max(1,int(ceil(delta.length()/4.0)))
	var step=delta/steps
	for i in range(steps):
		var next=point+step
		if not worker_blocked(next):point=next;continue
		var horizontal=point+Vector2(step.x,0)
		if not worker_blocked(horizontal):point=horizontal
		var vertical=point+Vector2(0,step.y)
		if not worker_blocked(vertical):point=vertical
	return point

func navigation():
	collision_rects()
	var key=body_layout_key
	if navigation_cache!=null and key==navigation_key:return navigation_cache
	var nav=AStarGrid2D.new()
	nav.region=Rect2i(0,0,int(cfg.size)*2,int(cfg.size)*2);nav.cell_size=Vector2(16,16);nav.offset=Vector2(8,8)
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;nav.update()
	var bodies=collision_rects()
	for y in range(nav.region.size.y):
		for x in range(nav.region.size.x):
			var point=Vector2(x*16+8,y*16+8)
			for rect in bodies:
				if rect.has_point(point):nav.set_point_solid(Vector2i(x,y));break
	navigation_key=key;navigation_cache=nav
	return nav

func nav_cell(p,nav):
	var center=Vector2i((p/16).floor())
	if nav.region.has_point(center) and not nav.is_point_solid(center):return center
	for radius in range(1,nav.region.size.x):
		var best=Vector2i(-1,-1);var distance=INF
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				if abs(x)!=radius and abs(y)!=radius:continue
				var cell=center+Vector2i(x,y)
				if not nav.region.has_point(cell) or nav.is_point_solid(cell):continue
				var delta=(Vector2(cell)*16+Vector2(8,8)).distance_squared_to(p)
				if delta<distance:distance=delta;best=cell
		if best.x>=0:return best
	return Vector2i(-1,-1)

func work_reachable(worker,b):
	if worker_blocked(worker.pos):return false
	var body=building_body(b)
	var nearest=worker.pos.clamp(body.position,body.end)
	return worker.pos.distance_to(nearest)<=28

func worker_path(worker,b):
	worker.pos=safe_worker_position(worker.pos)
	var nav=navigation();var start=nav_cell(worker.pos,nav)
	if start.x<0:return PackedVector2Array()
	var best=PackedVector2Array()
	var area=building_body(b).grow(28)
	var low=Vector2i((area.position/16).floor());var high=Vector2i((area.end/16).ceil())
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			var cell=Vector2i(x,y)
			if not nav.region.has_point(cell) or nav.is_point_solid(cell):continue
			var p=Vector2(cell)*16+Vector2(8,8)
			var body=building_body(b)
			if p.distance_to(p.clamp(body.position,body.end))>28:continue
			var path=nav.get_point_path(start,cell)
			if not path.is_empty() and (best.is_empty() or path.size()<best.size()):best=path
	return best

func move_builder(worker,b,dt):
	worker.pos=safe_worker_position(worker.pos)
	if work_reachable(worker,b):worker.stuck_time=0.0;return true
	navigation()
	worker.path_retry=max(0.0,worker.get("path_retry",0.0)-dt)
	var exhausted=worker.get("path_cursor",0)>=worker.get("work_path",[]).size()
	if worker.get("path_site","")!=b.id or str(worker.get("path_version",""))!=navigation_key or (exhausted and worker.path_retry<=0) or worker.get("stuck_time",0.0)>.4:
		worker.work_path=Array(worker_path(worker,b));worker.path_cursor=0
		worker.path_site=b.id;worker.path_version=navigation_key;worker.path_retry=.25;worker.stuck_time=0.0
	while worker.path_cursor<worker.work_path.size() and worker.pos.distance_to(worker.work_path[worker.path_cursor])<1:worker.path_cursor+=1
	var previous=worker.pos
	if worker.path_cursor<worker.work_path.size():worker.pos=move_actor(worker.pos,worker.pos.move_toward(worker.work_path[worker.path_cursor],80*dt))
	worker.stuck_time=worker.get("stuck_time",0.0)+dt if worker.pos.distance_to(previous)<.01 else 0.0
	return work_reachable(worker,b)

func move_resident(actor,target,speed,dt):
	var point=actor.pos
	if worker_blocked(point):point=safe_worker_position(point);actor.pos=point
	collision_rects()
	var revision=body_layout_key
	var target_cell=Vector2i((target/16).floor())
	var follow=str(actor.get("walk_revision",""))==revision and actor.get("walk_target",Vector2i(-1,-1))==target_cell and actor.get("walk_cursor",0)<actor.get("walk_path",[]).size()
	if not follow:
		var direct=point.move_toward(target,speed*dt)
		# Ordinary movement needs no A*: only route around an encountered obstacle.
		if not worker_blocked(direct):return move_actor(point,direct)
		var nav=navigation();var end=nav_cell(target,nav);var start=nav_cell(point,nav)
		if start.x<0 or end.x<0:return point
		actor.walk_path=Array(nav.get_point_path(start,end));actor.walk_cursor=0
		actor.walk_revision=revision;actor.walk_target=target_cell;actor.walk_stuck=0.0
	while actor.walk_cursor<actor.walk_path.size() and point.distance_to(actor.walk_path[actor.walk_cursor])<1:actor.walk_cursor+=1
	var goal=actor.walk_path[actor.walk_cursor] if actor.walk_cursor<actor.walk_path.size() else safe_worker_position(target)
	var next=move_actor(point,point.move_toward(goal,speed*dt))
	actor.walk_stuck=actor.get("walk_stuck",0.0)+dt if next.distance_to(point)<.01 else 0.0
	if actor.walk_stuck>.4:actor.walk_revision=""
	return next

func wall_line(a,b):
	var result=[a]
	var cell=a
	while cell!=b and result.size()<40:
		if cell.x!=b.x:cell.x+=int(sign(b.x-cell.x));result.append(cell)
		if cell.y!=b.y and result.size()<40:cell.y+=int(sign(b.y-cell.y));result.append(cell)
	return result

func place_wall_line(a,b):
	var line=wall_line(a,b)
	if line[-1]!=b:return "单次最多40段，请缩短墙线"
	var clone=g.get_script().new()
	if not clone.restore(g.snapshot()):clone.dispose();return "墙线校验失败：当前存档状态无效"
	clone.phase=g.phase
	for cell in line:
		var reason=clone.current().can_place("wall",cell)
		if reason!="":clone.dispose();return "墙线无效："+reason
		if not clone.spend(g.rules.buildings.wall.cost):clone.dispose();return "材料不足，整条墙线未创建"
		clone.current().add_building("wall",cell)
	clone.dispose()
	for cell in line:
		place("wall",cell)
		s.buildings[-1].batch=true
	return "已创建%d段墙体施工队列"%line.size()

func assign_builder(b, worker=null):
	if worker!=null and worker.job==b.id:return "工匠已在此工地"
	if site_builders(b).size()>=building_level(b):return "该工地人数已达建筑等级上限"
	if worker==null:
		for r in builders():
			if r.job in ["idle","build"]:
				worker=r
				break
	if worker==null:return "暂无空闲工匠，请在设施分配页指派"
	if s.status!="OWNED" or worker.profession!="BUILD" or worker.retreated or worker.travel>0:return "工匠当前不可施工"
	if b.progress>=b.duration:return "工地已经完工"
	if workplace_count(b.id,worker.id)>=building_level(b):return "该建筑岗位已满"
	unstation(worker)
	worker.workplace=b.id
	worker.job=b.id
	b.worker=worker.id
	return "已指派工匠到工地"

func building_level(b):
	return max(1,int(s.level if b.kind=="core" else b.level))
func capacity():
	var count=0
	for b in s.buildings:count+=building_level(b)
	return count
func assigned_count():
	return s.residents.filter(func(r):return r.profession in ["BUILD","GATHER"]).size()
func workplace_count(id,except_id=""):
	return s.residents.filter(func(r):return r.id!=except_id and r.profession in ["BUILD","GATHER"] and r.get("workplace","")==id).size()
func free_workplace(except_id=""):
	for b in s.buildings:
		if workplace_count(b.id,except_id)<building_level(b):return b
	return null
func assign_workplace(r,b):
	if s.status!="OWNED" or r.island!=g.worlds.find(self) or not building_index.has(b.id):return "请先完成本岛居民调度"
	if r.travel>0 or r.retreated:return "居民当前不可分配设施"
	if r.profession not in ["BUILD","GATHER"]:return "该岗位仅用于建造和收集"
	if r.profession=="GATHER" and b.progress<b.duration:return "该建筑尚未完工，请先安排工匠施工"
	if workplace_count(b.id,r.id)>=building_level(b):return "该建筑人数已达等级上限"
	r.workplace=b.id
	r.job=(b.id if b.progress<b.duration else "build") if r.profession=="BUILD" else (r.job if r.job in ["wood","stone","food"] else "wood")
	return "已分配到"+g.rules.buildings[b.kind].name
func normalize_workplaces():
	var counts={}
	for r in s.residents:
		if r.profession not in ["BUILD","GATHER"]:r.workplace="";continue
		var id=r.get("workplace","")
		if not building_index.has(id) or counts.get(id,0)>=building_level(building_index[id]):r.workplace=""
		else:counts[id]=counts.get(id,0)+1
	for r in s.residents:
		if r.profession not in ["BUILD","GATHER"] or r.get("workplace","")!="":continue
		var available=free_workplace(r.id)
		if available!=null:r.workplace=available.id
		else:
			unstation(r);r.profession="UNEMPLOYED";r.max_hp=50;r.hp=min(r.hp,50)

func can_place(kind, origin):
	var d = g.rules.buildings[kind]
	if g.phase not in ["DAY","NIGHT"]: return "当前阶段不能建造"
	if g.phase == "NIGHT" and (not s.enemies.is_empty() or s.cursor < s.wave.size()): return "本岛波次清空后才可建造"
	if s.status != "OWNED": return "先收复这座岛"
	if s.buildings.size() >= 45: return "建筑数量已达45座"
	if g.tech < d.tech: return "尚未解锁科技"
	if builders().is_empty(): return "需要本岛建造居民"
	if kind == "core" or kind == "dock": return "核心和码头使用固定位置"
	if kind == "htower" and s.buildings.filter(func(b):return b.kind == "htower").size() >= cfg.towers[int(s.level)-1]: return "已达本岛高塔数量上限"
	var footprint = cells(kind,origin)
	for c in footprint:
		if not Rect2i(0,0,int(cfg.size),int(cfg.size)).has_point(c): return "超出可建造区"
	for c in footprint:
		if s.occupancy.has(c): return "建筑占地重叠"
	for c in footprint:
		if node_at(c) != null: return "与资源点重叠"
	var area = Rect2i(origin,Vector2i(d.w,d.h))
	if Rect2(Vector2(origin)*32,Vector2(d.w,d.h)*32).intersects(Rect2(camp_position()-Vector2(64,48),Vector2(128,96))):return "难民营范围不可建造"
	if area.intersects(Rect2i(core().cell-Vector2i.ONE,Vector2i(5,5))): return "核心周围一格禁建"
	if area.intersects(Rect2i(s.buildings[1].cell-Vector2i(2,2),Vector2i(7,6))): return "码头周围两格禁建"
	# Placement flood fill only; enemy movement uses the waypoint graph below.
	var blocked = {}
	for b in s.buildings:
		if b.kind == "wall" or b.kind == "htower":
			for c in cells(b.kind,b.cell): blocked[c] = true
	if kind == "wall" or kind == "htower":
		for c in footprint: blocked[c] = true
	var reachable = {s.waypoints[12]:true}
	var queue = [s.waypoints[12]]
	var head = 0
	while head < queue.size():
		var cur = queue[head]
		head += 1
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var c = cur+step
			if Rect2i(0,0,int(cfg.size),int(cfg.size)).has_point(c) and not blocked.has(c) and not reachable.has(c):
				reachable[c] = true
				queue.append(c)
	for i in range(4):
		if not reachable.has(s.waypoints[i]): return "会封死入口到核心的通路"
	for c in footprint:
		if c in s.waypoints: return "不能覆盖敌人路点"
	return ""

func place(kind, origin):
	var reason = can_place(kind,origin)
	if reason != "": return reason
	if not g.spend(g.rules.buildings[kind].cost): return "材料不足"
	var b = add_building(kind,origin)
	b.worker=""
	assign_builder(b)
	if b.worker=="":return "工地已创建，请在居民设施分配中指派工匠"
	return "已安排居民施工；玩家和工匠在场时推进"

func recompute():
	s.power = 0
	s.used = 0
	for b in s.buildings:
		b.powered = b.progress >= b.duration
		if b.powered:
			s.power += g.rules.buildings[b.kind].output
			s.used += g.rules.buildings[b.kind].power
	for kind in ["repairer","collector","tesla"]:
		for b in s.buildings:
			if s.used > s.power and b.kind == kind and b.powered:
				b.powered = false
				s.used -= g.rules.buildings[kind].power
	for b in s.buildings:
		b.wall_link = b.kind == "wall" or (b.kind == "htower" and not b.occupants.is_empty())
	var changed = true
	while changed:
		changed = false
		for b in s.buildings:
			if b.kind != "htower" or b.wall_link: continue
			for other in s.buildings:
				if other.id != b.id and other.wall_link and Rect2i(b.cell-Vector2i.ONE,Vector2i(4,4)).intersects(Rect2i(other.cell,Vector2i(g.rules.buildings[other.kind].w,g.rules.buildings[other.kind].h))):
					b.wall_link = true
					changed = true
					break

func tower_form(b):
	if b.occupants.is_empty(): return "none"
	var r = resident(b.occupants[0])
	if r == null: return "none"
	if r.station in ["","archer"] and r.profession=="RANGED":return "archer"
	if r.station in ["musketeer","cannon"]:return "cannon"
	return "none"
	

func resident(id):
	for r in s.residents:
		if r.id == id: return r
	return null

func station(id, tower):
	if s.status != "OWNED": return "待收复岛屿的居民不可调度"
	var r = resident(id)
	if r == null or r.travel > 0 or r.retreated: return "居民不可用"
	if r.profession!="RANGED" or r.station not in ["","archer","musketeer","cannon"]:return "高塔只允许弓兵或火枪兵；迫击炮兵不可上塔"
	if r.profession.begins_with("HERO"): return "英雄不能驻守高塔"
	if tower.occupants.size() >= 3: return "高塔最多驻守3人"
	if tower.progress < tower.duration: return "请等待施工完成"
	if not tower.occupants.is_empty():
		var first = resident(tower.occupants[0])
		if (first.station in ["musketeer","cannon"]) != (r.station in ["musketeer","cannon"]): return "高塔只能驻同一职业与兵种"
	unstation(r)
	r.tower = tower.id
	r.job = tower.id
	r.pos = pos(tower)
	tower.occupants.append(id)
	tower.timers[str(id)] = 0.0
	recompute()
	return "已驻守高塔"

func assign_mortar(r,b):
	if s.status!="OWNED" or r.island!=g.worlds.find(self) or r.travel>0 or r.retreated:return "居民当前不可操作本岛阵列"
	if b.kind!="mortar_array" or b.progress<b.duration:return "请等待迫击炮阵列完工"
	if r.station!="mortar":return "只有迫击炮兵可以操作阵列"
	if s.residents.filter(func(other):return other.id!=r.id and other.job==b.id).size()>=building_level(b):return "阵列操作位已满"
	unstation(r);r.job=b.id;return "已分配迫击炮阵列"
func mortar_fire(b,point):
	var stats=g.rules.tower.mortar[min(2,building_level(b)-1)]
	if b.cooldown>0:return "迫击炮装填中"
	if pos(b).distance_to(point)>stats[2]:return "目标超出射程"
	for e in s.enemies.duplicate():
		if e.pos.distance_to(point)<=stats[3]:hurt_enemy(e,stats[0],pos(b),0)
	fx.append({"a":pos(b),"b":point,"life":.22,"damage":stats[0],"splash":stats[3]})
	b.cooldown=stats[1];return "迫击炮已发射"

func unstation(r):
	for b in s.buildings:
		if str(b.get("worker",""))==str(r.id):b.worker=""
		b.occupants.erase(r.id)
		b.timers.erase(str(r.id))
	r.tower = ""
	r.job = "idle"
	r.path_site=""
	recompute()

func remove_building(b, refund=false):
	for r in s.residents:
		if r.job==b.id:r.job="build" if r.profession=="BUILD" else "idle"
	if g.player.get("operating","")==b.id:g.player.operating=""
	for id in b.occupants.duplicate():
		var r = resident(id)
		if r == null: continue
		unstation(r)
		r.pos = pos(b) + Vector2(45,0)
		if not refund and r.profession != "MELEE": r.retreated = true
	release(b)
	s.buildings.erase(b)
	normalize_workplaces()
	if refund:
		for k in range(3): g.gain(k,b.cost[k])
	recompute()

func repair(b):
	var amount = b.max_hp-b.hp
	var defense = g.rules.buildings[b.kind].defense
	if not defense and s.status != "TO_RECLAIM": amount = min(amount,non_def_max()*0.25-s.repaired)
	amount = max(0,amount)
	if amount <= 0: return "无需修复或今日修复额度已用完"
	var coefficient = cfg.repair[int(s.level)-1]
	var cost = [ceil(amount*0.4*coefficient),ceil(amount*0.2*coefficient),0]
	if not g.spend(cost): return "修复材料不足"
	b.hp += amount
	if b.kind=="wall":
		fx.append({"kind":"repair","a":pos(b),"life":.7})
		for worker in builders():
			if worker.pos.distance_to(pos(b))<100:worker.repair_time=.7;worker.repair_target=pos(b)
	if not defense: s.repaired += amount
	return "已瞬时修复 %d HP" % amount

func non_def_max():
	var total = 0.0
	for b in s.buildings:
		if not g.rules.buildings[b.kind].defense: total += b.max_hp
	return total

func damage_rate():
	var hp = 0.0
	for b in s.buildings:
		if not g.rules.buildings[b.kind].defense: hp += b.hp
	return 1.0-hp/max(1.0,non_def_max())

func begin_night(day, index):
	s.wave = []
	s.cursor = 0
	s.night_elapsed = 0.0
	s.hurt = false
	var counts = g.rules.waves[day-1][index].duplicate()
	if s.first_attack and index > 0:
		for k in range(4): counts[k] = ceil(counts[k]*0.5) if k != 2 else 0
	var j = 0
	for kind in range(4):
		for k in range(int(counts[kind])):
			s.wave.append({"at":float((j % 3)*30),"kind":kind,"entry":j%4})
			j += 1
	s.wave.sort_custom(func(a,b):return a.at < b.at)
	if j > 0: s.first_attack = false

func spawn(kind, entry, location=null):
	if g.enemy_count() >= 120: return
	var d = g.rules.enemies[kind]
	var origin = Vector2(s.waypoints[entry])*32+Vector2(16,16) if location == null else location
	origin=safe_worker_position(origin)
	if location != null:
		var distance = INF
		for i in range(s.waypoints.size()):
			var delta = origin.distance_to(Vector2(s.waypoints[i])*32+Vector2(16,16))
			if delta < distance:
				distance = delta
				entry = i
	s.enemies.append({"id":g.uid(),"kind":kind,"hp":float(d.hp),"pos":origin,"cooldown":0.0,"retarget":0.0,"target":"","path":shortest_path(entry),"path_cursor":0,"summon":12.0})

func shortest_path(start):
	var dist = []
	var previous = []
	var todo = []
	for i in range(s.waypoints.size()):
		dist.append(INF)
		previous.append(-1)
		todo.append(i)
	dist[start] = 0.0
	while not todo.is_empty():
		var u = todo[0]
		for v in todo:
			if dist[v] < dist[u]: u = v
		todo.erase(u)
		if u == 12: break
		for edge in s.edges:
			var v = edge[1] if edge[0] == u else edge[0] if edge[1] == u else -1
			if v < 0: continue
			var a = Vector2(s.waypoints[u])*32
			var b = Vector2(s.waypoints[v])*32
			var cost = a.distance_to(b)
			for building in s.buildings:
				if building.kind == "barricade" and Geometry2D.get_closest_point_to_segment(pos(building),a,b).distance_to(pos(building)) < 48: cost *= 4
			if dist[u]+cost < dist[v]:
				dist[v] = dist[u]+cost
				previous[v] = u
	var result = [12]
	while result[0] != start and previous[result[0]] >= 0: result.push_front(previous[result[0]])
	return result

func target_for(e):
	var d = g.rules.enemies[e.kind]
	# Contact blockers always precede ranged priorities.
	var location = Vector2i((e.pos/32).floor())
	var contact = {}
	for x in range(location.x-1,location.x+2):
		for y in range(location.y-1,location.y+2):
			var id = s.occupancy.get(Vector2i(x,y),"")
			if id != "" and building_index.has(id): contact[id] = building_index[id]
	for b in contact.values():
		if b.kind!="dock" and building_body(b).grow(14).has_point(e.pos): return b.id
	if d.range > 18:
		var nearby = []
		var low = Vector2i(((e.pos-Vector2(d.range,d.range))/96).floor())
		var high = Vector2i(((e.pos+Vector2(d.range,d.range))/96).floor())
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1): nearby.append_array(building_grid.get(Vector2i(x,y),[]))
		for tier in range(3):
			var best = null
			var distance = INF
			for b in nearby:
				if b.kind == "dock": continue
				var bt = 0 if b.kind == "tesla" or (b.kind == "htower" and not b.occupants.is_empty()) else 1 if b.kind in ["wall","htower","barricade"] else 2
				var delta = e.pos.distance_to(pos(b))
				if bt == tier and delta <= d.range and delta < distance:
					best = b.id
					distance = delta
			if best != null: return best
	if g.player_is_here(self) and e.pos.distance_to(g.player.pos) < 24: return "player"
	for r in active_residents():
		if r.tower == "" and r.profession in ["MELEE","RANGED","HERO_MELEE","HERO_RANGED"] and r.pos.distance_to(e.pos) < 22: return r.id
	if e.pos.distance_to(pos(core())) < 60: return core().id
	return ""

func hurt_target(id, damage):
	if id == "player":
		if not g.player_is_here(self):return
		g.player.hp -= damage*(1.0-g.armor_reduction("player"))
		g.player["flash"] = 0.2
		return
	for b in s.buildings:
		if b.id == id:
			b.hp -= damage
			if not g.rules.buildings[b.kind].defense: s.hurt = true
			if b.hp <= 0:
				if b.kind == "core": b.hp = 0
				else: remove_building(b)
			return
	var r = resident(id)
	if r != null:
		r.hp -= damage*(1.0-g.armor_reduction(id))
		if r.hp <= 0:
			r.hp = 0
			r.retreated = true
			unstation(r)

func hurt_enemy(e, damage, origin, splash=0.0):
	if splash > 0:
		for other in s.enemies:
			if other.pos.distance_to(e.pos) <= splash: other.hp -= damage
	else: e.hp -= damage
	fx.append({"a":origin,"b":e.pos,"life":0.22,"damage":damage,"splash":splash,"kind":"hit"})

func closest_enemy(location, reach):
	var best = null
	var distance = reach
	var low = Vector2i(((location-Vector2(reach,reach))/96).floor())
	var high = Vector2i(((location+Vector2(reach,reach))/96).floor())
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			for e in enemy_grid.get(Vector2i(x,y),[]):
				if e.hp <= 0: continue
				var delta = location.distance_to(e.pos)
				if delta <= distance:
					best = e
					distance = delta
	return best

func tick(dt):
	if s.status == "LOCKED": return
	for effect in fx: effect.life -= dt
	fx = fx.filter(func(f):return f.life > 0)
	if g.phase == "NIGHT":
		s.night_elapsed += dt
		while s.cursor < s.wave.size() and s.wave[s.cursor].at <= s.night_elapsed:
			var item = s.wave[s.cursor]
			spawn(item.kind,item.entry)
			s.cursor += 1
	enemy_grid.clear()
	for e in s.enemies:
		var cell = Vector2i((e.pos/96).floor())
		if not enemy_grid.has(cell): enemy_grid[cell] = []
		enemy_grid[cell].append(e)
	for r in s.residents:
		r.repair_time=max(0.0,r.get("repair_time",0.0)-dt)
		r.motion_origin=r.pos
		r.moving=false
		r.working=r.repair_time>0
		if r.tower=="" and r.travel<=0 and worker_blocked(r.pos):r.pos=safe_worker_position(r.pos)
		if r.travel > 0: r.travel = max(0,r.travel-dt)
		if s.status == "TO_RECLAIM": continue
		if r.retreated or r.travel > 0 or r.tower != "": continue
		var factor = g.resident_factor(r)
		if r.profession == "GATHER" and r.job in ["wood","stone","food"]:
			var kind = ["wood","stone","iron","food"].find(r.job)
			var near = null
			for node in s.nodes:
				if node.kind == kind and node.amount > 0: near = node; break
			if near != null:
				r.pos = move_resident(r,Vector2(near.cell)*32+Vector2(16,16),70,dt)
				if r.pos.distance_to(Vector2(near.cell)*32+Vector2(16,16)) < 24:
					var amount = min(near.amount,([1.5,1.0,0,2.0][kind])*factor*dt)
					var collected = g.gain_resident_resource(kind,amount*(1+s.bonus))/(1+s.bonus)
					near.amount -= collected
					if collected > 0 and g.player_is_here(self): g.add_xp(int(ceil(collected)))
		if r.station=="mortar" and building_index.has(r.job) and building_index[r.job].kind=="mortar_array":
			var array=building_index[r.job]
			r.pos=move_resident(r,pos(array)+Vector2(0,g.rules.buildings.mortar_array.h*16+15),70,dt)
			continue
		if r.profession in ["MELEE","RANGED","HERO_MELEE","HERO_RANGED"]:
			var melee = r.profession in ["MELEE","HERO_MELEE"]
			var target = closest_enemy(r.pos,180 if melee else 150)
			if target == null:
				r.pos = move_resident(r,pos(core())+Vector2(0,70),40,dt)
				continue
			var stats = g.resident_combat(r)
			r.cooldown -= dt
			if r.pos.distance_to(target.pos) > stats[2]: r.pos = move_resident(r,target.pos,80,dt)
			elif r.cooldown <= 0.000001:
				r.facing=(target.pos-r.pos).normalized()
				r.attacks += 1
				hurt_enemy(target,stats[0]*g.resident_factor(r,true),r.pos,20 if r.profession == "HERO_MELEE" and r.attacks%3 == 0 else 0)
				r.cooldown = stats[1]
	for b in s.buildings.duplicate():
		if b.progress < b.duration:
			if g.tech>=6 or b.get("batch",false):
				for slot in range(building_level(b)-site_builders(b).size()):assign_builder(b)
			var crew=site_builders(b)
			var speed=0.0
			for worker in crew:
				if worker.tower!="" or worker.travel>0:continue
				var previous=worker.pos
				var arrived=move_builder(worker,b,dt)
				worker.moving=worker.pos.distance_to(previous)>.01
				if not arrived:continue
				speed+=1.6*g.resident_factor(worker)*(1.5 if g.tech>=6 else 1.0)
				worker.working=true;worker.repair_target=pos(b);worker.facing=(pos(b)-worker.pos).normalized()
			b.progress+=dt*speed
			if b.progress >= b.duration:
				if b.upgrade > 0:
					b.level = b.upgrade
					b.upgrade = 0
					b.max_hp = [70,90,110][int(b.level)-1] if b.kind == "htower" else 190 if b.kind=="wall" else g.rules.buildings[b.kind].hp*(1+.3*(b.level-1))
					b.hp = b.max_hp
				g.add_xp(3)
				for worker in crew:
					worker.job="build";worker.pos=safe_worker_position(worker.pos);worker.working=false
				b.worker=""
				if b.kind == "dock":
					b.hp = b.max_hp
					s.dock = true
				recompute()
			continue
		if b.kind=="mortar_array":
			b.cooldown=max(0.0,b.cooldown-dt)
			var operators=s.residents.filter(func(r):return r.job==b.id and r.station=="mortar" and r.travel<=0 and not r.retreated and r.pos.distance_to(pos(b))<85)
			if s.status=="OWNED" and not operators.is_empty() and g.player.get("operating","")!=b.id:
				var target=closest_enemy(pos(b),g.rules.tower.mortar[min(2,building_level(b)-1)][2])
				if target!=null:mortar_fire(b,target.pos)
		if b.kind == "htower":
			var form = tower_form(b)
			if form in ["none","signal"]: continue
			var stats = g.rules.tower[form][int(b.level)-1]
			for id in b.occupants:
				b.timers[str(id)] = b.timers.get(str(id),0.0)-dt
				var target = closest_enemy(pos(b),stats[2])
				if target != null and b.timers[str(id)] <= 0.000001:
					hurt_enemy(target,stats[0],pos(b)+Vector2((b.occupants.find(id)-1)*10,-15),0 if form=="cannon" else stats[3])
					b.timers[str(id)] = stats[1]
		if not b.powered or s.status != "OWNED": continue
		b.cooldown -= dt
		if b.kind == "tesla" and b.cooldown <= 0.000001:
			for e in s.enemies:
				if e.pos.distance_to(pos(b)) <= 80: hurt_enemy(e,12,pos(b))
			b.cooldown = 1.5
		if b.kind == "collector" and b.cooldown <= 0.000001:
			g.gain(0,2); g.gain(1,1); g.gain(2,1)
			b.cooldown = 8.0
		if b.kind == "repairer" and g.phase == "DAY" and b.cooldown <= 0.000001 and not s.repair_queue.is_empty():
			var id = s.repair_queue.pop_front()
			for target in s.buildings:
				if target.id == id: repair(target)
			b.cooldown = 3.0
	for r in s.residents:
		var delta=r.pos-r.get("motion_origin",r.pos)
		r.moving=delta.length_squared()>.0001 and not r.retreated and r.travel<=0
		if r.moving:r.facing=delta.normalized()
	for e in s.enemies.duplicate():
		if e.hp <= 0:
			g.add_xp(g.rules.enemies[e.kind].xp)
			fx.append({"a":e.pos,"b":e.pos,"life":0.45,"damage":0,"splash":0,"kind":"death","body":e.kind})
			s.enemies.erase(e)
			continue
		e.pos=safe_worker_position(e.pos)
		var d = g.rules.enemies[e.kind]
		e.retarget -= dt
		e.cooldown -= dt
		if e.kind == 3:
			e.summon -= dt
			if e.summon <= 0:
				e.summon = 12.0
				for j in range(3): spawn(0,j,e.pos+Vector2(j*12,0))
		if e.retarget <= 0:
			e.target = target_for(e)
			e.retarget = 0.25
		if e.target != "":
			if e.cooldown <= 0.000001:
				hurt_target(e.target,d.damage*(1 if e.target == "player" or resident(e.target) != null else d.mult))
				e.cooldown = d.interval
		else:
			if e.path_cursor < e.path.size():
				var destination = Vector2(s.waypoints[e.path[e.path_cursor]])*32+Vector2(16,16)
				e.pos = move_resident(e,destination,d.speed,dt)
				if e.pos.distance_to(destination) < 1: e.path_cursor += 1
	# Daytime reclamation is real combat with surviving enemies, never a score conversion.
	if s.status == "TO_RECLAIM" and s.enemies.is_empty() and core().hp >= core().max_hp and g.player_is_here(self):
		s.status = "OWNED"
		for r in s.residents: r.travel = max(r.travel,1.0)
		g.add_xp(25)
		g.message = "残敌清空，岛屿已收复"

func dawn():
	s.camp_waiting=min(6,int(s.get("camp_waiting",0))+2)
	s.camp_day=g.day
	s.repaired = 0.0
	s.repair_queue = []
	for b in s.buildings:
		if b.hp < b.max_hp: s.repair_queue.append(b.id)
		if b.kind == "repairer": b.cooldown = 3.0
	for node in s.nodes:
		# Do not regenerate a resource node beneath a completed building.
		if not s.occupancy.has(node.cell): node.amount = node.max*(2 if g.tech>=6 else 1)
	for r in s.residents:
		if s.status == "TO_RECLAIM": continue
		r.faith = min(5.0,r.faith+0.2)
		r.hungry = g.resources[3] < 1
		if not r.hungry: g.resources[3] -= 1
		var cost = (r.max_hp-r.hp)*2
		if g.resources[3] >= cost:
			g.resources[3] -= cost
			r.hp = r.max_hp
			r.retreated = false






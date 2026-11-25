extends RefCounted
const Island = preload("res://scripts/island_world.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Coast = preload("res://scripts/coast.gd")
var rules = {}
var worlds = []
var resources = [0.0,0.0,0.0,20.0]
var research = 0
var earned_research = 0
var tech = 1
var resident_tree = 1
var day = 1
var phase = "MENU"
var remaining = 100.0
var elapsed = 0.0
var serial = 0
var active = 0
var travel = {"time":0.0,"total":0.0,"target":0}
var player = {"pos":Vector2(450,520),"hp":150.0,"max_hp":150.0,"xp":0,"level":1,"blade":1,"ranged":"","armor":"","cooldown":0.0,"food_cd":0.0,"attack":0.0,"facing":Vector2.DOWN}
var inventory=[]
var gear=[]
var selected_slot=-1
var items
var equipment = {"shortbow":"","longbow":"","crossbow":"","leather":"","ironarmor":"","steelarmor":""}
var story = {"artisan":false,"settlers":false,"combat_next":0}
var pool = []
var pending_residents = []
var message = "先收集木头石堆；E救援居民，Tab拖入建造生产格成为工匠"
var results = []
var rng = RandomNumberGenerator.new()
var base_upgrade = {"island":-1,"time":0.0}

func _init():
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/rules.json"))
	rng.seed = 20261123
	for definition in rules.islands: worlds.append(Island.new(self,definition))
	worlds[0].s.status = "OWNED"
	items=Inventory.new(self);items.migrate()

func dispose():
	if items!=null:items.g=null
	for w in worlds: w.g = null
	worlds.clear()

func uid():
	serial += 1
	return "entity_%06d" % serial

func start():
	phase = "DAY"
	save(0)

func current():
	return worlds[active]

func resident_count():
	var n = pool.size()
	for world in worlds: n += world.s.residents.size()
	return n

func resident_limit():
	return 40 if resident_tree >= 6 else 30 if resident_tree >= 5 else 20 if resident_tree >= 3 else 12

func enemy_count():
	var n = 0
	for world in worlds: n += world.s.enemies.size()
	return n

func stock_limit():
	var warehouses = 0
	for w in worlds:
		warehouses += w.s.buildings.filter(func(b):return b.kind == "warehouse" and b.progress >= b.duration).size()
	return 120+(worlds[0].s.level-1)*50+warehouses*40

func gain(kind, amount):
	var before=resources[kind]
	resources[kind] = min(stock_limit(),resources[kind]+min(amount,items.room(kind)))
	items.sync()
	return resources[kind]-before

func spend(cost):
	for i in range(cost.size()):
		if resources[i]+0.0001 < cost[i]: return false
	for i in range(cost.size()): resources[i] = max(0.0,resources[i]-cost[i])
	items.sync()
	return true

func points(n):
	research += n
	earned_research += n

func add_xp(n):
	player.xp += n
	while player.level < 10 and player.xp >= rules.xp[player.level]:
		player.level += 1
		points(rules.xp_rewards[player.level-1])
		if player.level in [4,7,10]:
			player.max_hp += 10
			player.hp += 10

func player_is_here(world):
	return world == current() and travel.time <= 0

func add_resident(profession, island=-1, guaranteed=true):
	if resident_count() >= resident_limit():
		if guaranteed:pending_residents.append({"profession":profession,"island":island})
		return null
	if profession == "COMBAT":
		profession = "MELEE" if story.combat_next%2 == 0 else "RANGED"
		story.combat_next += 1
	var hp = {"UNEMPLOYED":50,"BUILD":60,"GATHER":50,"MELEE":150,"RANGED":80,"HERO_MELEE":300,"HERO_RANGED":200}[profession]
	if resident_tree >= 4: hp *= 1.3
	var r = {"id":uid(),"profession":profession,"station":"","faith":0.0,"hp":float(hp),"max_hp":float(hp),"pos":Vector2(460,540),"tower":"","job":"idle","workplace":"","travel":0.0,"island":island,"origin":max(0,island),"cooldown":0.0,"retreated":false,"hungry":false,"attacks":0}
	if island >= 0 and (profession not in ["BUILD","GATHER"] or worlds[island].assigned_count() < worlds[island].capacity()):
		worlds[island].s.residents.append(r)
		if profession in ["BUILD","GATHER"]:r.workplace=worlds[island].free_workplace(r.id).id
	else:
		r.island=-1
		pool.append(r)
	return r

func deliver_pending_residents():
	while not pending_residents.is_empty() and resident_count()<resident_limit():
		var grant=pending_residents.pop_front()
		add_resident(grant.profession,int(grant.island),false)

func resident_factor(r, combat=false):
	var value = (1+r.faith*0.08)*(1.65 if resident_tree>=4 else 1.25 if resident_tree>=2 else 1.0)*(0.5 if r.hungry else 1.0)
	if combat and not r.profession.begins_with("HERO"):
		var world = worlds[max(0,r.island)]
		if world.s.residents.any(func(other):return other.profession == "HERO_RANGED" and not other.retreated): value *= 1.4
	return value

func resident_combat(r):
	if r.profession == "HERO_MELEE": return [48,2.0,10.0]
	if r.profession == "HERO_RANGED": return [24,0.8,50.0]
	var item=items.equipped(r.id,"weapon")
	if item!=null and item.kind!="blade":
		var stats=ranged_stats(item.kind);stats[0]*=1+.15*(item.level-1);return stats
	return [5,1.0,10.0] if r.profession == "MELEE" else [8,1.2,70.0]

func ranged_stats(item):
	return {"shortbow":[6,1.0,90],"longbow":[10,1.2,110],"crossbow":[16,1.8,130]}.get(item,[0,1,0])

func armor_reduction(who):
	var item=items.equipped(who,"armor")
	return min(.55,{"leather":.1,"ironarmor":.2,"steelarmor":.3}.get(item.kind,0.0)*(1+.15*(item.level-1))) if item!=null else 0.0

func synergy():
	return min(3,min(tech,resident_tree)-1)

func unlock(tree):
	var level = tech if tree == "tech" else resident_tree
	if level >= 6: return "已达满级"
	var cost = rules.tree_cost[level]
	if research < cost: return "研究点不足，需要 %d 点" % cost
	research -= cost
	level += 1
	if tree == "tech":
		tech = level
		if level == 5:
			player.max_hp += 60
			player.hp += 60
	else:
		resident_tree = level
		if level == 2:
			for k in range(2): add_resident("UNEMPLOYED")
		if level == 3:
			for k in range(3): add_resident("UNEMPLOYED")
		if level == 4:
			for w in worlds:
				for r in w.s.residents:
					r.max_hp *= 1.3
					r.hp *= 1.3
			for r in pool:
				r.max_hp *= 1.3
				r.hp *= 1.3
			for k in range(3): add_resident("UNEMPLOYED")
		if level == 5:
			for k in range(4): add_resident("UNEMPLOYED")
		if level == 6:
			add_resident("HERO_MELEE")
			add_resident("HERO_RANGED")
			for k in range(6): add_resident("UNEMPLOYED")
		deliver_pending_residents()
	return "已解锁；协同等级 %d" % synergy()

func assign(r, island, profession):
	if worlds[island].s.status != "OWNED": return "目标岛尚未收复"
	if r.travel > 0 or r.retreated: return "居民暂不可调度"
	if r.profession.begins_with("HERO") and r.profession != profession: return "英雄保留专属职业"
	if r.profession != "UNEMPLOYED" and r.profession != profession and resident_tree < 6: return "居民树6级解锁自由转职"
	var needs_slot=profession in ["BUILD","GATHER"] and (r.island!=island or r.profession not in ["BUILD","GATHER"])
	if needs_slot and worlds[island].assigned_count()>=worlds[island].capacity():return "目标岛建造·收集岗位已满，请增加建筑或升级"
	var from = r.island
	if from >= 0 and worlds[from].s.status != "OWNED": return "居民正在防空洞内，请先收复岛屿"
	var origin=from if from>=0 else int(r.get("origin",0))
	if origin!=island:
		if worlds[origin].s.status!="OWNED":return "请先收复居民所在岛屿"
		if not worlds[origin].s.dock or not worlds[island].s.dock: return "跨岛调度需要两端码头"
	if from >= 0:
		worlds[from].unstation(r)
		worlds[from].s.residents.erase(r)
	else: pool.erase(r)
	r.island = island
	if r.profession!=profession:
		var ratio=r.hp/max(1.0,r.max_hp)
		r.max_hp={"BUILD":60,"GATHER":50,"MELEE":150,"RANGED":80,"UNEMPLOYED":50}.get(profession,50)*(1.3 if resident_tree>=4 else 1.0)
		r.hp=r.max_hp*ratio
	r.profession = profession
	r.job = "idle"
	r.pos = worlds[island].pos(worlds[island].core())+Vector2(60,70)
	r.travel = (5.0 if phase == "DAY" else 7.0) if origin != island else 0.0
	r.origin=island
	worlds[island].s.residents.append(r)
	r.workplace=worlds[island].free_workplace(r.id).id if profession in ["BUILD","GATHER"] else ""
	return "调度已提交" + ("，正在乘船" if r.travel>0 else "")

func set_station(r, kind):
	if r.profession not in ["MELEE","RANGED"]:return "请先将居民分配到战斗职业"
	kind={"signal":"archer","cannon":"musketeer"}.get(kind,kind)
	var needs = {"archer":0,"musketeer":2,"mortar":3,"":0}
	if synergy() < needs[kind]: return "需要对应协同能力"
	if r.profession.begins_with("HERO"): return "英雄不能转为协同兵种"
	if r.island >= 0: worlds[r.island].unstation(r)
	r.station = kind
	if kind!="":
		if r.profession!="RANGED":
			var ratio=r.hp/max(1.0,r.max_hp);r.max_hp=80*(1.3 if resident_tree>=4 else 1.0);r.hp=r.max_hp*ratio
		r.profession="RANGED"
		r.workplace=""
	return "兵种已切换"

func communication():
	if worlds[0].s.level < 2: return false
	for w in worlds:
		for b in w.s.buildings:
			if b.kind == "htower" and w.tower_form(b) == "signal": return true
	return false

func begin_travel(target):
	if phase not in ["DAY","NIGHT"]:return "当前阶段不能出航"
	if target<0 or target>=worlds.size():return "目标岛屿不存在"
	if target == active: return "已经在此岛"
	if travel.time > 0: return "正在航行"
	var w = worlds[target]
	if w.s.status == "LOCKED":
		if day < target+1: return "第%d天解锁" % (target+1)
		if story.get("last_unlock_day",0) == day: return "一天只能解锁一座副岛"
		if target == 2 and worlds[1].s.status == "LOCKED": return "先探索第一座副岛"
		if not current().s.dock: return "先修好出发岛的码头"
		var available=current().builders().filter(func(r):return r.job in ["idle","build"])
		if available.is_empty():return "首次登陆需要一名空闲工匠随船建立码头"
		w.s.status = "OWNED"
		story["last_unlock_day"] = day
		points(1)
		var n = int(w.cfg.size)
		w.add_building("wall",Vector2i(n/2-3,n/2-4),true)
		w.add_building("barricade",Vector2i(n/2+2,n/2-4),true)
		w.add_building("barricade",Vector2i(n/2-4,n/2+2),true)
		# The story boat carries an available builder for establishing the first dock.
		var crew = available
		if not crew.is_empty():
			var worker = crew[0]
			current().unstation(worker)
			current().s.residents.erase(worker)
			worker.island = target
			worker.pos = w.pos(w.s.buildings[1])-Vector2(0,60)
			worker.travel = (5.0 if phase=="DAY" else 7.0)*(0.6 if tech>=5 else 1.0)
			w.s.residents.append(worker)
		for k in range(2):add_resident("UNEMPLOYED",target)
	else:
		if not current().s.dock or not w.s.dock: return "往返需要两端可用码头"
	player.operating=""
	travel.total = (5.0 if phase == "DAY" else 7.0)*(0.6 if tech>=5 else 1.0)
	travel.time = travel.total
	travel.target = target
	return "已启航，前往"+w.cfg.name

func upgrade_core():
	var w = current()
	if w.s.status != "OWNED": return "先清剿残敌并修满核心，收复此岛"
	if phase != "DAY": return "基地只能在白天升级"
	if player.pos.distance_to(w.pos(w.core())) > 110: return "请站在核心附近"
	if base_upgrade.time > 0: return "升级正在进行"
	if w.s.level >= w.cfg.hps.size(): return "基地已满级"
	if w.cfg.hps.size()==2 and worlds[0].s.level<3: return "需要主岛3级"
	if w.s.level==2 and w.cfg.hps.size()>2 and earned_research<8: return "累计研究点需要8"
	if w.s.level==3 and earned_research<20: return "累计研究点需要20"
	if not spend(w.cfg.costs[int(w.s.level)-1]): return "升级材料不足"
	base_upgrade = {"island":active,"time":3.0}
	return "核心升级中，请保持在核心附近3秒"

func upgrade_building(b):
	var w = current()
	if phase not in ["DAY","NIGHT"]: return "当前阶段不能施工"
	if phase == "NIGHT" and (not w.s.enemies.is_empty() or w.s.cursor < w.s.wave.size()): return "本岛清场后才可施工"
	if w.builders().is_empty(): return "需要建造居民"
	if b.progress < b.duration: return "施工中"
	var cost = []
	if b.kind == "htower":
		if b.level >= min(3,tech-1): return "高塔等级受科技限制或已满级"
		cost = [0,15,8] if b.level == 1 else [0,25,15]
	elif b.kind == "wall" and b.level == 1: cost = [0,5,0]
	elif b.kind not in ["core","dock"]:
		if b.level>=3:return "建筑已满级"
		cost=[ceil(rules.buildings[b.kind].cost[0]*.5*b.level),10*b.level,5*(b.level-1)]
	else:return "核心请按U升级；码头使用固定等级"
	if not spend(cost): return "升级材料不足"
	b.upgrade = b.level+1
	b.progress = 0.0
	b.duration = 4.0 if b.kind == "htower" else 2.0
	b.worker=""
	w.assign_builder(b)
	for k in range(3): b.cost[k] += cost[k]
	return "已安排升级施工"

func craft(item, recipient="bag"):
	if recipient not in ["bag","player"]:return "请手持装备靠近居民，右键交付"
	if item=="blade":
		for gear_item in gear:
			if gear_item.kind=="blade":return items.craft("",gear_item.id)
	return items.craft(item)

func interact():
	if travel.time > 0: return
	var w = current()
	var center = w.pos(w.core())
	for b in w.s.buildings:
		if b.kind=="mortar_array" and b.progress>=b.duration and player.pos.distance_to(w.pos(b))<85:
			if w.s.residents.any(func(r):return r.job==b.id and r.station=="mortar"):message="阵列已有迫击炮兵操作";return
			player.operating="" if player.get("operating","")==b.id else b.id
			message="已退出迫击炮" if player.operating=="" else "已操作迫击炮：左键选择目标，E退出，移动也可退出"
			return
	if player.pos.distance_to(w.camp_position())<75:
		if w.s.get("camp_waiting",0)<=0:message="营地暂无居民，明天会有新的难民抵达"
		elif resident_count()>=resident_limit():message="居民人数已满，请先提升人口上限"
		else:
			add_resident("UNEMPLOYED",active)
			story.artisan=true
			w.s.camp_waiting-=1
			message="救援无业居民；Tab打开居民调度，拖入职业格分配"
		return
	if day>=2 and not story.settlers and active==0 and player.pos.distance_to(center+Vector2(150,100))<80:
		story.settlers = true
		for k in range(3):add_resident("UNEMPLOYED",0)
		message = "救出3名居民！Tab打开调度；科技与居民都要抓"
		return
	var best = null
	var distance = 80.0
	for b in w.s.buildings:
		var delta = player.pos.distance_to(w.pos(b))
		if delta<distance:
			best = b
			distance = delta
	if best != null and best.hp < best.max_hp:
		if best.kind == "dock" and not w.s.dock:
			var cost = [20,0,0] if active==0 else [30,10,0]
			if w.builders().is_empty(): message = "码头工程需要本岛建造居民"
			elif best.progress < best.duration: message = "码头正在施工"
			elif spend(cost):
				if active == 0:
					best.hp = best.max_hp
					w.s.dock = true
					message = "主岛码头已修复，可以出航"
				else:
					best.progress = 0.0
					best.duration = 8.0
					best.worker=""
					w.assign_builder(best)
					message = "已安排工匠建造副岛码头"
			else: message = "码头材料不足"
		else: message = w.repair(best)

func attack(direction):
	if player.get("operating","")!="":
		var array=current().building_index.get(player.operating)
		if array!=null and array.kind=="mortar_array" and current().pos(array).distance_to(player.pos)<85:message=current().mortar_fire(array,player.pos+direction);return
		player.operating=""
	if player.cooldown>0.000001 or travel.time>0: return
	player.facing = direction.normalized()
	player.attack = 0.2
	var equipped=items.equipped("player","weapon")
	var weapon=equipped.kind if equipped!=null else "blade"
	var stats = ranged_stats(weapon) if weapon!="blade" else [[10,13,16,20,24][int(player.blade)-1],0.55,[55,58,60,62,65][int(player.blade)-1]]
	if equipped!=null and weapon!="blade":stats[0]*=1+.15*(equipped.level-1)

	var range_mult = 1.15 if tech>=3 else 1.0
	var damage_mult = 1.45 if tech>=6 else 1.2 if tech>=2 else 1.0
	player.cooldown = stats[1]/(1.35 if tech>=6 else 1.15 if tech>=3 else 1.0)
	var hits = 0
	var candidates = current().s.enemies.duplicate()
	candidates.sort_custom(func(a,b):return a.pos.distance_to(player.pos)<b.pos.distance_to(player.pos))
	for e in candidates:
		var delta = e.pos-player.pos
		if delta.length()<=stats[2]*range_mult and abs(player.facing.angle_to(delta))<=deg_to_rad(50):
			current().hurt_enemy(e,stats[0]*damage_mult,player.pos)
			e.pos += delta.normalized()*[30,34,38,42,46][int(player.blade)-1]
			hits += 1
			if hits >= (3 if tech>=4 else 1): break

func move(direction, dt):
	player.moving=false
	if travel.time>0 or phase not in ["DAY","TRANSITION","NIGHT"]: return
	if direction.length()>0: player.facing=direction.normalized();player.operating=""
	var dest = player.pos+direction.limit_length()*120*(1.25 if tech>=6 else 1.1 if tech>=2 else 1.0)*dt
	var size = current().cfg.size*32
	dest.x=clamp(dest.x,-100,size+100);dest.y=clamp(dest.y,-100,size+100)
	var blocked=Coast.distance_at(dest,size)>-8
	if not blocked:
		var next=current().move_actor(player.pos,dest)
		player.moving=player.pos.distance_to(next)>.001
		player.pos=next

func gather(dt):
	if travel.time>0: return
	var closest=null
	var distance=55.0
	for node in current().s.nodes:
		var delta=player.pos.distance_to(Vector2(node.cell)*32+Vector2(16,16))
		if node.amount>0 and delta<distance:
			closest=node
			distance=delta
	if closest!=null:
		var amount=min(closest.amount,[4,3,2,5][closest.kind]*dt)
		var accepted=gain(closest.kind,amount)
		closest.amount-=accepted
		if accepted<=.000001:message="物品栏或库存已满，请先消耗或整理物品"

func heal():
	if player.food_cd>0 or resources[3]<1: return
	resources[3]-=1
	player.hp=min(player.max_hp,player.hp+(40 if tech>=5 else 20))
	player.food_cd=3.0

func tick(dt):
	if phase not in ["DAY","TRANSITION","NIGHT"]: return
	elapsed+=dt
	player.cooldown=max(0,player.cooldown-dt)
	player.attack=max(0,player.attack-dt)
	player.food_cd=max(0,player.food_cd-dt)
	player["flash"] = max(0,player.get("flash",0.0)-dt)
	if travel.time>0:
		travel.time=max(0,travel.time-dt)
		if travel.time<=0:
			active=travel.target
			player.pos=current().pos(current().s.buildings[1])-Vector2(0,100)
	if base_upgrade.time>0:
		var w=worlds[base_upgrade.island]
		if player_is_here(w) and player.pos.distance_to(w.pos(w.core()))<=110:
			base_upgrade.time-=dt
			if base_upgrade.time<=0:
				w.s.level+=1
				w.core().max_hp=w.cfg.hps[int(w.s.level)-1]
				w.core().hp=w.core().max_hp
				points(w.cfg.points[int(w.s.level)-2])
				message="基地升级完成，核心回满血并获得研究点"
	for w in worlds:
		w.tick(dt)
		if tech >= 6 and w != current() and w.s.status == "OWNED":
			for node in w.s.nodes:
				var amount = min(node.amount,[4,3,2,5][node.kind]*0.5*dt)
				node.amount -= gain(node.kind,amount)
	if player.hp<=0 or worlds[0].core().hp<=0:
		phase="BE"
		message="风暴吞没了最后的灯火。读取白天存档，重新布置防线。"
		return
	remaining-=dt
	if remaining>0.000001: return
	if phase=="DAY":
		phase="TRANSITION"
		remaining=2.0
	elif phase=="TRANSITION":
		phase="NIGHT"
		remaining=80.0
		for i in range(3):
			if worlds[i].s.status!="LOCKED": worlds[i].begin_night(day,i)
		message="深海来袭！夜晚固定80秒，清场后可以继续采集与建造"
	else: finish_night()

func finish_night():
	results=[]
	for w in worlds:
		if w.s.status=="LOCKED": continue
		var defenses=w.s.buildings.any(func(b):return b.kind in ["htower","tesla"] and b.hp>0) or w.active_residents().any(func(r):return r.profession in ["MELEE","RANGED","HERO_MELEE","HERO_RANGED"])
		var lost=(not w.s.enemies.is_empty() and not defenses) or (day==10 and w.s.status=="TO_RECLAIM")
		if lost:
			w.s.status="TO_RECLAIM"
			w.s.enemies=w.s.enemies.slice(0,5)
		else: w.s.enemies=[]
		var perfect=not w.s.hurt and not lost
		w.s.bonus=0.2 if perfect and resident_tree>=5 else 0.1 if perfect else 0.0
		if perfect:
			add_xp(15)
			add_resident("UNEMPLOYED",-1,false)
			if rng.randf()<(0.5 if resident_tree>=5 else 0.25): add_resident("UNEMPLOYED",-1,false)
		for r in w.s.residents: r.faith=min(5,r.faith+0.3+((2 if resident_tree>=5 else 1) if perfect else 0))
		results.append({"name":w.cfg.name,"damage":w.damage_rate(),"lost":lost,"perfect":perfect})
	add_xp(10)
	if day==10:
		if results.any(func(r):return r.lost): phase="BE"
		else:
			phase="HE" if results.all(func(r):return r.damage<=0.2) else "NE"
	else: phase="RESULT"

func next_day():
	if phase!="RESULT": return
	day+=1
	phase="DAY"
	remaining=100.0
	for w in worlds:
		if w.s.status!="LOCKED": w.dawn()
	save(0)
	message="新的一天；先检查损伤、食物和各岛驻防"

func pack_value(v):
	if v is Vector2: return {"_v2":[v.x,v.y]}
	if v is Vector2i: return {"_vi":[v.x,v.y]}
	if v is Array:
		var a=[]
		for item in v:a.append(pack_value(item))
		return a
	if v is Dictionary:
		var d={}
		for key in v:
			if key=="occupancy":continue
			d[str(key)]=pack_value(v[key])
		return d
	return v

func unpack_value(v):
	if v is Dictionary:
		if v.has("_v2"):return Vector2(v._v2[0],v._v2[1])
		if v.has("_vi"):return Vector2i(v._vi[0],v._vi[1])
		var d={}
		for key in v:d[key]=unpack_value(v[key])
		return d
	if v is Array:
		var a=[]
		for item in v:a.append(unpack_value(item))
		return a
	return v

func snapshot():
	items.sync();items.legacy()
	var ws=[]
	for w in worlds:ws.append(w.s)
	return pack_value({"version":9,"inventory":inventory,"gear":gear,"selected_slot":selected_slot,"resources":resources,"research":research,"earned_research":earned_research,"tech":tech,"resident_tree":resident_tree,"day":day,"remaining":remaining,"elapsed":elapsed,"serial":serial,"active":active,"player":player,"story":story,"pool":pool,"pending_residents":pending_residents,"worlds":ws,"equipment":equipment,"rng":str(rng.state),"base_upgrade":base_upgrade})

func valid_encoded_value(value):
	if value is Dictionary:
		for marker in ["_v2","_vi"]:
			if value.has(marker):
				var v=value[marker]
				return v is Array and v.size()==2 and (v[0] is int or v[0] is float) and (v[1] is int or v[1] is float)
		for key in value:
			if not valid_encoded_value(value[key]):return false
	elif value is Array:
		for item in value:
			if not valid_encoded_value(item):return false
	return true

func valid_snapshot(data):
	if not data is Dictionary or data.get("version",0)!=9:return false
	if not valid_encoded_value(data):return false
	for key in ["resources","research","earned_research","tech","resident_tree","day","remaining","elapsed","serial","active","player","story","pool","equipment","base_upgrade","rng","worlds"]:
		if not data.has(key):return false
	for key in ["research","earned_research","tech","resident_tree","day","remaining","elapsed","serial","active"]:
		if not (data[key] is int or data[key] is float):return false
	if data.active<0 or data.active>=3 or data.day<1 or data.day>10:return false
	if data.tech<1 or data.tech>6 or data.resident_tree<1 or data.resident_tree>6:return false
	if not data.resources is Array or data.resources.size()!=4:return false
	for amount in data.resources:
		if not (amount is int or amount is float) or amount<0:return false
	if not data.worlds is Array or data.worlds.size()!=3:return false
	if not data.pool is Array:return false
	for key in ["player","story","equipment","base_upgrade"]:
		if not data[key] is Dictionary:return false
	# Validate required nested keys against the current schema before mutating state.
	var decoded=unpack_value(data)
	if decoded.has("gear"):
		if not decoded.gear is Array or decoded.gear.size()>4096:return false
		var ids={}
		for item in decoded.gear:
			if not item is Dictionary or not item.has_all(["id","kind","owner","level","exclusive"]):return false
			if not item.id is String or ids.has(item.id) or item.kind not in ["blade","shortbow","longbow","crossbow","leather","ironarmor","steelarmor"]:return false
			if not item.owner is String or not (item.level is int or item.level is float) or item.level<1 or item.level>5 or not item.exclusive is bool:return false
			ids[item.id]=true
		if not decoded.get("inventory",null) is Array or decoded.inventory.size()!=36:return false
		for slot in decoded.inventory:
			if not slot is Dictionary:return false
			if slot.is_empty():continue
			if slot.get("kind","")=="gear":
				if not ids.has(slot.get("id","")):return false
			elif slot.get("kind","") in ["wood","stone","iron","food"]:
				if not (slot.get("count",null) is int or slot.get("count",null) is float) or slot.count<0 or slot.count>10:return false
			else:return false
		if not (decoded.get("selected_slot",-1) is int or decoded.get("selected_slot",-1) is float) or decoded.get("selected_slot",-1)<-1 or decoded.get("selected_slot",-1)>=36:return false

	for key in player:
		if key in ["moving","flash"]:continue
		if not decoded.player.has(key):return false
	if not decoded.player.pos is Vector2:return false
	for key in ["artisan","settlers","combat_next"]:
		if not decoded.story.has(key):return false
	for key in equipment:
		if not decoded.equipment.has(key):return false
	if not decoded.base_upgrade.has_all(["island","time"]):return false
	for i in range(3):
		var world=decoded.worlds[i]
		if not world is Dictionary:return false
		for key in worlds[i].s:
			if key in ["occupancy","camp_waiting","camp_day"]:continue
			if not world.has(key):return false
		if not world.buildings is Array or world.buildings.size()<2:return false
		if not world.residents is Array or not world.nodes is Array or not world.enemies is Array:return false
		for building in world.buildings:
			if not building is Dictionary or not building.has_all(["id","kind","cell","hp","max_hp","progress","duration","occupants","timers","level","cost","upgrade","cooldown"]):return false
			if not rules.buildings.has(building.kind) or not building.cell is Vector2i:return false
		if world.buildings[0].kind!="core" or world.buildings[1].kind!="dock":return false
	return true

func restore(data):
	if not valid_snapshot(data):return false
	var d=unpack_value(data)
	if d.get("version",0)!=9:return false
	resources=d.resources;research=int(d.research);earned_research=int(d.earned_research);tech=int(d.tech);resident_tree=int(d.resident_tree);day=int(d.day);remaining=d.remaining;elapsed=d.elapsed;serial=int(d.serial);active=int(d.active);player=d.player;story=d.story;pool=d.pool;equipment=d.equipment;base_upgrade=d.base_upgrade
	inventory=d.get("inventory",[]);gear=d.get("gear",[]);selected_slot=int(d.get("selected_slot",-1))
	items.migrate()
	rng.state=int(d.rng)
	pending_residents=d.get("pending_residents",[])
	for i in range(3):
		worlds[i].s=d.worlds[i]
		worlds[i].s.camp_waiting=worlds[i].s.get("camp_waiting",2)
		worlds[i].s.camp_day=worlds[i].s.get("camp_day",day)
		for node in worlds[i].s.nodes:
			if not node.has("form"):node.form="log" if node.kind==0 and int(node.cell.x)%2==0 else "natural"
		worlds[i].s.occupancy={}
		worlds[i].building_index.clear()
		worlds[i].building_grid.clear()
		for b in worlds[i].s.buildings:worlds[i].occupy(b)
		for r in worlds[i].s.residents:
			if r.tower!="" and (r.profession!="RANGED" or r.station not in ["","archer","musketeer","cannon"]):
				worlds[i].unstation(r);r.pos=worlds[i].safe_worker_position(r.pos)
		worlds[i].normalize_workplaces()
		worlds[i].recompute()
	phase="DAY"
	travel.time=0.0
	return true

func save(slot):
	if phase!="DAY" or travel.time>0:return "仅非航行的白天可以存档"
	if OS.get_environment("ISLAND_TEST_MODE")=="1":return "测试模式不写入玩家存档"
	var f=FileAccess.open("user://island_slot_%d.json"%slot,FileAccess.WRITE)
	if f==null:return "存档写入失败"
	f.store_string(JSON.stringify(snapshot()))
	return "已保存至槽位 %d"%slot

func load_slot(slot):
	var path="user://island_slot_%d.json"%slot
	if not FileAccess.file_exists(path):return "该槽位没有存档"
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if data==null or not restore(data):return "存档格式无效"
	return "读档完成，白天剩余时间已恢复"

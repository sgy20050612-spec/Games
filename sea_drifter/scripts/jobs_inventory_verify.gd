extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func fresh():
	var g=Sim.new();g.start();g.resident_tree=6;g.tech=6
	return g
func _initialize():OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func run():
	var g=fresh()
	for w in g.worlds:
		w.s.status="OWNED";w.s.level=2
		var extra=w.add_building("warehouse",Vector2i(4,4),true);extra.level=3
		check(w.capacity()==6,"mixed building levels sum rather than count times one level")
		for i in range(w.capacity()):
			var r=g.add_resident("UNEMPLOYED",g.worlds.find(w))
			check(g.assign(r,g.worlds.find(w),"BUILD" if i%2==0 else "GATHER").begins_with("调度已提交"),"civilian gets shared slot")
		check(w.assigned_count()==6,"civilian slots fill exact capacity")
		for b in w.s.buildings:check(w.workplace_count(b.id)<=w.building_level(b),"per-building civilian cap")
		var civilian=g.add_resident("UNEMPLOYED",g.worlds.find(w))
		check(g.assign(civilian,g.worlds.find(w),"BUILD").contains("已满"),"full civilian jobs reject without changing profession")
		check(civilian.profession=="UNEMPLOYED","failed assignment is atomic")
		check(g.assign(civilian,g.worlds.find(w),"RANGED").begins_with("调度已提交"),"combat assignment bypasses full civilian cap")
		check(w.assigned_count()==6,"combat does not consume building jobs")
		var occupant=w.s.residents.filter(func(r):return r.profession=="BUILD")[0]
		var target=w.s.buildings.filter(func(b):return b.id!=occupant.workplace)[0]
		var before=occupant.workplace
		check(w.assign_workplace(occupant,target).contains("上限") and occupant.workplace==before,"full individual building refuses drop atomically")
	g.dispose()
	g=fresh();var w=g.current();var worker=g.add_resident("BUILD",0);worker.pos=Vector2(600,600);g.player.pos=worker.pos+Vector2(0,40)
	g.resources=[80.0,80.0,80.0,20.0];g.items.sync()
	check(g.inventory.size()==36,"inventory is36 slots")
	check(g.inventory.filter(func(s):return s.get("kind","") in g.items.RESOURCE_KEYS).all(func(s):return s.count<=10),"resource stacks capped at10")
	check(g.craft("shortbow").begins_with("已打造"),"craft through nearby artisan")
	check(g.craft("shortbow").begins_with("已打造"),"duplicate gear may be crafted")
	var bows=g.gear.filter(func(item):return item.kind=="shortbow")
	check(bows.size()==2 and bows[0].id!=bows[1].id,"duplicate gear remains independent instances")
	check(g.inventory.filter(func(s):return s.get("kind","")=="gear").size()==3,"each piece consumes one inventory slot")
	var blade=g.gear.filter(func(item):return item.kind=="blade")[0]
	var blade_slot=0
	for i in range(36):
		if g.inventory[i].get("id","")==blade.id:blade_slot=i
	g.items.equip(blade_slot)
	check(g.items.give(worker).contains("专属") and blade.owner=="player","exclusive player weapon cannot be given")
	var slot=-1
	for i in range(36):
		if g.inventory[i].get("id","")==bows[0].id:slot=i
	g.items.equip(slot)
	worker.pos=g.player.pos+Vector2(200,0)
	check(g.items.give(worker).contains("靠近") and bows[0].owner=="player","remote handoff blocked")
	worker.pos=g.player.pos+Vector2(30,0)
	check(g.items.give(worker).begins_with("已交付") and bows[0].owner==worker.id,"held gear is equipped by nearby resident")
	check(not g.inventory.any(func(s):return s.get("id","")==bows[0].id),"given item leaves bag without duplication")
	var before=g.resources.duplicate();var level=bows[1].level
	check(g.items.craft("",bows[1].id).contains("已升至") and bows[1].level==level+1 and g.resources!=before,"artisan upgrade spends materials and increments item level")
	g.player.pos=Vector2(100,100);before=g.resources.duplicate()
	check(g.craft("leather").contains("靠近") and g.resources==before,"crafting cannot spend remotely")
	# Inventory and equipment must survive serialization, including resident ownership.
	var snapshot=g.snapshot();var clone=Sim.new()
	check(clone.restore(JSON.parse_string(JSON.stringify(snapshot))),"new inventory save restores")
	var restored_snapshot=clone.snapshot()
	check(JSON.parse_string(JSON.stringify(restored_snapshot))==JSON.parse_string(JSON.stringify(snapshot)),"inventory/equipment/workplaces exact save roundtrip")
	var invalid=snapshot.duplicate(true);invalid.gear[0].level=99
	check(not clone.restore(invalid),"invalid equipment level rejected before load")
	invalid=snapshot.duplicate(true);invalid.inventory[0]={"kind":"gear","id":"missing"}
	check(not clone.restore(invalid),"unknown inventory equipment reference rejected")
	clone.dispose()
	var old=snapshot.duplicate(true);old.erase("inventory");old.erase("gear");old.erase("selected_slot")
	clone=Sim.new();check(clone.restore(JSON.parse_string(JSON.stringify(old))) and clone.gear.any(func(item):return item.kind=="blade"),"old save migrates player-exclusive starter weapon")
	clone.dispose();g.dispose()
	g=fresh();g.resources=[120.0,120.0,100.0,10.0];g.items.sync()
	check(g.items.empty_slot()<0,"resource and equipment slots can fill inventory")
	w=g.current();var food=w.s.nodes.filter(func(node):return node.kind==3)[0]
	for node in w.s.nodes:
		if node!=food:node.amount=0
	g.player.pos=Vector2(food.cell)*32+Vector2(16,16)
	var node_before=food.amount;g.gather(1.0)
	check(food.amount==node_before and g.resources[3]==10,"full inventory does not consume uncollected resource node")
	g.dispose()
	# Only homogeneous archers or musketeers may stand on a tower.
	g=fresh();w=g.current();var tower=w.add_building("htower",Vector2i(5,5),true)
	var crew=[]
	for i in range(4):crew.append(g.add_resident("RANGED",0))
	for i in range(3):check(w.station(crew[i].id,tower)=="已驻守高塔","three archers share tower")
	check(w.station(crew[3].id,tower).contains("最多"),"fourth archer rejected")
	w.unstation(crew[2]);g.set_station(crew[2],"musketeer")
	check(w.station(crew[2].id,tower).contains("同一"),"mixed archer/musketeer tower rejected")
	g.set_station(crew[3],"mortar")
	check(w.station(crew[3].id,tower).contains("不可上塔"),"mortar operator cannot occupy tower")
	var array=w.add_building("mortar_array",Vector2i(8,8),true)
	check(w.assign_mortar(crew[3],array).begins_with("已分配"),"mortar specialist gets separate emplacement")
	check(w.assign_mortar(crew[2],array).contains("只有"),"musketeer cannot operate mortar facility")
	g.player.pos=w.pos(array)+Vector2(0,55);g.interact()
	check(g.player.get("operating","")=="","player cannot take already staffed array")
	w.unstation(crew[3]);g.interact()
	check(g.player.get("operating","")==array.id,"player may operate unstaffed standalone mortar")
	w.spawn(0,0,w.pos(array)+Vector2(90,0));var enemy=w.s.enemies[-1];enemy.hp=100
	g.attack(enemy.pos-g.player.pos)
	check(enemy.hp<100 and array.cooldown>0,"player mortar firing applies splash and reload")
	g.move(Vector2.DOWN,.05);check(g.player.get("operating","")=="","moving releases emplacement")
	array.cooldown=0;enemy.hp=100;crew[3].pos=w.pos(array)+Vector2(0,55)
	w.assign_mortar(crew[3],array);w.tick(.05)
	check(enemy.hp<100,"resident mortar operator fires standalone emplacement automatically")
	g.dispose()
	var f=FileAccess.open("res://jobs-inventory-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)

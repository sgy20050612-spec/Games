extends RefCounted
const RESOURCE_KEYS=["wood","stone","iron","food"]
const NAMES={"wood":"木材","stone":"石材","iron":"铁矿","food":"食物","blade":"锈蚀短刃","shortbow":"短弓","longbow":"长弓","crossbow":"弩","leather":"皮甲","ironarmor":"铁甲","steelarmor":"精铁甲"}
const COSTS={"shortbow":[20,0,5],"longbow":[30,0,10],"crossbow":[40,0,18],"leather":[30,0,5],"ironarmor":[0,20,12],"steelarmor":[0,40,20]}
var g
func _init(sim):g=sim
func weapon(kind):return kind in ["blade","shortbow","longbow","crossbow"]
func find(id):
	for item in g.gear:
		if item.id==id:return item
	return null
func make(kind,owner="bag",level=1):
	var item={"id":g.uid(),"kind":kind,"owner":owner,"level":level,"exclusive":kind=="blade"}
	g.gear.append(item);return item
func migrate():
	if g.gear.is_empty():
		make("blade","player",int(g.player.blade))
		for kind in g.equipment:
			if g.equipment[kind]!="":make(kind,"bag" if g.equipment[kind]=="stored" else g.equipment[kind])
	sync();legacy()
func legacy():
	for kind in g.equipment:g.equipment[kind]=""
	for item in g.gear:
		if g.equipment.has(item.kind):g.equipment[item.kind]="stored" if item.owner=="bag" else item.owner
func sync():
	if g.inventory.size()!=36:g.inventory.resize(36)
	var present={}
	for i in range(36):
		if not g.inventory[i] is Dictionary:g.inventory[i]={}
		var slot=g.inventory[i]
		if slot.get("kind","")=="gear":
			var item=find(slot.get("id",""))
			if item==null or item.owner not in ["bag","player"] or present.has(item.id):g.inventory[i]={}
			else:present[item.id]=true
	for item in g.gear:
		if item.owner in ["bag","player"] and not present.has(item.id):
			var index=empty_slot()
			if index>=0:g.inventory[index]={"kind":"gear","id":item.id};present[item.id]=true
	var preferred={};var quantities=[]
	for key in RESOURCE_KEYS:preferred[key]=[]
	for i in range(36):
		var key=g.inventory[i].get("kind","")
		if key in RESOURCE_KEYS:preferred[key].append(i);g.inventory[i]={}
	# Retain existing stack positions before allocating additional stacks.
	for k in range(4):
		var remaining=float(g.resources[k]);var key=RESOURCE_KEYS[k]
		for index in preferred[key]:
			if remaining<=.00001:break
			var count=min(10.0,remaining);remaining-=count;g.inventory[index]={"kind":key,"count":count}
		quantities.append(remaining)
	for k in range(4):
		var remaining=quantities[k];var key=RESOURCE_KEYS[k]
		while remaining>.00001:
			var index=empty_slot()
			if index<0:break
			var count=min(10.0,remaining);g.inventory[index]={"kind":key,"count":count};remaining-=count

func empty_slot():
	for i in range(g.inventory.size()):
		if g.inventory[i]==null or g.inventory[i].is_empty():return i
	return -1
func room(kind):
	sync();var result=0.0
	for slot in g.inventory:
		if slot.is_empty():result+=10
		elif slot.kind==RESOURCE_KEYS[kind]:result+=10-slot.count
	return result
func held():
	sync()
	if g.selected_slot<0 or g.selected_slot>=36:return null
	var slot=g.inventory[g.selected_slot]
	return find(slot.id) if slot.get("kind","")=="gear" else null
func equip(index):
	g.selected_slot=index
	var item=held()
	if item==null:return "已选择物品"
	for other in g.gear:
		if other.id!=item.id and other.owner=="player" and weapon(other.kind)==weapon(item.kind):other.owner="bag"
	item.owner="player";legacy()
	return "手持："+NAMES[item.kind]+("（玩家专属）" if item.exclusive else "；靠近居民右键交付")
func move_slot(a,b):
	sync()
	if a<0 or b<0 or a>=36 or b>=36:return
	var from=g.inventory[a];var to=g.inventory[b]
	if from.get("kind","") in RESOURCE_KEYS and from.get("kind","")==to.get("kind",""):
		var amount=min(10-to.count,from.count);to.count+=amount;from.count-=amount
		if from.count<=.00001:g.inventory[a]={}
	else:g.inventory[a]=to;g.inventory[b]=from
	if g.selected_slot==a:g.selected_slot=b
func equipped(owner,category):
	for item in g.gear:
		if item.owner==owner and (weapon(item.kind) if category=="weapon" else not weapon(item.kind)):return item
	return null
func give(resident):
	if g.travel.time>0:return "航行期间不可交付装备"
	var item=held()
	if item==null:return "先在物品栏选择要交付的装备"
	if item.exclusive:return "玩家专属装备不能交给居民"
	if resident.island!=g.active or resident.travel>0 or resident.tower!="" or resident.retreated:return "居民当前不可交互"
	if resident.pos.distance_to(g.player.pos)>85:return "请靠近居民再交付装备"
	for other in g.gear:
		if other.owner==resident.id and weapon(other.kind)==weapon(item.kind):other.owner="bag"
	item.owner=resident.id;g.inventory[g.selected_slot]={};g.selected_slot=-1
	sync();legacy();return "已交付"+NAMES[item.kind]+"，居民已装备"
func upgrade_cost(item):
	return [0,10*item.level,5*item.level] if item.kind=="blade" else COSTS[item.kind].map(func(v):return ceil(v*(.5+.25*item.level)))
func craft(kind,upgrade_id=""):
	if g.phase!="DAY" or g.current().s.status!="OWNED" or g.travel.time>0:return "请在已收复岛屿的白天与工匠交互"
	if not g.current().builders().any(func(r):return r.travel<=0 and r.pos.distance_to(g.player.pos)<=90):return "请靠近工匠进行打造或升级"
	sync()
	if upgrade_id!="":
		var item=find(upgrade_id)
		if item==null or item.owner not in ["bag","player"]:return "请把要升级的装备带到物品栏"
		if item.level>=5:return "装备已满级"
		var cost=upgrade_cost(item)
		if not g.spend(cost):return "升级材料不足"
		item.level+=1
		if item.kind=="blade":g.player.blade=item.level
		return NAMES[item.kind]+"已升至Lv.%d"%item.level
	if not COSTS.has(kind):return "请选择可打造装备"
	if empty_slot()<0:return "物品栏已满，请先腾出一格"
	if not g.spend(COSTS[kind]):return "打造材料不足"
	var item=make(kind);sync();legacy();return "已打造"+NAMES[kind]+"，已放入物品栏"

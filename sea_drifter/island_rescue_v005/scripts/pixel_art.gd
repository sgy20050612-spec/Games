extends RefCounted
## Original generated atlases. All placement, light and animation are runtime draws.
const ENV = preload("res://assets/art/environment-16bit-v4.png")
const PEOPLE = preload("res://assets/art/residents-side-16bit-v4.png")
const SOUTH = preload("res://assets/art/residents-south-16bit-v5.png")
const VERTICAL = preload("res://assets/art/residents-vertical-16bit-v4.png")
const CREATURES = preload("res://assets/art/enemies-16bit-v4.png")
const COAST = preload("res://scripts/coast.gd")
var game
var person_anchors={}

func _init(canvas):
	game=canvas
	person_anchors=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/residents-anchors-v4.json"))

func sprite(texture, index, target, color=Color.WHITE, columns=4, rows=4, flip_h=false):
	target=Rect2(target.position.round(),target.size.round())
	if texture==ENV:rows=5
	if flip_h:target=Rect2(target.position,Vector2(-target.size.x,target.size.y))
	index=int(index)
	var cell=Vector2(texture.get_width(),texture.get_height())/Vector2(columns,rows)
	var region=Rect2(Vector2(index%columns,floor(float(index)/columns))*cell+Vector2.ONE,cell-Vector2(2,2))
	game.draw_texture_rect_region(texture,target,region,color)

func night_amount():
	var g=game.g
	if g.phase=="NIGHT":return 1.0
	if g.phase=="TRANSITION":return clamp(1-g.remaining/2,0,1)
	if g.phase=="DAY" and 100-g.remaining<12:return .35*(1-(100-g.remaining)/12)
	return 0.0

func light(world_pos):
	var night=night_amount()
	var result=Color.WHITE.lerp(Color("697b9e"),night*.78)
	if game.g.phase=="DAY" and game.g.remaining<20:result=result.lerp(Color("ffd4a0"),((20-game.g.remaining)/20)*.18)
	for b in game.g.current().s.buildings:
		if b.kind not in ["core","house","dock","generator"]:continue
		var distance=world_pos.distance_to(game.g.current().pos(b))
		if distance<135:
			var weight=pow(1-distance/135,1.4)*night*.7
			result=result.lerp(Color("ffdda2"),weight)
	return result

func person_frame(role,running,facing):
	var row={"BUILD":0,"GATHER":1,"MELEE":2,"RANGED":3,"HERO_MELEE":4,"HERO_RANGED":5,"UNEMPLOYED":6}.get(role,6)
	var frame=int(game.clock*8)%4 if running else 0
	if abs(facing.y)>abs(facing.x):
		if facing.y>0:return {"texture":SOUTH,"index":row*4+frame,"columns":4,"rows":7,"flip":false}
		return {"texture":VERTICAL,"index":row*8+4+frame,"columns":8,"rows":7,"flip":false}
	return {"texture":PEOPLE,"index":row*4+frame,"columns":4,"rows":7,"flip":facing.x<0}

func person(p, role, running, alpha, scale_value,facing=Vector2.DOWN):
	var tint=Color(1,1,1,alpha)
	if game.menu=="":tint=light(p-game.offset);tint.a=alpha
	var state=person_frame(role,running,facing)
	var layout=person_layout(p,state,scale_value)
	game.draw_texture_rect_region(state.texture,layout.target,layout.region,tint)

func person_layout(p,state,scale_value):
	var frame=person_anchors["side" if state.texture==PEOPLE else "south" if state.texture==SOUTH else "vertical"][state.index]
	var r=frame.region
	var region=Rect2(r[0],r[1],r[2],r[3])
	var factor=32.0*scale_value/float(frame.reference_height)
	var anchor=Vector2(frame.anchor[0],frame.anchor[1])*factor
	var size_value=region.size*factor
	# Anchor the visible feet, never the weapon/cape bounding-box centre.
	# Mirroring is about the foot anchor, so a turn cannot translate the body.
	var ground=p.round()
	var target=Rect2(ground-anchor,size_value)
	if state.flip:
		# Godot flips negative widths in place: position remains the LEFT edge.
		# Do not use a mathematical negative Rect2 origin at the right edge.
		target=Rect2(ground+Vector2(anchor.x-size_value.x,-anchor.y),Vector2(-size_value.x,size_value.y))
	return {"target":target,"region":region,"anchor":ground,"source_anchor":Vector2(frame.anchor[0],frame.anchor[1]),"factor":factor}

func resource(node):
	var p=Vector2(node.cell)*32+Vector2(16,30)+game.offset
	if node.get("form","")=="log":
		for i in range(3):
			var at=p+Vector2(-20+i*5,-8-i*6)
			game.box(Rect2(at,Vector2(33,8)),Color("814019"))
			game.box(Rect2(at+Vector2(1,1),Vector2(31,3)),Color("c17a32"))
			game.box(Rect2(at+Vector2(27,0),Vector2(7,8)),Color("f0bc6a"))
			game.draw_line(at+Vector2(29,2),at+Vector2(31,6),Color("775635"),1)
		return
	var index=0 if node.kind==0 and node.cell.x%3!=0 else 1 if node.kind==0 else 2 if node.kind==1 else 3 if node.kind==2 else 4
	var size_value=Vector2(96,116) if node.kind==0 else Vector2(59,56) if node.kind in [1,2] else Vector2(59,52)
	var tint=light(p-game.offset)
	var sway=sin(game.clock*1.5+node.cell.x*.6)*1.1 if node.kind==0 else 0.0
	var rect=Rect2(p-Vector2(size_value.x/2,size_value.y-5)+Vector2(sway,0),size_value)
	sprite(ENV,index,rect,tint)

func building(w,b):
	var index={"core":5,"house":6,"warehouse":7,"dock":8,"htower":9,"generator":14,"collector":16,"repairer":17,"tesla":15,"mortar_array":13}.get(b.kind,-1)
	if index<0:return false
	var d=game.g.rules.buildings[b.kind]
	var p=Vector2(b.cell)*32+game.offset
	var floor_pos=p+Vector2(d.w*16,d.h*32)
	var size_value=Vector2(132,140) if b.kind=="core" else Vector2(108,110) if b.kind=="htower" else Vector2(116,83) if b.kind=="dock" else Vector2(96,96)
	if b.kind=="htower":
		index={"none":9,"archer":10,"elite":10,"signal":11,"cannon":12,"mortar":13}[w.tower_form(b)]
	var rect=Rect2(floor_pos-Vector2(size_value.x/2,size_value.y-5),size_value)
	var tint=light(w.pos(b))
	if b.progress<b.duration:tint.a=.55
	sprite(ENV,index,rect,tint)
	if b.kind=="htower":
		for j in range(b.occupants.size()):
			var r=w.resident(b.occupants[j])
			if r!=null:person(floor_pos+Vector2(-22+j*22,-63),r.profession,false,1,.65)
		for i in range(int(b.level)):game.box(Rect2(floor_pos+Vector2(-7+i*6,-5),Vector2(3,3)),Color("d7c28c"))
	if b.kind=="generator":
		var c=floor_pos+Vector2(13,-31)
		game.draw_arc(c,10,game.clock*2,game.clock*2+5,12,Color("b6a374"),2)
	if b.kind=="collector":
		var c=floor_pos+Vector2(15,-17)
		game.draw_line(c,c+Vector2(0,10+sin(game.clock*11)*3),Color("a9b4a6"),4)
	if b.kind=="repairer":
		game.draw_line(floor_pos+Vector2(-19,-30),floor_pos+Vector2(8,-38+sin(game.clock*3)*5),Color("84c4bb"),2)
	if b.kind=="tesla" and b.powered:
		var c=floor_pos+Vector2(0,-59)
		game.draw_polyline(PackedVector2Array([c+Vector2(-15,-4),c+Vector2(-5,3+sin(game.clock*18)*6),c+Vector2(3,-8),c+Vector2(14,0)]),Color("8dc9d8"),1)
	if not b.powered and d.power>0:game.label_at("停电",floor_pos+Vector2(-16,-49),12,Color("d1a17e"))
	if b.hp<b.max_hp:game.bar(Rect2(floor_pos+Vector2(-28,-size_value.y+6),Vector2(56,4)),b.hp,b.max_hp,Color("b97864"))
	if b.progress<b.duration:game.bar(Rect2(floor_pos+Vector2(-29,-8),Vector2(58,5)),b.progress,b.duration,Color("d5b76f"))
	if game.selected!=null and game.selected.get("id","")==b.id:game.draw_rect(Rect2(p,Vector2(d.w,d.h)*32),Color("b5cf7b"),false,2)
	return true

func enemy(e):
	var p=e.pos+game.offset
	var side=94.0 if e.kind==3 else 62.0 if e.kind==2 else 46.0
	var frame=3 if e.cooldown>.65 else int(game.clock*6+e.pos.x*.01)%3
	var rect=Rect2(p-Vector2(side/2,side-6),Vector2(side,side))
	sprite(CREATURES,e.kind*4+frame,rect,light(e.pos).lightened(.12))
	if e.cooldown>.65:game.draw_arc(p,17 if e.kind<3 else 35,game.clock*4,game.clock*4+2,8,Color("b78b77"),1)
	game.bar(Rect2(p-Vector2(side*.28,side-1),Vector2(side*.56,3)),e.hp,game.g.rules.enemies[e.kind].hp,Color("aa7d6d"))

func death(effect):
	var progress=1-effect.life/.45
	var side=80 if effect.get("body",0)==3 else 45
	var p=effect.b+game.offset+Vector2(0,progress*6)
	sprite(CREATURES,int(effect.get("body",0))*4+2,Rect2(p-Vector2(side/2,side-6),Vector2(side,side)),Color(.5,.6,.72,(1-progress)*.6))
	for i in range(5):
		var direction=Vector2.from_angle(i*TAU/5)
		game.box(Rect2(p+direction*(4+progress*17)-Vector2(0,8),Vector2(2,2)),Color(.65,.72,.69,(1-progress)*.5))

func shore(n, offset, ocean, night):
	var land=n*32
	var sections=[]
	for i in range(n*4):
		var stretch=round((25+sin(i*.085)*12+sin(i*.23)*5)/2)*2
		for side in range(4):
			var rect=Rect2()
			if side==0:rect=Rect2(Vector2(-stretch,i*8),Vector2(stretch,9))
			if side==1:rect=Rect2(Vector2(land,i*8),Vector2(stretch,9))
			if side==2:rect=Rect2(Vector2(i*8,-stretch),Vector2(9,stretch))
			if side==3:rect=Rect2(Vector2(i*8,land),Vector2(9,stretch))
			sections.append({"rect":rect,"side":side,"i":i})
	for section in sections:
		var r=section.rect
		game.box(Rect2(r.position+offset,r.size).grow(8),ocean.lightened(.1))
	for section in sections:
		var r=section.rect
		game.box(Rect2(r.position+offset,r.size),Color("aaa17b").lerp(Color("414d5b"),night*.8))
	for section in sections:
		if section.i%3!=0:continue
		var r=section.rect
		var side=section.side
		var edge=r.position+offset
		if side==1:edge+=Vector2(r.size.x,0)
		if side==3:edge+=Vector2(0,r.size.y)
		var drift=sin(game.clock*1.7+section.i*.2)*2
		if side<2:game.draw_line(edge+Vector2(drift,1),edge+Vector2(drift,7),Color(.7,.8,.71,.25),1)
		else:game.draw_line(edge+Vector2(1,drift),edge+Vector2(7,drift),Color(.7,.8,.71,.25),1)

func ground(w):
	var n=int(w.cfg.size)
	var night=night_amount()
	for y in range(1,n-1):
		for x in range(1,n-1):
			var seed_value=(x*173+y*79+x*y*13)%113
			if seed_value>78 or w.s.occupancy.has(Vector2i(x,y)):continue
			var p=Vector2(x*32+seed_value%19,y*32+seed_value%13)+game.offset
			if p.x < -30 or p.x>1180 or p.y<70 or p.y>600:continue
			var dark=Color("438329").lerp(Color("293d42"),night*.6)
			var leaf=Color("79bc37").lerp(Color("485f5c"),night*.6)
			for i in range(6):
				var dx=(i*7+seed_value)%23-11
				var dy=(i*3+seed_value)%9
				game.box(Rect2(p+Vector2(dx,dy),Vector2(3,3)),dark)
				game.draw_line(p+Vector2(dx,dy),p+Vector2(dx-2,dy-5-(i%3)),leaf,1)
			if seed_value<5:
				for i in range(3):game.box(Rect2(p+Vector2(i*6-6,-6+(i%2)*4),Vector2(2,2)),Color("d2c799").lerp(Color("819091"),night*.6))
	# A worn path from the village doorway to the dock, not the simulation graph.
	var start=w.pos(w.core())+Vector2(0,35)
	var end=w.pos(w.s.buildings[1])-Vector2(0,12)
	var count=int(start.distance_to(end)/8)
	for i in range(count):
		var p=start.lerp(end,float(i)/max(1,count))+game.offset+Vector2(sin(i*.26)*4,0)
		game.box(Rect2(p-Vector2(7,2),Vector2(14+(i%3)*2,7)),Color("d9a653").lerp(Color("48515b"),night*.7))
		if i%3==0:game.box(Rect2(p+Vector2(-4,1),Vector2(2,1)),Color("efc97e").lerp(Color("63717b"),night*.7))

func boat(p, drawer=null, alpha=1.0, reflection=false):
	if drawer==null:drawer=game
	p.y+=round(sin(game.clock*2.1)*1.3)
	var zoom=game.preferences.values.zoom if drawer==game else 1.0
	if drawer==game:p=Vector2(576,355)+(p-Vector2(576,355))*zoom
	drawer.draw_set_transform(p.round(),sin(game.clock*1.4)*.015,(Vector2(1,-.34) if reflection else Vector2.ONE)*zoom)
	var cell=Vector2(ENV.get_width()/4.0,ENV.get_height()/5.0)
	var region=Rect2(Vector2(3,4)*cell+Vector2.ONE,cell-Vector2(2,2))
	drawer.draw_texture_rect_region(ENV,Rect2(-47,-51,94,65),region,Color(1,1,1,alpha))
	for side in [-1,1]:
		var end=Vector2(side*(38+sin(game.clock*4)*6),20+cos(game.clock*4)*4)
		drawer.draw_line(Vector2(side*19,1),end,Color("a45a27"),3)
		drawer.draw_line(end,end+Vector2(side*5,3),Color("e5a557"),5)
	drawer.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if drawer==game:game.set_world_transform()
func harbor_position(w):
	var dock=w.s.buildings[1]
	var foot=Vector2(dock.cell)*32+Vector2(48,64)
	return Vector2(foot.x,w.cfg.size*32+COAST.depth(foot.x,3,w.cfg.size*32)+23)

func harbor_floor(w):
	if not w.s.dock:return
	var foot=Vector2(w.s.buildings[1].cell)*32+Vector2(48,64)
	var sea=harbor_position(w).y-23
	for y in range(int(foot.y),int(sea)+1,5):
		game.box(Rect2(Vector2(foot.x-15,y)+game.offset,Vector2(30,4)),Color("856a4c").lerp(Color("434b53"),night_amount()*.6))
	var p=harbor_position(w)+game.offset
	for i in range(4):
		var dx=-30+i*20
		var width=9+sin(game.clock*2+i)*3
		game.draw_line(p+Vector2(dx-width/2,13+i%2*3),p+Vector2(dx+width/2,13+i%2*3),Color(.65,.76,.73,.25),1)

func beach_entries(w):
	var entries=[]
	var size_value=w.cfg.size*32
	for side in range(4):
		for along in range(24,int(size_value)-20,37):
			var seed_value=(along*7+side*23)%17
			if seed_value not in [0,3,6]:continue
			var distance=COAST.depth(along,side,size_value)-12
			var p=Vector2(-distance,along) if side==0 else Vector2(size_value+distance,along) if side==1 else Vector2(along,-distance) if side==2 else Vector2(along,size_value+distance)
			entries.append({"kind":"beach","data":{"pos":p,"seed":seed_value},"y":p.y})
	return entries

func beach_detail(data):
	var p=data.pos+game.offset
	if data.seed==6:
		# Explicit rotated vertices keep the world's zoom transform intact.
		var points=PackedVector2Array()
		for v in [Vector2(-7,-2),Vector2(7,-2),Vector2(7,1),Vector2(-7,1)]:points.append(p+v.rotated(.35))
		game.draw_colored_polygon(points,Color("8d7b5c").lerp(Color("465054"),night_amount()*.6))
	else:sprite(ENV,2,Rect2(p-Vector2(9,11),Vector2(18,15)),Color.WHITE.lerp(Color("71828f"),night_amount()*.5))

func scene_entries(w):
	var entries=beach_entries(w)
	for node in w.s.nodes:
		if node.amount>0:entries.append({"kind":"resource","data":node,"y":node.cell.y*32+30})
	for b in w.s.buildings:entries.append({"kind":"building","data":b,"y":(b.cell.y+game.g.rules.buildings[b.kind].h)*32})
	for r in w.s.residents:
		if r.tower=="" and r.travel<=0:entries.append({"kind":"resident","data":r,"y":r.pos.y})
	for e in w.s.enemies:entries.append({"kind":"enemy","data":e,"y":e.pos.y})
	if game.g.travel.time<=0:entries.append({"kind":"player","data":game.g.player,"y":game.g.player.pos.y})
	# Upright objects share one queue; only ground and interface stay outside it.
	entries.append({"kind":"camp","data":null,"y":w.camp_position().y+32})
	for i in range(min(3,int(w.s.get("camp_waiting",0)))):
		var p=w.camp_position()+Vector2(43+i*16,30)
		entries.append({"kind":"refugee","data":p,"y":p.y})
	if w.s.dock:entries.append({"kind":"boat","data":harbor_position(w),"y":harbor_position(w).y})
	if game.g.day>=2 and not game.g.story.settlers and game.g.active==0:
		var p=w.pos(w.core())+Vector2(150,100)
		entries.append({"kind":"settlement","data":p,"y":p.y+11})
	for f in w.fx:
		var y=f.get("b",f.get("a",Vector2.ZERO)).y
		if f.get("kind","")=="repair":y=f.a.y+28
		entries.append({"kind":"effect","data":f,"y":y})
	for i in range(entries.size()):entries[i]["order"]=i
	entries.sort_custom(func(a,b):return a.y<b.y if a.y!=b.y else a.order<b.order)
	return entries

func scene(w):
	for entry in scene_entries(w):draw_entry(w,entry)

func draw_entry(w,entry):
	var data=entry.data
	if entry.kind=="resource":resource(data)
	elif entry.kind=="building":game.draw_building(w,data)
	elif entry.kind=="enemy":enemy(data)
	elif entry.kind=="resident":
		var working=data.get("working",false)
		var run=(data.get("moving",false) if data.profession=="BUILD" else data.job!="idle") and not data.retreated and not working
		var p=data.pos+game.offset
		if working:p+=Vector2(sin(game.clock*12)*1.5,abs(sin(game.clock*12))*2)
		run=data.get("moving",false) and not data.retreated and not working and game.menu==""
		person(p,data.profession,run,.3 if data.retreated else 1,1.35,data.get("facing",Vector2.DOWN))
		if working:
			hammer(p,data.get("repair_target",data.pos)+game.offset)
			game.label_at("施工中",p+Vector2(-21,-65),12,Color("edd39c"))
		if data.retreated:game.label_at("撤退",data.pos+game.offset+Vector2(-15,-38),11)
	elif entry.kind=="camp":camp(w)
	elif entry.kind=="refugee":person(data+game.offset,"UNEMPLOYED",false,1,.9)
	elif entry.kind=="boat":boat(data+game.offset)
	elif entry.kind=="beach":beach_detail(data)
	elif entry.kind=="effect":game.draw_world_effect(data)
	elif entry.kind=="settlement":
		var p=data+game.offset
		sprite(ENV,6,Rect2(p-Vector2(42,65),Vector2(84,76)),Color(1,1,1,.75))
		if game.preferences.values.tutorial:game.label_at("E  搜救聚落",p+Vector2(-40,-29),14)
	elif entry.kind=="player":
		var run=data.get("moving",false) and game.menu==""
		person(data.pos+game.offset,"HERO_MELEE",run,1,1.5,data.facing)
		if data.attack>0:
			var a=data.facing.angle()
			game.draw_arc(data.pos+game.offset,45,a-.85,a+.85,14,Color("ead9a5"),3)
		if data.get("flash",0)>0:game.draw_arc(data.pos+game.offset,18,0,TAU,12,Color("d98a77"),3)

func hammer(p,target):
	var side=1 if target.x>=p.x else -1
	var swing=sin(game.clock*10)
	var hand=p+Vector2(side*6,-16)
	var head=hand+Vector2(side*(8+6*swing),-10+11*swing)
	game.draw_line(p+Vector2(side*3,-22),hand+Vector2(side*3,swing*3),Color("e2b57c"),3)
	game.draw_line(hand,head,Color("b76b32"),3)
	game.box(Rect2(head-Vector2(5,3),Vector2(10,6)),Color("a7b8c7"))
	game.box(Rect2(head-Vector2(4,3),Vector2(8,2)),Color("e2e6dc"))
	if swing>.75:
		for k in range(3):game.box(Rect2(head+Vector2(k*4-4,5+k*3),Vector2(2,2)),Color("e6c78b"))

func camp(w):
	var p=w.camp_position()+game.offset
	sprite(ENV,18,Rect2(p-Vector2(72,70),Vector2(144,102)))
	game.label_at("难民营  %d人"%w.s.get("camp_waiting",0),p+Vector2(-52,-80),14)
	if game.preferences.values.tutorial:game.label_at("E救援 · 每日抵达",p+Vector2(-53,49),12)

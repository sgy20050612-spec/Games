extends Node2D
const Sim = preload("res://scripts/simulation.gd")
const Art = preload("res://scripts/pixel_art.gd")
const Water = preload("res://scripts/water_layer.gd")
const Title = preload("res://scripts/title_screen.gd")
const Preferences = preload("res://scripts/preferences.gd")
var preferences
var title_screen
var art
var water_layer
var g
var font
var ui_buttons = []
var avatars = []
var drops = []
var menu = ""
var detail = null
var selected = null
var placement = ""
var wall_start=null
var wall_preview_key=""
var wall_preview=[]
var dragging = null
var drag_facing=Vector2.DOWN
var cursor = Vector2.ZERO
var ui_scale_applied=false
var inventory_cells=[]
var warehouse_cells=[]
var inventory_drag=-1
var inventory_drag_origin=Vector2.ZERO
var workshop_id=""
var offset = Vector2.ZERO
var accumulator = 0.0
var clock = 0.0
var refresh = 0.0
var muted = false
var show_numbers = true
var music
var audio
var last_phase = ""
var window_save = false
var save_confirm = -1
var dispatch_scroll = {}
var facility_page = 0
const ROLE_NAMES = {"UNEMPLOYED":"无业居民","BUILD":"建造生产","GATHER":"资源收集","MELEE":"近战兵","RANGED":"弓兵","HERO_MELEE":"近战英雄","HERO_RANGED":"远程英雄"}
const FORM_NAMES = {"none":"空塔","archer":"弓箭塔","elite":"精锐弓箭塔","signal":"通讯塔","cannon":"火枪塔","mortar":"迫击炮阵列"}
const JOB_NAMES = {"idle":"待分配","wood":"伐木","stone":"采石","food":"采食","research":"研究","build":"建造修复"}

func _ready():
	DisplayServer.window_set_title("海岛～拯救！ v0")
	font = load("res://assets/fusion-pixel-12px.otf") if ResourceLoader.exists("res://assets/fusion-pixel-12px.otf") else ThemeDB.fallback_font
	if font is FontFile:
		font.antialiasing=TextServer.FONT_ANTIALIASING_NONE
		font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.hinting=TextServer.HINTING_NONE
		font.oversampling=1.0
		font.fixed_size=12
		font.fixed_size_scale_mode=TextServer.FIXED_SIZE_SCALE_ENABLED
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	g = Sim.new()
	art = Art.new(self)
	title_screen=Title.new(self)
	water_layer = Water.new()
	water_layer.game = self
	add_child(water_layer)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	music = AudioStreamPlayer.new()
	music.volume_db = -22
	add_child(music)
	preferences=Preferences.new(self)
	var finish_layer=CanvasLayer.new();finish_layer.layer=100;add_child(finish_layer)
	var finish=ColorRect.new();finish.position=Vector2.ZERO;finish.size=Vector2(1152,648)
	finish.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var finish_material=ShaderMaterial.new();finish_material.shader=preload("res://scripts/pixel_finish.gdshader")
	finish.material=finish_material;finish_layer.add_child(finish)
	menu="main"
	queue_redraw()

func _exit_tree():
	if is_instance_valid(music):
		if music.finished.is_connected(repeat_music):music.finished.disconnect(repeat_music)
		music.stop()
		music.stream=null
	if is_instance_valid(audio):
		audio.stop()
		audio.stream=null
	art = null
	title_screen=null
	preferences=null
	if g != null: g.dispose()

func box(rect, color):
	draw_rect(rect,color)

func label_at(text, p, size=17, color=Color("59321e")):
	draw_string(font,p.round(),str(text),HORIZONTAL_ALIGNMENT_LEFT,-1,max(12,size),color)

func wood(rect, title=""):
	box(rect,Color("f4d28b"))
	for i in range(0,int(rect.size.y),9):
		draw_line(rect.position+Vector2(3,i),rect.position+Vector2(rect.size.x-3,i+2),Color(.82,.55,.24,.18),1)
		for k in range(0,int(rect.size.x),90):
			var start=rect.position+Vector2(k+((i*7+k)%21),i+4)
			draw_line(start,start+Vector2(24+(i*11+k)%45,1),Color(.65,.34,.12,.14),1)
	draw_rect(rect,Color("a85a22"),false,4)
	draw_rect(rect.grow(-7),Color("ffe7af"),false,2)
	draw_line(rect.position+Vector2(3,3),rect.position+Vector2(rect.size.x-3,3),Color("ffe5a2"),2)
	for dx in [10,rect.size.x-10]:
		for dy in [10,rect.size.y-10]:
			box(Rect2(rect.position+Vector2(dx-2,dy-2),Vector2(4,4)),Color("ffd37d"))
	if title!="":label_at(title,rect.position+Vector2(18,29),22)

func lantern(p):
	draw_line(p-Vector2(0,30),p-Vector2(0,12),Color("9a8052"),3)
	box(Rect2(p-Vector2(9,12),Vector2(18,26)),Color("352f27"))
	box(Rect2(p-Vector2(5,8),Vector2(10,17)),Color("e2b55d"))
	box(Rect2(p-Vector2(2,5),Vector2(4,10)),Color("ffda8a"))
	for radius in [22,35]:draw_circle(p,radius,Color(1,.67,.25,.025))

func panel(rect, tint=Color("f6d99b"), edge=Color("a45a2a")):
	box(rect,tint)
	draw_rect(rect,edge,false,2)

func button(rect, text, action, enabled=true, color=Color("e8a354")):
	var hover=rect.has_point(cursor)
	box(rect,color.lightened(.12) if hover and enabled else color if enabled else Color("b89a76"))
	draw_rect(rect,Color("d5bd80") if hover and enabled else Color("95501d"),false,2)
	if enabled:
		draw_line(rect.position+Vector2(3,3),rect.position+Vector2(rect.size.x-3,3),color.lightened(.18),1)
		draw_line(rect.position+Vector2(3,rect.size.y-3),rect.end-Vector2(3,3),color.darkened(.3),2)
	label_at(text,rect.position+Vector2(9,rect.size.y*.5+6),16,Color("653015") if enabled else Color("765e4c"))
	if enabled:ui_buttons.append({"rect":rect,"action":action})

func bar(rect,value,max_value,color):
	box(rect,Color("17212b"))
	box(Rect2(rect.position,Vector2(rect.size.x*clamp(value/max(1,max_value),0,1),rect.size.y)),color)
	draw_rect(rect,Color("7b7761"),false,1)

func person(p, role, running=false, alpha=1.0, scale_value=2.0,facing=Vector2.DOWN):
	if art != null:
		art.person(p,role,running,alpha,scale_value,facing)
		return
	var cloth={"UNEMPLOYED":"7f8070","BUILD":"ba8c53","GATHER":"4d8f8d","MELEE":"ad6554","RANGED":"9b6a4d","HERO_MELEE":"d6bc69","HERO_RANGED":"a9b6a1"}.get(role,"8a8374")
	var c=Color(cloth);c.a=alpha
	var motion=sin(clock*17)*2 if running else sin(clock*2)*.4
	var base=p+Vector2(0,-abs(motion)*scale_value*.4)
	draw_ellipse_pixel(base+Vector2(0,1),Vector2(11,3)*scale_value,Color(0.03,.08,.1,.3*alpha))
	var pixels=[[Rect2(-5,-25,10,7),Color("44382d")],[Rect2(-4,-21,8,7),Color("d2a87c")],[Rect2(3,-19,1,2),Color("20292c")],[Rect2(-5,-14,10,10),c],[Rect2(-6,-5,12,2),Color("4c4030")],[Rect2(-4,-3,3,4+motion),Color("453a34")],[Rect2(1,-3,3,4-motion),Color("453a34")],[Rect2(-7,-12+motion,3,7),Color("c6a37c")],[Rect2(4,-12-motion,3,7),Color("c6a37c")]]
	for entry in pixels:
		var r=entry[0]
		var col=entry[1]
		col.a=alpha
		box(Rect2((base+r.position*scale_value).round(),r.size*scale_value),col)
	if role=="GATHER":
		box(Rect2(base+Vector2(-10,-13)*scale_value,Vector2(5,9)*scale_value),Color("9b804b"))
		box(Rect2(base+Vector2(-10,-17)*scale_value,Vector2(5,4)*scale_value),Color("89a958"))
		box(Rect2(base+Vector2(-6,-25)*scale_value,Vector2(12,4)*scale_value),Color("488284"))
	elif role=="BUILD":
		draw_line(base+Vector2(8,-4)*scale_value,base+Vector2(8,-16)*scale_value,Color("ad8048"),2*scale_value)
		box(Rect2(base+Vector2(5,-17)*scale_value,Vector2(8,4)*scale_value),Color("a7ada6"))
	elif role in ["RANGED","HERO_RANGED"]:
		draw_arc(base+Vector2(8,-10)*scale_value,7*scale_value,-1.3,1.3,8,Color("d6b77b"),2)
	elif role in ["MELEE","HERO_MELEE"]:
		draw_line(base+Vector2(8,-5)*scale_value,base+Vector2(11,-19)*scale_value,Color("c8d2c2"),3)
	if role.begins_with("HERO"):
		box(Rect2(base+Vector2(-5,-28)*scale_value,Vector2(10,3)*scale_value),Color("d9c275"))

func draw_ellipse_pixel(p,size_value,color):
	box(Rect2((p-size_value/2).round(),size_value.round()),color)

func pixel_tree(p, variant=0):
	box(Rect2(p+Vector2(-21,7),Vector2(44,10)),Color(0.03,.1,.1,.22))
	box(Rect2(p+Vector2(-5,-6),Vector2(10,21)),Color("503e2c"))
	box(Rect2(p+Vector2(-2,-5),Vector2(4,19)),Color("98774e"))
	box(Rect2(p+Vector2(-22,-30),Vector2(44,21)),Color("294c3c"))
	box(Rect2(p+Vector2(-17,-40),Vector2(34,30)),Color("3c6848"))
	box(Rect2(p+Vector2(-11,-47),Vector2(24,27)),Color("527d4c"))
	for i in range(18):
		var dx=((i*17+variant*3)%33)-17
		var dy=-38+((i*11+variant)%25)
		box(Rect2(p+Vector2(dx,dy),Vector2(5+(i%3),3)),Color("829d59") if i%3==0 else Color("60864e") if i%3==1 else Color("355d41"))
	for i in range(4):box(Rect2(p+Vector2(-11+i*7,-8-(i%2)*4),Vector2(4,4)),Color("31543e"))

func draw_building(w,b):
	if art != null and art.building(w,b):return
	var d=g.rules.buildings[b.kind]
	var p=Vector2(b.cell)*32+offset
	var size_value=Vector2(d.w,d.h)*32
	box(Rect2(p+Vector2(4,8),size_value-Vector2(2,2)),Color(0,.02,.04,.25))
	var palette={"core":"a9966c","dock":"927148","house":"9f8a60","warehouse":"82765b","wall":"b98b55","barricade":"ba7135","htower":"908a6a","generator":"718588","tesla":"577b88","collector":"7b886b","repairer":"7d8b83"}
	box(Rect2(p+Vector2(4,4),size_value-Vector2(8,5)),Color(palette[b.kind]))
	if b.kind=="wall":
		for x in range(4,28,8):box(Rect2(p+Vector2(x,0),Vector2(5,9)),Color("edc28a"))
		for y in [13,22]:draw_line(p+Vector2(4,y),p+Vector2(28,y),Color("84542d"),1)
		for row in range(2):
			for x in range(8+row*5,28,10):draw_line(p+Vector2(x,8+row*9),p+Vector2(x,13+row*9),Color("84542d"),1)
		draw_line(p+Vector2(4,5),p+Vector2(27,5),Color("f4ce93"),2)
	elif b.kind=="htower":
		box(Rect2(p+Vector2(4,4),Vector2(56,12)),Color("c5b28b"))
		box(Rect2(p+Vector2(11,17),Vector2(42,35)),Color("4b514a"))
		var form=w.tower_form(b)
		if form=="signal":
			draw_line(p+Vector2(32,20),p+Vector2(32,-15),Color("c7b478"),3)
			box(Rect2(p+Vector2(33,-15),Vector2(18,12)),Color("c2aa53"))
		elif form in ["cannon","mortar"]:
			box(Rect2(p+Vector2(24,-4),Vector2(15,32)),Color("303d42"))
			box(Rect2(p+Vector2(21,-8),Vector2(21,8)),Color("677c7b"))
		for i in range(b.occupants.size()):
			var r=w.resident(b.occupants[i])
			if r!=null:person(p+Vector2(16+i*16,40),r.profession,false,1,1)
		label_at(str(b.level),p+Vector2(6,60),12)
	elif b.kind=="barricade":
		for x in range(4,28,8):draw_line(p+Vector2(x,5),p+Vector2(x+3,27),Color("bd9a6a"),4)
	elif b.kind=="dock":
		for x in range(5,int(size_value.x),9):draw_line(p+Vector2(x,3),p+Vector2(x,size_value.y-3),Color("4f4431"),2)
		draw_circle(p+Vector2(15,10),5,Color("d5b16c"))
	else:
		var roof=Color("a26248") if b.kind in ["core","house","warehouse"] else Color("57706c")
		box(Rect2(p+Vector2(0,-4),Vector2(size_value.x,16)),roof)
		box(Rect2(p+Vector2(8,-13),Vector2(size_value.x-16,12)),roof.lightened(.12))
		for y in range(0,11,5):
			for x in range(3,int(size_value.x)-6,12):
				draw_line(p+Vector2(x+(y%2)*3,y),p+Vector2(x+9+(y%2)*3,y),roof.darkened(.2),2)
		for x in range(8,int(size_value.x)-5,10):draw_line(p+Vector2(x,14),p+Vector2(x,size_value.y-5),Color(0.2,.17,.12,.2),1)
		box(Rect2(p+Vector2(size_value.x/2-7,size_value.y-25),Vector2(14,22)),Color("423d34"))
		for x in [10,size_value.x-20]:
			box(Rect2(p+Vector2(x,20),Vector2(9,10)),Color("e1b65f"))
			draw_line(p+Vector2(x+4,20),p+Vector2(x+4,30),Color("62533a"),1)
			draw_line(p+Vector2(x,25),p+Vector2(x+9,25),Color("62533a"),1)
		box(Rect2(p+Vector2(2,size_value.y-6),Vector2(size_value.x-4,5)),Color("6b6c55"))
		if b.kind in ["generator","collector","repairer","mortar_array"]:
			var center=p+size_value/2
			draw_arc(center,12,clock*2,clock*2+5.5,10,Color("b6b59a"),3)
			if not b.powered:label_at("停电",p+Vector2(5,22),12,Color("ed9674"))
	if b.hp<b.max_hp:
		bar(Rect2(p+Vector2(0,-20),Vector2(size_value.x,4)),b.hp,b.max_hp,Color("b97861"))
		for i in range(int((1-b.hp/b.max_hp)*5)):
			draw_line(p+Vector2(12+i*7,18),p+Vector2(16+i*7,35),Color("504b3d"),2)
	if b.progress<b.duration:
		box(Rect2(p,size_value),Color(.15,.2,.25,.55))
		bar(Rect2(p+Vector2(3,size_value.y-8),Vector2(size_value.x-6,5)),b.progress,b.duration,Color("e3bd72"))
	if selected!=null and selected.get("id","")==b.id:draw_rect(Rect2(p-Vector2(3,3),size_value+Vector2(6,6)),Color("c8d77f"),false,2)

func draw_world():
	var w=g.current()
	var n=int(w.cfg.size)
	offset=Vector2(576,355)-g.player.pos
	offset=offset.round()
	var night=1.0 if g.phase=="NIGHT" else clamp(1-g.remaining/2,0,1) if g.phase=="TRANSITION" else 0.0
	var dusk=clamp((20-g.remaining)/20,0,1) if g.phase=="DAY" else (1-night) if g.phase=="TRANSITION" else 0.0
	if g.phase=="DAY" and 100-g.remaining<10:night=.35*(1-(100-g.remaining)/10)
	var ocean=Color("285b68").lerp(Color("152b4a"),night).lerp(Color("675e63"),dusk*.4)
	water_layer.update_water(n,offset,night,dusk)
	if placement!="":
		for y in range(n):
			for x in range(n):
				var p=Vector2(x,y)*32+offset
				if p.x>=-32 and p.x<1184 and p.y>50 and p.y<680:draw_rect(Rect2(p,Vector2(32,32)),Color(.8,.8,.6,.15),false,1)
	if placement!="":
		for edge in w.s.edges:draw_line(Vector2(w.s.waypoints[edge[0]])*32+Vector2(16,16)+offset,Vector2(w.s.waypoints[edge[1]])*32+Vector2(16,16)+offset,Color(.62,.57,.4,.09),3)
	art.ground(w)
	art.harbor_floor(w)
	# Soft pixel fire rings are drawn after the evening ambient tint.
	if night>0 or dusk>0:
		for b in w.s.buildings:
			if b.kind not in ["core","house","dock"]:continue
			var p=w.pos(b)+offset
			for rad in [24,16,8]:draw_circle(p,rad+sin(clock*8)*2,Color(1,.64,.23,.035))
			box(Rect2(p-Vector2(2,5),Vector2(4,6)),Color("edc97a"))
	art.scene(w)
	if placement!="":
		var cell=Vector2i(((cursor-offset)/32).floor())
		if placement=="wall":
			var line=w.wall_line(wall_start,cell) if wall_start!=null else [cell]
			var key=str(wall_start)+str(cell)+str(w.s.buildings.size())+g.phase+str(w.s.enemies.size())
			if key!=wall_preview_key:
				wall_preview_key=key;wall_preview=[]
				for c in line:wall_preview.append(w.can_place("wall",c)=="")
			for i in range(line.size()):draw_rect(Rect2(Vector2(line[i])*32+offset,Vector2(32,32)),Color(.45,.9,.6,.5) if wall_preview[i] else Color(.95,.2,.2,.6))
			var cost=g.rules.buildings.wall.cost
			label_at(("左键设置起点" if wall_start==null else "移动鼠标选择终点 · 左键确认")+"  %d段 / 木%d 石%d · 右键取消"%[line.size(),cost[0]*line.size(),cost[1]*line.size()],cursor+Vector2(18,-12),14)
			return
		var d=g.rules.buildings[placement]
		var reason=w.can_place(placement,cell)
		draw_rect(Rect2(Vector2(cell)*32+offset,Vector2(d.w,d.h)*32),Color(.45,.9,.6,.45) if reason=="" else Color(.9,.3,.25,.5))
		label_at(reason if reason!="" else "左键建造 · 右键取消",cursor+Vector2(18,-12),14)

func draw_world_effect(f):
	if f.get("kind","")=="repair":
		art.hammer(f.a+offset+Vector2(-25,28),f.a+offset)
		return
	if f.get("kind","")=="death":
		art.death(f)
		return
	var progress=clamp(1-f.life/.22,0,1)
	var head=f.a.lerp(f.b,progress)+offset-Vector2(0,sin(progress*PI)*(12+f.splash*.18))
	var previous=f.a.lerp(f.b,max(0,progress-.12))+offset-Vector2(0,sin(max(0,progress-.12)*PI)*(12+f.splash*.18))
	draw_line(previous,head,Color("dec795"),1)
	box(Rect2(head-Vector2(1,1),Vector2(3,3)),Color("e8d3a0"))
	if f.splash>0 and progress>.45:
		var burst=(progress-.45)/.55
		for i in range(9):
			var direction=Vector2.from_angle(i*TAU/9)
			var p=f.b+offset+direction*(6+min(f.splash,42)*burst)
			box(Rect2(p,Vector2(2,3)),Color(1,.68,.32,(1-burst)*.8))
	if show_numbers:label_at(str(int(f.damage)),f.b+offset-Vector2(4,25),14,Color("ffdea0"))


func clock_minutes():
	var minutes=360.0
	if g.phase=="DAY":minutes=360+clamp((100.0-g.remaining)/100.0,0,1)*720
	elif g.phase=="TRANSITION":minutes=1080+clamp((2.0-g.remaining)/2.0,0,1)*60
	elif g.phase=="NIGHT":minutes=1140+clamp((80.0-g.remaining)/80.0,0,1)*660
	return posmod(int(minutes/10)*10,1440)

func draw_day_clock():
	var minutes=clock_minutes()
	var dx=1152/preferences.values.ui_scale-1152
	wood(Rect2(830+dx,10,310,94))
	var c=Vector2(876+dx,57)
	for y in range(-36,37,3):
		var half=int(sqrt(max(0,36*36-y*y))/3)*3
		box(Rect2(c+Vector2(-half,y),Vector2(half*2,3)),Color("34485d") if y<0 else Color("7dbdc4"))
	for at in [Vector2(-20,-20),Vector2(7,-27),Vector2(20,-13)]:box(Rect2(c+at,Vector2(3,3)),Color("c6d6bb"))
	box(Rect2(c+Vector2(-6,13),Vector2(12,12)),Color("f6cc56"))
	box(Rect2(c+Vector2(-8,16),Vector2(16,6)),Color("f6cc56"))
	box(Rect2(c+Vector2(-6,-26),Vector2(12,12)),Color("dfdfba"))
	box(Rect2(c+Vector2(-3,-27),Vector2(10,8)),Color("34485d"))
	game_clock_hand(c,minutes)
	panel(Rect2(923+dx,20,205,29),Color("f0c681"))
	label_at("第 %d 天"%g.day,Vector2(971+dx,43),24)
	panel(Rect2(923+dx,58,205,33),Color("e0b477"))
	label_at("%02d:%02d"%[int(minutes/60),minutes%60],Vector2(969+dx,83),25)

func game_clock_hand(center,minutes):
	var angle=(float(minutes)/1440)*TAU-PI*.5
	var tip=center+Vector2.from_angle(angle)*30
	draw_line(center,tip,Color("8c431d"),3)
	box(Rect2(center-Vector2(3,3),Vector2(6,6)),Color("f0ba56"))

func hud():
	var scale_value=preferences.values.ui_scale
	var width=1152/scale_value;var height=648/scale_value
	var first_button=ui_buttons.size()
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_value)

	draw_day_clock()
	button(Rect2(width-120,112,105,32),"Tab 菜单",func():menu="info")
	button(Rect2(width-120,152,105,32),"I 物品栏",func():menu="character")
	var y=92
	for i in range(3):
		var w=g.worlds[i]
		if w.s.status=="LOCKED":continue
		var known=i==g.active or g.communication()
		var alarm=w.damage_rate()>.65
		panel(Rect2(12,y,158,66),Color("522d30") if known and alarm and sin(clock*7)>0 else Color("edc77f"))
		label_at(w.cfg.name+(" · 告急" if known and alarm else ""),Vector2(22,y+23),15)
		if known:
			bar(Rect2(22,y+35,138,7),1-w.damage_rate(),1,Color("a3b36d"))
			label_at("敌 %d  波次 %d/%d"%[w.s.enemies.size(),w.s.cursor,w.s.wave.size()],Vector2(22,y+59),12)
		else:label_at("夜间失联" if g.phase=="NIGHT" else "未建立通讯",Vector2(22,y+51),13)
		y+=73
	wood(Rect2(12,height-75,width-24,64))
	label_at(g.message.left(66),Vector2(27,height-51),16)
	panel(Rect2(width-48,height-156,28,126),Color("3b2d2b"))
	var hp_ratio=clamp(g.player.hp/max(1.0,g.player.max_hp),0.0,1.0)
	box(Rect2(width-39,height-146,10,106),Color("542f32"))
	box(Rect2(width-39,height-40-106*hp_ratio,10,106*hp_ratio),Color("c65d5d"))
	if preferences.values.tutorial:label_at("WASD移动  E交互/按住采集  B建造  左键攻击  右键食物回血  U升级核心  Tab菜单",Vector2(27,height-27),14)
	for i in range(first_button,ui_buttons.size()):
		ui_buttons[i].rect=Rect2(ui_buttons[i].rect.position*scale_value,ui_buttons[i].rect.size*scale_value);ui_buttons[i].screen_space=true
	set_ui_transform()
	if g.travel.time>0:
		panel(Rect2(345,265,465,115))
		label_at("乘船前往 "+g.worlds[g.travel.target].cfg.name,Vector2(370,297),22)
		bar(Rect2(370,315,410,13),g.travel.total-g.travel.time,g.travel.total,Color("d3b777"))
		label_at("剩余 %.1f 秒；三岛仍持续战斗"%g.travel.time,Vector2(370,355),16)
		var boat=Vector2(430+260*(1-g.travel.time/g.travel.total),350+sin(clock*4)*2)
		art.sprite(Art.ENV,19,Rect2(boat-Vector2(8,33),Vector2(76,53)))
	if g.base_upgrade.time>0:bar(Rect2(440,535,270,11),3-g.base_upgrade.time,3,Color("d8bf78"))
	if selected!=null and menu=="":draw_selection()

func draw_selection():
	var b=selected
	if not g.current().s.buildings.has(b):selected=null;return
	wood(Rect2(790,130,348,426),g.rules.buildings[b.kind].name)
	label_at("Lv.%d  HP %d/%d"%[b.level,b.hp,b.max_hp],Vector2(808,192),17)
	button(Rect2(808,210,142,34),"修复",func():
		if g.player.pos.distance_to(g.current().pos(b))<110:g.message=g.current().repair(b)
		else:g.message="需要站在设施附近")
	button(Rect2(962,210,150,34),"升级",func():g.message=g.upgrade_building(b),b.kind not in ["core","dock"])
	button(Rect2(808,255,142,34),"拆除返还100%",func():
		g.current().remove_building(b,true);selected=null,g.phase=="DAY" and b.kind not in ["core","dock"])
	button(Rect2(962,255,150,34),"关闭",func():selected=null)
	if b.kind=="mortar_array":
		label_at("独立迫击炮阵列 · 迫击炮兵/玩家操作",Vector2(808,318),15)
		button(Rect2(808,345,303,38),"操作阵列 / 退出操作",func():g.interact(),g.player.pos.distance_to(g.current().pos(b))<85 and b.progress>=b.duration)
		return
	if b.kind!="htower":return
	label_at(FORM_NAMES[g.current().tower_form(b)]+"  %d/3人"%b.occupants.size(),Vector2(808,315),19)
	label_at("高塔：弓兵/火枪兵，同职业最多3人",Vector2(808,342),14)
	var y=361
	for id in b.occupants.duplicate():
		var r=g.current().resident(id)
		if r==null:continue
		label_at(ROLE_NAMES[r.profession]+" #"+id.right(3),Vector2(808,y+21),14)
		button(Rect2(1010,y,96,28),"下塔",func():g.current().unstation(r))
		y+=32
	var available=g.current().active_residents().filter(func(r):return r.tower=="" and not r.profession.begins_with("HERO"))
	for r in available.slice(0,max(0,int((545-y)/30))):
		button(Rect2(808,y,300,27),"上塔："+({"musketeer":"火枪兵","cannon":"火枪兵","mortar":"迫击炮兵"}.get(r.station,ROLE_NAMES[r.profession]))+" #"+r.id.right(3),func():g.message=g.current().station(r.id,b))
		y+=30

func menu_shell(title):
	box(Rect2(0,76,1152,497),Color(0.04,.08,.1,.85))
	wood(Rect2(20,83,1112,480),title)
	panel(Rect2(36,168,1080,380),Color("f3d7a2"),Color("756747"))
	for y in range(170,547,5):draw_line(Vector2(38,y),Vector2(1113,y),Color(.6,.6,.5,.018),1)
	lantern(Vector2(1002,109))
	var tabs=["信息","物品","成长技能书","居民调度","群岛地图","设置"]
	var ids=["info","character","tree","dispatch","map","settings"]
	for i in range(6):button(Rect2(38+i*163,127,155,32),tabs[i],func():menu=ids[i];detail=null)
	button(Rect2(1035,96,78,26),"返回",func():menu="";detail=null;dragging=null)

func tree_ui():
	label_at("可用研究点  %d"%g.research,Vector2(870,111),18,Color("e7cf81"))
	label_at("科技技能书 · 投入 %d/30"%tree_spent(g.tech),Vector2(70,188),18)
	label_at("混合技能书",Vector2(465,188),18)
	label_at("居民技能书 · 投入 %d/30"%tree_spent(g.resident_tree),Vector2(785,188),18)
	var blue=Color("246eae");var red=Color("c24d36");var yellow=Color("a8771d")
	for i in range(6):
		var y=205+i*52
		if i>=3:y+=14
		for col in [0,2]:
			var x=62 if col==0 else 770
			var level=g.tech if col==0 else g.resident_tree
			var name=g.rules.tech_names[i] if col==0 else g.rules.resident_names[i]
			var color=blue if col==0 else yellow
			var rect=Rect2(x,y,310,42)
			panel(rect,Color("f6dfaa"),color if level>i else Color("666d6a"))
			book_icon(Vector2(x+21,y+22),color if level>i else Color("727b76"),[0,9,12,13,14,14][i] if col==0 else -10-[6,2,6,3,3,4][i])
			label_at("%d  %s"%[i+1,name],Vector2(x+48,y+26),17)
			label_at("已解锁" if level>i else "%d点"%g.rules.tree_cost[i],Vector2(x+238,y+25),14,color if level>i else Color("897152"))
			if level==i:ui_buttons.append({"rect":rect,"action":func():g.message=g.unlock("tech" if col==0 else "resident")})
			if i<5:draw_arrow(Vector2(x+156,y+43),Vector2(x+156,y+51),Color("b7a272"))
		if i in [1,2,3]:
			var rect=Rect2(435,y,280,42)
			panel(rect,Color("f4d5ad"),red if g.synergy()>=i else Color("686d6b"))
			book_icon(Vector2(458,y+22),red if g.synergy()>=i else Color("747675"),[0,11,12,13][i])
			label_at(["","协同Ⅰ · 弓兵","协同Ⅱ · 火枪兵","协同Ⅲ · 迫击炮兵"][i],Vector2(480,y+26),16)
			draw_arrow(Vector2(376,y+21),Vector2(430,y+21),red if g.synergy()>=i else Color("7e817a"))
			draw_arrow(Vector2(766,y+21),Vector2(721,y+21),red if g.synergy()>=i else Color("7e817a"))
	wood(Rect2(38,354,1074,13))
	label_at("第三级分界",Vector2(514,365),12)

func tree_spent(level):
	var n=0
	for i in range(level):n+=g.rules.tree_cost[i]
	return n

func book_icon(p,color,icon=-1):
	box(Rect2(p+Vector2(-12,-14),Vector2(25,29)),Color("694b36"))
	box(Rect2(p+Vector2(-8,11),Vector2(20,3)),Color("b9aa85"))
	draw_rect(Rect2(p+Vector2(-12,-14),Vector2(25,29)),color,false,1)
	box(Rect2(p+Vector2(-10,-12),Vector2(3,23)),Color("392b25"))
	if icon>=0:art.sprite(Art.ENV,icon,Rect2(p-Vector2(11,12),Vector2(24,24)))
	elif icon<=-10:art.sprite(Art.VERTICAL,(-10-icon)*8,Rect2(p-Vector2(13,14),Vector2(28,28)),Color.WHITE,8,7)
	else:draw_line(p+Vector2(-1,5),p+Vector2(7,-5),color,2)

func draw_arrow(a,b,color):
	draw_line(a,b,color,3)
	var unit=(b-a).normalized()
	draw_line(b,b-unit.rotated(.5)*10,color,3)
	draw_line(b,b-unit.rotated(-.5)*10,color,3)

func drag_avatar(r,p,scale_value=1.1):
	if dragging!=null and dragging.id==r.id:
		draw_rect(Rect2(p-Vector2(14,32),Vector2(28,37)),Color("a7a58b"),false,1)
		return
	person(p,r.profession,false,.4 if r.retreated or r.travel>0 else 1,scale_value)
	var caption=({"musketeer":"枪","cannon":"枪","mortar":"炮","archer":"弓"}.get(r.station,"弓" if r.profession=="RANGED" else ""))+r.id.right(3)+("·"+["主","A","B"][int(r.get("origin",0))] if r.island<0 else "")
	label_at(caption,p+Vector2(-13,11),9)
	avatars.append({"rect":Rect2(p-Vector2(17,52),Vector2(34,66)),"r":r})

func dispatch_ui():
	if g.resident_count()==0:
		label_at("前往难民营或废墟，按 E 救援居民",Vector2(290,320),25)
		return
	if detail!=null:facility_ui();return
	panel(Rect2(39,173,156,373))
	label_at("无业 / 待入岛",Vector2(51,197),17)
	var unemployed=g.pool.duplicate()
	for w in g.worlds:
		for r in w.s.residents:
			if r.profession=="UNEMPLOYED":unemployed.append(r)
	label_at("共 %d 人"%unemployed.size(),Vector2(51,220),14)
	var pool_start=int(dispatch_scroll.get("pool",0))*3
	var visible_pool=unemployed.slice(pool_start,pool_start+15)
	for i in range(visible_pool.size()):
		var r=visible_pool[i]
		var p=Vector2(65+(i%3)*45,284+floor(i/3)*56)
		if p.y>528:continue
		drag_avatar(r,p,1.1)
	if unemployed.size()>15:label_at("滚轮查看更多",Vector2(51,540),12)
	for c in range(3):
		panel(Rect2(205+c*238,173,228,42))
		label_at(["建造生产","资源收集","战斗"][c],Vector2(245+c*238,200),19)
	for row in range(3):
		var w=g.worlds[row]
		var y=224+row*105
		panel(Rect2(927,y,182,97))
		label_at("岛屿 0%d"%(row+1),Vector2(943,y+28),16)
		label_at(w.cfg.name,Vector2(943,y+55),22)
		label_at("建收 %d/%d · 战斗∞"%[w.assigned_count(),w.capacity()],Vector2(936,y+79),12)
		for c in range(3):
			var rect=Rect2(205+c*238,y,228,97)
			panel(rect,Color("f3d7a2"),Color("65ad37") if rect.has_point(cursor) else Color("b1703b"))
			var group=w.s.residents.filter(func(r):return role_column(r.profession)==c and r.profession!="UNEMPLOYED")
			label_at(("%d人 · 共用%d岗"%[group.size(),w.capacity()]) if c<2 else "%d人 · 无岗位上限"%group.size(),rect.position+Vector2(8,19),12)
			var key="cell_%d_%d"%[row,c]
			var first=int(dispatch_scroll.get(key,0))*6
			var visible_group=group.slice(first,first+6)
			for i in range(visible_group.size()):
				var p=rect.position+Vector2(30+i*34,76)
				if p.y<rect.end.y-5:drag_avatar(visible_group[i],p,1.35)
			ui_buttons.append({"rect":rect,"action":func():detail={"island":row,"column":c};facility_page=0})
			drops.append({"rect":rect,"island":row,"column":c})
			label_at("滚轮翻页 · 点击设施 ›" if group.size()>6 else "点击查看设施 ›",rect.position+Vector2(100,19),12)
	label_at("按住小人跑动并拖拽；固定职业，居民树6级可自由转职；跨岛需要码头与航程",Vector2(220,551),13)

func role_column(role):
	return 0 if role=="BUILD" else 1 if role=="GATHER" else 2

func facility_ui():
	var w=g.worlds[detail.island]
	var c=detail.column
	button(Rect2(42,172,160,30),"‹ 返回调度总览",func():detail=null)
	label_at(w.cfg.name+" · "+["建造生产","资源收集","战斗"][c],Vector2(230,195),21)
	var facilities=[]
	if c<2:
		for b in w.s.buildings:facilities.append({"name":g.rules.buildings[b.kind].name+" Lv.%d"%w.building_level(b),"job":b.id,"workplace":b})
	else:
		for b in w.s.buildings:
			if b.kind=="htower":facilities.append({"name":"高塔 #"+b.id.right(3),"job":b.id,"building":b})
			elif b.kind=="mortar_array":facilities.append({"name":"迫击炮阵列 #"+b.id.right(3),"job":b.id,"mortar":b})
	var primary={"name":"未分配" if c<2 else "地面驻守 · 不限人数","job":"idle"}

	var pages=max(1,int(ceil(facilities.size()/3.0)))
	facility_page=clamp(facility_page,0,pages-1)
	if pages>1:
		button(Rect2(820,172,100,29),"上一页",func():facility_page=max(0,facility_page-1),facility_page>0)
		label_at("%d/%d"%[facility_page+1,pages],Vector2(933,193),14)
		button(Rect2(990,172,110,29),"下一页",func():facility_page=min(pages-1,facility_page+1),facility_page<pages-1)
	var columns=[primary]+facilities.slice(facility_page*3,facility_page*3+3)
	var width=1048.0/columns.size()
	var group=w.s.residents.filter(func(r):return role_column(r.profession)==c and r.profession!="UNEMPLOYED")
	for i in range(columns.size()):
		var f=columns[i]
		var x=43+i*width
		var rect=Rect2(x,218,width-10,286)
		panel(rect)
		wood(Rect2(x,218,width-10,45),f.name)
		var members=group.filter(func(r):return r.get("workplace","")==f.job) if f.has("workplace") else group.filter(func(r):return r.job==f.job and (c==2 or r.get("workplace","")==""))
		var limit=" / 3" if f.has("building") else (" / %d"%w.building_level(f.workplace) if f.has("workplace") else " / %d"%w.building_level(f.mortar) if f.has("mortar") else " · 不限" if c==2 else "")
		label_at("%d 人"%members.size()+limit,Vector2(x+13,285),14)
		if f.has("workplace"):
			label_at("建收合计 %d/%d"%[w.workplace_count(f.workplace.id),w.building_level(f.workplace)],Vector2(x+13,307),13)
			if c==1:button(Rect2(x+12,464,width-34,27),"采集类型：循环木/石/食物",func():
				for r in members:r.job=["wood","stone","food"][(max(0,["wood","stone","food"].find(r.job))+1)%3])
		if f.has("site"):bar(Rect2(x+13,293,width-36,5),f.site.progress,f.site.duration,Color("d2b877"))
		for j in range(members.size()):
			var p=Vector2(x+30+(j%int(max(1,floor((width-30)/42))))*42,337+floor(j/max(1,floor((width-30)/42)))*65)
			if p.y<480:drag_avatar(members[j],p,1.1)
		drops.append({"rect":rect,"facility":f,"island":detail.island})
	label_at("建造与收集共用建筑岗位：容量为各建筑等级之和，单栋不超过自身等级。" if c<2 else "地面驻守不限人数；高塔仅弓兵/火枪兵，同职业最多3人；迫击炮兵只操作独立阵列。",Vector2(48,535),13)
	if c==2:
		label_at("右键居民：切换协同兵种（需解锁）；左键按住拖动",Vector2(48,553),13)

func map_ui():
	panel(Rect2(40,175,680,370),Color("4c9acb"))
	for y in range(195,535,23):
		for x in range(50,710,59):draw_line(Vector2(x,y),Vector2(x+18,y),Color("76b8d3"),2)
	var positions=[Vector2(300,385),Vector2(530,270),Vector2(550,462)]
	for j in [1,2]:draw_line(positions[0],positions[j],Color("a6a684"),2)
	for i in range(3):
		var p=positions[i]
		var poly=PackedVector2Array([p+Vector2(-75,0),p+Vector2(-44,-40),p+Vector2(-10,-50),p+Vector2(18,-37),p+Vector2(54,-24),p+Vector2(70,10),p+Vector2(27,30),p+Vector2(-40,25)])
		draw_colored_polygon(poly,Color("72b83f") if g.worlds[i].s.status!="LOCKED" else Color("879b7c"))
		if i==g.active:
			for glow in [8,4,2]:draw_polyline(PackedVector2Array(Array(poly)+[poly[0]]),Color(.55,1,.35,.16 if glow>2 else .9),glow)
		pixel_tree(p-Vector2(15,10),i)
		box(Rect2(p+Vector2(14,-15),Vector2(18,21)),Color("877754"))
		label_at(g.worlds[i].cfg.name,p+Vector2(-28,52),18)
	for i in range(3):
		var w=g.worlds[i]
		var y=178+i*121
		panel(Rect2(737,y,370,112))
		label_at(w.cfg.name+"  Lv."+str(w.s.level),Vector2(750,y+25),20)
		var known=g.phase!="NIGHT" or i==g.active or g.communication()
		label_at(w.s.status+" · 码头"+("可用" if w.s.dock else "残破"),Vector2(750,y+50),14)
		label_at("核心 %d/%d"%[w.core().hp,w.core().max_hp] if known else "通讯失联",Vector2(750,y+76),15)
		button(Rect2(955,y+65,136,32),"当前岛屿" if i==g.active else "前往",func():g.message=g.begin_travel(i);menu="",i!=g.active and g.travel.time<=0)

func item_icon(slot,rect):
	if slot.is_empty():return
	var center=rect.get_center();var kind=slot.kind
	if kind=="gear":
		var item=g.items.find(slot.id)
		if item==null:return
		kind=item.kind
		var ink=Color("583321");var metal=Color("c8d2dc")
		if kind=="blade":
			draw_line(center+Vector2(-12,14),center+Vector2(12,-15),ink,7)
			draw_line(center+Vector2(-8,9),center+Vector2(12,-15),metal,4)
			draw_line(center+Vector2(-15,4),center+Vector2(0,15),Color("d78b26"),4)
		elif kind in ["shortbow","longbow","crossbow"]:
			draw_arc(center-Vector2(5,0),18,-1.2,1.2,8,ink,5)
			draw_arc(center-Vector2(5,0),18,-1.2,1.2,8,Color("c47e24"),3)
			draw_line(center+Vector2(2,-16),center+Vector2(2,16),Color("fff2be"),1)
			if kind=="crossbow":draw_line(center+Vector2(-15,12),center+Vector2(16,-8),metal,4)
		else:
			var color=Color("a96532") if kind=="leather" else Color("a6bccb") if kind=="ironarmor" else Color("7377a6")
			box(Rect2(center-Vector2(13,15),Vector2(26,30)),ink)
			box(Rect2(center-Vector2(11,13),Vector2(22,26)),color)
			box(Rect2(center-Vector2(5,15),Vector2(10,6)),Color("b87841"))
			box(Rect2(center+Vector2(-18,-10),Vector2(7,12)),color);box(Rect2(center+Vector2(11,-10),Vector2(7,12)),color)
		label_at(str(item.level),rect.position+Vector2(3,13),12)
		if item.exclusive:label_at("专",rect.end-Vector2(15,3),12,Color("87391d"))
	elif kind=="wood":
		for i in range(3):box(Rect2(center+Vector2(-15+i*5,-10+i*5),Vector2(25,7)),Color("9c5123"));box(Rect2(center+Vector2(4+i*5,-10+i*5),Vector2(6,7)),Color("efc47b"))
	elif kind in ["stone","iron"]:art.sprite(Art.ENV,2 if kind=="stone" else 3,Rect2(center-Vector2(23,20),Vector2(46,40)))
	elif kind=="food":art.sprite(Art.ENV,4,Rect2(center-Vector2(23,20),Vector2(46,40)))
	if slot.has("count"):label_at(str(int(slot.count)) if slot.count>=1 else "·",rect.end-Vector2(19,4),14)

func character_ui():
	g.items.sync();inventory_cells=[]
	# Information above, inventory below; no dedicated equipment sockets.
	panel(Rect2(49,177,1050,170),Color("f2c27c"))
	panel(Rect2(61,189,145,145),Color("8dc8de"))
	person(Vector2(134,316),"HERO_MELEE",false,1,3.0,Vector2.DOWN)
	label_at("开拓者 Lv.%d"%g.player.level,Vector2(224,207),22)
	label_at("HP %d/%d  XP %d"%[g.player.hp,g.player.max_hp,g.player.xp],Vector2(224,235),18)
	bar(Rect2(224,249,355,9),g.player.hp,g.player.max_hp,Color("7aa044"))
	label_at("木材 %d    石材 %d"%[g.resources[0],g.resources[1]],Vector2(224,286),18)
	label_at("铁矿 %d    食物 %d"%[g.resources[2],g.resources[3]],Vector2(224,315),18)
	label_at("%s · 电力 %d/%d"%[g.current().cfg.name,g.current().s.used,g.current().s.power],Vector2(663,208),20)
	label_at("库存上限 %d   研究点 %d"%[g.stock_limit(),g.research],Vector2(663,239),18)
	label_at("居民 %d/%d · 第%d天"%[g.resident_count(),g.resident_limit(),g.day],Vector2(663,270),18)
	label_at("建收岗位 %d/%d · 战斗岗位不限"%[g.current().assigned_count(),g.current().capacity()],Vector2(663,301),16)
	for i in range(36):
		var rect=Rect2(68+(i%12)*85,359+floor(i/12.0)*55,80,50)
		panel(rect,Color("ffc77f"),Color("c78342"))
		if i<12:label_at(str(i+1) if i<9 else ["0","−","="][i-9],rect.position+Vector2(3,12),10)
		if i==g.selected_slot:draw_rect(rect.grow(-2),Color("e75f29"),3)
		item_icon(g.inventory[i],rect)
		inventory_cells.append({"rect":rect,"index":i})
	label_at("点击选择 · 拖动换格 · 装备不堆叠 · 手持装备靠近居民，右键交付",Vector2(69,542),15)
	var item=g.items.held()
	if item!=null:label_at("手持："+g.items.NAMES[item.kind]+" Lv.%d"%item.level+(" · 玩家专属" if item.exclusive else ""),Vector2(224,338),14)
	if inventory_drag>=0:item_icon(g.inventory[inventory_drag],Rect2(cursor-Vector2(30,25),Vector2(60,50)))

func warehouse_ui():
	warehouse_cells=[]
	panel(Rect2(49,177,1050,170),Color("d9b77e"))
	label_at("核心仓库 · 三座岛共享",Vector2(69,207),22)
	label_at("核心仓库容量与玩家背包分开显示；仓库建筑提升核心仓库堆叠上限。",Vector2(69,235),15)
	for i in range(36):
		var top=Rect2(68+(i%12)*85,250+floor(i/12.0)*32,80,26)
		panel(top,Color("e5c48a"),Color("a47642"))
		warehouse_cells.append({"rect":top,"index":i,"source":"warehouse"})
	for i in range(36):
		item_icon(g.warehouse[i],warehouse_cells[i].rect)
		label_at("玩家物品栏",Vector2(69,359),19)
	for i in range(36):
		var rect=Rect2(68+(i%12)*85,374+floor(i/12.0)*32,80,26)
		panel(rect,Color("ffc77f"),Color("c78342"))
		item_icon(g.inventory[i],rect)
		warehouse_cells.append({"rect":rect,"index":i,"source":"bag"})
	label_at("点击上方取出资源，点击下方资源格存入核心仓库。每座仓库使单格上限 +5。",Vector2(69,535),15)

func workshop_ui():
	label_at("工匠：打造与升级",Vector2(66,203),22)
	label_at("打造后放入物品栏；选择装备后，右键居民交付。",Vector2(66,231),16)
	var kinds=g.items.COSTS.keys()
	for i in range(kinds.size()):
		var kind=kinds[i];var cost=g.items.COSTS[kind];var y=250+i*43
		label_at(g.items.NAMES[kind]+" · 木%d 石%d 铁%d"%cost,Vector2(75,y+24),17)
		button(Rect2(427,y,155,32),"打造",func():g.message=g.craft(kind))
	var held=g.items.held()
	panel(Rect2(633,255,440,213))
	label_at("装备升级",Vector2(654,287),22)
	if held!=null:
		item_icon({"kind":"gear","id":held.id},Rect2(658,306,65,65))
		label_at(g.items.NAMES[held.kind]+" Lv.%d"%held.level,Vector2(745,338),20)
		label_at("升级：木%d 石%d 铁%d"%g.items.upgrade_cost(held),Vector2(655,396),17)
		button(Rect2(655,414,390,36),"升级当前手持装备",func():g.message=g.items.craft("",held.id),held.level<5)
	else:label_at("请先到物品栏选择要升级的装备",Vector2(650,351),17)
	button(Rect2(647,490,190,35),"打开物品栏",func():menu="character")
	button(Rect2(854,490,190,35),"离开工匠",func():menu="")
	label_at(g.message.left(68),Vector2(66,547),16)

func interact_action():
	var w=g.current()
	if w.s.buildings.any(func(b):return b.kind=="mortar_array" and b.progress>=b.duration and w.pos(b).distance_to(g.player.pos)<85):g.interact();return
	if w.pos(w.core()).distance_to(g.player.pos)<110:
		menu="warehouse"
		return
	if g.player.pos.distance_to(w.camp_position())>=75:
		for r in w.builders():
			if r.travel<=0 and r.pos.distance_to(g.player.pos)<80:workshop_id=r.id;menu="workshop";return
	g.interact()

func settings_ui():
	button(Rect2(60,185,220,36),"设置选项",func():menu="settings")
	button(Rect2(300,185,220,36),"返回游戏",func():menu="")
	button(Rect2(860,185,220,36),"返回主菜单",func():g.phase="MENU";menu="main")
	label_at("存档只可在白天写入；槽位0为自动，1—9为手动",Vector2(60,255),18)
	for i in range(10):
		var x=60+(i%5)*210
		var y=280+floor(i/5)*112
		panel(Rect2(x,y,192,99))
		var exists=FileAccess.file_exists("user://island_slot_%d.json"%i)
		label_at(("自动存档" if i==0 else "手动槽 %d"%i)+(" · 有记录" if exists else " · 空"),Vector2(x+10,y+25),14)
		button(Rect2(x+10,y+42,76,34),"读取",func():g.message=g.load_slot(i);menu="";DisplayServer.window_set_title("海岛～拯救！ v0"),exists)
		button(Rect2(x+99,y+42,80,34),"保存",func():
			if exists:save_confirm=i
			else:g.message=g.save(i),g.phase=="DAY" and i>0)
	if save_confirm>=0:
		wood(Rect2(370,280,420,170),"覆盖此存档？")
		button(Rect2(395,362,165,42),"确认覆盖",func():g.message=g.save(save_confirm);save_confirm=-1)
		button(Rect2(592,362,165,42),"取消",func():save_confirm=-1)

func info_ui():
	var lines=["比勒加群岛 · 十日重建", "白天100秒 → 入夜2秒 → 夜晚80秒；三岛同步受袭。", "E救援无业居民；Tab分配工匠；采集木石后按B建造。", "按住E采集，右键吃食物；左键朝鼠标方向攻击，玩家死亡即失败。", "高塔仅弓兵或火枪兵，同职业最多3人；迫击炮使用独立阵列。", "科技与居民从2级起分化，火枪兵需协同Ⅱ，迫击炮兵需协同Ⅲ。", "整局最多获得30研究点：基地升级15点、玩家等级15点。", "修复核心和其他非防御设施每日上限25%；升级核心立即回满。", "其他岛不会停摆，远程信息依赖通讯塔；夜间交通7秒。", "第10夜无岛失守即胜利；所有岛损伤≤20%达成完美结局。", "当前任务："+g.message]
	for i in range(lines.size()):label_at(lines[i],Vector2(55,195+i*31),22 if i==0 else 16)

func draw_main():
	title_screen.draw()

func start_new_game():
	g.dispose();g=Sim.new();g.start();menu=""
	DisplayServer.window_set_title("海岛～拯救！ v0")

func result_ui():
	var title="第 %d 夜结算"%g.day
	if g.phase=="BE":title="灯火熄灭 · 失败结局"
	if g.phase=="HE":title="群岛重生 · 完美结局"
	if g.phase=="NE":title="风暴之后 · 胜利结局"
	wood(Rect2(180,150,792,355),title)
	var y=225
	for r in g.results:
		label_at("%s  损伤 %.1f%%  %s  %s"%[r.name,r.damage*100,"待收复" if r.lost else "守住","完美防御" if r.perfect else ""],Vector2(215,y),21)
		y+=51
	if g.phase=="BE":label_at("读取白天存档，重新布置防线。",Vector2(215,405),19)
	if g.phase in ["HE","NE"]:label_at("你让三座岛的灯火，照亮了第十一日的晨曦。",Vector2(215,405),19)
	var reward_y=395
	for i in range(g.reward_choices.size()):
		var reward=g.reward_choices[i]
		label_at(g.worlds[reward.island].cfg.name+" 完美防御奖励：",Vector2(215,reward_y),15)
		button(Rect2(455,reward_y-23,125,28),"产出 +20%",func():g.message=g.choose_reward(i,0),reward.choice==-1)
		button(Rect2(590,reward_y-23,125,28),"信赖 +1",func():g.message=g.choose_reward(i,1),reward.choice==-1)
		button(Rect2(725,reward_y-23,125,28),"流民 1 名",func():g.message=g.choose_reward(i,2),reward.choice==-1)
		reward_y+=34
	button(Rect2(290,440,570,44),"迎接新一天" if g.phase=="RESULT" else "回到存档 / 开始另一条路线",func():
		if g.phase=="RESULT":g.next_day();menu=""
		else:menu="settings";g.phase="MENU")

func build_ui():
	wood(Rect2(200,120,752,465),"工匠建造目录")
	var kinds=["wall","barricade","htower","warehouse","house","generator","tesla","collector","repairer","mortar_array"]
	for i in range(kinds.size()):
		var kind=kinds[i]
		var d=g.rules.buildings[kind]
		var p=Vector2(220+(i%3)*240,179+floor(i/3)*85)
		button(Rect2(p,Vector2(220,57)),d.name,func():placement=kind;wall_start=null;menu="",g.tech>=d.tech)
		label_at("%d木 %d石 %d铁 · %d×%d"%[d.cost[0],d.cost[1],d.cost[2],d.w,d.h],p+Vector2(3,74),13)
	button(Rect2(735,545,190,32),"取消建造",func():menu="";placement="")

func resident_context():
	var r=detail.resident
	wood(Rect2(300,165,550,390),({"musketeer":"火枪兵","cannon":"火枪兵","mortar":"迫击炮兵"}.get(r.station,ROLE_NAMES[r.profession]))+" #"+r.id.right(3))
	label_at("信赖 %.1f  HP %d/%d"%[r.faith,r.hp,r.max_hp],Vector2(325,220),18)
	for i in range(4):
		var kind=["","archer","musketeer","mortar"][i]
		button(Rect2(325+i*125,240,115,36),["普通兵种","弓兵","火枪兵","迫击炮兵"][i],func():g.message=g.set_station(r,kind))
	label_at("装备需在物品栏选择，靠近居民后右键交付。",Vector2(325,330),17)
	label_at("玩家专属装备无法交付；打造和升级请找工匠。",Vector2(325,365),17)

	button(Rect2(325,463,490,38),"返回居民总览",func():detail=null)

func screen_to_ui(point):
	return Vector2(576,324)+(point-Vector2(576,324))/preferences.values.ui_scale

func set_ui_transform():
	var scale_value=preferences.values.ui_scale
	draw_set_transform(Vector2(576,324)*(1-scale_value),0,Vector2.ONE*scale_value)
	if not ui_scale_applied:cursor=screen_to_ui(cursor)
	ui_scale_applied=true

func _draw():
	var pointer=cursor
	ui_scale_applied=false
	inventory_cells=[]
	_draw_content()
	if ui_scale_applied:
		var scale_value=preferences.values.ui_scale
		for b in ui_buttons:
			if not b.get("screen_space",false):b.rect=Rect2(Vector2(576,324)+(b.rect.position-Vector2(576,324))*scale_value,b.rect.size*scale_value)
		for a in avatars:a.rect=Rect2(Vector2(576,324)+(a.rect.position-Vector2(576,324))*scale_value,a.rect.size*scale_value)
		for cell in inventory_cells:cell.rect=Rect2(Vector2(576,324)+(cell.rect.position-Vector2(576,324))*scale_value,cell.rect.size*scale_value)
		for d in drops:d.rect=Rect2(Vector2(576,324)+(d.rect.position-Vector2(576,324))*scale_value,d.rect.size*scale_value)
	cursor=pointer
	draw_set_transform(Vector2.ZERO)

func _draw_content():
	if g==null:return
	ui_buttons=[];avatars=[];drops=[]
	if menu=="main" or menu.begins_with("title_"):
		water_layer.visible=false
		title_screen.draw()
		return
	water_layer.visible=true
	var original_cursor=cursor
	var zoom=preferences.values.zoom
	var anchor=Vector2(576,355)
	cursor=(cursor-anchor)/zoom+anchor
	water_layer.position=anchor*(1-zoom);water_layer.scale=Vector2(zoom,zoom)
	set_world_transform()
	draw_world()
	draw_set_transform(Vector2.ZERO)
	cursor=original_cursor
	set_ui_transform()
	hud()
	if menu=="settings":preferences.draw(false);return
	if menu=="main":draw_main()
	elif menu=="build":build_ui()
	elif menu!="":
		menu_shell({"info":"群岛日志","character":"角色与物品","workshop":"工匠作坊","tree":"成长技能书","dispatch":"居民调度","map":"群岛地图","saves":"存档管理"}.get(menu,"菜单"))
		if menu=="info":info_ui()
		elif menu=="tree":tree_ui()
		elif menu=="map":map_ui()
		elif menu=="dispatch":
			if detail!=null and detail.has("resident"):resident_context()
			else:dispatch_ui()
		elif menu=="character":character_ui()
		elif menu=="warehouse":warehouse_ui()
		elif menu=="workshop":workshop_ui()
		elif menu=="saves":settings_ui()
	if menu=="" and g.phase in ["RESULT","BE","HE","NE"]:result_ui()
	if dragging!=null:person(cursor,dragging.profession,true,1,2,drag_facing)

func _process(dt):
	clock+=dt
	if menu=="main" or menu.begins_with("title_"):title_screen.advance(dt)
	var old_cursor=cursor
	cursor=get_global_mouse_position()
	if dragging!=null and cursor.distance_to(old_cursor)>1:drag_facing=(cursor-old_cursor).normalized()
	if menu=="":
		accumulator=min(accumulator+dt,.2)
		while accumulator>=.05:
			var direction=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
			g.move(direction,.05)
			if Input.is_physical_key_pressed(KEY_E):g.gather(.05)
			g.tick(.05)
			accumulator-=.05
	else:accumulator=0
	if last_phase!=g.phase:
		last_phase=g.phase
		play_music()
	queue_redraw()

func play_music():
	var name="night" if g.phase=="NIGHT" else "day"
	if g.day==10 and g.phase=="NIGHT":name="final"
	var path="res://assets/"+name+".wav"
	if ResourceLoader.exists(path):
		music.stream=load(path)
		music.play()
		preferences.apply_audio()
	if not music.finished.is_connected(repeat_music):music.finished.connect(repeat_music)

func repeat_music():
	if not muted and is_inside_tree() and not is_queued_for_deletion():music.play()

func sound():
	if muted:return
	if ResourceLoader.exists("res://assets/click.wav"):
		audio.stream=load("res://assets/click.wav");audio.play()

func finish_drag():
	for target in drops:
		if not target.rect.has_point(cursor):continue
		if target.has("facility"):
			if dragging.profession=="UNEMPLOYED":g.message="先拖入岛屿职业格分配职业，再分配设施";break
			var f=target.facility
			var w=g.worlds[target.island]
			if w.s.status!="OWNED":
				g.message="先收复岛屿，再恢复设施调度"
				break
			if f.has("workplace"):g.message=w.assign_workplace(dragging,f.workplace)
			elif f.has("mortar"):g.message=w.assign_mortar(dragging,f.mortar)
			elif f.has("building"):g.message=w.station(dragging.id,f.building)
			elif f.has("site"):g.message=w.assign_builder(f.site,dragging)
			else:
				w.unstation(dragging)
				dragging.job=f.job
				g.message="已分配到"+f.name
		else:
			var profession=dragging.profession
			var choosing_combat=false
			if role_column(profession)!=target.column or profession=="UNEMPLOYED":
				profession=["BUILD","GATHER","MELEE" if g.story.combat_next%2==0 else "RANGED"][target.column]
				choosing_combat=target.column==2
			g.message=g.assign(dragging,target.island,profession)
			if choosing_combat and g.message.begins_with("调度已提交"):g.story.combat_next+=1
		break
	dragging=null

func placement_click(cell):
	if placement=="wall":
		if wall_start==null:
			wall_start=cell
			g.message="移动鼠标延伸墙线，再次左键确认；右键取消"
		else:
			g.message=g.current().place_wall_line(wall_start,cell)
			if g.message.begins_with("已创建"):wall_start=null
	else:g.message=g.current().place(placement,cell)

func set_world_transform():
	var z=preferences.values.zoom
	draw_set_transform(Vector2(576,355)*(1-z),0,Vector2(z,z))

func screen_to_world(point):
	return (point-Vector2(576,355))/preferences.values.zoom+g.player.pos

func _input(event):
	if preferences!=null and preferences.handle_input(event):return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_TAB,KEY_ESCAPE]:
			if g.phase=="MENU":menu="main"
			else:menu="info" if menu=="" else ""
			detail=null;dragging=null;placement="";wall_start=null;selected=null
		if event.keycode==KEY_I:
			if g.phase=="MENU":return
			inventory_drag=-1;menu="" if menu=="character" else "character";return
		if menu!="":return
		var quick_keys=[KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0,KEY_MINUS,KEY_EQUAL]
		if event.keycode in quick_keys:g.message=g.items.equip(quick_keys.find(event.keycode));return
		if event.keycode==KEY_F:g.message="请使用鼠标右键食物回血"
		if event.keycode==KEY_E:interact_action()
		if event.keycode==KEY_U:g.message=g.upgrade_core()
		if event.keycode==KEY_B:
			var workers=g.current().builders()
			if g.phase=="TRANSITION":g.message="入夜转场不可建造"
			elif g.phase=="NIGHT" and (not g.current().s.enemies.is_empty() or g.current().s.cursor<g.current().s.wave.size()):g.message="本岛波次清空后才能建造"
			elif workers.any(func(r):return r.pos.distance_to(g.player.pos)<110):menu="build"
			else:g.message="先找到建造居民，并靠近工匠按B"
	if event is InputEventMouseButton:
		cursor=event.position
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and menu=="dispatch" and detail==null:
			var key=""
			var max_scroll=0
			if Rect2(39,224,156,322).has_point(cursor):
				key="pool"
				var count=g.pool.size()
				for w in g.worlds:count+=w.s.residents.filter(func(r):return r.profession=="UNEMPLOYED").size()
				max_scroll=max(0,int(ceil(count/3.0))-5)
			else:
				for d in drops:
					if d.rect.has_point(cursor) and d.has("column"):
						key="cell_%d_%d"%[d.island,d.column]
						var count=g.worlds[d.island].s.residents.filter(func(r):return role_column(r.profession)==d.column and r.profession!="UNEMPLOYED").size()
						max_scroll=max(0,int(ceil(count/6.0))-1)
			if key!="":dispatch_scroll[key]=clamp(dispatch_scroll.get(key,0)+(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1),0,max_scroll)
			return
		if event.button_index==MOUSE_BUTTON_LEFT and menu=="warehouse" and event.pressed:
			for cell in warehouse_cells:
				if cell.rect.has_point(cursor):
					if cell.source=="warehouse":g.message=g.warehouse_withdraw(cell.index)
					else:g.message=g.warehouse_transfer(-1,cell.index)
					return
		if event.button_index==MOUSE_BUTTON_LEFT and menu=="character":
			if event.pressed:
				for cell in inventory_cells:
					if cell.rect.has_point(cursor):inventory_drag=cell.index;inventory_drag_origin=cursor;return
			elif inventory_drag>=0:
				for cell in inventory_cells:
					if cell.rect.has_point(cursor):
						if cell.index==inventory_drag:g.message=g.items.equip(cell.index)
						else:g.items.move_slot(inventory_drag,cell.index)
						break
				inventory_drag=-1;return
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			if menu=="" and placement=="":
				var point=screen_to_world(cursor)
				if g.items.held()==null:
					g.heal()
					return
				for r in g.current().s.residents:
					if point.distance_to(r.pos)<28 and r.pos.distance_to(g.player.pos)<85:
						if g.items.held()!=null:g.message=g.items.give(r)
						elif r.profession=="BUILD":workshop_id=r.id;menu="workshop"
						return
			placement="";wall_start=null;selected=null
			if menu=="dispatch":
				for a in avatars:
					if a.rect.has_point(cursor):detail={"resident":a.r};return
		if event.button_index!=MOUSE_BUTTON_LEFT:return
		if not event.pressed:
			if dragging!=null:finish_drag()
			return
		if menu=="dispatch" and (detail==null or not detail.has("resident")):
			for a in avatars:
				if a.rect.has_point(cursor):dragging=a.r;return
		for i in range(ui_buttons.size()-1,-1,-1):
			if ui_buttons[i].rect.has_point(cursor):ui_buttons[i].action.call();sound();return
		if menu!="" or g.phase not in ["DAY","TRANSITION","NIGHT"] or g.travel.time>0:return
		if placement!="":placement_click(Vector2i((screen_to_world(cursor)/32).floor()));sound();return
		var world_pos=screen_to_world(cursor)
		for b in g.current().s.buildings:
			var d=g.rules.buildings[b.kind]
			if Rect2(Vector2(b.cell)*32,Vector2(d.w,d.h)*32).has_point(world_pos):selected=b;return
		g.attack(world_pos-g.player.pos)
		sound()






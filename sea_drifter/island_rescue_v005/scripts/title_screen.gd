extends RefCounted
## Animated title composition, matching the user's left-scene/right-sign layout.
var game
var time=0.0
func _init(canvas):game=canvas
func advance(dt):time+=dt
func polygon(points,color):game.draw_colored_polygon(PackedVector2Array(points),Color(color))
func cloud(p,scale_value):
	for i in range(5):
		var at=p+Vector2(i*18,sin(i*1.7)*8)*scale_value
		game.box(Rect2(at,Vector2(39,11)*scale_value),Color("e5ddc4"))
		game.box(Rect2(at+Vector2(6,-6)*scale_value,Vector2(24,8)*scale_value),Color("f1e7cc"))
func sign_board(index,text,rect,tag,action,enabled=true):
	var fall=pow(max(0.0,1.0-time/1.35),3)*-570
	var center=rect.get_center()+Vector2(sin(time*1.2+index*.45)*3,fall)
	var angle=sin(time*1.15+index*.55)*.014
	game.draw_set_transform(center,angle,Vector2.ONE)
	var local=Rect2(-rect.size/2,rect.size)
	game.wood(local)
	var hover=rect.has_point(game.cursor) and enabled
	if hover:game.draw_rect(local.grow(-5),Color("e5ce86"),false,2)
	var font_size=39 if index==0 else 29
	var width=game.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	game.label_at(text,Vector2(-width/2,font_size*.34),font_size,Color("663213") if enabled else Color("a1845b"))
	for side in [-1,1]:
		game.box(Rect2(Vector2(side*75-3,-rect.size.y/2+8),Vector2(6,6)),Color("d3b882"))
	game.draw_set_transform(Vector2.ZERO)
	if enabled and time>.5:game.ui_buttons.append({"rect":Rect2(center-rect.size/2,rect.size).grow(4),"tag":tag,"action":action})
func draw():
	# Warm sky, layered distant islands, and an animated pixel sea.
	for y in range(0,648,8):
		var color=Color("a9e0fb").lerp(Color("d9f3df"),min(1.0,y/280.0)) if y<280 else Color("227fba").lerp(Color("1264a1"),(y-280)/368.0)
		game.box(Rect2(0,y,1152,8),color)
	cloud(Vector2(fmod(time*3+80,850)-80,88),1.3)
	cloud(Vector2(fmod(time*2+430,900)-60,250),.85)
	polygon([Vector2(20,300),Vector2(95,248),Vector2(127,266),Vector2(163,230),Vector2(220,299)],"62a98a")
	polygon([Vector2(475,300),Vector2(542,253),Vector2(567,261),Vector2(610,218),Vector2(674,300)],"62a98a")
	for y in range(298,648,14):
		for i in range(15):
			var x=fmod(i*91+y*.61+time*(4+y*.013),1160)-30
			game.box(Rect2(x,y+sin(time*1.1+i)*2,18+(i%4)*7,2),Color(.62,.79,.76,.12+(i%3)*.035))
	var bob=sin(time*1.2)*2
	var p=Vector2(365,492+bob)
	# Shore ripples and island body; original environment atlas supplies vegetation.
	for ring in range(3):
		var spread=sin(time*1.8-ring*.8)*4+ring*10
		var points=[]
		for i in range(33):
			var a=i*TAU/32
			points.append(p+Vector2(cos(a)*(228+spread),sin(a)*(61+spread*.5)))
		game.draw_polyline(PackedVector2Array(points),Color(.7,.87,.82,.23-ring*.05),2)
	var outline=[Vector2(-221,1),Vector2(-194,-37),Vector2(-120,-57),Vector2(-37,-49),Vector2(26,-61),Vector2(108,-48),Vector2(187,-27),Vector2(224,5),Vector2(181,39),Vector2(75,61),Vector2(-83,58),Vector2(-184,34)]
	var shore=[]
	for v in outline:shore.append(p+v)
	polygon(shore,"f4ca79")
	var grass=[]
	for v in outline:grass.append(p+Vector2(v.x*.93,v.y*.8-9))
	polygon(grass,"75b83f")
	polygon([p+Vector2(-104,-25),p+Vector2(-58,-90),p+Vector2(-33,-156),p+Vector2(12,-162),p+Vector2(35,-87),p+Vector2(95,-22)],"b98d66")
	polygon([p+Vector2(-33,-156),p+Vector2(-15,-99),p+Vector2(0,-39),p+Vector2(41,-27),p+Vector2(12,-162)],"d9b27b")
	var mountain=PackedVector2Array([Vector2(-104,-25),Vector2(-58,-90),Vector2(-33,-156),Vector2(12,-162),Vector2(35,-87),Vector2(95,-22)])
	for y in range(-150,-26,5):
		for x in range(-100,95,5):
			var pattern=posmod(x*13+y*19,71)
			if pattern<19 and Geometry2D.is_point_in_polygon(Vector2(x,y),mountain):
				game.box(Rect2(p+Vector2(x,y),Vector2(5,3+(pattern%3))),Color("e3bf84") if pattern<8 else Color("98724f"))
	polygon([p+Vector2(-37,-155),p+Vector2(-25,-166),p+Vector2(9,-169),p+Vector2(20,-157),p+Vector2(4,-148),p+Vector2(-23,-148)],"363f3c")
	for i in range(4):
		var drift=fmod(time*13+i*17,78)
		game.box(Rect2(p+Vector2(-18+sin(time+i)*9,-175-drift),Vector2(12+drift*.16,7)),Color(.75,.76,.67,(1-drift/78)*.35))
	game.art.sprite(game.art.ENV,0,Rect2(p+Vector2(-178,-105),Vector2(72,94)))
	game.art.sprite(game.art.ENV,1,Rect2(p+Vector2(126,-71),Vector2(66,83)))
	game.art.sprite(game.art.ENV,5,Rect2(p+Vector2(-48,-43),Vector2(87,82)))
	game.art.sprite(game.art.ENV,6,Rect2(p+Vector2(41,-21),Vector2(52,52)))
	for i in range(3):game.art.person(p+Vector2(-86+i*23,25),["BUILD","GATHER","RANGED"][i],true,1,.72)
	if game.preferences.values.background!="标准":
		game.box(Rect2(0,0,1152,648),Color(.12,.09,.28,.43) if game.preferences.values.background=="夜色" else Color(.74,.22,.08,.23))
	# Title emerges from below then settles. Keep its left/right relationship fixed.
	var title_y=171+pow(max(0.0,1-time/1.2),3)*35
	game.label_at("海岛～拯救！",Vector2(69,title_y+4),65,Color("304942"))
	game.label_at("海岛～拯救！",Vector2(66,title_y),65,Color("f3e2b4"))
	game.label_at("十日重建 · 守住群岛的最后灯火",Vector2(105,title_y+46),20,Color("306a54"))
	game.label_at("像素海岛生存",Vector2(55,613),14,Color("e4f5ca"))
	var active=game.menu=="main"
	for side in [-1,1]:
		var x=939+side*75+sin(time*1.2)*3
		game.draw_line(Vector2(x,0),Vector2(x,545),Color("443b2d"),5)
		game.draw_line(Vector2(x-1,0),Vector2(x-1,545),Color("a99366"),2)
	sign_board(0,"开始",Rect2(804,126,270,92),"title_start",func():game.start_new_game(),active)
	sign_board(1,"读取",Rect2(822,267,234,70),"title_load",func():game.menu="title_load",active)
	sign_board(2,"设置",Rect2(822,377,234,70),"title_settings",func():game.menu="title_settings",active)
	sign_board(3,"退出",Rect2(822,487,234,70),"title_exit",func():game.menu="title_exit",active)
	if game.menu!="main":panel()
func panel():
	if game.menu=="title_settings":game.preferences.draw(true);return
	game.box(Rect2(0,0,1152,648),Color(0,0,0,.48))
	game.wood(Rect2(150,150,852,370),{"title_load":"读取存档","title_settings":"设置","title_exit":"退出游戏","title_closed":"本次游玩已结束"}.get(game.menu,"菜单"))
	if game.menu=="title_load":
		for i in range(10):
			var rect=Rect2(185+(i%5)*158,235+floor(i/5)*83,145,59)
			var exists=FileAccess.file_exists("user://island_slot_%d.json"%i)
			game.button(rect,("自动" if i==0 else "存档%d"%i)+(" · 读取" if exists else " · 空"),func():
				game.g.message=game.g.load_slot(i)
				if game.g.phase=="DAY":game.menu="",exists)
	elif game.menu=="title_settings":
		game.button(Rect2(290,245,570,48),"音量："+("关闭" if game.muted else "开启"),func():game.muted=not game.muted;game.music.stream_paused=game.muted)
		game.button(Rect2(290,318,570,48),"伤害数字："+("开启" if game.show_numbers else "关闭"),func():game.show_numbers=not game.show_numbers)
	elif game.menu=="title_exit":
		game.label_at("确定结束本次游玩吗？",Vector2(380,270),26)
		game.button(Rect2(350,320,450,52),"确认退出",func():
			if OS.has_feature("web"):game.music.stop();game.menu="title_closed"
			else:game.get_tree().quit())
	else:game.label_at("可关闭游戏页面，或返回标题重新开始。",Vector2(306,300),22)
	game.button(Rect2(380,438,392,42),"返回标题",func():game.menu="main")

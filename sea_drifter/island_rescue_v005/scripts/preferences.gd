extends RefCounted
var game
var view="options"
var popup=""
var dragging_slider=""
var sliders={}
const UI_SCALES=[.75,.9,1.0,1.1]
const RESOLUTIONS=["1152 × 648","1280 × 720","1382 × 778","1600 × 900","1920 × 1080"]
const DEFAULTS={"tutorial":true,"zoom":1.0,"effects":10,"music":10,"numbers":true,"fullscreen":false,"window_mode":"窗口","resolution":"1382 × 778","background":"标准","vsync":true,"ui_scale":1.0}
const ZOOMS=[1.0,1.25,1.5,2.0]
var values=DEFAULTS.duplicate()
func _init(canvas):
	game=canvas
	if OS.get_environment("ISLAND_TEST_MODE")!="1":load_from("user://preferences.cfg")
	apply_audio()
	if not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
		if values.window_mode=="无边框":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
	game.show_numbers=values.numbers
	if not OS.has_feature("web") and values.fullscreen:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
func load_from(path):
	var config=ConfigFile.new()
	if config.load(path)!=OK:return false
	for key in DEFAULTS:values[key]=config.get_value("options",key,DEFAULTS[key])
	values.effects=clamp(int(values.effects),0,10);values.music=clamp(int(values.music),0,10)
	if not ZOOMS.has(values.zoom):values.zoom=1.0
	if not UI_SCALES.has(values.ui_scale):values.ui_scale=1.0
	if not RESOLUTIONS.has(values.resolution):values.resolution=DEFAULTS.resolution
	return true
func save_to(path):
	var config=ConfigFile.new()
	for key in values:config.set_value("options",key,values[key])
	return config.save(path)==OK
func save():
	if OS.get_environment("ISLAND_TEST_MODE")!="1":save_to("user://preferences.cfg")
func apply_audio():
	game.audio.volume_db=linear_to_db(values.effects/10.0) if values.effects>0 else -80
	game.music.volume_db=-22+(linear_to_db(values.music/10.0) if values.music>0 else -58)
	game.music.stream_paused=values.music==0
	game.muted=values.music==0 and values.effects==0
func set_option(key,value):
	if not DEFAULTS.has(key):return
	if key in ["effects","music"]:value=clamp(int(value),0,10)
	if key=="zoom" and not ZOOMS.has(value):return
	if key=="ui_scale" and not UI_SCALES.has(value):return
	values[key]=value
	if key=="vsync" and not OS.has_feature("web"):DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
	if key=="window_mode":apply_window_mode(value)
	if key=="resolution" and not OS.has_feature("web") and not is_fullscreen():
		var parts=value.split(" × ");DisplayServer.window_set_size(Vector2i(int(parts[0]),int(parts[1])))
	game.show_numbers=values.numbers
	apply_audio();save()
func is_fullscreen():
	if OS.has_feature("web"):return JavaScriptBridge.eval("!!document.fullscreenElement") == true
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
func toggle_fullscreen():
	var enable=not is_fullscreen()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(document.fullscreenElement ? document.exitFullscreen() : document.getElementById('canvas').requestFullscreen()).catch(e=>console.error('Fullscreen: '+e.message));")
	else:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enable else DisplayServer.WINDOW_MODE_WINDOWED)
	values.fullscreen=enable;save()
func reset():
	var exit_fullscreen=is_fullscreen()
	values=DEFAULTS.duplicate();game.show_numbers=true;apply_audio()
	if not OS.has_feature("web"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,false)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if exit_fullscreen:toggle_fullscreen()
	save()
func arrow(rect,text,tag,action,enabled=true):
	game.button(rect,"",action,enabled,Color("d5913f"))
	var center=rect.get_center().round()
	var ink=Color("6c351a") if enabled else Color("947954")
	if text in ["−","＋"]:
		game.box(Rect2(center-Vector2(7,2),Vector2(14,4)),ink)
		if text=="＋":game.box(Rect2(center-Vector2(2,7),Vector2(4,14)),ink)
	elif text in ["‹","›"]:
		var side=-1 if text=="‹" else 1
		game.draw_colored_polygon(PackedVector2Array([center+Vector2(side*6,0),center+Vector2(-side*4,-7),center+Vector2(-side*4,7)]),ink)
	elif text=="√":
		game.box(Rect2(center-Vector2(10,10),Vector2(20,20)),Color("75411f"))
		game.box(Rect2(center-Vector2(7,7),Vector2(14,14)),Color("fff0bd"))
	if enabled:game.ui_buttons[-1].tag=tag
func cycle_zoom(direction):
	var index=ZOOMS.find(values.zoom)
	set_option("zoom",ZOOMS[clamp(index+direction,0,ZOOMS.size()-1)])
func apply_window_mode(mode):
	if OS.has_feature("web"):
		if (mode=="全屏")!=is_fullscreen():toggle_fullscreen()
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,mode=="无边框")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode=="全屏" else DisplayServer.WINDOW_MODE_WINDOWED)
	values.fullscreen=mode=="全屏"

func slider(key,rect,label):
	sliders[key]=rect
	game.label_at(label,rect.position+Vector2(0,-16),22)
	game.box(rect.grow(3),Color("73331d"));game.box(rect,Color("ae9c72"))
	game.box(Rect2(rect.position+Vector2(2,2),Vector2(rect.size.x-4,3)),Color("d5c394"))
	var x=rect.position.x+(rect.size.x-24)*values[key]/10.0
	game.box(Rect2(x,rect.position.y-3,24,rect.size.y+6),Color("783217"))
	game.box(Rect2(x+3,rect.position.y,18,rect.size.y),Color("df8506"))
	game.box(Rect2(x+5,rect.position.y+2,14,3),Color("ffba41"))
	game.label_at("%d%%"%(values[key]*10),rect.end+Vector2(14,-1),18)

func handle_input(event):
	if game.menu not in ["settings","title_settings"]:dragging_slider="";return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			var active=dragging_slider!="";dragging_slider="";save();return active
		var p=game.screen_to_ui(event.position)
		for key in sliders:
			if sliders[key].grow(10).has_point(p):dragging_slider=key;update_slider(p);return true
	elif event is InputEventMouseMotion and dragging_slider!="":update_slider(game.screen_to_ui(event.position));return true
	return false

func update_slider(p):
	var rect=sliders[dragging_slider]
	values[dragging_slider]=clamp(int(round((p.x-rect.position.x-12)/(rect.size.x-24)*10)),0,10)
	apply_audio();game.queue_redraw()

func check_box(rect,label,tag,on,action,enabled=true):
	game.box(rect.grow(3),Color("824224") if enabled else Color("bb8554"))
	game.box(rect,Color("ffc983") if enabled else Color("e7b878"))
	if on:
		game.draw_line(rect.position+Vector2(5,13),rect.position+Vector2(10,19),Color("673016"),3)
		game.draw_line(rect.position+Vector2(10,19),rect.position+Vector2(22,6),Color("673016"),3)
	game.label_at(label,rect.position+Vector2(38,22),21,Color("613018") if enabled else Color("a7784f"))
	if enabled:game.ui_buttons.append({"rect":Rect2(rect.position,Vector2(38+label.length()*21,rect.size.y)),"tag":tag,"action":action})

func dropdown(rect,text,key,options,enabled=true):
	game.box(rect.grow(3),Color("78391f") if enabled else Color("c18e59"))
	game.box(rect,Color("df8b07") if enabled else Color("edb367"))
	game.label_at(text,rect.position+Vector2(8,27),19,Color("40200f") if enabled else Color("a47e4e"))
	var center=rect.end-Vector2(19,rect.size.y*.5)
	game.draw_line(Vector2(rect.end.x-38,rect.position.y),Vector2(rect.end.x-38,rect.end.y),Color("9e4d1c"),3)
	game.draw_colored_polygon(PackedVector2Array([center+Vector2(-10,-5),center+Vector2(10,-5),center+Vector2(0,9)]),Color("79401d") if enabled else Color("c99d5e"))
	if enabled:game.ui_buttons.append({"rect":rect,"tag":key+"_dropdown","action":func():popup="" if popup==key else key})
	if popup==key and enabled:return {"key":key,"rect":rect,"options":options}
	return {}

func draw(from_title):
	game.set_ui_transform()
	game.ui_buttons=[];sliders={}
	game.box(Rect2(-300,-200,1752,1048),Color(0,0,0,.6))
	game.wood(Rect2(116,48,920,548),{"options":"设置","controls":"操作说明","credits":"制作人员","privacy":"本机数据说明"}.get(view,"设置"))
	game.box(Rect2(128,96,896,488),Color("ffc67d"))
	if view!="options":
		var lines=[]
		if view=="controls":lines=["WASD / 方向键：移动","E：交互；按住 E：采集自然资源","B：靠近工匠打开建造菜单","城墙：左键起点 → 移动鼠标 → 左键确认","左键：攻击 / 选择；右键：取消建造","F：食物回血；U：在核心旁升级","Tab / Esc：打开或关闭菜单","居民：按住拖动到职业 / 设施，松开确认"]
		elif view=="credits":lines=["海岛～拯救！","游戏设计：基于用户提供的 GDD 与迭代需求","开发引擎：Godot 4.7.2","程序与界面：AI 辅助实现","美术：原创像素图集与程序动画","字体：Fusion Pixel（授权随工程提供）"]
		else:lines=["游戏进度与设置保存在当前设备。","浏览器版本使用本机浏览器存储。","游戏没有账号登录或联网排行榜。","恢复默认设置不会删除游戏存档。"]
		for i in range(lines.size()):game.label_at(lines[i],Vector2(155,137+i*43),19)
		game.button(Rect2(380,526,392,42),"返回设置",func():view="options")
		return
	game.label_at("图像：",Vector2(150,127),27)
	game.label_at("音效：",Vector2(724,127),27)
	var menus=[]
	var window_mode="全屏" if is_fullscreen() else (values.window_mode if values.window_mode!="全屏" else "窗口")
	menus.append(dropdown(Rect2(152,153,282,38),window_mode,"window_mode",["窗口","全屏"] if OS.has_feature("web") else ["窗口","无边框","全屏"]))
	game.label_at("窗口模式",Vector2(455,181),22)
	var can_resize=not OS.has_feature("web") and not is_fullscreen()
	menus.append(dropdown(Rect2(152,216,282,38),values.resolution if not OS.has_feature("web") else "浏览器自适应","resolution",RESOLUTIONS,can_resize))
	game.label_at("分辨率",Vector2(455,244),22,Color("633018") if can_resize else Color("aa794e"))
	menus.append(dropdown(Rect2(152,279,282,38),values.background,"background",["标准","暮色","夜色"]))
	game.label_at("菜单背景",Vector2(455,307),22)
	check_box(Rect2(152,345,26,26),"垂直同步","vsync",values.vsync,func():set_option("vsync",not values.vsync),not OS.has_feature("web"))
	if OS.has_feature("web"):game.label_at("由浏览器管理",Vector2(370,366),15,Color("a57649"))
	arrow(Rect2(150,405,32,30),"−","ui_down",func():set_option("ui_scale",UI_SCALES[max(0,UI_SCALES.find(values.ui_scale)-1)]),values.ui_scale>UI_SCALES[0])
	game.label_at("%d%%"%int(values.ui_scale*100),Vector2(196,429),22)
	arrow(Rect2(279,405,32,30),"＋","ui_up",func():set_option("ui_scale",UI_SCALES[min(UI_SCALES.size()-1,UI_SCALES.find(values.ui_scale)+1)]),values.ui_scale<UI_SCALES[-1])
	game.label_at("界面缩放比例",Vector2(333,430),21)
	slider("music",Rect2(727,172,190,15),"音乐音量")
	slider("effects",Rect2(727,259,190,15),"音效音量")
	check_box(Rect2(726,318,26,26),"教程提示","tutorial",values.tutorial,func():set_option("tutorial",not values.tutorial))
	check_box(Rect2(726,368,26,26),"伤害数字","numbers",values.numbers,func():set_option("numbers",not values.numbers))
	game.label_at("场景缩放",Vector2(726,431),18)
	arrow(Rect2(837,406,30,30),"‹","zoom_down",func():cycle_zoom(-1),values.zoom>ZOOMS[0])
	game.label_at("%d%%"%int(values.zoom*100),Vector2(879,429),18)
	arrow(Rect2(961,406,30,30),"›","zoom_up",func():cycle_zoom(1),values.zoom<ZOOMS[-1])
	game.draw_line(Vector2(150,458),Vector2(1000,458),Color("b96c35"),2)
	var actions=[{"text":"操作说明","action":func():view="controls"},{"text":"恢复默认","action":func():reset();popup=""},{"text":"制作人员","action":func():view="credits"},{"text":"本机数据","action":func():view="privacy"}]
	for i in range(actions.size()):game.button(Rect2(150+i*216,477,204,35),actions[i].text,actions[i].action)
	game.label_at("设置自动保存",Vector2(152,554),15)
	game.button(Rect2(574,532,204,35),"返回标题" if from_title else "存档管理",func():game.menu="main" if from_title else "saves";popup="")
	game.button(Rect2(798,532,204,35),"关闭设置" if from_title else "返回游戏",func():game.menu="main" if from_title else "";popup="")
	# Popup options are last in both draw and hit order.
	for menu in menus:
		if menu.is_empty():continue
		for i in range(menu.options.size()):
			var value=menu.options[i];var rect=Rect2(menu.rect.position+Vector2(0,menu.rect.size.y+2+i*34),Vector2(menu.rect.size.x,34))
			game.box(rect.grow(2),Color("7a391f"));game.box(rect,Color("ffda95"))
			game.label_at(value,rect.position+Vector2(8,24),19)
			game.ui_buttons.append({"rect":rect,"tag":menu.key+"_"+str(i),"action":func():set_option(menu.key,value);popup=""})

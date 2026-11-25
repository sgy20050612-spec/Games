extends SceneTree
## Staged endgame data for visual review; never loaded by the normal main scene.
var game

func _initialize():call_deferred("run")

func capture(name):
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/"+name+".png")

func place(kind, desired):
	var w=game.g.current()
	for radius in range(5):
		for dx in range(-radius,radius+1):
			for dy in range(-radius,radius+1):
				var cell=desired+Vector2i(dx,dy)
				if w.can_place(kind,cell)=="":return w.add_building(kind,cell,true)
	return null

func run():
	root.size=Vector2i(1152,648)
	DirAccess.make_dir_recursive_absolute("res://previews")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.menu=""
	var g=game.g
	g.phase="DAY";g.day=10;g.remaining=55
	g.story.artisan=true;g.story.settlers=true
	g.tech=4;g.resident_tree=4;g.research=0;g.earned_research=30
	g.player.level=10;g.player.xp=1080;g.player.max_hp=180;g.player.hp=180
	g.player.pos=Vector2(464,520)
	g.resources=[260.0,140.0,40.0,80.0]
	for i in range(3):
		var w=g.worlds[i]
		w.s.status="OWNED";w.s.level=4 if i==0 else 2
		w.core().hp=w.cfg.hps[-1];w.core().max_hp=w.cfg.hps[-1]
		w.s.dock=true;w.s.buildings[1].hp=70
	var w=g.current()
	var builder=g.add_resident("BUILD",0);builder.pos=Vector2(390,525)
	place("house",Vector2i(5,13));place("house",Vector2i(21,13));place("warehouse",Vector2i(13,6))
	var spots=[Vector2i(9,9),Vector2i(17,9),Vector2i(9,17),Vector2i(17,17)]
	var stations=["","signal","cannon","mortar"]
	for i in range(4):
		var tower=place("htower",spots[i])
		if tower==null:continue
		tower.level=3;tower.hp=110;tower.max_hp=110
		for j in range(3 if i==0 else 1):
			var r=g.add_resident("RANGED" if i==0 else "BUILD" if i==1 else "MELEE",0)
			r.station=stations[i]
			w.station(r.id,tower)
	var gatherer=g.add_resident("GATHER",0);gatherer.pos=Vector2(560,530);gatherer.job="food"
	g.message="像素美术预览 · 建筑与居民场景展示（非初始布局）"
	await capture("11-art-day")
	g.remaining=8
	await capture("12-art-sunset")
	g.phase="NIGHT";g.remaining=65
	w.s.wave=[];w.s.cursor=0
	for i in range(4):w.spawn(i,0,Vector2(220+i*60,410+i*35))
	await capture("13-art-night")
	prepare_harbor()
	g.message="水面美术预览 · 波纹、岸浪、倒影与灯光（非初始布局）"
	g.phase="DAY";g.remaining=55
	await capture("14-water-day")
	g.remaining=8
	await capture("15-water-sunset")
	g.phase="NIGHT";g.remaining=65
	await capture("16-water-night")
	game.queue_free()
	await process_frame
	quit()

func prepare_harbor():
	var w=game.g.current()
	w.s.enemies=[]
	place("house",Vector2i(6,24));place("house",Vector2i(20,24))
	var trees=w.s.nodes.filter(func(node):return node.kind==0)
	if trees.size()>=2:
		trees[0].cell=Vector2i(3,25)
		trees[1].cell=Vector2i(24,25)
	game.g.player.pos=Vector2(464,860)

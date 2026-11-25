extends SceneTree
var game
var failures=[]
var checks=0
func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func check(value,name):
	checks+=1
	if not value:failures.append(name);push_error(name)
func render():
	game.queue_redraw()
	for k in range(3):await process_frame
func drop(resident,column):
	var target=game.drops.filter(func(d):return d.has("column") and d.column==column and d.island==0)[0]
	game.dragging=resident;game.cursor=target.rect.get_center();game.finish_drag()
func run():
	root.size=Vector2i(1152,648)
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false)
	var g=game.g;var w=g.current()
	for i in range(5):g.add_resident("UNEMPLOYED",0)
	var arriving=g.add_resident("UNEMPLOYED")
	check(w.assigned_count()==0 and w.s.residents.size()==5,"five waiting residents occupy no jobs")
	g.phase="RESULT";g.next_day();game.menu="dispatch";await render()
	check(g.day==2 and g.phase=="DAY","actual day continuation preserves dispatch eligibility")
	drop(arriving,0)
	check(arriving.profession=="BUILD" and arriving.island==0,"new pool arrival can take free job despite existing local unemployed")
	check(w.assigned_count()==1,"job counter changes only for assigned resident")
	await render()
	var local=w.s.residents.filter(func(r):return r.profession=="UNEMPLOYED")[0]
	drop(local,1)
	check(local.profession=="GATHER" and w.assigned_count()==2,"local waiting resident can take final free job")
	await render()
	var extra=w.s.residents.filter(func(r):return r.profession=="UNEMPLOYED")[0]
	var alternate=g.story.combat_next
	drop(extra,2)
	check(extra.profession=="UNEMPLOYED" and w.assigned_count()==2,"full capacity rejects further assignment without overfill")
	check(g.story.combat_next==alternate,"failed combat drop does not alter alternating profession order")
	g.resources=[100.0,100.0,0.0,20.0]
	w.add_building("house",Vector2i(4,22),true)
	drop(extra,2)
	check(extra.profession=="MELEE" and w.assigned_count()==3,"housing reopens job and allows same resident to be assigned")
	check(g.story.combat_next==alternate+1,"successful combat drop advances profession alternation once")
	var file=FileAccess.open("res://dispatch-dawn-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print(JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)

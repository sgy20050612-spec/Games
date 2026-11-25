extends Node2D
const ENV = preload("res://assets/art/environment-16bit-v4.png")
const COAST = preload("res://scripts/coast.gd")
var game

func coast(along,side,land_size):
	return COAST.depth(along,side,land_size)

func reflected_sprite(index, ground, size_value, land_size):
	var distances=[ground.x+coast(ground.y,0,land_size),land_size+coast(ground.y,1,land_size)-ground.x,ground.y+coast(ground.x,2,land_size),land_size+coast(ground.x,3,land_size)-ground.y]
	var side=0
	for i in range(1,4):
		if distances[i]<distances[side]:side=i
	if distances[side]>185:return null
	var position=ground
	var scale_value=Vector2(1,-.55)
	if side==3:
		position.y=land_size+coast(ground.x,3,land_size)+7+distances[side]*.1
	elif side==2:
		position.y=-coast(ground.x,2,land_size)-7-distances[side]*.1
		scale_value=Vector2(1,.55)
	elif side==0:
		position.x=-coast(ground.y,0,land_size)-size_value.x*.23
		scale_value=Vector2(-.55,.62)
	else:
		position.x=land_size+coast(ground.y,1,land_size)+size_value.x*.23
		scale_value=Vector2(-.55,.62)
	var alpha=clamp((185-distances[side])/145.0,.05,.65)
	var cell=Vector2(ENV.get_width()/4.0,ENV.get_height()/5.0)
	var region=Rect2(Vector2(index%4,floor(index/4.0))*cell+Vector2.ONE,cell-Vector2(2,2))
	draw_set_transform(position+game.offset,0,scale_value)
	draw_texture_rect_region(ENV,Rect2(Vector2(-size_value.x/2,-size_value.y+5),size_value),region,Color(.72,.82,.92,alpha))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	return {"position":position,"side":side,"alpha":alpha}

func _draw():
	if game==null or game.g==null or game.art==null:return
	var w=game.g.current()
	var n=w.cfg.size*32
	for node in w.s.nodes:
		if node.amount<=0 or node.kind!=0:continue
		reflected_sprite(0 if node.cell.x%3!=0 else 1,Vector2(node.cell)*32+Vector2(16,30),Vector2(96,116),n)
	for b in w.s.buildings:
		var index={"core":5,"house":6,"warehouse":7,"dock":8,"htower":9,"generator":14,"tesla":15}.get(b.kind,-1)
		if index<0:continue
		if b.kind=="htower":index={"none":9,"archer":10,"elite":10,"signal":11,"cannon":12,"mortar":13}[w.tower_form(b)]
		var d=game.g.rules.buildings[b.kind]
		var ground=Vector2(b.cell)*32+Vector2(d.w*16,d.h*32)
		var size_value=Vector2(132,140) if b.kind=="core" else Vector2(108,110) if b.kind=="htower" else Vector2(116,83) if b.kind=="dock" else Vector2(96,96)
		var reflection=reflected_sprite(index,ground,size_value,n)
		if reflection!=null and b.kind in ["core","house","dock","generator"]:
			var point=reflection.position+game.offset
			var night=game.art.night_amount()
			for j in range(6):
				var width=8+sin(j*1.7+game.clock)*3
				var p=point+Vector2(0,j*4)
				draw_line(p-Vector2(width/2,0),p+Vector2(width/2,0),Color(1,.70,.34,reflection.alpha*night*(.7-j*.08)),2)
	if w.s.dock:
		var dock=w.s.buildings[1]
		var ground=Vector2(dock.cell)*32+Vector2(48,64)
		var point=Vector2(ground.x,n+coast(ground.x,3,n)+23)+game.offset
		game.art.boat(point+Vector2(0,15),self,.35,true)

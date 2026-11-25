extends Node2D
const REFLECTION = preload("res://scripts/water_reflections.gd")
var game
var reflections
var reflection_viewport
var water_material

func _ready():
	show_behind_parent=true
	reflection_viewport=SubViewport.new()
	reflection_viewport.size=Vector2i(1152,648)
	reflection_viewport.transparent_bg=true
	reflection_viewport.disable_3d=true
	reflection_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(reflection_viewport)
	reflections=REFLECTION.new()
	reflections.game=game
	reflection_viewport.add_child(reflections)
	water_material=ShaderMaterial.new()
	water_material.shader=preload("res://scripts/water.gdshader")
	water_material.set_shader_parameter("reflection_map",reflection_viewport.get_texture())
	material=water_material
	queue_redraw()

func update_water(n, offset, night, dusk):
	if water_material==null:return
	water_material.set_shader_parameter("island_size",float(n*32))
	water_material.set_shader_parameter("world_offset",offset)
	water_material.set_shader_parameter("night",float(night))
	water_material.set_shader_parameter("sunset",float(dusk))
	reflections.queue_redraw()

func _draw():
	draw_rect(Rect2(0,0,1152,648),Color.WHITE)

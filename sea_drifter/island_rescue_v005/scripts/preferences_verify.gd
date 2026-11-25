extends SceneTree
var game
var checks=0
var failures=[]
func _initialize():
	OS.set_environment("ISLAND_TEST_MODE","1");call_deferred("run")
func check(value,name):
	checks+=1
	if not value:failures.append(name);push_error(name)
func render():
	game.queue_redraw()
	for k in range(3):await process_frame
	await RenderingServer.frame_post_draw
func run():
	root.size=Vector2i(1152,648)
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false)
	var prefs=game.preferences
	game.play_music()
	game.title_screen.time=2;game.menu="title_settings";await render()
	check(not prefs.values.has("language"),"language selection removed")
	check(not game.ui_buttons.any(func(b):return b.get("tag","").begins_with("language")),"no language arrows remain")
	root.get_texture().get_image().save_png("res://previews/26-pixel-settings.png")
	prefs.set_option("effects",5)
	check(is_equal_approx(game.audio.volume_db,linear_to_db(.5)),"effects volume changes audio gain")
	check(is_equal_approx(game.music.volume_db,-22),"effects adjustment does not change music gain")
	prefs.set_option("music",0)
	check(game.music.stream_paused and not game.muted,"music can mute independently")
	prefs.set_option("effects",0)
	check(game.muted,"both zero mutes all sound")
	prefs.set_option("music",20)
	check(prefs.values.music==10,"volume clamps to10")
	prefs.set_option("tutorial",false);prefs.set_option("numbers",false)
	check(not prefs.values.tutorial and not game.show_numbers,"tutorial and damage-number toggles apply")
	prefs.set_option("zoom",1.5)
	var path="user://settings_validation.cfg"
	check(prefs.save_to(path),"preferences write to separate test file")
	prefs.reset();prefs.load_from(path);prefs.apply_audio()
	check(prefs.values.zoom==1.5 and prefs.values.effects==0 and not prefs.values.tutorial,"preferences roundtrip preserves values")
	game.menu="";game.g.start()
	for z in prefs.ZOOMS:
		prefs.set_option("zoom",z);await render()
		var expected=game.g.player.pos+Vector2(64,32)
		check(game.screen_to_world(Vector2(576,355)+Vector2(64,32)*z).distance_to(expected)<.001,"world click projection matches zoom %.2f"%z)
		check(game.water_layer.scale==Vector2(z,z),"water shares world zoom %.2f"%z)
	root.get_texture().get_image().save_png("res://previews/27-pixel-world-zoom.png")
	prefs.reset();check(prefs.values==prefs.DEFAULTS,"restore defaults resets options without touching game state")
	await render()
	root.get_texture().get_image().save_png("res://previews/30-16bit-game.png")
	game.menu="settings";await render()
	check(game.ui_buttons.any(func(b):return b.get("tag","")=="zoom_up"),"in-game settings use same controls")
	prefs.view="controls";await render();check(game.ui_buttons.size()==1,"controls page provides a return action")
	prefs.view="credits";await render();check(game.ui_buttons.size()==1,"credits page provides a return action")
	prefs.view="privacy";await render();check(game.ui_buttons.size()==1,"local data explanation provides a return action")
	var f=FileAccess.open("res://preferences-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print(JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame;await process_frame;await create_timer(.15).timeout;quit(0 if failures.is_empty() else 1)

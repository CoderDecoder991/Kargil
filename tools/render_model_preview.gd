extends SceneTree

# Usage: Godot --path PROJECT --script res://tools/render_model_preview.gd -- MODEL OUTPUT [ANIMATION]
func _initialize() -> void:
	call_deferred("_render_preview")

func _render_preview() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected model scene and output PNG")
		quit(2)
		return
	var packed := load(args[0]) as PackedScene
	if packed == null:
		printerr("Could not load model: ", args[0])
		quit(3)
		return
	root.size = Vector2i(768, 768)
	var model := packed.instantiate() as Node3D
	root.add_child(model)
	if args.size() > 3 and args[3] == "hide_glass":
		var invisible := StandardMaterial3D.new()
		invisible.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		invisible.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh.get_surface_count() > 9:
				mesh.set_surface_override_material(9, invisible)
	if args.size() > 3 and args[3] == "hide_headset":
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.name == "Object_111":
				mesh.visible = false
	if args.size() > 3 and args[3] == "field_uniform":
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.name in ["Object_111", "Object_101", "Object_105", "Object_117"]:
				mesh.visible = false
	var animations := model.find_children("*", "AnimationPlayer", true, false)
	if not animations.is_empty():
		var player := animations[0] as AnimationPlayer
		var clip := args[2] if args.size() > 2 else "idle"
		if player.has_animation(clip):
			player.play(clip)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.37, 0.40, 0.43)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.90, 0.96)
	environment.ambient_light_energy = 0.72
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.light_energy = 2.0
	root.add_child(light)
	light.position = Vector3(2.0, 5.0, 3.0)
	light.look_at(Vector3(0.0, 1.0, 0.0))
	var camera := Camera3D.new()
	camera.fov = 38.0
	root.add_child(camera)
	camera.position = Vector3(2.25, 2.35, 3.05) if args.size() > 3 else Vector3(3.0, 2.8, 4.0)
	if args.size() > 3 and args[3] == "rifle":
		camera.position = Vector3(1.5, 0.9, 1.7)
		camera.look_at(Vector3.ZERO)
	else:
		camera.look_at(Vector3(0.0, 1.0, 0.0))
	camera.current = true
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(args[1])
	print("preview_saved=", args[1], " error=", result)
	quit(0 if result == OK else 4)

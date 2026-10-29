extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var model := (load(args[0]) as PackedScene).instantiate()
	root.add_child(model)
	_print_node(model, "")
	quit()

func _print_node(node: Node, prefix: String) -> void:
	var extra := " transform=" + str((node as Node3D).transform) if node is Node3D else ""
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		var material := mesh.surface_get_material(0) as StandardMaterial3D
		extra = " surfaces=%d aabb=%s material=%s color=%s roughness=%s metallic=%s skin=%s skeleton=%s transform=%s" % [mesh.get_surface_count(),mesh.get_aabb(),material.resource_name,material.albedo_color,material.roughness,material.metallic,(node as MeshInstance3D).skin,(node as MeshInstance3D).skeleton,(node as MeshInstance3D).transform]
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		extra = " bones=%d" % skeleton.get_bone_count()
		for i in skeleton.get_bone_count():
			print("BONE ", i, " ", skeleton.get_bone_name(i), " pose=", skeleton.get_bone_pose_rotation(i))
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		for animation_name in player.get_animation_list():
			var animation: Animation = player.get_animation(animation_name)
			print("ANIMATION ", animation_name, " tracks=", animation.get_track_count(), " length=", animation.length)
			if String(animation_name).to_lower().contains("grip"):
				for track in animation.get_track_count():
					print("  TRACK ", animation.track_get_path(track), " type=", animation.track_get_type(track), " keys=", animation.track_get_key_count(track), " first=", animation.track_get_key_value(track,0) if animation.track_get_key_count(track)>0 else null)
	print(prefix, node.name, " ", node.get_class(), extra)
	for child in node.get_children():
		_print_node(child, prefix + "  ")

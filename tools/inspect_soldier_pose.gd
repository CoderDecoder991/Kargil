extends SceneTree

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var model := (load("res://assets/models/soldier_tac_danlyvostok_ccby.glb") as PackedScene).instantiate() as Node3D
	model.rotation.y = PI
	root.add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for bone in [9,10,11,34,35,36]:
		var pose := skeleton.get_bone_global_pose(bone)
		print("POSE ", bone, " ", skeleton.get_bone_name(bone), " position=", skeleton.global_transform * pose.origin, " rotation=", skeleton.get_bone_pose_rotation(bone))
	quit()

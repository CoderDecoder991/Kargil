extends SceneTree

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var actor := preload("res://scripts/actor.gd").new() as PatrolActor
	actor.display_name = "Grip review"
	root.add_child(actor)
	var skeleton := actor.soldier_skeleton
	var rifle := actor.rifle_node
	for is_high in [false, true]:
		actor.set_contact_ready(is_high)
		actor._update_ready_pose(1.0)
		var right_index := skeleton.find_bone("mixamorig_RightHand")
		var left_index := skeleton.find_bone("mixamorig_LeftHand")
		var right_hand := skeleton.global_transform * skeleton.get_bone_global_pose(right_index).origin
		var left_hand := skeleton.global_transform * skeleton.get_bone_global_pose(left_index).origin
		var right_grip := rifle.to_global(actor.RIGHT_GRIP_LOCAL)
		var left_grip := rifle.to_global(actor.LEFT_GRIP_LOCAL)
		var butt_in_body := actor.body_root.to_local(rifle.to_global(Vector3(0, -0.008, 0.423)))
		print("GRIP_CHECK pose=", "high" if is_high else "low", " right_error=", right_hand.distance_to(right_grip), " left_error=", left_hand.distance_to(left_grip), " butt_body_z=", butt_in_body.z, " barrel_direction=", rifle.global_basis * Vector3(0, 0, -1))
		for side in ["Right", "Left"]:
			var upper_index := skeleton.find_bone("mixamorig_" + side + "Arm")
			var elbow_index := skeleton.find_bone("mixamorig_" + side + "ForeArm")
			var hand_index := skeleton.find_bone("mixamorig_" + side + "Hand")
			print("ARM ", side, " shoulder=", actor.body_root.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(upper_index).origin), " elbow=", actor.body_root.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(elbow_index).origin), " hand=", actor.body_root.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(hand_index).origin))
	quit()

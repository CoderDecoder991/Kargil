extends SceneTree

# A05l gate: validate a candidate humanoid scene before it replaces the
# interim patrol model. This reports facts about the asset; it does not claim
# that a generic candidate is historically accurate.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("CHARACTER_BASE_USAGE path/to/candidate.glb")
		quit(2)
		return
	var path := args[0]
	var packed := load(path) as PackedScene
	if packed == null:
		print("CHARACTER_BASE_FAIL path=%s reason=not_a_packed_scene" % path)
		quit(2)
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		print("CHARACTER_BASE_FAIL path=%s reason=not_node3d" % path)
		quit(2)
		return
	root.add_child(instance)
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var skeletons := instance.find_children("*", "Skeleton3D", true, false)
	var bones := 0
	if not skeletons.is_empty():
		bones = (skeletons[0] as Skeleton3D).get_bone_count()
	var aabb := AABB()
	var first := true
	for node in meshes:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		# The imported GLB may not be inside a rendered frame during headless
		# validation, so use each mesh's local authored bounds rather than asking
		# Node3D for a global transform.
		var world_box := mesh_node.get_aabb()
		if first:
			aabb = world_box
			first = false
		else:
			aabb = aabb.merge(world_box)
	var dimensions := aabb.size
	var humanoid_scale := dimensions.y > 1.2 and dimensions.y < 2.6 and dimensions.x > 0.25 and dimensions.z > 0.15
	var skeleton_ok := not skeletons.is_empty() and bones >= 20
	var geometry_ok := meshes.size() >= 1 and humanoid_scale
	var criteria_pass := skeleton_ok and geometry_ok
	print("CHARACTER_BASE_%s path=%s meshes=%d skeletons=%d bones=%d dimensions=%s humanoid_scale=%s" % ["PASS" if criteria_pass else "REVIEW", path, meshes.size(), skeletons.size(), bones, dimensions, humanoid_scale])
	quit(0 if criteria_pass else 1)

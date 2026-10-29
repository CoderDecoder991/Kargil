extends SceneTree

# One-time authoring step: merge the AK-pattern reconstruction's static mesh
# pieces into material batches for the six-character isometric scene.
func _initialize() -> void:
	call_deferred("_optimize")

func _optimize() -> void:
	var source := preload("res://scripts/ak_pattern_rifle.gd").new() as Node3D
	root.add_child(source)
	source.call("build")
	var groups: Dictionary = {}
	var materials: Dictionary = {}
	var stock_groups: Dictionary = {}
	var source_to_local := source.global_transform.affine_inverse()
	for child in source.find_children("*", "MeshInstance3D", true, false):
		var part := child as MeshInstance3D
		for surface in part.mesh.get_surface_count():
			var material := part.material_override if part.material_override != null else part.mesh.surface_get_material(surface)
			var hidden_stock := part.get_parent().name == "FPS-hidden AK buttstock"
			var key := str(material.get_instance_id()) + ("_stock" if hidden_stock else "_body")
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = tool
				materials[key] = material
				stock_groups[key] = hidden_stock
			(groups[key] as SurfaceTool).append_from(part.mesh, surface, source_to_local * part.global_transform)
	var output := Node3D.new()
	output.name = "AK-pattern rifle reconstruction"
	var body := Node3D.new()
	body.name = "AK rifle body"
	var buttstock := Node3D.new()
	buttstock.name = "AK buttstock (hide in first person)"
	output.add_child(body)
	body.owner = output
	output.add_child(buttstock)
	buttstock.owner = output
	for key in groups.keys():
		var mesh := ArrayMesh.new()
		var tool := groups[key] as SurfaceTool
		tool.set_material(materials[key])
		tool.commit(mesh)
		var part := MeshInstance3D.new()
		part.name = "Material batch"
		part.mesh = mesh
		var parent: Node3D = buttstock if stock_groups[key] else body
		parent.add_child(part)
		part.owner = output
	var packed := PackedScene.new()
	var err := packed.pack(output)
	if err == OK:
		err = ResourceSaver.save(packed, "res://assets/models/ak_pattern_rifle.tscn")
	print("AK_PATTERN_OPTIMIZE batches=", groups.size(), " result=", err)
	source.queue_free()
	quit(0 if err == OK else 2)

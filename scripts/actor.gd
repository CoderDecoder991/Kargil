extends Node3D
class_name PatrolActor

var display_name := ""
var hostile := false
var selected := false
var crouched := false
var prone := false
var stamina := 100.0
var cold := 0.0
var alert := 0.0
var health := 100.0
var defeated := false
var hit_area: Area3D
var direction := Vector3(0,0,-1)
var patrol_origin := Vector3.ZERO
var patrol_radius := 4.0
var patrol_clock := 0.0
var path: Array[Vector3] = []
var mountain: Mountain
var moving := false
var manual_speed_scale := 1.0
var manual_move_direction := Vector3.ZERO
var rope_traversing := false
var ledge_traversing := false
var step_distance := 0.0
var wind_strength := 0.0
var selection_ring: Node3D
var body_root: Node3D
var generated_character_sprite: Sprite3D
var generated_character_textures: Dictionary = {}
var generated_character_walk_width_scales: Dictionary = {}
var generated_character_texture_key := ""
var soldier_skeleton: Skeleton3D
var soldier_base_pose: Array[Quaternion] = []
var badge: Label3D
var step_player: AudioStreamPlayer
var snow_step: AudioStream
var rock_step: AudioStream
var left_leg_rig: Node3D
var right_leg_rig: Node3D
var left_arm_rig: Node3D
var right_arm_rig: Node3D
var gait_clock := 0.0
var gait_cycle_distance := 1.5
var a05l_candidate := false
var rifle_node: Node3D
var high_ready := false
var motion_state := "idle_low_ready"
var left_foot_target_error := 999.0
var right_foot_target_error := 999.0
var kneeling_knee_target_error := 999.0
var kneeling_left_foot_error := 999.0
var kneeling_right_ankle_error := 999.0
var kneeling_upper_leg_length := 0.0
var kneeling_hip_to_knee_target := 0.0
var kneeling_pose_cached := false
var kneeling_cached_position := Vector3.ZERO
var kneeling_cached_direction := Vector3.ZERO
var kneeling_cached_root_y := INF
var last_leg_target_distance := 0.0
var last_leg_chain_reach := 0.0
var worst_foot_target_error := 0.0
var worst_foot_target_distance := 0.0
var worst_foot_chain_reach := 0.0
var ready_override := -1
var ready_grip_anchor := Vector3.ZERO
var support_grip_local := Vector3(0.0,-0.02,-0.30)
var ready_blend := 0.0
var low_arm_pose: Dictionary = {}
var high_arm_pose: Dictionary = {}
var prone_arm_pose: Dictionary = {}
var prone_arm_pose_cached := false
var prone_right_grip_error := INF
var prone_left_grip_error := INF
var prone_target_pitch := -PI * 0.5
var a05n_kit_attachment_count := 0
var visual_variant := 0
var visual_height_scale := 1.0
var a05o_variant_signature := ""
var action_animation := ""
var action_animation_clock := 0.0
var action_restore_high_ready := false
var a05n_close_detail_nodes: Array[Node3D] = []
var a05n_mid_detail_nodes: Array[Node3D] = []
var visual_shadow_instances: Array[GeometryInstance3D] = []
var visual_lod_tier := -1
var pose_update_interval := 0.0
var pose_update_clock := 0.0
const A05L_DEFAULT_BASE := true
const RIGHT_GRIP_LOCAL := Vector3(0.035,-0.125,0.065)
const LEFT_GRIP_LOCAL := Vector3(0.0,-0.02,-0.30)
const LOW_RIFLE_POSITION := Vector3(0.0, 1.60, -0.28)
const HIGH_RIFLE_POSITION := Vector3(0.0, 1.72, -0.36)
const HIGH_READY_ROTATION := Vector3(0.0, 0.0, 0.0)
const LOW_READY_ROTATION := Vector3(-PI / 4.0, 0.0, 0.0)

func configure(actor_name: String, is_hostile: bool, terrain: Mountain) -> void:
	display_name = actor_name
	hostile = is_hostile
	mountain = terrain

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--rifle-high" in args: ready_override = 1
	elif "--rifle-low" in args: ready_override = 0
	if ready_override >= 0: high_ready = ready_override == 1
	_build_figure()
	if hostile: _build_hit_area()
	patrol_origin = position
	step_player = AudioStreamPlayer.new()
	step_player.volume_db = -28 if hostile else -23
	add_child(step_player)
	snow_step = load("res://assets/audio/snow_step.wav")
	rock_step = load("res://assets/audio/rock_step.wav")

func _build_hit_area() -> void:
	hit_area = Area3D.new()
	hit_area.name = "Hostile target hit volume"
	hit_area.collision_layer = 2
	hit_area.collision_mask = 0
	add_child(hit_area)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.78
	collision.shape = capsule
	collision.position.y = 0.91
	hit_area.add_child(collision)
	hit_area.set_meta("patrol_actor",self)

func apply_shot_damage(amount: float) -> bool:
	if not hostile or defeated or amount <= 0.0: return false
	health = maxf(0.0,health-amount)
	alert = 1.0
	if health <= 0.0:
		defeated = true
		set_process(false)
		if body_root != null: body_root.visible = false
		if hit_area != null: hit_area.monitorable = false
		if badge != null: badge.visible = false
	return true

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	return mat

func _part(mesh: Mesh, mat: Material, p: Vector3, size: Vector3, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = p
	node.scale = size
	parent.add_child(node)
	return node

func _capsule(parent: Node3D, mat: Material, a: Vector3, b: Vector3, radius: float, sides := 10) -> MeshInstance3D:
	var span := a.distance_to(b)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = span + radius * 2.0
	mesh.radial_segments = sides
	mesh.rings = 4
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = (a + b) * 0.5
	node.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	parent.add_child(node)
	return node

func _loft_y(parent: Node3D, mat: Material, profile: Array[Vector3], sides := 24) -> MeshInstance3D:
	# Smooth elliptical cross-sections make one continuous tailored garment surface.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size()):
		var shape := profile[ring]
		for side in range(sides):
			var angle := TAU * float(side) / float(sides)
			surface.set_uv(Vector2(float(side) / float(sides), float(ring) / float(profile.size() - 1) * 2.0))
			surface.add_vertex(Vector3(cos(angle) * shape.y, shape.x, sin(angle) * shape.z))
	for ring in range(profile.size() - 1):
		for side in range(sides):
			var next := (side + 1) % sides
			var lower := ring * sides + side
			var lower_next := ring * sides + next
			var upper := (ring + 1) * sides + side
			var upper_next := (ring + 1) * sides + next
			surface.add_index(lower)
			surface.add_index(upper)
			surface.add_index(upper_next)
			surface.add_index(lower)
			surface.add_index(upper_next)
			surface.add_index(lower_next)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = mat
	parent.add_child(node)
	return node

func _loft_path(parent: Node3D, mat: Material, centers: Array[Vector3], radii: Array[Vector2], sides := 16) -> MeshInstance3D:
	# A curved, tapered tube follows a limb through shoulder/elbow or hip/knee/ankle.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(centers.size()):
		var tangent := (centers[mini(ring + 1, centers.size() - 1)] - centers[maxi(ring - 1, 0)]).normalized()
		var right := tangent.cross(Vector3.FORWARD)
		if right.length_squared() < 0.001:
			right = tangent.cross(Vector3.RIGHT)
		right = right.normalized()
		var front := right.cross(tangent).normalized()
		for side in range(sides):
			var angle := TAU * float(side) / float(sides)
			var point := centers[ring] + right * cos(angle) * radii[ring].x + front * sin(angle) * radii[ring].y
			surface.set_uv(Vector2(float(side) / float(sides), float(ring) / float(centers.size() - 1) * 1.7))
			surface.add_vertex(point)
	for ring in range(centers.size() - 1):
		for side in range(sides):
			var next := (side + 1) % sides
			var lower := ring * sides + side
			var lower_next := ring * sides + next
			var upper := (ring + 1) * sides + side
			var upper_next := (ring + 1) * sides + next
			surface.add_index(lower)
			surface.add_index(upper)
			surface.add_index(upper_next)
			surface.add_index(lower)
			surface.add_index(upper_next)
			surface.add_index(lower_next)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = mat
	parent.add_child(node)
	return node

func _build_figure() -> void:
	if not hostile:
		if OS.get_cmdline_user_args().has("--a05p-turnaround"):
			_build_turnaround_soldier()
		else:
			_build_rigged_soldier()
		_build_marker()
		return
	var base_color := Color(0.34,0.33,0.27) if hostile else Color.WHITE
	var cloth := _material(base_color)
	cloth.roughness = 0.96
	if not hostile:
		cloth.albedo_texture = load("res://assets/textures/field_uniform_weave_v2.png") as Texture2D
		cloth.uv1_scale = Vector3(0.75, 0.75, 1.0)
	var cloth_shadow := _material(Color(0.24,0.27,0.21) if not hostile else Color(0.25,0.23,0.20))
	var webbing := _material(Color(0.20,0.23,0.19) if not hostile else Color(0.22,0.20,0.17))
	var leather := _material(Color(0.20,0.17,0.13))
	var boots := _material(Color(0.12,0.13,0.12))
	var rubber := _material(Color(0.075,0.08,0.075))
	var skin := _material(Color(0.39,0.27,0.21))
	var scarf := _material(Color(0.31,0.33,0.28))
	var metal := _material(Color(0.11,0.13,0.12))
	body_root = Node3D.new()
	add_child(body_root)
	var box := BoxMesh.new()
	var ball := SphereMesh.new()
	ball.radial_segments = 24
	ball.rings = 12
	# One smooth torso shell and tapered curved limbs replace the disconnected blockout forms.
	_loft_y(body_root, cloth, [
		Vector3(0.91,0.22,0.145), Vector3(0.98,0.27,0.165), Vector3(1.06,0.285,0.17),
		Vector3(1.16,0.30,0.17), Vector3(1.29,0.32,0.165), Vector3(1.41,0.35,0.16),
		Vector3(1.50,0.37,0.145), Vector3(1.56,0.34,0.13), Vector3(1.61,0.22,0.105),
		Vector3(1.66,0.13,0.09)
	])
	var belt := _part(box, cloth_shadow, Vector3(0,0.96,0.0), Vector3(0.56,0.12,0.35), body_root)
	# Separate hip pivots let trouser legs swing as a joined cloth tube when walking.
	left_leg_rig = Node3D.new()
	left_leg_rig.position = Vector3(-0.16,0.91,0)
	body_root.add_child(left_leg_rig)
	_loft_path(left_leg_rig, cloth, [Vector3(0,-0.70,0),Vector3(0,-0.56,0),Vector3(0,-0.39,0.005),Vector3(0,-0.20,0),Vector3(0,-0.02,0)], [Vector2(0.072,0.075),Vector2(0.083,0.09),Vector2(0.095,0.105),Vector2(0.113,0.125),Vector2(0.12,0.13)])
	right_leg_rig = Node3D.new()
	right_leg_rig.position = Vector3(0.16,0.91,0)
	body_root.add_child(right_leg_rig)
	_loft_path(right_leg_rig, cloth, [Vector3(0,-0.70,0),Vector3(0,-0.56,0),Vector3(0,-0.39,0.005),Vector3(0,-0.20,0),Vector3(0,-0.02,0)], [Vector2(0.072,0.075),Vector2(0.083,0.09),Vector2(0.095,0.105),Vector2(0.113,0.125),Vector2(0.12,0.13)])
	for side in [-1.0, 1.0]:
		var leg := left_leg_rig if side < 0.0 else right_leg_rig
		_part(box, cloth_shadow, Vector3(0,-0.67,0.015), Vector3(0.15,0.20,0.19), leg) # gaiter cuff
		_part(box, boots, Vector3(0,-0.79,-0.055), Vector3(0.19,0.19,0.30), leg)
		_part(box, rubber, Vector3(0,-0.885,-0.075), Vector3(0.20,0.045,0.31), leg)
	# Bent sleeves and gloves form a deliberate low-ready pose around the carried rifle.
	left_arm_rig = Node3D.new()
	left_arm_rig.position = Vector3(-0.31,1.51,0.0)
	body_root.add_child(left_arm_rig)
	_loft_path(left_arm_rig, cloth, [Vector3(0.08,-0.05,-0.30),Vector3(0.15,-0.10,-0.25),Vector3(0.15,-0.18,-0.17),Vector3(0.08,-0.10,-0.055),Vector3(0,0,0)], [Vector2(0.060,0.058),Vector2(0.068,0.066),Vector2(0.078,0.078),Vector2(0.092,0.090),Vector2(0.105,0.10)])
	_part(ball, webbing, Vector3(0.08,-0.05,-0.30), Vector3(0.105,0.075,0.085), left_arm_rig) # insulated glove
	right_arm_rig = Node3D.new()
	right_arm_rig.position = Vector3(0.31,1.51,0.0)
	body_root.add_child(right_arm_rig)
	_loft_path(right_arm_rig, cloth, [Vector3(-0.06,-0.31,-0.29),Vector3(-0.12,-0.27,-0.24),Vector3(-0.15,-0.18,-0.16),Vector3(-0.08,-0.10,-0.055),Vector3(0,0,0)], [Vector2(0.060,0.058),Vector2(0.068,0.066),Vector2(0.078,0.078),Vector2(0.092,0.090),Vector2(0.105,0.10)])
	_part(ball, webbing, Vector3(-0.06,-0.31,-0.29), Vector3(0.10,0.075,0.08), right_arm_rig) # insulated glove
	# Pack, straps, webbing and pouches are fitted over the continuous jacket shell.
	_part(box, cloth_shadow, Vector3(0,1.36,0.20), Vector3(0.42,0.60,0.27), body_root)
	_part(ball, cloth_shadow, Vector3(0,1.67,0.19), Vector3(0.22,0.13,0.16), body_root)
	_capsule(body_root, webbing, Vector3(-0.23,1.58,-0.12), Vector3(0.18,1.00,-0.18), 0.026, 10)
	_capsule(body_root, webbing, Vector3(0.23,1.58,-0.12), Vector3(-0.18,1.00,-0.18), 0.026, 10)
	_part(box, webbing, Vector3(-0.25,1.03,-0.19), Vector3(0.14,0.18,0.12), body_root)
	_part(box, webbing, Vector3(0.25,1.03,-0.19), Vector3(0.14,0.18,0.12), body_root)
	_part(box, leather, Vector3(0,0.96,-0.19), Vector3(0.09,0.06,0.035), body_root)
	# Head, scarf and helmet use natural oval proportions; face remains generic and unidentifiable.
	_part(ball, skin, Vector3(0,1.78,-0.015), Vector3(0.15,0.205,0.145), body_root)
	_part(ball, scarf, Vector3(0,1.69,-0.035), Vector3(0.16,0.09,0.15), body_root)
	_part(ball, cloth_shadow, Vector3(0,1.96,0.005), Vector3(0.245,0.13,0.225), body_root)
	_part(ball, cloth, Vector3(0,1.99,0.03), Vector3(0.235,0.115,0.22), body_root)
	_part(ball, cloth_shadow, Vector3(0,1.92,-0.10), Vector3(0.265,0.045,0.245), body_root)
	# Plain generic long arm profile, deliberately without a claimed model designation.
	_capsule(body_root, metal, Vector3(-0.22,1.47,-0.25), Vector3(0.25,1.20,-0.29), 0.034, 12)
	_capsule(body_root, metal, Vector3(0.25,1.20,-0.29), Vector3(0.39,1.12,-0.28), 0.014, 10)
	_part(box, leather, Vector3(-0.20,1.47,-0.24), Vector3(0.10,0.16,0.08), body_root)
	_capsule(body_root, leather, Vector3(-0.18,1.56,-0.23), Vector3(0.27,1.05,-0.20), 0.010, 8)
	_build_marker()

func _build_rigged_soldier() -> void:
	body_root = Node3D.new()
	add_child(body_root)
	visual_variant = posmod(visual_variant,6)
	visual_height_scale = [0.975,1.010,1.025,0.990,1.015,0.985][visual_variant]
	a05o_variant_signature = "variant_%d" % visual_variant
	body_root.scale.y = visual_height_scale
	a05l_candidate = A05L_DEFAULT_BASE or OS.get_cmdline_user_args().has("--a05l-candidate")
	var scene := preload("res://assets/models/patrol_soldier_generated.glb") if a05l_candidate else preload("res://assets/models/soldier_tac_danlyvostok_ccby.glb")
	var model := scene.instantiate() as Node3D
	model.rotation.y = PI # Source character faces +Z; patrol movement faces -Z.
	body_root.add_child(model)
	if a05l_candidate:
		_apply_reconstructed_uniform_palette(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if not a05l_candidate and mesh.name in ["Object_111", "Object_101", "Object_105", "Object_117"]:
			mesh.visible = false # Misplaced headset and conspicuously modern armor pieces.
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		soldier_skeleton = skeletons[0] as Skeleton3D
	# The Blender export carries its own olive weave, skin, webbing and boot
	# materials. Replacing them here would erase the authored kit treatment.
	var rifle_scene := preload("res://assets/models/ak_pattern_rifle.tscn")
	var rifle := rifle_scene.instantiate() as Node3D
	rifle.name = "AK-pattern rifle - reconstructed visual choice"
	rifle_node = rifle
	rifle.position = Vector3(-0.17, 1.36, -0.17) if not a05l_candidate else Vector3.ZERO
	rifle.rotation = Vector3(-0.12, 0.03, 0.0) if not a05l_candidate else HIGH_READY_ROTATION
	rifle.scale = Vector3.ONE * (0.82 if a05l_candidate else 0.86)
	body_root.add_child(rifle)
	if soldier_skeleton != null:
		# Authored grip pose: right hand on the trigger grip, left under the
		# fore-end. These values were solved against this imported rig and prop.
		if a05l_candidate:
			var left_arm := soldier_skeleton.find_bone("mixamorig_LeftArm")
			var right_arm := soldier_skeleton.find_bone("mixamorig_RightArm")
			if left_arm >= 0:
				var left_base := soldier_skeleton.get_bone_pose_rotation(left_arm)
				soldier_skeleton.set_bone_pose_rotation(left_arm, left_base * Quaternion(Vector3.FORWARD, -1.45))
			if right_arm >= 0:
				var right_base := soldier_skeleton.get_bone_pose_rotation(right_arm)
				soldier_skeleton.set_bone_pose_rotation(right_arm, right_base * Quaternion(Vector3.FORWARD, 1.45))
			_pose_closed_rifle_hands()
		else:
			soldier_skeleton.set_bone_pose_rotation(9, Quaternion(0.556406, -0.054689, -0.404088, 0.723971))
			soldier_skeleton.set_bone_pose_rotation(10, Quaternion(-0.12626, 0.275023, 0.743742, -0.596044))
			soldier_skeleton.set_bone_pose_rotation(34, Quaternion(0.344176, -0.049014, 0.754012, 0.557321))
			soldier_skeleton.set_bone_pose_rotation(35, Quaternion(-0.000921, -0.029303, 0.036908, 0.998889))
		for bone in soldier_skeleton.get_bone_count():
			soldier_base_pose.append(soldier_skeleton.get_bone_pose_rotation(bone))
	if a05l_candidate:
		_cache_rifle_arm_poses()
		_build_a05n_bone_kit()
	for instance in body_root.find_children("*","GeometryInstance3D",true,false):
		visual_shadow_instances.append(instance as GeometryInstance3D)
	set_contact_ready(false)
	_update_ready_pose(1.0)

func _apply_reconstructed_uniform_palette(model: Node3D) -> void:
	# Lift the nearly black tactical palette into a readable olive field uniform
	# and matte cotton webbing while preserving the authored fabric textures.
	var texture_tints := {
		"Patrol olive winter cloth": Color(1.65,1.72,1.38),
		"Patrol olive jacket panels": Color(1.72,1.76,1.40),
		"Field webbing and pouches": Color(1.68,1.58,1.30),
		"Olive rib knit cap": Color(1.58,1.67,1.35),
		"Dark wool neck warmer": Color(1.54,1.62,1.34)
	}
	var solid_colors := {
		"Dulled hardware": Color(0.19,0.20,0.16),
		"Worn canvas straps": Color(0.34,0.32,0.22),
		"Blackened boot leather": Color(0.18,0.13,0.085)
	}
	var cloth_variation: Array[Color] = [
		Color(1.00,1.00,1.00),Color(1.035,1.00,0.97),Color(0.97,1.025,0.95),
		Color(1.015,0.98,0.94),Color(0.965,1.005,1.00),Color(1.025,1.015,0.955)
	]
	var skin_variation: Array[Color] = [
		Color(1.00,1.00,1.00),Color(1.025,0.99,0.975),Color(0.985,1.005,1.02),
		Color(0.99,0.98,0.97),Color(1.015,1.01,0.99),Color(0.975,0.99,1.015)
	]
	for node in model.find_children("*","MeshInstance3D",true,false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null: continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null: continue
			var material := source.duplicate() as StandardMaterial3D
			if texture_tints.has(source.resource_name):
				material.albedo_color = texture_tints[source.resource_name] * cloth_variation[visual_variant]
				material.roughness = 0.98
			elif solid_colors.has(source.resource_name):
				material.albedo_color = solid_colors[source.resource_name] * cloth_variation[visual_variant]
				material.roughness = 0.90
			elif source.resource_name.to_lower().contains("skin"):
				material.albedo_color = source.albedo_color * skin_variation[visual_variant]
				material.roughness = 0.86
			mesh_instance.set_surface_override_material(surface,material)

func _a05n_attach(bone_name: String, item_name: String) -> BoneAttachment3D:
	if soldier_skeleton == null or soldier_skeleton.find_bone(bone_name) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "A05n reconstructed " + item_name + " on " + bone_name
	attachment.bone_name = bone_name
	soldier_skeleton.add_child(attachment)
	if item_name.contains("sleeve patch"):
		a05n_close_detail_nodes.append(attachment)
	elif item_name.contains("padded glove shells"):
		a05n_mid_detail_nodes.append(attachment)
	a05n_kit_attachment_count += 1
	return attachment

func update_visual_lod(camera_position: Vector3) -> void:
	if body_root == null:
		return
	# Horizontal distance follows the isometric ground view; camera height alone
	# should not strip character detail while the player is zoomed in.
	var distance := Vector2(global_position.x-camera_position.x,global_position.z-camera_position.z).length()
	var tier := 0 if distance < 24.0 else (1 if distance < 48.0 else 2)
	if tier == visual_lod_tier:
		return
	visual_lod_tier = tier
	pose_update_interval = [0.0,1.0/30.0,1.0/15.0][tier]
	for detail in a05n_close_detail_nodes: detail.visible = tier == 0
	for detail in a05n_mid_detail_nodes: detail.visible = tier < 2
	var shadow_setting := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if tier == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for instance in visual_shadow_instances: instance.cast_shadow = shadow_setting

func _build_a05n_bone_kit() -> void:
	# The imported GLB is centimetre-authored under a 0.01 skeleton transform.
	# Keep all added equipment in those bone-local units so it follows animation.
	a05n_kit_attachment_count = 0
	var kit_wear: Array[Color] = [
		Color(1.00,1.00,1.00),Color(1.035,1.01,0.965),Color(0.96,1.02,0.95),
		Color(1.02,0.98,0.94),Color(0.975,0.99,1.02),Color(1.025,1.015,0.96)
	]
	var olive_cloth := _material(Color(0.25,0.30,0.20)*kit_wear[visual_variant])
	var olive_canvas := _material(Color(0.30,0.32,0.22)*kit_wear[visual_variant])
	var dark_canvas := _material(Color(0.15,0.18,0.12))
	var dark_metal := _material(Color(0.12,0.14,0.13))
	dark_metal.metallic = 0.28
	var helmet_scales: Array[Vector3] = [Vector3(25,16,23),Vector3(24,16,22),Vector3(26,15,24),Vector3(24,17,22),Vector3(25,15,24),Vector3(26,16,22)]
	var helmet_offsets: Array[float] = [18.0,17.0,19.0,18.0,17.0,19.0]
	var radio_side := 1.0 if visual_variant % 2 == 0 else -1.0
	var canteen_side := -radio_side

	# Low-profile cloth-covered helmet over the existing knit cap, with a rim and chin straps.
	var head := _a05n_attach("mixamorig_Head", "cloth covered high-altitude helmet")
	if head != null:
		var helmet := SphereMesh.new()
		helmet.radius = 0.5
		helmet.height = 0.76
		helmet.radial_segments = 24
		helmet.rings = 12
		_part(helmet,olive_cloth,Vector3(0,helmet_offsets[visual_variant],0),helmet_scales[visual_variant],head)
		var rim := TorusMesh.new()
		rim.inner_radius = 0.39
		rim.outer_radius = 0.5
		rim.rings = 20
		rim.ring_segments = 8
		var rim_node := _part(rim,olive_canvas,Vector3(0,helmet_offsets[visual_variant]-6,0),Vector3(27,24,2),head)
		rim_node.rotation.x = PI * 0.5
		_capsule(head,dark_canvas,Vector3(-10,11,0),Vector3(-7,-9,5),0.55,8)
		_capsule(head,dark_canvas,Vector3(10,11,0),Vector3(7,-9,5),0.55,8)
		if visual_variant == 1 or visual_variant == 4:
			# A few patrol members wear a raised snow gaiter over the lower face.
			var face_gaiter := BoxMesh.new()
			face_gaiter.size = Vector3(13,6,2.4)
			_part(face_gaiter,dark_canvas,Vector3(0,-7,7),Vector3.ONE,head)
		elif visual_variant == 2 or visual_variant == 5:
			# Cloth ear flaps alter the outline while remaining attached to the head.
			var flap := BoxMesh.new()
			flap.size = Vector3(3.5,9,8)
			_part(flap,olive_canvas,Vector3(-11,2,-1),Vector3.ONE,head)
			_part(flap,olive_canvas,Vector3(11,2,-1),Vector3.ONE,head)

	# Wool neck wrap layered over the skinned neck warmer already in the source mesh.
	var neck := _a05n_attach("mixamorig_Neck", "wool neck wrap")
	if neck != null:
		var wrap := TorusMesh.new()
		wrap.inner_radius = 0.34
		wrap.outer_radius = 0.5
		wrap.rings = 20
		wrap.ring_segments = 8
		var wrap_scale := Vector3(12.0,12.0,2.0) if visual_variant % 2 == 0 else Vector3(14.0,13.0,2.4)
		var wrap_node := _part(wrap,dark_canvas,Vector3(0,-2,0),wrap_scale,neck)
		wrap_node.rotation.x = PI * 0.5
		if visual_variant == 3 or visual_variant == 5:
			var scarf_tail := BoxMesh.new()
			scarf_tail.size = Vector3(8,12,2)
			_part(scarf_tail,olive_canvas,Vector3(-5,-8,-1),Vector3.ONE,neck)

	# Reconstructed shoulder identifiers follow the upper arm bones rather than the world root.
	for arm in ["mixamorig_LeftArm", "mixamorig_RightArm"]:
		var shoulder_patch := _a05n_attach(arm, "subdued tricolour sleeve patch")
		if shoulder_patch != null:
			_add_subdued_tricolour(shoulder_patch,Vector3(0,4,5),Vector2(6.6,4.2),0.20)

	# A compact field radio sits high on the chest; the integrated source webbing and pouches remain skinned.
	var chest := _a05n_attach("mixamorig_Spine2", "field radio")
	if chest != null:
		var radio_body := BoxMesh.new()
		radio_body.size = Vector3(8,12,4.5)
		_part(radio_body,olive_canvas,Vector3(radio_side*14,-3,10),Vector3.ONE,chest)
		var radio_face := BoxMesh.new()
		radio_face.size = Vector3(5.5,8.5,0.5)
		_part(radio_face,dark_metal,Vector3(radio_side*14,-3,12.5),Vector3.ONE,chest)
		var antenna := CylinderMesh.new()
		antenna.top_radius = 0.45
		antenna.bottom_radius = 0.65
		antenna.height = 1.0
		_part(antenna,dark_metal,Vector3(radio_side*17,8,9),Vector3(1.0,11,1.0),chest)
		var dial := SphereMesh.new()
		dial.radius = 0.5
		dial.height = 0.5
		_part(dial,olive_cloth,Vector3(radio_side*12,-1,12.9),Vector3(1.8,1.8,0.7),chest)

	# A hard-sided canteen rides at the belt beside the integrated utility pouches.
	var hips := _a05n_attach("mixamorig_Hips", "canteen and climbing hardware")
	if hips != null:
		var canteen := CapsuleMesh.new()
		canteen.radius = 0.5
		canteen.height = 1.0
		canteen.radial_segments = 12
		canteen.rings = 4
		_part(canteen,olive_canvas,Vector3(canteen_side*16,-8,1),Vector3(8,14,5),hips)
		var cap := CylinderMesh.new()
		cap.top_radius = 0.5
		cap.bottom_radius = 0.5
		cap.height = 1.0
		_part(cap,dark_canvas,Vector3(canteen_side*16,0,1),Vector3(2.8,1.6,2.8),hips)
		var carabiner := TorusMesh.new()
		carabiner.inner_radius = 0.32
		carabiner.outer_radius = 0.5
		carabiner.rings = 16
		carabiner.ring_segments = 6
		var belt_drop := 3.0+float(visual_variant%3)*1.4
		for side in [-1.0,1.0]:
			_part(carabiner,dark_metal,Vector3(side*17,-belt_drop,6),Vector3(5.5,7.5,1.5),hips)
			var gate := BoxMesh.new()
			gate.size = Vector3(0.8,4.8,0.8)
			_part(gate,olive_cloth,Vector3(side*17+1.8,-belt_drop,6),Vector3.ONE,hips)

	# Coiled static line on the pack and padded gloves remain attached through all poses.
	var back := _a05n_attach("mixamorig_Spine2", "climbing rope coil")
	if back != null:
		var rope := TorusMesh.new()
		rope.inner_radius = 0.36
		rope.outer_radius = 0.5
		rope.rings = 20
		rope.ring_segments = 8
		var rope_scale := Vector3(18.0+float(visual_variant%3)*1.5,18.0,3.5)
		var rope_offset := Vector3(float(visual_variant%3-1)*2.0,0,-18)
		_part(rope,olive_canvas,rope_offset,rope_scale,back)
	for hand_name in ["mixamorig_LeftHand", "mixamorig_RightHand"]:
		var glove := _a05n_attach(hand_name, "padded winter glove")
		if glove != null:
			var palm := SphereMesh.new()
			palm.radius = 0.5
			palm.height = 0.7
			palm.radial_segments = 12
			palm.rings = 8
			_part(palm,olive_canvas,Vector3.ZERO,Vector3(8.5,4.5,8.5),glove)

func _add_subdued_tricolour(parent: Node3D, center: Vector3, size: Vector2, thickness: float) -> void:
	var backing := _material(Color(0.12,0.15,0.10))
	var saffron := _material(Color(0.43,0.24,0.10))
	var off_white := _material(Color(0.48,0.46,0.37))
	var green := _material(Color(0.12,0.22,0.13))
	var navy := _material(Color(0.035,0.055,0.085))
	backing.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	saffron.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	off_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	navy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var base := BoxMesh.new()
	base.size = Vector3(size.x+0.006,size.y+0.006,thickness)
	_part(base,backing,center,Vector3.ONE,parent)
	var stripe_height := size.y/3.0
	for stripe in 3:
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(size.x,stripe_height,thickness*0.35)
		var stripe_material: Material = saffron if stripe == 0 else (off_white if stripe == 1 else green)
		var stripe_position := center+Vector3(0,(1-stripe)*stripe_height,thickness*0.55)
		_part(stripe_mesh,stripe_material,stripe_position,Vector3.ONE,parent)
	var chakra := SphereMesh.new()
	chakra.radial_segments = 12
	chakra.rings = 6
	_part(chakra,navy,center+Vector3(0,0,thickness*0.8),Vector3(size.y*0.10,size.y*0.10,thickness*0.60),parent)

func _build_turnaround_soldier() -> void:
	body_root = Node3D.new()
	add_child(body_root)
	generated_character_sprite = Sprite3D.new()
	generated_character_sprite.name = "Generated patrol character — turnaround sprite"
	generated_character_sprite.pixel_size = 2.0 / 506.0
	generated_character_sprite.position = Vector3(0.0, 1.0, 0.0)
	generated_character_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	generated_character_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	generated_character_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body_root.add_child(generated_character_sprite)
	var width_scale_file := FileAccess.open("res://assets/Characters/generated_turnaround/walk_width_scales.json", FileAccess.READ)
	if width_scale_file != null:
		var parsed_scales: Variant = JSON.parse_string(width_scale_file.get_as_text())
		if parsed_scales is Dictionary:
			generated_character_walk_width_scales = parsed_scales
	for pose in ["low", "high", "crouch_low", "crouch_high"]:
		for view_index in range(8):
			var key := "%s_%d" % [pose, view_index]
			var texture_path := "res://assets/Characters/generated_turnaround/soldier_%s_%d.png" % [pose, view_index]
			generated_character_textures[key] = load(texture_path) as Texture2D
			for frame_index in range(4):
				var walk_key := "walk_%s_%d_%d" % [pose, view_index, frame_index]
				var walk_path := "res://assets/Characters/generated_turnaround/soldier_walk_%s_%d_%d.png" % [pose, view_index, frame_index]
				generated_character_textures[walk_key] = load(walk_path) as Texture2D
	_update_turnaround_sprite()

func _update_turnaround_sprite() -> void:
	if generated_character_sprite == null:
		return
	var view_index := 0
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var actor_forward := -global_basis.z
		var camera_direction := camera.global_position - global_position
		actor_forward.y = 0.0
		camera_direction.y = 0.0
		actor_forward = actor_forward.normalized()
		camera_direction = camera_direction.normalized()
		var view_angle := atan2(actor_forward.cross(camera_direction).y, actor_forward.dot(camera_direction))
		view_index = posmod(roundi(view_angle / (PI / 4.0)), 8)
	var ready_pose := "high" if high_ready else "low"
	var pose := "crouch_%s" % ready_pose if crouched else ready_pose
	var texture_key := "%s_%d" % [pose, view_index]
	if moving:
		var walk_frame := posmod(floori(fposmod(gait_clock, TAU) / TAU * 4.0), 4)
		texture_key = "walk_%s_%d_%d" % [pose, view_index, walk_frame]
	if texture_key != generated_character_texture_key:
		generated_character_sprite.texture = generated_character_textures.get(texture_key) as Texture2D
		generated_character_texture_key = texture_key
	generated_character_sprite.pixel_size = 2.0 / 506.0
	var walk_width_scale := Vector2.ONE
	if moving:
		var scale_data: Variant = generated_character_walk_width_scales.get("%s_%d" % [pose, view_index], {})
		if scale_data is Dictionary:
			walk_width_scale = Vector2(float(scale_data.get("x", 1.0)), float(scale_data.get("y", 1.0)))
	generated_character_sprite.scale = Vector3(walk_width_scale.x, walk_width_scale.y, 1.0)
	# The walk frames share a planted boot baseline, so the old float-like root bob
	# is removed; only the alternating full-body step poses move while travelling.
	generated_character_sprite.position.y = walk_width_scale.y

func _pose_closed_rifle_hands() -> void:
	if soldier_skeleton == null:
		return
	# The candidate mesh imports with open relaxed fingers. Curl the digits around
	# the rifle axis so the palms read as gripping the trigger and fore-end areas.
	for bone_index in soldier_skeleton.get_bone_count():
		var bone_name := soldier_skeleton.get_bone_name(bone_index)
		if not bone_name.contains("Hand") or bone_name.ends_with("_end"):
			continue
		var is_thumb := bone_name.contains("Thumb")
		var is_digit := is_thumb or bone_name.contains("Index") or bone_name.contains("Middle") or bone_name.contains("Ring") or bone_name.contains("Pinky")
		if not is_digit:
			continue
		var flex := 0.42 if is_thumb else 0.72
		if bone_name.ends_with("1"):
			flex *= 0.72
		var base_rotation := soldier_skeleton.get_bone_pose_rotation(bone_index)
		soldier_skeleton.set_bone_pose_rotation(bone_index, base_rotation * Quaternion(Vector3.RIGHT, flex))

func set_contact_ready(value: bool) -> void:
	if ready_override >= 0:
		value = ready_override == 1
	high_ready = value

func play_action_animation(action: String) -> bool:
	if action not in ["reload", "incoming_fire", "aftermath"]:
		return false
	if action == "reload" and moving:
		return false
	action_animation = action
	action_animation_clock = 0.0
	if action == "reload":
		action_restore_high_ready = high_ready
		set_contact_ready(false)
	if action == "aftermath":
		path.clear()
		moving = false
		set_contact_ready(false)
	return true

func _update_action_animation(delta: float) -> void:
	if action_animation.is_empty() or soldier_skeleton == null:
		return
	var amount := 1.0
	if action_animation != "aftermath":
		action_animation_clock += delta
		var duration := 1.15 if action_animation == "reload" else 0.82
		var progress := action_animation_clock / duration
		if progress >= 1.0:
			var finished_action := action_animation
			action_animation = ""
			if finished_action == "reload": set_contact_ready(action_restore_high_ready)
			return
		amount = sin(PI * clampf(progress,0.0,1.0))
	match action_animation:
		"reload":
			# Support hand reaches the magwell and returns to the fore-end grip;
			# the trigger hand stays on the pistol grip throughout.
			if rifle_node != null and not prone:
				var target_local := LEFT_GRIP_LOCAL.lerp(Vector3(0.0,-0.17,-0.105),amount)
				_solve_rifle_arm("mixamorig_LeftArm","mixamorig_LeftForeArm","mixamorig_LeftHand",rifle_node.to_global(target_local),Vector3(-0.5,-1.0,0.15))
		"incoming_fire":
			# A startled brace to distant fire, not a confirmed hit or casualty.
			var brace_rotation := body_root.rotation
			brace_rotation.z += 0.045 * amount
			body_root.rotation = brace_rotation
			_pose_bone_axis("mixamorig_Spine2",Vector3.RIGHT,-0.035*amount)
			_pose_bone_axis("mixamorig_Neck",Vector3.RIGHT,0.025*amount)
		"aftermath":
			# Quiet, upright reflective pose; no collapse, wound or captivity depiction.
			_pose_bone_axis("mixamorig_Spine2",Vector3.RIGHT,-0.035)
			_pose_bone_axis("mixamorig_Neck",Vector3.RIGHT,0.075)
			_pose_bone_axis("mixamorig_Head",Vector3.RIGHT,0.06)

func _update_ready_pose(delta: float) -> void:
	if rifle_node == null or not a05l_candidate:
		return
	if prone:
		high_ready = false
		ready_blend = 0.0
		rifle_node.position = Vector3(0.0,1.50,-0.04)
		# Counter-rotate the rifle against the body's prone pitch so its barrel
		# stays level and aimed ahead rather than pointing into the snow.
		rifle_node.rotation = Vector3(-body_root.rotation.x,0.0,0.0)
		rifle_node.force_update_transform()
		if not prone_arm_pose_cached and absf(body_root.rotation.x-prone_target_pitch) < 0.025:
			for joint in low_arm_pose: soldier_skeleton.set_bone_pose_rotation(joint,soldier_base_pose[joint])
			soldier_skeleton.force_update_all_bone_transforms()
			_solve_rifle_arm("mixamorig_RightArm","mixamorig_RightForeArm","mixamorig_RightHand",rifle_node.to_global(RIGHT_GRIP_LOCAL),Vector3(0.5,-1.0,0.15))
			soldier_skeleton.force_update_all_bone_transforms()
			_solve_rifle_arm("mixamorig_LeftArm","mixamorig_LeftForeArm","mixamorig_LeftHand",rifle_node.to_global(LEFT_GRIP_LOCAL),Vector3(-0.5,-1.0,0.15))
			soldier_skeleton.force_update_all_bone_transforms()
			var right_hand := soldier_skeleton.find_bone("mixamorig_RightHand")
			var left_hand := soldier_skeleton.find_bone("mixamorig_LeftHand")
			if right_hand >= 0: prone_right_grip_error = soldier_skeleton.to_global(soldier_skeleton.get_bone_global_pose(right_hand).origin).distance_to(rifle_node.to_global(RIGHT_GRIP_LOCAL))
			if left_hand >= 0: prone_left_grip_error = soldier_skeleton.to_global(soldier_skeleton.get_bone_global_pose(left_hand).origin).distance_to(rifle_node.to_global(LEFT_GRIP_LOCAL))
			for joint in low_arm_pose: prone_arm_pose[joint] = soldier_skeleton.get_bone_pose_rotation(joint)
			prone_arm_pose_cached = true
		var active_arm_pose := prone_arm_pose if prone_arm_pose_cached else low_arm_pose
		for joint in active_arm_pose: soldier_skeleton.set_bone_pose_rotation(joint,active_arm_pose[joint])
		return
	var target_blend := 1.0 if high_ready else 0.0
	ready_blend = target_blend if delta >= 1.0 else lerpf(ready_blend, target_blend, minf(1.0, delta * 9.0))
	rifle_node.position = LOW_RIFLE_POSITION.lerp(HIGH_RIFLE_POSITION, ready_blend)
	rifle_node.rotation = LOW_READY_ROTATION.lerp(HIGH_READY_ROTATION, ready_blend)
	support_grip_local = LEFT_GRIP_LOCAL
	for joint in low_arm_pose.keys():
		var low_rotation: Quaternion = low_arm_pose[joint]
		var high_rotation: Quaternion = high_arm_pose[joint]
		soldier_skeleton.set_bone_pose_rotation(joint, low_rotation.slerp(high_rotation, ready_blend))

func _cache_rifle_arm_poses() -> void:
	var arm_bones: Array[int] = []
	for bone_name in ["mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_LeftArm", "mixamorig_LeftForeArm"]:
		var joint := soldier_skeleton.find_bone(bone_name)
		if joint >= 0:
			arm_bones.append(joint)
	for is_high in [false, true]:
		rifle_node.position = HIGH_RIFLE_POSITION if is_high else LOW_RIFLE_POSITION
		rifle_node.rotation = HIGH_READY_ROTATION if is_high else LOW_READY_ROTATION
		_solve_rifle_arm("mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand", rifle_node.to_global(RIGHT_GRIP_LOCAL), Vector3(0.5, -1.0, 0.15))
		_solve_rifle_arm("mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", rifle_node.to_global(LEFT_GRIP_LOCAL), Vector3(-0.5, -1.0, 0.15))
		var pose_cache := high_arm_pose if is_high else low_arm_pose
		for joint in arm_bones:
			pose_cache[joint] = soldier_skeleton.get_bone_pose_rotation(joint)

func _solve_rifle_arm(upper_name: String, forearm_name: String, hand_name: String, target_world: Vector3, pole_body: Vector3) -> void:
	if soldier_skeleton == null:
		return
	var upper := soldier_skeleton.find_bone(upper_name)
	var forearm := soldier_skeleton.find_bone(forearm_name)
	var hand := soldier_skeleton.find_bone(hand_name)
	if upper < 0 or forearm < 0 or hand < 0:
		return
	for joint in [upper, forearm]:
		soldier_skeleton.set_bone_pose_rotation(joint, soldier_base_pose[joint])
	var target := soldier_skeleton.to_local(target_world)
	var shoulder_position := soldier_skeleton.get_bone_global_pose(upper).origin
	var elbow_position := soldier_skeleton.get_bone_global_pose(forearm).origin
	var hand_position := soldier_skeleton.get_bone_global_pose(hand).origin
	var upper_length := shoulder_position.distance_to(elbow_position)
	var lower_length := elbow_position.distance_to(hand_position)
	var shoulder_to_target := target - shoulder_position
	var target_distance := shoulder_to_target.length()
	if target_distance < 0.001:
		return
	var reach := clampf(target_distance, absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	var direction_to_target := shoulder_to_target / target_distance
	var pole_world := body_root.global_basis * pole_body
	var pole := (soldier_skeleton.global_basis.inverse() * pole_world).normalized()
	pole = (pole - direction_to_target * pole.dot(direction_to_target)).normalized()
	if pole.length_squared() < 0.001:
		pole = direction_to_target.cross(Vector3.UP).normalized()
	var along := (upper_length * upper_length - lower_length * lower_length + reach * reach) / (2.0 * reach)
	var bend := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var desired_elbow := shoulder_position + direction_to_target * along + pole * bend
	_aim_bone_segment(upper, forearm, desired_elbow)
	_aim_bone_segment(forearm, hand, target)

func _aim_bone_segment(joint: int, child: int, target: Vector3) -> void:
	var joint_pose := soldier_skeleton.get_bone_global_pose(joint)
	var pivot := joint_pose.origin
	var child_position := soldier_skeleton.get_bone_global_pose(child).origin
	var from_direction := child_position - pivot
	var to_direction := target - pivot
	if from_direction.length_squared() < 0.0001 or to_direction.length_squared() < 0.0001:
		return
	var correction := Quaternion(from_direction.normalized(), to_direction.normalized())
	var joint_global := joint_pose.basis.get_rotation_quaternion()
	var local_correction := joint_global.inverse() * correction * joint_global
	var pose := soldier_skeleton.get_bone_pose_rotation(joint)
	soldier_skeleton.set_bone_pose_rotation(joint, (pose * local_correction).normalized())

func _apply_a05l_period_palette(model: Node3D) -> void:
	# The supplied candidate is a generic contemporary soldier mesh. Recolour
	# its untextured surfaces toward an olive field uniform and remove the visor
	# surface so it reads as a period-informed base for review, not modern black
	# armor. This is a visual reconstruction, not a claim about a named soldier.
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh.mesh == null or mesh.mesh.get_surface_count() < 11:
			continue
		mesh.set_surface_override_material(0,_a05l_material(Color(0.18,0.22,0.15),0.92,0.0)) # clothes
		mesh.set_surface_override_material(1,_a05l_material(Color(0.32,0.34,0.23),0.62,0.28)) # iron, painted field hardware
		mesh.set_surface_override_material(2,_a05l_material(Color(0.27,0.28,0.19),0.90,0.0)) # fabric
		mesh.set_surface_override_material(3,_a05l_material(Color(0.38,0.39,0.25),0.66,0.20)) # metal, painted field hardware
		mesh.set_surface_override_material(4,_a05l_material(Color(0.12,0.15,0.095),0.72,0.08)) # webbing
		mesh.set_surface_override_material(5,_a05l_material(Color(0.22,0.25,0.15),0.76,0.05)) # armor converted to olive kit
		mesh.set_surface_override_material(6,_a05l_material(Color(0.43,0.27,0.19),0.76,0.0)) # flesh
		mesh.set_surface_override_material(7,_a05l_material(Color(0.18,0.15,0.10),0.84,0.0)) # shoes
		mesh.set_surface_override_material(8,_a05l_material(Color(0.12,0.11,0.08),0.88,0.0)) # boots
		# The source visor surface is kept as a matte olive helmet/eye-shade
		# treatment. This removes the glossy black sci-fi read while retaining
		# readable head volume from the isometric camera.
		mesh.set_surface_override_material(9,_a05l_material(Color(0.48,0.45,0.30),0.86,0.0))
		mesh.set_surface_override_material(10,_a05l_material(Color(0.46,0.30,0.22),0.72,0.0)) # visible face/skin

func _a05l_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# A restrained lift keeps the olive kit readable in the Compatibility
	# renderer's deep mountain shadows without flattening its roughness.
	material.emission_enabled = true
	material.emission = color * 0.12
	material.emission_energy_multiplier = 0.35
	return material

func _apply_a05m_materials(model: Node3D) -> void:
	# A05m keeps the candidate's readable surface separation but replaces the
	# flat imported response with one Compatibility-safe material family. The
	# shader adds a very small UV grain, upward snow catch and lower-surface
	# dusting so the kit sits in the same cold, dirty world as the terrain.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float snow_amount = 0.0;
uniform float dust_amount = 0.0;
uniform vec4 snow_color : source_color = vec4(0.74, 0.78, 0.82, 1.0);
uniform vec4 dust_color : source_color = vec4(0.46, 0.42, 0.34, 1.0);

void fragment() {
    float grain = fract(sin(dot(UV * vec2(41.0, 67.0), vec2(12.9898, 78.233))) * 43758.5453);
    float weave = mix(0.94, 1.06, grain);
    vec3 albedo = base_color.rgb * weave;
    float upward = smoothstep(0.45, 0.90, NORMAL.y);
    float lower = 1.0 - smoothstep(0.12, 0.72, NORMAL.y);
    float snow_mask = upward * snow_amount;
    float dust_mask = lower * dust_amount * 0.22;
    albedo = mix(albedo, dust_color.rgb, dust_mask);
    albedo = mix(albedo, snow_color.rgb, snow_mask);
    ALBEDO = albedo;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = mix(0.24, 0.52, metallic);
}
"""
	var surfaces := [
		[Color(0.18,0.22,0.15),0.92,0.00,0.16,0.18], # jacket/clothes
		[Color(0.32,0.34,0.23),0.62,0.28,0.05,0.20], # painted iron
		[Color(0.27,0.29,0.19),0.94,0.00,0.22,0.22], # wool/fabric
		[Color(0.38,0.39,0.25),0.66,0.20,0.04,0.18], # painted metal
		[Color(0.12,0.15,0.095),0.82,0.05,0.10,0.25], # webbing
		[Color(0.22,0.25,0.15),0.78,0.05,0.10,0.16], # armour/kit shell
		[Color(0.43,0.27,0.19),0.76,0.00,0.03,0.06], # flesh
		[Color(0.18,0.15,0.10),0.85,0.00,0.04,0.28], # shoes
		[Color(0.12,0.11,0.08),0.90,0.00,0.03,0.32], # rubber/boots
		[Color(0.48,0.45,0.30),0.86,0.00,0.08,0.12], # matte helmet/eye shade
		[Color(0.46,0.30,0.22),0.72,0.00,0.02,0.05] # exposed skin
	]
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh.mesh == null or mesh.mesh.get_surface_count() < surfaces.size():
			continue
		for i in surfaces.size():
			var spec: Array = surfaces[i]
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("base_color", spec[0])
			material.set_shader_parameter("roughness", spec[1])
			material.set_shader_parameter("metallic", spec[2])
			material.set_shader_parameter("snow_amount", spec[3])
			material.set_shader_parameter("dust_amount", spec[4])
			material.set_shader_parameter("snow_color", Color(0.74,0.78,0.82,1.0))
			material.set_shader_parameter("dust_color", Color(0.46,0.42,0.34,1.0))
			mesh.set_surface_override_material(i, material)

func _build_marker() -> void:
	# Four small ground triangles read as a selected unit without hiding the
	# boots or turning the marker into a large flat yellow disc.
	var marker_mat := _material(Color(0.12,0.95,0.24))
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker_mat.no_depth_test = true
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(0.04,0.42,0.08)
	marker_mat.emission_energy_multiplier = 0.65
	var triangle_arrays := []
	triangle_arrays.resize(Mesh.ARRAY_MAX)
	# The tip sits toward the actor's centre; each instance is placed around
	# the feet so the four arrows frame both legs instead of clustering under
	# the pelvis.
	triangle_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.12,0.0,0.16), Vector3(0.12,0.0,0.16), Vector3(0.0,0.0,-0.06)
	])
	var triangle_mesh := ArrayMesh.new()
	triangle_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,triangle_arrays)
	selection_ring = Node3D.new()
	selection_ring.name = "Selection marker - four green triangles"
	selection_ring.position = Vector3(0,0.16,0)
	add_child(selection_ring)
	var marker_positions := [
		Vector3(0,0,0.42), Vector3(0.42,0,0), Vector3(0,0,-0.42), Vector3(-0.42,0,0)
	]
	for direction in range(4):
		var triangle := _part(triangle_mesh,marker_mat,marker_positions[direction],Vector3.ONE,selection_ring)
		triangle.rotation.y = float(direction) * PI * 0.5
	selection_ring.visible = false
	badge = Label3D.new()
	badge.text = display_name
	badge.font_size = 26
	badge.pixel_size = 0.0055
	badge.position = Vector3(0,2.35,0)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.modulate = Color(0.96,0.93,0.8) if not hostile else Color(0.9,0.67,0.59)
	badge.no_depth_test = false
	add_child(badge)

func set_selected(value: bool) -> void:
	selected = value
	selection_ring.visible = value
	badge.visible = value or hostile

func set_destination(points: Array[Vector3]) -> void:
	path = points.duplicate()
	if not path.is_empty() and position.distance_to(path[0]) < 0.6:
		path.pop_front()

func _process(delta: float) -> void:
	if mountain == null or defeated:
		return
	moving = false
	var manual_move := manual_move_direction.length_squared() > 0.001
	if manual_move or not path.is_empty():
		var target := position + manual_move_direction.normalized()*0.5 if manual_move else path[0]
		var flat := Vector3(manual_move_direction.x,0,manual_move_direction.z).normalized() if manual_move else Vector3(target.x-position.x,0,target.z-position.z)
		if not manual_move and flat.length() < 0.3:
			path.pop_front()
		elif flat.length_squared() > 0.001:
			var terrain_type := mountain.surface_at(position.x,position.z)
			var speed := 0.34 if prone else (1.20 if not crouched else 0.72)
			speed *= manual_speed_scale
			if rope_traversing: speed = minf(speed,0.42)
			if terrain_type == "scree": speed *= 0.8
			if terrain_type == "snow": speed *= 0.82
			var exposure := mountain.exposure_at(position.x,position.z)
			if exposure > 0.7: speed *= 1.0-0.3*wind_strength
			var rise := mountain.height_at(target.x,target.z)-position.y
			if rise > 0.1: speed *= 0.76
			if stamina < 25.0: speed *= 0.7
			var travel := speed*delta if manual_move else minf(flat.length(),speed*delta)
			var previous := position
			position += flat.normalized()*travel
			position.y = mountain.height_at(position.x,position.z)
			direction = flat.normalized()
			rotation.y = atan2(-direction.x,-direction.z)
			moving = true
			step_distance += travel
			# The generated 3D rig uses a longer, loaded patrol stride. The
			# turnaround fallback keeps the cadence its painted cycle was built for.
			var step_interval := (0.75 if prone else (0.40 if rope_traversing else (0.45 if crouched else 0.60))) if soldier_skeleton != null else (0.55 if crouched else 0.78)
			var cycle_distance := step_interval * 2.0
			gait_cycle_distance = cycle_distance
			gait_clock = fposmod(gait_clock + travel * TAU / cycle_distance, TAU)
			while step_distance >= step_interval:
				step_distance -= step_interval
				step_player.stream = snow_step if terrain_type == "snow" else rock_step
				if not step_player.playing: step_player.play()
			var effort := (2.0 if rise > 0.1 else 0.55)+exposure*wind_strength
			var exertion_scale := 0.82 if prone else (0.9 if crouched else 1.4)
			stamina = maxf(0.0,stamina-delta*effort*exertion_scale)
	if not moving:
		stamina = minf(100.0,stamina+delta*3.5)
	var exposure := mountain.exposure_at(position.x,position.z)
	cold = clampf(cold+delta*(exposure*(0.22+wind_strength*0.2)-0.08),0,100)
	if generated_character_sprite != null:
		body_root.scale.y = 1.0
		_update_turnaround_sprite()
		return
	if soldier_skeleton != null:
		pose_update_clock += delta
		if pose_update_interval <= 0.0 or pose_update_clock >= pose_update_interval:
			var pose_delta := pose_update_clock
			pose_update_clock = 0.0
			_animate_rigged_soldier(pose_delta)
			_update_ready_pose(pose_delta)
			_update_action_animation(pose_delta)
		return
	_update_ready_pose(delta)
	var gait := sin(gait_clock) * (0.18 if moving else 0.0)
	left_leg_rig.rotation.x = lerpf(left_leg_rig.rotation.x, gait, minf(1.0,delta*10.0))
	right_leg_rig.rotation.x = lerpf(right_leg_rig.rotation.x, -gait, minf(1.0,delta*10.0))
	left_arm_rig.rotation.x = lerpf(left_arm_rig.rotation.x, -gait*0.3, minf(1.0,delta*8.0))
	right_arm_rig.rotation.x = lerpf(right_arm_rig.rotation.x, gait*0.3, minf(1.0,delta*8.0))
	body_root.scale.y = 0.82 if crouched else 1.0
	body_root.position.y = 0.015*sin(Time.get_ticks_msec()*0.012) if moving else 0.0
	if hostile and path.is_empty():
		patrol_clock += delta
		if patrol_clock > 5.0:
			patrol_clock = 0.0
			direction = Vector3(sin(Time.get_ticks_msec()*0.0007+position.x),0,-cos(Time.get_ticks_msec()*0.0007+position.x))
			rotation.y = atan2(-direction.x,-direction.z)

func _pose_bone(index: int, angle: float) -> void:
	if soldier_skeleton != null and index < soldier_base_pose.size():
		soldier_skeleton.set_bone_pose_rotation(index, soldier_base_pose[index] * Quaternion(Vector3.RIGHT, angle))

func _animate_rigged_soldier(delta: float) -> void:
	if soldier_skeleton == null:
		return
	_update_motion_state()
	var prone_active := prone
	if not prone_active: prone_arm_pose_cached = false
	var static_kneel := crouched and not moving and not prone_active
	if prone_active:
		# Follow the grade along the soldier's facing axis so the trunk rests on
		# the mountain instead of cutting through uphill slopes or floating downhill.
		var forward := direction.normalized()
		forward.y = 0.0
		if forward.length_squared() < 0.001: forward = Vector3(0.0,0.0,-1.0)
		forward = forward.normalized()
		var sample_distance := 0.75
		var rise := mountain.height_at(position.x+forward.x*sample_distance,position.z+forward.z*sample_distance)-mountain.height_at(position.x-forward.x*sample_distance,position.z-forward.z*sample_distance)
		var grade := rise/(sample_distance*2.0)
		prone_target_pitch = clampf(-PI*0.5+atan(grade),-2.2,-0.94)
		body_root.position.y = lerpf(body_root.position.y,0.20,minf(1.0,delta*12.0))
		body_root.rotation.x = lerpf(body_root.rotation.x,prone_target_pitch,minf(1.0,delta*10.0))
		soldier_skeleton.force_update_all_bone_transforms()
	if static_kneel:
		# Lower the pelvis before solving the support legs so the grounded knee
		# is within the actual thigh's reach instead of faking a high folded leg.
		body_root.position.y = lerpf(body_root.position.y,-0.62,minf(1.0,delta*14.0))
		body_root.rotation.x = lerpf(body_root.rotation.x,0.045,minf(1.0,delta*8.0))
		soldier_skeleton.force_update_all_bone_transforms()
	var phase := gait_clock
	var stride_active := moving and not crouched and not rope_traversing
	var climb_active := moving and rope_traversing and not ledge_traversing
	var ledge_active := moving and rope_traversing and ledge_traversing
	var walk_swing := sin(phase) * (0.34 if stride_active else (0.19 if climb_active else 0.0))
	var double_support := absf(cos(phase * 2.0))
	var cold_strength := clampf((cold - 35.0) / 65.0, 0.0, 1.0) if not moving else 0.0
	var cold_clock := Time.get_ticks_msec() * 0.001
	if prone_active:
		# Prone lies the generated body along its facing axis, keeping a subtle
		# crawl cycle in the hips and knees without raising the profile.
		_pose_bone_alias("mixamorig_LeftUpLeg",sin(phase)*0.055 if moving else 0.0)
		_pose_bone_alias("mixamorig_RightUpLeg",-sin(phase)*0.055 if moving else 0.0)
		_pose_bone_alias("mixamorig_LeftLeg",-0.08-maxf(0.0,cos(phase))*0.10 if moving else -0.04)
		_pose_bone_alias("mixamorig_RightLeg",-0.08-maxf(0.0,-cos(phase))*0.10 if moving else -0.04)
		_pose_bone_alias("mixamorig_LeftFoot",0.04)
		_pose_bone_alias("mixamorig_RightFoot",0.04)
		_pose_bone_alias("mixamorig_Spine",0.035*sin(phase*2.0) if moving else 0.0)
		# The imported model is yawed 180 degrees to face patrol travel, which
		# reverses its local X axis. Counter-pitch neck and head against the trunk
		# so the soldier looks forward instead of pressing the face into the snow.
		_pose_bone_axis("mixamorig_Neck",Vector3.RIGHT,prone_target_pitch*0.54)
		_pose_bone_axis("mixamorig_Head",Vector3.RIGHT,prone_target_pitch*0.46)
	# Walking is a layered, distance-driven patrol gait. Knees flex in swing,
	# ankles counter-rotate to keep the soles near level, while pelvis, chest and
	# head make small counter-movements around the stable rifle carry.
	if prone_active:
		pass
	elif stride_active:
		_pose_bone_alias("mixamorig_LeftUpLeg", walk_swing)
		_pose_bone_alias("mixamorig_RightUpLeg", -walk_swing)
		_pose_bone_alias("mixamorig_LeftLeg", -maxf(0.0, cos(phase)) * 0.58)
		_pose_bone_alias("mixamorig_RightLeg", -maxf(0.0, -cos(phase)) * 0.58)
		_pose_bone_alias("mixamorig_LeftFoot", maxf(0.0, cos(phase)) * 0.26)
		_pose_bone_alias("mixamorig_RightFoot", maxf(0.0, -cos(phase)) * 0.26)
		_pose_bone_alias("mixamorig_LeftToeBase", -maxf(0.0, -cos(phase)) * 0.18)
		_pose_bone_alias("mixamorig_RightToeBase", -maxf(0.0, cos(phase)) * 0.18)
		_pose_bone_alias("mixamorig_Spine", 0.045 + 0.018 * sin(phase * 2.0))
		_pose_bone_axis("mixamorig_Spine1", Vector3.BACK, 0.025 * sin(phase))
		_pose_bone_axis("mixamorig_Spine2", Vector3.UP, -0.025 * sin(phase))
		_pose_bone_axis("mixamorig_Neck", Vector3.BACK, -0.018 * sin(phase))
		_pose_bone_axis("mixamorig_Head", Vector3.BACK, -0.012 * sin(phase))
		_solve_walking_feet(phase)
	elif ledge_active:
		# Bent-knee lateral shelf steps with the trunk braced toward the slope.
		var traverse_swing := sin(phase)
		_pose_bone_alias("mixamorig_LeftUpLeg",traverse_swing*0.15)
		_pose_bone_alias("mixamorig_RightUpLeg",-traverse_swing*0.15)
		_pose_bone_alias("mixamorig_LeftLeg",-0.12-maxf(0.0,cos(phase))*0.20)
		_pose_bone_alias("mixamorig_RightLeg",-0.12-maxf(0.0,-cos(phase))*0.20)
		_pose_bone_alias("mixamorig_LeftFoot",0.08)
		_pose_bone_alias("mixamorig_RightFoot",0.08)
		_pose_bone_alias("mixamorig_Spine",0.13+0.015*sin(phase*2.0))
		_pose_bone_axis("mixamorig_Spine1",Vector3.BACK,0.055*sin(phase))
		_solve_walking_feet(phase,true)
	elif climb_active:
		var climb_swing := sin(phase)
		_pose_bone_alias("mixamorig_LeftUpLeg", climb_swing * 0.22)
		_pose_bone_alias("mixamorig_RightUpLeg", -climb_swing * 0.22)
		_pose_bone_alias("mixamorig_LeftLeg", -maxf(0.0, cos(phase)) * 0.45)
		_pose_bone_alias("mixamorig_RightLeg", -maxf(0.0, -cos(phase)) * 0.45)
		_pose_bone_alias("mixamorig_Spine", 0.10 + 0.02 * sin(phase))
		_pose_bone_axis("mixamorig_Spine1", Vector3.BACK, 0.035 * sin(phase))
		_solve_walking_feet(phase, true)
	elif crouched and moving:
		var crouch_swing := sin(phase) * 0.18
		_pose_bone_alias("mixamorig_LeftUpLeg", 0.20 + crouch_swing)
		_pose_bone_alias("mixamorig_RightUpLeg", 0.38 - crouch_swing)
		_pose_bone_alias("mixamorig_LeftLeg", -0.52 - maxf(0.0,cos(phase))*0.22)
		_pose_bone_alias("mixamorig_RightLeg", -0.52 - maxf(0.0,-cos(phase))*0.22)
		_pose_bone_alias("mixamorig_LeftFoot", 0.24)
		_pose_bone_alias("mixamorig_RightFoot", 0.24)
		_pose_bone_alias("mixamorig_Spine", 0.18)
		_solve_walking_feet(phase,true)
	elif crouched:
		# Static crouch is a one-knee firing stance: left boot plants forward,
		# the left thigh folds toward horizontal, and the right knee touches down.
		_pose_bone_alias("mixamorig_Spine", 0.10 if static_kneel else 0.18)
		_pose_bone_alias("mixamorig_Spine1", 0.065 if static_kneel else 0.08)
		if static_kneel:
			_solve_kneeling_pose()
		else:
			_pose_bone_alias("mixamorig_LeftUpLeg", 0.20 + sin(phase)*0.18)
			_pose_bone_alias("mixamorig_RightUpLeg", 0.38 - sin(phase)*0.18)
			_pose_bone_alias("mixamorig_LeftLeg", -0.52 - maxf(0.0,cos(phase))*0.22)
			_pose_bone_alias("mixamorig_RightLeg", -0.52 - maxf(0.0,-cos(phase))*0.22)
			_pose_bone_alias("mixamorig_LeftFoot", 0.24)
			_pose_bone_alias("mixamorig_RightFoot", 0.24)
			_solve_walking_feet(phase,true)
	else:
		_pose_bone_alias("mixamorig_LeftUpLeg", 0.0)
		_pose_bone_alias("mixamorig_RightUpLeg", 0.0)
		_pose_bone_alias("mixamorig_LeftLeg", 0.0)
		_pose_bone_alias("mixamorig_RightLeg", 0.0)
		_pose_bone_alias("mixamorig_LeftFoot", 0.0)
		_pose_bone_alias("mixamorig_RightFoot", 0.0)
		_pose_bone_axis("mixamorig_Spine", Vector3.BACK, 0.012 * sin(cold_clock * 2.2) * cold_strength)
		_pose_bone_axis("mixamorig_Spine2", Vector3.BACK, 0.018 * sin(cold_clock * 7.4) * cold_strength)
		_pose_bone_axis("mixamorig_Neck", Vector3.BACK, -0.014 * sin(cold_clock * 7.4) * cold_strength)
		_pose_bone_axis("mixamorig_Head", Vector3.BACK, -0.009 * sin(cold_clock * 7.4) * cold_strength)
	var target_scale_y := visual_height_scale
	body_root.scale.y = lerpf(body_root.scale.y, target_scale_y, minf(1.0, delta * 10.0))
	var gait_bob := 0.012 * (1.0 - double_support) if stride_active else (0.006 * absf(sin(phase * 2.0)) if climb_active or ledge_active else 0.0)
	var gait_compression := -0.62 if static_kneel else (-0.14 if stride_active else (-0.06 if climb_active or ledge_active else (-0.10 if crouched else 0.0)))
	if not static_kneel and not prone_active:
		body_root.position.y = lerpf(body_root.position.y, gait_compression + gait_bob, minf(1.0, delta * 14.0))
	var desired_pitch := (0.055 if moving and not crouched else (0.10 if climb_active else (0.13 if ledge_active else (0.04 if crouched else 0.0))))
	if not prone_active:
		body_root.rotation.x = lerpf(body_root.rotation.x, desired_pitch, minf(1.0, delta * 8.0))
	body_root.rotation.z = lerpf(body_root.rotation.z, sin(phase) * (0.012 if prone_active else 0.018) if moving else 0.0, minf(1.0, delta * 8.0))

func _solve_kneeling_pose() -> void:
	if mountain == null or soldier_skeleton == null:
		return
	var forward := direction.normalized()
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3(0.0,0.0,-1.0)
	if kneeling_pose_cached and position.distance_to(kneeling_cached_position) < 0.025 and forward.dot(kneeling_cached_direction) > 0.999 and absf(body_root.position.y-kneeling_cached_root_y) < 0.008:
		return
	var right := forward.cross(Vector3.UP).normalized()
	var left_foot_xz := position + forward*0.42 - right*0.12
	var left_foot_world := Vector3(left_foot_xz.x,mountain.height_at(left_foot_xz.x,left_foot_xz.z)+0.055,left_foot_xz.z)
	var right_up := soldier_skeleton.find_bone("mixamorig_RightUpLeg")
	var right_lower := soldier_skeleton.find_bone("mixamorig_RightLeg")
	var right_foot := soldier_skeleton.find_bone("mixamorig_RightFoot")
	if right_up < 0 or right_lower < 0 or right_foot < 0:
		return
	for bone_name in ["mixamorig_LeftUpLeg","mixamorig_LeftLeg","mixamorig_LeftFoot","mixamorig_RightUpLeg","mixamorig_RightLeg","mixamorig_RightFoot"]:
		var bone := soldier_skeleton.find_bone(bone_name)
		if bone >= 0 and bone < soldier_base_pose.size():
			soldier_skeleton.set_bone_pose_rotation(bone,soldier_base_pose[bone])
	soldier_skeleton.force_update_all_bone_transforms()
	var hip_local := soldier_skeleton.get_bone_global_pose(right_up).origin
	var knee_rest_local := soldier_skeleton.get_bone_global_pose(right_lower).origin
	var ankle_rest_local := soldier_skeleton.get_bone_global_pose(right_foot).origin
	var hip_world := soldier_skeleton.to_global(hip_local)
	kneeling_upper_leg_length = hip_world.distance_to(soldier_skeleton.to_global(knee_rest_local))
	var lower_leg_length := soldier_skeleton.to_global(knee_rest_local).distance_to(soldier_skeleton.to_global(ankle_rest_local))
	# Search the nearby ground for a reachable knee anchor. A fixed rear offset
	# fails on steep terrain because the ground height can change sharply.
	var lateral_offset := 0.13
	var right_knee_world := Vector3.ZERO
	var best_knee_error := INF
	for step in range(0,81,4):
		var candidate := position-forward*(float(step)*0.01)+right*lateral_offset
		var ground := mountain.height_at(candidate.x,candidate.z)
		var candidate_world := Vector3(candidate.x,ground+0.13,candidate.z)
		var candidate_error := absf(hip_world.distance_to(candidate_world)-kneeling_upper_leg_length)
		if candidate_error < best_knee_error:
			best_knee_error = candidate_error
			right_knee_world = candidate_world
	kneeling_hip_to_knee_target = hip_world.distance_to(right_knee_world)
	var right_ankle_world := Vector3.ZERO
	var best_ankle_error := INF
	for step in range(10,101,2):
		var ankle_xz := Vector3(right_knee_world.x,right_knee_world.y,right_knee_world.z)-forward*(float(step)*0.01)
		var ankle_world := Vector3(ankle_xz.x,mountain.height_at(ankle_xz.x,ankle_xz.z)+0.065,ankle_xz.z)
		var ankle_error := absf(right_knee_world.distance_to(ankle_world)-lower_leg_length)
		if ankle_error < best_ankle_error:
			best_ankle_error = ankle_error
			right_ankle_world = ankle_world
	# The right knee is the explicit ground anchor. Aim the thigh to that point,
	# then lay the shin backward to its ankle target while preserving knee contact.
	_aim_bone_segment(right_up,right_lower,soldier_skeleton.to_local(right_knee_world))
	soldier_skeleton.force_update_all_bone_transforms()
	_aim_bone_segment(right_lower,right_foot,soldier_skeleton.to_local(right_ankle_world))
	soldier_skeleton.force_update_all_bone_transforms()
	var actual_knee := soldier_skeleton.to_global(soldier_skeleton.get_bone_global_pose(right_lower).origin)
	var actual_ankle := soldier_skeleton.to_global(soldier_skeleton.get_bone_global_pose(right_foot).origin)
	kneeling_knee_target_error = actual_knee.distance_to(right_knee_world)
	kneeling_right_ankle_error = actual_ankle.distance_to(right_ankle_world)
	var left_error := _solve_leg_to_target("Left",left_foot_world,forward)
	kneeling_left_foot_error = left_error
	kneeling_cached_position = position
	kneeling_cached_direction = forward
	kneeling_cached_root_y = body_root.position.y
	kneeling_pose_cached = true

func _solve_leg_to_target(side_name: String, target_world: Vector3, pole_world: Vector3) -> float:
	var upper := soldier_skeleton.find_bone("mixamorig_%sUpLeg" % side_name)
	var lower := soldier_skeleton.find_bone("mixamorig_%sLeg" % side_name)
	var foot := soldier_skeleton.find_bone("mixamorig_%sFoot" % side_name)
	if upper < 0 or lower < 0 or foot < 0:
		return 999.0
	soldier_skeleton.set_bone_pose_rotation(upper,soldier_base_pose[upper])
	soldier_skeleton.set_bone_pose_rotation(lower,soldier_base_pose[lower])
	soldier_skeleton.set_bone_pose_rotation(foot,soldier_base_pose[foot])
	soldier_skeleton.force_update_all_bone_transforms()
	var hip := soldier_skeleton.get_bone_global_pose(upper).origin
	var knee := soldier_skeleton.get_bone_global_pose(lower).origin
	var ankle := soldier_skeleton.get_bone_global_pose(foot).origin
	var upper_length := hip.distance_to(knee)
	var lower_length := knee.distance_to(ankle)
	var target_local := soldier_skeleton.to_local(target_world)
	var to_target := target_local-hip
	var distance := to_target.length()
	if distance < 0.001:
		return 999.0
	var reach := clampf(distance,absf(upper_length-lower_length)+0.001,upper_length+lower_length-0.001)
	var aim := to_target/distance
	var pole := (soldier_skeleton.global_basis.inverse()*pole_world).normalized()
	pole = (pole-aim*pole.dot(aim)).normalized()
	if pole.length_squared() < 0.001:
		pole = aim.cross(Vector3.RIGHT).normalized()
	var along := (upper_length*upper_length-lower_length*lower_length+reach*reach)/(2.0*reach)
	var bend := sqrt(maxf(0.0,upper_length*upper_length-along*along))
	var knee_target := hip+aim*along+pole*bend
	_aim_bone_segment(upper,lower,knee_target)
	soldier_skeleton.force_update_all_bone_transforms()
	_aim_bone_segment(lower,foot,target_local)
	soldier_skeleton.force_update_all_bone_transforms()
	return soldier_skeleton.to_global(soldier_skeleton.get_bone_global_pose(foot).origin).distance_to(target_world)

func _update_motion_state() -> void:
	if action_animation == "aftermath":
		motion_state = "aftermath_reflective"
	elif action_animation == "reload":
		motion_state = "reload_low_ready"
	elif action_animation == "incoming_fire":
		motion_state = "incoming_fire_brace"
	elif prone and moving:
		motion_state = "prone_crawl"
	elif prone:
		motion_state = "prone_idle"
	elif moving and rope_traversing and ledge_traversing:
		motion_state = "ledge_traverse"
	elif moving and rope_traversing:
		motion_state = "rope_climb"
	elif moving and crouched:
		motion_state = "crouch_walk"
	elif moving:
		motion_state = "walk_high_ready" if high_ready else "walk_low_ready"
	elif crouched:
		motion_state = "kneel_high_ready" if high_ready else "kneel_low_ready"
	elif cold >= 55.0:
		motion_state = "cold_idle"
	else:
		motion_state = "high_ready" if high_ready else "low_ready"

func _pose_bone_axis(base_name: String, axis: Vector3, angle: float) -> void:
	if soldier_skeleton == null:
		return
	var index := soldier_skeleton.find_bone(base_name)
	if index < 0:
		for i in soldier_skeleton.get_bone_count():
			if soldier_skeleton.get_bone_name(i).begins_with(base_name + "_"):
				index = i
				break
	if index >= 0 and index < soldier_base_pose.size():
		soldier_skeleton.set_bone_pose_rotation(index, soldier_base_pose[index] * Quaternion(axis.normalized(), angle))

func _solve_walking_feet(phase: float, climbing := false) -> void:
	if mountain == null or soldier_skeleton == null:
		return
	left_foot_target_error = _solve_foot_target("Left", phase, -1.0, climbing)
	right_foot_target_error = _solve_foot_target("Right", phase + PI, 1.0, climbing)
	var frame_error := maxf(left_foot_target_error,right_foot_target_error)
	if frame_error > worst_foot_target_error:
		worst_foot_target_error = frame_error
		worst_foot_target_distance = last_leg_target_distance
		worst_foot_chain_reach = last_leg_chain_reach

func _solve_foot_target(side_name: String, phase: float, side: float, climbing: bool) -> float:
	var upper := soldier_skeleton.find_bone("mixamorig_%sUpLeg" % side_name)
	var lower := soldier_skeleton.find_bone("mixamorig_%sLeg" % side_name)
	var foot := soldier_skeleton.find_bone("mixamorig_%sFoot" % side_name)
	if upper < 0 or lower < 0 or foot < 0:
		return 999.0
	var phase_t := fposmod(phase, TAU) / TAU
	var stance_fraction := 0.52 if not climbing else 0.50
	var stride := gait_cycle_distance * stance_fraction
	var along := 0.0
	var lift := 0.0
	if phase_t < stance_fraction:
		along = stride * (0.5 - phase_t / stance_fraction)
	else:
		var swing_t := (phase_t - stance_fraction) / (1.0 - stance_fraction)
		along = -stride * 0.5 + stride * (swing_t * swing_t * (3.0 - 2.0 * swing_t))
		lift = sin(swing_t * PI) * (0.105 if not climbing else 0.15)
	var forward := direction.normalized()
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3(0,0,-1)
	var right := forward.cross(Vector3.UP).normalized()
	var foot_xz := position + right * side * 0.115 + forward * along
	var target_world := Vector3(foot_xz.x, mountain.height_at(foot_xz.x,foot_xz.z) + 0.07 + lift, foot_xz.z)
	for joint in [upper,lower]:
		soldier_skeleton.set_bone_pose_rotation(joint,soldier_base_pose[joint])
	soldier_skeleton.force_update_all_bone_transforms()
	var target_local := soldier_skeleton.to_local(target_world)
	var hip := soldier_skeleton.get_bone_global_pose(upper).origin
	var knee := soldier_skeleton.get_bone_global_pose(lower).origin
	var ankle := soldier_skeleton.get_bone_global_pose(foot).origin
	var upper_length := hip.distance_to(knee)
	var lower_length := knee.distance_to(ankle)
	var to_target := target_local - hip
	var distance := to_target.length()
	last_leg_target_distance = distance
	last_leg_chain_reach = upper_length + lower_length
	if distance < 0.001:
		return 999.0
	var reach := clampf(distance,absf(upper_length-lower_length)+0.001,upper_length+lower_length-0.001)
	var aim := to_target/distance
	var pole_world := global_basis * Vector3(0.0,0.10,-1.0)
	var pole := (soldier_skeleton.global_basis.inverse()*pole_world).normalized()
	pole = (pole-aim*pole.dot(aim)).normalized()
	if pole.length_squared() < 0.001:
		pole = aim.cross(Vector3.RIGHT).normalized()
	var along_bone := (upper_length*upper_length-lower_length*lower_length+reach*reach)/(2.0*reach)
	var bend := sqrt(maxf(0.0,upper_length*upper_length-along_bone*along_bone))
	var desired_knee := hip+aim*along_bone+pole*bend
	_aim_bone_segment(upper,lower,desired_knee)
	soldier_skeleton.force_update_all_bone_transforms()
	_aim_bone_segment(lower,foot,target_local)
	soldier_skeleton.force_update_all_bone_transforms()
	return soldier_skeleton.to_global(soldier_skeleton.get_bone_global_pose(foot).origin).distance_to(target_world)

func _pose_bone_named(name: String, angle: float) -> void:
	if soldier_skeleton == null:
		return
	var index := soldier_skeleton.find_bone(name)
	if index >= 0 and index < soldier_base_pose.size():
		soldier_skeleton.set_bone_pose_rotation(index, soldier_base_pose[index] * Quaternion(Vector3.RIGHT, angle))

func _pose_bone_alias(base_name: String, angle: float) -> void:
	if soldier_skeleton == null:
		return
	var index := soldier_skeleton.find_bone(base_name)
	if index < 0:
		for i in soldier_skeleton.get_bone_count():
			if soldier_skeleton.get_bone_name(i).begins_with(base_name + "_"):
				index = i
				break
	if index >= 0 and index < soldier_base_pose.size():
		soldier_skeleton.set_bone_pose_rotation(index, soldier_base_pose[index] * Quaternion(Vector3.RIGHT, angle))

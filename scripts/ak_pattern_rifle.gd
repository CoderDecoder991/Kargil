extends Node3D

# Original, low-cost AK-pattern rifle reconstruction for the game.
# This is a visual art choice, not a claim about this patrol's documented loadout.
# The barrel points toward local -Z. Geometry is visual only.
var magazine_rig: Node3D
var shaped_profile_count := 0

func build() -> void:
	name = "AK-pattern rifle - reconstructed visual"
	var blued := _metal_mat(Color(0.135, 0.145, 0.135), 0.58, 0.58)
	var edge := _metal_mat(Color(0.235, 0.245, 0.22), 0.48, 0.52)
	var dark := _mat(Color(0.035, 0.042, 0.038), 0.82)
	var wood := _wood_mat(Color(0.38, 0.235, 0.125), 0.19)
	var wood_lite := _wood_mat(Color(0.43, 0.285, 0.155), 0.15)
	var polymer := _mat(Color(0.095, 0.090, 0.071), 0.84)
	# Narrow stamped receiver, dust cover and visible side ribs. Axis/hand anchors
	# are retained from the prior model so the existing poses remain aligned.
	var receiver := PackedVector2Array([
		Vector2(0.043, 0.124), Vector2(0.060, 0.094), Vector2(0.055, -0.105),
		Vector2(0.035, -0.138), Vector2(-0.073, -0.138), Vector2(-0.092, -0.110),
		Vector2(-0.080, 0.078), Vector2(-0.052, 0.119), Vector2(-0.006, 0.132)
	])
	_profile(receiver, 0.092, blued)
	# The receiver profile supplies the dust-cover roof as one connected surface.
	# Avoid a separate flat plate here: it exaggerated perspective in the FPS view.
	# Receiver rails, rivets, ejection port and AK selector lever.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.049, 0.044, -0.038), Vector3(0.005, 0.009, 0.145), dark)
		for z in [-0.09, -0.02, 0.07]:
			_sphere(Vector3(side * 0.051, 0.058, z), Vector3(0.008, 0.008, 0.008), edge)
	_box(Vector3(0.049, 0.025, 0.025), Vector3(0.008, 0.035, 0.072), dark)
	_box(Vector3(0.054, 0.019, 0.023), Vector3(0.006, 0.020, 0.055), edge)
	_box(Vector3(-0.052, -0.030, -0.005), Vector3(0.010, 0.009, 0.142), edge)
	_box(Vector3(-0.059, -0.025, 0.039), Vector3(0.020, 0.009, 0.046), blued)
	# Fixed laminated stock with a narrow metal butt plate and shoulder curvature.
	var buttstock := Node3D.new()
	buttstock.name = "FPS-hidden AK buttstock"
	add_child(buttstock)
	_profile(PackedVector2Array([
		Vector2(-0.014, 0.112), Vector2(0.034, 0.135), Vector2(0.055, 0.203),
		Vector2(0.050, 0.322), Vector2(0.027, 0.411), Vector2(-0.055, 0.411),
		Vector2(-0.063, 0.343), Vector2(-0.040, 0.251), Vector2(-0.053, 0.168)
	]), 0.075, wood, Vector3.ZERO, buttstock)
	_box_in(buttstock, Vector3(0, -0.012, 0.418), Vector3(0.090, 0.104, 0.014), blued)
	for groove in range(5):
		_box_in(buttstock, Vector3(0, -0.046 + float(groove) * 0.017, 0.426), Vector3(0.066, 0.004, 0.003), dark)
	# Two-piece upper/lower wood handguard and visible cooling slots.
	_profile(PackedVector2Array([
		Vector2(-0.023, -0.414), Vector2(-0.043, -0.393), Vector2(-0.044, -0.157),
		Vector2(-0.026, -0.133), Vector2(0.033, -0.133), Vector2(0.047, -0.161),
		Vector2(0.044, -0.390), Vector2(0.024, -0.414)
	]), 0.083, wood)
	# A thin cap sits flush with the handguard top; the earlier stacked plates
	# floated above the handguard and made the first-person rifle look exploded.
	_box(Vector3(0, 0.046, -0.294), Vector3(0.058, 0.010, 0.192), wood_lite)
	for side in [-1.0, 1.0]:
		for i in range(4):
			_box(Vector3(side * 0.043, 0.005, -0.208 - float(i) * 0.049), Vector3(0.004, 0.012, 0.025), dark)
	# Gas tube, front handguard cap and ribbed steel gas block.
	_cylinder(Vector3(0, 0.064, -0.438), 0.009, 0.210, blued)
	_box(Vector3(0, 0.040, -0.427), Vector3(0.083, 0.026, 0.020), edge)
	_box(Vector3(0, 0.052, -0.440), Vector3(0.050, 0.018, 0.186), dark)
	for i in range(5):
		_box(Vector3(0, 0.064, -0.366 - float(i) * 0.028), Vector3(0.051, 0.004, 0.004), edge)
	# AK pistol grip remains directly under the trigger hand anchor.
	_profile(PackedVector2Array([
		Vector2(-0.064, 0.033), Vector2(-0.125, 0.044), Vector2(-0.172, 0.095),
		Vector2(-0.167, 0.129), Vector2(-0.118, 0.142), Vector2(-0.067, 0.116)
	]), 0.062, polymer)
	# Distinctive 30-round curved steel magazine, profiled rather than a straight box.
	magazine_rig = Node3D.new()
	magazine_rig.name = "AK-pattern curved 30-round magazine"
	add_child(magazine_rig)
	_profile(PackedVector2Array([
		Vector2(-0.095, -0.072), Vector2(-0.164, -0.066), Vector2(-0.221, -0.095),
		Vector2(-0.284, -0.145), Vector2(-0.331, -0.203), Vector2(-0.337, -0.238),
		Vector2(-0.309, -0.252), Vector2(-0.274, -0.225), Vector2(-0.225, -0.174),
		Vector2(-0.174, -0.134), Vector2(-0.108, -0.119)
	]), 0.064, blued, Vector3.ZERO, magazine_rig)
	# Embossed magazine ribs and a flat base pad, kept subdued at game scale.
	for side in [-1.0, 1.0]:
		for i in range(4):
			_box_in(magazine_rig, Vector3(side * 0.033, -0.205 - float(i) * 0.022, -0.152 - float(i) * 0.018), Vector3(0.003, 0.004, 0.047), edge)
	_box_in(magazine_rig, Vector3(0, -0.324, -0.221), Vector3(0.060, 0.010, 0.050), dark)
	# Slim barrel, front sight tower with protective ears, and short slant brake.
	_cylinder(Vector3(0, 0.012, -0.558), 0.0085, 0.395, blued)
	_cylinder(Vector3(0, 0.013, -0.755), 0.010, 0.055, edge)
	_cylinder(Vector3(0, 0.013, -0.795), 0.008, 0.025, dark)
	_box(Vector3(0, 0.026, -0.570), Vector3(0.020, 0.040, 0.028), edge)
	_box(Vector3(-0.016, 0.059, -0.570), Vector3(0.005, 0.035, 0.025), blued)
	_box(Vector3(0.016, 0.059, -0.570), Vector3(0.005, 0.035, 0.025), blued)
	_box(Vector3(0, 0.074, -0.570), Vector3(0.004, 0.022, 0.008), edge)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.009, 0.025, -0.566), Vector3(0.004, 0.018, 0.016), dark)
	# Tangent rear sight and narrow notch, no oversized optic or INSAS bridge.
	_box(Vector3(0, 0.062, -0.083), Vector3(0.038, 0.008, 0.018), blued)
	_box(Vector3(0, 0.068, -0.083), Vector3(0.022, 0.005, 0.014), dark)
	_box(Vector3(-0.014, 0.072, -0.083), Vector3(0.003, 0.008, 0.009), edge)
	_box(Vector3(0.014, 0.072, -0.083), Vector3(0.003, 0.008, 0.009), edge)
	# Trigger guard and small sling ferrule. A procedural ribbon sling was removed
	# because its box-shaped strip read as a separate floating part in first person.
	var guard := MeshInstance3D.new()
	var guard_mesh := TorusMesh.new()
	guard_mesh.inner_radius = 0.023
	guard_mesh.outer_radius = 0.028
	guard_mesh.rings = 6
	guard_mesh.ring_segments = 12
	guard.mesh = guard_mesh
	guard.material_override = blued
	guard.position = Vector3(0, -0.104, -0.047)
	guard.rotation.z = PI * 0.5
	add_child(guard)
	_box(Vector3(0, -0.105, -0.046), Vector3(0.010, 0.036, 0.010), edge)
	_cylinder_axis(Vector3(-0.054, -0.012, -0.407), 0.006, 0.018, edge, Vector3(PI * 0.5, 0, 0))

func set_reload_progress(progress: float) -> void:
	if magazine_rig == null:
		return
	var phase := clampf(progress, 0.0, 1.0)
	var drop := 0.0
	if phase < 0.22:
		drop = -0.29 * smoothstep(0.0, 0.22, phase)
	elif phase < 0.58:
		drop = -0.29
	elif phase < 0.90:
		drop = lerpf(-0.29, 0.0, smoothstep(0.58, 0.90, phase))
	magazine_rig.position = Vector3(0.012 * sin(phase * PI), drop, 0.018 * sin(phase * PI))
	magazine_rig.rotation.x = -0.12 * sin(phase * PI)

func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _metal_mat(color: Color, roughness: float, metallic: float) -> ShaderMaterial:
	# Fine directional variation makes blued steel catch a controlled highlight
	# on the receiver and barrel without a noisy high-resolution texture.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 metal_color : source_color = vec3(0.12, 0.13, 0.13);
uniform float base_roughness = 0.5;
uniform float metalness = 0.8;
varying vec3 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    float brush = sin(local_position.z * 280.0 + local_position.y * 21.0 + local_position.x * 13.0);
    float fine = sin(local_position.x * 190.0) * sin(local_position.z * 150.0);
    float value = 0.94 + brush * 0.028 + fine * 0.012;
    ALBEDO = metal_color * value;
    ROUGHNESS = clamp(base_roughness + brush * 0.018, 0.30, 0.90);
    METALLIC = metalness;
    SPECULAR = 0.52;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("metal_color", color)
	material.set_shader_parameter("base_roughness", roughness)
	material.set_shader_parameter("metalness", metallic)
	return material

func _wood_mat(base_color: Color, grain_strength: float) -> ShaderMaterial:
	# Fine directional grain keeps the rifle furniture from reading as flat boxes
	# while remaining inexpensive in the Compatibility renderer.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 wood_color : source_color = vec3(0.37, 0.245, 0.145);
uniform float grain_strength : hint_range(0.0, 0.3) = 0.15;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float fine_grain = sin(local_position.z * 320.0 + sin(local_position.x * 40.0) * 0.4 + sin(local_position.y * 27.0) * 0.2);
	float broad_grain = sin(local_position.z * 14.0 + local_position.x * 1.2 + sin(local_position.y * 2.0) * 0.2);
	float variation = 1.0 + fine_grain * grain_strength * 0.14 + broad_grain * grain_strength * 0.10;
	ALBEDO = wood_color * variation;
	ROUGHNESS = clamp(0.76 - max(broad_grain, 0.0) * 0.06, 0.68, 0.82);
	METALLIC = 0.0;
	SPECULAR = 0.24;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("wood_color", base_color)
	material.set_shader_parameter("grain_strength", grain_strength)
	return material

func _box(at: Vector3, size: Vector3, material: Material) -> void:
	_box_in(self, at, size, material)

func _box_in(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	part.position = at
	parent.add_child(part)

func _cylinder(at: Vector3, radius: float, length: float, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 20
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation.x = PI * 0.5
	add_child(part)

func _sphere(at: Vector3, scale: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.scale = scale
	add_child(part)

func _cylinder_axis(at: Vector3, radius: float, length: float, material: Material, rotation: Vector3) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = rotation
	add_child(part)

func _profile(points: PackedVector2Array, depth: float, material: Material, offset: Vector3 = Vector3.ZERO, parent: Node3D = null) -> void:
	# Extrude a hand-shaped Y/Z side profile across X for rounded receiver, stock,
	# and grip silhouettes that retain a low-cost mesh budget in Compatibility.
	var outline := points.duplicate()
	if Geometry2D.is_polygon_clockwise(outline):
		outline.reverse()
	var cap := Geometry2D.triangulate_polygon(outline)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := depth * 0.5
	for side in [-1.0, 1.0]:
		for i in range(0, cap.size(), 3):
			var tri := [cap[i], cap[i + 1], cap[i + 2]]
			if side < 0.0:
				tri.reverse()
			for index in tri:
				var point: Vector2 = outline[index]
				tool.add_vertex(offset + Vector3(side * half, point.x, point.y))
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var a0 := offset + Vector3(-half, a.x, a.y)
		var a1 := offset + Vector3(half, a.x, a.y)
		var b0 := offset + Vector3(-half, b.x, b.y)
		var b1 := offset + Vector3(half, b.x, b.y)
		tool.add_vertex(a0)
		tool.add_vertex(b0)
		tool.add_vertex(b1)
		tool.add_vertex(a0)
		tool.add_vertex(b1)
		tool.add_vertex(a1)
	tool.generate_normals()
	var part := MeshInstance3D.new()
	part.name = "Shaped extruded weapon component"
	part.mesh = tool.commit()
	part.material_override = material
	if parent == null:
		add_child(part)
	else:
		parent.add_child(part)
	shaped_profile_count += 1

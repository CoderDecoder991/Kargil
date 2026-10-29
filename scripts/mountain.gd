extends Node3D
class_name Mountain

const HALF := 48.0
const STEP := 1.5
var noise := FastNoiseLite.new()
var rocks: Array[Vector3] = []
var snow_points: Array[Vector3] = []

func _ready() -> void:
	noise.seed = 1999
	noise.frequency = 0.075
	noise.fractal_octaves = 3
	_build_ground()
	_build_backdrop()
	_build_rocks()

func height_at(x: float, z: float) -> float:
	# Broad cross-cut ridges make a recognizable mountain landform at gameplay
	# scale. The forms are authored as an interpretive test map, not a surveyed
	# reconstruction of the historical patrol route.
	var regional_rise := (45.0 - z) * 0.12
	var crest_warp := noise.get_noise_2d(x * 0.20 + 12.0, 4.0) * 3.2
	var crest_z := -20.0 + x * 0.23 + sin(x * 0.075) * 4.2 + crest_warp
	var primary_crest := 12.0 * exp(-pow((z - crest_z) / 10.5, 2.0))
	var rear_crest_z := -46.0 + x * 0.10 + sin(x * 0.06 + 0.8) * 5.5 + noise.get_noise_2d(x * 0.18 - 8.0, 19.0) * 3.0
	var rear_ridge := 7.0 * exp(-pow((z - rear_crest_z) / 7.5, 2.0))
	var west_spur_x := -30.0 + sin(z * 0.065) * 5.0 + z * 0.08
	var east_spur_x := 29.0 + cos(z * 0.058 + 0.7) * 5.5 - z * 0.07
	var side_spurs := 7.0 * exp(-pow((x - west_spur_x) / 8.0, 2.0))
	side_spurs += 8.0 * exp(-pow((x - east_spur_x) / 9.0, 2.0))
	# Drainage cuts run diagonally down the faces and form lower route choices.
	var west_gully_x := -17.0 + z * 0.13 + sin(z * 0.075) * 3.8
	var east_gully_x := 17.0 - z * 0.12 + cos(z * 0.07) * 3.2
	var gullies := -3.4 * exp(-pow((x - west_gully_x) / 4.4, 2.0))
	gullies += -3.0 * exp(-pow((x - east_gully_x) / 4.8, 2.0))
	var shelves := 1.25 * sin(x * 0.13 + z * 0.065) + 0.8 * cos(z * 0.12 - x * 0.035)
	var broad_erosion := noise.get_noise_2d(x * 0.19, z * 0.19) * 2.4
	var detail := noise.get_noise_2d(x * 0.62, z * 0.62) * 1.0
	var broken_rock := noise.get_noise_2d(x * 2.1, z * 2.1) * 0.28
	return regional_rise + primary_crest + rear_ridge + side_spurs + gullies + shelves + broad_erosion + detail + broken_rock

func _smooth01(low: float, high: float, value: float) -> float:
	var t := clampf((value - low) / (high - low), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func surface_at(x: float, z: float) -> String:
	var h := height_at(x, z)
	var n := noise.get_noise_2d(x * 2.1 + 80.0, z * 2.1)
	# Broad, readable route bands for the climb prototype. These are authored
	# gameplay surfaces, not a surveyed map of the historical patrol route.
	if z < -21.0 or (z >= -22.0 and z <= -8.0 and x < 3.0) or h > 17.0:
		return "snow"
	if (z > -3.0 and z < 10.0) or (x > 3.0 and z < -3.0 and z > -25.0) or n > 0.42:
		return "scree"
	return "rock"

func exposure_at(x: float, z: float) -> float:
	var ledge := 1.0 if z < -4.0 and z > -23.0 and x > 4.0 else 0.0
	var crest := clampf((height_at(x,z)-12.0)/9.0,0.0,1.0)
	var shelter := 0.25 if x < -8.0 and x > -20.0 and z > -15.0 and z < -3.0 else 1.0
	return maxf(ledge,crest)*shelter

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := int(HALF * 2.0 / STEP)
	for zi in range(cells):
		for xi in range(cells):
			var x := -HALF + xi * STEP
			var z := -HALF + zi * STEP
			var a := Vector3(x, height_at(x,z), z)
			var b := Vector3(x+STEP, height_at(x+STEP,z), z)
			var c := Vector3(x, height_at(x,z+STEP), z+STEP)
			var d := Vector3(x+STEP, height_at(x+STEP,z+STEP), z+STEP)
			_add_vertex(st,a)
			_add_vertex(st,b)
			_add_vertex(st,c)
			_add_vertex(st,b)
			_add_vertex(st,d)
			_add_vertex(st,c)
	st.generate_normals()
	var mesh := st.commit()
	var mat := _terrain_material()
	mesh.surface_set_material(0,mat)
	var body := StaticBody3D.new()
	body.name = "WalkableMountain"
	add_child(body)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(instance)
	var collider := CollisionShape3D.new()
	collider.shape = mesh.create_trimesh_shape()
	body.add_child(collider)

func _terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/terrain.gdshader")
	mat.set_shader_parameter("rock_tex",load("res://assets/textures/rock_scree_v1.png"))
	mat.set_shader_parameter("snow_tex",load("res://assets/textures/wind_snow_v1.png"))
	return mat

func _backdrop_height(x: float, z: float) -> float:
	var h := height_at(x,z)
	if x > HALF or z > HALF:
		var edge_x := minf(x,HALF)
		var edge_z := minf(z,HALF)
		h = height_at(edge_x,edge_z)-maxf(maxf(0,x-HALF),maxf(0,z-HALF))*0.33
	return h

func _build_backdrop() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 4.0
	for zi in range(56):
		for xi in range(56):
			var x := -112.0 + xi*step
			var z := -112.0 + zi*step
			if x >= -HALF and x+step <= HALF and z >= -HALF and z+step <= HALF:
				continue
			var a := Vector3(x,_backdrop_height(x,z),z)
			var b := Vector3(x+step,_backdrop_height(x+step,z),z)
			var c := Vector3(x,_backdrop_height(x,z+step),z+step)
			var d := Vector3(x+step,_backdrop_height(x+step,z+step),z+step)
			_add_vertex(st,a)
			_add_vertex(st,b)
			_add_vertex(st,c)
			_add_vertex(st,b)
			_add_vertex(st,d)
			_add_vertex(st,c)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0,_terrain_material())
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _add_vertex(st: SurfaceTool, p: Vector3) -> void:
	var surface := surface_at(p.x,p.z)
	# Keep the gameplay surface categories, but shade snow as a soft accumulation
	# field so the visible boundary follows terrain and wind rather than hard map bands.
	var upper_snow := 1.0 - _smooth01(-29.0, -14.0, p.z)
	var shelf_snow := _smooth01(-25.0, -19.0, p.z) * (1.0 - _smooth01(-10.0, -3.0, p.z)) * (1.0 - _smooth01(-1.0, 7.0, p.x))
	var altitude_snow := _smooth01(11.0, 23.0, p.y) * 0.88
	var authored_snow := 0.94 if surface == "snow" else 0.0
	var snow_mask := maxf(maxf(maxf(upper_snow * 0.88, shelf_snow * 0.82), altitude_snow), authored_snow)
	snow_mask = clampf(snow_mask + noise.get_noise_2d(p.x * 0.22 + 31.0, p.z * 0.22 - 17.0) * 0.11, 0.0, 1.0)
	# Central differences produce a real gradient magnitude. This steep-face mask
	# strips snow from cliffs while leaving broad shelves white.
	var sample_step := 0.75
	var gradient_x := (height_at(p.x + sample_step, p.z) - height_at(p.x - sample_step, p.z)) / (sample_step * 2.0)
	var gradient_z := (height_at(p.x, p.z + sample_step) - height_at(p.x, p.z - sample_step)) / (sample_step * 2.0)
	var slope := clampf(Vector2(gradient_x, gradient_z).length() / 1.05, 0.0, 1.0)
	var altitude := clampf((p.y + 4.0) / 24.0,0.0,1.0)
	st.set_color(Color(snow_mask,slope,altitude,1.0))
	st.set_uv(Vector2(p.x*0.105,p.z*0.105))
	st.add_vertex(p)

func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 491999
	var mesh := _create_boulder_mesh()
	var materials: Array[StandardMaterial3D] = []
	var rock_transforms: Array = [[], [], []]
	for tint in [Color(0.56,0.57,0.58),Color(0.72,0.7,0.67),Color(0.83,0.81,0.78)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = tint
		m.albedo_texture = load("res://assets/textures/rock_scree_v1.png")
		m.roughness = 1.0
		materials.append(m)
	for i in range(105):
		var x := rng.randf_range(-45.0,45.0)
		var z := rng.randf_range(-44.0,44.0)
		if absf(x) < 6.0 and i % 3 != 0:
			continue
		var scale := Vector3(rng.randf_range(0.7,2.0),rng.randf_range(0.55,1.6),rng.randf_range(0.7,2.3))
		# Rest the irregular mesh on the local grade, with its up axis following
		# the slope normal. This prevents steep-face boulders reading as floaters.
		var sample := 0.75
		var gradient_x := (height_at(x+sample,z)-height_at(x-sample,z))/(sample*2.0)
		var gradient_z := (height_at(x,z+sample)-height_at(x,z-sample))/(sample*2.0)
		var normal := Vector3(-gradient_x,1.0,-gradient_z).normalized()
		var p := Vector3(x,height_at(x,z),z)+normal*scale.y*0.18
		rocks.append(p)
		var orientation := Quaternion(Vector3.UP,normal)*Quaternion(Vector3.UP,rng.randf_range(0.0,TAU))
		var rock_basis := Basis(orientation).scaled(scale)
		rock_transforms[i % materials.size()].append(Transform3D(rock_basis,p))
		if scale.x > 1.1:
			var obstacle := StaticBody3D.new()
			obstacle.position = p
			add_child(obstacle)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(scale.x*1.35,scale.y*1.65,scale.z*1.35)
			shape.shape = box
			obstacle.add_child(shape)
	# Batch the repeated boulder mesh into three tinted MultiMeshes. Collision
	# bodies above remain separate, while the render path drops to three draws.
	for material_index in materials.size():
		var transforms: Array = rock_transforms[material_index]
		if transforms.is_empty(): continue
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = transforms.size()
		for instance_index in transforms.size():
			instances.set_instance_transform(instance_index,transforms[instance_index])
		var rocks_batch := MultiMeshInstance3D.new()
		rocks_batch.name = "Rock LOD batch %d (%d)" % [material_index,transforms.size()]
		rocks_batch.multimesh = instances
		rocks_batch.material_override = materials[material_index]
		add_child(rocks_batch)

func _create_boulder_mesh() -> ArrayMesh:
	# Low-poly icosahedral boulders with shared per-vertex deformation keep the
	# silhouette angular without holes between independently displaced faces.
	var t := (1.0 + sqrt(5.0)) * 0.5
	var source_points: Array[Vector3] = [
		Vector3(-1,t,0), Vector3(1,t,0), Vector3(-1,-t,0), Vector3(1,-t,0),
		Vector3(0,-1,t), Vector3(0,1,t), Vector3(0,-1,-t), Vector3(0,1,-t),
		Vector3(t,0,-1), Vector3(t,0,1), Vector3(-t,0,-1), Vector3(-t,0,1)
	]
	var faces: Array[Vector3i] = [
		Vector3i(0,11,5), Vector3i(0,5,1), Vector3i(0,1,7), Vector3i(0,7,10), Vector3i(0,10,11),
		Vector3i(1,5,9), Vector3i(5,11,4), Vector3i(11,10,2), Vector3i(10,7,6), Vector3i(7,1,8),
		Vector3i(3,9,4), Vector3i(3,4,2), Vector3i(3,2,6), Vector3i(3,6,8), Vector3i(3,8,9),
		Vector3i(4,9,5), Vector3i(2,4,11), Vector3i(6,2,10), Vector3i(8,6,7), Vector3i(9,8,1)
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1729
	var points: Array[Vector3] = []
	for point in source_points:
		var radial_scale := rng.randf_range(0.84,1.12)
		var p := point.normalized() * radial_scale
		p.y *= rng.randf_range(0.78,1.18)
		points.append(p)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for index in [face.x,face.z,face.y]:
			var point := points[index]
			st.set_uv(Vector2(atan2(point.z,point.x)/TAU+0.5,point.y*0.5+0.5))
			st.add_vertex(point)
	st.generate_normals()
	return st.commit()

func _build_snow_drifts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9914
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.76,0.79,0.8)
	mat.roughness = 1.0
	var transforms: Array[Transform3D] = []
	for i in range(38):
		var x := rng.randf_range(-42,42)
		var z := rng.randf_range(-43,8)
		var p := Vector3(x,height_at(x,z)-0.18,z)
		snow_points.append(p)
		var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(rng.randf_range(1.1,3.4),0.22,rng.randf_range(1.0,3.0)))
		transforms.append(Transform3D(basis,p))
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in transforms.size(): instances.set_instance_transform(i,transforms[i])
	var drift_batch := MultiMeshInstance3D.new()
	drift_batch.name = "Snow drift LOD batch (%d)" % transforms.size()
	drift_batch.multimesh = instances
	drift_batch.material_override = mat
	drift_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drift_batch)

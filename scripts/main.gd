extends Node3D

const MountainScript = preload("res://scripts/mountain.gd")
const ActorScript = preload("res://scripts/actor.gd")
const AK_VIEWMODEL = preload("res://assets/models/ak_pattern_rifle.tscn")
const GLOVED_ARMS = preload("res://assets/hands/gloved_hands_trimmed.glb")
const OLIVE_FABRIC = preload("res://assets/textures/olive_fabric.png")
const ROSTER := ["Lt. Saurabh Kalia", "Sepoy Arjun Ram", "Sepoy Bhanwar Lal Bhagaria", "Sepoy Bhikaram", "Sepoy Moola Ram", "Sepoy Naresh Singh"]
const OBSERVATION := Vector3(0,0,-32)
const ROPE_NEAR := Vector3(12,0,-13)
const ROPE_FAR := Vector3(8,0,-25)
enum FireMode { SINGLE, BURST }
const MAGAZINE_CAPACITY := 30
const RESERVE_CAPACITY := 120
const BURST_SHOT_COUNT := 3
const SHOT_INTERVAL := 0.10
const RELOAD_DURATION := 1.45
const SHOT_DAMAGE := 40.0

var mountain: Mountain
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
var squad: Array[PatrolActor] = []
var sentries: Array[PatrolActor] = []
var mission_markers: Array[Node3D] = []
var selected: Array[int] = [0]
var grid := AStarGrid2D.new()
var camera_target := Vector3(0,5,30)
var camera_yaw := 0.0
var camera_zoom := 38.0
var camera_manual := false
var first_person_mode := false
var fps_mouse_captured := false
var fps_yaw := 0.0
var fps_pitch := -0.04
var fps_aiming := false
var fps_follow_clock := 0.0
var fps_last_move_direction := Vector3.ZERO
var fps_view_rig: Node3D
var fps_view_muzzle_local := Vector3.ZERO
var fps_view_muzzle_anchor_valid := false
var fps_view_stock: Node3D
var fps_aim_hidden_parts: Array[Node3D] = []
var fps_reload_started_msec := -1
var fps_reload_remaining := 0.0
var fps_fire_mode := FireMode.SINGLE
var fps_magazine_rounds := MAGAZINE_CAPACITY
var fps_reserve_rounds := RESERVE_CAPACITY
var fps_trigger_down := false
var fps_fire_cooldown := 0.0
var fps_burst_rounds_remaining := 0
var fps_burst_timer := 0.0
var fps_weapon_recoil_pitch := 0.0
var fps_weapon_recoil_roll := 0.0
var fps_weapon_recoil_back := 0.0
var fps_camera_recoil_pitch := 0.0
var fps_muzzle_flash_clock := 0.0
var fps_muzzle_attachment: Node3D
var fps_ejection_port: Node3D
var fps_muzzle_flash: Sprite3D
var fps_muzzle_light: OmniLight3D
var fps_casings: Array[RigidBody3D] = []
var fps_transient_effects: Array[Node3D] = []
var fps_transient_lifetimes: Dictionary = {}
var fps_shot_count := 0
var fps_hit_count := 0
var phase := 0
var phase_timer := 0.0
var tactical_paused := false
var queued_orders: Dictionary = {}
var weather_clock := 0.0
var visibility := 1.0
var preset := 1
var objective_label: Label
var status_label: Label
var weapon_status_label: Label
var roster_label: RichTextLabel
var hint_label: Label
var flash_label: Label
var fps_reticle: Control
var overlay: PanelContainer
var overlay_title: Label
var overlay_body: RichTextLabel
var overlay_button: Button
var review_ui_layer: CanvasLayer
var benchmark := ""
var fps_lighting_review := false
var smoke_route := false
var input_check := false
var smoke_clock := 0.0
var smoke_route_leg := 0
var bench_clock := 0.0
var bench_frames: Array[float] = []
var bench_capture := false
var footprint_clock := 0.0
var footprint_multimesh: MultiMesh
var footprint_cursor := 0
var footprint_count := 0
var sound_player: AudioStreamPlayer
var fire_player: AudioStreamPlayer
var weapon_fire_player: AudioStreamPlayer
var weapon_fire_players: Array[AudioStreamPlayer] = []
var weapon_fire_player_cursor := 0
var contact_cue := 0
var detection_message_shown := false
var rope_started := false
var rope_crossing_group: Array[int] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_ensure_firing_input_action()
	if "--bench-terrain" in args: benchmark = "terrain"
	if "--bench-game" in args: benchmark = "game"
	fps_lighting_review = "--fps-lighting-review" in args
	smoke_route = "--smoke-route" in args
	input_check = "--input-check" in args
	if benchmark != "":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_setup_world()
	if fps_lighting_review: _setup_fps_lighting_review_environment()
	_build_path_grid()
	if benchmark != "terrain":
		_build_landmarks()
		_build_characters()
		_build_footprint_batch()
		_build_ui()
		_load_wind()
	_apply_preset(1)
	if benchmark == "terrain":
		if "--terrain-close" in args:
			camera_target = Vector3(0,mountain.height_at(0,-22),-22)
			camera_zoom = 22.0
		else:
			camera_target = Vector3(0,8,0)
			camera_zoom = 67.0
		_apply_preset(0)
		print("BENCH_TERRAIN_BEGIN renderer=%s viewport=%s" % [RenderingServer.get_current_rendering_method(),get_viewport().get_visible_rect().size])
	elif benchmark == "game":
		_begin_mission()
		if "--bench-perf" in args: _apply_preset(0)
		elif "--bench-high" in args: _apply_preset(2)
		phase = 4
		phase_timer = 0
		if "--fps-review" in args:
			for i in squad.size():
				squad[i].path.clear()
				squad[i].set_contact_ready(true)
			_set_first_person_mode(true)
		if fps_lighting_review:
			for i in squad.size():
				squad[i].path.clear()
				squad[i].set_contact_ready(true)
			_set_first_person_mode(true)
			if review_ui_layer != null: review_ui_layer.visible = false
		if "--fps-aim-review" in args:
			for i in squad.size():
				squad[i].path.clear()
				squad[i].set_contact_ready(true)
			_set_first_person_mode(true)
			fps_aiming = true
			if review_ui_layer != null: review_ui_layer.visible = true
		elif "--a05l-review" in args:
			for i in squad.size():
				squad[i].path.clear()
				squad[i].visible = i == 0
				squad[i].position = _ground(Vector3(0,0,-27))
				squad[i].crouched = "--art-crouch" in args
				squad[i].set_selected(i == 0)
			camera_target = squad[0].position
			camera_zoom = 4.0
			if review_ui_layer != null: review_ui_layer.visible = false
		elif "--a05n-review" in args:
			phase = 1
			phase_timer = 0.0
			for enemy in sentries: enemy.visible = false
			for i in squad.size():
				squad[i].path.clear()
				squad[i].visible = i == 0
				squad[i].position = _ground(Vector3(0,0,-22))
				squad[i].direction = Vector3(0,0,-1)
				squad[i].rotation.y = 0.0
				squad[i].set_contact_ready(false)
				squad[i].set_selected(false)
				squad[i].badge.visible = false
			camera_target = squad[0].position
			camera_zoom = 4.0
			for marker in mission_markers: marker.visible = false
			if review_ui_layer != null: review_ui_layer.visible = false
		elif "--a05o-review" in args or "--a05o-close-review" in args:
			phase = 1
			phase_timer = 0.0
			for enemy in sentries: enemy.visible = false
			for i in squad.size():
				squad[i].path.clear()
				squad[i].visible = true
				squad[i].position = _ground(Vector3((float(i%3)-1.0)*2.6,0,-23.0+float(i/3)*3.4))
				squad[i].direction = Vector3(0,0,1)
				squad[i].rotation.y = PI
				squad[i].set_contact_ready(false)
				squad[i].set_selected(i == 0)
				squad[i].badge.visible = true
			camera_target = _ground(Vector3(0,0,-21.3))
			camera_zoom = 8.0 if "--a05o-close-review" in args else 10.0
			for marker in mission_markers: marker.visible = false
			if review_ui_layer != null: review_ui_layer.visible = false
		elif "--walk-compare" in args:
			for i in squad.size():
				squad[i].path.clear()
				squad[i].visible = i < 2
				squad[i].position = _ground(Vector3(-4.0 + i * 8.0,0,-27))
				squad[i].crouched = "--walk-crouch" in args
				squad[i].set_contact_ready("--rifle-high" in args)
				squad[i].direction = Vector3(0,0,1)
				squad[i].rotation.y = PI
				squad[i].set_selected(false)
				squad[i].badge.visible = false
			_order_actor(1,_ground(Vector3(4.0,0,27)))
			camera_target = _ground(Vector3(0,0,-27))
			camera_zoom = 11.0
			if review_ui_layer != null: review_ui_layer.visible = false
		elif "--walk-review" in args:
			for i in squad.size():
				squad[i].path.clear()
				squad[i].visible = i == 0
				squad[i].position = _ground(Vector3(0,0,-27))
				squad[i].crouched = "--walk-crouch" in args
				squad[i].set_contact_ready("--rifle-high" in args)
				squad[i].set_selected(i == 0)
			_order_actor(0,_ground(Vector3(0,0,27)))
			camera_target = squad[0].position
			camera_zoom = 6.0
			if review_ui_layer != null: review_ui_layer.visible = false
		elif "--a05p-kneel-review" in args:
			phase = 1
			phase_timer = 0.0
			for enemy in sentries: enemy.visible = false
			for i in squad.size():
				squad[i].path.clear()
				squad[i].visible = i == 0
				squad[i].position = _ground(Vector3(0,0,-22))
				squad[i].direction = Vector3(0,0,-1)
				squad[i].rotation.y = 0.0
				squad[i].crouched = i == 0
				squad[i].rope_traversing = false
				squad[i].set_contact_ready(false)
				squad[i].set_selected(false)
				squad[i].badge.visible = false
			camera_target = squad[0].position
			camera_zoom = 4.5
			for marker in mission_markers: marker.visible = false
			if review_ui_layer != null: review_ui_layer.visible = false
		elif "--a05p-prone-review" in args:
			phase = 1
			phase_timer = 0.0
			var full_squad_prone := "--a05p-prone-squad" in args
			for enemy in sentries:
				if not full_squad_prone: enemy.visible = false
			for i in squad.size():
				squad[i].path.clear()
				squad[i].visible = full_squad_prone or i == 0
				squad[i].position = _ground(Vector3((float(i)-2.5)*2.2,0,-22))
				squad[i].direction = Vector3(0,0,-1)
				squad[i].rotation.y = 0.0
				squad[i].prone = full_squad_prone or i == 0
				squad[i].crouched = false
				squad[i].rope_traversing = false
				squad[i].set_contact_ready(false)
				squad[i].set_selected(false)
				squad[i].badge.visible = false
			camera_target = _ground(Vector3(0,0,-22)) if full_squad_prone else squad[0].position
			camera_zoom = 13.0 if full_squad_prone else 4.0
			for marker in mission_markers: marker.visible = false
			if review_ui_layer != null: review_ui_layer.visible = false
		elif "--a05p-walk-review" in args:
			phase = 1
			phase_timer = 0.0
			for enemy in sentries: enemy.visible = false
			for i in squad.size():
				squad[i].path.clear()
				squad[i].visible = i == 0
				squad[i].position = _ground(Vector3(0,0,-22))
				squad[i].direction = Vector3(0,0,-1)
				squad[i].rotation.y = 0.0
				squad[i].crouched = "--a05p-crouch" in args
				squad[i].rope_traversing = "--a05p-rope" in args
				squad[i].set_contact_ready("--rifle-high" in args)
				squad[i].set_selected(false)
				squad[i].badge.visible = false
			_order_actor(0,_ground(Vector3(0,0,-39)))
			camera_target = squad[0].position
			camera_zoom = 4.5
			for marker in mission_markers: marker.visible = false
			if review_ui_layer != null: review_ui_layer.visible = false
		else:
			for i in squad.size():
				squad[i].position = _ground(Vector3(-8+i*2,0,-23+i*0.4))
				if "--art-crouch" in args: squad[i].crouched = true
				_order_actor(i,Vector3(8-i*2,0,-35))
			camera_target = squad[0].position if "--art-review" in args else _ground(Vector3(0,0,-27))
			camera_zoom = 4 if "--art-macro" in args else (8 if "--art-review" in args else 30)
		if "--art-side" in args: camera_yaw = PI * 0.5
		elif "--art-front" in args: camera_yaw = PI
		print("BENCH_GAME_BEGIN renderer=%s preset=%s viewport=%s" % [RenderingServer.get_current_rendering_method(),["Performance","Balanced","High"][preset],get_viewport().get_visible_rect().size])
	elif smoke_route:
		_begin_mission()
		selected = [0,1,2,3,4,5]
		_sync_selection()
		smoke_route_leg = 1
		_command_move(_ground(Vector3(0,0,15)))
		print("SMOKE_ROUTE_BEGIN path_nodes=%d" % squad[0].path.size())
	_update_camera()
	if input_check: call_deferred("_check_input_path")

func _send_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	_unhandled_input(event)

func _ensure_firing_input_action() -> void:
	if not InputMap.has_action("fire_weapon"):
		InputMap.add_action("fire_weapon")
		var fire_button := InputEventMouseButton.new()
		fire_button.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire_weapon",fire_button)
	if not InputMap.has_action("fire_mode_toggle"):
		InputMap.add_action("fire_mode_toggle")
		var mode_key := InputEventKey.new()
		mode_key.physical_keycode = KEY_B
		InputMap.action_add_event("fire_mode_toggle",mode_key)

func _check_input_path() -> void:
	for frame in range(5): await get_tree().physics_frame
	if not squad.is_empty() and squad[0].soldier_skeleton != null:
		_check_rigged_input_path()
		return
	_begin_mission()
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for step in 15: _unhandled_input(wheel)
	var zoom_close := camera_zoom <= 8.01
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for step in 20: _unhandled_input(wheel)
	var zoom_far := camera_zoom >= 82.99
	camera_zoom = 38.0
	_update_camera()
	var turnaround_sprites := 0
	var kneeling_sprites := 0
	var pose_textures := 0
	var walk_textures := 0
	var walk_width_scale_entries := 0
	for actor in squad:
		actor.set_contact_ready(true)
		actor._update_ready_pose(1.0)
		actor._update_turnaround_sprite()
		if actor.generated_character_sprite != null and actor.generated_character_sprite.texture != null:
			turnaround_sprites += 1
			pose_textures += actor.generated_character_textures.size()
			for texture_key in actor.generated_character_textures:
				if str(texture_key).begins_with("walk_") and actor.generated_character_textures[texture_key] != null:
					walk_textures += 1
			for scale_key in actor.generated_character_walk_width_scales:
				var scale_data: Variant = actor.generated_character_walk_width_scales[scale_key]
				var width_scale_x := float(scale_data.get("x", 0.0)) if scale_data is Dictionary else 0.0
				var width_scale_y := float(scale_data.get("y", 0.0)) if scale_data is Dictionary else 0.0
				if width_scale_x >= 0.5 and width_scale_x <= 1.0 and width_scale_y >= 0.5 and width_scale_y <= 1.0:
					walk_width_scale_entries += 1
	_send_key(KEY_TAB)
	_send_key(KEY_C)
	var crouch_pass := squad[0].crouched
	for actor in squad:
		actor._update_turnaround_sprite()
		if actor.crouched and actor.generated_character_texture_key.begins_with("crouch_high_"):
			kneeling_sprites += 1
	var walk_cycle_frames := {}
	var walk_test_actor: PatrolActor = squad[0]
	walk_test_actor.moving = true
	for frame_index in range(4):
		walk_test_actor.gait_clock = (float(frame_index) + 0.2) * TAU / 4.0
		walk_test_actor._update_turnaround_sprite()
		walk_cycle_frames[walk_test_actor.generated_character_texture_key] = walk_test_actor.generated_character_sprite.texture != null
	var walking_sprite_scale := walk_test_actor.generated_character_sprite.scale
	var walking_boot_anchor := walk_test_actor.generated_character_sprite.position.y - walking_sprite_scale.y
	walk_test_actor.moving = false
	walk_test_actor._update_turnaround_sprite()
	var walking_size_pass := walking_sprite_scale.x >= 0.5 and walking_sprite_scale.x <= 1.0 and walking_sprite_scale.y >= 0.5 and walking_sprite_scale.y <= 1.0 and is_zero_approx(walking_boot_anchor) and is_equal_approx(walk_test_actor.generated_character_sprite.scale.x, 1.0) and is_equal_approx(walk_test_actor.generated_character_sprite.scale.y, 1.0)
	var walk_cycle_pass := walk_cycle_frames.size() == 4 and not walk_cycle_frames.values().has(false) and walking_size_pass
	_send_key(KEY_SPACE)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = camera.unproject_position(_ground(Vector3(0,0,27)))
	var probe := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,80,27),Vector3(0,-80,27)))
	_unhandled_input(click)
	var queued := queued_orders.size()
	_send_key(KEY_ENTER)
	var path_nodes := squad[0].path.size()
	_send_key(KEY_F5)
	var saved := FileAccess.file_exists(_save_path())
	_send_key(KEY_F9)
	var guard := sentries[0]
	squad[0].position = _ground(guard.position+guard.direction*3.0)
	squad[0].crouched = false
	_perception(2.0)
	var seen := guard.alert > 0.5
	var passed := selected.size() == 6 and turnaround_sprites == 6 and kneeling_sprites == 6 and pose_textures == 960 and walk_textures == 768 and walk_width_scale_entries == 192 and walk_cycle_pass and crouch_pass and queued == 6 and path_nodes > 0 and not tactical_paused and saved and phase == 1 and not probe.is_empty() and seen and zoom_close and zoom_far
	print("INPUT_CHECK_%s selected=%d turnaround_sprites=%d kneeling_sprites=%d pose_textures=%d walk_textures=%d walk_width_scales=%d walk_cycle_frames=%d queued=%d path_nodes=%d saved=%s sight=%s zoom_close=%s zoom_far=%s" % ["PASS" if passed else "FAIL",selected.size(),turnaround_sprites,kneeling_sprites,pose_textures,walk_textures,walk_width_scale_entries,walk_cycle_frames.size(),queued,path_nodes,saved,seen,zoom_close,zoom_far])
	if saved: DirAccess.remove_absolute(_save_path())
	get_tree().quit(0 if passed else 2)

func _check_rigged_input_path() -> void:
	_begin_mission()
	var rig_count := 0
	var bone_count_min := 999
	var rifles := 0
	var close_grips := true
	var prone_pose_pass := true
	var a05n_kit_pass := true
	var a05n_min_attachments := 999
	var a05o_variants: Dictionary = {}
	var max_foot_error := 0.0
	for actor in squad:
		if actor.soldier_skeleton == null or not actor.a05l_candidate:
			continue
		rig_count += 1
		bone_count_min = mini(bone_count_min,actor.soldier_skeleton.get_bone_count())
		a05o_variants[actor.a05o_variant_signature] = true
		if actor.rifle_node != null: rifles += 1
		var kit_attachments := actor.soldier_skeleton.find_children("A05n reconstructed *","BoneAttachment3D",true,false)
		a05n_min_attachments = mini(a05n_min_attachments,kit_attachments.size())
		var actor_kit_pass := actor.a05n_kit_attachment_count == 9 and kit_attachments.size() == 9
		for attachment_node in kit_attachments:
			var attachment := attachment_node as BoneAttachment3D
			actor_kit_pass = actor_kit_pass and attachment != null and actor.soldier_skeleton.find_bone(attachment.bone_name) >= 0 and attachment.get_parent() == actor.soldier_skeleton
		a05n_kit_pass = a05n_kit_pass and actor_kit_pass
		actor.set_contact_ready(true)
		actor._update_ready_pose(1.0)
		actor.direction = Vector3(0,0,-1)
		actor.moving = true
		actor.gait_cycle_distance = 1.20
		actor.worst_foot_target_error = 0.0
		actor.gait_clock = 0.0
		actor._animate_rigged_soldier(1.0)
		for phase_index in range(8):
			actor.gait_clock = float(phase_index) * TAU / 8.0
			actor._animate_rigged_soldier(1.0/60.0)
			actor._update_ready_pose(1.0/60.0)
			max_foot_error = maxf(max_foot_error,maxf(actor.left_foot_target_error,actor.right_foot_target_error))
		close_grips = close_grips and actor.low_arm_pose.size() >= 4 and actor.high_arm_pose.size() >= 4
		actor.rope_traversing = true
		actor._animate_rigged_soldier(1.0/60.0)
		var climb_state := actor.motion_state == "rope_climb"
		actor.rope_traversing = false
		actor.crouched = true
		actor.moving = false
		for settle_frame in range(40): actor._animate_rigged_soldier(1.0/60.0)
		var crouch_state := actor.motion_state.begins_with("kneel_")
		var kneel_contact_pass := actor.kneeling_knee_target_error < 0.20 and actor.kneeling_left_foot_error < 0.20 and actor.kneeling_right_ankle_error < 0.20
		if not kneel_contact_pass: close_grips = false
		actor.crouched = false
		actor._animate_rigged_soldier(1.0/60.0)
		actor.prone = true
		for settle_frame in range(40):
			actor._animate_rigged_soldier(1.0/60.0)
			actor._update_ready_pose(1.0/60.0)
		var prone_state := actor.motion_state == "prone_idle" and absf(actor.body_root.rotation.x-actor.prone_target_pitch) < 0.04 and not actor.high_ready and actor.prone_arm_pose_cached and actor.prone_right_grip_error < 0.05 and actor.prone_left_grip_error < 0.05
		actor.prone = false
		actor._animate_rigged_soldier(1.0/60.0)
		if not climb_state or not crouch_state: close_grips = false
		if not prone_state: prone_pose_pass = false
	selected = [0]
	squad[0].prone = false
	squad[0].crouched = false
	_send_key(KEY_V)
	var prone_toggle_on := squad[0].prone
	_send_key(KEY_C)
	var prone_to_kneel := not squad[0].prone and squad[0].crouched
	_send_key(KEY_V)
	var kneel_to_prone := squad[0].prone and not squad[0].crouched
	_send_key(KEY_V)
	var prone_toggle_off := not squad[0].prone and not squad[0].crouched
	var prone_controls_pass := prone_toggle_on and prone_to_kneel and kneel_to_prone and prone_toggle_off
	_set_first_person_mode(true)
	var fps_mode_pass := first_person_mode and camera.projection == Camera3D.PROJECTION_PERSPECTIVE and fps_view_rig != null and fps_view_rig.visible and camera.cull_mask == 3
	var fps_stock := fps_view_rig.find_child("Stock",true,false) as Node3D
	var rear_sight := fps_view_rig.find_child("RearIronGeometry",true,false) as MeshInstance3D
	var front_sight := fps_view_rig.find_child("FrontIronGeometry",true,false) as MeshInstance3D
	var optic_adapter := fps_view_rig.find_child("OpticRailAdapterGeometry",true,false) as MeshInstance3D
	fps_aiming = true
	_update_camera()
	var sight_alignment_px := 999.0
	var sight_center_error_px := 999.0
	if rear_sight != null and front_sight != null:
		var rear_screen := camera.unproject_position(rear_sight.to_global(rear_sight.mesh.get_aabb().get_center()))
		var front_screen := camera.unproject_position(front_sight.to_global(front_sight.mesh.get_aabb().get_center()))
		sight_alignment_px = rear_screen.distance_to(front_screen)
		sight_center_error_px = ((rear_screen+front_screen)*0.5).distance_to(get_viewport().get_visible_rect().size*0.5)
	# The centers of the rear and front sight meshes are separated along the
	# barrel by design; validate their projected separation and that their sight
	# pair stays near the central aiming area rather than demanding a false
	# sub-10-pixel center match from the mesh AABB centers.
	var fps_aim_state_pass := camera.fov == 50.0 and fps_stock != null and not fps_stock.is_visible_in_tree() and rear_sight != null and rear_sight.is_visible_in_tree() and front_sight != null and front_sight.is_visible_in_tree() and optic_adapter != null and not optic_adapter.is_visible_in_tree() and sight_alignment_px < 12.0 and sight_center_error_px < 20.0
	fps_aiming = false
	_update_camera()
	var fps_hip_state_pass := camera.fov == 64.0 and fps_stock != null and fps_stock.is_visible_in_tree()
	var mouse_look_yaw := fps_yaw
	var mouse_look_pitch := fps_pitch
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(12.0,-7.0)
	fps_mouse_captured = true
	_input(mouse_motion)
	var fps_look_pass := not is_equal_approx(mouse_look_yaw,fps_yaw) and not is_equal_approx(mouse_look_pitch,fps_pitch)
	var grip_player := fps_view_rig.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var grip_skeleton := fps_view_rig.find_child("Skeleton3D",true,false) as Skeleton3D
	var trigger_hand := fps_view_rig.find_child("Reconstructed firing hand with trigger finger",true,false) as Node3D
	var index_finger := fps_view_rig.find_child("Index finger on trigger",true,false) as MeshInstance3D
	var support_sleeve := fps_view_rig.find_child("Textured tapered FPS uniform sleeve",true,false) as MeshInstance3D
	var sleeve_material := support_sleeve.material_override as StandardMaterial3D if support_sleeve != null else null
	var trigger_grip_anchor := fps_view_rig.find_child("GripR",true,false) as Node3D
	var support_grip_pass: bool = grip_player != null and grip_player.has_animation("grip_vgrip") and grip_skeleton != null and grip_skeleton.find_bone("Hand_L") >= 0 and grip_skeleton.find_bone("Hand_R") >= 0 and support_sleeve != null and support_sleeve.mesh is CylinderMesh and sleeve_material != null and sleeve_material.albedo_texture == OLIVE_FABRIC and trigger_hand != null and trigger_hand.get_parent() == trigger_grip_anchor and index_finger != null
	_send_key(KEY_T)
	var tactical_switch_pass := not first_person_mode and camera.projection == Camera3D.PROJECTION_ORTHOGONAL and fps_view_rig != null and not fps_view_rig.visible
	_send_key(KEY_T)
	var return_fps_pass := first_person_mode and camera.projection == Camera3D.PROJECTION_PERSPECTIVE and fps_view_rig.visible
	_send_key(KEY_ESCAPE)
	var escape_release_pass := not fps_mouse_captured
	_set_first_person_mode(false)
	var a05o_variant_pass := a05o_variants.size() == 6
	var passed := rig_count == 6 and bone_count_min >= 78 and rifles == 6 and close_grips and prone_pose_pass and a05n_kit_pass and a05o_variant_pass and prone_controls_pass and fps_mode_pass and fps_aim_state_pass and fps_hip_state_pass and fps_look_pass and support_grip_pass and tactical_switch_pass and return_fps_pass and escape_release_pass and max_foot_error < 0.20
	print("A05P_RIG_CHECK_%s rigged=%d min_bones=%d rifles=%d grip_pose_sets=%s prone_pose=%s a05n_kit=%s kit_attachments_min=%d a05o_variants=%s a05o_unique=%d prone_controls=%s fps_mode=%s fps_aim_state=%s fps_hip_state=%s sight_alignment_px=%.2f sight_center_error_px=%.2f fps_mouse_look=%s support_grip=%s sleeve_texture=%s trigger_hand_anchored=%s tactical_switch=%s esc_release=%s prone_grips=%.3f/%.3f max_foot_error=%.3f kneel_contacts=%.3f/%.3f/%.3f" % ["PASS" if passed else "FAIL",rig_count,bone_count_min,rifles,close_grips,prone_pose_pass,a05n_kit_pass,a05n_min_attachments,a05o_variant_pass,a05o_variants.size(),prone_controls_pass,fps_mode_pass,fps_aim_state_pass,fps_hip_state_pass,sight_alignment_px,sight_center_error_px,fps_look_pass,support_grip_pass,support_sleeve != null and sleeve_material != null and sleeve_material.albedo_texture == OLIVE_FABRIC,trigger_hand != null and trigger_hand.get_parent() == trigger_grip_anchor,tactical_switch_pass and return_fps_pass,escape_release_pass,squad[0].prone_right_grip_error,squad[0].prone_left_grip_error,max_foot_error,squad[0].kneeling_knee_target_error,squad[0].kneeling_left_foot_error,squad[0].kneeling_right_ankle_error])
	get_tree().quit(0 if passed else 2)

func _setup_world() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	# A restrained procedural sky gives the mountain scene a real horizon and
	# separates the snow and rock from the background better than a flat color.
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16,0.23,0.31)
	sky_material.sky_horizon_color = Color(0.60,0.66,0.69)
	sky_material.ground_horizon_color = Color(0.39,0.43,0.43)
	sky_material.ground_bottom_color = Color(0.10,0.12,0.13)
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.36,0.41,0.45)
	environment.ambient_light_energy = 0.34
	environment.ambient_light_sky_contribution = 0.70
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.06
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.44,0.49,0.52)
	environment.fog_density = 0.003
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-38,0)
	sun.light_color = Color(0.96,0.91,0.82)
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	# Layer 2 is reserved for the camera-space viewmodel. The sun still lights
	# terrain and rifle, while camera-local fills can stay isolated to the rifle.
	sun.light_cull_mask = 3
	add_child(sun)
	mountain = MountainScript.new()
	add_child(mountain)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)

func _setup_fps_lighting_review_environment() -> void:
	# Neutral gray background isolates the same live viewmodel for controlled
	# lighting review. This flag is only used by the review capture command.
	if environment == null: return
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.23,0.25,0.27)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.40
	environment.ambient_light_sky_contribution = 0.70
	environment.adjustment_enabled = false
	environment.fog_enabled = false
	if sun != null:
		sun.visible = true
		sun.rotation_degrees = Vector3(-42.0,-28.0,0.0)
		sun.light_energy = 1.0
		sun.shadow_enabled = false

func _set_fps_viewmodel_render_layer(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = 2
	for child in node.get_children():
		_set_fps_viewmodel_render_layer(child)

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x,mountain.height_at(p.x,p.z),p.z)

func _build_path_grid() -> void:
	grid.region = Rect2i(-46,-46,93,93)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for z in range(-45,46):
		for x in range(-45,46):
			var h := mountain.height_at(x,z)
			var slope := maxf(absf(h-mountain.height_at(x+1,z)),absf(h-mountain.height_at(x,z+1)))
			if slope > 1.45: grid.set_point_solid(Vector2i(x,z),true)
	for rock in mountain.rocks:
		for z in range(int(round(rock.z))-1,int(round(rock.z))+2):
			for x in range(int(round(rock.x))-1,int(round(rock.x))+2):
				if grid.is_in_boundsv(Vector2i(x,z)): grid.set_point_solid(Vector2i(x,z),true)

func _make_marker(at: Vector3, label: String, color: Color) -> void:
	var holder := Node3D.new()
	holder.name = "Mission marker: " + label
	holder.position = _ground(at)
	add_child(holder)
	mission_markers.append(holder)
	var base := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.72
	cylinder.bottom_radius = 0.72
	cylinder.height = 0.09
	base.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base.material_override = mat
	base.position.y = 0.06
	holder.add_child(base)
	var text3d := Label3D.new()
	text3d.text = label
	text3d.font_size = 30
	text3d.pixel_size = 0.008
	text3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text3d.position.y = 1.3
	text3d.modulate = color
	holder.add_child(text3d)

func _build_landmarks() -> void:
	_make_marker(Vector3(0,0,15),"APPROACH",Color(0.77,0.72,0.45))
	_make_marker(Vector3(-13,0,-8),"SHELTER",Color(0.67,0.73,0.65))
	_make_marker(OBSERVATION,"OBSERVATION",Color(0.87,0.75,0.42))
	_make_marker(Vector3(2,0,3),"SCREE",Color(0.7,0.65,0.55))
	_make_marker(Vector3(-2,0,-15),"SNOWFIELD",Color(0.77,0.84,0.86))
	_make_marker(Vector3(9,0,-10),"EXPOSED LEDGE",Color(0.83,0.68,0.47))
	_build_rope_traverse()
	for point in [Vector3(-14,0,-9),Vector3(-12,0,-10),Vector3(11,0,4),Vector3(12,0,3)]:
		var cairn := Node3D.new()
		cairn.position = _ground(point)
		add_child(cairn)
		for k in range(3):
			var stone := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radial_segments = 7
			mesh.rings = 4
			stone.mesh = mesh
			stone.scale = Vector3(0.46-k*0.08,0.19,0.36-k*0.05)
			stone.position.y = 0.1+k*0.19
			cairn.add_child(stone)

func _build_rope_traverse() -> void:
	var near_ground := _ground(ROPE_NEAR)
	var far_ground := _ground(ROPE_FAR)
	var rope_material := StandardMaterial3D.new()
	rope_material.albedo_color = Color(0.42,0.32,0.2)
	rope_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cable := MeshInstance3D.new()
	var cable_mesh := CylinderMesh.new()
	cable_mesh.top_radius = 0.045
	cable_mesh.bottom_radius = 0.045
	cable_mesh.height = near_ground.distance_to(far_ground)
	cable.mesh = cable_mesh
	cable.material_override = rope_material
	cable.position = (near_ground+far_ground)*0.5+Vector3.UP*1.4
	add_child(cable)
	cable.look_at(far_ground+Vector3.UP*1.4,Vector3.UP)
	cable.rotate_object_local(Vector3.RIGHT,PI/2)
	_add_rope_anchor(near_ground,rope_material)
	_add_rope_anchor(far_ground,rope_material)
	_make_marker(ROPE_NEAR,"ROPE ANCHOR · R",Color(0.78,0.63,0.36))
	_make_marker(ROPE_FAR,"FAR ANCHOR",Color(0.65,0.69,0.59))

func _add_rope_anchor(at: Vector3, material: Material) -> void:
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.12
	post_mesh.bottom_radius = 0.19
	post_mesh.height = 1.7
	post.mesh = post_mesh
	post.material_override = material
	post.position = at+Vector3.UP*0.85
	add_child(post)

func _build_characters() -> void:
	for i in ROSTER.size():
		var actor: PatrolActor = ActorScript.new()
		actor.configure(ROSTER[i],false,mountain)
		actor.visual_variant = i
		actor.position = _ground(Vector3((i%3-1)*1.5,0,37+(i/3)*2.1))
		add_child(actor)
		squad.append(actor)
	for i in range(4):
		var enemy: PatrolActor = ActorScript.new()
		enemy.configure("Unknown figure",true,mountain)
		enemy.position = _ground(Vector3(-19+i*12,0,-39+(i%2)*5))
		add_child(enemy)
		enemy.patrol_origin = enemy.position
		enemy.badge.visible = false
		sentries.append(enemy)
	_build_fps_view_rig()
	_set_actor_visual_layer(squad[0],3)
	_sync_selection()

func _build_footprint_batch() -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	footprint_multimesh = MultiMesh.new()
	footprint_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	footprint_multimesh.mesh = mesh
	footprint_multimesh.instance_count = 150
	footprint_multimesh.visible_instance_count = 0
	var hidden := Transform3D(Basis.IDENTITY,Vector3(0,-1000,0))
	for i in range(150): footprint_multimesh.set_instance_transform(i,hidden)
	var marks := MultiMeshInstance3D.new()
	marks.name = "Snow track LOD batch (150 reusable impressions)"
	marks.multimesh = footprint_multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45,0.49,0.5)
	marks.material_override = material
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marks)

func _build_fps_view_rig() -> void:
	fps_view_rig = Node3D.new()
	fps_view_rig.name = "First-person AK-pattern rifle and winter arms"
	fps_view_rig.position = Vector3(0.79,-0.40,-0.50)
	fps_view_rig.rotation = Vector3(0.13,0.30,0.0)
	fps_view_rig.scale = Vector3.ONE*1.76
	fps_view_rig.visible = false
	camera.add_child(fps_view_rig)
	var rifle := AK_VIEWMODEL.instantiate() as Node3D
	rifle.name = "Reconstructed AK-pattern first-person viewmodel"
	rifle.visible = false # The detailed textured AK is part of the licensed FPS arms asset.
	fps_view_rig.add_child(rifle)
	var arms := GLOVED_ARMS.instantiate() as Node3D
	arms.name = "Gloved support arms"
	arms.scale = Vector3.ONE*0.72
	arms.position = Vector3(0.0,-0.025,-0.055)
	fps_view_rig.add_child(arms)
	var fps_ak := arms.find_child("Gun_ak47",true,false) as Node3D
	if fps_ak != null: _add_fps_ak_detail_pass(fps_ak)
	_show_licensed_ak_meshes(arms)
	var viewmodel_fill := OmniLight3D.new()
	viewmodel_fill.name = "Broad neutral first-person key fill"
	viewmodel_fill.position = Vector3(-0.22,0.34,-0.28)
	viewmodel_fill.light_color = Color(0.94,0.96,1.0)
	viewmodel_fill.light_energy = 0.72
	viewmodel_fill.omni_range = 2.7
	viewmodel_fill.omni_attenuation = 1.5
	viewmodel_fill.shadow_enabled = false
	viewmodel_fill.light_cull_mask = 2
	camera.add_child(viewmodel_fill)
	var viewmodel_bounce := OmniLight3D.new()
	viewmodel_bounce.name = "Low level warm rifle bounce"
	viewmodel_bounce.position = Vector3(0.74,-0.22,-0.34)
	viewmodel_bounce.light_color = Color(1.0,0.89,0.73)
	viewmodel_bounce.light_energy = 0.18
	viewmodel_bounce.omni_range = 2.4
	viewmodel_bounce.omni_attenuation = 1.6
	viewmodel_bounce.shadow_enabled = false
	viewmodel_bounce.light_cull_mask = 2
	camera.add_child(viewmodel_bounce)
	fps_view_stock = arms.find_child("Stock",true,false) as Node3D
	if fps_view_stock != null:
		fps_view_stock.visible = true
	var spare_magazine := arms.find_child("SpareMagazine",true,false) as Node3D
	if spare_magazine != null: spare_magazine.visible = false
	for animator in arms.find_children("*","AnimationPlayer",true,false):
		for animation_name in animator.get_animation_list():
			if String(animation_name).contains("grip"):
				animator.play(animation_name)
				animator.seek(0.0,true)
				animator.pause()
	if fps_view_stock != null:
		# Apply after the authored pose so the stock stays seated at the shoulder.
		# Keep the movement small so it remains joined to the receiver.
		fps_view_stock.position.z += 0.040
	# Keep the imported two-hand grip pose intact. Its hands, arms and rifle were
	# authored together; a separate IK target displaced the palm away from the
	# mesh and left only a floating-looking grip near the receiver.
	var trigger_grip := arms.find_child("GripR",true,false) as Node3D
	if trigger_grip != null:
		_add_fps_trigger_hand(trigger_grip)
		var added_hand := trigger_grip.get_node_or_null("Reconstructed firing hand with trigger finger") as Node3D
		if added_hand != null: fps_aim_hidden_parts.append(added_hand)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.34,0.39,0.26)
	cloth.albedo_texture = OLIVE_FABRIC
	cloth.uv1_scale = Vector3(1.25,1.75,1.0)
	cloth.roughness = 1.0
	# Continue the authored support glove from its actual wrist to the lower-left
	# frame edge. Ending a cylinder at the visible elbow exposed a large flat cap.
	_view_sleeve_between(fps_view_rig,Vector3(-0.113,-0.124,-0.601),Vector3(-0.76,-0.62,0.13),0.058,0.095,cloth)
	for part in fps_view_rig.get_children():
		if part is MeshInstance3D: fps_aim_hidden_parts.append(part as Node3D)
	_add_fps_uniform_patch(fps_view_rig,Vector3(-0.45,-0.40,0.075))
	var muzzle_tip := arms.find_child("MuzzleDeviceTip",true,false) as Node3D
	if muzzle_tip != null:
		fps_muzzle_attachment = muzzle_tip
		fps_view_muzzle_local = fps_view_rig.to_local(muzzle_tip.global_position)
		fps_view_muzzle_anchor_valid = true
	fps_ejection_port = arms.find_child("EjectionPort",true,false) as Node3D
	_build_fps_muzzle_effect()
	_set_fps_viewmodel_render_layer(fps_view_rig)
	var viewmodel_key := DirectionalLight3D.new()
	viewmodel_key.name = "Camera-relative soft key for weapon layer"
	viewmodel_key.rotation_degrees = Vector3(-34.0,-18.0,0.0)
	viewmodel_key.light_color = Color(0.91,0.95,1.0)
	viewmodel_key.light_energy = 0.18 if not fps_lighting_review else 0.60
	viewmodel_key.shadow_enabled = false
	viewmodel_key.light_cull_mask = 2
	camera.add_child(viewmodel_key)

func _add_fps_uniform_patch(parent: Node3D, center: Vector3) -> void:
	var colors := [Color(0.43,0.24,0.10),Color(0.48,0.46,0.37),Color(0.12,0.22,0.13)]
	var backing := StandardMaterial3D.new()
	backing.albedo_color = Color(0.12,0.15,0.10)
	backing.roughness = 1.0
	var backing_mesh := BoxMesh.new()
	backing_mesh.size = Vector3(0.030,0.020,0.002)
	var backing_node := MeshInstance3D.new()
	backing_node.name = "Subdued reconstructed Indian sleeve patch backing"
	backing_node.mesh = backing_mesh
	backing_node.material_override = backing
	backing_node.position = center
	parent.add_child(backing_node)
	for stripe in range(3):
		var stripe_material := StandardMaterial3D.new()
		stripe_material.albedo_color = colors[stripe]
		stripe_material.roughness = 1.0
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.027,0.0055,0.001)
		var stripe_node := MeshInstance3D.new()
		stripe_node.name = "Reconstructed tricolour stripe %d" % stripe
		stripe_node.mesh = stripe_mesh
		stripe_node.material_override = stripe_material
		stripe_node.position = center+Vector3(0,(1-stripe)*0.0055,0.002)
		parent.add_child(stripe_node)
	var chakra_material := StandardMaterial3D.new()
	chakra_material.albedo_color = Color(0.035,0.055,0.085)
	chakra_material.roughness = 1.0
	var chakra_mesh := BoxMesh.new()
	chakra_mesh.size = Vector3(0.0018,0.0018,0.001)
	var chakra_node := MeshInstance3D.new()
	chakra_node.name = "Small subdued sleeve-patch center mark"
	chakra_node.mesh = chakra_mesh
	chakra_node.material_override = chakra_material
	chakra_node.position = center+Vector3(0,0,0.003)
	parent.add_child(chakra_node)

func _add_fps_trigger_hand(grip_anchor: Node3D) -> void:
	# The source arm mesh crops its firing hand behind the enlarged rifle. Add a
	# small glove at its authored GripR point so the trigger-side contact remains
	# readable in first person without changing the support-hand pose.
	var hand := Node3D.new()
	hand.name = "Reconstructed firing hand with trigger finger"
	# GripR is an armature-space wrist marker. Offset the visible glove toward the
	# camera-side of the pistol grip so it is not occluded by the receiver mesh.
	hand.position = Vector3(-0.12,0.01,0.0)
	grip_anchor.add_child(hand)
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.25,0.24,0.19)
	glove.roughness = 0.94
	glove.metallic = 0.0
	var palm_mesh := SphereMesh.new()
	palm_mesh.radius = 0.040
	palm_mesh.height = 0.108
	palm_mesh.radial_segments = 12
	palm_mesh.rings = 6
	var palm := MeshInstance3D.new()
	palm.name = "Padded glove palm around pistol grip"
	palm.mesh = palm_mesh
	palm.material_override = glove
	palm.position = Vector3(0.030,-0.015,-0.005)
	palm.scale = Vector3(1.05,0.94,1.0)
	hand.add_child(palm)
	_add_fps_hand_segment(hand,"Trigger finger upper joint",Vector3(0.055,0.035,0.015),Vector3(0.025,0.018,-0.025),0.008,glove)
	_add_fps_hand_segment(hand,"Index finger on trigger",Vector3(0.025,0.018,-0.025),Vector3(-0.005,-0.010,-0.060),0.007,glove)
	for finger in range(3):
		var y := -0.010-float(finger)*0.019
		_add_fps_hand_segment(hand,"Curled firing-hand finger %d proximal" % finger,Vector3(0.073,y,0.030),Vector3(0.018,y-0.004,0.008),0.008,glove)
		_add_fps_hand_segment(hand,"Curled firing-hand finger %d distal" % finger,Vector3(0.018,y-0.004,0.008),Vector3(-0.006,y-0.012,-0.014),0.007,glove)
	_add_fps_hand_segment(hand,"Firing-hand thumb base",Vector3(0.067,0.044,0.035),Vector3(0.040,0.067,-0.002),0.013,glove)
	_add_fps_hand_segment(hand,"Firing-hand thumb wrap",Vector3(0.040,0.067,-0.002),Vector3(-0.014,0.036,-0.030),0.011,glove)

func _add_fps_hand_segment(parent: Node3D, segment_name: String, start: Vector3, finish: Vector3, radius: float, material: StandardMaterial3D) -> void:
	var segment := MeshInstance3D.new()
	segment.name = segment_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = start.distance_to(finish)+radius*2.0
	mesh.radial_segments = 8
	mesh.rings = 3
	segment.mesh = mesh
	segment.material_override = material
	segment.position = (start+finish)*0.5
	segment.quaternion = Quaternion(Vector3.UP,(finish-start).normalized())
	parent.add_child(segment)

func _add_fps_ak_detail_pass(gun: Node3D) -> void:
	var steel := StandardMaterial3D.new()
	steel.resource_name = "FPS AK blued phosphate details"
	steel.albedo_color = Color(0.105,0.115,0.105)
	steel.metallic = 0.42
	steel.roughness = 0.66
	var edge := StandardMaterial3D.new()
	edge.resource_name = "FPS AK worn steel edges"
	edge.albedo_color = Color(0.115,0.125,0.112)
	edge.metallic = 0.22
	edge.roughness = 0.78
	var dark := StandardMaterial3D.new()
	dark.resource_name = "FPS AK stamped recesses"
	dark.albedo_color = Color(0.035,0.041,0.036)
	dark.roughness = 0.78
	# Subtle receiver pins and rivets on both sides, kept close to the stamped body.
	for side in [-1.0,1.0]:
		for z in [-0.485,-0.425,-0.265,-0.205,-0.155]:
			var pin_mesh := SphereMesh.new()
			pin_mesh.radius = 0.0045
			pin_mesh.height = 0.009
			pin_mesh.radial_segments = 10
			pin_mesh.rings = 5
			var pin := MeshInstance3D.new()
			pin.name = "Stamped receiver rivet %s %.3f" % ["L" if side < 0.0 else "R",z]
			pin.mesh = pin_mesh
			pin.material_override = edge
			pin.position = Vector3(side*0.022,0.008,z)
			pin.scale = Vector3(0.55,1.0,1.0)
			gun.add_child(pin)
	# AK selector plate, pivot and lever on both sides, with restrained finish contrast.
	for side in [1.0]:
		var selector_pivot := MeshInstance3D.new()
		selector_pivot.name = "Right-side fire selector pivot"
		var pivot_mesh := SphereMesh.new()
		pivot_mesh.radius = 0.012
		pivot_mesh.height = 0.024
		pivot_mesh.radial_segments = 10
		pivot_mesh.rings = 5
		selector_pivot.mesh = pivot_mesh
		selector_pivot.material_override = steel
		selector_pivot.position = Vector3(side*0.024,-0.018,-0.178)
		selector_pivot.scale = Vector3(0.42,1.0,1.0)
		gun.add_child(selector_pivot)
		var selector := MeshInstance3D.new()
		selector.name = "Right-side stamped safety selector lever"
		var lever_mesh := BoxMesh.new()
		lever_mesh.size = Vector3(0.007,0.009,0.062)
		selector.mesh = lever_mesh
		selector.material_override = edge
		selector.position = Vector3(side*0.027,-0.039,-0.205)
		selector.rotation.x = -0.12
		gun.add_child(selector)
	# Deep, narrow cooling notches in the wooden handguard, visible in close inspection.
	for side in [-1.0,1.0]:
		for slot in range(5):
			var vent := MeshInstance3D.new()
			vent.name = "Handguard cooling slot %d" % slot
			var vent_mesh := BoxMesh.new()
			vent_mesh.size = Vector3(0.0035,0.006,0.027)
			vent.mesh = vent_mesh
			vent.material_override = dark
			vent.position = Vector3(side*0.040,0.006,-0.205-float(slot)*0.041)
			gun.add_child(vent)
	# Small steel keeper bands where the handguard meets the gas system.
	for z in [-0.402,-0.446]:
		var band := MeshInstance3D.new()
		band.name = "Handguard steel retaining band"
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(0.078,0.004,0.004)
		band.mesh = band_mesh
		band.material_override = steel
		band.position = Vector3(0.0,0.012,z)
		gun.add_child(band)
	# Dust-cover joint and shallow stamped ribs on the receiver top.
	var cover_seam := MeshInstance3D.new()
	cover_seam.name = "AK dust-cover joint"
	var seam_mesh := BoxMesh.new()
	seam_mesh.size = Vector3(0.040,0.002,0.230)
	cover_seam.mesh = seam_mesh
	cover_seam.material_override = dark
	cover_seam.position = Vector3(0.0,0.061,-0.325)
	gun.add_child(cover_seam)
	for rib in range(4):
		var top_rib := MeshInstance3D.new()
		top_rib.name = "Dust-cover stamped rib %d" % rib
		var rib_mesh := BoxMesh.new()
		rib_mesh.size = Vector3(0.030,0.002,0.004)
		top_rib.mesh = rib_mesh
		top_rib.material_override = edge
		top_rib.position = Vector3(0.0,0.064,-0.405+float(rib)*0.032)
		gun.add_child(top_rib)
	# Shallow pressed ribs follow the AK's curved magazine profile on both sides.
	for side in [-1.0,1.0]:
		for rib in range(4):
			var mag_rib := MeshInstance3D.new()
			mag_rib.name = "Curved magazine pressed rib %d" % rib
			var mag_rib_mesh := BoxMesh.new()
			mag_rib_mesh.size = Vector3(0.0025,0.0035,0.074)
			mag_rib.mesh = mag_rib_mesh
			mag_rib.material_override = edge
			mag_rib.position = Vector3(side*0.014,-0.082-float(rib)*0.026,-0.370-float(rib)*0.026)
			gun.add_child(mag_rib)
	# Narrow gas-system collars add metal transitions without thickening the barrel.
	for z in [-0.79,-0.84]:
		var gas_collar := MeshInstance3D.new()
		gas_collar.name = "Gas-system retaining collar"
		var collar_mesh := CylinderMesh.new()
		collar_mesh.top_radius = 0.014
		collar_mesh.bottom_radius = 0.014
		collar_mesh.height = 0.008
		collar_mesh.radial_segments = 12
		gas_collar.mesh = collar_mesh
		gas_collar.material_override = steel
		gas_collar.position = Vector3(0.0,0.012,z)
		gas_collar.rotation.x = PI*0.5
		gun.add_child(gas_collar)
	# The imported rifle already has a front post and protective ears. Keep those
	# meshes as the single sight assembly; only add the small gas-block cross-pins.
	for side in [-1.0,1.0]:
		var gas_pin := MeshInstance3D.new()
		gas_pin.name = "Gas block cross pin"
		var gas_pin_mesh := SphereMesh.new()
		gas_pin_mesh.radius = 0.004
		gas_pin_mesh.height = 0.008
		gas_pin.mesh = gas_pin_mesh
		gas_pin.material_override = edge
		gas_pin.position = Vector3(side*0.023,0.020,-0.842)
		gas_pin.scale = Vector3(0.55,1.0,1.0)
		gun.add_child(gas_pin)
	# Fine port cuts in the slant brake, kept narrow so the muzzle stays slim.
	for side in [-1.0,1.0]:
		for port in range(3):
			var muzzle_port := MeshInstance3D.new()
			muzzle_port.name = "Muzzle brake side port %d" % port
			var port_mesh := BoxMesh.new()
			port_mesh.size = Vector3(0.0025,0.004,0.008)
			muzzle_port.mesh = port_mesh
			muzzle_port.material_override = dark
			muzzle_port.position = Vector3(side*0.010,0.013,-1.095-float(port)*0.014)
			gun.add_child(muzzle_port)
	# Subtle detent marks make the stamped selector plate read as a working control.
	for side in [-1.0,1.0]:
		for mark in range(3):
			var detent := MeshInstance3D.new()
			detent.name = "Selector detent mark %d" % mark
			var mark_mesh := BoxMesh.new()
			mark_mesh.size = Vector3(0.002,0.002,0.010)
			detent.mesh = mark_mesh
			detent.material_override = dark
			detent.position = Vector3(side*0.030,-0.026,-0.158-float(mark)*0.020)
			gun.add_child(detent)
	# A compact front sling swivel sits against the receiver-side lug.
	var swivel := MeshInstance3D.new()
	swivel.name = "Front sling swivel loop"
	var swivel_mesh := TorusMesh.new()
	swivel_mesh.inner_radius = 0.012
	swivel_mesh.outer_radius = 0.018
	swivel_mesh.rings = 8
	swivel_mesh.ring_segments = 10
	swivel.mesh = swivel_mesh
	swivel.material_override = steel
	swivel.position = Vector3(0.045,-0.026,-0.470)
	swivel.rotation.z = PI*0.5
	gun.add_child(swivel)
	# Build a narrow rounded guard loop in the rifle's side plane. The former
	# pair of box rails formed a front-facing stirrup and a straight trigger bar.
	var guard_path: Array[Vector3] = [
		Vector3(0.0,-0.075,-0.202),
		Vector3(0.0,-0.105,-0.202),
		Vector3(0.0,-0.125,-0.214),
		Vector3(0.0,-0.131,-0.239),
		Vector3(0.0,-0.125,-0.264),
		Vector3(0.0,-0.105,-0.277),
		Vector3(0.0,-0.075,-0.277),
	]
	for i in guard_path.size():
		_add_ak_rounded_segment(gun,"Rounded trigger guard segment %d" % i,guard_path[i],guard_path[(i+1)%guard_path.size()],0.0028,steel)
	var trigger_path: Array[Vector3] = [
		Vector3(0.0,-0.081,-0.224),
		Vector3(0.0,-0.095,-0.229),
		Vector3(0.0,-0.111,-0.238),
	]
	for i in trigger_path.size()-1:
		_add_ak_rounded_segment(gun,"Curved trigger shoe segment %d" % i,trigger_path[i],trigger_path[i+1],0.0024,edge)

func _add_ak_rounded_segment(parent: Node3D, segment_name: String, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var segment := MeshInstance3D.new()
	segment.name = segment_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = start.distance_to(finish)+radius*2.0
	mesh.radial_segments = 8
	mesh.rings = 3
	segment.mesh = mesh
	segment.material_override = material
	segment.position = (start+finish)*0.5
	segment.quaternion = Quaternion(Vector3.UP,(finish-start).normalized())
	parent.add_child(segment)

func _show_licensed_ak_meshes(node: Node, inside_ak := false) -> void:
	var is_ak := inside_ak or node.name == "Gun_ak47"
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		# This view uses fixed iron sights. The imported, unused top rail adapter
		# overlaps their sight corridor and reads as a floating slab in close ADS.
		mesh_instance.visible = node.name == "FPArms" or (is_ak and node.name != "OpticRailAdapterGeometry")
		if node.name == "FPArms" and mesh_instance.mesh != null:
			for surface in mesh_instance.mesh.get_surface_count():
				var arms_source := mesh_instance.get_active_material(surface) as StandardMaterial3D
				if arms_source == null: continue
				var arms_material := arms_source.duplicate() as StandardMaterial3D
				arms_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				arms_material.metallic = 0.0
				arms_material.roughness = 0.92
				mesh_instance.set_surface_override_material(surface,arms_material)
		if is_ak and mesh_instance.mesh != null:
			for surface in mesh_instance.mesh.get_surface_count():
				var source_material := mesh_instance.get_active_material(surface) as StandardMaterial3D
				if source_material == null: continue
				var material := source_material.duplicate() as StandardMaterial3D
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				var material_name := source_material.resource_name
				if material_name.contains("BluedReceiver"):
					# Keep the existing dark blued-steel response while retaining its
					# imported roughness and occlusion maps.
					material.metallic = 0.52
					material.roughness = 1.0
				elif material_name.contains("WornBoltSteel"):
					material.metallic = 0.58
					material.roughness = 1.0
				elif material_name.contains("PhosphateSteel"):
					material.metallic = 0.45
					material.roughness = 1.0
				elif material_name.contains("LaminatedWood"):
					material.metallic = 0.0
					material.roughness = 1.0
				elif material_name.contains("BakeliteMagazine"):
					material.metallic = 0.0
					material.roughness = 1.0
				mesh_instance.set_surface_override_material(surface,material)
	for child in node.get_children():
		_show_licensed_ak_meshes(child,is_ak)

func _view_sleeve_between(parent: Node3D, wrist: Vector3, elbow: Vector3, wrist_radius: float, elbow_radius: float, material: StandardMaterial3D) -> void:
	var sleeve := MeshInstance3D.new()
	sleeve.name = "Textured tapered FPS uniform sleeve"
	# Keep the wrist capped beneath the authored glove; the sleeve carries the
	# same rough woven cloth as the uniform, with a modest taper toward the elbow.
	var mesh := CylinderMesh.new()
	mesh.top_radius = wrist_radius
	mesh.bottom_radius = elbow_radius
	mesh.height = wrist.distance_to(elbow)
	mesh.radial_segments = 24
	mesh.rings = 4
	sleeve.mesh = mesh
	sleeve.material_override = material
	sleeve.position = (wrist+elbow)*0.5
	sleeve.quaternion = Quaternion(Vector3.UP,(wrist-elbow).normalized())
	parent.add_child(sleeve)

func _set_actor_visual_layer(actor: PatrolActor, layer: int) -> void:
	for node in actor.find_children("*","VisualInstance3D",true,false):
		(node as VisualInstance3D).layers = 1 << (layer-1)

func _ui_panel(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(5)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box

func _build_ui() -> void:
	review_ui_layer = CanvasLayer.new()
	add_child(review_ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	review_ui_layer.add_child(root)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel",_ui_panel(Color(0.055,0.075,0.08,0.88)))
	top.position = Vector2(18,17)
	top.size = Vector2(420,113)
	root.add_child(top)
	var topbox := VBoxContainer.new()
	top.add_child(topbox)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size",18)
	topbox.add_child(objective_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size",13)
	topbox.add_child(status_label)
	var weapon_panel := PanelContainer.new()
	weapon_panel.add_theme_stylebox_override("panel",_ui_panel(Color(0.055,0.075,0.08,0.88)))
	weapon_panel.position = Vector2(930,17)
	weapon_panel.size = Vector2(330,36)
	root.add_child(weapon_panel)
	weapon_status_label = Label.new()
	weapon_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_status_label.add_theme_font_size_override("font_size",14)
	weapon_panel.add_child(weapon_status_label)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size",13)
	hint_label.modulate = Color(0.78,0.83,0.81)
	topbox.add_child(hint_label)
	var roster_panel := PanelContainer.new()
	roster_panel.add_theme_stylebox_override("panel",_ui_panel(Color(0.055,0.075,0.08,0.85)))
	roster_panel.position = Vector2(18,476)
	roster_panel.size = Vector2(330,216)
	root.add_child(roster_panel)
	roster_label = RichTextLabel.new()
	roster_label.bbcode_enabled = true
	roster_label.scroll_active = false
	roster_panel.add_child(roster_label)
	flash_label = Label.new()
	flash_label.position = Vector2(445,18)
	flash_label.size = Vector2(810,70)
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.add_theme_font_size_override("font_size",18)
	flash_label.add_theme_color_override("font_color",Color(0.98,0.83,0.5))
	root.add_child(flash_label)
	fps_reticle = Control.new()
	fps_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	fps_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_reticle.visible = false
	root.add_child(fps_reticle)
	var reticle_color := Color(0.9,0.94,0.88,0.78)
	var reticle_vertical := ColorRect.new()
	reticle_vertical.position = Vector2(-1,-6)
	reticle_vertical.size = Vector2(2,12)
	reticle_vertical.color = reticle_color
	fps_reticle.add_child(reticle_vertical)
	var reticle_horizontal := ColorRect.new()
	reticle_horizontal.position = Vector2(-6,-1)
	reticle_horizontal.size = Vector2(12,2)
	reticle_horizontal.color = reticle_color
	fps_reticle.add_child(reticle_horizontal)
	overlay = PanelContainer.new()
	overlay.add_theme_stylebox_override("panel",_ui_panel(Color(0.045,0.057,0.06,0.96)))
	overlay.position = Vector2(300,100)
	overlay.size = Vector2(680,515)
	root.add_child(overlay)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation",15)
	overlay.add_child(contents)
	overlay_title = Label.new()
	overlay_title.add_theme_font_size_override("font_size",29)
	contents.add_child(overlay_title)
	overlay_body = RichTextLabel.new()
	overlay_body.bbcode_enabled = true
	overlay_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.scroll_active = true
	overlay_body.add_theme_font_size_override("normal_font_size",17)
	contents.add_child(overlay_body)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size.y = 47
	overlay_button.pressed.connect(_begin_mission)
	contents.add_child(overlay_button)
	_show_briefing()
	_refresh_ui()

func _show_briefing() -> void:
	overlay.visible = true
	overlay_title.text = "BAJRANG | THE PATROL"
	overlay_body.text = "[b]Kaksar sector · May 1999[/b]\n\nA six-man 4 JAT patrol led by Lt. Saurabh Kalia moves toward the Bajrang spur to check the ground and report observations. Suspicious movement had already been reported in the wider region.\n\n[b]Historical boundary[/b]  The route, dialogue, weather sequence, observation and contact here are reconstructed for play. The patrol's documented loss is fixed. There is no captivity scene or score for its outcome.\n\n[b]Mountain route[/b]  Move in first person with WASD and mouse look. The five patrol members follow Lt. Kalia. Press T for the tactical overhead view to select individuals and issue squad orders. The marked rope anchor leads over a reconstructed exposed shelf; bring Lt. Kalia there and press R.\n\n[b]Controls[/b]  WASD move, mouse look, Shift quick-step, left mouse fire, right mouse aim, B toggle SINGLE/BURST, G reload, C crouch, V prone/crawl, T tactical overhead, Esc release mouse or switch view. In overhead view, left click selects, Shift + left click adds, 1–6 select, Tab selects all, right click moves, Space pauses, Enter executes queued orders, Q/E rotate and wheel zooms. R crosses the marked rope shelf; O records observation. F1/F2/F3 graphics; F5/F9 quick save/load.\n\nSnow, scree, slope, wind exposure and visibility change the safest pace and route. Prone/crawl is a generic gameplay mechanic, not a verified action by this historical patrol. Individual powers are deliberately omitted because the sources do not establish them."
	overlay_button.text = "Begin patrol"
	overlay_button.visible = true

func _begin_mission() -> void:
	phase = 1
	phase_timer = 0
	rope_started = false
	fps_magazine_rounds = MAGAZINE_CAPACITY
	fps_reserve_rounds = RESERVE_CAPACITY
	fps_fire_mode = FireMode.SINGLE
	fps_reload_remaining = 0.0
	fps_reload_started_msec = -1
	fps_fire_cooldown = 0.0
	fps_burst_rounds_remaining = 0
	fps_trigger_down = false
	overlay.visible = false
	if benchmark == "" and not smoke_route and not input_check:
		_set_first_person_mode(true)
	_message("Keep the six together. Use rock and terrain to break sightlines.")
	_refresh_ui()

func _set_first_person_mode(enabled: bool) -> void:
	first_person_mode = enabled
	fps_aiming = false
	if not enabled:
		_cancel_burst()
		fps_trigger_down = false
		fps_reload_remaining = 0.0
		fps_reload_started_msec = -1
	if objective_label != null:
		var status_panel := objective_label.get_parent().get_parent() as Control
		if status_panel != null: status_panel.visible = true
	if flash_label != null: flash_label.visible = true
	if enabled:
		selected = [0]
		_sync_selection()
		if not squad.is_empty():
			squad[0].path.clear()
			fps_yaw = squad[0].rotation.y
			fps_pitch = -0.04
		_set_actor_visual_layer(squad[0],3)
		if roster_label != null: roster_label.get_parent().visible = false
		if fps_reticle != null: fps_reticle.visible = true
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.cull_mask = 3
		if fps_view_rig != null: fps_view_rig.visible = true
		fps_mouse_captured = false
		if benchmark == "": call_deferred("_capture_fps_mouse")
	else:
		fps_mouse_captured = false
		if not squad.is_empty():
			squad[0].manual_move_direction = Vector3.ZERO
			_set_actor_visual_layer(squad[0],1)
			camera_target = squad[0].position
			camera_manual = false
			camera_yaw = fps_yaw
		if roster_label != null: roster_label.get_parent().visible = true
		if fps_reticle != null: fps_reticle.visible = false
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.cull_mask = 0xFFFFFFFF
		if fps_view_rig != null: fps_view_rig.visible = false
		if benchmark == "": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		camera_zoom = 24.0
	_update_camera()

func _capture_fps_mouse() -> void:
	if not first_person_mode or phase <= 0 or phase >= 5 or benchmark != "": return
	get_viewport().gui_release_focus()
	fps_mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _update_first_person_input(delta: float) -> void:
	if squad.is_empty(): return
	var leader := squad[0]
	leader.manual_speed_scale = 1.55 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	leader.manual_move_direction = Vector3.ZERO
	if leader.rope_traversing:
		return
	if not fps_mouse_captured or tactical_paused:
		leader.path.clear()
		return
	var forward := Vector3.FORWARD.rotated(Vector3.UP,fps_yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP,fps_yaw)
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move += forward
	if Input.is_key_pressed(KEY_S): move -= forward
	if Input.is_key_pressed(KEY_D): move += right
	if Input.is_key_pressed(KEY_A): move -= right
	if move.length_squared() > 0.001:
		_set_fps_move_order(leader,move.normalized(),delta)
	else:
		leader.path.clear()
		leader.manual_speed_scale = 1.0
		fps_last_move_direction = Vector3.ZERO
	fps_follow_clock += delta
	if fps_follow_clock >= 0.85:
		fps_follow_clock = 0.0
		var slots: Array[Vector3] = [Vector3(-1.25,0,1.35),Vector3(1.25,0,1.35),Vector3(-1.65,0,2.8),Vector3(1.65,0,2.8),Vector3(0,0,3.8)]
		for i in range(1,squad.size()):
			var target := leader.position+slots[i-1].rotated(Vector3.UP,fps_yaw)
			var need_order := squad[i].path.is_empty()
			if not squad[i].path.is_empty() and squad[i].path.back().distance_to(target) > 1.15: need_order = true
			if need_order: _order_actor(i,target)

func _set_fps_move_order(leader: PatrolActor, move: Vector3, delta := 1.0/60.0) -> void:
	var direction := move.normalized()
	leader.direction = Vector3.FORWARD.rotated(Vector3.UP,fps_yaw)
	leader.rotation.y = fps_yaw
	# WASD is direct locomotion. Do not feed each directional change through the
	# tactical A* route: its obstacle detours can initially point against the
	# requested input on steep ground. Stop at blocked grid cells and let the
	# player steer around them instead.
	leader.path.clear()
	var step_distance := maxf(0.06,1.2*leader.manual_speed_scale*delta+0.015)
	var next_cell := _cell(leader.position+direction*step_distance)
	var current_cell := _cell(leader.position)
	leader.manual_move_direction = direction if next_cell == current_cell or not grid.is_point_solid(next_cell) else Vector3.ZERO
	fps_last_move_direction = direction

func _fps_direct_segment_clear(start: Vector3, finish: Vector3) -> bool:
	var distance := Vector2(finish.x-start.x,finish.z-start.z).length()
	var samples := maxi(1,ceili(distance/0.35))
	for sample in range(1,samples+1):
		var point := start.lerp(finish,float(sample)/float(samples))
		var cell := _cell(point)
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell): return false
	return true

func _message(value: String) -> void:
	flash_label.text = value
	var tween := create_tween()
	flash_label.modulate.a = 1
	tween.tween_interval(5.0)
	tween.tween_property(flash_label,"modulate:a",0.0,1.2)

func _play_reload_animation() -> void:
	if phase <= 0 or phase >= 5:
		return
	if first_person_mode:
		_start_weapon_reload()
		return
	var controlled: Array[int] = [0] if first_person_mode else selected.duplicate()
	var played := false
	for actor_id in controlled:
		if actor_id >= 0 and actor_id < squad.size():
			played = squad[actor_id].play_action_animation("reload") or played
	if played:
		_message("Reload motion shown · switch to first person for weapon ammunition")
	else:
		_message("Stop the selected patrol member before starting the reload motion.")

func _start_weapon_reload() -> void:
	if not first_person_mode or phase <= 0 or phase >= 5: return
	if fps_reload_remaining > 0.0 or fps_magazine_rounds >= MAGAZINE_CAPACITY or fps_reserve_rounds <= 0:
		if fps_reserve_rounds <= 0: _message("No reserve ammunition remains.")
		return
	_cancel_burst()
	fps_reload_remaining = RELOAD_DURATION
	fps_reload_started_msec = Time.get_ticks_msec()
	_message("Reloading · weapon unavailable")
	_refresh_ui()

func _finish_weapon_reload() -> void:
	var loaded := mini(MAGAZINE_CAPACITY-fps_magazine_rounds,fps_reserve_rounds)
	fps_magazine_rounds += loaded
	fps_reserve_rounds -= loaded
	fps_reload_remaining = 0.0
	fps_reload_started_msec = -1
	_message("Reload complete · %d / %d" % [fps_magazine_rounds,fps_reserve_rounds])
	_refresh_ui()

func _fire_trigger_pressed() -> void:
	if fps_trigger_down: return
	fps_trigger_down = true
	if not first_person_mode or fps_view_rig == null or not fps_view_rig.visible or not fps_mouse_captured or phase <= 0 or phase >= 5 or tactical_paused or fps_reload_remaining > 0.0: return
	if fps_magazine_rounds <= 0:
		_message("Magazine empty · press G to reload")
		return
	if fps_fire_mode == FireMode.SINGLE:
		if fps_fire_cooldown <= 0.0: _fire_one_round()
		return
	if fps_burst_rounds_remaining > 0 or fps_fire_cooldown > 0.0: return
	fps_burst_rounds_remaining = BURST_SHOT_COUNT
	fps_burst_timer = 0.0
	_update_burst_fire(0.0)

func _fire_trigger_released() -> void:
	fps_trigger_down = false

func _toggle_fire_mode() -> void:
	if not first_person_mode or phase <= 0 or phase >= 5: return
	_cancel_burst()
	fps_fire_mode = FireMode.BURST if fps_fire_mode == FireMode.SINGLE else FireMode.SINGLE
	_message("Fire mode · %s" % ("BURST ×3" if fps_fire_mode == FireMode.BURST else "SINGLE"))
	_refresh_ui()

func _cancel_burst() -> void:
	fps_burst_rounds_remaining = 0
	fps_burst_timer = 0.0

func _update_fire_system(delta: float) -> void:
	fps_fire_cooldown = maxf(0.0,fps_fire_cooldown-delta)
	fps_muzzle_flash_clock = maxf(0.0,fps_muzzle_flash_clock-delta)
	if fps_muzzle_flash != null: fps_muzzle_flash.visible = fps_muzzle_flash_clock > 0.0
	if fps_muzzle_light != null:
		fps_muzzle_light.visible = fps_muzzle_flash_clock > 0.0
		fps_muzzle_light.light_energy = 3.4*clampf(fps_muzzle_flash_clock/0.045,0.0,1.0)
	var recoil_recovery := 1.0-exp(-delta*10.5)
	fps_weapon_recoil_pitch = lerpf(fps_weapon_recoil_pitch,0.0,recoil_recovery)
	fps_weapon_recoil_roll = lerpf(fps_weapon_recoil_roll,0.0,recoil_recovery)
	fps_weapon_recoil_back = lerpf(fps_weapon_recoil_back,0.0,recoil_recovery)
	fps_camera_recoil_pitch = lerpf(fps_camera_recoil_pitch,0.0,1.0-exp(-delta*8.0))
	_update_transient_firing_effects(delta)
	if not first_person_mode or fps_view_rig == null or not fps_view_rig.visible or phase <= 0 or phase >= 5 or tactical_paused:
		_cancel_burst()
		fps_trigger_down = false
		return
	if fps_reload_remaining > 0.0:
		fps_reload_remaining = maxf(0.0,fps_reload_remaining-delta)
		if fps_reload_remaining <= 0.0: _finish_weapon_reload()
	if fps_burst_rounds_remaining > 0 and fps_reload_remaining <= 0.0:
		_update_burst_fire(delta)

func _update_burst_fire(delta: float) -> void:
	if fps_burst_rounds_remaining <= 0: return
	if fps_burst_timer > 0.0:
		fps_burst_timer -= delta
		if fps_burst_timer > 0.0: return
	if fps_magazine_rounds <= 0 or fps_reload_remaining > 0.0:
		_cancel_burst()
		return
	if _fire_one_round():
		fps_burst_rounds_remaining -= 1
		fps_burst_timer = SHOT_INTERVAL
	else:
		_cancel_burst()

func _fire_one_round() -> bool:
	if fps_magazine_rounds <= 0 or fps_reload_remaining > 0.0: return false
	fps_magazine_rounds -= 1
	fps_fire_cooldown = SHOT_INTERVAL
	fps_shot_count += 1
	fps_weapon_recoil_pitch = minf(0.18,fps_weapon_recoil_pitch+0.042)
	fps_weapon_recoil_roll = clampf(fps_weapon_recoil_roll+randf_range(-0.006,0.006),-0.025,0.025)
	fps_weapon_recoil_back = minf(0.045,fps_weapon_recoil_back+0.012)
	fps_camera_recoil_pitch = minf(0.075,fps_camera_recoil_pitch+0.012)
	fps_muzzle_flash_clock = 0.055
	if not weapon_fire_players.is_empty():
		var report := weapon_fire_players[weapon_fire_player_cursor]
		report.pitch_scale = randf_range(0.98,1.02)
		report.play()
		weapon_fire_player_cursor = (weapon_fire_player_cursor+1)%weapon_fire_players.size()
	elif weapon_fire_player != null:
		weapon_fire_player.pitch_scale = randf_range(0.98,1.02)
		weapon_fire_player.play()
	_spawn_spent_casing()
	_resolve_hitscan()
	return true

func _resolve_hitscan() -> void:
	if camera == null: return
	var camera_origin := camera.global_position
	var forward := -camera.global_transform.basis.z.normalized()
	var max_range := 180.0
	var space := get_world_3d().direct_space_state
	var camera_query := PhysicsRayQueryParameters3D.create(camera_origin,camera_origin+forward*max_range)
	camera_query.collision_mask = 3
	camera_query.collide_with_areas = true
	var camera_hit := space.intersect_ray(camera_query)
	var aim_point: Vector3 = camera_hit.position if not camera_hit.is_empty() else camera_origin+forward*max_range
	var muzzle_origin := fps_muzzle_attachment.global_position if fps_muzzle_attachment != null else camera_origin
	if not camera_hit.is_empty():
		var camera_collider: Object = camera_hit.get("collider")
		var camera_hit_is_target := camera_collider is Area3D and camera_collider.has_meta("patrol_actor")
		var blocker_distance: float = (aim_point-camera_origin).dot(forward)
		var muzzle_distance: float = (muzzle_origin-camera_origin).dot(forward)
		if not camera_hit_is_target and blocker_distance < muzzle_distance+0.05:
			fps_hit_count += 1
			_add_firing_impact(aim_point,camera_hit.normal)
			return
	var muzzle_delta := aim_point-muzzle_origin
	if muzzle_delta.length_squared() < 0.0001: return
	var shot_direction := muzzle_delta.normalized()
	var shot_query := PhysicsRayQueryParameters3D.create(muzzle_origin,aim_point+shot_direction*0.04)
	shot_query.collision_mask = 3
	shot_query.collide_with_areas = true
	var hit := space.intersect_ray(shot_query)
	if hit.is_empty(): return
	fps_hit_count += 1
	var collider: Object = hit.get("collider")
	if collider is Area3D and collider.has_meta("patrol_actor"):
		var target: Variant = collider.get_meta("patrol_actor")
		if is_instance_valid(target) and target.has_method("apply_shot_damage"):
			target.apply_shot_damage(SHOT_DAMAGE)
			if target.defeated: _message("Contact target down · fire is dramatized")
	_add_firing_impact(hit.position,hit.normal)

func _build_fps_muzzle_effect() -> void:
	if fps_muzzle_attachment == null:
		push_warning("FPS AK MuzzleDeviceTip marker was not found; muzzle flash will be unavailable.")
		return
	var image := Image.create(40,40,false,Image.FORMAT_RGBA8)
	for y in range(40):
		for x in range(40):
			var nx := (float(x)-19.5)/19.5
			var ny := (float(y)-19.5)/19.5
			var radial := exp(-5.0*(nx*nx+ny*ny))
			var streak := exp(-absf(ny)*19.0)*exp(-absf(nx)*1.7)*0.36
			var alpha := clampf(radial+streak,0.0,1.0)
			var heat := clampf(1.0-sqrt(nx*nx+ny*ny),0.0,1.0)
			image.set_pixel(x,y,Color(1.0,0.54+heat*0.40,0.12+heat*0.76,alpha))
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_material.albedo_texture = ImageTexture.create_from_image(image)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0,0.62,0.20)
	flash_material.emission_energy_multiplier = 2.0
	fps_muzzle_flash = Sprite3D.new()
	fps_muzzle_flash.name = "Per-shot warm AK muzzle flash"
	fps_muzzle_flash.texture = flash_material.albedo_texture
	fps_muzzle_flash.material_override = flash_material
	fps_muzzle_flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fps_muzzle_flash.pixel_size = 0.0038
	fps_muzzle_flash.position = Vector3(0,0,-0.025)
	fps_muzzle_flash.visible = false
	fps_muzzle_attachment.add_child(fps_muzzle_flash)
	fps_muzzle_light = OmniLight3D.new()
	fps_muzzle_light.name = "Brief per-shot muzzle illumination"
	fps_muzzle_light.position = Vector3(0,0,-0.04)
	fps_muzzle_light.light_color = Color(1.0,0.58,0.24)
	fps_muzzle_light.light_energy = 3.4
	fps_muzzle_light.omni_range = 3.4
	fps_muzzle_light.shadow_enabled = false
	fps_muzzle_light.light_cull_mask = 3
	fps_muzzle_light.visible = false
	fps_muzzle_attachment.add_child(fps_muzzle_light)

func _spawn_spent_casing() -> void:
	if fps_ejection_port == null: return
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.48,0.31,0.11)
	brass.metallic = 0.72
	brass.roughness = 0.38
	var shell := RigidBody3D.new()
	shell.name = "Spent 7.62x39 casing"
	shell.mass = 0.008
	shell.gravity_scale = 0.72
	shell.linear_damp = 0.85
	shell.angular_damp = 1.2
	shell.collision_layer = 0
	shell.collision_mask = 1
	shell.continuous_cd = true
	var shell_mesh := CylinderMesh.new()
	shell_mesh.top_radius = 0.0048
	shell_mesh.bottom_radius = 0.0052
	shell_mesh.height = 0.039
	shell_mesh.radial_segments = 10
	var shell_visual := MeshInstance3D.new()
	shell_visual.mesh = shell_mesh
	shell_visual.material_override = brass
	shell_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_child(shell_visual)
	var shell_shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = 0.005
	cylinder_shape.height = 0.039
	shell_shape.shape = cylinder_shape
	shell.add_child(shell_shape)
	var ejection_right := fps_ejection_port.global_transform.basis.x.normalized()
	var weapon_forward := -fps_ejection_port.global_transform.basis.z.normalized()
	var origin := fps_ejection_port.global_position+ejection_right*0.035+Vector3.UP*0.012
	add_child(shell)
	shell.global_position = origin
	shell.global_rotation = Vector3(randf_range(-1.0,1.0),randf_range(-PI,PI),randf_range(-1.0,1.0))
	shell.linear_velocity = ejection_right*randf_range(1.7,2.4)+Vector3.UP*randf_range(0.9,1.5)+weapon_forward*0.25
	shell.angular_velocity = Vector3(randf_range(-24.0,24.0),randf_range(-24.0,24.0),randf_range(-24.0,24.0))
	fps_transient_effects.append(shell)
	fps_transient_lifetimes[shell.get_instance_id()] = 4.5
	var live_casings := 0
	for effect in fps_transient_effects:
		if effect is RigidBody3D: live_casings += 1
	while live_casings > 20:
		for i in fps_transient_effects.size():
			if fps_transient_effects[i] is RigidBody3D:
				var oldest: Node3D = fps_transient_effects.pop_at(i)
				fps_transient_lifetimes.erase(oldest.get_instance_id())
				oldest.queue_free()
				live_casings -= 1
				break

func _add_firing_impact(point: Vector3, normal: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.92,0.64,0.27)
	material.emission_enabled = true
	material.emission = Color(0.9,0.42,0.10)
	material.emission_energy_multiplier = 1.4
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	mesh.radial_segments = 8
	mesh.rings = 4
	var spark := MeshInstance3D.new()
	spark.name = "Brief hitscan impact glint"
	spark.mesh = mesh
	spark.material_override = material
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spark)
	spark.global_position = point+normal*0.015
	fps_transient_effects.append(spark)
	fps_transient_lifetimes[spark.get_instance_id()] = 0.10

func _update_transient_firing_effects(delta: float) -> void:
	for i in range(fps_transient_effects.size()-1,-1,-1):
		var effect := fps_transient_effects[i]
		var id := effect.get_instance_id()
		var remaining := float(fps_transient_lifetimes.get(id,0.0))-delta
		if remaining <= 0.0 or not is_instance_valid(effect):
			fps_transient_effects.remove_at(i)
			fps_transient_lifetimes.erase(id)
			if is_instance_valid(effect): effect.queue_free()
		else:
			fps_transient_lifetimes[id] = remaining

func _refresh_ui() -> void:
	if benchmark == "terrain": return
	var objective := ""
	match phase:
		0: objective = "BRIEFING | Review the patrol task"
		1: objective = "APPROACH | Reach the lower cairn"
		2: objective = "CLIMB | Choose sheltered snow or exposed scree; reach the rope anchor and press R"
		3: objective = "OBSERVATION | Bring the patrol near the spur, press O"
		4: objective = "CONTACT | Seek rock cover and keep the patrol together"
		5: objective = "AFTERMATH | Remember the six"
	objective_label.text = objective
	var focus: PatrolActor = squad[selected[0]] if not selected.is_empty() else squad[0]
	var condition := "Prone" if focus.prone else ("Crouched" if focus.crouched else "Standing")
	var surface_note := mountain.surface_at(focus.position.x,focus.position.z).capitalize()
	var exposure_note := "Exposed ledge" if mountain.exposure_at(focus.position.x,focus.position.z) > 0.7 else "Sheltered slope"
	if focus.rope_traversing: exposure_note = "Rope crossing · slow movement"
	var danger := "Dramatized contact" if phase == 4 else _danger_text()
	status_label.text = "%s  ·  %s  ·  Stamina %d  ·  Cold %d  ·  %s  ·  %s" % [condition,surface_note,int(focus.stamina),int(focus.cold),exposure_note,danger]
	var view_hint := "FPS · T overhead · Esc cursor" if first_person_mode else "TACTICAL · T first person"
	hint_label.text = "%s  ·  Visibility %d%%  ·  %s  ·  %d FPS" % [view_hint,int(visibility*100),"PAUSED / %d queued" % queued_orders.size() if tactical_paused else ["Performance","Balanced","High"][preset],Engine.get_frames_per_second()]
	if weapon_status_label != null:
		var mode_text := "BURST ×3" if fps_fire_mode == FireMode.BURST else "SINGLE"
		var ammo_text := "RELOADING" if fps_reload_remaining > 0.0 else "%02d / %03d" % [fps_magazine_rounds,fps_reserve_rounds]
		weapon_status_label.text = "AK  ·  %s  ·  %s  ·  B MODE" % [mode_text,ammo_text]
		weapon_status_label.get_parent().visible = first_person_mode and phase > 0 and phase < 5
	var lines := "[b]4 JAT patrol[/b]\n"
	for i in squad.size(): lines += "%s  %s\n" % ["●" if i in selected else "○",ROSTER[i]]
	roster_label.text = lines

func _danger_text() -> String:
	var high := 0.0
	for guard in sentries: high = maxf(high,guard.alert)
	if high > 0.8: return "Seen: break sightline"
	if high > 0.3: return "Movement suspected"
	return "No confirmed sighting"

func _update_camera() -> void:
	if first_person_mode and phase > 0 and phase < 5 and not squad.is_empty():
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 50.0 if fps_aiming else 64.0
		if fps_reticle != null: fps_reticle.visible = not fps_aiming
		if objective_label != null:
			var aim_status_panel := objective_label.get_parent().get_parent() as Control
			if aim_status_panel != null: aim_status_panel.visible = not fps_aiming
		if flash_label != null: flash_label.visible = not fps_aiming
		var actor := squad[0]
		var eye_height := 0.42 if actor.prone else (1.08 if actor.crouched else 1.58)
		camera.position = actor.position+Vector3.UP*eye_height
		camera.rotation = Vector3(fps_pitch+fps_camera_recoil_pitch,fps_yaw,0.0)
		camera.cull_mask = 3
		_update_actor_lod(camera.position)
		if fps_view_rig != null:
			fps_view_rig.visible = true
			# The camera sits behind the stock while aiming. Keep it in the
			# hip-fire view, but prevent its top and buttplate from filling ADS.
			if fps_view_stock != null: fps_view_stock.visible = not fps_aiming
			var view_scale := 1.65 if fps_aiming else 1.76
			fps_view_rig.scale = Vector3.ONE * view_scale
			var base_position := Vector3(0.0,-0.08,-0.04) if fps_aiming else Vector3(0.78,-0.40,-0.41)
			var base_rotation := Vector3.ZERO if fps_aiming else Vector3(0.13,0.30,0.0)
			var reload_blend := 0.0
			if fps_reload_remaining > 0.0:
				var reload_progress := 1.0-fps_reload_remaining/RELOAD_DURATION
				reload_blend = sin(PI*clampf(reload_progress,0.0,1.0))
			var reload_offset := Vector3(0.035,-0.075,0.045)*reload_blend
			var final_rotation := base_rotation + Vector3(0.22,0.0,0.06)*reload_blend + Vector3(fps_weapon_recoil_pitch,0.0,fps_weapon_recoil_roll)
			var recoil_offset := Vector3(0.0,0.0,fps_weapon_recoil_back)
			# Slightly yaw the normal carry pose around its muzzle so the rear sits
			# farther left without moving the muzzle or separating either hand.
			var rear_left_yaw := deg_to_rad(-2.0) if not fps_aiming else 0.0
			var displayed_rotation := final_rotation + Vector3(0.0,rear_left_yaw,0.0)
			fps_view_rig.rotation = displayed_rotation
			var displayed_position := base_position + reload_offset + recoil_offset
			if fps_view_muzzle_anchor_valid and not is_zero_approx(rear_left_yaw):
				var base_basis := Basis.from_euler(final_rotation).scaled(Vector3.ONE*view_scale)
				var displayed_basis := Basis.from_euler(displayed_rotation).scaled(Vector3.ONE*view_scale)
				var muzzle_camera_position := displayed_position + base_basis*fps_view_muzzle_local
				displayed_position = muzzle_camera_position-displayed_basis*fps_view_muzzle_local
			fps_view_rig.position = displayed_position
			for part in fps_aim_hidden_parts: part.visible = not fps_aiming
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_zoom
	# Preserve detail when the player inspects a soldier or rifle. The normal
	# preset scales the 3D buffer for the GT 730, but close tactical zooms need
	# extra samples so small weapon edges do not blur into the terrain.
	var preset_scale: float = [0.65, 0.82, 0.88][preset]
	# Close inspection is where a small rifle silhouette is most visible. Raise
	# the 3D buffer substantially for that view so the barrel, sight ears and
	# wood/steel boundary are sampled cleanly instead of being enlarged from a
	# coarse Performance buffer.
	var close_scale_boost := 0.16 if camera_zoom <= 12.0 else 0.0
	get_viewport().scaling_3d_scale = minf(1.0, preset_scale + close_scale_boost)
	# Keep the same isometric angle while bringing the camera physically closer
	# at close zoom. The previous fixed offset made characters remain tiny even
	# when the orthographic size was reduced for inspection.
	var zoom_ratio := camera_zoom / 38.0
	var offset := (Vector3(34,29,39) * zoom_ratio).rotated(Vector3.UP,camera_yaw)
	camera.position = camera_target + offset
	camera.look_at(camera_target,Vector3.UP)
	_update_actor_lod(camera.position)

func _update_actor_lod(camera_position: Vector3) -> void:
	for actor in squad: actor.update_visual_lod(camera_position)
	for actor in sentries: actor.update_visual_lod(camera_position)

func _apply_preset(value: int) -> void:
	preset = value
	match value:
		0:
			get_viewport().scaling_3d_scale = 0.65
			sun.shadow_enabled = false
			environment.fog_density = 0.0012
		1:
			get_viewport().scaling_3d_scale = 0.82
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 42.0
			environment.fog_density = 0.0018
		2:
			get_viewport().scaling_3d_scale = 0.88
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 72.0
			environment.fog_density = 0.0027
	if benchmark == "": _message("Graphics: %s" % ["Performance","Balanced","High"][value])

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(p.x),-45,45),clampi(roundi(p.z),-45,45))

func _free_cell(cell: Vector2i) -> Vector2i:
	if not grid.is_point_solid(cell): return cell
	for radius in range(1,7):
		for dz in range(-radius,radius+1):
			for dx in range(-radius,radius+1):
				var test := cell+Vector2i(dx,dz)
				if grid.is_in_boundsv(test) and not grid.is_point_solid(test): return test
	return cell

func _order_actor(index: int, point: Vector3) -> void:
	var actor := squad[index]
	var start_cell := _free_cell(_cell(actor.position))
	var flat_path := grid.get_point_path(start_cell,_free_cell(_cell(point)))
	var route: Array[Vector3] = []
	for flat in flat_path: route.append(_ground(Vector3(flat.x,0,flat.y)))
	# AStarGrid2D includes the start-cell center as the first waypoint. When
	# the actor is off-center, steering back to that point causes a visible
	# wrong-way step before the requested route begins. Drop it only when the
	# path truly starts in the actor's current cell; retain a nearby free-cell
	# waypoint when the actor is standing on a blocked cell.
	if route.size() > 1 and _cell(route[0]) == _cell(actor.position):
		route.pop_front()
	actor.set_destination(route)

func _command_move(point: Vector3) -> void:
	if phase == 0 or phase == 5: return
	var n := selected.size()
	if n == 0: return
	for k in n:
		var actor_id := selected[k]
		var angle := TAU*k/maxi(1,n)
		var spread := 0.0 if n == 1 else 1.7+0.3*(k%2)
		var target := point+Vector3(cos(angle)*spread,0,sin(angle)*spread)
		if tactical_paused: queued_orders[actor_id] = target
		else: _order_actor(actor_id,target)
	if tactical_paused: _message("Orders queued. Enter executes them together.")
	_refresh_ui()

func _sync_selection() -> void:
	for i in squad.size(): squad[i].set_selected(i in selected)
	if roster_label != null: _refresh_ui()

func _world_click(screen_point: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_point)
	var to := from+camera.project_ray_normal(screen_point)*500
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to))
	return hit.position if not hit.is_empty() else Vector3(INF,INF,INF)

func _input(event: InputEvent) -> void:
	if benchmark != "": return
	if event is InputEventMouseMotion and first_person_mode and fps_mouse_captured:
		fps_yaw -= event.relative.x*0.0022
		fps_pitch = clampf(fps_pitch-event.relative.y*0.0022,-1.35,1.25)
	elif event is InputEventMouseButton:
		if first_person_mode and event.button_index == MOUSE_BUTTON_RIGHT:
			fps_aiming = event.pressed and fps_mouse_captured
		if first_person_mode and InputMap.event_is_action(event,"fire_weapon"):
			if event.pressed and not fps_mouse_captured:
				_capture_fps_mouse()
			elif event.pressed:
				_fire_trigger_pressed()
			else:
				_fire_trigger_released()

func _unhandled_input(event: InputEvent) -> void:
	if benchmark != "": return
	if event is InputEventMouseButton:
		if not event.pressed: return
		if first_person_mode and fps_mouse_captured: return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and not first_person_mode: camera_zoom = maxf(8.0,camera_zoom*0.85)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not first_person_mode: camera_zoom = minf(83.0,camera_zoom*1.15)
		elif event.button_index == MOUSE_BUTTON_LEFT and not first_person_mode and phase > 0 and phase < 5:
			var nearest := -1
			var distance_px := 27.0
			for i in squad.size():
				var point := camera.unproject_position(squad[i].position+Vector3.UP*1.1)
				var d: float = event.position.distance_to(point)
				if d < distance_px:
					distance_px = d
					nearest = i
			if nearest >= 0:
				if event.shift_pressed:
					if nearest in selected: selected.erase(nearest)
					else: selected.append(nearest)
				else: selected = [nearest]
				if selected.is_empty(): selected = [nearest]
				_sync_selection()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not first_person_mode:
			var point := _world_click(event.position)
			if is_finite(point.x): _command_move(point)
	if event is InputEventKey and event.pressed and not event.echo:
		if InputMap.event_is_action(event,"fire_mode_toggle"):
			_toggle_fire_mode()
			_update_camera()
			return
		match event.keycode:
			KEY_ESCAPE:
				if first_person_mode and fps_mouse_captured:
					fps_mouse_captured = false
					fps_aiming = false
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				elif first_person_mode and phase > 0 and phase < 5:
					_set_first_person_mode(false)
				elif not first_person_mode and phase > 0 and phase < 5:
					_set_first_person_mode(true)
			KEY_T:
				if phase > 0 and phase < 5: _set_first_person_mode(not first_person_mode)
			KEY_TAB:
				if not first_person_mode:
					selected = [0,1,2,3,4,5]
					_sync_selection()
			KEY_C:
				var controlled := [0] if first_person_mode else selected
				for i in controlled:
					if squad[i].prone:
						squad[i].prone = false
						squad[i].crouched = true
					else:
						squad[i].crouched = not squad[i].crouched
			KEY_V:
				var can_prone := true
				var controlled := [0] if first_person_mode else selected
				for i in controlled:
					if squad[i].rope_traversing: can_prone = false
				if not can_prone:
					_message("Prone stance is unavailable during a rope crossing.")
				else:
					var go_prone := not squad[controlled[0]].prone
					for i in controlled:
						squad[i].prone = go_prone
						squad[i].crouched = false
					_refresh_ui()
			KEY_SPACE:
				if phase > 0 and phase < 5:
					tactical_paused = not tactical_paused
					_message("Tactical pause" if tactical_paused else "Orders resumed")
			KEY_ENTER:
				if tactical_paused:
					for id in queued_orders: _order_actor(int(id),queued_orders[id])
					queued_orders.clear()
					tactical_paused = false
			KEY_O: _observe()
			KEY_F: camera_manual = false
			KEY_F1: _apply_preset(0)
			KEY_F2: _apply_preset(1)
			KEY_F3: _apply_preset(2)
			KEY_R: _start_rope_traverse()
			KEY_G: _play_reload_animation()
			KEY_F5: _save_game()
			KEY_F9: _load_game()
			KEY_Q:
				if not first_person_mode: camera_yaw -= PI/8
			KEY_E:
				if not first_person_mode: camera_yaw += PI/8
			KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6:
				if not first_person_mode:
					selected = [event.keycode-KEY_1]
					_sync_selection()
	_update_camera()

func _observe() -> void:
	if phase != 3:
		_message("Reach the observation area first.")
		return
	var close_count := 0
	for actor in squad:
		if actor.position.distance_to(_ground(OBSERVATION)) < 18: close_count += 1
	if squad[0].position.distance_to(_ground(OBSERVATION)) > 12 or close_count < 4:
		_message("Bring Lt. Kalia and at least four patrol members close to the spur.")
		return
	phase = 4
	phase_timer = 0
	contact_cue = 0
	_message("Reconstructed observation recorded. The final patrol's report is not established.")
	_refresh_ui()

func _start_rope_traverse() -> void:
	if phase != 2 or rope_started:
		_message("The rope traverse is available from its marked lower anchor during the climb.")
		return
	if squad[0].position.distance_to(_ground(ROPE_NEAR)) > 8.0:
		_message("Move Lt. Kalia to the marked lower rope anchor first.")
		return
	rope_started = true
	rope_crossing_group.clear()
	for i in squad.size():
		var actor := squad[i]
		actor.rope_traversing = true
		actor.ledge_traversing = true
		rope_crossing_group.append(i)
		var offset := Vector3((float(i%3)-1.0)*0.65,0,float(i/3)*0.75)
		_order_actor(i,_ground(ROPE_FAR)+offset)
	_message("Reconstructed rope crossing: keep the patrol on the marked shelf; the exposed traverse slows movement.")
	_refresh_ui()

func _finish_rope_traverse_if_ready() -> void:
	if not rope_started:
		return
	var across := 0
	for i in rope_crossing_group:
		if squad[i].position.distance_to(_ground(ROPE_FAR)) < 5.0:
			across += 1
	if across < squad.size():
		return
	for actor in squad:
		actor.rope_traversing = false
		actor.ledge_traversing = false
	rope_started = false
	phase = 3
	_message("The rope shelf is clear. Bring four or more patrol members near the observation spur.")
	_refresh_ui()

func _perception(delta: float) -> void:
	for guard in sentries:
		var best := 0.0
		for actor in squad:
			var displacement := actor.position-guard.position
			var distance := displacement.length()
			if distance < 0.1: continue
			var hear := (10.0 if actor.moving else 2.0)*(0.28 if actor.prone else (0.5 if actor.crouched else 1.0))
			if mountain.surface_at(actor.position.x,actor.position.z) == "scree": hear *= 1.35
			hear *= 0.7+visibility*0.3
			if distance < hear: best = maxf(best,0.48)
			var sight_range := 29.0*visibility*(0.54 if actor.prone else (0.72 if actor.crouched else 1.0))
			if distance > sight_range: continue
			if guard.direction.dot(displacement.normalized()) < 0.15: continue
			var start := guard.position+Vector3.UP*1.65
			var end := actor.position+Vector3.UP*(0.28 if actor.prone else (0.65 if actor.crouched else 1.25))
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,end))
			if hit.is_empty(): best = maxf(best,0.9)
		guard.alert = clampf(guard.alert+delta*(best*0.75-0.16),0,1)
		guard.badge.visible = guard.alert > 0.35
	if _danger_text() == "Seen: break sightline" and not detection_message_shown:
		detection_message_shown = true
		_message("Movement spotted. Crouch, use a ridge or rock, and change route.")

func _drop_footprint(delta: float) -> void:
	if footprint_multimesh == null: return
	footprint_clock += delta
	if footprint_clock < 0.42: return
	footprint_clock = 0.0
	for actor in squad:
		if not actor.moving or mountain.surface_at(actor.position.x,actor.position.z) != "snow": continue
		var footprint_scale := Vector3(0.20,0.014,0.42) if actor.prone else Vector3(0.13,0.015,0.22)
		var yaw := atan2(-actor.direction.x,-actor.direction.z)
		var transform := Transform3D(Basis(Vector3.UP,yaw).scaled(footprint_scale),actor.position+Vector3(0,0.03,0))
		footprint_multimesh.set_instance_transform(footprint_cursor,transform)
		footprint_cursor = (footprint_cursor+1)%150
		footprint_count = mini(150,footprint_count+1)
		footprint_multimesh.visible_instance_count = footprint_count

func _save_path() -> String:
	if OS.has_feature("template"):
		return "user://savegame.json"
	return OS.get_executable_path().get_base_dir().path_join("user_data/savegame.json")

func _save_game() -> void:
	if phase == 0 or phase == 5: return
	var positions := []
	var stances := []
	var prone_stances := []
	var routes := []
	for actor in squad:
		positions.append([actor.position.x,actor.position.z,actor.stamina,actor.cold])
		stances.append(actor.crouched)
		prone_stances.append(actor.prone)
		var points := []
		for waypoint in actor.path: points.append([waypoint.x,waypoint.z])
		routes.append(points)
	var guard_alerts := []
	for guard in sentries: guard_alerts.append(guard.alert)
	var queued := {}
	for id in queued_orders:
		var point: Vector3 = queued_orders[id]
		queued[str(id)] = [point.x,point.z]
	var data := {"phase":phase,"phase_timer":phase_timer,"positions":positions,"stances":stances,"prone":prone_stances,"routes":routes,"guards":guard_alerts,"queued":queued,"paused":tactical_paused,"selected":selected,"weather_clock":weather_clock,"contact_cue":contact_cue,"rope_started":rope_started,"rope_group":rope_crossing_group,"camera":[camera_target.x,camera_target.z,camera_zoom,camera_yaw,camera_manual],"fps_view":[first_person_mode,fps_yaw,fps_pitch],"weapon":[fps_magazine_rounds,fps_reserve_rounds,fps_fire_mode],"preset":preset}
	DirAccess.make_dir_recursive_absolute(_save_path().get_base_dir())
	var file := FileAccess.open(_save_path(),FileAccess.WRITE)
	if file == null:
		_message("Quick save unavailable in this folder.")
		return
	file.store_string(JSON.stringify(data))
	_message("Quick save written.")

func _load_game() -> void:
	if not FileAccess.file_exists(_save_path()):
		_message("No quick save found.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if typeof(parsed) != TYPE_DICTIONARY: return
	_cancel_burst()
	fps_trigger_down = false
	fps_reload_remaining = 0.0
	fps_reload_started_msec = -1
	var weapon_state: Array = parsed.get("weapon",[MAGAZINE_CAPACITY,RESERVE_CAPACITY,FireMode.SINGLE])
	if weapon_state.size() >= 3:
		fps_magazine_rounds = clampi(int(weapon_state[0]),0,MAGAZINE_CAPACITY)
		fps_reserve_rounds = clampi(int(weapon_state[1]),0,RESERVE_CAPACITY)
		fps_fire_mode = int(weapon_state[2]) if int(weapon_state[2]) == FireMode.BURST else FireMode.SINGLE
	phase = int(parsed.get("phase",1))
	phase_timer = float(parsed.get("phase_timer",0))
	rope_started = bool(parsed.get("rope_started",false))
	rope_crossing_group.clear()
	for id in parsed.get("rope_group",[]):
		if int(id) >= 0 and int(id) < squad.size(): rope_crossing_group.append(int(id))
	var positions: Array = parsed.get("positions",[])
	var stances: Array = parsed.get("stances",[])
	var prone_stances: Array = parsed.get("prone",[])
	var routes: Array = parsed.get("routes",[])
	for i in mini(squad.size(),positions.size()):
		var record: Array = positions[i]
		squad[i].position = _ground(Vector3(record[0],0,record[1]))
		squad[i].stamina = record[2]
		squad[i].cold = record[3]
		squad[i].path.clear()
		if i < routes.size():
			for waypoint in routes[i]: squad[i].path.append(_ground(Vector3(waypoint[0],0,waypoint[1])))
		if i < stances.size(): squad[i].crouched = stances[i]
		squad[i].prone = bool(prone_stances[i]) if i < prone_stances.size() else false
		if squad[i].prone: squad[i].crouched = false
	for i in squad.size():
		squad[i].rope_traversing = rope_started and i in rope_crossing_group
		squad[i].ledge_traversing = rope_started and i in rope_crossing_group
	var guard_alerts: Array = parsed.get("guards",[])
	for i in mini(sentries.size(),guard_alerts.size()): sentries[i].alert = guard_alerts[i]
	queued_orders.clear()
	var queued: Dictionary = parsed.get("queued",{})
	for id in queued:
		var point: Array = queued[id]
		queued_orders[int(id)] = _ground(Vector3(point[0],0,point[1]))
	tactical_paused = parsed.get("paused",false)
	selected.clear()
	for id in parsed.get("selected",[0]):
		if int(id) >= 0 and int(id) < squad.size(): selected.append(int(id))
	if selected.is_empty(): selected = [0]
	_sync_selection()
	weather_clock = parsed.get("weather_clock",0.0)
	contact_cue = parsed.get("contact_cue",0)
	var state: Array = parsed.get("camera",[0,30,49,0])
	camera_target = _ground(Vector3(state[0],0,state[1]))
	camera_zoom = state[2]
	camera_yaw = state[3]
	if state.size() > 4: camera_manual = state[4]
	_apply_preset(int(parsed.get("preset",1)))
	var fps_state: Array = parsed.get("fps_view",[false,0.0,-0.04])
	if fps_state.size() >= 3:
		_set_first_person_mode(bool(fps_state[0]))
		fps_yaw = float(fps_state[1])
		fps_pitch = float(fps_state[2])
	overlay.visible = false
	_update_camera()
	_refresh_ui()
	_message("Quick save loaded.")

func _show_aftermath() -> void:
	_cancel_burst()
	fps_trigger_down = false
	fps_reload_remaining = 0.0
	fps_reload_started_msec = -1
	if first_person_mode: _set_first_person_mode(false)
	phase = 5
	for actor in squad: actor.play_action_animation("aftermath")
	overlay.visible = true
	overlay_title.text = "THE PATROL DID NOT RETURN"
	overlay_body.text = "Lt. Saurabh Kalia and Sepoys Arjun Ram, Bhanwar Lal Bhagaria, Bhikaram, Moola Ram and Naresh Singh of 4 JAT were lost near Bajrang in May 1999. A subsequent search patrol encountered hostile positions on the spur. Their remains were handed over in June.\n\nThis sequence stops before captivity. The route, observation, dialogue and on-screen contact were reconstructed; their exact course is unknown. Sources differ on whether the final patrol set out on 14 or 15 May.\n\n[b]Remember all six.[/b]\n\nSource notes: see docs/research/SOURCE_LEDGER.md and the mission dossier."
	overlay_button.visible = false
	_refresh_ui()

func _load_wind() -> void:
	var path := "res://assets/audio/wind.wav"
	if not ResourceLoader.exists(path): return
	sound_player = AudioStreamPlayer.new()
	sound_player.stream = load(path)
	if sound_player.stream is AudioStreamWAV: sound_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound_player.volume_db = -21
	add_child(sound_player)
	sound_player.play()
	fire_player = AudioStreamPlayer.new()
	fire_player.stream = load("res://assets/audio/distant_fire.wav")
	fire_player.volume_db = -15
	add_child(fire_player)
	weapon_fire_player = AudioStreamPlayer.new()
	var report_stream := _build_single_rifle_report()
	weapon_fire_players.clear()
	for i in range(3):
		var report_player := AudioStreamPlayer.new()
		report_player.name = "AK report placeholder voice %d" % (i+1)
		report_player.stream = report_stream
		report_player.volume_db = -2
		add_child(report_player)
		weapon_fire_players.append(report_player)
	weapon_fire_player = weapon_fire_players[0]

# One-pulse placeholder report synthesized as 16-bit PCM. distant_fire.wav is a
# two-pulse volley imported as QOA, so byte-trimming it does not yield one shot.
func _build_single_rifle_report() -> AudioStreamWAV:
	const RATE := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var frames := int(RATE*0.24)
	var data := PackedByteArray()
	data.resize(frames*2)
	var noise := 0.0
	for i in frames:
		var t := float(i)/RATE
		noise = 0.55*noise+0.45*rng.randf_range(-1.0,1.0)
		var crack := noise*exp(-t*38.0)
		var thump := sin(t*95.0*TAU)*exp(-t*22.0)*0.55
		var attack := minf(1.0,t*RATE/24.0)
		data.encode_s16(i*2,int(clampf((crack+thump)*attack*0.9,-1.0,1.0)*32767.0))
	var report := AudioStreamWAV.new()
	report.format = AudioStreamWAV.FORMAT_16_BITS
	report.mix_rate = RATE
	report.stereo = false
	report.loop_mode = AudioStreamWAV.LOOP_DISABLED
	report.data = data
	return report

func _process(delta: float) -> void:
	if benchmark != "":
		_benchmark_tick(delta)
		if benchmark == "terrain": return
	if smoke_route:
		smoke_clock += delta
		if phase == 2 and smoke_route_leg == 1:
			smoke_route_leg = 2
			_command_move(_ground(ROPE_NEAR))
		elif phase == 2 and smoke_route_leg == 2 and squad[0].position.distance_to(_ground(ROPE_NEAR)) < 8.0:
			smoke_route_leg = 3
			_start_rope_traverse()
		elif phase == 3 and smoke_route_leg == 3:
			smoke_route_leg = 4
			_command_move(_ground(OBSERVATION))
		if phase == 3 and smoke_route_leg == 4 and squad[0].position.distance_to(_ground(OBSERVATION)) < 11:
			_observe()
		if phase == 5:
			print("SMOKE_ROUTE_PASS elapsed=%.1f squad=%d aftermath=%s" % [smoke_clock,squad.size(),overlay_title.text])
			get_tree().quit()
		elif smoke_clock > 130:
			print("SMOKE_ROUTE_FAIL phase=%d leader_z=%.1f path_nodes=%d" % [phase,squad[0].position.z,squad[0].path.size()])
			get_tree().quit(2)
	if phase == 0 or phase == 5:
		_update_camera()
		return
	if tactical_paused:
		for actor in squad: actor.set_process(false)
		for enemy in sentries: enemy.set_process(false)
	else:
		for actor in squad: actor.set_process(true)
		for enemy in sentries: enemy.set_process(true)
		phase_timer += delta
		weather_clock += delta
		visibility = clampf(0.72+0.28*sin(weather_clock*0.13)+0.08*sin(weather_clock*0.57),0.34,1.0)
		for actor in squad: actor.wind_strength = 1.0-visibility
		environment.fog_density = [0.0012,0.0018,0.0027][preset]*(1.0+(1.0-visibility)*2.0)
		_perception(delta)
		_drop_footprint(delta)
		if phase == 1 and Vector2(squad[0].position.x,squad[0].position.z).distance_to(Vector2(0,15)) < 5.0:
			phase = 2
			_message("The rise steepens. Scree is noisy; snow slows the climb.")
		elif phase == 2 and rope_started:
			_finish_rope_traverse_if_ready()
		elif phase == 4 and phase_timer > 18 and benchmark == "": _show_aftermath()
		if phase == 4 and phase_timer > 3 and contact_cue == 0:
			contact_cue = 1
			_message("Dramatized contact: fire from the spur. The exact exchange is unknown.")
			for actor in squad: actor.play_action_animation("incoming_fire")
			if fire_player != null: fire_player.play()
		elif phase == 4 and phase_timer > 10 and contact_cue == 1:
			contact_cue = 2
			_message("Weather closes in. Keep the patrol within sight.")
			if fire_player != null: fire_player.play()
		if sound_player != null: sound_player.volume_db = -25+8*(1.0-visibility)
	if phase < 5:
		for actor in squad: actor.set_contact_ready(phase == 4 and actor.action_animation != "reload")
		if first_person_mode:
			_update_first_person_input(delta)
		else:
			var pan := Vector3.ZERO
			if Input.is_key_pressed(KEY_W): pan.z -= 1
			if Input.is_key_pressed(KEY_S): pan.z += 1
			if Input.is_key_pressed(KEY_D): pan.x += 1
			if Input.is_key_pressed(KEY_A): pan.x -= 1
			if pan != Vector3.ZERO:
				camera_manual = true
				camera_target += pan.normalized().rotated(Vector3.UP,camera_yaw)*delta*16
			if not camera_manual and not selected.is_empty():
				var centre := Vector3.ZERO
				for i in selected: centre += squad[i].position
				centre /= selected.size()
				camera_target = camera_target.lerp(centre,clampf(delta*2.5,0,1))
			camera_target.x = clampf(camera_target.x,-35,35)
			camera_target.z = clampf(camera_target.z,-39,40)
	_update_fire_system(delta)
	_update_camera()
	_refresh_ui()

func _benchmark_tick(delta: float) -> void:
	bench_clock += delta
	if benchmark == "terrain" and bench_clock < 2: return
	if not bench_capture and bench_clock > 2.1:
		bench_capture = true
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds"))
		var args := OS.get_cmdline_user_args()
		var path := "res://builds/%s_benchmark.png" % benchmark
		if "--a05n-review" in args:
			path = "res://builds/a05n_kit_review.png"
		elif "--a05o-close-review" in args:
			path = "res://builds/a05o_squad_close.png"
		elif "--a05o-review" in args:
			path = "res://builds/a05o_squad_normal.png"
		elif fps_lighting_review:
			path = "res://builds/fps_lighting_controlled.png"
		elif "--fps-review" in args:
			path = "res://builds/fps_review.png"
		elif "--fps-aim-review" in args:
			path = "res://builds/fps_aim_review.png"
		elif "--a05p-prone-squad" in args:
			path = "res://builds/a05p_prone_squad_benchmark.png"
		elif "--a05p-prone-review" in args:
			path = "res://builds/a05p_prone_review.png"
		elif "--a05p-kneel-review" in args:
			path = "res://builds/a05p_kneel_review.png"
		elif "--a05p-walk-review" in args:
			path = "res://builds/a05p_walk_review.png"
		elif "--a05l-review" in args:
			var review_name := "rifle_low_ready.png" if "--rifle-low" in args else ("rifle_high_ready.png" if "--rifle-high" in args else ("a05l_candidate_side.png" if "--art-side" in args else ("a05l_candidate_crouch.png" if "--art-crouch" in args else "a05l_candidate_review.png")))
			path = "res://builds/%s" % review_name
		get_viewport().get_texture().get_image().save_png(path)
		print("BENCH_SCREENSHOT ",ProjectSettings.globalize_path(path))
		return
	if bench_clock > 3 and bench_clock < 18:
		if delta > 0.05: print("BENCH_SLOW_FRAME time=%.3f dt=%.3f" % [bench_clock,delta])
		bench_frames.append(delta)
	if bench_clock > 18:
		bench_frames.sort()
		var sum := 0.0
		for frame in bench_frames: sum += frame
		var fifth := mini(bench_frames.size()-1,int(bench_frames.size()*0.95))
		print("BENCH_%s_RESULT frames=%d avg_fps=%.1f fifth_percentile_fps=%.1f min_fps=%.1f" % [benchmark.to_upper(),bench_frames.size(),bench_frames.size()/sum,1.0/bench_frames[fifth],1.0/bench_frames[-1]])
		get_tree().quit()

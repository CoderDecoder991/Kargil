extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main._begin_mission()
	main.set_process(false)
	for actor in main.squad: actor.set_process(false)
	for enemy in main.sentries: enemy.set_process(false)
	main.fps_mouse_captured = true
	var failures := 0
	main.fps_fire_mode = 0
	main.fps_magazine_rounds = 30
	main.fps_reserve_rounds = 120
	main.fps_shot_count = 0
	main.fps_fire_cooldown = 0.0
	main.fps_trigger_down = false
	main._fire_trigger_pressed()
	var single_first: bool = main.fps_shot_count == 1 and main.fps_magazine_rounds == 29
	main._fire_trigger_pressed()
	var held_single: bool = main.fps_shot_count == 1 and main.fps_magazine_rounds == 29
	main._fire_trigger_released()
	main.fps_fire_cooldown = 0.05
	main._fire_trigger_pressed()
	var cooldown_gate: bool = main.fps_shot_count == 1
	main._fire_trigger_released()
	main.fps_fire_cooldown = 0.0
	main._fire_trigger_pressed()
	var single_pass: bool = single_first and held_single and cooldown_gate and main.fps_shot_count == 2 and main.fps_magazine_rounds == 28
	if not single_pass: failures += 1
	print("FIRE_SINGLE_%s first=%s held=%s cooldown=%s shots=%d ammo=%d" % ["PASS" if single_pass else "FAIL",single_first,held_single,cooldown_gate,main.fps_shot_count,main.fps_magazine_rounds])
	main._toggle_fire_mode()
	var mode_pass: bool = main.fps_fire_mode == 1 and InputMap.has_action("fire_mode_toggle") and InputMap.has_action("fire_weapon")
	if not mode_pass: failures += 1
	print("FIRE_MODE_INPUT_%s mode=%d binding=%s/%s" % ["PASS" if mode_pass else "FAIL",main.fps_fire_mode,InputMap.has_action("fire_mode_toggle"),InputMap.has_action("fire_weapon")])

	main._fire_trigger_released()
	main.fps_fire_mode = 1
	main.fps_magazine_rounds = 30
	main.fps_shot_count = 0
	main.fps_fire_cooldown = 0.0
	main.fps_burst_rounds_remaining = 0
	main._fire_trigger_pressed()
	var burst_first: bool = main.fps_shot_count == 1 and main.fps_burst_rounds_remaining == 2
	main._fire_trigger_released()
	for frame in range(5): main._update_fire_system(0.10)
	var burst_pass: bool = burst_first and main.fps_shot_count == 3 and main.fps_magazine_rounds == 27 and main.fps_burst_rounds_remaining == 0
	main._update_fire_system(0.50)
	var held_burst_no_repeat: bool = main.fps_shot_count == 3
	if not burst_pass or not held_burst_no_repeat: failures += 1
	print("FIRE_BURST_%s first=%s release_did_not_cancel=true shots=%d ammo=%d held_no_repeat=%s" % ["PASS" if burst_pass and held_burst_no_repeat else "FAIL",burst_first,main.fps_shot_count,main.fps_magazine_rounds,held_burst_no_repeat])

	main._fire_trigger_released()
	main.fps_magazine_rounds = 2
	main.fps_shot_count = 0
	main.fps_fire_cooldown = 0.0
	main._fire_trigger_pressed()
	main._fire_trigger_released()
	for frame in range(5): main._update_fire_system(0.10)
	var partial_pass: bool = main.fps_shot_count == 2 and main.fps_magazine_rounds == 0 and main.fps_burst_rounds_remaining == 0
	if not partial_pass: failures += 1
	print("FIRE_PARTIAL_BURST_%s shots=%d ammo=%d remaining=%d" % ["PASS" if partial_pass else "FAIL",main.fps_shot_count,main.fps_magazine_rounds,main.fps_burst_rounds_remaining])

	main.fps_magazine_rounds = 10
	main.fps_reserve_rounds = 20
	main.fps_fire_mode = 0
	main.fps_fire_cooldown = 0.0
	main._start_weapon_reload()
	main._fire_trigger_released()
	main._fire_trigger_pressed()
	var fire_blocked_during_reload: bool = main.fps_magazine_rounds == 10
	main._fire_trigger_released()
	for frame in range(16): main._update_fire_system(0.10)
	var reload_pass: bool = fire_blocked_during_reload and main.fps_reload_remaining == 0.0 and main.fps_magazine_rounds == 30 and main.fps_reserve_rounds == 0
	if not reload_pass: failures += 1
	print("FIRE_RELOAD_%s blocked=%s magazine=%d reserve=%d" % ["PASS" if reload_pass else "FAIL",fire_blocked_during_reload,main.fps_magazine_rounds,main.fps_reserve_rounds])

	main.fps_magazine_rounds = 5
	main.fps_shot_count = 0
	main.fps_fire_cooldown = 0.0
	main.fps_fire_mode = 1
	main._fire_trigger_pressed()
	main.tactical_paused = true
	main._update_fire_system(0.1)
	var pause_pass: bool = main.fps_shot_count == 1 and main.fps_burst_rounds_remaining == 0 and not main.fps_trigger_down
	if not pause_pass: failures += 1
	print("FIRE_PAUSE_CANCELS_BURST_%s shots=%d remaining=%d" % ["PASS" if pause_pass else "FAIL",main.fps_shot_count,main.fps_burst_rounds_remaining])
	var paused_shots: int = main.fps_shot_count
	main._fire_trigger_pressed()
	var paused_fire_blocked: bool = main.fps_shot_count == paused_shots
	main._fire_trigger_released()
	main.tactical_paused = false
	if not paused_fire_blocked: failures += 1
	print("FIRE_PAUSED_INPUT_%s shots=%d" % ["PASS" if paused_fire_blocked else "FAIL",main.fps_shot_count])

	var target = main.sentries[0]
	var player_position: Vector3 = main._ground(Vector3(-1.5,0,37))
	main.squad[0].position = player_position
	target.set_process(false)
	main._set_first_person_mode(true)
	main.fps_mouse_captured = true
	main.fps_yaw = 0.0
	main.fps_pitch = 0.0
	main._update_camera()
	await physics_frame
	var sight_origin: Vector3 = main.camera.global_position
	var sight_forward: Vector3 = -main.camera.global_transform.basis.z.normalized()
	var aim_center: Vector3 = sight_origin+sight_forward*16.0
	target.position = Vector3(aim_center.x,aim_center.y-0.91,aim_center.z)
	var aim_delta: Vector3 = target.position+Vector3.UP*0.91-sight_origin
	main.fps_yaw = atan2(-aim_delta.x,-aim_delta.z)
	main.fps_pitch = atan2(aim_delta.y,Vector2(aim_delta.x,aim_delta.z).length())
	main._update_camera()
	await physics_frame
	await physics_frame
	var health_before: float = target.health
	main._resolve_hitscan()
	var hit_pass: bool = target.health < health_before
	if not hit_pass: failures += 1
	print("FIRE_HITSCAN_%s health_before=%.1f health_after=%.1f hit_count=%d muzzle=%s ejection=%s" % ["PASS" if hit_pass else "FAIL",health_before,target.health,main.fps_hit_count,str(main.fps_muzzle_attachment != null),str(main.fps_ejection_port != null)])
	var wall := StaticBody3D.new()
	wall.name = "Test-only shot blocker"
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.8,0.8,0.5)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	var muzzle_origin: Vector3 = main.fps_muzzle_attachment.global_position
	var target_point: Vector3 = target.position+Vector3.UP*0.91
	var muzzle_direction := (target_point-muzzle_origin).normalized()
	wall.position = muzzle_origin+muzzle_direction*2.0
	root.add_child(wall)
	await physics_frame
	var blocked_health: float = target.health
	main._resolve_hitscan()
	var blocked_pass: bool = is_equal_approx(target.health,blocked_health)
	if not blocked_pass: failures += 1
	print("FIRE_WALL_OCCLUSION_%s target_health=%.1f blocked_health=%.1f" % ["PASS" if blocked_pass else "FAIL",blocked_health,target.health])
	root.remove_child(wall)
	wall.free()

	var ammo_before: int = main.fps_magazine_rounds
	var shots_before: int = main.fps_shot_count
	main.fps_fire_mode = 0
	main.fps_fire_cooldown = 0.0
	main.fps_trigger_down = false
	main._fire_trigger_pressed()
	var shell_count := 0
	for effect in main.fps_transient_effects:
		if effect is RigidBody3D: shell_count += 1
	var effects_pass: bool = main.fps_shot_count == shots_before+1 and main.fps_magazine_rounds == ammo_before-1 and main.fps_muzzle_flash_clock > 0.0 and shell_count > 0
	if not effects_pass: failures += 1
	print("FIRE_SHOT_EFFECTS_%s ammo=%d muzzle_timer=%.3f shells=%d audio=%s recoil=%.3f/%.3f" % ["PASS" if effects_pass else "FAIL",main.fps_magazine_rounds,main.fps_muzzle_flash_clock,shell_count,str(main.weapon_fire_player != null),main.fps_weapon_recoil_pitch,main.fps_camera_recoil_pitch])

	root.remove_child(main)
	main.free()
	await process_frame
	print("FPS_FIRING_CHECK_%s failures=%d" % ["PASS" if failures == 0 else "FAIL",failures])
	quit(0 if failures == 0 else 2)

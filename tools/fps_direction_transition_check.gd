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
	var actor = main.squad[0]
	actor.set_process(false)
	var origin: Vector3 = actor.position
	var transitions := [
		{"name":"Left -> Right","from":Vector3.LEFT,"to":Vector3.RIGHT},
		{"name":"Right -> Left","from":Vector3.RIGHT,"to":Vector3.LEFT},
		{"name":"Left -> Forward","from":Vector3.LEFT,"to":Vector3.FORWARD},
		{"name":"Right -> Forward","from":Vector3.RIGHT,"to":Vector3.FORWARD},
		{"name":"Forward -> Left","from":Vector3.FORWARD,"to":Vector3.LEFT},
		{"name":"Forward -> Right","from":Vector3.FORWARD,"to":Vector3.RIGHT},
		{"name":"Left -> Stop","from":Vector3.LEFT,"to":Vector3.ZERO},
		{"name":"Right -> Stop","from":Vector3.RIGHT,"to":Vector3.ZERO},
		{"name":"Forward -> Stop","from":Vector3.FORWARD,"to":Vector3.ZERO},
		{"name":"Backward -> Forward","from":Vector3.BACK,"to":Vector3.FORWARD},
		{"name":"Forward -> Backward","from":Vector3.FORWARD,"to":Vector3.BACK},
		{"name":"Diagonal -> Straight","from":(Vector3.LEFT+Vector3.FORWARD).normalized(),"to":Vector3.FORWARD}
	]
	var failures := 0
	for rate in [30,60,120]:
		var dt := 1.0/float(rate)
		for transition in transitions:
			actor.position = origin
			actor.stamina = 100.0
			actor.manual_speed_scale = 1.0
			actor.manual_move_direction = Vector3.ZERO
			actor.path.clear()
			main.fps_last_move_direction = Vector3.ZERO
			var from_direction: Vector3 = transition["from"]
			var to_direction: Vector3 = transition["to"]
			var from_position: Vector3 = actor.position
			for frame in range(roundi(0.18/dt)):
				main._set_fps_move_order(actor,from_direction,dt)
				actor._process(dt)
			var prior_travel := Vector2(actor.position.x-from_position.x,actor.position.z-from_position.z)
			var prior_alignment := prior_travel.normalized().dot(Vector2(from_direction.x,from_direction.z).normalized()) if prior_travel.length_squared() > 0.0001 else -1.0
			if to_direction == Vector3.ZERO:
				actor.path.clear()
				actor.manual_move_direction = Vector3.ZERO
				var stopped_at: Vector3 = actor.position
				for frame in range(roundi(0.15/dt)): actor._process(dt)
				var stop_delta: float = actor.position.distance_to(stopped_at)
				var passed_stop: bool = stop_delta < 0.001
				var passed: bool = prior_alignment > 0.98 and passed_stop
				if not passed: failures += 1
				print("FPS_TRANSITION_%s hz=%d case=%s prior_dot=%.3f stop_delta=%.4f" % ["PASS" if passed else "FAIL",rate,transition["name"],prior_alignment,stop_delta])
				continue
			actor.path.clear()
			var switch_start: Vector3 = actor.position
			var early_position: Vector3 = switch_start
			for frame in range(roundi(0.12/dt)):
				main._set_fps_move_order(actor,to_direction,dt)
				actor._process(dt)
				if frame == maxi(0,roundi(0.06/dt)-1): early_position = actor.position
			var travel := Vector2(actor.position.x-switch_start.x,actor.position.z-switch_start.z)
			var early_travel := Vector2(early_position.x-switch_start.x,early_position.z-switch_start.z)
			var expected := Vector2(to_direction.x,to_direction.z).normalized()
			var alignment := travel.normalized().dot(expected) if travel.length_squared() > 0.0001 else -1.0
			var early_alignment := early_travel.normalized().dot(expected) if early_travel.length_squared() > 0.0001 else -1.0
			var passed := prior_alignment > 0.98 and early_alignment > 0.95 and alignment > 0.98
			if not passed: failures += 1
			print("FPS_TRANSITION_%s hz=%d case=%s prior_dot=%.3f early_dot=%.3f final_dot=%.3f" % ["PASS" if passed else "FAIL",rate,transition["name"],prior_alignment,early_alignment,alignment])
	# Probe a steep/blocked segment that previously fell back to A* and began by
	# steering back toward the start-cell center before following player input.
	var blocked_position := Vector3(-7.49,0.0,-25.51)
	actor.position = main._ground(blocked_position)
	actor.path.clear()
	actor.manual_move_direction = Vector3.ZERO
	var blocked_start: Vector3 = actor.position
	for frame in range(18):
		main._set_fps_move_order(actor,Vector3.LEFT,1.0/60.0)
		actor._process(1.0/60.0)
	var blocked_delta := Vector2(actor.position.x-blocked_start.x,actor.position.z-blocked_start.z)
	var blocked_dot := blocked_delta.normalized().dot(Vector2.LEFT) if blocked_delta.length_squared() > 0.0001 else 1.0
	var blocked_pass := blocked_delta.length_squared() < 0.0001 or blocked_dot > 0.95
	if not blocked_pass: failures += 1
	print("FPS_BLOCKED_SEGMENT_%s moved=(%.3f,%.3f) input_dot=%.3f residual_path=%d" % ["PASS" if blocked_pass else "FAIL",blocked_delta.x,blocked_delta.y,blocked_dot,actor.path.size()])
	print("FPS_DIRECTION_CHECK_%s failures=%d transitions=%d rates=30,60,120" % ["PASS" if failures == 0 else "FAIL",failures,transitions.size()*3])
	root.remove_child(main)
	main.free()
	await process_frame
	quit(0 if failures == 0 else 2)

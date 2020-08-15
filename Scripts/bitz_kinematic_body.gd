extends KinematicBody
class_name BitzKinematicBody


var floor_velocity = Vector3()
var floor_normal = Vector3()
var on_floor = false
var on_wall = false
var on_ceiling = false
var current_collision = KinematicCollision
var target_speed = 1.0

export(float, 0, 90, 1) var MAX_SLOPE_ANGLE = 40
export(float, 0, 90, 1) var MAX_CEILING_ANGLE = 40
export(float, 0, 90, 1) var MAX_STEP_ANGLE = 7.0

var cos_slope = 0.707
var cos_ceil = 0.707

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cos_slope = cos(deg2rad(MAX_SLOPE_ANGLE))
	cos_ceil = cos(deg2rad(180 + MAX_CEILING_ANGLE))


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass

func get_floor_normal():
	return floor_normal

func get_floor_velocity():
	return floor_velocity

func is_on_ceiling():
	return on_ceiling


func is_on_floor():
	return on_floor


func is_on_wall():
	return on_wall

func get_collision():
	return current_collision

func apply_velocity_with_prediction(delta, vel, scope = 1.0):
	var future_col = move_and_collide(vel * scope * delta, true, false, true)
	if (!future_col):
		return move_and_slide_kinematic_with_prediction(
			vel, global_transform.basis.y, -global_transform.basis.z,
			8, 0.05, 
			MAX_SLOPE_ANGLE, MAX_CEILING_ANGLE, 
			false, true, true
		)
	else:
		if future_col.normal.dot(global_transform.basis.y) >= cos(deg2rad(45.0)):
			var correction_motion = vel.length()*vel.slide(future_col.normal).normalized()
			var v_a = vel
			var v_b = move_and_slide_kinematic_with_prediction(
				correction_motion, future_col.normal, -global_transform.basis.z,
				8, 0.05, 
				MAX_SLOPE_ANGLE, MAX_CEILING_ANGLE, 
				false, true, true
			)

			return v_a.linear_interpolate(v_b, abs(vel.length()) / (target_speed * .5))
		else:
			return move_and_slide_kinematic_with_prediction(
				vel, global_transform.basis.y, -global_transform.basis.z,
				8, 0.05, 
				MAX_SLOPE_ANGLE, MAX_CEILING_ANGLE,  
				false, true, true
			)
			

func move_and_slide_kinematic(
	var lv, 
	var floor_direction = Vector3(0,1,0), 
	var foward_direction = Vector3(0,0,-1), 
	var physics_delta = get_physics_process_delta_time(), 
	var max_slides = 4, 
	var slope_stop_min_velocity = 0.05, 
	var floor_max_angle = deg2rad(45),
	var ceiling_max_angle = deg2rad(225),
	var update_floor = true,
	var update_wall = true,
	var update_ceiling = true
):
	var _cos_slope = cos(deg2rad(floor_max_angle))
	var _cos_ceil = cos(deg2rad(180 + ceiling_max_angle))
	var motion = (floor_velocity + lv) * physics_delta
	floor_velocity = Vector3.ZERO

	if update_floor:
		on_floor = false
	if update_ceiling:
		on_ceiling = false
	if update_wall:
		on_wall = false

	while(max_slides):
		var collision = move_and_collide(motion, true, false)
		current_collision = collision
		if collision:
			
			motion = collision.remainder
			floor_normal = collision.normal

			if collision.normal.dot(floor_direction) >= _cos_slope:
				if update_floor:
					on_floor = true

				floor_velocity = collision.collider_velocity

				var rel_v = lv - floor_velocity
				var hor_v = rel_v - floor_direction * floor_direction.dot(rel_v)

				if collision.get_travel().length() < 0.05 and hor_v.length() < slope_stop_min_velocity:
					var gt = get_global_transform()
					gt.origin -= collision.travel 
					set_global_transform(gt)
					return (floor_velocity - floor_direction * floor_direction.dot(floor_velocity))

			elif collision.normal.dot(floor_direction) < _cos_slope and collision.normal.dot(floor_direction) > _cos_ceil and sqrt(lv.length_squared()) > slope_stop_min_velocity:
				if update_wall:
					on_wall = true	

					var d = collision.normal.dot(lv)
					if (d < _cos_ceil or d > _cos_slope):
						lv = lerp(lv, Vector3.ZERO, 0.1)
						break
			
			elif collision.normal.dot(floor_direction) <= _cos_ceil:
				if update_ceiling:
					on_ceiling = true

			var n = collision.normal
			motion = motion.slide(n)
			lv = lv.slide(n)
		else:
			break

		max_slides -= 1
		if motion.length() == 0:
			break

	return lv


func move_and_slide_kinematic_with_prediction(
	var lv = Vector3.ZERO, 
	var floor_direction = Vector3(0,1,0), 
	var foward_direction = Vector3(0,0,-1),  
	var max_slides = 4, 
	var slope_stop_min_velocity = 0.05, 
	var floor_max_angle = deg2rad(45),
	var ceiling_max_angle = deg2rad(225),
	var update_floor = true,
	var update_wall = true,
	var update_ceiling = true
):
	var physics_delta = get_physics_process_delta_time()
	var _cos_slope = cos(deg2rad(floor_max_angle))
	var _cos_ceil = cos(deg2rad(180 + ceiling_max_angle))
	var motion = (floor_velocity + lv) * physics_delta
	floor_velocity = Vector3.ZERO

	if update_floor:
		on_floor = false
	if update_ceiling:
		on_ceiling = false
	if update_wall:
		on_wall = false

	while(max_slides):
		var collision
		var future_collision = move_and_collide(motion, true, false, true)
		var invalid_floor = false

		while !invalid_floor:
			if future_collision:
				if future_collision.normal.dot(floor_direction) >= _cos_slope and max_slides:
					var v_a = (floor_velocity + lv)
					var v_b = v_a.length() * v_a.slide(future_collision.normal).normalized()
					motion = v_a.linear_interpolate(v_b, abs(v_a.length()) / (target_speed * .5)) * physics_delta
					future_collision = move_and_collide(motion, true, false, true)
					max_slides -= 1
				else:
					invalid_floor = true
			else:
				invalid_floor = true
				
		collision = move_and_collide(motion, true, false)

		if collision:
			current_collision = collision
			motion = collision.remainder
			floor_normal = collision.normal

			if collision.normal.dot(floor_direction) >= _cos_slope:
				if update_floor:
					on_floor = true

				floor_velocity = collision.collider_velocity

				var rel_v = lv - floor_velocity
				var hor_v = rel_v - floor_direction * floor_direction.dot(rel_v)

				if collision.get_travel().length() < 0.05 and hor_v.length() < slope_stop_min_velocity:
					var gt = get_global_transform()
					gt.origin -= collision.travel 
					set_global_transform(gt)
					return (floor_velocity - floor_direction * floor_direction.dot(floor_velocity))

			elif collision.normal.dot(floor_direction) < _cos_slope and collision.normal.dot(floor_direction) > _cos_ceil and sqrt(lv.length_squared()) > slope_stop_min_velocity:
				if update_wall:
					on_wall = true	

					var d = collision.normal.dot(lv)
					if (d < _cos_ceil or d > _cos_slope):
						lv = lerp(lv, Vector3.ZERO, 0.1)
						break
			
			elif collision.normal.dot(floor_direction) <= _cos_ceil:
				if update_ceiling:
					on_ceiling = true

			var n = collision.normal
			motion = motion.slide(n)
			lv = lv.slide(n)
		else:
			break

		max_slides -= 1
		if motion.length() == 0:
			break

	return lv


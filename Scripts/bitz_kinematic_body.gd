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
	# Test collision in the future
	var future_col = move_and_collide(vel * scope * delta, true, false, true)

	if !future_col:
		# We didn't hit anything, just move like normal
		return move_and_slide_kinematic_with_prediction(
			vel, global_transform.basis.y,
			8, 0.05, 
			MAX_SLOPE_ANGLE, MAX_CEILING_ANGLE, 
			false, true, true
		)
	else:
		# We do hit something in the future. Handle before hand
		if future_col.normal.dot(global_transform.basis.y) >= cos_slope:
			# Happens to be a valid floor so we compesate to avoid physical slow downs

			# Adjust motion to be parralel to the future collision normal
			var correction_motion = vel.length()*vel.slide(future_col.normal).normalized()
			var v_a = vel
			var v_b = move_and_slide_kinematic_with_prediction(
				correction_motion, future_col.normal,
				8, 0.05, 
				MAX_SLOPE_ANGLE, MAX_CEILING_ANGLE, 
				false, true, true
			)

			# Don't snap to the future velocity as that may dislodge the player from the floor.
			# Ease into it as the player gains speed where such prediction will actually be helpful
			return v_a.linear_interpolate(v_b, abs(vel.length()) / (target_speed * .5))
		else:
			# Wasn't a valid floor. Don't compesate and move normally
			return move_and_slide_kinematic_with_prediction(
				vel, global_transform.basis.y,
				8, 0.05, 
				MAX_SLOPE_ANGLE, MAX_CEILING_ANGLE,  
				false, true, true
			)
			

func move_and_slide_kinematic(
	var lv, 
	var floor_direction = Vector3(0,1,0), 
	var max_slides = 4, 
	var slope_stop_min_velocity = 0.05, 
	var floor_max_angle = 45,
	var ceiling_max_angle = 225,
	var update_floor = true,
	var update_wall = true,
	var update_ceiling = true
):
	var _target_speed = target_speed
	var physics_delta = get_physics_process_delta_time()
	var _cos_slope = cos(deg2rad(floor_max_angle))
	var _cos_ceil = cos(deg2rad(180 + ceiling_max_angle))
	var motion = (floor_velocity + lv) * physics_delta
	floor_velocity = Vector3.ZERO

	# Reset player collision states if we want to properly update them later
	if update_floor:
		on_floor = false
	if update_ceiling:
		on_ceiling = false
	if update_wall:
		on_wall = false

	# Loop collision checking with max slide amount for continous collision
	while(max_slides):

		# Idmeddiately move our player
		var collision = move_and_collide(motion, true, false)
		current_collision = collision

		if collision:
			# Update for any possible future collisions and for value retrievals
			motion = collision.remainder
			floor_normal = collision.normal

			if collision.normal.dot(floor_direction) >= _cos_slope:
				# We're on the floor!
				if update_floor:
					on_floor = true

				floor_velocity = collision.collider_velocity

				var rel_v = lv - floor_velocity
				var hor_v = rel_v - floor_direction * floor_direction.dot(rel_v)

				# TBH, I don't know what this does. Just translated from the source code of GODOT
				if collision.get_travel().length() < 0.05 and hor_v.length() < slope_stop_min_velocity:
					var gt = get_global_transform()
					gt.origin -= collision.travel 
					set_global_transform(gt)
					return get_clamped_vector3((floor_velocity - floor_direction * floor_direction.dot(floor_velocity)), _target_speed)

			elif collision.normal.dot(floor_direction) < _cos_slope and collision.normal.dot(floor_direction) > _cos_ceil and sqrt(lv.length_squared()) > slope_stop_min_velocity:
				# We're hitting a wall
				if update_wall:
					on_wall = true	

					# Dot test for wall sliding
					var d = collision.normal.dot(lv)

					# If we're not within the tolerants set by are wall/ceiling values, we don't slide but instead nullify our velocity.
					# This prevents velocity accumulation on walls which would shoot our player instantaneous the moment we reach the corners of walls
					if (d < _cos_ceil or d > _cos_slope):
						# Add a bit of interpolation for a small chance of recovery then break from the while loop
						lv = lerp(lv, Vector3.ZERO, 0.25) #0.1 was the original value
						break
			
			elif collision.normal.dot(floor_direction) <= _cos_ceil:
				# We're hitting a ceiling
				if update_ceiling:
					on_ceiling = true

			# Update motion for the next set of collisions		
			var n = collision.normal
			motion = motion.slide(n)
			lv = lv.slide(n)

		else:
			# We had absolutely no collisions occur, save resources by breaking loop
			break

		# Decrement max slides by 1 so that we don't get stuck in the future
		max_slides -= 1

		# If we have no speed, why do any collision checks? just break the loop and stick with the last set of info in that case
		if motion.length() == 0:
			break

	# DONE!! ^w^ 
	# Give the user their new velocity back for feedback looping and future usage
	return get_clamped_vector3(lv, _target_speed)


func move_and_slide_kinematic_with_prediction(
	var lv = Vector3.ZERO, 
	var floor_direction = Vector3(0,1,0), 
	var max_slides = 4, 
	var slope_stop_min_velocity = 0.05, 
	var floor_max_angle = 45,
	var ceiling_max_angle = 225,
	var update_floor = true,
	var update_wall = true,
	var update_ceiling = true
):
	var _target_speed = target_speed
	var physics_delta = get_physics_process_delta_time()
	var _cos_slope = cos(deg2rad(floor_max_angle))
	var _cos_ceil = cos(deg2rad(180 + ceiling_max_angle))
	var motion = (floor_velocity + lv) * physics_delta
	floor_velocity = Vector3.ZERO

	# Reset player collision states if we want to properly update them later
	if update_floor:
		on_floor = false
	if update_ceiling:
		on_ceiling = false
	if update_wall:
		on_wall = false

	# Loop collision checking with max slide amount for continous collision
	while max_slides:
		var future_collision = move_and_collide(motion, true, false, true) # Perform test collision first for prediction
		var invalid_floor = false

		# Second loop of collision for predictions only
		while !invalid_floor and max_slides:
			if future_collision:
				if future_collision.normal.dot(floor_direction) >= _cos_slope and max_slides:
					# We have made contact with a valid floor in the future given the floor_max_angle provided
					var v_a = (floor_velocity + lv)
					var v_b = v_a.length() * v_a.slide(future_collision.normal).normalized()

					# Interpolate between the current velocity and the future velocity as we increase in speed
					motion = v_a.linear_interpolate(v_b, abs(v_a.length()) / (target_speed * .5)) * physics_delta

					# Keep making a future collision checks with the newly calculated motion instead until we don't hit a valid floor
					future_collision = move_and_collide(motion, true, false, true)

					# Decrement max slides by 1 so that we don't get stuck in the future
					max_slides -= 1
				else:
					# We didn't hit a valid floor in the future. Could be a wall or ceiling but we don't care here. Just set the flag to exit the loop
					invalid_floor = true
			else:
				# We didn't hit anything in the future. Set the flag to exit the loop
				invalid_floor = true
			
		# We alreay did the future check collision. Actually move with the newly calculated motion now
		var collision = move_and_collide(motion, true, false)

		if collision:
			# Update for any possible future collisions and for value retrievals
			current_collision = collision
			motion = collision.remainder
			floor_normal = collision.normal

			if collision.normal.dot(floor_direction) >= _cos_slope:
				# We're on the floor!
				if update_floor:
					on_floor = true

				floor_velocity = collision.collider_velocity

				var rel_v = lv - floor_velocity
				var hor_v = rel_v - floor_direction * floor_direction.dot(rel_v)

				# TBH, I don't know what this does. Just translated from the source code of GODOT
				if collision.get_travel().length() < 0.05 and hor_v.length() < slope_stop_min_velocity:
					var gt = get_global_transform()
					gt.origin -= collision.travel 
					set_global_transform(gt)
					return get_clamped_vector3((floor_velocity - floor_direction * floor_direction.dot(floor_velocity)), _target_speed)

			elif collision.normal.dot(floor_direction) < _cos_slope and collision.normal.dot(floor_direction) > _cos_ceil and sqrt(lv.length_squared()) > slope_stop_min_velocity:
				# We're hitting a wall
				if update_wall:
					on_wall = true	

					# Dot test for wall sliding
					var d = collision.normal.dot(lv)

					# If we're not within the tolerants set by are wall/ceiling values, we don't slide but instead nullify our velocity.
					# This prevents velocity accumulation on walls which would shoot our player instantaneous the moment we reach the corners of walls
					if (d < _cos_ceil or d > _cos_slope):
						# Add a bit of interpolation for a small chance of recovery then break from the while loop
						lv = lerp(lv, Vector3.ZERO, 0.25) #0.1 was the original value
						break
			
			elif collision.normal.dot(floor_direction) <= _cos_ceil:
				# We're hitting a ceiling
				if update_ceiling:
					on_ceiling = true


			# Update motion for the next set of collisions
			var n = collision.normal
			motion = motion.slide(n)
			lv = lv.slide(n)
		else:
			# We had absolutely no collisions occur, save resources by breaking loop
			break

		# Decrement max slides by 1 so that we don't get stuck in the future
		max_slides -= 1

		# If we have no speed, why do any collision checks? just break the loop and stick with the last set of info in that case
		if motion.length() == 0:
			break

	# DONE!! ^w^ 
	# Give the user their new velocity back for feedback looping and future usage
	return get_clamped_vector3(lv, _target_speed)


func step_up_stair(var lv = Vector3.ZERO, var up_direction = Vector3(0,1,0), var step_max_angle = 5):
	var physics_delta = get_physics_process_delta_time()
	var _cos_step = cos(deg2rad(step_max_angle))
	var motion = lv * physics_delta

	var future_collision = move_and_collide(motion, true, false, true) # Perform test collision first for prediction

	if future_collision:
		if future_collision.normal.dot(up_direction) >= _cos_step:
			var step_distance = 0
			#print(future_collision.normal)
	return motion


func get_clamped_vector3(vector, maxLength):
	var sqrmag = vector.length_squared()
	if sqrmag > maxLength * maxLength:
		var mag = sqrt(sqrmag)

		# these intermediate variables force the intermediate result to be
		# of float precision. without this, the intermediate result can be of higher
		# precision, which changes behavior.
		var normalized_x = vector.x / mag
		var normalized_y = vector.y / mag
		var normalized_z = vector.z / mag

		return Vector3(
			normalized_x * maxLength,
			normalized_y * maxLength,
			normalized_z * maxLength
		);
	
	return vector;


func linecast(var start, var direction, var line_length = 1.0, var ignore_self = true):
	var ignoredNodes = []
	if ignore_self:
		ignoredNodes.append(self)
		
	return get_world().direct_space_state.intersect_ray(start, start + (direction * line_length), ignoredNodes)


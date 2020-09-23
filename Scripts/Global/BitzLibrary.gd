extends Node


func get_capsule_basis(var shape, dir, length = 1, offset = Vector3(0, 0, 0)):
	return shape.transform.origin + (get_cshape_radius(shape) * (dir * length)) + offset


func get_cshape_half_height(var shape) -> float:
	return shape.get_shape().get_height()


func get_cshape_radius(var shape) -> float:
	return shape.get_shape().get_radius()


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


func linecast(var world, var start, var direction, var line_length = 1.0, var ignore_self = true, var debug_cast = false, var debug_time = 0.0):
	var _p1 = start
	var _p2 = start + (direction * line_length)
	var ignoredNodes = []

	if ignore_self:
		ignoredNodes.append(self)
	if debug_cast:
		DrawLine3d.DrawLine(_p1, _p2, Color.darkviolet, debug_time + 0.01, 1)

	return world.direct_space_state.intersect_ray(_p1, _p2, ignoredNodes)


func radial_multicast(var world, var center, var forward, var direction, var count = 8, var radius = 1.0, var line_length = 1.0, var ignore_self = true, var debug_cast = false):
	var _deltaTheta = (2 * PI) / count
	var _rays = []

	for n in count:
		var xx = direction.cross(forward).normalized() * (cos(_deltaTheta * n) * radius)
		var yy = forward * (sin(_deltaTheta * n) * radius)
		_rays.append(linecast(world, center + xx + yy, direction, line_length, ignore_self, debug_cast))

	return _rays


func apply_input_to_velocity(DeltaTime, input_vect, vect, Acceleration, Deacceleration, TurnBoost, TargetSpeed):
	var temp_vec = vect
	var ControlAcceleration = get_clamped_vector3(input_vect, 1.0)
	var AnalogInputModifier = (ControlAcceleration.length() if ControlAcceleration.length_squared() > 0.0 else 0.0)
	var MaxPawnSpeed = TargetSpeed * AnalogInputModifier
	var bExceedingMaxSpeed = (true if temp_vec.length() >= TargetSpeed else false)
	
	if AnalogInputModifier > 0.0 and not bExceedingMaxSpeed:
		# Apply change in velocity direction
		if temp_vec.length_squared() > 0.0:
			# Change direction faster than only using acceleration, but never increase velocity magnitude.
			var TimeScale = clamp(DeltaTime * TurnBoost, 0.0, 1.0)
			temp_vec = temp_vec + (ControlAcceleration * temp_vec.length() - temp_vec) * TimeScale * DeltaTime * Deacceleration
	else:
		# Dampen velocity magnitude based on deceleration.
		if temp_vec.length_squared() > 0.0:
			var OldVelocity = temp_vec
			var VelSize = max(temp_vec.length() - abs(Deacceleration) * DeltaTime, 0.0)
			temp_vec = temp_vec.normalized() * VelSize

			# Don't allow braking to lower us below max speed if we started above it.
			if bExceedingMaxSpeed and temp_vec.length_squared() < pow(MaxPawnSpeed, 2):
				temp_vec = OldVelocity.normalized() * MaxPawnSpeed

	# Apply acceleration and clamp velocity magnitude.
	var NewMaxSpeed = (temp_vec.length() if bExceedingMaxSpeed else TargetSpeed)
	temp_vec += ControlAcceleration * abs(Acceleration) * DeltaTime
	return get_clamped_vector3(temp_vec, NewMaxSpeed)


func velocity_deacceleration(DeltaTime, Deacceleration, vec):
	if vec.length_squared() > 0.0:
		var VelSize = max(vec.length() - abs(Deacceleration) * DeltaTime, 0.0);
		vec = vec.normalized() * VelSize;
	return vec
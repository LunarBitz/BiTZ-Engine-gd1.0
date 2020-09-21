extends "res://Scripts/bitz_kinematic_body.gd"

enum RayCastMode{
	SINGLE,
	DOUBLES,
}

var player_input = preload("player_input_class.gd").new([],[])

const EPSILON = 0.0001
var normal_get_state = RayCastMode
var mouse_sens = 0.3
var camera_anglev = 0
export(float, -19.62, -0.01, 0.01) var GRAVITY = -9.81
var gravity_scalar = 0.0
var speed_scalar = 0.0
var grv_rst = true
var smooth_speed_scalar = 0.0
var target_input_vector = Vector3()
var raw_input_vector = Vector3()

var gravity_vel = Vector3()
var movement_vel = Vector3()
var composite_vel = Vector3()

var pitch_transform: Transform
var roll_transform: Transform
var velocity_direction = Vector3()

export(float, 1, 100, 1) var MAX_SPEED = 20
export(float, 1, 64, 1) var JUMP_SPEED = 18
export(float, 1, 16, 0.25) var ACCEL = 2.7*2
export(float, 1, 16, 0.25) var DEACCEL = 5.4*2
var direction = Vector3()
var floor_rays = {
	"Center": Object(),
	"Front": Object(),
	"Back": Object(),
	"Left": Object(),
	"Right": Object(),
}
var floor_normals = {
	"Center": Vector3(0, 1, 0),
	"Front": Vector3(0, 1, 0),
	"Back": Vector3(0, 1, 0),
	"Left": Vector3(0, 1, 0),
	"Right": Vector3(0, 1, 0),
}
var average_normal = Vector3()
var player_basis = Basis()

#export(float, 0, 90, 1) var MAX_SLOPE_ANGLE = 40
#export(float, 0, 90, 1) var MAX_CEILING_ANGLE = 40
#export(float, 0, 90, 1) var MAX_STEP_ANGLE = 7.0


func _ready():
	self.target_speed = MAX_SPEED
	normal_get_state = RayCastMode.DOUBLES
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	for ray in $Rays.get_children():
		if ray.get_class() == "RayCast":
			ray.set_cast_to(Vector3(0, -1.5, 0))
		
			
	floor_rays["Snap"] = $Rays/RaycastSnap
	floor_rays["Center"] = $Rays/RaycastCenter
	floor_rays["Front"] = $Rays/RaycastFront
	floor_rays["Back"] = $Rays/RaycastBack
	floor_rays["Left"] = $Rays/RaycastLeft
	floor_rays["Right"] = $Rays/RaycastRight
	floor_rays["Snap"].set_cast_to(Vector3(0, -0.25, 0))

func get_capsule_basis(dir, length = 1, offset = Vector3(0, 0, 0)):
	return $CollisionShape.transform.origin + ($CollisionShape.get_shape().get_radius() * (dir * length)) + offset
	
	
func get_capsule_bottom():
	return $CollisionShape.get_shape().get_height()#$CollisionShape.transform.origin + $CollisionShape.get_shape().get_height() + ($CollisionShape2.get_shape().get_length())

func get_capsule_half_height():
	return $CollisionShape.get_shape().get_height()

func _physics_process(delta):
	process_input()
	process_movement(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		player_input.input_axis["mouse_yaw"] = event.relative.x
		player_input.input_axis["mouse_pitch"] = event.relative.y
		

func process_input():
	# ----------------------------------
	# Walking
	direction = Vector3()

	player_input.input_axis["movement_forward"] = Input.get_action_strength("player_move_backward") - Input.get_action_strength("player_move_forward")
	player_input.input_axis["movement_side"] = Input.get_action_strength("player_move_right") - Input.get_action_strength("player_move_left")

	raw_input_vector = Vector3(player_input.input_axis["movement_side"], 0, player_input.input_axis["movement_forward"]).normalized()
	target_input_vector = target_input_vector.linear_interpolate(raw_input_vector, 0.1)

	# Basis vectors are already normalized.
	var target_q = global_transform.basis.get_rotation_quat() * Quat(Vector3(0.0, $SpringArm.rotation.y, 0.0))
	#  
	direction = target_q.xform(raw_input_vector).normalized()

	# ----------------------------------

	# ----------------------------------
	
	
	# Jumping
	#if is_on_floor():
		#if Input.is_action_just_pressed("movement_jump"):
			#vel.y = JUMP_SPEED
	# ----------------------------------

	# ----------------------------------
	# Capturing/Freeing the cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# ----------------------------------
	get_node("SpringArm").player_input = player_input

	linecast(global_transform.origin, target_input_vector, 10)


func process_movement(delta):
	handle_gravity(delta)
	align_to_floor()
	rotate_mesh_to_velocity(delta)
	
	movement_vel = apply_input_to_velocity(delta, direction, movement_vel, ACCEL, DEACCEL, 5.0, MAX_SPEED)
	
	movement_vel = apply_velocity_with_prediction(delta, movement_vel)
	# With the predicted velocity, it's possible to get stuck at max speed even when no input is pressed
	# This forces deacceleration only when the player is above the max speed
	if abs(movement_vel.length()) >= MAX_SPEED - (MAX_SPEED / 10) and !raw_input_vector:
		pass#movement_vel = velocity_deacceleration(delta, DEACCEL, movement_vel)
	"""
	movement_vel = move_and_slide_kinematic(
		movement_vel, average_normal,
		8, 0.05, 
		MAX_SLOPE_ANGLE, MAX_CEILING_ANGLE, 
		false, true, true
	)
	"""

	
	
	
	gravity_vel = move_and_slide_kinematic(
		gravity_vel, average_normal,
		4, 0.05, 
		MAX_STEP_ANGLE, MAX_STEP_ANGLE, 
		true, false, false
	)
		#movement_vel
		#-global_transform.basis.z
	var vvv = step_up_stair(movement_vel, global_transform.basis.y, 5)
	
	composite_vel = movement_vel + gravity_vel
	var f_s = "\n|%10s|-|%10s|-|%10s|"
	get_node("SpringArm").player_velocity = composite_vel
	$RichTextLabel.text = "\n%-10s: %-10s" % ["FPS", Engine.get_frames_per_second()]
	$RichTextLabel.text += f_s % ["On_Floor", "On_Wall", "On_Ceil"]\
		+ f_s % [is_on_floor(), is_on_wall(), is_on_ceiling()] + "\n"
	$RichTextLabel.text += "\n%-10s: %-10s\n%-10s: %-4.2f\n%-10s: %-10s" % ["Velocity", movement_vel, "Speed", abs(movement_vel.length()), "Target", MAX_SPEED]
	#$RichTextLabel.text += "\n%-10s: %-10s" % ["Up Dir", global_transform.basis.y]

func handle_gravity(delta):
	var override_force
	var valid_gravity

	if floor_rays["Snap"]:
		override_force = floor_rays["Snap"].is_colliding()
		valid_gravity = floor_rays["Snap"].is_colliding()  #&& is_walkable(floor_rays["Snap"].get_collision_normal())

	if is_on_floor() and valid_gravity:
		grv_rst = false
		gravity_scalar = delta * (GRAVITY * ((abs(movement_vel.length()) / (MAX_SPEED * 1.0)) * 100))
	elif !is_on_floor() and valid_gravity:
		grv_rst = false
		transform.origin = floor_rays["Snap"].get_collision_point() + (get_capsule_half_height() * global_transform.basis.y)
	else:
		if !grv_rst:
			if !override_force:
				gravity_scalar = 0.0
			grv_rst = true
		if !override_force and !valid_gravity:
			var terminal_speed = ((2 * 100 * (abs(GRAVITY) * 10.0)) / (0.33 * 2488.53 * 0.5))
			gravity_scalar += delta * GRAVITY
			gravity_scalar = clamp(gravity_scalar, -terminal_speed, terminal_speed)
		
	gravity_vel = global_transform.basis.y * gravity_scalar


func Reset_Gravity_Acceleration(new_acc = 0.0, reset = true):
	if reset:
		grv_rst = false;
		
	gravity_scalar = new_acc
	
	if reset:
		gravity_vel = Vector3.ZERO


func is_walkable(vec):
	return true if vec.dot(global_transform.basis.y) >= cos_slope else false
	

func align_to_floor():

	if normal_get_state == RayCastMode.SINGLE:
		if floor_rays.has("Center"):
			# Center Ray
			update_ray_normal("Center", deg2rad(MAX_SLOPE_ANGLE))
			average_normal = floor_normals["Center"]
			pitch_transform = get_y_align(global_transform, average_normal)

		# Combine and apply transforms	
		global_transform = global_transform.interpolate_with(pitch_transform, 0.1)

	elif normal_get_state == RayCastMode.DOUBLES:
		# Calculate Pitch
		if floor_rays.has_all(["Front", "Back"]):
			# Front-Back Ray
			update_raypair_normal(["Front", "Back"], deg2rad(MAX_SLOPE_ANGLE))
				
			var forward_normal = (floor_normals["Front"] + floor_normals["Back"]).normalized()
			average_normal += forward_normal
			pitch_transform = get_y_align(global_transform, forward_normal)
		
		# Calculate Roll
		if floor_rays.has_all(["Left", "Right"]):
			# Left-Right Ray
			update_raypair_normal(["Left", "Right"], deg2rad(MAX_SLOPE_ANGLE))
			
			var side_normal = (floor_normals["Left"] + floor_normals["Right"]).normalized()
			average_normal += side_normal
			roll_transform = get_y_align(global_transform, side_normal)

		average_normal = average_normal.normalized()

		# Combine and apply transforms	
		global_transform = global_transform.interpolate_with(pitch_transform, 0.1)
		global_transform = global_transform.interpolate_with(roll_transform, 0.1)


func update_raypair_normal(ray_pair, max_angle = 40, default_value = Vector3.UP):
	var cos_slope = cos(max_angle + EPSILON)

	# Ray 1
	var v1t = default_value
	if floor_rays[ray_pair[0]].is_colliding():
		v1t = floor_rays[ray_pair[0]].get_collision_normal() if floor_rays[ray_pair[0]].get_collision_normal().dot(global_transform.basis.y) >= cos_slope else default_value
	elif floor_rays[ray_pair[1]].is_colliding() and not floor_rays[ray_pair[0]].is_colliding():
		v1t = floor_rays[ray_pair[1]].get_collision_normal() if floor_rays[ray_pair[1]].get_collision_normal().dot(global_transform.basis.y) >= cos_slope else default_value
	else:
		v1t = default_value
	floor_normals[ray_pair[0]] = lerp(floor_normals[ray_pair[0]], v1t, 0.5)

	# Ray 2
	var v2t = default_value
	if floor_rays[ray_pair[1]].is_colliding():
		v2t = floor_rays[ray_pair[1]].get_collision_normal() if floor_rays[ray_pair[1]].get_collision_normal().dot(global_transform.basis.y) >= cos_slope else default_value
	elif floor_rays[ray_pair[0]].is_colliding() and not floor_rays[ray_pair[1]].is_colliding():
		v2t = floor_rays[ray_pair[1]].get_collision_normal() if floor_rays[ray_pair[0]].get_collision_normal().dot(global_transform.basis.y) >= cos_slope else default_value
	else:
		v2t = default_value
	floor_normals[ray_pair[1]] = lerp(floor_normals[ray_pair[1]], v2t, 0.5)


func update_ray_normal(ray, max_angle = 40, default_value = Vector3.UP):
	var cos_slope = cos(max_angle + EPSILON)

	var v1t = default_value
	if floor_rays[ray]:
		if floor_rays[ray].is_colliding():
			v1t = floor_rays[ray].get_collision_normal() if floor_rays[ray].get_collision_normal().dot(global_transform.basis.y) >= cos_slope else default_value
		else:
			v1t = default_value
		floor_normals[ray] = lerp(floor_normals[ray], v1t, 0.5)


func get_y_align(base_transform, normal):
	base_transform.basis.y = normal
	base_transform.basis.x = -base_transform.basis.z.cross(normal)
	base_transform.basis = base_transform.basis.orthonormalized()
	
	return base_transform


func rotate_mesh_to_velocity(delta):	
	var arc_tan_2 = atan2(-target_input_vector.x, -target_input_vector.z)
	var target_angle = (arc_tan_2 - rotation.y + $SpringArm.rotation.y)
	var u_f = (deg2rad(-180.0) if global_transform.basis.y.y <= -0.001 else 0.0)
	var up_fix = u_f if sign(global_transform.basis.y.y) == -1 and abs(global_transform.basis.y.z)>0.0+EPSILON else 0.0

	$HelperVel.rotation.y = target_angle + up_fix
	velocity_direction = -$HelperVel.transform.basis.z

	if movement_vel.length_squared() >= delta:
		$VisualMesh.rotation.y = lerp_angle($VisualMesh.rotation.y, target_angle + up_fix, delta * 8.0)


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

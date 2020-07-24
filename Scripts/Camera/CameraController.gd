extends Spatial

var player_input = "f"
var player_velocity = Vector3()
export(float, 1, 256, 1) var max_lag_offset = 256.0
export(float, 1, 100, 0.1) var position_lag_speed = 50.0

export(NodePath) var target_parent_path
onready var target_parent = get_node(target_parent_path)


func _ready() -> void:
	pass # Replace with function body.


func _physics_process(delta: float) -> void:
	if target_parent != null:
		var camera_socket = target_parent.global_transform.basis.z * target_parent.spring_length

		var pos_lag = player_velocity * max_lag_offset * delta * delta
		global_transform.origin = global_transform.origin.linear_interpolate(target_parent.global_transform.origin + camera_socket + pos_lag, 1 / position_lag_speed)
		#$h.rotation_degrees.y = lerp($h.rotation_degrees.y, camrot_h, delta * h_acceleration)
		
	pass


func handle_clipping(delta: float):
	# Cast ray from camera to player
	# If ray hit
		# Get clipping distance
		# Lerp camera offest value to distance if small value
		## Instant set if big value
	pass

	

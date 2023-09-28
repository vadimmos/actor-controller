extends RigidBody3D
class_name Actor

@export var move_acceleration: float = 800
@export var jump_acceleration: float = 400
@export var air_control: float = 400

@export_range(15, 120, 1) var turning_scale : float = 45


@export var max_duck_speed: float = 1
@export var max_crouch_speed: float = 2
@export var max_walk_speed: float = 3
@export var max_sprint_speed: float = 4
@export var max_run_speed: float = 5

@export var allways_sprint: bool = true

@export var crouching_speed: float = 10

@export_range(0.1,100,0.1) var anti_slide_force : float = 4

@export_range(0, 1, 0.01) var walkable_normal : float = 0.35

@onready var neck: Node3D = $neck 
@onready var head: Node3D = $neck/head
@onready var body = $body
@onready var body_shape = $body.shape

var direction = Vector3()
var neck_offset: float
var normal_height: float
var normal_body_pos_y: float
var crouching_height: float:
	get: return normal_height/2
var ducking_height: float :
	get: return normal_height/4
var pose
enum { DUCK, CROUCH, WALK, RUN, SPRINT }

var _mult: float = 0.01
var _is_grounded: bool
var _current_max_speed: float
var _current_height: float
var _shrinking: bool = false
var _jumping: bool
var _jump_throttle_length: float = 0.1
var _jump_throttle: float = 0
#var _ceil_collision: bool

func _ready():
	pose = WALK
	normal_height = body_shape.height
	normal_body_pos_y = body.position.y
	neck_offset = normal_height - neck.position.y

func _physics_process(delta: float):
	neck.position.y = body_shape.height - neck_offset
	check_groundedness()
	apply_pose(delta)
	if(_jump_throttle > 0):
		_jump_throttle -= delta
	
func _integrate_forces(state):
	var upper_slope_normal = Vector3(0,1,0)
	var lower_slope_normal = Vector3(0,-1,0)
	
	var contacted_body: RigidBody3D
	var slope_normal: Vector3
	var contacted_body_vel_at_point: Vector3
	
	var shallowest_contact_index: int = -1
	if (state.get_contact_count() > 0):
		for i in state.get_contact_count():
			slope_normal = state.get_contact_local_normal(i)
			if (slope_normal.y < upper_slope_normal.y):
				upper_slope_normal = slope_normal
			if (slope_normal.y > lower_slope_normal.y):
				lower_slope_normal = slope_normal
				shallowest_contact_index = i
				
		if (is_walkable(upper_slope_normal.y)):
			_is_grounded = true
			if (shallowest_contact_index >= 0):
				var contact_position = state.get_contact_collider_position(0)
				var collisions = get_colliding_bodies()
				if (collisions.size() > 0 and collisions[0].get_class() == "RigidBody"):
					contacted_body = collisions[0]
					contacted_body_vel_at_point = get_contacted_body_velocity_at_point(contacted_body, contact_position)
		elif (!is_walkable(lower_slope_normal.y)):
			_is_grounded = false
		
	var has_walkable_contact: bool = state.get_contact_count() > 0 and is_walkable(lower_slope_normal.y)
	
	if has_walkable_contact:
		if _jumping:
			state.apply_central_impulse(Vector3(0,1,0) * jump_acceleration)
			_jumping = false
	
	
	var move = direction
	var move2 = Vector2(move.x, move.z)
	
#	set_friction(move)

	var vel = Vector3()
	if _is_grounded:
		vel = get_linear_velocity()
		vel -= contacted_body_vel_at_point
	else:
		vel = Vector3(state.get_linear_velocity().x,0,state.get_linear_velocity().z)
		vel -= Vector3(contacted_body_vel_at_point.x,0,contacted_body_vel_at_point.z)
	var nvel = vel.normalized()
	var nvel2 = Vector2(nvel.x, nvel.z)
	
	var angle = nvel2.angle_to(move2)
	var theta = rad_to_deg(angle) # Angle between 2D look and velocity vectors
	var is_below_speed_limit: bool = is_below_speed_limit(nvel,vel)
	var is_facing_velocity: bool = (nvel2.dot(move2) >= 0)
	var dir: Vector3 # vector to be set 90 degrees either to the left or right of the velocity
	var scale: float # Scaled from 0 to 1. Used for both turn assist interpolation and vector scaling
	# If the angle is to the right of the velocity
	if (theta > 0 and theta < 90):
		dir = nvel.cross(head.transform.basis.y) # Vecor 90 degrees to the right of velocity
		scale = clamp(theta/turning_scale, 0, 1) # Turn assist scale
	# If the angle is to the left of the velocity
	elif(theta < 0 and theta > -90):
		dir = head.transform.basis.y.cross(nvel) # Vecor 90 degrees to the left of velocity
		scale = clamp(-theta/turning_scale, 0, 1)
	# Prevent continuous sliding down steep walkable slopes when the player isn't moving. Could be made better with
	# debouncing because too high of a force also affects stopping distance noticeably when not on a slope.
	if (move == Vector3(0,0,0) and _is_grounded):
			move = -vel / (mass/anti_slide_force)
			apply_move(move, state, lower_slope_normal, upper_slope_normal, contacted_body)
	# If not pushing into an unwalkable slope
	elif (upper_slope_normal.y > walkable_normal):
		# If the player is below the speed limit, or is above it, but facing away from the velocity
		if (is_below_speed_limit or not is_facing_velocity):
			# Interpolate between the movement and velocity vectors, scaling with turn assist sensitivity
			move = move.lerp(dir, scale)
		# If the player is above the speed limit, and looking within 90 degrees of the velocity
		else:
			move = dir # Set the move vector 90 to the right or left of the velocity vector
			move *= scale # Scale the vector. 0 if looking at velocity, up to full magnitude if looking 90 degrees to the side.
		apply_move(move, state, lower_slope_normal, upper_slope_normal, contacted_body)
	# If pushing into an unwalkable slope, move with unscaled movement vector. Prevents turn assist from pushing the player into the wall.
	elif is_below_speed_limit:
		apply_move(move, state, lower_slope_normal, upper_slope_normal, contacted_body)




func jump():
	if (_is_grounded && _jump_throttle <= 0):
		_jumping = true
		_jump_throttle = _jump_throttle_length
	
const RAY_OFFSET: float = -0.05
const RAY_LENGHT: float = 0.1
func check_groundedness():
	var rays = Array()
	var start = RAY_OFFSET
	var cv_dist = body_shape.radius - RAY_LENGHT
	var ov_dist = cv_dist/sqrt(2)
	
	var direct_state = get_world_3d().direct_space_state
	rays.clear()
	
	for i in 9:
		var pos1 = position
		pos1.y -= start
		match i:
			0: 
				pos1.z -= cv_dist # N
			1:
				pos1.z += cv_dist # S
			2:
				pos1.x += cv_dist # E
			3:
				pos1.x -= cv_dist # W
			4:
				pos1.z -= ov_dist # NE
				pos1.x += ov_dist
			5:
				pos1.z += ov_dist # SE
				pos1.x += ov_dist	
			6:
				pos1.z -= ov_dist # NW
				pos1.x -= ov_dist
			7:
				pos1.z += ov_dist # SW
				pos1.x -= ov_dist
		var pos2 = pos1
		pos2.y -= RAY_LENGHT
		rays.append([pos1,pos2])
	_is_grounded = false
	for array in rays:
		var direct_query_parameters = PhysicsRayQueryParameters3D.create(array[0],array[1], collision_mask, [self])
		var collision = direct_state.intersect_ray(direct_query_parameters)
		if (collision and is_walkable(collision.normal.y)):
			_is_grounded = true
			break
	return _is_grounded;

func apply_pose(delta: float):
	match pose:
		DUCK:
			_current_max_speed = max_duck_speed
			_current_height = ducking_height
		CROUCH:
			_current_max_speed = max_crouch_speed
			_current_height = crouching_height
		WALK:
			_current_max_speed = max_walk_speed
			_current_height = normal_height
		SPRINT:
			_current_max_speed = max_sprint_speed
			_current_height = normal_height
		RUN:
			_current_max_speed = max_run_speed
			_current_height = normal_height
	
	shrink_body_shape_height(delta)
	grow_body_shape_height(delta)

func grow_body_shape_height(delta: float):
	if (body_shape.height < _current_height):
		var step = delta * crouching_speed
		
		var start = position + Vector3.UP * (body_shape.height + body_shape.radius)
		var end = start + Vector3.UP * step
		var ray = PhysicsRayQueryParameters3D.create(start, end, collision_mask, [self])
		var direct_state = get_world_3d().direct_space_state
		var hit = direct_state.intersect_ray(ray)
		
#		if !_ceil_collision:
		if hit.is_empty():
			body_shape.height += step
			if (body_shape.height > _current_height):
				body_shape.height = _current_height
			body.position.y = normal_body_pos_y - (normal_body_pos_y - body_shape.height/2)

func shrink_body_shape_height(delta: float):
	if (body_shape.height > _current_height):
		body_shape.height -= delta * crouching_speed
		if (body_shape.height < _current_height):
			body_shape.height = _current_height
		body.position.y = normal_body_pos_y - (normal_body_pos_y - body_shape.height/2)

func is_walkable(normal):
	return (normal >= walkable_normal)

func get_contacted_body_velocity_at_point(contacted_body: RigidBody3D, contact_position: Vector3):
	var body_position = contacted_body.transform.origin
	var global_contact_position = body_position + contact_position
	var local_vel_at_point = contacted_body.get_angular_velocity().cross(global_contact_position - body_position)
	return contacted_body.get_linear_velocity() + local_vel_at_point

#func set_friction(move):
#	player_physics_material.friction = local_friction
#	if not is_grounded:
#		player_physics_material.friction = local_friction/friction_divider

func is_below_speed_limit(nvel, vel):
	return ((nvel.x >= 0 and vel.x < nvel.x*_current_max_speed) or (nvel.x <= 0 and vel.x > nvel.x*_current_max_speed) or
		(nvel.z >= 0 and vel.z < nvel.z*_current_max_speed) or (nvel.z <= 0 and vel.z > nvel.z*_current_max_speed) or
		(nvel.x == 0 or nvel.z == 0))
		
func apply_move(move, state, lower_slope_normal, upper_slope_normal, contacted_body):
	if _is_grounded:
		var direct_state = get_world_3d().direct_space_state
		
		var start = (position - Vector3(0, -body_shape.radius, 0)) + (move * body_shape.radius)
		var end = start + Vector3.DOWN * normal_height
		var direct_query_parameters = PhysicsRayQueryParameters3D.create(start, end, 0x00000005, [self])
		var hit = direct_state.intersect_ray(direct_query_parameters)
		var use_normal: Vector3
		
		if hit and hit.normal.y < lower_slope_normal.y:
			use_normal = upper_slope_normal
		else:
			use_normal = lower_slope_normal
		
		move = cross4(move, use_normal)
		state.apply_central_force(move * move_acceleration)
		if (contacted_body != null):
			contacted_body.apply_force(move * -move_acceleration,state.get_contact_collider_position(0))
	else:
		state.apply_central_force(move * air_control)

func cross4(a,b):
	return a.cross(b).cross(b).cross(b).cross(b)

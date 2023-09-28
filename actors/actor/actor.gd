extends RigidBody3D
class_name Actor

@export var move_acceleration:float = 30
@export var move_max_speed: float = 100
@export var rotate_speed:float = 0.1

@onready var head: Node3D = $head

var head_rot_x = 0
var head_rot_y = 0

var direction = Vector3()

func move(move_vector:Vector2):
	pass

func _apply_movement(delta:float):
	linear_velocity += direction * move_acceleration * delta
	print(linear_velocity)

func _apply_rotation(delta:float):
	head.rotation.x = head_rot_x * rotate_speed * delta
	rotation.y = head_rot_y * rotate_speed * delta

func _physics_process(delta:float):
	_apply_rotation(delta)
	_apply_movement(delta)

func _integrate_forces(state:PhysicsDirectBodyState3D):
	rotation_degrees = Vector3(0,0,0)

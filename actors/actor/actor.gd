extends CharacterBody3D
class_name Actor

@export var ground_acceleration: float = 5
#@export var max_speed: float = 5
#@export var air_multiplyer: float = 0.5
@export var jump_velocity: float = 3

@onready var neck: Node3D = $neck 

var direction = Vector3()

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	if is_on_floor():
		velocity.x = direction.x * ground_acceleration
		velocity.z = direction.z * ground_acceleration
	else:
		velocity.y += -gravity * delta
		
#	velocity.x = clamp(velocity.x, 0, max_speed)
#	velocity.z = clamp(velocity.z, 0, max_speed)
	move_and_slide()
	
	

func jump():
	if is_on_floor():
		velocity.y = jump_velocity

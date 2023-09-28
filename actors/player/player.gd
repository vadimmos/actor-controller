extends Actor
class_name Player

@export var mouse_sensetive: float = 0.01

const min_camera_x_angle = deg_to_rad(-80)
const max_camera_x_angle = deg_to_rad(80)

func _process(delta):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if(Input.is_action_just_pressed("jump")):
			jump()
		direction = _get_move_input()
		pose = _get_pose()


func _get_move_input():
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return neck.transform.basis * Vector3(input.x, 0, input.y)
	
func _unhandled_input(event):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			neck.rotate_y(-event.relative.x * mouse_sensetive)
			head.rotate_x(-event.relative.y * mouse_sensetive)
			head.rotation.x = clamp(head.rotation.x, min_camera_x_angle, max_camera_x_angle)
			
func _get_pose():
	if Input.is_action_pressed("crouch") && Input.is_action_pressed("run_or_walk"):
		return DUCK
	elif Input.is_action_pressed("crouch"):
		return CROUCH
	elif Input.is_action_pressed("run_or_walk"):
		return RUN if allways_sprint else WALK
	else:
		return SPRINT if allways_sprint else WALK

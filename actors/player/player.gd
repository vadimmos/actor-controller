extends Actor
class_name Player

@export var mouse_sensetive: float = 0.01

const min_camera_x_angle = deg_to_rad(-80)
const max_camera_x_angle = deg_to_rad(80)

func _process(delta):
		if(Input.is_action_just_pressed("jump")):
			jump()
		direction = _get_move_input()


func _get_move_input():
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return transform.basis * Vector3(input.x, 0, input.y)
	
func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * mouse_sensetive)
			neck.rotate_x(-event.relative.y * mouse_sensetive)
			neck.rotation.x = clamp(neck.rotation.x, min_camera_x_angle, max_camera_x_angle)

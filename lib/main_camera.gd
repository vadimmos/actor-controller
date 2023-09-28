extends Camera3D

@export var target_path: NodePath
var target: Node3D

func _ready():
	if target_path:
		target = get_node(target_path)

func _process(delta):
	if target:
		position = target.global_position
		rotation = target.global_rotation

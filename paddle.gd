extends Area2D

@export var speed: float = 400
@export  var player_number =1 #1 for player 2 for AI
@export var is_ai: bool= false

#AI variables
var ball_reference: Node2D = null
var ai_difficulty: float = 0.8 #0.0 to 1 (higher = better AI)

func _ready ():
	#Find the ball in the scene
	ball_reference = get_tree().get_first_node_in_group("ball")	

func _process (delta):
	var input_vector =Vector2.ZERO
	
	if is_ai:
		input_vector =  get_ai_movement()
	else:
		input_vector = get_player_input()

	position += input_vector * speed * delta
	
	#keep paddle within screen bounds
	var viewport_rect =get_viewport_rect()
	position.x = clamp(position.x,50,viewport_rect.size.x -50)
	position.y = clamp(position.y,50,viewport_rect.size.y -50)
	
func get_player_input() -> Vector2:
	var input = Vector2.ZERO

	if player_number ==1:
		input.x = Input.get_axis(p1_left,p1_right)
		input.y



@export var speed: float = 400.0
@export var player_number: int = 1  # 1 = player1, 2 = player2
@export var is_ai: bool = false

# Optional: assign the ball in the editor (preferred). If left empty, script will look for the first node in the "ball" group.
@export var ball_path: NodePath
@export var use_raycast: bool = true         # Use RayCast2D to "find" the ball (detect collisions)
@export var ray_length: float = 3000.0       # Ray length used for the RayCast2D

# AI tuning
@export var ai_difficulty: float = 0.8  # 0.0 (worst) .. 1.0 (perfect)

# How tall is the paddle for hit position calculations (tweak to match your CollisionShape2D or Sprite)
@export var paddle_hit_height: float = 120.0

const VERTICAL_DEADZONE: float = 20.0
const HORIZONTAL_REACTION_THRESHOLD: float = 30.0
const RETURN_THRESHOLD: float = 10.0

var ball_reference: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var raycast: RayCast2D = null
var is_left_side: bool = false

func _ready() -> void:
	rng.randomize()

	# Prefer explicit path set in the editor
	if ball_path and str(ball_path) != "":
		ball_reference = get_node_or_null(ball_path)
	# Fallback: find first node in group "ball"
	if not ball_reference:
		var balls = get_tree().get_nodes_in_group("ball")
		if balls.size() > 0:
			ball_reference = balls[0]
		else:
			ball_reference = null

	# Setup RayCast2D if requested and this paddle will be AI
	if is_ai and use_raycast:
		raycast = $RayCast2D if has_node("RayCast2D") else null
		if not raycast:
			raycast = RayCast2D.new()
			raycast.name = "RayCast2D"
			raycast.enabled = true
			add_child(raycast)

	# Ensure this Area2D detects body enters (so paddles can reflect the ball)
	# is_connected expects the Callable form in Godot 4, so construct a Callable and test/connect it.
	var hook_callable := Callable(self, "_on_body_entered")
	if not is_connected("body_entered", hook_callable):
		connect("body_entered", hook_callable)

	# Detect which side the paddle starts on so default_x is sensible
	var rect = get_viewport().get_visible_rect()
	is_left_side = global_position.x < rect.size.x * 0.5

func _process(delta: float) -> void:
	var input_vector: Vector2 = Vector2.ZERO

	if is_ai:
		input_vector = get_ai_movement()
	else:
		input_vector = get_player_input()

	# Use global_position to avoid issues when nodes are in different parents
	global_position += input_vector * speed * delta

	# Clamp to visible viewport rect
	var rect: Rect2 = get_viewport().get_visible_rect()
	global_position.x = clamp(global_position.x, 50.0, rect.size.x - 50.0)
	global_position.y = clamp(global_position.y, 50.0, rect.size.y - 50.0)

func get_player_input() -> Vector2:
	var input: Vector2 = Vector2.ZERO
	if player_number == 1:
		input.x = Input.get_axis("p1_left", "p1_right")
		input.y = Input.get_axis("p1_up", "p1_down")
	elif player_number == 2:
		input.x = Input.get_axis("p2_left", "p2_right")
		input.y = Input.get_axis("p2_up", "p2_down")
	return input

# When a PhysicsBody2D (like the ball) enters this paddle area, reflect the ball
func _on_body_entered(body: Node) -> void:
	if not body:
		return
	# Ball must be in "ball" group or implement hit_by_paddle
	if body.is_in_group("ball") and body.has_method("hit_by_paddle"):
		# Tell the ball to reflect. Pass paddle center, configured height, and which side the paddle is on.
		body.call("hit_by_paddle", global_position, paddle_hit_height, is_left_side)
	# If the ball is a RigidBody2D and you ever want to use physics impulses instead, handle that here.

# Robust helper to retrieve the ball's velocity regardless of implementation
func _get_ball_velocity() -> Vector2:
	if not ball_reference:
		return Vector2.ZERO

	# Common built-in types
	if ball_reference is RigidBody2D:
		return ball_reference.linear_velocity
	if ball_reference is CharacterBody2D:
		if "velocity" in ball_reference:
			return ball_reference.velocity
	# Try common methods
	if ball_reference.has_method("get_velocity"):
		return ball_reference.get_velocity()
	if ball_reference.has_method("get_linear_velocity"):
		return ball_reference.get_linear_velocity()

	# Inspect property list for "linear_velocity" or "velocity" as last resort
	var prop_list = ball_reference.get_property_list()
	for p in prop_list:
		if String(p.name) == "linear_velocity":
			return ball_reference.get("linear_velocity")
		elif String(p.name) == "velocity":
			return ball_reference.get("velocity")

	return Vector2.ZERO

# Helper to compute a target point using either direct beeline or raycast collision point
func _ai_compute_target_point() -> Vector2:
	# If no ball, return current position as target
	if not ball_reference:
		return global_position

	# Use global positions for comparisons
	var ball_pos: Vector2 = ball_reference.global_position if "global_position" in ball_reference else ball_reference.position

	# Simple direct beeline target
	var direct_target: Vector2 = ball_pos

	# If raycast is enabled, point the raycast in the direction of the ball and use collision point (if any)
	if use_raycast and raycast:
		var direction: Vector2 = (ball_pos - global_position)
		if direction == Vector2.ZERO:
			return direct_target
		var cast_to: Vector2 = direction.normalized() * ray_length
		raycast.cast_to = cast_to
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var col_point = raycast.get_collision_point()
			return col_point
		return direct_target

	return direct_target

func get_ai_movement() -> Vector2:
	var input: Vector2 = Vector2.ZERO
	if not ball_reference:
		return input

	var target_point: Vector2 = _ai_compute_target_point()
	var paddle_pos: Vector2 = global_position

	# Add some imperfection based on ai_difficulty
	var offset_range: float = 50.0 * (1.0 - clamp(ai_difficulty, 0.0, 1.0))
	var random_offset: float = rng.randf_range(-offset_range, offset_range)
	var target_y: float = target_point.y + random_offset
	var target_x: float = target_point.x

	# Vertical movement (with dead zone)
	if abs(paddle_pos.y - target_y) > VERTICAL_DEADZONE:
		input.y = 1.0 if paddle_pos.y < target_y else -1.0

	# Horizontal movement: move toward ball when heading toward this paddle, else return to default
	var ball_vel: Vector2 = _get_ball_velocity()
	var moving_toward: bool
	moving_toward = (is_left_side and ball_vel.x < 0.0) or (not is_left_side and ball_vel.x > 0.0)

	if moving_toward:
		if abs(paddle_pos.x - target_x) > HORIZONTAL_REACTION_THRESHOLD:
			input.x = 1.0 if paddle_pos.x < target_x else -1.0
	else:
		var rect = get_viewport().get_visible_rect()
		var default_x: float
		if is_left_side:
			default_x = 100.0
		else:
			default_x = rect.size.x - 100.0
		if abs(paddle_pos.x - default_x) > RETURN_THRESHOLD:
			input.x = 1.0 if paddle_pos.x < default_x else -1.0

	return input


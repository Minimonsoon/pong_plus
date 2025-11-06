extends RigidBody2D

# Simple, deterministic Ball controller (works well with Area2D paddles).
# Put this script on the ball root (Node2D). Add a CollisionShape2D and Sprite2D as you have.

@export var initial_speed: float = 450.0
@export var max_speed: float = 1400.0
@export var speed_increase_on_hit: float = 1.05  # multiplier applied each paddle hit
@export var max_bounce_angle_degrees: float = 60.0
@export var start_direction_right: bool = true
@export var reset_position: Vector2 = Vector2.ZERO  # set from the scene or left at 0,0 and positioned manually

signal scored(side: String)  # "left" or "right"

var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Make sure the ball is findable by the paddle AI
	if not is_in_group("ball"):
		add_to_group("ball")
	# Set initial position if reset_position is provided (optional)
	if reset_position != Vector2.ZERO:
		global_position = reset_position
	# Choose initial velocity direction
	var dir_x = 1.0 if start_direction_right else -1.0
	var angle = randf_range(-0.25, 0.25)  # small random vertical angle
	velocity = Vector2(dir_x, angle).normalized() * initial_speed

func _physics_process(delta: float) -> void:
	# Simple integrator
	global_position += velocity * delta

	# Bounce on top/bottom edges
	var rect = get_viewport().get_visible_rect()
	var top_limit = 10.0
	var bottom_limit = rect.size.y - 10.0
	if global_position.y < top_limit:
		global_position.y = top_limit
		velocity.y = -velocity.y
	elif global_position.y > bottom_limit:
		global_position.y = bottom_limit
		velocity.y = -velocity.y

	# Check left/right scoring (ball left the play area)
	var left_limit = -50.0
	var right_limit = rect.size.x + 50.0
	if global_position.x < left_limit:
		emit_signal("scored", "left")
		_reset_after_score(false)
		return
	elif global_position.x > right_limit:
		emit_signal("scored", "right")
		_reset_after_score(true)
		return

func _reset_after_score(start_to_right: bool) -> void:
	# Reset to center or configured reset_position and set a starting velocity toward the scoring side's opponent.
	if reset_position != Vector2.ZERO:
		global_position = reset_position
	else:
		var rect = get_viewport().get_visible_rect()
		global_position = rect.size * 0.5
	# Small random vertical angle and direction toward the player who *lost* (so ball goes to scorer's opponent)
	var dir_x = -1.0 if start_to_right else 1.0
	var angle = randf_range(-0.25, 0.25)
	velocity = Vector2(dir_x, angle).normalized() * clamp(initial_speed, 100.0, max_speed)

# Called by a paddle Area2D when a collision is detected.
# paddle_global_pos: global position of the paddle center
# paddle_hit_height: full height used to compute hit offset (set on paddle side)
# is_left_side: true if paddle is on the left side (so ball will be reflected right), false for right paddle
func hit_by_paddle(paddle_global_pos: Vector2, paddle_hit_height: float, is_left_side: bool) -> void:
	# Compute how far from paddle center the ball hit (-1..1)
	var relative_y = global_position.y - paddle_global_pos.y
	var half_height = max(1.0, paddle_hit_height * 0.5)
	var norm = clamp(relative_y / half_height, -1.0, 1.0)

	# Turn that into an angle: -max..+max degrees
	var max_rad = deg_to_rad(max_bounce_angle_degrees)
	var bounce_angle = norm * max_rad

	# direction x will be toward the opposite side of the paddle
	var dir_x = 1.0 if is_left_side else -1.0
	var new_dir = Vector2(dir_x * cos(bounce_angle), sin(bounce_angle)).normalized()

	# Increase speed slightly on paddle hits and clamp
	var new_speed = clamp(velocity.length() * speed_increase_on_hit, 100.0, max_speed)
	velocity = new_dir * new_speed

func get_velocity() -> Vector2:
	return velocity

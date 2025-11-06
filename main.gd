extends Node2D

# Simple main / game manager that listens for the ball's `scored` signal
# and keeps a left/right score counter. Drop this on your main scene root
# (Node2D) and set the exported NodePaths in the Inspector.

@export var ball_path: NodePath
@export var left_paddle_path: NodePath
@export var right_paddle_path: NodePath
@export var left_score_label_path: NodePath
@export var right_score_label_path: NodePath

var left_score: int = 0
var right_score: int = 0

var ball: Node = null
var left_score_label: Label = null
var right_score_label: Label = null
var left_paddle: Node = null
var right_paddle: Node = null

func _ready() -> void:
	# Resolve nodes from exported paths (safe, null-checked)
	if ball_path and str(ball_path) != "":
		ball = get_node_or_null(ball_path)
	if left_score_label_path and str(left_score_label_path) != "":
		left_score_label = get_node_or_null(left_score_label_path)
	if right_score_label_path and str(right_score_label_path) != "":
		right_score_label = get_node_or_null(right_score_label_path)
	if left_paddle_path and str(left_paddle_path) != "":
		left_paddle = get_node_or_null(left_paddle_path)
	if right_paddle_path and str(right_paddle_path) != "":
		right_paddle = get_node_or_null(right_paddle_path)

	# Connect to ball's `scored` signal if available
	if ball:
		if ball.has_signal("scored"):
			# Use Callable for Godot 4 signal connect
			ball.connect("scored", Callable(self, "_on_ball_scored"))
		else:
			push_warning("Ball node has no `scored` signal. Main will not receive score updates.")

	# Initialize labels
	_update_score_labels()

func _on_ball_scored(side: String) -> void:
	# The Ball emits the side the ball left the play area on ("left" or "right").
	# We treat that as: if ball left on left side, the RIGHT player scored, and vice-versa.
	if side == "left":
		right_score += 1
	elif side == "right":
		left_score += 1
	else:
		# Unexpected payload, ignore
		return

	_update_score_labels()

	# Optional: you can do other things here, e.g. play a sound, update UI, pause, etc.

func _update_score_labels() -> void:
	if left_score_label:
		left_score_label.text = str(left_score)
	if right_score_label:
		right_score_label.text = str(right_score)

# Utility: reset scores to zero and update labels
func reset_scores() -> void:
	left_score = 0
	right_score = 0
	_update_score_labels()

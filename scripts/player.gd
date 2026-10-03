extends CharacterBody2D

const SPEED = 100.0
const BED_POSITION := Vector2(50, 50)

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var energy = 5
var psyche = 5
var hunger = 5

#TODO
var n = 0

var isDay = true
var going_to_bed = false


func _ready() -> void:
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0


func _process(delta: float) -> void:
	if energy <= 0 and isDay:
		start_night()


func start_night() -> void:
	isDay = false
	going_to_bed = true
	velocity = Vector2.ZERO
	nav_agent.target_position = BED_POSITION


func _physics_process(delta: float) -> void:
	# Night: walk to bed with pathfinding
	if going_to_bed:
		_walk_to_bed()
		return

	# Night, already in bed: do nothing
	if !isDay:
		return

	# Day: normal player control
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	if Input.is_action_just_pressed("ui_accept"):
		n += 1

		energy -= 1
		$"../CanvasLayer".updateEnergy(energy)

		$"../Gallows".updateGallows(n)

	if direction:
		if direction.x > 0:
			$AnimatedSprite2D.flip_h = false
		elif direction.x < 0:
			$AnimatedSprite2D.flip_h = true
		velocity = direction * SPEED
		$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("idle")
		velocity = Vector2.ZERO

	move_and_slide()


func _walk_to_bed() -> void:
	if nav_agent.is_navigation_finished():
		going_to_bed = false
		velocity = Vector2.ZERO
		$AnimatedSprite2D.play("sleep")
		return

	var next_pos := nav_agent.get_next_path_position()
	var dir := global_position.direction_to(next_pos)

	if dir.x != 0:
		$AnimatedSprite2D.flip_h = dir.x < 0

	velocity = dir * SPEED
	$AnimatedSprite2D.play("run")
	move_and_slide()

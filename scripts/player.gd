extends CharacterBody2D

const SPEED = 100.0
const BED_POSITION := Vector2(50, 50)
const GALLOW_POSITION := Vector2(144, 66)

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var energy = 5
var psyche = 5
var hunger = 5

var n = 0

var isDay = true
var going_to_bed = false
var night_phase = 0


func _ready() -> void:
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0


func _process(delta: float) -> void:
	if energy <= 0 and isDay:
		start_night()


func start_night() -> void:
	isDay = false
	going_to_bed = true
	night_phase = 0
	
	$"../CanvasLayer".night(true)
	
	nav_agent.target_position = BED_POSITION


func _physics_process(delta: float) -> void:
	if going_to_bed:
		_walk_at_night(delta)
		return
	
	if !isDay:
		return
	
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	if Input.is_action_just_pressed("ui_accept"):
		energy -= 1
		$"../CanvasLayer".updateEnergy(energy)
	
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


func _walk_at_night(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		if night_phase == 0:
			night_phase = 1
			$AnimatedSprite2D.play("sleep")
			
			nav_agent.target_position = GALLOW_POSITION
			return
		elif night_phase == 1:
			night_phase = 2
			
			n += 1
			$"../Gallows".updateGallows(n)
			
			nav_agent.target_position = BED_POSITION
			return
		
		elif night_phase == 2:
			going_to_bed = false
			isDay = true
			$"../CanvasLayer".night(false)
			night_phase = 0
			
			velocity = Vector2.ZERO
			energy = 5
			$"../CanvasLayer".updateEnergy(energy)
			
			$AnimatedSprite2D.play("idle")
			return
	
	var next_pos := nav_agent.get_next_path_position()
	var dir := global_position.direction_to(next_pos)
	
	if dir.x != 0:
		$AnimatedSprite2D.flip_h = dir.x < 0
	
	global_position = global_position.move_toward(
		next_pos,
		SPEED * delta
	)

	$AnimatedSprite2D.play("run")

extends CharacterBody2D

const SPEED = 100.0

var energy = 5;
var psyche = 5;
var hunger = 5;

var n = 0;

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)
	
	if Input.is_action_just_pressed("ui_accept"):
		n += 1;

		$"../Gallows".updateGallows(n)

	if direction:
		if direction.x > 0:
			$AnimatedSprite2D.flip_h = false;
		elif direction.x < 0:
			$AnimatedSprite2D.flip_h = true;
		velocity = direction * SPEED
		$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("idle")
		velocity = Vector2.ZERO

	move_and_slide()

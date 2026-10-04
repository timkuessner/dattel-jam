extends Node2D

var level = 0
var is_lit := false

var pos = [Vector2(0, 0), Vector2(0, -19), Vector2(0, -19), Vector2(0, -19), Vector2(0, -19), Vector2(-1, -19), Vector2(0, -24.5), Vector2(0, -24.5)]

func _ready() -> void:
	$AnimatedSprite2D.play("0")

func updateFire():
	$AnimatedSprite2D.position = pos[level]

	if is_lit:
		if $AnimatedSprite2D.animation != "fire_start" and $AnimatedSprite2D.animation != "fire_run":
			$AnimatedSprite2D.play("fire_start")
	elif level <= 5:
		$AnimatedSprite2D.play(str(level))
	else:
		# All wood is placed, but it still needs Flint and Steel.
		$AnimatedSprite2D.play("5")

func _on_animated_sprite_2d_animation_finished() -> void:
	if is_lit and $AnimatedSprite2D.animation == "fire_start":
		$AnimatedSprite2D.play("fire_run")
		$"../Ship".start()

func needs_wood() -> bool:
	return level < 6 and not is_lit

func needs_flint_and_steel() -> bool:
	return level >= 6 and not is_lit

func buildFire():
	if not needs_wood():
		return
	level += 1
	updateFire()

func ignite_fire() -> void:
	if not needs_flint_and_steel():
		return
	is_lit = true
	updateFire()
	
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.enterFire()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.exitFire()

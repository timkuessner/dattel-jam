extends Node2D

var level = 0

var pos = [Vector2(0, 0), Vector2(0, -19), Vector2(0, -19), Vector2(0, -19), Vector2(0, -19), Vector2(-1, -19), Vector2(0, -24.5), Vector2(0, -24.5)]

func _ready() -> void:
	$AnimatedSprite2D.play("0")

func updateFire():
	$AnimatedSprite2D.position = pos[level]

	if level <= 5:
		$AnimatedSprite2D.play(str(level))
	elif level >= 6:
		$AnimatedSprite2D.play("fire_start")


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "fire_start":
		$AnimatedSprite2D.play("fire_run")
		$"../Ship".start()

func buildFire():
	level += 1
	updateFire()
	
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.enterFire()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.exitFire()

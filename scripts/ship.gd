extends Node2D

func _ready() -> void:
	$AnimatedSprite2D.play("default")

func start():
	$"../AnimationPlayer".play("animation")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	$"../AnimationPlayer".play("idle")

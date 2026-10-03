@tool
extends Node2D

@export var item: Player.items:
	set(value):
		item = value
		_update_sprite()

func _ready() -> void:
	_update_sprite()

func _update_sprite() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D

	var animation_name: String = str(Player.items.keys()[item])

	if sprite.sprite_frames.has_animation(animation_name):
		sprite.animation = animation_name
		sprite.frame = 0
		sprite.pause()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.enterArea(self)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.exitArea(self)

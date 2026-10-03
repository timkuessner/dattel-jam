@tool
extends Node2D

@export var item: Player.items

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_sprite()

func _ready() -> void:
	_update_sprite()

func _update_sprite() -> void:
	if not has_node("AnimatedSprite2D"):
		return

	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	var animation_name := str(item)

	if sprite.sprite_frames.has_animation(animation_name):
		sprite.animation = animation_name


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		$Panel.show()
		body.enterArea(self)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		$Panel.hide()
		body.exitArea(self)

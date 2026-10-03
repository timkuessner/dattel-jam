extends Node2D

@export var item: Player.items

func _ready():
	$AnimatedSprite2D.play(str(item))

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		$Panel.show()
		body.enterArea(self)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		$Panel.hide()
		body.enterArea(self)

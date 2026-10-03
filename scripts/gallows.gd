extends AnimatedSprite2D

var n = 0

func updateGallows(_n):
	n = _n
	if n in [0, 1, 2, 3, 4, 5]:
		play(str(n))
		
		if n != 0:
			$StaticBody2D.set_collision_layer_value(1, true)
		else:
			$StaticBody2D.set_collision_layer_value(1, false)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and n != 0:
		body.showLabel("?")


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.hideInteract()

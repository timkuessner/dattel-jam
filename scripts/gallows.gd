extends AnimatedSprite2D

var n = 0

func updateGallows(_n):
	n = _n
	print(n)
	if n in [0, 1, 2, 3, 4, 5]:
		play(str(n))
		
		$Build.play()
		
		if n != 0:
			$StaticBody2D.set_collision_layer_value(1, true)
		else:
			$StaticBody2D.set_collision_layer_value(1, false)
	
	if n == 6:
		$AnimatedSprite2D.show()
		$AnimationPlayer.play("animation")


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and n != 0:
		body.showLabel("?")


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.hideInteract()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	get_tree().change_scene_to_file("res://scenes/FinalMenu.tscn")

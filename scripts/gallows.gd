extends AnimatedSprite2D

func updateGallows(n):
	if n in [0, 1, 2, 3, 4, 5]:
		play(str(n))
		
		if n != 0:
			$StaticBody2D.set_collision_layer_value(1, true)
		else:
			$StaticBody2D.set_collision_layer_value(1, false)

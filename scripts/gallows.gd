extends AnimatedSprite2D

func updateGallows(n):
	if n in [0, 1, 2, 3, 4, 5]:
		play(str(n))

extends Camera2D

@export var speed: float =  10

func _process(delta: float) -> void:
	position = position.lerp($"../Player".position + Vector2(0, -8), speed * delta)

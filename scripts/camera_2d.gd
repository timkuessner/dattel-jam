extends Camera2D

@export var speed: float = 10.0
@export var zoom_speed: float = 5.0
@export var margin: Vector2 = Vector2(40, 40)   # Rand um die Ghosts (in Pixeln)
@export var min_zoom: float = 0.5
@export var max_zoom: float = 4.0               # Wie weit man maximal hineinzoomen darf

@onready var player: Player = $"../Player"


func _process(delta: float) -> void:
	if player.finale:
		_follow_ghosts(delta)
	else:
		position = position.lerp(player.position + Vector2(0, -8), speed * delta)


func _follow_ghosts(delta: float) -> void:
	var ghosts := get_tree().get_nodes_in_group("ghost")
	if ghosts.is_empty():
		return

	# Mittelpunkt = Durchschnitt aller Positionen,
	# gleichzeitig Bounding Box für den Zoom bestimmen
	var sum := Vector2.ZERO
	var min_p: Vector2 = ghosts[0].global_position
	var max_p: Vector2 = min_p

	for g in ghosts:
		var p: Vector2 = g.global_position
		sum += p
		min_p = min_p.min(p)
		max_p = max_p.max(p)

	var center := sum / ghosts.size()

	# Da die Kamera auf den Durchschnitt zentriert ist (nicht auf die Mitte der
	# Bounding Box), brauchen wir den größten Abstand vom Zentrum pro Achse.
	var half_extent := Vector2(
		maxf(center.x - min_p.x, max_p.x - center.x),
		maxf(center.y - min_p.y, max_p.y - center.y)
	)

	var needed_size := half_extent * 2.0 + margin * 2.0
	var viewport_size := get_viewport_rect().size

	# Zoom so groß wie möglich, sodass beide Achsen noch passen
	var z := minf(viewport_size.x / needed_size.x, viewport_size.y / needed_size.y)
	z = clampf(z, min_zoom, max_zoom)

	global_position = global_position.lerp(center, speed * delta)
	zoom = zoom.lerp(Vector2(z, z), zoom_speed * delta)

extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var points: Array = []
var replay_time := 10.0
var gallow_time := 5.0
var gallow_pos := Vector2.ZERO

var t := 0.0
var active := false
var facing := "down"


func start(p: Array, replay: float, gallow: float, gallow_position: Vector2) -> void:
	points = p
	replay_time = replay
	gallow_time = gallow
	gallow_pos = gallow_position
	global_position = points[0]
	t = 0.0
	active = true


func _process(delta: float) -> void:
	if not active:
		return

	t += delta
	var new_pos: Vector2

	if t < replay_time:
		var f := (t / replay_time) * (points.size() - 1)
		var i := int(f)
		var next := mini(i + 1, points.size() - 1)
		new_pos = points[i].lerp(points[next], f - i)
	elif t < replay_time + gallow_time:
		var k := (t - replay_time) / gallow_time
		new_pos = points.back().lerp(gallow_pos, k)
	else:
		global_position = gallow_pos
		sprite.play("idle_" + facing)
		active = false
		return

	_face(new_pos - global_position)
	global_position = new_pos


func _face(d: Vector2) -> void:
	if d.length() < 0.01:
		return
	if abs(d.x) > abs(d.y):
		facing = "right" if d.x > 0 else "left"
	else:
		facing = "down" if d.y > 0 else "up"
	sprite.play("run_" + facing)

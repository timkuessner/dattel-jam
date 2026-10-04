extends Node2D

const WOOD_SCENE = preload("res://scenes/items/wood.tscn")

var used := false


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not used and body is Player:
		body.enterArea(self)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		body.exitArea(self)


func interact(player: Player) -> void:
	if used:
		return

	var hud = player.get_node("../PlayerHUD")
	if hud == null or hud.get_energy() < 2:
		return
	
	player.play_tree_animation()

	used = true
	player.exitArea(self)

	$Area2D.set_deferred("monitoring", false)

	var sprite := $AnimatedSprite2D
	sprite.frame = 0
	sprite.play(sprite.animation)

	await sprite.animation_finished

	var wood := WOOD_SCENE.instantiate()

	get_tree().current_scene.add_child(wood)
	wood.global_position = global_position
	
	hud.decrease_energy(2)
	if randf() < 0.15:
		hud.decrease_hunger(1)
	hud.update()


func _on_area_2d_mouse_entered() -> void:
	pass # Replace with function body.


func _on_area_2d_mouse_exited() -> void:
	pass # Replace with function body.

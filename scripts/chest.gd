extends Node2D

const MUSHROOM_SCENE := preload("res://scenes/items/mushroom.tscn")
const FISHING_ROD_SCENE := preload("res://scenes/items/fishing_rod.tscn")

var opened := false


func _on_area_2d_body_entered(body: Node2D) -> void:
	if opened:
		return

	if body is Player:
		body.enterArea(self)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		body.exitArea(self)


func interact(player: Player) -> void:
	if opened:
		return

	opened = true
	player.exitArea(self)
	$Area2D.set_deferred("monitoring", false)

	$AnimatedSprite2D.play("open")
	await $AnimatedSprite2D.animation_finished

	var mushroom := MUSHROOM_SCENE.instantiate()
	get_tree().current_scene.add_child(mushroom)
	mushroom.global_position = global_position + Vector2(-16, 12)

	var fishing_rod := FISHING_ROD_SCENE.instantiate()
	get_tree().current_scene.add_child(fishing_rod)
	fishing_rod.global_position = global_position + Vector2(16, 12)

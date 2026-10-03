extends Area2D

@export var seed_amount := 3

var collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if collected or not (body is CharacterBody2D):
		return

	var farm_system := get_tree().get_first_node_in_group("farm_system")
	if farm_system == null:
		return

	collected = true
	farm_system.add_carrot_seeds(seed_amount)
	queue_free()

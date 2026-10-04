class_name Item
extends Node2D

enum items {MUSHROOM, WOOD, HOE, BUCKET, CARROT_SEEDS, CARROT, FISHING_ROD, FISH_BLUE, FISH_ORANGE, FISH_GREEN, TRASH, FLINT_AND_STEEL, EMPTY}

@export var item: items = items.MUSHROOM:
	set(value):
		item = value
		_update_sprite()

@export var amount: int = 1

func _ready() -> void:
	_update_sprite()

func _update_sprite() -> void:
	if not has_node("AnimatedSprite2D"):
		return
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	var animation_name := str(items.keys()[item])
	if sprite.sprite_frames.has_animation(animation_name):
		sprite.animation = animation_name
		sprite.frame = 0
		sprite.pause()

func interact(player: Player) -> void:
	player.add_item(item, amount)
	player.exitArea(self)
	queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		body.enterArea(self)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		body.exitArea(self)

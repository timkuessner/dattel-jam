extends PanelContainer

func _ready() -> void:
	set_item(Item.items.EMPTY)

func set_item(item: Item.items) -> void:
	$AnimatedSprite2D.play(str(Item.items.keys()[item]))

extends PanelContainer

func set_item(item: Item.items) -> void:
	$AnimatedSprite2D.play(str(Item.items.keys()[item]))

extends PanelContainer

@onready var icon_rect: TextureRect = $ItemIcon

func set_item(item_texture: Texture2D) -> void:
	if item_texture:
		icon_rect.texture = item_texture
		icon_rect.show()
	else:
		clear_slot()

func clear_slot() -> void:
	icon_rect.texture = null
	icon_rect.hide()

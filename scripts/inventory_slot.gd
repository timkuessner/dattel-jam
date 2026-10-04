extends PanelContainer

signal item_selected(item: Item.items)

var current_item: Item.items = Item.items.EMPTY
var is_selected := false
var is_drop_choice := false

func _ready() -> void:
	pivot_offset = Vector2(32, 32)
	set_item(Item.items.EMPTY)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_slot_number(number: int) -> void:
	$NumberOverlay/SlotNumber.text = str(number)

func set_item(item: Item.items) -> void:
	current_item = item
	$AnimatedSprite2D.play(str(Item.items.keys()[item]))

func set_bucket_full(full: bool) -> void:
	if current_item != Item.items.BUCKET:
		return
	$AnimatedSprite2D.play("BUCKET_FULL" if full else "BUCKET")

func set_selected(selected: bool) -> void:
	is_selected = selected
	_refresh_visual()


func set_drop_choice_mode(enabled: bool) -> void:
	is_drop_choice = enabled
	_refresh_visual()


func _refresh_visual() -> void:
	if is_drop_choice:
		self_modulate = Color(1.0, 0.72, 0.72, 1.0)
		scale = Vector2(1.08, 1.08)
		z_index = 5
	elif is_selected:
		self_modulate = Color(0.72, 1.0, 0.72, 1.0)
		scale = Vector2(1.16, 1.16)
		z_index = 10
	else:
		self_modulate = Color.WHITE
		scale = Vector2.ONE
		z_index = 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		item_selected.emit(current_item)
		accept_event()

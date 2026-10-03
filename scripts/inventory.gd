extends Control

@export var slot_scene: PackedScene = load("res://scenes/Inventory_Slot.tscn")
@export var total_slots: int = 9

@onready var grid_container: GridContainer = $GridContainer

var slots: Array = []
var selected_slot_index: int = -1
var selected_item: Item.items = Item.items.EMPTY

func _ready() -> void:
	create_inventory_slots()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var slot_index := _slot_index_from_key(event)
		if slot_index != -1:
			select_slot(slot_index)
			get_viewport().set_input_as_handled()

func _slot_index_from_key(event: InputEventKey) -> int:
	# Obere Zahlenreihe 1-9 (funktioniert auch mit unterschiedlichen Tastaturlayouts).
	var code := event.physical_keycode
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_1

	# Fallback über das tatsächlich eingegebene Zeichen.
	if event.unicode >= 49 and event.unicode <= 57:
		return event.unicode - 49

	return -1

func create_inventory_slots() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	slots.clear()

	for i in range(total_slots):
		var slot_instance = slot_scene.instantiate()
		grid_container.add_child(slot_instance)
		slot_instance.set_slot_number(i + 1)
		slot_instance.item_selected.connect(_on_slot_item_selected.bind(i))
		slots.append(slot_instance)

func update_slots(items: Dictionary) -> void:
	var slot := 0
	for item in items:
		for _i in range(items[item]):
			if slot >= slots.size():
				_refresh_selection_after_inventory_change()
				return
			slots[slot].set_item(item)
			slot += 1

	for i in range(slot, slots.size()):
		slots[i].set_item(Item.items.EMPTY)

	_refresh_bucket_visual()
	_refresh_selection_after_inventory_change()

func _refresh_bucket_visual() -> void:
	var farm_system := get_tree().get_first_node_in_group("farm_system") as FarmManager
	var bucket_full := false
	if farm_system != null:
		bucket_full = farm_system.water_units > 0
	for slot in slots:
		slot.set_bucket_full(bucket_full)

func refresh_bucket_visual() -> void:
	_refresh_bucket_visual()

func _refresh_selection_after_inventory_change() -> void:
	if selected_slot_index < 0 or selected_slot_index >= slots.size():
		_set_selected_slot(-1)
		return

	if slots[selected_slot_index].current_item == Item.items.EMPTY:
		_set_selected_slot(-1)
	else:
		selected_item = slots[selected_slot_index].current_item
		_refresh_selection_visual()
		_apply_selected_item()

func _on_slot_item_selected(_item: Item.items, slot_index: int) -> void:
	select_slot(slot_index)

func select_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return

	# Dieselbe Zahl bzw. denselben Slot erneut drücken/klicken = Auswahl aufheben.
	if selected_slot_index == slot_index:
		_set_selected_slot(-1)
		return

	# Ein leerer Slot kann sichtbar ausgewählt werden, hat aber kein aktives Item.
	_set_selected_slot(slot_index)

func _set_selected_slot(slot_index: int) -> void:
	selected_slot_index = slot_index

	if selected_slot_index >= 0 and selected_slot_index < slots.size():
		selected_item = slots[selected_slot_index].current_item
	else:
		selected_item = Item.items.EMPTY

	_refresh_selection_visual()
	_apply_selected_item()

func _refresh_selection_visual() -> void:
	for i in range(slots.size()):
		slots[i].set_selected(i == selected_slot_index)

func _apply_selected_item() -> void:
	var farm_system := get_tree().get_first_node_in_group("farm_system") as FarmManager
	var player := get_tree().get_first_node_in_group("player") as Player
	if farm_system == null or player == null:
		return

	match selected_item:
		Item.items.HOE:
			farm_system.select_tool(FarmManager.TOOL_HOE, player)
		Item.items.CARROT_SEEDS:
			farm_system.select_tool(FarmManager.TOOL_SEEDS, player)
		Item.items.BUCKET:
			farm_system.select_tool(FarmManager.TOOL_BUCKET, player)
		_:
			farm_system.select_tool(FarmManager.TOOL_NONE, player)

func add_item_to_first_free_slot(texture: Texture2D) -> bool:
	for slot in slots:
		if slot.icon_rect.texture == null:
			slot.set_item(texture)
			return true
	print("Inventar ist voll!")
	return false

func remove_item_at_index(index: int) -> bool:
	if index < 0 or index >= slots.size():
		print("Ungültiger Index: ", index)
		return false

	var target_slot = slots[index]
	if target_slot.icon_rect.texture == null:
		print("Slot ", index, " ist bereits leer!")
		return false

	target_slot.clear_slot()
	return true

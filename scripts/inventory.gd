extends Control

@export var slot_scene: PackedScene = load("res://scenes/Inventory_Slot.tscn")
@export var total_slots: int = 9

@onready var grid_container: GridContainer = $GridContainer
@onready var overflow_label: Label = $OverflowLabel

var slots: Array = []
var selected_slot_index: int = -1
var selected_item: Item.items = Item.items.EMPTY
var choosing_overflow_drop := false
var overflow_incoming_item: Item.items = Item.items.EMPTY

func _ready() -> void:
	create_inventory_slots()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Bei einer Inventar-voll-Entscheidung bricht ESC den aktuellen Tausch ab.
		# Das wartende neue Item wird dabei auf den Boden gelegt und geht nicht verloren.
		if choosing_overflow_drop and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
			var player := get_tree().get_first_node_in_group("player") as Player
			if player != null and player.has_method("cancel_inventory_overflow"):
				player.cancel_inventory_overflow()
			get_viewport().set_input_as_handled()
			return

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
	# Die sichtbaren Slots sind die feste Anordnung des Inventars.
	# Deshalb wird NICHT mehr bei jedem Update alles von links neu gepackt.
	# Wir gleichen nur die Anzahl pro Item mit dem Player-Dictionary ab:
	# vorhandene Items bleiben an ihrem Platz, fehlende kommen in freie Slots.
	var desired_counts: Dictionary = {}
	for item in items:
		desired_counts[item] = int(items[item])

	var current_counts: Dictionary = {}
	for slot in slots:
		var current_item: Item.items = slot.current_item
		if current_item != Item.items.EMPTY:
			current_counts[current_item] = current_counts.get(current_item, 0) + 1

	# Zuerst nur echte Ueberstaende entfernen. Wenn das aktuell ausgewaehlte
	# Item verbraucht wurde, verschwindet bevorzugt genau dieser Slot.
	for item in current_counts.keys():
		var surplus: int = int(current_counts[item]) - int(desired_counts.get(item, 0))
		if surplus <= 0:
			continue

		var candidates: Array[int] = []
		if (
			selected_slot_index >= 0
			and selected_slot_index < slots.size()
			and slots[selected_slot_index].current_item == item
		):
			candidates.append(selected_slot_index)

		for i in range(slots.size() - 1, -1, -1):
			if i != selected_slot_index and slots[i].current_item == item:
				candidates.append(i)

		for i in range(mini(surplus, candidates.size())):
			slots[candidates[i]].set_item(Item.items.EMPTY)

	# Nach dem Entfernen neu zaehlen.
	current_counts.clear()
	for slot in slots:
		var current_item: Item.items = slot.current_item
		if current_item != Item.items.EMPTY:
			current_counts[current_item] = current_counts.get(current_item, 0) + 1

	# Fehlende Items werden nur in freie Slots gesetzt. Bestehende Slots
	# veraendern dabei niemals ihre Position.
	for item in desired_counts.keys():
		var missing: int = int(desired_counts[item]) - int(current_counts.get(item, 0))
		for _i in range(maxi(missing, 0)):
			var free_index := _first_empty_slot_index()
			if free_index == -1:
				break
			slots[free_index].set_item(item)

	_refresh_bucket_visual()
	_refresh_selection_after_inventory_change()


func _first_empty_slot_index() -> int:
	for i in range(slots.size()):
		if slots[i].current_item == Item.items.EMPTY:
			return i
	return -1

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

	# Inventar voll: Der nächste Klick/Zahlendruck wählt nicht das aktive Item,
	# sondern genau den Slot, der auf den Boden gelegt werden soll.
	if choosing_overflow_drop:
		if slots[slot_index].current_item == Item.items.EMPTY:
			return
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null:
			player.resolve_inventory_overflow(slot_index)
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
		Item.items.FISHING_ROD:
			farm_system.select_tool(FarmManager.TOOL_FISHING_ROD, player)
		_:
			farm_system.select_tool(FarmManager.TOOL_NONE, player)

func begin_overflow_choice(incoming_item: Item.items) -> void:
	choosing_overflow_drop = true
	overflow_incoming_item = incoming_item
	_set_selected_slot(-1)

	var incoming_name := _display_name(incoming_item)
	overflow_label.text = "Inventar voll! %s wartet. Wähle mit Klick oder 1–9 ein Item zum Tauschen. ESC = abbrechen." % incoming_name
	overflow_label.show()

	for slot in slots:
		slot.set_drop_choice_mode(true)


func end_overflow_choice() -> void:
	choosing_overflow_drop = false
	overflow_incoming_item = Item.items.EMPTY
	overflow_label.hide()

	for slot in slots:
		slot.set_drop_choice_mode(false)




func replace_item_at_slot(slot_index: int, new_item: Item.items) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return

	# Der neue Gegenstand kommt EXAKT in den gewählten Slot.
	# Dadurch rutschen die Items davor nicht nach links.
	slots[slot_index].set_item(new_item)
	_refresh_bucket_visual()


func get_item_at_slot(slot_index: int) -> Item.items:
	if slot_index < 0 or slot_index >= slots.size():
		return Item.items.EMPTY
	return slots[slot_index].current_item


func _display_name(item: Item.items) -> String:
	match item:
		Item.items.MUSHROOM:
			return "Pilz"
		Item.items.WOOD:
			return "Holz"
		Item.items.HOE:
			return "Hacke"
		Item.items.BUCKET:
			return "Eimer"
		Item.items.CARROT_SEEDS:
			return "Karottensamen"
		Item.items.CARROT:
			return "Karotte"
		Item.items.FISHING_ROD:
			return "Angel"
		Item.items.FISH_BLUE:
			return "Blauer Fisch"
		Item.items.FISH_ORANGE:
			return "Oranger Fisch"
		Item.items.FISH_GREEN:
			return "Grüner Fisch"
		Item.items.TRASH:
			return "Müll"
		_:
			return "Item"

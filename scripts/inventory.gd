extends Control

@export var slot_scene: PackedScene = load("res://scenes/Inventory_Slot.tscn")
@export var total_slots: int = 9   # Anzahl der Plätze im Inventar

@onready var grid_container: GridContainer = $GridContainer

var slots: Array = []

func _ready() -> void:
	create_inventory_slots()
	

func create_inventory_slots() -> void:
	# Bisherige Slots löschen (falls vorhanden)
	for child in grid_container.get_children():
		child.queue_free()
	slots.clear()

	# Slots entsprechend der gewünschten Anzahl instanziieren
	for i in range(total_slots):
		var slot_instance = slot_scene.instantiate()
		grid_container.add_child(slot_instance)
		slots.append(slot_instance)

# Funktion zum Hinzufügen eines Items an den ersten freien Slot
func add_item_to_first_free_slot(texture: Texture2D) -> bool:
	for slot in slots:
		if slot.icon_rect.texture == null:
			slot.set_item(texture)
			return true # Item erfolgreich abgelegt
	print("Inventar ist voll!")
	return false
	
func remove_item_at_index(index: int) -> bool:
	# Prüfen, ob der Index innerhalb der Grenzen liegt
	if index < 0 or index >= slots.size():
		print("Ungültiger Index: ", index)
		return false
	
	var target_slot = slots[index]
	
	# Prüfen, ob der Slot überhaupt belegt ist
	if target_slot.icon_rect.texture == null:
		print("Slot ", index, " ist bereits leer!")
		return false
	
	# Slot zurücksetzen
	target_slot.clear_slot()
	return true

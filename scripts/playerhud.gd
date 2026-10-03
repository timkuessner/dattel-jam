extends CanvasLayer

@onready var psyche_icons: Array = $Attributes/Psyche.get_children()
@onready var hunger_icons: Array = $Attributes/Health.get_children()
@onready var energy_icons: Array = $Attributes/Energy.get_children()

var psyche_full = preload("res://assets/sprites/HUD/Psyche.png")
var psyche_empty = preload("res://assets/sprites/HUD/Psyche_Shadow.png")

var hunger_full = preload("res://assets/sprites/HUD/Heart.png")
var hunger_empty = preload("res://assets/sprites/HUD/Heart_Shadow.png")

var energy_full = preload("res://assets/sprites/HUD/Energy.png")
var energy_empty = preload("res://assets/sprites/HUD/Energy_Shadow.png")



func _ready() -> void:
	update()

var psyche = 4
var hunger = 4
var energy = 4

var max_psyche = 4
var max_hunger = 4
var max_energy = 4

func decrease_psyche(n):
	if psyche - n >= 0 :
		psyche = psyche - n
		return true
	else :
		return false

func increase_psyche(n):
	if psyche + n <= max_psyche :
		psyche = psyche + n
		return true
	else :
		return false

func get_psyche():
	return psyche

func decrease_hunger(n):
	if hunger - n >= 0 :
		hunger = hunger - n
		return true
	else :
		return false

func increase_hunger(n):
	if hunger + n <= max_hunger :
		hunger = hunger + n
		return true
	else :
		return false

func get_hunger():
	return hunger

func decrease_energy(n):
	if energy - n >= 0 :
		energy = energy - n
		return true
	else :
		return false

func increase_energy(n):
	if energy + n <= max_energy :
		energy = energy + n
		return true
	else :
		return false

func get_energy():
	return energy

func reset_energy():
	energy = max_energy


func night(b):
	if b:
		$NightOverlay.show()
		$Attributes/Health.propagate_call("set_visible", [false])
		$Attributes/Health.show()
		$Attributes/Energy.propagate_call("set_visible", [false])
		$Attributes/Energy.show()
	else:
		$NightOverlay.hide()
		$Attributes/Health.propagate_call("set_visible", [true])
		$Attributes/Energy.propagate_call("set_visible", [true])

func update():
	update_psyche_display()
	update_hunger_display()
	update_energy_display()



func update_psyche_display() -> void:
	for i in range(max_psyche):
		if i < psyche:
			psyche_icons[i].texture = psyche_full
		else :
			psyche_icons[i].texture = psyche_empty

func update_hunger_display() -> void:
	for i in range(max_hunger):
		if i < hunger:
			hunger_icons[i].texture = hunger_full
		else :
			hunger_icons[i].texture = hunger_empty

func update_energy_display() -> void:
	for i in range(max_energy):
		if i < energy:
			energy_icons[i].texture = energy_full
		else :
			energy_icons[i].texture = energy_empty

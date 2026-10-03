extends CanvasLayer

var psyche = 4
var hunger = 4
var energy = 4

func decrease_psyche(n):
	if psyche - n >= 0 :
		psyche = psyche - n
		return true
	else :
		return false

func increase_psyche(n):
	if psyche + n <= 4 :
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
	if hunger + n <= 4 :
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
	if energy + n <= 4 :
		energy = energy + n
		return true
	else :
		return false

func get_energy():
	return energy



func night(b):
	if b:
		$VBoxContainer.hide()
		$NightOverlay.show()
	else:
		$VBoxContainer.show()
		$NightOverlay.hide()

func update():
	$VBoxContainer/Label.text = "psyche: " + str(psyche)
	$VBoxContainer/Label2.text = "hunger: " + str(hunger)
	$VBoxContainer/Label3.text = "energy: " + str(energy)

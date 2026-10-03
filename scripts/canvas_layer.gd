extends CanvasLayer

func updatePsyche(n):
	$VBoxContainer/Label.text = "psyche: " + str(n)

func updateHunger(n):
	$VBoxContainer/Label2.text = "hunger: " + str(n)

func updateEnergy(n):
	$VBoxContainer/Label3.text = "energy: " + str(n)

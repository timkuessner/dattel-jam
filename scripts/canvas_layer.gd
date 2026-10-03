extends CanvasLayer

func night(b):
	if b:
		$VBoxContainer.hide()
		$NightOverlay.show()
	else:
		$VBoxContainer.show()
		$NightOverlay.hide()

func updatePsyche(n):
	$VBoxContainer/Label.text = "psyche: " + str(n)

func updateHunger(n):
	$VBoxContainer/Label2.text = "hunger: " + str(n)

func updateEnergy(n):
	$VBoxContainer/Label3.text = "energy: " + str(n)

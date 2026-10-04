extends Control

var button_type = null

func _ready() -> void:
	$Fadetransition.show()
	$Fadetransition/fade_timer.start()
	$Fadetransition/AnimationPlayer.play("Fade_in")
	$Fadetransition/AnimationPlayer.advance(0)
	pass


func _on_start_pressed() -> void:
	button_type = "start"
	$Fadetransition.show()
	$Fadetransition/fade_timer.start()
	$Fadetransition/AnimationPlayer.play("Fade_out")

func _on_options_pressed() -> void:
	button_type = "Credits"
	$Fadetransition.show()
	$Fadetransition/fade_timer.start()
	$Fadetransition/AnimationPlayer.play("Fade_out")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_fade_timer_timeout() -> void:
	if button_type == "start" :
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	elif button_type == "Credits" :
		get_tree().change_scene_to_file("res://scenes/CreditMenu.tscn")

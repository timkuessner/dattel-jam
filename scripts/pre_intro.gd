extends Control

func _ready() -> void:
	$Fadetransition.show()
	$Fadetransition/delay_timer.start()
	$Fadetransition/AnimationPlayer.play("Fade_in")
	$Fadetransition/AnimationPlayer.advance(0)
	pass


func _on_fade_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://scenes/Intro.tscn")


func _on_delay_timer_timeout() -> void:
	$Fadetransition.show()
	$Fadetransition/fade_timer.start()
	$Fadetransition/AnimationPlayer.play("Fade_out")

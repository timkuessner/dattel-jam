extends Control



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Start.set_pivot_offset($Start.size/2)
	$Options.set_pivot_offset($Options.size/2)
	$Quit.set_pivot_offset($Quit.size/2)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	



func _on_start_mouse_entered() -> void:
	$Start.scale = $Start.scale + Vector2(0.1,0.1)

func _on_start_mouse_exited() -> void:
	$Start.scale = $Start.scale - Vector2(0.1,0.1)


func _on_options_mouse_entered() -> void:
	$Options.scale = $Options.scale + Vector2(0.1,0.1)


func _on_options_mouse_exited() -> void:
	$Options.scale = $Options.scale - Vector2(0.1,0.1)


func _on_quit_mouse_entered() -> void:
	$Quit.scale = $Quit.scale + Vector2(0.1,0.1)


func _on_quit_mouse_exited() -> void:
	$Quit.scale = $Quit.scale - Vector2(0.1,0.1)

extends CanvasLayer

@onready var psyche_icons: Array = $Attributes/Psyche.get_children()
@onready var hunger_icons: Array = $Attributes/Health.get_children()
@onready var energy_icons: Array = $Attributes/Energy.get_children()

var track_number = null

var psyche_full = preload("res://assets/sprites/HUD/Psyche.png")
var psyche_empty = preload("res://assets/sprites/HUD/Psyche_Shadow.png")

var hunger_full = preload("res://assets/sprites/HUD/Heart.png")
var hunger_empty = preload("res://assets/sprites/HUD/Heart_Shadow.png")

var energy_full = preload("res://assets/sprites/HUD/Energy.png")
var energy_empty = preload("res://assets/sprites/HUD/Energy_Shadow.png")


# --- Blink settings ---
const BLINK_COUNT := 3
const BLINK_INTERVAL := 0.12

# Last displayed value per stat
var _displayed: Dictionary = {}

# Running blink tweens per icon
var _blink_tweens: Dictionary = {}


var psyche = 4
var hunger = 4
var energy = 4

var max_psyche = 4
var max_hunger = 4
var max_energy = 4


func _ready() -> void:
	update()


func decrease_psyche(n):
	if psyche - n >= 0:
		psyche = psyche - n
		return true
	else:
		return false


func increase_psyche(n):
	if psyche + n <= max_psyche:
		psyche = psyche + n
		return true
	else:
		return false


func get_psyche():
	return psyche


func decrease_hunger(n):
	if hunger - n >= 0:
		hunger = hunger - n
		return true
	else:
		return false


func increase_hunger(n):
	if hunger + n <= max_hunger:
		hunger = hunger + n
		return true
	else:
		return false


func get_hunger():
	return hunger


func decrease_energy(n):
	if energy - n >= 0:
		energy = energy - n
		return true
	else:
		return false


func increase_energy(n):
	if energy + n <= max_energy:
		energy = energy + n
		return true
	else:
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
		$Panel.hide()
		night_audio()
	else:
		$NightOverlay.hide()
		$Attributes/Health.propagate_call("set_visible", [true])
		$Attributes/Energy.propagate_call("set_visible", [true])
		$Panel.show()
		update_audiotracks(true)


func update():
	update_psyche_display()
	update_hunger_display()
	update_energy_display()
	update_audiotracks(false)


func update_audiotracks(override: bool):
	if psyche < 3:
		if hunger < 3:
			if (track_number != 3)||override:
				$AudioStreamPlayer.stream = preload(
					"res://assets/Music/low_hp_low_mental_v1.wav"
				)
				track_number = 3
				$AudioStreamPlayer.play()

		else:
			if (track_number != 2)||override:
				$AudioStreamPlayer.stream = preload(
					"res://assets/Music/good_hp_low_mental_v3.wav"
				)
				track_number = 2
				$AudioStreamPlayer.play()

	elif hunger < 3:
		if (track_number != 1)||override:
			$AudioStreamPlayer.stream = preload(
				"res://assets/Music/low_hp_high_mental_v1.wav"
			)
			track_number = 1
			$AudioStreamPlayer.play()

	else:
		if (track_number != 0)||override:
			$AudioStreamPlayer.stream = preload(
				"res://assets/Music/good_hp_good_mental_v2.wav"
			)
			track_number = 0
			$AudioStreamPlayer.play()

func night_audio():
	$AudioStreamPlayer.stream = preload("res://assets/Music/night_v2.wav")
	$AudioStreamPlayer.play()

func update_psyche_display() -> void:
	_update_stat_display(
		"psyche",
		psyche_icons,
		psyche,
		max_psyche,
		psyche_full,
		psyche_empty
	)


func update_hunger_display() -> void:
	_update_stat_display(
		"hunger",
		hunger_icons,
		hunger,
		max_hunger,
		hunger_full,
		hunger_empty
	)


func update_energy_display() -> void:
	_update_stat_display(
		"energy",
		energy_icons,
		energy,
		max_energy,
		energy_full,
		energy_empty
	)


# Generic display updater:
# sets textures and blinks every icon whose state changed
func _update_stat_display(
	key: String,
	icons: Array,
	value: int,
	max_value: int,
	full_tex: Texture2D,
	empty_tex: Texture2D
) -> void:

	var old_value: int = _displayed.get(key, -1)
	_displayed[key] = value

	# Example:
	# 4 -> 2 changes icons 2 and 3
	var change_start := mini(old_value, value)
	var change_end := maxi(old_value, value)

	for i in range(mini(max_value, icons.size())):
		var final_tex: Texture2D = full_tex if i < value else empty_tex
		var other_tex: Texture2D = empty_tex if i < value else full_tex

		_stop_blink(icons[i])

		var changed := (
			old_value >= 0
			and i >= change_start
			and i < change_end
		)

		if changed:
			_blink_icon(
				icons[i],
				final_tex,
				other_tex
			)
		else:
			icons[i].texture = final_tex


func _blink_icon(
	icon,
	final_tex: Texture2D,
	other_tex: Texture2D
) -> void:

	var steps := BLINK_COUNT * 2

	var tween: Tween = icon.create_tween()

	_blink_tweens[icon.get_instance_id()] = tween

	for k in range(steps):
		var tex: Texture2D = (
			final_tex
			if (steps - 1 - k) % 2 == 0
			else other_tex
		)

		tween.tween_callback(
			func():
				icon.texture = tex
		)

		tween.tween_interval(BLINK_INTERVAL)

	# Guarantee final texture
	tween.tween_callback(
		func():
			icon.texture = final_tex
	)


func _stop_blink(icon) -> void:
	var id: int = icon.get_instance_id()

	if _blink_tweens.has(id):
		var t: Tween = _blink_tweens[id]

		if t and t.is_valid():
			t.kill()

		_blink_tweens.erase(id)

extends Control

signal finished(winner_index: int, item_name: String)

const ITEM_SIZE := 64.0
const GAP := 0.0
const STEP := ITEM_SIZE + GAP

# CHANGE THIS to the folder where your images are
const IMAGE_FOLDER := "res://assets/sprites/items/"

const ITEM_NAMES: Array[String] = ["Blue fish", "Green fish", "Orange fish", "Trash"]
const ITEM_FILES: Array[String] = ["fish_blue.png", "fish_green.png", "fish_orange.png", "trash.png"]

var textures: Array[Texture2D] = []

var reel: Control
var track: Control
var item_ids: Array[int] = []   # which item type every slot in the track is

func _ready() -> void:
	# load the images
	for file in ITEM_FILES:
		var tex := load(IMAGE_FOLDER + file) as Texture2D
		if tex == null:
			push_error("Could not load: " + IMAGE_FOLDER + file)
		textures.append(tex)

	# clipping area inside the strip
	reel = Control.new()
	reel.name = "Reel"
	$Panel/Control.add_child(reel)
	reel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reel.clip_contents = true
	reel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	await get_tree().process_frame
	await get_tree().process_frame
	spin()

func spin(duration: float = 6.0, travel_items: int = 60) -> void:
	if track:
		track.queue_free()
	item_ids.clear()

	track = Control.new()
	reel.add_child(track)

	var width := reel.size.x
	if width <= 0.0:
		width = get_viewport_rect().size.x

	var half := int(ceil(width / 2.0 / STEP)) + 2
	var winner_index := half + 2
	var start_index := winner_index + travel_items
	var total := start_index + half + 1

	for i in total:
		var id := randi() % textures.size()
		item_ids.append(id)

		var item := TextureRect.new()
		item.texture = textures[id]
		item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.size = Vector2(ITEM_SIZE, ITEM_SIZE)
		item.position = Vector2(i * STEP, 0)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(item)

	var center_x := roundf(width / 2.0 - ITEM_SIZE / 2.0)
	var start_x := center_x - start_index * STEP
	var final_x := center_x - winner_index * STEP

	track.position = Vector2(start_x, 0)

	var tween := create_tween()
	tween.tween_property(track, "position:x", final_x, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		track.position.x = final_x
		var item_name := ITEM_NAMES[item_ids[winner_index]]
		print("Winner: ", item_name, " (item ", winner_index, ")")
		finished.emit(winner_index, item_name)
	)

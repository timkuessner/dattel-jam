extends Control

signal finished(winner_index: int, item_name: String)

const SLOT_SIZE := 64.0                 # size of one slot (same as the cross)
const PIXEL_SCALE := 3                  # 16px image * 3 = 48px (use 4 to fill the slot completely)
const SOURCE_SIZE := 16.0
const ICON_SIZE := SOURCE_SIZE * PIXEL_SCALE
const GAP := 0.0
const STEP := SLOT_SIZE + GAP

const IMAGE_FOLDER := "res://assets/sprites/items/"

const ITEM_NAMES: Array[String] = ["Blue fish", "Green fish", "Orange fish", "Trash", "Monster Energy"]
const ITEM_FILES: Array[String] = ["fish_blue.png", "fish_green.png", "fish_orange.png", "trash.png", "monster_energy.png"]

var textures: Array[Texture2D] = []

var reel: Control
var track: Control
var item_ids: Array[int] = []

const MONSTER_ID := 4   # index of "Monster Energy" in ITEM_NAMES
# Blue, Green, Orange, Trash, Monster -> Monster is super rare
const ITEM_WEIGHTS: Array[float] = [30.0, 30.0, 30.0, 30.0, 0.5]
const MONSTER_NEXT_TO_WINNER_CHANCE := 0.75

func _pick_weighted(allow_monster: bool = true) -> int:
	var total_weight := 0.0
	for i in ITEM_WEIGHTS.size():
		if i == MONSTER_ID and not allow_monster:
			continue
		total_weight += ITEM_WEIGHTS[i]

	var roll := randf() * total_weight
	for i in ITEM_WEIGHTS.size():
		if i == MONSTER_ID and not allow_monster:
			continue
		roll -= ITEM_WEIGHTS[i]
		if roll <= 0.0:
			return i
	return 0

func _ready() -> void:
	for file in ITEM_FILES:
		var tex := load(IMAGE_FOLDER + file) as Texture2D
		if tex == null:
			push_error("Could not load: " + IMAGE_FOLDER + file)
		textures.append(tex)

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

	# vertical centering inside the strip
	var y_offset := roundf((reel.size.y - SLOT_SIZE) / 2.0)
	var icon_margin := (SLOT_SIZE - ICON_SIZE) / 2.0

		# --- 1) generate the ids (weighted, monster is rare) ---
	for i in total:
		item_ids.append(_pick_weighted(true))

	# --- 2) the winner can NEVER be monster energy ---
	item_ids[winner_index] = _pick_weighted(false)

	# --- 3) 50/50 chance that monster energy is next to the winner ---
	var left := winner_index - 1
	var right := winner_index + 1
	item_ids[left] = _pick_weighted(false)    # clear both neighbors first
	item_ids[right] = _pick_weighted(false)
	if randf() < MONSTER_NEXT_TO_WINNER_CHANCE:
		var side := left if randi() % 2 == 0 else right
		item_ids[side] = MONSTER_ID

	# --- 4) build the visuals ---
	for i in total:
		var id := item_ids[i]

		var item := TextureRect.new()
		item.texture = textures[id]
		item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixels
		item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item.stretch_mode = TextureRect.STRETCH_SCALE
		item.size = Vector2(ICON_SIZE, ICON_SIZE)
		item.position = Vector2(i * STEP + icon_margin, y_offset + icon_margin)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(item)

	var center_x := roundf(width / 2.0 - SLOT_SIZE / 2.0)
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

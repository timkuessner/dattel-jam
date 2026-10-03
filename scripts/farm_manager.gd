class_name FarmManager
extends Node2D

const CropPlotScene := preload("res://scenes/crop_plot.tscn")
const FARM_TEXTURE := preload("res://assets/Tilemap/tilemap_farm.png")
const SOIL_AUTOTILE_TEXTURE := preload("res://assets/Tilemap/soil_autotile.png")

const FARM_ATLAS_SOURCE_ID := 0
const TOWN_ATLAS_SOURCE_ID := 1
const WELL_ATLAS := Vector2i(8, 8)

# The large green grass area is provided by the repeating background layer.
# Therefore a normal plantable grass cell is represented by an EMPTY Ground
# cell. Roads, shores, water borders and decorations occupy Ground/Objects and
# must never be converted into farmland.

# Connected dry-soil strip from tilemap_farm.png.
# Row 5 is the lighter cultivated-earth variant. The vertical pieces come
# from the matching first column.
const SOIL_LEFT_CAP := Vector2i(0, 5)
const SOIL_MIDDLE := Vector2i(1, 5)
const SOIL_RIGHT_CAP := Vector2i(2, 5)
const SOIL_ISOLATED := Vector2i(3, 5)
const SOIL_VERTICAL_TOP := Vector2i(0, 1)
const SOIL_VERTICAL_MIDDLE := Vector2i(0, 2)
const SOIL_VERTICAL_BOTTOM := Vector2i(0, 3)
const SOIL_VARIANTS := [
	SOIL_LEFT_CAP, SOIL_MIDDLE, SOIL_RIGHT_CAP, SOIL_ISOLATED,
	SOIL_VERTICAL_TOP, SOIL_VERTICAL_MIDDLE, SOIL_VERTICAL_BOTTOM
]

const TOOL_NONE := "none"
const TOOL_HOE := "hoe"
const TOOL_SEEDS := "seeds"
const TOOL_BUCKET := "bucket"

const ICON_HOE := Vector2i(3, 7)
const ICON_BUCKET_EMPTY := Vector2i(0, 6)
const ICON_BUCKET_FULL := Vector2i(1, 6)
const ICON_SEEDS := Vector2i(9, 0)

@export var bucket_capacity := 2

var selected_tool := TOOL_NONE
var has_hoe := false
var has_bucket := false
var carrot_seeds := 0
var harvested_carrots := 0
var water_units := 0
var discovered_seeds := false
var discovered_carrots := false
var discovered_water := false
var crops: Dictionary = {}
var tilled_cells: Dictionary = {}
var soil_sprites: Dictionary = {}

@onready var ground: TileMapLayer = $"../../Map/Ground"
@onready var objects: TileMapLayer = $"../../Map/Objects"
@onready var crops_root: Node2D = $Crops
@onready var soil_root: Node2D = $"../../Map/FarmSoil"
@onready var target_outline: Line2D = $TargetOutline
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var inventory_label: Label = $HUD/InventoryLabel
@onready var tool_label: Label = $HUD/ToolLabel
@onready var help_label: Label = $HUD/HelpLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var equipped_icon: Sprite2D = $HUD/EquippedIcon

func _ready() -> void:
	add_to_group("farm_system")
	selected_tool = TOOL_NONE
	water_units = 0
	carrot_seeds = 0
	_update_hud()
	interaction_prompt.visible = false
	target_outline.visible = false

func obtain_hoe() -> void:
	has_hoe = true
	selected_tool = TOOL_HOE
	_show_message("Hacke aufgehoben")
	_update_hud()

func obtain_bucket() -> void:
	has_bucket = true
	discovered_water = true
	water_units = 0
	selected_tool = TOOL_BUCKET
	_show_message("Leeren Eimer aufgehoben")
	_update_hud()

func add_carrot_seeds(amount: int) -> void:
	if amount <= 0:
		return
	discovered_seeds = true
	carrot_seeds += amount
	selected_tool = TOOL_SEEDS
	_show_message("+%d Karottensamen" % amount)
	_update_hud()

func select_tool(tool: String) -> void:
	match tool:
		TOOL_HOE:
			if not has_hoe:
				_show_message("Du hast noch keine Hacke")
				return
		TOOL_BUCKET:
			if not has_bucket:
				_show_message("Du hast noch keinen Eimer")
				return
		TOOL_SEEDS:
			if carrot_seeds <= 0:
				_show_message("Du hast keine Karottensamen")
				return
	selected_tool = tool
	_update_hud()

func request_interact(player: Node2D, facing_direction: Vector2) -> void:
	var interaction := _get_interaction(player, facing_direction)
	if interaction.is_empty():
		return

	var action: String = interaction["type"]
	var cell: Vector2i = interaction.get("cell", Vector2i.ZERO)

	match action:
		"pickup":
			var pickup: FarmPickup = interaction["pickup"]
			pickup.collect(self)
		"harvest":
			_harvest_crop(cell, crops[cell])
		"fill_bucket":
			water_units = bucket_capacity
			_show_message("Eimer gefüllt: %d/%d" % [water_units, bucket_capacity])
			_update_hud()
		"hoe":
			_use_hoe(cell)
		"plant":
			_use_seeds(cell)
		"water":
			_use_bucket(cell)

	update_player_target(player, facing_direction)

func update_player_target(player: Node2D, facing_direction: Vector2) -> void:
	var cell := _get_target_cell(player, facing_direction)
	var cell_world := ground.to_global(ground.map_to_local(cell))

	# A clear square marker makes the exact targeted 16x16 cell unambiguous.
	target_outline.global_position = cell_world
	target_outline.visible = true

	var interaction := _get_interaction(player, facing_direction)
	if interaction.is_empty():
		interaction_prompt.visible = false
	else:
		interaction_prompt.text = "E  " + String(interaction["label"])
		interaction_prompt.global_position = Vector2(cell_world.x, cell_world.y - 18)
		if interaction["type"] == "pickup":
			var p: Node2D = interaction["pickup"]
			interaction_prompt.global_position = p.global_position + Vector2(-18, -18)
		interaction_prompt.visible = true

func _get_interaction(player: Node2D, facing_direction: Vector2) -> Dictionary:
	var cell := _get_target_cell(player, facing_direction)
	var cell_world := ground.to_global(ground.map_to_local(cell))

	var pickup := _get_pickup_for_target(cell_world)
	if pickup != null:
		return {"type": "pickup", "label": "Aufheben", "pickup": pickup, "cell": cell}

	if crops.has(cell):
		var crop: CropPlot = crops[cell]
		if crop.is_mature:
			return {"type": "harvest", "label": "Ernten", "cell": cell}

	if selected_tool == TOOL_BUCKET and has_bucket and water_units < bucket_capacity and _is_well_target(cell):
		return {"type": "fill_bucket", "label": "Auffüllen", "cell": cell}

	match selected_tool:
		TOOL_HOE:
			if has_hoe and not crops.has(cell) and not _is_tilled_soil(cell) and _is_plantable_grass(cell):
				return {"type": "hoe", "label": "Hacken", "cell": cell}
		TOOL_SEEDS:
			if carrot_seeds > 0 and _is_tilled_soil(cell) and not crops.has(cell):
				return {"type": "plant", "label": "Pflanzen", "cell": cell}
		TOOL_BUCKET:
			if has_bucket and water_units > 0 and crops.has(cell):
				var crop: CropPlot = crops[cell]
				if not crop.is_mature:
					return {"type": "water", "label": "Gießen", "cell": cell}

	return {}

func _get_pickup_for_target(cell_world: Vector2) -> FarmPickup:
	var best: FarmPickup = null
	var best_distance := 14.0
	for node in get_tree().get_nodes_in_group("farm_pickup"):
		var pickup := node as FarmPickup
		if pickup == null:
			continue
		var distance := pickup.global_position.distance_to(cell_world)
		if distance < best_distance:
			best_distance = distance
			best = pickup
	return best

func _use_hoe(cell: Vector2i) -> void:
	if crops.has(cell) or _is_tilled_soil(cell) or not _is_plantable_grass(cell):
		return
	tilled_cells[cell] = true
	_ensure_soil_sprite(cell)
	_refresh_soil_connections(cell)
	_show_message("Boden bearbeitet")

func _use_seeds(cell: Vector2i) -> void:
	if carrot_seeds <= 0 or not _is_tilled_soil(cell) or crops.has(cell):
		return
	_plant_carrot(cell)
	carrot_seeds -= 1
	_show_message("Karotte gepflanzt")
	_update_hud()

func _use_bucket(cell: Vector2i) -> void:
	if water_units <= 0 or not crops.has(cell):
		return
	var crop: CropPlot = crops[cell]
	if crop.grow():
		water_units -= 1
		_show_message("Gegossen – %d/%d Wasser" % [water_units, bucket_capacity])
		_update_hud()

func _harvest_crop(cell: Vector2i, crop: CropPlot) -> void:
	crops.erase(cell)
	crop.queue_free()
	harvested_carrots += 1
	discovered_carrots = true
	_show_message("Karotte geerntet")
	_update_hud()

func _plant_carrot(cell: Vector2i) -> void:
	var crop := CropPlotScene.instantiate() as CropPlot
	crop.cell = cell
	crops_root.add_child(crop)
	crop.global_position = ground.to_global(ground.map_to_local(cell))
	crops[cell] = crop

func _get_target_cell(player: Node2D, facing_direction: Vector2) -> Vector2i:
	# Anchor the selector to the exact tile containing the player's origin.
	# The target is ALWAYS exactly one neighbouring 16x16 cell away:
	# left, right, up or down. No pixel/feet offset is applied.
	var player_cell := ground.local_to_map(ground.to_local(player.global_position))
	return player_cell + _cardinal_direction(facing_direction)

func _cardinal_direction(direction: Vector2) -> Vector2i:
	if direction == Vector2.ZERO:
		return Vector2i.DOWN
	if abs(direction.x) > abs(direction.y):
		return Vector2i.RIGHT if direction.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y > 0.0 else Vector2i.UP

func _is_plantable_grass(cell: Vector2i) -> bool:
	# In THIS map the normal full grass tile is on the Ground layer:
	# TileSet source 2 (tilemap_water.png), atlas coordinate (0, 0).
	# Border/shore/path tiles use different atlas coordinates, so they are
	# automatically protected and cannot be turned into farmland.
	const GRASS_SOURCE_ID := 2
	const FULL_GRASS_ATLAS := Vector2i(0, 0)

	if ground.get_cell_source_id(cell) != GRASS_SOURCE_ID:
		return false
	if ground.get_cell_atlas_coords(cell) != FULL_GRASS_ATLAS:
		return false
	if objects.get_cell_source_id(cell) != -1:
		return false
	return true

func _is_tilled_soil(cell: Vector2i) -> bool:
	return tilled_cells.has(cell)

func _ensure_soil_sprite(cell: Vector2i) -> Sprite2D:
	if soil_sprites.has(cell):
		return soil_sprites[cell] as Sprite2D
	var sprite := Sprite2D.new()
	sprite.name = "Soil_%d_%d" % [cell.x, cell.y]
	sprite.position = ground.map_to_local(cell)
	sprite.centered = true
	soil_root.add_child(sprite)
	soil_sprites[cell] = sprite
	return sprite

func _soil_neighbor_mask(cell: Vector2i) -> int:
	# 4-bit cardinal mask: N=1, E=2, S=4, W=8.
	# All 16 combinations therefore have their own visual tile.
	var mask := 0
	if _is_tilled_soil(cell + Vector2i.UP):
		mask |= 1
	if _is_tilled_soil(cell + Vector2i.RIGHT):
		mask |= 2
	if _is_tilled_soil(cell + Vector2i.DOWN):
		mask |= 4
	if _is_tilled_soil(cell + Vector2i.LEFT):
		mask |= 8
	return mask

func _set_soil_visual(cell: Vector2i) -> void:
	if not _is_tilled_soil(cell):
		return
	var sprite := _ensure_soil_sprite(cell)
	var mask := _soil_neighbor_mask(cell)
	var atlas := AtlasTexture.new()
	atlas.atlas = SOIL_AUTOTILE_TEXTURE
	atlas.region = Rect2(
		Vector2((mask % 4) * 16, int(mask / 4) * 16),
		Vector2(16, 16)
	)
	sprite.texture = atlas

func _refresh_soil_connections(changed_cell: Vector2i) -> void:
	# The changed cell can alter only itself and its four direct neighbours.
	# Every cell uses one of 16 N/E/S/W combinations, so corners, T-pieces
	# and four-way crossings are handled without horizontal/vertical priority.
	var cells := [
		changed_cell,
		changed_cell + Vector2i.UP,
		changed_cell + Vector2i.RIGHT,
		changed_cell + Vector2i.DOWN,
		changed_cell + Vector2i.LEFT,
	]
	for cell in cells:
		if _is_tilled_soil(cell):
			_set_soil_visual(cell)

func _is_well_target(cell: Vector2i) -> bool:
	if objects.get_cell_source_id(cell) == TOWN_ATLAS_SOURCE_ID and objects.get_cell_atlas_coords(cell) == WELL_ATLAS:
		return true
	var well := get_tree().get_first_node_in_group("water_well") as Node2D
	if well != null:
		var cell_world := ground.to_global(ground.map_to_local(cell))
		return cell_world.distance_to(well.global_position) <= 14.0
	return false

func _tool_name() -> String:
	match selected_tool:
		TOOL_HOE: return "Hacke"
		TOOL_SEEDS: return "Karottensamen"
		TOOL_BUCKET: return "Eimer"
		_: return "Leer"

func _set_icon(atlas_coord: Vector2i) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = FARM_TEXTURE
	atlas.region = Rect2(Vector2(atlas_coord.x * 17, atlas_coord.y * 17), Vector2(16, 16))
	equipped_icon.texture = atlas
	equipped_icon.visible = true

func _update_equipped_icon() -> void:
	match selected_tool:
		TOOL_HOE:
			_set_icon(ICON_HOE)
		TOOL_SEEDS:
			_set_icon(ICON_SEEDS)
		TOOL_BUCKET:
			_set_icon(ICON_BUCKET_FULL if water_units > 0 else ICON_BUCKET_EMPTY)
		_:
			equipped_icon.visible = false

func _show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(func():
		if is_instance_valid(message_label) and message_label.text == text:
			message_label.text = ""
	)

func _update_hud() -> void:
	var inventory_parts: Array[String] = []
	if discovered_seeds:
		inventory_parts.append("Samen: %d" % carrot_seeds)
	if discovered_carrots:
		inventory_parts.append("Karotten: %d" % harvested_carrots)
	if discovered_water:
		inventory_parts.append("Wasser: %d/%d" % [water_units, bucket_capacity])
	inventory_label.text = "   ".join(inventory_parts)
	inventory_label.visible = not inventory_parts.is_empty()

	tool_label.text = "Ausgerüstet: %s" % _tool_name()
	tool_label.visible = selected_tool != TOOL_NONE

	var help_parts: Array[String] = []
	if has_hoe:
		help_parts.append("5 Hacke")
	if discovered_seeds:
		help_parts.append("6 Samen")
	if has_bucket:
		help_parts.append("7 Eimer")
	help_label.text = "   ".join(help_parts)
	help_label.visible = not help_parts.is_empty()
	_update_equipped_icon()

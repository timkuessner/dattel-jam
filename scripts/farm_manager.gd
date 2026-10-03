class_name FarmManager
extends Node2D

const CropPlotScene := preload("res://scenes/crop_plot.tscn")
const SOIL_AUTOTILE_TEXTURE := preload("res://assets/Tilemap/soil_autotile.png")

const TOWN_ATLAS_SOURCE_ID := 1
const WELL_ATLAS := Vector2i(8, 8)

const TOOL_NONE := "none"
const TOOL_HOE := "hoe"
const TOOL_SEEDS := "seeds"
const TOOL_BUCKET := "bucket"

@export var bucket_capacity := 2

var selected_tool := TOOL_NONE
var water_units := 0
var crops: Dictionary = {}
var tilled_cells: Dictionary = {}
var soil_sprites: Dictionary = {}
var _player_using_farm_prompt: Player = null

@onready var ground: TileMapLayer = $"../../Map/Ground"
@onready var objects: TileMapLayer = $"../../Map/Objects"
@onready var crops_root: Node2D = $Crops
@onready var soil_root: Node2D = $"../../Map/FarmSoil"
@onready var target_outline: Line2D = $TargetOutline

func _ready() -> void:
	add_to_group("farm_system")
	target_outline.visible = false

func select_tool(tool: String, player: Player) -> void:
	match tool:
		TOOL_HOE:
			if not player.inventory.has(Item.items.HOE):
				return
		TOOL_SEEDS:
			if not player.inventory.has(Item.items.CARROT_SEEDS):
				return
		TOOL_BUCKET:
			if not player.inventory.has(Item.items.BUCKET):
				return
	selected_tool = tool
	update_player_target(player, player.facing_direction)

func interact(player: Player) -> void:
	var interaction := _get_interaction(player, player.facing_direction)
	if interaction.is_empty():
		return

	var action: String = interaction["type"]
	var cell: Vector2i = interaction.get("cell", Vector2i.ZERO)

	match action:
		"harvest":
			_harvest_crop(player, cell, crops[cell])
		"fill_bucket":
			water_units = bucket_capacity
			_refresh_bucket_inventory_icon()
		"hoe":
			_use_hoe(cell)
		"plant":
			_use_seeds(player, cell)
		"water":
			_use_bucket(cell)

	update_player_target(player, player.facing_direction)

func update_player_target(player: Player, facing_direction: Vector2) -> void:
	var cell := _get_target_cell(player, facing_direction)
	var cell_world := ground.to_global(ground.map_to_local(cell))
	target_outline.global_position = cell_world
	target_outline.visible = selected_tool != TOOL_NONE

	var interaction := _get_interaction(player, facing_direction)
	if interaction.is_empty():
		if player.area == self:
			player.exitArea(self)
		_player_using_farm_prompt = null
	elif player.area == null or player.area == self:
		player.enterArea(self)
		_player_using_farm_prompt = player

func _get_interaction(player: Player, facing_direction: Vector2) -> Dictionary:
	var cell := _get_target_cell(player, facing_direction)

	if crops.has(cell):
		var crop: CropPlot = crops[cell]
		if crop.is_mature:
			return {"type": "harvest", "cell": cell}

	if selected_tool == TOOL_BUCKET and player.inventory.has(Item.items.BUCKET) and water_units < bucket_capacity and _is_well_target(cell):
		return {"type": "fill_bucket", "cell": cell}

	match selected_tool:
		TOOL_HOE:
			if player.inventory.has(Item.items.HOE) and not crops.has(cell) and not _is_tilled_soil(cell) and _is_plantable_grass(cell):
				return {"type": "hoe", "cell": cell}
		TOOL_SEEDS:
			if player.inventory.get(Item.items.CARROT_SEEDS, 0) > 0 and _is_tilled_soil(cell) and not crops.has(cell):
				return {"type": "plant", "cell": cell}
		TOOL_BUCKET:
			if player.inventory.has(Item.items.BUCKET) and water_units > 0 and crops.has(cell):
				var crop: CropPlot = crops[cell]
				if not crop.is_mature:
					return {"type": "water", "cell": cell}

	return {}

func _use_hoe(cell: Vector2i) -> void:
	if crops.has(cell) or _is_tilled_soil(cell) or not _is_plantable_grass(cell):
		return
	tilled_cells[cell] = true
	_ensure_soil_sprite(cell)
	_refresh_soil_connections(cell)

func _use_seeds(player: Player, cell: Vector2i) -> void:
	if player.inventory.get(Item.items.CARROT_SEEDS, 0) <= 0 or not _is_tilled_soil(cell) or crops.has(cell):
		return
	_plant_carrot(cell)
	player.remove_item(Item.items.CARROT_SEEDS)

func _use_bucket(cell: Vector2i) -> void:
	if water_units <= 0 or not crops.has(cell):
		return
	var crop: CropPlot = crops[cell]
	if crop.grow():
		water_units -= 1
		_refresh_bucket_inventory_icon()

func _refresh_bucket_inventory_icon() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var inventory_ui := player.get_node_or_null("../PlayerHUD/Inventory")
	if inventory_ui != null and inventory_ui.has_method("refresh_bucket_visual"):
		inventory_ui.refresh_bucket_visual()

func _harvest_crop(player: Player, cell: Vector2i, crop: CropPlot) -> void:
	crops.erase(cell)
	crop.queue_free()
	player.add_item(Item.items.CARROT)

func _plant_carrot(cell: Vector2i) -> void:
	var crop := CropPlotScene.instantiate() as CropPlot
	crop.cell = cell
	crops_root.add_child(crop)
	crop.global_position = ground.to_global(ground.map_to_local(cell))
	crops[cell] = crop

func _get_target_cell(player: Node2D, facing_direction: Vector2) -> Vector2i:
	var player_cell := ground.local_to_map(ground.to_local(player.global_position))
	return player_cell + _cardinal_direction(facing_direction)

func _cardinal_direction(direction: Vector2) -> Vector2i:
	if direction == Vector2.ZERO:
		return Vector2i.DOWN
	if abs(direction.x) > abs(direction.y):
		return Vector2i.RIGHT if direction.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y > 0.0 else Vector2i.UP

func _is_plantable_grass(cell: Vector2i) -> bool:
	# Beide verwendeten Tilesets enthalten dieselben zwei begehbaren Gras-Tiles:
	# (0, 0) = normales Grün, (1, 0) = Grün mit dunkelgrünen Blättern/Grashalmen.
	const PLANTABLE_GRASS := {
		1: [Vector2i(0, 0), Vector2i(1, 0)],
		2: [Vector2i(0, 0), Vector2i(1, 0)],
	}

	var source_id := ground.get_cell_source_id(cell)
	var atlas_coords := ground.get_cell_atlas_coords(cell)

	if not PLANTABLE_GRASS.has(source_id):
		return false
	if atlas_coords not in PLANTABLE_GRASS[source_id]:
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
	var mask := 0
	if _is_tilled_soil(cell + Vector2i.UP): mask |= 1
	if _is_tilled_soil(cell + Vector2i.RIGHT): mask |= 2
	if _is_tilled_soil(cell + Vector2i.DOWN): mask |= 4
	if _is_tilled_soil(cell + Vector2i.LEFT): mask |= 8
	return mask

func _set_soil_visual(cell: Vector2i) -> void:
	if not _is_tilled_soil(cell):
		return
	var sprite := _ensure_soil_sprite(cell)
	var mask := _soil_neighbor_mask(cell)
	var atlas := AtlasTexture.new()
	atlas.atlas = SOIL_AUTOTILE_TEXTURE
	atlas.region = Rect2(Vector2((mask % 4) * 16, int(mask / 4) * 16), Vector2(16, 16))
	sprite.texture = atlas

func _refresh_soil_connections(changed_cell: Vector2i) -> void:
	for cell in [changed_cell, changed_cell + Vector2i.UP, changed_cell + Vector2i.RIGHT, changed_cell + Vector2i.DOWN, changed_cell + Vector2i.LEFT]:
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

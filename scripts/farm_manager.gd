class_name FarmManager
extends Node2D

const CropPlotScene := preload("res://scenes/crop_plot.tscn")

const SOIL_TEXTURES := {
	"dry_h_left": preload("res://assets/Tilemap/soil_runtime/dry_h_left.png"),
	"dry_h_middle": preload("res://assets/Tilemap/soil_runtime/dry_h_middle.png"),
	"dry_h_right": preload("res://assets/Tilemap/soil_runtime/dry_h_right.png"),
	"dry_h_single": preload("res://assets/Tilemap/soil_runtime/dry_h_single.png"),
	"wet_h_left": preload("res://assets/Tilemap/soil_runtime/wet_h_left.png"),
	"wet_h_middle": preload("res://assets/Tilemap/soil_runtime/wet_h_middle.png"),
	"wet_h_right": preload("res://assets/Tilemap/soil_runtime/wet_h_right.png"),
	"wet_h_single": preload("res://assets/Tilemap/soil_runtime/wet_h_single.png"),
	"dry_v_single": preload("res://assets/Tilemap/soil_runtime/dry_v_single.png"),
	"dry_v_top": preload("res://assets/Tilemap/soil_runtime/dry_v_top.png"),
	"dry_v_middle": preload("res://assets/Tilemap/soil_runtime/dry_v_middle.png"),
	"dry_v_bottom": preload("res://assets/Tilemap/soil_runtime/dry_v_bottom.png"),
	"wet_v_single": preload("res://assets/Tilemap/soil_runtime/wet_v_single.png"),
	"wet_v_top": preload("res://assets/Tilemap/soil_runtime/wet_v_top.png"),
	"wet_v_middle": preload("res://assets/Tilemap/soil_runtime/wet_v_middle.png"),
	"wet_v_bottom": preload("res://assets/Tilemap/soil_runtime/wet_v_bottom.png"),
}

const WATER_ATLAS_SOURCE_ID := 2
const WATERSET_LAND_TILES := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

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

# Alle Felder, die HEUTE gegossen wurden.
# In der Nacht wachsen Pflanzen auf diesen Feldern und der Boden trocknet wieder.
var watered_cells: Dictionary = {}

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
	update_player_target(player)


func interact(player: Player) -> void:
	var interaction := _get_interaction(player)

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

	update_player_target(player)


# Das unsichtbare Interaktionsfeld ist ein 3x3-Raster um den Player.
# Welches der 9 Tiles benutzt wird, bestimmt ausschließlich die Mausposition.
func update_player_target(
	player: Player,
	_facing_direction: Vector2 = Vector2.ZERO
) -> void:
	var target_cell_variant = _get_mouse_target_cell(player)

	if target_cell_variant == null:
		target_outline.visible = false

		# Das Auffüllen am Wasser hängt nur davon ab, wo der Player steht.
		# Dafür muss die Maus nicht auf einem bestimmten Tile liegen.
		if _can_fill_bucket_at_water_edge(player):
			if player.area == null or player.area == self:
				player.enterArea(self)
			_player_using_farm_prompt = player
			return

		if player.area == self:
			player.exitArea(self)

		_player_using_farm_prompt = null
		return

	var cell: Vector2i = target_cell_variant
	var cell_world := ground.to_global(ground.map_to_local(cell))

	target_outline.global_position = cell_world
	target_outline.visible = selected_tool != TOOL_NONE

	var interaction := _get_interaction(player)

	if interaction.is_empty():
		if player.area == self:
			player.exitArea(self)

		_player_using_farm_prompt = null
	elif player.area == null or player.area == self:
		player.enterArea(self)
		_player_using_farm_prompt = player


func _get_interaction(player: Player) -> Dictionary:
	# Der alte Brunnen ist komplett entfernt. Mit ausgewähltem Eimer kann man
	# ihn jetzt direkt am Ufer auffüllen, sobald der Player auf einem Rand-Tile
	# steht bzw. direkt an ein Wasser-Tile angrenzt.
	if _can_fill_bucket_at_water_edge(player):
		return {
			"type": "fill_bucket"
		}

	var target_cell_variant = _get_mouse_target_cell(player)

	if target_cell_variant == null:
		return {}

	var cell: Vector2i = target_cell_variant

	# Eine reife Karotte kann mit E geerntet werden, egal welches Werkzeug aktiv ist.
	if crops.has(cell):
		var crop: CropPlot = crops[cell]
		if crop.is_mature:
			return {
				"type": "harvest",
				"cell": cell
			}

	match selected_tool:
		TOOL_HOE:
			if (
				player.inventory.has(Item.items.HOE)
				and not crops.has(cell)
				and not _is_tilled_soil(cell)
				and _is_plantable_grass(cell)
			):
				return {
					"type": "hoe",
					"cell": cell
				}

		TOOL_SEEDS:
			if (
				player.inventory.get(Item.items.CARROT_SEEDS, 0) > 0
				and _is_tilled_soil(cell)
				and not crops.has(cell)
			):
				return {
					"type": "plant",
					"cell": cell
				}

		TOOL_BUCKET:
			# Auch ein noch unbepflanztes gehacktes Feld kann gegossen werden.
			# Wachstum passiert trotzdem erst in der Nacht und nur, falls eine Pflanze darauf steht.
			if (
				player.inventory.has(Item.items.BUCKET)
				and water_units > 0
				and _is_tilled_soil(cell)
				and not watered_cells.has(cell)
			):
				return {
					"type": "water",
					"cell": cell
				}

	return {}


func _use_hoe(cell: Vector2i) -> void:
	if crops.has(cell):
		return

	if _is_tilled_soil(cell):
		return

	if not _is_plantable_grass(cell):
		return

	tilled_cells[cell] = true
	_ensure_soil_sprite(cell)
	_refresh_soil_connections(cell)


func _use_seeds(player: Player, cell: Vector2i) -> void:
	if player.inventory.get(Item.items.CARROT_SEEDS, 0) <= 0:
		return

	if not _is_tilled_soil(cell):
		return

	if crops.has(cell):
		return

	_plant_carrot(cell)
	player.remove_item(Item.items.CARROT_SEEDS)


func _use_bucket(cell: Vector2i) -> void:
	if water_units <= 0:
		return

	if not _is_tilled_soil(cell):
		return

	if watered_cells.has(cell):
		return

	# Gießen lässt die Pflanze NICHT sofort wachsen.
	# Es markiert nur das Feld als gegossen und schaltet auf den dunklen Boden-Frame.
	watered_cells[cell] = true
	water_units -= 1
	_set_soil_wet(cell, true)
	_refresh_bucket_inventory_icon()


func advance_day() -> void:
	# Wird beim Schlafengehen einmal aufgerufen:
	# 1. gegossene Karotten wachsen um genau eine Stufe
	# 2. alle heute gegossenen Böden werden wieder trocken/hell
	# 3. am neuen Tag können sie erneut gegossen werden
	var watered_today := watered_cells.keys().duplicate()

	for cell_variant in watered_today:
		var cell: Vector2i = cell_variant

		if crops.has(cell):
			var crop: CropPlot = crops[cell]
			if not crop.is_mature:
				crop.grow()

		_set_soil_wet(cell, false)

	watered_cells.clear()


func _refresh_bucket_inventory_icon() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if player == null:
		return

	var inventory_ui := player.get_node_or_null("../PlayerHUD/Inventory")

	if inventory_ui != null and inventory_ui.has_method("refresh_bucket_visual"):
		inventory_ui.refresh_bucket_visual()


func _harvest_crop(player: Player, cell: Vector2i, crop: CropPlot) -> void:
	crops.erase(cell)
	watered_cells.erase(cell)
	_set_soil_wet(cell, false)
	crop.queue_free()
	player.add_item(Item.items.CARROT)


func _plant_carrot(cell: Vector2i) -> void:
	var crop := CropPlotScene.instantiate() as CropPlot
	crop.cell = cell
	crops_root.add_child(crop)
	crop.global_position = ground.to_global(ground.map_to_local(cell))
	crops[cell] = crop


func _get_mouse_target_cell(player: Node2D) -> Variant:
	# Die CharacterBody2D-Position liegt wegen der Player-Collision optisch zu tief.
	# Das 3x3-Feld wird deshalb bewusst EIN TILE nach oben verschoben, damit
	# es wirklich um die sichtbare Spielfigur liegt.
	var player_cell := ground.local_to_map(ground.to_local(player.global_position)) + Vector2i.UP
	var mouse_cell := ground.local_to_map(ground.to_local(get_global_mouse_position()))
	var offset := mouse_cell - player_cell

	# Unsichtbares 3x3-Raster rund um den korrigierten Player-Mittelpunkt.
	if abs(offset.x) > 1 or abs(offset.y) > 1:
		return null

	return mouse_cell


func _is_plantable_grass(cell: Vector2i) -> bool:
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
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# FarmSoil selbst liegt bereits über dem Ground. z_index 0 hält
	# alle Bodenstücke auf derselben Ebene innerhalb dieses Layers.
	soil_root.add_child(sprite)
	soil_sprites[cell] = sprite
	return sprite


func _soil_neighbor_mask(cell: Vector2i) -> int:
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

	_set_soil_wet(cell, watered_cells.has(cell))


func _set_soil_wet(cell: Vector2i, wet: bool) -> void:
	if not _is_tilled_soil(cell):
		return

	var sprite := _ensure_soil_sprite(cell)
	sprite.texture = _get_soil_texture(cell, wet)
	sprite.modulate = Color.WHITE


func _get_soil_texture(cell: Vector2i, wet: bool) -> Texture2D:
	var up := _is_tilled_soil(cell + Vector2i.UP)
	var right := _is_tilled_soil(cell + Vector2i.RIGHT)
	var down := _is_tilled_soil(cell + Vector2i.DOWN)
	var left := _is_tilled_soil(cell + Vector2i.LEFT)

	var horizontal_count := int(left) + int(right)
	var vertical_count := int(up) + int(down)
	var prefix := "dry" if wet else "wet"

	# Reine horizontale Reihe
	if horizontal_count > vertical_count:
		if left and right:
			return SOIL_TEXTURES["%s_h_middle" % prefix]
		if right:
			return SOIL_TEXTURES["%s_h_left" % prefix]
		if left:
			return SOIL_TEXTURES["%s_h_right" % prefix]
		return SOIL_TEXTURES["%s_h_single" % prefix]

	# Reine vertikale Reihe
	if vertical_count > horizontal_count:
		if up and down:
			return SOIL_TEXTURES["%s_v_middle" % prefix]
		if down:
			return SOIL_TEXTURES["%s_v_top" % prefix]
		if up:
			return SOIL_TEXTURES["%s_v_bottom" % prefix]
		return SOIL_TEXTURES["%s_v_single" % prefix]

	# Einzelnes Feld oder Mischform: lieber das sichere einzelne Feld,
	# damit nie wieder ein falscher Ausschnitt aus dem Atlas erscheint.
	if horizontal_count == 0 and vertical_count == 0:
		return SOIL_TEXTURES["%s_h_single" % prefix]

	# Bei Ecken/T-Kreuzungen/Kreuzen ist das horizontale Feld optisch am stimmigsten.
	if left and right:
		return SOIL_TEXTURES["%s_h_middle" % prefix]
	if right:
		return SOIL_TEXTURES["%s_h_left" % prefix]
	if left:
		return SOIL_TEXTURES["%s_h_right" % prefix]
	if down:
		return SOIL_TEXTURES["%s_v_top" % prefix]
	if up:
		return SOIL_TEXTURES["%s_v_bottom" % prefix]

	return SOIL_TEXTURES["%s_h_single" % prefix]


func _refresh_soil_connections(changed_cell: Vector2i) -> void:
	var affected_cells := [
		changed_cell,
		changed_cell + Vector2i.UP,
		changed_cell + Vector2i.RIGHT,
		changed_cell + Vector2i.DOWN,
		changed_cell + Vector2i.LEFT
	]

	for cell in affected_cells:
		if _is_tilled_soil(cell):
			_set_soil_visual(cell)


func _can_fill_bucket_at_water_edge(player: Player) -> bool:
	if selected_tool != TOOL_BUCKET:
		return false

	if not player.inventory.has(Item.items.BUCKET):
		return false

	# Der Eimer kann erst wieder aufgefüllt werden, wenn beide Wasser-Einheiten
	# verbraucht sind. Eine Füllung reicht dadurch exakt für 2 Felder.
	if water_units > 0:
		return false

	return _player_is_at_water_edge(player)


func _player_is_at_water_edge(player: Node2D) -> bool:
	# Gleicher optischer Zell-Offset wie beim 3x3-Interaktionsraster.
	var player_cell := ground.local_to_map(ground.to_local(player.global_position)) + Vector2i.UP

	# Einige Ufer-Tiles enthalten gleichzeitig Gras und Wasser. Wenn der Player
	# auf dem begehbaren Rand dieser Zelle steht, soll Auffüllen ebenfalls gehen.
	if _tile_contains_water(player_cell):
		return true

	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if _tile_contains_water(player_cell + direction):
			return true

	return false


func _tile_contains_water(cell: Vector2i) -> bool:
	if ground.get_cell_source_id(cell) != WATER_ATLAS_SOURCE_ID:
		return false

	var atlas_coords := ground.get_cell_atlas_coords(cell)

	# Die ersten drei Tiles der Wasser-Atlas-Zeile sind reine Grasvarianten.
	# Alle anderen im verwendeten Wasser-Tileset enthalten Wasser/Ufer.
	return atlas_coords not in WATERSET_LAND_TILES

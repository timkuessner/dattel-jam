class_name FarmPickup
extends Node2D

const TILE_SIZE := 16
const FARM_TEXTURE := preload("res://assets/Tilemap/tilemap_farm.png")

@export_enum("hoe", "bucket", "seeds") var item_type := "seeds"
@export var amount := 1
@export var atlas_coord := Vector2i(9, 0)

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("farm_pickup")
	_update_texture()

func _update_texture() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = FARM_TEXTURE
	atlas.region = Rect2(Vector2(atlas_coord.x * 17, atlas_coord.y * 17), Vector2(TILE_SIZE, TILE_SIZE))
	sprite.texture = atlas

func get_action_text() -> String:
	return "Aufheben"

func collect(farm_manager: Node) -> void:
	match item_type:
		"hoe":
			farm_manager.obtain_hoe()
		"bucket":
			farm_manager.obtain_bucket()
		"seeds":
			farm_manager.add_carrot_seeds(amount)
	queue_free()

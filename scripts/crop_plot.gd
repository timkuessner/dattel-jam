class_name CropPlot
extends Node2D

const TILE_SIZE := 16
const FARM_TEXTURE := preload("res://assets/Tilemap/tilemap_farm.png")

# Karotte: jung -> mittel -> erntereif.
const CARROT_STAGES: Array[Vector2i] = [
	Vector2i(4, 0),
	Vector2i(5, 0),
	Vector2i(6, 0),
]

var cell := Vector2i.ZERO
var growth_stage := 0
var is_mature := false

@onready var crop_sprite: Sprite2D = $CropSprite

func _ready() -> void:
	_update_visual()

func grow() -> bool:
	if is_mature:
		return false
	growth_stage += 1
	if growth_stage >= CARROT_STAGES.size() - 1:
		growth_stage = CARROT_STAGES.size() - 1
		is_mature = true
	_update_visual()
	return true

func _update_visual() -> void:
	if not crop_sprite:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = FARM_TEXTURE
	var atlas_coord := CARROT_STAGES[growth_stage]
	atlas.region = Rect2(Vector2(atlas_coord.x * 17, atlas_coord.y * 17), Vector2(TILE_SIZE, TILE_SIZE))
	crop_sprite.texture = atlas

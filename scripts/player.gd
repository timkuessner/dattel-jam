class_name Player
extends CharacterBody2D

const RECORD_INTERVAL := 0.1
const GHOST_SCENE := preload("res://scenes/ghost.tscn")
const FINALE_DAY := 5
const INTERACT_PROMPT_SWAP_INTERVAL := 0.7

var recording: Array = []
var record_timer := 0.0
var finale := false
var is_chopping := false

const SPEED = 80.0
const BED_POSITION := Vector2(50, 50)
const GALLOW_POSITION := Vector2(96, 200)


@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var facing_direction := Vector2.DOWN

var n = 0

var isDay = true
var night_phase = 0

var inventory: Dictionary = {}

var pos_array: Array[Array] = []

var area: Node2D
var _alternate_interact_prompt := false
var _interact_prompt_timer := 0.0
var _show_click_prompt := false

@onready var interact_ui: Sprite2D = $Interact
@onready var interact_label: Label = $Interact/Label
@onready var interact_items: AnimatedSprite2D = $Interact/Items
@onready var interact_click_icon: Sprite2D = $Interact/ClickIcon


func add_item(item, amount: int = 1):
	if amount <= 0:
		return

	inventory[item] = inventory.get(item, 0) + amount
	$"../PlayerHUD/Inventory".update_slots(inventory)


func remove_item(item):
	if not inventory.has(item):
		return

	inventory[item] -= 1

	if inventory[item] <= 0:
		inventory.erase(item)

	$"../PlayerHUD/Inventory".update_slots(inventory)


func _ready() -> void:
	add_to_group("player")

	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	
	$"../Gallows".updateGallows(n)


func showLabel(text):
	if !isDay:
		return

	if text == "E / LMB":
		_show_alternating_interact_prompt()
		return

	_alternate_interact_prompt = false
	interact_ui.show()
	interact_label.text = text
	interact_label.show()
	interact_click_icon.hide()
	interact_items.hide()


func showInteractItem(item):
	if !isDay:
		return

	_alternate_interact_prompt = false
	interact_ui.show()
	interact_label.hide()
	interact_click_icon.hide()
	interact_items.play(str(Item.items.keys()[item]))
	interact_items.show()


func hideInteract():
	_alternate_interact_prompt = false
	interact_ui.hide()
	interact_label.hide()
	interact_click_icon.hide()
	interact_items.hide()


func _show_alternating_interact_prompt() -> void:
	_alternate_interact_prompt = true
	_interact_prompt_timer = 0.0
	_show_click_prompt = false
	interact_ui.show()
	interact_items.hide()
	_update_alternating_interact_prompt()


func _update_alternating_interact_prompt() -> void:
	if not _alternate_interact_prompt:
		return

	if _show_click_prompt:
		interact_label.hide()
		interact_click_icon.show()
	else:
		interact_click_icon.hide()
		interact_label.text = "E"
		interact_label.show()


func enterArea(a):
	showLabel("E / LMB")
	area = a


func exitArea(a):
	hideInteract()

	if area == a:
		area = null


func enterFire():
	if Item.items.WOOD in inventory:
		showLabel("E / LMB")
	else:
		showInteractItem(Item.items.WOOD)

	area = $"../Fire"


func exitFire():
	exitArea($"../Fire")


func start_night() -> void:
	isDay = false
	night_phase = 0

	if recording.size() >= 2:
		pos_array.append(recording.duplicate())

	recording = []
	record_timer = 0.0

	nav_agent.target_position = BED_POSITION

var t = 0

func _process(delta: float) -> void:
	if not _alternate_interact_prompt or not interact_ui.visible:
		return

	_interact_prompt_timer += delta

	if _interact_prompt_timer >= INTERACT_PROMPT_SWAP_INTERVAL:
		_interact_prompt_timer = 0.0
		_show_click_prompt = not _show_click_prompt
		_update_alternating_interact_prompt()


func _physics_process(delta: float) -> void:
	if finale:
		t += delta
		
		if t >= 17:
			$"../PlayerHUD".night(false)
			$"../Gallows".updateGallows(6)
		
		return
		
	if $"../PlayerHUD".get_energy() <= 0 and isDay:
		start_night()
	
	if !isDay:
		_walk_at_night(delta)
		return
	
	# Pfeiltasten bleiben erhalten; WASD ist zusätzlich möglich.
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	var wasd_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if wasd_direction != Vector2.ZERO:
		direction = wasd_direction

	if Input.is_action_just_pressed("ui_accept"):
		$"../PlayerHUD".decrease_energy(1)
		$"../PlayerHUD".update()
	
	if not is_chopping:
		if direction:
			_update_facing_direction(direction)
			velocity = direction * SPEED
			_play_direction_animation("run")
		else:
			velocity = Vector2.ZERO
			_play_direction_animation("idle")
	else:
		velocity = Vector2.ZERO
		
	
	move_and_slide()
	
	if Input.is_action_just_pressed("e"):
		_try_context_interaction()
	
	if Input.is_action_just_pressed("ui_home"):
		$"../Fire".buildFire()
	
	var farm_system := get_tree().get_first_node_in_group("farm_system")

	if farm_system:
		farm_system.update_player_target(self, facing_direction)
	
	record_timer += delta

	if record_timer >= RECORD_INTERVAL:
		record_timer = 0.0
		recording.append(global_position)


func _input(event: InputEvent) -> void:
	# Linksklick hat seine EIGENE Input-Action und ist nicht an die Action "e" gebunden.
	# Beide rufen am Ende nur dieselbe Kontextfunktion auf.
	if event.is_action_pressed("mouse_interact"):
		if event is InputEventMouseButton and (event as InputEventMouseButton).double_click:
			return

		# Klicks auf das Inventar dürfen keine Aktion in der Welt auslösen.
		var hovered_control := get_viewport().gui_get_hovered_control()
		var inventory_ui := get_node_or_null("../PlayerHUD/Inventory") as Control

		if (
			inventory_ui != null
			and hovered_control != null
			and (
				hovered_control == inventory_ui
				or inventory_ui.is_ancestor_of(hovered_control)
			)
		):
			return

		_try_context_interaction()


func _try_context_interaction() -> void:
	if not isDay or is_chopping:
		return

	# Vor einem Klick das aktuelle Maus-Tile noch einmal sofort prüfen.
	# So funktioniert ein Klick auch dann zuverlässig, wenn die Maus gerade erst
	# auf ein anderes Feld bewegt wurde und noch kein neuer Physics-Frame lief.
	var farm_system := get_tree().get_first_node_in_group("farm_system")
	if farm_system != null:
		farm_system.update_player_target(self, facing_direction)

	if area == null:
		return

	if area == $"../Fire":
		if Item.items.WOOD in inventory:
			$"../Fire".buildFire()
			remove_item(Item.items.WOOD)

		exitFire()
		return

	if area.has_method("interact"):
		area.interact(self)

func play_tree_animation() -> void:
	is_chopping = true
	velocity = Vector2.ZERO

	_play_direction_animation("tree")

	await $AnimatedSprite2D.animation_finished

	is_chopping = false

func _update_facing_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		facing_direction = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT

	elif abs(direction.y) > abs(direction.x):
		facing_direction = Vector2.DOWN if direction.y > 0 else Vector2.UP

	elif facing_direction.x != 0 and direction.x != 0:
		facing_direction = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT

	elif direction.y != 0:
		facing_direction = Vector2.DOWN if direction.y > 0 else Vector2.UP


func _play_direction_animation(animation_type: String) -> void:
	if facing_direction == Vector2.RIGHT:
		$AnimatedSprite2D.play(animation_type + "_right")

	elif facing_direction == Vector2.LEFT:
		$AnimatedSprite2D.play(animation_type + "_left")

	elif facing_direction == Vector2.UP:
		$AnimatedSprite2D.play(animation_type + "_up")

	elif facing_direction == Vector2.DOWN:
		$AnimatedSprite2D.play(animation_type + "_down")


func _walk_at_night(delta: float) -> void:
	if nav_agent.is_navigation_finished():

		if night_phase == 0:
			night_phase = 1

			$AnimatedSprite2D.play("sleep")

			# Erst beim Schlafen wachsen bewässerte Pflanzen.
			var farm_system := get_tree().get_first_node_in_group("farm_system")

			if farm_system != null and farm_system.has_method("advance_day"):
				farm_system.advance_day()

			nav_agent.target_position = GALLOW_POSITION
			$"../PlayerHUD".night(true)
			$"../PlayerHUD/Inventory".hide()
			$AnimatedSprite2D.modulate = Color(0.0, 0.0, 0.0, 1.0)
			$"../PlayerHUD".decrease_psyche(1)
			return

		elif night_phase == 1:
			night_phase = 2
			
			n += 1
			$"../Gallows".updateGallows(n)
			
			nav_agent.target_position = BED_POSITION
			
			return
		
		elif night_phase == 2:
			if n >= FINALE_DAY:
				start_finale()
				return
			isDay = true
			night_phase = 0
			
			velocity = Vector2.ZERO

			$"../PlayerHUD".increase_energy(4)
			$"../PlayerHUD".update()
			
			_play_direction_animation("idle")
			$"../PlayerHUD".night(false)
			$"../PlayerHUD/Inventory".show()
			$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)
			return
	
	var next_pos := nav_agent.get_next_path_position()
	var dir := global_position.direction_to(next_pos)
	
	_update_facing_direction(dir)
	
	global_position = global_position.move_toward(
		next_pos,
		SPEED * delta
	)

	_play_direction_animation("run")


func start_finale() -> void:

	finale = true
	velocity = Vector2.ZERO
	$AnimatedSprite2D.hide()

	for rec in pos_array:
		var g = GHOST_SCENE.instantiate()
		get_parent().add_child(g)
		g.start(rec, 10.0, 5.0, GALLOW_POSITION)

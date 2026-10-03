class_name Player
extends CharacterBody2D

const SPEED = 80.0
const BED_POSITION := Vector2(50, 50)
const GALLOW_POSITION := Vector2(96, 200)

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var energy = 5
var psyche = 5
var hunger = 5

var facing_direction := Vector2.DOWN

var n = 0

var isDay = true
var night_phase = 0

var inventory: Dictionary = {}

func add_item(item):
	inventory[item] = inventory.get(item, 0) + 1
	$"../PlayerHUD/Inventory".update_slots(inventory)

func remove_item(item):
	if not inventory.has(item):
		return

	inventory[item] -= 1

	if inventory[item] <= 0:
		inventory.erase(item)

	$"../PlayerHUD/Inventory".update_slots(inventory)

var area: Node2D


func _ready() -> void:
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	
	$"../Gallows".updateGallows(n)

func enterArea(a):
	$Interact.show()
	area = a

func exitArea(a):
	$Interact.hide()
	if area == a:
		area = null

func enterFire():
	if Item.items.WOOD in inventory:
		$Interact.show()
	area = $"../Fire"

func exitFire():
	exitArea($"../Fire")

func start_night() -> void:
	isDay = false
	night_phase = 0
	
	nav_agent.target_position = BED_POSITION


func _physics_process(delta: float) -> void:
	if $"../PlayerHUD".get_energy() <= 0 and isDay:
		start_night()
	
	if !isDay:
		_walk_at_night(delta)
		return
	
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	if Input.is_action_just_pressed("ui_accept"):
		$"../PlayerHUD".decrease_energy(1)
		$"../PlayerHUD".update()
	
	if direction:
		_update_facing_direction(direction)
		velocity = direction * SPEED
		_play_direction_animation("run")
	else:
		velocity = Vector2.ZERO
		_play_direction_animation("idle")
	
	move_and_slide()
	
	if Input.is_action_just_pressed("e"):
		if area:
			if area == $"../Fire":
				if Item.items.WOOD in inventory:
					$"../Fire".buildFire()
					remove_item(Item.items.WOOD)
				
				exitFire()
				
				return
				
			if area.has_method("interact"):
				area.interact(self)
				return
				
			add_item(area.item)
			area.queue_free()
			
	if Input.is_action_just_pressed("ui_home"):
		$"../Fire".buildFire()
	
	var farm_system := get_tree().get_first_node_in_group("farm_system")
	if farm_system:
		farm_system.update_player_target(self, facing_direction)


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


func _unhandled_key_input(event: InputEvent) -> void:
	if not isDay:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	var farm_system := get_tree().get_first_node_in_group("farm_system")
	if farm_system == null:
		return

	var key := key_event.keycode
	var physical := key_event.physical_keycode

	if key == KEY_5 or physical == KEY_5:
		farm_system.select_tool(FarmManager.TOOL_HOE)
	elif key == KEY_6 or physical == KEY_6:
		farm_system.select_tool(FarmManager.TOOL_SEEDS)
	elif key == KEY_7 or physical == KEY_7:
		farm_system.select_tool(FarmManager.TOOL_BUCKET)
	elif key == KEY_E or physical == KEY_E:
		farm_system.request_interact(self, facing_direction)


func _walk_at_night(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		if night_phase == 0:
			night_phase = 1
			$AnimatedSprite2D.play("sleep")
			
			nav_agent.target_position = GALLOW_POSITION
			$"../PlayerHUD".night(true)
			return
		elif night_phase == 1:
			night_phase = 2
			
			n += 1
			$"../Gallows".updateGallows(n)
			
			nav_agent.target_position = BED_POSITION
			return
		
		elif night_phase == 2:
			isDay = true
			night_phase = 0
			
			velocity = Vector2.ZERO
			energy = 5
			$"../PlayerHUD".increase_energy(4)
			$"../PlayerHUD".update()
			
			_play_direction_animation("idle")
			$"../PlayerHUD".night(false)
			return
	
	var next_pos := nav_agent.get_next_path_position()
	var dir := global_position.direction_to(next_pos)
	
	_update_facing_direction(dir)
	
	global_position = global_position.move_toward(
		next_pos,
		SPEED * delta
	)

	_play_direction_animation("run")

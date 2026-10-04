class_name Player
extends CharacterBody2D

const RECORD_INTERVAL := 0.1
const GHOST_SCENE := preload("res://scenes/ghost.tscn")
const FINALE_DAY := 5
const INTERACT_PROMPT_SWAP_INTERVAL := 0.7
const INVENTORY_CAPACITY := 9

@onready var walk_left_sound: AudioStreamPlayer = $WalkLeftSound
@onready var walk_right_sound: AudioStreamPlayer = $WalkRightSound

var walk_sound_left := true
var last_walk_animation_frame := -1

var recording: Array = []
var record_timer := 0.0
var finale := false
var is_chopping := false
var is_fishing := false
var carrot_bait_ready: bool = false
var is_eating := false
var eating_item: Item.items = Item.items.EMPTY
var pending_inventory_items: Array = []

const SPEED = 80.0
const BED_POSITION := Vector2(50, 50)
const GALLOW_POSITION := Vector2(96, 200)
const TENT_INTERACT_POSITION := Vector2(54.24, 83.42)
const TENT_EXIT_POSITION := Vector2(54.24, 83.42)
const TENT_INTERACT_RADIUS := 24.0

const REEL_ITEM_MAP: Array = [
	Item.items.FISH_BLUE,
	Item.items.FISH_GREEN,
	Item.items.FISH_ORANGE,
	Item.items.TRASH,
	Item.items.FLINT_AND_STEEL,
]

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var facing_direction := Vector2.DOWN

var n = 0

var isDay = true
var night_phase = 0
var is_dying := false

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
@onready var eat_sound: AudioStreamPlayer = $EatSound

func _play_walk_sound() -> void:
	if walk_sound_left:
		walk_left_sound.play()
	else:
		walk_right_sound.play()

	walk_sound_left = not walk_sound_left

func add_item(item: Item.items, amount: int = 1) -> void:
	if amount <= 0:
		return

	for _i in range(amount):
		# Wenn bereits ein Item auf eine Entscheidung wartet, kommen weitere
		# neue Items ebenfalls in die Warteschlange. So geht nichts verloren.
		if not pending_inventory_items.is_empty() or _inventory_item_count() >= INVENTORY_CAPACITY:
			pending_inventory_items.append(item)
		else:
			_add_item_direct(item)

	_refresh_inventory_ui()
	_start_inventory_overflow_choice_if_needed()


func remove_item(item: Item.items) -> void:
	if not inventory.has(item):
		return

	_remove_item_direct(item)
	_refresh_inventory_ui()


func _add_item_direct(item: Item.items) -> void:
	inventory[item] = inventory.get(item, 0) + 1


func _remove_item_direct(item: Item.items) -> void:
	if not inventory.has(item):
		return

	inventory[item] -= 1
	if inventory[item] <= 0:
		inventory.erase(item)


func _inventory_item_count() -> int:
	var count := 0
	for amount in inventory.values():
		count += int(amount)
	return count


func _refresh_inventory_ui() -> void:
	var inventory_ui := get_node_or_null("../PlayerHUD/Inventory")
	if inventory_ui != null:
		inventory_ui.update_slots(inventory)


func _start_inventory_overflow_choice_if_needed() -> void:
	if pending_inventory_items.is_empty():
		return

	var inventory_ui := get_node_or_null("../PlayerHUD/Inventory")
	if inventory_ui != null and inventory_ui.has_method("begin_overflow_choice"):
		inventory_ui.begin_overflow_choice(pending_inventory_items[0])


func has_pending_inventory_choice() -> bool:
	return not pending_inventory_items.is_empty()


func resolve_inventory_overflow(slot_index: int) -> void:
	if pending_inventory_items.is_empty():
		return

	var inventory_ui := get_node_or_null("../PlayerHUD/Inventory")
	if inventory_ui == null or not inventory_ui.has_method("get_item_at_slot"):
		return

	var dropped_item: Item.items = inventory_ui.get_item_at_slot(slot_index)
	if dropped_item == Item.items.EMPTY:
		return

	# Genau das vom Spieler gewählte Slot-Item wird aus dem Inventar genommen
	# und als echtes Pickup direkt beim Spieler auf den Boden gelegt.
	_remove_item_direct(dropped_item)
	_drop_item_to_ground(dropped_item)

	# Das wartende neue Item nimmt EXAKT den gewählten Slot ein.
	# Wir bauen hier absichtlich NICHT das komplette Inventar neu auf,
	# weil sonst alle Items davor aufrutschen würden.
	var incoming_item: Item.items = pending_inventory_items.pop_front()
	_add_item_direct(incoming_item)
	if inventory_ui.has_method("replace_item_at_slot"):
		inventory_ui.replace_item_at_slot(slot_index, incoming_item)
	else:
		_refresh_inventory_ui()

	if pending_inventory_items.is_empty():
		if inventory_ui.has_method("end_overflow_choice"):
			inventory_ui.end_overflow_choice()
	else:
		inventory_ui.begin_overflow_choice(pending_inventory_items[0])


func cancel_inventory_overflow() -> void:
	if pending_inventory_items.is_empty():
		return

	var inventory_ui := get_node_or_null("../PlayerHUD/Inventory")

	# ESC verwirft nicht das Item: Der aktuelle Neuzugang wird stattdessen
	# direkt beim Spieler auf den Boden gelegt. Das bestehende Inventar bleibt unverändert.
	var incoming_item: Item.items = pending_inventory_items.pop_front()
	_drop_item_to_ground(incoming_item)

	if inventory_ui == null:
		return

	if pending_inventory_items.is_empty():
		if inventory_ui.has_method("end_overflow_choice"):
			inventory_ui.end_overflow_choice()
	else:
		if inventory_ui.has_method("begin_overflow_choice"):
			inventory_ui.begin_overflow_choice(pending_inventory_items[0])


func _drop_item_to_ground(item: Item.items) -> void:
	var scene: PackedScene = _get_world_item_scene(item)
	if scene == null:
		return

	var dropped := scene.instantiate()
	get_tree().current_scene.add_child(dropped)

	# Jeder Inventarslot entspricht exakt EINEM Item. Das ist besonders bei
	# Karottensamen wichtig, deren normales Pickup sonst mehrere Samen gäbe.
	if dropped is Item:
		dropped.amount = 1

	# Direkt neben/unter dem Spieler ablegen, damit es sofort wieder sichtbar
	# und wie Holz/Pilz mit E aufhebbar ist.
	var offset := Vector2(0, 14)
	if facing_direction != Vector2.ZERO:
		# Hinter dem Player ablegen. Beim Angeln schaut er zum Wasser, dadurch
		# landet das abgelegte Item auf der Landseite statt im Wasser.
		offset = -facing_direction.normalized() * 14.0
	dropped.global_position = global_position + offset


func _get_world_item_scene(item: Item.items) -> PackedScene:
	match item:
		Item.items.MUSHROOM:
			return preload("res://scenes/items/mushroom.tscn")
		Item.items.WOOD:
			return preload("res://scenes/items/wood.tscn")
		Item.items.HOE:
			return preload("res://scenes/items/hoe.tscn")
		Item.items.BUCKET:
			return preload("res://scenes/items/bucket.tscn")
		Item.items.CARROT_SEEDS:
			return preload("res://scenes/items/carrot_seeds.tscn")
		Item.items.CARROT:
			return preload("res://scenes/items/carrot.tscn")
		Item.items.FISHING_ROD:
			return preload("res://scenes/items/fishing_rod.tscn")
		Item.items.FISH_BLUE:
			return preload("res://scenes/items/fish_blue.tscn")
		Item.items.FISH_ORANGE:
			return preload("res://scenes/items/fish_orange.tscn")
		Item.items.FISH_GREEN:
			return preload("res://scenes/items/fish_green.tscn")
		Item.items.TRASH:
			return preload("res://scenes/items/trash.tscn")
		Item.items.FLINT_AND_STEEL:
			return preload("res://scenes/items/flint_and_steel.tscn")
		_:
			return null


func _ready() -> void:
	add_to_group("player")

	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	
	$"../Gallows".updateGallows(n)

	# Das Essen wird erst am Ende des ca. 2 Sekunden langen Sounds verbraucht.
	eat_sound.finished.connect(_on_eat_sound_finished)


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
	var fire := $"../Fire"

	if fire.has_method("needs_wood") and fire.needs_wood():
		if Item.items.WOOD in inventory:
			showLabel("E / LMB")
		else:
			showInteractItem(Item.items.WOOD)
	elif fire.has_method("needs_flint_and_steel") and fire.needs_flint_and_steel():
		if Item.items.FLINT_AND_STEEL in inventory:
			showLabel("E / LMB")
		else:
			showInteractItem(Item.items.FLINT_AND_STEEL)
	else:
		hideInteract()

	area = fire


func exitFire():
	exitArea($"../Fire")


func start_night() -> void:
	if not isDay or is_dying:
		return

	isDay = false
	night_phase = 0
	hideInteract()

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

	if is_dying:
		velocity = Vector2.ZERO
		return
	
	if isDay and $"../PlayerHUD".get_hunger() <= 0:
		_start_hunger_death()
		return
		
	if $"../PlayerHUD".get_energy() <= 0 and isDay:
		start_night()
	
	if !isDay:
		_walk_at_night(delta)
		return

	# Wenn das Inventar voll war, muss zuerst ein Slot zum Ablegen gewählt werden.
	# Solange bleibt der Player stehen, damit die Entscheidung nicht umgangen wird.
	if has_pending_inventory_choice():
		velocity = Vector2.ZERO
		move_and_slide()
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
	
	if not is_chopping and not is_fishing:
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
	
	if velocity != Vector2.ZERO and not is_chopping and not is_fishing:
		var frame: int = $AnimatedSprite2D.frame

		if frame != last_walk_animation_frame:
			last_walk_animation_frame = frame

			if frame == 0 or frame == 2:
				_play_walk_sound()
	else:
		last_walk_animation_frame = -1
	
	if Input.is_action_just_pressed("e"):
		_try_context_interaction()

	if Input.is_action_just_pressed("eat"):
		_try_eat_selected_item()
	
	if Input.is_action_just_pressed("ui_home"):
		$"../Fire".buildFire()
	
	var farm_system := get_tree().get_first_node_in_group("farm_system")

	if farm_system:
		farm_system.update_player_target(self, facing_direction)

	_update_tent_interaction_prompt()
	
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
	if not isDay or is_chopping or is_fishing or has_pending_inventory_choice():
		return

	# Vor einem Klick das aktuelle Maus-Tile noch einmal sofort prüfen.
	# So funktioniert ein Klick auch dann zuverlässig, wenn die Maus gerade erst
	# auf ein anderes Feld bewegt wurde und noch kein neuer Physics-Frame lief.
	var farm_system := get_tree().get_first_node_in_group("farm_system")
	if farm_system != null:
		farm_system.update_player_target(self, facing_direction)

	if area == null:
		if _is_near_tent():
			start_night()
		return

	if area == $"../Fire":
		var fire := $"../Fire"
		if fire.has_method("needs_wood") and fire.needs_wood():
			if Item.items.WOOD in inventory:
				fire.buildFire()
				remove_item(Item.items.WOOD)
		elif fire.has_method("needs_flint_and_steel") and fire.needs_flint_and_steel():
			if Item.items.FLINT_AND_STEEL in inventory:
				fire.ignite_fire()
		return

	if area.has_method("interact"):
		area.interact(self)


func _is_near_tent() -> bool:
	return global_position.distance_to(TENT_INTERACT_POSITION) <= TENT_INTERACT_RADIUS


func _update_tent_interaction_prompt() -> void:
	if not isDay or is_chopping or is_fishing or is_eating or has_pending_inventory_choice():
		return

	# Andere Interaktionen (Items, Feuer, Farming usw.) haben Vorrang.
	if area != null:
		return

	if _is_near_tent():
		showLabel("E")
	elif interact_ui.visible and not _alternate_interact_prompt:
		hideInteract()


func _try_eat_selected_item() -> void:
	# Essbare Items koennen mit F gegessen werden.
	if not isDay or is_chopping or is_fishing or is_eating or has_pending_inventory_choice():
		return

	var inventory_ui := get_node_or_null("../PlayerHUD/Inventory")
	if inventory_ui == null:
		return

	var selected_food: Item.items = inventory_ui.selected_item
	var edible_items := [
		Item.items.CARROT,
		Item.items.MUSHROOM,
		Item.items.FISH_BLUE,
		Item.items.FISH_ORANGE,
		Item.items.FISH_GREEN,
	]
	if selected_food not in edible_items:
		return

	if inventory.get(selected_food, 0) <= 0:
		return

	is_eating = true
	eating_item = selected_food
	eat_sound.stop()
	eat_sound.play()


func _on_eat_sound_finished() -> void:
	if not is_eating:
		return

	var eaten_item := eating_item
	is_eating = false
	eating_item = Item.items.EMPTY

	# Falls das Item waehrend des Sounds irgendwie aus dem Inventar verschwunden ist,
	# wird kein Effekt angewendet.
	if inventory.get(eaten_item, 0) <= 0:
		return

	remove_item(eaten_item)

	var hud := get_node_or_null("../PlayerHUD")
	if hud == null:
		return

	match eaten_item:
		Item.items.CARROT:
	
			hud.increase_energy(2)
			hud.increase_hunger(1)

		Item.items.MUSHROOM:
			# Pilz: immer +1 Energie und dazu exakt 50/50.
			hud.increase_energy(1)
			if randi() % 2 == 0:
				hud.increase_psyche(1)
			else:
				var hunger_loss: int = mini(2, hud.get_hunger())
				hud.decrease_hunger(hunger_loss)

		Item.items.FISH_BLUE:
			hud.increase_hunger(1)

		Item.items.FISH_ORANGE:
			hud.increase_energy(2)
			hud.increase_hunger(1)

		Item.items.FISH_GREEN:
			hud.increase_psyche(2)

	hud.update()

const FISHING_SPIN_DURATION := 9.0

func start_fishing(direction: Vector2) -> void:
	if not isDay or is_chopping or is_fishing or is_eating:
		return

	if direction == Vector2.ZERO:
		return

	var hud := get_node_or_null("../PlayerHUD")
	if hud == null or hud.get_energy() < 1:
		return

	is_fishing = true
	velocity = Vector2.ZERO
	hideInteract()

	# Die Animation richtet sich automatisch zum Wasser aus.
	if abs(direction.x) > abs(direction.y):
		facing_direction = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		facing_direction = Vector2.DOWN if direction.y > 0 else Vector2.UP

	# 3 Frames: Angel auswerfen.
	$AngelSound.play()
	_play_direction_animation("fish")
	await $AnimatedSprite2D.animation_finished

	# Eine aktivierte Karotte wird genau einmal beim Auswerfen als Koeder verbraucht.
	var use_carrot_bait: bool = carrot_bait_ready and int(inventory.get(Item.items.CARROT, 0)) > 0
	if use_carrot_bait:
		remove_item(Item.items.CARROT)

	carrot_bait_ready = false

	# Die Angel ist draußen: Roulette starten.
	var caught: Item.items = Item.items.TRASH
	var reel_ui := get_node_or_null("../PlayerHUD/GamblingOverlay")

	if reel_ui != null:
		reel_ui.show()
		await get_tree().process_frame

		reel_ui.spin(FISHING_SPIN_DURATION, 60, use_carrot_bait)

		var result: Array = await reel_ui.finished
		var id: int = result[0]

		if id < REEL_ITEM_MAP.size():
			caught = REEL_ITEM_MAP[id]

		# Kurze Pause, damit man sieht, was man gefangen hat.
		await get_tree().create_timer(1.0).timeout
		reel_ui.hide()

	else:
		# Fallback, falls das Rad nicht gefunden wird.
		await get_tree().create_timer(randf_range(3.0, 6.0)).timeout

	# Angel wieder einholen.
	_play_direction_animation("fish_reverse")
	await $AnimatedSprite2D.animation_finished

	add_item(caught)

	# Angeln kostet 1 Energie.
	hud.decrease_energy(1)
	hud.update()

	is_fishing = false
	_play_direction_animation("idle")

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
	# Die Angel-Frames fuer links/rechts liegen im Spritesheet vertauscht.
	# Deshalb werden nur fuer fish/fish_reverse links und rechts absichtlich gespiegelt aufgerufen.
	var effective_right := "_right"
	var effective_left := "_left"
	if animation_type == "fish" or animation_type == "fish_reverse":
		effective_right = "_left"
		effective_left = "_right"

	if facing_direction == Vector2.RIGHT:
		$AnimatedSprite2D.play(animation_type + effective_right)

	elif facing_direction == Vector2.LEFT:
		$AnimatedSprite2D.play(animation_type + effective_left)

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

			var hud := $"../PlayerHUD"

			# Reihenfolge der Nacht:
			# 1. Energie + aktueller Essensstand (maximal bis 4)
			var free_energy: int = maxi(hud.max_energy - hud.get_energy(), 0)
			var energy_gain: int = mini(hud.get_hunger(), free_energy)
			if energy_gain > 0:
				hud.increase_energy(energy_gain)

			# 2. Danach -2 Essen/Leben, niemals unter 0.
			var hunger_loss: int = mini(1, hud.get_hunger())
			if hunger_loss > 0:
				hud.decrease_hunger(hunger_loss)

			hud.decrease_psyche(1)
			
			if n < 4-$"../PlayerHUD".get_psyche():
				n = 4-$"../PlayerHUD".get_psyche()

			hud.update()

			# Wenn Essen/Leben durch die Nacht auf 0 fällt:
			# direkt zum Galgen laufen und dort sterben.
			if hud.get_hunger() <= 0:
				night_phase = 3
				nav_agent.target_position = GALLOW_POSITION
				hud.night(false)
				$"../PlayerHUD/Inventory".hide()
				$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)
				return

			nav_agent.target_position = GALLOW_POSITION
			hud.night(true)
			$"../PlayerHUD/Inventory".hide()
			$AnimatedSprite2D.modulate = Color(0.0, 0.0, 0.0, 1.0)
			return

		elif night_phase == 1:
			night_phase = 2
			
			
			
			
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

			$"../PlayerHUD".update()
			
			_play_direction_animation("idle")
			$"../PlayerHUD".night(false)
			$"../PlayerHUD/Inventory".show()
			$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)
			return

		elif night_phase == 3:
			_start_hunger_death()
			return
	
	var next_pos := nav_agent.get_next_path_position()
	var dir := global_position.direction_to(next_pos)
	
	_update_facing_direction(dir)
	
	global_position = global_position.move_toward(
		next_pos,
		SPEED * delta
	)

	_play_direction_animation("run")


func _start_hunger_death() -> void:
	if is_dying:
		return

	is_dying = true
	velocity = Vector2.ZERO
	hideInteract()
	$"../PlayerHUD".night(false)
	$"../PlayerHUD/Inventory".hide()
	$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)
	$AnimatedSprite2D.play("death")
	await $AnimatedSprite2D.animation_finished
	get_tree().change_scene_to_file("res://scenes/FinalMenu.tscn")


func start_finale() -> void:

	finale = true
	velocity = Vector2.ZERO
	$AnimatedSprite2D.hide()

	for rec in pos_array:
		var g = GHOST_SCENE.instantiate()
		get_parent().add_child(g)
		g.start(rec, 10.0, 5.0, GALLOW_POSITION)

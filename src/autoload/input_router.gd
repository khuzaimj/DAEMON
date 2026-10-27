extends Node

# Hold threshold at 60 ticks per second (0.5 s = 30 ticks)
const HOLD_TICKS_THRESHOLD: int = 30

var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.ZERO
var primary: bool = false
var secondary: bool = false
var hop: bool = false
var eject: bool = false
var routine_cycle: bool = false
var pin: bool = false
var interact: bool = false
var back: bool = false
var map_toggle: bool = false

var _hop_hold_counter: int = 0
var _hop_ejected: bool = false
var _routine_hold_counter: int = 0
var _routine_pinned: bool = false

func _ready() -> void:
	_setup_actions_from_data()

func _setup_actions_from_data() -> void:
	var bindings_file: FileAccess = FileAccess.open("res://data/bindings_default.json", FileAccess.READ)
	if bindings_file == null:
		return
	var text: String = bindings_file.get_as_text()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return
	if not (json.data is Dictionary):
		return
	var root: Dictionary = json.data as Dictionary
	var actions: Dictionary = root.get("actions", {})
	for action_name: String in actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var config: Dictionary = actions[action_name]

		# Keyboard keys
		var keys: Array = config.get("keys", [])
		for k: Variant in keys:
			var key_str: String = str(k)
			var keycode: Key = OS.find_keycode_from_string(key_str)
			if keycode != KEY_NONE:
				var ev: InputEventKey = InputEventKey.new()
				ev.physical_keycode = keycode
				InputMap.action_add_event(action_name, ev)

		# Gamepad buttons
		var joy_buttons: Array = config.get("joy_buttons", [])
		for b: Variant in joy_buttons:
			var btn_ev: InputEventJoypadButton = InputEventJoypadButton.new()
			btn_ev.button_index = int(b) as JoyButton
			InputMap.action_add_event(action_name, btn_ev)

		# Gamepad axes
		var joy_axis_val: Variant = config.get("joy_axis")
		if joy_axis_val is Dictionary:
			var axis_dict: Dictionary = joy_axis_val as Dictionary
			var motion_ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion_ev.axis = int(axis_dict.get("axis", 0)) as JoyAxis
			motion_ev.axis_value = float(axis_dict.get("value", 0.0))
			InputMap.action_add_event(action_name, motion_ev)

## Called once per physics tick by World
func sample_input() -> void:
	var move_x: float = Input.get_axis("move_left", "move_right")
	var move_y: float = Input.get_axis("move_up", "move_down")
	var raw_move: Vector2 = Vector2(move_x, move_y)
	if raw_move.length_squared() > 1.0:
		move = raw_move.normalized()
	else:
		move = raw_move

	# Right stick aim override (§1.13), falling back to movement direction
	var r_stick_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var r_stick_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var r_stick: Vector2 = Vector2(r_stick_x, r_stick_y)
	if r_stick.length_squared() > 0.04: # 0.2 deadzone
		aim = r_stick.normalized()
	elif move != Vector2.ZERO:
		aim = move.normalized()

	primary = Input.is_action_just_pressed("primary")
	secondary = Input.is_action_just_pressed("secondary")
	interact = Input.is_action_just_pressed("interact")
	back = Input.is_action_just_pressed("back")
	map_toggle = Input.is_action_just_pressed("map")

	# Hop vs Eject hold detection
	eject = false
	hop = false
	if Input.is_action_pressed("hop"):
		_hop_hold_counter += 1
		if _hop_hold_counter >= HOLD_TICKS_THRESHOLD and not _hop_ejected:
			eject = true
			_hop_ejected = true
	else:
		if _hop_hold_counter > 0 and _hop_hold_counter < HOLD_TICKS_THRESHOLD and not _hop_ejected:
			hop = true
		_hop_hold_counter = 0
		_hop_ejected = false

	# Routine cycle vs Pin hold detection
	pin = false
	routine_cycle = false
	if Input.is_action_pressed("routine"):
		_routine_hold_counter += 1
		if _routine_hold_counter >= HOLD_TICKS_THRESHOLD and not _routine_pinned:
			pin = true
			_routine_pinned = true
	else:
		if _routine_hold_counter > 0 and _routine_hold_counter < HOLD_TICKS_THRESHOLD and not _routine_pinned:
			routine_cycle = true
		_routine_hold_counter = 0
		_routine_pinned = false

func reset_input() -> void:
	move = Vector2.ZERO
	aim = Vector2.ZERO
	primary = false
	secondary = false
	hop = false
	eject = false
	routine_cycle = false
	pin = false
	interact = false
	back = false
	map_toggle = false
	_hop_hold_counter = 0
	_hop_ejected = false
	_routine_hold_counter = 0
	_routine_pinned = false

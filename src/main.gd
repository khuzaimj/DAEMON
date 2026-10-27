class_name Main
extends Node2D

var _frame_count: int = 0
var _smoke_mode: bool = false
var world: World = null

func _ready() -> void:
	var start_room: String = "debug_01"
	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())

	for i: int in range(all_args.size()):
		var arg: String = all_args[i]
		if arg == "--smoke":
			_smoke_mode = true
		elif arg == "--room" and i + 1 < all_args.size():
			start_room = all_args[i + 1]
		elif arg.begins_with("--room="):
			start_room = arg.substr(7)

	var world_scene: PackedScene = load("res://scenes/world.tscn")
	if world_scene != null:
		world = world_scene.instantiate() as World
		add_child(world)
		world.load_room(start_room)

func _process(_delta: float) -> void:
	if _smoke_mode:
		_frame_count += 1
		if _frame_count >= 150:
			get_tree().quit(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			if world != null and world.handle_back_input():
				return
			get_tree().quit(0)

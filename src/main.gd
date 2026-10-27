class_name Main
extends Node2D

var _frame_count: int = 0
var _smoke_mode: bool = false

@onready var _color_rect: ColorRect = $Background
@onready var _debug_label: Label = $DebugLabel

func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in user_args:
		if arg == "--smoke":
			_smoke_mode = true
			break

func _process(_delta: float) -> void:
	if _smoke_mode:
		_frame_count += 1
		if _frame_count >= 120:
			get_tree().quit(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			get_tree().quit(0)

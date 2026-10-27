class_name Intent
extends RefCounted

var move: Vector2 = Vector2.ZERO    # zero or normalized
var aim: Vector2 = Vector2.ZERO     # zero means use facing
var primary: bool = false
var secondary: bool = false
var hop: bool = false               # press edge
var eject: bool = false             # hold-complete edge
var routine_cycle: bool = false
var pin: bool = false
var interact: bool = false

func reset() -> void:
	move = Vector2.ZERO
	aim = Vector2.ZERO
	primary = false
	secondary = false
	hop = false
	eject = false
	routine_cycle = false
	pin = false
	interact = false

func clone() -> Intent:
	var copy: Intent = Intent.new()
	copy.move = move
	copy.aim = aim
	copy.primary = primary
	copy.secondary = secondary
	copy.hop = hop
	copy.eject = eject
	copy.routine_cycle = routine_cycle
	copy.pin = pin
	copy.interact = interact
	return copy

class_name AbilitiesRunner
extends Node

signal ability_triggered(slot: String, ability_id: String, kind: String, direction: Vector2)
signal ability_finished(slot: String, ability_id: String)

var machine: Machine = null
var primary_data: Dictionary = {}
var secondary_data: Dictionary = {}

var primary_slot: Dictionary = {
	"id": "",
	"state": "idle", # "idle", "windup", "active"
	"ticks_left": 0,
	"dir": Vector2.DOWN
}

var secondary_slot: Dictionary = {
	"id": "",
	"state": "idle",
	"ticks_left": 0,
	"dir": Vector2.DOWN
}

func setup(p_machine: Machine, primary_id: String, secondary_id: String) -> void:
	machine = p_machine
	primary_slot["id"] = primary_id
	primary_slot["state"] = "idle"
	primary_slot["ticks_left"] = 0
	
	secondary_slot["id"] = secondary_id
	secondary_slot["state"] = "idle"
	secondary_slot["ticks_left"] = 0
	
	_load_ability_data()

func _load_ability_data() -> void:
	var data_node: Node = get_node_or_null("/root/Data")
	if data_node != null and data_node.has_method("get_json"):
		if not primary_slot["id"].is_empty():
			var p_path: String = "res://data/abilities/%s.json" % primary_slot["id"]
			var p_res: Variant = data_node.call("get_json", p_path)
			if p_res is Dictionary:
				primary_data = p_res
		if not secondary_slot["id"].is_empty():
			var s_path: String = "res://data/abilities/%s.json" % secondary_slot["id"]
			var s_res: Variant = data_node.call("get_json", s_path)
			if s_res is Dictionary:
				secondary_data = s_res

func step(_tick: int, intent: Intent) -> void:
	if machine == null or machine.state == null:
		return
		
	# Process active slot timers
	_step_slot("primary", primary_slot, primary_data, intent.primary)
	_step_slot("secondary", secondary_slot, secondary_data, intent.secondary)
	
	# If machine cannot act (crashed, overheated, stunned), don't start new abilities
	if not machine.state.can_act():
		return
		
	var aim_dir: Vector2 = intent.aim if intent.aim != Vector2.ZERO else machine.facing
	
	if intent.primary and _can_trigger("primary", primary_slot, primary_data):
		_start_ability("primary", primary_slot, primary_data, aim_dir)
	elif intent.secondary and _can_trigger("secondary", secondary_slot, secondary_data):
		_start_ability("secondary", secondary_slot, secondary_data, aim_dir)

func _can_trigger(slot_name: String, slot: Dictionary, data: Dictionary) -> bool:
	if data.is_empty() or slot["id"].is_empty():
		return false
	if slot["state"] != "idle":
		return false
	if machine.state.is_cooling_down(slot_name):
		return false
	return true

func _start_ability(slot_name: String, slot: Dictionary, data: Dictionary, dir: Vector2) -> void:
	var heat_cost: float = float(data.get("heat_cost", 0.0))
	var windup_sec: float = float(data.get("windup", 0.0))
	var windup_ticks: int = AbilityMath.seconds_to_ticks(windup_sec)
	
	# Add Heat cost to body state
	machine.state.add_heat(heat_cost)
	
	slot["dir"] = dir
	if windup_ticks > 0:
		slot["state"] = "windup"
		slot["ticks_left"] = windup_ticks
	else:
		_execute_ability(slot_name, slot, data, dir)

func _execute_ability(slot_name: String, slot: Dictionary, data: Dictionary, dir: Vector2) -> void:
	var kind: String = str(data.get("kind", ""))
	slot["state"] = "active"
	
	# Determine duration if channelled or fixed active frames
	var duration_sec: float = float(data.get("params", {}).get("duration", 0.1))
	slot["ticks_left"] = AbilityMath.seconds_to_ticks(duration_sec)
	
	# Set cooldown on slot
	var cd_sec: float = float(data.get("cooldown", 0.5))
	var cd_ticks: int = AbilityMath.seconds_to_ticks(cd_sec)
	machine.state.set_cooldown(slot_name, cd_ticks)
	
	match kind:
		"charge_dash":
			MovementAbilities.start_charge_dash(machine, data, dir)
		"dash":
			MovementAbilities.start_dash(machine, data, dir)
		"cling":
			MovementAbilities.start_cling(machine, data, dir)
	
	ability_triggered.emit(slot_name, str(slot["id"]), kind, dir)

func _step_slot(slot_name: String, slot: Dictionary, data: Dictionary, _held: bool) -> void:
	if slot["state"] == "idle":
		return
		
	slot["ticks_left"] -= 1
	if slot["ticks_left"] <= 0:
		if slot["state"] == "windup":
			_execute_ability(slot_name, slot, data, slot["dir"])
		elif slot["state"] == "active":
			slot["state"] = "idle"
			slot["ticks_left"] = 0
			ability_finished.emit(slot_name, str(slot["id"]))

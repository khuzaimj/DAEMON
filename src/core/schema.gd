class_name Schema
extends RefCounted

const ABILITY_KINDS: Array[String] = [
	"charge_dash", "dash", "cling",
	"melee_arc", "claw", "suction",
	"projectile", "overwatch", "overload_shot", "harpoon", "throw_parcel",
	"flame_cone", "beam_channel", "repair_beam",
	"ping", "lift_carry", "tow", "bubble_shield", "patch"
]

const BODY_KEYS: Array[String] = [
	"id", "name", "size", "weight", "medium", "speed", "integrity",
	"heat_max", "heat_cooldown", "primary", "secondary", "passives",
	"tags", "sprite", "clearance", "garage_cost", "unlock_zone"
]

const ABILITY_KEYS: Array[String] = [
	"id", "kind", "heat_cost", "cooldown", "windup", "params", "sfx"
]

const ENEMY_KEYS: Array[String] = [
	"id", "body", "faction", "integrity", "ai", "senses",
	"open_threshold", "drops", "palette_variant"
]

const AI_PRESET_KEYS: Array[String] = [
	"id", "initial", "params", "states"
]

static func validate_keys(data: Dictionary, allowed_keys: Array[String], context: String = "") -> Array[String]:
	var errors: Array[String] = []
	for k: Variant in data.keys():
		var key_str: String = str(k)
		if key_str.begins_with("_"):
			continue
		if not allowed_keys.has(key_str):
			errors.append("%s: unknown key '%s'" % [context, key_str])
	return errors

static func is_snake_case(id: String) -> bool:
	var regex: RegEx = RegEx.new()
	var compile_err: Error = regex.compile("^[a-z0-9]+(_[a-z0-9]+)*$")
	if compile_err != OK:
		return false
	return regex.search(id) != null

static func validate_sizes(data: Dictionary, context: String = "sizes.json") -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_keys(data, ["sizes"], context))
	if not data.has("sizes") or not (data["sizes"] is Dictionary):
		errors.append("%s: missing or invalid 'sizes' dictionary" % context)
		return errors
	var sizes_dict: Dictionary = data["sizes"] as Dictionary
	for size_key: Variant in sizes_dict.keys():
		var entry: Variant = sizes_dict[size_key]
		if not (entry is Dictionary):
			errors.append("%s: size entry '%s' must be Dictionary" % [context, str(size_key)])
			continue
		var entry_dict: Dictionary = entry as Dictionary
		if not entry_dict.has("hitbox_px") or not (entry_dict["hitbox_px"] is int or entry_dict["hitbox_px"] is float):
			errors.append("%s: size entry '%s' missing numeric 'hitbox_px'" % [context, str(size_key)])
	return errors

static func validate_body(data: Dictionary, context: String = "body") -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_keys(data, BODY_KEYS, context))
	for req: String in BODY_KEYS:
		if not data.has(req):
			errors.append("%s: missing required key '%s'" % [context, req])

	var id_val: String = str(data.get("id", ""))
	if id_val.is_empty() or not is_snake_case(id_val):
		errors.append("%s: id '%s' must be valid snake_case" % [context, id_val])

	var size_val: String = str(data.get("size", "")).to_lower()
	if not ["xs", "s", "m", "l", "xl"].has(size_val):
		errors.append("%s: invalid size '%s' (expected XS, S, M, L, XL)" % [context, data.get("size", "")])

	if not (data.get("medium") is Array):
		errors.append("%s: 'medium' must be Array" % context)
	if not (data.get("passives") is Array):
		errors.append("%s: 'passives' must be Array" % context)
	if not (data.get("tags") is Array):
		errors.append("%s: 'tags' must be Array" % context)

	return errors

static func validate_ability(data: Dictionary, context: String = "ability") -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_keys(data, ABILITY_KEYS, context))
	for req: String in ABILITY_KEYS:
		if not data.has(req):
			errors.append("%s: missing required key '%s'" % [context, req])

	var id_val: String = str(data.get("id", ""))
	if id_val.is_empty() or not is_snake_case(id_val):
		errors.append("%s: id '%s' must be valid snake_case" % [context, id_val])

	var kind_val: String = str(data.get("kind", ""))
	if not ABILITY_KINDS.has(kind_val):
		errors.append("%s: unknown ability kind '%s'" % [context, kind_val])

	if not (data.get("params") is Dictionary):
		errors.append("%s: 'params' must be Dictionary" % context)

	return errors

static func validate_enemy(data: Dictionary, context: String = "enemy") -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_keys(data, ENEMY_KEYS, context))
	for req: String in ENEMY_KEYS:
		if not data.has(req):
			errors.append("%s: missing required key '%s'" % [context, req])

	var id_val: String = str(data.get("id", ""))
	if id_val.is_empty() or not is_snake_case(id_val):
		errors.append("%s: id '%s' must be valid snake_case" % [context, id_val])

	var faction: String = str(data.get("faction", ""))
	if not ["hostile", "neutral", "allied"].has(faction):
		errors.append("%s: invalid faction '%s'" % [context, faction])

	if not (data.get("senses") is Dictionary):
		errors.append("%s: 'senses' must be Dictionary" % context)
	if not (data.get("drops") is Dictionary):
		errors.append("%s: 'drops' must be Dictionary" % context)

	return errors

static func validate_ai_preset(data: Dictionary, context: String = "ai_preset") -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_keys(data, AI_PRESET_KEYS, context))
	for req: String in AI_PRESET_KEYS:
		if not data.has(req):
			errors.append("%s: missing required key '%s'" % [context, req])

	var id_val: String = str(data.get("id", ""))
	if id_val.is_empty() or not is_snake_case(id_val):
		errors.append("%s: id '%s' must be valid snake_case" % [context, id_val])

	if not (data.get("params") is Dictionary):
		errors.append("%s: 'params' must be Dictionary" % context)
	if not (data.get("states") is Dictionary):
		errors.append("%s: 'states' must be Dictionary" % context)

	return errors

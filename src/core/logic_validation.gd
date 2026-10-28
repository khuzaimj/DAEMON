class_name LogicValidation
extends RefCounted

## Static data checks for LogicGraph (kept in its own file to hold both under the size limit).
## Call through LogicGraph.validate(). Pure rules, no nodes.

static func validate(elements: Array, links: Array) -> Array[String]:
	var errors: Array[String] = []
	var behaviors: Dictionary = {} # id -> Behavior
	var others: Dictionary = {} # ids of non-logic entities, for clearer messages
	for item: Variant in elements:
		_validate_element(item, behaviors, others, errors)
	for item: Variant in links:
		_validate_link(item, behaviors, others, errors)
	return errors

static func _validate_element(item: Variant, behaviors: Dictionary, others: Dictionary, errors: Array[String]) -> void:
	if not (item is Dictionary):
		errors.append("LogicGraph: element is not a Dictionary")
		return
	var d: Dictionary = item as Dictionary
	var id: String = str(d.get("id", ""))
	var kind: String = str(d.get("kind", ""))
	if id.is_empty():
		errors.append("LogicGraph: element of kind '%s' has no id" % kind)
		return
	if not LogicGraph.BEHAVIOR_BY_KIND.has(kind):
		others[id] = true
		return
	if behaviors.has(id):
		errors.append("LogicGraph: duplicate element id '%s'" % id)
		return
	var behavior: int = LogicGraph.BEHAVIOR_BY_KIND[kind]
	behaviors[id] = behavior
	if behavior == LogicGraph.Behavior.PLATE and d.has("weight") and as_int(d["weight"]) < 1:
		errors.append("LogicGraph: plate '%s' weight must be an integer >= 1" % id)
	if behavior == LogicGraph.Behavior.TIMER:
		var dur: Variant = d.get("duration", null)
		if not (dur is int or dur is float) or float(dur) <= 0.0:
			errors.append("LogicGraph: timer '%s' needs duration > 0 (seconds)" % id)
	for flag: String in ["persist", "on"]:
		if d.has(flag) and not (d[flag] is bool):
			errors.append("LogicGraph: element '%s' key '%s' must be a bool" % [id, flag])

static func _validate_link(item: Variant, behaviors: Dictionary, others: Dictionary, errors: Array[String]) -> void:
	if not (item is Dictionary):
		errors.append("LogicGraph: link is not a Dictionary")
		return
	var d: Dictionary = item as Dictionary
	var from_id: String = str(d.get("from", ""))
	var to_id: String = str(d.get("to", ""))
	var label: String = "link %s -> %s" % [from_id, to_id]
	var ok: bool = true
	for end_id: String in [from_id, to_id]:
		if behaviors.has(end_id):
			continue
		ok = false
		var why: String = "is not a logic element" if others.has(end_id) else "does not exist"
		errors.append("LogicGraph: %s: '%s' %s" % [label, end_id, why])
	if not ok:
		return
	var behavior: int = behaviors[to_id]
	if not LogicGraph.PORTS_BY_BEHAVIOR.has(behavior):
		errors.append("LogicGraph: %s: '%s' accepts no incoming links" % [label, to_id])
		return
	var port_name: String = str(d.get("port", ""))
	if port_name.is_empty():
		return # default port always exists on a behavior that has ports
	if not LogicGraph.PORT_BY_NAME.has(port_name) or not (LogicGraph.PORTS_BY_BEHAVIOR[behavior] as Array).has(LogicGraph.PORT_BY_NAME[port_name]):
		errors.append("LogicGraph: %s: '%s' has no port '%s'" % [label, to_id, port_name])

static func as_int(value: Variant) -> int:
	if value is int:
		return value as int
	if value is float and is_equal_approx(float(value), roundf(float(value))):
		return int(value)
	return 0

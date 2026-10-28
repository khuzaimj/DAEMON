class_name LogicGraph
extends RefCounted

## Deterministic boolean signal graph for puzzle rooms (SPEC 1.10, ARCH 2.5 system 6, 2.6).
## Pure rules: no nodes, no scene tree, no device input. The World's logic system feeds sensor
## values in (set_load, set_sensor, trigger), calls step() ONCE per tick, then reads results out.
##
## Rules (integers and booleans only, no RNG, so results are fully deterministic):
## - Elements run in dependency order, so a signal crosses any acyclic chain within ONE step.
## - Cycles: traversal starts from element ids in sorted order. The link that closes a loop is
##   "delayed": it reads its source's output from the PREVIOUS tick (one-tick delay). Authoring
##   order of the elements and links never changes the result.
## - A gate with no inputs outputs false. NOT of several inputs is NOR. AND needs every input.
## - switch: toggles at most once per tick, however many triggers arrived.
## - latch: ports "set" and "reset" (level sensitive). Reset wins when both are high.
## - timer: a rising edge on "in" starts (or restarts) it; output is high for exactly
##   `duration` seconds (converted to ticks). A held input does not retrigger it.
## - plate: high while the load handed to set_load() is at least its `weight` (default 1).
## - Relays (door, lift, bridge, ...): high while any input is high. What "high" means
##   (open, raised, disabled) is the entity's decision, not the graph's.

enum Behavior { PLATE, SENSOR, SWITCH, LATCH, TIMER, AND, OR, NOT, RELAY }
enum Port { IN, SET, RESET }

## Room-JSON `kind` -> behavior. Add one line here to make a new entity kind part of the graph.
const BEHAVIOR_BY_KIND: Dictionary = {
	"plate": Behavior.PLATE,
	"node": Behavior.SENSOR,
	"switch": Behavior.SWITCH,
	"latch": Behavior.LATCH,
	"broken_structure": Behavior.LATCH,
	"timer": Behavior.TIMER,
	"and": Behavior.AND,
	"or": Behavior.OR,
	"not": Behavior.NOT,
	"door": Behavior.RELAY,
	"lift": Behavior.RELAY,
	"bridge": Behavior.RELAY,
	"crusher": Behavior.RELAY,
	"beam_gate": Behavior.RELAY,
	"emitter": Behavior.RELAY,
	"firewall": Behavior.RELAY,
}
## Kinds whose state is always saved, with no `persist` flag needed.
const ALWAYS_PERSIST_KINDS: Array[String] = ["broken_structure"]
const PORT_BY_NAME: Dictionary = { "in": Port.IN, "set": Port.SET, "reset": Port.RESET }
## Behaviors missing here (plate, sensor, switch) accept no incoming links.
const PORTS_BY_BEHAVIOR: Dictionary = {
	Behavior.LATCH: [Port.SET, Port.RESET],
	Behavior.TIMER: [Port.IN],
	Behavior.AND: [Port.IN],
	Behavior.OR: [Port.IN],
	Behavior.NOT: [Port.IN],
	Behavior.RELAY: [Port.IN],
}

## Edges point at their source by INDEX into `_sorted`, never by object. Object references here
## would turn every loop in a puzzle into a RefCounted cycle that Godot never frees.
class _Edge:
	extends RefCounted
	var src: int = 0
	var port: int = Port.IN
	var delayed: bool = false

class _Elem:
	extends RefCounted
	var id: String = ""
	var index: int = 0 # position in `_sorted`
	var behavior: int = Behavior.RELAY
	var inputs: Array[_Edge] = []
	var out: bool = false
	var mark: int = 0 # 0 unvisited, 1 in progress, 2 done (order computation only)
	var threshold: int = 1 # plate
	var load_value: int = 0 # plate
	var sensor: bool = false # sensor
	var initial: bool = false # switch and latch starting state
	var state: bool = false # switch and latch memory
	var pending: bool = false # switch: trigger received since the last step
	var persist: bool = false # latch: state is saved in the room delta
	var duration: int = 1 # timer, ticks
	var timer_left: int = 0
	var prev_in: bool = false

var _elems: Dictionary = {} # id -> _Elem
var _sorted: Array[_Elem] = [] # every element, sorted by id
var _order: Array[_Elem] = [] # evaluation order
var _changed: Array[String] = []

static func is_logic_kind(kind: String) -> bool:
	return BEHAVIOR_BY_KIND.has(kind)

## Returns human-readable errors; an empty array means the data is valid. Entities whose kind is
## not a logic kind (machines, spawns, pickups) are skipped, so the full room list can be passed.
static func validate(elements: Array, links: Array) -> Array[String]:
	return LogicValidation.validate(elements, links)

## Builds the graph. On any validation error the graph stays empty (every signal reads false) and
## the errors are returned, so bad data fails closed instead of half-working.
func setup(elements: Array, links: Array) -> Array[String]:
	clear()
	var errors: Array[String] = validate(elements, links)
	if not errors.is_empty():
		return errors
	_build_elements(elements)
	_build_edges(links)
	for e: _Elem in _sorted:
		if e.mark == 0:
			_visit(e)
	return errors

func clear() -> void:
	_elems.clear()
	_sorted.clear()
	_order.clear()
	_changed.clear()

func _build_elements(elements: Array) -> void:
	for item: Variant in elements:
		var d: Dictionary = item as Dictionary
		var kind: String = str(d.get("kind", ""))
		if not BEHAVIOR_BY_KIND.has(kind):
			continue
		var e: _Elem = _Elem.new()
		e.id = str(d["id"])
		e.behavior = BEHAVIOR_BY_KIND[kind]
		e.threshold = maxi(1, LogicValidation.as_int(d.get("weight", 1)))
		e.initial = bool(d.get("on", false))
		e.state = e.initial
		e.persist = bool(d.get("persist", false)) or ALWAYS_PERSIST_KINDS.has(kind)
		e.duration = maxi(1, AbilityMath.seconds_to_ticks(float(d.get("duration", 0.0))))
		_elems[e.id] = e
	var ids: Array = _elems.keys()
	ids.sort()
	for id: String in ids:
		var sorted_elem: _Elem = _elems[id] as _Elem
		sorted_elem.index = _sorted.size()
		_sorted.append(sorted_elem)

func _build_edges(links: Array) -> void:
	for item: Variant in links:
		var d: Dictionary = item as Dictionary
		var target: _Elem = _elems[str(d["to"])] as _Elem
		var edge: _Edge = _Edge.new()
		edge.src = (_elems[str(d["from"])] as _Elem).index
		var port_name: String = str(d.get("port", ""))
		if port_name.is_empty():
			edge.port = Port.SET if target.behavior == Behavior.LATCH else Port.IN
		else:
			edge.port = PORT_BY_NAME[port_name]
		target.inputs.append(edge)
	for e: _Elem in _sorted:
		e.inputs.sort_custom(_edge_before)

## `src` indices follow sorted ids, so comparing them compares ids.
static func _edge_before(a: _Edge, b: _Edge) -> bool:
	if a.src != b.src:
		return a.src < b.src
	return a.port < b.port

## Depth-first walk over dependencies. Finishing order is the evaluation order. A source that is
## still in progress means the link closes a cycle, so that link becomes the delayed one.
func _visit(e: _Elem) -> void:
	e.mark = 1
	for edge: _Edge in e.inputs:
		var src: _Elem = _sorted[edge.src]
		if src.mark == 1:
			edge.delayed = true
		elif src.mark == 0:
			_visit(src)
	e.mark = 2
	_order.append(e)

# --- per-tick inputs (applied by the next step) ------------------------------------------------

## Plate: total weight currently on it (machines and crates summed by the caller).
func set_load(id: String, weight: int) -> void:
	var e: _Elem = _elems.get(id) as _Elem
	if e != null and e.behavior == Behavior.PLATE:
		e.load_value = maxi(0, weight)

## Sensor (node): true while the Cursor is inside it.
func set_sensor(id: String, active: bool) -> void:
	var e: _Elem = _elems.get(id) as _Elem
	if e != null and e.behavior == Behavior.SENSOR:
		e.sensor = active

## Switch: an interact or hit happened. Any number of triggers before a step toggle it once.
func trigger(id: String) -> void:
	var e: _Elem = _elems.get(id) as _Elem
	if e != null and e.behavior == Behavior.SWITCH:
		e.pending = true

## Sets the memory of a switch or latch directly (a repair finished, a save was restored).
func force_state(id: String, on: bool) -> void:
	var e: _Elem = _elems.get(id) as _Elem
	if e != null and (e.behavior == Behavior.LATCH or e.behavior == Behavior.SWITCH):
		e.state = on

# --- the tick ---------------------------------------------------------------------------------

func step() -> void:
	_changed.clear()
	for e: _Elem in _order:
		var before: bool = e.out
		_evaluate(e)
		if e.out != before:
			_changed.append(e.id)

func _evaluate(e: _Elem) -> void:
	match e.behavior:
		Behavior.PLATE:
			e.out = e.load_value >= e.threshold
		Behavior.SENSOR:
			e.out = e.sensor
		Behavior.SWITCH:
			if e.pending:
				e.state = not e.state
				e.pending = false
			e.out = e.state
		Behavior.LATCH:
			if _any(e, Port.RESET):
				e.state = false
			elif _any(e, Port.SET):
				e.state = true
			e.out = e.state
		Behavior.TIMER:
			_evaluate_timer(e)
		Behavior.AND:
			e.out = _all(e)
		Behavior.NOT:
			e.out = not e.inputs.is_empty() and not _any(e, Port.IN)
		_:
			e.out = _any(e, Port.IN) # OR and RELAY

func _evaluate_timer(e: _Elem) -> void:
	var level: bool = _any(e, Port.IN)
	if level and not e.prev_in:
		e.timer_left = e.duration
	elif e.timer_left > 0:
		e.timer_left -= 1
	e.prev_in = level
	e.out = e.timer_left > 0

## Reads `out` of the source. For normal links the source already ran this tick; for a delayed
## link the source runs later in the order, so `out` still holds last tick's value.
func _any(e: _Elem, port: int) -> bool:
	for edge: _Edge in e.inputs:
		if edge.port == port and _sorted[edge.src].out:
			return true
	return false

func _all(e: _Elem) -> bool:
	if e.inputs.is_empty():
		return false
	for edge: _Edge in e.inputs:
		if not _sorted[edge.src].out:
			return false
	return true

# --- results ----------------------------------------------------------------------------------

func is_active(id: String) -> bool:
	var e: _Elem = _elems.get(id) as _Elem
	return e != null and e.out

func has_element(id: String) -> bool:
	return _elems.has(id)

func timer_remaining(id: String) -> int:
	var e: _Elem = _elems.get(id) as _Elem
	return e.timer_left if e != null and e.behavior == Behavior.TIMER else 0

## Ids whose output changed during the last step. Read only; reused every step.
func get_changed() -> Array[String]:
	return _changed

## Evaluation order (ids). For tests and tools.
func get_order() -> Array[String]:
	var ids: Array[String] = []
	for e: _Elem in _order:
		ids.append(e.id)
	return ids

## Links that carry the one-tick delay, as { from, to, port }. For the validator and tools.
func get_delayed_links() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e: _Elem in _order:
		for edge: _Edge in e.inputs:
			if edge.delayed:
				result.append({ "from": _sorted[edge.src].id, "to": e.id, "port": PORT_BY_NAME.find_key(edge.port) })
	return result

# --- persistence (room delta) -----------------------------------------------------------------

## Saved latch states that differ from their starting state: { id: bool }. Deltas only.
func get_persistent_state() -> Dictionary:
	var result: Dictionary = {}
	for e: _Elem in _order:
		if e.persist and e.state != e.initial:
			result[e.id] = e.state
	return result

## Applies a saved delta. Persistent latches missing from it return to their starting state;
## ids that no longer exist are ignored. Call before the first step of a room.
func restore_persistent_state(saved: Dictionary) -> void:
	for e: _Elem in _order:
		if e.persist:
			e.state = bool(saved.get(e.id, e.initial))

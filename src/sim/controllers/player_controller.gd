class_name PlayerController
extends Controller

func decide(_machine: Machine, _tick: int) -> Intent:
	var router: Node = get_node_or_null("/root/InputRouter")
	if router == null:
		return Intent.new()
	var intent: Intent = Intent.new()
	intent.move = router.get("move")
	intent.aim = router.get("aim")
	intent.primary = bool(router.get("primary"))
	intent.secondary = bool(router.get("secondary"))
	intent.hop = bool(router.get("hop"))
	intent.eject = bool(router.get("eject"))
	intent.routine_cycle = bool(router.get("routine_cycle"))
	intent.pin = bool(router.get("pin"))
	intent.interact = bool(router.get("interact"))
	return intent

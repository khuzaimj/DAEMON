class_name ScriptController
extends Controller

var planned_moves: Array[Vector2] = []
var default_intent: Intent = Intent.new()

func queue_move(dir: Vector2, ticks: int = 1) -> void:
	for i: int in range(ticks):
		planned_moves.append(dir)

func decide(_machine: Node2D, _tick: int) -> Intent:
	var intent: Intent = default_intent.clone()
	if planned_moves.size() > 0:
		intent.move = planned_moves.pop_front()
	return intent

class_name NullController
extends Controller

## Null controller returns neutral Intent. Used for dormant, crashed or unpiloted machines.
func decide(_machine: Machine, _tick: int) -> Intent:
	return Intent.new()

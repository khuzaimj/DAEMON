class_name RngStreams
extends RefCounted

var _world_seed: int = 0
var _streams: Dictionary = {}

func _init(seed_val: int = 1337) -> void:
	_world_seed = seed_val

func get_stream(stream_name: String) -> RandomNumberGenerator:
	if _streams.has(stream_name):
		return _streams[stream_name]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var stream_seed: int = _world_seed + hash(stream_name)
	rng.seed = stream_seed
	_streams[stream_name] = rng
	return rng

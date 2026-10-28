class_name LogicFixtures
extends RefCounted

## Shared builders for the logic graph tests.

static func el(id: String, kind: String, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = { "id": id, "kind": kind }
	d.merge(extra)
	return d

static func ln(from_id: String, to_id: String, port: String = "") -> Dictionary:
	var d: Dictionary = { "from": from_id, "to": to_id }
	if not port.is_empty():
		d["port"] = port
	return d

## Builds a graph and fails the calling test if setup reports errors.
static func build(test: GutTest, elements: Array, links: Array) -> LogicGraph:
	var g: LogicGraph = LogicGraph.new()
	var errors: Array[String] = g.setup(elements, links)
	test.assert_eq(errors, [] as Array[String], "setup should report no errors")
	return g

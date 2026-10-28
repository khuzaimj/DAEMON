extends GutTest

# Cycles (one-tick delay), determinism and memory behavior of LogicGraph.

func test_self_inverting_not_oscillates_with_one_tick_delay() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("n", "not")], [LogicFixtures.ln("n", "n")])
	var seen: Array[bool] = []
	for i: int in range(5):
		g.step()
		seen.append(g.is_active("n"))
	assert_eq(seen, [true, false, true, false, true] as Array[bool])
	assert_eq(g.get_delayed_links().size(), 1)

func test_or_with_self_feedback_holds_after_input_drops() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("p", "plate"), LogicFixtures.el("o", "or")], [LogicFixtures.ln("p", "o"), LogicFixtures.ln("o", "o")])
	g.set_load("p", 1)
	g.step()
	assert_true(g.is_active("o"))
	g.set_load("p", 0)
	for i: int in range(4):
		g.step()
		assert_true(g.is_active("o"), "self-holding loop stays on")

func test_cross_coupled_nots_settle_deterministically() -> void:
	var elements: Array = [LogicFixtures.el("a", "not"), LogicFixtures.el("b", "not")]
	var links: Array = [LogicFixtures.ln("a", "b"), LogicFixtures.ln("b", "a")]
	var g: LogicGraph = LogicFixtures.build(self, elements, links)
	assert_eq(g.get_delayed_links(), [{ "from": "a", "to": "b", "port": "in" }] as Array[Dictionary], "the link that closes the loop (ids sorted) is delayed")
	for i: int in range(4):
		g.step()
		assert_true(g.is_active("b"), "b = not(a of last tick) = true")
		assert_false(g.is_active("a"), "a = not(b of this tick) = false")

func test_acyclic_graph_has_no_delayed_links() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("p", "plate"), LogicFixtures.el("d", "door")], [LogicFixtures.ln("p", "d")])
	assert_eq(g.get_delayed_links().size(), 0)
	assert_eq(g.get_order(), ["p", "d"] as Array[String])

func test_authoring_order_does_not_change_the_result() -> void:
	var elements: Array = [LogicFixtures.el("p", "plate"), LogicFixtures.el("o", "or"), LogicFixtures.el("n", "not"), LogicFixtures.el("d", "door")]
	var links: Array = [LogicFixtures.ln("p", "o"), LogicFixtures.ln("o", "o"), LogicFixtures.ln("o", "n"), LogicFixtures.ln("n", "d"), LogicFixtures.ln("d", "n")]
	var reference: LogicGraph = LogicFixtures.build(self, elements, links)
	var reversed_elements: Array = elements.duplicate()
	reversed_elements.reverse()
	var reversed_links: Array = links.duplicate()
	reversed_links.reverse()
	var other: LogicGraph = LogicFixtures.build(self, reversed_elements, reversed_links)
	assert_eq(other.get_order(), reference.get_order())
	assert_eq(other.get_delayed_links(), reference.get_delayed_links())
	for tick: int in range(20):
		var load_value: int = 1 if (tick % 7) < 3 else 0
		reference.set_load("p", load_value)
		other.set_load("p", load_value)
		reference.step()
		other.step()
		for id: String in ["p", "o", "n", "d"]:
			assert_eq(other.is_active(id), reference.is_active(id), "%s at tick %d" % [id, tick])

func test_long_mixed_run_is_repeatable() -> void:
	var elements: Array = [
		LogicFixtures.el("p1", "plate", { "weight": 2 }), LogicFixtures.el("s", "switch"), LogicFixtures.el("t", "timer", { "duration": 0.1 }),
		LogicFixtures.el("l", "latch"), LogicFixtures.el("g", "and"), LogicFixtures.el("n", "not"), LogicFixtures.el("d", "door")]
	var links: Array = [
		LogicFixtures.ln("p1", "g"), LogicFixtures.ln("s", "g"), LogicFixtures.ln("g", "t"), LogicFixtures.ln("t", "l", "set"),
		LogicFixtures.ln("n", "l", "reset"), LogicFixtures.ln("s", "n"), LogicFixtures.ln("l", "d"), LogicFixtures.ln("t", "d")]
	var traces: Array[String] = []
	for run: int in range(2):
		var g: LogicGraph = LogicFixtures.build(self, elements, links)
		var trace: String = ""
		for tick: int in range(240):
			g.set_load("p1", 2 if (tick / 5) % 2 == 0 else 0)
			if tick % 37 == 0:
				g.trigger("s")
			g.step()
			for id: String in ["g", "t", "l", "n", "d"]:
				trace += "1" if g.is_active(id) else "0"
		traces.append(trace)
	assert_eq(traces[0], traces[1], "identical inputs give identical outputs")
	assert_true(traces[0].contains("1"), "the scenario actually does something")

## A loop in a puzzle must never become a RefCounted reference cycle (those are never freed).
func test_graphs_with_loops_do_not_leak() -> void:
	var elements: Array = [LogicFixtures.el("p", "plate"), LogicFixtures.el("o", "or"), LogicFixtures.el("a", "not"), LogicFixtures.el("b", "not"), LogicFixtures.el("d", "door")]
	var links: Array = [LogicFixtures.ln("p", "o"), LogicFixtures.ln("o", "o"), LogicFixtures.ln("o", "a"), LogicFixtures.ln("a", "b"), LogicFixtures.ln("b", "a"), LogicFixtures.ln("b", "d")]
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i: int in range(20):
		var g: LogicGraph = LogicGraph.new()
		g.setup(elements, links)
		g.step()
		g.setup(elements, links) # rebuilding must not strand the old elements either
	var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_lt(after - before, 10, "20 looped graphs left %d objects behind" % (after - before))

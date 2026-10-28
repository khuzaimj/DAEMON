extends GutTest

# Data validation and error handling of LogicGraph.setup().

func test_validate_catches_bad_data() -> void:
	var errs: Array[String] = LogicGraph.validate(
		[LogicFixtures.el("p", "plate", { "weight": 0 }), LogicFixtures.el("t", "timer"), LogicFixtures.el("p", "plate"), LogicFixtures.el("m", "machine"), LogicFixtures.el("l", "latch", { "persist": "yes" }), LogicFixtures.el("", "door"), LogicFixtures.el("d", "door")],
		[LogicFixtures.ln("p", "ghost"), LogicFixtures.ln("m", "d"), LogicFixtures.ln("d", "p"), LogicFixtures.ln("p", "d", "set"), LogicFixtures.ln("p", "d", "bogus")])
	var text: String = "\n".join(errs)
	for needle: String in ["weight", "timer 't' needs duration", "duplicate element id 'p'", "persist", "has no id", "'ghost' does not exist", "'m' is not a logic element", "accepts no incoming links", "has no port 'set'", "has no port 'bogus'"]:
		assert_true(text.contains(needle), "expected an error mentioning: " + needle)

func test_setup_with_errors_leaves_graph_empty() -> void:
	var g: LogicGraph = LogicGraph.new()
	var errors: Array[String] = g.setup([LogicFixtures.el("p", "plate")], [LogicFixtures.ln("p", "nope")])
	assert_false(errors.is_empty())
	assert_false(g.has_element("p"), "fails closed: nothing is built")
	g.set_load("p", 9)
	g.step()
	assert_false(g.is_active("p"))

func test_setup_can_be_called_again() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("a", "plate")], [])
	g.set_load("a", 1)
	g.step()
	assert_true(g.is_active("a"))
	assert_eq(g.setup([LogicFixtures.el("b", "plate")], []), [] as Array[String])
	assert_false(g.has_element("a"))
	assert_true(g.has_element("b"))
	assert_false(g.is_active("b"), "fresh state after setup")

func test_unknown_ids_are_harmless_to_inputs_and_queries() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("p", "plate")], [])
	g.set_load("ghost", 5)
	g.set_sensor("ghost", true)
	g.set_sensor("p", true) # wrong behavior, ignored
	g.trigger("ghost")
	g.force_state("ghost", true)
	g.step()
	assert_false(g.is_active("ghost"))
	assert_false(g.is_active("p"))
	assert_eq(g.timer_remaining("ghost"), 0)

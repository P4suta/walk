extends GutTest

var route: RouteDef = preload("res://data/route.tres")


func test_upgrade_spends_available_steps_and_preserves_lifetime_record() -> void:
	var state: GameState = GameRules.walk(GameState.new(), 10, route)
	var result: ActionResult = GameRules.purchase(state, 0)
	assert_eq(result.status, ActionResult.Status.OK)
	assert_eq(result.state.steps, 0)
	assert_eq(result.state.total_steps, 10)
	assert_almost_eq(GameRules.stride_m(result.state), 0.8, 0.00001)
	assert_eq(state.purchases[0], 0)
	assert_eq(GameRules.price(0, 1), 11)
	assert_eq(GameRules.price(0, 2), 13)


func test_insufficient_purchase_reports_exact_shortfall() -> void:
	var result: ActionResult = GameRules.purchase(GameState.new(), 1)
	assert_eq(result.status, ActionResult.Status.INSUFFICIENT_STEPS)
	assert_eq(result.shortfall, 300)
	assert_eq(result.state.purchases[1], 0)


func test_companions_credit_steps_and_distance_without_offline_time() -> void:
	var state: GameState = GameRules.walk(GameState.new(), 50, route)
	state = GameRules.purchase(state, 3).state
	state = GameRules.tick(state, 0.5, route)
	state = GameRules.tick(state, 0.5, route)
	assert_eq(state.steps, 1)
	assert_eq(state.total_steps, 51)
	assert_almost_eq(state.distance_m, 35.7, 0.00001)
	var suspended: GameState = GameRules.tick(state, 3600.0, route)
	assert_same(suspended, state)


func test_arrivals_wait_until_displayed_and_chapter_end_blocks_progress() -> void:
	var state: GameState = GameRules.walk(GameState.new(), 2000000, route)
	assert_eq(state.reached_count, 40)
	assert_eq(state.visited_count, 0)
	assert_eq(GameRules.open_gate(state, route).status, ActionResult.Status.LOCKED)
	var waiting_distance: float = state.chapter_distance_m
	state = GameRules.walk(state, 100, route)
	assert_eq(state.reached_count, 40)
	assert_eq(state.chapter_distance_m, waiting_distance)
	assert_gt(state.distance_m, waiting_distance)
	for index: int in range(40):
		state = GameRules.finish_sight(state, route)
	var result: ActionResult = GameRules.open_gate(state, route)
	assert_eq(result.status, ActionResult.Status.OK)
	assert_eq(result.state.chapter, 1)
	assert_eq(result.state.chapter_distance_m, 0.0)
	assert_eq(result.state.steps, state.steps - 20000)
	assert_eq(GameRules.open_gate(result.state, route).status, ActionResult.Status.LOCKED)
	assert_almost_eq(GameRules.stride_m(result.state), 7.0, 0.00001)


func test_steps_do_not_overflow_signed_integer() -> void:
	var state := GameState.new()
	state.steps = GameRules.MAX_STEPS - 1
	state.total_steps = GameRules.MAX_STEPS - 1
	state = GameRules.walk(state, 100, route)
	assert_eq(state.steps, GameRules.MAX_STEPS)
	assert_eq(state.total_steps, GameRules.MAX_STEPS)


func test_ready_gate_reports_shortfall_without_spending_or_advancing() -> void:
	var state := GameState.new()
	state.steps = 19999
	state.total_steps = 19999
	state.reached_count = 40
	state.visited_count = 40
	state.chapter_distance_m = route.chapters[0].length_m()
	state.distance_m = state.chapter_distance_m
	var result: ActionResult = GameRules.open_gate(state, route)
	assert_eq(result.status, ActionResult.Status.INSUFFICIENT_STEPS)
	assert_eq(result.shortfall, 1)
	assert_same(result.state, state)
	assert_eq(result.state.chapter, 0)
	assert_eq(result.state.steps, 19999)


func test_huge_distance_has_a_finite_readable_unit() -> void:
	assert_eq(GameFormat.distance(1.2e19), "1.2京km")
	assert_eq(GameFormat.distance(0.7), "0.7m")
	assert_false("inf" in GameFormat.distance(1.0e30))

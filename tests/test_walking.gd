extends GutTest


func test_one_step_credits_currency_lifetime_steps_and_distance() -> void:
	var state := GameState.new()
	var result := GameRules.walk(state)
	assert_eq(result.steps, 1)
	assert_eq(result.total_steps, 1)
	assert_almost_eq(result.distance_m, 0.7, 0.00001)
	assert_eq(state.steps, 0, "The rule must preserve its input.")

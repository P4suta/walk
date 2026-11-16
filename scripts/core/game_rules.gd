class_name GameRules
extends RefCounted

const MAX_STEPS: int = 9223372036854775807
const UPGRADES: UpgradeCatalog = preload("res://data/upgrades.tres")
const ROUTE: RouteDef = preload("res://data/route.tres")
const MAX_ACTIVE_DELTA: float = 0.5


static func stride_m(state: GameState) -> float:
	var stride: float = 0.7
	for index: int in range(3):
		stride += UPGRADES.items[index].stride_m * state.purchases[index]
	for index: int in range(state.chapter):
		stride *= ROUTE.chapters[index].gate_multiplier
	return stride


static func auto_rate(state: GameState) -> int:
	var rate: int = 0
	for index: int in range(3):
		rate += UPGRADES.items[index + 3].steps_per_second * state.purchases[index + 3]
	return rate


static func price(upgrade_index: int, owned: int) -> int:
	if upgrade_index < 0 or upgrade_index >= UPGRADES.items.size() or owned < 0:
		return -1
	var amount: float = ceil(UPGRADES.items[upgrade_index].base_price * pow(1.10, owned))
	if not is_finite(amount) or amount >= float(MAX_STEPS):
		return -1
	return int(amount)


static func walk(state: GameState, count: int = 1, route: RouteDef = null) -> GameState:
	if count <= 0:
		return state
	var result: GameState = state.copy()
	var credited: int = mini(count, MAX_STEPS - state.total_steps)
	result.steps = mini(state.steps, MAX_STEPS - credited) + credited
	result.total_steps += credited
	var distance: float = stride_m(state) * float(credited)
	result.distance_m += distance
	if route != null and not state.home:
		result.chapter_distance_m = minf(
			state.chapter_distance_m + distance, route.chapters[state.chapter].length_m()
		)
		result.reached_count = route.reached_at(result.chapter, result.chapter_distance_m)
	return result


static func tick(state: GameState, delta: float, route: RouteDef) -> GameState:
	if not is_finite(delta) or delta <= 0.0 or delta > MAX_ACTIVE_DELTA:
		return state
	var result: GameState = state.copy()
	result.play_time_s += delta
	var fraction: float = state.auto_fraction + auto_rate(state) * delta
	var count: int = int(floor(fraction + 0.0000000001))
	result.auto_fraction = maxf(0.0, fraction - count)
	if count > 0:
		result = walk(result, count, route)
	return result


static func purchase(state: GameState, upgrade_index: int) -> ActionResult:
	if upgrade_index < 0 or upgrade_index >= state.purchases.size():
		return ActionResult.new(state, ActionResult.Status.INVALID_ACTION)
	var cost: int = price(upgrade_index, state.purchases[upgrade_index])
	if cost < 0:
		return ActionResult.new(state, ActionResult.Status.LIMIT_REACHED)
	if state.steps < cost:
		return ActionResult.new(
			state, ActionResult.Status.INSUFFICIENT_STEPS, cost, cost - state.steps
		)
	var result: GameState = state.copy()
	result.steps -= cost
	result.purchases[upgrade_index] += 1
	return ActionResult.new(result, ActionResult.Status.OK, cost)


static func finish_sight(state: GameState, route: RouteDef) -> GameState:
	if state.visited_count >= state.reached_count:
		return state
	var result: GameState = state.copy()
	result.visited_count += 1
	result.home = result.visited_count == route.sight_count()
	return result


static func gate_ready(state: GameState, route: RouteDef) -> bool:
	return (
		state.chapter < route.chapters.size() - 1
		and (
			state.visited_count
			== route.chapter_start(state.chapter) + route.chapters[state.chapter].sight_count()
		)
	)


static func open_gate(state: GameState, route: RouteDef) -> ActionResult:
	if not gate_ready(state, route):
		return ActionResult.new(state, ActionResult.Status.LOCKED)
	var cost: int = route.chapters[state.chapter].gate_price
	if state.steps < cost:
		return ActionResult.new(
			state, ActionResult.Status.INSUFFICIENT_STEPS, cost, cost - state.steps
		)
	var result: GameState = state.copy()
	result.steps -= cost
	result.chapter += 1
	result.chapter_distance_m = 0.0
	return ActionResult.new(result, ActionResult.Status.OK, cost)

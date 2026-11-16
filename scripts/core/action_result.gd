class_name ActionResult
extends RefCounted

enum Status { OK, INSUFFICIENT_STEPS, LOCKED, LIMIT_REACHED, INVALID_ACTION }

var state: GameState
var status: Status
var price: int
var shortfall: int


func _init(
	result_state: GameState, result_status: Status, action_price: int = 0, missing_steps: int = 0
) -> void:
	state = result_state
	status = result_status
	price = action_price
	shortfall = missing_steps

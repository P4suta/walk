class_name SaveResult
extends RefCounted

enum Status { LOADED, EMPTY, RECOVERED, INVALID, WRITE_FAILED }

var status: Status = Status.INVALID
var state: GameState
var settings: GameSettings
var message: String = ""


func _init(result_status: Status = Status.INVALID, detail: String = "") -> void:
	status = result_status
	message = detail

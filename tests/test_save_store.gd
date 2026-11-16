extends GutTest

var route: RouteDef = preload("res://data/route.tres")
var store: SaveStore


func before_each() -> void:
	store = SaveStore.new("user://walk-store-test.json")
	assert_true(store.erase())


func after_each() -> void:
	assert_true(store.erase())


func test_corrupt_primary_recovers_a_valid_backup_and_can_save_again() -> void:
	var settings := GameSettings.new()
	var first: GameState = GameRules.walk(GameState.new(), 10, route)
	assert_true(store.write_save(first, settings, route))
	assert_true(store.write_save(GameRules.walk(first, 1, route), settings, route))
	_write(store.path, "{")
	var recovered: SaveResult = store.read_save(route)
	assert_eq(recovered.status, SaveResult.Status.RECOVERED)
	assert_eq(recovered.state.total_steps, 10)
	assert_true(store.write_save(recovered.state, recovered.settings, route))
	assert_eq(store.read_save(route).status, SaveResult.Status.LOADED)


func test_interrupted_temporary_write_never_replaces_valid_progress() -> void:
	var state: GameState = GameRules.walk(GameState.new(), 123, route)
	assert_true(store.write_save(state, GameSettings.new(), route))
	_write(store.path + ".tmp", '{"format":')
	assert_eq(store.read_save(route).state.total_steps, 123)
	assert_eq(DirAccess.remove_absolute(store.path), OK)
	assert_eq(store.read_save(route).status, SaveResult.Status.RECOVERED)
	assert_eq(store.read_save(route).state.total_steps, 123)


func test_both_invalid_copies_stop_loading_and_erase_restores_empty_state() -> void:
	_write(store.path, "invalid")
	_write(store.path + ".bak", "[]")
	assert_eq(store.read_save(route).status, SaveResult.Status.INVALID)
	assert_true(store.erase())
	assert_eq(store.read_save(route).status, SaveResult.Status.EMPTY)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()

class_name SaveStore
extends RefCounted

var path: String


func _init(save_path: String = "user://walk-save.json") -> void:
	path = save_path


func read_save(route: RouteDef) -> SaveResult:
	var primary: SaveResult = _read(path, route)
	if primary.status == SaveResult.Status.LOADED:
		return primary
	var backup: SaveResult = _read(path + ".bak", route)
	if backup.status == SaveResult.Status.LOADED:
		backup.status = SaveResult.Status.RECOVERED
		return backup
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		var empty := SaveResult.new(SaveResult.Status.EMPTY)
		empty.state = GameState.new()
		empty.settings = GameSettings.new()
		return empty
	return SaveResult.new(SaveResult.Status.INVALID, primary.message)


func write_save(state: GameState, settings: GameSettings, route: RouteDef) -> bool:
	var text: String = SaveCodec.encode(state, settings)
	if SaveCodec.decode(text, route).status != SaveResult.Status.LOADED:
		return false
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or _read(temporary, route).status != SaveResult.Status.LOADED:
		return false
	var backup_source: String = temporary
	if _read(path, route).status == SaveResult.Status.LOADED:
		backup_source = path
	var backup_temporary: String = path + ".bak.tmp"
	if DirAccess.copy_absolute(backup_source, backup_temporary) != OK:
		return false
	if DirAccess.rename_absolute(backup_temporary, path + ".bak") != OK:
		return false
	return DirAccess.rename_absolute(temporary, path) == OK


func erase() -> bool:
	var removed: bool = true
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		var target: String = path + suffix
		if FileAccess.file_exists(target):
			removed = DirAccess.remove_absolute(target) == OK and removed
	return removed


func _read(target: String, route: RouteDef) -> SaveResult:
	if not FileAccess.file_exists(target):
		return SaveResult.new(SaveResult.Status.INVALID, "The save file is missing.")
	var file: FileAccess = FileAccess.open(target, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return SaveResult.new(SaveResult.Status.INVALID, "The save file is unreadable.")
	var text: String = file.get_as_text()
	file.close()
	return SaveCodec.decode(text, route)

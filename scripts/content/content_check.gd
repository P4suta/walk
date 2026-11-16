class_name ContentCheck
extends RefCounted


static func errors(route: RouteDef) -> PackedStringArray:
	var findings := PackedStringArray()
	if route.chapters.size() != 5 or route.sight_count() != 248:
		findings.append("The route requires five chapters and 248 sights.")
	var expected_regions: Array[int] = [5, 11, 9, 8, 8]
	var space_sights: Array[int] = [4, 5, 4, 5, 4, 4, 4, 5, 5]
	var gate_prices: Array[int] = [20000, 60000, 600000, 2000000, 0]
	var gate_multipliers: Array[float] = [10.0, 1000.0, 1000.0, 1000.0, 1.0]
	var keys: Array[String] = []
	var previous_end: float = 0.0
	for chapter_index: int in range(route.chapters.size()):
		var chapter: ChapterDef = route.chapters[chapter_index]
		if chapter_index >= 5 or chapter.regions.size() != expected_regions[chapter_index]:
			findings.append("The chapter region count differs from the design.")
		if chapter.source_origin_m != previous_end:
			findings.append("The chapter origin differs from the previous chapter endpoint.")
		if (
			chapter_index < 5
			and (
				chapter.gate_price != gate_prices[chapter_index]
				or chapter.gate_multiplier != gate_multipliers[chapter_index]
			)
		):
			findings.append("The gate differs from the approved route.")
		var region_index: int = 0
		for region: RegionDef in chapter.regions:
			var expected_sights: int = 8 if chapter_index < 2 else 5
			if chapter_index == 2 and region_index < space_sights.size():
				expected_sights = space_sights[region_index]
			if region.sights.size() != expected_sights:
				findings.append(region.key + ": invalid sight count.")
			region_index += 1
			if region.key.is_empty() or keys.has(region.key):
				findings.append("A region key is empty or duplicated.")
			keys.append(region.key)
			if not is_finite(region.end_distance_m) or region.end_distance_m <= previous_end:
				findings.append(region.key + ": invalid distance interval.")
			previous_end = region.end_distance_m
			for sight: SightDef in region.sights:
				if sight.title.is_empty():
					findings.append(region.key + ": missing sight title.")
				findings.append_array(_artwork_errors(sight.artwork, sight.artwork_size))
			findings.append_array(landscape_errors(region))
	return findings


static func _artwork_errors(path: String, expected: Vector2i) -> PackedStringArray:
	var findings := PackedStringArray()
	if not path.begins_with("res://assets/art/") or not ResourceLoader.exists(path):
		findings.append(path + ": missing artwork.")
	else:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null or Vector2i(texture.get_size()) != expected:
			findings.append(path + ": artwork dimensions differ from the design slot.")
	return findings


static func landscape_errors(region: RegionDef) -> PackedStringArray:
	var findings := PackedStringArray()
	if not FileAccess.file_exists(region.landscape):
		return PackedStringArray([region.key + ": missing landscape."])
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(region.landscape)) != OK:
		return PackedStringArray([region.key + ": invalid landscape JSON."])
	var root: Variant = parser.data
	if not root is Dictionary or not root.get("sprites") is Array:
		return PackedStringArray([region.key + ": invalid landscape structure."])
	if not root.get("night") is bool or root.night != region.night:
		findings.append(region.key + ": invalid landscape palette.")
	for raw: Variant in root.sprites:
		if (
			not raw is Dictionary
			or not raw.has_all(["artwork", "width", "height", "x", "y", "motion", "name"])
		):
			findings.append(region.key + ": missing sprite fields.")
			continue
		if not raw.artwork is String or not raw.name is String:
			findings.append(region.key + ": invalid sprite identity.")
			continue
		if not _sprite_geometry_valid(raw):
			findings.append(region.key + ": invalid sprite geometry.")
			continue
		var filename: String = raw.artwork
		if filename.get_file() != filename:
			findings.append(region.key + ": invalid artwork path.")
			continue
		findings.append_array(
			_artwork_errors(
				"res://assets/art/" + filename, Vector2i(int(raw.width), int(raw.height))
			)
		)
	return findings


static func _sprite_geometry_valid(data: Dictionary) -> bool:
	for key: String in ["width", "height", "x", "y", "motion"]:
		var value: Variant = data[key]
		if not value is float and not value is int:
			return false
		if not is_finite(float(value)) or float(value) != floor(float(value)):
			return false
	return float(data.width) > 0 and float(data.height) > 0 and int(data.motion) in [0, 1, 4, 8]

class_name RouteDef
extends Resource

@export var chapters: Array[ChapterDef] = []


func sight_count() -> int:
	var count: int = 0
	for chapter: ChapterDef in chapters:
		count += chapter.sight_count()
	return count


func chapter_start(chapter_index: int) -> int:
	var count: int = 0
	for index: int in range(chapter_index):
		count += chapters[index].sight_count()
	return count


func region_for_sight(sight_index: int) -> RegionDef:
	var offset: int = 0
	for chapter: ChapterDef in chapters:
		for region: RegionDef in chapter.regions:
			if sight_index < offset + region.sights.size():
				return region
			offset += region.sights.size()
	return chapters[0].regions[0]


func sight(sight_index: int) -> SightDef:
	var offset: int = 0
	for chapter: ChapterDef in chapters:
		for region: RegionDef in chapter.regions:
			if sight_index < offset + region.sights.size():
				return region.sights[sight_index - offset]
			offset += region.sights.size()
	return null


func reached_at(chapter_index: int, distance_m: float) -> int:
	var chapter: ChapterDef = chapters[chapter_index]
	var reached: int = chapter_start(chapter_index)
	var start_m: float = chapter.source_origin_m
	for region: RegionDef in chapter.regions:
		for index: int in range(region.sights.size()):
			var threshold: float = (
				start_m
				+ (region.end_distance_m - start_m) * float(index + 1) / region.sights.size()
				- chapter.source_origin_m
			)
			if distance_m >= threshold:
				reached += 1
		start_m = region.end_distance_m
	return reached

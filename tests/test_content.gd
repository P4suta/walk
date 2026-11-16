extends GutTest

var route: RouteDef = preload("res://data/route.tres")


func test_route_contains_every_designed_region_and_sight() -> void:
	assert_eq(route.chapters.size(), 5)
	var regions: int = 0
	for chapter: ChapterDef in route.chapters:
		regions += chapter.regions.size()
	assert_eq(regions, 41)
	assert_eq(route.sight_count(), 248)


func test_original_artwork_has_the_designed_geometry() -> void:
	assert_eq(ContentCheck.errors(route), PackedStringArray())


func test_missing_sights_and_artwork_are_rejected() -> void:
	var incomplete: RouteDef = route.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as RouteDef
	incomplete.chapters[0].regions[0].sights.pop_back()
	assert_false(ContentCheck.errors(incomplete).is_empty())
	var missing: RouteDef = route.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as RouteDef
	missing.chapters[0].regions[0].sights[0].artwork = "res://assets/art/missing.svg"
	assert_false(ContentCheck.errors(missing).is_empty())

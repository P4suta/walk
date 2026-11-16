class_name GameFormat
extends RefCounted


static func number(value: float) -> String:
	if value < 10000.0:
		return str(int(value))
	var units: Array[String] = ["万", "億", "兆", "京", "垓"]
	var scaled: float = value
	for unit: String in units:
		scaled /= 10000.0
		if scaled < 10000.0:
			return ("%.1f" % scaled).trim_suffix(".0") + unit
	var exponent: int = int(floor(log(value) / log(10.0)))
	return "%.2f×10^%d" % [value / pow(10.0, exponent), exponent]


static func distance(meters: float) -> String:
	if meters < 1000.0:
		return ("%.1f" % meters).trim_suffix(".0") + "m"
	return number(meters / 1000.0) + "km"


static func duration(seconds: float) -> String:
	var minutes: int = int(seconds / 60.0)
	return "%d時間%d分" % [int(minutes / 60.0), minutes % 60]


static func stride_gain(meters: float) -> String:
	return str(roundi(meters * 100.0)) + "cm" if meters < 1.0 else distance(meters)

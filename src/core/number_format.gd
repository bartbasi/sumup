class_name NumberFormat extends RefCounted
## Number text for tiles and scores (GDD section 14). All static.
## Costs, the merge preview, Best Tile and the run's highest tile use
## tile_label. Score and Best Score use score.


## TH17, D-31. Values up to LABEL_FULL_MAX show in full (1024). Above that the
## value is divided by LABEL_STEP until it is below LABEL_STEP or the
## suffixes run out, then the suffix for that step follows (2K, 128K, 1M, 1T,
## 1024T). With no config the GDD section 18 values are used.
@warning_ignore("integer_division")
static func tile_label(value: int, config: GameConfig = null) -> String:
	var settings: GameConfig = config if config != null else GameConfig.new()
	if value <= settings.label_full_max or settings.label_step <= 1 or settings.label_suffixes.is_empty():
		return str(value)
	var shown: int = value
	var steps: int = 0
	while shown >= settings.label_step and steps < settings.label_suffixes.size():
		shown /= settings.label_step
		steps += 1
	if steps == 0:
		return str(value)
	return str(shown) + settings.label_suffixes[steps - 1]


## TH17, D-32. The full number with a comma every three digits: 1,234,567.
static func score(value: int) -> String:
	var digits: String = str(value)
	var sign_text: String = ""
	if digits.begins_with("-"):
		sign_text = "-"
		digits = digits.substr(1)
	var grouped: String = ""
	var count: int = 0
	for position: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			grouped = "," + grouped
		grouped = digits[position] + grouped
		count += 1
	return sign_text + grouped

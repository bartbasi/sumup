extends RefCounted
## The one fixed game moment that all three Phase 1 directions render, so
## Bart compares like for like. Every screen scene reads its numbers, board
## and text from here. Nothing here is a game rule: rules, costs and UI text
## are placeholders until docs/GDD.md is final, and the senior-graphic-designer
## syncs them in round 2.
##
## Board cells are Vector2i(column, row). Column 0 is the left edge, row 0 is
## the top row. Board arrays hold ROWS rows of COLUMNS values, top row first.
##
## Phase 1 prototype code. Nothing under tools/ ships with the game.

## Capture size. Every screen scene fills exactly this canvas.
const CANVAS_SIZE: Vector2i = Vector2i(1080, 2400)
## Simulated device safe area: status bar with a punch hole camera at the top,
## gesture bar at the bottom. Keep text and touch targets out of these bands.
const SAFE_TOP: int = 120
const SAFE_BOTTOM: int = 66

const COLUMNS: int = 5
const ROWS: int = 8

# Board screen

const SCORE: int = 21350
const BEST_SCORE: int = 48212
## Best tile ever, shown wherever the design shows a best tile.
const BEST_TILE: int = 4096

## The chain being dragged on the board screen: 8, 8, 16, 32, 64, 128.
## Its sum is 256, a power of two, so the preview is 256 under any rounding rule.
const CHAIN_PREVIEW: int = 256

# Boosters, in bar order

const BOOSTER_IDS: PackedStringArray = ["hammer", "swap", "shuffle", "double", "undo"]
const BOOSTER_NAMES: PackedStringArray = ["Hammer", "Swap", "Shuffle", "Double", "Undo"]
## Placeholder costs. Double costs more than SCORE, so it shows disabled.
const BOOSTER_COSTS: PackedInt32Array = [900, 1200, 1500, 24000, 600]

# Targeting screen

## The booster in targeting mode, and the tile under the finger.
const TARGETING_BOOSTER: String = "hammer"
const TARGET_CELL: Vector2i = Vector2i(2, 5)
const TARGET_HINT: String = "Tap a tile to smash it"
const TARGET_CANCEL_HINT: String = "Tap Hammer again to cancel"

# Game over screen

const FINAL_SCORE: int = 38904
const RUN_BEST_TILE: int = 4096
const IS_NEW_BEST: bool = false
## The rescue offer: the booster the player can still afford.
const RESCUE_BOOSTER: String = "shuffle"
const GAMEOVER_TITLE: String = "Out of moves"
const GAMEOVER_BODY: String = "Shuffle the board and keep this run going?"
const GAMEOVER_END: String = "End run"

# Settings screen

const SETTINGS_TITLE: String = "Settings"
const SOUND_LABEL: String = "Sound"
const SOUND_ON: bool = true
const SKIN_LABEL: String = "Skin"
## Built in skins shown in the picker. Each direction shows its own name as
## selected. Whether the unpicked directions become skins is Bart's call at
## Hard Stop 1; the picker here only shows what one would look like.
const SKIN_NAMES: PackedStringArray = ["Gumdrop", "Slate", "Nova"]
const SKIN_IDS: PackedStringArray = ["gumdrop", "slate", "nova"]
const VERSION_TEXT: String = "numbersgame 0.1"

# HUD text

const SCORE_LABEL: String = "Score"
const BEST_LABEL: String = "Best"
const BEST_TILE_LABEL: String = "Best tile"
const CHAIN_LABEL: String = "Chain"


## Mid game board for the board and targeting screens. Highest tile 2048.
static func board_values() -> Array[PackedInt32Array]:
	return [
		PackedInt32Array([2, 16, 4, 2, 8]),
		PackedInt32Array([4, 1024, 64, 8, 2]),
		PackedInt32Array([16, 128, 2, 32, 4]),
		PackedInt32Array([2, 4, 512, 16, 64]),
		PackedInt32Array([32, 8, 8, 2, 16]),
		PackedInt32Array([4, 2048, 16, 4, 2]),
		PackedInt32Array([8, 2, 32, 256, 8]),
		PackedInt32Array([64, 4, 2, 8, 4]),
	]


## The chain on the board screen, in drag order. The finger is on the last cell.
static func chain_cells() -> Array[Vector2i]:
	return [
		Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 3),
		Vector2i(3, 2), Vector2i(2, 1), Vector2i(1, 2),
	]


## Where the finger is, in board cell units (Vector2(0, 0) is the top left
## corner of the board, Vector2(5, 8) the bottom right). It sits just past the
## center of the last chain cell, heading down and left.
static func drag_point() -> Vector2:
	return Vector2(1.36, 2.72)


## Board at game over: no two touching tiles (eight directions) are equal,
## so no chain can start. Highest tile 4096.
static func gameover_values() -> Array[PackedInt32Array]:
	return [
		PackedInt32Array([4, 32, 2, 16, 8]),
		PackedInt32Array([16, 8, 64, 4, 2]),
		PackedInt32Array([2, 128, 2, 512, 32]),
		PackedInt32Array([64, 16, 32, 8, 4]),
		PackedInt32Array([8, 4096, 2, 128, 16]),
		PackedInt32Array([2, 64, 16, 4, 256]),
		PackedInt32Array([32, 4, 1024, 64, 8]),
		PackedInt32Array([8, 16, 2, 32, 2]),
	]


## Cost of a booster by id.
static func booster_cost(booster_id: String) -> int:
	var index: int = BOOSTER_IDS.find(booster_id)
	if index < 0:
		push_error("unknown booster '%s'" % booster_id)
		return 0
	return BOOSTER_COSTS[index]


## Display name of a booster by id.
static func booster_name(booster_id: String) -> String:
	var index: int = BOOSTER_IDS.find(booster_id)
	if index < 0:
		push_error("unknown booster '%s'" % booster_id)
		return ""
	return BOOSTER_NAMES[index]


## Whether the booster is affordable at SCORE on the board screens.
static func is_affordable(booster_id: String) -> bool:
	return SCORE >= booster_cost(booster_id)


## Tile label. Placeholder rule until docs/GDD.md fixes it: values up to 1024
## show in full, then K for thousands and M for millions in steps of 1024
## (2048 is 2K, 65536 is 64K, 131072 is 128K, 1048576 is 1M). Labels stay at
## 4 characters or fewer up to 512M.
static func tile_label(value: int) -> String:
	if value <= 1024:
		return str(value)
	if value < 1048576:
		return "%dK" % (value / 1024)
	return "%dM" % (value / 1048576)


## Score and cost text with thousands separators, for example 21,350.
static func format_number(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if value < 0 else out

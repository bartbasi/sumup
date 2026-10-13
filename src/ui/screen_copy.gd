extends RefCounted
## Every word the screens and panels show (DESIGN_SYSTEM.md section 7 and
## 7.10). Screens case it with the skin's type role rule when they show it
## (see ui_parts.gd). Booster names come from the design's UiCopy, so the bar
## and the screens always agree.

const UiCopy: GDScript = preload("res://src/design/shared/ui_copy.gd")

const WORDMARK: String = "SumUp"
const NEW_GAME: String = "New game"
const SETTINGS: String = "Settings"
const BEST_SCORE: String = "Best score"
const BEST_TILE: String = "Best tile"
const RUN_HIGHEST: String = "This run's highest tile"
const SCORE: String = "Score"

const PAUSED: String = "Paused"
const RESUME: String = "Resume"

const CONFIRM_TITLE: String = "Start a new game?"
const CONFIRM_BODY: String = "This run ends here. Its score already counts in your records."
const CANCEL: String = "Cancel"

const OUT_OF_MOVES: String = "Out of moves"
const OFFER_BODY: String = "Pick a booster to keep this run going."
const OFFER_NO_RESCUE: String = "No rescue left. Pick a booster or end the run."
const END_RUN: String = "End run"

const RUN_OVER: String = "Run over"
## GDD 12.2 step 3: the run ended at once because nothing was usable (QA4-01).
const NO_MOVES_LEFT: String = "No moves left."
const MAIN_MENU: String = "Main menu"
const NEW_BEST: String = "New best"

const SOUND: String = "Sound"
const SKIN: String = "Skin"

const HINTS: Dictionary[StringName, String] = {
	&"hammer": "Tap a tile to smash it",
	&"swap": "Tap two tiles to swap them",
	&"double": "Tap a tile to double it",
}
const SWAP_SECOND: String = "Now tap the tile to swap with"


## The suggested buy button: "Shuffle for 4K". The cost uses the tile label
## format (D-32).
static func buy(booster_id: StringName, cost: int) -> String:
	return "%s for %s" % [booster_name(booster_id), NumberFormat.tile_label(cost)]


static func booster_name(booster_id: StringName) -> String:
	return UiCopy.BOOSTER_NAMES.get(booster_id, String(booster_id))


## The targeting hint for the booster (7.10), or "" for none. Swap reads
## differently once its first tile is chosen.
static func hint(booster_id: StringName, swap_chosen: bool) -> String:
	if booster_id == &"swap" and swap_chosen:
		return SWAP_SECOND
	return HINTS.get(booster_id, "")


## Slate's context row in targeting: "Hammer: Tap a tile to smash it", which
## its label role sets in capitals (DESIGN_SYSTEM.md 5.7).
static func targeting_context(booster_id: StringName, swap_chosen: bool) -> String:
	var text: String = hint(booster_id, swap_chosen)
	if text.is_empty():
		return ""
	return "%s: %s" % [booster_name(booster_id), text]


## Slate's context row while dragging: "Chain 6" (DESIGN_SYSTEM.md 5.7).
static func chain(count: int) -> String:
	return "Chain %d" % count


## The settings version line: the project name and, when the project sets
## one, its version.
static func version_line() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	return WORDMARK if version.is_empty() else "%s %s" % [WORDMARK, version]

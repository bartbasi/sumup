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

## 2026-10-13 additions (DESIGN_SYSTEM.md 7.10).
const HOW_TO_PLAY: String = "How to play"
const ABOUT: String = "About"
const VERSION: String = "Version %s"
const MADE_BY: String = "Made by Bart Basi"
## A license term (NOTICE, term 1): shown exactly, never cased.
const COPYRIGHT: String = "Copyright 2026 Bart Basi"
const ABOUT_SECTIONS: Array[Dictionary] = [
	{"title": "What it is", "text": "SumUp is a number merge puzzle. Join touching tiles of the same number into bigger ones and see how high you can go."},
	{"title": "Offline, no data", "text": "SumUp works fully offline. It collects no data, has no ads or accounts and asks for no permissions."},
	{"title": "Licenses", "text": "SumUp is free software: you can share and change it under the GNU General Public License, version 3, with two additional terms. Every copy keeps the attribution above, and changed versions are marked as changed. SumUp comes with no warranty."},
]
## The license rows, in order: id, title, detail line.
const LICENSE_ROWS: Array[Dictionary] = [
	{"id": &"game", "title": "SumUp", "detail": "GNU GPL version 3, two added terms"},
	{"id": &"godot", "title": "Godot Engine", "detail": "MIT license and its parts"},
	{"id": &"outfit", "title": "Outfit font", "detail": "SIL Open Font License 1.1"},
]
const LICENSE_TITLES: Dictionary[StringName, String] = {
	&"game": "SumUp license",
	&"godot": "Godot Engine",
	&"outfit": "Outfit font",
}
const NOTICE_HEADING: String = "Notice"
const GPL_HEADING: String = "GNU General Public License"
const GODOT_LICENSE_HEADING: String = "Godot Engine license"
const GODOT_PARTS_HEADING: String = "Third party parts"
const GODOT_TEXTS_HEADING: String = "License texts"
const PART_COPYRIGHT: String = "Copyright %s"
const PART_LICENSE: String = "License: %s"
## Shown in a license view instead of a text that is missing or damaged in
## this copy of the game.
const TEXT_MISSING: String = "This text could not be read in this copy of SumUp. Installing the game again should bring it back."

const HINTS: Dictionary[StringName, String] = {
	&"hammer": "Tap a tile to smash it",
	&"swap": "Tap two tiles to swap them",
	&"double": "Tap a tile to double it",
}
const SWAP_SECOND: String = "Now tap the tile to swap with"


## The suggested buy button: "Shuffle for 4K". The cost uses the tile label
## format (D-32). While a free booster is held: "Shuffle for free" (D-46).
static func buy(booster_id: StringName, cost: int, free: bool = false) -> String:
	if free:
		return "%s for free" % booster_name(booster_id)
	return "%s for %s" % [booster_name(booster_id), NumberFormat.tile_label(cost)]


## GDD 21.2, HP1 to HP7, word for word. Each section: {"title": String,
## "text": String, "example": PackedInt64Array (the joined tiles in drag
## order, empty for none), "result": int (the result tile, 0 for none)}.
static func how_to_play_sections() -> Array[Dictionary]:
	return [
		_section("Make a chain", "Slide across touching tiles, diagonals too, starting with two equal ones. Each next tile must match the last one or double it.", [2, 2, 4], 8),
		_section("What it makes", "Lift to merge, or lift on one tile to cancel. The tiles add up and round down to a tile number, so 6 becomes 4.", [2, 2, 2], 4),
		_section("After a merge", "The merged tile lands where your chain ended, tiles above fall and new ones drop in. While you drag, highlighted tiles can join next.", [], 0),
		_section("Score", "A chain scores the sum of its tiles. Boosters cost points, your score never drops below zero, and best score and best tile are saved.", [], 0),
		_section("Move up, earn stars", "Each new highest tile from 2K up removes the smallest number and earns a star. Every 3 stars make your next booster free.", [1024, 1024], 2048),
		_section("Boosters", "Hammer smashes a tile, Swap swaps two, Shuffle mixes the board, Double doubles one, Undo takes back your last chain. Prices grow as you go.", [], 0),
		_section("Out of moves", "When no two touching tiles match, you can pick a booster to keep going. If you can't, or you tap End run, the run ends.", [], 0),
	]


static func _section(title: String, text: String, example: Array[int], result: int) -> Dictionary:
	return {"title": title, "text": text, "example": PackedInt64Array(example), "result": result}


## "Version 0.1" for About, or "" when the project sets no version (the line
## is then left out, DESIGN_SYSTEM.md 7.10).
static func version_text() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	return "" if version.is_empty() else VERSION % version


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

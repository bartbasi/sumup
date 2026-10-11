extends "res://tools/directions/shared/direction_tokens.gd"
## Gumdrop: tactile candy. Chunky squircle tiles with a darker lip underneath,
## like keycaps or gummy sweets, on a deep plum night. Everything sits in soft
## rounded containers and moves with a springy bounce.
##
## Owner: senior-graphic-designer. Artists read these values; they do not
## edit this file. Ask for any value that is missing.


func _init() -> void:
	id = "gumdrop"
	display_name = "Gumdrop"

	# Palette. Text only uses the pairs listed in text_pairs below.
	palette = {
		"bg": Color("#150820"),               # screen background, deep plum
		"tray": Color("#20112F"),             # board tray behind the tiles
		"slot": Color("#2A1A3A"),             # empty cell, seen while tiles fall
		"surface": Color("#2B183D"),          # pills, dock, cards, sheets
		"surface_raised": Color("#3F2956"),   # booster buttons, secondary buttons, chips
		"surface_lip": Color("#090213"),      # the lip under raised surfaces and the dock
		"ink": Color("#FFF7FC"),              # main text on dark surfaces
		"ink_soft": Color("#D3BDE5"),         # labels and secondary text
		"ink_dark": Color("#1C0D2B"),         # text on bright fills
		"accent": Color("#FF63B2"),           # hot pink: primary button, active booster, selected chip
		"accent_pressed": Color("#EB4B9F"),
		"accent_lip": Color("#A9246E"),       # lip under accent buttons
		"lemon": Color("#FFDC4F"),            # hint pill, new best badge
		"lemon_lip": Color("#BF9007"),
		"disabled_surface": Color("#1D1625"), # flat, lipless booster that cannot be afforded
		"disabled_ink": Color("#A39AAE"),     # its cost and icon
		"chain": Color("#FFF7FC"),            # chain rope and chained tile ring
		"target": Color("#FFF7FC"),           # targeting ring, drawn with a target_edge outline
		"target_edge": Color("#1C0D2B"),
		"scrim": Color("#150820C7"),          # bg at 78 percent over the board behind dialogs
		"divider": Color("#3F2956"),         # Hairline: a 4 px rounded groove, visible on bg and on surface
	}

	# Tile ramp, value 2 first. Low values are bright candy with dark numbers,
	# 512 to 16K are deep jewel tones with light numbers, and from 32K up each
	# tile is a special: licorice, pearl and gold, with the candy rim effect.
	tile_fill = [
		Color("#35F3B5"), # 2 mint
		Color("#58CCFF"), # 4 sky
		Color("#9398FF"), # 8 periwinkle
		Color("#E17AF8"), # 16 orchid
		Color("#FF81B6"), # 32 bubblegum
		Color("#FF6170"), # 64 watermelon
		Color("#FF9A5F"), # 128 tangerine
		Color("#FFDC4F"), # 256 lemon
		Color("#047B60"), # 512 emerald
		Color("#1957D2"), # 1024 sapphire
		Color("#7D24D3"), # 2K amethyst
		Color("#B70385"), # 4K fuchsia
		Color("#C2152F"), # 8K ruby
		Color("#AB4B01"), # 16K ember
		Color("#2C1A3F"), # 32K licorice
		Color("#FDF1FC"), # 64K pearl
		Color("#F7C243"), # 128K gold
	]
	var dark: Color = Color("#1C0D2B")
	var light: Color = Color("#FFF7FC")
	tile_ink = [
		dark, dark, dark, dark, dark, dark, dark, dark,
		light, light, light, light, light, light, light,
		dark, dark,
	]
	beyond_fill = Color("#F7C243")
	beyond_ink = dark

	text_pairs = [
		pair("Score on the background", "ink", "bg"),
		pair("HUD labels on the background", "ink_soft", "bg"),
		pair("Pill, dock and card text", "ink", "surface"),
		pair("Pill, dock and card labels", "ink_soft", "surface"),
		pair("Booster cost", "ink", "surface_raised"),
		pair("Booster cost, targeting", "ink_dark", "accent"),
		pair("Booster cost, disabled", "disabled_ink", "disabled_surface"),
		pair("Targeting hint pill", "ink_dark", "lemon"),
		pair("New best badge", "ink_dark", "lemon"),
		pair("Primary button", "ink_dark", "accent"),
		pair("Primary button, pressed", "ink_dark", "accent_pressed"),
		pair("Secondary button and skin chip", "ink", "surface_raised"),
		pair("Labels on raised surfaces", "ink_soft", "surface_raised"),
		pair("Skin chip, selected", "ink_dark", "accent"),
		pair("Text straight on the scrim, worst case over a pearl tile", "ink", "scrim", "tile:65536"),
	]

	# Type: one heavy family, black weight for numbers, sentence case.
	type_roles = {
		"display": {"size": 136, "weight": 900, "tracking": -2, "case": CASE_NONE}, # score
		"title": {"size": 76, "weight": 900, "tracking": -1, "case": CASE_NONE},    # dialog titles
		"body": {"size": 46, "weight": 700, "tracking": 0, "case": CASE_NONE},      # buttons, rows
		"label": {"size": 34, "weight": 700, "tracking": 1, "case": CASE_NONE},     # labels, costs
		"tile": {"weight": 900, "tracking": -1, "case": CASE_NONE},
	}
	tile_number_scale = PackedFloat32Array([0.48, 0.44, 0.36, 0.31])

	# Shape and layout. Lengths in px on the 1080 px canvas unless noted.
	shape = {
		"board_margin": 36.0,     # screen edge to tray edge
		"tray_padding": 22.0,     # tray edge to the outer tiles
		"tray_radius": 60.0,
		"gap": 18.0,              # between tiles
		"tile_radius": 0.30,      # fraction of tile side, squircle corners
		"lip_depth": 0.075,       # fraction of tile side: the darker base under the top face
		"lip_darken": 0.34,       # lip color = fill.darkened(lip_darken)
		"lip_pressed": 0.02,      # fraction of tile side: lip of a chained tile, pressed in
		"target_lift": 0.04,      # fraction of tile side: targeted tile rises by this much
		"rope_width": 30.0,       # chain rope, drawn under the tiles so it shows in the gaps
		"ring_width": 7.0,        # ring on chained tiles
		"target_ring_width": 9.0,
		"preview_scale": 0.46,    # preview mini tile, fraction of tile side. It sits on the gap
		                          # crossing at the top left corner of the last chain tile (top
		                          # right in column 0), covering only rounded corners, never numbers.
		"preview_ring": 6.0,      # px, chain color ring round the preview mini tile
		"target_edge_width": 4.0, # px, dark outer edge of the target ring
		"special_rim_width": 8.0, # px, candy rim on special tiles
		"special_rim_segments": 16.0, # color segments in the candy rim, cycling the 2 to 256 colors
		"label_fit": 0.88,        # widest tile label as a fraction of the tile side (6 percent padding each side)
		"special_from": 32768.0,  # tiles from this value get the candy rim effect
		"pill_height": 96.0,
		"pill_radius": 48.0,
		"button_radius": 44.0,
		"button_lip": 10.0,
		"dock_height": 208.0,
		"dock_radius": 68.0,
		"card_radius": 60.0,
		"space_xs": 12.0,
		"space_s": 24.0,
		"space_m": 36.0,
		"space_l": 56.0,
		"space_xl": 88.0,
		"touch_min": 132.0,       # smallest touch target side
		# Interface sizes, px
		"booster_icon": 84.0,     # icon inside a booster button
		"active_raise": 6.0,      # how much higher the active booster sits
		"hud_icon": 84.0,         # settings icon in the HUD
		"icon_stroke": 3.5,       # icon stroke on the 24 unit grid
		"button_lip_pressed": 3.0,
		"focus_width": 5.0,
		"focus_gap": 6.0,
		"divider_width": 4.0,
		"toggle_track_w": 140.0,
		"toggle_track_h": 76.0,
		"toggle_knob": 54.0,
		"toggle_knob_lip": 5.0,
	}

	# Motion: springy. Overshoot on arrival, squash on landing, nothing linear.
	motion = {
		"spawn": {"duration": 0.32, "trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT, "from_scale": 0.2, "stagger": 0.035},
		"fall": {"duration": 0.28, "trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT, "squash": 0.12},
		"chain_add": {"duration": 0.10, "trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT, "press_scale": 0.94},
		"merge_travel": {"duration": 0.18, "trans": Tween.TRANS_BACK, "ease": Tween.EASE_IN},
		"merge_pop": {"duration": 0.34, "trans": Tween.TRANS_ELASTIC, "ease": Tween.EASE_OUT, "peak_scale": 1.22},
		"button_press": {"duration": 0.08, "trans": Tween.TRANS_QUAD, "ease": Tween.EASE_OUT, "press_scale": 0.92},
		"button_release": {"duration": 0.30, "trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT},
		"dialog_in": {"duration": 0.42, "trans": Tween.TRANS_BACK, "ease": Tween.EASE_OUT, "from_offset": 240.0},
		"screen_fade": {"duration": 0.22, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_IN_OUT},
		"target_pulse": {"duration": 0.90, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_IN_OUT, "wobble_degrees": 4.0},
		"score_count": {"duration": 0.50, "trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_OUT},
	}

extends "res://tools/directions/shared/direction_tokens.gd"
## Slate: editorial and exact. Small values are dark slate slabs with their
## number set in a bright color; from 128 up a tile lights into a solid block
## of color with a black number, so the big tiles are the ones you see first.
## Sharp corners, hairline rules, left aligned type, fast cuts with no bounce.
##
## Owner: senior-graphic-designer. Artists read these values; they do not
## edit this file. Ask for any value that is missing.


func _init() -> void:
	id = "slate"
	display_name = "Slate"

	# Palette. Text only uses the pairs listed in text_pairs below.
	palette = {
		"bg": Color("#0B0C0E"),             # screen background, near black
		"surface": Color("#181A1C"),        # pressed rows and buttons, chip background
		"rule": Color("#36383B"),           # hairlines between regions and booster columns
		"ink": Color("#F5F2E9"),            # paper: main text, chain line, active booster fill
		"ink_muted": Color("#A1A5AB"),      # labels and secondary numbers
		"ink_dark": Color("#0E0F12"),       # text on paper and on color blocks
		"accent": Color("#FA5D36"),         # signal vermilion: primary button, hint bar, target brackets
		"accent_pressed": Color("#E14D28"),
		"disabled_ink": Color("#7D8085"),   # cost and icon of a booster that cannot be afforded
		"chain": Color("#F5F2E9"),          # chain line, nodes and the frame on chained tiles
		"chain_edge": Color("#0E0F12"),     # thin dark edge around the chain line
		"target": Color("#FA5D36"),         # corner brackets on the targeted tile
	}

	# Tile ramp, value 2 first. One continuous walk round the color wheel.
	# 2 to 64 are slabs (dark fill, bright number in the same hue). From 128
	# the tile becomes a solid color block with a black number. 128K is paper.
	tile_fill = [
		Color("#18460C"), # 2 green slab
		Color("#004447"), # 4 teal slab
		Color("#003C6C"), # 8 blue slab
		Color("#3F2D68"), # 16 indigo slab
		Color("#59224F"), # 32 plum slab
		Color("#641F26"), # 64 oxblood slab
		Color("#FE9975"), # 128 coral
		Color("#FFB66C"), # 256 orange
		Color("#FFDC4F"), # 512 yellow
		Color("#B3EE55"), # 1024 lime
		Color("#52F0BE"), # 2K mint
		Color("#41D9F8"), # 4K cyan
		Color("#95B6FE"), # 8K periwinkle
		Color("#D1A9FF"), # 16K lilac
		Color("#FD95DC"), # 32K pink
		Color("#FFB3B8"), # 64K rose
		Color("#F5F2E9"), # 128K paper
	]
	var dark: Color = Color("#0E0F12")
	tile_ink = [
		Color("#A5EE95"), # 2
		Color("#7AEDF3"), # 4
		Color("#BADBFE"), # 8
		Color("#DAD0FE"), # 16
		Color("#FEC1F0"), # 32
		Color("#FEC8C8"), # 64
		dark, dark, dark, dark, dark, dark, dark, dark, dark, dark, dark,
	]
	beyond_fill = Color("#F5F2E9")
	beyond_ink = dark

	text_pairs = [
		pair("Score on the background", "ink", "bg"),
		pair("Labels and secondary numbers", "ink_muted", "bg"),
		pair("Booster name and cost", "ink", "bg"),
		pair("Booster name and cost, targeting (paper fill)", "ink_dark", "ink"),
		pair("Booster name and cost, disabled", "disabled_ink", "bg"),
		pair("Targeting hint bar", "ink_dark", "accent"),
		pair("Primary button", "ink_dark", "accent"),
		pair("Primary button, pressed", "ink_dark", "accent_pressed"),
		pair("Rows and secondary buttons, pressed", "ink", "surface"),
		pair("Labels on pressed rows and chips", "ink_muted", "surface"),
		pair("Skin chip, selected (paper fill)", "ink_dark", "ink"),
	]

	# Type: grotesk, bold numbers with tight tracking, small labels in
	# tracked capitals. Everything left aligned.
	type_roles = {
		"display": {"size": 184, "weight": 700, "tracking": -6, "case": CASE_NONE}, # score
		"title": {"size": 72, "weight": 700, "tracking": -2, "case": CASE_NONE},    # screen titles
		"body": {"size": 44, "weight": 500, "tracking": 0, "case": CASE_NONE},      # buttons, rows
		"label": {"size": 30, "weight": 600, "tracking": 4, "case": CASE_UPPER},    # labels, costs
		"tile": {"weight": 700, "tracking": -1, "case": CASE_NONE},
	}
	tile_number_scale = PackedFloat32Array([0.40, 0.40, 0.32, 0.25])

	# Shape and layout. Lengths in px on the 1080 px canvas unless noted.
	shape = {
		"board_margin": 44.0,         # screen edge to the outer tiles
		"gap": 10.0,                  # between tiles
		"tile_radius": 6.0,           # px, nearly square
		"number_inset": 0.11,         # fraction of tile side: number sits top left, this far in
		"line_width": 8.0,            # chain line, drawn over tile fills and under numbers
		"line_edge": 3.0,             # dark edge on each side of the chain line
		"node_size": 24.0,            # square node at each chained tile center
		"chain_frame": 6.0,           # paper frame inset on chained tiles
		"target_bracket": 0.30,       # fraction of tile side: arm length of each corner bracket
		"target_bracket_width": 8.0,
		"rule_width": 2.0,            # hairlines
		"special_from": 32768.0,      # tiles from this value get an inner hairline frame
		"special_inset": 0.06,        # fraction of tile side: inset of that frame
		"preview_tile": 112.0,        # side of the preview tile in the header
		"button_radius": 4.0,
		"button_height": 136.0,
		"strip_height": 192.0,        # booster strip, under its hairline
		"row_height": 148.0,          # settings rows
		"space_xs": 8.0,
		"space_s": 20.0,
		"space_m": 40.0,
		"space_l": 64.0,
		"space_xl": 104.0,
		"touch_min": 132.0,           # smallest touch target side
	}

	# Motion: fast, exact cuts. Ease out only, no overshoot, nothing bounces.
	motion = {
		"spawn": {"duration": 0.14, "trans": Tween.TRANS_EXPO, "ease": Tween.EASE_OUT, "from_scale_y": 0.0, "stagger": 0.0},
		"fall": {"duration": 0.16, "trans": Tween.TRANS_QUART, "ease": Tween.EASE_OUT},
		"chain_add": {"duration": 0.06, "trans": Tween.TRANS_LINEAR, "ease": Tween.EASE_IN_OUT},
		"merge_travel": {"duration": 0.12, "trans": Tween.TRANS_QUART, "ease": Tween.EASE_IN},
		"merge_pop": {"duration": 0.16, "trans": Tween.TRANS_EXPO, "ease": Tween.EASE_OUT, "flash": 1.0},
		"button_press": {"duration": 0.04, "trans": Tween.TRANS_LINEAR, "ease": Tween.EASE_IN_OUT},
		"button_release": {"duration": 0.10, "trans": Tween.TRANS_QUART, "ease": Tween.EASE_OUT},
		"dialog_in": {"duration": 0.24, "trans": Tween.TRANS_EXPO, "ease": Tween.EASE_OUT, "wipe": 1.0},
		"screen_fade": {"duration": 0.12, "trans": Tween.TRANS_LINEAR, "ease": Tween.EASE_IN_OUT},
		# Duration 0 means no pulse: in Slate the target brackets hold still.
		"target_pulse": {"duration": 0.0, "trans": Tween.TRANS_LINEAR, "ease": Tween.EASE_IN_OUT},
		"score_count": {"duration": 0.24, "trans": Tween.TRANS_QUART, "ease": Tween.EASE_OUT},
	}

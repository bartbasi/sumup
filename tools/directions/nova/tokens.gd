extends "res://tools/directions/shared/direction_tokens.gd"
## Nova: tiles are stars. Round orbs float on deep space with no tray, and
## their color follows star temperature: small values burn red and orange,
## mid values go white and blue, the biggest become nebula colors. Bigger
## values glow wider. Light, airy type and slow, fluid motion.
##
## Owner: senior-graphic-designer. Artists read these values; they do not
## edit this file. Ask for any value that is missing.


func _init() -> void:
	id = "nova"
	display_name = "Nova"

	# Palette. Text only uses the pairs listed in text_pairs below.
	palette = {
		"bg": Color("#040819"),             # deep space, bottom and edges of the backdrop
		"bg_glow": Color("#181942"),        # lightest point of the backdrop glow, upper center
		"star": Color("#FFFFFF"),           # star dust dots, drawn at star_alpha_max or less
		"surface": Color("#10162F"),        # settings sheet
		"surface_raised": Color("#1F2646"), # chips and rows on the sheet
		"ring": Color("#52628C"),           # outlines of ring buttons and dividers
		"ink": Color("#F7F9FF"),            # main text
		"ink_muted": Color("#ABB7D5"),      # labels and secondary text
		"ink_dark": Color("#060C20"),       # text on bright fills
		"accent": Color("#49EAF2"),         # aurora cyan: primary button, active booster, selected chip
		"accent_pressed": Color("#17D0D8"),
		"accent_violet": Color("#9264EF"),  # second aurora color for gradients and glows, never behind text
		"disabled_ink": Color("#848C9F"),   # cost and icon of a booster that cannot be afforded
		"chain": Color("#FFFFFF"),          # core of the chain beam; its glow takes the orb colors
		"target": Color("#49EAF2"),         # orbit ring on the targeted orb
		"scrim": Color("#040819DB"),        # bg at 86 percent over the board at game over
	}

	# Tile ramp, value 2 first, by star temperature: red, orange, amber, gold,
	# white, then ice, sky and blues, then nebula colors from 2K up.
	tile_fill = [
		Color("#D02D27"), # 2 red dwarf
		Color("#F4741E"), # 4 flame
		Color("#FCAA2B"), # 8 amber
		Color("#F9DF5C"), # 16 gold
		Color("#FDF6D8"), # 32 white star
		Color("#9FE3FE"), # 64 ice
		Color("#40BEFD"), # 128 sky
		Color("#0B66D6"), # 256 azure
		Color("#413DD2"), # 512 indigo
		Color("#7D24D3"), # 1024 violet
		Color("#BD0DB7"), # 2K magenta
		Color("#FE9AC2"), # 4K rose
		Color("#49E9E0"), # 8K aqua
		Color("#007D51"), # 16K emerald
		Color("#84DE70"), # 32K aurora green
		Color("#FFE0AD"), # 64K supernova
		Color("#FBFCFE"), # 128K white hole
	]
	var dark: Color = Color("#060C20")
	var light: Color = Color("#F7F9FF")
	tile_ink = [
		light, dark, dark, dark, dark, dark, dark,
		light, light, light, light,
		dark, dark, light, dark, dark, dark,
	]
	beyond_fill = Color("#FBFCFE")
	beyond_ink = dark

	text_pairs = [
		pair("Score on the lightest part of the backdrop", "ink", "bg_glow"),
		pair("Labels on the lightest part of the backdrop", "ink_muted", "bg_glow"),
		pair("Labels on the darkest part of the backdrop", "ink_muted", "bg"),
		pair("Booster cost", "ink", "bg_glow"),
		pair("Booster cost, targeting", "accent", "bg_glow"),
		pair("Booster cost, disabled", "disabled_ink", "bg_glow"),
		pair("Game over text, worst case over a white hole tile", "ink", "scrim", "tile:131072"),
		pair("Game over labels, worst case over a white hole tile", "ink_muted", "scrim", "tile:131072"),
		pair("Primary button", "ink_dark", "accent"),
		pair("Primary button, pressed", "ink_dark", "accent_pressed"),
		pair("Settings sheet text", "ink", "surface"),
		pair("Settings sheet labels", "ink_muted", "surface"),
		pair("Rows and chips on the sheet", "ink", "surface_raised"),
		pair("Labels on rows and chips", "ink_muted", "surface_raised"),
		pair("Skin chip, selected", "ink_dark", "accent"),
	]

	# Type: light weight for the big numbers, semibold on tiles, lowercase
	# labels with open tracking.
	type_roles = {
		"display": {"size": 160, "weight": 300, "tracking": 0, "case": CASE_NONE}, # score
		"title": {"size": 68, "weight": 300, "tracking": 1, "case": CASE_NONE},    # titles
		"body": {"size": 44, "weight": 400, "tracking": 0, "case": CASE_NONE},     # buttons, rows
		"label": {"size": 32, "weight": 400, "tracking": 3, "case": CASE_LOWER},   # labels, costs
		"tile": {"weight": 600, "tracking": 0, "case": CASE_NONE},
	}
	tile_number_scale = PackedFloat32Array([0.46, 0.42, 0.37, 0.315])

	# Shape and layout. Lengths in px on the 1080 px canvas unless noted.
	shape = {
		"board_margin": 44.0,       # screen edge to the outer cell edge
		"orb_scale": 0.88,          # orb diameter as a fraction of the cell pitch
		"rim_width": 4.0,           # lighter rim on every orb
		"rim_lighten": 0.35,        # rim color = fill.lightened(rim_lighten)
		"glow_alpha_low": 0.10,     # glow alpha at value 2
		"glow_alpha_high": 0.55,    # glow alpha at 131072, linear in ramp index between
		"glow_spread_low": 1.12,    # glow radius as a multiple of the orb radius at value 2
		"glow_spread_high": 1.55,   # and at 131072
		"beam_width": 12.0,         # chain beam core, drawn under the orbs
		"beam_glow_width": 44.0,
		"beam_glow_alpha": 0.28,
		"chain_rim_width": 8.0,     # rim on chained orbs
		"orbit_offset": 0.10,       # target orbit radius = orb radius times (1 + orbit_offset)
		"orbit_width": 4.0,
		"preview_scale": 0.54,      # preview orb, fraction of orb diameter. It sits on the gap crossing
		                            # at the top left of the last chain orb (top right in column 0),
		                            # clear of the four orbs around it.
		"label_fit": 0.82,          # widest tile label as a fraction of the orb diameter
		"special_from": 32768.0,    # orbs from this value get corona rays
		"ray_count": 12.0,
		"ray_inner": 1.08,          # rays start this many orb radii from the center
		"ray_outer": 1.24,          # and end here, short of the neighbor orbs at orb_scale 0.88
		"ray_width": 3.0,           # px
		"spawn_bloom": 0.6,         # extra glow at the middle of the spawn
		"chain_glow": 1.4,          # glow on chained orbs, 1 is the resting glow
		"target_glow": 1.5,         # glow on the targeted orb
		"orbit_dashes": 24.0,       # dashes in the target orbit ring
		"orbit_dash_fill": 0.55,    # share of each dash period that is drawn
		"orbit_breath": 0.05,       # orbit radius grows by this fraction at the top of a breath
		"orbit_turn": 0.08,         # turns the orbit makes per target_pulse loop
		"ring_button": 148.0,       # booster ring button diameter
		"ring_width": 3.0,
		"sheet_radius": 64.0,
		"star_count": 70.0,         # star dust dots on the backdrop, fixed seed
		"star_alpha_max": 0.35,
		"star_alpha_min": 0.08,
		"star_size_min": 1.5,       # px, star dot diameter
		"star_size_max": 3.5,
		"star_seed": 20261010.0,    # fixed seed, so every capture looks the same
		"star_clearance": 24.0,     # px, no star within this distance of a clear rect (text)
		"backdrop_glow_x": 0.5,     # glow center as a share of the rect
		"backdrop_glow_y": 0.26,
		"backdrop_glow_radius": 0.95, # glow radius as a share of the rect width
		"space_xs": 12.0,
		"space_s": 28.0,
		"space_m": 44.0,
		"space_l": 72.0,
		"space_xl": 112.0,
		"touch_min": 132.0,         # smallest touch target side
		# Interface sizes, px
		"booster_icon": 88.0,       # icon inside a ring button
		"hud_ring": 96.0,           # settings ring in the HUD
		"hud_icon": 72.0,
		"icon_stroke": 1.5,         # icon stroke on the 24 unit grid
		"icon_spark": 1.0,          # spark dot radius on the 24 unit grid
		"icon_fit": 0.86,           # share of the icon size the grid is fitted to
		"icon_glow_alpha": 0.4,     # glow behind an active icon
		"ring_glow_spread": 1.45,   # active ring glow radius, multiple of the ring radius
		"ring_glow_alpha": 0.75,
		"disabled_ring_alpha": 0.4,
		"focus_gap": 6.0,
		"divider_width": 2.0,
		"toggle_track_w": 124.0,
		"toggle_track_h": 64.0,
		"toggle_knob": 40.0,
		"toggle_glow_spread": 1.9,
		"toggle_glow_alpha": 0.6,
	}

	# Motion: fluid and calm. Sine and cubic curves, longer glides, light blooms.
	motion = {
		"spawn": {"duration": 0.38, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_OUT, "from_scale": 0.55, "from_alpha": 0.0, "stagger": 0.05},
		"fall": {"duration": 0.30, "trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_OUT},
		"chain_add": {"duration": 0.16, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_OUT},
		"merge_travel": {"duration": 0.28, "trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_IN_OUT},
		"merge_pop": {"duration": 0.48, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_OUT, "peak_glow": 1.8},
		"button_press": {"duration": 0.10, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_OUT, "press_scale": 0.96},
		"button_release": {"duration": 0.24, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_OUT},
		"dialog_in": {"duration": 0.50, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_OUT, "from_alpha": 0.0, "from_scale": 0.96},
		"screen_fade": {"duration": 0.40, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_IN_OUT},
		"target_pulse": {"duration": 1.60, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_IN_OUT, "alpha_low": 0.45},
		"score_count": {"duration": 0.60, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_OUT},
	}

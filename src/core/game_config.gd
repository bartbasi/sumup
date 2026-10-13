class_name GameConfig extends RefCounted
## Every tunable from GDD section 18 that the rules read. Tests make their own
## instance to override values (TH4). Everything that needs a constant takes a
## GameConfig, so nothing reads these numbers from anywhere else.

var columns: int = 5                    # BOARD_COLUMNS
var rows: int = 8                       # BOARD_ROWS
var min_chain_length: int = 2           # MIN_CHAIN_LENGTH
var join_radius: float = 0.42           # JOIN_RADIUS, share of the tile pitch (D-07)
var spawn_window_size: int = 4          # SPAWN_WINDOW_SIZE
var spawn_weights: PackedInt32Array = PackedInt32Array([40, 30, 20, 10])   # smallest value first, total 100
var spawn_top_min: int = 16             # SPAWN_TOP_MIN
var spawn_top_divisor: int = 64         # SPAWN_TOP_DIVISOR
var start_board_max_attempts: int = 100 # START_BOARD_MAX_ATTEMPTS
var shuffle_max_attempts: int = 100     # SHUFFLE_MAX_ATTEMPTS
var cost_basis_min: int = 128           # COST_BASIS_MIN
## Each cost is B shifted by this many bits: 0 is B, 1 is 2B, -1 is B/2. Keeps every cost a power of two.
var cost_shift: Dictionary[StringName, int] = {&"hammer": 0, &"swap": 0, &"shuffle": 0, &"double": 1, &"undo": -1}
var label_full_max: int = 1024          # LABEL_FULL_MAX
var label_step: int = 1024              # LABEL_STEP
var label_suffixes: PackedStringArray = PackedStringArray(["K", "M", "B", "T"])   # LABEL_SUFFIXES
var stars_per_free_booster: int = 3     # STARS_PER_FREE_BOOSTER (D-46)


## Number of cells on the board: columns times rows.
func cell_count() -> int:
	return columns * rows

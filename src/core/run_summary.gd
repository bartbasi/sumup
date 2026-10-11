class_name RunSummary extends RefCounted
## What the end of run screen shows (GDD 12.3). GameSession fills it in. It
## lives in core so the ui area depends on core only.

var final_score: int
var best_score: int
var best_tile: int
var run_highest: int
var new_best_score: bool  # this run set the Best Score (the New best badge)
var no_moves_left: bool   # the run ended because nothing was usable (12.2 step 3)

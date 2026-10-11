class_name BoosterStatus extends RefCounted
## One booster as the interface shows it. GameSession fills it in. It lives in
## core so the design and ui areas depend on core only.

enum Usability { USABLE, CANNOT_AFFORD, NO_SNAPSHOT }

var id: StringName
var cost: int
var usable: bool
var reason: Usability
var active: bool          # this booster is in targeting mode
var suggested: bool       # marked as the suggested rescue in the no moves offer (D-42)

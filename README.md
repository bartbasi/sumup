# numbersgame

A number merge puzzle game for Android, built with Godot 4. Endless mode, boosters paid with score, built in skins, fully offline.

## Engine

- Godot 4.7.2 stable, exact build `4.7.2.stable.official.ed1daf0bf`
- Compatibility renderer, GDScript only (statically typed)

## Run the tests

From the repo root, in a Bash shell:

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

The first command builds Godot's class cache and is only needed after a fresh clone. The test run exits with code 0 when every test passes.

Android build and install steps will be added in Phase 5.

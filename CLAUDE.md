# numbersgame: standing rules

numbersgame is a number merge puzzle game (same core mechanic as "2248") for Android, built in Godot 4. Bart Basi owns the project. The main Claude Code session is the Development Manager (DM): it plans, launches every agent, integrates, commits, and is the only one who talks to Bart. The full kickoff brief is in docs/BRIEF.md. Read it before starting any phase.

## Fixed decisions (ask Bart before revisiting any of these)

- Engine: Godot 4.7.2 stable (`4.7.2.stable.official.ed1daf0bf`), Compatibility renderer.
- Language: GDScript, statically typed everywhere (typed variables, parameters and return values). No C#, no GDExtension. project.godot treats untyped declarations as errors.
- Platform for v1: Android, portrait only. Develop and iterate in the Godot editor on Windows.
- Repo: github.com/bartbasi/numbersgame, private. Only the DM pushes.
- Assets: nothing paid, nothing third party. Every visual and every sound is made in code (StyleBoxFlat, Theme resources, `_draw()`, shaders, Tweens, AudioStreamWAV filled by code). No image files, no audio files, no asset store downloads, no addons. The one exception is the Outfit font (see Bart's decisions below).
- Network: none. No accounts, ads, analytics or leaderboards. Release builds request no Android permissions.
- Skins: built in only for v1. No import of any kind.
- Level goals: not in v1. Keep game rules separate from UI so they can be added later, but build nothing for them.
- Boosters are paid from the current run's score. Score can never go below zero.
- Out of scope: level goals, player-made skins, file import, anything online, ads, in-app purchases, iOS, Windows and Linux builds, store listings, release signing keys, Play Console work.

## Ownership

Each agent edits only what it owns, plus any path its task brief from the DM explicitly grants for that task. Godot's `.uid` files belong to whoever owns the file next to them.

| Path | Owner |
|---|---|
| CLAUDE.md, docs/BRIEF.md, docs/ARCHITECTURE.md, .claude/agents/, .gitattributes | DM |
| scenes/main.tscn, tests/run_tests.gd, tests/base_test.gd | DM |
| README.md, project.godot, export_presets.cfg, .gitignore, scripts/ (build and install scripts) | platform-dev |
| docs/GDD.md (rules, balance, acceptance test list) | lead-game-designer |
| docs/DESIGN_SYSTEM.md, docs/ASSETS.md, docs/design/, tools/ | senior-graphic-designer |
| docs/reviews/qa-*.md | qa-reviewer |
| docs/reviews/security-*.md | security-reviewer |
| src/core/, tests/core/ | core-logic-dev |
| src/board/, scenes/board/, tests/board/ | board-input-dev |
| src/boosters/, scenes/boosters/, tests/boosters/ | boosters-dev |
| src/ui/, src/save/, scenes/ui/, tests/ui/, tests/save/ | ui-systems-dev |
| src/audio/, scenes/audio/, tests/audio/ | audio-dev |
| src/skins/, scenes/skins/, tests/skins/ | tile-board-artist |
| src/design/, scenes/design/, tests/design/ | ui-motion-artist |

Autoload and input map entries in project.godot are added by the DM during integration, so two agents never edit that file at once.

## Decisions from Bart since the brief

- 2026-10-10: Skin Resources. The senior-graphic-designer specifies every value in docs/DESIGN_SYSTEM.md. The tile-board-artist writes the Resource files in src/skins/. The senior-graphic-designer reviews them.
- 2026-10-10: Android launcher icon. It is drawn in code by a tool script in tools/ that saves the icon image the export uses, and it is logged in docs/ASSETS.md. No hand made or downloaded image.
- 2026-10-10: Commits are authored as the bartbasi GitHub account (set in this repo's git config, not globally).
- 2026-10-10, Hard Stop 1: Gumdrop is the default look. Slate and Nova ship as built in skins the player can switch to in Settings.
- 2026-10-10: A skin switches the whole look: tiles, colors, chain line, effects, motion, HUD, booster bar, icons, buttons, background and font, so the play screen matches that direction's Phase 1 screens. Menus and dialogs (out of moves offer, end of run, settings, pause, main menu) keep one shared arrangement, drawn in each skin's style.
- 2026-10-10, Hard Stop 1: Fonts. Gumdrop and Nova use Outfit (SIL Open Font License 1.1). Slate uses the system font (Roboto on Android). `Outfit[wght].ttf` and its `OFL.txt` are the only third party files allowed in the repo, unmodified, side by side, and logged in docs/ASSETS.md.
- 2026-10-10, Hard Stop 1: Best Score updates live (GDD D-16). All GDD rules are approved as recommended.
- 2026-10-10, Hard Stop 1: Three additions to v1 scope: small tiles are cleared automatically as the game moves up, as in 2248; tiles that could join next are highlighted while dragging; the end of run screen shows this run's highest tile. Not added: a confirm step before Shuffle and Undo.
- 2026-10-10: Bart approved creating the private GitHub repo bartbasi/numbersgame and pushing (Hard Stop 2 cleared early).

## Rules for every session and agent

- docs/ARCHITECTURE.md (written in Phase 2) is the contract. Build against it. If you need the contract or another area's code changed, stop and ask the DM. Never edit another area's files.
- Agents never commit. The DM commits after each integration step, once tests pass.
- Keep it simple. No features, settings or abstractions beyond the brief. Extra ideas go to the DM as suggestions for Bart.
- Priority for every decision and fix: security and bugs first, then fun and polish.
- No em dashes and no double hyphens in prose: docs, UI text, code comments, commit messages. Write plainly, like a person. Command line flags inside code formatting are fine.
- If anything is unclear, conflicts, or would force a guess, stop and ask. Do not pick an interpretation silently.
- Hard stops: Hard Stop 1 and Hard Stop 2 are both cleared. Ask Bart before any store work, release signing, or anything else outside the brief.
- Every agent finishes with a short report: what changed (file list), how it was proven (command and result, screenshot path, or test names), open questions, and any contract change requests.

## Commands

Run Godot commands from the repo root in the Bash tool.

```bash
godot --headless --path . --import                            # build the class cache (fresh clone, or after adding a class_name)
godot --headless --path . --quit                              # project opens and runs
godot --headless --path . --script res://tests/run_tests.gd   # all tests; exit code 0 means every test passed
```

## Writing tests

- Put tests in `tests/<area>/test_*.gd`. Each file starts with `extends "res://tests/base_test.gd"`.
- Every method named `test_*` runs on a fresh instance. Optional hooks: `before_each()`, `after_each()`.
- Helpers: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_near`, `fail`.
- A script error raised while a test runs (a null access, for example) counts as a failure.
- Tests are synchronous. Seed every RandomNumberGenerator so results repeat.

## Environment notes (this Windows machine)

- `godot` on PATH is a WinGet link to the main Godot 4.7.2 exe. It works from Bash with real exit codes. In PowerShell the same exe does not wait or return an exit code unless its output is piped, so prefer Bash.
- Do not use `godot_console.exe`. It fails with "CreateProcess failed, error 193" because a stray installer log file named `C:\Users\Bart` breaks the wrapper's unquoted path. Bart wants that file left alone: never move, rename or delete it.
- Android SDK: `C:\Android\Sdk`. adb is at `C:\Android\Sdk\platform-tools\adb.exe` and is not on PATH. JDK 17 (Temurin) is on PATH. The Android debug keystore lives outside the repo in Godot's editor settings folder.
- docs/ has a `.gdignore`, so Godot never imports the design screenshots into the game.
- Pushing (DM only): git's credential manager has no GitHub login here, so push through the gh login without changing git config: `git -c credential.helper= -c "credential.helper=!gh auth git-credential" push origin main`.
- Public classes in src/ use `class_name` (names fixed in docs/ARCHITECTURE.md). After adding one, run `godot --headless --path . --import`. If several agents import at once and you then see "could not find type" errors, import again. tools/ code uses preload and adds no class names.

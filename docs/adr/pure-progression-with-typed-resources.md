---
date: 2026-11-16
status: accepted
---

# Pure progression with typed resources

## Context

Walk must advance through 248 sights while purchases spend only the available steps.
Rendering coordinates can't represent the route's large distances.
The approved plan selects Godot 4.7.2, typed GDScript, and separate progression rules.

## Decision

Keep progression in pure functions over GameState and describe chapters, regions, sights, and upgrades with typed Resource classes.
Track lifetime distance and the distance since a gate opened in distinct fields.
Serialize integers as decimal strings because [Godot JSON](https://docs.godotengine.org/en/4.7/classes/class_json.html) uses floating-point numbers.

## Alternatives

Scene-owned progression would reduce the initial class count but couple route tests to rendering and input.
Deriving progress from scrolling would make screen dimensions affect travel and lose precision on large distances.

## Consequences

Adapters handle input, elapsed time, files, and audio while the core returns the resulting state.
Each save must validate its fields and progression invariants before constructing GameState.
Reconsider the in-memory snapshot approach if the game needs concurrent simulation.

## Confirmation

The approved plan accepts the separation.
Walking, upgrade, gate, recovery, and complete-route tests check the resulting behavior.

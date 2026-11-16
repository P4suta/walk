# Development

Install [mise](https://mise.jdx.dev/getting-started.html), then run the commands from the extracted project directory.
The project pins Godot 4.7.2, gdtoolkit 4.5.0, Python 3.14.10, uv 0.13.8, and Rust 1.99.0.
The project stores Godot Unit Test (GUT) 9.7.1 in `addons/gut` with its license.

```sh
mise trust
mise install godot rust python uv pipx:gdtoolkit
mise run editor
```

`project.godot` opens the editable project.
The game uses typed GDScript and the Compatibility renderer.
`data/route.tres` links editable `ChapterDef`, `RegionDef`, and `SightDef` resources.
`data/upgrades.tres` contains the upgrade prices and effects.
The landscape JSON files preserve the source design's individual asset positions and dimensions.

## Checks

Run the same local checks used by the pull request workflow.

```sh
mise run check
```

The command checks Rust formatting, Clippy, tool tests, GDScript formatting, lint, engine compilation, game tests, and compiler rejection fixtures.
The engine refuses missing type annotations and incompatible types.
The content tests reject missing sights, missing artwork, invalid dimensions, and invalid landscape data.
The persistence tests exercise interrupted writes, corrupted primary files, backup recovery, and integer precision.
The complete-route test uses the normal walking, upgrade, arrival, and gate rules through all 248 sights.

Use `mise run format` to format GDScript.
Run `mise run typecheck` or `mise run test` for a focused check.
The Rust helper treats engine error diagnostics as failures even when the editor returns a successful exit status.

## Desktop packages

Install the official Godot 4.7.2 export templates through Godot's Export Template Manager.
Run exports on macOS to build all three packages, including the universal macOS app.
The archive command uses BSD tar.

```sh
mise run export
```

The `build` directory receives the editable project archive and the Windows, macOS, and Linux packages.
Each desktop package contains launch instructions and third-party licenses.
The export command runs the complete local check before exporting.

Run an exported executable with `-- --smoke-test` to check input, settings, saves, audio, the complete route, continued play, and normal exit.
The smoke test uses a dedicated save filename and leaves regular progress untouched.
The smoke test requires an active audio driver.
Add `--capture-gallery` to save rendered region and panel images.
Native operating-system smoke tests use the exported packages.
The routine workflow runs on Ubuntu 24.04.
Package preparation includes checks on the other desktop systems.

## Progression and presentation

The pure rules copy `GameState` before changing a value.
Scene input, clocks, files, and audio stay in adapters.
Step counters use signed 64-bit integers and saturate at 9,223,372,036,854,775,807.
Distance uses 64-bit floating-point meters and never depends on scrolling coordinates.
The distance for each journey part starts when its gate opens.
Waiting at a gate doesn't skip later sights.

The [resolution guidance](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html) supports the 320 by 180 viewport with integer scaling.
The window opens at 960 by 540 and doesn't shrink below 640 by 360.
The [input event flow](https://docs.godotengine.org/en/4.7/tutorials/inputs/inputevent.html#how-does-it-work) lets controls consume an action before walking handles it.
The [font guidance](https://docs.godotengine.org/en/4.7/tutorials/ui/gui_using_fonts.html#subpixel-positioning) supports turning subpixel positioning off for the pixel font.
Independent audio controls adopt the recommendation in [Xbox Accessibility Guideline 105](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/105).
The supplied pixel art game design governs the interface.
Browser typography and browser target-size rules don't apply to the desktop viewport.

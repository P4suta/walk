# Contributing

Read the [playing instructions](docs/playing.md) and [development guide](docs/development.md) before changing the game.
Open an issue that describes the intended player behavior, and keep each pull request within that scope.

Install the pinned tools from `mise.toml` and run `mise run check` before submitting a change.
Run `mise run secrets` from a Git checkout to check committed source for secrets.
Use signed commits and [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
The `Check` workflow must pass before merging.

If Git has no shared `core.hooksPath`, run `mise x -- lefthook install` to install the local hooks.
Keep an existing shared hook dispatcher and let it run the repository's Lefthook configuration.
The hooks check formatting, lint, secrets, types, and game behavior through the maintained project commands.

Describe the changed behavior and the checks that passed in the pull request.
Include a screenshot when the change affects a screen.
Keep original third-party files unchanged, and update their notices when importing an upstream version.
The [release guide](docs/releases.md) describes the separate binary publication process.

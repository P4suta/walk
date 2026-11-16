# Binary releases

Source updates don't publish binaries automatically.
Prepare desktop packages from one reviewed commit using the [development guide](development.md).
Run the complete local check and the native package smoke test on Windows, macOS, and Linux for that revision.

Create a draft GitHub release for the verified revision.
Complete platform signing, notarization where applicable, native verification, checksums, dependency inventory, and build provenance before publishing.
Attach the final packages, license notices, and verification artifacts to the draft.
Check that the tag, source revision, and uploaded bytes identify the same candidate.

Publish the completed draft once with explicit release authorization.
[Immutable Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases#immutable-releases) protect published assets and tags.
Correct a published defect with another release and preserve the existing downloads.

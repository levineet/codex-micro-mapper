# Releasing Codex Micro Mapper

The initial binary distribution targets **Apple silicon (arm64)** and macOS 14 or later. Intel and universal binaries are not part of this release. Build with Xcode 26 or later; [Xcode 26 includes Swift 6.2](https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes).

## Build a candidate

1. Update `CFBundleShortVersionString`, `CFBundleVersion` and `CodexMicroMapperReleaseDate` in `Info.plist`, and update `CHANGELOG.md`.
2. Run the tests and build the archive from the repository root:

   ```bash
   swift test --disable-sandbox
   bash scripts/build-app.sh
   ```

3. Inspect `outputs/Codex Micro Mapper.zip`. The build script verifies the signed app before packaging and again after extracting the ZIP. It does not install or launch the app.
4. Quit Mapper, then install a candidate locally with `bash scripts/install-app.sh`. The installer verifies and preserves the incoming signature; it never replaces a Developer ID signature with ad-hoc signing. It refuses to replace a running Mapper, keeps the previous app until verification passes, and leaves user settings in place.
5. Check both languages, missing and granted permissions, reconnect/wake behavior, key recording and all six hardware positions. Verify ACT12 still deletes only the exact selected `:yolo:` placeholder and abandons the action if focus changes.

## Keep build paths neutral

Swift Package Manager's generated `Bundle.module` accessor contains an absolute fallback path to its resource bundle. A release built in a personal checkout can otherwise embed a local username in the executable.

`build-app.sh` therefore defaults to a fresh scratch directory under `/private/tmp`, maps source paths in compiler debug information to `/src/codex-micro-mapper`, and bundles all resources inside the app. The temporary fallback directory is not required at runtime.

To reuse a scratch directory, choose a neutral absolute path that belongs to this project:

```bash
CODEX_MICRO_MAPPER_BUILD_PATH=/private/tmp/codex-micro-mapper-release-build \
  bash scripts/build-app.sh
```

Do not point this variable into a home directory when preparing a public binary. For a final release, inspect the executable and archive for personal paths, check resource loading after the build directory is removed, and distribute the ZIP rather than a File Provider-managed `.app` folder. The archive avoids Finder metadata that can invalidate bundle verification.

## Signing and notarization

Local and CI builds are **ad-hoc signed and not notarized** by default. This signature verifies bundle integrity; it does not identify a trusted publisher to Gatekeeper. Label such downloads accordingly. The installer does not remove quarantine or change Gatekeeper settings.

For public distribution, use a consistent Developer ID Application certificate and notarize the build. Set the signing identity only in your local release environment:

```bash
CODEX_MICRO_MAPPER_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
  bash scripts/build-app.sh
```

The build enables the hardened runtime and adds a secure timestamp for a named identity. Submit the ZIP using `xcrun notarytool` with a locally stored credential profile, check the result, staple the ticket to the extracted `.app`, then create and verify the final ZIP. Do not re-sign the app after notarization. Keep certificates and credentials out of the repository.

Follow Apple's [Developer ID guidance](https://developer.apple.com/developer-id/) and [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow). Test the final download with Gatekeeper enabled on a separate Mac or test account. Signature or identity changes can affect macOS privacy grants; never assume a new binary inherits permissions merely because its bundle ID is unchanged.

## CI and publication

The workflow runs tests and produces an ad-hoc signed arm64 ZIP for pushes, pull requests and manual runs. It uses no signing secrets, grants only `contents: read`, and **does not create tags or publish GitHub Releases**. Create a release manually only after reviewing the candidate and its checks.

The runner is `macos-26`, using `/Applications/Xcode_26.0.1.app/Contents/Developer` to exercise the Swift 6.2 baseline. Confirm availability against GitHub's [runner labels](https://github.com/actions/runner-images#available-images) and [macOS 26 arm64 image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md) when updating the workflow.

Actions are pinned to official release commits:

- [actions/checkout v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1): `3d3c42e5aac5ba805825da76410c181273ba90b1`
- [actions/upload-artifact v7.0.1](https://github.com/actions/upload-artifact/releases/tag/v7.0.1): `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`

Dependabot proposes action updates weekly. Review the upstream release and commit before merging an update. CI artifacts expire after 14 days; a reviewed release archive should be uploaded separately when the maintainer publishes a release.

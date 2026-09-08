#!/bin/bash
set -euo pipefail

# The first distribution targets Apple silicon. Keep the SwiftPM scratch path
# outside a user's home directory: Bundle.module embeds a fallback build path.
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_output="$task_root/outputs/Codex Micro Mapper.zip"
task_stage="$(mktemp -d /private/tmp/codex-micro-mapper-build.XXXXXX)"
task_build_path="${CODEX_MICRO_MAPPER_BUILD_PATH:-$task_stage/swift-build}"
task_app="$task_stage/Codex Micro Mapper.app"
task_resources="$task_app/Contents/Resources"
task_identity="${CODEX_MICRO_MAPPER_SIGNING_IDENTITY:--}"

cleanup() {
    rm -rf "$task_stage"
}
trap cleanup EXIT

swift build --package-path "$task_root" --scratch-path "$task_build_path" \
    --arch arm64 -c release --product CodexMicroMapper \
    -Xswiftc -file-prefix-map -Xswiftc "$task_root=/src/codex-micro-mapper"
task_bin_dir="$(swift build --package-path "$task_root" --scratch-path "$task_build_path" \
    --arch arm64 -c release --show-bin-path)"

mkdir -p "$task_app/Contents/MacOS" "$task_resources" "$task_root/outputs"
cp "$task_bin_dir/CodexMicroMapper" "$task_app/Contents/MacOS/CodexMicroMapper"
cp "$task_root/Info.plist" "$task_app/Contents/Info.plist"
cp "$task_root/Sources/CodexMicroMapperApp/Resources/CodexMicroMapping.icns" "$task_resources/CodexMicroMapping.icns"

for task_bundle in "$task_bin_dir"/*.bundle; do
    [[ -d "$task_bundle" ]] || continue
    cp -R "$task_bundle" "$task_resources/"
done

# Clean only our newly built, temporary bundle before applying its signature.
# No installed app or system Gatekeeper preference is modified here.
xattr -cr "$task_app"
task_sign_options=(--force --deep --options runtime --sign "$task_identity")
if [[ "$task_identity" != "-" ]]; then
    task_sign_options+=(--timestamp)
fi
codesign "${task_sign_options[@]}" "$task_app"
codesign --verify --deep --strict --verbose=2 "$task_app"
plutil -lint "$task_app/Contents/Info.plist"

# Archive outside File Provider storage before copying the result into outputs.
# Verify a clean extraction, preserving the signature created above.
task_archive="$task_stage/Codex Micro Mapper.zip"
ditto -c -k --keepParent --norsrc "$task_app" "$task_archive"
task_verify_dir="$task_stage/verify"
mkdir -p "$task_verify_dir"
ditto -x -k "$task_archive" "$task_verify_dir"
codesign --verify --deep --strict --verbose=2 "$task_verify_dir/Codex Micro Mapper.app"
cp "$task_archive" "$task_output"

printf '%s\n' "$task_output"

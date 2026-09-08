#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_archive="$task_root/outputs/Codex Micro Mapper.zip"
task_stage="$(mktemp -d /private/tmp/codex-micro-mapper-install.XXXXXX)"
task_app="$task_stage/Codex Micro Mapper.app"
task_destination="/Applications/Codex Micro Mapper.app"
task_install_stage=""
task_previous=""
task_new_installed=false
task_install_complete=false

cleanup() {
    if [[ "$task_install_complete" != true ]]; then
        if [[ "$task_new_installed" == true ]]; then
            rm -rf "$task_destination"
        fi
        if [[ -n "$task_previous" && -d "$task_previous" ]]; then
            mv "$task_previous" "$task_destination"
        fi
    fi
    if [[ -n "$task_install_stage" ]]; then
        rm -rf "$task_install_stage"
    fi
    rm -rf "$task_stage"
}
trap cleanup EXIT

# Verify the incoming app before touching the installed copy. Do not clear
# quarantine or replace a Developer ID signature with an ad-hoc signature.
ditto -x -k "$task_archive" "$task_stage"
codesign --verify --deep --strict --verbose=2 "$task_app"
plutil -lint "$task_app/Contents/Info.plist"
if [[ "$(plutil -extract CFBundleIdentifier raw -o - "$task_app/Contents/Info.plist")" != "local.codex.micro.mapper" ]]; then
    printf '%s\n' 'The archive is not a Codex Micro Mapper application.' >&2
    exit 1
fi

if pgrep -f '^/Applications/Codex Micro Mapper\.app/Contents/MacOS/CodexMicroMapper([[:space:]]|$)' >/dev/null; then
    printf '%s\n' 'Quit Codex Micro Mapper before installing to keep any unfinished edits.' >&2
    exit 1
fi

# Prepare and verify on the destination volume before replacing the old app.
# The temporary previous copy is restored if installation verification fails.
task_install_stage="$(mktemp -d /Applications/.codex-micro-mapper-install.XXXXXX)"
task_prepared="$task_install_stage/Codex Micro Mapper.app"
task_previous="$task_install_stage/previous.app"
ditto "$task_app" "$task_prepared"
codesign --verify --deep --strict --verbose=2 "$task_prepared"
if [[ -e "$task_destination" ]]; then
    mv "$task_destination" "$task_previous"
fi
mv "$task_prepared" "$task_destination"
task_new_installed=true
codesign --verify --deep --strict --verbose=2 "$task_destination"
plutil -lint "$task_destination/Contents/Info.plist"
task_install_complete=true

printf '%s\n' "$task_destination"

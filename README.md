<img src="docs/images/app-icon.png" width="80" alt="Codex Micro Mapper icon">

# Codex Micro Mapper

[简体中文](README.zh-CN.md) · English

A native macOS menu-bar app that maps **Work Louder Codex Micro** keys to keyboard shortcuts and app controls.

macOS 14+ · Swift 6.2+ · Local processing · No analytics

## Why it exists

The keys on a small macro keyboard should do the things you use every day. Codex Micro Mapper lets you assign a shortcut, bring an app forward, hide it when it is already in front, or send a shortcut after activating it—all from a small native settings window.

It responds to the device's ACT06–ACT12 identifiers. It does not modify Codex Micro firmware or another app's internal shortcuts. It is an independent community project, not an official Work Louder or OpenAI product.

![Mappings interface, shown in Simplified Chinese](docs/images/mappings-zh.jpg)

## What you can do

- Record a shortcut or choose a single key, including Home and **Left/Right Option**.
- Open or activate an app; choose whether another press hides it or keeps it visible.
- Send an additional shortcut after the app is confirmed to be in front.
- Enable or pause each mapping, or clear all six mappings.
- Use English or Simplified Chinese, and optionally launch at login.

The wide bottom key's two switches, ACT10 and ACT11, behave as one key. ACT12 has a guarded path for the device's `:yolo:` placeholder: it deletes only an exact match and cancels if focus changes.

## Privacy, in plain language

**There is no background typing log, analytics SDK, telemetry upload, or backend connection.** The app does not collect a history of what you type.

There are two deliberate, limited input operations:

1. When you click **Record Shortcut**, a temporary, session-wide macOS event tap reads key codes and modifiers so it can capture the shortcut. It also intercepts those events to reduce conflicts with other hotkeys. Recording ends when completed or canceled; cleanup can briefly wait for held keys to be released.
2. When you use ACT12's guarded shortcut, Accessibility reads the current focus and selected text to check for `:yolo:`. That text is not stored in the mapping or diagnostic log.

Normal mapping listens to reports from the matching Codex Micro device. The app stores mappings and preferences locally and does not upload them. Diagnostics are kept in memory and copied only when you choose **Copy**. macOS permissions are broader than these particular uses; granting a permission is not proof of how any app uses it.

Read the [full privacy explanation and source pointers](PRIVACY.md). Apps, URLs and macOS Shortcuts invoked by a mapping can have their own network activity and privacy policies.

## Get started

### Requirements

- macOS 14 or later and a Work Louder Codex Micro.
- Codex installed to configure the device's key layout.
- Input Monitoring and Accessibility permissions for this app.
- For a source build: Xcode 26 with Swift 6.2 or newer.

The initial downloadable build targets **Apple Silicon (arm64)**. It is locally signed, not Developer ID signed or notarized. Intel binaries and physical-device behavior beyond the documented checks are not claimed as verified. You can inspect the source and build it yourself.

### Configure the device once

In Codex, go to **Settings → Codex Micro → Layout** and use these settings:

| Physical key | Codex setting | Hardware identifier |
| --- | --- | --- |
| Lower row, first from left | Empty 1 | ACT06 |
| Lower row, second | Empty 2 | ACT07 |
| Lower row, third | Empty 3 | ACT08 |
| Lower row, fourth | Empty 4 | ACT09 |
| Bottom wide key | Empty 5 | ACT10 + ACT11 |
| Bottom-right key | Yolo | ACT12 |

Open Mapper, grant the requested permissions, then click a key in **Mappings** to edit it. Quit the older `Codex Micro Mapping.app` if it is running; two helpers should not listen to the device at once. Mapper detects that conflict and waits for you to resolve it.

### Initial examples

The first launch includes examples: Command-N, Codex, ChatGPT, Chrome, Home, and guarded Return. They are editable examples, not required integrations. **General → Clear key mappings** makes all six keys unassigned. Existing saved mappings are preserved on upgrade.

### Build and install

```bash
git clone https://github.com/levineet/codex-micro-mapper.git
cd codex-micro-mapper
swift test --disable-sandbox
bash scripts/build-app.sh
bash scripts/install-app.sh
```

The build creates `outputs/Codex Micro Mapper.zip`. Quit Mapper before installing. The installer replaces `/Applications/Codex Micro Mapper.app` and leaves your mapping file in place. It preserves the archive's signature. No third-party Swift packages are required.

For downloadable builds, use only the repository's [Releases](https://github.com/levineet/codex-micro-mapper/releases) and verify the provided SHA-256 checksum. Signing limitations and release steps are in [RELEASING.md](docs/RELEASING.md).

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Keys do nothing | Device connection, Codex key layout, Input Monitoring, and the mapping enable switches |
| A shortcut cannot be recorded or sent | Accessibility and input permissions; try the manual key menu |
| A permission was enabled but still appears required | Follow macOS's own instructions; some changes or a rebuilt signature require quitting and reopening the app or reauthorizing it |
| An app does not respond to a shortcut | Check that app's own shortcut settings and whether it supports a global hotkey |
| The old helper is detected | Quit `Codex Micro Mapping.app`; Mapper will resume listening when the conflict clears |
| ACT12 leaves the placeholder in place | Text is preserved when an exact selected-text match cannot be verified; focus changes cancel the action |

## Project structure

| Directory | Responsibility |
| --- | --- |
| `Sources/CodexMicroCore` | Mapping models, HID decoding, press reduction, shortcut capture and safety decisions |
| `Sources/CodexMicroSystem` | HID access, permission checks, temporary recording and action execution |
| `Sources/CodexMicroMapperApp` | SwiftUI interface, lifecycle and local storage |
| `Tests` | Core, system-decision and persistence tests |

Tests and CI do not grant macOS permissions or simulate physical Codex Micro presses. See [CONTRIBUTING.md](CONTRIBUTING.md) for the validation boundary and how to help.

## License and credits

Created by **Steve**. Licensed under [MIT](LICENSE): use, modify and redistribute the project, including commercially, while keeping the copyright and license notice.

Product names and third-party app icons belong to their respective owners. App icons are read from installed apps at runtime, not bundled as reusable assets. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

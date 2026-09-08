# Setup and troubleshooting

[Back to README](../README.md) · [简体中文](SETUP.zh-CN.md)

## Requirements

- macOS 14 or later and a Work Louder Codex Micro.
- Codex installed to configure the device's key layout.
- Input Monitoring and Accessibility permissions for Mapper.
- For a source build: Xcode 26 with Swift 6.2 or newer.

The downloadable app targets **Apple silicon (arm64)**. It uses an ad-hoc signature, not a Developer ID signature, and is not notarized. An Intel build is not provided. Signing details are in [Releasing](RELEASING.md).

## Install the app

Download the app ZIP from [Releases](https://github.com/levineet/codex-micro-mapper/releases) and check its SHA-256 against `SHA256SUMS.txt`. The automatically generated **Source code** archives contain source files, not an app.

Quit any running Mapper, unzip the app ZIP, and move `Codex Micro Mapper.app` to Applications. If macOS blocks the app, follow its security guidance or inspect and build the source; do not disable system security protections.

Quit the older `Codex Micro Mapping.app` if it is running. The two helpers must not listen to the keyboard at the same time. Mapper detects the conflict and waits for you to quit the old helper.

## Configure Layer 1

In Codex, open **Settings → Codex Micro → Layout**. Configure the bottom two rows on **Layer 1** as follows:

| Physical key | Codex setting | Hardware identifier |
| --- | --- | --- |
| Lower row, first from left | Empty 1 | ACT06 |
| Lower row, second | Empty 2 | ACT07 |
| Lower row, third | Empty 3 | ACT08 |
| Lower row, fourth | Empty 4 | ACT09 |
| Bottom wide key | Empty 5 | ACT10 + ACT11 |
| Bottom-right key | Yolo | ACT12 |

The mapper responds to ACT identifiers, not the words printed on the keys. ACT10 and ACT11 are the two switches under the wide key and are treated as one logical key.

## Allow permissions and choose actions

Open Mapper and follow the permission prompts. Both permissions are in **System Settings → Privacy & Security**:

| Permission | Purpose |
| --- | --- |
| Input Monitoring | Receive key reports from Codex Micro. |
| Accessibility | Send shortcuts, control apps, and verify selected text for ACT12. |

In **Mappings**, enable key mappings and click a key to configure it. Each key can use a shortcut or app control independently, so you can mix actions across the layout. Record a shortcut or use the manual menu for a single key, including Home and **Left/Right Option**. For app control, choose an app, its behavior when already in front, and an optional shortcut after activation.

Closing the settings window leaves Mapper running in the menu bar. Mapping preferences stay on your Mac. See the [privacy explanation](../PRIVACY.md) for the input access involved.

### Initial examples

The first launch includes Command-N, Codex, ChatGPT, Chrome, Home, and guarded Return. These are editable examples, not required integrations. **General → Clear key mappings** makes all six keys unassigned after confirmation. Upgrades preserve existing saved mappings.

### ACT12 and `:yolo:`

Keep ACT12 set to **Yolo** in Codex. For a shortcut assigned to ACT12, Mapper waits for the device's placeholder and checks the foreground app, input focus, and selected text. It removes only an exact `:yolo:` match before sending the configured shortcut—Return by default.

If the match cannot be verified, the text is preserved. A change of foreground app or input focus cancels both cleanup and the shortcut. Clearing ACT12's mapping disables the mapper action; it does not change the device's own Yolo setting.

## Build from source

No third-party Swift packages are required. Quit Mapper before running the installer.

```bash
git clone https://github.com/levineet/codex-micro-mapper.git
cd codex-micro-mapper
swift test --disable-sandbox
bash scripts/build-app.sh
bash scripts/install-app.sh
```

The build creates `outputs/Codex Micro Mapper.zip`. The installer replaces `/Applications/Codex Micro Mapper.app` while preserving the archive's signature and your mapping file. A signature change may require permissions to be granted again.

Tests and CI do not grant macOS permissions or simulate physical key presses. See [Contributing](../CONTRIBUTING.md) for verification guidance and [Releasing](RELEASING.md) for signing and release steps.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Keys do nothing | Device connection, Layer 1 settings in Codex, Input Monitoring, and the global and individual mapping switches. |
| A shortcut cannot be recorded or sent | Accessibility and input permissions; try the manual key menu. |
| A permission is enabled but still appears required | Follow macOS's instructions. Some permission or signature changes require quitting and reopening Mapper, or granting access again. |
| An app does not respond to a shortcut | Check the app's shortcut settings and whether it supports that shortcut globally. A generated Home or Right Option press still depends on the receiving app. |
| The old helper is detected | Quit `Codex Micro Mapping.app`; listening resumes when the conflict clears and the other requirements are met. |
| ACT12 leaves `:yolo:` in place | An unverified or mismatched selection is preserved. Changing the foreground app or input focus cancels the action. |

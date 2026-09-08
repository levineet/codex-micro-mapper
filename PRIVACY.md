# Privacy

English · [简体中文](PRIVACY.zh-CN.md)

This explanation describes the implementation in this repository, version **1.8.1**, updated **September 8, 2026**. It does not describe the behavior of macOS or the other apps you choose to control.

## Local processing

Codex Micro Mapper does not require an account. The app contains no analytics, advertising, telemetry, crash-upload service, or network client. It uses Apple frameworks and no third-party SDKs. Mapping recognition and action decisions run locally on your Mac. See the [package dependencies](Package.swift).

Actions sent to other apps can still have network effects. Opening a browser, starting a recording app, or submitting text with a shortcut does not make that app's activity local or private; its own behavior and privacy policy apply.

## What the app reads

**Codex Micro events.** While mappings are enabled and Input Monitoring is available, the hardware listener accepts reports from devices matching vendor `0x303A`, product `0x8360`, and report ID `6`. It interprets hardware key identifiers and press/release events. Unknown identifiers from these vendor messages are retained for compatibility; this is not a logger for text typed on an ordinary keyboard. Device name, transport, and connection metadata are held in memory. See the [HID service](Sources/CodexMicroSystem/CodexMicroHIDService.swift) and [decoder](Sources/CodexMicroCore/HIDFrameDecoder.swift).

**Shortcut recording.** Clicking **Record Shortcut** creates a temporary, session-wide macOS keyboard event tap. It can receive events from keyboards other than Codex Micro. It reads key codes and modifier flags, including left/right modifiers, and suppresses the recording events to reduce conflicts with global hotkeys. It captures a shortcut definition, not a typed sentence or a general typing history.

The tap is removed after recording completes or is cancelled. Losing app/window focus or the required permissions interrupts recording. Cancellation may keep the tap alive for up to two seconds to handle releases of keys already intercepted; unrelated new input is passed through during that cleanup. A captured shortcut remains an editor draft until you save. See the [recording service](Sources/CodexMicroSystem/ShortcutRecordingService.swift), [capture reducer](Sources/CodexMicroCore/ShortcutCapture.swift), and [recorder UI](Sources/CodexMicroMapperApp/Views/ShortcutRecorder.swift).

**ACT12 selected text.** The guarded ACT12 action uses Accessibility to inspect the frontmost app, focused element, and selected text when checking the `:yolo:` placeholder. It selects backwards, compares the selected string with the placeholder, and deletes only when the exact-match and focus checks pass. An app may expose a selection longer than the placeholder, so this is not a promise to read exactly six characters. Focus changes cancel deletion and the final shortcut. The selected string is not written to the mapping file or diagnostic log and is not uploaded. See the [action executor](Sources/CodexMicroSystem/SystemActionExecutor.swift) and [safety decision](Sources/CodexMicroCore/SafetyDecisions.swift).

**App and keyboard state.** App control checks which app is in front and whether the target is running or hidden. The legacy-helper check examines running app identities and paths to detect a conflict. Choosing an app reads its bundle identifier, display name, and local icon. Before sending shortcuts, the app checks held modifier keys and Caps Lock state. These checks do not create a persistent app-usage history. See the [executor](Sources/CodexMicroSystem/SystemActionExecutor.swift), [legacy monitor](Sources/CodexMicroSystem/LegacyHelperMonitor.swift), and [app picker](Sources/CodexMicroMapperApp/Views/MappingEditorSheet.swift).

The app does not capture microphone audio or screenshots. It does not monitor or read clipboard contents in the background.

## What is stored

| Data | Location and retention |
| --- | --- |
| Mappings | `~/Library/Application Support/Codex Micro Mapper/mappings.json`, until replaced or removed. Stores key codes/modifiers, action enablement, app identifiers/names, follow-up shortcuts, and any legacy action parameters. Unrecognized action JSON is preserved. |
| Language and global mapping switch | macOS preferences for `local.codex.micro.mapper`, until changed or removed. |
| Instance lock | `instance.lock` in the same Application Support directory. Used to prevent duplicate listeners; the app writes no payload to it. |
| Launch at login | Registered through macOS `SMAppService` when you enable it. |
| Diagnostics | In memory for the current app session, up to 80 entries. The visible/copyable output includes the latest 20 entries and current status. No diagnostic file or upload is implemented. |

Configuration uses ordinary JSON and macOS preferences, with no application-level encryption. macOS, backups, or other software may retain additional copies. See the [mapping store](Sources/CodexMicroMapperApp/MappingStore.swift), [app model](Sources/CodexMicroMapperApp/AppModel.swift), [instance lock](Sources/CodexMicroSystem/SingleInstanceGuard.swift), and [login service](Sources/CodexMicroSystem/LaunchAtLoginService.swift).

## Diagnostics and the clipboard

Diagnostics include connection and permission state, hardware key identifiers, local times, and action results. Errors can include app names, macOS Shortcut names, file names, paths, or URL information. They are **not guaranteed anonymous**; review them before sharing.

Choosing **Copy** in Diagnostics replaces the system clipboard contents with that diagnostic text. The app does not automatically send it anywhere. macOS or a clipboard manager may retain or sync a copy. Normal native copy actions remain available, and a mapping such as Command-C or Command-V can make the target app use the clipboard. See [diagnostic creation and copying](Sources/CodexMicroMapperApp/AppModel.swift).

## Older configurations and other apps

The editor now focuses on shortcuts and app control. Existing configurations can still open URLs, files, or folders, run named macOS Shortcuts, or send a Typeless recording hotkey. URLs and files are handed to their system-selected handler; Shortcuts receives the configured shortcut name. Mapper does not read the opened file's contents or record audio for Typeless. The invoked handler, app, or shortcut can process data or use the network. See the [legacy action models](Sources/CodexMicroCore/MappingModels.swift), [preservation behavior](Sources/CodexMicroMapperApp/EditorDraft.swift), and [executor](Sources/CodexMicroSystem/SystemActionExecutor.swift).

## Your controls

- **Pause mappings** to stop the normal hardware listener and mapping actions. Cancel any active shortcut recording separately.
- **Revoke access** in macOS **System Settings → Privacy & Security → Input Monitoring / Accessibility**. The app checks capabilities periodically and when it becomes active. Losing Input Monitoring stops the hardware listener; losing Accessibility or event-posting access blocks mapping execution. macOS may require quitting and reopening the app for a permission change to take effect. Revoking access does not delete saved settings.
- **General → Clear key mappings** replaces all mappings with six unassigned keys. It does not reset language, the global enable switch, login registration, permission grants, diagnostics, or clipboard copies, and is not secure erasure.
- **Quit the app** to stop its listeners and end the in-memory diagnostic session. To remove its local mapping files, quit first, then remove `~/Library/Application Support/Codex Micro Mapper/`. Preferences and system permissions are separate. Removing files cannot remove copies already made by backups or other software.

These statements describe the source implementation. They are not a claim of an independent privacy audit, network traffic capture, or a guarantee about third-party builds. When reporting an issue, share only the configuration or diagnostics needed to reproduce it and remove personal details first.

@preconcurrency import AppKit
import ApplicationServices
import CodexMicroCore
import Foundation

@MainActor
public final class SystemActionExecutor {
    public typealias Completion = @MainActor (ActionResult) -> Void

    private var activeTask: Task<Void, Never>?

    public init() {}

    public var isBusy: Bool { activeTask != nil }

    public func execute(_ action: MappingAction, completion: @escaping Completion) {
        guard activeTask == nil else {
            completion(.skipped(reason: "Another mapping action is still running."))
            return
        }

        activeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.perform(action)
            self.activeTask = nil
            completion(result)
        }
    }

    public func cancelAll() {
        activeTask?.cancel()
    }

    private func perform(_ action: MappingAction) async -> ActionResult {
        switch action {
        case .disabled:
            return .skipped(reason: "This control is disabled.")

        case let .keyStroke(keyStroke):
            return await postKeyStroke(keyStroke)

        case let .toggleApplication(target, afterActivation):
            return await controlApplication(
                target,
                hideWhenFrontmost: true,
                afterActivation: afterActivation
            )

        case let .activateApplication(target, afterActivation):
            return await controlApplication(
                target,
                hideWhenFrontmost: false,
                afterActivation: afterActivation
            )

        case let .openTarget(target):
            return open(target)

        case let .runShortcut(name):
            return runShortcut(named: name)

        case let .typelessRecordingToggle(target, keyStroke):
            guard !NSRunningApplication.runningApplications(
                withBundleIdentifier: target.bundleIdentifier
            ).isEmpty else {
                return .skipped(reason: "\(target.displayName) is not running.")
            }
            return await postKeyStroke(keyStroke)

        case let .verifiedPlaceholderReturn(placeholder, returnKeyStroke):
            guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else {
                return .skipped(reason: "Accessibility event-posting permission is required.")
            }
            return await performVerifiedPlaceholderReturn(
                placeholder: placeholder,
                returnKeyStroke: returnKeyStroke
            )
        }
    }

    private func controlApplication(
        _ target: ApplicationTarget,
        hideWhenFrontmost: Bool,
        afterActivation: KeyStrokeDefinition?
    ) async -> ActionResult {
        if hideWhenFrontmost,
           appToggleDecision(
            frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            target: target
        ) == .hide {
            guard let application = NSWorkspace.shared.frontmostApplication,
                  application.hide() else {
                return .failure(reason: "Could not hide \(target.displayName).")
            }
            return .success
        }

        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: target.bundleIdentifier
        ) else {
            return .failure(reason: "\(target.displayName) is not installed.")
        }

        let application: NSRunningApplication
        if let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: target.bundleIdentifier
        ).first {
            if running.isHidden {
                _ = running.unhide()
            }
            _ = running.activate(options: [.activateAllWindows])
            application = running
        } else {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            do {
                application = try await NSWorkspace.shared.openApplication(
                    at: applicationURL,
                    configuration: configuration
                )
            } catch {
                return .failure(reason: "Could not open \(target.displayName): \(error.localizedDescription)")
            }
        }

        guard await waitUntilFrontmost(
            application: application,
            bundleIdentifier: target.bundleIdentifier
        ) else {
            return Task.isCancelled
                ? .skipped(reason: "The action was cancelled.")
                : .failure(reason: "Timed out bringing \(target.displayName) to the front.")
        }

        guard let afterActivation else {
            return .success
        }

        do {
            try await Task.sleep(for: .milliseconds(250))
        } catch {
            return .skipped(reason: "The action was cancelled.")
        }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == target.bundleIdentifier else {
            return .skipped(reason: "Focus changed before the follow-up shortcut.")
        }
        return await postKeyStroke(afterActivation) {
            NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
        }
    }

    private func open(_ target: OpenTarget) -> ActionResult {
        let url: URL
        let displayName: String

        switch target {
        case let .webURL(rawValue):
            guard let parsedURL = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
                  parsedURL.scheme != nil else {
                return .failure(reason: "The URL is not valid.")
            }
            url = parsedURL
            displayName = parsedURL.host ?? parsedURL.absoluteString

        case let .file(path):
            url = URL(fileURLWithPath: path)
            displayName = url.lastPathComponent

        case let .folder(path):
            url = URL(fileURLWithPath: path, isDirectory: true)
            displayName = url.lastPathComponent
        }

        guard NSWorkspace.shared.open(url) else {
            return .failure(reason: "Could not open \(displayName).")
        }
        return .success
    }

    private func runShortcut(named rawName: String) -> ActionResult {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              var components = URLComponents(string: "shortcuts://run-shortcut") else {
            return .failure(reason: "A shortcut name is required.")
        }

        components.queryItems = [URLQueryItem(name: "name", value: name)]
        guard let url = components.url,
              NSWorkspace.shared.open(url) else {
            return .failure(reason: "Could not run the macOS shortcut named \(name).")
        }
        return .success
    }

    private func waitUntilFrontmost(
        application: NSRunningApplication,
        bundleIdentifier: String
    ) async -> Bool {
        for attempt in 0..<80 {
            if Task.isCancelled || application.isTerminated {
                return false
            }
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier {
                return true
            }
            if attempt.isMultiple(of: 10) {
                if application.isHidden { _ = application.unhide() }
                _ = application.activate(options: [.activateAllWindows])
            }
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return false
            }
        }
        return false
    }

    private func performVerifiedPlaceholderReturn(
        placeholder: String,
        returnKeyStroke: KeyStrokeDefinition
    ) async -> ActionResult {
        guard !placeholder.isEmpty,
              let originalProcess = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let originalElement = focusedElement() else {
            return .failure(reason: "No focused text field was available.")
        }

        do {
            try await Task.sleep(for: .milliseconds(220))
        } catch {
            return .skipped(reason: "The action was cancelled.")
        }

        guard focusIsUnchanged(process: originalProcess, element: originalElement) else {
            return .skipped(reason: "Focus changed before :yolo: could be checked.")
        }

        for _ in placeholder {
            guard focusIsUnchanged(process: originalProcess, element: originalElement) else {
                return .skipped(reason: "Focus changed while selecting :yolo:.")
            }
            let selectionResult = await postKeyStroke(
                KeyStrokeDefinition(keyCode: 123, modifiers: .shift)
            ) { self.focusIsUnchanged(process: originalProcess, element: originalElement) }
            guard selectionResult.succeeded else { return selectionResult }
        }

        do {
            try await Task.sleep(for: .milliseconds(80))
        } catch {
            return .skipped(reason: "The action was cancelled.")
        }

        let currentElement = focusedElement()
        let focusUnchanged = currentElement.map { CFEqual(originalElement, $0) } ?? false
        let processUnchanged = NSWorkspace.shared.frontmostApplication?.processIdentifier == originalProcess
        let selectedText = currentElement.flatMap(selectedText(from:))
        let decision = placeholderCleanupDecision(
            selectedText: selectedText,
            expectedPlaceholder: placeholder,
            isTargetProcessUnchanged: processUnchanged,
            isFocusedElementUnchanged: focusUnchanged
        )

        switch decision {
        case .deleteSelection:
            let deleteResult = await postKeyStroke(KeyStrokeDefinition(keyCode: 51)) {
                self.focusIsUnchanged(process: originalProcess, element: originalElement)
            }
            guard deleteResult.succeeded else { return deleteResult }
        case .preserveSelection:
            guard processUnchanged, focusUnchanged else {
                return .skipped(reason: "Focus changed; no text or Return key was sent.")
            }
            let collapseResult = await postKeyStroke(KeyStrokeDefinition(keyCode: 124)) {
                self.focusIsUnchanged(process: originalProcess, element: originalElement)
            }
            guard collapseResult.succeeded else { return collapseResult }
        }

        guard !Task.isCancelled, focusIsUnchanged(process: originalProcess, element: originalElement) else {
            return .skipped(reason: "Focus changed; Return was not sent.")
        }
        return await postKeyStroke(returnKeyStroke) {
            self.focusIsUnchanged(process: originalProcess, element: originalElement)
        }
    }

    private func focusIsUnchanged(process: pid_t, element: AXUIElement) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == process,
              let currentElement = focusedElement() else {
            return false
        }
        return CFEqual(element, currentElement)
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success,
        let value else {
            return nil
        }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }

    private func selectedText(from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? String
    }

    private func postKeyStroke(
        _ definition: KeyStrokeDefinition,
        focusCheck: (() -> Bool)? = nil
    ) async -> ActionResult {
        guard !Task.isCancelled else { return .skipped(reason: "The action was cancelled.") }
        guard CGPreflightPostEventAccess() else {
            return .skipped(reason: "Accessibility event-posting permission is required.")
        }
        guard ModifierKey.allCases.allSatisfy({ !CGEventSource.keyState(.combinedSessionState, key: $0.rawValue) }) else {
            return .skipped(reason: "Release the keyboard modifier keys before running this mapping.")
        }
        guard let steps = ShortcutEvents.make(definition) else {
            return .failure(reason: "Could not create keyboard events.")
        }
        var pressed: Set<UInt16> = []
        // Cancellation/focus changes may stop downs but must never strand a
        // modifier or main key. Release only keys this action actually posted.
        defer {
            for step in steps where !step.isDown && pressed.contains(step.keyCode) {
                step.event.post(tap: .cghidEventTap)
                pressed.remove(step.keyCode)
            }
        }
        for step in steps {
            guard !Task.isCancelled else { return .skipped(reason: "The action was cancelled.") }
            if step.isDown, let focusCheck, !focusCheck() {
                return .skipped(reason: "Focus changed before the shortcut.")
            }
            step.event.post(tap: .cghidEventTap)
            if step.isDown { pressed.insert(step.keyCode) } else { pressed.remove(step.keyCode) }
            do {
                try await Task.sleep(for: .milliseconds(definition.isModifierOnly ? 60 : 15))
            } catch { return .skipped(reason: "The action was cancelled.") }
        }
        return .success
    }
}

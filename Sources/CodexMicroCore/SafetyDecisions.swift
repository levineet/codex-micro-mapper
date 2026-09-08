public enum AppToggleDecision: String, Codable, Equatable, Sendable {
    case hide
    case activate
}

/// Chooses the foreground toggle behavior without consulting AppKit state.
public func appToggleDecision(
    frontmostBundleIdentifier: String?,
    targetBundleIdentifier: String
) -> AppToggleDecision {
    frontmostBundleIdentifier == targetBundleIdentifier ? .hide : .activate
}

public func appToggleDecision(
    frontmostBundleIdentifier: String?,
    target: ApplicationTarget
) -> AppToggleDecision {
    appToggleDecision(
        frontmostBundleIdentifier: frontmostBundleIdentifier,
        targetBundleIdentifier: target.bundleIdentifier
    )
}

public enum PlaceholderCleanupDecision: String, Codable, Equatable, Sendable {
    case deleteSelection
    case preserveSelection
}

/// Allows deletion only when every safety precondition captured by the System
/// layer still holds. Return submission is intentionally outside this decision:
/// the verified-placeholder action always posts Return after preserving or
/// deleting the selection.
public func placeholderCleanupDecision(
    selectedText: String?,
    expectedPlaceholder: String = ":yolo:",
    isTargetProcessUnchanged: Bool,
    isFocusedElementUnchanged: Bool
) -> PlaceholderCleanupDecision {
    guard !expectedPlaceholder.isEmpty,
          isTargetProcessUnchanged,
          isFocusedElementUnchanged,
          selectedText == expectedPlaceholder
    else {
        return .preserveSelection
    }
    return .deleteSelection
}

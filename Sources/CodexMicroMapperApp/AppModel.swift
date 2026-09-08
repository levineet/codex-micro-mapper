@preconcurrency import AppKit
import CodexMicroCore
import CodexMicroSystem
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isDeviceConnected = false
    @Published private(set) var deviceName = "Codex Micro"
    @Published private(set) var lastEventSummary = ""
    @Published private(set) var highlightedControl: PhysicalControl?
    @Published private(set) var isRecordingShortcut = false
    private var highlightTask: Task<Void, Never>?
    @Published private(set) var permissions: PermissionSnapshot
    @Published private(set) var permissionOnboardingRequest = PermissionOnboardingRequest()
    @Published private(set) var legacyHelperRunning = false
    @Published private(set) var profile: MappingProfile
    @Published private(set) var launchAtLogin = false
    @Published private(set) var language: AppLanguage
    @Published private var diagnosticLines: [String] = []
    @Published private var runtimeError: String?

    private let mappingStore: MappingStore
    private let permissionService: PermissionService
    private let permissionMonitor: PermissionMonitor
    private let hidService: CodexMicroHIDService
    private let actionExecutor: SystemActionExecutor
    private let legacyMonitor: LegacyHelperMonitor
    private let launchAtLoginService: LaunchAtLoginService
    private let instanceGuard: SingleInstanceGuard
    private let defaults: UserDefaults

    private var isPrimaryInstance = false
    private var isShutDown = false
    private var defaultNotificationTokens: [NSObjectProtocol] = []
    private var workspaceNotificationTokens: [NSObjectProtocol] = []
    private var distributedToken: NSObjectProtocol?

    private static let enabledDefaultsKey = "mappingsEnabled"
    private static let languageDefaultsKey = "appLanguage"

    init(
        mappingStore: MappingStore = MappingStore(),
        permissionService: PermissionService = PermissionService(),
        hidService: CodexMicroHIDService = CodexMicroHIDService(),
        actionExecutor: SystemActionExecutor = SystemActionExecutor(),
        legacyMonitor: LegacyHelperMonitor = LegacyHelperMonitor(),
        launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService(),
        instanceGuard: SingleInstanceGuard = SingleInstanceGuard(),
        defaults: UserDefaults = .standard
    ) {
        self.mappingStore = mappingStore
        self.permissionService = permissionService
        permissionMonitor = PermissionMonitor(readSnapshot: permissionService.currentSnapshot)
        self.hidService = hidService
        self.actionExecutor = actionExecutor
        self.legacyMonitor = legacyMonitor
        self.launchAtLoginService = launchAtLoginService
        self.instanceGuard = instanceGuard
        self.defaults = defaults

        profile = mappingStore.load()
        permissions = permissionService.currentSnapshot()
        launchAtLogin = launchAtLoginService.state == .enabled
        language = AppLanguage(
            rawValue: defaults.string(forKey: Self.languageDefaultsKey) ?? ""
        ) ?? .simplifiedChinese
        if defaults.object(forKey: Self.enabledDefaultsKey) == nil {
            isEnabled = true
        } else {
            isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)
        }

        configureCallbacks()
        configureLifecycleObservers()
        acquireInstanceLockAndStart()
        if isPrimaryInstance {
            permissionOnboardingRequest.request(for: permissions)
        }
    }

    var healthTitle: String {
        if !isPrimaryInstance { return language.text("已在运行", "Already Running") }
        if legacyHelperRunning { return language.text("旧版助手占用中", "Legacy Helper Running") }
        if !permissions.inputMonitoringGranted { return language.text("需要输入监控权限", "Input Monitoring Required") }
        if !permissions.canExecuteMappings { return language.text("需要辅助功能权限", "Accessibility Required") }
        if !isEnabled { return language.text("映射已暂停", "Mappings Paused") }
        if let runtimeError { return runtimeError }
        if isDeviceConnected { return language.text("已连接", "Connected") }
        return language.text("未连接", "Not Connected")
    }

    var healthDetail: String {
        if !isPrimaryInstance {
            return language.text("打开已运行的 Codex Micro Mapper。", "Open the running Codex Micro Mapper.")
        }
        if legacyHelperRunning {
            return language.text("退出 Codex Micro Mapping 以启用按键映射。", "Quit Codex Micro Mapping to enable key mappings.")
        }
        if !permissions.inputMonitoringGranted {
            return language.text("开启输入监控以接收键盘按键。", "Enable Input Monitoring to receive key presses.")
        }
        if !permissions.canExecuteMappings {
            return language.text("开启辅助功能以使用快捷键和应用控制。", "Enable Accessibility to use shortcuts and app control.")
        }
        if !isEnabled {
            return language.text("启用按键映射以恢复使用。", "Enable key mappings to resume.")
        }
        if let runtimeError { return runtimeError }
        if isDeviceConnected {
            return language.text("按键映射已启用。", "Key mappings are enabled.")
        }
        return language.text("通过蓝牙或 USB 连接 Codex Micro。", "Connect Codex Micro over Bluetooth or USB.")
    }

    var menuStatusText: String {
        if legacyHelperRunning { return language.text("Codex Micro · 旧版助手冲突", "Codex Micro · Legacy Helper Conflict") }
        if !permissions.inputMonitoringGranted || !permissions.canExecuteMappings {
            return language.text("Codex Micro · 需要权限", "Codex Micro · Permission Required")
        }
        if !isEnabled { return language.text("Codex Micro · 已暂停", "Codex Micro · Paused") }
        if isDeviceConnected { return language.text("Codex Micro · 已连接", "Codex Micro · Connected") }
        return language.text("Codex Micro · 未连接", "Codex Micro · Not Connected")
    }

    var healthSymbolName: String {
        if legacyHelperRunning || runtimeError != nil { return "exclamationmark.triangle.fill" }
        if !permissions.inputMonitoringGranted || !permissions.canExecuteMappings {
            return "lock.trianglebadge.exclamationmark"
        }
        if !isEnabled { return "pause.circle.fill" }
        if isDeviceConnected { return "checkmark.circle.fill" }
        return "cable.connector"
    }

    var diagnosticsText: String {
        let permissionSummary = "Input Monitoring: \(permissions.inputMonitoringGranted ? "granted" : "required") · Accessibility: \(permissions.accessibilityGranted ? "granted" : "required") · Event Posting: \(permissions.eventPostingGranted ? "granted" : "required")"
        let deviceSummary = "Device: \(isDeviceConnected ? deviceName + " connected" : "not connected")"
        let modeSummary = "Mappings: \(isEnabled ? "enabled" : "paused") · Legacy conflict: \(legacyHelperRunning ? "yes" : "no")"
        return ([deviceSummary, permissionSummary, modeSummary] + diagnosticLines.suffix(20)).joined(separator: "\n")
    }

    func toggleEnabled() {
        isEnabled.toggle()
        defaults.set(isEnabled, forKey: Self.enabledDefaultsKey)
        appendDiagnostic(isEnabled ? "Mappings resumed." : "Mappings paused.")
        reconcileRuntime()
    }

    func setLanguage(_ newLanguage: AppLanguage) {
        guard language != newLanguage else { return }
        language = newLanguage
        defaults.set(newLanguage.rawValue, forKey: Self.languageDefaultsKey)
    }

    func openCodex() {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: ApplicationTarget.codex.bundleIdentifier
        ) else {
            appendDiagnostic("Codex is not installed.")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    self?.appendDiagnostic("Could not open Codex: \(error.localizedDescription)")
                }
            }
        }
    }

    func setRecordingShortcut(_ active: Bool) {
        isRecordingShortcut = active
        if active { actionExecutor.cancelAll() }
    }

    @discardableResult
    func editBinding(_ binding: MappingBinding) -> Bool {
        var updated = profile
        updated.setBinding(binding)
        do {
            try mappingStore.save(updated)
            profile = updated
            appendDiagnostic("Updated \(binding.control.id) mapping.")
            return true
        } catch {
            appendDiagnostic("Mapping save failed: \(error.localizedDescription)")
            return false
        }
    }

    func requestInputMonitoring() {
        _ = permissionService.requestInputMonitoring()
        appendDiagnostic("Input Monitoring permission requested.")
        refreshPermissionsAndRuntime()
    }

    func requestAccessibility() {
        _ = permissionService.requestAccessibility(prompt: true)
        _ = permissionService.requestEventPosting()
        appendDiagnostic("Accessibility permission requested.")
        refreshPermissionsAndRuntime()
    }

    func openInputMonitoringSettings() {
        _ = permissionService.openSystemSettings(.inputMonitoring)
    }

    func openAccessibilitySettings() {
        _ = permissionService.openSystemSettings(.accessibility)
    }

    func takePermissionOnboardingRequest() -> Bool {
        refreshPermissionsAndRuntime()
        return permissionOnboardingRequest.take(for: permissions)
    }

    private func settingsWindowOpened() {
        refreshPermissionsAndRuntime()
        permissionOnboardingRequest.request(for: permissions)
    }

    func terminateLegacyHelper() {
        let requested = legacyMonitor.terminateConflictingHelper()
        appendDiagnostic(requested ? "Asked the legacy helper to quit." : "Could not quit the legacy helper.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.legacyHelperRunning = self.legacyMonitor.refresh() != nil
            self.reconcileRuntime()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            let state = try launchAtLoginService.setEnabled(enabled)
            launchAtLogin = state == .enabled || state == .requiresApproval
            appendDiagnostic("Launch at login: \(state.rawValue).")
        } catch {
            launchAtLogin = launchAtLoginService.state == .enabled
            appendDiagnostic("Launch-at-login change failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func clearMappings() -> Bool {
        do {
            try mappingStore.save(.empty)
            actionExecutor.cancelAll()
            profile = .empty
            appendDiagnostic("Cleared all key mappings.")
            return true
        } catch {
            appendDiagnostic("Clearing mappings failed: \(error.localizedDescription)")
            return false
        }
    }

    func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticsText, forType: .string)
        appendDiagnostic("Diagnostics copied.")
    }

    func shutdown() {
        guard !isShutDown else { return }
        isShutDown = true
        highlightTask?.cancel()
        permissionMonitor.stop()
        defaultNotificationTokens.forEach(NotificationCenter.default.removeObserver)
        defaultNotificationTokens.removeAll()
        workspaceNotificationTokens.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceNotificationTokens.removeAll()
        if let distributedToken {
            DistributedNotificationCenter.default().removeObserver(distributedToken)
            self.distributedToken = nil
        }
        legacyMonitor.stopMonitoring()
        actionExecutor.cancelAll()
        hidService.stop()
        instanceGuard.releaseLock()
    }

    private func configureCallbacks() {
        permissionMonitor.onSnapshot = { [weak self] snapshot in
            self?.applyPermissionSnapshot(snapshot)
        }
        hidService.onConnectionChanged = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.applyConnectionState(state)
            }
        }
        hidService.onLogicalEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleLogicalEvent(event)
            }
        }
        legacyMonitor.onConflictChanged = { [weak self] conflict in
            guard let self else { return }
            self.legacyHelperRunning = conflict != nil
            self.appendDiagnostic(
                conflict == nil ? "Legacy helper conflict cleared." : "Legacy helper detected; mappings blocked."
            )
            self.reconcileRuntime()
        }
    }

    private func configureLifecycleObservers() {
        let center = NotificationCenter.default
        defaultNotificationTokens.append(center.addObserver(
            forName: .codexMicroMapperDidOpenSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsWindowOpened() }
        })
        defaultNotificationTokens.append(center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissionsAndRuntime() }
        })
        defaultNotificationTokens.append(center.addObserver(
            forName: .codexMicroMapperWillTerminate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.shutdown() }
        })

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceNotificationTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.actionExecutor.cancelAll()
                self?.hidService.resetPressState()
            }
        })
        workspaceNotificationTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hidService.resetPressState()
                self?.refreshPermissionsAndRuntime()
            }
        })

        distributedToken = DistributedNotificationCenter.default().addObserver(
            forName: SingleInstanceGuard.reopenSettingsNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AppLifecycleDelegate.presentMainWindow()
            }
        }
    }

    private func acquireInstanceLockAndStart() {
        do {
            switch try instanceGuard.acquire() {
            case .acquired:
                isPrimaryInstance = true
            case .alreadyRunning:
                instanceGuard.notifyExistingInstanceToOpenSettings()
                appendDiagnostic("Another instance already owns the mapper lock.")
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
                return
            }
        } catch {
            runtimeError = "Single-instance protection failed"
            appendDiagnostic(error.localizedDescription)
            return
        }

        legacyMonitor.startMonitoring()
        legacyHelperRunning = legacyMonitor.conflict != nil
        permissionMonitor.start()
        appendDiagnostic("Codex Micro Mapper started.")
    }

    private func refreshPermissionsAndRuntime() {
        permissionMonitor.refresh()
    }

    private func applyPermissionSnapshot(_ snapshot: PermissionSnapshot) {
        guard !isShutDown else { return }
        if snapshot != permissions {
            permissions = snapshot
            appendDiagnostic("Permission state changed.")
        }
        launchAtLogin = launchAtLoginService.state == .enabled
        legacyHelperRunning = legacyMonitor.refresh() != nil
        reconcileRuntime()
    }

    private func reconcileRuntime() {
        guard isPrimaryInstance, !isShutDown else { return }
        // Executing actions needs both Accessibility and Event Posting. Losing
        // either permission cancels delayed app actions and ACT12 continuations.
        if !permissions.canExecuteMappings { actionExecutor.cancelAll() }
        let shouldListen = isEnabled
            && permissions.canListenToDevice
            && !legacyHelperRunning

        guard shouldListen else {
            actionExecutor.cancelAll()
            if hidService.isRunning { hidService.stop() }
            isDeviceConnected = false
            deviceName = "Codex Micro"
            return
        }

        if !hidService.isRunning {
            do {
                try hidService.start()
                runtimeError = nil
                appendDiagnostic("Listening for Codex Micro.")
            } catch {
                runtimeError = "Could not start device listener"
                appendDiagnostic(error.localizedDescription)
            }
        }
    }

    private func applyConnectionState(_ state: CodexMicroHIDConnectionState) {
        guard !isShutDown else { return }
        switch state {
        case .stopped, .listening:
            isDeviceConnected = false
            deviceName = "Codex Micro"
        case let .connected(device):
            // A queued device-match callback must not revive a listener that
            // was stopped on revocation. Failures remain visible even when the
            // HID manager could not be opened and is consequently not running.
            guard hidService.isRunning, permissions.canListenToDevice, isEnabled else { return }
            isDeviceConnected = true
            deviceName = device.productName
            runtimeError = nil
            appendDiagnostic("Connected to \(device.productName) via \(device.transport).")
        case let .failed(message):
            isDeviceConnected = false
            runtimeError = "Device listener failed"
            appendDiagnostic(message)
        }
    }

    private func handleLogicalEvent(_ event: LogicalKeyEvent) {
        guard event.phase == .down else { return }
        highlightedControl = event.control
        highlightTask?.cancel()
        highlightTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
            self?.highlightedControl = nil
        }
        let timestamp = Date.now.formatted(date: .omitted, time: .standard)
        lastEventSummary = "\(event.sourceKey.rawValue) · \(timestamp)"
        appendDiagnostic("Received \(event.sourceKey.rawValue).")

        guard !isShutDown,
              isPrimaryInstance,
              permissions.canListenToDevice,
              permissions.canExecuteMappings,
              isEnabled,
              !isRecordingShortcut,
              !legacyHelperRunning else {
            appendDiagnostic("Action skipped because mappings are unavailable.")
            return
        }
        guard let action = profile.action(for: event.control) else {
            appendDiagnostic("No mapping exists for \(event.control.id).")
            return
        }

        actionExecutor.execute(action) { [weak self] result in
            self?.appendDiagnostic("\(event.control.id): \(Self.describe(result)).")
        }
    }

    private func appendDiagnostic(_ message: String) {
        let timestamp = Date.now.formatted(date: .omitted, time: .standard)
        diagnosticLines.append("[\(timestamp)] \(message)")
        if diagnosticLines.count > 80 {
            diagnosticLines.removeFirst(diagnosticLines.count - 80)
        }
    }

    private static func describe(_ result: ActionResult) -> String {
        switch result {
        case .success:
            return "completed"
        case let .skipped(reason):
            return "skipped — \(reason)"
        case let .failure(reason):
            return "failed — \(reason)"
        }
    }

}

import Darwin
import Foundation

@MainActor
public final class SingleInstanceGuard {
    public enum Acquisition: Sendable, Equatable {
        case acquired
        case alreadyRunning
    }

    public enum GuardError: LocalizedError {
        case unableToCreateDirectory(URL, underlying: Error)
        case unableToOpenLockFile(URL, errno: Int32)
        case unableToLock(URL, errno: Int32)

        public var errorDescription: String? {
            switch self {
            case let .unableToCreateDirectory(url, error):
                return "Unable to create the lock directory at \(url.path): \(error.localizedDescription)"
            case let .unableToOpenLockFile(url, code):
                return "Unable to open the instance lock at \(url.path): \(String(cString: strerror(code)))"
            case let .unableToLock(url, code):
                return "Unable to acquire the instance lock at \(url.path): \(String(cString: strerror(code)))"
            }
        }
    }

    public static let reopenSettingsNotification = Notification.Name(
        "local.codex.micro.mapper.reopen-settings"
    )

    public let lockFileURL: URL
    public private(set) var acquisition: Acquisition?
    private var fileDescriptor: Int32 = -1

    public init(lockFileURL: URL? = nil) {
        if let lockFileURL {
            self.lockFileURL = lockFileURL
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.lockFileURL = base
                .appendingPathComponent("Codex Micro Mapper", isDirectory: true)
                .appendingPathComponent("instance.lock", isDirectory: false)
        }
    }

    deinit {
        if fileDescriptor >= 0 {
            _ = flock(fileDescriptor, LOCK_UN)
            Darwin.close(fileDescriptor)
        }
    }

    @discardableResult
    public func acquire() throws -> Acquisition {
        if let acquisition {
            return acquisition
        }

        do {
            try FileManager.default.createDirectory(
                at: lockFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw GuardError.unableToCreateDirectory(
                lockFileURL.deletingLastPathComponent(),
                underlying: error
            )
        }

        let descriptor = Darwin.open(lockFileURL.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            throw GuardError.unableToOpenLockFile(lockFileURL, errno: Darwin.errno)
        }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let code = Darwin.errno
            Darwin.close(descriptor)
            if code == EWOULDBLOCK || code == EAGAIN {
                acquisition = .alreadyRunning
                return .alreadyRunning
            }
            throw GuardError.unableToLock(lockFileURL, errno: code)
        }

        fileDescriptor = descriptor
        acquisition = .acquired
        return .acquired
    }

    public func notifyExistingInstanceToOpenSettings() {
        DistributedNotificationCenter.default().postNotificationName(
            Self.reopenSettingsNotification,
            object: Bundle.main.bundleIdentifier ?? "local.codex.micro.mapper",
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public func releaseLock() {
        guard fileDescriptor >= 0 else {
            acquisition = nil
            return
        }
        _ = flock(fileDescriptor, LOCK_UN)
        Darwin.close(fileDescriptor)
        fileDescriptor = -1
        acquisition = nil
    }
}

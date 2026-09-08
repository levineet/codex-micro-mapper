import CodexMicroSystem
@testable import CodexMicroMapper
import XCTest

final class PermissionOnboardingRequestTests: XCTestCase {
    private let missingPermissions = PermissionSnapshot(
        inputMonitoringGranted: false,
        accessibilityGranted: false,
        eventPostingGranted: false
    )
    private let grantedPermissions = PermissionSnapshot(
        inputMonitoringGranted: true,
        accessibilityGranted: true,
        eventPostingGranted: true
    )

    func testExplicitOpenRequestsOnboardingForEveryMissingCapability() {
        for inputMonitoring in [false, true] {
            for accessibility in [false, true] {
                for eventPosting in [false, true] {
                    let permissions = PermissionSnapshot(
                        inputMonitoringGranted: inputMonitoring,
                        accessibilityGranted: accessibility,
                        eventPostingGranted: eventPosting
                    )
                    var request = PermissionOnboardingRequest()

                    request.request(for: permissions)

                    XCTAssertEqual(
                        request.isPending,
                        !(inputMonitoring && accessibility && eventPosting),
                        "Input Monitoring: \(inputMonitoring), Accessibility: \(accessibility), Event Posting: \(eventPosting)"
                    )
                }
            }
        }
    }

    func testRepeatedOpenRequestsProduceOnlyOnePresentation() {
        var request = PermissionOnboardingRequest()
        request.request(for: missingPermissions)
        request.request(for: missingPermissions)
        request.request(for: missingPermissions)

        XCTAssertTrue(request.take(for: missingPermissions))
        XCTAssertFalse(request.isPending)
        XCTAssertFalse(request.take(for: missingPermissions))
    }

    func testAnotherExplicitOpenCanRequestOnboardingAfterDismissal() {
        var request = PermissionOnboardingRequest()
        request.request(for: missingPermissions)
        XCTAssertTrue(request.take(for: missingPermissions))
        XCTAssertFalse(request.take(for: missingPermissions))

        request.request(for: missingPermissions)

        XCTAssertTrue(request.isPending)
        XCTAssertTrue(request.take(for: missingPermissions))
        XCTAssertFalse(request.isPending)
    }

    func testPermissionsGrantedWhileEditingCancelDeferredPresentation() {
        var request = PermissionOnboardingRequest()
        request.request(for: missingPermissions)
        XCTAssertTrue(request.isPending)

        XCTAssertFalse(request.take(for: grantedPermissions))
        XCTAssertFalse(request.isPending)
        XCTAssertFalse(request.take(for: missingPermissions))
    }

    func testMissingPermissionsWithoutExplicitOpenNeverPresentOnboarding() {
        var request = PermissionOnboardingRequest()

        XCTAssertFalse(request.isPending)
        XCTAssertFalse(request.take(for: missingPermissions))
        XCTAssertFalse(request.take(for: missingPermissions))
        XCTAssertFalse(request.isPending)
    }
}

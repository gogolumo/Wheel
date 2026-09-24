import Foundation
import XCTest
import WheelDomain
@testable import WheelMacOS

final class WheelApplicationNavigationTests: XCTestCase {
    func testGestureSelectsPreviousCapturedApplication() async {
        let harness = await MainActor.run { NavigationHarness() }

        await MainActor.run {
            harness.viewModel.start()
            harness.applicationMonitor.emitActivated(
                observation(name: "Safari", bundle: "com.apple.Safari", pid: 10)
            )
            harness.applicationMonitor.emitActivated(
                observation(name: "Finder", bundle: "com.apple.finder", pid: 11)
            )

            XCTAssertEqual(
                harness.viewModel.wheelApplications.map(\.localizedName),
                ["Safari"]
            )

            harness.inputMonitor.emit(
                .triggerBegan(origin: .init(x: 100, y: 100))
            )
            harness.inputMonitor.emit(
                .pointerMoved(
                    displacement: .init(horizontal: 120, vertical: 0)
                )
            )
            harness.inputMonitor.emit(
                .triggerEnded(
                    direction: .right,
                    displacement: .init(horizontal: 120, vertical: 0),
                    duration: 0.25
                )
            )
        }

        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(
                harness.activator.requestedContexts.map(\.localizedName),
                ["Safari"]
            )
            XCTAssertEqual(harness.viewModel.lastApplicationAction, "Safari")
        }
    }

    func testTerminatedApplicationRemainsInWheelAndIsSentToActivator() async {
        let harness = await MainActor.run { NavigationHarness() }
        let safari = observation(
            name: "Safari",
            bundle: "com.apple.Safari",
            pid: 10
        )
        let finder = observation(
            name: "Finder",
            bundle: "com.apple.finder",
            pid: 11
        )

        await MainActor.run {
            harness.viewModel.start()
            harness.applicationMonitor.emitActivated(safari)
            harness.applicationMonitor.emitActivated(finder)
            harness.applicationMonitor.emitTerminated(safari)

            XCTAssertEqual(harness.viewModel.wheelApplications.count, 1)
            XCTAssertEqual(
                harness.viewModel.wheelApplications[0].runState,
                .terminated
            )

            harness.inputMonitor.emit(
                .triggerBegan(origin: .init(x: 100, y: 100))
            )
            harness.inputMonitor.emit(
                .triggerEnded(
                    direction: .right,
                    displacement: .init(horizontal: 140, vertical: 0),
                    duration: 0.25
                )
            )
        }

        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(harness.activator.requestedContexts.count, 1)
            XCTAssertEqual(
                harness.activator.requestedContexts[0].localizedName,
                "Safari"
            )
            XCTAssertEqual(
                harness.activator.requestedContexts[0].runState,
                .terminated
            )
        }
    }

    func testWheelOriginActivationDoesNotAppendDuplicateTransition() async {
        let harness = await MainActor.run { NavigationHarness() }
        let safari = observation(
            name: "Safari",
            bundle: "com.apple.Safari",
            pid: 10
        )
        let finder = observation(
            name: "Finder",
            bundle: "com.apple.finder",
            pid: 11
        )

        await MainActor.run {
            harness.viewModel.start()
            harness.applicationMonitor.emitActivated(safari)
            harness.applicationMonitor.emitActivated(finder)
            let countBeforeRestore = harness.historyStore.entries.count

            harness.inputMonitor.emit(
                .triggerBegan(origin: .init(x: 0, y: 0))
            )
            harness.inputMonitor.emit(
                .triggerEnded(
                    direction: .right,
                    displacement: .init(horizontal: 120, vertical: 0),
                    duration: 0.2
                )
            )
            harness.applicationMonitor.emitActivated(safari)

            XCTAssertEqual(
                harness.historyStore.entries.count,
                countBeforeRestore
            )
            XCTAssertEqual(
                harness.historyStore.currentIdentifier,
                safari.stableIdentifier
            )
        }
    }

    private func observation(
        name: String,
        bundle: String,
        pid: Int32
    ) -> WheelObservedApplication {
        WheelObservedApplication(
            localizedName: name,
            bundleIdentifier: bundle,
            applicationURL: URL(
                fileURLWithPath: "/Applications/\(name).app"
            ),
            processIdentifier: pid
        )
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}

@MainActor
private final class NavigationHarness {
    let inputMonitor = NavigationInputMonitor()
    let applicationMonitor = NavigationApplicationMonitor()
    let activator = NavigationApplicationActivator()
    let historyStore = WheelApplicationHistoryStore(
        persistence: NavigationHistoryPersistence()
    )
    let settings: WheelSettings
    let viewModel: WheelAppViewModel

    init() {
        let suiteName = "WheelApplicationNavigationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        settings = WheelSettings(defaults: defaults)

        viewModel = WheelAppViewModel(
            permissionProvider: { true },
            permissionRequester: { true },
            monitorFactory: { [inputMonitor] _ in inputMonitor },
            settings: settings,
            applicationMonitor: applicationMonitor,
            applicationActivator: activator,
            applicationHistoryStore: historyStore
        )
    }
}

private final class NavigationInputMonitor: InputEventMonitoring {
    var onEvent: ((GlobalInputEvent) -> Void)?
    private(set) var isRunning = false

    func start() throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func emit(_ event: GlobalInputEvent) {
        onEvent?(event)
    }
}

@MainActor
private final class NavigationApplicationMonitor: WheelApplicationMonitoring {
    var onActivated: ((WheelObservedApplication) -> Void)?
    var onLaunched: ((WheelObservedApplication) -> Void)?
    var onTerminated: ((WheelObservedApplication) -> Void)?

    func start() {}
    func stop() {}

    func emitActivated(_ observation: WheelObservedApplication) {
        onActivated?(observation)
    }

    func emitTerminated(_ observation: WheelObservedApplication) {
        onTerminated?(observation)
    }
}

@MainActor
private final class NavigationApplicationActivator: WheelApplicationActivating {
    private(set) var requestedContexts: [WheelApplicationContext] = []

    func activate(
        _ context: WheelApplicationContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        requestedContexts.append(context)
        completion(.success(()))
    }
}

private final class NavigationHistoryPersistence:
    WheelApplicationHistoryPersisting
{
    var snapshot: WheelApplicationHistorySnapshot?

    func load() -> WheelApplicationHistorySnapshot? {
        snapshot
    }

    func save(_ snapshot: WheelApplicationHistorySnapshot) {
        self.snapshot = snapshot
    }
}

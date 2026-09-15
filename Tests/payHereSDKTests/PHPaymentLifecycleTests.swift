import XCTest
import UIKit
import ObjectMapper
import Alamofire
@testable import payHereSDK

final class PHPaymentLifecycleTests: XCTestCase {
    func testConfigurationPreservesExistingDefaults() {
        let configuration = PHPaymentConfiguration.default

        XCTAssertTrue(configuration.showResultScreen)
        XCTAssertTrue(configuration.showRetryOnResultScreen)
    }

    @MainActor
    func testRetryRequiresVisibleResultAndConfirmedFailure() async {
        let statuses: [StatusResponse.Status?] = [nil, .INIT, .PAYMENT, .SUCCESS, .FAILED, .AUTHORIZED]

        for showResultScreen in [false, true] {
            for showRetryOnResultScreen in [false, true] {
                let configuration = PHPaymentConfiguration(
                    showResultScreen: showResultScreen,
                    showRetryOnResultScreen: showRetryOnResultScreen)

                for status in statuses {
                    var lifecycle = PHPaymentLifecycle()
                    _ = lifecycle.beginAttempt()
                    _ = lifecycle.receiveTerminalStatus(status)

                    XCTAssertEqual(
                        lifecycle.canRetry(configuration: configuration, status: status),
                        showResultScreen && showRetryOnResultScreen && status == .FAILED,
                        "Unexpected retry availability for status \(String(describing: status)), result \(showResultScreen), retry \(showRetryOnResultScreen)")
                }
            }
        }
    }

    @MainActor
    func testPendingAndUnavailableStatusesKeepAttemptActive() async throws {
        var lifecycle = PHPaymentLifecycle()
        let attemptID = try XCTUnwrap(lifecycle.beginAttempt())

        for status: StatusResponse.Status? in [nil, .INIT, .PAYMENT] {
            XCTAssertFalse(lifecycle.receiveTerminalStatus(status))
            XCTAssertEqual(lifecycle.phase, .active)
            XCTAssertTrue(lifecycle.accepts(attemptID))
            XCTAssertFalse(lifecycle.canRetry(configuration: .default, status: status))
        }
    }

    @MainActor
    func testTerminalResultIsConsumedOnceAndStopsAcceptingWork() async throws {
        for status: StatusResponse.Status in [.SUCCESS, .FAILED, .AUTHORIZED] {
            var lifecycle = PHPaymentLifecycle()
            let attemptID = try XCTUnwrap(lifecycle.beginAttempt())

            XCTAssertTrue(lifecycle.receiveTerminalStatus(status))
            XCTAssertEqual(lifecycle.phase, .result)
            XCTAssertFalse(lifecycle.accepts(attemptID))
            XCTAssertFalse(lifecycle.receiveTerminalStatus(status))
            XCTAssertFalse(lifecycle.receiveTerminalStatus(.FAILED))
        }
    }

    @MainActor
    func testRetryRejectsPreviousAttemptResponses() async throws {
        var lifecycle = PHPaymentLifecycle()
        let failedAttemptID = try XCTUnwrap(lifecycle.beginAttempt())
        XCTAssertTrue(lifecycle.receiveTerminalStatus(.FAILED))

        let retryAttemptID = try XCTUnwrap(lifecycle.beginAttempt())

        XCTAssertNotEqual(failedAttemptID, retryAttemptID)
        XCTAssertFalse(lifecycle.accepts(failedAttemptID))
        XCTAssertTrue(lifecycle.accepts(retryAttemptID))
        XCTAssertFalse(lifecycle.canRetry(configuration: .default, status: .FAILED))
        XCTAssertTrue(lifecycle.receiveTerminalStatus(.SUCCESS))
    }

    @MainActor
    func testClosingRejectsRepeatedActionsAndDeliversCompletionOnce() async throws {
        var lifecycle = PHPaymentLifecycle()
        let attemptID = try XCTUnwrap(lifecycle.beginAttempt())
        XCTAssertTrue(lifecycle.receiveTerminalStatus(.FAILED))

        XCTAssertTrue(lifecycle.beginClosing())
        XCTAssertEqual(lifecycle.phase, .closing)
        XCTAssertFalse(lifecycle.beginClosing())
        XCTAssertFalse(lifecycle.accepts(attemptID))
        XCTAssertNil(lifecycle.beginAttempt())
        XCTAssertFalse(lifecycle.canRetry(configuration: .default, status: .FAILED))
        XCTAssertFalse(lifecycle.receiveTerminalStatus(.SUCCESS))

        XCTAssertTrue(lifecycle.finishClosing())
        XCTAssertEqual(lifecycle.phase, .closed)
        XCTAssertFalse(lifecycle.finishClosing())
        XCTAssertFalse(lifecycle.beginClosing())
        XCTAssertNil(lifecycle.beginAttempt())
    }

    @MainActor
    func testCompletionCannotRunBeforeDismissalStarts() async {
        var lifecycle = PHPaymentLifecycle()

        XCTAssertFalse(lifecycle.finishClosing())
        XCTAssertFalse(lifecycle.receiveTerminalStatus(.SUCCESS))
        _ = lifecycle.beginAttempt()
        XCTAssertFalse(lifecycle.finishClosing())
        XCTAssertTrue(lifecycle.beginClosing())
        XCTAssertTrue(lifecycle.finishClosing())
    }

    func testMissingMalformedAndUnknownStatusesRemainUnavailable() throws {
        for payload in ["{}", "{\"status\":null}", "{\"status\":\"invalid\"}", "{\"status\":999}"] {
            let response = try XCTUnwrap(StatusResponse(JSONString: payload))

            XCTAssertNil(response.getStatusState(), payload)
        }
    }

    func testSupportedWireStatusesDecodeWithoutChangingMeaning() throws {
        for status: StatusResponse.Status in [.INIT, .PAYMENT, .SUCCESS, .FAILED, .AUTHORIZED] {
            let response = try XCTUnwrap(StatusResponse(JSON: ["status": status.rawValue]))

            XCTAssertEqual(response.getStatusState(), status)
        }
    }

    @MainActor
    func testConfigurationIsAppliedIndependentlyToEachPresentation() async throws {
        let presenter = CapturingPresenter()
        let delegate = UnexpectedPaymentDelegate()
        let configurations = [
            PHPaymentConfiguration(showResultScreen: true, showRetryOnResultScreen: true),
            PHPaymentConfiguration(showResultScreen: true, showRetryOnResultScreen: false),
            PHPaymentConfiguration(showResultScreen: false, showRetryOnResultScreen: true),
            PHPaymentConfiguration(showResultScreen: false, showRetryOnResultScreen: false)
        ]

        for configuration in configurations {
            PayHereSDK.present(from: presenter, withInitRequest: makeRequest(),
                               configuration: configuration, delegate: delegate)
        }

        XCTAssertEqual(presenter.capturedControllers.count, configurations.count)
        for (controller, expected) in zip(presenter.capturedControllers, configurations) {
            let payment = try XCTUnwrap(controller as? PHBottomViewController)
            XCTAssertEqual(payment.configuration.showResultScreen, expected.showResultScreen)
            XCTAssertEqual(payment.configuration.showRetryOnResultScreen, expected.showRetryOnResultScreen)
            XCTAssertFalse(payment.isViewLoaded, "Configuration must be assigned before checkout starts")
        }
    }

    @MainActor
    func testPresentationWithoutConfigurationPreservesDefaultsAndLegacyFlags() async throws {
        let presenter = CapturingPresenter()
        let delegate = UnexpectedPaymentDelegate()

        PayHereSDK.present(from: presenter, withInitRequest: makeRequest(), delegate: delegate)
        PHPresentController.present(from: presenter, withInitRequest: makeRequest(), delegate: delegate)
        PHPrecentController.present(from: presenter, withInitRequest: makeRequest(), delegate: delegate)
        PHPrecentController.present(from: presenter, withInitRequest: makeRequest(),
                                    shouldShowPaymentStatus: true, delegate: delegate)
        PHPrecentController.present(from: presenter, withInitRequest: makeRequest(),
                                    shouldShowPaymentStatus: false, delegate: delegate)
        PHPrecentController.precent(from: presenter, withInitRequest: makeRequest(),
                                    shouldShowPaymentStatus: false, delegate: delegate)

        XCTAssertEqual(presenter.capturedControllers.count, 6)
        for (controller, expectedResult) in zip(presenter.capturedControllers, [true, true, true, true, false, false]) {
            let payment = try XCTUnwrap(controller as? PHBottomViewController)
            XCTAssertEqual(payment.configuration.showResultScreen, expectedResult)
            XCTAssertTrue(payment.configuration.showRetryOnResultScreen)
        }
    }

    private func makeRequest() -> PHInitialRequest {
        return PHInitialRequest(merchantID: "1210000", notifyURL: nil, firstName: nil,
                                lastName: nil, email: nil, phone: nil, address: nil,
                                city: nil, country: nil, orderID: nil, itemsDescription: nil,
                                itemsMap: nil, currency: nil, amount: nil, deliveryAddress: nil,
                                deliveryCity: nil, deliveryCountry: nil, custom1: nil, custom2: nil)
    }
}

private final class CapturingPresenter: UIViewController {
    private(set) var capturedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                          completion: (() -> Void)? = nil) {
        capturedControllers.append(viewControllerToPresent)
        completion?()
    }
}

private final class UnexpectedPaymentDelegate: PHViewControllerDelegate {
    func onResponseReceived(response: PHResponse<Any>?) {
        XCTFail("Presentation must not complete the payment")
    }

    func onErrorReceived(error: Error) {
        XCTFail("Unexpected presentation error: \(error)")
    }
}

// Exercises the production controller and storyboard with every SDK request intercepted.
final class PHPaymentControllerTests: XCTestCase {
    @MainActor
    func testPendingStatusKeepsCheckingWithoutResultOrRetry() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":1}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually { fixture.network.requestPaths.contains("/pay/order_status") }
        // Allow the intercepted response to complete before checking the unchanged active state.
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(try fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden)
        XCTAssertNil(fixture.alert)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        XCTAssertEqual(fixture.network.requestPaths, ["/pay/api/payment/v2/init", "/pay/order_status"])
    }

    @MainActor
    func testHiddenResultCompletesOnceOnMainThreadAfterDismissal() async throws {
        let fixture = try makeFixture(configuration: PHPaymentConfiguration(showResultScreen: false, showRetryOnResultScreen: true), api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":2,\"paymentNo\":123}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually { fixture.delegate.callbackCount == 1 }

        XCTAssertTrue(fixture.delegate.allCallbacksOnMainThread)
        XCTAssertTrue(fixture.delegate.resultArrivedAfterDismissal)
        XCTAssertEqual(fixture.delegate.response?.isSuccess(), true)
        XCTAssertEqual(fixture.delegate.errorCount, 0)
        XCTAssertTrue(try fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden)

        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        XCTAssertEqual(fixture.delegate.callbackCount, 1)
    }

    @MainActor
    func testRetryDisabledFailureShowsDoneAndReturnsKnownFailureOnce() async throws {
        let fixture = try makeFixture(configuration: PHPaymentConfiguration(showResultScreen: true, showRetryOnResultScreen: false), api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":-2,\"message\":\"Declined\"}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually {
            (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
        }

        XCTAssertFalse(try fixture.outlet("btnDone", as: UIButton.self).isHidden)
        XCTAssertTrue(try fixture.outlet("btnTryAgain", as: UIButton.self).isHidden)
        XCTAssertTrue(try fixture.outlet("btnCancel", as: UIButton.self).isHidden)
        XCTAssertFalse(try fixture.outlet("lblBottomMessage", as: UILabel.self).text?.contains("try again") ?? true)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)

        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("update"))
        try await eventually { fixture.delegate.callbackCount == 1 }

        XCTAssertEqual(fixture.delegate.response?.isSuccess(), false)
        XCTAssertEqual((fixture.delegate.response?.getData() as? StatusResponse)?.getStatusState(), .FAILED)
        XCTAssertEqual(fixture.delegate.errorCount, 0)
        XCTAssertTrue(fixture.delegate.resultArrivedAfterDismissal)
    }

    @MainActor
    func testRetryCancelsPreviousResultsFiveSecondDismissal() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":-2}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually {
            (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
        }
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        try await waitForPaymentMethods(fixture)

        // Cross the previous result's real timer deadline; no virtual lifecycle shortcut.
        try await Task.sleep(nanoseconds: 5_250_000_000)

        XCTAssertEqual(fixture.delegate.callbackCount, 0)
        XCTAssertNotNil(fixture.controller.presentingViewController)
        XCTAssertTrue(try fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden)
        XCTAssertEqual(fixture.network.requestPaths,
                       ["/pay/api/payment/v2/init", "/pay/order_status", "/pay/api/payment/v2/init"])
    }

    private var initializationData: Data {
        return Data("{\"status\":1,\"data\":{\"order\":{\"orderKey\":\"test-order\"},\"paymentMethods\":[]}}".utf8)
    }

    @MainActor
    private func waitForPaymentMethods(_ fixture: PaymentControllerFixture) async throws {
        try await eventually {
            fixture.network.requestPaths.contains("/pay/api/payment/v2/init") &&
                (try? fixture.outlet("tableView", as: UITableView.self).isHidden) == false &&
                (try? fixture.outlet("progressBar", as: UIActivityIndicatorView.self).isHidden) == true
        }
    }

    @MainActor
    private func makeFixture(configuration: PHPaymentConfiguration, api: SelectedAPI,
                             responses: [String: Result<Data, Error>]) throws -> PaymentControllerFixture {
        // Logic-only package runners have no application event loop for presentation.
        guard let application = UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication,
              application.delegate != nil else {
            throw XCTSkip("UI integration tests require the demoapp host. Run the payHereSDK-Tests scheme in payHereSDK.xcodeproj.")
        }
        let scene = try XCTUnwrap(application.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
                                  "The demoapp test host must connect its window scene before UI tests start")
        return try PaymentControllerFixture(configuration: configuration, api: api,
                                             responses: responses, windowScene: scene)
    }

    @MainActor
    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Expected controller state was not reached", file: file, line: line)
                throw URLError(.timedOut)
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

@MainActor
private final class PaymentControllerFixture {
    let controller: PHBottomViewController
    let delegate: RecordingPaymentDelegate
    let network: PaymentNetworkStub
    private let window: UIWindow
    private let presenter: UIViewController
    private let previousBaseURL: String?

    var alert: UIAlertController? { controller.presentedViewController as? UIAlertController }

    init(configuration: PHPaymentConfiguration, api: SelectedAPI,
         responses: [String: Result<Data, Error>], windowScene: UIWindowScene) throws {
        previousBaseURL = PHConfigs.BASE_URL
        network = PaymentNetworkStub(responses: responses)
        let presentationController = UIViewController()
        presenter = presentationController
        delegate = RecordingPaymentDelegate(isDismissed: { [weak presentationController] in presentationController?.presentedViewController == nil })
        let storyboard = UIStoryboard(name: "PayHere", bundle: Bundle.payHereBundle)
        controller = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "PHBottomViewController") as? PHBottomViewController)
        let request = PHInitialRequest(merchantID: "1210000", notifyURL: nil, firstName: "Test",
                                       lastName: "Customer", email: "test@example.invalid", phone: nil,
                                       address: nil, city: nil, country: nil, orderID: "test-order",
                                       itemsDescription: "Test", itemsMap: nil, currency: .LKR, amount: 10,
                                       deliveryAddress: nil, deliveryCity: nil, deliveryCountry: nil,
                                       custom1: nil, custom2: nil)
        request.api = api
        controller.initialRequest = request
        controller.isSandBoxEnabled = true
        controller.configuration = configuration
        controller.delegate = delegate
        controller.networkSession = network.makeSession()
        controller.modalPresentationStyle = .overFullScreen
        window = UIWindow(windowScene: windowScene)
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        presenter.present(controller, animated: false)
    }

    func outlet<T>(_ name: String, as type: T.Type) throws -> T {
        return try XCTUnwrap(controller.value(forKey: name) as? T)
    }

    func stop() async {
        controller.perform(NSSelectorFromString("btnCancelTapped"))
        // Let the controller cancel its timers and finish any in-progress dismissal.
        let deadline = Date().addingTimeInterval(2)
        while presenter.presentedViewController != nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        presenter.dismiss(animated: false)
        window.isHidden = true
        window.rootViewController = nil
        controller.networkSession.cancelAllRequests()
        network.unregister()
        PHConfigs.BASE_URL = previousBaseURL
    }
}

private final class RecordingPaymentDelegate: PHViewControllerDelegate {
    private let lock = NSLock()
    private let isDismissed: () -> Bool
    private var receivedResponse: PHResponse<Any>?
    private var responses = 0
    private var errors = 0
    private var callbacksOnMainThread = true
    private var dismissedBeforeResult = false

    init(isDismissed: @escaping () -> Bool) { self.isDismissed = isDismissed }
    var callbackCount: Int { locked { responses + errors } }
    var errorCount: Int { locked { errors } }
    var response: PHResponse<Any>? { locked { receivedResponse } }
    var allCallbacksOnMainThread: Bool { locked { callbacksOnMainThread } }
    var resultArrivedAfterDismissal: Bool { locked { dismissedBeforeResult } }

    func onResponseReceived(response: PHResponse<Any>?) {
        let onMain = Thread.isMainThread
        let dismissed = onMain && isDismissed()
        locked {
            receivedResponse = response
            responses += 1
            callbacksOnMainThread = callbacksOnMainThread && onMain
            dismissedBeforeResult = dismissed
        }
    }

    func onErrorReceived(error: Error) {
        let onMain = Thread.isMainThread
        let dismissed = onMain && isDismissed()
        locked {
            errors += 1
            callbacksOnMainThread = callbacksOnMainThread && onMain
            dismissedBeforeResult = dismissed
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class PaymentNetworkStub {
    let identifier = UUID().uuidString
    private let lock = NSLock()
    private let responses: [String: Result<Data, Error>]
    private var requests: [URLRequest] = []

    init(responses: [String: Result<Data, Error>]) { self.responses = responses }

    var requestPaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requests.compactMap { $0.url?.path }
    }

    func makeSession() -> Alamofire.Session {
        PaymentURLProtocol.register(self)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PaymentURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-PayHere-Test-ID": identifier]
        return Alamofire.Session(configuration: configuration)
    }

    func respond(to request: URLRequest) -> Result<Data, Error> {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        guard let response = responses[request.url?.path ?? ""] else {
            XCTFail("Unexpected SDK request: \(request.url?.path ?? "missing URL")")
            return .failure(URLError(.unsupportedURL))
        }
        return response
    }

    func unregister() { PaymentURLProtocol.unregister(identifier) }
}

private final class PaymentURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var stubs: [String: PaymentNetworkStub] = [:]

    static func register(_ stub: PaymentNetworkStub) {
        lock.lock()
        defer { lock.unlock() }
        stubs[stub.identifier] = stub
    }

    static func unregister(_ identifier: String) {
        lock.lock()
        defer { lock.unlock() }
        stubs.removeValue(forKey: identifier)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let stub = request.value(forHTTPHeaderField: "X-PayHere-Test-ID").flatMap { Self.stubs[$0] }
        Self.lock.unlock()
        guard let stub = stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch stub.respond(to: request) {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .success(let data):
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                                 headerFields: ["Content-Type": "application/json"]) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

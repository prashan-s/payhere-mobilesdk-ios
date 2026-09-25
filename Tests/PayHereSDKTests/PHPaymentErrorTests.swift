import XCTest
import UIKit
import Alamofire
@testable import PayHereSDK

final class PHPaymentErrorTests: XCTestCase {
    func testCannotContinueUsesGenericMessageWithoutServerMetadata() {
        let error = PHPaymentErrorMapper.paymentCannotContinue()

        XCTAssertEqual(error.reason.rawValue, "payment_cannot_continue")
        XCTAssertEqual(error.message, "We couldn’t continue this payment.")
        XCTAssertNil(error.serverMessage)
        XCTAssertNil(error.code)
    }

    func testDisplayMessageDoesNotRequireLocalizedErrorConformance() {
        let error = PHPaymentErrorMapper.paymentStatusUnavailable()
        let bridged: Error = error

        XCTAssertEqual(error.message, "We couldn’t confirm your payment status.")
        XCTAssertFalse(bridged is LocalizedError)
    }

    func testInvalidInitializationUsesInvalidResponseWithoutServerMetadata() {
        let error = PHPaymentErrorMapper.invalidInitializationResponse()

        XCTAssertEqual(error.reason, .invalidResponse)
        XCTAssertEqual(error.message, "We couldn’t confirm the payment details.")
        XCTAssertNil(error.serverMessage)
        XCTAssertNil(error.code)
    }

    func testServerMessagesArePreservedWithoutTrimmingOrReplacement() {
        for message in ["", " \t\n", "  Please use another card.\n", "ගෙවීම නැවත පරීක්ෂා කරන්න. 💳", "e\u{301}"] {
            let error = PHPaymentErrorMapper.serverRejected(message: message)

            XCTAssertEqual(Array(error.message.utf8), Array(message.utf8))
            XCTAssertEqual(error.serverMessage.map { Array($0.utf8) }, Array(message.utf8))
            XCTAssertEqual(error.code, 501)
            XCTAssertEqual(error.reason, .requestRejected)
        }
    }

    func testMissingServerMessageUsesSDKMessage() {
        let error = PHPaymentErrorMapper.serverRejected(message: nil)

        XCTAssertNil(error.serverMessage)
        XCTAssertEqual(error.code, 501)
        XCTAssertFalse(error.message.isEmpty)
    }

    func testTransportReasonsUseStructuredUnderlyingError() {
        let cases: [(URLError.Code, PHPaymentError.Reason)] = [
            (.notConnectedToInternet, .noInternet),
            (.networkConnectionLost, .connectionLost),
            (.timedOut, .requestTimedOut),
            (.cannotConnectToHost, .networkFailure)
        ]
        for (urlCode, expectedReason) in cases {
            let underlying = URLError(urlCode, userInfo: [NSLocalizedDescriptionKey: "Oparation cancelled!"])
            let transport = AFError.sessionTaskFailed(error: underlying)
            let error = PHPaymentErrorMapper.network(transport, responseCode: transport.responseCode, responseData: nil)

            XCTAssertEqual(error.reason, expectedReason)
            XCTAssertNil(error.code)
            XCTAssertNil(error.serverMessage)
        }
    }

    func testCancelledURLSessionRequestUsesGeneralNetworkFailure() {
        let transport = AFError.sessionTaskFailed(error: URLError(.cancelled))
        let error = PHPaymentErrorMapper.network(transport, responseCode: transport.responseCode, responseData: nil)

        XCTAssertEqual(error.reason, .networkFailure)
    }

    func testHTTPStatusesRemainSeparateFromReasons() {
        let cases: [(Int, PHPaymentError.Reason)] = [(401, .requestRejected), (503, .serviceUnavailable), (302, .invalidResponse)]
        for (status, expectedReason) in cases {
            let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: status))
            let error = PHPaymentErrorMapper.network(transport, responseCode: transport.responseCode, responseData: nil)

            XCTAssertEqual(error.reason, expectedReason)
            XCTAssertEqual(error.code, status)
            XCTAssertNil(error.serverMessage)
        }
    }

    func testRejectedRequestMessageDoesNotClaimThePaymentNeverStarted() {
        let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 403))
        let error = PHPaymentErrorMapper.network(transport, responseCode: transport.responseCode, responseData: nil)

        XCTAssertEqual(error.reason, .requestRejected)
        XCTAssertEqual(error.message, "We couldn’t complete this payment request.")
    }

    func testHTTPRejectionPreservesRecognizedServerMessages() throws {
        for status in [422, 503] {
            let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: status))
            for message in ["", " \t\n", "Please contact the merchant. 💳"] {
                let data = try JSONSerialization.data(withJSONObject: ["status": -19, "msg": message])
                let error = PHPaymentErrorMapper.network(transport, responseCode: transport.responseCode, responseData: data)

                XCTAssertEqual(error.serverMessage.map { Array($0.utf8) }, Array(message.utf8))
                XCTAssertEqual(Array(error.message.utf8), Array(message.utf8))
                XCTAssertEqual(error.code, status)
            }
        }
    }

    func testHTTPCodeIsPreservedRegardlessOfJSONStatus() throws {
        let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 503))
        for status in [-19, 0, 1, 401, 501] {
            let data = try JSONSerialization.data(withJSONObject: ["status": status])
            let error = PHPaymentErrorMapper.network(transport, responseCode: 503, responseData: data)

            XCTAssertEqual(error.code, 503)
        }
    }

    func testHTTPCodeDoesNotDependOnResponseBody() {
        let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 503))
        let payloads: [String?] = [nil, "{}", "{\"status\":null}", "{\"msg\":\"Unavailable\"}", "<html>Unavailable</html>"]
        for payload in payloads {
            let error = PHPaymentErrorMapper.network(transport, responseCode: 503,
                                                    responseData: payload.map { Data($0.utf8) })

            XCTAssertEqual(error.code, 503)
        }
    }

    func testSerializationFailurePreservesSuppliedHTTPCodeWhenAFErrorHasNone() {
        let transport = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
        XCTAssertNil(transport.responseCode)

        let error = PHPaymentErrorMapper.network(transport, responseCode: 200, responseData: Data())

        XCTAssertEqual(error.reason, .invalidResponse)
        XCTAssertEqual(error.code, 200)
        XCTAssertNil(error.serverMessage)
    }

    func testTransportFailureAfterHTTPHeadersPreservesResponseCodeAndConnectionReason() {
        let transport = AFError.sessionTaskFailed(error: URLError(.networkConnectionLost))
        let partialData = Data("{\"status\":-19,\"msg\":\"Incomplete server response\"}".utf8)

        for status in [200, 422, 503] {
            let error = PHPaymentErrorMapper.network(transport, responseCode: status, responseData: partialData)

            XCTAssertEqual(error.reason, .connectionLost)
            XCTAssertEqual(error.code, status)
            XCTAssertNil(error.serverMessage)
            XCTAssertFalse(error.message.contains("Incomplete server response"))
        }
    }

    func testGenericErrorsHaveNoCode() {
        let error = PHPaymentErrorMapper.sdk(reason: .invalidResponse, code: nil)
        let unavailable = PHPaymentErrorMapper.paymentStatusUnavailable()

        XCTAssertNil(error.code)
        XCTAssertNil(unavailable.code)
    }

    func testHTTPRejectionWithoutUsableServerMessageUsesSDKMessage() {
        let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 503))
        for payload in ["{\"status\":-19,\"msg\":null}", "{\"status\":-19}", "<html>Proxy unavailable</html>", "{\"msg\":123}"] {
            let error = PHPaymentErrorMapper.network(transport, responseCode: transport.responseCode, responseData: Data(payload.utf8))

            XCTAssertEqual(error.reason, .serviceUnavailable)
            XCTAssertNil(error.serverMessage)
            XCTAssertEqual(error.message, "The payment service is temporarily unavailable.")
        }
    }

    func testPartialTransportBodyAndNonErrorHTTPBodyDoNotBecomeServerMessages() {
        let data = Data("{\"status\":-19,\"msg\":\"Do not display this partial body\"}".utf8)
        let errors: [AFError] = [
            .sessionTaskFailed(error: URLError(.networkConnectionLost)),
            .responseValidationFailed(reason: .unacceptableStatusCode(code: 302))
        ]
        for transport in errors {
            let error = PHPaymentErrorMapper.network(transport, responseCode: transport.responseCode, responseData: data)

            XCTAssertNil(error.serverMessage)
            XCTAssertFalse(error.message.contains("partial body"))
        }
    }

    func testSubmissionRejectionWithoutPaymentURLPreservesServerMessageAndCode() {
        let message = "  This card cannot be used.\n"
        let error = PHPaymentErrorMapper.missingPaymentURL(status: -2, message: message)

        XCTAssertEqual(error.reason, .requestRejected)
        XCTAssertEqual(error.code, 401)
        XCTAssertEqual(Array(error.message.utf8), Array(message.utf8))
        XCTAssertEqual(error.serverMessage, message)
    }

    func testMissingPaymentURLDoesNotDisplaySuccessOrUnknownStatusTextAsAnError() {
        for status: Int? in [1, nil] {
            let error = PHPaymentErrorMapper.missingPaymentURL(status: status, message: "Success")

            XCTAssertEqual(error.reason, .invalidPaymentURL)
            XCTAssertEqual(error.code, 401)
            XCTAssertNil(error.serverMessage)
            XCTAssertEqual(error.message, "The payment page couldn’t be opened.")
        }
    }

    @MainActor
    func testControllerDoesNotRetainErrorDelegate() async {
        let typedController = PHBottomViewController()
        weak var typedDelegate: TypedErrorRecorder?
        do {
            let typed = TypedErrorRecorder()
            typedDelegate = typed
            typedController.delegate = typed
        }

        XCTAssertNil(typedDelegate)
        XCTAssertNil(typedController.delegate)
    }

    @MainActor
    func testInvalidMerchantPresentationDeliversTypedErrorWithoutPresenting() async {
        for merchantID: String? in [nil, "", " \t\n"] {
            let presenter = ErrorTestPresenter()
            let recorder = TypedErrorRecorder()

            PayHereSDK.present(from: presenter, withInitRequest: Self.makeRequest(merchantID: merchantID), delegate: recorder)

            XCTAssertEqual(presenter.presentationCount, 0)
            XCTAssertEqual(recorder.errors.count, 1)
            XCTAssertEqual(recorder.errors.first?.reason, .invalidMerchantID)
            XCTAssertEqual(recorder.errors.first?.code, 401)
            XCTAssertTrue(recorder.responses.isEmpty)
            XCTAssertTrue(recorder.allCallbacksOnMainThread)
        }
    }

    @MainActor
    func testInvalidAmountAndMissingCurrencyFailControllerValidation() async throws {
        let previousBaseURL = PHConfigs.BASE_URL
        defer { PHConfigs.BASE_URL = previousBaseURL }
        let cases: [(Double?, PHCurrency?, PHPaymentError.Reason)] = [
            (nil, .LKR, .invalidAmount),
            (0, .LKR, .invalidAmount),
            (-1, .LKR, .invalidAmount),
            (10, nil, .invalidCurrency)
        ]
        for (amount, currency, expectedReason) in cases {
            let presenter = ErrorTestPresenter()
            let recorder = TypedErrorRecorder()
            let request = Self.makeRequest(merchantID: "1210000", amount: amount, currency: currency)

            PayHereSDK.present(from: presenter, withInitRequest: request, delegate: recorder)
            let controller = try XCTUnwrap(presenter.lastPresentedController as? PHBottomViewController)
            controller.loadViewIfNeeded()
            controller.beginAppearanceTransition(true, animated: false)
            controller.endAppearanceTransition()

            let error = try XCTUnwrap(recorder.errors.first)
            XCTAssertEqual(recorder.errors.count, 1)
            XCTAssertEqual(error.reason, expectedReason)
            XCTAssertEqual(error.code, 401)
            XCTAssertEqual(error.message, "This payment couldn’t be started. - \(expectedReason.rawValue)")
            XCTAssertTrue(recorder.allCallbacksOnMainThread)
            XCTAssertTrue(recorder.responses.isEmpty)
        }
    }

    @MainActor
    func testBackgroundPresentationDeliversTypedErrorOnMainThread() async {
        let presenter = ErrorTestPresenter()
        let recorder = TypedErrorRecorder()
        let callback = expectation(description: "Typed callback from a background presentation request")
        recorder.onTypedError = { callback.fulfill() }
        DispatchQueue.global().async {
            PayHereSDK.present(from: presenter, withInitRequest: Self.makeRequest(merchantID: nil), delegate: recorder)
        }
        await fulfillment(of: [callback], timeout: 5)

        XCTAssertTrue(recorder.allCallbacksOnMainThread)
        XCTAssertEqual(recorder.errors.count, 1)
        XCTAssertTrue(recorder.responses.isEmpty)
        XCTAssertEqual(presenter.presentationCount, 0)
    }

    @MainActor
    func testBackgroundPreflightRetainsDelegateUntilQueuedCallbackCompletes() async {
        let presenter = ErrorTestPresenter()
        let callback = expectation(description: "Typed preflight callback")
        let released = expectation(description: "Temporary delegate released after callback")
        let scheduled = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            var delegate: TemporaryErrorDelegate? = TemporaryErrorDelegate(
                onError: { error in
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(error.code, 401)
                    XCTAssertEqual(error.reason, .invalidMerchantID)
                    callback.fulfill()
                },
                onRelease: { released.fulfill() })
            PayHereSDK.present(from: presenter, withInitRequest: Self.makeRequest(merchantID: nil), delegate: delegate!)
            delegate = nil
            scheduled.signal()
        }
        // Keep queued main work pending until the background caller releases its reference.
        XCTAssertEqual(scheduled.wait(timeout: .now() + 5), .success)
        await fulfillment(of: [callback, released], timeout: 5, enforceOrder: true)

        XCTAssertEqual(presenter.presentationCount, 0)
    }

    private static func makeRequest(merchantID: String?) -> PHInitialRequest {
        return makeRequest(merchantID: merchantID, amount: 10, currency: .LKR)
    }

    private static func makeRequest(merchantID: String?, amount: Double?, currency: PHCurrency?) -> PHInitialRequest {
        return PHInitialRequest(merchantID: merchantID, notifyURL: nil, firstName: nil,
                                lastName: nil, email: nil, phone: nil, address: nil,
                                city: nil, country: nil, orderID: nil, itemsDescription: nil,
                                itemsMap: nil, currency: currency, amount: amount, deliveryAddress: nil,
                                deliveryCity: nil, deliveryCountry: nil, custom1: nil, custom2: nil)
    }
}

private final class TemporaryErrorDelegate: PayHereSDKDelegate {
    private let onError: @Sendable (PHPaymentError) -> Void
    private let onRelease: @Sendable () -> Void

    init(onError: @escaping @Sendable (PHPaymentError) -> Void, onRelease: @escaping @Sendable () -> Void) {
        self.onError = onError
        self.onRelease = onRelease
    }

    deinit { onRelease() }
    func payHereSDK(didReceive response: PHResponse<Any>) { XCTFail("Expected the typed error callback") }
    func payHereSDK(didFailWith error: PHPaymentError) { onError(error) }
}

// All mutable state is locked, including the callback shared with the background-presentation test.
private final class TypedErrorRecorder: PayHereSDKDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var receivedErrors: [PHPaymentError] = []
    private var receivedResponses: [PHResponse<Any>] = []
    private var callbacksOnMainThread = true
    private var callback: (@Sendable () -> Void)?
    var errors: [PHPaymentError] { locked { receivedErrors } }
    var responses: [PHResponse<Any>] { locked { receivedResponses } }
    var allCallbacksOnMainThread: Bool { locked { callbacksOnMainThread } }
    var onTypedError: (@Sendable () -> Void)? {
        get { locked { callback } }
        set { locked { callback = newValue } }
    }

    func payHereSDK(didReceive response: PHResponse<Any>) {
        locked {
            receivedResponses.append(response)
            callbacksOnMainThread = callbacksOnMainThread && Thread.isMainThread
        }
    }

    func payHereSDK(didFailWith error: PHPaymentError) {
        let completion = locked {
            receivedErrors.append(error)
            callbacksOnMainThread = callbacksOnMainThread && Thread.isMainThread
            return callback
        }
        completion?()
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class ErrorTestPresenter: UIViewController {
    private(set) var presentationCount = 0
    private(set) var lastPresentedController: UIViewController?

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                          completion: (() -> Void)? = nil) {
        presentationCount += 1
        lastPresentedController = viewControllerToPresent
        completion?()
    }
}

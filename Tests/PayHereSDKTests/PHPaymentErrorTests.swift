import XCTest
import UIKit
import Alamofire
@testable import PayHereSDK

final class PHPaymentErrorTests: XCTestCase {
    func testCannotContinueUsesGenericMessageWithoutServerOrLegacyMetadata() {
        for stage: PHPaymentError.Stage in [.submission, .paymentPage] {
            let error = PHPaymentErrorMapper.paymentCannotContinue(stage: stage)

            XCTAssertEqual(error.code.rawValue, "payment_cannot_continue")
            XCTAssertEqual(error.category, .service)
            XCTAssertEqual(error.stage, stage)
            XCTAssertEqual(error.message, "We couldn’t continue this payment. Please contact the merchant to check your payment status.")
            XCTAssertEqual(error.localizedDescription, error.message)
            XCTAssertNil(error.serverMessage)
            XCTAssertNil(error.serverStatusCode)
            XCTAssertNil(error.httpStatusCode)
            XCTAssertNil(error.legacyError)
        }
    }

    func testInvalidInitializationUsesInvalidResponseWithoutServerOrLegacyMetadata() {
        let error = PHPaymentErrorMapper.invalidInitializationResponse()

        XCTAssertEqual(error.code, .invalidResponse)
        XCTAssertEqual(error.category, .service)
        XCTAssertEqual(error.stage, .initialization)
        XCTAssertEqual(error.message, "We couldn’t confirm the payment details. Please contact the merchant to check your payment status.")
        XCTAssertEqual(error.localizedDescription, error.message)
        XCTAssertNil(error.serverMessage)
        XCTAssertNil(error.serverStatusCode)
        XCTAssertNil(error.httpStatusCode)
        XCTAssertNil(error.legacyError)
    }

    func testUserClosureAndIntegrationFailuresRemainDistinctWithIdenticalLegacyCodes() {
        let legacy = NSError(domain: "", code: 401, userInfo: [:])
        let closed = PHPaymentErrorMapper.sdk(code: .checkoutClosed, stage: .paymentPage, legacyError: legacy)
        let invalid = PHPaymentErrorMapper.sdk(code: .invalidAmount, stage: .initialization, legacyError: legacy)

        XCTAssertEqual(closed.code.rawValue, "checkout_closed")
        XCTAssertEqual(closed.category, .userAction)
        XCTAssertEqual(invalid.code.rawValue, "invalid_amount")
        XCTAssertEqual(invalid.category, .integration)
        XCTAssertNotEqual(closed.message, invalid.message)
    }

    func testServerMessagesArePreservedWithoutTrimmingOrReplacement() throws {
        for message in ["", " \t\n", "  Please use another card.\n", "ගෙවීම නැවත පරීක්ෂා කරන්න. 💳", "e\u{301}"] {
            let error = PHPaymentErrorMapper.serverRejected(status: -17, message: message, stage: .initialization)

            XCTAssertEqual(Array(error.message.utf8), Array(message.utf8))
            XCTAssertEqual(error.serverMessage.map { Array($0.utf8) }, Array(message.utf8))
            XCTAssertEqual(error.errorDescription.map { Array($0.utf8) }, Array(message.utf8))
            XCTAssertEqual(Array(error.localizedDescription.utf8), Array(message.utf8))
            XCTAssertEqual(error.serverStatusCode, -17)
            XCTAssertEqual(error.code, .requestRejected)
            XCTAssertEqual(error.stage, .initialization)
            XCTAssertNil(error.httpStatusCode)
            XCTAssertEqual(error.category, .service)
            let legacy = try XCTUnwrap(error.legacyError) as NSError
            XCTAssertEqual(legacy.domain, "")
            XCTAssertEqual(legacy.code, 501)
            XCTAssertEqual(Array(legacy.localizedDescription.utf8), Array(message.utf8))
        }
    }

    func testMissingServerMessageUsesUXTextWithoutChangingLegacyEmptyDescription() {
        let error = PHPaymentErrorMapper.serverRejected(status: nil, message: nil, stage: .initialization)

        XCTAssertNil(error.serverMessage)
        XCTAssertNil(error.serverStatusCode)
        XCTAssertFalse(error.message.isEmpty)
        XCTAssertEqual(error.message, error.localizedDescription)
        XCTAssertEqual((error.legacyError as NSError?)?.localizedDescription, "")
    }

    func testDecodingDiagnosticTextDoesNotLeakIntoDisplayMessage() throws {
        do {
            _ = try JSONDecoder().decode(PHInitResponse.self, from: Data("{\"status\":\"not-an-integer\"}".utf8))
            XCTFail("An invalid response must fail decoding")
        } catch let original as DecodingError {
            let error = PHPaymentErrorMapper.sdk(code: .invalidResponse, stage: .initialization,
                                                legacyError: original)

            XCTAssertEqual(error.category, .service)
            XCTAssertEqual(error.message, "We couldn’t confirm the payment details. Please contact the merchant to check your payment status.")
            XCTAssertNil(error.serverMessage)
            guard case .typeMismatch(let originalType, let originalContext) = original,
                  case .typeMismatch(let deliveredType, let deliveredContext) = try XCTUnwrap(error.legacyError as? DecodingError) else {
                return XCTFail("The original decoding failure must be retained")
            }
            XCTAssertTrue(originalType == deliveredType)
            XCTAssertEqual(originalContext.debugDescription, deliveredContext.debugDescription)
            XCTAssertEqual(originalContext.codingPath.map(\.stringValue), ["status"])
            XCTAssertEqual(originalContext.codingPath.map(\.stringValue), deliveredContext.codingPath.map(\.stringValue))
            XCTAssertFalse(error.message.contains(originalContext.debugDescription))
        }
    }

    func testTransportReasonsUseStructuredUnderlyingError() {
        let cases: [(URLError.Code, PHPaymentError.Code)] = [
            (.notConnectedToInternet, .noInternet),
            (.networkConnectionLost, .connectionLost),
            (.timedOut, .requestTimedOut),
            (.cannotConnectToHost, .networkFailure)
        ]
        for (urlCode, expectedCode) in cases {
            let underlying = URLError(urlCode, userInfo: [NSLocalizedDescriptionKey: "Oparation cancelled!"])
            let transport = AFError.sessionTaskFailed(error: underlying)
            let error = PHPaymentErrorMapper.network(transport, stage: .submission, responseData: nil)

            XCTAssertEqual(error.code, expectedCode)
            XCTAssertEqual(error.category, .connectivity)
            XCTAssertEqual(error.stage, .submission)
            XCTAssertNil(error.serverMessage)
            XCTAssertNil(error.httpStatusCode)
            XCTAssertEqual((error.legacyError as NSError?)?.code, 0)
            XCTAssertEqual((error.legacyError as NSError?)?.localizedDescription, transport.errorDescription)
        }
    }

    func testCancelledURLSessionRequestUsesGeneralNetworkFailure() {
        let transport = AFError.sessionTaskFailed(error: URLError(.cancelled))
        let error = PHPaymentErrorMapper.network(transport, stage: .submission, responseData: nil)

        XCTAssertEqual(error.code, .networkFailure)
        XCTAssertEqual(error.category, .connectivity)
        XCTAssertNotEqual(error.category, .userAction)
    }

    func testHTTPStatusesRemainSeparateFromSDKCodesAndLegacyPayloadIsPreserved() throws {
        let cases: [(Int, PHPaymentError.Code)] = [(401, .requestRejected), (503, .serviceUnavailable), (302, .invalidResponse)]
        for (status, expectedCode) in cases {
            let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: status))
            let error = PHPaymentErrorMapper.network(transport, stage: .initialization, responseData: nil)

            XCTAssertEqual(error.code, expectedCode)
            XCTAssertEqual(error.category, .service)
            XCTAssertEqual(error.httpStatusCode, status)
            XCTAssertNil(error.serverStatusCode)
            XCTAssertNil(error.serverMessage)
            let legacy = try XCTUnwrap(error.legacyError) as NSError
            XCTAssertEqual(legacy.domain, "")
            XCTAssertEqual(legacy.code, status)
            XCTAssertEqual(legacy.localizedDescription, transport.errorDescription)
        }
    }

    func testRejectedSubmissionMessageDoesNotClaimThePaymentNeverStarted() {
        let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 403))
        let initialization = PHPaymentErrorMapper.network(transport, stage: .initialization, responseData: nil)
        let submission = PHPaymentErrorMapper.network(transport, stage: .submission, responseData: nil)

        XCTAssertEqual(initialization.code, .requestRejected)
        XCTAssertEqual(submission.code, .requestRejected)
        XCTAssertEqual(initialization.message, "We couldn’t start this payment. Please contact the merchant.")
        XCTAssertEqual(submission.message, "We couldn’t complete this payment request. Please contact the merchant to check your payment status.")
    }

    func testHTTPRejectionPreservesRecognizedServerMessagesAndLegacyHTTPDescription() throws {
        for status in [422, 503] {
            let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: status))
            for message in ["", " \t\n", "Please contact the merchant. 💳"] {
                let data = try JSONSerialization.data(withJSONObject: ["status": -19, "msg": message])
                let error = PHPaymentErrorMapper.network(transport, stage: .submission, responseData: data)

                XCTAssertEqual(error.serverMessage.map { Array($0.utf8) }, Array(message.utf8))
                XCTAssertEqual(Array(error.message.utf8), Array(message.utf8))
                XCTAssertEqual(error.serverStatusCode, -19)
                XCTAssertEqual(error.httpStatusCode, status)
                XCTAssertEqual((error.legacyError as NSError?)?.code, status)
                XCTAssertEqual((error.legacyError as NSError?)?.localizedDescription, transport.errorDescription)
            }
        }
    }

    func testHTTPRejectionWithoutUsableServerMessageUsesSDKMessage() {
        let transport = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 503))
        for payload in ["{\"status\":-19,\"msg\":null}", "{\"status\":-19}", "<html>Proxy unavailable</html>", "{\"msg\":123}"] {
            let error = PHPaymentErrorMapper.network(transport, stage: .submission, responseData: Data(payload.utf8))

            XCTAssertEqual(error.code, .serviceUnavailable)
            XCTAssertNil(error.serverMessage)
            XCTAssertEqual(error.message, "The payment service is temporarily unavailable. Please check your payment status before trying again.")
        }
    }

    func testPartialTransportBodyAndNonErrorHTTPBodyDoNotBecomeServerMessages() {
        let data = Data("{\"status\":-19,\"msg\":\"Do not display this partial body\"}".utf8)
        let errors: [AFError] = [
            .sessionTaskFailed(error: URLError(.networkConnectionLost)),
            .responseValidationFailed(reason: .unacceptableStatusCode(code: 302))
        ]
        for transport in errors {
            let error = PHPaymentErrorMapper.network(transport, stage: .submission, responseData: data)

            XCTAssertNil(error.serverMessage)
            XCTAssertNil(error.serverStatusCode)
            XCTAssertFalse(error.message.contains("partial body"))
        }
    }

    func testSubmissionRejectionWithoutPaymentURLPreservesServerMessageAndLegacyURLError() {
        let message = "  This card cannot be used.\n"
        let error = PHPaymentErrorMapper.missingPaymentURL(status: -2, message: message, stage: .submission)

        XCTAssertEqual(error.code, .requestRejected)
        XCTAssertEqual(error.category, .service)
        XCTAssertEqual(error.stage, .submission)
        XCTAssertEqual(error.serverStatusCode, -2)
        XCTAssertEqual(Array(error.message.utf8), Array(message.utf8))
        XCTAssertEqual(error.serverMessage, message)
        XCTAssertEqual((error.legacyError as NSError?)?.domain, "")
        XCTAssertEqual((error.legacyError as NSError?)?.code, 401)
        XCTAssertEqual((error.legacyError as NSError?)?.localizedDescription, "Invalid URL")
    }

    func testMissingPaymentURLDoesNotDisplaySuccessOrUnknownStatusTextAsAnError() {
        for status: Int? in [1, nil] {
            let error = PHPaymentErrorMapper.missingPaymentURL(status: status, message: "Success", stage: .submission)

            XCTAssertEqual(error.code, .invalidPaymentURL)
            XCTAssertNil(error.serverMessage)
            XCTAssertEqual(error.message, "The payment page couldn’t be opened.")
            XCTAssertEqual((error.legacyError as NSError?)?.localizedDescription, "Invalid URL")
        }
    }

    @MainActor
    func testDeprecatedFallbackDeliversOriginalNSErrorInstanceExactlyOnce() async throws {
        let original = NSError(domain: "provider", code: 912,
                               userInfo: [NSLocalizedDescriptionKey: "original", "providerPayload": "unchanged"])
        let error = PHPaymentErrorMapper.sdk(code: .invalidResponse, stage: .initialization, legacyError: original)
        let recorder = LegacyErrorRecorder()
        let delegate: PayHereSDKDelegate = recorder

        delegate.payHereSDK(didFailWith: error)

        XCTAssertEqual(recorder.errors.count, 1)
        let delivered = try XCTUnwrap(recorder.errors.first) as NSError
        XCTAssertTrue(delivered === original)
        XCTAssertEqual(delivered.userInfo["providerPayload"] as? String, "unchanged")
    }

    @MainActor
    func testDeprecatedFallbackPreservesDecodingErrorTypeAndContext() async throws {
        let original = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Original parser context"))
        let error = PHPaymentErrorMapper.sdk(code: .invalidResponse, stage: .submission, legacyError: original)
        let recorder = LegacyErrorRecorder()
        let delegate: PayHereSDKDelegate = recorder

        delegate.payHereSDK(didFailWith: error)

        let delivered = try XCTUnwrap(recorder.errors.first)
        guard case DecodingError.dataCorrupted(let context) = delivered else {
            return XCTFail("Legacy delegates must receive the original decoding error")
        }
        XCTAssertEqual(context.debugDescription, "Original parser context")
        XCTAssertTrue(context.codingPath.isEmpty)
    }

    @MainActor
    func testStatusUnavailableUsesTypedErrorForDeprecatedFallback() async throws {
        let error = PHPaymentErrorMapper.paymentStatusUnavailable()
        let recorder = LegacyErrorRecorder()
        let delegate: PayHereSDKDelegate = recorder

        delegate.payHereSDK(didFailWith: error)

        XCTAssertEqual(error.code, .paymentStatusUnavailable)
        XCTAssertEqual(error.category, .service)
        XCTAssertEqual(error.stage, .statusCheck)
        XCTAssertNil(error.legacyError)
        XCTAssertNil(error.serverMessage)
        XCTAssertFalse(error.message.isEmpty)
        XCTAssertTrue(recorder.responses.isEmpty)
        XCTAssertEqual(recorder.errors.count, 1)
        let delivered = try XCTUnwrap(recorder.errors.first as? PHPaymentError)
        XCTAssertEqual(delivered.code, .paymentStatusUnavailable)
        XCTAssertEqual(delivered.stage, .statusCheck)
        XCTAssertNil(delivered.legacyError)
    }

    @MainActor
    func testCannotContinueAndInvalidInitializationUseTypedErrorsForDeprecatedFallback() async throws {
        let errors = [PHPaymentErrorMapper.paymentCannotContinue(stage: .paymentPage),
                      PHPaymentErrorMapper.invalidInitializationResponse()]
        for error in errors {
            let recorder = LegacyErrorRecorder()
            let delegate: PayHereSDKDelegate = recorder

            delegate.payHereSDK(didFailWith: error)

            XCTAssertEqual(recorder.errors.count, 1)
            XCTAssertTrue(recorder.responses.isEmpty)
            let delivered = try XCTUnwrap(recorder.errors.first as? PHPaymentError)
            XCTAssertEqual(delivered.code, error.code)
            XCTAssertEqual(delivered.stage, error.stage)
            XCTAssertEqual(delivered.message, error.message)
            XCTAssertNil(delivered.legacyError)
        }
    }

    @MainActor
    func testControllerDoesNotRetainTypedOrLegacyErrorDelegate() async {
        let typedController = PHBottomViewController()
        let legacyController = PHBottomViewController()
        weak var typedDelegate: TypedErrorRecorder?
        weak var legacyDelegate: LegacyErrorRecorder?
        do {
            let typed = TypedErrorRecorder()
            let legacy = LegacyErrorRecorder()
            typedDelegate = typed
            legacyDelegate = legacy
            typedController.delegate = typed
            legacyController.delegate = legacy
        }

        XCTAssertNil(typedDelegate)
        XCTAssertNil(legacyDelegate)
        XCTAssertNil(typedController.delegate)
        XCTAssertNil(legacyController.delegate)
    }

    @MainActor
    func testTypedPresentationDoesNotAlsoInvokeDeprecatedErrorHandler() async {
        let presenter = ErrorTestPresenter()
        let delegate = BothErrorHandlersRecorder()

        PayHereSDK.present(from: presenter, withInitRequest: Self.makeRequest(merchantID: nil), delegate: delegate)

        XCTAssertEqual(delegate.modernErrorCount, 1)
        XCTAssertEqual(delegate.modernResponseCount, 0)
        XCTAssertEqual(delegate.legacyErrorCount, 0)
    }

    @MainActor
    func testInvalidMerchantPresentationDeliversTypedIntegrationErrorWithoutPresenting() async {
        for merchantID: String? in [nil, "", " \t\n"] {
            let presenter = ErrorTestPresenter()
            let recorder = TypedErrorRecorder()

            PayHereSDK.present(from: presenter, withInitRequest: Self.makeRequest(merchantID: merchantID), delegate: recorder)

            XCTAssertEqual(presenter.presentationCount, 0)
            XCTAssertEqual(recorder.errors.count, 1)
            XCTAssertEqual(recorder.errors.first?.code, .invalidMerchantID)
            XCTAssertEqual(recorder.errors.first?.category, .integration)
            XCTAssertEqual(recorder.errors.first?.stage, .presentation)
            XCTAssertTrue(recorder.responses.isEmpty)
            XCTAssertTrue(recorder.allCallbacksOnMainThread)
        }
    }

    @MainActor
    func testInvalidMerchantPresentationPreservesLegacyPayload() async throws {
        let presenter = ErrorTestPresenter()
        let recorder = LegacyErrorRecorder()

        PayHereSDK.present(from: presenter, withInitRequest: Self.makeRequest(merchantID: nil), delegate: recorder)

        let error = try XCTUnwrap(recorder.errors.first) as NSError
        XCTAssertEqual(recorder.errors.count, 1)
        XCTAssertEqual(presenter.presentationCount, 0)
        XCTAssertEqual(error.domain, "")
        XCTAssertEqual(error.code, 401)
        XCTAssertEqual(error.localizedDescription, "Invalid merchant ID")
    }

    @MainActor
    func testInvalidAmountAndMissingCurrencyFailControllerValidation() async throws {
        let previousBaseURL = PHConfigs.BASE_URL
        defer { PHConfigs.BASE_URL = previousBaseURL }
        let cases: [(Double?, PHCurrency?, PHPaymentError.Code, String)] = [
            (nil, .LKR, .invalidAmount, "Invalid amount"),
            (0, .LKR, .invalidAmount, "Invalid amount"),
            (-1, .LKR, .invalidAmount, "Invalid amount"),
            (10, nil, .invalidCurrency, "Invalid currency")
        ]
        for (amount, currency, expectedCode, legacyMessage) in cases {
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
            XCTAssertEqual(error.code, expectedCode)
            XCTAssertEqual(error.category, .integration)
            XCTAssertEqual(error.stage, .initialization)
            XCTAssertEqual(error.message, "This payment couldn’t be started. Please contact the merchant.")
            XCTAssertEqual((error.legacyError as NSError?)?.code, 401)
            XCTAssertEqual((error.legacyError as NSError?)?.localizedDescription, legacyMessage)
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
    func testLegacyBackgroundPreflightRetainsDelegateUntilQueuedCallbackCompletes() async {
        let presenter = ErrorTestPresenter()
        let callback = expectation(description: "Legacy preflight callback")
        let released = expectation(description: "Temporary legacy delegate released after callback")
        let scheduled = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            var delegate: TemporaryLegacyErrorDelegate? = TemporaryLegacyErrorDelegate(
                onError: { error in
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual((error as NSError).code, 401)
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

private final class LegacyErrorRecorder: PayHereSDKDelegate {
    private(set) var errors: [Error] = []
    private(set) var responses: [PHResponse<Any>] = []

    func payHereSDK(didReceive response: PHResponse<Any>) { responses.append(response) }
    func onErrorReceived(error: Error) { errors.append(error) }
}

private final class TemporaryLegacyErrorDelegate: PayHereSDKDelegate {
    private let onError: @Sendable (Error) -> Void
    private let onRelease: @Sendable () -> Void

    init(onError: @escaping @Sendable (Error) -> Void, onRelease: @escaping @Sendable () -> Void) {
        self.onError = onError
        self.onRelease = onRelease
    }

    deinit { onRelease() }
    func payHereSDK(didReceive response: PHResponse<Any>) { XCTFail("Expected the deprecated error callback") }
    func onErrorReceived(error: Error) { onError(error) }
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

    func onErrorReceived(error: Error) {
        XCTFail("The typed error handler must exclusively receive payment errors")
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class BothErrorHandlersRecorder: PayHereSDKDelegate {
    private(set) var modernErrorCount = 0
    private(set) var modernResponseCount = 0
    private(set) var legacyErrorCount = 0

    func payHereSDK(didReceive response: PHResponse<Any>) {
        modernResponseCount += 1
    }
    func payHereSDK(didFailWith error: PHPaymentError) {
        modernErrorCount += 1
    }
    func onErrorReceived(error: Error) { legacyErrorCount += 1 }
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

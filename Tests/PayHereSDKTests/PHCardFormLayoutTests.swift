import XCTest
import WebKit
@testable import PayHereSDK

@MainActor
final class PHCardFormLayoutTests: XCTestCase {
    private let legacyFields = """
    <input id="cardHolderName"><input id="cardNo">
    <input id="cardSecureId"><input id="cardExpiry">
    """
    private let currentFields = """
    <input id="cardholder-name"><input id="card-number"><input id="cardSecureId">
    <select id="expiry-month"><option>01</option></select>
    <select id="expiry-year"><option>2030</option></select>
    """
    private let payButton = "<button id=\"payButton\" class=\"btn-primary\" type=\"submit\">Pay</button>"

    func testBothCardFormsMatchWithoutDependingOnHostOrPath() async throws {
        for fields in [legacyFields, currentFields] {
            let webView = makeWebView()
            try await load(form(fields: fields, footer: payButton), in: webView)

            let matched = try await evaluate("""
            document.querySelector('.container').style.getPropertyValue('height') === 'auto' &&
            document.querySelector('.container').style.getPropertyPriority('height') === 'important' &&
            document.querySelector('.container').hasAttribute('data-payhere-sdk-card-form') &&
            document.querySelector('#payButton').hasAttribute('data-payhere-sdk-card-submit')
            """, in: webView)
            XCTAssertEqual(matched as? Bool, true)
        }
    }

    func testNonmatchingPagesRemainUnchanged() async throws {
        let candidates = [
            form(fields: "<input id=\"otp\">", footer: payButton),
            form(fields: legacyFields.replacingOccurrences(of: "<input", with: "<input type=\"hidden\""), footer: payButton),
            form(fields: legacyFields.replacingOccurrences(of: "<input id=\"cardSecureId\">", with: ""), footer: payButton),
            form(fields: "<div id=\"cardHolderName\"></div><div id=\"cardNo\"></div><div id=\"cardSecureId\"></div><div id=\"cardExpiry\"></div>", footer: payButton),
            form(fields: legacyFields, footer: ""),
            form(fields: legacyFields, footer: payButton.replacingOccurrences(of: "submit", with: "button")),
            form(fields: legacyFields, footer: payButton.replacingOccurrences(of: "<button", with: "<button hidden")),
            form(fields: legacyFields, footer: payButton).replacingOccurrences(of: "id=\"paymentForm\"", with: "id=\"paymentForm\" style=\"display:none\""),
            form(fields: legacyFields, footer: payButton).replacingOccurrences(of: "paymentForm", with: "otherForm"),
            form(fields: legacyFields, footer: payButton).replacingOccurrences(of: "container", with: "other-layout"),
            form(fields: legacyFields, footer: payButton) + form(fields: currentFields, footer: payButton),
            "<div class=\"container\"><p>Payment complete</p></div>"
        ]
        let webView = makeWebView()
        for (index, body) in candidates.enumerated() {
            try await load(body, in: webView)
            let unchanged = try await evaluate("document.body.innerHTML === window.fixtureBefore", in: webView)
            XCTAssertEqual(unchanged as? Bool, true, "Nonmatching fixture \(index) was modified")
        }
    }

    func testFieldsAndSubmitButtonMustBelongToPaymentForm() async throws {
        let otherForm = "<form id=\"otherForm\"></form>"
        let candidates = [
            form(fields: legacyFields.replacingOccurrences(of: "<input", with: "<input form=\"otherForm\""), footer: payButton) + otherForm,
            form(fields: legacyFields, footer: payButton.replacingOccurrences(of: "<button", with: "<button form=\"otherForm\"")) + otherForm
        ]
        let webView = makeWebView()
        for body in candidates {
            try await load(body, in: webView)
            let unchanged = try await evaluate("document.body.innerHTML === window.fixtureBefore", in: webView)
            XCTAssertEqual(unchanged as? Bool, true)
        }
    }

    func testLayoutIsIdempotentAndPreservesFormControlsAndSubmission() async throws {
        let webView = makeWebView()
        try await load(form(fields: legacyFields, footer: payButton), in: webView)
        let original = try await evaluate("document.body.innerHTML", in: webView) as? String
        _ = try await evaluate(PHWebViewScripts.cardFormLayout, in: webView)
        let repeated = try await evaluate("document.body.innerHTML", in: webView) as? String
        XCTAssertNotNil(original)
        XCTAssertEqual(original, repeated)

        let preserved = try await evaluate("""
        (() => {
            const fields = Array.from(document.querySelectorAll('input, select')).map(field => field.outerHTML);
            const form = document.querySelector('#paymentForm');
            const prevented = !form.dispatchEvent(new Event('submit', {cancelable: true}));
            return JSON.stringify(fields) === window.fixtureFields && prevented && window.fixtureSubmissions === 1;
        })();
        """, in: webView)
        XCTAssertEqual(preserved as? Bool, true)
    }

    func testOnlyEmptyRaisedButtonFooterIsCollapsed() async throws {
        let raisedButton = payButton.replacingOccurrences(of: "<button", with: "<button style=\"transform:translateY(-60px)\"")
        let webView = makeWebView()
        try await load(form(fields: legacyFields, footer: raisedButton), in: webView)
        let collapsed = try await evaluate("""
        document.querySelector('.form-group').style.getPropertyValue('height') === 'auto' &&
        document.querySelector('.form-group').style.getPropertyValue('margin-bottom') === '0px'
        """, in: webView)
        XCTAssertEqual(collapsed as? Bool, true)

        try await load(form(fields: currentFields, footer: raisedButton + "<p>Keep this notice</p>"), in: webView)
        let retained = try await evaluate("""
        document.querySelector('.form-group').style.getPropertyValue('height') === '100px' &&
        document.querySelector('.form-group').style.getPropertyValue('margin-bottom') === '20px'
        """, in: webView)
        XCTAssertEqual(retained as? Bool, true)
    }

    func testMatchingCardFormInsideIframeIsNotModified() async throws {
        let embedded = form(fields: legacyFields, footer: payButton)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let webView = makeWebView()
        try await load("<iframe srcdoc=\"\(embedded)\"></iframe>", in: webView)
        let untouched = try await evaluate("""
        (() => {
            const frame = document.querySelector('iframe').contentDocument;
            return frame.querySelector('#paymentForm') !== null &&
                !frame.querySelector('[data-payhere-sdk-card-form]') &&
                !document.querySelector('[data-payhere-sdk-card-form]');
        })();
        """, in: webView)
        XCTAssertEqual(untouched as? Bool, true)
    }

    func testNavigationToChallengeDoesNotRetainCardFormMarkers() async throws {
        let webView = makeWebView()
        try await load(form(fields: legacyFields, footer: payButton), in: webView)
        let matched = try await evaluate("!!document.querySelector('[data-payhere-sdk-card-form]')", in: webView)
        XCTAssertEqual(matched as? Bool, true)

        try await load(form(fields: "<input id=\"otp\">", footer: payButton), in: webView)
        let unchanged = try await evaluate("document.body.innerHTML === window.fixtureBefore", in: webView)
        XCTAssertEqual(unchanged as? Bool, true)
    }

    private func form(fields: String, footer: String) -> String {
        return """
        <div class="container" style="height:1000px">
            <form id="paymentForm">
                \(fields)
                <div class="form-group" style="height:100px;margin-bottom:20px">\(footer)</div>
            </form>
        </div>
        """
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.addUserScript(WKUserScript(
            source: PHWebViewScripts.cardFormLayout,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        return WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
    }

    private func load(_ body: String, in webView: WKWebView) async throws {
        let observer = CardFormNavigationObserver(finished: expectation(description: "Fixture loaded"))
        webView.navigationDelegate = observer
        defer { webView.navigationDelegate = nil }
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body>\(body)<script>
            window.fixtureBefore = document.body.innerHTML;
            window.fixtureFields = JSON.stringify(Array.from(document.querySelectorAll('input, select')).map(field => field.outerHTML));
            window.fixtureSubmissions = 0;
            const fixtureForm = document.querySelector('#paymentForm');
            if (fixtureForm) fixtureForm.addEventListener('submit', event => {
                event.preventDefault();
                window.fixtureSubmissions += 1;
            });
        </script></body></html>
        """
        // HTML fixtures only: this origin and path are intentionally unrelated to PayHere.
        webView.loadHTMLString(html, baseURL: URL(string: "https://processor.example.invalid/redirect/checkout?fixture=1"))
        await fulfillment(of: [observer.finished], timeout: 10)
        if let error = observer.error { throw error }
    }

    private func evaluate(_ script: String, in webView: WKWebView) async throws -> Any? {
        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

@MainActor
private final class CardFormNavigationObserver: NSObject, WKNavigationDelegate {
    let finished: XCTestExpectation
    private(set) var error: Error?

    init(finished: XCTestExpectation) { self.finished = finished }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finished.fulfill()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.error = error
        finished.fulfill()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.error = error
        finished.fulfill()
    }
}

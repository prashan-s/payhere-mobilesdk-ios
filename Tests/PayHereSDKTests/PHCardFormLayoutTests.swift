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

    func testProviderIdentifiersStayEscapedInBothInjectedScripts() {
        let identifiers = ["paymentForm", "payButton", "cardHolderName", "cardNo", "cardSecureId", "cardExpiry",
                           "cardholder-name", "card-number", "expiry-month", "expiry-year", "scheme-logo", "declaration-text"]
        for script in [PHWebViewScripts.cardFormLayout, PHWebViewScripts.cardFormMeasurement] {
            XCTAssertFalse(script.contains("atob("))
            XCTAssertTrue(script.contains("\\x"), "JavaScript must receive the escapes, not Swift-decoded identifiers")
            for identifier in identifiers {
                XCTAssertFalse(script.contains(identifier), "Provider identifier must not appear literally: \(identifier)")
            }
        }
    }

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

        let result = try await evaluate(PHWebViewScripts.cardFormMeasurement, in: webView)
        let layout = try XCTUnwrap(result as? [String: Double])
        let noticeBottom = try await evaluate("""
        (() => {
            const range = document.createRange();
            range.selectNodeContents(document.querySelector('.form-group p'));
            return range.getBoundingClientRect().bottom + window.scrollY;
        })();
        """, in: webView)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(layout["height"]), try XCTUnwrap(noticeBottom as? Double))
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

    func testProviderFooterResizesWithoutLosingContentOrClippingMeasurement() async throws {
        let disclosure = "<small>Payment terms and card-scheme information. <a href=\"#terms\">Read terms</a></small>"
        for contents in ["", disclosure] {
            let webView = makeWebView()
            webView.frame.size.height = 200
            let body = form(fields: legacyFields, footer: payButton)
                .replacingOccurrences(of: "height:1000px", with: "height:840px") + providerFooter(contents)
            try await load(body, in: webView)

            let preserved = try await evaluate("""
            (() => {
                const footer = document.querySelector('body > .container + .container');
                return footer.style.height === 'auto' &&
                    footer.style.getPropertyPriority('height') === 'important' &&
                    footer.hasAttribute('data-payhere-sdk-card-footer') &&
                    footer.innerHTML === window.fixtureFooterContents;
            })();
            """, in: webView)
            XCTAssertEqual(preserved as? Bool, true)

            let result = try await evaluate(PHWebViewScripts.cardFormMeasurement, in: webView)
            let layout = try XCTUnwrap(result as? [String: Double])
            let measuredHeight = try XCTUnwrap(layout["height"])
            let geometryResult = try await evaluate("""
            (() => {
                const form = document.querySelector('body > .container');
                const footer = form.nextElementSibling;
                const range = document.createRange();
                range.selectNodeContents(footer.querySelector('.declaration-text'));
                const contentBottom = Math.max(footer.querySelector('img').getBoundingClientRect().bottom,
                                               range.getBoundingClientRect().bottom);
                return {formBottom:form.getBoundingClientRect().bottom,
                        contentBottom:Math.ceil(contentBottom + window.scrollY),
                        documentHeight:document.documentElement.scrollHeight};
            })();
            """, in: webView)
            let geometry = try XCTUnwrap(geometryResult as? [String: Double])
            XCTAssertEqual(measuredHeight, try XCTUnwrap(geometry["contentBottom"]), accuracy: 1)
            XCTAssertGreaterThan(measuredHeight, try XCTUnwrap(geometry["formBottom"]))
            XCTAssertLessThan(try XCTUnwrap(geometry["documentHeight"]), 840)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(layout["bottomSpacing"]), 0)

            let beforeRepeat = try await evaluate("document.body.innerHTML", in: webView) as? String
            _ = try await evaluate(PHWebViewScripts.cardFormLayout, in: webView)
            let afterRepeat = try await evaluate("document.body.innerHTML", in: webView) as? String
            XCTAssertNotNil(beforeRepeat)
            XCTAssertEqual(beforeRepeat, afterRepeat)
        }
    }

    func testUnrecognizedOrInteractiveSiblingContainerIsNotResized() async throws {
        let candidates = [
            providerFooter("<small>Terms</small>").replacingOccurrences(of: "scheme-logo", with: "other-logo"),
            providerFooter("<small>Terms</small>").replacingOccurrences(of: "declaration-text", with: "other-text"),
            providerFooter("<small>Terms</small>").replacingOccurrences(of: "</small>", with: "</small><input id=\"otp\">"),
            "<div class=\"container\" style=\"height:840px\">Unrelated content</div>"
        ]
        let webView = makeWebView()
        for footer in candidates {
            try await load(form(fields: currentFields, footer: payButton) + footer, in: webView)
            let unchanged = try await evaluate("""
            (() => {
                const footer = document.querySelector('body > .container + .container');
                return footer.style.height === '840px' &&
                    !footer.hasAttribute('data-payhere-sdk-card-footer') &&
                    footer.innerHTML === window.fixtureFooterContents;
            })();
            """, in: webView)
            XCTAssertEqual(unchanged as? Bool, true)
        }
    }

    func testProviderFooterOnNonCardPageRemainsUnchanged() async throws {
        let webView = makeWebView()
        try await load(form(fields: "<input id=\"otp\">", footer: payButton) + providerFooter(""), in: webView)
        let unchanged = try await evaluate("document.body.innerHTML === window.fixtureBefore", in: webView)
        XCTAssertEqual(unchanged as? Bool, true)
        let measurement = try await evaluate(PHWebViewScripts.cardFormMeasurement, in: webView)
        XCTAssertTrue(measurement == nil || measurement is NSNull)
    }

    func testSingleContainerMeasuresPayButtonFromDocumentRoot() async throws {
        let webView = makeWebView()
        webView.frame.size.height = 80
        try await load(form(fields: currentFields, footer: payButton), in: webView)
        try await waitForCommittedScrollPosition(0, in: webView)
        let result = try await evaluate(PHWebViewScripts.cardFormMeasurement, in: webView)
        let layout = try XCTUnwrap(result as? [String: Double])
        let expectedResult = try await evaluate("""
        (() => {
            const container = document.querySelector('body > .container');
            const buttonBounds = container.querySelector('#payButton').getBoundingClientRect();
            const height = Math.ceil(buttonBounds.bottom + window.scrollY);
            return {height, bottomSpacing:document.scrollingElement.scrollHeight - height};
        })();
        """, in: webView)
        let expected = try XCTUnwrap(expectedResult as? [String: Double])
        XCTAssertEqual(layout, expected)
        XCTAssertGreaterThan(try XCTUnwrap(layout["bottomSpacing"]), 20)
    }

    func testEmptyProviderFooterAndRootPaddingDoNotIncreaseContentHeight() async throws {
        let webView = makeWebView()
        let emptyFooter = providerFooter("").replacingOccurrences(of: "alt=\"Payment scheme\"", with: "src=\"\"")
        let body = """
        <style>body { margin:0; padding:32px 0 96px; } .container { padding-bottom:64px; }</style>
        \(form(fields: legacyFields, footer: payButton))\(emptyFooter)
        """
        var firstMeasurement: [String: Double]?
        for viewportHeight: CGFloat in [120, 1800] {
            webView.frame.size.height = viewportHeight
            try await load(body, in: webView)
            try await waitForCommittedScrollPosition(0, in: webView)
            let result = try await evaluate(PHWebViewScripts.cardFormMeasurement, in: webView)
            let layout = try XCTUnwrap(result as? [String: Double])
            let buttonBottom = try await evaluate("Math.ceil(document.querySelector('#payButton').getBoundingClientRect().bottom + window.scrollY)", in: webView)
            XCTAssertEqual(try XCTUnwrap(layout["height"]), try XCTUnwrap(buttonBottom as? Double), accuracy: 1)
            XCTAssertGreaterThan(try XCTUnwrap(layout["bottomSpacing"]), 200)

            if let firstMeasurement = firstMeasurement {
                XCTAssertEqual(layout, firstMeasurement, "Unused viewport height must not affect the document measurement")
            } else {
                firstMeasurement = layout
                let scroll = try await evaluate("window.scrollTo(0, 48); window.scrollY", in: webView)
                let scrollY = try XCTUnwrap(scroll as? Double)
                XCTAssertEqual(scrollY, 48)
                try await waitForCommittedScrollPosition(48, in: webView)
                let scrolledResult = try await evaluate(PHWebViewScripts.cardFormMeasurement, in: webView)
                let scrolledLayout = try XCTUnwrap(scrolledResult as? [String: Double])
                XCTAssertEqual(scrolledLayout, layout, "Root coordinates must not change with scrolling")
                let afterMeasurement = try await evaluate("window.scrollY", in: webView)
                XCTAssertEqual(try XCTUnwrap(afterMeasurement as? Double), scrollY, "Measuring must not reset the user's scroll position")
            }
        }
    }

    func testProviderPayButtonMarginBoxFitsNarrowAndWideCardForms() async throws {
        for viewportWidth: CGFloat in [320, 359, 375, 390, 540] {
            let webView = makeWebView()
            webView.frame.size = CGSize(width: viewportWidth, height: 220)
            try await load(providerWidthFixture, in: webView)
            try await waitForCommittedScrollPosition(0, in: webView)

            let result = try await evaluate("""
            (() => {
                const container = document.querySelector('[data-payhere-sdk-card-form]');
                const button = container.querySelector('#payButton');
                const buttonBounds = button.getBoundingClientRect();
                const buttonStyle = getComputedStyle(button);
                const parent = button.parentElement;
                const parentBounds = parent.getBoundingClientRect();
                const parentStyle = getComputedStyle(parent);
                const containerBounds = container.getBoundingClientRect();
                return {
                    viewportWidth:window.innerWidth,
                    documentWidth:document.scrollingElement.scrollWidth,
                    containerWidth:container.clientWidth,
                    containerScrollWidth:container.scrollWidth,
                    containerLeft:containerBounds.left,
                    containerRight:containerBounds.right,
                    buttonLeft:buttonBounds.left,
                    buttonRight:buttonBounds.right,
                    buttonWidth:buttonBounds.width,
                    marginBoxLeft:buttonBounds.left - parseFloat(buttonStyle.marginLeft),
                    marginBoxRight:buttonBounds.right + parseFloat(buttonStyle.marginRight),
                    parentContentLeft:parentBounds.left + parseFloat(parentStyle.borderLeftWidth) + parseFloat(parentStyle.paddingLeft),
                    parentContentRight:parentBounds.right - parseFloat(parentStyle.borderRightWidth) - parseFloat(parentStyle.paddingRight)
                };
            })();
            """, in: webView)
            let geometry = try XCTUnwrap(result as? [String: Double])
            XCTAssertEqual(try XCTUnwrap(geometry["viewportWidth"]), Double(viewportWidth), accuracy: 1)
            XCTAssertLessThanOrEqual(try XCTUnwrap(geometry["documentWidth"]), Double(viewportWidth) + 1)
            XCTAssertLessThanOrEqual(try XCTUnwrap(geometry["containerScrollWidth"]),
                                     try XCTUnwrap(geometry["containerWidth"]) + 1,
                                     "The recognized form must not hide overflowing Pay content at width \(viewportWidth)")
            XCTAssertGreaterThan(try XCTUnwrap(geometry["buttonWidth"]), 0)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(geometry["buttonLeft"]),
                                        try XCTUnwrap(geometry["containerLeft"]) - 1)
            XCTAssertLessThanOrEqual(try XCTUnwrap(geometry["buttonRight"]),
                                     try XCTUnwrap(geometry["containerRight"]) + 1)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(geometry["marginBoxLeft"]),
                                        try XCTUnwrap(geometry["parentContentLeft"]) - 1)
            XCTAssertLessThanOrEqual(try XCTUnwrap(geometry["marginBoxRight"]),
                                     try XCTUnwrap(geometry["parentContentRight"]) + 1,
                                     "Pay must fit together with both provider margins at width \(viewportWidth)")

            let preserved = try await evaluate("""
            (() => {
                const form = document.querySelector('#paymentForm');
                const fields = Array.from(form.querySelectorAll('input, select'));
                const footer = document.querySelector('[data-payhere-sdk-card-footer]');
                const prevented = !form.dispatchEvent(new Event('submit', {cancelable:true}));
                return JSON.stringify(fields.map(field => field.outerHTML)) === window.fixtureFields &&
                    fields.every(field => field.value === 'sample') &&
                    form.getAttribute('action') === '#receipt' && form.method === 'post' &&
                    prevented && window.fixtureSubmissions === 1 &&
                    footer.innerHTML === window.fixtureFooterContents &&
                    footer.querySelector('.declaration-text a').getAttribute('href') === '#terms';
            })();
            """, in: webView)
            XCTAssertEqual(preserved as? Bool, true, "Form and disclosure contracts must survive width normalization")
        }
    }

    func testMeasurementIncludesCollapsedBodyBottomMarginWithoutMutatingDocument() async throws {
        let webView = makeWebView()
        webView.frame.size.height = 120
        let body = """
        <style>body { margin:0 0 96px; padding:0; } input { display:block; height:40px; }</style>
        \(form(fields: legacyFields, footer: payButton))
        """
        try await load(body, in: webView)
        try await waitForCommittedScrollPosition(0, in: webView)
        let before = try await evaluate("document.documentElement.outerHTML", in: webView) as? String
        let result = try await evaluate(PHWebViewScripts.cardFormMeasurement, in: webView)
        let layout = try XCTUnwrap(result as? [String: Double])
        let geometryResult = try await evaluate("""
        ({documentHeight:document.scrollingElement.scrollHeight,
          bodyBottom:document.body.getBoundingClientRect().bottom + window.scrollY,
          buttonBottom:Math.ceil(document.querySelector('#payButton').getBoundingClientRect().bottom + window.scrollY),
          viewportHeight:window.innerHeight, scrollY:window.scrollY})
        """, in: webView)
        let geometry = try XCTUnwrap(geometryResult as? [String: Double])
        let documentHeight = try XCTUnwrap(geometry["documentHeight"])
        XCTAssertGreaterThan(documentHeight, try XCTUnwrap(geometry["viewportHeight"]))
        XCTAssertGreaterThan(documentHeight - (try XCTUnwrap(geometry["bodyBottom"])), 90,
                             "The fixture must expose the collapsed body margin outside its border box")
        XCTAssertEqual(try XCTUnwrap(layout["height"]), try XCTUnwrap(geometry["buttonBottom"]), accuracy: 1)
        XCTAssertEqual(try XCTUnwrap(layout["height"]) + (try XCTUnwrap(layout["bottomSpacing"])),
                       documentHeight, accuracy: 1,
                       "Measured content and removable tail must cover the complete scrolling extent")
        let after = try await evaluate("document.documentElement.outerHTML", in: webView) as? String
        XCTAssertNotNil(before)
        XCTAssertEqual(after, before, "Measurement must not rewrite root margins or provider markup")
        XCTAssertEqual(try XCTUnwrap(geometry["scrollY"]), 0)
    }

    func testPageMeasurementPreservesRecognizedCardHeightAndTail() async throws {
        let webView = makeWebView()
        for fields in [legacyFields, currentFields] {
            try await load(form(fields: fields, footer: payButton), in: webView)
            let originalResult = try await evaluate(PHWebViewScripts.cardFormMeasurement, in: webView)
            let original = try XCTUnwrap(originalResult as? [String: Double])
            let pageResult = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
            let page = try XCTUnwrap(pageResult as? [String: Any])
            XCTAssertEqual(page["kind"] as? String, "card")
            XCTAssertEqual(page["height"] as? Double, original["height"])
            XCTAssertEqual(page["bottomSpacing"] as? Double, original["bottomSpacing"])
            XCTAssertEqual(page["viewportFloorBottom"] as? Double, 0)
            XCTAssertFalse(try XCTUnwrap(page["documentID"] as? String).isEmpty)

            _ = try await evaluate("""
            window.fixtureLayoutMutations = 0;
            window.fixtureMutationObserver = new MutationObserver(records => {
                window.fixtureLayoutMutations += records.length;
            });
            window.fixtureMutationObserver.observe(document.documentElement, {
                childList:true, subtree:true, attributes:true, characterData:true
            });
            """, in: webView)
            for _ in 0..<3 {
                _ = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
            }
            let mutations = try await evaluate("window.fixtureLayoutMutations", in: webView)
            XCTAssertEqual(mutations as? Int, 0,
                           "Recognized card measurements must not repeat style writes or trigger DOM layout notifications")
        }
    }

    func testNonCardMeasurementIncludesTallFooterAndRejectsHiddenAncestors() async throws {
        let webView = makeWebView()
        webView.frame.size.height = 240
        try await load("""
        <style>body { margin:0; } p { margin:0; }</style>
        <p>Bank authentication</p>
        <footer style="margin-top:640px;visibility:hidden"><p id="notice" style="visibility:visible">Review the bank terms.</p></footer>
        <div style="position:absolute;top:4000px;opacity:0"><p>Hidden text</p><input></div>
        <div style="position:absolute;top:5000px;visibility:hidden"><button>Hidden ancestor</button></div>
        <div style="display:none"><p style="margin-top:6000px">Not rendered</p></div>
        """, in: webView)
        let before = try await evaluate("document.documentElement.outerHTML", in: webView) as? String
        let result = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
        let page = try XCTUnwrap(result as? [String: Any])
        let expectedResult = try await evaluate("""
        (() => {
            const range = document.createRange();
            range.selectNodeContents(document.querySelector('#notice'));
            return Math.ceil(range.getBoundingClientRect().bottom + window.scrollY);
        })();
        """, in: webView)
        XCTAssertEqual(page["kind"] as? String, "page")
        XCTAssertEqual(try XCTUnwrap(page["height"] as? Double), try XCTUnwrap(expectedResult as? Double), accuracy: 1)
        XCTAssertGreaterThan(try XCTUnwrap(page["height"] as? Double), 640)
        XCTAssertEqual(page["bottomSpacing"] as? Double, 0)
        let after = try await evaluate("document.documentElement.outerHTML", in: webView) as? String
        XCTAssertNotNil(before)
        XCTAssertEqual(after, before, "Generic measurement must not rewrite bank content")
    }

    func testPageMeasurementRecognizesCardControlsInsertedAfterLoad() async throws {
        let webView = makeWebView()
        try await load(form(fields: "", footer: payButton), in: webView)
        let initialResult = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
        let initial = try XCTUnwrap(initialResult as? [String: Any])
        XCTAssertEqual(initial["kind"] as? String, "page")
        let fieldsData = try JSONSerialization.data(withJSONObject: currentFields, options: .fragmentsAllowed)
        let encodedFields = try XCTUnwrap(String(data: fieldsData, encoding: .utf8))
        _ = try await evaluate("document.querySelector('#paymentForm').insertAdjacentHTML('afterbegin', \(encodedFields))", in: webView)
        let result = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
        let page = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(page["kind"] as? String, "card")
        let originalResult = try await evaluate(PHWebViewScripts.cardFormMeasurement, in: webView)
        let original = try XCTUnwrap(originalResult as? [String: Double])
        XCTAssertEqual(page["height"] as? Double, original["height"])
        XCTAssertEqual(page["bottomSpacing"] as? Double, original["bottomSpacing"])
        let before = try await evaluate("document.body.innerHTML", in: webView) as? String
        _ = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
        let after = try await evaluate("document.body.innerHTML", in: webView) as? String
        XCTAssertNotNil(before)
        XCTAssertEqual(after, before, "Repeated measurement must not rewrite a recognized form")
    }

    func testNonCardMeasurementIgnoresViewportFloorsAcrossRepeatedResizing() async throws {
        let webView = makeWebView()
        webView.frame.size.height = 120
        try await load("""
        <style>html, body, main { min-height:100vh; margin:0; } button { height:40px; margin-top:12px; }</style>
        <main><button>Verify</button></main><aside style="position:fixed;bottom:0"><button>Help</button></aside>
        """, in: webView)
        var documentID: String?
        for viewportHeight: CGFloat in [120, 700, 1800, 240] {
            webView.frame.size.height = viewportHeight
            try await waitForCommittedScrollPosition(0, in: webView)
            let result = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
            let page = try XCTUnwrap(result as? [String: Any])
            XCTAssertEqual(page["kind"] as? String, "page")
            XCTAssertEqual(try XCTUnwrap(page["height"] as? Double), 52, accuracy: 1)
            XCTAssertEqual(try XCTUnwrap(page["viewportHeight"] as? Double), Double(viewportHeight), accuracy: 1)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(page["documentHeight"] as? Double), Double(viewportHeight))
            if let documentID = documentID {
                XCTAssertEqual(page["documentID"] as? String, documentID)
            } else {
                documentID = try XCTUnwrap(page["documentID"] as? String)
            }
        }
        try await load("<style>body { margin:0; min-height:100vh; }</style>", in: webView)
        let emptyResult = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
        let emptyPage = try XCTUnwrap(emptyResult as? [String: Any])
        XCTAssertEqual(emptyPage["height"] as? Double, 0, "An empty page must be able to restore the payment baseline")
        XCTAssertNotEqual(emptyPage["documentID"] as? String, documentID, "Reloading the same URL creates a new document identity")
    }

    func testViewportFloorHintDistinguishesNaturalFlowFromFlexPositioning() async throws {
        let webView = makeWebView()
        webView.frame.size.height = 244
        try await load("""
        <style>body { margin:0; } button { display:block; box-sizing:border-box;
            height:44px; padding:0; margin:200px 0 0; }</style><button>Continue</button>
        """, in: webView)
        try await waitForCommittedScrollPosition(0, in: webView)
        let naturalResult = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
        let natural = try XCTUnwrap(naturalResult as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(natural["height"] as? Double), 244, accuracy: 1)
        XCTAssertEqual(try XCTUnwrap(natural["height"] as? Double),
                       try XCTUnwrap(natural["viewportHeight"] as? Double), accuracy: 1)
        XCTAssertEqual(natural["viewportFloorBottom"] as? Double, 0,
                       "Natural content matching the viewport must retain its full sizing demand")

        for (justification, filler) in [("space-between", ""), ("normal", "<div style='flex:1'></div>")] {
            try await load("""
            <style>
                body { margin:0; height:100vh; display:flex; flex-direction:column;
                       justify-content:\(justification); font:14px/20px sans-serif; }
                h1 { margin:0; font:inherit; }
                button { display:block; box-sizing:border-box; height:44px; margin:0; padding:0; }
            </style><h1>Bank authentication</h1>\(filler)<button>Continue</button>
            """, in: webView)
            let before = try await evaluate("document.documentElement.outerHTML", in: webView) as? String
            for viewportHeight: CGFloat in [244, 420] {
                webView.frame.size.height = viewportHeight
                try await waitForCommittedScrollPosition(0, in: webView)
                let result = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
                let page = try XCTUnwrap(result as? [String: Any])
                XCTAssertEqual(try XCTUnwrap(page["height"] as? Double), Double(viewportHeight), accuracy: 1)
                XCTAssertEqual(try XCTUnwrap(page["viewportFloorBottom"] as? Double),
                               try XCTUnwrap(page["height"] as? Double), accuracy: 1,
                               "Flex-positioned content must report its viewport dependency without discarding its height")
            }
            let after = try await evaluate("document.documentElement.outerHTML", in: webView) as? String
            XCTAssertNotNil(before)
            XCTAssertEqual(after, before, "Viewport classification must not rewrite provider layout")
        }
    }

    func testViewportFloorHintRequiresActualFlexFreeSpace() async throws {
        let webView = makeWebView()
        webView.frame.size.height = 244
        for (headerHeight, gap, filler) in [
            (200, 0, ""),
            (200, 0, "<div id='filler' style='flex:1'></div>"),
            (180, 20, "")
        ] {
            try await load("""
            <style>
                body { margin:0; height:100vh; display:flex; flex-direction:column;
                       justify-content:space-between; row-gap:\(gap)px; }
                h1 { height:\(headerHeight)px; flex-shrink:0; margin:0; font:14px/20px sans-serif; }
                button { display:block; box-sizing:border-box; height:44px; flex-shrink:0; margin:0; padding:0; }
            </style><h1>Bank authentication</h1>\(filler)<button>Continue</button>
            """, in: webView)
            try await waitForCommittedScrollPosition(0, in: webView)
            let result = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
            let page = try XCTUnwrap(result as? [String: Any])
            XCTAssertEqual(try XCTUnwrap(page["height"] as? Double), 244, accuracy: 1)
            XCTAssertEqual(try XCTUnwrap(page["viewportHeight"] as? Double), 244, accuracy: 1)
            XCTAssertEqual(page["viewportFloorBottom"] as? Double, 0,
                           "Flex declarations and authored gaps must not hide natural demand when no free space exists")
            if !filler.isEmpty {
                let fillerHeight = try await evaluate("document.querySelector('#filler').getBoundingClientRect().height", in: webView)
                XCTAssertEqual(try XCTUnwrap(fillerHeight as? Double), 0, accuracy: 1)
            }
        }
    }

    func testNonCardMeasurementPreservesOpaqueIframeDemandBeforeAndAfterFitting() async throws {
        let webView = makeWebView()
        webView.frame.size.height = 200
        try await load("""
        <style>body { margin:0; } iframe { display:block; width:90%; height:640px; }</style>
        <iframe sandbox srcdoc="<p style='height:2400px'>Bank challenge</p>"></iframe>
        """, in: webView)
        let result = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
        let page = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(page["kind"] as? String, "page")
        let frameBottomResult = try await evaluate("Math.ceil(document.querySelector('iframe').getBoundingClientRect().bottom + window.scrollY)", in: webView)
        XCTAssertEqual(try XCTUnwrap(page["height"] as? Double), try XCTUnwrap(frameBottomResult as? Double), accuracy: 1,
                       "Only the outer frame contributes; cross-origin inner content stays inside the frame")
        XCTAssertEqual(page["viewportFloorBottom"] as? Double, 0)
        let frameBottom = try XCTUnwrap(frameBottomResult as? Double)
        webView.frame.size.height = CGFloat(frameBottom)
        try await waitForCommittedScrollPosition(0, in: webView)
        for _ in 0..<3 {
            let fittedResult = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
            let fitted = try XCTUnwrap(fittedResult as? [String: Any])
            XCTAssertEqual(try XCTUnwrap(fitted["height"] as? Double), frameBottom, accuracy: 1,
                           "A fixed iframe must retain its demand after the viewport fits its height")
            XCTAssertEqual(try XCTUnwrap(fitted["viewportFloorBottom"] as? Double), frameBottom, accuracy: 1)
        }
        _ = try await evaluate("document.querySelector('iframe').style.height = '100vh'", in: webView)
        for viewportHeight: CGFloat in [200, 700, 320] {
            webView.frame.size.height = viewportHeight
            try await waitForCommittedScrollPosition(0, in: webView)
            let resizedResult = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
            let resized = try XCTUnwrap(resizedResult as? [String: Any])
            let height = try XCTUnwrap(resized["height"] as? Double)
            XCTAssertGreaterThan(height, Double(viewportHeight), "The browser's iframe borders are part of its outer demand")
            XCTAssertEqual(try XCTUnwrap(resized["viewportFloorBottom"] as? Double), height, accuracy: 1,
                           "Native sizing receives the viewport feedback hint separately from the measured demand")
        }
        _ = try await evaluate("""
        document.body.insertAdjacentHTML('beforeend',
            '<p style="margin-top:40px">Additional bank instructions</p>');
        """, in: webView)
        let footerResult = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
        let footer = try XCTUnwrap(footerResult as? [String: Any])
        XCTAssertGreaterThan(try XCTUnwrap(footer["height"] as? Double),
                             try XCTUnwrap(footer["viewportFloorBottom"] as? Double) + 1,
                             "Content below the frame must still be able to expand the sheet")
    }

    func testLayoutObserverReportsDocumentIdentityForDelayedContent() async throws {
        let webView = makeWebView()
        let observer = CardFormLayoutMessageObserver()
        let contentController = webView.configuration.userContentController
        contentController.add(observer, name: "payhereLayoutChanged")
        defer {
            observer.onMessage = nil
            contentController.removeScriptMessageHandler(forName: "payhereLayoutChanged")
        }
        try await load("<p>Bank authentication</p>", in: webView)
        try await waitForCommittedScrollPosition(0, in: webView)
        let initialIDResult = try await evaluate("window.__payhereLayoutDocumentID", in: webView)
        let documentID = try XCTUnwrap(initialIDResult as? String)
        let changed = expectation(description: "Delayed content notifies the native layout owner")
        var awaitingChange = true
        observer.onMessage = { id in
            guard id == documentID else { return }
            webView.evaluateJavaScript("document.querySelector('#late-notice') !== null") { result, _ in
                guard result as? Bool == true, awaitingChange else { return }
                awaitingChange = false
                observer.onMessage = nil
                changed.fulfill()
            }
        }
        _ = try await evaluate("""
        setTimeout(() => {
            const notice = document.createElement('p');
            notice.id = 'late-notice';
            notice.style.marginTop = '900px';
            notice.textContent = 'Additional authentication instructions';
            document.body.appendChild(notice);
        }, 20);
        """, in: webView)
        await fulfillment(of: [changed], timeout: 5)
        let result = try await evaluate(PHWebViewScripts.pageMeasurement, in: webView)
        let page = try XCTUnwrap(result as? [String: Any])
        XCTAssertGreaterThan(try XCTUnwrap(page["height"] as? Double), 900)
        XCTAssertEqual(page["documentID"] as? String, documentID)
        XCTAssertFalse(observer.receivedUnexpectedPayload, "The bridge must send only a document identity")
        XCTAssertTrue(observer.documentIDs.allSatisfy { $0 == documentID })
    }

    private var providerWidthFixture: String {
        return """
        <style>
            body { font-family:sans-serif; line-height:1.4; }
            .container { width:100%; max-width:400px; height:840px; margin-left:auto; margin-right:auto;
                         padding-left:0!important; padding-right:0!important; overflow:hidden; }
            .form-group.payment { margin:0 15px; min-height:56px; }
            .form-group.cardExpiry { height:84px; }
            input.form-control { width:86%; margin-right:7%; height:40px; border:1px solid #eef1f4; }
            .btn { display:inline-block; box-sizing:border-box; padding:6px 12px; border:1px solid; }
            button[type=submit] { min-width:80%; max-width:320px; height:44px;
                                  margin-left:40px; margin-right:40px; margin-top:-90px;
                                  position:relative; font-size:18px; }
        </style>
        <div class="container"><form id="paymentForm" method="post" action="#receipt">
            <div class="form-group payment cardHolderName"><input id="cardHolderName" class="form-control" value="sample"></div>
            <div class="form-group payment cardNo"><input id="cardNo" class="form-control" value="sample"></div>
            <div class="form-group payment cardSecureId"><input id="cardSecureId" class="form-control" value="sample"></div>
            <div class="form-group payment cardExpiry"><input id="cardExpiry" class="form-control" value="sample"></div>
            <div class="form-group" style="height:100px;margin-bottom:20px">
                <button id="payButton" class="btn btn-primary" type="submit">Pay</button>
            </div>
        </form></div>
        \(providerFooter("<small>Payment terms. <a href=\"#terms\">Read terms</a></small>"))
        """
    }

    // Mirrors the adjacent logo/disclosure container in the downloaded provider HTML.
    // No request tokens, merchant data, remote assets, or payment actions are included.
    private func providerFooter(_ disclosure: String) -> String {
        return """
        <div class="container" style="height:840px;overflow:hidden">
            <div class="row text-center"><img class="scheme-logo" width="80" height="40" alt="Payment scheme"></div>
            <p class="declaration-text">\(disclosure)</p>
        </div>
        """
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
        configuration.userContentController.addUserScript(WKUserScript(
            source: PHWebViewScripts.layoutObserver,
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
            const fixtureFooter = document.querySelector('body > .container + .container');
            window.fixtureFooterContents = fixtureFooter ? fixtureFooter.innerHTML : null;
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

    private func waitForCommittedScrollPosition(_ expected: Double, in webView: WKWebView) async throws {
        let deadline = Date().addingTimeInterval(5)
        var stableSince: Date?
        while Date() < deadline {
            webView.layoutIfNeeded()
            let result = try await evaluate("""
                ({height:window.innerHeight, scrollHeight:document.scrollingElement.scrollHeight,
                  scrollY:window.scrollY})
                """, in: webView)
            let geometry = try XCTUnwrap(result as? [String: Double])
            let viewportHeight = try XCTUnwrap(geometry["height"])
            let contentHeight = try XCTUnwrap(geometry["scrollHeight"])
            // Navigation completion does not wait for the native scroll/viewport transaction.
            let committed = geometry["scrollY"] == expected && webView.scrollView.contentOffset.y == CGFloat(expected) &&
                abs(webView.bounds.height - CGFloat(viewportHeight)) <= 1 &&
                abs(webView.scrollView.bounds.height - CGFloat(viewportHeight)) <= 1 &&
                abs(webView.scrollView.contentSize.height - CGFloat(contentHeight)) <= 1
            if committed {
                if let stableSince = stableSince, Date().timeIntervalSince(stableSince) >= 0.1 { return }
                if stableSince == nil { stableSince = Date() }
            } else {
                stableSince = nil
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("WKWebView did not commit the requested \(expected)-point scroll position")
        throw URLError(.timedOut)
    }
}

@MainActor
private final class CardFormLayoutMessageObserver: NSObject, WKScriptMessageHandler {
    private(set) var documentIDs: [String] = []
    private(set) var receivedUnexpectedPayload = false
    var onMessage: ((String) -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let documentID = message.body as? String else {
            receivedUnexpectedPayload = true
            return
        }
        documentIDs.append(documentID)
        onMessage?(documentID)
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

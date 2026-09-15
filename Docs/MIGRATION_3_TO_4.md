# Migrate from 3.x.x to 4.x.x

## 1. Update the linked product

Follow the [Swift Package Manager installation steps](../README.md#swift-package-manager) and link the `PayHereSDK` product to each target that imports the SDK. CocoaPods users should first follow the [CocoaPods migration steps](../README.md#migrate-from-cocoapods).

`PayHereSDK` is the only library product. Replace any lowercase `payHereSDK` product references in Xcode or `Package.swift` with `PayHereSDK`.

## 2. Update the import

Replace the old module import:

```swift
// Before
import payHereSDK

// After
import PayHereSDK
```

Replace module-qualified references such as `payHereSDK.StatusResponse` with `StatusResponse` after importing the new module.

If compilation reports `No such module 'payHereSDK'`, replace `import payHereSDK` with `import PayHereSDK`. Swift does not support deprecating an `import` declaration, so this migration cannot emit a compiler deprecation warning.

## 3. Update the payment entry point

- Replace `PHPrecentController` with `PayHereSDK`.
- Replace `precent(...)` with `present(...)`.

`PHPresentController` has been removed; replace it with `PayHereSDK` too. `PHPrecentController` and its `precent`/`present` methods are unavailable. Their compiler errors identify the replacement API.

Calls that customize result behavior use `PayHereSDK.present(..., configuration:delegate:)`. See [Present PayHere Payment View](../README.md#present-payhere-payment-view) for configuration examples.

Replace `shouldShowPaymentStatus` with `PHPaymentConfiguration.showResultScreen`:

```swift
// Before: this entry point is now unavailable.
PHPrecentController.precent(
    from: self,
    withInitRequest: initRequest,
    shouldShowPaymentStatus: false,
    delegate: self
)

// After: self must conform to PayHereSDKDelegate.
PayHereSDK.present(
    from: self,
    withInitRequest: initRequest,
    configuration: PHPaymentConfiguration(showResultScreen: false),
    delegate: self
)
```

Apply the same conversion to `PHPrecentController.present(..., shouldShowPaymentStatus:delegate:)`. If the old call omitted the flag, omit `configuration` to retain the default result-screen behavior.

### Availability changes

| API | Status | Required action |
| --- | --- | --- |
| `PHPrecentController` | Unavailable; compiler error | Use `PayHereSDK`. |
| `precent`/`present` with `shouldShowPaymentStatus` | Unavailable; compiler error | Use `PayHereSDK.present(..., configuration:delegate:)`. |
| `PHViewControllerDelegate` | Unavailable; compiler error | Conform to `PayHereSDKDelegate`. |
| `onResponseReceived(response: PHResponse<Any>?)` | Unavailable; compiler error | Implement `payHereSDK(didReceive:)` with a nonoptional response. |
| `PayHereSDK.present(...)` accepting `PHViewControllerDelegate` | Unavailable; compiler error | Pass a `PayHereSDKDelegate`. |
| `onErrorReceived(error: Error)` | Deprecated; retained requirement on `PayHereSDKDelegate` | Move application error handling to `payHereSDK(didFailWith:)`; retain the old method only for temporary compatibility. |
| Default `payHereSDK(didFailWith:)` compatibility implementation | Deprecated; migration warning | Implement the typed callback to replace the fallback. |

## 4. Migrate the payment delegate

Replace `PHViewControllerDelegate` conformance with `PayHereSDKDelegate`. Move `onResponseReceived(response:)` handling into `payHereSDK(didReceive:)` and remove the optional-response guard. The old protocol, response method, and presentation overload are unavailable; this upgrade requires source changes.

Move application error handling from `onErrorReceived(error: Error)` into `payHereSDK(didFailWith error: PHPaymentError)`. Branch on the typed error's `code` and `stage`, and use `message` for display. The typed callback receives errors exclusively; the SDK does not also call `onErrorReceived`.

The SDK owns the deprecation and `renamed: "payHereSDK(didFailWith:)"` annotation; no deprecation annotation is needed in your app. Migrate the parameter type from `Error` to `PHPaymentError` when moving your handling logic.

Swift emits an SDK deprecation warning when your delegate relies on the legacy fallback, or when you call the legacy method through `PayHereSDKDelegate`. It does not warn merely for declaring a deprecated protocol method's implementation. A delegate implementing both error callbacks receives no declaration warning; implementing the typed callback replaces the deprecated fallback.

If a superclass declares `PayHereSDKDelegate` conformance, implement the typed error callback there and override it in subclasses. Adding the callback only in a subclass can leave protocol dispatch using the inherited fallback.

```swift
extension ViewController: PayHereSDKDelegate {
    func payHereSDK(didReceive response: PHResponse<Any>) {
        // Move existing payment-result handling here. The response is nonoptional.
        print("Payment result:", response)
    }

    func payHereSDK(didFailWith error: PHPaymentError) {
        switch error.code {
        case .checkoutClosed:
            // The customer closed checkout. No failure alert is needed.
            return
        default:
            let alert = UIAlertController(
                title: "Payment",
                message: error.message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
```

`onErrorReceived(error:)` remains a deprecated, required protocol method until a future release removes it. Retain it in a separate extension for temporary compatibility. Do not add application error handling here; use the typed callback above.

```swift
extension ViewController {
    func onErrorReceived(error: Error) {
        print("Legacy payment error:", error)
    }
}
```

Existing integrations that omit the typed callback temporarily use a deprecated fallback. It forwards each original legacy error unchanged, including its type, domain, code, and message. Its SDK-provided compiler warning states: `onErrorReceived(error:) is deprecated. Implement payHereSDK(didFailWith:) with PHPaymentError instead.` Errors are not silently dropped.

Continue calling `PayHereSDK.present(from:withInitRequest:configuration:delegate:)` with the migrated delegate. This static method returns no value. The payment view holds the delegate weakly, so your app must keep it alive until checkout completes.

Preflight errors can call the delegate synchronously on the main queue before `present(...)` returns. Set up any state needed by your callbacks before calling `present(...)`.

The response is never `nil`. A status failure that previously delivered `onResponseReceived(response: nil)` now delivers `.paymentStatusUnavailable` through `didFailWith`, with category `.service` and stage `.statusCheck`. This signals an unknown payment status, not a failed payment. When using the deprecated error fallback, `onErrorReceived` receives this `PHPaymentError` directly because there is no original error payload for the former `nil` response. The optional-response path is no longer available.

### Error fields

| Field | Use |
| --- | --- |
| `code` | Stable scenario enum. Use cases such as `.checkoutClosed`, `.invalidMerchantID`, `.requestTimedOut`, and `.requestRejected` for branching. `code.rawValue` provides a stable string such as `checkout_closed`. |
| `category` | `.userAction`, `.integration`, `.connectivity`, or `.service`. Invalid payment request data and local SDK resource setup failures are integration errors, not customer actions. |
| `stage` | `.presentation`, `.initialization`, `.submission`, `.paymentPage`, `.statusCheck`, or `.result`. Identifies where the error occurred. |
| `message` | SDK-authored, nontechnical text for SDK-generated errors, or a recognized server error's exact message when present. `localizedDescription` returns this same value. |
| `serverMessage` | Optional original text from a recognized server error, preserved without trimming, sanitizing, or substitution. An empty server string remains an empty string. |
| `serverStatusCode` | Optional status code supplied by the server. This is separate from the HTTP status. |
| `httpStatusCode` | Optional HTTP response status code. |

### Error codes

The 14 codes below correspond to errors emitted by the SDK. Use `code` with `stage` to distinguish scenarios: `.requestRejected` at `.initialization` identifies initialization rejection, while the same code at `.submission` identifies submission rejection.

| Code | Category | Scenario |
| --- | --- | --- |
| `.checkoutClosed` | `.userAction` | Customer closes checkout, including cancelling further retries after a failed result. |
| `.invalidMerchantID` | `.integration` | Merchant ID validation fails. |
| `.invalidAmount` | `.integration` | Payment amount validation fails. |
| `.invalidCurrency` | `.integration` | Currency validation fails. |
| `.paymentViewUnavailable` | `.integration` | The payment view cannot be loaded from the SDK resources. |
| `.noInternet` | `.connectivity` | No internet connection is reported. |
| `.connectionLost` | `.connectivity` | An active network connection is interrupted. |
| `.requestTimedOut` | `.connectivity` | A network request times out. |
| `.networkFailure` | `.connectivity` | A request fails without a more specific network classification, including server-trust failures. |
| `.requestRejected` | `.service` | HTTP 4xx, initialization rejection, or a submission rejection with no payment URL. Use `stage` to identify the affected step. |
| `.serviceUnavailable` | `.service` | HTTP 5xx. |
| `.invalidResponse` | `.service` | A response cannot be decoded or otherwise fails validation. |
| `.invalidPaymentURL` | `.service` | A payment URL is invalid, or missing without an explicit rejection. |
| `.paymentStatusUnavailable` | `.service` | The status check cannot provide a payment result. Verify the payment status before another attempt. |

### Preserve server messages and payment outcomes

Recognized server errors keep their original `msg`, including empty strings:

- An initialization response with a status other than `1` produces `.requestRejected` at `.initialization`. The deprecated error fallback keeps code `501` and its original message.
- A submission response with an explicit status other than `1` and no payment URL produces `.requestRejected` at `.submission`. The deprecated error fallback keeps code `401` and `"Invalid URL"`.
- HTTP 400–599 responses preserve `msg` when the body decodes as JSON with optional `status: Int` and `msg: String` fields. The typed callback exposes both application and HTTP statuses when available; network errors sent through the deprecated fallback remain unchanged.

Arbitrary raw bodies, HTML, and messages from successful responses are not treated as server error text. When a recognized error has no `msg`, the SDK supplies its own UX text. The SDK does not infer card failures or customer actions by matching message text. Use `code` and available status fields for logic.

`.checkoutClosed` means the customer closed the payment window. It does not confirm that the bank or server cancelled a payment. After a submission error, verify the payment status before offering another payment attempt.

Final failed, authorized, and successful payment results arrive through `payHereSDK(didReceive:)`. They are not converted into errors. Existing polling, retry, dismissal, and main-queue delivery behavior is preserved.

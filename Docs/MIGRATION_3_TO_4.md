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
| `onErrorReceived(error: Error)` | Removed | Replace it with `payHereSDK(didFailWith error: PHPaymentError)`. |

## 4. Migrate the payment delegate

Replace `PHViewControllerDelegate` with `PayHereSDKDelegate` and implement both callbacks. Move `onResponseReceived(response:)` handling to `didReceive` and remove the optional-response guard. Replace the removed `onErrorReceived(error:)` with `didFailWith`.

```swift
extension ViewController: PayHereSDKDelegate {
    func payHereSDK(didReceive response: PHResponse<Any>) {
        // Move existing payment-result handling here. The response is nonoptional.
        print("Payment result:", response)
    }

    func payHereSDK(didFailWith error: PHPaymentError) {
        let alert = UIAlertController(title: "Payment", message: error.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

Keep the delegate alive until checkout completes; the SDK holds it weakly. Callbacks run once on the main queue after dismissal. Preflight errors may arrive synchronously before `present(...)` returns, so prepare callback state first.

### Public error message

`PHPaymentError` conforms to `Error` and exposes only `message: String`. Use `error.message` instead of `localizedDescription` or the removed `errorDescription`; it no longer conforms to `LocalizedError`.

`reason`, `code`, and `serverMessage` are internal. `category`, `stage`, `serverStatusCode`, and `httpStatusCode` are removed. Display the message without parsing it for error classification or payment status.

Recognized server errors preserve their exact `msg`, including empty strings. This covers initialization/submission rejections and recognized JSON errors on HTTP 400–599. Other failures use SDK messages; raw bodies, HTML, and successful-response text are not displayed as errors.

### App-side backward compatibility

`PHPaymentError` conforms to `Error`, so `didFailWith` can forward it to your app’s existing `Error` handler. Update that handler to read `PHPaymentError.message` for display. The SDK no longer provides `onErrorReceived`, an automatic fallback, or the original legacy error payload; old `NSError` domain/code checks must be migrated.

### Payment outcomes and closing

- `didReceive` delivers nonoptional final successful, authorized, or failed results. Closing after a final result still delivers that result, never a closure error.
- `didFailWith` handles SDK errors and closure before a final result. Ordinary cancellation and confirmed **Exit Now** share the internal reason `user_cancelled` and the same display message; only `message` is public.
- Status checks that previously returned a `nil` response now report an error. An error or closed window does not confirm bank cancellation or payment failure; verify an unknown status before retrying.

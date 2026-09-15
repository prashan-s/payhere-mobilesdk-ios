# PayHere Mobile SDK for iOS

<p>
  <a href="https://cocoapods.org/pods/payHereSDK">
    <img src="https://img.shields.io/cocoapods/v/payHereSDK?style=flat&amp;label=CocoaPods" alt="CocoaPods version (legacy releases)"/>
  </a>
  <a href="https://github.com/PayHereLK/payhere-mobilesdk-ios/tags">
    <img src="https://img.shields.io/github/v/tag/PayHereLK/payhere-mobilesdk-ios?style=flat&amp;label=Swift%20Package%20Manager" alt="Latest SDK tag"/>
  </a>
  <a href="https://swiftpackageindex.com/PayHereLK/payhere-mobilesdk-ios">
    <img src="https://img.shields.io/badge/Swift%20Package%20Index-View%20package-orange?style=flat" alt="View PayHere on Swift Package Index"/>
  </a>
  <a href="https://developer.apple.com/ios">
    <img src="https://img.shields.io/badge/Platform-iOS_13%2B-blue?style=flat" alt="iOS 13 and later"/>
  </a>
  <a href="https://developer.apple.com/swift">
    <img src="https://img.shields.io/badge/Language-Swift-orange?style=flat" alt="Swift"/>
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-Apache%202.0-blue?style=flat" alt="License: Apache 2.0"/>
  </a>
</p>

> [!WARNING]
> **CocoaPods:** New versions of the PayHere iOS SDK will no longer be published to CocoaPods after **August 2026**. Previously published CocoaPods versions will remain available, and existing installations will continue to work. Use Swift Package Manager for future SDK updates. See the [migration guide](#migrate-from-cocoapods) for the required steps.

PayHere Mobile SDK for iOS allows you to accept payments seamlessly within your iOS app, without redirecting your app user to the web browser.

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Migrate from CocoaPods](#migrate-from-cocoapods)
- [Swift Package Index](#swift-package-index)
- [Module migration](#module-migration)
- [Usage](#usage)
- [Tests](#tests)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Requirements
- iOS 13.0+
- Xcode 15.0+
- Swift 5.0+

## Installation

### Swift Package Manager

1. In Xcode, select **File > Add Package Dependencies...**.
2. Enter this repository URL:

   ```text
   https://github.com/PayHereLK/payhere-mobilesdk-ios.git
   ```

3. Select the SDK version and click **Add Package**.
4. Select the `PayHereSDK` product, assign it to your app target, and click **Add Package**.
5. Import the SDK:

   ```swift
   import PayHereSDK
   ```

### CocoaPods (legacy releases)

Previously published versions remain listed as [`payHereSDK` on CocoaPods](https://cocoapods.org/pods/payHereSDK). CocoaPods distribution ends with the **August 2026** cutoff; new integrations and future SDK updates use Swift Package Manager. The CocoaPods badge reports the version published to CocoaPods, independently of newer Git tags.

### Migrate from CocoaPods

1. Remove `pod 'payHereSDK'` from each affected target in your `Podfile`, then run `pod install` to update the integration and lockfile. Keep CocoaPods configuration for any other pods your app still uses.
2. Follow the [Swift Package Manager installation](#swift-package-manager) steps and link `PayHereSDK` to each target that imports the SDK.
3. Replace `import payHereSDK` with `import PayHereSDK`. Replace any module-qualified references such as `payHereSDK.StatusResponse` with the corresponding unqualified type after importing the new module.
4. Replace legacy `PHPresentController` or `PHPrecentController` entry points with `PayHereSDK.present(...)` as described in [Usage](#usage). `PHPresentController` has been removed; `PHPrecentController` is unavailable. Replace `PHViewControllerDelegate` with `PayHereSDKDelegate` using the [migration guide](Docs/MIGRATION_3_TO_4.md).
5. Build and test your checkout flow, including sandbox payments and delegate callbacks. Ensure the same target does not link both the CocoaPods and Swift Package Manager copies of PayHere.

### Swift Package Index

View PayHere on [Swift Package Index](https://swiftpackageindex.com/PayHereLK/payhere-mobilesdk-ios). Install it using the [Swift Package Manager steps](#swift-package-manager) above.

## Usage
Import PayHere SDK into your UIViewController 
```swift
import PayHereSDK
```
### Create InitRequest

#### CheckOut
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID, 
    notifyURL: "", 
    firstName: "Pay", 
    lastName: "Here", 
    email: "test@test.com", 
    phone: "+9477123456", 
    address: "Colombo", 
    city: "Colombo", 
    country: "Sri Lanka", 
    orderID: "001", 
    itemsDescription: "PayHere SDK Sample", 
    itemsMap: [item], 
    currency: .LKR, 
    amount: 50.00,
    deliveryAddress: "", 
    deliveryCity: "", 
    deliveryCountry: "", 
    custom1: "custom 01", 
    custom2: "custom 02"
)
```
#### PreApproval
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID, 
    notifyURL: "", 
    firstName: "", 
    lastName: "", 
    email: "", 
    phone: "", 
    address: "", 
    city: "", 
    country: "", 
    orderID: "001", 
    itemsDescription: "", 
    itemsMap: [item1], 
    currency: .LKR, 
    custom1: "", 
    custom2: ""
)
```

#### Recurring
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID, 
    notifyURL: "", 
    firstName: "", 
    lastName: "", 
    email: "", 
    phone: "", 
    address: "", 
    city: "", 
    country: "", 
    orderID: "002", 
    itemsDescription: "", 
    itemsMap: [item1], 
    currency: .LKR, 
    amount: 60.50, 
    deliveryAddress: "", 
    deliveryCity: "", 
    deliveryCountry: "", 
    custom1: "", 
    custom2: "", 
    startupFee: 0.0, 
    recurrence: .Month(duration: 2), 
    duration: .Forver
)
```
#### PreApproval
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID, 
    notifyURL: "", 
    firstName: "", 
    lastName: "", 
    email: "", 
    phone: "", 
    address: "", 
    city: "", 
    country: "", 
    orderID: "001", 
    itemsDescription: "", 
    itemsMap: [item1], 
    currency: .LKR, 
    custom1: "", 
    custom2: ""
)
```

#### Hold On Card
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
            merchantID: merchandID,
            notifyURL: "",
            firstName: "",
            lastName: "",
            email: "",
            phone: "",
            address: "",
            city: "",
            country: "",
            orderID: "",
            itemsDescription: "",
            itemsMap: [item1,item2],
            currency: .LKR,
            amount: 0.0,
            deliveryAddress: "",
            deliveryCity: "",
            deliveryCountry: "",
            custom1: "",
            custom2: "",
            isHoldOnCardEnabled: true 
)
```

### Present PayHere Payment View
Configuration is optional. You do not need to create or pass `PHPaymentConfiguration` to integrate the SDK. Without it, the SDK shows the result screen and offers Retry after failed payments.

```swift
PayHereSDK.present(
    from: self,
    withInitRequest: initRequest,
    delegate: self
)
```

`PayHereSDK.present(...)` is a static method that returns no value. The payment view holds the delegate weakly, so keep it alive until checkout completes. Preflight errors can call back synchronously on the main queue before `present(...)` returns. Set up any state needed by your callbacks before presenting checkout.

Pass a configuration only when customizing that behavior. Both options default to `true` and apply to checkout, recurring payments, preapproval, and hold-on-card payments. For example, show the result screen without Retry:

```swift
let configuration = PHPaymentConfiguration(
    showResultScreen: true,
    showRetryOnResultScreen: true
)

PayHereSDK.present(
    from: self,
    withInitRequest: initRequest,
    configuration: configuration,
    delegate: self
)
```

| `showResultScreen` | `showRetryOnResultScreen` | Behavior |
| --- | --- | --- |
| `true` | `true` | Show the result screen. Failed payments offer Retry. |
| `true` | `false` | Show the result screen. Failed payments offer Done, which returns the failed payment response. |
| `false` | `true` | Dismiss after receiving a final payment status. No result screen or Retry is shown. |
| `false` | `false` | Dismiss after receiving a final payment status. No result screen or Retry is shown. |

Result screens are shown only for final statuses: success, failure, or authorization. Pending payments continue checking their status. Retry is never offered for successful or authorized payments. Displayed result screens retain the five-second automatic close behavior.

Set `showResultScreen` to `false` when your app handles the outcome through the delegate callbacks. `showRetryOnResultScreen` is ignored when the result screen is hidden. Configuration applies to each presentation.

### Module Migration

Upgrading from 3.x.x to 4.x.x? Follow the [migration guide](Docs/MIGRATION_3_TO_4.md) for product, import, and API changes.

### Handle Payment Response

The SDK delivers one completion callback on the main queue after the payment view is dismissed. Closing a failed result with Retry disabled returns the failed payment response. Closing an unfinished checkout reports `.checkoutClosed`; this does not confirm that the bank or server cancelled the payment. Validation errors detected before presentation are also delivered on the main queue.

Implement `PayHereSDKDelegate` as shown below. `didReceive` provides a nonoptional response. `didFailWith` provides a `PHPaymentError` with stable `code`, `category`, and `stage` fields. SDK-generated errors provide nontechnical `message` text. Recognized server error messages are preserved exactly, including empty strings; `serverMessage`, `serverStatusCode`, and `httpStatusCode` expose available server details. This includes decoded initialization and submission rejections, and `msg` from recognized JSON error bodies on HTTP 400–599 responses. Arbitrary raw bodies, HTML, and successful-response messages are not used as error text. `localizedDescription` returns the same text as `message`.

Move application error handling from the deprecated `onErrorReceived(error: Error)` to `payHereSDK(didFailWith error: PHPaymentError)`. Implementing the typed callback gives it exclusive error delivery. `PHViewControllerDelegate`, `onResponseReceived(response:)`, and presentation using the old delegate are unavailable; use `PayHereSDKDelegate` and the nonoptional response callback below.

```swift
extension ViewController: PayHereSDKDelegate {
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

    func payHereSDK(didReceive response: PHResponse<Any>) {
        if(response.isSuccess()){
            
            guard let resp = response.getData() as? StatusResponse else{
                return
            }
            
            print("Payment Success")
            print("Payment Status", resp.status ?? -1)
            print("Message", resp.message ?? "Unknown Message")
            print("Payment No", resp.paymentNo ?? -1.0)
            print("Payment Amount", resp.price ?? -1.0)
            
        }
        else{
            print("Payment Error", response.getMessage() ?? "Unknown Message")
        }
    }
}
```

The protocol still requires the deprecated `onErrorReceived(error:)` during the transition. Include this separate extension only for temporary compatibility; put application error handling in the typed callback above. The SDK supplies the deprecation annotations; your app does not need to add them. The deprecated method will be removed in a future release.

```swift
extension ViewController {
    func onErrorReceived(error: Error) {
        print("Legacy payment error:", error)
    }
}
```

Existing integrations that omit the typed callback temporarily use a deprecated fallback, which preserves the original error and emits an SDK migration warning naming `onErrorReceived(error:)` and its replacement. Swift does not warn just for implementing a deprecated protocol method; declaring both error callbacks therefore produces no declaration warning. See [delegate migration](Docs/MIGRATION_3_TO_4.md#4-migrate-the-payment-delegate) for warning behavior, required changes, and error codes.

User actions (`.userAction`) are distinct from invalid integration data or local SDK resource setup failures (`.integration`), network problems (`.connectivity`), and server failures (`.service`). Codes describe errors emitted by the SDK. Use `code` and `stage` together: `.requestRejected` at `.initialization` identifies initialization rejection, while the same code at `.submission` identifies submission rejection. Branch on codes, stages, and status fields, not message text. After a submission error, verify the payment status before offering another payment attempt. Final failed, authorized, and successful payment results arrive through `didReceive`.

For status failures that previously delivered `onResponseReceived(response: nil)`, the SDK reports `.paymentStatusUnavailable` at stage `.statusCheck` through `didFailWith`. The deprecated error fallback sends that `PHPaymentError` to `onErrorReceived` because the former `nil` response has no original error payload. The payment status is unknown; verify it before offering another payment attempt. Polling behavior is unchanged.

### Tests

For local development, open [Demo/Demo.xcodeproj](Demo/Demo.xcodeproj) and run the `demoapp` scheme. The demo uses the Swift package from this checkout, including its resources.

In `Demo/Demo.xcodeproj`, run the `PayHereSDK-Tests` scheme on an iOS Simulator. Xcode resolves the Swift package dependencies when the project opens. The suite uses `demoapp` as its host for UIKit presentation, result configuration, dismissal, and retry tests. SDK requests are intercepted with local responses; these tests do not submit real payments.

Package-only test runs can execute the configuration and lifecycle tests. UIKit integration tests require the app host and are explicitly skipped without one.

## Code of Conduct

Participation in this project's community is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). It includes expected behavior and instructions for reporting concerns privately.

## License

PayHere Mobile SDK for iOS is licensed under the [Apache License, Version 2.0](LICENSE). Third-party dependencies retain their respective licenses.

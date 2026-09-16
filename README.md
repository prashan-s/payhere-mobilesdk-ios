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

Supports **checkout**, **recurring payments**, **preapproval**, and **hold on card**. Start with [installation](#installation), [integration setup](#integration-setup), and [payment response handling](#handle-payment-response), or run the [demo app](Demo/README.md).

> [!IMPORTANT]
> Use your sandbox Merchant ID when testing. Before going live, configure your server's `notifyURL` and verify payment notifications as described in [Integration setup](#integration-setup).

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Migrate from CocoaPods](#migrate-from-cocoapods)
- [Swift Package Index](#swift-package-index)
- [Module migration](#module-migration)
- [Integration setup](#integration-setup)
- [Usage](#usage)
- [Create InitRequest](#create-initrequest)
- [Present PayHere Payment View](#present-payhere-payment-view)
- [Handle Payment Response](#handle-payment-response)
- [Tests](#tests)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Requirements

- iOS 13.0+
- Xcode 16.0+ with the Swift 6.0+ toolchain, required by the Alamofire dependency.
- The SDK uses Swift 5 language mode.

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

## Module Migration

Upgrading from 3.x.x to 4.x.x? Follow the [migration guide](Docs/MIGRATION_3_TO_4.md) for product, import, and API changes.

## Integration setup

- **Merchant ID and environment:** Use your PayHere sandbox Merchant ID for testing and your live Merchant ID for production.
- **Payment notifications:** Set `notifyURL` to your publicly accessible server endpoint. Follow [PayHere's documentation](https://support.payhere.lk/api-%26-mobile-sdk/checkout-api) to receive and verify payment notifications.
- **Request data:** Replace the sample Merchant ID, notification URL, customer details, and order ID with your integration's values. Keep amounts and currencies consistent with the order recorded by your server.
- **Presentation lifecycle:** Prepare callback state before presenting, keep your delegate alive until completion, and handle server verification asynchronously so callbacks do not block the main queue.

## Usage

See the [Demo sample](Demo/Demo/ViewController.swift) for integration code, including payment callbacks and cancellation handling.

Import UIKit and the SDK into your view controller. The presentation examples use `self`, which must be a `UIViewController` conforming to `PayHereSDKDelegate` as shown in [Handle Payment Response](#handle-payment-response).

```swift
import UIKit
import PayHereSDK
```

### Create InitRequest

Choose one request type below, then pass its `initRequest` to [PayHereSDK.present(...)](#present-payhere-payment-view).

#### Checkout

```swift
let merchantID = "YOUR_MERCHANT_ID"
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID,
    notifyURL: "https://your-domain.com/payhere/notify",
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

#### Preapproval

Use the preapproval initializer to request payment authorization for future charges. This example omits the optional initial charge.

```swift
let merchantID = "YOUR_MERCHANT_ID"
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID,
    notifyURL: "https://your-domain.com/payhere/notify",
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
    custom1: "",
    custom2: ""
)
```

#### Recurring

This example charges every two months with no end date. `PHDuration.Forver` is the current public API spelling.

```swift
let merchantID = "YOUR_MERCHANT_ID"
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID,
    notifyURL: "https://your-domain.com/payhere/notify",
    firstName: "Pay",
    lastName: "Here",
    email: "test@test.com",
    phone: "+9477123456",
    address: "Colombo",
    city: "Colombo",
    country: "Sri Lanka",
    orderID: "002",
    itemsDescription: "PayHere SDK Sample",
    itemsMap: [item],
    currency: .LKR,
    amount: 50.00,
    deliveryAddress: "",
    deliveryCity: "",
    deliveryCountry: "",
    custom1: "",
    custom2: "",
    startupFee: 0.0,
    recurrence: .Month(period: 2),
    duration: .Forver
)
```

#### Hold On Card

Use `isHoldOnCardEnabled: true` for authorization. Distinguish `.AUTHORIZED` from `.SUCCESS` in your response handler; see [payment outcomes](#payment-outcomes).

```swift
let merchantID = "YOUR_MERCHANT_ID"
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID,
    notifyURL: "https://your-domain.com/payhere/notify",
    firstName: "Pay",
    lastName: "Here",
    email: "test@test.com",
    phone: "+9477123456",
    address: "Colombo",
    city: "Colombo",
    country: "Sri Lanka",
    orderID: "003",
    itemsDescription: "PayHere SDK Sample",
    itemsMap: [item],
    currency: .LKR,
    amount: 50.00,
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
    showRetryOnResultScreen: false
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

Result screens are shown only for final statuses: success, failure, or authorization. Pending payments continue checking their status. Retry is never offered for successful or authorized payments, or for SDK errors delivered through `didFailWith`. Displayed result screens retain the five-second automatic close behavior.

Set `showResultScreen` to `false` when your app handles the outcome through the delegate callbacks. `showRetryOnResultScreen` is ignored when the result screen is hidden. Configuration applies to each presentation.

## Handle Payment Response

Implement both `PayHereSDKDelegate` callbacks. The SDK delivers one completion callback on the main queue after dismissal; validation errors before presentation also arrive on the main queue.

`didReceive` returns successful, authorized, and failed final results, including when the user closes the result screen. Closing an unfinished checkout, including confirming **Exit Now**, calls `didFailWith` with `error.reason == .userCancelled`. This does not confirm bank cancellation. Verify an unknown payment status before offering another attempt.

Use `PHPaymentError.reason` to handle specific errors and `message` for display; do not parse the message or use `localizedDescription`. Recognized server messages are preserved exactly, including empty strings; raw response bodies and HTML are excluded. Numeric codes and server-message storage remain internal.

The following callbacks and alert helper follow the [demo's ViewController](Demo/Demo/ViewController.swift):

```swift
extension ViewController: PayHereSDKDelegate {
    // Handles SDK errors and user cancellation before a final payment result is available.
    // Final results arrive through `didReceive`; an error does not confirm payment failure.
    // If the payment status is unknown, verify it before offering another attempt.
    func payHereSDK(didFailWith error: PHPaymentError) {
        switch error.reason {
        case .userCancelled:
            // The user closed the bottom sheet; this does not confirm cancellation by the bank.
            showPaymentError(message: error.message)
        default:
            showPaymentError(message: error.message)
        }
    }

    // Receives final successful, failed, or authorized payment results after dismissal.
    // `isSuccess()` is true only for SUCCESS; inspect StatusResponse to distinguish AUTHORIZED.
    func payHereSDK(didReceive response: PHResponse<Any>) {
        if response.isSuccess() {
            guard let resp = response.getData() as? StatusResponse else {
                return
            }
            print(resp.message ?? "" as Any)
            // Handle a successful payment using the details in `resp`.
        } else {
            print(response.getMessage() ?? "")
            showPaymentError(message: response.getMessage() ?? "")
        }
    }

    private func showPaymentError(message: String) {
        let alert = UIAlertController(
            title: "Payment",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

### Payment outcomes

`response.isSuccess()` is `true` only for `.SUCCESS`. Read `(response.getData() as? StatusResponse)?.getStatusState()` when your integration needs to distinguish the final outcomes:

| `StatusResponse.Status` | `response.isSuccess()` | Outcome |
| --- | --- | --- |
| `.SUCCESS` | `true` | Payment succeeded. |
| `.FAILED` | `false` | Payment failed. |
| `.AUTHORIZED` | `false` | Authorization succeeded. Handle it separately from a failed payment. |

The demo's `else` branch displays a message for all non-success responses, including authorization. For hold-on-card integrations, check `.AUTHORIZED` before using that branch as a failure path. `StatusResponse` also exposes `paymentNo`, `currency`, `price`, and `message` as optional values; `response.getMessage()` is a response summary, not the payment status.

### Delegate migration

Replace the removed `onErrorReceived(error:)` with `didFailWith`. See [delegate migration](Docs/MIGRATION_3_TO_4.md#4-migrate-the-payment-delegate) for the complete 3.x migration.

For app-side backward compatibility, pass `PHPaymentError` to an existing handler accepting `Error`; use `message` for display. The SDK no longer retains the original legacy error payload. See [compatibility guidance](Docs/MIGRATION_3_TO_4.md#app-side-backward-compatibility).

## Tests

For local development, keep the full repository checkout, open [Demo/Demo.xcodeproj](Demo/Demo.xcodeproj), and run the `demoapp` scheme. The demo uses the Swift package from this checkout, including its resources. Replace the demo Merchant ID and request data before testing your integration. See the [demo instructions](Demo/README.md) for device signing and project setup.

In `Demo/Demo.xcodeproj`, run the `PayHereSDK-Tests` scheme on an iOS Simulator. Xcode resolves the Swift package dependencies when the project opens. The suite uses `demoapp` as its host for UIKit presentation, result configuration, dismissal, and retry tests. SDK requests are intercepted with local responses; these tests do not submit real payments.

Package-only test runs can execute the configuration and lifecycle tests. UIKit integration tests require the app host and are explicitly skipped without one.

## Code of Conduct

Participation in this project's community is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). It includes expected behavior and instructions for reporting concerns privately.

## License

PayHere Mobile SDK for iOS is licensed under the [Apache License, Version 2.0](LICENSE). Third-party dependencies retain their respective licenses.

# PayHere Mobile SDK for iOS

<p>
  <a href="https://cocoapods.org/pods/payHereSDK">
    <img src="https://img.shields.io/cocoapods/v/payHereSDK?style=flat&amp;label=CocoaPods" alt="CocoaPods version (legacy releases)"/>
  </a>
  <a href="https://github.com/PayHereLK/payhere-mobilesdk-ios/tags">
    <img src="https://img.shields.io/github/v/tag/PayHereLK/payhere-mobilesdk-ios?style=flat&amp;label=Swift%20Package%20Manager" alt="Latest SDK tag"/>
  </a>
  <a href="#swift-package-index">
    <img src="https://img.shields.io/badge/Swift%20Package%20Index-pending%20submission-orange?style=flat" alt="Swift Package Index: pending submission"/>
  </a>
  <a href="https://developer.apple.com/ios">
    <img src="https://img.shields.io/badge/Platform-iOS_13%2B-blue?style=flat" alt="iOS 13 and later"/>
  </a>
  <a href="https://developer.apple.com/swift">
    <img src="https://img.shields.io/badge/Language-Swift-orange?style=flat" alt="Swift"/>
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

## Requirements
- iOS 13.0+
- Xcode 15.0+
- Swift 5.0+

## Installation

### Swift Package Manager

PayHere is distributed through [Swift Package Manager](https://swift.org/package-manager/). Xcode resolves its dependencies automatically.

To integrate PayHere into your Xcode project using Swift Package Manager:

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the package repository URL:
   ```
   https://github.com/PayHereLK/payhere-mobilesdk-ios.git
   ```
3. Select a release that contains the `PayHereSDK` product and module
4. Click **Add Package** and add the `PayHereSDK` product to your app target

The module rename documented here is newer than tag `3.2.2`, which still uses `payHereSDK`. A package pinned to that tag cannot use `import PayHereSDK`. Select a release containing the rename once published. To test this checkout before that release, use Xcode's **Add Local...** package option, or a local dependency in your `Package.swift`:

```swift
dependencies: [
    .package(path: "../payhere-mobilesdk-ios")
]
```

For either a released package containing the rename or this local checkout, add the SDK product to the target that imports it:

```swift
.target(
    name: "YourAppTarget",
    dependencies: [
        .product(name: "PayHereSDK", package: "payhere-mobilesdk-ios")
    ]
)
```

### CocoaPods (legacy releases)

Previously published versions remain listed as [`payHereSDK` on CocoaPods](https://cocoapods.org/pods/payHereSDK). CocoaPods distribution ends with the **August 2026** cutoff; new integrations and future SDK updates use Swift Package Manager. The CocoaPods badge reports the version published to CocoaPods, independently of newer Git tags.

### Migrate from CocoaPods

1. Remove `pod 'payHereSDK'` from each affected target in your `Podfile`, then run `pod install` to update the integration and lockfile. Keep CocoaPods configuration for any other pods your app still uses.
2. Follow the [Swift Package Manager installation](#swift-package-manager) steps and link the `PayHereSDK` product to every app, extension, or test target that imports the SDK. Use a version containing the module rename, or this local checkout while that release is pending.
3. Replace `import payHereSDK` with `import PayHereSDK`. Replace any module-qualified references such as `payHereSDK.StatusResponse` with the corresponding unqualified type after importing the new module.
4. Replace legacy `PHPresentController` or `PHPrecentController` entry points with `PayHereSDK.present(...)` as described in [Usage](#usage). The legacy controller APIs remain deprecated forwarding wrappers.
5. Build and test your checkout flow, including sandbox payments and delegate callbacks. Ensure the same target does not link both the CocoaPods and Swift Package Manager copies of PayHere.

### Swift Package Index

Swift Package Index submission is pending. This checkout includes [.spi.yml](.spi.yml) to generate iOS API documentation for the `PayHereSDK` target. Maintainers can follow the [submission checklist](docs/SWIFT_PACKAGE_INDEX.md) to publish the renamed module, submit the canonical repository, and enable live platform and Swift-version badges after indexing. Swift Package Manager remains the installation mechanism.

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

Result screens are shown only for final statuses: success, failure, or authorization. Pending payments continue checking their status. Retry is never offered for successful or authorized payments. Displayed result screens retain the five-second automatic close behavior.

Set `showResultScreen` to `false` when your app handles the outcome through the delegate callbacks. `showRetryOnResultScreen` is ignored when the result screen is hidden. Configuration applies to each presentation.

`PayHereSDK` is the canonical payment entry point. `PHPresentController` and the misspelled `PHPrecentController` are deprecated compatibility APIs. For new integrations, use `PayHereSDK.present(...)`. To migrate, replace either legacy controller name with `PayHereSDK`, and rename any `precent(...)` calls to `present(...)`. Calls that customize result behavior use `PayHereSDK.present(..., configuration:delegate:)`. The deprecated `PHPrecentController` methods retain the optional `shouldShowPaymentStatus` argument for source compatibility; it controls the result screen and keeps Retry enabled for failures.

### Module Migration

Use the `PayHereSDK` product and `import PayHereSDK` for all integrations. Update existing integrations by changing both the linked product and import:

```swift
// Before
import payHereSDK

// After
import PayHereSDK
```

The lowercase `payHereSDK` product remains available as a package-selection compatibility alias, but it exports the `PayHereSDK` module. Update the import even if your dependency declaration still uses the lowercase product. If an existing integration reports `No such module 'payHereSDK'`, replace `import payHereSDK` with `import PayHereSDK`. Swift does not support deprecating an `import` declaration, so this import migration cannot emit a compiler deprecation warning.

### Handle Payment Response

The SDK delivers one completion callback on the main queue after the payment view is dismissed. Closing a failed result with Retry disabled returns the failed payment response. Cancelling an unfinished payment reports an error. Validation errors detected before presentation are also delivered on the main queue.

```swift
extension ViewController : PHViewControllerDelegate{
    func onErrorReceived(error: Error) {
        print("✋ Error",error)
    }
    
    func onResponseReceived(response: PHResponse<Any>?) {
        guard let response = response else {
            print("Could not receive payment response")
            return
        }
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

### Source layout

`payHereSDK/Sources` is organized into `API`, `Core`, `Models`, `UI`, `Utilities`, and `Resources`. UI files are grouped by controllers, cells, views, and theme. Resources contain assets, fonts, nibs, the storyboard, and the privacy manifest.

`API/PayHereSDK.swift` contains the public payment entry point and forwards to the internal `Core/PHPaymentPresenter.swift` implementation. Merchant validation, storyboard loading, controller configuration, and main-queue dispatch stay inside the SDK. Existing `PayHereSDK.present(...)` calls and deprecated compatibility entry points keep the same behavior. This separates the public API from its implementation; Swift Package Manager still distributes the source files.

The Xcode navigator mirrors this directory through a synchronized folder. Add SDK files on disk; `Package.swift` owns compilation and resource processing. SDK sources do not belong directly to the demo or test target.

### Tests

For local development, open `payHereSDK.xcodeproj` and run the `demoapp` scheme. The demo uses the Swift package from this checkout, including its resources.

Open `payHereSDK.xcodeproj` and run the `payHereSDK-Tests` scheme on an iOS Simulator. Xcode resolves the Swift package dependencies when the project opens. The suite uses `demoapp` as its host for UIKit presentation, result configuration, dismissal, and retry tests. SDK requests are intercepted with local responses; these tests do not submit real payments.

Package-only test runs can execute the configuration and lifecycle tests. UIKit integration tests require the app host and are explicitly skipped without one.

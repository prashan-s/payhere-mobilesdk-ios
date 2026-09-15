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

`PayHereSDK` is the canonical payment entry point. Replace `PHPresentController` or the misspelled `PHPrecentController` with `PayHereSDK`, and rename any `precent(...)` calls to `present(...)`.

Both legacy controller types remain deprecated compatibility APIs. The deprecated `PHPrecentController` methods retain the optional `shouldShowPaymentStatus` argument; it controls the result screen and keeps Retry enabled for failures.

Calls that customize result behavior use `PayHereSDK.present(..., configuration:delegate:)`. See [Present PayHere Payment View](../README.md#present-payhere-payment-view) for configuration examples.

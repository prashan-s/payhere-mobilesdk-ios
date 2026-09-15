# Swift Package Index maintenance

Canonical repository: `https://github.com/PayHereLK/payhere-mobilesdk-ios.git`.

Package page: [PayHere on Swift Package Index](https://swiftpackageindex.com/PayHereLK/payhere-mobilesdk-ios).

This guide covers release validation, documentation generation, and compatibility badges for the canonical repository. SDK releases are published on GitHub and installed through Swift Package Manager.

## Package configuration

The root [Package.swift](../Package.swift) defines `PayHereSDK` as the only library product and module, processes the SDK resources, and retains the iOS 13 deployment target and Swift 5 language mode. Existing lowercase `payHereSDK` product references must change to `PayHereSDK`.

The separate demo application and its Xcode project live in [Demo](../Demo/README.md). Swift Package Index builds the root SDK package; the demo project is not required to consume the library.

The root [.spi.yml](../.spi.yml) enables API documentation for the canonical `PayHereSDK` target on iOS. The iOS setting is necessary because the package uses UIKit. Swift Package Index supplies its DocC tooling; the package needs no additional documentation dependency. This configuration controls documentation generation, not the compatibility results for other platforms. See the [official configuration examples](https://github.com/SwiftPackageIndex/SPIManifest/blob/main/Sources/SPIManifest/Documentation.docc/CommonUseCases.md) and [build behavior](https://swiftpackageindex.com/docs/builds).

## Maintainer checklist

1. Include the [Apache License, Version 2.0](../LICENSE) with SDK distributions and preserve applicable third-party license notices.
2. Verify that `swift package dump-package` outputs valid JSON and that the package builds for iOS. Verify the existing presentation tests through the `PayHereSDK-Tests` scheme in [Demo/Demo.xcodeproj](../Demo/Demo.xcodeproj).
3. Publish the reviewed changes, including `.spi.yml`, to the canonical repository. The `prashan-s` development fork is not the indexed repository.
4. Publish a semantic-version tag containing the `PayHereSDK` module rename, with release notes explaining the required import migration and the August 2026 CocoaPods cutoff. Tag `3.2.2` still exposes `payHereSDK`; it does not contain this migration. Choose a release version that accounts for the source-breaking import change.
5. Inspect the [package page](https://swiftpackageindex.com/PayHereLK/payhere-mobilesdk-ios) after each release to confirm the indexed version and its iOS build and documentation results.
6. Keep the README's package link current. If adding live compatibility badges, obtain the current snippets from the package page's maintainer section and verify they show actual results.

The index requires a public repository, a valid root package manifest, valid manifest JSON, a supported Swift version, and successful compilation. It also asks for at least one semantic-version release. The complete criteria are in the [official submission instructions](https://swiftpackageindex.com/add-a-package).

## Compatibility badges

The README uses a neutral badge linking to the package page. Once build results are available, the live badges below can display the index's measured compatibility. Verify the endpoints before enabling them; they do not assert that every Swift version or Apple platform is supported.

```html
<a href="https://swiftpackageindex.com/PayHereLK/payhere-mobilesdk-ios">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FPayHereLK%2Fpayhere-mobilesdk-ios%2Fbadge%3Ftype%3Dplatforms" alt="Platforms supported by PayHereSDK"/>
</a>
<a href="https://swiftpackageindex.com/PayHereLK/payhere-mobilesdk-ios">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FPayHereLK%2Fpayhere-mobilesdk-ios%2Fbadge%3Ftype%3Dswift-versions" alt="Swift versions supported by PayHereSDK"/>
</a>
```

Keep the CocoaPods badge connected to `https://img.shields.io/cocoapods/v/payHereSDK` so it continues to report the published legacy pod version after newer releases move to Swift Package Manager.

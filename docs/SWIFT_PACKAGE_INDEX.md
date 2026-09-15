# Swift Package Index preparation

Canonical repository: `https://github.com/PayHereLK/payhere-mobilesdk-ios.git`.

This checkout prepares the package for submission. It does not publish a release or register the repository with Swift Package Index.

## Package configuration

The root [Package.swift](../Package.swift) defines the `PayHereSDK` library and target, processes the SDK resources, and retains the iOS 13 deployment target and Swift 5 language mode. The lowercase `payHereSDK` product is a package-selection alias; both products expose the `PayHereSDK` module.

The root [.spi.yml](../.spi.yml) enables API documentation for the canonical `PayHereSDK` target on iOS. The iOS setting is necessary because the package uses UIKit. Swift Package Index supplies its DocC tooling; the package needs no additional documentation dependency. This configuration controls documentation generation, not the compatibility results for other platforms. See the [official configuration examples](https://github.com/SwiftPackageIndex/SPIManifest/blob/main/Sources/SPIManifest/Documentation.docc/CommonUseCases.md) and [build behavior](https://swiftpackageindex.com/docs/builds).

## Maintainer checklist

1. Review the currently empty [LICENSE](../LICENSE) before distributing the next release. The maintainer must supply the intended license terms; this preparation does not select a license.
2. Verify that `swift package dump-package` outputs valid JSON and that the package builds for iOS. Verify the existing presentation tests through the `payHereSDK-Tests` Xcode scheme.
3. Publish the reviewed changes, including `.spi.yml`, to the canonical repository. The `prashan-s` development fork is not the submission URL.
4. Publish a semantic-version tag containing the `PayHereSDK` module rename, with release notes explaining the required import migration and the August 2026 CocoaPods cutoff. Tag `3.2.2` still exposes `payHereSDK`; it does not contain this migration. Choose a release version that accounts for the source-breaking import change.
5. Follow [Add a Package](https://swiftpackageindex.com/add-a-package) to submit `https://github.com/PayHereLK/payhere-mobilesdk-ios.git`. Wait for acceptance and inspect the package's iOS build and documentation results.
6. Replace the README's pending-submission badge with the live badges below after the package appears in the index. Obtain the current badge snippets from the package page's maintainer section and verify they show actual results.

The index requires a public repository, a valid root package manifest, valid manifest JSON, a supported Swift version, and successful compilation. It also asks for at least one semantic-version release. The complete criteria are in the [official submission instructions](https://swiftpackageindex.com/add-a-package).

## Badges after indexing

The expected package page is `https://swiftpackageindex.com/PayHereLK/payhere-mobilesdk-ios`. Do not display these live badges before the listing exists. These endpoints report the index's measured compatibility; they do not assert that every Swift version or Apple platform is supported.

```html
<a href="https://swiftpackageindex.com/PayHereLK/payhere-mobilesdk-ios">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FPayHereLK%2Fpayhere-mobilesdk-ios%2Fbadge%3Ftype%3Dplatforms" alt="Platforms supported by PayHereSDK"/>
</a>
<a href="https://swiftpackageindex.com/PayHereLK/payhere-mobilesdk-ios">
  <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FPayHereLK%2Fpayhere-mobilesdk-ios%2Fbadge%3Ftype%3Dswift-versions" alt="Swift versions supported by PayHereSDK"/>
</a>
```

Keep the CocoaPods badge connected to `https://img.shields.io/cocoapods/v/payHereSDK` so it continues to report the published legacy pod version after newer releases move to Swift Package Manager.

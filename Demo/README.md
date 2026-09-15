# PayHere demo application

This is a separate iOS application that consumes the SDK from this repository. The Xcode project is [Demo.xcodeproj](Demo.xcodeproj); application sources and resources are in the `Demo` subfolder.

## Run the demo

1. Keep the full repository checkout. The project resolves its local Swift package from `..`, where the root [Package.swift](../Package.swift) lives; copying only `Demo` will break this dependency.
2. Open `Demo/Demo.xcodeproj` in Xcode and let package dependencies resolve.
3. Select the `demoapp` scheme and an iOS Simulator, then run. For a physical device, configure the app target's signing team first.

SDK implementation files and resources remain in `../PayHereSDK/Sources` and are compiled by Swift Package Manager, not directly by the application target.

## Run hosted SDK tests

Select the `PayHereSDK-Tests` scheme in the same project and run tests on an iOS Simulator. The test target reuses `../Tests/PayHereSDKTests` and uses `demoapp` as its host for UIKit presentation tests. SDK requests are intercepted with local responses; these tests do not submit real payments.

Package-only test runs can execute configuration and lifecycle tests. UIKit integration tests are explicitly skipped without the application host.

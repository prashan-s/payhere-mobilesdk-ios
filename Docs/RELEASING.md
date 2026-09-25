# Tests and releases

## CI

Pull requests targeting `master`, pushes to `master`, and manual CI runs execute
the functional test classes from `PayHereSDK-Tests` in `Demo/Demo.xcodeproj`.
Tests run serially on an iPhone 17 Pro with iOS 26.5 and Xcode 26.6 on `macos-26`.
Committed package resolutions are enforced. Logs and `.xcresult` bundles are
uploaded for 14 days, including failed runs.
CI explicitly includes lifecycle/state, error mapping, and sheet-height policy
tests. It excludes `PHPaymentControllerTests`, `PHPaymentImageTests`, and
`PHCardFormLayoutTests`, which exercise live presentation, UIKit cells, WebKit,
redirects, dismissal, or software-keyboard behavior. CI also rejects failed,
empty, or skipped functional suites, so a partial run cannot pass the release
gate.

The shared runner configuration is in `.github/workflows/tests.yml`. Update the
Xcode path and simulator destination together when changing toolchains.

## Versioning

Use [Semantic Versioning](https://semver.org/) and squash-merge feature PRs with
a [Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/) title:

| Commit | Version change |
| --- | --- |
| `fix: correct payment sheet corners` | Patch: backward-compatible fix |
| `feat: add an optional payment capability` | Minor: backward-compatible functionality |
| `feat!: replace the payment delegate` | Major: incompatible public contract |
| Any type with a `BREAKING CHANGE:` footer | Major |
| `docs:`, `test:`, `ci:`, or nonbreaking `chore:` | No release by itself |

Deprecating a public API requires a minor release. Removing it requires a major
release. Reviewers must check the actual compatibility impact; the automation
reads pull request metadata and cannot infer whether an API change is breaking.

`version.txt` defines the minimum release baseline. Existing stable SemVer tags
in the repository take precedence when they are newer.

## Release flow

1. Merge a pull request into `master` with a Conventional Commit title.
2. `fix:` selects a patch, `feat:` selects a minor, and `!` or a
   `BREAKING CHANGE:` footer selects a major release. Other PR types do not
   produce releases.
3. The workflow runs functional tests against the exact merge commit.
4. After success, it creates the plain SemVer tag and publishes the GitHub
   Release directly. It does not create a release PR or commit version files.

Running release workflows are serialized and are not canceled by newer pushes.
Test jobs have read-only repository access; release write permissions are
confined to the final Ubuntu publication job, which does not execute SDK code.

If release tests or publication fail, use **Re-run failed jobs** on the original
Release run. Publication is idempotent for the calculated tag and exact commit.
Never retarget or move a published tag.

## Repository setup

- Enable GitHub Actions and allow the pinned actions in these workflows.
- Require the **CI / tests / Functional tests** check for PRs to `master` using the
  check name displayed after the first CI run. Enable squash merging and keep
  conventional titles in the final squash commit.

The workflows take effect after these files are merged into upstream `master`.
They publish GitHub Releases and Swift Package Manager tags, not CocoaPods or
App Store builds.

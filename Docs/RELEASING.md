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
reads commit metadata and cannot infer whether an API change is breaking.
The highest required bump across unreleased commits wins.

Release tracking starts at the published upstream `4.0.0` commit. Existing plain
commit titles are not rewritten. Use conventional titles for future changes.

## Release flow

1. Release Please maintains a release PR against `master`, updating
   `CHANGELOG.md`, `version.txt`, and `.release-please-manifest.json`.
2. CI is explicitly dispatched for bot-created release PRs using `GITHUB_TOKEN`.
   This avoids needing a personal access token for automatic test runs.
3. Review the proposed version and changelog, then merge the release PR.
4. Release Please creates a **draft** GitHub Release targeting the release PR's
   merge commit. It does not create a public tag at this stage.
5. The release workflow runs the functional tests against that exact commit. Only
   after success does it publish the draft and create the plain SemVer tag,
   such as `4.0.1`, for Swift Package Manager.

Running release workflows are serialized and are not canceled by newer pushes.
An unpublished draft blocks subsequent release preparation. Test jobs have
read-only repository access; release write permissions are confined to Ubuntu
jobs that do not execute SDK code. Forks run CI but cannot publish official SDK
releases. The publication workflow is restricted to
`PayHereLK/payhere-mobilesdk-ios` on `master`.

If release tests or publication fail, keep the draft unpublished. Use **Re-run
failed jobs** on the original Release run so the tested commit and draft outputs
are preserved. If a code fix is required, close out the failed draft and create
a new release PR for the corrected code; never retarget an existing release run
or move a published tag. A full rerun may not rediscover a previously created
draft because Release Please has already processed its release PR.

## Repository setup

- Enable GitHub Actions and allow the pinned actions in these workflows.
- Under **Settings → Actions → General → Workflow permissions**, enable
  **Allow GitHub Actions to create and approve pull requests**. The workflows
  request their own scoped token permissions; no personal token is required.
- Require the **CI / tests / Functional tests** check for PRs to `master` using the
  check name displayed after the first CI run. Enable squash merging and keep
  conventional titles in the final squash commit.

The workflows take effect after these files are merged into upstream `master`.
They publish GitHub Releases and Swift Package Manager tags, not CocoaPods or
App Store builds.

# Captur Demo for iOS

Captur Demo is a small SwiftUI application used to verify and demonstrate integration with the private `CapturSDK` iOS package.

The application is currently a starter project. It imports the SDK and creates a `Captur` instance, but it does not yet expose any Captur functionality in the user interface. The main screen still displays the default “Hello, world!” content.

## Requirements

- macOS with Xcode 26.6 or a compatible version
- iOS 26.5 SDK
- Access to the private Captur GitLab instance
- A GitLab token that can read the SDK repository and its package artifacts
- A Captur API key for runtime SDK use

## SDK dependency

The application uses CapturSDK Gen3 as the Swift Package Manager package hosted at:

```text
https://gitlab.development.captur.ai/Captur/captur-mobile-sdk-ios
```

The package exposes the `CapturSDK` library. The version currently recorded in `Package.resolved` is `0.1.0`.

Because both the Swift package repository and its binary artifact are private, GitLab credentials must be available before Xcode resolves the package.

### Configure local GitLab authentication

Create or update `~/.netrc` with credentials that can access the private repository and package registry:

```text
machine gitlab.development.captur.ai
  login CapturDemo
  password <gitlab-access-token>
```

Restrict access to the file:

```sh
chmod 600 ~/.netrc
```

Never commit the token or the `.netrc` file to this repository.

## Running the application

1. Configure GitLab authentication as described above.
2. Open `CapturDemo.xcodeproj` in Xcode.
3. Allow Xcode to resolve the Swift package dependency.
4. Replace `YOUR_API_KEY` in `CapturDemoApp.swift` with a development API key.
5. Select an iOS Simulator and run the `CapturDemo` scheme.

Do not commit a production API key. As the application grows, the API key should be supplied through an appropriate secrets or configuration mechanism instead of being stored directly in source code.

## Current SDK integration

The app entry point currently verifies that the SDK module and its primary client type are available:

```swift
import CapturSDK
import SwiftUI

@main
struct CapturDemoApp: App {
    let captur = Captur(apiKey: "YOUR_API_KEY")

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

This code compiles for both Apple Silicon and Intel iOS Simulator architectures.

## Project structure

| Path | Purpose |
| --- | --- |
| `CapturDemo/CapturDemoApp.swift` | Application entry point and initial SDK setup |
| `CapturDemo/ContentView.swift` | Starter SwiftUI screen |
| `CapturDemo.xcodeproj` | Xcode application and Swift package configuration |
| `.github/workflows/build.yml` | GitHub Actions build workflow |

## Continuous integration

The GitHub Actions workflow in `.github/workflows/build.yml` verifies that the application and `CapturSDK` compile together.

### Triggers

The workflow runs:

- On pushes to `main`
- On pull requests
- When started manually through `workflow_dispatch`

Only the most recent build for a branch or pull request continues running. An older in-progress build is cancelled when a newer commit is pushed.

### Build environment

The CI job uses:

- GitHub's `macos-26` hosted runner
- Xcode 26.6
- The `Debug` configuration
- A generic iOS Simulator destination
- Disabled code signing
- The dependency versions recorded in `Package.resolved`

The workflow runs the equivalent of:

```sh
xcodebuild \
  -project CapturDemo.xcodeproj \
  -scheme CapturDemo \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The workflow currently builds the application only. It does not run unit tests, UI tests, or launch the application in a simulator.

### Required GitHub Actions secret

Create the following repository secret under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
| --- | --- |
| `CAPTUR_GITLAB_ACCESS_TOKEN` | Reads the private SDK repository and downloads its binary artifact |

The workflow uses `CapturDemo` as the GitLab username and writes the token to a temporary `~/.netrc` file on the GitHub-hosted runner. The credential file is removed at the end of the job, including after a build failure.

The token value must never be placed directly in the workflow file, source code, build logs, or repository documentation.

### CI failure guidance

- **Secret not configured:** Add the `CAPTUR_GITLAB_ACCESS_TOKEN` repository secret.
- **Authentication or package download failure:** Confirm that the token is active and can read both the SDK repository and its binary package artifact.
- **Package version mismatch:** Confirm that `Package.resolved` is committed and points to an available SDK release.
- **Xcode compatibility failure:** Confirm that the selected runner still provides Xcode 26.6 and the iOS 26.5 SDK.
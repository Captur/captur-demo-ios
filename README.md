# Captur Demo for iOS

Captur Demo is a small SwiftUI application that demonstrates integration with the private `CapturSDK` iOS package.

The app mimics two real use cases — verifying an **e-bike is parked correctly** (micro-mobility) and verifying a **package was dropped off** (delivery). Pick a use case, prepare a session, open the camera, and the SDK validates the photo on-device: live predictions while framing, then a final decision with the captured image.

## Requirements

- macOS with Xcode 26.6 or a compatible version
- iOS 15.0 or later (the app's deployment target)
- A physical iPhone for the full flow (the simulator has no camera; the app still builds and runs)
- Access to the private Captur GitLab instance
- A GitLab token that can read the SDK repository and its package artifacts
- A Captur API key for runtime SDK use

## SDK dependency

The application uses CapturSDK as a Swift Package Manager package hosted at:

```text
https://gitlab.development.captur.ai/Captur/captur-mobile-sdk-ios
```

The package exposes the `CapturSDK` library. The version currently recorded in `Package.resolved` is `0.2.0`. Read the version at runtime with `CapturSDKMetadata.version` — the app shows it at the bottom of the start screen.

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
4. Paste your API key into `CapturDemo/CapturConfig.swift`.
5. Select a device and run the `CapturDemo` scheme.

## The demo flow

1. **Pick a use case** — e-bike parking or package delivery. Each maps to a Captur policy type and a capture location (`UseCase.swift`). The SDK never reads GPS; the app supplies every coordinate.
2. **Prepare Session** — `captur.prepareSession(policyType:location:)`. Authenticates with the API key and downloads the policy model; the heaviest call, so the UI shows a spinner.
3. **Open Camera** — `session.prepareCamera(location:onCapturEvent:)` loads the models and returns a camera controller; the camera screen presents itself as soon as the controller exists. The app requests camera permission first — the SDK checks it but never prompts.
4. **Capture** — live predictions render at the bottom of the camera. Capture manually with the shutter, or let the SDK finalize on its own after a run of consistently good frames or a timeout. The camera controls (torch, front/back, lens, zoom) call straight into the controller.
5. **Result** — the final decision carries the JPEG; the app shows it framed with **New Session** and **Retake**. Retake resumes the still-open camera. New Session ends the flow: it calls `controller.close()`, which closes the session — the only place the demo does. Each new attempt starts with a fresh session. Persisting or uploading the image is the app's responsibility, not the SDK's.

For deterministic teardown, call await cameraController.close() from the host's definite completion or cancellation action. The call returns after camera shutdown. This is done in order to free resources and cleanup.

All CapturSDK lifecycle code lives in `CapturDemoModel.swift`. The integration itself remains a handful of small calls:

```swift
let captur = Captur(apiKey: CapturConfig.apiKey)

session = try await captur.prepareSession(
    policyType: useCase.policyType,
    location: useCase.demoLocation
)

cameraController = try await session.prepareCamera(location: useCase.demoLocation) { event in
    // Handle live predictions, the final decision, and failures.
}

try await cameraController.captureImage()
try cameraController.retake()
await cameraController.close()
```

## Project structure

| Path | Purpose |
| --- | --- |
| `CapturDemo/CapturDemoApp.swift` | Application entry point |
| `CapturDemo/CapturDemoModel.swift` | CapturSDK lifecycle and event handling |
| `CapturDemo/CapturConfig.swift` | API key configuration |
| `CapturDemo/UseCase.swift` | The two demo use cases (policy type, location) |
| `CapturDemo/UI/ContentView.swift` | Use-case picker and the two preparation steps |
| `CapturDemo/UI/CameraExperienceView.swift` | Camera, live predictions, and the captured result |
| `CapturDemo/UI/CameraControlsView.swift` | Shutter and camera hardware toggles |
| `CapturDemo/UI/CapturTheme.swift` | Brand colors, fonts, and button style (fonts in `UI/Fonts/`) |
| `CapturDemo.xcodeproj` | Xcode application and Swift package configuration |
| `.github/workflows/build.yml` | GitHub Actions build workflow |

## Continuous integration

GitLab authentication comes from one repository secret, configured under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
| --- | --- |
| `CAPTUR_GITLAB_ACCESS_TOKEN` | Reads the private SDK repository and downloads its binary artifact |

The workflow writes the token to a temporary `~/.netrc` on the runner and removes it at the end of the job, including after a failure. No API key is needed on CI — the app is built, not run.

If CI fails: check that the secret is configured and its token can read the SDK repository and package artifact, and that `Package.resolved` is committed and points to an available SDK release.

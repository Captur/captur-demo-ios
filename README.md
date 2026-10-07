# Captur Demo for iOS

Captur Demo is a small SwiftUI application that demonstrates integration with the private `CapturSDK` iOS package.

The app mimics real use cases — verifying an **e-bike or e-scooter is parked correctly** (micro-mobility) and verifying a **package was dropped off** (delivery). Pick a use case, prepare a session, open the camera, and the SDK validates the photo on-device: live predictions while framing, then a final decision with the captured image.

## Requirements

In the order you will need them:

1. An account on the private Captur GitLab instance, with access to the SDK repository
2. A GitLab personal access token that can read the SDK repository and its package artifacts
3. macOS with Xcode 26.6 or a compatible version
4. A Captur API key for runtime SDK use
5. An Apple ID on the Captur developer team, to sign the app for a physical device
6. A physical iPhone running iOS 15.0 or later for the full flow (the simulator has no camera; the app still builds and runs)

## Getting started

The steps below are in strict order: Xcode tries to resolve the SDK the moment
the project opens, so the GitLab credentials must exist first.

### 1. Get access to the SDK on GitLab

The SDK is served from the private Captur GitLab instance as a Swift Package
Manager package:

```text
https://gitlab.development.captur.ai/captur/mobile-sdks/captur-mobile-ios-sdk.git
```

You need an account on that instance with at least read access to the project.
Note: `gitlab.development.captur.ai` is a separate GitLab instance from
`gitlab.captur.ai`, with its own accounts. Credentials for one do not work on
the other. If the repository URL shows "404 Not Found" while you are signed
in, your account has not been granted access yet — ask for it.

### 2. Create a personal access token

Create a token with the `read_repository` and `read_api` scopes at:

```text
https://gitlab.development.captur.ai/-/user_settings/personal_access_tokens
```

An account password is not enough: it can clone the repository, but the
package registry that serves the binary artifact only accepts a token.

### 3. Store the token in ~/.netrc

Create or update `~/.netrc` with the token, then restrict access to the file:

```text
machine gitlab.development.captur.ai
  login <your-username>
  password <personal-access-token>
```

```sh
chmod 600 ~/.netrc
```

Never commit the token or the `~/.netrc` file to this repository.

### 4. Open the project and resolve the SDK

Open `CapturDemo.xcodeproj` in Xcode and let it resolve the Swift package
dependency — resolution uses the `~/.netrc` credentials from the previous
step, for both the repository and the binary artifact download.

### 5. Add your Captur API key

Create `CapturDemo/Secrets.env` (gitignored — real keys never reach source
control) containing your API key:

```sh
echo 'CAPTUR_API_KEY=your-api-key' > CapturDemo/Secrets.env
```

Without the file the app still builds and runs; preparing a session fails
with an authentication error.

### 6. Set up code signing (physical device only)

The project signs automatically with the Captur developer team and the bundle
identifier `captur.ai.CapturDemo`. Add an Apple ID that belongs to that team
under **Xcode → Settings → Accounts**; Xcode then creates the certificate and
provisioning profile on the first device build.

Without access to the Captur team, select your own team and a unique bundle
identifier under **Signing & Capabilities** for the `CapturDemo` target. Do
not commit that change.

### 7. Run

Select a device and run the `CapturDemo` scheme.

### Troubleshooting

| Error | Cause |
| --- | --- |
| Repository URL shows 404 in the browser | Your GitLab account has no access to the project (GitLab shows private projects as "not found") — see step 1 |
| `could not read Username for 'https://gitlab.development.captur.ai': terminal prompts disabled` | `~/.netrc` has no entry for `gitlab.development.captur.ai`, or the entry's credentials are rejected — see step 3 |
| `failed downloading '…/CapturSDK.xcframework.zip' … badResponseStatusCode(401)` | The `~/.netrc` entry holds an account password instead of a personal access token — see step 2 |
| `No profiles for 'captur.ai.CapturDemo' were found` | No Apple ID on the Captur developer team is signed in to Xcode — see step 6 |

## The demo flow

1. **Pick a use case** — e-bike parking, e-scooter parking, or package delivery. Each maps to a Captur policy type and a capture location (`UseCase.swift`). The SDK never reads GPS; the app supplies every coordinate.
2. **Prepare Session** — `captur.prepareSession(policyType:location:reference:)`. Authenticates with the API key and downloads the policy model; the heaviest call, so the UI shows a spinner. The reference (required since SDK 0.4.0) is your identifier for the capture — the demo passes a fresh UUID; a real app would use its own order or trip ID.
3. **Open Camera** — `session.prepareCamera(location:onCapturEvent:)` loads the models and returns a camera controller; the camera screen presents itself as soon as the controller exists. The app requests camera permission first — the SDK checks it but never prompts.
4. **Capture** — the live decision’s reason code renders at the bottom of the camera (per-label output is not surfaced). Capture manually with the shutter, or let the SDK finalize on its own after a run of consistently good frames or a timeout — the toggle on the start screen sets `CapturCameraConfiguration.disableAuto`, which stops consecutive good frames from finishing the capture automatically — the manual shutter and the SDK-managed timeout still apply. The camera controls (torch, front/back, lens, zoom) call straight into the controller.
5. **Result** — the final decision carries the JPEG; the app shows it framed with **New Session** and **Retake**. Retake resumes the still-open camera. New Session ends the flow: it calls `controller.close()`, which closes the session — the only place the demo does. Each new attempt starts with a fresh session. Persisting or uploading the image is the app's responsibility, not the SDK's.

For deterministic teardown, call await cameraController.close() from the host's definite completion or cancellation action. The call returns after camera shutdown. This is done in order to free resources and cleanup.

All CapturSDK lifecycle code lives in `CapturDemoModel.swift`. The integration itself remains a handful of small calls:

```swift
let captur = Captur(apiKey: CapturConfig.apiKey)

session = try await captur.prepareSession(
    policyType: useCase.policyType,
    location: useCase.demoLocation,
    reference: UUID().uuidString
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
| `CapturDemo/CapturConfig.swift` | Reads the API key from the gitignored `Secrets.env` |
| `CapturDemo/UseCase.swift` | The demo use cases (policy type, location) |
| `CapturDemo/UI/ContentView.swift` | Use-case picker and the two preparation steps |
| `CapturDemo/UI/CameraExperienceView.swift` | Camera, live reason code, and the captured result |
| `CapturDemo/UI/CameraControlsView.swift` | Shutter and camera hardware toggles |
| `CapturDemo/UI/CapturTheme.swift` | Brand colors, fonts, and button style (fonts in `UI/Fonts/`) |
| `CapturDemo.xcodeproj` | Xcode application and Swift package configuration |
| `.github/workflows/build.yml` | GitHub Actions build workflow |

## Continuous integration

GitLab authentication comes from one repository secret, configured under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
| --- | --- |
| `CAPTUR_REGIONAL_GITLAB_TOKEN` | Reads the private SDK repository and downloads its binary artifact |

The workflow writes the token to a temporary `~/.netrc` on the runner and removes it at the end of the job, including after a failure. No API key is needed on CI — the app is built, not run.

If CI fails: check that the secret is configured and its token can read the SDK repository and package artifact, and that `Package.resolved` is committed and points to an available SDK release.

# Captur Demo for iOS

Captur Demo is a small SwiftUI application that demonstrates integration with the private `CapturSDK` iOS package.

The app mimics real use cases — verifying an **e-bike or e-scooter is parked correctly** (micro-mobility) and verifying a **package was dropped off** (delivery). Pick a use case, prepare a session, open the camera, and the SDK validates the photo on-device: live predictions while framing, then a final decision with the captured image.

## Requirements

- macOS with Xcode 26.6 or a compatible version
- iOS 15.0 or later (the app's deployment target)
- A physical iPhone for the full flow (the simulator has no camera; the app still builds and runs)
- Access to the private Captur GitLab instance
- A GitLab personal access token that can read the SDK repository and its package artifacts
- An Apple ID on the Captur developer team, to sign the app for a physical device
- A Captur API key for runtime SDK use

## SDK dependency

The application uses CapturSDK as a Swift Package Manager package hosted at:

```text
https://gitlab.development.captur.ai/captur/mobile-sdks/captur-mobile-ios-sdk.git
```

Because both the Swift package repository and its binary artifact are private, GitLab credentials must be available before Xcode resolves the package.

`gitlab.development.captur.ai` is a separate GitLab instance from `gitlab.captur.ai`, with its own accounts. Credentials for one do not work on the other.

### Configure local GitLab authentication

Create a personal access token with the `read_repository` and `read_api` scopes at:

```text
https://gitlab.development.captur.ai/-/user_settings/personal_access_tokens
```

An account password is not enough: it can clone the repository, but the package registry that serves the binary artifact only accepts a token.

Create or update `~/.netrc` with the token:

```text
machine gitlab.development.captur.ai
  login <your-username>
  password <personal-access-token>
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
4. Create `CapturDemo/Secrets.env` (gitignored — real keys never reach source
   control) containing your API key:

   ```sh
   echo 'CAPTUR_API_KEY=your-api-key' > CapturDemo/Secrets.env
   ```

   Without the file the app still builds and runs; preparing a session fails
   with an authentication error.
5. To run on a physical iPhone, set up code signing as described below.
6. Select a device and run the `CapturDemo` scheme.

### Code signing

The project deliberately ships with no development team and no bundle
identifier: every cloner sets their own under **Signing & Capabilities** for
the `CapturDemo` target before the first device build.

- **Team** — if your Apple ID belongs to the Captur developer team, add it
  under **Xcode → Settings → Accounts** and select it. Otherwise select your
  own team; a free personal team works for device builds (apps expire after
  7 days and need re-installing from Xcode).
- **Bundle identifier — you must invent a unique one.** Bundle identifiers
  are globally unique across *all* Apple developer accounts, first come,
  first served, forever. If any team anywhere has already registered the
  string you pick, the build fails with "could not be registered to your
  development team" — which is why obvious choices often fail while a novel
  string works. Namespace it to yourself (for example
  `com.<yourname>.CapturDemo`) and keep reusing the same one: each new
  identifier is claimed permanently on first use, and free personal teams
  can only register about ten new ones per week. Members of the Captur team
  can use the already-registered `captur.ai.CapturDemo`.

Xcode creates the certificate and provisioning profile on the first device
build. Do not commit your team or bundle identifier.

### Troubleshooting

| Error | Cause |
| --- | --- |
| `could not read Username for 'https://gitlab.development.captur.ai': terminal prompts disabled` | `~/.netrc` has no entry for `gitlab.development.captur.ai`, or the entry's credentials are rejected |
| `failed downloading '…/CapturSDK.xcframework.zip' … badResponseStatusCode(401)` | The `~/.netrc` entry holds an account password instead of a personal access token |
| `No profiles for 'captur.ai.CapturDemo' were found` | No Apple ID on the Captur developer team is signed in to Xcode |

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

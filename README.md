# Captur Demo for iOS

Captur Demo is a small SwiftUI application that demonstrates integration with the private `CapturSDK` iOS package.

The app mimics real use cases — verifying an **e-bike or e-scooter is parked correctly** (micro-mobility) and verifying a **package was dropped off** (delivery). Pick a use case, prepare a session, open the camera, and the SDK validates the photo on-device: live predictions while framing, then a final decision with the captured image.

## Requirements

In the order you will need them:

1. Captur-issued GitLab deploy credentials with `read_repository` and `read_package_registry` scopes
2. macOS with Xcode 26.6 or a compatible version
3. A Captur API key for runtime SDK use
4. A physical iPhone running iOS 15.0 or later for the full flow (the simulator has no camera; the app still builds and runs)

## Getting started

The steps below are in strict order: Xcode tries to resolve the SDK the moment
the project opens, so the GitLab credentials must exist first.

### 1. Store the token in ~/.netrc

`~/.netrc` lives in your home directory, so the commands below work from any
folder — and the file is per machine and per user: create it on each Mac that
will run Xcode. Add or update the entry below using the `http_basic.username`
and `http_basic.password` from the Captur credential bundle, then restrict access:

```sh
cat >> ~/.netrc <<'EOF'
machine gitlab.captur.ai
  login captur-demo-apps-mobile-sdk-g1
  password <http_basic.password>
EOF
chmod 600 ~/.netrc
```

Verify repository access before involving Xcode — this must print the tag's revision:

```sh
GIT_TERMINAL_PROMPT=0 git ls-remote \
  https://gitlab.captur.ai/captur/mobile-sdks/captur-mobile-ios-sdk.git \
  refs/tags/1.0.0
```

Deploy credentials authorize repository and package downloads; they do not
need access to the general GitLab projects API. These credentials are for
installing the SDK and are separate from the Captur API key used at runtime.

Never commit the token or the `~/.netrc` file to this repository.

### 2. Open the project and resolve the SDK

Open `CapturDemo.xcodeproj` in Xcode. The project already declares the
`CapturSDK` product, pinned to exactly **1.0.0**. Resolution uses the
`~/.netrc` credentials from the previous step for both the repository and
the binary artifact download.

The package repository is:
```text
https://gitlab.captur.ai/captur/mobile-sdks/captur-mobile-ios-sdk.git
```
If Xcode already tried and failed before the credentials existed, retry with
**File → Packages → Resolve Package Versions**.

See the [Captur iOS implementation guide](https://docs.captur.ai/ios/implementation/)
for the SDK installation and lifecycle APIs.

### 3. Add your Captur API key

The demo passes its API key directly to `Captur.initialise(apiKey:)` in
`CapturDemo/CapturDemoModel.swift`. Replace `<YOUR_CAPTUR_API_KEY>` there
with your workspace's API key. This key is separate from the GitLab token
used to download the SDK.

### 4. Code signing

The project deliberately ships with no development team and no bundle
identifier: every cloner sets their own under **Signing & Capabilities** for
the `CapturDemo` target before the first device build.

- **Team** — Select your own team; a free personal team works for device builds
 (apps expire after 7 days and need re-installing from Xcode).
- **Bundle identifier — you must invent a unique one.** Bundle identifiers
  are globally unique across *all* Apple developer accounts, first come,
  first served, forever. If any team anywhere has already registered the
  string you pick, the build fails with "could not be registered to your
  development team" — which is why obvious choices often fail while a novel
  string works. Namespace it to yourself (for example
  `com.<yourname>.<yourcompany>.CapturDemo`) and keep reusing the same one: each new
  identifier is claimed permanently on first use, and free personal teams
  can only register about ten new ones per week.

Xcode creates the certificate and provisioning profile on the first device
build. Do not commit your team or bundle identifier.

### 5. Running the application (recap)

1. Configure GitLab authentication as described above.
2. Open `CapturDemo.xcodeproj` in Xcode.
3. Allow Xcode to resolve the Swift package dependency.
4. Replace `<YOUR_CAPTUR_API_KEY>` in `CapturDemo/CapturDemoModel.swift`
   with your Captur workspace's API key.
5. To run on a physical iPhone, set up code signing as described below.
6. Select a device and run the `CapturDemo` scheme.


### Troubleshooting

| Error | Cause |
| --- | --- |
| `could not read Username for 'https://gitlab.captur.ai': terminal prompts disabled` | `~/.netrc` has no entry for `gitlab.captur.ai`, or the deploy credentials are rejected |
| `failed downloading '…/CapturSDK.xcframework.zip' … badResponseStatusCode(401)` | The deploy credentials are invalid or lack `read_package_registry` access |
| `Failed Registering Bundle Identifier The app identifier "test" cannot be registered to your development team because it is not available. Change your bundle identifier to a unique string to try again.` | The specific bundle identifier you picked was already taken|

## The demo flow

1. **Pick a use case** — e-bike parking, e-scooter parking, or package delivery. Each maps to a Captur policy type and a capture location (`UseCase.swift`). The SDK never reads GPS; the app supplies every coordinate.
2. **Prepare Session** — `captur.prepareSession(policyType:location:reference:)`. Authenticates with the API key and downloads the policy model; the heaviest call, so the UI shows a spinner. The reference (required since SDK 0.4.0) is your identifier for the capture — the demo passes a fresh UUID; a real app would use its own order or trip ID.
3. **Open Camera** — `session.prepareCamera(location:onCapturEvent:)` loads the models and returns a camera controller; the camera screen presents itself as soon as the controller exists. The app requests camera permission first — the SDK checks it but never prompts.
4. **Capture** — the live decision’s reason code renders at the bottom of the camera (per-label output is not surfaced). Capture manually with the shutter, or let the SDK finalize on its own after a run of consistently good frames or a timeout — the toggle on the start screen sets `CapturCameraConfiguration.disableAuto`, which stops consecutive good frames from finishing the capture automatically — the manual shutter and the SDK-managed timeout still apply. The camera controls (torch, front/back, lens, zoom) call straight into the controller.
5. **Result** — the final decision carries the JPEG; the app shows it framed with **New Session** and **Retake**. Retake resumes the still-open camera. New Session ends the flow: it calls `controller.close()`, which closes the session — the only place the demo does. Each new attempt starts with a fresh session. Persisting or uploading the image is the app's responsibility, not the SDK's.

For deterministic teardown, call await cameraController.close() from the host's definite completion or cancellation action. The call returns after camera shutdown. This is done in order to free resources and cleanup.

All CapturSDK lifecycle code lives in `CapturDemoModel.swift`. The integration itself remains a handful of small calls:

```swift
let captur = try await Captur.initialise(apiKey: "<YOUR_CAPTUR_API_KEY>")

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
| `CapturDemo/UseCase.swift` | The demo use cases (policy type, location) |
| `CapturDemo/UI/ContentView.swift` | Use-case picker and the two preparation steps |
| `CapturDemo/UI/CameraExperienceView.swift` | Camera, live reason code, and the captured result |
| `CapturDemo/UI/CameraControlsView.swift` | Shutter and camera hardware toggles |
| `CapturDemo/UI/CapturTheme.swift` | Brand colors, fonts, and button style (fonts in `UI/Fonts/`) |
| `CapturDemo.xcodeproj` | Xcode application and Swift package configuration |
| `.github/workflows/build.yml` | GitHub Actions build workflow |

## Continuous integration

Configure the repository Actions secret `GITLAB_TOKEN` with the credential
bundle's `http_basic.password`. The workflow uses
`captur-demo-apps-mobile-sdk-g1` as the username and `gitlab.captur.ai` as
the host, writes a temporary `~/.netrc`, and removes it when the job ends.
Keep `Package.resolved` committed so CI builds the pinned SDK release.

CI builds for the iOS Simulator with signing disabled and supplies its own
bundle identifier, `ai.captur.demo.ci`. It needs neither an Apple signing
certificate nor a runtime Captur API key.

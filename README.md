# Captur Demo (iOS)

A minimal SwiftUI app showing how to integrate the **Captur SDK**: capture a photo,
get real-time framing guidance, and receive an on-device validation decision.
It mimics two real use cases — verifying an **e-bike is parked correctly**
(micro-mobility) and verifying a **package was dropped off** (delivery) — in five
small Swift files.

> **Alpha.** The Captur iOS SDK is in alpha; its API may change before general
> availability. Review the changelog when upgrading.

## Requirements

| Requirement | Minimum |
|---|---|
| iOS deployment target | iOS 16.0 (SDK itself supports 15.0+) |
| Xcode | 16 or newer |
| Device | A physical iPhone (the simulator has no camera) |

## Installation

The SDK is distributed as a binary XCFramework via Swift Package Manager:

1. In Xcode: *File → Add Package Dependencies…* and enter
   `https://gitlab.development.captur.ai/Captur/captur-mobile-sdk-ios`
2. Choose the dependency rule (this demo uses *Up to Next Major Version* from
   `0.1.0`) and add the `CapturSDK` product to your app target.

The package is hosted on Captur's GitLab and requires credentials. Captur
provides an access token — put it in `~/.netrc` so Xcode and SPM can resolve
the package:

```
machine gitlab.development.captur.ai
login <your-username>
password <your-access-token>
```

## Setup

1. **API key** — paste the API key Captur gave you into
   [`CapturDemo/CapturConfig.swift`](CapturDemo/CapturConfig.swift).
2. **Camera permission** — `NSCameraUsageDescription` is already set in the
   target's Info settings. The SDK checks permission but never prompts; the app
   requests access before opening the camera.
3. Build and run on a physical device.

## The SDK lifecycle in five steps

Pick a use case in the app and it walks you through the lifecycle one step at a
time — each step in the UI runs exactly one SDK call, and the same numbered
comments appear in
[`CapturDemo/CaptureFlowModel.swift`](CapturDemo/CaptureFlowModel.swift).
Before everything, initialize once: `Captur(apiKey:)`, one instance for the
app's lifetime.

1. **Prepare the session** — `captur.prepareSession(policyType:location:reference:metadata:)`
   authenticates with your API key and downloads the on-device model; call it
   early, ahead of capture. The demo's two policy types are `"eBike"` and
   `"package"`.
2. **Prepare the camera** — `session.prepareCamera(location:onCapturEvent:)`
   loads the models and returns a `CapturCameraController`. The app must hold
   camera permission first (`AVCaptureDevice.requestAccess(for: .video)`) — the
   SDK checks but never prompts.
3. **Open the camera** — presenting the SwiftUI `CapturCameraScreen` is what
   starts the preview and live predictions; there is no `start()` call.
4. **Handle events** — every result arrives through the single event callback:
   `.prediction` (live guidance per frame), `.finalDecision` (the outcome), and
   `.failed`. Capture with `controller.captureImage()` for a manual shutter, or
   let the SDK finalize automatically when the photo looks consistently good or
   on timeout (see `finalDecision.trigger`).
5. **Close** — removing `CapturCameraScreen` from the view hierarchy closes the
   camera and the session; there is no `close()` call. Each new attempt starts
   a new session.

The final decision carries the JPEG (`finalDecision.imageData`) and the
decision (`PASS` / `FAIL` / `IMPROVABLE` / `INSUFFICIENT_INFORMATION`). What
happens next — displaying, persisting, uploading — is owned by the app; the SDK
does not upload images.

## File map

- [`CapturDemoApp.swift`](CapturDemo/CapturDemoApp.swift) — app entry; owns the one flow model.
- [`CapturConfig.swift`](CapturDemo/CapturConfig.swift) — API key placeholder.
- [`UseCase.swift`](CapturDemo/UseCase.swift) — the two demo use cases (policy type, demo location, labels).
- [`CaptureFlowModel.swift`](CapturDemo/CaptureFlowModel.swift) — **the SDK showcase**: the full lifecycle as one small state machine, one method per step.
- [`HomeView.swift`](CapturDemo/HomeView.swift) — use-case picker.
- [`FlowView.swift`](CapturDemo/FlowView.swift) — the step-by-step walkthrough: runs and explains each SDK call.
- [`CaptureView.swift`](CapturDemo/CaptureView.swift) — camera screen with overlay and result panel.

## CI

A GitHub Actions workflow ([`.github/workflows/build.yml`](.github/workflows/build.yml))
builds the app for the iOS Simulator on every push and pull request. It
authenticates to Captur's GitLab with a repository secret
(`CAPTUR_GITLAB_ACCESS_TOKEN`) via `~/.netrc` and uses
`-disableAutomaticPackageResolution`, so `Package.resolved` must stay in sync
with the pinned SDK version. No API key is needed on CI — the app is built, not run.

## Should this repo be public?

**Recommendation: keep it private and share by invitation.**

- The SDK package resolves only with Captur GitLab credentials, so a public repo
  would not build for anyone outside a client engagement — no self-serve value.
- A public repo that fails to resolve its main dependency makes a worse first
  impression than a clean invite, and it advertises internal infrastructure
  (`gitlab.development.captur.ai`) unnecessarily.
- Public repos are a standing surface that must be kept free of tokens and keys
  forever, including in git history.

Revisit once the SDK is distributed from a publicly reachable endpoint — at that
point a public demo becomes genuinely useful and this repo is ready for it (no
secrets are committed; the API key is a placeholder).

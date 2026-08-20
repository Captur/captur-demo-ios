# CapturSDK — What the Android Demo App Needs

The iOS demo (`captur-demo-ios`, SDK 0.4.0) exercises the SDK surface below. An
Android SDK that covers this list supports a 1:1 port of the demo.

## The demo flow and what each step requires

1. **Init once** — `Captur(apiKey)`, one instance for the app lifetime.
2. **Prepare session** — `prepareSession(policyType, location, reference)` for the
   policy types `eBike`, `eScooter`, `package`. The host supplies the coordinate
   (the SDK has no GPS) and a required `reference` string (the demo uses a UUID).
   This is the heavy call (model download) — the demo shows a spinner on it, and a
   distinguishable authentication error (bad/missing API key) to surface.
3. **Prepare camera** — `prepareCamera(location, configuration, onEvent)` returning
   a camera controller. Configuration must include `disableAuto` (demo has a toggle
   for it). The host holds camera permission; the SDK only checks it.
4. **Camera view** — an embeddable, chrome-free camera view bound to the controller.
   Its lifecycle drives capture: attaching starts preview + live predictions,
   detaching stops them. All demo UI (shutter, toggles, overlays) is drawn on top.
5. **Events** (main thread): `prediction` per frame, `finalDecision` on capture,
   `failed` on errors.
6. **Close** — `controller.close()` ends the camera and its session; required
   cleanup. The demo calls it from the result screen only.

## Behavioral rules the demo depends on

- **One camera per session.** A second `prepareCamera` on the same session fails
  (`cameraAlreadyActive`).
- **Dismiss ≠ close.** Detaching the camera view keeps the controller and session
  alive; re-attaching the same controller resumes capture. The demo's X button and
  "Resume Camera" button rely on this.
- **Retake** — `retake()` discards a final decision and resumes the still-attached
  camera.
- **Auto + manual capture.** Auto finalizes on sustained good frames or timeout
  (`trigger`: `continuousGood` / `timeout` / `manual`); `captureImage()` is the
  manual shutter. Its result arrives as the `finalDecision` event, not a return
  value. With `disableAuto`, only manual capture finalizes.
- **Camera controls** — toggle position (front/back), lens (wide/ultra-wide),
  torch, zoom; unsupported combinations fail with typed errors the demo shows.

## Data the demo displays

- From `prediction`: only `decision.reasonCode` (per-label output is internal
  since 0.3.0 and not needed).
- From `finalDecision`: the JPEG bytes and the `trigger`. Note `decision` can be
  nil on manual/timeout captures.
- Error messages: human-readable descriptions for session and camera errors.
- The SDK version string at runtime (shown in the demo's footer).

## Checklist

- [ ] `Captur(apiKey)`
- [ ] `prepareSession(policyType, location, reference)` + auth error
- [ ] `prepareCamera(location, configuration(disableAuto), onEvent)`
- [ ] Embeddable camera view; lifecycle starts/stops capture; resume by re-attach
- [ ] Events: `prediction` (reasonCode), `finalDecision` (JPEG, trigger), `failed`
- [ ] `captureImage()`, `retake()`, `close()`
- [ ] Position / lens / torch / zoom toggles with typed errors
- [ ] Runtime SDK version string

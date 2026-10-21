# GOZEN BOARDING PRO web

This is the same Flutter application, compiled for the browser. The browser
opens a clearly labelled, in-memory walkthrough first. Its seven tabs and
sample-card validation do not use Firebase and do not persist passenger data.
Refreshing the page clears the demo. All sample names and equipment are fictional.
The opening flight list offers LS1730, OR3057 and BY412. Use **Uçuş Değiştir**
to return to it. Passenger records, watchlists, logs and closure state belong to
each selected flight; card validation uses that flight's code and date.

Use **Yetkili Giriş** to open the existing Firebase Auth / Firestore application.
The active-profile and security migration documented in SECURITY_HANDOVER.md
still applies. This web port does not deploy rules or activate accounts.
Real-account sign-in requires an approved existing account; no credentials are
included and no account was created for the preview. Live sign-in is not part
of the automated browser tests.

## Platform support

- Firebase initialization uses the existing generated web app configuration.
- PDF417, QR, Aztec and DataMatrix camera capture use mobile_scanner's web
  support. A camera-capable browser, HTTPS and user permission are required.
  Physical camera and flashlight behaviour require real-device testing.
- ML Kit OCR remains available on Android/iOS. Web does not load that native
  implementation; use barcode capture or explicit manual verification instead.
- Both CSV report paths create an in-memory XFile. share_plus uses browser
  sharing where available and a download fallback otherwise. Export audit
  records contain only the filename, never a data/blob URL.
- Android and web run from the same source; the web entry does not change the
  native AuthGate entry.

## Checks and delivery

The web workflow runs analysis, existing validation tests, an interactive
walkthrough widget regression in Chrome, and `flutter build web --release
--no-web-resources-cdn`. Self-hosted CanvasKit assets are included in the output.
The Android workflow also runs on this branch to check the native build.

The generated `build/web` output is published to an owner-private Site. Source
changes remain on `feat/web-preview`, based on the security-fix branch; main
is not modified or merged automatically.

# MusicSync

MusicSync is a Flutter-based LAN music folder mirror sync tool for Windows and Android.

## Status

This repository now contains a working first-pass product flow built around:

- `Home` as a lightweight overview and entry page
- `Transfer` as the main working page for:
  - connecting to a peer
  - selecting the local source directory
  - opening the preview/detail workflow
- `Preview` as the detailed review-and-sync page
  - preview summary
  - diff list and filtering
  - sync execution
  - in-page execution result feedback

The repository also contains:

- product and implementation docs in `docs/`
- the Flutter application in `lib/`
- widget and unit tests in `test/`

## Next Steps

1. Run `flutter pub get`.
2. Let Flutter generate missing platform folders if needed.
3. Continue hardening the current flow:
   - device discovery stability
   - HTTP control plane robustness
   - preview/detail UX polish
   - sync execution resilience and reporting
   - music metadata and conflict semantics

## CI Build Artifacts

The workflow at `.github/workflows/build-installers.yml` builds:

- verified Flutter release inputs via `flutter analyze` and `flutter test`
- signed Android `app-armeabi-v7a-release.apk`
- signed Android `app-arm64-v8a-release.apk`
- signed Android `app-release.aab`
- Windows portable bundle `.zip`
- Windows Inno Setup installer `.exe`

Before running it in GitHub Actions, add these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

For local signing, copy `android/key.properties.example` to `android/key.properties` and point `storeFile` at your keystore.

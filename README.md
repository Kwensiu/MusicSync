# MusicSync

MusicSync is a Flutter-based LAN music folder mirror sync tool for Windows and Android.

## Status

This repository currently contains:

- product and implementation docs in `docs/`
- an initial Flutter app skeleton in `lib/`
- the first pass of routing and placeholder screens

## Next Steps

1. Run `flutter pub get`.
2. Let Flutter generate missing platform folders if needed.
3. Implement:
   - directory access
   - TCP connection flow
   - scanning and diff engine
   - preview and execution wiring

## CI Build Artifacts

The workflow at `.github/workflows/build-installers.yml` builds:

- signed Android `app-release.apk`
- Windows portable bundle `.zip`
- Windows Inno Setup installer `.exe`

Before running it in GitHub Actions, add these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

For local signing, copy `android/key.properties.example` to `android/key.properties` and point `storeFile` at your keystore.

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

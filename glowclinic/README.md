# GlowClinic

Flutter demo application for clinic booking, branch map, GlowBot, local notifications, biometrics, and GlowSpin.

## Run

1. Install Flutter SDK and Android SDK compatible with the Flutter version in use.
2. From this folder run `flutter pub get`.
3. Configure Gemini locally; do not commit the key:

   ```bash
   flutter run --dart-define-from-file=dart_defines.json
   ```

4. For Android biometrics, enroll a fingerprint/face or device credential in Android settings and test on a real device. Emulator support varies.
5. Open Settings in the app and use **Tes notifikasi (5 detik)** to verify notifications.

## Important demo notes

- Branch names and coordinates seeded in `lib/core/core.dart` are demo locations around Yogyakarta, not verified clinic addresses. Replace them with the clinic's real branch details before production.
- QRIS is a simulation; it does not move money.
- Staff accounts are intentionally not created through public registration. Provision staff accounts through a controlled admin workflow.
- Gemini API keys bundled in a mobile app can be extracted. For production, call Gemini through a secured backend with quotas and key restrictions rather than shipping a key in the app.
- The uploaded archive did not contain `pubspec.yaml`; a dependency manifest has been added based on the imports found in the source. Run `flutter pub get` and `flutter analyze` in your local Flutter environment to confirm package/API compatibility.

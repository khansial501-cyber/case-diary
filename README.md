# Case Diary  (Flutter, Android 10+)

Offline-first court diary for lawyers: hearings, cases, judges, documents, receipts, reminders,
Urdu/English, dark/light, encrypted data, resellable per-phone activation.

> **Honest status:** this whole project was written without access to a Flutter/Dart compiler
> (my build environment cannot download the SDK). Every Dart file passed a syntax check, the
> activation-code maths was verified independently, and the unit tests are included - but the
> first `flutter pub get` / `flutter run` on your computer is the real compile test. If anything
> prints an error, copy it to me and I will fix it quickly. Expect a handful of small fixes.

---------------------------------------------------------------------------------------------------

## 1. First-time setup (once)

1. Install Flutter + Android Studio (for the Android SDK) + VS Code with the *Flutter* extension.
   Run `flutter doctor` until the Android toolchain is green.
2. Unzip this project, open the folder `case_diary` in VS Code, open a terminal there.
3. Run the setup script:
   * Windows: `setup.bat`
   * Mac/Linux: `./setup.sh`

   It runs `flutter create` (generates the `android/` folder), then
   `dart run tools/apply_android_config.dart` (installs the permissions/manifest, switches to
   `FlutterFragmentActivity` for fingerprint unlock, sets `minSdk 29`, enables desugaring), then
   `flutter pub get`.
4. Plug in your phone (Developer options -> USB debugging) and run `flutter run`.
5. Release APK for customers: `flutter build apk --release`
   (file: `build/app/outputs/flutter-apk/app-release.apk`).
   For Play Store later use `flutter build appbundle` and create your own signing key.

If `flutter pub get` complains about a version conflict, run `flutter pub upgrade` and send me the
message if it persists.

## 2. Selling the app: activation codes

1. The customer installs the APK, opens it, and sees their **Device ID**. They send it to you.
2. Open `tools/Key_Generator.html` in any browser (works offline), paste the Device ID, choose
   Lifetime / 1 / 3 / 6 / 12 months / custom date, click **Generate**, send them the code.
3. The code only works on that phone, is checked fully offline (Ed25519 signature), and cannot be
   forged without your private key. A code for another phone, a changed date, or a typo is rejected.
4. When the licence expires the app becomes **read-only** (viewing and exports still work) and shows
   a Renew banner; a new code unlocks it again. Rolling the phone clock back does not extend it.

### IMPORTANT - replace the demo keypair before you sell
The keypair shipped here was generated during our chat, so treat it as a demo.
1. Open `Key_Generator.html`, scroll to *Advanced*, click **Generate new keypair**.
2. Paste the **public key** into `lib/core/config.dart` -> `kPublicKeyHex`, rebuild the app.
3. Paste the **private seed** into `Key_Generator.html` replacing `SEED_HEX`.
4. Keep `Key_Generator.html` private (it is in `.gitignore`) and back it up. If you lose the seed you
   cannot issue codes for already-sold apps.

## 3. Optional cloud accounts + sync (Firebase)
Without Firebase the app is fully offline with a local login (password-reset works through the
registered phone number). To enable email password-reset and multi-device sync:
1. Create a Firebase project, enable *Authentication -> Email/Password* and *Firestore*.
2. Add an Android app with package `com.jdsoftware.case_diary`.
3. Copy `apiKey`, `appId`, `messagingSenderId`, `projectId` into `lib/core/config.dart`.
4. Firestore rules: only allow `users/{uid}/**` for the signed-in user.
Sync covers text data (cases, hearings, clients, fees...). Attached files stay on the phone - use
encrypted backups for those.

## 4. What is where
```
lib/core/       config, theme, strings (EN/UR), roles & categories, router, gate, providers
lib/data/       SQLCipher schema (db.dart), models, repo.dart (all queries)
lib/services/   license, auth, app lock, notifications, PDF, thermal printing, messaging, backup, sync
lib/features/   home (hearings, lists), cases (form, details, documents), license, auth, extras, settings
tools/          Key_Generator.html (PRIVATE), apply_android_config.dart
android_overlay/AndroidManifest.xml
test/           licence + utility unit tests   ->  flutter test
```

## 5. Feature checklist (what was built)
* **Phase 1** hearings by date (today default, prev/next, picker, today/tomorrow counts, tomorrow
  highlighted, overdue banner), Add/Edit case with category->default roles (8+ built-in roles,
  custom roles/categories, Urdu labels), title built from names only ("Ali etc Vs Ahmad etc"),
  extra parties, nature/court/judge/client autocomplete from history, "Set next date" (writes a
  history row), decided/reopen, priority, search + filters, calendar-style history timeline.
* **Phase 2** offline Ed25519 licence + renewal, firm setup/logo, register/login/forgot, PIN +
  biometric lock with auto-lock, lawyers (multi-lawyer + filter), SQLCipher database key in Keystore.
* **Phase 3** per-case reminders + evening/morning digests (next 14 days, rebuilt on every change),
  document scanner (multi-page -> PDF) / camera / gallery / files grouped by type, case-file PDF
  (details + history + all documents), SMS/WhatsApp/share/call with editable EN/UR templates.
* **Phase 4** 58/80 mm Bluetooth thermal receipts (rendered by Flutter so Urdu shapes correctly;
  falls back to the system print dialog), calendar with counts, clash warning, cause list PDF,
  clients directory, reminders list, fees + payments, reports, full Urdu/RTL.
* **Phase 5** AES-256-GCM password-protected backup/restore (database + documents), weekly backup
  reminder, optional Firestore sync, assistant/owner mode (hides fees), screenshot blocking,
  settings, unit tests, setup scripts.

## 6. Decisions and honest limitations
* **No code-generation:** I used `sqflite_sqlcipher` with plain SQL instead of Drift, and a simple
  built-in EN/UR string table instead of ARB files, so there is no `build_runner` step for you.
* **Clash warning** has no hearing *time* field, so it warns when one day has hearings in 2+ courts.
* **Documents** live in the app's private folder (Android sandbox + device encryption); individual
  files are not separately encrypted, but backups are.
* **Backups** are built in memory - very large libraries (hundreds of MB) may be slow.
* **Urdu in PDFs** uses Noto Naskh via the `pdf` package; if shaping looks off on your device, tell
  me and I will switch those pages to image rendering like the receipts.
* **Skipped (needs native/Google setup):** home-screen widget, Google sign-in, cloud storage of
  document files. Everything else in the brief is implemented.
* Fonts (Inter, Noto Nastaliq Urdu, Noto Naskh Arabic) are bundled under the SIL Open Font Licence.
* Default role pairs for categories not named in the brief (Family, Rent, Banking, Service, Tax,
  Consumer, Arbitration) are my choices - change them in `lib/core/roles.dart`.
* Notifications created before a reboot keep working; digest *contents* refresh whenever you open
  the app or change data.

## 7. Manual test checklist (10 minutes)
1. Fresh install -> Device ID shown -> generate code -> activate -> setup -> register -> hearings.
2. Wrong-phone code / edited code is rejected. 1-day-past code shows "expired".
3. Add case "Ali" (etc on) Vs "Ahmad" (etc on) -> card shows "Ali etc Vs Ahmad etc".
4. Pick Appeal -> roles become Appellant / Respondent; add a custom role and category.
5. Set next date twice -> two timeline entries; card shows the new date.
6. Add reminder 2 minutes ahead -> notification fires (screen off too).
7. Scan a 2-page document -> one PDF in Documents; export case PDF contains it.
8. Pair a thermal printer -> Test print in Urdu and English.
9. Create backup, uninstall, reinstall, activate, restore -> data and documents are back.
10. Turn on PIN + fingerprint, background the app 1 minute -> lock screen appears.

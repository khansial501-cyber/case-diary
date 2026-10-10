/// ---------------------------------------------------------------------------
/// App configuration. Edit values here, never anywhere else.
/// ---------------------------------------------------------------------------

/// Ed25519 PUBLIC key (hex, 64 chars). The matching private key lives only in
/// Key_Generator.html. See README "Activation codes" to replace this pair
/// BEFORE you sell the app.
const String kPublicKeyHex =
    'f5260ed2f521ef340cd14b6ab0def83cff3136e522254ff8a1cb0b9813af9884';

/// Default country calling code used to normalise phone numbers (Pakistan).
const String kDefaultCountryCode = '92';

/// Name shown before the client enters their own firm name.
const String kAppName = 'Case Diary';

/// Optional Firebase settings (Auth + Firestore sync). Leave as-is to run in
/// fully-offline "local account" mode. To enable, create a Firebase project,
/// add an Android app with package `com.jdsoftware.case_diary`, then paste the
/// values from the console (Project settings > Your apps) here.
const String kFirebaseApiKey = '';
const String kFirebaseAppId = '';
const String kFirebaseMessagingSenderId = '';
const String kFirebaseProjectId = '';

bool get firebaseConfigured =>
    kFirebaseApiKey.isNotEmpty &&
    kFirebaseAppId.isNotEmpty &&
    kFirebaseProjectId.isNotEmpty;

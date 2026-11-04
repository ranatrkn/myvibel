// Kapalı beta App Check ayarları.
// Play Store / web production: appCheckBetaModu = false.
// Web reCAPTCHA site key: Firebase Console > App Check > Web app.

const bool appCheckBetaModu = false;

/// Yerel debug için Firebase Console'dan alınan token.
/// Repoya gerçek token koyma; boş bırak, debug cihazda yerel ayarla.
const String appCheckDebugTokenSabit = String.fromEnvironment(
  'APP_CHECK_DEBUG_TOKEN',
  defaultValue: '',
);

/// Web App Check (reCAPTCHA v3) site key.
/// Console'dan alıp buraya veya --dart-define=APP_CHECK_WEB_SITE_KEY=... ile ver.
const String appCheckWebRecaptchaSiteKey = String.fromEnvironment(
  'APP_CHECK_WEB_SITE_KEY',
  defaultValue: '',
);

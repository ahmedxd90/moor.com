class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://uhaugikrudchlunaufjj.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_wPa5bmVYZ7D-oy9qHPqHKg_Jvb0rgpX',
  );

  static const appName = 'Saki Chat';
  static const appVersion = '1.0.0';
  static const androidPackage = 'saki.chat.co';
  static const authRedirectOverride = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      !supabaseUrl.contains('YOUR_PROJECT') &&
      supabasePublishableKey != 'YOUR_SUPABASE_PUBLISHABLE_KEY';
}

class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://faxtmvvovorxximsnxzy.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_tZvg-hzXKI10JxiHJRht3w_Aa7rFOjN',
  );

  static const appName = 'Saki Chat';
  static const appVersion = '1.0.1';
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

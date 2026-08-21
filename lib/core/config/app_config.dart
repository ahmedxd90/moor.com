class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'YOUR_SUPABASE_PUBLISHABLE_KEY',
  );

  static const appName = 'Saki Chat';
  static const appVersion = '1.0.0';
  static const androidPackage = 'saki.chat.co';

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      !supabaseUrl.contains('YOUR_PROJECT') &&
      supabasePublishableKey != 'YOUR_SUPABASE_PUBLISHABLE_KEY';
}

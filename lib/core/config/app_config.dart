const _fallbackUrl = 'https://llefbftizpnjpjnvaarc.supabase.co';
const _fallbackKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxsZWZiZnRpenBuanBqbnZhYXJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTMzNzcsImV4cCI6MjA5MTgyOTM3N30.hKXo6IxsV4uF0l1OVbF2vf1FzjdKUvtS7VTdm5TVqO8';

class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _fallbackUrl,
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _fallbackKey,
  );
  static const osmTileUrlTemplate = String.fromEnvironment(
    'OSM_TILE_URL_TEMPLATE',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const osmTileAttribution = String.fromEnvironment(
    'OSM_TILE_ATTRIBUTION',
    defaultValue: 'OpenStreetMap contributors',
  );
  static const osrmRouteBaseUrl = String.fromEnvironment(
    'OSRM_ROUTE_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );
  static const pushFunctionName = String.fromEnvironment(
    'SUPABASE_PUSH_FUNCTION_NAME',
    defaultValue: 'send-push-notification',
  );
  static const passwordResetScheme = 'quickdeliver';
  static const authCallbackHost = 'auth-callback';
  static const passwordResetHost = 'reset-password';
  static const demoMode = bool.fromEnvironment(
    'QUICKDELIVER_DEMO_MODE',
    defaultValue: false,
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isMapsConfigured => osmTileUrlTemplate.isNotEmpty;

  static bool get isRoutingConfigured => osrmRouteBaseUrl.isNotEmpty;

  static String get authCallbackUrl =>
      '$passwordResetScheme://$authCallbackHost';

  static String get passwordResetRedirectUrl =>
      '$passwordResetScheme://$passwordResetHost';
}

class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
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

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../supabase/providers/supabase_client_provider.dart';

final passwordRecoveryServiceProvider =
    ChangeNotifierProvider<PasswordRecoveryService>((ref) {
      final service = PasswordRecoveryService(
        client: AppConfig.isSupabaseConfigured
            ? ref.read(supabaseClientProvider)
            : null,
      );
      ref.onDispose(service.dispose);
      return service;
    });

class PasswordRecoveryService extends ChangeNotifier {
  PasswordRecoveryService({
    required SupabaseClient? client,
    AppLinks? appLinks,
  }) : _client = client,
       _appLinks = appLinks ?? AppLinks();

  final SupabaseClient? _client;
  final AppLinks _appLinks;

  StreamSubscription<Uri>? _deepLinkSubscription;
  StreamSubscription<AuthState>? _authStateSubscription;

  bool _isInitialized = false;
  bool _isHandlingLink = false;
  bool _hasRecoveryContext = false;
  bool _pendingResetNavigation = false;
  String? _lastError;

  bool get isInitialized => _isInitialized;
  bool get isHandlingLink => _isHandlingLink;
  bool get hasRecoveryContext => _hasRecoveryContext;
  bool get pendingResetNavigation => _pendingResetNavigation;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    if (_client == null) {
      notifyListeners();
      return;
    }

    _authStateSubscription = _client.auth.onAuthStateChange.listen((event) {
      final authEvent = event.event;
      if (authEvent == AuthChangeEvent.passwordRecovery) {
        _hasRecoveryContext = true;
        _pendingResetNavigation = true;
        _lastError = null;
        notifyListeners();
        return;
      }

      if (authEvent == AuthChangeEvent.signedOut && _hasRecoveryContext) {
        clearRecoveryContext(notify: true);
      }
    });

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleIncomingUri(initialUri);
      }
    } catch (error) {
      _lastError = error.toString();
    }

    _deepLinkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleIncomingUri(uri)),
      onError: (Object error) {
        _lastError = error.toString();
        notifyListeners();
      },
    );

    notifyListeners();
  }

  void markResetRouteVisited() {
    if (!_pendingResetNavigation) {
      return;
    }
    _pendingResetNavigation = false;
    notifyListeners();
  }

  void clearRecoveryContext({bool notify = true}) {
    _hasRecoveryContext = false;
    _pendingResetNavigation = false;
    _lastError = null;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    if (_client == null || !_looksLikeAuthUri(uri)) {
      return;
    }

    _isHandlingLink = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _client.auth.getSessionFromUrl(uri);
      if (response.redirectType == 'recovery') {
        _hasRecoveryContext = true;
        _pendingResetNavigation = true;
      } else {
        _lastError = null;
      }
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _isHandlingLink = false;
      notifyListeners();
    }
  }

  bool _looksLikeAuthUri(Uri uri) {
    final hostMatches =
        uri.host == AppConfig.passwordResetHost ||
        uri.host == AppConfig.authCallbackHost;
    final pathMatches =
        uri.pathSegments.contains(AppConfig.passwordResetHost) ||
        uri.pathSegments.contains(AppConfig.authCallbackHost);
    final params = _parseUriParameters(uri);
    return uri.scheme == AppConfig.passwordResetScheme &&
        (hostMatches ||
            pathMatches ||
            uri.path == '/${AppConfig.passwordResetHost}' ||
            uri.path == '/${AppConfig.authCallbackHost}') &&
        (params['type'] == 'recovery' ||
            params['type'] == 'signup' ||
            params.containsKey('access_token') ||
            params.containsKey('refresh_token'));
  }

  Map<String, String> _parseUriParameters(Uri uri) {
    final resolved = uri.hasQuery
        ? uri.toString().replaceAll('#', '&')
        : uri.toString().replaceAll('#', '?');
    return Uri.parse(resolved).queryParameters;
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    _authStateSubscription?.cancel();
    super.dispose();
  }
}

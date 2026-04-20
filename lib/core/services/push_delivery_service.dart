import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/operations/domain/models/app_notification.dart';
import '../config/app_config.dart';
import '../supabase/providers/supabase_client_provider.dart';
import '../utils/notification_type_codec.dart';

final pushDeliveryServiceProvider = Provider<PushDeliveryService>((ref) {
  return PushDeliveryService(ref);
});

class PushDeliveryService {
  const PushDeliveryService(this._ref);

  final Ref _ref;

  Future<void> sendPushNotification(AppNotification notification) async {
    if (!AppConfig.isSupabaseConfigured) {
      return;
    }

    try {
      await _ref
          .read(supabaseClientProvider)
          .functions
          .invoke(
            AppConfig.pushFunctionName,
            body: {
              'userIds': [notification.userId],
              'title': notification.title,
              'body': notification.body,
              'orderId': notification.orderId,
              'type': notification.type.storageValue,
            },
          );
    } catch (_) {
      // Push dispatch remains best-effort until the edge function is deployed.
    }
  }
}

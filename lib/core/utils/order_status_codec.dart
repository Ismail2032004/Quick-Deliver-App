import '../../features/customer/domain/models/delivery_order.dart';

extension OrderStatusCodec on OrderStatus {
  String get storageValue {
    return switch (this) {
      OrderStatus.pending => 'pending',
      OrderStatus.confirmed => 'confirmed',
      OrderStatus.preparing => 'preparing',
      OrderStatus.ready => 'ready',
      OrderStatus.pickedUp => 'picked_up',
      OrderStatus.delivering => 'delivering',
      OrderStatus.deliveredPendingProofReview =>
        'delivered_pending_proof_review',
      OrderStatus.delivered => 'delivered',
      OrderStatus.cancelled => 'cancelled',
    };
  }

  String get label {
    return switch (this) {
      OrderStatus.pending => 'Pending',
      OrderStatus.confirmed => 'Confirmed',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.ready => 'Ready',
      OrderStatus.pickedUp => 'Picked up',
      OrderStatus.delivering => 'Delivering',
      OrderStatus.deliveredPendingProofReview => 'Proof review',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
  }
}

OrderStatus orderStatusFromStorage(String? value) {
  return switch (value) {
    'pending' => OrderStatus.pending,
    'confirmed' => OrderStatus.confirmed,
    'preparing' => OrderStatus.preparing,
    'ready' => OrderStatus.ready,
    'picked_up' => OrderStatus.pickedUp,
    'delivering' => OrderStatus.delivering,
    'delivered_pending_proof_review' =>
      OrderStatus.deliveredPendingProofReview,
    'delivered' => OrderStatus.delivered,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.pending,
  };
}

extension DeliveryProgressStatusCodec on DeliveryProgressStatus {
  String get storageValue {
    return switch (this) {
      DeliveryProgressStatus.assigned => 'assigned',
      DeliveryProgressStatus.accepted => 'accepted',
      DeliveryProgressStatus.pickedUp => 'picked_up',
      DeliveryProgressStatus.delivering => 'delivering',
      DeliveryProgressStatus.proofReview => 'delivered_pending_proof_review',
      DeliveryProgressStatus.delivered => 'delivered',
      DeliveryProgressStatus.cancelled => 'cancelled',
    };
  }

  String get label {
    return switch (this) {
      DeliveryProgressStatus.assigned => 'Awaiting rider response',
      DeliveryProgressStatus.accepted => 'Accepted by rider',
      DeliveryProgressStatus.pickedUp => 'Picked up',
      DeliveryProgressStatus.delivering => 'Delivering',
      DeliveryProgressStatus.proofReview => 'Proof review',
      DeliveryProgressStatus.delivered => 'Delivered',
      DeliveryProgressStatus.cancelled => 'Cancelled',
    };
  }
}

DeliveryProgressStatus? deliveryProgressStatusFromStorage(String? value) {
  return switch (value) {
    null => null,
    'assigned' => DeliveryProgressStatus.assigned,
    'accepted' => DeliveryProgressStatus.accepted,
    'confirmed' => DeliveryProgressStatus.accepted,
    'picked_up' => DeliveryProgressStatus.pickedUp,
    'delivering' => DeliveryProgressStatus.delivering,
    'delivered_pending_proof_review' => DeliveryProgressStatus.proofReview,
    'delivered' => DeliveryProgressStatus.delivered,
    'cancelled' => DeliveryProgressStatus.cancelled,
    _ => null,
  };
}

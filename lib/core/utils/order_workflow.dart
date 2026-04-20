import '../../features/customer/domain/models/delivery_order.dart';

bool canAssignRider(DeliveryOrder order) {
  return order.status == OrderStatus.ready ||
      order.status == OrderStatus.pickedUp ||
      order.status == OrderStatus.delivering;
}

bool canRiderAccept(DeliveryOrder order) {
  return order.riderId != null &&
      order.status == OrderStatus.ready &&
      (order.deliveryStatus == null ||
          order.deliveryStatus == DeliveryProgressStatus.assigned);
}

bool canRiderDecline(DeliveryOrder order) {
  return canRiderAccept(order);
}

bool canRiderMarkPickedUp(DeliveryOrder order) {
  return order.riderId != null &&
      order.status == OrderStatus.ready &&
      order.deliveryStatus == DeliveryProgressStatus.accepted;
}

bool canRiderMarkDelivering(DeliveryOrder order) {
  return order.riderId != null && order.status == OrderStatus.pickedUp;
}

bool canAttachPickupProof(DeliveryOrder order) {
  return false;
}

bool canAttachDeliveryProof(DeliveryOrder order) {
  return order.riderId != null &&
      order.status == OrderStatus.delivering;
}

bool canPublishRiderLocation(DeliveryOrder order) {
  return order.riderId != null &&
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.deliveredPendingProofReview &&
      order.status != OrderStatus.cancelled;
}

bool canEditDeliveryDestination(DeliveryOrder order) {
  return order.status.index < OrderStatus.pickedUp.index &&
      order.status != OrderStatus.cancelled &&
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.deliveredPendingProofReview;
}

bool canBusinessConfirmDelivery(DeliveryOrder order) {
  return order.deliveryProofImageUrl != null &&
      order.status == OrderStatus.deliveredPendingProofReview;
}

bool isStatusTransitionAllowed(
  OrderStatus current,
  OrderStatus next,
) {
  if (current == next) {
    return true;
  }

  return switch (current) {
    OrderStatus.pending =>
      next == OrderStatus.confirmed || next == OrderStatus.cancelled,
    OrderStatus.confirmed =>
      next == OrderStatus.preparing || next == OrderStatus.cancelled,
    OrderStatus.preparing =>
      next == OrderStatus.ready || next == OrderStatus.cancelled,
    OrderStatus.ready => next == OrderStatus.pickedUp,
    OrderStatus.pickedUp => next == OrderStatus.delivering,
    OrderStatus.delivering =>
      next == OrderStatus.deliveredPendingProofReview,
    OrderStatus.deliveredPendingProofReview => next == OrderStatus.delivered,
    OrderStatus.delivered => false,
    OrderStatus.cancelled => false,
  };
}

List<OrderStatus> ownerAllowedStatuses(OrderStatus current) {
  return switch (current) {
    OrderStatus.pending => const [OrderStatus.confirmed, OrderStatus.cancelled],
    OrderStatus.confirmed => const [
      OrderStatus.preparing,
      OrderStatus.cancelled,
    ],
    OrderStatus.preparing => const [OrderStatus.ready, OrderStatus.cancelled],
    OrderStatus.deliveredPendingProofReview => const [OrderStatus.delivered],
    _ => const [],
  };
}

List<OrderStatus> riderAllowedStatuses(OrderStatus current) {
  return switch (current) {
    OrderStatus.pickedUp => const [OrderStatus.delivering],
    _ => const [],
  };
}

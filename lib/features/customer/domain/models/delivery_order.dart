import 'order_item.dart';
import '../../../../core/utils/order_destination_source_codec.dart';

const _deliveryOrderUnset = Object();

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  pickedUp,
  delivering,
  deliveredPendingProofReview,
  delivered,
  cancelled,
}

enum DeliveryProgressStatus {
  assigned,
  accepted,
  pickedUp,
  delivering,
  proofReview,
  delivered,
  cancelled,
}

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.status,
    required this.items,
    required this.createdAt,
    this.destinationSource = OrderDestinationSource.manual,
    this.destinationLatitude,
    this.destinationLongitude,
    this.businessPhone,
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.pickupProofImageUrl,
    this.deliveryProofImageUrl,
    this.trackingEnabled = false,
    this.deliveryStatus,
    this.note,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final OrderStatus status;
  final List<OrderItem> items;
  final DateTime createdAt;
  final OrderDestinationSource destinationSource;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? businessPhone;
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final String? pickupProofImageUrl;
  final String? deliveryProofImageUrl;
  final bool trackingEnabled;
  final DeliveryProgressStatus? deliveryStatus;
  final String? note;

  double get totalAmount => items.fold(0, (sum, item) => sum + item.totalPrice);
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  DeliveryOrder copyWith({
    String? id,
    String? businessId,
    String? businessName,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    OrderStatus? status,
    List<OrderItem>? items,
    DateTime? createdAt,
    OrderDestinationSource? destinationSource,
    Object? destinationLatitude = _deliveryOrderUnset,
    Object? destinationLongitude = _deliveryOrderUnset,
    Object? businessPhone = _deliveryOrderUnset,
    Object? riderId = _deliveryOrderUnset,
    Object? riderName = _deliveryOrderUnset,
    Object? riderPhone = _deliveryOrderUnset,
    Object? pickupProofImageUrl = _deliveryOrderUnset,
    Object? deliveryProofImageUrl = _deliveryOrderUnset,
    bool? trackingEnabled,
    Object? deliveryStatus = _deliveryOrderUnset,
    Object? note = _deliveryOrderUnset,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      destinationSource: destinationSource ?? this.destinationSource,
      destinationLatitude: identical(destinationLatitude, _deliveryOrderUnset)
          ? this.destinationLatitude
          : destinationLatitude as double?,
      destinationLongitude: identical(destinationLongitude, _deliveryOrderUnset)
          ? this.destinationLongitude
          : destinationLongitude as double?,
      businessPhone: identical(businessPhone, _deliveryOrderUnset)
          ? this.businessPhone
          : businessPhone as String?,
      riderId: identical(riderId, _deliveryOrderUnset)
          ? this.riderId
          : riderId as String?,
      riderName: identical(riderName, _deliveryOrderUnset)
          ? this.riderName
          : riderName as String?,
      riderPhone: identical(riderPhone, _deliveryOrderUnset)
          ? this.riderPhone
          : riderPhone as String?,
      pickupProofImageUrl: identical(pickupProofImageUrl, _deliveryOrderUnset)
          ? this.pickupProofImageUrl
          : pickupProofImageUrl as String?,
      deliveryProofImageUrl:
          identical(deliveryProofImageUrl, _deliveryOrderUnset)
          ? this.deliveryProofImageUrl
          : deliveryProofImageUrl as String?,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      deliveryStatus: identical(deliveryStatus, _deliveryOrderUnset)
          ? this.deliveryStatus
          : deliveryStatus as DeliveryProgressStatus?,
      note: identical(note, _deliveryOrderUnset) ? this.note : note as String?,
    );
  }

  List<OrderStatus> get timeline {
    return const [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.pickedUp,
      OrderStatus.delivering,
      OrderStatus.deliveredPendingProofReview,
      OrderStatus.delivered,
    ];
  }
}

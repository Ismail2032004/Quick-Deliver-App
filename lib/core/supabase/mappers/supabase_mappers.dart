import '../../models/app_role.dart';
import '../../../features/customer/domain/models/business.dart';
import '../../../features/customer/domain/models/delivery_order.dart';
import '../../../features/customer/domain/models/order_item.dart';
import '../../../features/customer/domain/models/product.dart';
import '../../../features/operations/domain/models/app_notification.dart';
import '../../../features/operations/domain/models/rider_location.dart';
import '../../models/app_user.dart';
import '../../models/role_application.dart';
import '../../utils/app_role_codec.dart';
import '../../utils/order_destination_source_codec.dart';
import '../../utils/notification_type_codec.dart';
import '../../utils/order_status_codec.dart';

class SupabaseMappers {
  const SupabaseMappers._();

  static AppUser appUserFromMap(Map<String, dynamic> map) {
    final primaryRole = appRoleFromStorage(map['role'] as String?);
    final ownerStatus = roleApplicationStatusFromStorage(
      map['owner_application_status'] as String?,
    );
    final riderStatus = roleApplicationStatusFromStorage(
      map['rider_application_status'] as String?,
    );
    final approvedRoleValues = ((map['approved_roles'] as List?) ?? const [])
        .map((item) => appRoleFromStorage(item?.toString()))
        .whereType<AppRole>()
        .toList(growable: false);
    final normalizedApprovedRoles = <AppRole>{...approvedRoleValues};
    normalizedApprovedRoles.add(AppRole.customer);
    if (primaryRole != AppRole.customer) {
      normalizedApprovedRoles.add(primaryRole);
    }
    if (ownerStatus == RoleApplicationStatus.approved) {
      normalizedApprovedRoles.add(AppRole.owner);
    }
    if (riderStatus == RoleApplicationStatus.approved) {
      normalizedApprovedRoles.add(AppRole.rider);
    }
    final approvedRoles = AppRole.values
        .where(normalizedApprovedRoles.contains)
        .toList(growable: false);

    return AppUser(
      id: map['id'] as String,
      name: (map['full_name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      role: primaryRole,
      phoneNumber: map['phone_number'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      approvedRoles: approvedRoles,
      ownerApplicationStatus:
          approvedRoles.contains(AppRole.owner)
          ? RoleApplicationStatus.approved
          : ownerStatus,
      riderApplicationStatus:
          approvedRoles.contains(AppRole.rider)
          ? RoleApplicationStatus.approved
          : riderStatus,
      ownerApplicationData:
          (map['owner_application_data'] as Map?)?.cast<String, dynamic>() ??
          const {},
      riderApplicationData:
          (map['rider_application_data'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );
  }

  static Map<String, dynamic> appUserToMap(AppUser user) {
    return {
      'id': user.id,
      'full_name': user.name,
      'email': user.email,
      'role': user.role.storageValue,
      'phone_number': user.phoneNumber,
      'avatar_url': user.avatarUrl,
      'approved_roles': user.approvedRoles
          .map((role) => role.storageValue)
          .toList(growable: false),
      'owner_application_status': user.ownerApplicationStatus.storageValue,
      'rider_application_status': user.riderApplicationStatus.storageValue,
      'owner_application_data': user.ownerApplicationData,
      'rider_application_data': user.riderApplicationData,
    };
  }

  static Business businessFromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: (map['name'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      phoneNumber: (map['phone_number'] ?? '') as String,
      imageUrl: (map['image_url'] ?? '') as String,
      rating: ((map['rating'] ?? 0) as num).toDouble(),
      estimatedDeliveryMinutes:
          ((map['estimated_delivery_minutes'] ?? 0) as num).toInt(),
      latitude: ((map['latitude'] ?? 0) as num).toDouble(),
      longitude: ((map['longitude'] ?? 0) as num).toDouble(),
      tags: ((map['tags'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> businessToMap(Business business) {
    return {
      'id': business.id,
      'owner_id': business.ownerId,
      'name': business.name,
      'category': business.category,
      'description': business.description,
      'address': business.address,
      'phone_number': business.phoneNumber,
      'image_url': business.imageUrl,
      'rating': business.rating,
      'estimated_delivery_minutes': business.estimatedDeliveryMinutes,
      'latitude': business.latitude,
      'longitude': business.longitude,
      'tags': business.tags,
    };
  }

  static Product productFromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      businessId: map['business_id'] as String,
      name: (map['name'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      price: ((map['price'] ?? 0) as num).toDouble(),
      imageUrl: (map['image_url'] ?? '') as String,
      isAvailable: (map['is_available'] ?? true) as bool,
      preparationMinutes: ((map['preparation_minutes'] ?? 0) as num).toInt(),
    );
  }

  static Map<String, dynamic> productToMap(Product product) {
    return {
      'id': product.id,
      'business_id': product.businessId,
      'name': product.name,
      'description': product.description,
      'category': product.category,
      'price': product.price,
      'image_url': product.imageUrl,
      'is_available': product.isAvailable,
      'preparation_minutes': product.preparationMinutes,
    };
  }

  static DeliveryOrder orderFromMap(
    Map<String, dynamic> map, {
    required List<OrderItem> items,
    DeliveryProgressStatus? deliveryStatus,
  }) {
    return DeliveryOrder(
      id: map['id'] as String,
      businessId: map['business_id'] as String,
      businessName: (map['business_name'] ?? '') as String,
      customerId: map['customer_id'] as String,
      customerName: (map['customer_name'] ?? '') as String,
      customerPhone: (map['customer_phone'] ?? '') as String,
      deliveryAddress: (map['delivery_address'] ?? '') as String,
      status: orderStatusFromStorage(map['status'] as String?),
      items: items,
      createdAt: DateTime.parse(map['created_at'] as String),
      destinationSource: orderDestinationSourceFromStorage(
        map['destination_source'] as String?,
      ),
      destinationLatitude: (map['destination_latitude'] as num?)?.toDouble(),
      destinationLongitude: (map['destination_longitude'] as num?)?.toDouble(),
      businessPhone: map['business_phone'] as String?,
      riderId: map['rider_id'] as String?,
      riderName: map['rider_name'] as String?,
      riderPhone: map['rider_phone'] as String?,
      pickupProofImageUrl: map['pickup_proof_image_url'] as String?,
      deliveryProofImageUrl: map['delivery_proof_image_url'] as String?,
      trackingEnabled: (map['tracking_enabled'] ?? false) as bool,
      deliveryStatus: deliveryStatus,
      note: map['note'] as String?,
    );
  }

  static Map<String, dynamic> orderToMap(DeliveryOrder order) {
    return {
      'id': order.id,
      'business_id': order.businessId,
      'business_name': order.businessName,
      'customer_id': order.customerId,
      'customer_name': order.customerName,
      'customer_phone': order.customerPhone,
      'delivery_address': order.deliveryAddress,
      'status': order.status.storageValue,
      'destination_source': order.destinationSource.storageValue,
      'destination_latitude': order.destinationLatitude,
      'destination_longitude': order.destinationLongitude,
      'business_phone': order.businessPhone,
      'rider_id': order.riderId,
      'rider_name': order.riderName,
      'rider_phone': order.riderPhone,
      'pickup_proof_image_url': order.pickupProofImageUrl,
      'delivery_proof_image_url': order.deliveryProofImageUrl,
      'tracking_enabled': order.trackingEnabled,
      'note': order.note,
      'total_amount': order.totalAmount,
    };
  }

  static OrderItem orderItemFromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['product_id'] as String,
      productName: (map['product_name'] ?? '') as String,
      unitPrice: ((map['unit_price'] ?? 0) as num).toDouble(),
      quantity: ((map['quantity'] ?? 0) as num).toInt(),
      imageUrl: (map['image_url'] ?? '') as String,
    );
  }

  static Map<String, dynamic> orderItemToMap(OrderItem item, String orderId) {
    return {
      'order_id': orderId,
      'product_id': item.productId,
      'product_name': item.productName,
      'unit_price': item.unitPrice,
      'quantity': item.quantity,
      'image_url': item.imageUrl,
    };
  }

  static RiderLocation riderLocationFromMap(Map<String, dynamic> map) {
    return RiderLocation(
      riderId: map['rider_id'] as String,
      riderName: (map['rider_name'] ?? '') as String,
      latitude: ((map['latitude'] ?? 0) as num).toDouble(),
      longitude: ((map['longitude'] ?? 0) as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      orderId: map['order_id'] as String?,
      isActive: (map['is_active'] ?? false) as bool,
    );
  }

  static Map<String, dynamic> riderLocationToMap(RiderLocation location) {
    return {
      'rider_id': location.riderId,
      'rider_name': location.riderName,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'updated_at': location.updatedAt.toIso8601String(),
      'order_id': location.orderId,
      'is_active': location.isActive,
    };
  }

  static AppNotification notificationFromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: (map['title'] ?? '') as String,
      body: (map['body'] ?? '') as String,
      type: notificationTypeFromStorage(map['type'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      orderId: map['order_id'] as String?,
      isRead: (map['is_read'] ?? false) as bool,
    );
  }

  static Map<String, dynamic> notificationToMap(AppNotification notification) {
    return {
      'id': notification.id,
      'user_id': notification.userId,
      'title': notification.title,
      'body': notification.body,
      'type': notification.type.storageValue,
      'created_at': notification.createdAt.toIso8601String(),
      'order_id': notification.orderId,
      'is_read': notification.isRead,
    };
  }
}

class RiderLocation {
  const RiderLocation({
    required this.riderId,
    required this.riderName,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.orderId,
    this.isActive = false,
  });

  final String riderId;
  final String riderName;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final String? orderId;
  final bool isActive;

  RiderLocation copyWith({
    String? riderId,
    String? riderName,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
    String? orderId,
    bool? isActive,
  }) {
    return RiderLocation(
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      updatedAt: updatedAt ?? this.updatedAt,
      orderId: orderId ?? this.orderId,
      isActive: isActive ?? this.isActive,
    );
  }
}

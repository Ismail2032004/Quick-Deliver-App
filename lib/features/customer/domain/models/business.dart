class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.description,
    required this.address,
    required this.phoneNumber,
    required this.imageUrl,
    required this.rating,
    required this.estimatedDeliveryMinutes,
    required this.latitude,
    required this.longitude,
    required this.tags,
  });

  final String id;
  final String ownerId;
  final String name;
  final String category;
  final String description;
  final String address;
  final String phoneNumber;
  final String imageUrl;
  final double rating;
  final int estimatedDeliveryMinutes;
  final double latitude;
  final double longitude;
  final List<String> tags;

  Business copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? category,
    String? description,
    String? address,
    String? phoneNumber,
    String? imageUrl,
    double? rating,
    int? estimatedDeliveryMinutes,
    double? latitude,
    double? longitude,
    List<String>? tags,
  }) {
    return Business(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      estimatedDeliveryMinutes:
          estimatedDeliveryMinutes ?? this.estimatedDeliveryMinutes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tags: tags ?? this.tags,
    );
  }
}

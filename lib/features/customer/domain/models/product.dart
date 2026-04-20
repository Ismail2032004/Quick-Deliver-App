class Product {
  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.preparationMinutes,
    this.imageSource = ProductImageSource.remote,
  });

  final String id;
  final String businessId;
  final String name;
  final String description;
  final String category;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final int preparationMinutes;
  final ProductImageSource imageSource;

  Product copyWith({
    String? id,
    String? businessId,
    String? name,
    String? description,
    String? category,
    double? price,
    String? imageUrl,
    bool? isAvailable,
    int? preparationMinutes,
    ProductImageSource? imageSource,
  }) {
    return Product(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      preparationMinutes: preparationMinutes ?? this.preparationMinutes,
      imageSource: imageSource ?? this.imageSource,
    );
  }
}

enum ProductImageSource { remote, localMock, cameraMock }

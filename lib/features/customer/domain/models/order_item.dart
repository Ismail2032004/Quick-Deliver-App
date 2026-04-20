import 'product.dart';

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.imageUrl,
  });

  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final String imageUrl;

  double get totalPrice => unitPrice * quantity;

  factory OrderItem.fromProduct(Product product, {int quantity = 1}) {
    return OrderItem(
      productId: product.id,
      productName: product.name,
      unitPrice: product.price,
      quantity: quantity,
      imageUrl: product.imageUrl,
    );
  }

  OrderItem copyWith({
    String? productId,
    String? productName,
    double? unitPrice,
    int? quantity,
    String? imageUrl,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

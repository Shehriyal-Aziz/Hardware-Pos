import 'product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final double priceOverride;
  final double discount;

  CartItem({
    required this.product,
    this.quantity = 1,
    double? priceOverride,
    this.discount = 0,
  }) : priceOverride = priceOverride ?? product.price;

  double get lineTotal => (priceOverride * quantity) - discount;

  CartItem copyWith({
    int? quantity,
    double? priceOverride,
    double? discount,
  }) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      priceOverride: priceOverride ?? this.priceOverride,
      discount: discount ?? this.discount,
    );
  }
}
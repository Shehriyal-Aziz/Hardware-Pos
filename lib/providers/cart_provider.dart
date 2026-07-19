import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartNotifier extends Notifier<List<CartItem>> {
  double overallDiscount = 0;

  @override
  List<CartItem> build() {
    return [];
  }

  void addProduct(Product product) {
    final index = state.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      final existing = state[index];
      state = [
        ...state.sublist(0, index),
        existing.copyWith(quantity: existing.quantity + 1),
        ...state.sublist(index + 1),
      ];
    } else {
      state = [...state, CartItem(product: product)];
    }
  }

  void updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    state = [
      for (final item in state)
        if (item.product.id == productId)
          item.copyWith(quantity: quantity)
        else
          item,
    ];
  }

  void updatePrice(int productId, double newPrice) {
    state = [
      for (final item in state)
        if (item.product.id == productId)
          item.copyWith(priceOverride: newPrice)
        else
          item,
    ];
  }

  void applyDiscount(int productId, double discount) {
    state = [
      for (final item in state)
        if (item.product.id == productId)
          item.copyWith(discount: discount)
        else
          item,
    ];
  }

  void removeItem(int productId) {
    state = state.where((item) => item.product.id != productId).toList();
    if (state.isEmpty) overallDiscount = 0;
  }

  void clearCart() {
    state = [];
    overallDiscount = 0;
  }

  void setOverallDiscount(double discount) {
    overallDiscount = discount;
    state = [...state];
  }

  void setTotalDirectly(double newTotal) {
    final itemsSum = state.fold(0.0, (sum, item) => sum + item.lineTotal);
    overallDiscount = (itemsSum - newTotal).clamp(0, itemsSum);
    state = [...state];
  }

  double get subtotal => state.fold(0, (sum, item) => sum + item.lineTotal);
  double get total => (subtotal - overallDiscount).clamp(0, double.infinity);
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(() {
  return CartNotifier();
});

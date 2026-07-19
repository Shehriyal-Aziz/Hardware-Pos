import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/product.dart';

class ProductNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() {
    loadProducts();
    return [];
  }

  Future<void> loadProducts() async {
    final maps = await DatabaseHelper.instance.getAllProducts();
    state = maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<void> addProduct(Product product) async {
    final id = await DatabaseHelper.instance.insertProduct(product.toMap());
    state = [...state, product.copyWith(id: id)];
  }

  Future<void> updateProduct(Product product) async {
    await DatabaseHelper.instance.updateProduct(product.toMap());
    state = [
      for (final p in state)
        if (p.id == product.id) product else p
    ];
  }

  Future<void> reduceStock(int productId, int quantitySold) async {
    final product = state.firstWhere((p) => p.id == productId);
    final newStock = product.stock - quantitySold;
    await DatabaseHelper.instance.updateStock(productId, newStock);
    state = [
      for (final p in state)
        if (p.id == productId) p.copyWith(stock: newStock) else p
    ];
  }

  Future<void> deleteProduct(int id) async {
    await DatabaseHelper.instance.deleteProduct(id);
    state = state.where((p) => p.id != id).toList();
  }
}

final productProvider = NotifierProvider<ProductNotifier, List<Product>>(() {
  return ProductNotifier();
});
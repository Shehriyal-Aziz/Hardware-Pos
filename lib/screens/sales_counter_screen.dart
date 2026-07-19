import 'package:flutter/material.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_sidebar.dart';
import 'inventory_screen.dart';

class SalesCounterScreen extends StatelessWidget {
  const SalesCounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Inventory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InventoryScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: const Row(
        children: [
          Expanded(child: ProductGrid()),
          CartSidebar(),
        ],
      ),
    );
  }
}

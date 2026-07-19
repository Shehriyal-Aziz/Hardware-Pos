import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../models/cart_item.dart';
import '../db/database_helper.dart';
import '../services/printer_service.dart';

class CartSidebar extends ConsumerWidget {
  const CartSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final subtotal = cartNotifier.subtotal;
    final total = cartNotifier.total;
    final discountPercent =
        subtotal > 0 ? (cartNotifier.overallDiscount / subtotal * 100) : 0;

    return Container(
      width: 340,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cart',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (cartItems.isNotEmpty)
                  TextButton(
                    onPressed: cartNotifier.clearCart,
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cartItems.isEmpty
                ? const Center(
                    child: Text(
                      'Cart is empty',
                      style: TextStyle(color: Colors.black38),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return _CartItemTile(item: item);
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    Text('Rs ${subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Discount %', style: TextStyle(fontSize: 13)),
                    ),
                    SizedBox(
                      width: 70,
                      child: TextFormField(
                        key: ValueKey('discount_${discountPercent.toStringAsFixed(1)}'),
                        initialValue: discountPercent == 0
                            ? ''
                            : discountPercent.toStringAsFixed(0),
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          suffixText: '%',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                        onFieldSubmitted: (value) {
                          final pct = double.tryParse(value) ?? 0;
                          final clamped = pct.clamp(0, 100);
                          cartNotifier.setOverallDiscount(subtotal * clamped / 100);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        key: ValueKey('total_${total.toStringAsFixed(0)}'),
                        initialValue: total.toStringAsFixed(0),
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          prefixText: 'Rs ',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onFieldSubmitted: (value) {
                          final newTotal = double.tryParse(value);
                          if (newTotal != null && newTotal >= 0) {
                            cartNotifier.setTotalDirectly(newTotal);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: cartItems.isEmpty
                        ? null
                        : () => _checkout(context, ref),
                    child: const Text(
                      'CHECKOUT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final cartItems = ref.read(cartProvider);
    final productNotifier = ref.read(productProvider.notifier);
    final total = ref.read(cartProvider.notifier).total;

    final printerIp = await DatabaseHelper.instance.getSetting('printer_ip');
    final printerModeSetting =
        await DatabaseHelper.instance.getSetting('printer_mode');
    final windowsPrinterName =
        await DatabaseHelper.instance.getSetting('windows_printer_name');

    final mode = printerModeSetting == 'windows'
        ? PrinterMode.windows
        : PrinterMode.network;
    final target =
        mode == PrinterMode.windows ? (windowsPrinterName ?? '') : (printerIp ?? '');
    final printerConfigured = target.isNotEmpty;

    for (final item in cartItems) {
      if (item.product.id != null) {
        await productNotifier.reduceStock(item.product.id!, item.quantity);
      }
    }

    ref.read(cartProvider.notifier).clearCart();

    // Fire-and-forget, same as before: checkout completes instantly and
    // doesn't wait on or react to the print result.
    if (printerConfigured) {
      PrinterService.printReceiptAuto(
        mode: mode,
        target: target,
        items: cartItems,
        total: total,
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printerConfigured
                ? 'Sale completed & printing'
                : 'Sale completed (no printer set)',
          ),
        ),
      );
    }
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartNotifier = ref.read(cartProvider.notifier);
    final productId = item.product.id!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => cartNotifier.removeItem(productId),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () => cartNotifier.updateQuantity(
                      productId,
                      item.quantity - 1,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 50,
                    child: TextFormField(
                      key: ValueKey('qty_${productId}_${item.quantity}'),
                      initialValue: '${item.quantity}',
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                      ),
                      onFieldSubmitted: (value) {
                        final qty = int.tryParse(value);
                        if (qty != null && qty > 0) {
                          if (qty > item.product.stock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Only ${item.product.stock} in stock'),
                              ),
                            );
                            cartNotifier.updateQuantity(
                                productId, item.product.stock);
                          } else {
                            cartNotifier.updateQuantity(productId, qty);
                          }
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () {
                      if (item.quantity + 1 > item.product.stock) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Only ${item.product.stock} in stock'),
                          ),
                        );
                      } else {
                        cartNotifier.updateQuantity(
                            productId, item.quantity + 1);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: item.priceOverride.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: 'Rs ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                  onFieldSubmitted: (value) {
                    final newPrice = double.tryParse(value);
                    if (newPrice != null) {
                      cartNotifier.updatePrice(productId, newPrice);
                    }
                  },
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Rs ${item.lineTotal.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
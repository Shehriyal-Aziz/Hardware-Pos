import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../db/database_helper.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import 'settings_screen.dart';
import 'customers_screen.dart';
import 'reports_screen.dart';
import '../widgets/product_grid.dart' show fuzzyMatch;

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _authenticated = false;
  bool _obscure = true;
  final _passwordController = TextEditingController();
  String? _error;

  Future<void> _checkPassword() async {
    final storedPassword =
        await DatabaseHelper.instance.getSetting('inventory_password');
    if (_passwordController.text == storedPassword) {
      setState(() {
        _authenticated = true;
        _error = null;
      });
    } else {
      setState(() => _error = 'Incorrect password');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory Login')),
        body: Center(
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _checkPassword(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _checkPassword,
                    child: const Text('Unlock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const _InventoryPanel();
  }
}

class _InventoryPanel extends ConsumerStatefulWidget {
  const _InventoryPanel();

  @override
  ConsumerState<_InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends ConsumerState<_InventoryPanel> {
  String searchQuery = '';
  final _searchController = TextEditingController();

  List<Product> _suggestions(List<Product> products) {
    if (searchQuery.isEmpty) return [];
    final matches = products
        .where((p) =>
            fuzzyMatch(p.name, searchQuery) ||
            fuzzyMatch(p.category, searchQuery))
        .toList();
    matches.sort((a, b) {
      final aExact =
          a.name.toLowerCase().contains(searchQuery.toLowerCase()) ? 0 : 1;
      final bExact =
          b.name.toLowerCase().contains(searchQuery.toLowerCase()) ? 0 : 1;
      return aExact.compareTo(bExact);
    });
    return matches.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = ref.watch(productProvider);
    final products = allProducts
        .where((p) =>
            fuzzyMatch(p.name, searchQuery) ||
            fuzzyMatch(p.category, searchQuery))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Customers (Udhar)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomersScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Product',
            onPressed: () => _showAddProductDialog(context, ref, allProducts),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or category...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
                if (searchQuery.isNotEmpty && _suggestions(allProducts).isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: _suggestions(allProducts).map((p) {
                        return ListTile(
                          dense: true,
                          title: Text(p.name),
                          subtitle: Text('${p.category} • Rs ${p.price.toStringAsFixed(0)}'),
                          onTap: () {
                            setState(() {
                              searchQuery = p.name;
                              _searchController.text = p.name;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black26)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 32, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 48),
                Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('No products found'))
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return _InventoryRow(
                        index: index + 1,
                        product: p,
                        onTap: () => _showAddProductDialog(context, ref, allProducts, existing: p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(
    BuildContext context,
    WidgetRef ref,
    List<Product> allProducts, {
    Product? existing,
  }) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final categoryController = TextEditingController(text: existing?.category ?? '');
    final priceController =
        TextEditingController(text: existing?.price.toString() ?? '');
    final stockController =
        TextEditingController(text: existing?.stock.toString() ?? '');
    String? imagePath = existing?.imagePath;
    String? duplicateWarning;
    List<String> nameSuggestions = [];
    List<String> categorySuggestions = [];

    final allCategories = {for (final p in allProducts) p.category}.toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void checkDuplicateName(String value) {
            final trimmed = value.trim().toLowerCase();
            if (trimmed.isEmpty) {
              duplicateWarning = null;
              nameSuggestions = [];
              return;
            }
            final match = allProducts.firstWhere(
              (p) =>
                  p.name.trim().toLowerCase() == trimmed &&
                  p.id != existing?.id,
              orElse: () => Product(name: '', category: '', price: 0, stock: 0),
            );
            duplicateWarning = match.name.isNotEmpty
                ? 'A product named "${match.name}" already exists'
                : null;

            nameSuggestions = allProducts
                .where((p) => p.id != existing?.id && fuzzyMatch(p.name, value))
                .map((p) => p.name)
                .toSet()
                .take(5)
                .toList();
          }

          void checkCategory(String value) {
            if (value.trim().isEmpty) {
              categorySuggestions = [];
              return;
            }
            categorySuggestions = allCategories
                .where((c) => fuzzyMatch(c, value))
                .take(5)
                .toList();
          }

          Future<void> submit() async {
            if (duplicateWarning != null) return;

            final name = nameController.text.trim();
            final rawCategory = categoryController.text.trim();
            final category = rawCategory.isEmpty
                ? ''
                : rawCategory[0].toUpperCase() +
                    rawCategory.substring(1).toLowerCase();
            final price = double.tryParse(priceController.text) ?? 0;
            final stock = int.tryParse(stockController.text) ?? 0;

            if (name.isEmpty || category.isEmpty) return;

            final notifier = ref.read(productProvider.notifier);

            if (existing == null) {
              await notifier.addProduct(Product(
                name: name,
                category: category,
                price: price,
                stock: stock,
                imagePath: imagePath,
              ));
            } else {
              await notifier.updateProduct(existing.copyWith(
                name: name,
                category: category,
                price: price,
                stock: stock,
                imagePath: imagePath,
              ));
            }

            if (context.mounted) Navigator.pop(context);
          }

          return AlertDialog(
            title: Text(existing == null ? 'Add Product' : 'Edit Product'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final result = await fp.FilePicker.platform.pickFiles(
                        type: fp.FileType.image,
                      );
                      if (result != null && result.files.single.path != null) {
                        setDialogState(() {
                          imagePath = result.files.single.path;
                        });
                      }
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: imagePath != null && imagePath!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(imagePath!), fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, color: Colors.black45),
                                SizedBox(height: 4),
                                Text('Add image', style: TextStyle(fontSize: 11, color: Colors.black45)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Product Name',
                      errorText: duplicateWarning,
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        checkDuplicateName(value);
                      });
                    },
                    onSubmitted: (_) => submit(),
                  ),
                  if (nameSuggestions.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: nameSuggestions.map((s) {
                          return ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              setDialogState(() {
                                nameController.text = s;
                                checkDuplicateName(s);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                    onChanged: (value) {
                      setDialogState(() {
                        checkCategory(value);
                      });
                    },
                    onSubmitted: (_) => submit(),
                  ),
                  if (categorySuggestions.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: categorySuggestions.map((c) {
                          return ActionChip(
                            label: Text(c, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              setDialogState(() {
                                categoryController.text = c;
                                categorySuggestions = [];
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price'),
                    onSubmitted: (_) => submit(),
                  ),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock Quantity'),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: duplicateWarning != null ? null : submit,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  final int index;
  final Product product;
  final VoidCallback onTap;

  const _InventoryRow({
    required this.index,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text('$index')),
            SizedBox(
              width: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: product.imagePath != null && product.imagePath!.isNotEmpty
                    ? Image.file(
                        File(product.imagePath!),
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 36,
                          height: 36,
                          color: Colors.grey[200],
                          child: const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.black26),
                        ),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        color: Colors.grey[200],
                        child: const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.black26),
                      ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(child: Text(product.name, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(product.category)),
            Expanded(flex: 2, child: Text('Rs ${product.price.toStringAsFixed(0)}')),
            Expanded(
              flex: 2,
              child: Text(
                '${product.stock}',
                style: TextStyle(
                  color: product.stock <= 0 ? Colors.red : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onTap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
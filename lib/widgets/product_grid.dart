import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';
import 'dart:io';

class ProductGrid extends ConsumerStatefulWidget {
  const ProductGrid({super.key});

  @override
  ConsumerState<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends ConsumerState<ProductGrid> {
  String searchQuery = '';
  String selectedCategory = 'All';
  final _searchController = TextEditingController();

  List<Product> _suggestions(List<Product> products) {
    if (searchQuery.isEmpty) return [];
    final matches =
        products.where((p) => fuzzyMatch(p.name, searchQuery)).toList();
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
    final products = ref.watch(productProvider);

    final categories = [
      'All',
      ...{for (final p in products) p.category},
    ];

    final filtered = products.where((p) {
      final matchesSearch = fuzzyMatch(p.name, searchQuery);
      final matchesCategory =
          selectedCategory == 'All' || p.category == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Column(
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
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search, color: Colors.black),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
              if (searchQuery.isNotEmpty && _suggestions(products).isNotEmpty)
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
                    children: _suggestions(products).map((p) {
                      return ListTile(
                        dense: true,
                        title: Text(p.name),
                        subtitle: Text(
                            '${p.category} • Rs ${p.price.toStringAsFixed(0)}'),
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
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: categories.map((cat) {
              final isSelected = cat == selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => selectedCategory = cat),
                  selectedColor: Colors.black,
                  backgroundColor: Colors.grey[100],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No products found'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount =
                        (width / 180).floor().clamp(1, 8);
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return _ProductCard(product: product);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ProductCard extends ConsumerStatefulWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final outOfStock = product.stock <= 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering && !outOfStock ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hovering && !outOfStock
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: InkWell(
            onTap: outOfStock
                ? null
                : () => ref.read(cartProvider.notifier).addProduct(product),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
                color: outOfStock ? Colors.grey[200] : Colors.white,
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: product.imagePath != null &&
                              product.imagePath!.isNotEmpty
                          ? Image.file(
                              File(product.imagePath!),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    product.category,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Rs ${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          outOfStock ? 'Out' : '${product.stock} left',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: outOfStock ? Colors.red : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, color: Colors.black26, size: 32),
      ),
    );
  }
}

bool fuzzyMatch(String text, String query) {
  if (query.isEmpty) return true;
  final t = text.toLowerCase();
  final q = query.toLowerCase();
  if (t.contains(q)) return true;

  int distance(String a, String b) {
    final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) dp[i][0] = i;
    for (int j = 0; j <= b.length; j++) dp[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 +
              [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                  .reduce((x, y) => x < y ? x : y);
        }
      }
    }
    return dp[a.length][b.length];
  }

  for (final word in t.split(' ')) {
    final maxDist = q.length <= 4 ? 1 : 2;
    if (distance(word, q) <= maxDist) return true;
  }
  return false;
}
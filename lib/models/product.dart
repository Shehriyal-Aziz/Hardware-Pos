class Product {
  final String? id;
  final String name;
  final String category;
  final double price;
  final int stock;
  final String? barcode;
  final String? imagePath;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.barcode,
    this.imagePath,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  // NOTE: map keys are lowercase to match the Supabase/PowerSync schema
  // (Postgres lowercases unquoted identifiers). Dart-side field names stay
  // camelCase; only the DB column mapping changed.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'barcode': barcode,
      'imagepath': imagePath,
      'updatedat': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String?,
      name: map['name'] as String,
      category: map['category'] as String,
      price: (map['price'] as num).toDouble(),
      stock: map['stock'] as int,
      barcode: map['barcode'] as String?,
      imagePath: map['imagepath'] as String?,
      updatedAt: DateTime.parse(map['updatedat'] as String),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    int? stock,
    String? barcode,
    String? imagePath,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

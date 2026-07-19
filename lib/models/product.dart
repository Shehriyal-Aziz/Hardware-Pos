class Product {
  final int? id;
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'barcode': barcode,
      'imagePath': imagePath,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String,
      price: (map['price'] as num).toDouble(),
      stock: map['stock'] as int,
      barcode: map['barcode'] as String?,
      imagePath: map['imagePath'] as String?,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Product copyWith({
    int? id,
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
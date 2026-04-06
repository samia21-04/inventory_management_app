class Item {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final double price;
  final DateTime createdAt;

  Item({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    required this.createdAt,
  });

  /// Convert Item to a Map for Firestore writes.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Reconstruct an Item from a Firestore document snapshot.
  factory Item.fromMap(String id, Map<String, dynamic> map) {
    return Item(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Uncategorized',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// Returns true when stock is at or below the low-stock threshold.
  bool get isLowStock => quantity <= 5;

  /// Creates a copy with updated fields (used for editing).
  Item copyWith({
    String? name,
    String? category,
    int? quantity,
    double? price,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'Item(id: $id, name: $name, qty: $quantity, price: $price)';
}
class Item {
  final int? id;
  final String name;
  final String category;
  final double price;
  final bool isActive;

  const Item({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    this.isActive = true,
  });

  factory Item.fromMap(Map<String, dynamic> map) {
    int? parsedId;
    if (map['id'] is num) {
      parsedId = (map['id'] as num).toInt();
    } else if (map['id'] != null) {
      parsedId = int.tryParse(map['id'].toString());
    }

    double parsedPrice = 0.0;
    if (map['price'] is num) {
      parsedPrice = (map['price'] as num).toDouble();
    } else if (map['price'] != null) {
      parsedPrice = double.tryParse(map['price'].toString()) ?? 0.0;
    }

    return Item(
      id: parsedId,
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      price: parsedPrice,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class DiamondPackageModel {
  final String id;
  final int diamonds;
  final String price; // e.g., "$2.50" or local currency text
  final String category; // e.g., 'hot', 'bonus', 'regular'
  final bool isBonus;
  final bool isHot;
  final bool isActive;

  DiamondPackageModel({
    required this.id,
    required this.diamonds,
    required this.price,
    this.category = 'regular',
    this.isBonus = false,
    this.isHot = false,
    this.isActive = true,
  });

  factory DiamondPackageModel.fromMap(Map<String, dynamic> map, String docId) {
    return DiamondPackageModel(
      id: docId,
      diamonds: map['diamonds'] ?? map['coins'] ?? 0,
      price: map['price'] ?? '',
      category: map['category'] ?? 'regular',
      isBonus: map['isBonus'] ?? false,
      isHot: map['isHot'] ?? false,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'diamonds': diamonds,
      'price': price,
      'category': category,
      'isBonus': isBonus,
      'isHot': isHot,
      'isActive': isActive,
    };
  }
}

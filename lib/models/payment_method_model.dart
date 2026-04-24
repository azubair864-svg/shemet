class PaymentMethodModel {
  final String id;
  final String name;
  final String iconUrl;
  final String instructions;
  final bool isActive;

  PaymentMethodModel({
    required this.id,
    required this.name,
    this.iconUrl = '',
    this.instructions = '',
    this.isActive = true,
  });

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map, String docId) {
    return PaymentMethodModel(
      id: docId,
      name: map['name'] ?? '',
      iconUrl: map['iconUrl'] ?? '',
      instructions: map['instructions'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconUrl': iconUrl,
      'instructions': instructions,
      'isActive': isActive,
    };
  }
}

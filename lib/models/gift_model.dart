class GiftModel {
  final String id;
  final String name;
  final String emoji;
  final int price;     // Legacy (Coins)
  final int priceDiamonds; // New standard
  final String? animationUrl;
  final String? iconUrl; // For new UI mapping
  final bool isBigGift;
  final String category;
  final bool isActive;

  GiftModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    this.priceDiamonds = 0,
    this.animationUrl,
    this.iconUrl,
    this.isBigGift = false,
    this.category = 'normal',
    this.isActive = true,
  });

  /// Get the actual price to use for transactions (prioritizing diamonds)
  int get effectivePrice => priceDiamonds > 0 ? priceDiamonds : price;

  // ⭐ ADD THIS METHOD
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'price': price,
      'priceDiamonds': priceDiamonds,
      'animationUrl': animationUrl,
      'iconUrl': iconUrl,
      'isBigGift': isBigGift,
      'category': category,
      'isActive': isActive,
    };
  }

  // ⭐ ADD THIS METHOD
  factory GiftModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawPrice = map['price'] ?? 0;
    final rawDiamonds = map['priceDiamonds'] ?? map['diamonds']; // Handle legacy field names

    return GiftModel(
      id: docId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      emoji: map['emoji'] ?? '🎁',
      price: rawPrice is int ? rawPrice : (int.tryParse(rawPrice.toString()) ?? 0),
      priceDiamonds: rawDiamonds != null 
          ? (rawDiamonds is int ? rawDiamonds : (int.tryParse(rawDiamonds.toString()) ?? 0))
          : (rawPrice is int ? rawPrice : 0),
      animationUrl: map['animationUrl'],
      iconUrl: map['iconUrl'],
      isBigGift: map['isBigGift'] ?? false,
      category: map['category'] ?? 'normal',
      isActive: map['isActive'] ?? true,
    );
  }

  /// Get all default gifts organized by price tiers
  /// Basic: 10-100 diamonds | Premium: 500-5000 diamonds | Luxury: 10000+ diamonds
  static List<GiftModel> getDefaultGifts() {
    return [
      // --- HOT GIFTS (PAGE 1) ---
      GiftModel(id: 'lucky_lock', name: 'Lucky Lock', emoji: '🔒', price: 1777, iconUrl: 'assets/images/gifts/lucky_lock.png', category: 'hot', priceDiamonds: 1777),
      GiftModel(id: 'lucky_clover', name: 'Lucky Clover', emoji: '🍀', price: 2777, iconUrl: 'assets/images/gifts/lucky_clover.png', category: 'hot', priceDiamonds: 2777),
      GiftModel(id: 'lucky_win', name: 'Lucky Win', emoji: '🔨', price: 3777, iconUrl: 'assets/images/gifts/lucky_hammer.png', category: 'hot', priceDiamonds: 3777),
      GiftModel(id: 'kiss_lips', name: 'Kiss', emoji: '💋', price: 19999, iconUrl: 'assets/images/gifts/kiss_lips.png', category: 'hot', priceDiamonds: 19999),
      GiftModel(id: 'luxury_rose', name: 'Rose', emoji: '🌹', price: 29999, iconUrl: 'assets/images/gifts/luxury_rose.png', category: 'hot', priceDiamonds: 29999),
      GiftModel(id: 'lollipop', name: 'Lollipop', emoji: '🍭', price: 5999, iconUrl: 'assets/images/gifts/lollipop.png', category: 'hot', priceDiamonds: 5999),
      GiftModel(id: 'love_coffee', name: 'Love Coffee', emoji: '☕', price: 6999, iconUrl: 'assets/images/gifts/love_coffee.png', category: 'hot', priceDiamonds: 6999),
      GiftModel(id: 'heart_balloon', name: 'Balloon', emoji: '🎈', price: 39999, iconUrl: 'assets/images/gifts/heart_balloon.png', category: 'hot', isBigGift: true, priceDiamonds: 39999),
      
      // --- HOT GIFTS (PAGE 2) ---
      GiftModel(id: 'luxury_cake', name: 'Luxury Cake', emoji: '🎂', price: 69999, iconUrl: 'assets/images/gifts/luxury_cake.png', category: 'hot', isBigGift: true, priceDiamonds: 69999),
      GiftModel(id: 'heart_fly', name: 'Heart Fly', emoji: '🕊️', price: 99999, iconUrl: 'assets/images/gifts/heart_fly.png', category: 'hot', isBigGift: true, priceDiamonds: 99999),
      GiftModel(id: 'golden_watch', name: 'Golden Watch', emoji: '⌚', price: 199999, iconUrl: 'assets/images/gifts/golden_watch.png', category: 'hot', isBigGift: true, priceDiamonds: 199999),
      GiftModel(id: 'true_love', name: 'True Love', emoji: '💖', price: 299999, iconUrl: 'assets/images/gifts/true_love.png', category: 'hot', isBigGift: true, priceDiamonds: 299999),
      GiftModel(id: 'shamet_no1', name: 'Shamet No.1', emoji: '👑', price: 999999, iconUrl: 'assets/images/gifts/shamet_no1.png', category: 'hot', isBigGift: true, priceDiamonds: 999999),
      GiftModel(id: 'bouquet', name: 'Bouquet', emoji: '💐', price: 59999, iconUrl: 'assets/images/gifts/bouquet.png', category: 'hot', isBigGift: true, priceDiamonds: 59999),
      GiftModel(id: 'love_car', name: 'Love Car', emoji: '🏎️', price: 89999, iconUrl: 'assets/images/gifts/love_car.png', category: 'hot', isBigGift: true, priceDiamonds: 89999),
      GiftModel(id: 'i_love_u', name: 'I Love U', emoji: '💌', price: 199999, iconUrl: 'assets/images/gifts/i_love_u.png', category: 'hot', isBigGift: true, priceDiamonds: 199999),

      // --- HOT GIFTS (PAGE 3: Ultra-Premium) ---
      GiftModel(id: 'supercar', name: 'Supercar', emoji: '🏎️', price: 399999, iconUrl: 'assets/images/gifts/supercar.png', category: 'hot', isBigGift: true, priceDiamonds: 399999),
      GiftModel(id: 'royal_lion', name: 'Royal Lion', emoji: '🦁', price: 599999, iconUrl: 'assets/images/gifts/royal_lion.png', category: 'hot', isBigGift: true, priceDiamonds: 599999),
      GiftModel(id: 'helicopter', name: 'Helicopter', emoji: '🚁', price: 599999, iconUrl: 'assets/images/gifts/helicopter.png', category: 'hot', isBigGift: true, priceDiamonds: 599999),
      GiftModel(id: 'tiger_king', name: 'Tiger King', emoji: '🐯', price: 799999, iconUrl: 'assets/images/gifts/tiger_king.png', category: 'hot', isBigGift: true, priceDiamonds: 799999),
      GiftModel(id: 'private_jet_hot', name: 'Private Jet', emoji: '🛩️', price: 799999, iconUrl: 'assets/images/gifts/private_jet.png', category: 'hot', isBigGift: true, priceDiamonds: 799999),
      GiftModel(id: 'cruise_ship', name: 'Cruise Ship', emoji: '🚢', price: 1999999, iconUrl: 'assets/images/gifts/cruise_ship.png', category: 'hot', isBigGift: true, priceDiamonds: 1999999),
      GiftModel(id: 'legend_emerald', name: 'Legend Emerald', emoji: '💎', price: 9999999, iconUrl: 'assets/images/gifts/legend_emerald.png', category: 'hot', isBigGift: true, priceDiamonds: 9999999),
      
      // --- LUCKY GIFTS (PAGE 1) ---
      GiftModel(id: 'lucky_thumb', name: 'Thumb', emoji: '👍', price: 377, iconUrl: 'assets/images/gifts/lucky_thumb.png', category: 'lucky', priceDiamonds: 377),
      GiftModel(id: 'lucky_duck', name: 'Duck', emoji: '🦆', price: 577, iconUrl: 'assets/images/gifts/lucky_duck.png', category: 'lucky', priceDiamonds: 577),
      GiftModel(id: 'lucky_bell', name: 'Bell', emoji: '🔔', price: 777, iconUrl: 'assets/images/gifts/lucky_bell.png', category: 'lucky', priceDiamonds: 777),
      GiftModel(id: 'lucky_crystal', name: 'Crystal', emoji: '🔮', price: 977, iconUrl: 'assets/images/gifts/lucky_crystal.png', category: 'lucky', priceDiamonds: 977),
      GiftModel(id: 'lucky_lock_lucky', name: 'Lock', emoji: '🔒', price: 1777, iconUrl: 'assets/images/gifts/lucky_lock.png', category: 'lucky', priceDiamonds: 1777),
      GiftModel(id: 'lucky_clover_lucky', name: 'Clover', emoji: '🍀', price: 2777, iconUrl: 'assets/images/gifts/lucky_clover.png', category: 'lucky', priceDiamonds: 2777),
      GiftModel(id: 'lucky_win_lucky', name: 'Win', emoji: '🔨', price: 3777, iconUrl: 'assets/images/gifts/lucky_win.png', category: 'lucky', priceDiamonds: 3777),
      GiftModel(id: 'lucky_applause', name: 'Applause', emoji: '👏', price: 277, iconUrl: 'assets/images/gifts/lucky_applause.png', category: 'lucky', priceDiamonds: 277),

      // --- LUCKY GIFTS (PAGE 2) ---
      GiftModel(id: 'lucky_shooting', name: 'Shooting', emoji: '🔫', price: 877, iconUrl: 'assets/images/gifts/lucky_shooting.png', category: 'lucky', priceDiamonds: 877),
      GiftModel(id: 'lucky_bubbles', name: 'Bubbles', emoji: '🫧', price: 3777, iconUrl: 'assets/images/gifts/lucky_bubbles.png', category: 'lucky', priceDiamonds: 3777),
      GiftModel(id: 'lucky_777', name: '777', emoji: '🎰', price: 4777, iconUrl: 'assets/images/gifts/lucky_777.png', category: 'lucky', priceDiamonds: 4777),
      GiftModel(id: 'lucky_candy', name: 'Candy', emoji: '🍬', price: 5777, iconUrl: 'assets/images/gifts/lucky_candy.png', category: 'lucky', priceDiamonds: 5777),
      GiftModel(id: 'lucky_donut', name: 'Donut', emoji: '🍩', price: 177, iconUrl: 'assets/images/gifts/lucky_donut.png', category: 'lucky', priceDiamonds: 177),
      GiftModel(id: 'lucky_kiss', name: 'Kiss', emoji: '😘', price: 177, iconUrl: 'assets/images/gifts/lucky_kiss.png', category: 'lucky', priceDiamonds: 177),
      GiftModel(id: 'lucky_star_lucky', name: 'Star', emoji: '⭐', price: 7777, iconUrl: 'assets/images/gifts/lucky_star.png', category: 'lucky', priceDiamonds: 7777),
      GiftModel(id: 'lucky_lamp', name: 'Lamp', emoji: '🪔', price: 9777, iconUrl: 'assets/images/gifts/lucky_lamp.png', category: 'lucky', priceDiamonds: 9777),
      
      // --- LUCKY GIFTS (PAGE 3) ---
      GiftModel(id: 'lucky_finger_heart', name: 'Finger Heart', emoji: '🫰', price: 388, iconUrl: 'assets/images/gifts/lucky_finger_heart.png', category: 'lucky', priceDiamonds: 388),
      GiftModel(id: 'lucky_hugging_heart', name: 'Hugging Heart', emoji: '🫂', price: 1088, iconUrl: 'assets/images/gifts/lucky_hugging_heart.png', category: 'lucky', priceDiamonds: 1088),
      GiftModel(id: 'lucky_holding_hands', name: 'Holding Hands', emoji: '🤝', price: 3888, iconUrl: 'assets/images/gifts/lucky_holding_hands.png', category: 'lucky', priceDiamonds: 3888),
      GiftModel(id: 'lucky_witch', name: 'Lucky Witch', emoji: '🧙', price: 9888, iconUrl: 'assets/images/gifts/lucky_witch.png', category: 'lucky', priceDiamonds: 9888),
      GiftModel(id: 'lucky_cupid_arrow', name: 'Cupid\'s Arrow', emoji: '💘', price: 38888, iconUrl: 'assets/images/gifts/lucky_cupid_arrow.png', category: 'lucky', isBigGift: true, priceDiamonds: 38888),
      GiftModel(id: 'lucky_bottle', name: 'Lucky Bottle', emoji: '🍼', price: 17777, iconUrl: 'assets/images/gifts/lucky_bottle.png', category: 'lucky', isBigGift: true, priceDiamonds: 17777),
      GiftModel(id: 'lucky_pearl', name: 'Lucky Pearl', emoji: '🦪', price: 37777, iconUrl: 'assets/images/gifts/lucky_pearl.png', category: 'lucky', isBigGift: true, priceDiamonds: 37777),

      // ============ BASIC TIER (10-100 diamonds) ============
      // Casual gifts
      GiftModel(id: '1', name: 'Coffee', emoji: '☕', price: 10, category: 'casual'),
      GiftModel(id: '2', name: 'Ice Cream', emoji: '🍦', price: 15, category: 'fun'),
      GiftModel(id: '3', name: 'Cake', emoji: '🎂', price: 20, category: 'fun'),
      GiftModel(id: '4', name: 'Pizza', emoji: '🍕', price: 25, category: 'fun'),
      GiftModel(id: '6', name: 'Wine', emoji: '🍷', price: 40, category: 'casual'),
      GiftModel(id: '7', name: 'Heart', emoji: '❤️', price: 50, category: 'romantic'),
      GiftModel(id: '9', name: 'Teddy Bear', emoji: '🧸', price: 80, category: 'romantic'),
      GiftModel(id: '10', name: 'Chocolate', emoji: '🍫', price: 100, category: 'romantic'),

      // ============ PREMIUM TIER (500-5000 diamonds) ============
      // High-value gifts with special animations
      GiftModel(id: '11', name: 'Diamond', emoji: '💎', price: 500, category: 'premium'),
      GiftModel(id: '12', name: 'Crown', emoji: '👑', price: 800, category: 'premium'),
      GiftModel(id: '13', name: 'Ring', emoji: '💍', price: 1000, category: 'premium'),
      GiftModel(id: '14', name: 'Bouquet', emoji: '💐', price: 1500, category: 'romantic'),
      GiftModel(id: '15', name: 'Fireworks', emoji: '🎆', price: 2000, isBigGift: true, category: 'celebration'),
      GiftModel(id: '16', name: 'Trophy', emoji: '🏆', price: 2500, isBigGift: true, category: 'premium'),
      GiftModel(id: '17', name: 'Star', emoji: '⭐', price: 3000, isBigGift: true, category: 'premium'),
      GiftModel(id: '18', name: 'Rocket', emoji: '🚀', price: 4000, isBigGift: true, category: 'premium'),
      GiftModel(id: '19', name: 'Rainbow', emoji: '🌈', price: 5000, isBigGift: true, category: 'premium'),

      // ============ LUXURY TIER (NEW CLIENT REQUEST) ============
      // --- LUXURY GIFTS (PAGE 1) ---
      GiftModel(id: 'luxury_golden_watch', name: 'Golden Watch', emoji: '⌚', price: 199999, iconUrl: 'assets/images/gifts/golden_watch.png', category: 'luxury', isBigGift: true, priceDiamonds: 199999),
      GiftModel(id: 'luxury_heart_fly', name: 'Heart Fly', emoji: '🕊️', price: 99999, iconUrl: 'assets/images/gifts/heart_fly.png', category: 'luxury', isBigGift: true, priceDiamonds: 99999),
      GiftModel(id: 'luxury_supercar', name: 'Supercar', emoji: '🏎️', price: 399999, iconUrl: 'assets/images/gifts/supercar.png', category: 'luxury', isBigGift: true, priceDiamonds: 399999),
      GiftModel(id: 'luxury_royal_lion', name: 'Royal Lion', emoji: '🦁', price: 599999, iconUrl: 'assets/images/gifts/royal_lion.png', category: 'luxury', isBigGift: true, priceDiamonds: 599999),
      GiftModel(id: 'luxury_helicopter', name: 'Helicopter', emoji: '🚁', price: 599999, iconUrl: 'assets/images/gifts/helicopter.png', category: 'luxury', isBigGift: true, priceDiamonds: 599999),
      GiftModel(id: 'luxury_tiger_king', name: 'Tiger King', emoji: '🐯', price: 799999, iconUrl: 'assets/images/gifts/tiger_king.png', category: 'luxury', isBigGift: true, priceDiamonds: 799999),
      GiftModel(id: 'luxury_private_jet', name: 'Private Jet', emoji: '🛩️', price: 799999, iconUrl: 'assets/images/gifts/private_jet.png', category: 'luxury', isBigGift: true, priceDiamonds: 799999),
      GiftModel(id: 'luxury_i_love_u', name: 'I Love U', emoji: '💌', price: 199999, iconUrl: 'assets/images/gifts/i_love_u.png', category: 'luxury', isBigGift: true, priceDiamonds: 199999),

      // --- LUXURY GIFTS (PAGE 2) ---
      GiftModel(id: 'luxury_true_love', name: 'True Love', emoji: '💖', price: 299999, iconUrl: 'assets/images/gifts/true_love.png', category: 'luxury', isBigGift: true, priceDiamonds: 299999),
      GiftModel(id: 'luxury_shine_for_u', name: 'Shine For U', emoji: '✨', price: 499999, iconUrl: 'assets/images/gifts/luxury_shine_for_u.png', category: 'luxury', isBigGift: true, priceDiamonds: 499999),
      GiftModel(id: 'luxury_airship', name: 'Luxury Airship', emoji: '🎈', price: 699999, iconUrl: 'assets/images/gifts/luxury_airship.png', category: 'luxury', isBigGift: true, priceDiamonds: 699999),
      GiftModel(id: 'luxury_shamet_no1', name: 'Shamet No.1', emoji: '👑', price: 999999, iconUrl: 'assets/images/gifts/shamet_no1.png', category: 'luxury', isBigGift: true, priceDiamonds: 999999),
      GiftModel(id: 'luxury_cruise_ship', name: 'Cruise Ship', emoji: '🚢', price: 1999999, iconUrl: 'assets/images/gifts/cruise_ship.png', category: 'luxury', isBigGift: true, priceDiamonds: 1999999),
      GiftModel(id: 'luxury_submarine', name: 'Submarine', emoji: '🚢', price: 1999999, iconUrl: 'assets/images/gifts/luxury_submarine.png', category: 'luxury', isBigGift: true, priceDiamonds: 1999999),
      GiftModel(id: 'luxury_space_plane', name: 'Space Plane', emoji: '✈️', price: 2999999, iconUrl: 'assets/images/gifts/luxury_space_plane.png', category: 'luxury', isBigGift: true, priceDiamonds: 2999999),
      GiftModel(id: 'luxury_travel_in_space', name: 'Travel in Space', emoji: '🌌', price: 4999999, iconUrl: 'assets/images/gifts/luxury_travel_in_space.png', category: 'luxury', isBigGift: true, priceDiamonds: 4999999),

      // --- FUNNY GIFTS (PAGE 1) ---
      GiftModel(id: 'funny_follow_me', name: 'Follow Me', emoji: '🎀', price: 999, iconUrl: 'assets/images/gifts/funny_follow_me.png', category: 'funny', priceDiamonds: 999),
      GiftModel(id: 'funny_sunglasses', name: 'Sunglasses', emoji: '🕶️', price: 999, iconUrl: 'assets/images/gifts/funny_sunglasses.png', category: 'funny', priceDiamonds: 999),
      GiftModel(id: 'funny_tiger_hat', name: 'Tiger Hat', emoji: '🐯', price: 999, iconUrl: 'assets/images/gifts/funny_tiger_hat.png', category: 'funny', priceDiamonds: 999),
      GiftModel(id: 'funny_star_bomb', name: 'Star Bomb', emoji: '⭐', price: 1999, iconUrl: 'assets/images/gifts/funny_star_bomb.png', category: 'funny', priceDiamonds: 1999),
      GiftModel(id: 'funny_kiss_you', name: 'Kiss You', emoji: '💖', price: 9999, iconUrl: 'assets/images/gifts/funny_kiss_you.png', category: 'funny', priceDiamonds: 9999),
      GiftModel(id: 'funny_cheers', name: 'Cheers', emoji: '🍻', price: 1599, iconUrl: 'assets/images/gifts/funny_cheers.png', category: 'funny', priceDiamonds: 1599),
      GiftModel(id: 'funny_bomb', name: 'Bomb', emoji: '💣', price: 1599, iconUrl: 'assets/images/gifts/funny_bomb.png', category: 'funny', priceDiamonds: 1599),
      GiftModel(id: 'funny_tomato', name: 'Tomato', emoji: '🍅', price: 1599, iconUrl: 'assets/images/gifts/funny_tomato.png', category: 'funny', priceDiamonds: 1599),

      // --- FUNNY GIFTS (PAGE 2) ---
      GiftModel(id: 'funny_oh_rose', name: 'Oh! Rose', emoji: '🌹', price: 25599, iconUrl: 'assets/images/gifts/funny_oh_rose.png', category: 'funny', priceDiamonds: 25599),
      GiftModel(id: 'funny_hairband', name: 'Hairband', emoji: '🎀', price: 999, iconUrl: 'assets/images/gifts/funny_hairband.png', category: 'funny', priceDiamonds: 999),
    ];
  }

  /// Get gifts by category
  static List<GiftModel> getGiftsByCategory(String category) {
    return getDefaultGifts().where((g) => g.category == category).toList();
  }

  /// Get gifts by price tier
  static List<GiftModel> getBasicGifts() {
    return getDefaultGifts().where((g) => g.price <= 100).toList();
  }

  static List<GiftModel> getPremiumGifts() {
    return getDefaultGifts().where((g) => g.price > 100 && g.price < 10000).toList();
  }

  static List<GiftModel> getLuxuryGifts() {
    return getDefaultGifts().where((g) => g.price >= 10000).toList();
  }

  /// Get big gifts only (with full-screen animations)
  static List<GiftModel> getBigGifts() {
    return getDefaultGifts().where((g) => g.isBigGift).toList();
  }
}
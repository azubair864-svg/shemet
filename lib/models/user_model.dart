import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/country_utils.dart';

class UserModel {
  final String uid;
  final String? id; // NEW - Sequential ID (e.g., 1000)
  final String name;
  final String email;
  final String? phoneNumber;

  // Profile Photos
  final List<String> photos;
  final String? photoURL; // Main photo (backward compatibility)

  // Basic Info
  final String? gender;
  final DateTime? birthday;
  final int? age;
  final String? bio;

  // Location
  final String? country;
  final String? city;
  final GeoPoint? location; // For nearby feature

  // Additional Info
  final String? language;
  final String? secondLanguage; // NEW
  final List<String> interests;
  final String? height;
  final String? occupation;
  final String? relationshipStatus;

  // Profile Status
  final bool profileComplete;
  final bool isHost;
  final bool isVerified;
  final bool isOnline;
  final bool? isLive;
  final bool? isVip; // NEW - VIP status
  final String? agencyId; // Agency association
  final String? currentStreamId; // NEW - For live previews in Discovery
  final String? invitationCode; // NEW - For referral system
  final String? invitedBy; // NEW - Who invited this user

  // Currency
  final int diamonds;
  final int points;
  final int earningsBeans; // NEW - For hosts/agencies
  final int totalBeansReceived; // NEW - Lifetime stats

  // Level & Stats
  final int level;
  final int followers;
  final int following;
  final int friends;
  final int likesCount;
  final int commentsCount;
  final int giftsReceived; // NEW - Total gifts received

  // Call & Voice
  final int? callRate; // Diamonds per minute
  final String? voiceIntroUrl; // NEW - Voice introduction URL
  final int? voiceIntroDuration; // NEW - Voice duration in seconds

  // VIP
  final String? vipExpiryDate; // NEW - VIP expiry date

  // Settings
  final bool notificationsEnabled;
  final String? deviceToken;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSeen;
  final String? lastDeviceId; // NEW - For device security
  final int? freeTrialCards; // NEW - For random chat free trials

  UserModel({
    required this.uid,
    this.id, // NEW
    required this.name,
    required this.email,
    this.phoneNumber,
    this.photos = const [],
    this.photoURL,
    this.gender,
    this.birthday,
    this.age,
    this.bio,
    this.country,
    this.city,
    this.location,
    this.language,
    this.secondLanguage, // NEW
    this.interests = const [],
    this.height,
    this.occupation,
    this.relationshipStatus,
    this.profileComplete = false,
    this.isHost = false,
    this.isVerified = false,
    this.isOnline = false,
    this.isLive,
    this.isVip, // NEW
    this.agencyId, // Agency association
    this.currentStreamId, // NEW
    this.invitationCode, // NEW
    this.invitedBy, // NEW
    this.diamonds = 0,
    this.points = 0,
    this.level = 0,
    this.followers = 0,
    this.following = 0,
    this.friends = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.giftsReceived = 0, // NEW
    this.earningsBeans = 0, // NEW
    this.totalBeansReceived = 0, // NEW
    this.callRate,
    this.voiceIntroUrl, // NEW
    this.voiceIntroDuration, // NEW
    this.vipExpiryDate, // NEW
    this.notificationsEnabled = true,
    this.deviceToken,
    this.lastDeviceId, // NEW
    this.freeTrialCards = 0, // NEW
    required this.createdAt,
    this.updatedAt,
    this.lastSeen,
  });
  
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      throw Exception('User document does not exist');
    }
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap({
      ...data,
      'uid': doc.id, // Ensure UID is always taken from Document ID
    });
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      id: map['id']?.toString(), // NEW
      lastDeviceId: map['lastDeviceId'], // NEW
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
      photos: map['photos'] != null ? List<String>.from(map['photos']) : [],
      photoURL:
          map['photoURL'] ??
          (map['photos'] != null && (map['photos'] as List).isNotEmpty
              ? map['photos'][0]
              : null),
      gender: map['gender'],
      birthday: map['birthday'] != null
          ? (map['birthday'] is Timestamp
                ? (map['birthday'] as Timestamp).toDate()
                : (map['birthday'] is String
                      ? DateTime.tryParse(map['birthday'] as String)
                      : null))
          : null,
      age: map['age'],
      bio: map['bio'],
      country: map['country'],
      city: map['city'],
      location: map['location'],
      language: map['language'],
      secondLanguage: map['secondLanguage'], // NEW
      interests: map['interests'] != null
          ? List<String>.from(map['interests'])
          : [],
      height: map['height'],
      occupation: map['occupation'],
      relationshipStatus: map['relationshipStatus'],
      profileComplete: map['profileComplete'] ?? false,
      isHost: map['isHost'] ?? false,
      isVerified: map['isVerified'] ?? false,
      isOnline: map['isOnline'] ?? false,
      isLive: map['isLive'] as bool?,
      isVip: map['isVip'] as bool?, // NEW
      agencyId: map['agencyId'], // Agency association
      currentStreamId: map['currentStreamId'], // NEW
      invitationCode: map['invitationCode'], // NEW
      invitedBy: map['invitedBy'], // NEW
      diamonds: map['diamonds'] ?? map['coins'] ?? 0,
      points: map['points'] ?? 0,
      level: map['level'] ?? 0,
      followers: map['followers'] ?? 0,
      following: map['following'] ?? 0,
      friends: map['friends'] ?? 0,
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      giftsReceived: map['giftsReceived'] ?? 0, // NEW
      earningsBeans: map['earningsBeans'] ?? map['points'] ?? 0, // NEW - fallback to points if applicable
      totalBeansReceived: map['totalBeansReceived'] ?? 0, // NEW
      callRate: map['callRate'],
      voiceIntroUrl: map['voiceIntroUrl'], // NEW
      voiceIntroDuration: map['voiceIntroDuration'], // NEW
      vipExpiryDate: map['vipExpiryDate'], // NEW
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      deviceToken: map['deviceToken'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
                ? (map['createdAt'] as Timestamp).toDate()
                : (map['createdAt'] is String
                      ? DateTime.tryParse(map['createdAt'] as String) ??
                            DateTime.now()
                      : DateTime.now()))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
                ? (map['updatedAt'] as Timestamp).toDate()
                : (map['updatedAt'] is String
                      ? DateTime.tryParse(map['updatedAt'] as String)
                      : null))
          : null,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] is Timestamp
                ? (map['lastSeen'] as Timestamp).toDate()
                : (map['lastSeen'] is String
                      ? DateTime.tryParse(map['lastSeen'] as String)
                      : null))
          : null,
      freeTrialCards: map['freeTrialCards'] ?? 15,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'id': id, // NEW
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'photos': photos,
      'photoURL': photoURL,
      'gender': gender,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'age': age,
      'bio': bio,
      'country': country,
      'city': city,
      'location': location,
      'language': language,
      'secondLanguage': secondLanguage, // NEW
      'interests': interests,
      'height': height,
      'occupation': occupation,
      'relationshipStatus': relationshipStatus,
      'profileComplete': profileComplete,
      'isHost': isHost,
      'isVerified': isVerified,
      'isOnline': isOnline,
      'isLive': isLive,
      'isVip': isVip, // NEW
      'agencyId': agencyId, // Agency association
      'currentStreamId': currentStreamId, // NEW
      'invitationCode': invitationCode, // NEW
      'invitedBy': invitedBy, // NEW
      'diamonds': diamonds,
      'points': points,
      'earningsBeans': earningsBeans,
      'totalBeansReceived': totalBeansReceived,
      'level': level,
      'followers': followers,
      'following': following,
      'friends': friends,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'giftsReceived': giftsReceived, // NEW
      'callRate': callRate,
      'voiceIntroUrl': voiceIntroUrl, // NEW
      'voiceIntroDuration': voiceIntroDuration, // NEW
      'vipExpiryDate': vipExpiryDate, // NEW
      'notificationsEnabled': notificationsEnabled,
      'deviceToken': deviceToken,
      'lastDeviceId': lastDeviceId, // NEW
      'freeTrialCards': freeTrialCards,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
    };
  }

  UserModel copyWith({
    String? uid,
    String? id, // NEW
    String? name,
    String? email,
    String? phoneNumber,
    List<String>? photos,
    String? photoURL,
    String? gender,
    DateTime? birthday,
    int? age,
    String? bio,
    String? country,
    String? city,
    GeoPoint? location,
    String? language,
    String? secondLanguage, // NEW
    List<String>? interests,
    String? height,
    String? occupation,
    String? relationshipStatus,
    bool? profileComplete,
    bool? isHost,
    bool? isVerified,
    bool? isOnline,
    bool? isLive,
    bool? isVip, // NEW
    String? agencyId, // Agency association
    String? currentStreamId, // NEW
    String? invitationCode, // NEW
    String? invitedBy, // NEW
    int? diamonds,
    int? points,
    int? earningsBeans,
    int? totalBeansReceived,
    int? level,
    int? followers,
    int? following,
    int? friends,
    int? likesCount,
    int? commentsCount,
    int? giftsReceived, // NEW
    int? callRate,
    String? voiceIntroUrl, // NEW
    int? voiceIntroDuration, // NEW
    String? vipExpiryDate, // NEW
    bool? notificationsEnabled,
    String? deviceToken,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeen,
    String? lastDeviceId, // NEW
    int? freeTrialCards,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      id: id ?? this.id, // NEW
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photos: photos ?? this.photos,
      photoURL: photoURL ?? this.photoURL,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      age: age ?? this.age,
      bio: bio ?? this.bio,
      country: country ?? this.country,
      city: city ?? this.city,
      location: location ?? this.location,
      language: language ?? this.language,
      secondLanguage: secondLanguage ?? this.secondLanguage, // NEW
      interests: interests ?? this.interests,
      height: height ?? this.height,
      occupation: occupation ?? this.occupation,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      profileComplete: profileComplete ?? this.profileComplete,
      isHost: isHost ?? this.isHost,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      isLive: isLive ?? this.isLive,
      isVip: isVip ?? this.isVip, // NEW
      agencyId: agencyId ?? this.agencyId, // Agency association
      currentStreamId: currentStreamId ?? this.currentStreamId, // NEW
      invitationCode: invitationCode ?? this.invitationCode, // NEW
      invitedBy: invitedBy ?? this.invitedBy, // NEW
      diamonds: diamonds ?? this.diamonds,
      points: points ?? this.points,
      earningsBeans: earningsBeans ?? this.earningsBeans,
      totalBeansReceived: totalBeansReceived ?? this.totalBeansReceived,
      level: level ?? this.level,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      friends: friends ?? this.friends,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      giftsReceived: giftsReceived ?? this.giftsReceived, // NEW
      callRate: callRate ?? this.callRate,
      voiceIntroUrl: voiceIntroUrl ?? this.voiceIntroUrl, // NEW
      voiceIntroDuration: voiceIntroDuration ?? this.voiceIntroDuration, // NEW
      vipExpiryDate: vipExpiryDate ?? this.vipExpiryDate, // NEW
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      deviceToken: deviceToken ?? this.deviceToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId, // NEW
      freeTrialCards: freeTrialCards ?? this.freeTrialCards,
    );
  }

  String get displayName {
    if (name.trim().isEmpty || name.toLowerCase() == 'user') {
      if (id != null && id!.isNotEmpty) {
        return 'User $id';
      }
      final safeUid = uid.length >= 4 ? uid.substring(0, 4) : uid;
      return 'User $safeUid';
    }
    return name;
  }

  String get displayId {
    if (id != null && id!.isNotEmpty) return id!;
    // Deterministic fallback: Consistent 8-digit number from UID hash
    final hash = uid.hashCode.abs().toString();
    if (hash.length >= 8) return hash.substring(0, 8);
    return hash.padLeft(8, '0');
  }

  String? get mainPhoto => photos.isNotEmpty ? photos[0] : photoURL;

  bool get hasBasicProfile =>
      name.isNotEmpty &&
      photos.isNotEmpty &&
      gender != null &&
      birthday != null;

  // Country flag emoji
  String get countryFlag {
    if (country == null) return '🌍';
    return CountryUtils.getFlag(country!);
  }

  static int calculateAge(DateTime? birthday) {
    if (birthday == null) return 0;
    final today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  String get onlineStatus {
    if (isOnline) return 'Online';
    if (lastSeen == null) return 'Offline';

    final difference = DateTime.now().difference(lastSeen!);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return 'Offline';
  }

  // Priority 3: Distance Filter - Helper methods
  double? get latitude => location?.latitude;
  double? get longitude => location?.longitude;

  // Priority 3: Calculate distance between two users using Haversine formula
  // Returns distance in kilometers
  double? distanceTo(UserModel other) {
    if (location == null || other.location == null) return null;

    final lat1 = latitude!;
    final lon1 = longitude!;
    final lat2 = other.latitude!;
    final lon2 = other.longitude!;

    return _haversineDistance(lat1, lon1, lat2, lon2);
  }

  // Haversine formula for calculating distance between two points on Earth
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    // Convert degrees to radians
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    // Haversine formula
    final a = _sin2(dLat / 2) + _cos(lat1Rad) * _cos(lat2Rad) * _sin2(dLon / 2);
    final c = 2 * _asin(_sqrt(a));

    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) =>
      degrees * 3.141592653589793 / 180.0;
  static double _sin2(double x) {
    final s = _sin(x);
    return s * s;
  }

  static double _sin(double x) =>
      x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  static double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  static double _sqrt(double x) => x < 0 ? 0 : _newtonSqrt(x);
  static double _newtonSqrt(double x) {
    double z = (x + 1) / 2;
    for (int i = 0; i < 10; i++) {
      z = (z + x / z) / 2;
    }
    return z;
  }

  static double _asin(double x) =>
      x + (x * x * x) / 6 + (3 * x * x * x * x * x) / 40;
}

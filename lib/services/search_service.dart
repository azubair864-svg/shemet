import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';

/// ⭐⭐⭐ PRODUCTION-READY ADVANCED SEARCH SERVICE ⭐⭐⭐
/// Features: Multi-filter search, Location-based, Sorting, Pagination, Caching
class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Cache for recent searches
  final Map<String, List<UserModel>> _searchCache = {};
  final int _cacheMaxSize = 10;

  // ==================== ADVANCED SEARCH ====================

  /// Search users with multiple filters
  Future<SearchResult> searchUsers({
    required SearchFilters filters,
    String? lastUserId,
    int limit = 20,
  }) async {
    
    
    
    

    try {
      // Check cache first
      final cacheKey = '${filters.hashCode}_$lastUserId';
      if (_searchCache.containsKey(cacheKey)) {
        
        return SearchResult(
          users: _searchCache[cacheKey]!,
          hasMore: _searchCache[cacheKey]!.length >= limit,
        );
      }

      Query query = _usersCollection;

      // Apply gender filter
      if (filters.gender != null && filters.gender!.isNotEmpty) {
        
        query = query.where('gender', isEqualTo: filters.gender);
      }

      // Apply country filter
      if (filters.country != null && filters.country!.isNotEmpty) {
        
        query = query.where('country', isEqualTo: filters.country);
      }

      // Apply language filter
      if (filters.language != null && filters.language!.isNotEmpty) {
        
        query = query.where('language', isEqualTo: filters.language);
      }

      // Apply online status filter
      if (filters.onlineOnly == true) {
        
        query = query.where('isOnline', isEqualTo: true);
      }

      // Apply verified filter
      if (filters.verifiedOnly == true) {
        
        query = query.where('isVerified', isEqualTo: true);
      }

      // Apply VIP filter
      if (filters.vipOnly == true) {
        
        query = query.where('isVip', isEqualTo: true);
      }

      // Apply host filter
      if (filters.hostsOnly == true) {
        
        query = query.where('isHost', isEqualTo: true);
      }

      // Apply sorting
      switch (filters.sortBy) {
        case SortBy.newest:
          query = query.orderBy('createdAt', descending: true);
          break;
        case SortBy.popular:
          query = query.orderBy('followers', descending: true);
          break;
        case SortBy.level:
          query = query.orderBy('level', descending: true);
          break;
        case SortBy.lastActive:
          query = query.orderBy('lastSeen', descending: true);
          break;
        case SortBy.distance:
          // Distance sorting needs post-processing
          query = query.orderBy('createdAt', descending: true);
          break;
      }

      // Pagination
      if (lastUserId != null) {
        final lastDoc = await _usersCollection.doc(lastUserId).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      // Limit results
      query = query.limit(limit + 1);

      // Execute query
      final snapshot = await query.get();
      

      // Process results
      List<UserModel> users = [];
      for (final doc in snapshot.docs) {
        try {
          final user = UserModel.fromMap(doc.data() as Map<String, dynamic>);

          // Post-filter: Age range
          if (filters.minAge != null || filters.maxAge != null) {
            if (user.age != null) {
              if (filters.minAge != null && user.age! < filters.minAge!) continue;
              if (filters.maxAge != null && user.age! > filters.maxAge!) continue;
            }
          }

          // Post-filter: Has photos
          if (filters.hasPhotosOnly == true) {
            if (user.photos.isEmpty) continue;
          }

          // Post-filter: Has bio
          if (filters.hasBioOnly == true) {
            if (user.bio == null || user.bio!.isEmpty) continue;
          }

          // Post-filter: Interests match
          if (filters.interests != null && filters.interests!.isNotEmpty) {
            final hasMatchingInterest = user.interests.any(
              (interest) => filters.interests!.contains(interest),
            );
            if (!hasMatchingInterest) continue;
          }

          users.add(user);
        } catch (e) {
          
        }
      }

      // Distance sorting (post-process)
      if (filters.sortBy == SortBy.distance && filters.userLocation != null) {
        users = await _sortByDistance(users, filters.userLocation!);

        // Apply max distance filter
        if (filters.maxDistanceKm != null) {
          users = users.where((user) {
            if (user.location == null) return false;
            final distance = _calculateDistance(
              filters.userLocation!.latitude,
              filters.userLocation!.longitude,
              user.location!.latitude,
              user.location!.longitude,
            );
            return distance <= filters.maxDistanceKm!;
          }).toList();
        }
      }

      // Check if has more
      final hasMore = users.length > limit;
      if (hasMore) {
        users = users.take(limit).toList();
      }

      // Cache results
      _cacheResults(cacheKey, users);

      
      
      

      return SearchResult(users: users, hasMore: hasMore);
    } catch (e) {
      
      
      
      
      return SearchResult(users: [], hasMore: false, error: e.toString());
    }
  }

  /// Sort users by distance
  Future<List<UserModel>> _sortByDistance(
    List<UserModel> users,
    GeoPoint userLocation,
  ) async {
    

    final usersWithDistance = users.map((user) {
      double distance = double.infinity;
      if (user.location != null) {
        distance = _calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          user.location!.latitude,
          user.location!.longitude,
        );
      }
      return MapEntry(user, distance);
    }).toList();

    usersWithDistance.sort((a, b) => a.value.compareTo(b.value));

    return usersWithDistance.map((e) => e.key).toList();
  }

  /// Calculate distance between two points (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // km
  }

  /// Cache search results
  void _cacheResults(String key, List<UserModel> users) {
    if (_searchCache.length >= _cacheMaxSize) {
      _searchCache.remove(_searchCache.keys.first);
    }
    _searchCache[key] = users;
  }

  // ==================== QUICK SEARCH ====================

  /// Search users by name or username
  Future<List<UserModel>> quickSearch(String query, {int limit = 20}) async {
    
    

    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final queryLower = query.toLowerCase();

      // Search by name prefix
      final snapshot = await _usersCollection
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(limit)
          .get();

      final users = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((user) =>
              user.name.toLowerCase().contains(queryLower) ||
              (user.bio?.toLowerCase().contains(queryLower) ?? false))
          .toList();

      
      return users;
    } catch (e) {
      
      return [];
    }
  }

  // ==================== NEARBY USERS ====================

  /// Get users near a location
  Future<List<UserModel>> getNearbyUsers({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 50,
  }) async {
    
    
    

    try {
      // Get all users with location (limited query)
      final snapshot = await _usersCollection
          .where('location', isNotEqualTo: null)
          .limit(200) // Get a larger set to filter
          .get();

      final nearbyUsers = <UserModel>[];

      for (final doc in snapshot.docs) {
        try {
          final user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
          if (user.location == null) continue;

          final distance = _calculateDistance(
            latitude,
            longitude,
            user.location!.latitude,
            user.location!.longitude,
          );

          if (distance <= radiusKm) {
            nearbyUsers.add(user);
          }
        } catch (e) {
          
        }
      }

      // Sort by distance
      nearbyUsers.sort((a, b) {
        final distA = _calculateDistance(
          latitude, longitude,
          a.location!.latitude, a.location!.longitude,
        );
        final distB = _calculateDistance(
          latitude, longitude,
          b.location!.latitude, b.location!.longitude,
        );
        return distA.compareTo(distB);
      });

      final result = nearbyUsers.take(limit).toList();
      
      return result;
    } catch (e) {
      
      return [];
    }
  }

  // ==================== SUGGESTED USERS ====================

  /// Get suggested users based on interests and preferences
  Future<List<UserModel>> getSuggestedUsers({
    required String currentUserId,
    required UserModel currentUser,
    int limit = 20,
  }) async {
    
    

    try {
      Query query = _usersCollection
          .where('profileComplete', isEqualTo: true)
          .limit(100);

      // Filter by opposite gender if set
      if (currentUser.gender != null) {
        final preferredGender = currentUser.gender == 'Male' ? 'Female' : 'Male';
        query = query.where('gender', isEqualTo: preferredGender);
      }

      final snapshot = await query.get();

      List<MapEntry<UserModel, int>> scoredUsers = [];

      for (final doc in snapshot.docs) {
        try {
          final user = UserModel.fromMap(doc.data() as Map<String, dynamic>);

          // Skip current user
          if (user.uid == currentUserId) continue;

          // Calculate compatibility score
          int score = 0;

          // Same country bonus
          if (user.country == currentUser.country) score += 20;

          // Same language bonus
          if (user.language == currentUser.language) score += 15;

          // Matching interests
          final matchingInterests = user.interests
              .where((i) => currentUser.interests.contains(i))
              .length;
          score += matchingInterests * 10;

          // Verified bonus
          if (user.isVerified) score += 10;

          // Online bonus
          if (user.isOnline) score += 15;

          // Has photos bonus
          if (user.photos.isNotEmpty) score += 10;

          // Similar level bonus
          final levelDiff = (user.level - currentUser.level).abs();
          if (levelDiff <= 5) score += 10;

          // Age compatibility
          if (user.age != null && currentUser.age != null) {
            final ageDiff = (user.age! - currentUser.age!).abs();
            if (ageDiff <= 5) {
              score += 10;
            } else if (ageDiff <= 10) score += 5;
          }

          // Distance bonus (if locations available)
          if (user.location != null && currentUser.location != null) {
            final distance = _calculateDistance(
              currentUser.location!.latitude,
              currentUser.location!.longitude,
              user.location!.latitude,
              user.location!.longitude,
            );
            if (distance <= 50) {
              score += 20;
            } else if (distance <= 100) score += 10;
          }

          scoredUsers.add(MapEntry(user, score));
        } catch (e) {
          
        }
      }

      // Sort by score
      scoredUsers.sort((a, b) => b.value.compareTo(a.value));

      final result = scoredUsers.take(limit).map((e) => e.key).toList();
      
      return result;
    } catch (e) {
      
      return [];
    }
  }

  // ==================== RECENT SEARCHES ====================

  /// Save recent search
  Future<void> saveRecentSearch({
    required String userId,
    required String searchQuery,
    Map<String, dynamic>? filters,
  }) async {
    

    try {
      final recentSearchRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_searches')
          .doc();

      await recentSearchRef.set({
        'query': searchQuery,
        'filters': filters,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      
    }
  }

  /// Get recent searches
  Future<List<Map<String, dynamic>>> getRecentSearches(String userId) async {
    

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_searches')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      
      return [];
    }
  }

  /// Clear recent searches
  Future<void> clearRecentSearches(String userId) async {
    

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_searches')
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      
    }
  }

  // ==================== CLEANUP ====================

  /// Clear search cache
  void clearCache() {
    
    _searchCache.clear();
  }
}

// ==================== MODELS ====================

class SearchFilters {
  final String? gender;
  final int? minAge;
  final int? maxAge;
  final String? country;
  final String? language;
  final List<String>? interests;
  final bool? onlineOnly;
  final bool? verifiedOnly;
  final bool? vipOnly;
  final bool? hostsOnly;
  final bool? hasPhotosOnly;
  final bool? hasBioOnly;
  final double? maxDistanceKm;
  final GeoPoint? userLocation;
  final SortBy sortBy;

  SearchFilters({
    this.gender,
    this.minAge,
    this.maxAge,
    this.country,
    this.language,
    this.interests,
    this.onlineOnly,
    this.verifiedOnly,
    this.vipOnly,
    this.hostsOnly,
    this.hasPhotosOnly,
    this.hasBioOnly,
    this.maxDistanceKm,
    this.userLocation,
    this.sortBy = SortBy.newest,
  });

  Map<String, dynamic> toMap() {
    return {
      'gender': gender,
      'minAge': minAge,
      'maxAge': maxAge,
      'country': country,
      'language': language,
      'interests': interests,
      'onlineOnly': onlineOnly,
      'verifiedOnly': verifiedOnly,
      'vipOnly': vipOnly,
      'hostsOnly': hostsOnly,
      'hasPhotosOnly': hasPhotosOnly,
      'hasBioOnly': hasBioOnly,
      'maxDistanceKm': maxDistanceKm,
      'sortBy': sortBy.name,
    };
  }

  SearchFilters copyWith({
    String? gender,
    int? minAge,
    int? maxAge,
    String? country,
    String? language,
    List<String>? interests,
    bool? onlineOnly,
    bool? verifiedOnly,
    bool? vipOnly,
    bool? hostsOnly,
    bool? hasPhotosOnly,
    bool? hasBioOnly,
    double? maxDistanceKm,
    GeoPoint? userLocation,
    SortBy? sortBy,
  }) {
    return SearchFilters(
      gender: gender ?? this.gender,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      country: country ?? this.country,
      language: language ?? this.language,
      interests: interests ?? this.interests,
      onlineOnly: onlineOnly ?? this.onlineOnly,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      vipOnly: vipOnly ?? this.vipOnly,
      hostsOnly: hostsOnly ?? this.hostsOnly,
      hasPhotosOnly: hasPhotosOnly ?? this.hasPhotosOnly,
      hasBioOnly: hasBioOnly ?? this.hasBioOnly,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      userLocation: userLocation ?? this.userLocation,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

enum SortBy {
  newest,
  popular,
  level,
  lastActive,
  distance,
}

extension SortByExtension on SortBy {
  String get displayName {
    switch (this) {
      case SortBy.newest:
        return 'Newest';
      case SortBy.popular:
        return 'Most Popular';
      case SortBy.level:
        return 'Highest Level';
      case SortBy.lastActive:
        return 'Recently Active';
      case SortBy.distance:
        return 'Nearest';
    }
  }

  String get icon {
    switch (this) {
      case SortBy.newest:
        return '🆕';
      case SortBy.popular:
        return '🔥';
      case SortBy.level:
        return '⭐';
      case SortBy.lastActive:
        return '🟢';
      case SortBy.distance:
        return '📍';
    }
  }
}

class SearchResult {
  final List<UserModel> users;
  final bool hasMore;
  final String? error;

  SearchResult({
    required this.users,
    required this.hasMore,
    this.error,
  });
}

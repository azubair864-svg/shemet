import 'package:cloud_firestore/cloud_firestore.dart';

/// ⭐⭐⭐ HOST APPLICATION MODEL ⭐⭐⭐
/// Complete model for host applications with all verification fields
class HostApplicationModel {
  final String applicationId;
  final String userId;
  final String userName;
  final String email;
  final String? phone;
  final String? bio;
  final String? reason; // Why they want to become a host
  final List<String> socialLinks; // Instagram, TikTok, YouTube, etc.
  final int? expectedHoursPerWeek;
  final String? experienceLevel; // 'beginner', 'intermediate', 'professional'
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Admin user ID
  final String? reviewNotes;
  final String? rejectionReason;

  // ⭐ NEW FIELDS - Photo, Age, Category, ID Verification
  final String? category; // 'gaming', 'music', 'dance', 'talk_show', 'education', 'lifestyle', 'cooking', 'fitness', 'art', 'other'
  final List<String> verificationPhotos; // Profile/verification photos
  final String? idDocumentUrl; // ID document for verification
  final int? age; // Host age
  final DateTime? dateOfBirth; // Date of birth for age verification
  final bool ageVerified; // Age verification status
  final bool idVerified; // ID verification status

  HostApplicationModel({
    required this.applicationId,
    required this.userId,
    required this.userName,
    required this.email,
    this.phone,
    this.bio,
    this.reason,
    this.socialLinks = const [],
    this.expectedHoursPerWeek,
    this.experienceLevel,
    this.status = 'pending',
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
    this.rejectionReason,
    // New fields
    this.category,
    this.verificationPhotos = const [],
    this.idDocumentUrl,
    this.age,
    this.dateOfBirth,
    this.ageVerified = false,
    this.idVerified = false,
  });

  Map<String, dynamic> toMap() {
    
    
    
    
    
    
    
    
    
    

    return {
      'applicationId': applicationId,
      'userId': userId,
      'userName': userName,
      'email': email,
      'phone': phone,
      'bio': bio,
      'reason': reason,
      'socialLinks': socialLinks,
      'expectedHoursPerWeek': expectedHoursPerWeek,
      'experienceLevel': experienceLevel,
      'status': status,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'reviewNotes': reviewNotes,
      'rejectionReason': rejectionReason,
      // New fields
      'category': category,
      'verificationPhotos': verificationPhotos,
      'idDocumentUrl': idDocumentUrl,
      'age': age,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'ageVerified': ageVerified,
      'idVerified': idVerified,
    };
  }

  factory HostApplicationModel.fromMap(Map<String, dynamic> map) {
    
    
    
    
    
    

    return HostApplicationModel(
      applicationId: map['applicationId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      bio: map['bio'],
      reason: map['reason'],
      socialLinks: List<String>.from(map['socialLinks'] ?? []),
      expectedHoursPerWeek: map['expectedHoursPerWeek'],
      experienceLevel: map['experienceLevel'],
      status: map['status'] ?? 'pending',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: map['reviewedBy'],
      reviewNotes: map['reviewNotes'],
      rejectionReason: map['rejectionReason'],
      // New fields
      category: map['category'],
      verificationPhotos: List<String>.from(map['verificationPhotos'] ?? []),
      idDocumentUrl: map['idDocumentUrl'],
      age: map['age'],
      dateOfBirth: (map['dateOfBirth'] as Timestamp?)?.toDate(),
      ageVerified: map['ageVerified'] ?? false,
      idVerified: map['idVerified'] ?? false,
    );
  }

  factory HostApplicationModel.fromSnapshot(DocumentSnapshot doc) {
    
    

    final data = doc.data() as Map<String, dynamic>;
    return HostApplicationModel.fromMap(data);
  }

  HostApplicationModel copyWith({
    String? applicationId,
    String? userId,
    String? userName,
    String? email,
    String? phone,
    String? bio,
    String? reason,
    List<String>? socialLinks,
    int? expectedHoursPerWeek,
    String? experienceLevel,
    String? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewNotes,
    String? rejectionReason,
    // New fields
    String? category,
    List<String>? verificationPhotos,
    String? idDocumentUrl,
    int? age,
    DateTime? dateOfBirth,
    bool? ageVerified,
    bool? idVerified,
  }) {
    

    return HostApplicationModel(
      applicationId: applicationId ?? this.applicationId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      reason: reason ?? this.reason,
      socialLinks: socialLinks ?? this.socialLinks,
      expectedHoursPerWeek: expectedHoursPerWeek ?? this.expectedHoursPerWeek,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      // New fields
      category: category ?? this.category,
      verificationPhotos: verificationPhotos ?? this.verificationPhotos,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      ageVerified: ageVerified ?? this.ageVerified,
      idVerified: idVerified ?? this.idVerified,
    );
  }

  /// Get category display name
  String get categoryDisplayName {
    switch (category) {
      case 'gaming':
        return '🎮 Gaming';
      case 'music':
        return '🎵 Music';
      case 'dance':
        return '💃 Dance';
      case 'talk_show':
        return '🎙️ Talk Show';
      case 'education':
        return '📚 Education';
      case 'lifestyle':
        return '✨ Lifestyle';
      case 'cooking':
        return '🍳 Cooking';
      case 'fitness':
        return '💪 Fitness';
      case 'art':
        return '🎨 Art';
      case 'other':
        return '📌 Other';
      default:
        return '📌 Not Selected';
    }
  }

  /// Check if application is complete
  bool get isComplete {
    return reason != null &&
        reason!.isNotEmpty &&
        category != null &&
        verificationPhotos.isNotEmpty;
  }
}

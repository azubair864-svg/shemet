import 'package:cloud_firestore/cloud_firestore.dart';

class DiamondDealer {
  final String id;
  final String uid;
  final String officialName;
  final String region;
  final String status;
  final String contactLink;
  final String? photoURL;
  final String? whatsapp;
  final String? country;

  DiamondDealer({
    required this.id,
    required this.uid,
    required this.officialName,
    required this.region,
    required this.status,
    required this.contactLink,
    this.photoURL,
    this.whatsapp,
    this.country,
  });

  factory DiamondDealer.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DiamondDealer(
      id: doc.id,
      uid: data['uid'] ?? '',
      officialName: data['officialName'] ?? 'Official Dealer',
      region: data['region'] ?? 'Global',
      status: data['status'] ?? 'pending',
      contactLink: data['contactLink'] ?? 'https://wa.me/shemet_official',
      photoURL: data['photoURL'],
      whatsapp: data['whatsapp'],
      country: data['country'],
    );
  }
}

class DiamondDealerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final DiamondDealerService _instance = DiamondDealerService._internal();
  factory DiamondDealerService() => _instance;
  DiamondDealerService._internal();

  /// Fetch list of authorized dealers
  Future<List<DiamondDealer>> getAuthorizedDealers() async {
    try {
      final snapshot = await _firestore
          .collection('diamond_dealers')
          .where('status', isEqualTo: 'authorized')
          .get();

      return snapshot.docs
          .map((doc) => DiamondDealer.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

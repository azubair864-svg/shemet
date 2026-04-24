import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../core/constants/api_constants.dart';
import '../calls/video_call_screen.dart';

class HostessWaitingSheet extends StatefulWidget {
  final VoidCallback onRandomMatch;

  const HostessWaitingSheet({
    super.key,
    required this.onRandomMatch,
  });

  static Future<void> show(BuildContext context, VoidCallback onRandomMatch) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HostessWaitingSheet(onRandomMatch: onRandomMatch),
    );
  }

  @override
  State<HostessWaitingSheet> createState() => _HostessWaitingSheetState();
}

class _HostessWaitingSheetState extends State<HostessWaitingSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _initiateCall(UserModel host) {
    Navigator.pop(context); // Close sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          callId: 'direct_${host.uid}_${DateTime.now().millisecondsSinceEpoch}',
          otherUser: host,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.6;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C), // Dark base
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Join a Host',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    widget.onRandomMatch(); // Trigger random match
                  },
                  icon: const Icon(Icons.shuffle, color: Color(0xFFFF1493), size: 18),
                  label: const Text(
                    'Random Match',
                    style: TextStyle(
                      color: Color(0xFFFF1493),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1493).withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stream / List of Hostesses
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection(ApiConstants.usersCollection)
                  .where('isHost', isEqualTo: true)
                  .where('gender', isEqualTo: 'Female')
                  // Adding this basic where clause, more complex ordering usually requires composite index. 
                  // But standard equality checks like this work without extra indexing.
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF1493)));
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading hostesses', style: TextStyle(color: Colors.redAccent)),
                  );
                }

                final hosts = snapshot.data?.docs.map((doc) {
                  return UserModel.fromMap(doc.data() as Map<String, dynamic>);
                }).toList() ?? [];

                // Optionally filter "recent" online status locally if required, 
                // assuming they are fairly fresh in the query or by limiting output.
                // For a robust system, an 'isOnline' index could also be added.

                if (hosts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_rounded, size: 60, color: Colors.white54),
                        const SizedBox(height: 16),
                        const Text(
                          'No hostesses currently online.',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onRandomMatch();
                          },
                          icon: const Icon(Icons.shuffle, size: 18),
                          label: const Text('Try Random Match'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF1493),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        )
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: hosts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final host = hosts[index];
                    return _buildHostCard(host);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostCard(UserModel host) {
    final photoUrl = host.photos.isNotEmpty ? host.photos.first : '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
             width: 60,
             height: 60,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               border: Border.all(color: const Color(0xFFFF1493), width: 2),
             ),
             child: ClipRRect(
               borderRadius: BorderRadius.circular(30),
               child: photoUrl.isNotEmpty
                   ? CachedNetworkImage(
                       imageUrl: photoUrl,
                       fit: BoxFit.cover,
                     )
                   : const Icon(Icons.person, color: Colors.white54, size: 30),
             ),
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      host.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 6),
                    // Level Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF1493), Color(0xFFFF69B4)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Lv${host.level}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(host.countryFlag, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    // Placeholder for Price/Rate
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Row(
                        children: [
                          Text('💎', style: TextStyle(fontSize: 10)),
                          SizedBox(width: 4),
                          Text('100 / min', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Button
          ElevatedButton.icon(
            onPressed: () => _initiateCall(host),
            icon: const Icon(Icons.videocam, size: 16),
            label: const Text('Call Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }
}

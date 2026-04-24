import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../profile/user_profile_detail_screen.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}
class _RankingsScreenState extends State<RankingsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  String _category = 'earners'; // 'gifters' or 'earners'

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rankings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildCategoryToggle(),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _databaseService.getLeaderboard(category: _category),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
                }

                final users = snapshot.data ?? [];
                if (users.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _buildRankItem(user, index + 1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryToggle() {
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          _buildToggleItem('Top Earners', 'earners'),
          _buildToggleItem('Top Gifters', 'gifters'),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, String category) {
    final bool isSelected = _category == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _category = category),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFD700) : Colors.transparent, // Gold for ranking
            borderRadius: BorderRadius.circular(23),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 10)] : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankItem(UserModel user, int rank) {
    Color rankColor = Colors.white.withOpacity(0.4);
    if (rank == 1) rankColor = const Color(0xFFFFD700); // Gold
    if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
    if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileDetailScreen(user: user))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rank <= 3 ? rankColor.withOpacity(0.3) : Colors.white10, width: 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                rank.toString(),
                style: TextStyle(color: rankColor, fontSize: 18, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 24,
              backgroundImage: (user.photoURL != null && user.photoURL!.isNotEmpty) ? NetworkImage(user.photoURL!) : null,
              backgroundColor: Colors.white10,
              child: (user.photoURL == null || user.photoURL!.isEmpty) ? const Icon(Icons.person, color: Colors.white24) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        _category == 'earners' ? Icons.diamond : Icons.stars,
                        color: _category == 'earners' ? Colors.blue : const Color(0xFFFFD700),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _category == 'earners' ? '${user.diamonds}' : '${user.points}',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (rank <= 3)
              Icon(Icons.workspace_premium, color: rankColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, size: 60, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text('No rankings available yet', style: TextStyle(color: Colors.white.withOpacity(0.3))),
        ],
      ),
    );
  }
}

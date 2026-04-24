import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';

class PartyRoomsListScreen extends StatefulWidget {
  const PartyRoomsListScreen({super.key});

  @override
  State<PartyRoomsListScreen> createState() => _PartyRoomsListScreenState();
}

class _PartyRoomsListScreenState extends State<PartyRoomsListScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  late TabController _tabController;
  int _currentTab = 0;
  String _selectedCountry = 'All';
  String _selectedLanguage = 'All';

  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;

  final List<String> _countries = [
    'All','United States','United Kingdom','Canada','India',
    'Pakistan','Philippines','Indonesia','Saudi Arabia',
    'UAE','Egypt','Turkey','Brazil','Mexico',
  ];

  final List<String> _languages = [
    'All','English','Spanish','Arabic','Hindi','Urdu','Portuguese',
    'Indonesian','Turkish','French','German',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
        _loadRooms();
      }
    });
    _loadRooms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      Stream<List<Map<String, dynamic>>> roomsStream;

      if (_currentTab == 0) {
        roomsStream = _databaseService.getNearbyPartyRooms(
          country: _selectedCountry == 'All' ? null : _selectedCountry,
          language: _selectedLanguage == 'All' ? null : _selectedLanguage,
        );
      } else if (_currentTab == 1) {
        roomsStream = _databaseService.getActivePartyRooms();
      } else {
        roomsStream = _databaseService.getFollowingPartyRooms(_currentUserId);
      }

      roomsStream.listen((rooms) {
        if (mounted) {
          setState(() {
            _rooms = rooms;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildContent(),
          _buildTopBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton('Nearby', 0),
                      _buildTabButton('Party', 1),
                      _buildTabButton('Follow', 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/monthly_rank'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() => _currentTab = index);
          _loadRooms();
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 52),

          // INLINE FILTERS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Country dropdown
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade700,
                        width: 1,
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedCountry,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: Colors.grey.shade800,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.7), size: 20),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: _countries.map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(Icons.public, size: 14, color: Colors.white.withOpacity(0.7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCountry = val!);
                        _loadRooms();
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Language dropdown
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade700,
                        width: 1,
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: Colors.grey.shade800,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.7), size: 20),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: _languages.map((l) => DropdownMenuItem(
                        value: l,
                        child: Row(
                          children: [
                            Icon(Icons.language, size: 14, color: Colors.white.withOpacity(0.7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                      onChanged: (val) {
                        setState(() => _selectedLanguage = val!);
                        _loadRooms();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _rooms.isEmpty
                ? _buildEmptyState()
                : _buildRoomsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: _rooms.length,
      itemBuilder: (context, index) => _buildRoomCard(_rooms[index]),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final participantCount = room['participantCount'] ?? 0;
    final earnings = room['earnings'] ?? 0;
    final hostPhoto = room['hostPhoto'] ?? '';
    final coverPhoto = room['coverPhoto'] ?? '';
    final roomName = room['roomName'] ?? 'Party Room';
    final countryFlag = room['countryFlag'] ?? '🌍';
    final hostLevel = room['hostLevel'] ?? 1;
    final isLive = room['isLive'] ?? false;
    
    final displayImage = coverPhoto.toString().isNotEmpty ? coverPhoto : hostPhoto;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/party_room', arguments: room),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF69B4).withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: displayImage.isNotEmpty
                    ? Image.network(
                  displayImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade900, Colors.pink.shade900],
                      ),
                    ),
                    child: const Icon(Icons.people, size: 64, color: Colors.white30),
                  ),
                )
                    : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade900, Colors.pink.shade900],
                    ),
                  ),
                  child: const Icon(Icons.people, size: 64, color: Colors.white30),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              if (isLive)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.red, Colors.redAccent]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text('$participantCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        roomName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 2)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(countryFlag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF69B4), Color(0xFFFF1493)]),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF69B4).withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text('Lv$hostLevel', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (earnings > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💎', style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 4),
                              Text(_formatEarnings(earnings), style: const TextStyle(color: Colors.yellow, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    switch (_currentTab) {
      case 0:
        message = 'No nearby party rooms';
        break;
      case 2:
        message = 'No rooms from people you follow';
        break;
      default:
        message = 'No party rooms available';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
          const SizedBox(height: 8),
          Text('Try changing filters or check back later', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
        ],
      ),
    );
  }

  String _formatEarnings(int earnings) {
    if (earnings >= 1000000) {
      return '${(earnings / 1000000).toStringAsFixed(1)}M';
    } else if (earnings >= 1000) {
      return '${(earnings / 1000).toStringAsFixed(1)}K';
    }
    return earnings.toString();
  }
}
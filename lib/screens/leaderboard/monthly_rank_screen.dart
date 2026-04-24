import 'package:flutter/material.dart';
import 'dart:async';

class MonthlyRankScreen extends StatefulWidget {
  const MonthlyRankScreen({super.key});

  @override
  State<MonthlyRankScreen> createState() => _MonthlyRankScreenState();
}

class _MonthlyRankScreenState extends State<MonthlyRankScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Timer _timer;

  int _days = 23;
  int _hours = 4;
  int _minutes = 9;
  int _seconds = 34;

  String _selectedRange = '1-100';
  final List<String> _ranges = [
    '1-100',
    '101-200',
    '201-300',
    '301-400',
    '401-500',
    '501+',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_seconds > 0) {
          _seconds--;
        } else {
          _seconds = 59;
          if (_minutes > 0) {
            _minutes--;
          } else {
            _minutes = 59;
            if (_hours > 0) {
              _hours--;
            } else {
              _hours = 23;
              if (_days > 0) {
                _days--;
              }
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF6B4CE6), const Color(0xFF9B6FD7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Monthly Rank',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // Countdown Timer
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chevron_left, color: Colors.white),
                    const SizedBox(width: 12),
                    _buildTimeBox(_days.toString()),
                    const SizedBox(width: 4),
                    const Text('d', style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 12),
                    _buildTimeBox(_hours.toString().padLeft(2, '0')),
                    const SizedBox(width: 4),
                    const Text(
                      ':',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(width: 4),
                    _buildTimeBox(_minutes.toString().padLeft(2, '0')),
                    const SizedBox(width: 4),
                    const Text(
                      ':',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(width: 4),
                    _buildTimeBox(_seconds.toString().padLeft(2, '0')),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tabs Container
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Tab Bar
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF9B6FD7),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF9B6FD7),
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        tabs: const [
                          Tab(text: 'Charm Queens'),
                          Tab(text: 'Fortune Kings'),
                        ],
                      ),

                      // Sub Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Points',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.pink.shade300,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 60),
                            Text(
                              'Estimated reward',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.pink.shade300,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tab Content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLeaderboardList(true),
                            _buildLeaderboardList(false),
                          ],
                        ),
                      ),
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

  Widget _buildTimeBox(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5FD6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        time,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(bool isCharmQueens) {
    return Column(
      children: [
        // Range Selector
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _ranges.length,
            itemBuilder: (context, index) {
              final range = _ranges[index];
              final isSelected = _selectedRange == range;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRange = range;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF9B6FD7)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      range,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Leaderboard List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildRankItem(
                10,
                '💗Purnima💗',
                'Lv9',
                '🇮🇳',
                46086,
                15000,
                false,
              ),
              _buildRankItem(
                11,
                '🐬 dollphin 🥰',
                'Lv8',
                '🇮🇳',
                35475,
                10000,
                false,
              ),
              _buildRankItem(
                12,
                'pakhi Chaudhary',
                'Lv8',
                '🇮🇳',
                35414,
                10000,
                false,
              ),
              _buildRankItem(
                13,
                '🇧🇩 👑ভাভলি...',
                'Lv8',
                '🇧🇩',
                34727,
                10000,
                false,
              ),
              _buildRankItem(
                14,
                'তানিয়া জাকারিন 💁...',
                'Lv8',
                '🇧🇩',
                32300,
                10000,
                false,
              ),
              _buildRankItem(
                15,
                'Anjali 👑 quen',
                'Lv9',
                '🇮🇳',
                31307,
                10000,
                false,
              ),
            ],
          ),
        ),

        // Current User Position
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              const Text(
                '1000+',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF9B6FD7),
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'SensibleFig8788',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const Text('🇱🇰', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text(
                '💎 0',
                style: TextStyle(fontSize: 13, color: Colors.orange),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  _showAnonymousDialog();
                },
                child: const Text(
                  'Anonymous',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankItem(
    int rank,
    String name,
    String level,
    String flag,
    int points,
    int reward,
    bool isTop3,
  ) {
    Color rankColor;
    if (rank <= 3) {
      rankColor = rank == 1
          ? Colors.orange
          : rank == 2
          ? Colors.blue
          : Colors.orange.shade300;
    } else {
      rankColor = Colors.grey.shade400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rank == 1 ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank == 1 ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rankColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade300,
            child: Text(
              name[0],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B6FD7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '👑 $level',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(flag, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${points}K',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('💎', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 2),
                  Text(
                    '${reward}K',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAnonymousDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "You can't show up on the rank when anonymous. Are you sure to be anonymous?",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B6FD7),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/daily_bonus_service.dart';

class DailyBonusScreen extends StatefulWidget {
  final String userId;

  const DailyBonusScreen({
    super.key,
    required this.userId,
  });

  @override
  State<DailyBonusScreen> createState() => _DailyBonusScreenState();
}

class _DailyBonusScreenState extends State<DailyBonusScreen>
    with SingleTickerProviderStateMixin {
  final DailyBonusService _bonusService = DailyBonusService();

  LoginStreak? _streak;
  bool _isLoading = true;
  bool _isClaiming = false;
  Timer? _countdownTimer;
  Duration _timeUntilNextClaim = Duration.zero;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadStreak();
    _startCountdown();
    
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStreak() async {
    try {
      
      final streak = await _bonusService.getLoginStreak(widget.userId);
      if (mounted) {
        setState(() {
          _streak = streak;
          _isLoading = false;
        });
        
      }
    } catch (e) {
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Optionally set an empty streak or error state
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bonus info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    setState(() {
      _timeUntilNextClaim = _bonusService.getTimeUntilNextClaim();
    });
  }

  Future<void> _claimBonus() async {
    if (_isClaiming || _streak == null || !_streak!.canClaimToday) return;

    setState(() => _isClaiming = true);
    _animationController.forward().then((_) => _animationController.reverse());

    try {
      final result = await _bonusService.claimDailyBonus(widget.userId);

      if (result.success) {
        await _loadStreak();
        if (mounted) {
          _showRewardDialog(result);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? 'Failed to claim')),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }

  void _showRewardDialog(ClaimResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2D1F4E), Color(0xFF1A1A2E)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration icon
              const Text('🎉', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Daily Bonus Claimed!',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Streak info
              if (result.isNewLongestStreak)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 4),
                      Text(
                        'New Longest Streak!',
                        style: TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                '${result.newStreak} Day Streak!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),

              // Rewards
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'You Received:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRewardItem('💎', '+${result.diamondsEarned}', 'Diamonds'),
                        const SizedBox(width: 24),
                        _buildRewardItem('⭐', '+${result.xpEarned}', 'XP'),
                      ],
                    ),
                    if (result.specialReward != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.withOpacity(0.3),
                              Colors.pink.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎁', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Text(
                              result.specialReward!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardItem(String icon, String value, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text(
          'Daily Bonus',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE94057)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStreakHeader(),
                  const SizedBox(height: 24),
                  _buildWeeklyCalendar(),
                  const SizedBox(height: 24),
                  _buildClaimButton(),
                  const SizedBox(height: 24),
                  _buildMultiplierInfo(),
                  const SizedBox(height: 24),
                  _buildStreakMilestones(),
                ],
              ),
            ),
    );
  }

  Widget _buildStreakHeader() {
    final streak = _streak!;
    final multiplier = _bonusService.getMultiplier(streak.currentStreak);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE94057).withOpacity(0.8),
            const Color(0xFFF27121).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streak.currentStreak}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'Day Streak',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStreakStat('Best', '${streak.longestStreak}', '🏆'),
              _buildStreakStat('Total', '${streak.totalLogins}', '📅'),
              _buildStreakStat('Bonus', '${multiplier}x', '✨'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakStat(String label, String value, String icon) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyCalendar() {
    final streak = _streak!;
    final currentDay = streak.todayRewardDay;
    final claimedDays = streak.claimedDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Week Rewards',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Week ${streak.currentWeek}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final day = index + 1;
              final reward = DailyBonusService.weeklyRewards[index];
              final isClaimed = claimedDays.contains(day);
              final isToday = day == currentDay && streak.canClaimToday;
              final isPast = day < currentDay || isClaimed;

              return _buildDayCard(day, reward, isClaimed, isToday, isPast);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(
    int day,
    DailyReward reward,
    bool isClaimed,
    bool isToday,
    bool isPast,
  ) {
    Color bgColor;
    Color borderColor;

    if (isClaimed) {
      bgColor = Colors.green.withOpacity(0.2);
      borderColor = Colors.green;
    } else if (isToday) {
      bgColor = Colors.amber.withOpacity(0.2);
      borderColor = Colors.amber;
    } else if (isPast) {
      bgColor = Colors.grey.withOpacity(0.1);
      borderColor = Colors.grey;
    } else {
      bgColor = Colors.white.withOpacity(0.05);
      borderColor = Colors.white24;
    }

    return Container(
      width: 42,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isToday ? 2 : 1),
      ),
      child: Column(
        children: [
          Text(
            'D$day',
            style: TextStyle(
              color: isToday ? Colors.amber : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (isClaimed)
            const Icon(Icons.check_circle, color: Colors.green, size: 20)
          else if (reward.isMilestone)
            const Text('🎁', style: TextStyle(fontSize: 16))
          else
            const Text('💎', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            '+${reward.diamonds}',
            style: TextStyle(
              color: isToday ? Colors.amber : Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimButton() {
    final canClaim = _streak?.canClaimToday ?? false;

    return Column(
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: canClaim
                  ? const LinearGradient(
                      colors: [Color(0xFFE94057), Color(0xFFF27121)],
                    )
                  : null,
              color: canClaim ? null : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
              boxShadow: canClaim
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE94057).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canClaim ? _claimBonus : null,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: _isClaiming
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              canClaim ? Icons.card_giftcard : Icons.timer,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              canClaim ? 'Claim Daily Bonus' : 'Come Back Tomorrow',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        if (!canClaim) ...[
          const SizedBox(height: 12),
          Text(
            'Next bonus in: ${_formatDuration(_timeUntilNextClaim)}',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildMultiplierInfo() {
    final currentStreak = _streak?.currentStreak ?? 0;
    final currentMultiplier = _bonusService.getMultiplier(currentStreak);
    final nextMilestone = _bonusService.getNextMilestone(currentStreak);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('✨', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'Streak Multiplier',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE94057), Color(0xFFF27121)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${currentMultiplier}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Bonus',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (nextMilestone != null)
                      Text(
                        'Next: $nextMilestone days for ${_bonusService.getMultiplier(nextMilestone)}x',
                        style: const TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakMilestones() {
    final currentStreak = _streak?.currentStreak ?? 0;

    final milestones = [
      {'days': 7, 'label': '1 Week', 'icon': '🗓️'},
      {'days': 14, 'label': '2 Weeks', 'icon': '📅'},
      {'days': 30, 'label': '1 Month', 'icon': '🌙'},
      {'days': 60, 'label': '2 Months', 'icon': '⭐'},
      {'days': 90, 'label': '3 Months', 'icon': '🏅'},
      {'days': 180, 'label': '6 Months', 'icon': '👑'},
      {'days': 365, 'label': '1 Year', 'icon': '💎'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎯', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'Streak Milestones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...milestones.map((milestone) {
            final days = milestone['days'] as int;
            final label = milestone['label'] as String;
            final icon = milestone['icon'] as String;
            final isReached = currentStreak >= days;
            final progress = (currentStreak / days).clamp(0.0, 1.0);
            final multiplier = DailyBonusService.milestoneMultipliers[days] ?? 1.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isReached
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: TextStyle(
                          fontSize: 20,
                          color: isReached ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: isReached ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${multiplier}x',
                              style: TextStyle(
                                color: isReached ? Colors.amber : Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isReached ? Colors.amber : const Color(0xFFE94057),
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isReached
                              ? 'Unlocked!'
                              : '$currentStreak / $days days',
                          style: TextStyle(
                            color: isReached ? Colors.green : Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

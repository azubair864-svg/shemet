import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../services/racing_game_service.dart';

class CarRacingGameWidget extends StatefulWidget {
  final int userDiamonds;
  final Function(int)? onDiamondUpdate;
  final VoidCallback? onClose;

  const CarRacingGameWidget({
    super.key,
    required this.userDiamonds,
    required this.onDiamondUpdate,
    this.onClose,
  });

  @override
  State<CarRacingGameWidget> createState() => _CarRacingGameWidgetState();
}

class _CarRacingGameWidgetState extends State<CarRacingGameWidget>
    with TickerProviderStateMixin {
  final RacingGameService _racingService = RacingGameService();
  bool _showIntro = false; // Directly start in Garage/Betting screen

  // Video Banner Controller
  VideoPlayerController? _bannerVideoController;

  void _initializeVideo() {
    _bannerVideoController =
        VideoPlayerController.asset('assets/videos/car_race.mp4')
          ..initialize().then((_) {
            _bannerVideoController!.setLooping(true);
            _bannerVideoController!.setVolume(0.0); // Mute background
            _bannerVideoController!.play();
            setState(() {});
          });
  }

  // Local Animation Handling
  Timer? _animTimer;
  Timer? _countdownTimer;
  List<double> _carProgress = [];
  List<double> _carSpeeds = [];
  bool _isAnimatingRace = false;
  bool _isF1Countdown = false;
  int _lightState = 0; // 0=Off, 1=1Red, 2=2Red, 3=3Red, 4=Green
  Timer? _uiTimer;
  Timer? _resetDelayTimer;
  late Stream<RacingGameState> _gameStream;
  RacingStatus? _lastStatus; // Track previous status for transition logic
  bool _showingResult = false; // LOCAL flag: Are we displaying result screen?
  Timer? _resultDisplayTimer; // Timer for result screen display duration
  final Stopwatch _sessionStopwatch = Stopwatch();
  int _heartbeatTick = 0;
  int? _lastLoggedViewIndex;
  DateTime? _lastViewEnteredAt;

  // BUG FIX 1: Track last handled state to prevent duplicate _handleServerState calls
  String? _lastHandledRoundId;
  RacingStatus? _lastHandledStatus;
  bool _hasProcessedResult = false;

  // Timestamp helper for debug prints (Standardized for easier log filtering)
  String _ts() {
    final n = DateTime.now();
    final timeStr =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    return '[RACING_TRACE] 🏎️ $timeStr';
  }

  String _viewLabel(int index) {
    switch (index) {
      case -1:
        return 'INTRO';
      case 0:
        return 'GARAGE';
      case 1:
        return 'F1_COUNTDOWN';
      case 2:
        return 'RACING';
      case 3:
        return 'RESULT';
      case 4:
        return 'WAITING';
      default:
        return 'UNKNOWN($index)';
    }
  }

  void _logViewTransition(int nextViewIndex, RacingGameState state) {
    if (_lastLoggedViewIndex == nextViewIndex) return;

    final now = DateTime.now();
    if (_lastLoggedViewIndex != null && _lastViewEnteredAt != null) {
      final spentMs = now.difference(_lastViewEnteredAt!).inMilliseconds;
      debugPrint(
        '${_ts()} 🧭 VIEW EXIT ${_viewLabel(_lastLoggedViewIndex!)} after ${spentMs}ms',
      );
    }

    debugPrint(
      '${_ts()} 🧭 VIEW ENTER ${_viewLabel(nextViewIndex)} | '
      'status=${state.status.name} | round=${state.roundId} | '
      'remaining=${state.secondsRemaining}s | anim=$_isAnimatingRace | '
      'f1=$_isF1Countdown | result=$_showingResult',
    );
    _lastLoggedViewIndex = nextViewIndex;
    _lastViewEnteredAt = now;
  }

  // Betting Stats
  // Betting State
  int _selectedCarIndex = -1;
  int _betAmount = 10;
  String? _betCarId; // ID of the car user bet on (null if no bet placed)

  // --- Auto Betting State ---
  bool _isAutoMode = false;
  int _autoRoundsTotal = 0; // 0 = unlimited
  int _autoRoundsPlayed = 0;
  bool _autoRunning = false;
  int _consecutiveLosses = 0;
  int _consecutiveWins = 0; // Track winning streaks for "Hot" effect
  bool _showWinCelebration = false; // Toggle for coin rain
  int _stopAfterLosses = 0; // 0 = don't stop

  List<Map<String, dynamic>> _activeRacers = [];

  // Track Environments
  int _currentEnvIndex = 0;
  final Random _random = Random();
  int _roadTypePos = 1;
  int _activeRoadTypeIndex = 0; // Randomly selected road type

  final List<Map<String, dynamic>> _roadTipTypes = [
    {
      'name': 'ASPHALT',
      'icon': Icons.edit_road,
      'colors': [Colors.blueAccent, Colors.purpleAccent],
    },
    {
      'name': 'SAND',
      'icon': Icons.landscape,
      'colors': [Colors.orange, Colors.brown],
    },
    {
      'name': 'ICE',
      'icon': Icons.ac_unit,
      'colors': [Colors.cyan, Colors.white],
    },
    {
      'name': 'NEON',
      'icon': Icons.bolt,
      'colors': [Colors.cyanAccent, Colors.pinkAccent],
    },
  ];

  // POOL OF ALL VEHICLES (6 New Shemet Assets - Updated for 2025 UI)
  final List<Map<String, dynamic>> _allVehicles = [
    {
      'id': 'suv_purple', 'name': 'Luxury SUV',
      'image': 'assets/images/vehical_images/suv_purple_side.png',
      'top_image': 'assets/images/vehical_images/suv_purple_top.png',
      'color': Colors.purpleAccent,
      'speed': 0.8, 'handling': 0.9,
      'odds': 4.5, 'popularity': 1205, // "1,205 Bets"
      'price': 0,
      'owned': true,
      'speed_rating': '4.0/5.0',
      'speed_bars': 4,
      'wins': 1000,
    },
    {
      'id': 'jeep_green',
      'name': 'Safari Jeep',
      'image': 'assets/images/vehical_images/jeep_green_side.png',
      'top_image': 'assets/images/vehical_images/jeep_green_top.png',
      'color': Colors.green,
      'speed': 0.7,
      'handling': 0.95,
      'odds': 12.0,
      'popularity': 410,
      'price': 2000,
      'owned': false,
      'speed_rating': '3.5/5.0',
      'speed_bars': 3,
      'wins': 500,
    },
    {
      'id': 'sport_pink',
      'name': 'Retro Sport',
      'image': 'assets/images/vehical_images/sport_pink_side.png',
      'top_image': 'assets/images/vehical_images/sport_pink_top.png',
      'color': Colors.pinkAccent,
      'speed': 0.9,
      'handling': 0.7,
      'odds': 2.5,
      'popularity': 4890,
      'price': 5000,
      'owned': false,
      'speed_rating': '4.5/5.0',
      'speed_bars': 5,
      'wins': 2500,
    },
    {
      'id': 'bike_red',
      'name': 'Super Bike',
      'image': 'assets/images/vehical_images/bike_red_side.png',
      'top_image': 'assets/images/vehical_images/bike_red_top.png',
      'color': Colors.redAccent,
      'speed': 1.0,
      'handling': 0.6,
      'odds': 6.0,
      'popularity': 850,
      'price': 8000,
      'owned': false,
      'speed_rating': '5.0/5.0',
      'speed_bars': 5,
      'wins': 4000,
    },
    {
      'id': 'truck_yellow',
      'name': 'Monster Truck',
      'image': 'assets/images/vehical_images/truck_yellow_side.png',
      'top_image': 'assets/images/vehical_images/truck_yellow_top.png',
      'color': Colors.amber,
      'speed': 0.6,
      'handling': 1.0,
      'odds': 25.0,
      'popularity': 120,
      'price': 10000,
      'owned': false,
      'speed_rating': '3.0/5.0',
      'speed_bars': 3,
      'wins': 1500,
    },
    {
      'id': 'car_blue',
      'name': 'Cyber Car',
      'image': 'assets/images/vehical_images/car_blue_side.png',
      'top_image': 'assets/images/vehical_images/car_blue_top.png',
      'color': Colors.blueAccent,
      'speed': 0.95,
      'handling': 0.85,
      'odds': 8.8,
      'popularity': 600,
      'price': 15000,
      'owned': false,
      'speed_rating': '4.8/5.0',
      'speed_bars': 5,
      'wins': 3000,
    },
  ];

  final List<Map<String, dynamic>> _environments = [
    {
      'name': 'ASPHALT',
      'id': 'asphalt',
      'surface': Color(0xFF2D2D2D),
      'curb_1': Colors.redAccent,
      'curb_2': Colors.white,
      'divider': Colors.white.withValues(alpha: 0.5),
      'track_image': 'assets/images/track_images/cartoon_chamet_3lane.png',
      'header_colors': [Color(0xFF1A1A1A), Color(0xFF2C3E50)],
    },
    {
      'name': 'SAND',
      'id': 'sand',
      'surface': Color(0xFFD7CCC8),
      'curb_1': Color(0xFF5D4037),
      'curb_2': Colors.orangeAccent,
      'divider': Color(0xFF8D6E63),
      'track_image': 'assets/images/track_images/cartoon_chamet_sand_3lane.png',
      'header_colors': [Color(0xFFE65100), Color(0xFFFFB74D)],
    },
    {
      'name': 'ICE',
      'id': 'ice',
      'surface': Color(0xFFE1F5FE),
      'curb_1': Colors.blueAccent,
      'curb_2': Colors.white,
      'divider': Color(0xFF01579B),
      'track_image': 'assets/images/track_images/cartoon_chamet_ice_3lane.png',
      'header_colors': [Color(0xFF0288D1), Color(0xFFB3E5FC)],
    },
    {
      'name': 'NEON',
      'id': 'neon',
      'surface': Color(0xFF272F42),
      'curb_1': Colors.cyanAccent,
      'curb_2': Colors.pinkAccent,
      'divider': Color(0xFF80DEEA),
      'track_image': 'assets/images/track_images/cartoon_chamet_neon_3lane.png',
      'header_colors': [Color(0xFF141A2E), Color(0xFF3A234E)],
    },
  ];

  DateTime? _lastManualTrigger;

  @override
  void initState() {
    super.initState();
    _sessionStopwatch.start();
    _initializeVideo(); // Initialize Video for Screen 3 Banner
    _setupNewRace(); // Initialize vehicles
    _racingService.joinGameRoom(); // 🔌 Join the game room (Presence Tracking)
    // Optimized: Only refresh UI if something actually changed status-wise,
    // or if the timer is visible.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _heartbeatTick++;
        debugPrint(
          '${_ts()} ❤️ HB#$_heartbeatTick | t=${_sessionStopwatch.elapsed.inSeconds}s | '
          'status=${_lastHandledStatus?.name ?? "none"} | view=${_viewLabel(_lastLoggedViewIndex ?? 0)} | '
          'anim=$_isAnimatingRace | f1=$_isF1Countdown | result=$_showingResult | '
          'diamonds=${widget.userDiamonds} | bet=$_betAmount | selected=$_selectedCarIndex | betCar=$_betCarId',
        );
        // Selective updates are handled via StreamBuilder primarily
        // But we force a refresh for the global heartbeat countdown
        setState(() {});
      }
    });

    // Initialize Stream ONCE
    _gameStream = _racingService.gameStateStream;
  }

  // No longer init random cars here, we do it at Start Race
  void _setupNewRace() {
    _initRacers();
    // Randomize Road Type Position AND Content for this round
    _roadTypePos = _random.nextInt(3);
    _activeRoadTypeIndex = _random.nextInt(_roadTipTypes.length);
    _currentEnvIndex = _activeRoadTypeIndex;
  }

  @override
  void dispose() {
    _racingService.leaveGameRoom(); // 🔌 Leave the game room
    _bannerVideoController?.dispose(); // Dispose Video Controller
    _animTimer?.cancel();
    _countdownTimer?.cancel();
    _uiTimer?.cancel();
    _resetDelayTimer?.cancel();
    _resultDisplayTimer?.cancel();
    _racingService.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  void _startBettingPhase() {
    // _selectedCarIndex is preserved
    // ... (timer logic for countdown if needed, but we removed auto-start for manual play)
  }

  void _initRacers() {
    // 1. Force Include the Selected Car (if available)
    List<Map<String, dynamic>> finalRacers = [];

    if (_selectedCarIndex != -1 && _selectedCarIndex < _allVehicles.length) {
      finalRacers.add(_allVehicles[_selectedCarIndex]);
    }

    // 2. Fill remaining slots with random unique cars
    final shuffled = List<Map<String, dynamic>>.from(_allVehicles)..shuffle();
    for (var car in shuffled) {
      if (finalRacers.length >= 6) break;
      // Avoid duplicates
      if (finalRacers.any((existing) => existing['id'] == car['id'])) continue;

      finalRacers.add(car);
    }

    // 3. Shuffle positions so user isn't always Lane 1 (Optional, but good for game logic)
    finalRacers.shuffle();

    _activeRacers = finalRacers;
    _carProgress = List.filled(_activeRacers.length, 0.0);
  }

  // --- LIVE GAME SYNC LOGIC ---

  void _handleServerState(RacingGameState state) {
    // BUG FIX 1: Only process if round OR status actually changed — prevents duplicate calls
    final sameState =
        _lastHandledRoundId == state.roundId &&
        _lastHandledStatus == state.status;
    if (sameState) {
      // Same state as before — skip (this was the root cause of all navigation jumps)
      return;
    }

    debugPrint(
      '${_ts()} 📡 SERVER UPDATE: status=${state.status.name} round=${state.roundId} remaining=${state.secondsRemaining}s',
    );
    debugPrint(
      '${_ts()}    ℹ️ Client Flags: animating=$_isAnimatingRace f1=$_isF1Countdown showingResult=$_showingResult',
    );

    // If round ID changed, reset result processing flag
    if (_lastHandledRoundId != state.roundId) {
      _hasProcessedResult = false;
    }

    // Update tracking BEFORE any logic runs
    _lastHandledRoundId = state.roundId;
    _lastHandledStatus = state.status;
    _lastStatus = state.status;

    // --- RESULT: Activate result screen ---
    if (state.status == RacingStatus.result && !_showingResult) {
      debugPrint('${_ts()} 🏆 RESULT DETECTED → showing result screen for 6s');
      setState(() {
        _showingResult = true;
      });

      _resultDisplayTimer?.cancel();
      _resultDisplayTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) {
          debugPrint('${_ts()} ⏱️ Result timer done → hiding result screen');
          setState(() {
            _showingResult = false;
          });
        }
      });
    }

    // --- RACING: Start F1 lights → race animation ---
    if (state.status == RacingStatus.racing &&
        !_isAnimatingRace &&
        !_isF1Countdown) {
      if (state.winnerCarId != null) {
        debugPrint(
          '${_ts()} 🚀 Starting F1 sequence! winner=${state.winnerCarId}',
        );
        _startF1Sequence(state.winnerCarId!);
      } else {
        debugPrint(
          '${_ts()} ⚠️ RACING state but winnerCarId is null — skipping F1 sequence',
        );
      }
    } else if (state.status == RacingStatus.racing) {
      debugPrint(
        '${_ts()} ⚠️ Ignored RACING trigger — already animating=$_isAnimatingRace  f1=$_isF1Countdown',
      );
    }

    // --- BETTING: Reset to garage ---
    if (state.status == RacingStatus.betting) {
      if (_lastStatus == RacingStatus.result) {
        debugPrint('${_ts()} ⏳ RESULT→BETTING: Delayed reset in 6s');
        _resetDelayTimer?.cancel();
        _resetDelayTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) {
            debugPrint('${_ts()} ✅ Delayed reset fired → returning to garage');
            _resetRace();
          }
        });
      } else {
        debugPrint('${_ts()} 🔄 Direct BETTING → immediate reset');
        _resetRace();
      }
    }
  }

  // F1 Sequence: 3 Red Lights -> Green -> Go
  void _startF1Sequence(String winnerId) {
    debugPrint('${_ts()} 🚦 F1 Sequence START  winner=$winnerId');
    setState(() {
      _isF1Countdown = true;
      _lightState = 0;
    });

    int step = 0;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        step++;
        _lightState = step;
        debugPrint('${_ts()} 🚦 Light $step');

        if (step == 4) {
          // Green!
          timer.cancel();
          debugPrint('${_ts()} 🟩 GREEN! Starting race animation...');
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() => _isF1Countdown = false);
              _startLiveRaceAnimation(winnerId);
            }
          });
        }
      });
    });
  }

  // Animates the cars locally, but ENSURES 'winnerId' wins.
  void _startLiveRaceAnimation(String winnerId) {
    debugPrint(
      '${_ts()} 🏎️ Race animation START  winner=$winnerId  racers=${_activeRacers.map((c) => c["id"]).toList()}',
    );
    setState(() {
      _isAnimatingRace = true;
      _carProgress = List.filled(_activeRacers.length, 0.0);

      // Winner gets faster speed, others slightly slower random
      _carSpeeds = List.generate(_activeRacers.length, (index) {
        final carId = _activeRacers[index]['id'];
        if (carId == winnerId) return 0.015;
        return 0.008 + _random.nextDouble() * 0.005;
      });
    });

    _animTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        bool allFinished = true;
        for (int i = 0; i < _activeRacers.length; i++) {
          final jitter = (_random.nextDouble() - 0.5) * 0.002;
          _carProgress[i] += _carSpeeds[i] + jitter;
          if (_carProgress[i] >= 1.0) {
            _carProgress[i] = 1.0;
          } else {
            allFinished = false; // Not all cars have finished yet
          }
        }

        if (allFinished) {
          timer.cancel();
          // BUG FIX 4: Set _isAnimatingRace = false so screen transitions correctly
          _isAnimatingRace = false;
          debugPrint('${_ts()} 🏁 Race animation FINISHED (All cars crossed the line) winner=$winnerId');
        }
      });
    });
  }

  void _resetRace() {
    // BUG FIX 3: Removed the bad `if (_isAnimatingRace)` guard.
    // Reset must always happen regardless of current animation state.
    debugPrint(
      '${_ts()} 🔄 _resetRace() called  wasAnimating=$_isAnimatingRace  betCar=$_betCarId',
    );
    _animTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _isAnimatingRace = false;
      _isF1Countdown = false;
      _lightState = 0;
      _carProgress = List.filled(_activeRacers.length, 0.0);
      _roadTypePos = _random.nextInt(3);
      _activeRoadTypeIndex = _random.nextInt(_roadTipTypes.length);
      _currentEnvIndex = _activeRoadTypeIndex;
      _betCarId = null;
      _selectedCarIndex = -1;
      _hasProcessedResult = false;
      _initRacers();
    });
    debugPrint('${_ts()} ✅ _resetRace() complete — back to garage');
  }

  // --- ACTIONS ---

  void _handleVehicleSelect(int index) {
    debugPrint(
      '${_ts()} 🖱️ VEHICLE TAP index=$index id=${_allVehicles[index]['id']}',
    );

    setState(() {
      if (_selectedCarIndex == index) {
        // ENHANCEMENT 5: Unselect if tapping the already selected car
        _selectedCarIndex = -1;
        debugPrint('${_ts()} ❌ VEHICLE UNSELECTED id=${_allVehicles[index]['id']}');
      } else {
        // Select the new car
        _selectedCarIndex = index;
        debugPrint('${_ts()} ✅ VEHICLE SELECTED id=${_allVehicles[index]['id']}');
      }
      
      // RE-INIT RACERS immediately to show selected car on track or remove it
      _initRacers();
    });
  }

  Future<void> _placeBet() async {
    if (_selectedCarIndex == -1) return;
    final sw = Stopwatch()..start();
    debugPrint(
      '${_ts()} 🎯 PLACE_BET START amount=$_betAmount selected=$_selectedCarIndex coins=${widget.userDiamonds}',
    );

    // Check balance for auto-bet validation too
    if (widget.userDiamonds < _betAmount) {
      if (!mounted) return; // ✅ Fix: Check mounted before using context
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough diamonds to bet!')));
      if (_autoRunning) {
        setState(() => _autoRunning = false);
      }
      return;
    }

    // CRITICAL: Get car ID from _allVehicles (source of truth), not _activeRacers (shuffled)
    final selectedCar = _allVehicles[_selectedCarIndex];
    final carId = selectedCar['id'];
    debugPrint('${_ts()} 🎯 PLACE_BET REQUEST carId=$carId amount=$_betAmount');

    // ✅ Fix: Add timeout protection
    bool success = false;
    try {
      success = await _racingService
          .placeBet(carId, _betAmount)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Bet timeout'),
          );
    } on TimeoutException {
      if (!mounted) return; // ✅ Fix: Check mounted before using context
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Try again.')),
      );
      debugPrint(
        '${_ts()} ❌ PLACE_BET TIMEOUT after ${sw.elapsedMilliseconds}ms',
      );
      if (_autoRunning) {
        setState(() => _autoRunning = false);
      }
      return;
    } catch (e) {
      if (!mounted) return; // ✅ Fix: Check mounted before using context
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      debugPrint(
        '${_ts()} ❌ PLACE_BET ERROR after ${sw.elapsedMilliseconds}ms error=$e',
      );
      if (_autoRunning) {
        setState(() => _autoRunning = false);
      }
      return;
    }

    if (success) {
      if (!mounted) return; // ✅ Fix: Check mounted before using context
      widget.onDiamondUpdate?.call(
        widget.userDiamonds - _betAmount,
      ); // Deduct diamonds immediately locally for UX
      setState(() {
        _betCarId = carId; // Store bet car ID for result tracking
        if (_autoRunning) {
          _autoRoundsPlayed++;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bet Placed! Good Luck! 🍀')),
      );
      debugPrint(
        '${_ts()} ✅ PLACE_BET SUCCESS in ${sw.elapsedMilliseconds}ms carId=$carId',
      );
    } else {
      if (!mounted) return; // ✅ Fix: Check mounted before using context
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to place bet. Check balance!')),
      );
      debugPrint(
        '${_ts()} ❌ PLACE_BET FAILED in ${sw.elapsedMilliseconds}ms carId=$carId',
      );
      if (_autoRunning) {
        setState(() => _autoRunning = false); // Stop auto on failure
      }
    }
  }



  Future<void> _syncCoinBalanceFromServer() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return;

      final diamonds = (doc.data()?['diamonds'] as num?)?.toInt() ?? (doc.data()?['coins'] as num?)?.toInt();
      if (diamonds == null) return;
      widget.onDiamondUpdate?.call(diamonds);
    } catch (e) {
      debugPrint('${_ts()} ❌ balance sync failed: $e');
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RacingGameState>(
      stream: _gameStream,
      builder: (context, snapshot) {
        final state =
            snapshot.data ??
            RacingGameState(
              roundId: 'loading',
              status: RacingStatus.betting,
              nextPhaseTime: DateTime.now().add(const Duration(seconds: 30)),
            );

        // BUG FIX 1: Only call _handleServerState when round or status ACTUALLY changes.
        // Previously called via addPostFrameCallback on EVERY build (2-5x/second) causing
        // timer restarts, screen jumps, and countdown resets.
        final stateChanged =
            _lastHandledRoundId != state.roundId ||
            _lastHandledStatus != state.status;
        if (stateChanged) {
          debugPrint(
            '${_ts()} 📡 Stream state change detected: ${_lastHandledStatus?.name ?? "none"} → ${state.status.name}  round=${state.roundId}',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleServerState(state);
          });
        }

        // CLIENT ASSIST: If backend cron is delayed, fast-forward it if 0s remaining for a while
        if (state.status != RacingStatus.waiting && state.secondsRemaining == 0) {
          final now = DateTime.now();
          if (_lastManualTrigger == null || now.difference(_lastManualTrigger!).inSeconds > 5) {
             _lastManualTrigger = now;
             debugPrint('${_ts()} 🕒 State overdue on client! Notifying backend to fast-forward...');
             _racingService.triggerNextPhase();
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) => _buildGameContent(state),
        );
      },
    );
  }

  Widget _buildGameContent(RacingGameState state) {
    // Determine which view to show
    Widget currentView;

    if (_showIntro) {
      currentView = _buildIntroView();
    } else if (state.status == RacingStatus.waiting) {
      currentView = _buildWaitingView(state);
    } else if (_showingResult) {
      currentView = _buildResultScreen(state);
    } else if (_isAnimatingRace) {
      currentView = _buildRaceView(state);
    } else if (_isF1Countdown) {
      currentView = _buildF1CountdownView(state);
    } else {
      currentView = _buildGarageView(state);
    }

    // Wrap the entire content in a standard container to maintain Shemet aesthetic
    return Container(
      color: const Color(0xFF1E1E2C),
      child: Stack(
        children: [
          currentView,
          // Shared Overlay Header (Only for Garage/Intro)
          if (!_isAnimatingRace && !_isF1Countdown && !_showingResult)
            _buildHeader(state),
        ],
      ),
    );
  }

  // VIEWS

  Widget _buildResultScreen(RacingGameState state) {
    // Deferred Loading: Initialize video only when result screen is shown
    if (_bannerVideoController == null) {
      _initializeVideo();
    }

    // Find winner details
    final winner = _activeRacers.firstWhere(
      (car) => car['id'] == state.winnerCarId,
      orElse: () =>
          _activeRacers.isNotEmpty ? _activeRacers[0] : _allVehicles[0],
    );

    // SPECTATOR MODE: Handled if _betCarId is null
    bool localWin = _betCarId != null && _betCarId == winner['id'];
    bool isSpectator = _betCarId == null;

    // Display: winner car (always attractive)
    final displayCar = winner;

    // -- AUTO-BET TRACKING LOGIC --
    // We only want to track this ONCE per result screen display.
    // This build method gets called multiple times. We'll track it using a flag or during transition.
    // For simplicity, we update state immediately on first build if needed (guarded by a condition).
    // Note: To avoid setState during build, it's better to calculate this and apply coins/stats
    // only if they haven't been applied yet for this round.
    if (_lastHandledRoundId == state.roundId && !_hasProcessedResult) {
      _hasProcessedResult = true; // Need to add this flag to State
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (localWin) {
            setState(() {
              _consecutiveLosses = 0;
              _consecutiveWins++; // Increment win streak
              _showWinCelebration = true; // TRIGGER WOW FACTOR 🎉
            });
          } else {
            setState(() {
              _consecutiveLosses++;
              _consecutiveWins = 0; // Reset win streak
            });
          }

          // Keep UI balance aligned with backend payout/settlement
          _syncCoinBalanceFromServer();
        }
      });
    }

    // THEME SELECTION
    final bgColor = localWin
        ? const Color(0xFF2E1A05)
        : const Color(0xFF151515);
    final gradient = localWin
        ? const RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [Color(0xFFFFD700), Color(0xFF2E1A05)],
          )
        : const RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Color(0xFF444444), Color(0xFF000000)],
          );

    final titleText = isSpectator
        ? 'WINNER REVEALED'
        : (localWin ? 'YOU WIN!' : 'YOU LOSE');
    final titleColor = isSpectator
        ? Colors.white
        : (localWin ? Colors.amberAccent : Colors.redAccent);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(color: bgColor, gradient: gradient),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // 1. OUTCOME TITLE
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    titleText,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 32, // slightly smaller
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: titleColor.withValues(alpha: 0.6),
                          blurRadius: 15,
                        ),
                        const Shadow(
                          color: Colors.black,
                          blurRadius: 5,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // 2. SUBTITLE
                Text(
                  localWin ? 'CONGRATULATIONS!' : 'WINNER WAS:',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                
                const SizedBox(height: 12),

                // 3. MAIN VISUAL (Centerpiece - Flexible to avoid scrolling)
                Flexible(
                  flex: 3,
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Back Glow
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: displayCar['color'].withValues(
                                  alpha: localWin ? 0.5 : 0.2,
                                ),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),

                        // TROPHY (Only if Win)
                        if (localWin)
                          Positioned(
                            top: -10,
                            child: Image.asset(
                              'assets/images/trophy.png',
                              height: 80, // Scaling down slightly
                            ),
                          ),

                        // CAR IMAGE (Show bet car if won, winner car if lost)
                        Positioned(
                          bottom: 10,
                          child: Transform.scale(
                            scale: 1.1,
                            child: Image.asset(
                              displayCar['image'],
                              height: 80, // Scaling down slightly
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 4. REWARD / MESSAGE
                if (isSpectator) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'WATCHING ONLY',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ] else if (localWin) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'WIN CONFIRMED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Better Luck Next Time!',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const SizedBox(
                  width: 150,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: Colors.white24,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Returning to Garage...',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGarageView(RacingGameState state) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C), // Solid background
      ),
      child: Column(
        children: [
          // 3. Road Types Strip ("Race eke thiyena wiwida road types")
          Container(
            height: 30, // Reduced height ("usa adu karanna")
            width: double.infinity,
            color: const Color(0xFF2C2C3E),
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
            ), // Reduced padding to 8 to MAXIMIZE width
            child: Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  Expanded(
                    child: i == _roadTypePos
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _roadTipTypes[_activeRoadTypeIndex]['colors'][0]
                                      .withValues(alpha: 0.2),
                                  _roadTipTypes[_activeRoadTypeIndex]['colors'][1]
                                      .withValues(alpha: 0.2),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _roadTipTypes[_activeRoadTypeIndex]['icon'],
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _roadTipTypes[_activeRoadTypeIndex]['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Center(
                            child: Text(
                              '???',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                  ),
                  if (i < 2) const SizedBox(width: 4), // Reduced Gap to 4px
                ],
              ],
            ),
          ),

          // 4. Vehicle Betting Cards
          Expanded(child: _buildVehicleGrid(state)),

          // 5. Betting Controls (Manual / Auto Tabs)
          _buildBettingTabs(),

          // 6. Active Betting Panel
          if (_isAutoMode) _buildAutoControls() else _buildChipSelector(),
        ],
      ),
    );
  }

  Widget _buildHeader(
    RacingGameState state, {
    int viewIndex = 0,
    bool showInfoBar = true,
  }) {
    return Stack(
      children: [
        // 1. GLOBAL HEADER BACKGROUND (Extends behind Status Bar)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // 2. HEADER IMAGE
        Positioned(
          right: -15, // Move Right a bit ("poddk dakunata")
          top: -30,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.75,
          child: Opacity(
            opacity: 0.9,
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0.0, 0.4],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Transform.scale(
                scale: 0.9, // Slight Zoom Out ("poddk zoom out")
                child: Image.asset(
                  'assets/images/games/banner_23.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ),
        ),

        // 2. SAFE AREA CONTENT (Title & Stats)
        SafeArea(
          bottom: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              4,
              (viewIndex == 1 || viewIndex == 2) ? 0 : 5,
              4,
              0,
            ), // Reclaim top space during racing
            child: Column(
              children: [
                // ROW 1: Title & Close Button
                Padding(
                  padding: EdgeInsets.only(
                    bottom: (viewIndex == 1 || viewIndex == 2) ? 0 : 5,
                    left: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // LEFT: Title
                      Transform.translate(
                        offset: Offset(
                          0,
                          (viewIndex == 1 || viewIndex == 2) ? -20 : -12,
                        ), // Move title even higher during racing
                        child: Text(
                          'SHEMET RACING',
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: (viewIndex == 2) ? 0.5 : 1.0,
                            ), // Fade slightly during racing
                            fontWeight: FontWeight.w900,
                            fontSize: (viewIndex == 1 || viewIndex == 2)
                                ? 14
                                : 16,
                            fontStyle: FontStyle.italic,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (viewIndex == 1 || viewIndex == 2) ...[
                  // Screen 2 & 3 Override: Removed 30px spacer to expand track height
                  const SizedBox(height: 2),
                ] else if (showInfoBar) ...[
                  const SizedBox(
                    height: 8,
                  ), // Push Info Bar & Garage down ("tikak pahalata")
                  // ROW 2: The "Long Bar" (All Stats + Balance) RESTORED
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      // Gradient similar to reference (Red/Orange/Pink)
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18), // Pill shape
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 1. Users (Mock -> Now Live from RTDB count)
                        StreamBuilder<int>(
                          stream: _racingService.activePlayersStream,
                          builder: (context, snapshot) {
                            final activeCount = snapshot.data ?? 1; // Default to 1 (self) while loading
                            return Row(
                              children: [
                                const Icon(Icons.person, color: Colors.white, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  '$activeCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            );
                          }
                        ),
                        Container(
                          width: 1,
                          height: 15,
                          color: Colors.white30,
                        ), // Vertical Divider
                        // 2. Total Pool
                        Row(
                          children: [
                            const Text('💎', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 2),
                            Text(
                              '${state.totalPool}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 15, color: Colors.white30),

                        // 3. Timer (Heartbeat Pulse)
                        Builder(
                          builder: (context) {
                            final isCritical =
                                state.secondsRemaining <= 3 &&
                                state.status == RacingStatus.betting;
                            return TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 400),
                              tween: Tween(
                                begin: 1.0,
                                end: isCritical ? 1.2 : 1.0,
                              ),
                              curve: Curves.elasticOut,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        color: isCritical
                                            ? Colors.yellow
                                            : Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        state.secondsRemaining > 0
                                            ? '${state.secondsRemaining}s'
                                            : 'SYNC',
                                        style: TextStyle(
                                          color: isCritical
                                              ? Colors.yellow
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        Container(width: 1, height: 15, color: Colors.white30),

                        // 4. User Balance
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/diamond_purchase');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '💎',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${widget.userDiamonds}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.add_circle,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // 3. CLOSE BUTTON (Positioned Absolute Top Right)
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque, // Ensure hits are caught
            child: Container(
              padding: const EdgeInsets.all(12), // Larger Touch Area
              child: const Icon(Icons.close, color: Colors.black, size: 24),
            ),
          ),
        ),
      ],
    );
  }

  // 5. VEHICLE LIST (Horizontal Scroll, All Vehicles)
  Widget _buildVehicleGrid(RacingGameState state) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      // Reduced lateral padding to 8 to widen cards even more
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      itemCount: _allVehicles.length, // SHOW ALL 7
      itemBuilder: (context, index) {
        final car = _allVehicles[index];
        final isSelected = _selectedCarIndex == index;
        return _buildVehicleCard(car, index, isSelected, state);
      },
    );
  }

  Widget _buildVehicleCard(
    Map<String, dynamic> car,
    int index,
    bool isSelected,
    RacingGameState state,
  ) {
    // Dynamic values from backend mapped to car ID
    final carId = car['id'];
    final backendData = state.vehicles[carId] ?? {};
    
    // Fallback to static data if backend is still initializing
    final double odds = (backendData['odds'] as num?)?.toDouble() ?? (car['odds'] ?? 2.0);
    final int popularity = (backendData['total_bets'] as num?)?.toInt() ?? (car['popularity'] ?? 0);

    // 1. Calculate Opacity: If ANY car is selected, unselected cars get dimmed.
    final bool hasSelection = _selectedCarIndex != -1;
    final double cardOpacity = (hasSelection && !isSelected) ? 0.6 : 1.0;

    // 2. Wrap in AnimatedContainer/Scale for smooth pop-out effect
    return GestureDetector(
      onTap: () => _handleVehicleSelect(index),
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0, // Scale up by 5% if selected
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: cardOpacity, // Dim unselected cars
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: (MediaQuery.of(context).size.width - 24) / 3,
            margin: const EdgeInsets.only(right: 4, top: 4, bottom: 4), // Added vertical margin to allow scale
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.lightGreenAccent : Colors.transparent,
                width: isSelected ? 3 : 2, // Thicker border
              ),
              boxShadow: [
                if (isSelected) ...[
                  // ENHANCEMENT 3: Glowing Shadow (Updated to Green)
                  BoxShadow(
                    color: Colors.lightGreenAccent.withValues(alpha: 0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.8),
                    blurRadius: 8,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ] else ...[
                  const BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none, // Allow badge to overflow slightly
              children: [
                // 1. FILL: Vehicle Image
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 28),
                    child: Transform.scale(
                      scale: 1.08,
                      child: Image.asset(car['image'], fit: BoxFit.contain),
                    ),
                  ),
                ),

                // 2. TOP OVERLAY: Odds, Name, & Help
                Positioned(
                  top: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A5ACD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${odds.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            car['name'],
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const Icon(Icons.help_outline, color: Colors.grey, size: 14),
                    ],
                  ),
                ),

                // 3. BOTTOM OVERLAY: Popularity
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💎', style: TextStyle(fontSize: 8)),
                            const SizedBox(width: 2),
                            Text(
                              '$popularity',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // My Bet (Right)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💎', style: TextStyle(fontSize: 9)),
                            const SizedBox(width: 2),
                            Text(
                              (_selectedCarIndex == index && _betCarId != null) ? '$_betAmount' : '0',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. ENHANCEMENT 4: Green Checkmark Badge
                if (isSelected)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.lightGreenAccent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check, color: Colors.lightGreenAccent, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SCREEN 3 TRACK (Active) ---
  Widget _buildTrack() {
    return Stack(
      children: [
        // 1. SHARED BACKGROUND (Matches Screen 2 Visuals Exactly)
        Positioned.fill(child: _buildTrackBackground()),

        // 2. ACTIVE CARS OVERLAY
        Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Expanded(flex: 2, child: SizedBox()), // Top Spacer (Push cars down from curb)
                  ...List.generate(_activeRacers.length * 2 - 1, (i) {
                    if (i.isEven) {
                      // LANE (Active Car)
                      int laneIndex = i ~/ 2;
                      return _buildLane(laneIndex, []);
                    } else {
                      // INVISIBLE DIVIDER (between cars)
                      return const Expanded(flex: 1, child: SizedBox());
                    }
                  }),
                  const Expanded(flex: 2, child: SizedBox()), // Bottom Spacer (Push cars up from curb)
                ],
              ),
            ),
          ],
        ),

        // 3. UI OVERLAYS (Back Button)
        Positioned(
          top: 40,
          left: 10,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  // --- LAYOUT HELPERS (Racing Phase) ---

  Widget _buildGlobalStatsPill(RacingGameState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 6,
      ), // 1. Reduced Height ("usa adu wenna")
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white70, width: 1.5), // "kotu border"
        // No borderRadius -> Sharp Corners ("kon 4 rauwm karannepa")
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<int>(
            stream: _racingService.activePlayersStream,
            builder: (context, snapshot) {
              final activeCount = snapshot.data ?? 1;
              return Row(
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              );
            }
          ),
          Container(
            width: 1,
            height: 16,
            color: Colors.white54,
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '${state.totalPool}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRacerSummaries(RacingGameState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_activeRacers.length, (index) {
        final car = _activeRacers[index];
        final isMyCk = _selectedCarIndex == index;
        final carId = car['id'];
        final totalBets = state.vehicles[carId]?['total_bets'] ?? 0;

        return Container(
          width: (MediaQuery.of(context).size.width - 60) / 6,
          padding: const EdgeInsets.symmetric(
            vertical: 2,
            horizontal: 2,
          ), // 2. Reduced Card Height ("usa poddk adu")
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: isMyCk ? Border.all(color: Colors.lightGreenAccent, width: 2) : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row: Car + Global Bet
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Optimized Car Size ("pixel error solve")
                      Image.asset(
                        car['image'],
                        width: 62,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 2), // Minimizing gap
                      // Full Number
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '💎',
                            style: TextStyle(fontSize: 7, color: Colors.black54),
                          ),
                          Text(
                            '$totalBets',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isMyCk) ...[
                    const Divider(height: 2, thickness: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '💎',
                          style: TextStyle(fontSize: 8, color: Colors.orange),
                        ),
                        Text(
                          '$_betAmount',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // No spacer ("usa adu karanna")
                    const Text(
                      '-',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ],
              ),
              // Green Checkmark Badge overlay
              if (isMyCk)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.lightGreenAccent, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check, color: Colors.lightGreenAccent, size: 10),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCommonTopPanel(RacingGameState state) {
    // Robust environment selection
    final envIndex =
        (_currentEnvIndex >= 0 && _currentEnvIndex < _environments.length)
        ? _currentEnvIndex
        : 0;
    final env = _environments[envIndex];

    // Check for null list to prevent "Null cast" error
    final List<Color> headerColors =
        (env['header_colors'] as List?)?.cast<Color>() ??
        [const Color(0xFF1A1A1A), const Color(0xFF2C3E50)];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: headerColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ),
      ),
      child: Column(
        children: [_buildGlobalStatsPill(state), _buildRacerSummaries(state)],
      ),
    );
  }

  // --- SHARED TRACK BACKGROUND --- (Grey Road, Start/Finish Lines, Borders)
  Widget _buildTrackBackground() {
    final envIndex =
        (_currentEnvIndex >= 0 && _currentEnvIndex < _environments.length)
        ? _currentEnvIndex
        : 0;
    final env = _environments[envIndex];

    final surfaceColor = env['surface'] as Color? ?? Colors.grey.shade300;
    final trackImage = env['track_image'] as String?;
    final curb1 = env['curb_1'] as Color? ?? Colors.red;

    return Stack(
      children: [
        // 1. DYNAMIC REALISTIC TRACK IMAGE (Doubled for 6 lanes)
        Positioned.fill(
          child: trackImage != null
              ? Column(
                  children: [
                    Expanded(child: Image.asset(trackImage, fit: BoxFit.fill)),
                    Expanded(child: Image.asset(trackImage, fit: BoxFit.fill)),
                  ],
                )
              : Container(color: surfaceColor),
        ),

        // 2. OVERLAY START LINE (Keep procedural for consistent positioning)
        Positioned(
          left: 15,
          top: 0,
          bottom: 0,
          width: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: List.generate(
                20,
                (i) => Expanded(
                  child: Container(
                    color: i.isEven ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 37,
          top: 0,
          bottom: 0,
          width: 4,
          child: Container(color: curb1.withValues(alpha: 0.8)),
        ),

        // 3. FINISH LINE (Keep procedural for consistent positioning)
        Positioned(
          right: 15,
          top: 0,
          bottom: 0,
          width: 30,
          child: Column(
            children: List.generate(
              20,
              (i) => Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        color: i.isEven ? Colors.black87 : Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: i.isOdd ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          width: 5,
          child: Container(color: curb1.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  Widget _buildF1CountdownView(RacingGameState state) {
    // 5-LAYER STRUCTURE
    return Column(
      children: [
        // LAYER 2: Shared Top Panel
        _buildCommonTopPanel(state),

        // LAYER 4: Banner & Lights
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              // Banner
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  width: double.infinity, // Force full width
                  child: Image.asset(
                    'assets/images/vehical_images/banner_1.png',
                    fit:
                        BoxFit.cover, // Fill the width ("sampurna palal ganna")
                  ),
                ),
              ),
              // Lights (Positioned ON TOP of the banner)
              Positioned(
                top:
                    0, // 3. Aligned with Banner Top ("bulbs top border eka matha eka")
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildF1Bulb(1),
                        const SizedBox(width: 8),
                        _buildF1Bulb(2),
                        const SizedBox(width: 8),
                        _buildF1Bulb(3),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // LAYER 5: Tracks (Bottom)
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              _buildTrackBackground(),
              // Show aligned cars during countdown
              Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Expanded(flex: 2, child: SizedBox()), // Top Spacer
                        ...List.generate(_activeRacers.length * 2 - 1, (i) {
                          if (i.isEven) {
                            // LANE (Static Car - _carProgress is 0.0)
                            int laneIndex = i ~/ 2;
                            return _buildLane(laneIndex, []);
                          } else {
                            // INVISIBLE DIVIDER
                            return const Expanded(flex: 1, child: SizedBox());
                          }
                        }),
                        const Expanded(flex: 2, child: SizedBox()), // Bottom Spacer
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildF1Bulb(int bulbIndex) {
    // Logic:
    // State 1: 1=Red
    // State 2: 1=Red, 2=Red
    // State 3: 1=Red, 2=Red, 3=Red
    // State 4: All Green

    Color color = Colors.black45; // Off
    bool isGlow = false;

    if (_lightState == 4) {
      color = Colors.greenAccent; // GO!
      isGlow = true;
    } else {
      if (bulbIndex <= _lightState) {
        color = Colors.redAccent; // Countdown Red
        isGlow = true;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 28,
      height: 28, // 4. Bigger Bulbs ("bulbs thwa chuttak loku")
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade800, width: 3),
        boxShadow: isGlow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
    );
  }

  // Helper: Just the lane container for the car
  Widget _buildLane(int index, List<Color> ignoredColors) {
    return Expanded(
      flex: 10, // EXTREME WIDTH: From 6 to 10 for a very 'wide' track view
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final laneWidth = constraints.maxWidth;
          final laneHeight = constraints.maxHeight;
          final carSize = 150.0; // Reduced size for better mobile fit

          // --- VISIBLE START POSITION (Car fully visible, crossing line) ---
          // Car starts at 0.0. Nose is at 150.0.
          // Start Line is at 60.0. Car is AHEAD of line.
          double startX = 0.0;
          // Target: Drive fully OFF SCREEN to the right
          double maxLeft = laneWidth;
          double dist = maxLeft - startX;

          // Calculate Position
          double xPos =
              startX +
              (_activeRacers.length > index
                  ? (_carProgress.length > index ? _carProgress[index] : 0.0) *
                        dist
                  : 0.0);

          if (_activeRacers[index]['id'] == 'bike_red') {
            // Adjust for bike if needed
            // xPos -= 20.0;
          }

          final car = _activeRacers[index];

          return Container(
            color: Colors.transparent, // Transparent Lane
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                // (Redundant Start/Finish lines removed - now in Background)

                // CAR
                Positioned(
                  left: xPos,
                  top:
                      -laneHeight * 0.1, // Slight vertical centering adjustment
                  child: Container(
                    width: carSize,
                    height: laneHeight * 1.2,
                    padding: const EdgeInsets.only(
                      bottom: 10,
                    ), // Shadow spacing
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      car['top_image'] ?? car['image'],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRaceView(RacingGameState state) {
    return Column(
      children: [
        // Idenitcal Header to Screen 2
        _buildCommonTopPanel(state),

        // BANNER (Replaced with Video)
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              Positioned.fill(
                child:
                    _bannerVideoController != null &&
                        _bannerVideoController!.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _bannerVideoController!.value.size.width,
                          height: _bannerVideoController!.value.size.height,
                          child: VideoPlayer(_bannerVideoController!),
                        ),
                      )
                    : Image.asset(
                        'assets/images/vehical_images/banner_1.png',
                        fit: BoxFit.cover,
                      ),
              ),
              // Note: Lights not explicitly requested here, just the banner image.
            ],
          ),
        ),

        // The actual track (Bottom Section)
        Expanded(flex: 5, child: _buildTrack()),
      ],
    );
  }

  Widget _buildIntroView() {
    return Stack(
      children: [
        // Background Video comes from Global build()

        // Content
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TURBO RACING',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
              Image.asset(
                'assets/images/vehical_images/banner_1.png',
                height: 100,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _showIntro = false;
                    _startBettingPhase();
                  });
                },
                child: const Text(
                  'START ENGINE',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- NEW UI COMPONENTS (2025 Overhaul) ---

  Widget _buildBettingTabs() {
    return Container(
      height: 24, // Reduced from 30
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_autoRunning) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stop Auto-Bet first!')),
                  );
                  return;
                }
                setState(() => _isAutoMode = false);
              },
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'MANUAL',
                      style: TextStyle(
                        color: !_isAutoMode ? Colors.amber : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10, // Reduced from 12
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: 2,
                      width: 30, // Reduced from 40
                      decoration: BoxDecoration(
                        color: !_isAutoMode ? Colors.amber : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 20, color: Colors.white12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAutoMode = true),
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'AUTO',
                      style: TextStyle(
                        color: _isAutoMode ? Colors.amber : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10, // Reduced from 12
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: 2,
                      width: 30, // Reduced from 40
                      decoration: BoxDecoration(
                        color: _isAutoMode ? Colors.amber : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Bet',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                      onPressed: _autoRunning
                          ? null
                          : () => setState(() {
                              if (_betAmount > 10) _betAmount -= 10;
                              debugPrint(
                                '${_ts()} 💰 BET_AMOUNT CHANGE source=auto-controls-minus value=$_betAmount',
                              );
                            }),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Text('💎', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            '$_betAmount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.greenAccent,
                        size: 24,
                      ),
                      onPressed: _autoRunning
                          ? null
                          : () => setState(() {
                              _betAmount += 10;
                              debugPrint(
                                '${_ts()} 💰 BET_AMOUNT CHANGE source=auto-controls-plus value=$_betAmount',
                              );
                            }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rounds',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Wrap(
                spacing: 4,
                children: [0, 5, 10, 25].map((r) {
                  final isSelected = _autoRoundsTotal == r;
                  return GestureDetector(
                    onTap: _autoRunning
                        ? null
                        : () => setState(() => _autoRoundsTotal = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amber : Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? Colors.amberAccent
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        r == 0 ? '∞' : '$r',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stop if lose',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              SizedBox(
                height: 24,
                child: DropdownButton<int>(
                  value: _stopAfterLosses,
                  dropdownColor: const Color(0xFF2C2C3E),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                  items: [0, 3, 5, 10]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e == 0 ? 'Never' : '$e in a row'),
                        ),
                      )
                      .toList(),
                  onChanged: _autoRunning
                      ? null
                      : (v) => setState(() => _stopAfterLosses = v ?? 0),
                  underline: const SizedBox(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          GestureDetector(
            onTap: () {
              if (_selectedCarIndex == -1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Select a car first!')),
                );
                return;
              }
              setState(() {
                _autoRunning = !_autoRunning;
                if (_autoRunning) {
                  _autoRoundsPlayed = 0;
                  // _consecutiveLosses = 0;
                  // If we are currently in betting phase, place bet immediately
                  // Otherwise it will place on next _startBettingPhase via state change
                  _placeBet();
                }
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _autoRunning
                      ? [Colors.redAccent, Colors.red] // Stop color
                      : [
                          const Color(0xFF00C6FF),
                          const Color(0xFF0072FF),
                        ], // Start color
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (_autoRunning ? Colors.red : Colors.blue).withValues(
                      alpha: 0.4,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _autoRunning ? 'STOP AUTO' : 'START AUTO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                  if (_autoRunning && _autoRoundsTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$_autoRoundsPlayed/$_autoRoundsTotal',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView(RacingGameState state) {
    return Container(
      color: const Color(0xFF1E1E2C),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              'Syncing with Race Control...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Round: ${state.roundId}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: 12,
      ), // Reduced vertical padding
      decoration: const BoxDecoration(
        // Reduced "Too Orange" -> Dark Premium Background with Top Border
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. REFINED ADJUSTMENT CONTROLS ("Depaththe kali wenas widiyata")
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the group
              children: [
                // MINUS BUTTON (Circular, Glossy Green)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_betAmount > 10) _betAmount -= 10;
                      debugPrint(
                        '${_ts()} 💰 BET_AMOUNT CHANGE source=chip-minus value=$_betAmount',
                      );
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32, // Reduced from 40
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF66BB6A),
                          Color(0xFF2E7D32),
                        ], // Light to Dark Green
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                        const BoxShadow(
                          color: Colors.black45,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Colors.white,
                      size: 20,
                    ), // Reduced size
                  ),
                ),

                // CENTER DISPLAY (Glass/Dark Panel)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 32, // Reduced from 40
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(
                          '$_betAmount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15, // Reduced from 18
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // PLUS BUTTON (Circular, Glossy Green)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _betAmount += 10;
                      debugPrint(
                        '${_ts()} 💰 BET_AMOUNT CHANGE source=chip-plus value=$_betAmount',
                      );
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32, // Reduced from 40
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                        const BoxShadow(
                          color: Colors.black45,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ), // Reduced size
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // 2. PLAY BUTTON (Metallic)
          GestureDetector(
            onTap: _placeBet,
            child: Container(
              height: 32,
              width: 80, // Reduced from 44x100
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    offset: const Offset(0, -1),
                    blurRadius: 1,
                  ),
                  const BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'PLAY',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1, // Reduced from 18
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        offset: Offset(0, 1),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WOW FACTOR: COIN RAIN OVERLAY ---

class RacingWinOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const RacingWinOverlay({super.key, required this.onComplete});

  @override
  State<RacingWinOverlay> createState() => _RacingWinOverlayState();
}

class _RacingWinOverlayState extends State<RacingWinOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_CoinParticle> _particles = List.generate(
    40,
    (_) => _CoinParticle(),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _particles
              .map((p) {
                final progress = _controller.value;
                final y =
                    p.startY +
                    (MediaQuery.of(context).size.height + 100) *
                        progress *
                        p.speed;
                final x = p.startX + sin(progress * 10 + p.offset) * 20;

                return Positioned(
                  top: y,
                  left: x,
                  child: Opacity(
                    opacity: 1.0 - (progress > 0.8 ? (progress - 0.8) * 5 : 0),
                    child: Transform.rotate(
                      angle: progress * p.rotationSpeed,
                      child: const Text('💎', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              })
              .toList()
              .cast<Widget>(),
        );
      },
    );
  }
}

class _CoinParticle {
  final double startX = Random().nextDouble() * 400;
  final double startY = -100 - (Random().nextDouble() * 500);
  final double speed = 0.8 + Random().nextDouble() * 0.7;
  final double rotationSpeed = (Random().nextDouble() - 0.5) * 10;
  final double offset = Random().nextDouble() * 10;
}

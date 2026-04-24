import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/aviator_game_service.dart';
import '../widgets/live/top_up_sheet.dart';

class AviatorGameWidget extends StatefulWidget {
  final VoidCallback? onClose;

  const AviatorGameWidget({
    super.key,
    this.onClose,
  });

  @override
  State<AviatorGameWidget> createState() => _AviatorGameWidgetState();
}

class _AviatorGameWidgetState extends State<AviatorGameWidget> with TickerProviderStateMixin {
  final AviatorGameService _service = AviatorGameService();
  late AnimationController _bgController;
  AnimationController? _swayController; 

  // Audio Players
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  
  // UI State
  int _selectedControlTab = 0; // 0: Bet, 1: Auto
  final TextEditingController _betInputController = TextEditingController(text: "100");
  final TextEditingController _autoCashoutInputController = TextEditingController(text: "2.00");
  
  // State Tracking for Audio
  AviatorPhase _lastPhase = AviatorPhase.betting;

  // Parallax Scroll Offsets (Restored)
  // Parallax Scroll Offsets (Lower Memory)
  final ValueNotifier<double> _skyScrollNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _runwayScrollNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    debugPrint('[AVIATOR UI] 🎬 initState: Game starting...');
    // Background Scroller
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), 
    )..repeat();
    
    // Plane Swaying
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    )..repeat(reverse: true); 
    
    _bgController.addListener(_updateParallax);
    
    _service.addListener(_handleAudioState);
    _initAudio();
    
    // 🎁 AUTO-GIFT REMOVED (User requested real balance only)
  }
  
  void _updateParallax() {
    if (_service.phase == AviatorPhase.flying) {
      // Speed multiplier increases with game multiplier
      double speed = _service.currentMultiplier; 
      if (speed > 5) speed = 5; // Cap visual speed
      
      _skyScrollNotifier.value = (_skyScrollNotifier.value + 0.001 * speed) % 1.0;
      _runwayScrollNotifier.value = (_runwayScrollNotifier.value + 0.01 * speed) % 1.0;
    }
  }

  void _initAudio() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    // TODO: Add 'aviator_bgm.mp3' to assets
    // await _bgmPlayer.play(AssetSource('audio/aviator_bgm.mp3'), volume: 0.3);
  }

  void _handleAudioState() async {
    if (_service.phase != _lastPhase) {
      if (_service.phase == AviatorPhase.flying) {
        // Engine Start
        try {
           await _sfxPlayer.play(AssetSource('audio/aviator_engine.mp3')); 
        } catch (e) { /* debugPrint("Audio Error: $e"); */ }
      } else if (_service.phase == AviatorPhase.crashed) {
        // Crash Sound
        try {
           await _sfxPlayer.play(AssetSource('audio/aviator_crash.mp3'));
        } catch (e) { /* debugPrint("Audio Error: $e"); */ }
      }
      _lastPhase = _service.phase;
    }
    
    // Win Sound (Check if just cashed out)
    if (_service.hasCashedOut && _service.phase == AviatorPhase.flying) {
       // Debounce or check flags if needed, but simple check is okay
    }
  }

  @override
  void dispose() {
    debugPrint('[AVIATOR UI] 🛑 dispose: Widget destroyed.');
    _bgController.dispose();
    _swayController?.dispose();
    _service.removeListener(_handleAudioState);
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, child) {
        // Log rebuild for performance audit
        // debugPrint('[AVIATOR UI] 🔄 ListenableBuilder Rebuild: Phase=${_service.phase.name}');
        
        return ClipRect(
          child: Container(
            color: const Color(0xFF0F0F1E),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildImmersiveGameCanvas()),
                      if (_service.isHost) _buildViewerBalanceSidebar(),
                    ],
                  ),
                ),
                _buildControls(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical padding
      color: Colors.black45,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Row(
                children: [
                  const SizedBox(width: 8),
                  GestureDetector(
                    child: const Text(
                      'AVIATOR LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16, // Reduced from 18
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: [
                           Shadow(color: Colors.blueAccent, blurRadius: 10),
                           Shadow(color: Colors.purpleAccent, blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showRulesDialog(context),
                    child: const Icon(Icons.help_outline, color: Colors.white54, size: 20), // Smaller icon
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                       showModalBottomSheet(
                         context: context,
                         isScrollControlled: true,
                         backgroundColor: Colors.transparent,
                         builder: (context) => TopUpSheet(currentDiamonds: _service.balance),
                       );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        children: [
                          const Text('💎', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            "${_service.balance}",
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.onClose != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: const Icon(Icons.close, color: Colors.white54, size: 22),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 4), // Reduced from 8
          // History Bubbles
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _service.history.take(10).map((val) {
                final isCrash = val < 2.0;
                return Container(
                  margin: const EdgeInsets.only(right: 4), // Reduced margin
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Compact padding
                  decoration: BoxDecoration(
                    color: isCrash ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8), // Smaller radius
                    border: Border.all(
                      color: isCrash ? Colors.redAccent : Colors.greenAccent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${val.toStringAsFixed(2)}x',
                    style: TextStyle(
                      color: isCrash ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 9, // Reduced font
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmersiveGameCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            // 1. SKY Parallax Layer
            ValueListenableBuilder<double>(
              valueListenable: _skyScrollNotifier,
              builder: (context, scroll, child) {
                return _buildParallaxImage('assets/images/games/aviator_bg.png', scroll);
              },
            ),
            
            // 2. RUNWAY Dotted Lines
            ValueListenableBuilder<double>(
              valueListenable: _runwayScrollNotifier,
              builder: (context, scroll, child) {
                 return _buildRunwayLines(scroll); 
              },
            ),
            
            // 3. Grid (Make it subtle/techy)
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(opacity: 0.1),
            ),

            // 4. Flight Curve (The Red Thread)
            if (_service.phase == AviatorPhase.flying || _service.phase == AviatorPhase.crashed)
              ValueListenableBuilder<double>(
                valueListenable: _service.multiplierNotifier,
                builder: (context, multiplier, child) {
                  return RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _FlightPathPainter(
                        multiplier: multiplier,
                        isCrashed: _service.phase == AviatorPhase.crashed,
                      ),
                    ),
                  );
                },
              ),
              
            // 5. THE CUTE PLANE (Widget Layer)
            if (_service.phase == AviatorPhase.flying)
               ValueListenableBuilder<double>(
                 valueListenable: _service.multiplierNotifier,
                 builder: (context, multiplier, child) {
                   if (multiplier <= 1.0) return const SizedBox.shrink();
                   return _buildPlaneWidget(w, h, multiplier);
                 },
               ),

            // 6. EXPLOSION ANIMATION (On Crash)
            if (_service.phase == AviatorPhase.crashed)
               _buildExplosionWidget(w, h),

            // 7. Central Multiplier Text Overlay
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_service.phase == AviatorPhase.betting) ...[
                      const Text(
                        'TAKING OFF IN',
                        style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2),
                      ),
                      Text(
                        '${_service.timerSeconds}',
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.orangeAccent, blurRadius: 20)],
                        ),
                      ),
                    ] else if (_service.phase == AviatorPhase.flying) ...[
                       ValueListenableBuilder<double>(
                         valueListenable: _service.multiplierNotifier,
                         builder: (context, multiplier, child) {
                           return Text(
                            '${multiplier.toStringAsFixed(2)}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Colors.blueAccent, blurRadius: 30),
                                Shadow(color: Colors.purpleAccent, blurRadius: 60),
                              ],
                            ),
                          );
                         },
                       ),
                    ] else if (_service.phase == AviatorPhase.crashed) ...[
                      Text(
                        'FLEW AWAY!',
                        style: TextStyle(
                          color: Colors.red[300],
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [const Shadow(color: Colors.red, blurRadius: 15)],
                        ),
                      ),
                      Text(
                        '${_service.currentMultiplier.toStringAsFixed(2)}x',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewerBalanceSidebar() {
    return Positioned(
      top: 10,
      right: 10,
      width: 140,
      height: 200,
      child: RepaintBoundary(
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: _service.viewerBalancesNotifier,
          builder: (context, viewers, child) {
            if (viewers.isEmpty) return const SizedBox.shrink();
            
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'VIEWERS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: viewers.length,
                      itemBuilder: (context, index) {
                        final viewer = viewers[index];
                        final name = viewer['name'] ?? 'User';
                        final photo = viewer['photo'] ?? '';
                        final diamonds = viewer['diamonds'] ?? 0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                child: photo.isEmpty ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        const Text('💎', style: TextStyle(fontSize: 8)),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$diamonds',
                                          style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaneWidget(double w, double h, double multiplier) {
     double progress = (multiplier - 1.0) / 10.0;
     if (progress > 1.0) progress = 1.0;
     
     final double endX = w * 0.8 * progress;
     // Adjusted to reach top (Y=40, radius 40)
     final double endY = (h - 20) - ((h - 60) * progress);
     
     // Helicopter Tilt (Nose down when flying fast) - Reduced for Plane
     double angleDeg = 5.0 + (progress * 10); 
     
     // Lazy Initialization for Hot Reload Support
     _swayController ??= AnimationController(
          vsync: this,
          duration: const Duration(seconds: 2),
       )..repeat(reverse: true);

     return AnimatedBuilder(
       animation: _swayController!,
       builder: (context, child) {
         // Sway Calculation: Sine wave between -5 and +5
         final double swayOffset = sin(_swayController!.value * 2 * pi) * 5.0;
         
         return Positioned(
           left: endX - 40, // Centered (80/2)
           top: (endY - 40) + swayOffset, // Add Sway
           width: 80, 
           height: 80, 
           child: Transform.rotate(
             angle: angleDeg * pi / 180,
             child: Image.asset(
               'assets/images/games/helicopter.png', // Switched strictly to User's Path
               fit: BoxFit.contain,
             ),
           ),
         );
       },
     );
  }

  Widget _buildExplosionWidget(double w, double h) {
     double progress = (_service.currentMultiplier - 1.0) / 10.0;
     if (progress > 1.0) progress = 1.0;
     
     final double endX = w * 0.8 * progress;
     // Adjusted to reach top
     final double endY = (h - 20) - ((h - 60) * progress);
     
     return Positioned(
       left: endX - 60, // Center 120px explosion (120/2)
       top: endY - 60, 
       width: 120,  // Increased to 120
       height: 120, // Increased to 120
       child: TweenAnimationBuilder<double>(
         tween: Tween(begin: 0.0, end: 1.0),
         duration: const Duration(milliseconds: 1000), // 1.0 Second
         curve: Curves.elasticOut,
         builder: (context, val, child) {
           return Transform.scale(
             scale: val,
             child: Image.asset('assets/images/games/aviator_explosion.png'),
           );
         },
       ),
     );
  }
  
  Widget _buildParallaxImage(String asset, double scrollX) {
     return Stack(
       children: [
         // Image 1
         Positioned(
           left: -scrollX * MediaQuery.of(context).size.width,
           top: 0,
           bottom: 0,
           width: MediaQuery.of(context).size.width * 2, // Double width for seamless loop? Or just 2 images
           child: Image.asset(asset, fit: BoxFit.cover),
         ),
         // Image 2 (Clone to loop)
         Positioned(
           left: (1.0 - scrollX) * MediaQuery.of(context).size.width,
            top: 0,
           bottom: 0,
           width: MediaQuery.of(context).size.width,
           child: Image.asset(asset, fit: BoxFit.cover),
         ),
       ],
     );
  }

  Widget _buildControls() {
    final bool canBet = _service.phase == AviatorPhase.betting && _service.myBetAmount == 0;
    final bool canCashOut = _service.phase == AviatorPhase.flying && _service.myBetAmount > 0 && !_service.hasCashedOut;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical padding from 16 to 8
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.95), // Darker, more solid
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          const BoxShadow(color: Colors.black, blurRadius: 20, offset: Offset(0, -5))
        ],
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Status Message (Win/Loss/Waiting)
              if (_service.hasCashedOut)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   margin: const EdgeInsets.only(bottom: 12),
                   decoration: BoxDecoration(
                     color: Colors.greenAccent.withValues(alpha: 0.1),
                     borderRadius: BorderRadius.circular(20),
                     border: Border.all(color: Colors.greenAccent),
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                       const SizedBox(width: 8),
                       Text(
                         'YOU WON: ${(_service.myBetAmount * _service.cashedOutAt).floor()} DIAMONDS',
                         style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                       ),
                     ],
                   ),
                 )
               else if (_service.balance < 10)
                 // LOW BALANCE WARNING (Removed Claim Button)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   margin: const EdgeInsets.only(bottom: 12),
                   decoration: BoxDecoration(
                     color: Colors.redAccent.withValues(alpha: 0.1),
                     borderRadius: BorderRadius.circular(20),
                     border: Border.all(color: Colors.redAccent),
                   ),
                   child: const Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.warning_amber, color: Colors.redAccent, size: 20),
                       SizedBox(width: 8),
                       Text(
                         'LOW BALANCE',
                         style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                       ),
                     ],
                   ),
                 ),

          // 2. Control Tabs (Bet / Auto)
          Container(
            height: 32, // Reduced from 40
            margin: const EdgeInsets.only(bottom: 8), // Reduced from 16
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildTabButton("Bet", 0),
                _buildTabButton("Auto", 1),
                _buildTabButton("History", 2),
              ],
            ),
          ),

          // 3. Content Area
          if (_selectedControlTab == 0)
            _buildManualBetControls(canBet, canCashOut)
          else if (_selectedControlTab == 1)
            _buildAutoControls()
          else
             _buildHistoryList(),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final bool isSelected = _selectedControlTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedControlTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2C2C3E) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5)) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualBetControls(bool canBet, bool canCashOut) {
    return Column(
      children: [
        // Presets (Always visible, dims when disabled)
        Opacity(
          opacity: canBet ? 1.0 : 0.5,
          child: Container(
            height: 32, // Reduced height from 36
            margin: const EdgeInsets.only(bottom: 8), // Reduced bottom margin
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [100, 200, 500, 1000, 5000].map((amt) {
                return GestureDetector(
                  onTap: () {
                     // Allow setting amount even if not betting yet (for next round preparation logic if we had it, but here just UI)
                     if (canBet) {
                       _betInputController.text = amt.toString();
                       _service.placeBet(amt);
                     }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12), // Reduced padding
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18), // More pill-like
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      amt.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Input + Action Button
        Row(
          children: [
            // Bet Input (White Background, Black Text as requested)
            Expanded(
              flex: 1,
              child: Container(
                height: 40, // Reduced from 48
                decoration: BoxDecoration(
                  color: Colors.white, // White background
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _betInputController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16), // Reduced Font
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.black26),
                          contentPadding: EdgeInsets.only(bottom: 8) // Adjusted alignment
                        ),
                      ),
                    ),
                    // Diamond icon
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: const Text('💎', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Action Button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  if (canBet) {
                    final int? amt = int.tryParse(_betInputController.text);
                    debugPrint('[AVIATOR UI] 👆 Bet Button Tapped: Amount=$amt');
                    if (amt != null && amt > 0) {
                      _service.placeBet(amt);
                    }
                  } else if (canCashOut) {
                    debugPrint('[AVIATOR UI] 👆 Cash Out Button Tapped: Multiplier=${_service.currentMultiplier}');
                    _service.cashOut();
                  }
                },
                child: Container(
                  height: 40, // Reduced from 48
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: canCashOut 
                        ? [const Color(0xFFFF9800), const Color(0xFFFF5722)] // Orange
                        : canBet 
                          ? [const Color(0xFF00E676), const Color(0xFF00C853)] // Green
                          : [Colors.grey.shade700, Colors.grey.shade800],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (canCashOut || canBet)
                        BoxShadow(
                          color: (canCashOut ? Colors.orange : Colors.green).withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        canCashOut ? 'CASH OUT' : (canBet ? 'BET' : 'WAITING...'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5), // Reduced Font
                      ),
                      if (canCashOut)
                         Text(
                          '${(_service.myBetAmount * _service.currentMultiplier).floor()} DIAMONDS',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                         ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoControls() {
    return Column(
      children: [
        // Auto Bet Switch
        Container(
          height: 40, // Reduced height from 48
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Auto Bet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), // Reduced Font
              Switch(
                value: _service.autoBetEnabled,
                onChanged: (val) {
                  _service.setAutoBet(val);
                },
                activeThumbColor: Colors.greenAccent,
                activeTrackColor: Colors.green.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8), 
        // Auto Cashout
        Container(
          height: 40, // Reduced height from 48
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text('Auto Cashout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), // Reduced Font
              ),
              // Input (White bg, Black text)
              Container(
                width: 60, // Reduced width
                height: 30, // Reduced height
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white, // White background
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _autoCashoutInputController,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13), // Reduced Font
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          final double? d = double.tryParse(val);
                          // Only set if valid and > 1
                          if (d != null && d > 1.0) {
                            if (_service.autoCashoutMultiplier != null) {
                               _service.setAutoCashout(d);
                            }
                          }
                        },
                      ),
                    ),
                    const Text('x', style: TextStyle(color: Colors.black54, fontSize: 11)), // Dark 'x'
                  ],
                ),
              ),
              // Toggle
              Switch(
                value: _service.autoCashoutMultiplier != null,
                onChanged: (val) {
                  if (val) {
                    // Enable with current text value
                    final double? d = double.tryParse(_autoCashoutInputController.text);
                    _service.setAutoCashout(d ?? 2.0);
                  } else {
                    _service.setAutoCashout(null);
                  }
                },
                activeThumbColor: Colors.orangeAccent,
                activeTrackColor: Colors.deepOrange.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildHistoryList() {
    final bets = _service.myBets;
    if (bets.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const Text('No bets yet.', style: TextStyle(color: Colors.white24)),
      );
    }
    
    return SizedBox(
      height: 150,
      child: ListView.builder(
        itemCount: bets.length,
        itemBuilder: (context, index) {
          final bet = bets[index];
          final isWin = bet.winAmount != null && bet.winAmount! > 0;
          final isPending = bet.winAmount == null && bet.cashOutMultiplier == null;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isWin ? Colors.green.withValues(alpha: 0.3) : (isPending ? Colors.yellow.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${bet.amount}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  isPending 
                    ? 'FLYING...'
                    : (isWin ? '${bet.cashOutMultiplier!.toStringAsFixed(2)}x' : 'CRASHED'),
                  style: TextStyle(
                    color: isPending ? Colors.yellowAccent : (isWin ? Colors.greenAccent : Colors.redAccent),
                    fontWeight: FontWeight.bold
                  ),
                ),
                Text(
                  isPending 
                    ? '...'
                    : (isWin ? '+${bet.winAmount}' : '-${bet.amount}'),
                  style: TextStyle(
                     color: isPending ? Colors.white54 : (isWin ? Colors.green : Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("HOW TO PLAY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "1. PLACE YOUR BET\nSelect your bet amount before the round starts.",
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                "2. WATCH THE PLANE\nThe multiplier increases as the plane flies. It can fly away at any time!",
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                "3. CASH OUT\nPress 'CASH OUT' before the plane flies away to win your Bet x Multiplier.",
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 20),
              Text(
                "AUTO PLAY MODES",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "• Auto Bet: Automatically places your bet every round.\n• Auto Cashout: Automatically cashes out when the multiplier reaches your target.",
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 20),
              Text(
                "FAIRNESS",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "This game uses a Provably Fair server seed mechanism to determine the crash point before the round starts.",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("GOT IT", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildRunwayLines(double scroll) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      height: 4,
      child: Stack(
        children: List.generate(20, (i) {
          return Positioned(
            left: ((i * 40) - (scroll * 800)) % 800,
            child: Container(width: 20, height: 2, color: Colors.yellowAccent.withValues(alpha: 0.3)),
          );
        }),
      ),
    );
  }
}

class _FlightPathPainter extends CustomPainter {
  final double multiplier;
  final bool isCrashed;

  _FlightPathPainter({required this.multiplier, required this.isCrashed});

  @override
  void paint(Canvas canvas, Size size) {
    if (multiplier <= 1.0) return;

    final paintRed = Paint()
      ..color = const Color(0xFFFF1744) // Bright Neon Red
      ..strokeWidth = 2.5 // Thinner "Hini Nula"
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2); // Subtle Core blur

    final paintGlow = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.6)
      ..strokeWidth = 8.0 // Outer Glow
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8); // Spread Glow

    final paintFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [const Color(0xFFE50914).withValues(alpha: 0.5), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final double w = size.width;
    final double h = size.height;
    
    // Start slightly off-bottom to clear runway
    path.moveTo(0, h - 20);

    // Calculate progress (Scale effect)
    double progress = (multiplier - 1.0) / 10.0; 
    if (progress > 1.0) progress = 1.0;
    
    // Smooth Quadratic Curve with "Takeoff" steepness
    final double controlX = w * 0.4 * progress;
    final double controlY = h;
    final double endX = w * 0.8 * progress;
    // Adjusted to reach top
    final double endY = (h - 20) - ((h - 60) * progress); // Go up to top margin

    path.quadraticBezierTo(controlX, controlY, endX, endY);
    
    // Fill Area under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(endX, h);
    fillPath.lineTo(0, h);
    canvas.drawPath(fillPath, paintFill);
    
    // Draw Stroke
    // Draw Glow
    canvas.drawPath(path, paintGlow);
    // Draw Core Line
    canvas.drawPath(path, paintRed);

    // Plane is now drawn by Widget Layer for better asset quality
  }

  @override
  bool shouldRepaint(covariant _FlightPathPainter oldDelegate) {
    return oldDelegate.multiplier != multiplier || oldDelegate.isCrashed != isCrashed;
  }
}



class _GridPainter extends CustomPainter {
  final double opacity;
  _GridPainter({this.opacity = 0.05});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/dice_game_service.dart';
import 'social_diamond_overlay.dart';
import 'confetti_win_overlay.dart';
import '../widgets/live/top_up_sheet.dart';

class DiceGameWidget extends StatefulWidget {
  final VoidCallback? onClose;

  const DiceGameWidget({super.key, this.onClose});

  @override
  State<DiceGameWidget> createState() => _DiceGameWidgetState();
}

class _DiceGameWidgetState extends State<DiceGameWidget> with TickerProviderStateMixin {
  final DiceGameService _service = DiceGameService();
  final TextEditingController _betController = TextEditingController(text: "100");
  
  bool _isAutoMode = false;
  bool _hasProcessedResult = false;
  
  // Animations
  late AnimationController _rollController;

  @override
  void initState() {
    super.initState();
    debugPrint('[DICE UI] 🎬 initState: Widget created.');
    _rollController = AnimationController(
       vsync: this, 
       duration: const Duration(seconds: 1) // Fast roll
    );

    _service.addListener(_onGameStateChange);
  }
  
  void _onGameStateChange() {
    if (!mounted) return;
    setState(() {});

    if (_service.state == DiceGameState.rolling) {
      _rollController.repeat(); // Spin indefinitely until result
    } else if (_service.state == DiceGameState.result) {
      _rollController.stop();
      _rollController.reset();
      
      if (!_hasProcessedResult) {
         _hasProcessedResult = true;
         debugPrint('[DICE UI] Processing Result Phase UI. Won: ${_service.won}, Bet: ${_service.betAmount}');
         
         if (_service.won) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("🎉 WON ${_service.winnings} Diamonds! (Sum: ${_service.totalSum})"),
                  backgroundColor: Colors.green
                )
             );
         } else if (_service.betAmount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text("❌ LOST! Result was ${_service.totalSum}."),
                 backgroundColor: Colors.red
               )
            );
         }
      }
    } else if (_service.state == DiceGameState.betting) {
        // Reset processed flag for new round
        if (_hasProcessedResult) {
            debugPrint('[DICE UI] Transitioning back to Betting Phase.');
            _hasProcessedResult = false;
        }
    }
    
    debugPrint('[DICE UI] 📥 Sync: Phase=${_service.state.name}, Countdown=${_service.countdown}');
  }

  @override
  void dispose() {
    debugPrint('[DICE UI] 🛑 dispose: Widget destroyed.');
    _service.removeListener(_onGameStateChange);
    _rollController.dispose();
    _betController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, child) {
        return ConfettiWinOverlay(
          showWin: _service.state == DiceGameState.result && _service.won,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  border: const Border(top: BorderSide(color: Colors.white24, width: 0.5)),
                ),
                child: SocialDiamondOverlay(
                  isBettingPhase: _service.state == DiceGameState.betting,
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(child: Center(child: _buildDiceArea())),
                      _buildSelectionGrid(),
                      _buildBettingTabs(),
                      if (_isAutoMode) _buildAutoControls() else _buildControls(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    Color stateColor;
    String stateText;
    if (_service.state == DiceGameState.betting) {
      stateColor = Colors.green;
      stateText = "BET (${_service.countdown}s)";
    } else if (_service.state == DiceGameState.rolling) {
      stateColor = Colors.amber;
      stateText = "ROLLING";
    } else {
      stateColor = Colors.blue;
      stateText = "WIN: ${_service.totalSum}";
    }

    final String hostTag = _service.isHost ? " (HOST)" : "";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.black26,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    "DICE 🎲",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: stateColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: stateColor),
                  ),
                  child: Text(
                    "$stateText$hostTag",
                    style: TextStyle(color: stateColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _service.debugAddDiamonds(1000);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DEBUG: Added 1000 Diamonds')));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: const Text("DEBUG: +1000", style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    color: Colors.amber.withOpacity(0.2),
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
              const SizedBox(width: 8),
              if (widget.onClose != null)
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(Icons.close, color: Colors.white70, size: 20),
                )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDiceArea() {
    return AnimatedBuilder(
      animation: _rollController,
      builder: (context, child) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDie(0),
                  const SizedBox(width: 16),
                  _buildDie(1),
                  const SizedBox(width: 16),
                  _buildDie(2),
                ],
              ),
              const SizedBox(height: 6),
              if (_service.countdown == 0 && _service.state != DiceGameState.result)
                const Text(
                  "SYNCING...",
                  style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2),
                )
              else if (_service.state == DiceGameState.result)
                Text(
                  "TOTAL: ${_service.totalSum}",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                )
              else if (_service.state == DiceGameState.rolling)
                const Text(
                  "ROLLING...",
                  style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
                )
              else
                Text(
                  "PLACE YOUR BET (${_service.countdown}s)",
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDie(int index) {
    int value = (_service.state == DiceGameState.rolling) ? (Random().nextInt(6) + 1) : _service.diceResult[index];
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(2, 2)),
        ],
      ),
      child: Center(child: _getDiceIcon(value)),
    );
  }

  Widget _getDiceIcon(int value) {
    switch (value) {
      case 1: return const Icon(Icons.looks_one, size: 28);
      case 2: return const Icon(Icons.looks_two, size: 28);
      case 3: return const Icon(Icons.looks_3, size: 28);
      case 4: return const Icon(Icons.looks_4, size: 28);
      case 5: return const Icon(Icons.looks_5, size: 28);
      case 6: return const Icon(Icons.looks_6, size: 28);
      default: return const Icon(Icons.help_outline, size: 28);
    }
  }

  Widget _buildSelectionGrid() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: List.generate(8, (index) => Expanded(child: _buildGridItem(index + 3, EdgeInsets.only(right: index < 7 ? 2 : 0, bottom: 2)))),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(8, (index) => Expanded(child: _buildGridItem(index + 11, EdgeInsets.only(right: index < 7 ? 2 : 0)))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(int number, EdgeInsets margin) {
    bool isSelected = number == _service.selectedNumber;
    double payout = _service.getMultiplierFor(number);
    return GestureDetector(
      onTap: () => _service.selectNumber(number),
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [Colors.amber, Colors.orangeAccent], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : const LinearGradient(colors: [Color(0xFF2C2C44), Color(0xFF1B1B29)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 2))] : [],
          border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white12, width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "$number",
                style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "${payout.toInt()}x",
                style: TextStyle(color: isSelected ? Colors.black54 : Colors.white54, fontSize: 8),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBettingTabs() {
    return Container(
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          _buildTab("MANUAL", !_isAutoMode, () => setState(() => _isAutoMode = false)),
          Container(width: 1, height: 20, color: Colors.white12),
          _buildTab("AUTO", _isAutoMode, () => setState(() => _isAutoMode = true)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                style: TextStyle(color: isSelected ? Colors.amber : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                height: 3,
                width: 40,
                decoration: BoxDecoration(color: isSelected ? Colors.amber : Colors.transparent, borderRadius: BorderRadius.circular(2)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: const Color(0xFF1A1A1A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Bet Amount', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: _service.autoBetEnabled ? null : () {
                        int current = int.tryParse(_betController.text) ?? 100;
                        if (current > 50) _betController.text = (current - 50).toString();
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                      child: Text(_betController.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                      onPressed: _service.autoBetEnabled ? null : () {
                        int current = int.tryParse(_betController.text) ?? 100;
                        _betController.text = (current + 50).toString();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              if (_service.selectedNumber == -1) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a number first!')));
                return;
              }
              final bool nextState = !_service.autoBetEnabled;
              int? amt = int.tryParse(_betController.text);
              if (nextState) {
                if (amt != null && _service.balance >= amt) {
                  _service.setAutoBet(true, amt);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Auto-Bet Started!")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient diamonds!")));
                }
              } else {
                _service.setAutoBet(false, 0);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🛑 Auto-Bet Stopped")));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _service.autoBetEnabled ? [Colors.redAccent, Colors.red] : [Colors.blue, Colors.blueAccent]),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _service.autoBetEnabled ? 'STOP AUTO' : 'START AUTO',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildControls() {
    bool isBetting = _service.state == DiceGameState.betting;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFF24243A),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber, width: 2)),
              child: TextField(
                controller: _betController,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: InputBorder.none, hintText: "Bet"),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: isBetting ? () {
                  int? amt = int.tryParse(_betController.text);
                  if (amt != null && _service.balance >= amt) {
                    _service.placeBet(amt);
                  }
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(isBetting ? "PLACE BET" : "WAIT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}

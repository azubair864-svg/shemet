# 🏎️ Car Racing Game - Deep Explanation (Sinhala)

## Game එක එකවරම කොහොමද දිවයි?

### **ස්ටෙপ් 1: Game එක Open වෙන විට (Startup)**

```
App එක game widget create කරන්න
        ↓
_initializeVideo() - Video asset load (Race View සඳහා)
        ↓
_setupNewRace() - 3x cars rand랜덤ව pick කරන්න
        ↓
_uiTimer set කරන්න - Every 1 second UI refresh
        ↓
_gameStream = racingService.gameStateStream - Firestore එකෙන් listening start
        ↓
BUILD: Garage View show වෙන්න (ගිණුම තෝරපු)
```

**මෙතැනින් වඩුන්න:**
- Video playback සඳහා RAM allocated
- Network connection එක wait කරන්න

---

### **ස්ටෙපු 2: User ගිණුම තෝරපු (Vehicle Selection)**

```
User taps car card
        ↓
_handleVehicleSelect(index) function call වෙන්න
        ↓
if (owned == true) {
  - _selectedCarIndex = index  (ගිණුම mark කරන්න selected)
  - _initRacers() call කරන්න (3x racers list update)
  - setState() - UI refresh (ගිණුම borders change)
}

if (owned == false) {
  - _showBuyPopup() - Dialog show කරන්න (100 coins pay කරන්න?)
}
```

**Problem #1 - Missing mounted check ❌**
```dart
// If user closes game while the tap is being processed:
// _handleVehicleSelect() still tries to setState()
// Device throw error: "setState called on disposed widget"
```

---

### **ස්ටෙපු 3: Bet Amount තෝරපු (Betting)**

```
User clicks chip button (10, 50, 100, 500 coins)
        ↓
_betAmount = selectedAmount (state update)
        ↓
IF auto-play enabled:
  - _startAutoBetting() run වෙන්න
  - ELSE: Waiting for user to click "PLACE BET" button
```

---

### **ස්ටෙපු 4: Bet Place කරන්න (CRITICAL - Problems Here!)**

```
User clicks "PLACE BET" button
        ↓
_placeBet() function call වෙන්න (async/await)
        ↓
// ☑️ Check 1: Coins ඇතිද?
if (widget.userCoins < _betAmount) {
  ❌ ERROR_1: BUG! No mounted check
  ScaffoldMessenger.of(context).showSnackBar(...)
      ↓
      If user closes game → context is DISPOSED → CRASH!
}
        ↓
// ☑️ Check 2: Get car ID from source of truth
final selectedCar = _allVehicles[_selectedCarIndex];
final carId = selectedCar['id'];
        ↓
// ☑️ Check 3: Network call (await/async) 🚨 DANGEROUS!
final success = await _racingService.placeBet(carId, _betAmount);
        ↓
        Network delay (200-500ms) ⏳
        User might close game NOW!
        ↓
❌ ERROR_2: BUG! No mounted check AFTER await
if (success) {
  ScaffoldMessenger.of(context).showSnackBar(...)  ← CRASH!
}
        ↓
// ✅ Good: Deduct coins immediately (optimistic UI)
widget.onCoinUpdate(widget.userCoins - _betAmount);
        ↓
setState(() {
  _betCarId = carId;
});
        ↓
// ✅ Good: Stop auto-play if bet fails
if (!success) {
  _autoRunning = false;
}
```

**Firestore එකෙ ගිහින්න (Backend):**
```
RacingGameService.placeBet() function
        ↓
if (user == null) return false;  ← logout check
        ↓
// Firestore check: Game BETTING phase එකතින්ද?
final gameDoc = await _firestore.collection('games').doc('racing').get();
if (gameDoc.data()?['status'] != 'BETTING') {
  return false;  ← Race already started, can't bet
}
        ↓
// ☑️ Backend validation: Coins ඇතිද?
final balance = await _coinService.getCoinBalance(user.uid);
if (balance < amount) {
  return false;  ← Not enough coins
}
        ↓
// ☑️ Deduct coins atomically
bool deducted = await _coinService.deductCoins(
  userId: user.uid,
  amount: amount,
  reason: 'racing_bet'
);
if (!deducted) return false;
        ↓
// ☑️ Write bet to Firestore
final roundId = gameDoc.data()?['current_round_id'];
await _firestore
  .collection('games')
  .doc('racing')
  .collection('rounds')
  .doc(roundId)
  .collection('bets')
  .doc(user.uid)
  .set({
    'user_id': user.uid,
    'car_id': carId,
    'amount': amount,
    'timestamp': FieldValue.serverTimestamp(),
    'status': 'PENDING'
  });
        ↓
return true;  ← Success!
```

---

### **ස්ටෙපු 5: Firestore Stream එකෙන් Update ආවා (Racing Status)**

```
Firestore: games/racing document updated
  status: "BETTING" → "RACING"
  winner_car_id: "sports_red"  ← Predetermined!
        ↓
StreamBuilder එක listen කරන්න (Real-time)
        ↓
_gameStream.listen((state) {
  // ❌ BUG FIX 1 Fixed: Check if state actually changed
  if (state.roundId == _lastHandledRoundId && 
      state.status == _lastHandledStatus) {
    return;  ← Skip duplicate processing
  }
        ↓
  _handleServerState(state) call වෙන්න
})
```

**_handleServerState() එකෙ:**
```
// ☑️ Case 1: Status = RESULT
if (state.status == RacingStatus.result) {
  setState(() { _showingResult = true; });
  
  // 6 seconds වලින් result screen hide කරන්න
  _resultDisplayTimer = Timer(Duration(seconds: 6), () {
    _showingResult = false;
  });
}
        ↓
// ☑️ Case 2: Status = RACING (Race Start!)
else if (state.status == RacingStatus.racing) {
  _startF1Sequence(state.winnerCarId);  ← Countdown lights start
}
```

---

### **ස්ටෙපු 6: F1 Countdown Lights (3 seconds)**

```
_startF1Sequence(winnerId) function
        ↓
// 5 lights sequence:
Light 1 = Red    (1s)
Light 2 = Red    (1s)
Light 3 = Red    (1s)
All Green = GO!  (0.5s)
        ↓
_isF1Countdown = true;
setState(() { viewIndex = 1; });  ← UI switches to Countdown View
        ↓
// UI shows: F1 lights blinking + track view + cars aligned
// Video starts playing
```

---

### **ස්ටෙපු 7: Race Animation (8-10 seconds)**

```
Green light triggered
        ↓
_startRaceAnimation(winnerId) function
        ↓
// ☑️ Generate random speeds for 3 cars
_carSpeeds = [
  0.45 (car 1),
  0.62 (car 2),
  0.58 (car 3)  ← This one wins!
];

❌ PROBLEM #2: Winner predetermined on Firestore
                 but local animation uses random speeds
                 Result might NOT match!
        ↓
// Animation loop: 8 seconds duration
Timer.periodic(Duration(milliseconds: 30), (timer) {
  // Update _carProgress from 0.0 → 1.0
  _carProgress[0] += _carSpeeds[0] * 0.03;
  _carProgress[1] += _carSpeeds[1] * 0.03;
  _carProgress[2] += _carSpeeds[2] * 0.03;
  
  setState(() {});  ← Rebuild every frame (60 FPS)
})
        ↓
// Animation complete!
_isAnimatingRace = false;
```

**UI දිස්සු වෙන්න:**
```
Cars move left → right on track
Video banner plays
Background music (optional)
Road type shown (Asphalt/Sand/Ice)
```

---

### **ස්ටෙපු 8: Result Screen (6 seconds)**

```
Race complete!
        ↓
// ☑️ Determine winner
final winner = state.winnerCarId;  ← From Firestore (sports_red)
final localWin = (_betCarId == winner['id']);
        ↓
IF localWin {
  // Calculate winnings
  final winAmount = (_betAmount * (betCar['odds'] ?? 2)).toInt();
  
  ❌ PROBLEM #3: No mounted check!
  widget.onCoinUpdate(widget.userCoins + winAmount + _betAmount);
         ↓
         If user closes → CRASH!
         
  Show trophy animation ✅
  Play coin rain animation ✅
  Show "+100 coins" message ✅
}
ELSE {
  Show "Better luck next time" message
}
        ↓
// 6 seconds display කරන්න
Timer(Duration(seconds: 6), () {
  _showingResult = false;  ← Hide result
  _resetRace();             ← Return to garage
});
```

---

### **ස්ටෙපු 9: Back to Garage (Reset)**

```
_resetRace() function
        ↓
// Cancel all timers
_animTimer?.cancel();
_countdownTimer?.cancel();
        ↓
setState(() {
  _isAnimatingRace = false;
  _isF1Countdown = false;
  _lightState = 0;
  _carProgress = [0.0, 0.0, 0.0];  ← Reset positions
  _betCarId = null;
  _selectedCarIndex = -1;
  _hasProcessedResult = false;
  _initRacers();  ← Pick new 3 random cars
});
        ↓
UI returns to Garage View
User can place new bet!
```

---

## Problems Summary 🔴

### **Problem #1: BuildContext After Async**
```
❌ LOCATIONS:
  Line 419: ScaffoldMessenger.of(context).showSnackBar(...);
  Line 421: ScaffoldMessenger.of(context).showSnackBar(...);

❌ WHAT HAPPENS:
  1. User clicks "PLACE BET"
  2. await _racingService.placeBet(...) ← Network delay
  3. User closes game DURING wait
  4. Widget disposed, context invalid
  5. Code returns from await, tries to use context
  6. Flutter throws: "Looking up a deactivated widget's ancestor"
  
❌ RESULT: Game crashes!

✅ FIX:
  if (success) {
    if (!mounted) return;  ← Check first!
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
```

---

### **Problem #2: Race Winner Mismatch**
```
❌ WHAT HAPPENS:
  1. Firestore predetermined winner: "sports_red"
  2. Frontend generates random speeds locally
  3. Local animation winner: "bike_blue" (fastest in random)
  4. Result screen shows: "sports_red" (from Firestore)
  
❌ RESULT: User sees bike_blue cross finish line,
           then screen says sports_red won!
           
✅ PROPER FIX:
  Option A: Backend provides winner BEFORE animation
  Option B: Animation just visualizes predetermined winner
  Option C: Backend calculates winner, frontend uses that
```

---

### **Problem #3: Deprecated withOpacity()**
```
❌ 10+ LOCATIONS:
  Colors.white.withOpacity(0.5)
  
❌ WHAT HAPPENS:
  - Compiler warning: "deprecated member use"
  - No runtime error (still works)
  - Future Dart versions: might break
  
✅ FIX:
  Colors.white.withValues(alpha: 0.5)
```

---

### **Problem #4: No Timeout Handling**
```
❌ WHAT HAPPENS:
  1. User places bet
  2. Network slow (5G, WiFi disconnected, etc.)
  3. await _racingService.placeBet() never returns
  4. Game stuck in loading state
  5. No error message
  6. Auto-play keeps trying forever

❌ RESULT: Dead game (needs force close)

✅ FIX:
  final success = await _racingService.placeBet(carId, _betAmount)
    .timeout(
      Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Bet failed')
    );
```

---

### **Problem #5: Null Cast Safety**
```
❌ LINE 1364:
  final List<Color> headerColors = 
    (env['header_colors'] as List<Color>?) ?? [Color(...), Color(...)];

❌ WHAT HAPPENS:
  If env['header_colors'] is List<int> instead of List<Color>
  Cast fails but goes to fallback (might hide real issue)

✅ BETTER FIX:
  final List<Color> headerColors = 
    (env['header_colors'] as List?)?.cast<Color>() ?? [Color(...), Color(...)];
```

---

## Complete Flow Diagram

```
┌─ GARAGE VIEW ────────────────────────────┐
│  1. Pick car from 7 available            │
│  2. Select bet amount (10/50/100/500)    │
│  3. Click "PLACE BET"                    │
└──────────────┬──────────────────────────┘
               ↓
        ❌ CRASH RISK #1
        
┌─ FIRESTORE: BETTING PHASE ──────────────┐
│  - Validate coins                        │
│  - Deduct coins atomically               │
│  - Write bet document                    │
└──────────────┬──────────────────────────┘
               ↓
        ❌ NO TIMEOUT RISK
        
┌─ FIRESTORE: RACING PHASE ───────────────┐
│  - Status changed to "RACING"            │
│  - Winner predetermined: "sports_red"    │
└──────────────┬──────────────────────────┘
               ↓
┌─ F1 COUNTDOWN (3s) ──────────────────────┐
│  - Red light 1, 2, 3                     │
│  - Green light (GO!)                     │
│  - Track view + cars aligned             │
└──────────────┬──────────────────────────┘
               ↓
┌─ RACE ANIMATION (8s) ────────────────────┐
│  ❌ LOCAL RANDOM SPEEDS                  │
│  ❌ WINNER MISMATCH POSSIBLE             │
│  - Cars animate left → right             │
│  - Video plays                           │
└──────────────┬──────────────────────────┘
               ↓
┌─ RESULT SCREEN (6s) ─────────────────────┐
│  - Show winner (from Firestore)          │
│  - IF WIN: Add coins                     │
│  ❌ CRASH RISK #2                        │
│  - Show celebration animation            │
└──────────────┬──────────────────────────┘
               ↓
┌─ RESET TO GARAGE ────────────────────────┐
│  - Pick new 3 random cars                │
│  - Ready for next round                  │
└──────────────────────────────────────────┘
```

---

## දිනපතක්ක ඇති වෙන්නවා කියවින් ගිණුම්:

### **Scenario 1: Network Slow**
```
User: Click PLACE BET
Game: Awaiting Firestore (2 seconds)
User: Closes game
Result: ❌ Crash - context invalid
```

### **Scenario 2: Fast Network, Auto-play**
```
User: Enable auto-play (5 rounds)
Game: Bet placed, Firestore updates
User: Closes game DURING race animation
Result: ❌ Crash - widget disposed during setState()
```

### **Scenario 3: Race Animation Issue**
```
Firestore winner: sports_red
Animation winner: bike_blue (random)
Result screen: Shows sports_red
User sees: Animation != Result ❌
```

### **Scenario 4: Offline**
```
User: No internet
User: Click PLACE BET
Game: await forever (no timeout)
Result: 🕐 Game hangs, no error message
```

---

## දරුණු දාවන්ව (Severity)

| ගැටලුව | දරුණුතාවය | පුණුකරන ස්ඵුටිම |
|---------|-----------|----------|
| BuildContext crash | 🔴 Critical | 5 min |
| Race winner mismatch | 🟠 Medium | 10 min |
| withOpacity warnings | 🟡 Low | 15 min |
| No timeout | 🟠 Medium | 10 min |
| Null cast | 🟠 Medium | 5 min |

**සම්පූර්ණයි!** 🎮

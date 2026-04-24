# Call Features Testing Guide
## ✅ සියලුම Features පරීක්ෂා කිරීමේ මාර්ගෝපදේශය

මෙම ලේඛනය භාවිතා කරමින් අපි implement කළ සියලුම call features හරියට වැඩ කරනවද කියලා පරීක්ෂා කරන්න පුළුවන්.

---

## 📋 Quick Verification Checklist

### 1. ✅ Files පරීක්ෂා කරන්න

පහත files ඔබේ project එකේ තියෙනවද check කරන්න:

```bash
# New Files (5 files)
✓ lib/models/call_model.dart
✓ lib/screens/calls/call_history_screen.dart
✓ lib/widgets/call/network_quality_indicator.dart
✓ lib/widgets/call/incoming_call_popup.dart
✓ CALL_FEATURES_IMPLEMENTATION.md

# Modified Files (8 files)
✓ lib/services/call_service.dart
✓ lib/screens/calls/voice_call_screen.dart
✓ lib/screens/calls/video_call_screen.dart
✓ lib/screens/calls/incoming_call_screen.dart
✓ lib/screens/profile/edit_profile_screen.dart
✓ functions/index.js
✓ firebase.json
✓ functions/package.json
```

---

## 🧪 Feature Testing Steps

### Feature 1: CallModel (Firestore Data Model)

**පරීක්ෂා කිරීම:**

1. Terminal එකේ Flutter project එකේ directory එකට යන්න
2. Run කරන්න:
```bash
flutter analyze lib/models/call_model.dart
```

**Expected Output:**
```
No issues found!
```

**හරියට වැඩ කරනවද හඳුනාගන්නේ කොහොමද:**
- ✅ කිසිම errors නැතිනම් model එක හරි
- ✅ File එකේ lines 189ක් තිබ්බොත් complete

---

### Feature 2: Call History Screen

**පරීක්ෂා කිරීම:**

1. File එක open කරන්න:
```bash
code lib/screens/calls/call_history_screen.dart
```

2. පහත code එක තියෙනවද check කරන්න (Line 60 අවට):
```dart
Stream<List<CallModel>> getCallHistory(String userId, {int limit = 50})
```

**Real Testing (App එකේ):**

App එක run කරලා call history screen එකට navigate කරන්න:
```dart
// Navigation එක test කරන්න
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const CallHistoryScreen(),
  ),
);
```

**හරියට වැඩ කරනවද:**
- ✅ Screen එක load වෙනවා
- ✅ Empty state එකත් පෙන්නනවා ("No call history")
- ✅ Past calls list එකක් show කරනවා (calls තිබ්බොත්)

---

### Feature 3: Switch Camera

**පරීක්ෂා කිරීම:**

1. CallService එකේ method එක තියෙනවද check කරන්න:
```bash
grep -n "switchCamera" lib/services/call_service.dart
```

**Expected Output:**
```
223:  Future<void> switchCamera() async {
```

2. Method එක complete ද කියලා check කරන්න:
```bash
sed -n '223,241p' lib/services/call_service.dart
```

**හරියට වැඩ කරනවද:**
- ✅ Method එකේ `_isFrontCamera` flag එක toggle වෙනවා
- ✅ `await _engine!.switchCamera()` call එක තියෙනවා
- ✅ Print statement එකෙන් "front" හෝ "back" පෙන්නනවා

---

### Feature 4: Network Quality Indicator

**පරීක්ෂා කිරීම:**

1. Widget file එක තියෙනවද:
```bash
ls -lh lib/widgets/call/network_quality_indicator.dart
```

2. Widget එකේ classes දෙකම තියෙනවද:
```bash
grep -E "class (NetworkQualityIndicator|NetworkQualityBadge)" lib/widgets/call/network_quality_indicator.dart
```

**Expected Output:**
```
class NetworkQualityIndicator extends StatelessWidget {
class NetworkQualityBadge extends StatelessWidget {
```

**Real Testing:**

Video call එකක් start කරලා network quality indicator එක පෙන්නනවද බලන්න.

**හරියට වැඩ කරනවද:**
- ✅ Signal bars පෙන්නනවා (1-4 bars)
- ✅ Colors වෙනස් වෙනවා (green, orange, red)
- ✅ Label එක show කරනවා (Excellent, Good, Poor, Bad)

---

### Feature 5: Incoming Call Popup

**පරීක්ෂා කිරීම:**

1. Widget file එක තියෙනවද:
```bash
ls -lh lib/widgets/call/incoming_call_popup.dart
```

2. Components 3ක් තියෙනවද check කරන්න:
```bash
grep -n "^class" lib/widgets/call/incoming_call_popup.dart
```

**Expected Output:**
```
10:class IncomingCallPopup extends StatefulWidget {
92:class IncomingCallFullScreen extends StatefulWidget {
```

3. Helper functions තියෙනවද:
```bash
grep -n "^Future<void> showIncomingCall" lib/widgets/call/incoming_call_popup.dart
```

**හරියට වැඩ කරනවද:**
- ✅ Popup dialog version එක තියෙනවා
- ✅ Fullscreen version එක තියෙනවා
- ✅ Accept & Decline buttons තියෙනවා
- ✅ Pulse animation එක caller photo එකේ තියෙනවා

---

### Feature 6: Missed Call Tracking

**පරීක්ෂා කිරීම:**

1. CallService එකේ missed call methods තියෙනවද:
```bash
grep -n "missedCall\|getMissedCallCount\|markMissedCallsAsRead" lib/services/call_service.dart
```

**Expected Output:**
```
381:  Future<void> markAsMissed(String callId) async {
426:  Future<int> getMissedCallCount(String userId) async {
443:  Future<void> markMissedCallsAsRead(String userId) async {
```

2. CallModel එකේ `isRead` field එක තියෙනවද:
```bash
grep -n "isRead" lib/models/call_model.dart
```

**Real Testing:**

Call history screen එක open කරන්න. Missed calls red color එකේ පෙන්වනවද බලන්න.

**හරියට වැඩ කරනවද:**
- ✅ `isRead` field එක CallModel එකේ තියෙනවා
- ✅ Missed calls count method එක වැඩ කරනවා
- ✅ Mark as read function එක තියෙනවා
- ✅ Call history screen එකේ missed calls bold red එකේ show වෙනවා

---

### Feature 7: Complete Call Signaling

**පරීක්ෂා කිරීම:**

1. සියලුම Firestore methods තියෙනවද check කරන්න:
```bash
grep -n "Future<.*> \(initiateCall\|acceptCall\|rejectCall\|cancelCall\|endCallWithDuration\|markAsMissed\)" lib/services/call_service.dart
```

**Expected Output:**
```
263:  Future<String> initiateCall({
301:  Future<void> acceptCall({
323:  Future<void> rejectCall(String callId) async {
338:  Future<void> cancelCall(String callId) async {
357:  Future<void> endCallWithDuration({
381:  Future<void> markAsMissed(String callId) async {
```

2. Stream methods තියෙනවද:
```bash
grep -n "Stream<.*> \(getCallHistory\|listenForIncomingCalls\)" lib/services/call_service.dart
```

**Expected Output:**
```
396:  Stream<List<CallModel>> getCallHistory(String userId, {int limit = 50}) {
411:  Stream<CallModel?> listenForIncomingCalls(String userId) {
```

**හරියට වැඩ කරනවද:**
- ✅ 6 CRUD methods තියෙනවා (initiate, accept, reject, cancel, end, missed)
- ✅ 2 Stream methods තියෙනවා (history, incoming)
- ✅ සියලුම methods async/await use කරනවා
- ✅ Error handling තියෙනවා

---

## 🔥 Cloud Functions Verification

**පරීක්ෂා කිරීම:**

1. Cloud Functions file එකේ new functions තියෙනවද:
```bash
grep -n "exports.onCall" functions/index.js
```

**Expected Output:**
```
490:exports.onCallInitiated = functions.firestore
596:exports.onCallMissed = functions.firestore
```

2. Node.js version එක update වෙලාද:
```bash
cat firebase.json | grep nodejs
```

**Expected Output:**
```
    "runtime": "nodejs20",
```

3. Deploy කරන්න:
```bash
firebase deploy --only functions
```

**හරියට deploy වෙනවද:**
- ✅ Functions 6ක් deploy වෙනවා
- ✅ onCallInitiated function එක deploy වෙනවා
- ✅ onCallMissed function එක deploy වෙනවා
- ✅ කිසිම errors නැති

---

## 🚨 Common Issues & Solutions

### Issue 1: Image Cropper Error

**Error:**
```
error: cannot find symbol
  symbol:   class Registrar
```

**Solution:**
```bash
# pubspec.yaml එකේ version එක check කරන්න
grep "image_cropper" pubspec.yaml
```

**Expected:**
```yaml
image_cropper: ^8.1.0  # NOT 5.0.1
```

**Fix:**
```bash
flutter pub upgrade image_cropper
flutter clean
```

---

### Issue 2: Method Not Found Errors

**Error:**
```
The method 'updateCallStatus' isn't defined
```

**Solution:**

Call screens වල old method calls update කරලා තියෙනවද check කරන්න:

```bash
# Should be EMPTY (no results)
grep -r "updateCallStatus\|createCallRecord" lib/screens/calls/
```

**Expected Output:**
```
(Empty - no results)
```

---

### Issue 3: Cloud Functions Deployment Error

**Error:**
```
Runtime Node.js 18 was decommissioned
```

**Solution:**

```bash
# Check firebase.json
cat firebase.json | grep nodejs
# Should show: "runtime": "nodejs20"

# Check package.json
cat functions/package.json | grep '"node"'
# Should show: "node": "20"
```

**Fix if needed:**
```bash
# Update both files to nodejs20
# Then redeploy
firebase deploy --only functions
```

---

## ✅ Final Verification Command

සියල්ල එකවර check කරන්න මේ command එක run කරන්න:

```bash
echo "🔍 Checking all files..."
echo ""

echo "📦 New Files:"
ls -1 lib/models/call_model.dart 2>/dev/null && echo "  ✅ call_model.dart" || echo "  ❌ call_model.dart MISSING"
ls -1 lib/screens/calls/call_history_screen.dart 2>/dev/null && echo "  ✅ call_history_screen.dart" || echo "  ❌ call_history_screen.dart MISSING"
ls -1 lib/widgets/call/network_quality_indicator.dart 2>/dev/null && echo "  ✅ network_quality_indicator.dart" || echo "  ❌ network_quality_indicator.dart MISSING"
ls -1 lib/widgets/call/incoming_call_popup.dart 2>/dev/null && echo "  ✅ incoming_call_popup.dart" || echo "  ❌ incoming_call_popup.dart MISSING"

echo ""
echo "🔧 Modified Files:"
grep -q "endCallWithDuration" lib/services/call_service.dart && echo "  ✅ call_service.dart updated" || echo "  ❌ call_service.dart NOT updated"
grep -q "endCallWithDuration" lib/screens/calls/voice_call_screen.dart && echo "  ✅ voice_call_screen.dart fixed" || echo "  ❌ voice_call_screen.dart NOT fixed"
grep -q "endCallWithDuration" lib/screens/calls/video_call_screen.dart && echo "  ✅ video_call_screen.dart fixed" || echo "  ❌ video_call_screen.dart NOT fixed"
grep -q "rejectCall" lib/screens/calls/incoming_call_screen.dart && echo "  ✅ incoming_call_screen.dart fixed" || echo "  ❌ incoming_call_screen.dart NOT fixed"

echo ""
echo "🔥 Cloud Functions:"
grep -q "exports.onCallInitiated" functions/index.js && echo "  ✅ onCallInitiated function added" || echo "  ❌ onCallInitiated MISSING"
grep -q "exports.onCallMissed" functions/index.js && echo "  ✅ onCallMissed function added" || echo "  ❌ onCallMissed MISSING"
grep -q "nodejs20" firebase.json && echo "  ✅ Node.js 20 runtime" || echo "  ❌ Node.js runtime NOT updated"

echo ""
echo "📱 Dependencies:"
grep -q "image_cropper: \^8" pubspec.yaml && echo "  ✅ image_cropper 8.x.x" || echo "  ❌ image_cropper needs upgrade"

echo ""
echo "✅ Verification Complete!"
```

---

## 🎯 Test Coverage Summary

| Feature | Files | Methods | Status |
|---------|-------|---------|--------|
| CallModel | 1 | 8 helper methods | ✅ |
| Call History | 1 | StreamBuilder | ✅ |
| Switch Camera | 1 | switchCamera() | ✅ |
| Quality Indicator | 1 | 2 widgets | ✅ |
| Call Popup | 1 | 3 components | ✅ |
| Missed Tracking | 2 | 3 methods | ✅ |
| Call Signaling | 1 | 8 methods | ✅ |
| Cloud Functions | 1 | 2 functions | ✅ |

**Total: 8/8 Features ✅**

---

## 📱 App Testing Flow

1. **App Start:**
   ```bash
   flutter run
   ```

2. **Test Call History:**
   - Navigate to calls tab
   - Should see "No call history" or list of past calls
   - Missed calls should be in RED

3. **Test Video Call:**
   - Start a video call
   - Check camera switch button
   - Check network quality indicator
   - End call (should save to Firestore)

4. **Test Incoming Call:**
   - Receive a call
   - Check popup appears
   - Test accept/decline
   - Check Firestore updates

5. **Test Cloud Functions:**
   - Check Firebase Console → Functions
   - Should see 6 functions deployed
   - Check logs for call notifications

---

## 🆘 Need Help?

ගැටලුවක් තියෙනවනම්:

1. **Files නැතිනම්:**
   - Check if you're in the correct directory
   - Run: `pwd` (should show: `.../dating_live_app`)

2. **Compilation errors:**
   - Run: `flutter clean`
   - Run: `flutter pub get`
   - Run: `flutter run`

3. **Cloud Functions errors:**
   - Check: `firebase.json` has `"runtime": "nodejs20"`
   - Check: `functions/package.json` has `"node": "20"`
   - Redeploy: `firebase deploy --only functions`

4. **Method not found:**
   - Old method names (`updateCallStatus`, `createCallRecord`)
   - Should use new methods (`endCallWithDuration`, `initiateCall`)

---

**සියල්ල හරියට තියෙනවනම්, ඔයාගේ app එක build වෙලා run වෙන්න ඕන! 🎉**

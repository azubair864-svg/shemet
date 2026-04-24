# Debug Logging Guide - Call Features
## 🐛 Terminal එකේ Logs බලා ගන්න ආකාරය

මෙම guide එක භාවිතා කරමින් call features වල debug logs terminal එකේ කියවන්න පුළුවන්.

---

## 📋 Log Patterns

### 1. Voice Call Button Press කරන කොට

Terminal එකේ පෙන්වන logs:

```
📞 ========== VOICE CALL BUTTON PRESSED ==========
📞 Caller ID: your_user_id_here
📞 Receiver ID: other_user_id_here
📞 Receiver Name: John Doe
✅ Dialog closed
🔥 Creating call record in Firestore...
📞 Call initiated: call_document_id
✅ Call record created successfully!
📋 Call ID: Gk4Df8Hj3K...
🎙️ Call Type: VOICE
🚀 Navigating to voice call screen...
✅ Navigation initiated
✅ ========== VOICE CALL SETUP COMPLETE ==========
```

### 2. Video Call Button Press කරන කොට

```
📹 ========== VIDEO CALL BUTTON PRESSED ==========
📹 Caller ID: your_user_id_here
📹 Receiver ID: other_user_id_here
📹 Receiver Name: Jane Smith
✅ Dialog closed
🔥 Creating call record in Firestore...
📞 Call initiated: call_document_id
✅ Call record created successfully!
📋 Call ID: Hj5Eg9Ik4L...
📹 Call Type: VIDEO
🚀 Navigating to video call screen...
✅ Navigation initiated
✅ ========== VIDEO CALL SETUP COMPLETE ==========
```

### 3. Call Initiation (CallService)

```
📞 ========== INCOMING CALL NOTIFICATION TRIGGERED ==========
📋 Call ID: abc123def456
👤 Caller ID: user_id_1
👤 Receiver ID: user_id_2
📹 Call Type: video
📤 Sending incoming call notification...
✅ Incoming call notification sent: projects/.../messages/0:12345...
✅ ========== INCOMING CALL NOTIFICATION COMPLETED ==========
```

### 4. Call Screen Navigation

Voice Call Screen:
```
✅ Call service initialized
🔇 Mute: false
🔊 Speaker: true
📹 Video: true
✅ Joined voice call: call_channel_123
✅ Remote user joined: 12345678
```

Video Call Screen:
```
✅ Call service initialized
✅ Joined video call: call_channel_456
📷 Camera switched to: front
✅ Remote user joined: 87654321
```

### 5. Call End

```
✅ Call ended
✅ Call ended: call_id_here (120s)
```

---

## 🚨 Error Logs

### Error Pattern 1: Call Initiation Failed

```
❌ ========== VOICE CALL ERROR ==========
❌ Error: [cloud_firestore/permission-denied] Missing or insufficient permissions
📍 Stack trace: #0      MethodChannelCloudFirestore.addDoc...
❌ ========================================
```

**හේතුව:** Firestore permissions නැති

**විසඳුම:**
```bash
# firestore.rules check කරන්න
cat firestore.rules

# Rules යාවත්කාලීන කරන්න
firebase deploy --only firestore:rules
```

### Error Pattern 2: Navigation Failed

```
📞 ========== VOICE CALL BUTTON PRESSED ==========
📞 Caller ID: abc123
📞 Receiver ID: def456
📞 Receiver Name: Test User
✅ Dialog closed
🔥 Creating call record in Firestore...
✅ Call record created successfully!
📋 Call ID: xyz789
🎙️ Call Type: VOICE
🚀 Navigating to voice call screen...
❌ Could not find a route named '/voice_call'
```

**හේතුව:** Route එක register වෙලා නැහැ

**විසඳුම:**
```dart
// main.dart එකේ routes check කරන්න
routes: {
  '/voice_call': (context) => VoiceCallScreen(...),
  '/video_call': (context) => VideoCallScreen(...),
}
```

### Error Pattern 3: User Not Found

```
❌ ========== VOICE CALL ERROR ==========
❌ Error: Null check operator used on a null value
📍 Stack trace: ...
❌ ========================================
```

**හේතුව:** User object එක null හෝ incomplete

**විසඳුම:** User profile screen එකේ user data loaded වෙලාද බලන්න

### Error Pattern 4: Firestore Write Failed

```
🔥 Creating call record in Firestore...
❌ Initiate call error: [cloud_firestore/unavailable] The service is currently unavailable
```

**හේතුව:** Internet connection නැහැ හෝ Firebase down

**විසඳුම:**
- Internet connection check කරන්න
- Firebase Console status check කරන්න

---

## 🔍 Logs Filter කරන්නේ කොහොමද

Terminal එකේ specific logs filter කරන්න:

### 1. Voice Calls විතරක්:
```bash
flutter run | grep "🎙️\|📞 VOICE"
```

### 2. Video Calls විතරක්:
```bash
flutter run | grep "📹"
```

### 3. Errors විතරක්:
```bash
flutter run | grep "❌"
```

### 4. Call Service logs විතරක්:
```bash
flutter run | grep "Call\|call"
```

### 5. Firestore operations විතරක්:
```bash
flutter run | grep "🔥\|Firestore"
```

---

## 📊 Log Levels

| Icon | Meaning | Example |
|------|---------|---------|
| 📞 | Voice Call | Voice call initiated |
| 📹 | Video Call | Video call initiated |
| ✅ | Success | Operation completed |
| ❌ | Error | Operation failed |
| ⚠️ | Warning | Widget not mounted |
| 🔥 | Firestore | Database operation |
| 🚀 | Navigation | Screen navigation |
| 📋 | Data | Important data displayed |
| 👤 | User Info | User IDs, names |
| 🔇 | Audio Control | Mute/unmute |
| 🔊 | Speaker | Speaker on/off |
| 📷 | Camera | Camera operations |

---

## 🧪 Debug Testing Workflow

### Step 1: Run App with Logs
```bash
# Terminal එකේ run කරන්න
flutter run --verbose

# හෝ logs file එකක save කරන්න
flutter run > call_logs.txt 2>&1
```

### Step 2: Test Voice Call
1. User profile එකක් open කරන්න
2. Phone icon එක tap කරන්න
3. "Audio" button එක press කරන්න
4. Terminal එකේ logs බලන්න

**Expected Logs:**
```
📞 ========== VOICE CALL BUTTON PRESSED ==========
  → Caller/Receiver IDs
  → Dialog closed
  → Firestore call creation
  → Navigation
✅ ========== VOICE CALL SETUP COMPLETE ==========
```

### Step 3: Test Video Call
1. User profile එකක් open කරන්න
2. Phone icon එක tap කරන්න
3. "Video" button එක press කරන්න
4. Terminal එකේ logs බලන්න

**Expected Logs:**
```
📹 ========== VIDEO CALL BUTTON PRESSED ==========
  → Caller/Receiver IDs
  → Dialog closed
  → Firestore call creation
  → Navigation
✅ ========== VIDEO CALL SETUP COMPLETE ==========
```

### Step 4: Check for Errors
Terminal එකේ red ❌ icons හොයන්න:
```bash
# Errors count කරන්න
cat call_logs.txt | grep "❌" | wc -l
```

---

## 🔎 Common Issues හා Logs

### Issue 1: Button Press කරන කොට මොනවත් වෙන්නේ නැහැ

**Check Logs For:**
```
📞 ========== VOICE CALL BUTTON PRESSED ==========
```

**නැත්තන්:** Button event එක trigger වෙන්නේ නැහැ
- `onPressed` method එක check කරන්න
- Debug point එකක් දාලා breakpoint හරියටද බලන්න

### Issue 2: Call Record Create වෙන්නේ නැහැ

**Check Logs For:**
```
🔥 Creating call record in Firestore...
✅ Call record created successfully!
```

**Error තියෙනවනම්:**
```
❌ Initiate call error: ...
```

**විසඳුම්:**
- Firestore rules check කරන්න
- Internet connection check කරන්න
- User authentication status check කරන්න

### Issue 3: Navigation වෙන්නේ නැහැ

**Check Logs For:**
```
🚀 Navigating to voice call screen...
✅ Navigation initiated
```

**Error තියෙනවනම්:**
```
❌ Could not find a route
```

**විසඳුම්:**
- main.dart එකේ routes registered වෙලාද check කරන්න
- Route names හරියටද spell කරලා තියෙනවද (`/voice_call`, `/video_call`)

### Issue 4: Widget Not Mounted Warning

**Log:**
```
⚠️ Widget not mounted, skipping navigation
```

**හේතුව:** Screen එක dispose වෙලා navigation කරන්න try කරනවා

**විසඳුම:** දැනටමත් `if (mounted)` check එක තියෙනවා, මේක expected behavior එකක්

---

## 📱 Real Device vs Emulator Logs

### Android (Real Device)
```bash
# Android device logs එක්කම
flutter run -d <device-id> --verbose

# හෝ adb logcat use කරන්න
adb logcat | grep flutter
```

### iOS (Real Device)
```bash
# iOS device logs එක්කම
flutter run -d <device-id> --verbose

# හෝ Console app use කරන්න (Mac)
# Open Console.app → Filter: "flutter"
```

### Emulator
```bash
# Regular run එක මදිද logs වලට
flutter run --verbose
```

---

## 🎯 Quick Debug Checklist

ගැටලුවක් තියෙනවනම් මේ order එකට logs check කරන්න:

- [ ] **Button pressed log** තියෙනවද? (📞 හෝ 📹)
- [ ] **Dialog closed log** තියෙනවද? (✅ Dialog closed)
- [ ] **Firestore creation log** තියෙනවද? (🔥 Creating...)
- [ ] **Call ID generated** තියෙනවද? (📋 Call ID: ...)
- [ ] **Navigation log** තියෙනවද? (🚀 Navigating...)
- [ ] **Complete log** තියෙනවද? (✅ SETUP COMPLETE)
- [ ] **Errors** තියෙනවද? (❌ symbols)

---

## 💡 Tips

1. **Log File Save කරන්න:**
   ```bash
   flutter run > debug_$(date +%Y%m%d_%H%M%S).log 2>&1
   ```

2. **Real-time Filtering:**
   ```bash
   flutter run | tee call_logs.txt | grep "📞\|📹\|❌"
   ```

3. **Color Coded Logs:**
   Terminal එකේ emoji colors automatically show වෙනවා

4. **Search in Logs:**
   ```bash
   # Specific call ID එකක් හොයන්න
   grep "call_abc123" call_logs.txt

   # Specific user එකක් හොයන්න
   grep "user_xyz789" call_logs.txt
   ```

5. **Count Operations:**
   ```bash
   # කී call attempt කළාද
   grep "BUTTON PRESSED" call_logs.txt | wc -l

   # කී success වුණාද
   grep "SETUP COMPLETE" call_logs.txt | wc -l

   # කී errors ආවාද
   grep "ERROR" call_logs.txt | wc -l
   ```

---

## 🆘 තවත් Help ඕනද?

Logs බැලුවට issue එක හොයා ගන්න බැරිද?

1. **Full log file එක save කරන්න:**
   ```bash
   flutter run --verbose > full_debug.log 2>&1
   ```

2. **මේ info එක එක්කම:**
   - කොයි button එක press කළාද (Audio/Video)
   - Terminal එකේ කොයි logs පෙන්වුණාද
   - Red error messages මොනවද
   - App එක crash වුණාද

3. **Firebase Console check කරන්න:**
   - Firestore → Calls collection → Documents created වෙනවද
   - Cloud Functions → Logs → Errors තියෙනවද

---

**මතක තියා ගන්න:** Debug logs app එකේ performance වලට බලපානවා, production build එකේදී remove කරන්න!

**Production Build:**
```dart
// Debug mode එකේ විතරක් logs
if (kDebugMode) {
  print('Debug message');
}
```

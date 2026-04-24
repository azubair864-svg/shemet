# AI Coding Agent Instructions - Shemet (Dating Live App)

## Project Overview
**Shemet** is a Flutter-based live streaming and dating platform with real-time video/voice calls, party rooms, in-app games, and social features. The app integrates Firebase, Agora SDK, and DeepAR for beauty effects.

**Tech Stack**: Flutter (Dart 3.9+) | Firebase (Auth, Firestore, Storage, Functions) | Agora RTC | DeepAR | Provider (state management)

---

## Architecture & Key Components

### 1. **Layered Architecture**
- **lib/models/**: Data classes with `toMap()` and `fromMap()` for Firestore serialization
- **lib/services/**: Business logic and external API integration (Firebase, Agora, DeepAR, IAP)
- **lib/providers/**: State management using Provider with `ChangeNotifier`
- **lib/screens/**: UI screens organized by feature (auth, home, calls, messages, etc.)
- **lib/widgets/**: Reusable UI components and feature-specific widgets
- **lib/core/**: Theme, constants, and utilities

### 2. **Critical Integration Points**

#### Firebase Setup
- **Firestore Collections**: `users`, `calls`, `messages`, `chat_prices`, `party_rooms`, `gifts`, `moments`, `leaderboards`
- **Authentication**: Firebase Auth + Google Sign-In
- **Storage**: Profile photos, videos, voice introductions
- **Functions**: Token generation for Agora, payment processing, notifications
- Reference: `lib/services/database_service.dart` (3873 lines - main data hub)

#### Agora Real-time Communication
- **AgoraService** (Singleton): Manages RTC engine, camera/audio control, channel lifecycle
- **CallService** (Singleton): High-level call management with diamond earnings for receivers
- Diamond rates: 10/min (voice), 20/min (video)
- DeepAR integration for beauty filters during calls
- Reference: `lib/services/agora_service.dart`, `lib/services/call_service.dart`

#### State Management
- **AuthProvider**: Firebase Auth state, Google Sign-In, user authentication
- **UserProvider**: Current user data stream, profile updates
- **BeautySettingsProvider**: Beauty effect parameters (smooth, whiten, face slim, eye size)
- **StickerProvider**: AR sticker management
- Pattern: `ChangeNotifier` with `notifyListeners()` for reactive updates

### 3. **Data Flow: Real-time Calls Example**
```
User initiates call → CallService.initiateCall() 
  → Creates CallModel in Firestore 
  → AgoraService.joinChannel() with token from Cloud Function
  → RTCEventHandler monitors connection/quality
  → CallService applies diamond earnings on end
  → Updates CallModel.status to "ended"
```

---

## Developer Workflows

### Running the App
```bash
flutter pub get
flutter run -d <device>  # iOS/Android
flutter run -d chrome    # Web
```

### Building for Release
```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release

# App signing uses local.properties (Android) and Xcode config (iOS)
```

### Testing
- **Unit Tests**: `test/` directory (minimal - focus on services)
- **Widget Tests**: Most features tested via manual QA (see `TESTING_GUIDE.md`)
- Command: `flutter test`
- Reference: `test/widget_test.dart`, `test/translation_service_test.dart`

### Debugging
- Enable Firebase Debug Logging: `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: false);`
- Agora SDK debug: Check `[AGORA_DEBUG]` prefixed logs in call services
- Profiling: Use Flutter DevTools for performance analysis

---

## Project-Specific Patterns & Conventions

### 1. **Singleton Services**
Services use the singleton pattern to maintain state across the app:
```dart
class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();
}
```
✅ Use for: Agora, Call, Audio, Sound, Translation services  
❌ Avoid creating new instances; always use `ServiceName()` factory

### 2. **Firestore Model Pattern**
All models implement serialization for Firestore:
```dart
// Required methods in every model
Map<String, dynamic> toMap();
factory ModelName.fromMap(Map<String, dynamic> map);
factory ModelName.fromFirestore(DocumentSnapshot doc);
```
Reference: `lib/models/call_model.dart`, `lib/models/user_model.dart`

### 3. **Stream-based Real-time Updates**
Use `StreamBuilder` for Firestore subscriptions:
```dart
StreamBuilder<UserModel?>(
  stream: _databaseService.getUserStream(userId),
  builder: (context, snapshot) {
    if (snapshot.hasData) return UserWidget(user: snapshot.data!);
    return LoadingWidget();
  },
)
```
Common pattern in: Party rooms, messages, leaderboards, call history

### 4. **Provider for State Management**
Access providers with context:
```dart
final user = Provider.of<UserProvider>(context).currentUser;  // Listen (rebuilds)
final user = Provider.of<UserProvider>(context, listen: false).currentUser;  // No rebuild
```
Do NOT mix Provider with setState in StatefulWidget

### 5. **Navigation & Route Management**
Routes defined in `main.dart` with argument passing:
```dart
Navigator.of(context).pushNamed(
  '/chat',
  arguments: {
    'chatId': chatId,
    'otherUser': otherUser,
  },
);
```
For complex arguments, pass as Map<String, dynamic>

### 6. **Error Handling Pattern**
Services throw exceptions caught by screens/providers:
```dart
try {
  await service.operation();
} catch (e) {
  debugPrint('[ERROR] $e');
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e'))
  );
}
```

---

## Integration Patterns & External Dependencies

### Firebase Cloud Functions
- **Purpose**: Token generation for Agora, payment webhooks, notifications
- **Location**: `functions/src/` (TypeScript)
- **Called from**: `CallService`, `IAPService`, `NotificationService`
- **Key function**: `generateAgoraToken` - must return valid token for Agora RTC join

### Agora SDK Integration
- **AppID**: In `AgoraService.APP_ID` constant
- **Channels**: Named by `"{callId}"` (not channel name)
- **Tokens**: Generated by Cloud Function, valid 24 hours
- **Event Handlers**: `RtcEventHandler` monitors connection, user state, network quality

### DeepAR Beauty Filters
- **License Keys**: Android/iOS in `AgoraService`
- **Controller**: `DeepArControllerPlus` singleton in `AgoraService`
- **Parameters**: Smooth (0-1), Whiten (0-1), FaceSlim (0-1), EyeSize (0-1)
- **Camera Switching**: Managed by `CameraOwner` enum - DeepAR or Agora owns camera at a time

### In-App Purchases
- **Provider**: Google Play Billing (Android), StoreKit (iOS)
- **Service**: `IAPService`
- **Flow**: Query products → Purchase → Verify → Grant diamonds/coins

---

## Important Files Reference

| File | Purpose | Lines |
|------|---------|-------|
| [lib/main.dart](lib/main.dart) | App initialization, route definitions, Provider setup | 327 |
| [lib/services/database_service.dart](lib/services/database_service.dart) | All Firestore CRUD operations | 3873 |
| [lib/services/call_service.dart](lib/services/call_service.dart) | Call lifecycle, Agora integration, diamond earning | 775 |
| [lib/services/agora_service.dart](lib/services/agora_service.dart) | Agora RTC engine, beauty effects, camera control | 735 |
| [lib/providers/user_provider.dart](lib/providers/user_provider.dart) | Current user state, profile updates | - |
| [lib/providers/auth_provider.dart](lib/providers/auth_provider.dart) | Authentication state, sign-in methods | 383 |
| [lib/models/user_model.dart](lib/models/user_model.dart) | User data structure, profile fields | 473 |
| [lib/models/call_model.dart](lib/models/call_model.dart) | Call record structure, status tracking | 189 |
| [lib/core/constants/api_constants.dart](lib/core/constants/api_constants.dart) | Firestore collection names, API URLs | - |
| [CALL_FEATURES_IMPLEMENTATION.md](CALL_FEATURES_IMPLEMENTATION.md) | Call features documentation with examples | 658 |
| [TESTING_GUIDE.md](TESTING_GUIDE.md) | Manual testing procedures for all features | 481 |

---

## Common Implementation Tasks

### Adding a New Screen
1. Create in `lib/screens/[feature]/my_screen.dart` as StatefulWidget or StatelessWidget
2. Add route in `main.dart` routes map
3. Use Provider for state, StreamBuilder for real-time data
4. Follow AppTheme colors and styles from `lib/core/theme/app_theme.dart`

### Adding a Firestore Operation
1. Add method to `DatabaseService` using `_firestore.collection()...`
2. Return `Future<T>` or `Stream<T>` 
3. Handle exceptions with try-catch, return null on error
4. Call from service layer, not directly from UI

### Implementing Real-time Features
1. Create Stream method in service (e.g., `getUserStream(userId)`)
2. Use StreamBuilder in UI with snapshot.hasData/hasError checks
3. Apply pagination if needed (lastDocument pattern in Firestore queries)

### Modifying User Data
1. Update through `UserProvider.updateCurrentUser(field, value)`
2. Provider calls `DatabaseService.updateUser()`
3. Firestore listener updates UI automatically via Stream

---

## Known Constraints & Gotchas

⚠️ **AgoraService camera ownership**: DeepAR and Agora both need camera access. Carefully manage `CameraOwner` state during transitions.

⚠️ **Provider rebuild scope**: Using `listen: true` (default) rebuilds entire widget. Use `listen: false` in methods that don't need rebuilds.

⚠️ **Firestore permissions**: Cloud Firestore rules enforce authentication and data ownership. Check `firestore.rules` before debugging access issues.

⚠️ **Call token expiry**: Agora tokens expire after 24 hours. Generate fresh token when joining channel; handle token-expired errors gracefully.

⚠️ **Firebase initialization**: Must call `Firebase.initializeApp()` in `main()` before any Firebase service usage.

---

## Requesting AI Assistance

When asking for code generation or fixes:
1. **Specify the feature** (e.g., "Add friend request functionality")
2. **Reference related files** (e.g., "See lib/models/user_model.dart for user structure")
3. **Mention constraints** (e.g., "Must work with existing Provider setup")
4. **Include expected behavior** (e.g., "Should update Firestore and notify both users")

This helps agents understand the full context before implementing.

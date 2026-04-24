import 'package:dating_live_app/screens/party/create_party_room_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';

// Core
import 'core/theme/app_theme.dart';

// Models
import 'models/user_model.dart';
import 'models/call_model.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/beauty_settings_provider.dart';
import 'providers/sticker_provider.dart';

// Services
import 'services/notification_service.dart';

// Screens - Auth
import 'screens/auth/login_screen.dart';

// Screens - Onboarding
import 'screens/onboarding/gender_selection_screen.dart';
import 'screens/onboarding/language_selection_screen.dart';
import 'screens/onboarding/country_selection_screen.dart';
import 'screens/onboarding/basic_info_screen.dart';
import 'screens/onboarding/photo_upload_screen.dart';

// Screens - Profile Setup
import 'screens/profile/profile_setup_screen.dart';

// Screens - Home
import 'screens/home/main_screen.dart';

// Screens - Shop
import 'screens/coins/diamond_purchase_screen.dart';
import 'screens/shop/top_offers_screen.dart';

// Screens - Profile
import 'screens/profile/my_level_screen.dart';
import 'screens/profile/level_rules_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/my_beans_screen.dart';
import 'screens/profile/chat_price_screen.dart';
import 'screens/profile/profile_visitors_screen.dart';
import 'screens/profile/video_verification_screen.dart';
import 'screens/profile/my_invitation_screen.dart';
import 'screens/profile/following_screen.dart';
import 'screens/profile/followers_screen.dart';
import 'screens/profile/friends_screen.dart';
import 'screens/profile/withdrawal_screen.dart';
import 'screens/profile/greeting_words_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/auto_verification_screen.dart';
import 'screens/profile/user_profile_detail_screen.dart';
import 'screens/profile/bean_records_screen.dart'; // NEW

// Screens - Settings
import 'screens/settings/settings_screen.dart';
import 'screens/settings/app_language_screen.dart';
import 'screens/settings/privacy_policy_screen.dart';
import 'screens/settings/user_agreement_screen.dart';
import 'screens/settings/about_us_screen.dart';

// Screens - Party
import 'screens/party/party_room_screen.dart';
import 'screens/party/party_rooms_list_screen.dart';
import 'screens/party/party_end_screen.dart';

// Screens - Live

// Screens - Messages
import 'screens/messages/messages_screen.dart';
import 'screens/messages/chat_screen.dart';

// Screens - Calls
import 'screens/calls/voice_call_screen.dart';
import 'screens/calls/video_call_screen.dart';
import 'screens/calls/incoming_call_screen.dart';

// Screens - Tasks
import 'screens/tasks/my_tasks_screen.dart';

// Screens - Leaderboard
import 'screens/leaderboard/monthly_rank_screen.dart';

// Screens - New Features
import 'screens/calls/random_call_screen.dart';
import 'screens/group_chat/group_chat_list_screen.dart';
import 'screens/daily_bonus/daily_bonus_screen.dart';
import 'screens/search/advanced_search_screen.dart';
import 'screens/live/broadcast_setup_screen.dart';
import 'screens/live/live_stream_view_screen.dart';

// Screens - Splash
import 'screens/splash/splash_screen.dart';

import 'widgets/agency_invitation_listener.dart';
import 'screens/profile/notifications_screen.dart';

import 'widgets/global_call_listener.dart';
import 'widgets/admin_broadcast_listener.dart';

import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BeautySettingsProvider()),
        ChangeNotifierProvider(create: (_) => StickerProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Shemet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          return AdminBroadcastListener(
            child: AgencyInvitationListener(
              child: GlobalCallListener(
                child: Builder(
                  builder: (context) {
                    // One-time creation of reviewer account for Google Play
                    // WidgetsBinding.instance.addPostFrameCallback((_) {
                    //   _createReviewerAccount(context);
                    // });
                    return child!;
                  },
                ),
              ),
            ),
          );
        },
        home: const SplashScreen(),
        routes: {
          '/auth_wrapper': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/profile_visitors': (context) => const ProfileVisitorsScreen(),
          '/video_verification': (context) => const VideoVerificationScreen(),
          '/gender_selection': (context) => const GenderSelectionScreen(),
          '/language_selection': (context) => const LanguageSelectionScreen(),
          '/country_selection': (context) => const CountrySelectionScreen(),
          '/basic_info': (context) => const BasicInfoScreen(),
          '/photo_upload': (context) => const PhotoUploadScreen(),
          '/profile_setup': (context) => ProfileSetupScreen(),
          '/main': (context) => const MainScreen(),
          '/home': (context) => const MainScreen(),
          '/diamond_purchase': (context) => const DiamondPurchaseScreen(),
          '/coin_purchase': (context) => const DiamondPurchaseScreen(),
          '/top_offers': (context) => const TopOffersScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/my_level': (context) => const MyLevelScreen(),
          '/level_rules': (context) => const LevelRulesScreen(),
          '/my_beans': (context) => const MyBeansScreen(),
          '/chat_price': (context) => const ChatPriceScreen(),
          '/my_invitation': (context) => const MyInvitationScreen(),
          '/following': (context) => const FollowingScreen(),
          '/followers': (context) => const FollowersScreen(),
          '/friends': (context) => const FriendsScreen(),
          '/withdrawal': (context) => const WithdrawalScreen(),
          '/greeting_words': (context) => const GreetingWordsScreen(),
          '/edit_profile': (context) => const EditProfileScreen(),
          '/user_profile_detail': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments;
            if (args == null || args is! UserModel) {
              return const MainScreen();
            }
            return UserProfileDetailScreen(user: args);
          },
          '/settings': (context) => const SettingsScreen(),
          '/app_language': (context) => const AppLanguageScreen(),
          '/privacy_policy': (context) => const PrivacyPolicyScreen(),
          '/user_agreement': (context) => const UserAgreementScreen(),
          '/about_us': (context) => const AboutUsScreen(),
          '/party_room': (context) => const PartyRoomScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/bean_records': (context) => const BeanRecordsScreen(), // NEW
          '/party_rooms_list': (context) => const PartyRoomsListScreen(),
          '/create_party_room': (context) => const CreatePartyRoomScreen(),
          '/party_end': (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments
                    as Map<String, dynamic>;
            return PartyEndScreen(stats: args);
          },

          '/messages': (context) => const MessagesScreen(),
          '/chat': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments;
            if (args == null || args is! Map<String, dynamic>) {
              return const MainScreen();
            }
            return ChatScreen(
              chatId: args['chatId'] as String,
              otherUser: args['otherUser'] as UserModel,
            );
          },
          '/voice_call': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments;
            if (args == null || args is! Map<String, dynamic>) {
              return const MainScreen();
            }
            return VoiceCallScreen(
              callId: args['callId'] as String,
              otherUser: args['otherUser'] as UserModel,
              isOutgoing: args['isOutgoing'] as bool? ?? true,
            );
          },
          '/video_call': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments;
            if (args == null || args is! Map<String, dynamic>) {
              return const MainScreen();
            }
            return VideoCallScreen(
              callId: args['callId'] as String,
              otherUser: args['otherUser'] as UserModel,
              isOutgoing: args['isOutgoing'] as bool? ?? true,
            );
          },
          '/incoming_call': (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments
                    as Map<String, dynamic>;
            return IncomingCallScreen(call: args['call'] as CallModel);
          },
          '/my_tasks': (context) => const MyTasksScreen(),
          '/monthly_rank': (context) => const MonthlyRankScreen(),
          // New Feature Routes
          '/random_call': (context) => const RandomCallScreen(),
          '/group_chats': (context) => const GroupChatListScreen(),
          '/daily_bonus': (context) {
            final userId =
                ModalRoute.of(context)!.settings.arguments as String? ?? '';
            return DailyBonusScreen(userId: userId);
          },
          '/advanced_search': (context) {
            final userId =
                ModalRoute.of(context)!.settings.arguments as String? ?? '';
            return AdvancedSearchScreen(currentUserId: userId);
          },
          '/broadcast_setup': (context) => const BroadcastSetupScreen(),
          '/live_room_view_v2': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;

            if (args is Map<String, dynamic>) {
              return LiveStreamViewScreen(
                streamId: args['streamId'] as String?,
                isBroadcaster: args['isBroadcaster'] as bool? ?? false,
              );
            }
            return const LiveStreamViewScreen(isBroadcaster: false);
          },
          // Trap for correct legacy calls or bugs
          '/live_room_view': (context) {
            // AUTO-FIX: Redirect to Broadcast Setup
            // This handles the case where a legacy button calls this route directly.
            // We assume they want to Go Live.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/broadcast_setup');
            });

            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF1493)),
              ),
            );
          },
          '/auto_verification': (context) => const AutoVerificationScreen(),
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Page Not Found')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '404 - Page Not Found',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Route: ${settings.name}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/home'),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createReviewerAccount(BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      debugPrint('[PLAY_CONSOLE_PREP] Checking reviewer account...');
      
      // Try to sign up first
      final signedUp = await authProvider.signUpWithEmailPassword(
        'reviewer@shemet.app', 
        'reviewer1234', 
        'Google Reviewer'
      );

      if (!signedUp) {
        debugPrint('[PLAY_CONSOLE_PREP] Signup failed or user exists, attempting sign-in...');
        // If signup fails (likely already exists), try to sign in
        await authProvider.signInWithEmailPassword(
          'reviewer@shemet.app', 
          'reviewer1234'
        );
      }
      
      debugPrint('[PLAY_CONSOLE_PREP] Reviewer registered/logged in!');
    } catch (e) {
      debugPrint('[PLAY_CONSOLE_PREP] Error: $e');
    }
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  void _authLog(String message) {
    final n = DateTime.now();
    final ts =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[AUTH_TRACE][$ts][AUTH_WRAPPER] $message');
  }

  String? _lastInitializedUid;

  @override
  void initState() {
    super.initState();
    _authLog('initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInit(context.read<UserProvider>());
    });
  }

  void _checkAndInit(UserProvider userProvider) {
    if (userProvider.isLoggedIn && userProvider.currentUser != null) {
      final uid = userProvider.currentUser!.uid;
      if (_lastInitializedUid != uid) {
        _authLog('Initializing services for UID: $uid');
        _lastInitializedUid = uid;
        NotificationService().initialize(context, uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final isLoggedIn = userProvider.isLoggedIn;
        final isLoading = userProvider.isLoading;
        final currentUid = userProvider.currentUser?.uid;
        
        _authLog(
          '[AUTH_DEBUG] build: isLoading=$isLoading isLoggedIn=$isLoggedIn currentUid=$currentUid',
        );

        // Perform initialization if needed during build (after state updates)
        if (isLoggedIn && currentUid != null && _lastInitializedUid != currentUid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndInit(userProvider);
          });
        }

        if (isLoading) {
          _authLog('[AUTH_DEBUG] Rendering SEAMLESS LOADING screen');
          // SEAMLESS LOADING: Match Native Splash Screen
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black12),
                ),
              ),
            ),
          );
        }

        if (isLoggedIn) {
          final user = userProvider.currentUser;

          if (user?.profileComplete == true) {
            _authLog('[AUTH_DEBUG] ROUTE -> MainScreen (Profile Complete)');
            return const MainScreen();
          } else {
            _authLog('[AUTH_DEBUG] ROUTE -> GenderSelectionScreen (Profile Incomplete)');
            return const GenderSelectionScreen();
          }
        } else {
          _authLog('[AUTH_DEBUG] ROUTE -> LoginScreen (Not Logged In)');
          return const LoginScreen();
        }
      },
    );
  }
}

class ApiConstants {
  // Base URLs
  static const String baseUrl = 'https://your-backend-url.com/api';

  // Agora
  static const String agoraAppId = '6692816e28064f469df219a95ca2bb72';

  // Razorpay
  static const String razorpayKey = 'YOUR_RAZORPAY_KEY';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String profilesCollection = 'profiles';
  static const String matchesCollection = 'matches';
  static const String swipesCollection = 'swipes';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String liveStreamsCollection = 'live_streams';
  static const String giftsCollection = 'gifts';
  static const String transactionsCollection = 'transactions';
  static const String reportsCollection = 'reports';

  // Firebase Storage Paths
  static const String profilePhotosPath = 'users/{userId}/photos';
  static const String chatImagesPath = 'chats/{chatId}/images';

  // Limits
  static const int maxPhotos = 6;
  static const int maxBioLength = 500;
  static const int maxMessageLength = 1000;
  static const int messagesPerPage = 20;
  static const int usersPerPage = 20;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 2);
}

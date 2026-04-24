import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/call_model.dart';
import '../providers/user_provider.dart';
import '../services/call_service.dart';
import '../screens/calls/call_notification_banner.dart';
import '../main.dart'; // To access navigatorKey

class GlobalCallListener extends StatefulWidget {
  final Widget child;

  const GlobalCallListener({super.key, required this.child});

  @override
  State<GlobalCallListener> createState() => _GlobalCallListenerState();
}

class _GlobalCallListenerState extends State<GlobalCallListener> {
  final CallService _callService = CallService();
  OverlayEntry? _overlayEntry;
  String? _activeCallId;

  void _showCallBanner(CallModel call) {
    if (_activeCallId == call.callId) return;
    _activeCallId = call.callId;

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => CallNotificationBanner(
        call: call,
        onDismiss: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
          _activeCallId = null;
        },
      ),
    );

    final overlay = MyApp.navigatorKey.currentState?.overlay;
    if (overlay != null) {
      overlay.insert(_overlayEntry!);
    } else {
      debugPrint('[CALL_ERROR] Overlay not found via navigatorKey');
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return widget.child;
    }

    return StreamBuilder<CallModel?>(
      stream: _callService.listenForIncomingCalls(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Silent error for production
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          final call = snapshot.data!;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Warm up Agora engine as soon as the call starts ringing
            _callService.initialize();
            _showCallBanner(call);
          });
        } else if (snapshot.data == null && _activeCallId != null) {
          // Call was cancelled or ended remotely
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _overlayEntry?.remove();
            _overlayEntry = null;
            _activeCallId = null;
          });
        }

        return widget.child;
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';

class AgencyInvitationListener extends StatefulWidget {
  final Widget child;

  const AgencyInvitationListener({super.key, required this.child});

  @override
  State<AgencyInvitationListener> createState() =>
      _AgencyInvitationListenerState();
}

class _AgencyInvitationListenerState extends State<AgencyInvitationListener> {
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription? _hostInvitationSubscription;
  StreamSubscription? _agentInvitationSubscription;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    // Start listening after first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListener();
    });
  }

  void _setupListener() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Listen for user changes to restart the invitation listeners
    userProvider.addListener(() {
      final newUserId = userProvider.currentUser?.uid;
      if (newUserId != _currentUserId) {
        _currentUserId = newUserId;
        _startListening();
      }
    });

    // Initial check
    _currentUserId = userProvider.currentUser?.uid;
    if (_currentUserId != null) {
      _startListening();
    }
  }
  void _startListening() {
    _hostInvitationSubscription?.cancel();
    _agentInvitationSubscription?.cancel();

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser?.gender == 'Male') {
      debugPrint('[AGENCY_LISTENER] Skipping listeners for male account.');
      return; 
    }

    if (_currentUserId == null) return;

    // Listen for Host Invitations
    _hostInvitationSubscription = _databaseService
        .getHostInvitationsStream(_currentUserId!)
        .listen((invitations) {
          if (invitations.isNotEmpty) {
            // Show dialog for the first pending invitation
            _showInvitationDialog(invitations.first, 'host');
          }
        });

    // Listen for Agent Invitations
    _agentInvitationSubscription = _databaseService
        .getAgentInvitationsStream(_currentUserId!)
        .listen((invitations) {
          if (invitations.isNotEmpty) {
            _showInvitationDialog(invitations.first, 'agent');
          }
        });
  }

  void _showInvitationDialog(Map<String, dynamic> invitation, String type) {
    if (!mounted) return;

    final isHost = type == 'host';
    final inviterName = isHost
        ? invitation['agencyName']
        : invitation['inviterName'];
    final roleName = isHost ? 'host' : 'sub-agent';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isHost ? Icons.business_center : Icons.person_add,
              color: const Color(0xFF9B6FD7),
            ),
            const SizedBox(width: 8),
            Text(isHost ? 'Agency Invitation' : 'Sub-Agent Invitation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$inviterName has invited you to join them as a $roleName.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              isHost
                  ? 'As an agency host, your earnings will be managed through the agency portal.'
                  : 'As a sub-agent, you can recruit hosts and manage your own team under this agency.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (isHost) {
                await _databaseService.rejectHostInvitation(invitation['id']);
              } else {
                await _databaseService.rejectAgentInvitation(invitation['id']);
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = false;
              if (isHost) {
                success = await _databaseService.acceptHostInvitation(
                  invitationId: invitation['id'],
                  userId: _currentUserId!,
                  agencyId: invitation['agencyId'],
                );
              } else {
                success = await _databaseService.acceptAgentInvitation(
                  invitationId: invitation['id'],
                  userId: _currentUserId!,
                  inviterAgencyId: invitation['inviterAgencyId'],
                );
              }

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully joined as a $roleName!'),
                  ),
                );
                // Refresh user data to update isHost status
                Provider.of<UserProvider>(
                  context,
                  listen: false,
                ).loadUser(_currentUserId!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B6FD7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hostInvitationSubscription?.cancel();
    _agentInvitationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

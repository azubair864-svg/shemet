import 'package:flutter/material.dart';
import '../../widgets/common/empty_state_widget.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live')),
      body: const EmptyStateWidget(
        icon: Icons.video_call,
        message: 'Live streaming coming soon!',
      ),
    );
  }
}

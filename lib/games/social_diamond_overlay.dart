import 'dart:math';
import 'package:flutter/material.dart';

class SocialDiamondOverlay extends StatefulWidget {
  final bool isBettingPhase;
  final Widget child;

  const SocialDiamondOverlay({
    super.key,
    required this.isBettingPhase,
    required this.child,
  });

  @override
  State<SocialDiamondOverlay> createState() => _SocialDiamondOverlayState();
}

class _SocialDiamondOverlayState extends State<SocialDiamondOverlay> with TickerProviderStateMixin {
  final List<_DiamondDef> _diamonds = [];
  final Random _rnd = Random();

  @override
  void didUpdateWidget(SocialDiamondOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBettingPhase && !oldWidget.isBettingPhase) {
      _startThrowingProcess();
    } else if (!widget.isBettingPhase && oldWidget.isBettingPhase) {
      _diamonds.clear();
      setState(() {});
    }
  }

  void _startThrowingProcess() async {
    while (widget.isBettingPhase && mounted) {
      await Future.delayed(Duration(milliseconds: 300 + _rnd.nextInt(700)));
      if (!mounted || !widget.isBettingPhase) break;
      _spawnDiamond();
    }
  }

  void _spawnDiamond() {
    final startX = _rnd.nextDouble() > 0.5 ? -50.0 : MediaQuery.of(context).size.width + 50.0;
    final startY = MediaQuery.of(context).size.height * 0.7 + _rnd.nextDouble() * 100;
    
    // Target somewhere in the upper middle where the grid is
    final targetX = MediaQuery.of(context).size.width * 0.2 + _rnd.nextDouble() * (MediaQuery.of(context).size.width * 0.6);
    final targetY = MediaQuery.of(context).size.height * 0.3 + _rnd.nextDouble() * (MediaQuery.of(context).size.height * 0.3);

    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    final diamond = _DiamondDef(
      startX: startX,
      startY: startY,
      targetX: targetX,
      targetY: targetY,
      ctrl: ctrl,
    );

    _diamonds.add(diamond);
    setState(() {});

    ctrl.forward().then((_) {
      if (mounted) {
        setState(() {
          _diamonds.remove(diamond);
        });
        ctrl.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._diamonds.map((diamond) {
          return AnimatedBuilder(
            animation: diamond.ctrl,
            builder: (context, child) {
              final val = Curves.easeOutCubic.transform(diamond.ctrl.value);
              // Parabolic arc approximation
              final yOffset = sin(val * pi) * -(MediaQuery.of(context).size.height * 0.40);

              return Positioned(
                left: diamond.startX + (diamond.targetX - diamond.startX) * val,
                top: diamond.startY + (diamond.targetY - diamond.startY) * val + yOffset,
                child: Opacity(
                  opacity: val < 0.8 ? 1.0 : (1.0 - ((val - 0.8) * 5)),
                  child: Transform.rotate(
                    angle: val * pi * 4,
                    child: const Text('💎', style: TextStyle(fontSize: 24)),
                  ),
                ),
              );
            },
          );
        })
      ],
    );
  }

  @override
  void dispose() {
    for (var d in _diamonds) {
      d.ctrl.dispose();
    }
    super.dispose();
  }
}

class _DiamondDef {
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final AnimationController ctrl;

  _DiamondDef({
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.ctrl,
  });
}

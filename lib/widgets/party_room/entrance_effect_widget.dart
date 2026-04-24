import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class EntranceEffectWidget extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const EntranceEffectWidget({super.key, this.onAnimationComplete});

  static final GlobalKey<EntranceEffectWidgetState> globalKey =
      GlobalKey<EntranceEffectWidgetState>();

  @override
  EntranceEffectWidgetState createState() => EntranceEffectWidgetState();
}

class EntranceEffectWidgetState extends State<EntranceEffectWidget>
    with TickerProviderStateMixin {
  final Queue<EntranceEffectData> _effectQueue = Queue();
  EntranceEffectData? _currentEffect;
  bool _isPlaying = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishCurrentEffect();
      }
    });
    
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void playEffect(EntranceEffectData effect) {
    
    _effectQueue.add(effect);
    if (!_isPlaying) {
      _playNext();
    }
  }

  void _playNext() {
    if (_effectQueue.isEmpty) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
      if (widget.onAnimationComplete != null) {
        widget.onAnimationComplete!();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isPlaying = true;
        _currentEffect = _effectQueue.removeFirst();
      });
    }

    // Simulating Lottie duration if no actual asset or while loading
    // In real implementation, Lottie.network loaded callback would set duration

    // For now, we assume a fixed duration or placeholder duration
    _controller.duration = const Duration(seconds: 4); // Default duration
    _controller.forward(from: 0);

    // If using a placeholder (no Lottie), manually complete it
    if (_currentEffect!.lottieAssetPath == null &&
        _currentEffect!.lottieUrl == null) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _isPlaying && _currentEffect != null) {
          _finishCurrentEffect();
        }
      });
    }
  }

  void _finishCurrentEffect() {
    if (mounted) {
      setState(() {
        _controller.reset();
        _currentEffect = null;
      });
    }
    _playNext();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying || _currentEffect == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        // Allow touches to pass through most of it, or block if intended
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Lottie Animation Layer
            if (_currentEffect!.lottieAssetPath != null)
              Lottie.asset(
                _currentEffect!.lottieAssetPath!,
                controller: _controller,
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                onLoaded: (composition) {
                  _controller.duration = composition.duration;
                  _controller.forward();
                },
                errorBuilder: (context, error, stackTrace) {
                  
                  return const SizedBox.shrink();
                },
              )
            else if (_currentEffect!.lottieUrl != null)
              Lottie.network(
                _currentEffect!.lottieUrl!,
                controller: _controller,
                fit: BoxFit.contain,
                onLoaded: (composition) {
                  _controller.duration = composition.duration;
                  _controller.forward();
                },
                errorBuilder: (context, error, stackTrace) {
                  
                  return const SizedBox.shrink();
                },
              )
            else
              // Placeholder for debugging/testing
              Container(
                color: Colors.black45,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '✨ VIP ENTRANCE ✨',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${_currentEffect!.userName} is entering!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(color: Colors.yellow),
                    ],
                  ),
                ),
              ),

            // 2. User Info Overlay (optional, if part of the effect)
            Positioned(
              bottom: 100,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: const Offset(0, 0),
                    ).animate(
                      CurvedAnimation(
                        parent: _controller,
                        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
                      ),
                    ),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0, end: 1).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.deepOrange],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Welcome ${_currentEffect!.userName}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EntranceEffectData {
  final String userName;
  final String animationName;
  final String? lottieAssetPath; // e.g. 'assets/animations/car.json'
  final String? lottieUrl;

  EntranceEffectData({
    required this.userName,
    required this.animationName,
    this.lottieAssetPath,
    this.lottieUrl,
  });
}

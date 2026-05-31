import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AnimatedReveal extends HookConsumerWidget {
  const AnimatedReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slideOffset = const Offset(0, 24),
  });

  final Widget child;
  final Duration delay;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return child
        .animate()
        .fadeIn(
          delay: delay,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        )
        .slideY(
          begin: slideOffset.dy / 100,
          end: 0,
          delay: delay,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
  }
}

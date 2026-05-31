import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PressableScale extends HookConsumerWidget {
  const PressableScale({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.96,
  });

  final VoidCallback onTap;
  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pressed = useState(false);

    return GestureDetector(
      onTapDown: (_) => pressed.value = true,
      onTapUp: (_) {
        pressed.value = false;
        onTap();
      },
      onTapCancel: () => pressed.value = false,
      child: AnimatedScale(
        scale: pressed.value ? scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

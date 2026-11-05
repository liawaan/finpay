import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Menggoyangkan [child] ke kiri-kanan setiap kali [trigger] berubah.
/// Dipakai untuk memberi umpan balik saat PIN / OTP / form salah.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  /// Naikkan nilainya (mis. `_shake++`) untuk memicu animasi.
  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

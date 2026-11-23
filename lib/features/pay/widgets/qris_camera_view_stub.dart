import 'package:flutter/material.dart';

/// Fallback / Native camera preview untuk lingkungan non-Web dan pengujian widget.
Widget buildPlatformQrisCamera({
  required bool isActive,
  required bool isFlashOn,
  VoidCallback? onTapViewport,
  ValueChanged<String>? onQrDetected,
}) {
  return _SimulatedCameraFeed(
    isActive: isActive,
    isFlashOn: isFlashOn,
    onTapViewport: onTapViewport,
  );
}

class _SimulatedCameraFeed extends StatelessWidget {
  const _SimulatedCameraFeed({
    required this.isActive,
    required this.isFlashOn,
    this.onTapViewport,
  });

  final bool isActive;
  final bool isFlashOn;
  final VoidCallback? onTapViewport;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapViewport,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Latar visual lensa kamera realistis
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.3),
                radius: 1.35,
                colors: isFlashOn
                    ? const [
                        Color(0xFF7C6248),
                        Color(0xFF4B3D30),
                        Color(0xFF231E1A),
                      ]
                    : const [
                        Color(0xFF5C4B3B),
                        Color(0xFF352C25),
                        Color(0xFF1A1614),
                      ],
              ),
            ),
          ),
          // Efek pencahayaan ambient permukaan objek kamera
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD99B66).withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

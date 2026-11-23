import 'package:flutter/material.dart';

import 'qris_camera_view_stub.dart'
    if (dart.library.html) 'qris_camera_view_web.dart';

/// Widget kamera QRIS lintas platform (Web Chrome Live Webcam & Fallback Viewfinder).
class QrisCameraView extends StatelessWidget {
  const QrisCameraView({
    super.key,
    required this.isActive,
    required this.isFlashOn,
    this.onTapViewport,
    this.onQrDetected,
  });

  final bool isActive;
  final bool isFlashOn;
  final VoidCallback? onTapViewport;
  final ValueChanged<String>? onQrDetected;

  @override
  Widget build(BuildContext context) {
    return buildPlatformQrisCamera(
      isActive: isActive,
      isFlashOn: isFlashOn,
      onTapViewport: onTapViewport,
      onQrDetected: onQrDetected,
    );
  }
}

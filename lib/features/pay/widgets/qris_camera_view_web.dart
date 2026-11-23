// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Implementasi Live Camera WebRTC (`getUserMedia`) + Real-Time QRIS Decoder
/// untuk Flutter Web (Chrome).
Widget buildPlatformQrisCamera({
  required bool isActive,
  required bool isFlashOn,
  VoidCallback? onTapViewport,
  ValueChanged<String>? onQrDetected,
}) {
  return _WebQrisCameraFeed(
    isActive: isActive,
    isFlashOn: isFlashOn,
    onTapViewport: onTapViewport,
    onQrDetected: onQrDetected,
  );
}

class _WebQrisCameraFeed extends StatefulWidget {
  const _WebQrisCameraFeed({
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
  State<_WebQrisCameraFeed> createState() => _WebQrisCameraFeedState();
}

class _WebQrisCameraFeedState extends State<_WebQrisCameraFeed> {
  static int _viewIdSeed = 0;
  late final String _viewType;
  late final html.VideoElement _videoElement;
  html.MediaStream? _mediaStream;
  Timer? _scanTimer;
  bool _hasStream = false;
  bool _isRequesting = false;
  bool _isDecodingFrame = false;
  DateTime? _lastDetectedAt;
  String? _lastDetectedCode;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _viewIdSeed++;
    _viewType = 'finpay-qris-camera-$_viewIdSeed';
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _videoElement,
    );

    if (widget.isActive) {
      _startCamera();
    }
  }

  @override
  void didUpdateWidget(covariant _WebQrisCameraFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startCamera();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_isRequesting || _hasStream) return;
    setState(() {
      _isRequesting = true;
      _cameraError = null;
    });

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('Browser tidak mendukung perangkat kamera.');
      }

      html.MediaStream stream;
      try {
        stream = await mediaDevices.getUserMedia({
          'video': {'facingMode': 'environment'},
          'audio': false,
        });
      } catch (_) {
        stream = await mediaDevices.getUserMedia({
          'video': true,
          'audio': false,
        });
      }

      if (!mounted || !widget.isActive) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        return;
      }

      _mediaStream = stream;
      _videoElement.srcObject = stream;
      await _videoElement.play();

      _startQrFrameLoop();

      if (mounted) {
        setState(() {
          _hasStream = true;
          _isRequesting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasStream = false;
          _isRequesting = false;
          _cameraError =
              'Izin kamera belum aktif • Ketuk untuk aktifkan / pilih QRIS';
        });
      }
    }
  }

  void _startQrFrameLoop() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _scanCurrentFrame(),
    );
  }

  Future<void> _scanCurrentFrame() async {
    if (!_hasStream ||
        !widget.isActive ||
        _isDecodingFrame ||
        widget.onQrDetected == null) {
      return;
    }

    _isDecodingFrame = true;
    try {
      if (!js_util.hasProperty(html.window, 'finpayScanVideoFrame')) return;
      final promise = js_util.callMethod<Object>(
        html.window,
        'finpayScanVideoFrame',
        [_videoElement],
      );
      final result = await js_util.promiseToFuture<Object?>(promise);
      final raw = (result?.toString() ?? '').trim();
      if (raw.isNotEmpty && raw.contains('000201')) {
        final now = DateTime.now();
        final recentlySame = _lastDetectedCode == raw &&
            _lastDetectedAt != null &&
            now.difference(_lastDetectedAt!).inSeconds < 4;
        if (!recentlySame && mounted) {
          _lastDetectedCode = raw;
          _lastDetectedAt = now;
          widget.onQrDetected?.call(raw);
        }
      }
    } catch (_) {
    } finally {
      _isDecodingFrame = false;
    }
  }

  void _stopCamera() {
    _scanTimer?.cancel();
    _scanTimer = null;
    final stream = _mediaStream;
    _mediaStream = null;
    _videoElement.srcObject = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }
    if (mounted) {
      setState(() {
        _hasStream = false;
        _isRequesting = false;
      });
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _scanTimer = null;
    final stream = _mediaStream;
    _mediaStream = null;
    _videoElement.srcObject = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_hasStream && !_isRequesting) {
          _startCamera();
        }
        widget.onTapViewport?.call();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Latar visual lensa kamera
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.3),
                radius: 1.35,
                colors: widget.isFlashOn
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
          if (_hasStream) HtmlElementView(viewType: _viewType),
          if (widget.isFlashOn)
            IgnorePointer(
              child: Container(
                color: const Color(0x22FFF8E1),
              ),
            ),
          if (!_hasStream)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRequesting
                          ? Icons.videocam_outlined
                          : Icons.camera_alt_rounded,
                      color: AppColors.mint,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isRequesting
                            ? 'Mengaktifkan kamera perangkat...'
                            : (_cameraError ??
                                'Ketuk layar untuk mengaktifkan kamera / pindai QRIS'),
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

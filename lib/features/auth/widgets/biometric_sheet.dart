import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';

/// Menampilkan sheet "Sentuh sensor" dan mengembalikan `true` kalau
/// autentikasi biometrik berhasil, `false` kalau dibatalkan.
///
/// SIMULASI: di web/desktop tidak ada sensor biometrik. Saat app dibuat
/// untuk HP, ganti isi sheet ini dengan paket `local_auth`.
Future<bool> showBiometricSheet(
  BuildContext context, {
  required String title,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isDismissible: true,
    constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _BiometricSheet(title: title),
  );
  return result ?? false;
}

class _BiometricSheet extends StatefulWidget {
  const _BiometricSheet({required this.title});

  final String title;

  @override
  State<_BiometricSheet> createState() => _BiometricSheetState();
}

class _BiometricSheetState extends State<_BiometricSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  Timer? _scanTimer;
  Timer? _closeTimer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Pura-pura memindai sidik jari selama ~1,5 detik.
    _scanTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _done = true);
      _pulse.stop();
      _closeTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _closeTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _done ? AppColors.success : AppColors.primary;
    final background = _done ? AppColors.successLight : AppColors.primaryLight;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _done ? 'Berhasil diverifikasi' : 'Sentuh sensor sidik jari',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final double size = 96 + (_done ? 0.0 : _pulse.value * 14);
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: background,
                  ),
                  child: child,
                );
              },
              child: Icon(
                _done ? Icons.check_rounded : Icons.fingerprint_rounded,
                size: 52,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton(
              onPressed: _done ? null : () => Navigator.of(context).pop(false),
              child: Text(
                'Batal',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Simulasi — sensor asli belum tersedia di web.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
